@echo off
setlocal
cd /d "%~dp0\..\.."

if "%~1"=="" goto prepare
if /I "%~1"=="doctor" goto doctor
if /I "%~1"=="prepare" goto prepare
if /I "%~1"=="build" goto build
if /I "%~1"=="resume" goto build
if /I "%~1"=="approve-preproduction" goto preproduction
if /I "%~1"=="approve-art" goto art
if /I "%~1"=="approve-audio" goto audio
if /I "%~1"=="finalize" goto finalize

echo Usage: %~nx0 doctor^|prepare^|build^|approve-preproduction^|approve-art^|approve-audio^|finalize
exit /b 2

:doctor
python tools\cinematics\run_opening_pipeline.py doctor
goto end

:prepare
python tools\cinematics\run_opening_pipeline.py prepare
goto end

:build
python tools\cinematics\run_opening_pipeline.py execute
goto end

:preproduction
python tools\cinematics\run_opening_pipeline.py execute --approve-preproduction
goto end

:art
python tools\cinematics\run_opening_pipeline.py execute --approve-preproduction --approve-art
goto end

:audio
python tools\cinematics\run_opening_pipeline.py execute --approve-preproduction --approve-art --approve-audio
goto end

:finalize
python tools\cinematics\run_opening_pipeline.py execute --approve-preproduction --approve-art --approve-audio --approve-final
goto end

:end
if errorlevel 1 (
  echo.
  echo Pipeline interrompu. Consultez local\reports\opening_bird_intro\pipeline_state.json
  pause
  exit /b 1
)
echo.
echo Etape terminee. Le pipeline peut reprendre sans recommencer les sorties valides.
pause
