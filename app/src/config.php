<?php
// Lee la configuración desde /etc/chatia/chatia.env (fuera del repositorio)
declare(strict_types=1);

function config(string $clave): string
{
    static $valores = null;
    if ($valores === null) {
        $valores = parse_ini_file('/etc/chatia/chatia.env', false, INI_SCANNER_RAW) ?: [];
    }
    return $valores[$clave] ?? '';
}

// Conexión por socket unix: MariaDB no necesita escuchar en red
function db(): PDO
{
    static $pdo = null;
    if ($pdo === null) {
        $pdo = new PDO(
            'mysql:unix_socket=/run/mysqld/mysqld.sock;dbname=' . config('DB_NAME') . ';charset=utf8mb4',
            config('DB_USER'),
            config('DB_PASS'),
            [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]
        );
    }
    return $pdo;
}
