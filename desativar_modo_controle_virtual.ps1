$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $Root 'config.json'
$ExamplePath = Join-Path $Root 'config.example.json'
if (Test-Path -LiteralPath $ConfigPath) {
    $Config = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json
} else {
    $Config = Get-Content -Raw -LiteralPath $ExamplePath | ConvertFrom-Json
}
$Config.output_mode = 'keyboard'
$Config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $ConfigPath -Encoding UTF8
Write-Host 'Modo Teclado / Emuladores restaurado.' -ForegroundColor Green
