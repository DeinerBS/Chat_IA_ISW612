#!/usr/bin/env bash
# Despliegue completo en una VM Ubuntu Server 24.04 limpia: corre los scripts 00 a 07 en orden.
# Uso: sudo ./scripts/desplegar.sh /dev/sdX [modelo]   (sdX = disco de datos vacío de 20 GB)
set -euo pipefail

DISCO="${1:-}"
MODELO="${2:-llama3.2:1b}"
DIR="$(cd "$(dirname "$0")" && pwd)"

[[ $EUID -eq 0 ]] || { echo "Ejecutar con sudo"; exit 1; }
chmod +x "$DIR"/*.sh

paso() { echo; echo "=================== $1 ==================="; }

paso "Red host-only"
[[ -f /etc/netplan/60-hostonly.yaml ]] || "$DIR/00-red-hostonly.sh"

paso "Disco de datos"
if mountpoint -q /srv/ia; then
  echo "/srv/ia ya está montado: se omite"
else
  [[ -n "$DISCO" ]] || { echo "Indique el disco de datos, ej: /dev/sdc"; exit 1; }
  "$DIR/01-disco-datos.sh" "$DISCO"
fi

paso "Ollama";     "$DIR/02-ollama.sh" "$MODELO"
paso "MariaDB";    "$DIR/03-mariadb.sh"
paso "PHP-FPM";    "$DIR/04-php-fpm.sh"
paso "Nginx";      "$DIR/05-nginx.sh"
paso "App";        "$DIR/06-app.sh"
paso "Seguridad";  "$DIR/07-seguridad.sh"

paso "Respaldo diario (2:30 a. m.)"
install -m 750 "$DIR/respaldo.sh" /usr/local/sbin/chatia-respaldo
echo "30 2 * * * root /usr/local/sbin/chatia-respaldo >> /var/log/chatia-respaldo.log 2>&1" > /etc/cron.d/chatia-respaldo
chmod 644 /etc/cron.d/chatia-respaldo

paso "Verificación"
"$DIR/verificar-avance.sh" "$MODELO"
echo; echo "Despliegue terminado: https://$(ip -4 -br addr show enp0s8 | awk '{print $3}' | cut -d/ -f1)/"
