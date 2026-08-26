@echo off
setlocal
cd /d "%~dp0\..\.."
powershell -NoProfile -ExecutionPolicy Bypass -File "unreal\LITDValidation\Tools\Setup-UnrealPrototype.ps1"
if errorlevel 1 (
  echo.
  echo Compilation ou lancement Unreal echoue. Verifiez Visual Studio, le SDK Windows et Unreal 5.8.
  pause
  exit /b 1
)
