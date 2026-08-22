@echo off
setlocal
cd /d "%~dp0\..\.."
python tools\music_pipeline\build_music.py doctor
if errorlevel 1 echo.
python tools\music_pipeline\build_music.py prepare
if errorlevel 1 goto :error
echo.
echo LITD music pipeline prepared. Open a NEW REAPER project and run litd_setup_project.lua.
pause
exit /b 0
:error
echo.
echo LITD music pipeline preparation failed.
pause
exit /b 1
