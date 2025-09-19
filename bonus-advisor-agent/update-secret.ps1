# update-secret.ps1
# Script para generar y reemplazar SECRET_KEY en el archivo .env

# 1. Genera la SECRET_KEY usando Python
$SECRET_KEY = python3 -c "import secrets; print(secrets.token_urlsafe(32))"

# 2. Verifica que se haya generado correctamente
if (-not $SECRET_KEY) {
    Write-Error "No se pudo generar SECRET_KEY. Verifica que Python esté instalado y accesible."
    exit 1
}

# 3. Reemplaza en el archivo .env
if (Test-Path .env) {
    (Get-Content .env) -replace 'SECRET_KEY=tu-clave-secreta-aqui', "SECRET_KEY=$SECRET_KEY" | Set-Content .env
    Write-Host "✅ SECRET_KEY actualizado correctamente en .env"
} else {
    Write-Error "No se encontró el archivo .env en el directorio actual."
    exit 1
}
