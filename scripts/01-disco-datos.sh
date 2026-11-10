#!/usr/bin/env bash
# Particiona, formatea (ext4) y monta por UUID el disco de datos en /srv/ia.
# BORRA el disco indicado. Uso: sudo ./01-disco-datos.sh /dev/sdb
set -euo pipefail

DISCO="${1:-}"
PUNTO="/srv/ia"

[[ $EUID -eq 0 ]] || { echo "Ejecutar con sudo"; exit 1; }
[[ -b "$DISCO" ]] || { echo "Indique el disco, ej: /dev/sdb (vea lsblk)"; exit 1; }

# Protección: no tocar el disco del sistema ni uno con particiones
RAIZ="/dev/$(lsblk -no PKNAME "$(findmnt -no SOURCE /)" | head -1)"
[[ "$DISCO" != "$RAIZ" ]] || { echo "$DISCO es el disco del sistema"; exit 1; }
if [[ $(lsblk -no NAME "$DISCO" | wc -l) -gt 1 ]]; then
  echo "$DISCO ya tiene particiones; revise con lsblk -f"; exit 1
fi

lsblk "$DISCO"
read -rp "Se borrará $DISCO. Escriba SI para continuar: " ok
[[ "$ok" == "SI" ]] || exit 1

# Tabla GPT con una sola partición ext4
parted -s "$DISCO" mklabel gpt mkpart datos ext4 0% 100%
udevadm settle
PART="$(lsblk -lnpo NAME "$DISCO" | sed -n 2p)"
mkfs.ext4 -F -L datos-ia "$PART"

UUID="$(blkid -s UUID -o value "$PART")"
mkdir -p "$PUNTO"

# Se monta por UUID (no por /dev/sdb1, que puede cambiar de nombre)
cp /etc/fstab /etc/fstab.bak
grep -q "$PUNTO " /etc/fstab || \
  echo "UUID=$UUID  $PUNTO  ext4  defaults,nofail  0  2" >> /etc/fstab
systemctl daemon-reload
mount -a

# Estructura base del disco
install -d -m 755 "$PUNTO"
install -d -o root -g root -m 700 "$PUNTO/respaldos"
install -d -m 755 "$PUNTO/mariadb"   # se le asigna dueño al instalar MariaDB

findmnt "$PUNTO"
grep "$PUNTO" /etc/fstab
