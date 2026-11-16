\# Tabla de puertos



Verificado con `sudo ss -tlnp` y `sudo ufw status` el 9 nov 2026.



| Puerto | Servicio | Escucha en | Regla ufw | Expuesto fuera de la VM | Estado |

|---|---|---|---|---|---|

| 22/tcp | OpenSSH (`sshd`) | 0.0.0.0 y \[::] | ALLOW desde 192.168.50.0/24 y 192.168.56.0/24 | Sí, solo desde esas dos redes | Configurado |

| 80/tcp | Nginx (redirige a 443) | — | — | Sí | Pendiente |

| 443/tcp | Nginx HTTPS | — | — | Sí | Pendiente |

| 11434/tcp | Ollama | 127.0.0.1 | Ninguna | No | Configurado |

| 3306/tcp | MariaDB | — | Ninguna | No (solo 127.0.0.1) | Pendiente |

| 53/tcp | systemd-resolved (DNS local) | 127.0.0.53 / 127.0.0.54 | Ninguna | No | Propio de Ubuntu |

| 445/tcp | Samba (`smbd`, del taller) | 0.0.0.0 y \[::] | ALLOW desde 192.168.50.0/24 | Sí, desde la red local | Por eliminar |

| 139/tcp | Samba (`smbd`, del taller) | 0.0.0.0 y \[::] | Ninguna (bloqueado por ufw) | No | Por eliminar |



Para la entrega final, desde fuera solo deben verse 22, 80 y 443: hay que quitar la regla del 445 y detener Samba (`smbd`).

