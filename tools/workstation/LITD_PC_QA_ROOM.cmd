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
%GODOT% --path "%CD%" res://scenes/qa/qa_validation_room.tscn
if errorlevel 1 (
  echo La salle de validation n'a pas pu etre ouverte.
  pause
  exit /b 1
)
