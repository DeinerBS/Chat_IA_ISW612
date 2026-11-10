#!/usr/bin/env bash
# Junta la evidencia de la revisión de avance en un archivo de texto.
# Uso: sudo ./verificar-avance.sh [modelo]
set -uo pipefail

MODELO="${1:-llama3.2:1b}"
SALIDA="evidencia-avance-$(date +%Y%m%d-%H%M).txt"

seccion() { echo; echo "===== $1 ====="; }

{
  seccion "Sistema"
  hostnamectl | grep -E "Operating|Kernel|Virtualization"
  free -h | head -2; nproc

  seccion "Red (NAT + Solo anfitrión)"
  ip -br addr

  seccion "Disco de datos"
  lsblk -f
  findmnt /srv/ia
  grep /srv/ia /etc/fstab
  df -h /srv/ia
  ls -ld /srv/ia /srv/ia/*

  seccion "Servicio Ollama"
  systemctl is-enabled ollama; systemctl is-active ollama
  systemctl cat ollama | grep -E "OLLAMA_|RequiresMounts"
  ps -o user,pid,cmd -C ollama

  seccion "Puerto 11434 (debe ser solo 127.0.0.1)"
  ss -tlnp | grep 11434

  seccion "Modelos en /srv/ia"
  ollama list
  du -sh /srv/ia/ollama/models

  seccion "Prueba de la API en localhost"
  curl -s http://127.0.0.1:11434/api/generate \
    -d "{\"model\":\"$MODELO\",\"prompt\":\"Responde en una oración: ¿qué es un proxy inverso?\",\"stream\":false}" \
    | grep -o '"response":"[^"]*"'

  seccion "Prueba por la IP host-only (debe fallar)"
  IP_HO="$(ip -4 -br addr show enp0s8 2>/dev/null | awk '{print $3}' | cut -d/ -f1)"
  if [[ -n "$IP_HO" ]]; then
    curl -s -m 3 "http://$IP_HO:11434/api/version" && echo "ATENCIÓN: responde" || echo "OK: no responde en $IP_HO:11434"
  fi
} 2>&1 | tee "$SALIDA"

echo; echo "Evidencia guardada en $SALIDA"
