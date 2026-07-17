param(
    [string]$Version = '1.4.0-beta.2',
    [switch]$SkipInstaller
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$InstallerRoot = Join-Path $Root 'installer'
$Downloads = Join-Path $InstallerRoot 'downloads'
$StagingRoot = Join-Path $InstallerRoot 'staging'
$AppStaging = Join-Path $StagingRoot 'app'
$PortableRoot = Join-Path $StagingRoot 'portable'
$PortableApp = Join-Path $PortableRoot 'CelularGamepad'
$DistRelease = Join-Path $Root 'dist-release'
$LockPath = Join-Path $Root 'dependencies.lock.json'
$Lock = Get-Content -Raw -LiteralPath $LockPath | ConvertFrom-Json

function Assert-InRoot([string]$Path, [string]$AllowedRoot) {
    $full = [IO.Path]::GetFullPath($Path)
    $allowed = [IO.Path]::GetFullPath($AllowedRoot).TrimEnd('\') + '\'
    if (-not $full.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Caminho fora do escopo permitido: $full"
    }
}

function Reset-Directory([string]$Path, [string]$AllowedRoot) {
    Assert-InRoot $Path $AllowedRoot
    if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Recurse -Force }
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Get-VerifiedAsset($Dependency) {
    New-Item -ItemType Directory -Path $Downloads -Force | Out-Null
    $path = Join-Path $Downloads $Dependency.asset
    if (-not (Test-Path -LiteralPath $path)) {
        Write-Host "Baixando $($Dependency.name) $($Dependency.version) da origem oficial..." -ForegroundColor Cyan
        Invoke-WebRequest -UseBasicParsing -Uri $Dependency.downloadUrl -OutFile $path
    }
    $item = Get-Item -LiteralPath $path
    if ($item.Length -ne [long]$Dependency.assetSize) { throw "Tamanho divergente: $($Dependency.asset)" }
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()
    if ($hash -ne $Dependency.sha256) { throw "SHA-256 divergente: $($Dependency.asset)" }
    return $path
}

function Copy-AppFile([string]$RelativePath) {
    $source = Join-Path $Root $RelativePath
    $destination = Join-Path $AppStaging $RelativePath
    if (-not (Test-Path -LiteralPath $source)) { throw "Arquivo necessário ausente: $RelativePath" }
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination -Force
}

$pythonZip = Get-VerifiedAsset $Lock.pythonEmbeddable
$innoInstaller = $null
if (-not $SkipInstaller) {
    $innoInstaller = Get-VerifiedAsset $Lock.innoSetup
    $signature = Get-AuthenticodeSignature -FilePath $innoInstaller
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch [regex]::Escape($Lock.innoSetup.authenticodePublisher)) {
        throw 'Assinatura Authenticode do Inno Setup inválida.'
    }
}

$dotnet = Join-Path $Root '.dotnet\dotnet.exe'
if (-not (Test-Path -LiteralPath $dotnet)) {
    $command = Get-Command dotnet -ErrorAction SilentlyContinue
    if (-not $command) { throw '.NET SDK fixado não encontrado.' }
    $dotnet = $command.Source
}
if ((& $dotnet --version) -ne $Lock.dotnetSdk.version) {
    throw "SDK .NET divergente; esperado $($Lock.dotnetSdk.version)."
}

& (Join-Path $PSScriptRoot 'restore_hidmaestro.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Falha ao restaurar HIDMaestro.' }

Reset-Directory $StagingRoot $InstallerRoot
Reset-Directory $DistRelease $Root
New-Item -ItemType Directory -Path $AppStaging -Force | Out-Null

$bridgeOutput = Join-Path $AppStaging 'bridge'
New-Item -ItemType Directory -Path $bridgeOutput -Force | Out-Null
& $dotnet publish (Join-Path $Root 'bridge\PhoneGamepad.Bridge\PhoneGamepad.Bridge.csproj') `
    -c Release -r $Lock.dotnetSdk.rid --self-contained true -o $bridgeOutput `
    -p:DebugType=None -p:DebugSymbols=false
if ($LASTEXITCODE -ne 0) { throw 'Falha ao publicar a bridge self-contained.' }

$core = Join-Path $bridgeOutput 'HIDMaestro.Core.dll'
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $core).Hash.ToLowerInvariant() -ne $Lock.hidmaestro.coreDllSha256) {
    throw 'HIDMaestro.Core.dll publicada não corresponde ao lock.'
}
New-Item -ItemType Directory -Path (Join-Path $bridgeOutput 'licenses') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $Root '.dependencies\hidmaestro\LICENSE') `
    -Destination (Join-Path $bridgeOutput 'licenses\HIDMaestro-LICENSE.txt') -Force

$runtime = Join-Path $AppStaging 'runtime'
Expand-Archive -LiteralPath $pythonZip -DestinationPath $runtime
if (-not (Test-Path -LiteralPath (Join-Path $runtime 'python.exe'))) { throw 'Runtime Python não foi extraído.' }

$appFiles = @(
    'server.py', 'gamepad_protocol.py', 'xinput_bridge.py', 'config.example.json',
    'dependencies.lock.json', 'README.md', 'README.en.md', 'CHANGELOG.md',
    'LICENSE', 'SECURITY.md', 'THIRD_PARTY_NOTICES.md'
)
foreach ($relative in $appFiles) { Copy-AppFile $relative }
Copy-Item -LiteralPath (Join-Path $Root 'static') -Destination $AppStaging -Recurse
Copy-Item -LiteralPath (Join-Path $Root 'docs') -Destination $AppStaging -Recurse
Copy-Item -LiteralPath (Join-Path $Root 'installer\scripts') -Destination $AppStaging -Recurse
Copy-Item -LiteralPath (Join-Path $Root 'installer\scripts\launch_emulators.cmd') -Destination (Join-Path $AppStaging 'INICIAR_EMULADORES.bat')
Copy-Item -LiteralPath (Join-Path $Root 'installer\scripts\launch_xinput.cmd') -Destination (Join-Path $AppStaging 'INICIAR_JOGOS_PC.bat')

New-Item -ItemType Directory -Path $PortableRoot -Force | Out-Null
Copy-Item -LiteralPath $AppStaging -Destination $PortableApp -Recurse
$portableZip = Join-Path $DistRelease "celular-gamepad-pc-v$Version-portable.zip"
Compress-Archive -LiteralPath $PortableApp -DestinationPath $portableZip -CompressionLevel Optimal
$portableHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $portableZip).Hash.ToLowerInvariant()
Set-Content -LiteralPath "$portableZip.sha256" -Encoding ASCII -NoNewline -Value "$portableHash  $(Split-Path -Leaf $portableZip)`n"

