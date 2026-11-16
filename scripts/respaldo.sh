#!/usr/bin/env bash
# Respaldo de la BD y de las configuraciones en /srv/ia/respaldos (guarda los últimos 7).
# Uso: sudo ./respaldo.sh
set -euo pipefail

DEST="/srv/ia/respaldos"
FECHA="$(date +%Y%m%d-%H%M%S)"
CONSERVAR=7

[[ $EUID -eq 0 ]] || { echo "Ejecutar con sudo"; exit 1; }
mountpoint -q /srv/ia || { echo "/srv/ia no está montado"; exit 1; }

# Configuraciones propias del proyecto (rutas relativas a /)
CONFIG=(
  etc/chatia
  etc/nginx/sites-available/chatia etc/nginx/conf.d/chatia-limites.conf etc/nginx/snippets/chatia-php.conf
  etc/ssl/certs/chatia.crt etc/ssl/private/chatia.key
  etc/php/8.3/fpm/pool.d/chatia.conf
  etc/mysql/mariadb.conf.d/60-chatia.cnf
  etc/systemd/system/ollama.service.d etc/systemd/system/mariadb.service.d
  etc/fail2ban/jail.local etc/fail2ban/filter.d/chatia-login.conf
  etc/ssh/sshd_config.d/10-chatia.conf
  etc/ufw/user.rules etc/ufw/user6.rules
  etc/logrotate.d/chatia etc/netplan/60-hostonly.yaml etc/fstab
)
EXISTENTES=()
for c in "${CONFIG[@]}"; do [[ -e "/$c" ]] && EXISTENTES+=("$c"); done

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --single-transaction: copia consistente sin bloquear la app
mariadb-dump --single-transaction --databases chatia > "$TMP/chatia.sql"
tar -czf "$TMP/config.tar.gz" -C / "${EXISTENTES[@]}"
(cd "$TMP" && sha256sum chatia.sql config.tar.gz > SHA256SUMS)

ARCHIVO="$DEST/respaldo-$FECHA.tar.gz"
tar -czf "$ARCHIVO" -C "$TMP" chatia.sql config.tar.gz SHA256SUMS
chmod 600 "$ARCHIVO"

# Rotación: borrar los más viejos
ls -1t "$DEST"/respaldo-*.tar.gz | tail -n +$((CONSERVAR + 1)) | xargs -r rm -f

echo "Respaldo creado: $ARCHIVO ($(du -h "$ARCHIVO" | cut -f1))"
ls -lh "$DEST"
