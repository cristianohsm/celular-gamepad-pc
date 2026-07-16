$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$RuntimeDir = Join-Path $Root 'runtime'
$PythonExe = Join-Path $RuntimeDir 'python.exe'
$Version = '3.12.10'

if (Test-Path $PythonExe) {
    Write-Host 'Runtime Python portátil já está instalado.' -ForegroundColor Green
    exit 0
}

$arch = $env:PROCESSOR_ARCHITECTURE
if ($env:PROCESSOR_ARCHITEW6432) { $arch = $env:PROCESSOR_ARCHITEW6432 }

switch ($arch.ToUpperInvariant()) {
    'AMD64' { $packageArch = 'amd64' }
    'ARM64' { $packageArch = 'arm64' }
    default {
        throw "Arquitetura não suportada: $arch. Use Windows 10/11 de 64 bits (x64 ou ARM64)."
    }
}

$zipName = "python-$Version-embed-$packageArch.zip"
$url = "https://www.python.org/ftp/python/$Version/$zipName"
$tempZip = Join-Path $env:TEMP $zipName
$tempDir = Join-Path $env:TEMP ("celular-gamepad-python-" + [guid]::NewGuid().ToString('N'))

Write-Host 'Preparando o Celular Gamepad para este computador...' -ForegroundColor Cyan
Write-Host "Baixando runtime oficial do Python.org ($packageArch)..."

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $url -OutFile $tempZip -UseBasicParsing

    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    Expand-Archive -Path $tempZip -DestinationPath $tempDir -Force

    if (Test-Path $RuntimeDir) { Remove-Item $RuntimeDir -Recurse -Force }
    Move-Item $tempDir $RuntimeDir

    $pth = Get-ChildItem -Path $RuntimeDir -Filter 'python*._pth' | Select-Object -First 1
    if ($null -ne $pth) {
        $lines = Get-Content $pth.FullName
        if ($lines -notcontains '.') {
            Add-Content -Path $pth.FullName -Value '.'
        }
    }

    if (-not (Test-Path $PythonExe)) {
        throw 'python.exe não foi encontrado após a extração.'
    }

    Write-Host 'Runtime portátil instalado. Não foi feita instalação global no Windows.' -ForegroundColor Green
}
finally {
    Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
    if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
}
