# Riesgos de exponer el puerto 11434 de Ollama sin autenticación

## El problema

La API de Ollama (puerto 11434) **no tiene autenticación**: quien llega al puerto puede usar todas sus funciones. Por defecto escucha solo en `127.0.0.1`, pero basta con poner `OLLAMA_HOST=0.0.0.0` (algo común para "probar desde otra máquina" o en contenedores) para que quede abierta a toda la red.

No es un riesgo teórico:

- En febrero de 2026, LeakIX reportó **12 269 instancias de Ollama expuestas en internet sin autenticación**; unas 1 000 corrían versiones vulnerables y, como suelen desplegarse con Docker por defecto, el proceso corre como root.
- SentinelLABS y Censys analizaron 293 días de escaneos y encontraron **unas 175 000 instancias en 130 países**; a mediados de 2024 eran cerca de 1 000.
- Hay operadores que buscan instancias abiertas de forma automática y las suman a un "pool" de cómputo que revenden.

## Qué puede hacer un atacante con el puerto abierto

| Riesgo | Endpoint de la API | Impacto |
|---|---|---|
| Uso no autorizado del cómputo | `/api/generate`, `/api/chat` | Consume CPU/RAM del servidor (denegación de servicio para los usuarios reales) o lo usa para sus propios fines |
| Saltarse todos los controles de la app | Cualquiera | Sin login, sin roles, sin filtro de inyección, sin límite de tamaño, sin registro en los logs de la app |
| Robo de modelos | `/api/tags`, `/api/show`, `/api/pull`… | Listar y copiar modelos, incluidos los ajustados con datos propios |
| Sabotaje | `/api/delete`, `/api/create` | Borrar o reemplazar el modelo que usa la empresa |
| Llenar el disco | `/api/pull` | Descargar modelos grandes hasta agotar `/srv/ia` y tumbar MariaDB y los respaldos, que comparten el disco |
| Explotar vulnerabilidades | Varios | Versiones viejas con fallos conocidos; el riesgo crece si Ollama corre como root |

## Mitigaciones aplicadas en este proyecto

| Capa | Medida | Cómo se verifica |
|---|---|---|
| Escucha | `OLLAMA_HOST=127.0.0.1:11434` en el override de systemd | `ss -tlnp \| grep 11434` → `127.0.0.1:11434` |
| Firewall | ufw con entrada denegada por defecto; solo 22, 80 y 443 | nmap desde el anfitrión: 11434 no aparece |
| Único cliente | Solo la app PHP habla con Ollama, después de login, roles, filtro y límites | `curl` desde el anfitrión al 11434 → timeout |
| Privilegios | Ollama corre como el usuario de sistema `ollama`, no como root | `ps -o user -C ollama` |
| Disco | Modelos en `/srv/ia/ollama/models` con dueño `ollama` y permisos 750 | `ls -ld /srv/ia/ollama` |
| Sin CORS abierto | No se usa `OLLAMA_ORIGINS=*` | `systemctl cat ollama` |
| Actualización | Reinstalar con el instalador oficial actualiza Ollama | `ollama --version` |

## Riesgo residual

Cualquier proceso **dentro de la VM** puede llamar a `127.0.0.1:11434`. Se acepta porque la VM tiene un solo usuario administrador con acceso por llave SSH, sin root remoto y con fail2ban. Si hubiera más usuarios locales, se podría restringir con nftables por usuario dueño del proceso (`meta skuid`) o poner Ollama detrás de un proxy con autenticación.

## Fuentes

- LeakIX, *12,000 Ollama Instances Exposed* (feb. 2026): https://blog.leakix.net/2026/02/ollama-exposed/
- Hacking Passion, resumen del estudio de SentinelLABS y Censys: https://hackingpassion.com/ollama-175000-servers-exposed
- Tianpan, reventa del cómputo de instancias expuestas: https://tianpan.co/forum/t/175-000-ollama-servers-are-exposed-to-the-public-internet-attackers-are-reselling-your-gpu-compute/618
- UpGuard, *Understanding and Securing Exposed Ollama Instances*: https://www.upguard.com/blog/understanding-and-securing-exposed-ollama-instances
- Cisco, *Detecting Exposed LLM Servers: Shodan Case Study on Ollama*: https://blogs.cisco.com/security/detecting-exposed-llm-servers-shodan-case-study-on-ollama
