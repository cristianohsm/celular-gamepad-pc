@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title Preparar pacote offline - Celular Gamepad

if not exist "runtime\python.exe" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalar_runtime_portatil.ps1"
  if errorlevel 1 (
    echo Falha ao baixar o runtime.
    pause
    exit /b 1
  )
)

echo.
echo PRONTO PARA USO OFFLINE.
echo Agora copie esta pasta inteira, incluindo a pasta runtime,
echo para outro Windows 10/11 de mesma arquitetura.
echo.
echo No outro PC, execute primeiro LIBERAR_FIREWALL_PRIMEIRO_USO.bat
echo e depois INICIAR_EM_QUALQUER_PC.bat.
pause
endlocal
