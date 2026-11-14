#!/usr/bin/env bash
# MariaDB con datadir en /srv/ia/mariadb, solo localhost, BD y usuario de la app.
# Uso: sudo ./03-mariadb.sh
set -euo pipefail

DATADIR="/srv/ia/mariadb"
ENV_FILE="/etc/chatia/chatia.env"

[[ $EUID -eq 0 ]] || { echo "Ejecutar con sudo"; exit 1; }
mountpoint -q /srv/ia || { echo "/srv/ia no está montado"; exit 1; }

# Usuario de sistema de la app (sin shell ni home)
id chatia >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin chatia

apt-get install -y mariadb-server

# Mover los datos al disco de datos (solo la primera vez)
systemctl stop mariadb
if [[ ! -d "$DATADIR/mysql" ]]; then
  cp -a /var/lib/mysql/. "$DATADIR/"
fi
chown -R mysql:mysql "$DATADIR"
chmod 750 "$DATADIR"

cat > /etc/mysql/mariadb.conf.d/60-chatia.cnf <<EOF
[mysqld]
datadir      = $DATADIR
bind-address = 127.0.0.1
EOF

# Si AppArmor protege mariadbd, permitirle la nueva ruta
if aa-status 2>/dev/null | grep -q mariadbd; then
  grep -q "$DATADIR" /etc/apparmor.d/local/usr.sbin.mariadbd 2>/dev/null || \
    printf '%s/ r,\n%s/** rwk,\n' "$DATADIR" "$DATADIR" >> /etc/apparmor.d/local/usr.sbin.mariadbd
  apparmor_parser -r /etc/apparmor.d/usr.sbin.mariadbd
fi

# Esperar al disco antes de arrancar
install -d /etc/systemd/system/mariadb.service.d
printf '[Unit]\nRequiresMountsFor=/srv/ia\n' > /etc/systemd/system/mariadb.service.d/override.conf
systemctl daemon-reload
systemctl enable mariadb
systemctl start mariadb

# Credenciales de la app fuera del repositorio (se reutilizan si ya existen)
install -d -o root -g chatia -m 750 /etc/chatia
if [[ -f "$ENV_FILE" ]]; then
  DB_PASS="$(grep '^DB_PASS=' "$ENV_FILE" | cut -d= -f2-)"
else
  DB_PASS="$(openssl rand -base64 24 | tr -d '/+=')"
  cat > "$ENV_FILE" <<EOF
DB_NAME=chatia
DB_USER=chatia
DB_PASS=$DB_PASS
OLLAMA_URL=http://127.0.0.1:11434
OLLAMA_MODEL=llama3.2:1b
EOF
fi
chown root:chatia "$ENV_FILE"
chmod 640 "$ENV_FILE"

# Equivalente a mysql_secure_installation + BD con privilegios mínimos
mariadb <<EOF
DELETE FROM mysql.global_priv WHERE User='';
DROP DATABASE IF EXISTS test;
CREATE DATABASE IF NOT EXISTS chatia CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'chatia'@'localhost' IDENTIFIED BY '$DB_PASS';
ALTER USER 'chatia'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT SELECT, INSERT, UPDATE, DELETE ON chatia.* TO 'chatia'@'localhost';
FLUSH PRIVILEGES;
EOF

echo "--- verificación ---"
mariadb -Nse "SELECT @@datadir, @@bind_address, VERSION();"
ss -tlnp | grep 3306
ls -ld "$DATADIR" "$ENV_FILE"
