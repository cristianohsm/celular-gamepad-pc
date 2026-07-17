param(
    [string]$StagingPath,
    [string]$DistPath,
    [switch]$SkipInstaller
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
if (-not $StagingPath) { $StagingPath = Join-Path $Root 'installer\staging\app' }
if (-not $DistPath) { $DistPath = Join-Path $Root 'dist-release' }
$Lock = Get-Content -Raw -LiteralPath (Join-Path $Root 'dependencies.lock.json') | ConvertFrom-Json
$Iss = Get-Content -Raw -LiteralPath (Join-Path $Root 'installer\CelularGamepad.iss')

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

Assert (Test-Path -LiteralPath (Join-Path $StagingPath 'runtime\python.exe')) 'Runtime Python ausente no staging.'
$pthFiles = @(Get-ChildItem -LiteralPath (Join-Path $StagingPath 'runtime') -Filter 'python*._pth' -File)
Assert ($pthFiles.Count -eq 1 -and '..' -in @(Get-Content -LiteralPath $pthFiles[0].FullName)) 'Runtime Python não inclui a raiz da aplicação no _pth.'
Assert (Test-Path -LiteralPath (Join-Path $StagingPath 'bridge\PhoneGamepad.Bridge.exe')) 'Bridge self-contained ausente no staging.'
Assert (Test-Path -LiteralPath (Join-Path $StagingPath 'bridge\coreclr.dll')) 'Runtime .NET self-contained ausente.'
Assert ((Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $StagingPath 'bridge\HIDMaestro.Core.dll')).Hash.ToLowerInvariant() -eq $Lock.hidmaestro.coreDllSha256) 'HIDMaestro.Core.dll não corresponde ao lock.'
Assert (-not (Test-Path -LiteralPath (Join-Path $StagingPath 'config.json'))) 'config.json foi empacotado indevidamente.'

$forbiddenNames = @('.git', '.github', '__pycache__', 'logs', 'config.json')
$forbiddenExtensions = @('.pyc', '.pfx', '.p12', '.key', '.log', '.bak', '.tmp')
$forbidden = Get-ChildItem -LiteralPath $StagingPath -Recurse -Force | Where-Object {
    $_.Name -in $forbiddenNames -or $_.Extension.ToLowerInvariant() -in $forbiddenExtensions
}
Assert (-not $forbidden) "Conteúdo proibido no staging: $($forbidden.FullName -join ', ')"

$textExtensions = @('.py', '.js', '.json', '.md', '.txt', '.cmd', '.bat', '.ps1', '.toml', '.html', '.css')
$textFiles = Get-ChildItem -LiteralPath $StagingPath -Recurse -File | Where-Object { $_.Extension.ToLowerInvariant() -in $textExtensions }
foreach ($file in $textFiles) {
    $content = Get-Content -Raw -LiteralPath $file.FullName
    Assert ($content -notmatch '(?i)(?<![a-z0-9])CRISTIANO(?![a-z0-9])') "Nome local encontrado em $($file.FullName)."
    Assert ($content -notmatch '(?i)C:\\Users\\') "Caminho local encontrado em $($file.FullName)."
    Assert ($content -notmatch '(?i)(gho_|github_pat_|BEGIN (RSA |OPENSSH )?PRIVATE KEY)') "Possível segredo em $($file.FullName)."
    Assert ($content -notmatch 'PIN de conexão:\s*\d{4}') "PIN operacional encontrado em $($file.FullName)."
    # qr_connection.py contém somente faixas RFC1918 e endereços de exemplo;
    # não são dados operacionais. Os demais textos continuam auditados.
    if ($file.Name -ne 'qr_connection.py') {
        Assert ($content -notmatch '(?<![0-9])192\.168\.\d{1,3}\.\d{1,3}') "IP local encontrado em $($file.FullName)."
    }
}

Assert ($Iss -match '#define\s+AppGuid\s+"\{8C41B45B-1E31-4B85-93F8-E829A1A2DC42\}"') 'GUID fixo do aplicativo ausente.'
Assert ($Iss -match 'AppId=\{\{#AppGuid\}') 'AppId não referencia o GUID fixo.'
$firewallAdd = ($Iss -split "`r?`n") | Where-Object { $_ -match 'firewall add rule' }
Assert ($firewallAdd.Count -eq 1) 'Regra de firewall deve ser única.'
Assert ($firewallAdd -match 'profile=private') 'Firewall não está restrito a Private.'
Assert ($firewallAdd -notmatch 'profile=(public|domain|any)') 'Firewall liberou perfil proibido.'
Assert ($Iss -match 'HIDMaestro pode ser utilizado por outros programas e será preservado') 'Política de preservação do HIDMaestro ausente.'
$uninstallCleanup = Get-Content -Raw -LiteralPath (Join-Path $StagingPath 'scripts\uninstall_cleanup.ps1')
Assert ($uninstallCleanup -notmatch '--cleanup|remove_hidmaestro\.ps1') 'Desinstalação padrão pode remover HIDMaestro.'

$shortcutTargets = @('launch_emulators.cmd', 'launch_xinput.cmd', 'test_controllers.cmd', 'verify_installation.cmd')
foreach ($target in $shortcutTargets) {
    Assert (Test-Path -LiteralPath (Join-Path $StagingPath "scripts\$target")) "Destino de atalho ausente: $target"
}

$portable = Join-Path $DistPath 'celular-gamepad-pc-v1.4.0-beta.3-portable.zip'
Assert (Test-Path -LiteralPath $portable) 'ZIP portátil ausente.'
Assert (Test-Path -LiteralPath "$portable.sha256") 'Hash do ZIP portátil ausente.'
$expectedPortableHash = ((Get-Content -Raw -LiteralPath "$portable.sha256") -split '\s+')[0]
Assert ((Get-FileHash -Algorithm SHA256 -LiteralPath $portable).Hash.ToLowerInvariant() -eq $expectedPortableHash) 'Hash do ZIP portátil divergente.'
$zipEntries = tar -tf $portable
Assert (-not ($zipEntries | Where-Object { $_ -match '(^|/)(\.git|\.github|config\.json|logs|__pycache__)(/|$)' -or $_ -match '\.pyc$' })) 'ZIP portátil contém entrada proibida.'

if (-not $SkipInstaller) {
    $setup = Join-Path $DistPath 'CelularGamepad-Setup-v1.4.0-beta.3.exe'
    Assert (Test-Path -LiteralPath $setup) 'Instalador final ausente.'
    Assert (Test-Path -LiteralPath "$setup.sha256") 'Hash do instalador ausente.'
    $expectedSetupHash = ((Get-Content -Raw -LiteralPath "$setup.sha256") -split '\s+')[0]
    Assert ((Get-FileHash -Algorithm SHA256 -LiteralPath $setup).Hash.ToLowerInvariant() -eq $expectedSetupHash) 'Hash do instalador divergente.'
}

Write-Host 'AUDIT_INSTALLER_PASS' -ForegroundColor Green
