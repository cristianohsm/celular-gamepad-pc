param([Parameter(Mandatory = $true)][string]$AppRoot)

$ErrorActionPreference = 'Continue'
$resolvedRoot = [IO.Path]::GetFullPath($AppRoot).TrimEnd('\') + '\'
$bridge = Join-Path $AppRoot 'bridge\PhoneGamepad.Bridge.exe'

Get-CimInstance Win32_Process | Where-Object {
    $_.ExecutablePath -and [IO.Path]::GetFullPath($_.ExecutablePath).StartsWith($resolvedRoot, [StringComparison]::OrdinalIgnoreCase)
} | ForEach-Object {
    Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
}

if (Test-Path -LiteralPath $bridge) {
    & $bridge --cleanup 2>$null | Out-Null
}
