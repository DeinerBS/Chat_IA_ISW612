#!/usr/bin/env bash
# Despliega la app, crea las tablas y el primer administrador.
# Uso: sudo ./06-app.sh   (desde la raíz del repo; se puede repetir para actualizar el código)
set -euo pipefail

APP_DIR="/var/www/chatia"
REPO_APP="$(cd "$(dirname "$0")/.." && pwd)/app"

[[ $EUID -eq 0 ]] || { echo "Ejecutar con sudo"; exit 1; }
[[ -f /etc/chatia/chatia.env ]] || { echo "Falta /etc/chatia/chatia.env: corra 03-mariadb.sh"; exit 1; }

apt-get install -y php8.3-cli

# Código: root:chatia, 750 carpetas / 640 archivos
rm -rf "$APP_DIR"
install -d -o root -g chatia -m 750 "$APP_DIR"
cp -r "$REPO_APP/." "$APP_DIR/"
chown -R root:chatia "$APP_DIR"
find "$APP_DIR" -type d -exec chmod 750 {} +
find "$APP_DIR" -type f -exec chmod 640 {} +

# Log de la app
touch /var/log/chatia/app.log
chown chatia:chatia /var/log/chatia/app.log
chmod 640 /var/log/chatia/app.log

# Tablas (como root; la app no tiene permisos para crear tablas)
mariadb chatia < "$REPO_APP/sql/schema.sql"

# Primer administrador, solo si no existe ninguno
ADMINS="$(mariadb -Nse "SELECT COUNT(*) FROM chatia.usuarios WHERE rol='admin'")"
if [[ "$ADMINS" == "0" ]]; then
  echo "== Crear el primer administrador =="
  read -rp "Usuario (minúsculas, 3-40): " USUARIO
  [[ "$USUARIO" =~ ^[a-z0-9._-]{3,40}$ ]] || { echo "Usuario inválido"; exit 1; }
  read -rp "Nombre completo: " NOMBRE
  read -rsp "Contraseña (mínimo 10): " CLAVE; echo
  [[ ${#CLAVE} -ge 10 ]] || { echo "Contraseña muy corta"; exit 1; }
  # La contraseña se pasa por stdin para que no aparezca en ps
  HASH="$(printf '%s' "$CLAVE" | php -r 'echo password_hash(stream_get_contents(STDIN), PASSWORD_BCRYPT);')"
  NOMBRE_SQL="${NOMBRE//\'/\'\'}"
  mariadb chatia -e "INSERT INTO usuarios (usuario, nombre, hash, rol) VALUES ('$USUARIO', '$NOMBRE_SQL', '$HASH', 'admin');"
  echo "Administrador $USUARIO creado."
fi

systemctl reload php8.3-fpm

echo "--- verificación ---"
mariadb chatia -e "SHOW TABLES; SELECT id, usuario, rol, LEFT(hash, 7) AS hash FROM usuarios;"
ls -l "$APP_DIR" "$APP_DIR/src" /var/log/chatia
curl -sk -o /dev/null -w "GET /login → %{http_code}\n" https://127.0.0.1/login
