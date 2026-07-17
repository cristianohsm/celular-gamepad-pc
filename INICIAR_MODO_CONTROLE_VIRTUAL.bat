@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title Celular Gamepad - Controle Virtual Experimental

net session >nul 2>&1
if not %errorlevel%==0 (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ativar_modo_controle_virtual.ps1"
if errorlevel 1 (
  echo Nao foi possivel ativar o modo Controle Virtual.
  pause
  exit /b 1
)
call "%~dp0iniciar.bat"
