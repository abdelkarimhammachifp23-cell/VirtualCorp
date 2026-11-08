#!/bin/bash

set -e

# Cargar configuración
source configs/templates/templates.conf

echo "================================"
echo " CREANDO TEMPLATES VIRTUALCORP"
echo "================================"

# Comprobar VirtualBox
if ! command -v VBoxManage >/dev/null; then
    echo "ERROR: VirtualBox no está instalado"
    exit 1
fi

# Comprobar Packer
if ! command -v packer >/dev/null; then
    echo "ERROR: Packer no está instalado"
    exit 1
fi

# Comprobar claves SSH
if [ ! -f "$PROFESSOR_KEY" ]; then
    echo "ERROR: Falta la clave del profesor"
    exit 1
fi

if [ ! -f "$PERSONAL_KEY" ]; then
    echo "ERROR: Falta tu clave personal"
    exit 1
fi

# Crear directorios
mkdir -p iso build

# Descargar Debian
ISO_PATH="iso/$DEBIAN_ISO"

if [ ! -f "$ISO_PATH" ]; then
    echo "Descargando Debian..."

    wget "$DEBIAN_ISO_URL" -O "$ISO_PATH"
fi

echo "ISO preparada correctamente"

# Preparar claves SSH
mkdir -p build/keys

cat "$PROFESSOR_KEY" "$PERSONAL_KEY" \
    | sort -u > build/keys/authorized_keys

chmod 600 build/keys/authorized_keys

echo "Claves SSH preparadas"

echo "Preparación finalizada"
echo "Ahora se iniciará la construcción de los templates"

