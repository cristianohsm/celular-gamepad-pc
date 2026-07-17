$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$Lock = Get-Content -Raw -LiteralPath (Join-Path $Root 'dependencies.lock.json') | ConvertFrom-Json
$Dependency = $Lock.hidmaestro
$Destination = Join-Path $Root '.dependencies\hidmaestro'
$Zip = Join-Path $Destination $Dependency.asset
$Extracted = Join-Path $Destination 'extracted'

New-Item -ItemType Directory -Path $Destination -Force | Out-Null

if (-not (Test-Path -LiteralPath $Zip)) {
    Write-Host "Baixando HIDMaestro $($Dependency.tag) da release oficial..." -ForegroundColor Cyan
    Invoke-WebRequest -UseBasicParsing -Uri $Dependency.downloadUrl -OutFile $Zip
}

if ((Get-Item -LiteralPath $Zip).Length -ne [long]$Dependency.assetSize) {
    throw 'Tamanho do asset HIDMaestro divergente.'
}
$ZipHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Zip).Hash.ToLowerInvariant()
if ($ZipHash -ne $Dependency.sha256) {
    throw 'SHA-256 do asset HIDMaestro divergente.'
}

if (Test-Path -LiteralPath $Extracted) {
    Remove-Item -LiteralPath $Extracted -Recurse -Force
}
Expand-Archive -LiteralPath $Zip -DestinationPath $Extracted

$Core = Join-Path $Extracted 'HIDMaestro.Core.dll'
$License = Join-Path $Extracted 'LICENSE'
if ((Get-Item -LiteralPath $Core).Length -ne [long]$Dependency.coreDllSize) {
    throw 'Tamanho de HIDMaestro.Core.dll divergente.'
}
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $Core).Hash.ToLowerInvariant() -ne $Dependency.coreDllSha256) {
    throw 'SHA-256 de HIDMaestro.Core.dll divergente.'
}
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $License).Hash.ToLowerInvariant() -ne $Dependency.licenseSha256) {
    throw 'SHA-256 da licença HIDMaestro divergente.'
}

Copy-Item -LiteralPath $Core -Destination (Join-Path $Destination 'HIDMaestro.Core.dll') -Force
Copy-Item -LiteralPath $License -Destination (Join-Path $Destination 'LICENSE') -Force
Write-Host "HIDMaestro $($Dependency.tag) restaurado e verificado." -ForegroundColor Green
