<?php
// Sesiones, CSRF, login con bloqueo por intentos y control de roles
declare(strict_types=1);

function iniciar_sesion(): void
{
    session_name('CHATIA');
    session_start();

    $ahora = time();
    if (isset($_SESSION['usuario_id'])) {
        // Expiración por inactividad o por duración total
        $inactiva = $ahora - ($_SESSION['ultima_actividad'] ?? 0) > SESION_INACTIVA;
        $vencida  = $ahora - ($_SESSION['inicio'] ?? 0) > SESION_MAXIMA;
        if ($inactiva || $vencida) {
            app_log('SESION_EXPIRADA', $_SESSION['usuario'] ?? '-');
            cerrar_sesion();
            session_start();
            flash('Tu sesión expiró. Ingresa de nuevo.');
        } else {
            $_SESSION['ultima_actividad'] = $ahora;
        }
    }
    if (empty($_SESSION['csrf'])) {
        $_SESSION['csrf'] = bin2hex(random_bytes(32));
    }
}

function cerrar_sesion(): void
{
    $_SESSION = [];
    session_destroy();
}

// Usuario actual, revalidado contra la BD en cada petición (bloqueo inmediato)
function usuario_actual(): ?array
{
    static $usuario = false;
    if ($usuario !== false) {
        return $usuario;
    }
    $usuario = null;
    if (isset($_SESSION['usuario_id'])) {
        $st = db()->prepare('SELECT id, usuario, nombre, rol, bloqueado FROM usuarios WHERE id = ?');
        $st->execute([$_SESSION['usuario_id']]);
        $fila = $st->fetch();
        if ($fila && !$fila['bloqueado']) {
            $usuario = $fila;
        } else {
            app_log('SESION_CERRADA_BLOQUEO', $_SESSION['usuario'] ?? '-');
            cerrar_sesion();
            session_start();
            $_SESSION['csrf'] = bin2hex(random_bytes(32));
        }
    }
    return $usuario;
}

function requiere_login(): array
{
    $u = usuario_actual();
    if ($u === null) {
        redirigir('/login');
    }
    return $u;
}

function requiere_admin(): array
{
    $u = requiere_login();
    if ($u['rol'] !== 'admin') {
        app_log('ACCESO_DENEGADO', $u['usuario'], 'ruta=' . ($_SERVER['REQUEST_URI'] ?? ''));
        http_response_code(403);
        render('Acceso denegado', '<h1>403</h1><p>No tienes permiso para ver esta página.</p>');
        exit;
    }
    return $u;
}

function csrf_campo(): string
{
    return '<input type="hidden" name="csrf" value="' . e($_SESSION['csrf']) . '">';
}

function verificar_csrf(): void
{
    if (!hash_equals($_SESSION['csrf'] ?? '', $_POST['csrf'] ?? '')) {
        app_log('CSRF_INVALIDO', $_SESSION['usuario'] ?? '-');
        http_response_code(400);
        exit('Solicitud inválida.');
    }
}

// Devuelve null si entra, o el mensaje de error a mostrar
function intentar_login(string $usuario, string $clave): ?string
{
    $pdo = db();
    $ip  = ip_cliente();
    $generico = 'Usuario o contraseña incorrectos.';

    // Límite por IP (varios usuarios desde la misma máquina)
    $st = $pdo->prepare('SELECT COUNT(*) FROM eventos_login WHERE ip = ? AND exito = 0 AND creado_en > NOW() - INTERVAL ? MINUTE');
    $st->execute([$ip, MINUTOS_BLOQUEO]);
    if ((int)$st->fetchColumn() >= MAX_FALLOS_IP) {
        app_log('LOGIN_BLOQUEADO_IP', $usuario);
        return 'Demasiados intentos desde tu equipo. Intenta más tarde.';
    }

    // La comparación de fechas se hace en MariaDB (misma zona horaria que bloqueado_hasta)
    $st = $pdo->prepare('SELECT *, (bloqueado_hasta IS NOT NULL AND bloqueado_hasta > NOW()) AS bloqueo_activo FROM usuarios WHERE usuario = ?');
    $st->execute([$usuario]);
    $u = $st->fetch();

    if ($u && $u['bloqueo_activo']) {
        registrar_intento($usuario, false);
        app_log('LOGIN_BLOQUEADO_TEMPORAL', $usuario);
        return 'Cuenta bloqueada temporalmente por intentos fallidos. Intenta en ' . MINUTOS_BLOQUEO . ' minutos.';
    }

    // password_verify también se ejecuta si el usuario no existe (mismo tiempo de respuesta)
    $hash = $u['hash'] ?? '$2y$10$usuarioinexistenteXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX';
    if (!$u || !password_verify($clave, $hash)) {
        registrar_intento($usuario, false);
        app_log('LOGIN_FALLIDO', $usuario);
        if ($u) {
            $fallos = $u['intentos_fallidos'] + 1;
            if ($fallos >= MAX_INTENTOS) {
                $pdo->prepare('UPDATE usuarios SET intentos_fallidos = 0, bloqueado_hasta = NOW() + INTERVAL ? MINUTE WHERE id = ?')
                    ->execute([MINUTOS_BLOQUEO, $u['id']]);
                app_log('USUARIO_BLOQUEADO_TEMPORAL', $usuario, "intentos=$fallos");
            } else {
                $pdo->prepare('UPDATE usuarios SET intentos_fallidos = ? WHERE id = ?')->execute([$fallos, $u['id']]);
            }
        }
        return $generico;
    }

    if ($u['bloqueado']) {
        registrar_intento($usuario, false);
        app_log('LOGIN_USUARIO_BLOQUEADO', $usuario);
        return 'Tu cuenta está bloqueada. Contacta al administrador.';
    }

    // Login correcto: id de sesión nuevo (evita fijación de sesión)
    session_regenerate_id(true);
    $_SESSION['usuario_id']       = (int)$u['id'];
    $_SESSION['usuario']          = $u['usuario'];
    $_SESSION['inicio']           = time();
    $_SESSION['ultima_actividad'] = time();
    $_SESSION['csrf']             = bin2hex(random_bytes(32));

    $pdo->prepare('UPDATE usuarios SET intentos_fallidos = 0, bloqueado_hasta = NULL, ultimo_acceso = NOW() WHERE id = ?')
        ->execute([$u['id']]);
    registrar_intento($usuario, true);
    app_log('LOGIN_OK', $usuario);
    return null;
}

function registrar_intento(string $usuario, bool $exito): void
{
    db()->prepare('INSERT INTO eventos_login (usuario, ip, exito) VALUES (?, ?, ?)')
        ->execute([mb_substr($usuario, 0, 40), ip_cliente(), $exito ? 1 : 0]);
}
