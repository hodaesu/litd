@echo off
setlocal
cd /d "%~dp0\..\.."
python tools\music_pipeline\build_music.py finalize
if errorlevel 1 goto :error
echo.
echo LITD stems validated, synced into Godot, and imported successfully.
pause
exit /b 0
:error
echo.
echo LITD music finalization failed. See the errors above.
pause
exit /b 1
