param(
    [string]$InstallerPath,
    [string]$InstallDir,
    [string]$DataDir
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
if (-not $InstallerPath) { $InstallerPath = Join-Path $Root 'dist-release\CelularGamepad-Setup-v1.4.0-beta.2.exe' }
if (-not $InstallDir) { $InstallDir = Join-Path $Root 'installer\test-install\app' }
if (-not $DataDir) { $DataDir = Join-Path $Root 'installer\test-install\data' }
$TestRoot = Join-Path $Root 'installer\test-install'

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    foreach ($value in @($PSCommandPath, $InstallerPath, $InstallDir, $DataDir)) {
        if ($value.Contains('"')) { throw 'O teste não aceita aspas nos caminhos.' }
    }
    $elevatedArgs = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -InstallerPath "{1}" -InstallDir "{2}" -DataDir "{3}"' -f `
        $PSCommandPath, $InstallerPath, $InstallDir, $DataDir
    $elevated = Start-Process -FilePath "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" `
        -ArgumentList $elevatedArgs -Verb RunAs -Wait -PassThru
    exit $elevated.ExitCode
}

trap {
    New-Item -ItemType Directory -Path $TestRoot -Force | Out-Null
    $_ | Out-String | Set-Content -LiteralPath (Join-Path $TestRoot 'test-failure.log') -Encoding UTF8
    exit 1
}

$resolvedTestRoot = [IO.Path]::GetFullPath($TestRoot).TrimEnd('\') + '\'
foreach ($path in @($InstallDir, $DataDir)) {
    if (-not [IO.Path]::GetFullPath($path).StartsWith($resolvedTestRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Caminho de teste fora do escopo: $path"
    }
}
if (Test-Path -LiteralPath $TestRoot) { Remove-Item -LiteralPath $TestRoot -Recurse -Force }
New-Item -ItemType Directory -Path $TestRoot -Force | Out-Null

$driversBefore = @(& pnputil.exe /enum-drivers | Select-String -SimpleMatch 'HIDMaestro').Count
$installLog = Join-Path $TestRoot 'install.log'
$installArgs = @(
    '/VERYSILENT'
    '/SUPPRESSMSGBOXES'
    '/NORESTART'
    '/TYPE=emulators'
    "/DIR=$InstallDir"
    "/LOG=$installLog"
)
$install = Start-Process -FilePath $InstallerPath -ArgumentList $installArgs -Wait -PassThru
if ($install.ExitCode -ne 0) { throw "Instalação de teste falhou: $($install.ExitCode)" }

foreach ($relative in @('runtime\python.exe', 'server.py', 'scripts\launch_emulators.cmd', 'docs\INSTALACAO_WINDOWS.md')) {
    if (-not (Test-Path -LiteralPath (Join-Path $InstallDir $relative))) { throw "Arquivo instalado ausente: $relative" }
}
if (Get-ChildItem -LiteralPath (Join-Path $InstallDir 'bridge') -File -Recurse -ErrorAction SilentlyContinue) { throw 'Instalação Somente Emuladores incluiu arquivos da bridge.' }

$firewall = @(Get-NetFirewallRule -DisplayName 'Celular Gamepad — Rede Local' -ErrorAction SilentlyContinue)
$portFilter = @($firewall | Get-NetFirewallPortFilter)
if ($firewall.Count -ne 1 -or [string]$firewall[0].Profile -ne 'Private' -or
    [string]$firewall[0].Direction -ne 'Inbound' -or [string]$firewall[0].Enabled -ne 'True' -or
    $portFilter.Count -ne 1 -or [string]$portFilter[0].Protocol -ne 'TCP' -or
    [string]$portFilter[0].LocalPort -ne '8765') {
    throw 'Regra de firewall Private/TCP 8765 não foi criada.'
}

$env:CELULAR_GAMEPAD_DATA_DIR = $DataDir
Push-Location $InstallDir
try {
    $probe = & (Join-Path $InstallDir 'runtime\python.exe') -B -c "import sys;sys.path.insert(0,'.');import server;print(server.CONFIG_PATH);server.load_config()"
} finally {
    Pop-Location
}
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath (Join-Path $DataDir 'config.json'))) { throw 'Dados em LocalAppData simulado falharam.' }

$uninstaller = Join-Path $InstallDir 'unins000.exe'
if (-not (Test-Path -LiteralPath $uninstaller)) { throw 'Desinstalador ausente.' }
$uninstall = Start-Process -FilePath $uninstaller `
    -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART') -Wait -PassThru
if ($uninstall.ExitCode -notin @(0, -1)) { throw "Desinstalação de teste falhou: $($uninstall.ExitCode)" }
if (Test-Path -LiteralPath $InstallDir) { throw 'Desinstalação não removeu a pasta da aplicação.' }
if (-not (Test-Path -LiteralPath (Join-Path $DataDir 'config.json'))) { throw 'Desinstalação removeu configuração do usuário.' }
if (Get-NetFirewallRule -DisplayName 'Celular Gamepad — Rede Local' -ErrorAction SilentlyContinue) {
    throw 'Desinstalação deixou a regra de firewall.'
}
$driversAfter = @(& pnputil.exe /enum-drivers | Select-String -SimpleMatch 'HIDMaestro').Count
if ($driversAfter -ne $driversBefore) { throw 'Teste alterou a instalação HIDMaestro existente.' }

Write-Host "TEST_INSTALLED_APP_PASS CONFIG=$probe HIDMAESTRO_DRIVERS=$driversAfter" -ForegroundColor Green
