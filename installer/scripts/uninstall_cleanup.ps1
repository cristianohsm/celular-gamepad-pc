param([Parameter(Mandatory = $true)][string]$AppRoot)

$ErrorActionPreference = 'Continue'
$resolvedRoot = [IO.Path]::GetFullPath($AppRoot).TrimEnd('\') + '\'
$owned = @(Get-CimInstance Win32_Process | Where-Object {
    $_.ExecutablePath -and [IO.Path]::GetFullPath($_.ExecutablePath).StartsWith($resolvedRoot, [StringComparison]::OrdinalIgnoreCase)
})

$owned | Where-Object Name -eq 'python.exe' | ForEach-Object {
    Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 2

$owned | Where-Object Name -ne 'python.exe' | ForEach-Object {
    if (Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue) {
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }
}
