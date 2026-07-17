@echo off
setlocal EnableExtensions
cd /d "%~dp0"
echo Esta limpeza remove TODOS os controles virtuais HIDMaestro ativos.
echo O componente compartilhado e certificados serao preservados.
set /p "CONFIRMA=Continuar? [S/N]: "
if /i not "%CONFIRMA%"=="S" exit /b 1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~dp0bridge\PhoneGamepad.Bridge.exe' -Verb RunAs -Wait -ArgumentList '--cleanup'"
if errorlevel 1 echo A limpeza nao foi concluida.
pause
