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

set "TESTER_ID=developer-selftest"
if not "%~1"=="" set "TESTER_ID=%~1"

echo [LITD Les Veilleurs] Premier playtest Windows - Godot 4.7.x
echo Testeur : %TESTER_ID%
echo.

%PYTHON_CMD% tools\playtest\run_veilleurs_first_playtest.py --tester-id "%TESTER_ID%"
set "RESULT=%ERRORLEVEL%"

if "%RESULT%"=="0" (
  echo.
  echo [OK] Build lancee. Les preuves restent NOT_RUN tant qu'elles ne sont pas remplies apres observation reelle.
  echo Dossiers de session : local\playtests\
) else (
  echo.
  echo [BLOQUE] Consulter local\reports\veilleurs_pc_preflight.json et local\reports\veilleurs_first_playtest_export.log
)

pause
exit /b %RESULT%
