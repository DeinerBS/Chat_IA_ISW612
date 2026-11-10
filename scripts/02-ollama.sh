#!/usr/bin/env bash
# Instala Ollama como servicio, solo en 127.0.0.1, con los modelos en /srv/ia.
# Uso: sudo ./02-ollama.sh [modelo]
set -euo pipefail

MODELO="${1:-llama3.2:1b}"
DIR_MODELOS="/srv/ia/ollama/models"

[[ $EUID -eq 0 ]] || { echo "Ejecutar con sudo"; exit 1; }
mountpoint -q /srv/ia || { echo "/srv/ia no está montado: corra 01-disco-datos.sh"; exit 1; }

# zstd: el instalador actual descarga un .tar.zst
apt-get update
apt-get install -y curl ca-certificates zstd

# Instalador oficial: crea el usuario 'ollama' y el servicio systemd
curl -fsSL https://ollama.com/install.sh -o /tmp/ollama-install.sh
sh /tmp/ollama-install.sh
rm -f /tmp/ollama-install.sh

install -d -o ollama -g ollama -m 750 /srv/ia/ollama "$DIR_MODELOS"

# Override: solo localhost, modelos en el disco de datos, esperar al montaje
install -d /etc/systemd/system/ollama.service.d
cat > /etc/systemd/system/ollama.service.d/override.conf <<EOF
[Unit]
RequiresMountsFor=/srv/ia

[Service]
Environment="OLLAMA_HOST=127.0.0.1:11434"
Environment="OLLAMA_MODELS=$DIR_MODELOS"
EOF

systemctl daemon-reload
systemctl enable ollama
systemctl restart ollama

# Esperar a que la API responda
for _ in $(seq 1 30); do
  curl -fs http://127.0.0.1:11434/api/version >/dev/null && break
  sleep 1
done

ollama pull "$MODELO"
ollama list
du -sh "$DIR_MODELOS"
