@echo off
setlocal
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Install-FilmTools.ps1" %*
set "FilmToolsExitCode=%errorlevel%"
echo.
pause
exit /b %FilmToolsExitCode%
