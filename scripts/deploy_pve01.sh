#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VBOX="${VBOXMANAGE_BIN:-VBoxManage}"

VM_NAME="pve01"
VM_RAM="${PVE_RAM:-3072}"
VM_CPUS="${PVE_CPUS:-2}"
VM_DISK_GB="64"
VM_MAC="080027101033"
NETWORK="privada"

ISO_DIR="$ROOT_DIR/iso"
ISO="$ISO_DIR/proxmox-ve_9.2-1.iso"
AUTO_ISO="$ISO_DIR/proxmox-ve_9.2-1-auto.iso"
ANSWER_DIR="$ROOT_DIR/artifacts/proxmox"
ANSWER="$ANSWER_DIR/answer.toml"
DISK="$ANSWER_DIR/pve01.vdi"

ISO_URL="https://download.proxmox.com/iso/proxmox-ve_9.2-1.iso"
ISO_SHA256="4e88fe416df9b527624a175f24c9aa07c714d3332afb1ee3dbf3879573ef2c6c"

echo "==== Preparando Proxmox VE: $VM_NAME ===="

# Comprobar VirtualBox
command -v "$VBOX" >/dev/null 2>&1 || {
    echo "ERROR: No se encuentra VBoxManage."
    exit 1
}

# No modificar una VM que ya exista
if "$VBOX" showvminfo "$VM_NAME" >/dev/null 2>&1; then
    echo "AVISO: $VM_NAME ya existe. No se modifica ni se borra."
    echo "Comprueba su estado con: VBoxManage showvminfo $VM_NAME"
    exit 0
fi

# Instalar Podman si falta
if ! command -v podman >/dev/null 2>&1; then
    echo "Instalando Podman..."
    sudo apt-get update
    sudo apt-get install -y podman
fi

mkdir -p "$ISO_DIR" "$ANSWER_DIR"

# Descargar la ISO solo si no existe
if [[ ! -f "$ISO" ]]; then
    echo "Descargando ISO oficial de Proxmox..."
    curl -fL "$ISO_URL" -o "$ISO"
fi

# Verificar integridad de la ISO
echo "Verificando SHA256 de la ISO..."
echo "$ISO_SHA256  $ISO" | sha256sum -c -

# Buscar una clave pública SSH existente
SSH_KEY=""
for candidate in \
    "$ROOT_DIR/configs/ssh/vcorp_auditor.pub" \
    "$ROOT_DIR/configs/ssh/vcorp-auditor.pub" \
    "$ROOT_DIR/configs/ssh/abdelkarimhammachifp23.pub"; do
    if [[ -s "$candidate" ]]; then
        SSH_KEY="$(head -n 1 "$candidate")"
        break
    fi
done

if [[ -z "$SSH_KEY" ]]; then
    echo "ERROR: No encuentro una clave pública SSH en configs/ssh."
    echo "Comprueba tus archivos .pub antes de continuar."
    exit 1
fi

# Obtener contraseña automáticamente desde la configuración
PVE_ROOT_PASSWORD="Asdqwe!23"

ROOT_HASH="$(openssl passwd -6 "$PVE_ROOT_PASSWORD")"
unset PVE_ROOT_PASSWORD
# Crear answer.toml
cat > "$ANSWER" <<EOF
[global]
keyboard = "es"
country = "es"
fqdn = "pve01.virtualcorp.local"
mailto = "root@virtualcorp.local"
timezone = "Europe/Madrid"
root-password-hashed = "$ROOT_HASH"
root-ssh-keys = ["$SSH_KEY"]
reboot-mode = "power-off"
reboot-on-error = false

[network]
source = "from-answer"
cidr = "10.10.0.133/26"
gateway = "10.10.0.129"
dns = "10.10.0.129"
filter.ID_NET_NAME_MAC = "*$VM_MAC"

[disk-setup]
filesystem = "ext4"
disk-list = ["sda"]
EOF

chmod 600 "$ANSWER"
unset ROOT_HASH
# Crear usuario administrativo sysadmin en Proxmox
FIRST_BOOT="$ANSWER_DIR/first-boot.sh"

cat > "$FIRST_BOOT" <<'HOOK'
#!/usr/bin/env bash
set -Eeuo pipefail

SYSADMIN_PASSWORD="Asdqwe!23"

pveum user add sysadmin@pve \
    --password "$SYSADMIN_PASSWORD" \
    --comment "Administrador VirtualCorp"

pveum acl modify / \
    --user sysadmin@pve \
    --role Administrator
HOOK

chmod 700 "$FIRST_BOOT"
# Evitar que se suban al repositorio el answer y la ISO generada
if [[ -f .gitignore ]]; then
    grep -qxF '/artifacts/proxmox/answer.toml' .gitignore ||
        echo '/artifacts/proxmox/answer.toml' >> .gitignore
    grep -qxF '/iso/proxmox-ve_9.2-1-auto.iso' .gitignore ||
        echo '/iso/proxmox-ve_9.2-1-auto.iso' >> .gitignore
