@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title Instalar modo Controle Virtual - Experimental

echo ==============================================================
echo  MODO CONTROLE VIRTUAL - v1.4.0-beta.2 EXPERIMENTAL
echo ==============================================================
echo Sera instalado o componente oficial HIDMaestro v1.3.17.
echo O Windows recebera pacotes UMDF2 e um certificado local confiavel.
echo Nao sera ativado Test Signing e o Secure Boot nao sera alterado.
echo O modo XInput exige Windows 11 build 26100 ou posterior.
echo.
set /p "CONFIRMA=Deseja continuar e solicitar permissao de administrador? [S/N]: "
if /i not "%CONFIRMA%"=="S" (
  echo Instalacao cancelada.
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath 'powershell.exe' -Verb RunAs -Wait -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%~dp0instalar_modo_controle_virtual.ps1""'"
if errorlevel 1 (
  echo Instalacao nao concluida.
  pause
  exit /b 1
)
echo Instalacao concluida. Use INICIAR_MODO_CONTROLE_VIRTUAL.bat.
pause
