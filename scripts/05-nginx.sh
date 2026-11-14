#!/usr/bin/env bash
# Nginx como proxy inverso HTTPS hacia PHP-FPM, con cabeceras y rate limiting.
# Uso: sudo ./05-nginx.sh [ip_del_servidor]
set -euo pipefail

IP="${1:-192.168.56.10}"
CRT="/etc/ssl/certs/chatia.crt"
KEY="/etc/ssl/private/chatia.key"
REPO="$(cd "$(dirname "$0")/.." && pwd)"

[[ $EUID -eq 0 ]] || { echo "Ejecutar con sudo"; exit 1; }
[[ -S /run/php/chatia.sock ]] || { echo "Falta el socket de PHP-FPM: corra 04-php-fpm.sh"; exit 1; }

apt-get install -y nginx openssl

# Certificado autofirmado (1 año) con la IP en el SAN
if [[ ! -f "$CRT" ]]; then
  openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
    -keyout "$KEY" -out "$CRT" \
    -subj "/C=CR/O=UTN ISW-612/CN=$IP" \
    -addext "subjectAltName=IP:$IP,DNS:chatia.local"
fi
chmod 600 "$KEY"
chmod 644 "$CRT"

# Zonas de rate limiting (contexto http) y configuración del sitio
install -m 644 "$REPO/config/nginx/chatia-limites.conf" /etc/nginx/conf.d/chatia-limites.conf
install -m 644 "$REPO/config/nginx/chatia-php.conf" /etc/nginx/snippets/chatia-php.conf
install -m 644 "$REPO/config/nginx/chatia.conf" /etc/nginx/sites-available/chatia
ln -sf /etc/nginx/sites-available/chatia /etc/nginx/sites-enabled/chatia
rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl enable nginx
systemctl reload nginx || systemctl restart nginx

# Abrir solo 80 y 443 en el firewall
ufw allow 80/tcp comment 'HTTP (redirige a 443)'
ufw allow 443/tcp comment 'HTTPS chatia'

echo "--- verificación ---"
ss -tlnp | grep -E ':(80|443) '
curl -sI http://127.0.0.1/ | head -3
curl -skI https://127.0.0.1/ | head -12
