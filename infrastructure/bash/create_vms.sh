```bash
#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$0")/../.."

source configs/templates/templates.conf

command -v VBoxManage >/dev/null || {
    echo "ERROR: VirtualBox no está instalado."
    exit 1
}

ISO_PATH="iso/$DEBIAN_ISO"

mkdir -p iso

if [[ ! -f "$ISO_PATH" ]]; then
    echo "Descargando Debian..."
    wget -O "$ISO_PATH" "$DEBIAN_ISO_URL"
fi

create_vm() {
    NAME="$1"
    RAM="$2"
    CPU="$3"
    DISK="$4"

    echo "Creando máquina: $NAME"

    if VBoxManage showvminfo "$NAME" >/dev/null 2>&1; then
        echo "La máquina $NAME ya existe. Se omite."
        return
    fi

    VBoxManage createvm \
        --name "$NAME" \
        --ostype Debian_64 \
        --register

    VBoxManage modifyvm "$NAME" \
        --memory "$RAM" \
        --cpus "$CPU" \
        --nic1 intnet \
        --intnet1 "$NETWORK_NAME" \
        --cableconnected1 on \
        --boot1 dvd \
        --boot2 disk

    VBoxManage createmedium disk \
        --filename "$HOME/VirtualBox VMs/$NAME/$NAME.vdi" \
        --size "$((DISK * 1024))" \
        --format VDI

    VBoxManage storagectl "$NAME" \
        --name SATA \
        --add sata \
        --controller IntelAhci

    VBoxManage storageattach "$NAME" \
        --storagectl SATA \
        --port 0 \
        --device 0 \
        --type hdd \
        --medium "$HOME/VirtualBox VMs/$NAME/$NAME.vdi"

    VBoxManage storageattach "$NAME" \
        --storagectl SATA \
        --port 1 \
        --device 0 \
        --type dvddrive \
        --medium "$ISO_PATH"

    echo "Máquina $NAME creada."
}

create_vm "$SERVER_TEMPLATE" "$VM_RAM_SERVER" "$VM_CPU_SERVER" "$VM_DISK_SERVER"

create_vm "$DESKTOP_TEMPLATE" "$VM_RAM_DESKTOP" "$VM_CPU_DESKTOP" "$VM_DISK_DESKTOP"

echo "Creación finalizada."
VBoxManage list vms
```
