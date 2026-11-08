#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

source configs/templates/templates.conf

VBOX="${VBOXMANAGE_BIN:-VBoxManage}"
ISO="$ROOT/iso/$DEBIAN_ISO"
BUILD="$ROOT/build"
TIMEOUT=3600

die() {
    echo "ERROR: $*" >&2
    exit 1
}

command -v "$VBOX" >/dev/null || die "Falta VirtualBox."
command -v wget >/dev/null || die "Falta wget."
command -v python3 >/dev/null || die "Falta Python 3."

# Compatibilidad con el nombre real del archivo del profesor.
if [[ ! -f "$PROFESSOR_KEY" && -f configs/ssh/vcorp_auditor.pub ]]; then
    PROFESSOR_KEY="configs/ssh/vcorp_auditor.pub"
fi

[[ -f "$PROFESSOR_KEY" ]] || die "No existe la clave del profesor."
[[ -f "$PERSONAL_KEY" ]] || die "No existe la clave personal."

mkdir -p iso "$BUILD/preseed"

if [[ ! -s "$ISO" ]]; then
    echo "Descargando Debian..."
    wget -O "$ISO.part" "$DEBIAN_ISO_URL"
    mv "$ISO.part" "$ISO"
fi

# Preparar claves públicas.
KEYS_B64="$(
    cat "$PROFESSOR_KEY" "$PERSONAL_KEY" |
    sort -u |
    base64 -w0
)"

[[ -n "$KEYS_B64" ]] || die "No se pudieron preparar las claves SSH."

PASSWORD_FILE="$(mktemp)"
chmod 600 "$PASSWORD_FILE"
printf '%s\n' "$VM_PASSWORD" > "$PASSWORD_FILE"

trap 'rm -f "$PASSWORD_FILE"' EXIT

prepare_preseed() {
    local SOURCE="$1"
    local DEST="$2"

    VM_PASSWORD="$VM_PASSWORD" KEYS_B64="$KEYS_B64" \
    python3 - "$SOURCE" "$DEST" <<'PY'
import os
import sys

source, destination = sys.argv[1:3]
password = os.environ["VM_PASSWORD"]
keys = os.environ["KEYS_B64"]

with open(source, encoding="utf-8") as f:
    lines = f.readlines()

result = []
password_added = False

for line in lines:
    if line.startswith("d-i passwd/user-password"):
        continue

    if line.startswith("d-i preseed/late_command"):
        continue

    if line.startswith("d-i finish-install/reboot_in_progress"):
        continue

    if line.startswith("d-i debian-installer/exit/poweroff"):
        continue

    result.append(line)

    if line.startswith("d-i passwd/username") and not password_added:
        result.append(f"d-i passwd/user-password password {password}\n")
        result.append(f"d-i passwd/user-password-again password {password}\n")
        password_added = True

if not password_added:
    raise SystemExit("No se encontró passwd/username en el Preseed.")

result.extend([
    "d-i finish-install/reboot_in_progress note\n",
    "d-i debian-installer/exit/halt boolean true\n",
    "d-i debian-installer/exit/poweroff boolean true\n",
])

result.append(
    "d-i preseed/late_command string "
    "in-target usermod -aG sudo sysadmin; "
    "in-target install -d -m 700 -o sysadmin -g sysadmin /home/sysadmin/.ssh; "
    f"in-target sh -c 'echo {keys} | base64 -d > /home/sysadmin/.ssh/authorized_keys'; "
    "in-target chown sysadmin:sysadmin /home/sysadmin/.ssh/authorized_keys; "
    "in-target chmod 600 /home/sysadmin/.ssh/authorized_keys; "
    "in-target systemctl enable ssh; "
    "in-target sh -c 'printf \"auto lo\\niface lo inet loopback\\n\\nallow-hotplug enp0s3\\niface enp0s3 inet dhcp\\n\" > /etc/network/interfaces'; "
    "in-target systemctl enable networking\n"
)

with open(destination, "w", encoding="utf-8") as f:
    f.writelines(result)
PY
}

