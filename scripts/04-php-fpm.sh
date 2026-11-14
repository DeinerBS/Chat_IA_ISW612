#!/usr/bin/env bash
# PHP-FPM con un pool propio (usuario chatia) y despliegue del código de app/.
# Uso: sudo ./04-php-fpm.sh   (desde la raíz del repo)
set -euo pipefail

PHPV="8.3"
APP_DIR="/var/www/chatia"
REPO_APP="$(cd "$(dirname "$0")/.." && pwd)/app"

[[ $EUID -eq 0 ]] || { echo "Ejecutar con sudo"; exit 1; }
id chatia >/dev/null 2>&1 || { echo "Falta el usuario chatia: corra 03-mariadb.sh"; exit 1; }
[[ -d "$REPO_APP" ]] || { echo "No se encontró $REPO_APP"; exit 1; }

apt-get install -y "php$PHPV-fpm" "php$PHPV-mysql" "php$PHPV-curl" "php$PHPV-mbstring"

# Carpetas de la app: logs y sesiones solo para chatia
install -d -o chatia -g chatia -m 750 /var/log/chatia
install -d -o chatia -g chatia -m 700 /var/lib/chatia /var/lib/chatia/sessions

# Pool dedicado: corre como chatia, socket accesible solo para Nginx (www-data)
cat > "/etc/php/$PHPV/fpm/pool.d/chatia.conf" <<EOF
[chatia]
user = chatia
group = chatia
listen = /run/php/chatia.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

pm = ondemand
pm.max_children = 5
pm.process_idle_timeout = 30s
request_terminate_timeout = 120s

php_admin_value[date.timezone] = America/Costa_Rica
php_admin_flag[log_errors] = on
php_admin_flag[display_errors] = off
php_admin_value[error_log] = /var/log/chatia/php-error.log
php_admin_flag[file_uploads] = off
php_admin_value[post_max_size] = 16K
php_admin_value[max_execution_time] = 120
php_admin_value[open_basedir] = $APP_DIR:/etc/chatia:/var/lib/chatia:/var/log/chatia:/tmp
php_admin_value[disable_functions] = exec,passthru,shell_exec,system,proc_open,popen
php_admin_value[session.save_path] = /var/lib/chatia/sessions
php_admin_value[session.gc_maxlifetime] = 1800
php_admin_flag[session.use_strict_mode] = on
php_admin_flag[session.cookie_httponly] = on
php_admin_flag[session.cookie_secure] = on
php_admin_value[session.cookie_samesite] = Strict
EOF

# Se deshabilita el pool por defecto (www-data)
[[ -f "/etc/php/$PHPV/fpm/pool.d/www.conf" ]] && mv "/etc/php/$PHPV/fpm/pool.d/www.conf" "/etc/php/$PHPV/fpm/pool.d/www.conf.disabled"

# No anunciar la versión de PHP
sed -i 's/^expose_php = On/expose_php = Off/' "/etc/php/$PHPV/fpm/php.ini"

# Código: dueño root, solo lectura para chatia (750/640). Nginx no lo lee
install -d -o root -g chatia -m 750 "$APP_DIR"
cp -r "$REPO_APP/." "$APP_DIR/"
chown -R root:chatia "$APP_DIR"
find "$APP_DIR" -type d -exec chmod 750 {} +
find "$APP_DIR" -type f -exec chmod 640 {} +

systemctl enable "php$PHPV-fpm"
systemctl restart "php$PHPV-fpm"

echo "--- verificación ---"
systemctl is-active "php$PHPV-fpm"
ls -l /run/php/chatia.sock
ps -o user,pid,cmd -C "php-fpm$PHPV"
ls -ld "$APP_DIR" /var/log/chatia /var/lib/chatia/sessions
