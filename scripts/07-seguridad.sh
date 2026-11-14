#!/usr/bin/env bash
# Endurecimiento: ufw mínimo, sin Samba, SSH solo con llaves, fail2ban y rotación de logs.
# Uso: sudo ./07-seguridad.sh [usuario_ssh]
set -euo pipefail

USUARIO="${1:-${SUDO_USER:-warner}}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"

[[ $EUID -eq 0 ]] || { echo "Ejecutar con sudo"; exit 1; }

# --- 1. Samba del taller: fuera ---
systemctl disable --now smbd nmbd 2>/dev/null || true

# --- 2. ufw: entrada denegada, solo 22 (redes conocidas), 80 y 443 ---
# Borrar por número todas las reglas del 445 (de abajo hacia arriba)
for n in $(ufw status numbered | grep -E '\b445(/tcp)?\b' | grep -oE '^\[ *[0-9]+' | tr -dc '0-9\n' | sort -rn); do
  ufw --force delete "$n"
done
ufw default deny incoming
ufw default allow outgoing
ufw allow from 192.168.56.0/24 to any port 22 proto tcp comment 'SSH host-only'
ufw allow 80/tcp comment 'HTTP (redirige a 443)'
ufw allow 443/tcp comment 'HTTPS chatia'
ufw logging low
ufw --force enable

# --- 3. SSH: sin root; contraseñas desactivadas solo si ya hay una llave ---
LLAVES="$(getent passwd "$USUARIO" | cut -d: -f6)/.ssh/authorized_keys"
if [[ -s "$LLAVES" ]]; then
  PASS="no"
else
  PASS="yes"
  echo "AVISO: $LLAVES no existe; se mantiene el acceso con contraseña."
fi
# 10- se lee antes que 50-cloud-init.conf: en sshd gana el primer valor
cat > /etc/ssh/sshd_config.d/10-chatia.conf <<EOF
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication $PASS
KbdInteractiveAuthentication no
MaxAuthTries 3
LoginGraceTime 30
EOF
sshd -t
systemctl restart ssh

# --- 4. fail2ban: SSH y logins fallidos de la app ---
apt-get install -y fail2ban
install -m 644 "$REPO/config/fail2ban/chatia-login.conf" /etc/fail2ban/filter.d/chatia-login.conf
install -m 644 "$REPO/config/fail2ban/jail.local" /etc/fail2ban/jail.local
systemctl enable fail2ban
systemctl restart fail2ban

# --- 5. Rotación de los logs de la app (Nginx ya trae la suya) ---
install -m 644 "$REPO/config/logrotate/chatia" /etc/logrotate.d/chatia
logrotate -d /etc/logrotate.d/chatia 2>&1 | grep -q "error" && echo "Revisar logrotate" || true

echo "--- verificación ---"
ufw status verbose
systemctl is-active smbd 2>/dev/null || echo "smbd: inactivo"
sshd -T | grep -E '^(permitrootlogin|passwordauthentication|pubkeyauthentication|maxauthtries) '
sleep 2
fail2ban-client status
ss -tlnp | awk 'NR==1 || /LISTEN/'
