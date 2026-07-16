param(
    [string]$Version = '1.3.0'
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Dist = Join-Path $Root 'dist'
$Staging = Join-Path $Dist ("celular-gamepad-pc-v{0}-windows-portable" -f $Version)
$Zip = "$Staging.zip"
$Checksum = "$Zip.sha256"

$requiredFiles = @(
    'server.py', 'config.example.json', 'iniciar.bat',
    'INICIAR_EM_QUALQUER_PC.bat', 'instalar_runtime_portatil.ps1',
    'liberar_firewall.bat', 'LIBERAR_FIREWALL_PRIMEIRO_USO.bat',
    'DIAGNOSTICO.bat', 'PREPARAR_PACOTE_OFFLINE.bat',
    'README.md', 'README.en.md', 'LICENSE'
)
$documentation = @(
    'docs\CONFIGURAR_2_JOGADORES_SNES9X.md',
    'docs\EXECUCAO_PORTATIL.md',
    'docs\SEGURANCA_REDE_LOCAL.md',
    'docs\SOLUCAO_DE_PROBLEMAS.md'
)

foreach ($relativePath in $requiredFiles + $documentation + @('static')) {
    if (-not (Test-Path -LiteralPath (Join-Path $Root $relativePath))) {
        throw "Arquivo necessário ausente: $relativePath"
    }
}

if (Test-Path -LiteralPath $Staging) {
    Remove-Item -LiteralPath $Staging -Recurse -Force
}
if (Test-Path -LiteralPath $Zip) {
    Remove-Item -LiteralPath $Zip -Force
}
if (Test-Path -LiteralPath $Checksum) {
    Remove-Item -LiteralPath $Checksum -Force
}

New-Item -ItemType Directory -Path $Staging | Out-Null
New-Item -ItemType Directory -Path (Join-Path $Staging 'docs') | Out-Null

foreach ($relativePath in $requiredFiles) {
    Copy-Item -LiteralPath (Join-Path $Root $relativePath) -Destination (Join-Path $Staging $relativePath)
}
foreach ($relativePath in $documentation) {
    Copy-Item -LiteralPath (Join-Path $Root $relativePath) -Destination (Join-Path $Staging $relativePath)
}
Copy-Item -LiteralPath (Join-Path $Root 'static') -Destination $Staging -Recurse

$forbidden = Get-ChildItem -LiteralPath $Staging -Recurse -Force | Where-Object {
    $_.Name -in @('.git', '.github', 'runtime', 'config.json', '__pycache__', 'logs', 'dist') -or
    $_.Extension -in @('.pyc', '.log', '.bak', '.tmp', '.zip')
}
if ($forbidden) {
    throw "Conteúdo proibido no pacote: $($forbidden.FullName -join ', ')"
}

Compress-Archive -LiteralPath $Staging -DestinationPath $Zip -CompressionLevel Optimal
$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Zip).Hash.ToLowerInvariant()
Set-Content -LiteralPath $Checksum -Encoding ASCII -NoNewline -Value "$hash  $(Split-Path -Leaf $Zip)`n"
Remove-Item -LiteralPath $Staging -Recurse -Force

Write-Host "Pacote: $Zip" -ForegroundColor Green
Write-Host "SHA-256: $hash" -ForegroundColor Green
