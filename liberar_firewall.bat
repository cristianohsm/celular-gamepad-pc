@echo off
setlocal
cd /d "%~dp0"

net session >nul 2>&1
if not %errorlevel%==0 (
  echo Solicitando permissao de administrador...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

netsh advfirewall firewall delete rule name="Celular Gamepad TCP 8765" >nul 2>&1
netsh advfirewall firewall add rule name="Celular Gamepad TCP 8765" dir=in action=allow protocol=TCP localport=8765 profile=private

echo.
echo Regra criada para redes privadas na porta TCP 8765.
pause
endlocal
