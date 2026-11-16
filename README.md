# Chat con IA propia en servidor seguro — ISW-612, Trabajo 2

Opción A: una VM local con Ubuntu Server 24.04 en VirtualBox, Ollama, una app web en PHP con MariaDB y Nginx.
El diagrama de la arquitectura está en `docs/arquitectura.png` (fuente editable: `docs/arquitectura.svg`).

## Estructura del repositorio

| Ruta | Contenido |
|---|---|
| `scripts/` | Scripts Bash de instalación y verificación |
| `docs/arquitectura.png` / `.svg` | Diagrama de arquitectura |
| `docs/bitacora-ia.md` | Bitácora de uso de IA |
| `docs/evidencia/` | Salidas de los scripts y capturas de las pruebas |
| `docs/pruebas-seguridad.md` | Las 8 pruebas de seguridad con resultados |
| `docs/riesgos-11434.md` · `docs/decisiones-diseno.md` · `docs/puertos.md` | Investigación y tabla de puertos |
| `app/` | App web PHP (login, roles, chat, historial, panel) |
| `config/` | Configuración de Nginx, fail2ban y logrotate |
| `pruebas/` | Scripts de ataque para PowerShell (ráfaga 429 y fuerza bruta) |

## Datos de nuestra VM

| Elemento | Valor |
|---|---|
| VM | `ISW612-UBU-WM` (hostname `srv-archivos-mora`), Ubuntu Server 24.04.5 LTS, 4 GB RAM, 2 vCPU |
| Adaptador 1 (`enp0s3`) | Puente, sale a internet por la red local (VM reutilizada de los talleres) |
| Adaptador 2 (`enp0s8`) | Solo anfitrión, IP fija `192.168.56.10/24` |
| Disco del sistema | `sda`, 25 GB (LVM ampliado a 23 GB) |
| Disco del taller | `sdb`, 5 GB, montado en `/srv/compartido` (no se usa en este trabajo) |
| Disco de datos | `sdc` → `sdc1`, 20 GB, ext4, etiqueta `datos-ia`, montado por UUID en `/srv/ia` |
| Modelo inicial | `llama3.2:1b` (1,3 GB) |

---

## Despliegue

En una VM Ubuntu Server 24.04 con un disco de datos vacío de 20 GB y el adaptador Solo anfitrión:

```bash
git clone https://github.com/DeinerBS/Chat_IA_ISW612.git && cd Chat_IA_ISW612
sudo ./scripts/desplegar.sh /dev/sdc       # disco de datos; pide confirmar con SI y crear el admin
```

Antes del paso de seguridad, copiar la llave pública SSH a `~/.ssh/authorized_keys`: el script 07 desactiva las contraseñas solo si encuentra una llave.

| Script | Qué configura |
|---|---|
| `00-red-hostonly.sh` | IP fija `192.168.56.10/24` en `enp0s8` |
| `01-disco-datos.sh` | Disco de datos ext4 montado por UUID en `/srv/ia` |
| `02-ollama.sh` | Ollama solo en `127.0.0.1:11434`, modelos en `/srv/ia/ollama/models` |
| `03-mariadb.sh` | MariaDB con datadir en `/srv/ia/mariadb`, BD y usuario `chatia` |
| `04-php-fpm.sh` | Pool PHP-FPM `chatia` con usuario propio |
| `05-nginx.sh` | Nginx HTTPS (autofirmado), cabeceras y rate limiting |
| `06-app.sh` | Código de la app, tablas y primer administrador |
| `07-seguridad.sh` | ufw, sin Samba, SSH solo con llaves, fail2ban, logrotate |
| `respaldo.sh` / `restaurar.sh` | Respaldo de BD y configuraciones en `/srv/ia/respaldos` y su restauración |
| `comparar-modelos.py` | Mide 3 modelos y genera `docs/evidencia/comparacion-modelos.md` |
| `verificar-avance.sh` | Junta la evidencia del estado del servidor |

Uso: `https://192.168.56.10` (aceptar la advertencia del certificado autofirmado).

## Pruebas de seguridad

Desde Windows, con nmap instalado (`winget install Insecure.Nmap`):

```powershell
nmap -sS -sV -p- -T4 192.168.56.10
powershell -ExecutionPolicy Bypass -File .\pruebas\rafaga-429.ps1
powershell -ExecutionPolicy Bypass -File .\pruebas\fuerza-bruta-login.ps1 -Usuario empleado2
```

Resultados en `docs/pruebas-seguridad.md`.

## Problemas que tuvimos

| Problema | Causa | Solución |
|---|---|---|
| fail2ban no contaba los intentos SSH | En Ubuntu 24.04 el servicio es `ssh.service`, no `sshd.service` | `journalmatch` en `config/fail2ban/jail.local` |
| El bloqueo temporal del login no funcionaba | PHP en UTC comparaba fechas en hora local de MariaDB | Comparación en SQL + `date.timezone` en el pool |
| El 429 llegaba antes que el bloqueo de la app | Cada intento contaba el POST y el GET de la redirección | `map` para que la zona `login` cuente solo POST |
| El modelo se negaba a dar consejos de contraseñas | La instrucción de sistema mencionaba "contraseñas" como algo prohibido | Se reescribió la regla en `app/src/ollama.php` |
| `/srv/ia` no se montó en un arranque | udev no registró el sistema de archivos | `udevadm trigger` + `mount -a` |
| `ssh` daba *timeout* | ufw del taller solo permitía 22 desde 192.168.50.0/24 | Regla para 192.168.56.0/24 |
| Poco espacio en `/` | LVM a la mitad del disco | `lvextend -r -l +100%FREE` |
| Samba del taller expuesto (139, 445) | VM reutilizada | Servicio desactivado y regla de ufw borrada |
