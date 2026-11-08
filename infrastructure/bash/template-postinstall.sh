#!/usr/bin/env bash

set -e

# Comprobar que se ejecuta como root
if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: este script debe ejecutarse como root."
    exit 1
fi

# Comprobar usuario
id sysadmin >/dev/null 2>&1 || {
    echo "ERROR: no existe el usuario sysadmin."
    exit 1
}

# Actualizar paquetes
export DEBIAN_FRONTEND=noninteractive

apt-get update

# Paquetes comunes
apt-get install -y \
    openssh-server \
    sudo \
    ca-certificates \
    curl

# Instalar escritorio solo en Desktop
if [[ "${TEMPLATE_FLAVOR}" == "desktop" ]]; then

    apt-get install -y \
        lxqt-core \
        sddm \
        xorg \
        dbus-x11 \
        falkon

fi

# Incorporar sysadmin al grupo sudo
usermod -aG sudo sysadmin

# Crear directorio SSH
install -d \
    -m 700 \
    -o sysadmin \
    -g sysadmin \
    /home/sysadmin/.ssh

# Instalar las claves públicas autorizadas
printf '%s' "$AUTHORIZED_KEYS_B64" |
    base64 -d > /home/sysadmin/.ssh/authorized_keys

chown sysadmin:sysadmin \
    /home/sysadmin/.ssh/authorized_keys

chmod 600 /home/sysadmin/.ssh/authorized_keys

# Habilitar SSH
systemctl enable ssh

# Configurar DHCP
cat > /etc/network/interfaces <<'EOF'
auto lo
iface lo inet loopback

allow-hotplug enp0s3
iface enp0s3 inet dhcp
EOF

# Eliminar caché de paquetes
apt-get clean

# Finalizar
echo "Preparacion Debian completada."
