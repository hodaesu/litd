@echo off
setlocal
cd /d "%~dp0\..\.."

set "PYTHON_CMD="
where py >nul 2>nul && set "PYTHON_CMD=py -3"
if not defined PYTHON_CMD where python >nul 2>nul && set "PYTHON_CMD=python"
if not defined PYTHON_CMD (
  echo [LITD Les Veilleurs] Python 3 est requis.
  exit /b 2
)

echo [LITD Les Veilleurs] Preflight Godot 4.3...
%PYTHON_CMD% tools\workstation\veilleurs_pc_preflight.py --run-tests %*
set "RESULT=%ERRORLEVEL%"

if "%RESULT%"=="0" (
  echo.
  echo [OK] Le poste est pret pour la validation materielle des Veilleurs.
  echo Rapport : local\reports\veilleurs_pc_preflight.json
) else (
  echo.
  echo [BLOQUE] Consulter local\reports\veilleurs_pc_preflight.json
)

pause
exit /b %RESULT%
