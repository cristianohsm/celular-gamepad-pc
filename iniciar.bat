@echo off
setlocal
cd /d "%~dp0"
title Celular Gamepad para PC

if exist "runtime\python.exe" (
  "runtime\python.exe" server.py
  goto :fim
)

where py >nul 2>nul
if %errorlevel%==0 (
  py -3 server.py
  goto :fim
)

where python >nul 2>nul
if %errorlevel%==0 (
  python server.py
  goto :fim
)

call "%~dp0INICIAR_EM_QUALQUER_PC.bat"

:fim
endlocal
