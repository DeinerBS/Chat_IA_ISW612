# Ráfaga de peticiones en paralelo para comprobar el rate limiting (429) de Nginx.
# Uso: .\rafaga-429.ps1 -Peticiones 80
param(
    [string]$Servidor = "192.168.56.10",
    [int]$Peticiones  = 80
)

$tmp = Join-Path $env:TEMP "rafaga"
New-Item -ItemType Directory -Force $tmp | Out-Null

# 30 conexiones a la vez contra / (zona "general": 10 r/s con ráfaga de 20)
$codigos = curl.exe -sk --parallel --parallel-max 30 -w "%{http_code}`n" `
    -o "$tmp\r#1.html" "https://$Servidor/?n=[1-$Peticiones]"

"Peticiones enviadas: $Peticiones"
$codigos | Group-Object | Sort-Object Name | Format-Table @{n='Código HTTP';e={$_.Name}}, @{n='Cantidad';e={$_.Count}} -AutoSize
Remove-Item $tmp -Recurse -Force
