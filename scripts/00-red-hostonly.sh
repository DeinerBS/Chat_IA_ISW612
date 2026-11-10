#!/usr/bin/env bash
# Configura el 2.º adaptador (Solo anfitrión) con IP fija.
# Uso: sudo ./00-red-hostonly.sh [interfaz] [ip/prefijo]
set -euo pipefail

IFACE="${1:-enp0s8}"
IP="${2:-192.168.56.10/24}"

[[ $EUID -eq 0 ]] || { echo "Ejecutar con sudo"; exit 1; }
ip link show "$IFACE" >/dev/null 2>&1 || { echo "No existe $IFACE. Revise con: ip -br link"; exit 1; }

# Sin gateway: la salida a internet sigue siendo por NAT (enp0s3)
cat > /etc/netplan/60-hostonly.yaml <<EOF
network:
  version: 2
  ethernets:
    $IFACE:
      dhcp4: false
      addresses: [$IP]
EOF
chmod 600 /etc/netplan/60-hostonly.yaml

netplan apply
ip -br addr show "$IFACE"
