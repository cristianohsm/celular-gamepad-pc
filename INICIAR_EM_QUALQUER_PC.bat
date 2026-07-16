@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title Celular Gamepad para PC - Portatil

if not exist "runtime\python.exe" (
  echo.
  echo PRIMEIRO USO: sera baixado um runtime Python oficial e portatil.
  echo Ele fica somente nesta pasta e nao altera o Python do Windows.
  echo.
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalar_runtime_portatil.ps1"
  if errorlevel 1 (
    echo.
    echo Nao foi possivel preparar o runtime portatil.
    echo Verifique a internet e tente novamente.
    pause
    exit /b 1
  )
)

echo.
"%~dp0runtime\python.exe" "%~dp0server.py"
set "RC=%errorlevel%"

echo.
if not "%RC%"=="0" echo O servidor terminou com codigo %RC%.
pause
exit /b %RC%
