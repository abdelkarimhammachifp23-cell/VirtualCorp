#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$0")/.."

source configs/templates/templates.conf
source configs/equipment.conf

VBOX="${VBOXMANAGE_BIN:-VBoxManage}"

command -v "$VBOX" >/dev/null 2>&1 || {
    echo "ERROR: No se encuentra VBoxManage."
    exit 1
}

for TEMPLATE in "Debian-Server-Template" "Debian-Desktop-Template"; do
    "$VBOX" showvminfo "$TEMPLATE" >/dev/null 2>&1 || {
        echo "ERROR: No existe la plantilla $TEMPLATE."
        exit 1
    }

    STATE=$("$VBOX" showvminfo "$TEMPLATE" --machinereadable |
        sed -n 's/^VMState="\([^"]*\)"/\1/p')

    if [[ "$STATE" != "poweroff" ]]; then
        echo "ERROR: $TEMPLATE debe estar apagada. Estado: $STATE"
        exit 1
    fi
done

for ITEM in "${EQUIPMENT[@]}"; do
    IFS='|' read -r NAME TEMPLATE NETWORK <<< "$ITEM"

    echo
    echo "==== Preparando $NAME ===="

    if "$VBOX" showvminfo "$NAME" >/dev/null 2>&1; then
        echo "AVISO: $NAME ya existe. Se omite."
        continue
    fi

    SNAPSHOT_UUID=$("$VBOX" showvminfo "$TEMPLATE" --machinereadable |
        sed -n 's/^CurrentSnapshotUUID="{\([^}]*\)}"/\1/p')

    if [[ -z "$SNAPSHOT_UUID" ]]; then
        echo "Creando snapshot base de $TEMPLATE..."
        "$VBOX" snapshot "$TEMPLATE" take deploy-base
        SNAPSHOT_UUID=$("$VBOX" showvminfo "$TEMPLATE" --machinereadable |
            sed -n 's/^CurrentSnapshotUUID="{\([^}]*\)}"/\1/p')
    fi

    if [[ -z "$SNAPSHOT_UUID" ]]; then
        echo "ERROR: No se pudo obtener el snapshot de $TEMPLATE."
        exit 1
    fi

    "$VBOX" clonevm "$TEMPLATE" \
        --snapshot "$SNAPSHOT_UUID" \
        --name "$NAME" \
        --options link \
        --register

    "$VBOX" modifyvm "$NAME" \
        --nic1 intnet \
        --intnet1 "$NETWORK"

    echo "OK: $NAME creado en la red interna $NETWORK."
done

echo
echo "Despliegue terminado."
