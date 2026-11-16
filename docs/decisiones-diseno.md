# Decisiones de diseño

| Decisión | Alternativas consideradas | Por qué |
|---|---|---|
| **VM local en VirtualBox** (Opción A) | Servidor en la nube | Sin costo, sin exponer nada a internet y reproducible en el equipo de la pareja |
| **Red: adaptador puente/NAT + Solo anfitrión con IP fija** (`192.168.56.10`) | Solo NAT con reenvío de puertos | El anfitrión llega a la VM igual en la U o en la casa; nmap y las pruebas "desde otra máquina" tienen sentido |
| **Disco de datos aparte montado por UUID** | Todo en el disco del sistema | Separa sistema y datos (modelos, BD, respaldos); el UUID no cambia si cambia el orden de los discos; `nofail` evita que la VM no arranque si falta |
| **PHP 8.3 sin framework + PHP-FPM con pool propio** | Laravel, Python/Flask, Node | Ya conocíamos PHP (ISW-613); sin framework el código es corto y se puede explicar completo en la defensa; el pool corre como `chatia` sin shell |
| **MariaDB** | SQLite, PostgreSQL | Es el motor que usamos en el curso; usuario de la app con solo SELECT/INSERT/UPDATE/DELETE; datadir en el disco de datos; solo localhost y socket unix |
| **Nginx como proxy inverso** | Apache | Rate limiting nativo (`limit_req`), cabeceras y TLS en un solo lugar; no lee archivos de la app (todo pasa al socket de PHP-FPM) |
| **Certificado autofirmado** | Let's Encrypt | Let's Encrypt necesita un dominio público y la VM está en una red privada; el autofirmado da el mismo cifrado. Desventaja: el navegador muestra advertencia y no autentica al servidor |
| **Formularios HTML sin JavaScript** | Chat con fetch/JS | La CSP queda sin excepciones para scripts y se elimina una superficie de XSS; la respuesta tarda unos segundos, aceptable para uso interno |
| **bcrypt (`password_hash`)** | SHA-256, MD5 | Función lenta y con sal, diseñada para contraseñas |
| **Bloqueo por usuario (5 intentos) + por IP (20) + Nginx** | Solo una capa | Defensa en profundidad: la app protege cada cuenta y Nginx corta antes de llegar a PHP |
| **Contexto por `usuario_id`** | Historial global | Un usuario no puede obtener mensajes de otro, aunque engañe al modelo |
| **Modelo pequeño en CPU (1B–1.5B)** | Modelos de 7B+ | La VM tiene ~4 GB de RAM y sin GPU; ver `docs/evidencia/comparacion-modelos.md` |
| **Scripts Bash numerados** | Ansible | Más fácil de leer y defender; `desplegar.sh` los corre en orden |
