@echo off
setlocal
cd /d "%~dp0\..\.."
set PYEXE=
where py >nul 2>nul && set PYEXE=py
if not defined PYEXE where python >nul 2>nul && set PYEXE=python
if not defined PYEXE where python3 >nul 2>nul && set PYEXE=python3
if not defined PYEXE (
  echo Python introuvable. Lance d'abord LITD_VEILLEURS_PC_PREPARE.cmd.
  exit /b 2
)
%PYEXE% tools\workstation\veilleurs_hardware_session.py %*
