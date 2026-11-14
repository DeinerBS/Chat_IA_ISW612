<?php
// Una función por ruta
declare(strict_types=1);

// ---------- Login ----------

function pagina_login(): void
{
    if (usuario_actual()) {
        redirigir('/');
    }
    render('Ingresar', '
<div class="caja" style="max-width:380px;margin:40px auto">
  <h1>Ingresar</h1>
  <form method="post" action="/login">' . csrf_campo() . '
    <label>Usuario <input name="usuario" required maxlength="40" autocomplete="username"></label><br><br>
    <label>Contraseña <input type="password" name="clave" required maxlength="200" autocomplete="current-password"></label>
    <button class="principal">Entrar</button>
  </form>
</div>');
}

function procesar_login(): void
{
    $usuario = trim((string)($_POST['usuario'] ?? ''));
    $clave   = (string)($_POST['clave'] ?? '');
    $error = intentar_login(mb_substr($usuario, 0, 40), $clave);
    if ($error !== null) {
        flash($error, 'error');
        redirigir('/login');
    }
    redirigir('/');
}

function procesar_logout(): void
{
    app_log('LOGOUT', $_SESSION['usuario'] ?? '-');
    cerrar_sesion();
    redirigir('/login');
}

// ---------- Chat ----------

function pagina_chat(): void
{
    $u = requiere_login();
    $st = db()->prepare('SELECT * FROM (SELECT rol, contenido, creado_en, duracion_ms, id FROM mensajes WHERE usuario_id = ? ORDER BY id DESC LIMIT 50) t ORDER BY id');
    $st->execute([$u['id']]);

    $html = '<div class="caja"><h1>Chat</h1>';
    $mensajes = $st->fetchAll();
    if (!$mensajes) {
        $html .= '<p class="meta">Todavía no hay mensajes. Escribe tu primera pregunta.</p>';
    }
    foreach ($mensajes as $m) {
        $meta = e($m['creado_en']) . ($m['duracion_ms'] ? ' · ' . round($m['duracion_ms'] / 1000, 1) . ' s' : '');
        $html .= '<div class="msg ' . e($m['rol']) . '">' . e($m['contenido']) . '<div class="meta">' . $meta . '</div></div>';
    }
    $html .= '</div>
<div class="caja">
  <form method="post" action="/api/chat">' . csrf_campo() . '
    <textarea name="mensaje" rows="3" maxlength="' . MAX_MENSAJE . '" required placeholder="Escribe tu pregunta (máximo ' . MAX_MENSAJE . ' caracteres)"></textarea>
    <button class="principal">Enviar</button>
    <span class="meta">La respuesta puede tardar unos segundos.</span>
  </form>
  <form method="post" action="/historial/borrar" style="margin-top:10px">' . csrf_campo() . '
    <button>Borrar mi historial</button>
  </form>
</div>';
    render('Chat', $html);
}

function enviar_mensaje(): void
{
    $u = requiere_login();
    $mensaje = limpiar_mensaje((string)($_POST['mensaje'] ?? ''));

    if ($mensaje === '') {
        flash('El mensaje está vacío.', 'error');
        redirigir('/');
    }
    if (mb_strlen($mensaje) > MAX_MENSAJE) {
        app_log('MENSAJE_LARGO', $u['usuario'], 'largo=' . mb_strlen($mensaje));
        flash('El mensaje supera los ' . MAX_MENSAJE . ' caracteres.', 'error');
        redirigir('/');
    }
    if ($patron = detectar_inyeccion($mensaje)) {
        app_log('POSIBLE_INYECCION', $u['usuario'], 'patron="' . $patron . '"');
        flash('Tu mensaje fue bloqueado por el filtro de seguridad.', 'error');
        redirigir('/');
    }

    $pdo = db();
    $pdo->prepare('INSERT INTO mensajes (usuario_id, rol, contenido) VALUES (?, ?, ?)')->execute([$u['id'], 'user', $mensaje]);

    // Contexto: solo los últimos mensajes de este usuario
    $st = $pdo->prepare('SELECT * FROM (SELECT id, rol, contenido FROM mensajes WHERE usuario_id = ? ORDER BY id DESC LIMIT ' . CONTEXTO_MENSAJES . ') t ORDER BY id');
    $st->execute([$u['id']]);

    $inicio = microtime(true);
    $respuesta = consultar_ollama($st->fetchAll());
    $ms = (int)((microtime(true) - $inicio) * 1000);

    if ($respuesta === null) {
        app_log('OLLAMA_ERROR', $u['usuario']);
        flash('El asistente no respondió a tiempo. Intenta de nuevo.', 'error');
        redirigir('/');
    }
    $pdo->prepare('INSERT INTO mensajes (usuario_id, rol, contenido, duracion_ms) VALUES (?, ?, ?, ?)')
        ->execute([$u['id'], 'assistant', $respuesta, $ms]);
    app_log('CHAT', $u['usuario'], "ms=$ms");
    redirigir('/');
}

function borrar_historial(): void
{
    $u = requiere_login();
    db()->prepare('DELETE FROM mensajes WHERE usuario_id = ?')->execute([$u['id']]);
    app_log('HISTORIAL_BORRADO', $u['usuario']);
    flash('Historial borrado.', 'ok');
    redirigir('/');
}

// ---------- Administración (solo rol admin) ----------

function pagina_admin(): void
{
    $admin = requiere_admin();
    $filas = db()->query('
        SELECT u.id, u.usuario, u.nombre, u.rol, u.bloqueado, u.ultimo_acceso,
               (u.bloqueado_hasta IS NOT NULL AND u.bloqueado_hasta > NOW()) AS bloqueo_activo,
               COUNT(m.id) AS preguntas,
               SUM(m.creado_en >= CURDATE()) AS preguntas_hoy
        FROM usuarios u
        LEFT JOIN mensajes m ON m.usuario_id = u.id AND m.rol = \'user\'
        GROUP BY u.id ORDER BY u.usuario')->fetchAll();
    $fallos = (int)db()->query('SELECT COUNT(*) FROM eventos_login WHERE exito = 0 AND creado_en >= CURDATE()')->fetchColumn();

    $html = '<div class="caja"><h1>Panel de administración</h1>
<p>Logins fallidos hoy: <strong>' . $fallos . '</strong></p>
<table><tr><th>Usuario</th><th>Nombre</th><th>Rol</th><th>Preguntas (total / hoy)</th><th>Último acceso</th><th>Estado</th><th></th></tr>';
    foreach ($filas as $f) {
        $temporal = (bool)$f['bloqueo_activo'];
        $estado = $f['bloqueado'] ? '<span class="bloq">Bloqueado</span>' : ($temporal ? '<span class="bloq">Bloqueo temporal</span>' : 'Activo');
        $boton = '';
        if ((int)$f['id'] !== (int)$admin['id']) {   // el admin no se bloquea a sí mismo
            $accion = $f['bloqueado'] ? 'desbloquear' : 'bloquear';
            $boton = '<form method="post" action="/admin/bloqueo">' . csrf_campo() .
                '<input type="hidden" name="id" value="' . (int)$f['id'] . '"><input type="hidden" name="accion" value="' . $accion . '">' .
                '<button>' . ucfirst($accion) . '</button></form>';
        }
        $html .= '<tr><td>' . e($f['usuario']) . '</td><td>' . e($f['nombre']) . '</td><td>' . e($f['rol']) . '</td>' .
            '<td>' . (int)$f['preguntas'] . ' / ' . (int)$f['preguntas_hoy'] . '</td><td>' . e($f['ultimo_acceso'] ?? '—') . '</td>' .
            '<td>' . $estado . '</td><td>' . $boton . '</td></tr>';
    }
    $html .= '</table></div>
<div class="caja"><h2>Crear usuario</h2>
  <form method="post" action="/admin/usuarios">' . csrf_campo() . '
    <label>Usuario (3-40: letras minúsculas, números, punto, guion) <input name="usuario" required pattern="[a-z0-9._\-]{3,40}"></label><br><br>
    <label>Nombre <input name="nombre" required maxlength="100"></label><br><br>
    <label>Contraseña (mínimo 10 caracteres) <input type="password" name="clave" required minlength="10" autocomplete="new-password"></label><br><br>
    <label>Rol <select name="rol"><option value="usuario">usuario</option><option value="admin">admin</option></select></label>
    <button class="principal">Crear</button>
  </form>
</div>';
    render('Panel', $html);
}

function crear_usuario(): void
{
    $admin = requiere_admin();
    $usuario = trim((string)($_POST['usuario'] ?? ''));
    $nombre  = trim((string)($_POST['nombre'] ?? ''));
    $clave   = (string)($_POST['clave'] ?? '');
    $rol     = ($_POST['rol'] ?? '') === 'admin' ? 'admin' : 'usuario';

    if (!preg_match('/^[a-z0-9._-]{3,40}$/', $usuario) || $nombre === '' || mb_strlen($nombre) > 100 || strlen($clave) < 10) {
        flash('Datos inválidos: revise el usuario, el nombre y que la contraseña tenga al menos 10 caracteres.', 'error');
        redirigir('/admin');
    }
    try {
        db()->prepare('INSERT INTO usuarios (usuario, nombre, hash, rol) VALUES (?, ?, ?, ?)')
            ->execute([$usuario, $nombre, password_hash($clave, PASSWORD_BCRYPT), $rol]);
    } catch (PDOException $ex) {
        flash('Ese usuario ya existe.', 'error');
        redirigir('/admin');
    }
    app_log('USUARIO_CREADO', $admin['usuario'], "nuevo=$usuario rol=$rol");
    flash("Usuario $usuario creado.", 'ok');
    redirigir('/admin');
}

function cambiar_bloqueo(): void
{
    $admin = requiere_admin();
    $id = (int)($_POST['id'] ?? 0);
    $bloquear = ($_POST['accion'] ?? '') === 'bloquear';
    if ($id === (int)$admin['id']) {
        flash('No puedes bloquear tu propia cuenta.', 'error');
        redirigir('/admin');
    }
    db()->prepare('UPDATE usuarios SET bloqueado = ?, intentos_fallidos = 0, bloqueado_hasta = NULL WHERE id = ?')
        ->execute([$bloquear ? 1 : 0, $id]);
    app_log($bloquear ? 'USUARIO_BLOQUEADO' : 'USUARIO_DESBLOQUEADO', $admin['usuario'], "id=$id");
    flash($bloquear ? 'Usuario bloqueado.' : 'Usuario desbloqueado.', 'ok');
    redirigir('/admin');
}

// ---------- Estado (solo admin) ----------

function pagina_estado(): void
{
    requiere_admin();
    $chequeos = ['PHP-FPM (usuario del proceso)' => posix_getpwuid(posix_geteuid())['name'] ?? '?'];
    try {
        $chequeos['MariaDB'] = 'OK · ' . db()->query('SELECT VERSION()')->fetchColumn();
    } catch (Throwable $ex) {
        error_log('estado: ' . $ex->getMessage());
        $chequeos['MariaDB'] = 'ERROR';
    }
    $ch = curl_init(config('OLLAMA_URL') . '/api/version');
    curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 5]);
    $resp = curl_exec($ch);
    curl_close($ch);
    $chequeos['Ollama'] = $resp ? 'OK · versión ' . (json_decode($resp, true)['version'] ?? '?') . ' · modelo ' . config('OLLAMA_MODEL') : 'ERROR';

    $html = '<div class="caja"><h1>Estado del servidor</h1><table>';
    foreach ($chequeos as $k => $v) {
        $html .= '<tr><th>' . e($k) . '</th><td>' . e($v) . '</td></tr>';
    }
    render('Estado', $html . '</table></div>');
}

function no_encontrado(): void
{
    http_response_code(404);
    render('No encontrado', '<div class="caja"><h1>404</h1><p>Página no encontrada.</p></div>');
}
