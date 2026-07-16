$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = Join-Path $Root 'logs'
$Log = Join-Path $LogDir 'virtual-controller-install.log'

function Write-TechLog([string]$Message) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    $Safe = $Message -replace '(?i)C:\\Users\\[^\\\s]+', 'C:\Users\[local]'
    Add-Content -LiteralPath $Log -Encoding UTF8 -Value "$(Get-Date -Format o) $Safe"
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Esta etapa requer uma janela elevada pelo UAC.'
}
if (-not [Environment]::Is64BitOperatingSystem -or [Environment]::OSVersion.Version.Build -lt 26100) {
    throw 'O modo XInput experimental requer Windows 11 de 64 bits, build 26100 ou posterior.'
}

$Lock = Get-Content -Raw -LiteralPath (Join-Path $Root 'dependencies.lock.json') | ConvertFrom-Json
$Core = Join-Path $Root 'bridge\HIDMaestro.Core.dll'
$Bridge = Join-Path $Root 'bridge\PhoneGamepad.Bridge.exe'
if (-not (Test-Path -LiteralPath $Bridge) -or -not (Test-Path -LiteralPath $Core)) {
    throw 'Bridge ou HIDMaestro.Core.dll ausente. Extraia novamente o pacote completo.'
}
$CoreHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Core).Hash.ToLowerInvariant()
if ($CoreHash -ne $Lock.hidmaestro.coreDllSha256) {
    throw 'Integridade de HIDMaestro.Core.dll inválida. Nada foi executado.'
}

Write-TechLog "Inicio da instalacao HIDMaestro $($Lock.hidmaestro.tag); hash validado."
& $Bridge --install 2>&1 | ForEach-Object { Write-TechLog ([string]$_) }
if ($LASTEXITCODE -ne 0) {
    Write-TechLog "Falha controlada, codigo $LASTEXITCODE."
    throw 'O HIDMaestro não pôde ser instalado. Consulte logs\virtual-controller-install.log.'
}
$Check = & $Bridge --check 2>&1
Write-TechLog ([string]($Check -join ' '))
Write-TechLog 'Instalacao concluida.'
Write-Host 'Controle virtual instalado com sucesso.' -ForegroundColor Green
