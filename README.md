# Chat con IA propia en servidor seguro — ISW-612, Trabajo 2

Opción A: una VM local con Ubuntu Server 24.04 en VirtualBox, Ollama, una app web en PHP con MariaDB y Nginx.
El diagrama de la arquitectura está en `docs/arquitectura.png` (fuente editable: `docs/arquitectura.svg`).

## Estructura del repositorio

| Ruta | Contenido |
|---|---|
| `scripts/` | Scripts Bash de instalación y verificación |
| `docs/arquitectura.png` / `.svg` | Diagrama de arquitectura |
| `docs/bitacora-ia.md` | Bitácora de uso de IA |
| `docs/evidencia/` | Salidas de los scripts de verificación |

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

## Instalación paso a paso

### 1. VirtualBox (con la VM apagada)

- **Sistema:** 4 GB de RAM como mínimo, de 2 a 4 CPU.
- **Red → Adaptador 1:** NAT o puente; es la salida a internet (apt y descarga de modelos).
- **Red → Adaptador 2:** *Habilitar* → **Adaptador solo anfitrión** → `VirtualBox Host-Only Ethernet Adapter` (red `192.168.56.0/24`).
- **Almacenamiento → Controlador SATA → Agregar disco duro → Crear:** VDI, reserva dinámica, 20 GB, nombre `ia-datos`.

### 2. IP fija del adaptador host-only (en la consola de la VM)

```bash
ip -br link                                   # nombre del 2.º adaptador: enp0s8
sudo nano /etc/netplan/60-hostonly.yaml
```
```yaml
network:
  version: 2
  ethernets:
    enp0s8:
      dhcp4: false
      addresses: [192.168.56.10/24]
```
```bash
sudo chmod 600 /etc/netplan/60-hostonly.yaml
sudo netplan apply
ip -br addr                                   # enp0s8 → 192.168.56.10/24
```
También se puede hacer con `sudo ./scripts/00-red-hostonly.sh enp0s8 192.168.56.10/24`.

### 3. SSH desde el anfitrión

```bash
sudo apt update && sudo apt install -y openssh-server unzip
sudo systemctl enable --now ssh
sudo ufw allow from 192.168.56.0/24 to any port 22 proto tcp comment 'SSH host-only'
```
Desde Windows: `ssh warner@192.168.56.10`. Para copiar los archivos del repo a la VM: `scp` o `git clone`.

### 4. Disco de datos

```bash
chmod +x scripts/*.sh
lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS           # el de 20G sin particiones: sdc
sudo ./scripts/01-disco-datos.sh /dev/sdc     # pide escribir SI (mayúscula)
grep /srv/ia /etc/fstab
```

### 5. Ampliar el disco del sistema (LVM)

El instalador de Ubuntu dejó `/` con 11,5 GB de 23 GB. Se amplía antes de instalar Ollama:
```bash
sudo lvextend -r -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
df -h /
```

### 6. Ollama

```bash
sudo ./scripts/02-ollama.sh llama3.2:1b
```

### 7. Verificación

```bash
sudo reboot
sudo ./scripts/verificar-avance.sh llama3.2:1b   # genera evidencia-avance-*.txt
```
Desde Windows debe **fallar**:
```powershell
curl.exe -m 5 http://192.168.56.10:11434
```

---

## Qué hace cada script

| Script | Qué configura | Detalle para la defensa |
|---|---|---|
| `00-red-hostonly.sh` | IP fija en el 2.º adaptador (netplan) | Sin gateway: la salida a internet es por el adaptador 1 |
| `01-disco-datos.sh` | GPT → 1 partición → ext4 → `/srv/ia` en fstab por **UUID** | `/dev/sdc1` puede cambiar de nombre y el UUID no. `nofail` evita que la VM se quede trabada al arrancar si falta el disco |
| `02-ollama.sh` | Instalador oficial + override de systemd | `OLLAMA_HOST=127.0.0.1:11434` (no se expone), `OLLAMA_MODELS=/srv/ia/ollama/models` (modelos en el disco de datos), `RequiresMountsFor=/srv/ia` (espera al montaje) |
| `verificar-avance.sh` | Solo lee el estado y guarda la evidencia | — |

El override queda en `/etc/systemd/system/ollama.service.d/override.conf` (`systemctl cat ollama`).

## Problemas que tuvimos

| Problema | Causa | Solución |
|---|---|---|
| `netplan apply` dejó una IP equivocada | Error al escribir la IP (`192.186`) | `sed -i 's/192.186/192.168/'`, `ip addr flush dev enp0s8`, `netplan apply` |
| `cat` del netplan: *Permission denied* | El archivo quedó con permisos 600 (solo root) | `sudo cat` |
| `ssh`: *Connection timed out* con ping funcionando | ufw solo permitía el 22 desde `192.168.50.0/24` | Regla para `192.168.56.0/24` |
| Poco espacio en `/` (5,6 GB libres) | LVM usaba la mitad de `sda3` | `lvextend -r -l +100%FREE` |
| `apt update` sin conexión a `archive.ubuntu.com` | Falla del mirror o de la red | No afectó, los paquetes ya estaban instalados |

## Pendiente para la entrega final

- Quitar la regla de ufw del puerto 445 (SMB del taller): desde fuera solo deben verse 22, 80 y 443.
- MariaDB con su datadir en `/srv/ia/mariadb`, la app PHP, Nginx con HTTPS, fail2ban y respaldos.
