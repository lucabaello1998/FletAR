param(
    [string]$OutDir = (Join-Path $PSScriptRoot "..\backups"),
    [string]$DatabaseUrl = $env:DATABASE_URL,
    [string]$Image = "postgres:16"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($DatabaseUrl)) {
    throw "Falta DATABASE_URL. Usá la connection string directa de Neon (sin -pooler) o pasala con -DatabaseUrl."
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker no está disponible. Instalá Docker Desktop o corré pg_dump contra Neon desde una máquina con PostgreSQL 16."
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$outFull = (Resolve-Path $OutDir).Path
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$nombre = "fletar-$stamp.dump"

Write-Host "Generando $nombre desde Neon..."
docker run --rm `
    -v "${outFull}:/backup" `
    $Image `
    pg_dump --dbname="$DatabaseUrl" --format=custom --no-owner --no-privileges --file="/backup/$nombre"

if ($LASTEXITCODE -ne 0) {
    throw "pg_dump falló con código $LASTEXITCODE."
}

$archivo = Join-Path $outFull $nombre
Write-Host "OK: $archivo ($([math]::Round((Get-Item $archivo).Length / 1MB, 2)) MB)"
Write-Host "Guardá una copia fuera de esta PC. El artefacto de GitHub Actions sólo retiene 30 días."
