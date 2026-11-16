#!/usr/bin/env bash
# Restaura la BD (y opcionalmente las configuraciones) desde un respaldo.
# Uso: sudo ./restaurar.sh /srv/ia/respaldos/respaldo-AAAAMMDD-HHMMSS.tar.gz [--config]
set -euo pipefail

ARCHIVO="${1:-}"
CON_CONFIG="${2:-}"

[[ $EUID -eq 0 ]] || { echo "Ejecutar con sudo"; exit 1; }
[[ -f "$ARCHIVO" ]] || { echo "Indique el archivo de respaldo (ls /srv/ia/respaldos)"; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
tar -xzf "$ARCHIVO" -C "$TMP"

# Verificar integridad antes de tocar nada
(cd "$TMP" && sha256sum -c SHA256SUMS)

read -rp "Se reemplazará la base de datos chatia con el respaldo. Escriba SI para continuar: " ok
[[ "$ok" == "SI" ]] || exit 1

# El volcado trae DROP TABLE + CREATE TABLE: deja la BD igual que al momento del respaldo
mariadb < "$TMP/chatia.sql"
echo "Base de datos restaurada."

if [[ "$CON_CONFIG" == "--config" ]]; then
  tar -xzf "$TMP/config.tar.gz" -C /
  systemctl daemon-reload
  systemctl restart mariadb php8.3-fpm nginx fail2ban ollama
  ufw reload
  echo "Configuraciones restauradas y servicios reiniciados."
fi

mariadb -e "SELECT COUNT(*) AS usuarios FROM chatia.usuarios; SELECT COUNT(*) AS mensajes FROM chatia.mensajes;"
