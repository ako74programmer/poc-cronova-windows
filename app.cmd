@echo off
setlocal

cd /d "%~dp0"
set "APP_PS1=%~dp0scripts\windows\app.ps1"
set "POWERSHELL_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%POWERSHELL_EXE%" set "POWERSHELL_EXE=powershell.exe"

if not exist "%APP_PS1%" (
    echo [app.cmd] ERROR: PowerShell launcher not found: "%APP_PS1%"
    exit /b 1
)

"%POWERSHELL_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%APP_PS1%" %*
exit /b %ERRORLEVEL%
