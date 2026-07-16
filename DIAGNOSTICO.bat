@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title Diagnostico - Celular Gamepad

echo ==============================================================
echo  DIAGNOSTICO CELULAR GAMEPAD
echo ==============================================================
ver
wmic os get osarchitecture 2>nul

echo.
echo [1] Runtime portatil
if exist "runtime\python.exe" (
  "runtime\python.exe" --version
) else (
  echo NAO INSTALADO - execute INICIAR_EM_QUALQUER_PC.bat
)

echo.
echo [2] Porta configurada
if exist "config.json" (
  powershell -NoProfile -Command "$c=Get-Content '%~dp0config.json' -Raw|ConvertFrom-Json; Write-Host $c.port"
) else (
  echo 8765 ^(padrao; config.json sera criado ao iniciar^)
)

echo.
echo [3] Enderecos IPv4 deste PC
ipconfig | findstr /i "IPv4"

echo.
echo [4] Regra de Firewall
netsh advfirewall firewall show rule name=all | findstr /i /c:"Celular Gamepad TCP"

echo.
echo [5] Porta 8765 em uso
netstat -ano | findstr ":8765"

echo.
echo Dica: PC e celular devem estar na mesma rede e a rede do Windows
 echo deve estar marcada como PRIVADA.
echo ==============================================================
pause
endlocal
