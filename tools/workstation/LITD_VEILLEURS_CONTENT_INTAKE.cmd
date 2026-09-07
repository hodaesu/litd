@echo off
setlocal
cd /d "%~dp0\..\.."

where py >nul 2>nul
if %errorlevel%==0 (
  set "PY=py -3"
) else (
  where python >nul 2>nul
  if %errorlevel%==0 (
    set "PY=python"
  ) else (
    echo [ERREUR] Python introuvable. Lance d'abord LITD_VEILLEURS_PC_PREPARE.cmd
    exit /b 1
  )
)

if "%~1"=="" (
  %PY% tools\godot\veilleurs_content_intake.py --list-types
  echo.
  echo Exemple preview :
  echo   LITD_VEILLEURS_CONTENT_INTAKE.cmd enemy "Goule des Braises"
  echo Exemple reservation :
  echo   LITD_VEILLEURS_CONTENT_INTAKE.cmd enemy "Goule des Braises" --reserve
  exit /b %errorlevel%
)

%PY% tools\godot\veilleurs_content_intake.py %*
exit /b %errorlevel%
