@echo off
setlocal
cd /d "%~dp0\..\.."
where godot4 >nul 2>nul && set "GODOT=godot4"
if not defined GODOT where godot >nul 2>nul && set "GODOT=godot"
if not defined GODOT (
  echo Godot est introuvable dans PATH.
  pause
  exit /b 1
)
%GODOT% --headless --path "%CD%" --import
if errorlevel 1 (
  echo Import Godot echoue.
  pause
  exit /b 1
)
echo Import Godot termine.
pause