create_template() {
    local NAME="$1"
    local RAM="$2"
    local CPU="$3"
    local DISK="$4"
    local HOSTNAME="$5"
    local PRESEED="$6"

    local GENERATED="$BUILD/preseed/$NAME.cfg"
    local VM_DIR="$HOME/VirtualBox VMs/$NAME"

    if "$VBOX" showvminfo "$NAME" >/dev/null 2>&1; then
        die "$NAME ya existe. No se sobrescribirá automáticamente."
    fi

    prepare_preseed "$PRESEED" "$GENERATED"

    echo
    echo "===== Creando $NAME ====="
    echo "Red durante instalación: NAT"

    "$VBOX" createvm \
        --name "$NAME" \
        --ostype Debian_64 \
        --basefolder "$HOME/VirtualBox VMs" \
        --register

    mkdir -p "$VM_DIR"

    "$VBOX" modifyvm "$NAME" \
        --memory "$RAM" \
        --cpus "$CPU" \
        --ioapic on \
        --nic1 nat \
        --cableconnected1 on \
        --boot1 dvd \
        --boot2 disk

    "$VBOX" createmedium disk \
        --filename "$VM_DIR/$NAME.vdi" \
        --size "$((DISK * 1024))" \
        --format VDI

    "$VBOX" storagectl "$NAME" \
        --name SATA \
        --add sata \
        --controller IntelAhci

    "$VBOX" storageattach "$NAME" \
        --storagectl SATA \
        --port 0 \
        --device 0 \
        --type hdd \
        --medium "$VM_DIR/$NAME.vdi"

    "$VBOX" unattended install "$NAME" \
        --iso="$ISO" \
        --script-template="$GENERATED" \
        --user="$VM_USER" \
        --user-password-file="$PASSWORD_FILE" \
        --full-user-name="VirtualCorp Admin" \
        --hostname="$HOSTNAME.local" \
        --locale=es_ES \
        --country=ES \
        --time-zone=Europe/Madrid \
        --start-vm=headless

    echo "Esperando a que termine la instalación de $NAME..."

    local elapsed=0
    local state=""

    while (( elapsed < TIMEOUT )); do
        state=$("$VBOX" showvminfo "$NAME" --machinereadable |
            sed -n 's/^VMState="\([^"]*\)"/\1/p')

        [[ "$state" == "poweroff" ]] && break

        sleep 10
        elapsed=$((elapsed + 10))
    done

    [[ "$state" == "poweroff" ]] ||
        die "$NAME no terminó o no se apagó. Estado: $state"

    echo "Instalación terminada. Configurando red privada DHCP..."

    "$VBOX" modifyvm "$NAME" \
        --nic1 intnet \
        --intnet1 "$NETWORK_NAME" \
        --cableconnected1 on

    "$VBOX" snapshot "$NAME" take deploy-base

    echo "OK: $NAME preparado."
}

create_template \
    "$SERVER_TEMPLATE" \
    "$VM_RAM_SERVER" \
    "$VM_CPU_SERVER" \
    "$VM_DISK_SERVER" \
    "$SERVER_HOSTNAME" \
    "$ROOT/infrastructure/preseed/server.cfg" &
SERVER_PID=$!

create_template \
    "$DESKTOP_TEMPLATE" \
    "$VM_RAM_DESKTOP" \
    "$VM_CPU_DESKTOP" \
    "$VM_DISK_DESKTOP" \
    "$DESKTOP_HOSTNAME" \
    "$ROOT/infrastructure/preseed/desktop.cfg" &
DESKTOP_PID=$!

SERVER_STATUS=0
DESKTOP_STATUS=0

wait "$SERVER_PID" || SERVER_STATUS=$?
wait "$DESKTOP_PID" || DESKTOP_STATUS=$?

if (( SERVER_STATUS != 0 || DESKTOP_STATUS != 0 )); then
    die "Ha fallado la creación de una o ambas plantillas."
fi

echo
echo "Las dos plantillas se han creado correctamente."
"$VBOX" list vms
