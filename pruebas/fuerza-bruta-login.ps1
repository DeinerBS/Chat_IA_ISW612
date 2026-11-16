# Simula fuerza bruta contra el login desde otra máquina (Windows).
# Uso: .\fuerza-bruta-login.ps1 -Usuario empleado2 -Intentos 15
param(
    [string]$Servidor = "192.168.56.10",
    [string]$Usuario  = "empleado2",
    [int]$Intentos    = 15,
    [int]$Pausa       = 1       # segundos entre intentos
)

$jar = Join-Path $env:TEMP "chatia-cookies.txt"
Remove-Item $jar -ErrorAction SilentlyContinue

for ($i = 1; $i -le $Intentos; $i++) {
    # 1) Pedir el formulario: trae el token CSRF y el mensaje del intento anterior
    $html = (curl.exe -sk -c $jar -b $jar "https://$Servidor/login") -join "`n"
    $csrf = [regex]::Match($html, 'name="csrf" value="([0-9a-f]+)"').Groups[1].Value
    $msg  = [regex]::Match($html, 'class="flash[^"]*">([^<]+)<').Groups[1].Value
    if ($i -gt 1) { "      respuesta de la app: $msg" }

    # 2) Enviar una contraseña falsa
    $codigo = curl.exe -sk -c $jar -b $jar -o NUL -w "%{http_code}" -X POST `
        --data-urlencode "csrf=$csrf" --data-urlencode "usuario=$Usuario" `
        --data-urlencode "clave=intento$i" "https://$Servidor/login"
    "{0,2}  {1}  POST /login usuario={2} -> HTTP {3}" -f $i, (Get-Date -Format HH:mm:ss), $Usuario, $codigo
    Start-Sleep -Seconds $Pausa
}
