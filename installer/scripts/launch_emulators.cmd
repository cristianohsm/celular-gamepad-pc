@echo off
setlocal
set "CELULAR_GAMEPAD_DATA_DIR=%LOCALAPPDATA%\CelularGamepad"
if not exist "%CELULAR_GAMEPAD_DATA_DIR%" mkdir "%CELULAR_GAMEPAD_DATA_DIR%"
cd /d "%~dp0\.."
title Celular Gamepad - Emuladores
"%CD%\runtime\python.exe" -B "%CD%\server.py" --output-mode keyboard
endlocal
