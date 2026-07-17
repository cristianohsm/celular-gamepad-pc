param([switch]$Confirmed)

$ErrorActionPreference = 'Stop'
$DataDir = Join-Path $env:LOCALAPPDATA 'CelularGamepad'
$LogDir = Join-Path $DataDir 'logs'
$Log = Join-Path $LogDir 'hidmaestro-removal.log'
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

function Write-SafeLog([string]$Message) {
    $safe = $Message -replace [regex]::Escape($env:USERPROFILE), '[local-user]'
    Add-Content -LiteralPath $Log -Encoding UTF8 -Value "$(Get-Date -Format o) $safe"
}

if (-not $Confirmed) { throw 'A remoção requer confirmação explícita no desinstalador.' }

$allowedInf = @('hidmaestro.inf', 'hidmaestro_xusb.inf')
$drivers = Get-WindowsDriver -Online -All | Where-Object {
    $_.ProviderName -eq 'HIDMaestro' -and (Split-Path -Leaf $_.OriginalFileName).ToLowerInvariant() -in $allowedInf
}
if (-not $drivers) {
    Write-SafeLog 'Nenhum pacote HIDMaestro compatível foi encontrado.'
    exit 0
}

foreach ($driver in $drivers) {
    Write-SafeLog "Removendo pacote confirmado: $($driver.Driver) / $(Split-Path -Leaf $driver.OriginalFileName) / $($driver.ProviderName)"
    & pnputil.exe /delete-driver $driver.Driver /uninstall 2>&1 | ForEach-Object { Write-SafeLog ([string]$_) }
    if ($LASTEXITCODE -ne 0) { throw "Falha ao remover $($driver.Driver)." }
}

Write-SafeLog 'Certificados foram preservados; nenhum certificado de terceiro foi removido.'
