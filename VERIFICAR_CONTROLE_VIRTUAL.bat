@echo off
setlocal
cd /d "%~dp0"
if not exist "bridge\PhoneGamepad.Bridge.exe" (
  echo Controle virtual nao preparado: bridge ausente.
  pause
  exit /b 1
)
"bridge\PhoneGamepad.Bridge.exe" --check
echo.
echo Para inspecionar dispositivos ativos, abra joy.cpl.
pause
