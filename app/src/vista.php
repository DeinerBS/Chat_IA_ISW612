<?php
// Plantilla común, mensajes flash y redirecciones
declare(strict_types=1);

function redirigir(string $ruta): never
{
    header('Location: ' . $ruta, true, 303);
    exit;
}

function flash(string $mensaje, string $tipo = 'info'): void
{
    $_SESSION['flash'] = ['mensaje' => $mensaje, 'tipo' => $tipo];
}

function tomar_flash(): string
{
    if (empty($_SESSION['flash'])) {
        return '';
    }
    $f = $_SESSION['flash'];
    unset($_SESSION['flash']);
    return '<div class="flash ' . e($f['tipo']) . '">' . e($f['mensaje']) . '</div>';
}

function render(string $titulo, string $contenido): void
{
    $u = usuario_actual();
    $menu = '';
    if ($u) {
        $menu = '<nav><span>' . e($u['nombre']) . ' (' . e($u['rol']) . ')</span> <a href="/">Chat</a>';
        if ($u['rol'] === 'admin') {
            $menu .= ' <a href="/admin">Panel</a> <a href="/estado">Estado</a>';
        }
        $menu .= ' <form method="post" action="/logout" class="enlinea">' . csrf_campo() . '<button>Salir</button></form></nav>';
    }
    $flash = tomar_flash();
    $titulo = e($titulo);
    header('Content-Type: text/html; charset=utf-8');
    echo <<<HTML
<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{$titulo} · Asistente Arenal Tech</title>
<style>
  body { font-family: system-ui, sans-serif; margin: 0; background: #f4f6f8; color: #1e293b; }
  header { background: #0f172a; color: #fff; padding: 12px 24px; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px; }
  header a, header button { color: #fff; margin-left: 12px; background: none; border: 0; font: inherit; cursor: pointer; text-decoration: underline; }
  main { max-width: 860px; margin: 24px auto; padding: 0 16px; }
  .caja { background: #fff; border: 1px solid #e2e8f0; border-radius: 10px; padding: 20px; margin-bottom: 16px; }
  .enlinea { display: inline; }
  .flash { padding: 10px 14px; border-radius: 8px; margin-bottom: 16px; background: #e0f2fe; }
  .flash.error { background: #fee2e2; }
  .flash.ok { background: #dcfce7; }
  input, textarea, select { width: 100%; padding: 8px; box-sizing: border-box; border: 1px solid #cbd5e1; border-radius: 6px; font: inherit; }
  button.principal { background: #0f172a; color: #fff; border: 0; border-radius: 6px; padding: 10px 18px; cursor: pointer; margin-top: 10px; }
  .msg { padding: 10px 14px; border-radius: 10px; margin: 8px 0; white-space: pre-wrap; }
  .msg.user { background: #dbeafe; margin-left: 15%; }
  .msg.assistant { background: #fff; border: 1px solid #e2e8f0; margin-right: 15%; }
  .meta { font-size: 12px; color: #64748b; }
  table { width: 100%; border-collapse: collapse; background: #fff; }
  th, td { border: 1px solid #e2e8f0; padding: 8px; text-align: left; font-size: 14px; }
  .bloq { color: #b91c1c; font-weight: bold; }
</style>
</head>
<body>
<header><strong>Asistente Arenal Tech</strong>{$menu}</header>
<main>{$flash}{$contenido}</main>
</body>
</html>
HTML;
}
