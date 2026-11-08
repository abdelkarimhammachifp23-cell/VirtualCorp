#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/common.sh"

# Versiones fijadas
DEBIAN_VERSION="13.7.0"
DEBIAN_ISO_NAME="debian-13.7.0-amd64-netinst.iso"
DEBIAN_ISO_URL="https://cdimage.debian.org/debian-cd/13.7.0/amd64/iso-cd/debian-13.7.0-amd64-netinst.iso"
DEBIAN_SUMS_URL="https://cdimage.debian.org/debian-cd/13.7.0/amd64/iso-cd/SHA256SUMS"

PROXMOX_VERSION="9.2-1"
PROXMOX_ISO_NAME="proxmox-ve_9.2-1.iso"
PROXMOX_ISO_URL="https://download.proxmox.com/iso/proxmox-ve_9.2-1.iso"
PROXMOX_SHA256="4e88fe416df9b527624a175f24c9aa07c714d3332afb1ee3dbf3879573ef2c6c"

# Utilizar la carpeta iso del proyecto
ISO_DIR="$PROJECT_ROOT/iso"
mkdir -p "$ISO_DIR"

for command in curl sha256sum awk; do
    command -v "$command" >/dev/null 2>&1 || {
        log_err "Falta instalar: $command"
        exit 1
    }
done

# Descargar un archivo de forma segura
download_file() {
    local url="$1"
    local destination="$2"

    rm -f "${destination}.part"

    log_info "Descargando: $destination"

    curl --fail --location --retry 3 \
        --output "${destination}.part" "$url"

    mv "${destination}.part" "$destination"
}

# Comprobar SHA-256
verify_sha256() {
    local expected="$1"
    local file="$2"

    [[ "$expected" =~ ^[a-fA-F0-9]{64}$ ]] || return 1
    [[ -s "$file" ]] || return 1

    printf '%s  %s\n' "$expected" "$file" |
        sha256sum --check --status
}

# Comprobar ISO y descargar solamente si falta o es incorrecta
ensure_iso() {
    local name="$1"
    local url="$2"
    local expected="$3"
    local destination="$ISO_DIR/$name"

    if [[ -s "$destination" ]]; then
        if verify_sha256 "$expected" "$destination"; then
            log_ok "ISO válida. No se descarga: $name"
            return
        fi

        log_info "ISO incorrecta. Se descargará de nuevo: $name"
        rm -f "$destination"
    fi

    download_file "$url" "$destination"

    if ! verify_sha256 "$expected" "$destination"; then
        rm -f "$destination"
        log_err "La verificación SHA-256 ha fallado: $name"
        exit 1
    fi

    log_ok "ISO descargada y verificada: $name"
}

echo
log_info "===== COMPROBANDO DEBIAN $DEBIAN_VERSION ====="

# Descargar la lista de sumas de Debian
DEBIAN_SUMS="$ISO_DIR/SHA256SUMS-debian-$DEBIAN_VERSION"
download_file "$DEBIAN_SUMS_URL" "$DEBIAN_SUMS"

DEBIAN_EXPECTED="$(
    awk -v filename="$DEBIAN_ISO_NAME" '
    {
        name=$2
        sub(/^\*/, "", name)
        sub(/^\.\//, "", name)
        if (name == filename) {
            print $1
            exit
        }
    }' "$DEBIAN_SUMS"
)"

if [[ -z "$DEBIAN_EXPECTED" ]]; then
    log_err "No se encontró la suma SHA-256 de Debian."
    exit 1
fi

ensure_iso "$DEBIAN_ISO_NAME" "$DEBIAN_ISO_URL" "$DEBIAN_EXPECTED"

echo
log_info "===== COMPROBANDO PROXMOX $PROXMOX_VERSION ====="

ensure_iso "$PROXMOX_ISO_NAME" "$PROXMOX_ISO_URL" "$PROXMOX_SHA256"

echo
log_ok "Todas las ISOs están disponibles y verificadas."
echo "Directorio: $ISO_DIR"
ls -lh "$ISO_DIR"
