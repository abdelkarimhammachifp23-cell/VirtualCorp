#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

source configs/templates/templates.conf

die() {
    echo "ERROR: $*" >&2
    exit 1
}

command -v VBoxManage >/dev/null 2>&1 || die "VirtualBox no está instalado."
command -v wget >/dev/null 2>&1 || die "wget no está instalado."

mkdir -p iso

# ==========================================
# DESCARGA DEBIAN
# ==========================================

DEBIAN_ISO_PATH="$ROOT/iso/$DEBIAN_ISO"

if [[ ! -s "$DEBIAN_ISO_PATH" ]]; then
    echo "Descargando Debian..."
    wget -O "$DEBIAN_ISO_PATH.part" "$DEBIAN_ISO_URL"
    mv "$DEBIAN_ISO_PATH.part" "$DEBIAN_ISO_PATH"
else
    echo "ISO Debian existente. Se omite."
fi

# ==========================================
# DESCARGA PROXMOX
# ==========================================

PROXMOX_ISO_PATH="$ROOT/iso/$PROXMOX_ISO"

if [[ ! -s "$PROXMOX_ISO_PATH" ]]; then
    echo "Descargando Proxmox..."

    wget --no-check-certificate \
        -O "$PROXMOX_ISO_PATH.part" \
        "$PROXMOX_ISO_URL"

    mv "$PROXMOX_ISO_PATH.part" "$PROXMOX_ISO_PATH"
else
    echo "ISO Proxmox existente. Se omite."
fi

# ==========================================
# COMPROBACIONES
# ==========================================

[[ -s "$DEBIAN_ISO_PATH" ]] || die "Falta la ISO Debian."
[[ -s "$PROXMOX_ISO_PATH" ]] || die "Falta la ISO Proxmox."

# ==========================================
# CREAR MÁQUINAS
# ==========================================

create_vm() {
    [[ "$#" -eq 6 ]] || die "Argumentos incorrectos en create_vm."

    local NAME="$1"
    local RAM="$2"
    local CPU="$3"
    local DISK="$4"
    local HOSTNAME="$5"
    local POST_INSTALL="$6"

    echo ""
    echo "Comprobando $NAME..."

    if VBoxManage showvminfo "$NAME" >/dev/null 2>&1; then
        echo "$NAME ya existe. Se omite y se continúa."
        return 0
    fi

    echo "Creando $NAME..."

    local VM_DIR="$HOME/VirtualBox VMs/$NAME"

    VBoxManage createvm \
        --name "$NAME" \
        --ostype Debian_64 \
        --basefolder "$HOME/VirtualBox VMs" \
        --register

    if [[ "$NETWORK_MODE" == "intnet" ]]; then
    VBoxManage modifyvm "$NAME" \
        --memory "$RAM" \
        --cpus "$CPU" \
        --nic1 intnet \
        --intnet1 "$NETWORK_NAME" \
        --cableconnected1 on \
        --boot1 dvd \
        --boot2 disk
elif [[ "$NETWORK_MODE" == "nat" ]]; then
    VBoxManage modifyvm "$NAME" \
        --memory "$RAM" \
        --cpus "$CPU" \
        --nic1 nat \
        --cableconnected1 on \
        --boot1 dvd \
        --boot2 disk
else
    die "NETWORK_MODE no válido: $NETWORK_MODE"
fi
    VBoxManage createmedium disk \
        --filename "$VM_DIR/$NAME.vdi" \
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
        --medium "$VM_DIR/$NAME.vdi"

    VBoxManage storageattach "$NAME" \
        --storagectl SATA \
        --port 1 \
        --device 0 \
        --type dvddrive \
        --medium "$DEBIAN_ISO_PATH"

    echo "Preparando instalación automática de $NAME..."

    VBoxManage unattended install "$NAME" \
    --iso="$DEBIAN_ISO_PATH" \
    --user="$VM_USER" \
    --user-password="$VM_PASSWORD" \
    --full-user-name="VirtualCorp Admin" \
    --hostname="$HOSTNAME.local" \
    --locale="es_ES" \
    --country="ES" \
    --time-zone="Europe/Madrid" \
    --post-install-command="chroot /target /bin/sh -c '$POST_INSTALL'" \
    --start-vm=headless

echo "Instalación iniciada: $NAME"

TIMEOUT=1800
ELAPSED=0
STATE=""

# Primero esperar a que la máquina arranque
echo "Esperando a que arranque $NAME..."

while [[ $ELAPSED -lt $TIMEOUT ]]; do
    STATE=$(VBoxManage showvminfo "$NAME" --machinereadable |
        sed -n 's/^VMState="\([^"]*\)"/\1/p')

    [[ "$STATE" == "running" ]] && break

    sleep 10
    ELAPSED=$((ELAPSED + 10))
done

if [[ "$STATE" != "running" ]]; then
    echo "ERROR: $NAME no llegó a arrancar."
    return 1
fi

# Después esperar a que termine la instalación y se apague
echo "Esperando a que termine la instalación de $NAME..."

ELAPSED=0

while [[ $ELAPSED -lt $TIMEOUT ]]; do
    STATE=$(VBoxManage showvminfo "$NAME" --machinereadable |
        sed -n 's/^VMState="\([^"]*\)"/\1/p')

    [[ "$STATE" == "poweroff" ]] && break

    sleep 10
    ELAPSED=$((ELAPSED + 10))
done

if [[ "$STATE" != "poweroff" ]]; then
    echo "ERROR: $NAME no terminó dentro del tiempo esperado."
    return 1
fi

# Cambiar NAT por la red interna definitiva
echo "Cambiando $NAME a la red interna pl0..."

VBoxManage modifyvm "$NAME" \
    --nic1 intnet \
    --intnet1 "pl0" \
    --cableconnected1 on

echo "$NAME preparado correctamente."
}
# ==========================================
# DEBIAN SERVER
# ==========================================

create_vm \
    "$SERVER_TEMPLATE" \
    "$VM_RAM_SERVER" \
    "$VM_CPU_SERVER" \
    "$VM_DISK_SERVER" \
    "$SERVER_HOSTNAME" \
    "apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server sudo"

# ==========================================
# DEBIAN DESKTOP
# ==========================================

create_vm \
    "$DESKTOP_TEMPLATE" \
    "$VM_RAM_DESKTOP" \
    "$VM_CPU_DESKTOP" \
    "$VM_DISK_DESKTOP" \
    "$DESKTOP_HOSTNAME" \
    "apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y lxqt lightdm sudo"

echo ""
echo "======================================"
echo "PROCESO DE CREACIÓN FINALIZADO"
echo "======================================"

VBoxManage list vms
