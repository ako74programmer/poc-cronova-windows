@echo off
rem Double-click installer for Cronova. Windows Services when you are an
rem administrator (UAC prompt), otherwise a per-user install without admin rights.
echo.
echo Installation guide / Instrukcja instalacji:
echo   English: README-INSTALL.en.md
echo   Polski:  README-INSTALL.md
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" %*
if errorlevel 1 (
  echo.
  echo Installation failed. See the messages above.
)
pause
