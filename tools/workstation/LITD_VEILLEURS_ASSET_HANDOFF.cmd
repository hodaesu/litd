@echo off
setlocal
set "SCRIPT=%~dp0veilleurs_asset_handoff.py"
where py >nul 2>nul && (
  py "%SCRIPT%" %*
  exit /b %ERRORLEVEL%
)
where python >nul 2>nul && (
  python "%SCRIPT%" %*
  exit /b %ERRORLEVEL%
)
where python3 >nul 2>nul && (
  python3 "%SCRIPT%" %*
  exit /b %ERRORLEVEL%
)
echo Python 3 introuvable.
exit /b 2
