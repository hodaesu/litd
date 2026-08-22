@echo off
setlocal
cd /d "%~dp0\..\.."
powershell -NoProfile -ExecutionPolicy Bypass -File "tools\workstation\LITD_PC_SETUP.ps1" -Install
pause