fi

# Instalar el asistente dentro de Debian, sin añadir repositorios Proxmox a Ubuntu
echo
echo "Preparando el asistente de instalación dentro de Debian..."

podman run --rm \
    -v "$ROOT_DIR:/work:rw" \
    -w /work \
    docker.io/library/debian:trixie \
    bash -Eeuo pipefail -c '
        apt-get update
        apt-get install -y ca-certificates curl xorriso

        curl -fsSL \
          https://enterprise.proxmox.com/debian/proxmox-archive-keyring-trixie.gpg \
          -o /usr/share/keyrings/proxmox-archive-keyring.gpg

        echo "deb [signed-by=/usr/share/keyrings/proxmox-archive-keyring.gpg] http://download.proxmox.com/debian/pve trixie pve-no-subscription" \
          > /etc/apt/sources.list.d/pve.list

        apt-get update
        apt-get install -y proxmox-auto-install-assistant

        proxmox-auto-install-assistant validate-answer \
          /work/artifacts/proxmox/answer.toml

        proxmox-auto-install-assistant prepare-iso \
          /work/iso/proxmox-ve_9.2-1.iso \
          --fetch-from iso \
          --answer-file /work/artifacts/proxmox/answer.toml \
	  --on-first-boot /work/artifacts/proxmox/first-boot.sh \
          --output /work/iso/proxmox-ve_9.2-1-auto.iso
    '

if [[ ! -s "$AUTO_ISO" ]]; then
    echo "ERROR: No se ha generado la ISO automática."
    exit 1
fi

# Crear la VM nueva
echo
echo "Creando la máquina virtual $VM_NAME..."

"$VBOX" createvm \
    --name "$VM_NAME" \
    --ostype Debian_64 \
    --register

"$VBOX" modifyvm "$VM_NAME" \
    --memory "$VM_RAM" \
    --cpus "$VM_CPUS" \
    --nested-hw-virt on \
    --nic1 intnet \
    --intnet1 "$NETWORK" \
    --macaddress1 "$VM_MAC" \
    --boot1 dvd \
    --boot2 disk \
    --boot3 none \
    --boot4 none

"$VBOX" storagectl "$VM_NAME" \
    --name SATA \
    --add sata \
    --controller IntelAhci \
    --portcount 2

"$VBOX" createmedium disk \
    --filename "$DISK" \
    --size "$((VM_DISK_GB * 1024))" \
    --format VDI

"$VBOX" storageattach "$VM_NAME" \
    --storagectl SATA \
    --port 0 \
    --device 0 \
    --type hdd \
    --medium "$DISK"

"$VBOX" storageattach "$VM_NAME" \
    --storagectl SATA \
    --port 1 \
    --device 0 \
    --type dvddrive \
    --medium "$AUTO_ISO"

echo
echo "Iniciando instalación desatendida de Proxmox..."
"$VBOX" startvm "$VM_NAME" --type headless

# Esperar a que el instalador apague la VM al terminar
echo "Esperando a que finalice la instalación (máximo 60 minutos)..."
SEEN_RUNNING=0
INSTALL_FINISHED=0

for ((i=0; i<120; i++)); do
    STATE="$("$VBOX" showvminfo "$VM_NAME" --machinereadable |
        sed -n 's/^VMState="\([^"]*\)"/\1/p')"

    if [[ "$STATE" == "running" ]]; then
        SEEN_RUNNING=1
    elif [[ "$STATE" == "poweroff" && "$SEEN_RUNNING" -eq 1 ]]; then
        INSTALL_FINISHED=1
        break
    elif [[ "$STATE" == "aborted" ]]; then
        echo "ERROR: VirtualBox informa que la VM se ha abortado."
        exit 1
    fi

    sleep 30
done

if [[ "$INSTALL_FINISHED" -ne 1 ]]; then
    echo "AVISO: No se ha confirmado el fin de la instalación."
    echo "La VM se conserva. No se borra nada."
    echo "Revisa su consola con: VBoxManage showvminfo $VM_NAME"
    exit 1
fi

# Retirar ISO para evitar que vuelva a iniciar el instalador
echo "Instalación terminada. Retirando la ISO..."
"$VBOX" storageattach "$VM_NAME" \
    --storagectl SATA \
    --port 1 \
    --device 0 \
    --type dvddrive \
    --medium none

"$VBOX" modifyvm "$VM_NAME" \
    --boot1 disk \
    --boot2 none \
    --boot3 none \
    --boot4 none

echo "Arrancando Proxmox desde el disco..."
"$VBOX" startvm "$VM_NAME" --type headless

echo
echo "==== pve01 creado correctamente ===="
echo "Nombre:    pve01"
echo "IP:        10.10.0.133/26"
echo "Gateway:   10.10.0.129"
echo "Red:       privada"
echo "RAM:       ${VM_RAM} MB"
echo "CPU:       $VM_CPUS"
echo "Disco:     ${VM_DISK_GB} GB"
echo "Web:       https://10.10.0.133:8006"
