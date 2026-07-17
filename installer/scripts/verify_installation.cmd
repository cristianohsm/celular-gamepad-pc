@echo off
setlocal
cd /d "%~dp0\.."
echo === Runtime Python ===
"runtime\python.exe" --version
echo.
echo === Bridge e HIDMaestro ===
if exist "bridge\PhoneGamepad.Bridge.exe" (
  "bridge\PhoneGamepad.Bridge.exe" --check
) else (
  echo Modo Jogos de PC nao instalado. O modo Emuladores continua disponivel.
)
echo.
echo Dados do usuario: %LOCALAPPDATA%\CelularGamepad
pause
endlocal
