param(
    [string]$OutDir = (Join-Path $PSScriptRoot "..\backups"),
    [string]$RemotePath = "/data/uploads"
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command railway -ErrorAction SilentlyContinue)) {
    throw "Falta Railway CLI. Instalala con: npm install -g @railway/cli; después ejecutá 'railway login' y 'railway link' en este repo."
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$outFull = (Resolve-Path $OutDir).Path
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$destino = Join-Path $outFull "uploads-$stamp"

Write-Host "Descargando $RemotePath a $destino..."
railway volume files download $RemotePath $destino

if ($LASTEXITCODE -ne 0) {
    throw "La descarga del volumen falló con código $LASTEXITCODE."
}

Write-Host "OK: $destino"
Write-Host "Guardá una copia fuera de esta PC y cifrala: incluye documentos de identidad."
