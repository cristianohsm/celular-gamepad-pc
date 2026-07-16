@echo off
setlocal
cd /d "%~dp0"
title Testes - Celular Gamepad para PC

where py >nul 2>nul
if %errorlevel%==0 (
  py -3 -m py_compile server.py test_server.py
  if errorlevel 1 goto :falha
  py -3 -m unittest -v test_server.py
  if errorlevel 1 goto :falha
  goto :ok
)

where python >nul 2>nul
if %errorlevel%==0 (
  python -m py_compile server.py test_server.py
  if errorlevel 1 goto :falha
  python -m unittest -v test_server.py
  if errorlevel 1 goto :falha
  goto :ok
)

echo.
echo Python 3 nao foi encontrado.
goto :fim

:ok
echo.
echo Todos os testes foram aprovados.
goto :fim

:falha
echo.
echo Houve falha nos testes.

:fim
pause
endlocal
