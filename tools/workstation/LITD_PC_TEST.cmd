@echo off
setlocal
cd /d "%~dp0\..\.."
python tools\workstation\pc_preflight.py --repo "%CD%" --run-tests
if errorlevel 1 (
  echo.
  echo Verification incomplete. Consultez local\reports\pc_preflight.json
  pause
  exit /b 1
)
echo.
echo Tous les controles automatisables sont verts.
pause
