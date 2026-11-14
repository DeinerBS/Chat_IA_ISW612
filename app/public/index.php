<?php
// Controlador frontal. Por ahora solo /estado; la app completa se agrega después
declare(strict_types=1);
require __DIR__ . '/../src/config.php';

$ruta = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);

if ($ruta === '/estado' || $ruta === '/') {
    $chequeos = [];

    // PHP-FPM: con qué usuario corre el proceso
    $chequeos['PHP-FPM (usuario del proceso)'] = posix_getpwuid(posix_geteuid())['name'] ?? '?';

    // MariaDB: conexión con el usuario de la app
    try {
        $chequeos['MariaDB'] = 'OK · ' . db()->query('SELECT VERSION()')->fetchColumn();
    } catch (Throwable $e) {
        error_log('estado: MariaDB: ' . $e->getMessage());
        $chequeos['MariaDB'] = 'ERROR (ver /var/log/chatia/php-error.log)';
    }

    // Ollama: solo accesible desde la VM
    $ch = curl_init(config('OLLAMA_URL') . '/api/version');
    curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 5]);
    $resp = curl_exec($ch);
    curl_close($ch);
    $chequeos['Ollama'] = $resp ? 'OK · versión ' . (json_decode($resp, true)['version'] ?? '?') : 'ERROR';

    header('Content-Type: text/html; charset=utf-8');
    echo '<!doctype html><html lang="es"><meta charset="utf-8"><title>Estado · Chat IA</title>';
    echo '<body style="font-family:sans-serif;max-width:640px;margin:40px auto">';
    echo '<h1>Estado del servidor</h1><table border="1" cellpadding="8" style="border-collapse:collapse">';
    foreach ($chequeos as $nombre => $valor) {
        echo '<tr><th align="left">' . htmlspecialchars($nombre) . '</th><td>' . htmlspecialchars($valor) . '</td></tr>';
    }
    echo '</table><p>HTTPS: ' . (($_SERVER['HTTPS'] ?? '') === 'on' ? 'sí' : 'no') . '</p></body></html>';
    exit;
}

http_response_code(404);
echo 'No encontrado';
