-- Esquema de la app (se ejecuta como root; la app solo tiene SELECT/INSERT/UPDATE/DELETE)
CREATE TABLE IF NOT EXISTS usuarios (
    id                INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    usuario           VARCHAR(40)  NOT NULL UNIQUE,
    nombre            VARCHAR(100) NOT NULL,
    hash              VARCHAR(255) NOT NULL,            -- bcrypt
    rol               ENUM('admin','usuario') NOT NULL DEFAULT 'usuario',
    bloqueado         TINYINT(1)   NOT NULL DEFAULT 0,  -- bloqueo manual del admin
    intentos_fallidos INT UNSIGNED NOT NULL DEFAULT 0,
    bloqueado_hasta   DATETIME     NULL,                -- bloqueo temporal por intentos
    creado_en         DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ultimo_acceso     DATETIME     NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Historial por usuario
CREATE TABLE IF NOT EXISTS mensajes (
    id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    usuario_id  INT UNSIGNED NOT NULL,
    rol         ENUM('user','assistant') NOT NULL,
    contenido   TEXT NOT NULL,
    duracion_ms INT UNSIGNED NULL,
    creado_en   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_usuario (usuario_id, id),
    CONSTRAINT fk_mensajes_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Intentos de login (para el límite por IP y la evidencia de fuerza bruta)
CREATE TABLE IF NOT EXISTS eventos_login (
    id        BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    usuario   VARCHAR(40) NOT NULL,
    ip        VARCHAR(45) NOT NULL,
    exito     TINYINT(1)  NOT NULL,
    creado_en DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_ip_fecha (ip, creado_en)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