if (-not $SkipInstaller) {
    $isccCandidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
        'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
        'C:\Program Files\Inno Setup 6\ISCC.exe'
    )
    $iscc = $isccCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $iscc) { throw 'Inno Setup 6.7.1 verificado não está instalado.' }
    & $iscc "/DStagingDir=$AppStaging" "/DOutputDir=$DistRelease" (Join-Path $InstallerRoot 'CelularGamepad.iss')
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar o instalador Inno Setup.' }
    $setup = Join-Path $DistRelease "CelularGamepad-Setup-v$Version.exe"
    if (-not (Test-Path -LiteralPath $setup)) { throw 'Instalador final não foi criado.' }
    $setupHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $setup).Hash.ToLowerInvariant()
    Set-Content -LiteralPath "$setup.sha256" -Encoding ASCII -NoNewline -Value "$setupHash  $(Split-Path -Leaf $setup)`n"
}

if ($SkipInstaller) {
    & (Join-Path $PSScriptRoot 'audit_installer.ps1') -StagingPath $AppStaging -DistPath $DistRelease -SkipInstaller
} else {
    & (Join-Path $PSScriptRoot 'audit_installer.ps1') -StagingPath $AppStaging -DistPath $DistRelease
}
if ($LASTEXITCODE -ne 0) { throw 'Auditoria do staging/artefatos falhou.' }

Write-Host "Pacote portátil: $portableZip" -ForegroundColor Green
Write-Host "SHA-256 portátil: $portableHash" -ForegroundColor Green
if (-not $SkipInstaller) { Write-Host "Instalador: $(Join-Path $DistRelease "CelularGamepad-Setup-v$Version.exe")" -ForegroundColor Green }
