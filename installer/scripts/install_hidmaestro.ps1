param([Parameter(Mandatory = $true)][string]$AppRoot)

$ErrorActionPreference = 'Stop'
$DataDir = Join-Path $env:LOCALAPPDATA 'CelularGamepad'
$LogDir = Join-Path $DataDir 'logs'
$Log = Join-Path $LogDir 'installer-hidmaestro.log'
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

function Write-SafeLog([string]$Message) {
    $safe = $Message -replace [regex]::Escape($env:USERPROFILE), '[local-user]'
    Add-Content -LiteralPath $Log -Encoding UTF8 -Value "$(Get-Date -Format o) $safe"
}

$lock = Get-Content -Raw -LiteralPath (Join-Path $AppRoot 'dependencies.lock.json') | ConvertFrom-Json
$bridge = Join-Path $AppRoot 'bridge\PhoneGamepad.Bridge.exe'
$core = Join-Path $AppRoot 'bridge\HIDMaestro.Core.dll'
if (-not (Test-Path -LiteralPath $bridge) -or -not (Test-Path -LiteralPath $core)) {
    throw 'Bridge XInput incompleta; o modo Emuladores permanece disponível.'
}
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $core).Hash.ToLowerInvariant() -ne $lock.hidmaestro.coreDllSha256) {
    throw 'HIDMaestro.Core.dll não corresponde ao lock.'
}

$checkText = (& $bridge --check 2>&1) -join "`n"
Write-SafeLog $checkText
$check = $checkText | ConvertFrom-Json
if ($check.installed -eq $true) {
    $expectedInf = @('hidmaestro.inf', 'hidmaestro_xusb.inf')
    $installedDrivers = @(Get-WindowsDriver -Online -All | Where-Object {
        $_.ProviderName -eq 'HIDMaestro' -and (Split-Path -Leaf $_.OriginalFileName).ToLowerInvariant() -in $expectedInf
    })
    $incompatible = @($installedDrivers | Where-Object { ([string]$_.Version) -ne $lock.hidmaestro.driverVersion })
    if ($installedDrivers.Count -ne $expectedInf.Count -or $incompatible.Count -gt 0) {
        Write-SafeLog "HIDMaestro instalado, mas incompatível com a versão fixada $($lock.hidmaestro.driverVersion)."
        throw 'Existe uma instalação HIDMaestro incompatível; nenhuma substituição automática foi realizada.'
    }
    Write-SafeLog "HIDMaestro $($lock.hidmaestro.version) já instalado; preservado sem reinstalação."
    exit 0
}

Write-SafeLog "Instalando HIDMaestro $($lock.hidmaestro.version) após validação SHA-256."
$installText = (& $bridge --install 2>&1) -join "`n"
Write-SafeLog $installText
if ($LASTEXITCODE -ne 0) { throw 'Falha na instalação do HIDMaestro; o modo Emuladores permanece disponível.' }
