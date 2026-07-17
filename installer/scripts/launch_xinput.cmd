@echo off
setlocal EnableExtensions
net session >nul 2>&1
if not %errorlevel%==0 (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
set "CELULAR_GAMEPAD_DATA_DIR=%LOCALAPPDATA%\CelularGamepad"
if not exist "%CELULAR_GAMEPAD_DATA_DIR%" mkdir "%CELULAR_GAMEPAD_DATA_DIR%"
cd /d "%~dp0\.."
title Celular Gamepad - Jogos de PC
"%CD%\runtime\python.exe" "%CD%\server.py" --output-mode xinput
endlocal
