param([string]$Version = '1.4.0-beta.1')

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Dist = Join-Path $Root 'dist-experimental'
$Staging = Join-Path $Dist 'CelularGamepad'
$BridgeOutput = Join-Path $Staging 'bridge'
$Zip = Join-Path $Dist ("celular-gamepad-pc-v{0}-xinput.zip" -f $Version)
$Checksum = "$Zip.sha256"
$Project = Join-Path $Root 'bridge\PhoneGamepad.Bridge\PhoneGamepad.Bridge.csproj'
$Lock = Get-Content -Raw -LiteralPath (Join-Path $Root 'dependencies.lock.json') | ConvertFrom-Json

$DotNet = Join-Path $Root '.dotnet\dotnet.exe'
if (-not (Test-Path -LiteralPath $DotNet)) {
    $DotNetCommand = Get-Command dotnet -ErrorAction SilentlyContinue
    if ($null -eq $DotNetCommand) { throw '.NET SDK 10 não encontrado.' }
    $DotNet = $DotNetCommand.Source
}

& (Join-Path $PSScriptRoot 'restore_hidmaestro.ps1')
if (-not $?) { throw 'Falha ao restaurar HIDMaestro.' }

if (Test-Path -LiteralPath $Staging) { Remove-Item -LiteralPath $Staging -Recurse -Force }
if (Test-Path -LiteralPath $Zip) { Remove-Item -LiteralPath $Zip -Force }
if (Test-Path -LiteralPath $Checksum) { Remove-Item -LiteralPath $Checksum -Force }
New-Item -ItemType Directory -Path $BridgeOutput -Force | Out-Null

& $DotNet publish $Project -c Release -r win-x64 --self-contained true -o $BridgeOutput -p:DebugType=None -p:DebugSymbols=false
if ($LASTEXITCODE -ne 0) { throw 'Falha ao publicar o bridge.' }

$Core = Join-Path $BridgeOutput 'HIDMaestro.Core.dll'
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $Core).Hash.ToLowerInvariant() -ne $Lock.hidmaestro.coreDllSha256) {
    throw 'O DLL HIDMaestro publicado não corresponde ao lock.'
}
New-Item -ItemType Directory -Path (Join-Path $BridgeOutput 'licenses') | Out-Null
Copy-Item -LiteralPath (Join-Path $Root '.dependencies\hidmaestro\LICENSE') -Destination (Join-Path $BridgeOutput 'licenses\HIDMaestro-LICENSE.txt')

$files = @(
    'server.py', 'gamepad_protocol.py', 'xinput_bridge.py', 'config.example.json',
    'dependencies.lock.json', 'iniciar.bat', 'INICIAR_EM_QUALQUER_PC.bat',
    'instalar_runtime_portatil.ps1', 'liberar_firewall.bat',
    'LIBERAR_FIREWALL_PRIMEIRO_USO.bat', 'DIAGNOSTICO.bat',
    'PREPARAR_PACOTE_OFFLINE.bat', 'INSTALAR_MODO_CONTROLE_VIRTUAL.bat',
    'instalar_modo_controle_virtual.ps1', 'INICIAR_MODO_CONTROLE_VIRTUAL.bat',
    'ativar_modo_controle_virtual.ps1', 'VERIFICAR_CONTROLE_VIRTUAL.bat',
    'DESATIVAR_MODO_CONTROLE_VIRTUAL.bat', 'desativar_modo_controle_virtual.ps1',
    'REMOVER_COMPONENTE_CONTROLE_VIRTUAL.bat', 'TESTAR_CONTROLES_VIRTUAIS.bat',
    'README.md', 'README.en.md', 'LICENSE', 'THIRD_PARTY_NOTICES.md'
)
foreach ($relative in $files) {
    $source = Join-Path $Root $relative
    if (-not (Test-Path -LiteralPath $source)) { throw "Arquivo necessário ausente: $relative" }
    Copy-Item -LiteralPath $source -Destination (Join-Path $Staging $relative)
}
Copy-Item -LiteralPath (Join-Path $Root 'static') -Destination $Staging -Recurse
Copy-Item -LiteralPath (Join-Path $Root 'docs') -Destination $Staging -Recurse

$forbidden = Get-ChildItem -LiteralPath $Staging -Recurse -Force | Where-Object {
    $_.Name -in @('.git', '.github', 'runtime', 'config.json', '__pycache__', 'logs', 'dist', 'dist-experimental') -or
    $_.Extension -in @('.pyc', '.pdb', '.log', '.bak', '.tmp', '.zip', '.pfx', '.p12', '.key')
}
if ($forbidden) { throw "Conteúdo proibido: $($forbidden.FullName -join ', ')" }

Compress-Archive -LiteralPath $Staging -DestinationPath $Zip -CompressionLevel Optimal
$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Zip).Hash.ToLowerInvariant()
Set-Content -LiteralPath $Checksum -Encoding ASCII -NoNewline -Value "$hash  $(Split-Path -Leaf $Zip)`n"
Remove-Item -LiteralPath $Staging -Recurse -Force
Write-Host "Pacote experimental: $Zip" -ForegroundColor Green
Write-Host "SHA-256: $hash" -ForegroundColor Green
