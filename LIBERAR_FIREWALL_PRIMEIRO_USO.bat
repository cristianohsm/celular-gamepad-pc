@echo off
setlocal EnableExtensions
cd /d "%~dp0"

net session >nul 2>&1
if not %errorlevel%==0 (
  echo Solicitando permissao de administrador apenas para o Firewall...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

if exist "%~dp0config.json" for /f "usebackq tokens=*" %%P in (`powershell -NoProfile -Command "$c=Get-Content '%~dp0config.json' -Raw|ConvertFrom-Json; [int]$c.port"`) do set "PORTA=%%P"
if not defined PORTA set "PORTA=8765"

netsh advfirewall firewall delete rule name="Celular Gamepad TCP %PORTA%" >nul 2>&1
netsh advfirewall firewall add rule name="Celular Gamepad TCP %PORTA%" dir=in action=allow protocol=TCP localport=%PORTA% profile=private,domain

if errorlevel 1 (
  echo.
  echo Nao foi possivel criar a regra de Firewall.
  pause
  exit /b 1
)

echo.
echo Firewall liberado na porta TCP %PORTA% para redes Privadas e de Dominio.
echo Nao foi criada liberacao para redes Publicas por seguranca.
pause
endlocal
