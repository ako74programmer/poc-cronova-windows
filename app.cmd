@echo off
setlocal enabledelayedexpansion

cd /d "%~dp0"

set "BINARY=cronova.exe"
set "CONFIG=cronova.yaml"
set "PORT=8090"
set "HOST=127.0.0.1"
set "DB=data/cronova.db"
set "LOGS=logs"
set "DAGS=dags"

if "%~1"=="" goto :usage

if "%~1"=="stop" goto :do_stop
if "%~1"=="status" (
    echo [app.cmd] Running cronova processes:
    tasklist /FI "IMAGENAME eq cronova.exe" 2>nul
    exit /b 0
)
if "%~1"=="start" (
    set "DEV_MODE=0"
    goto :do_start
)
if "%~1"=="start-dev" (
    set "DEV_MODE=1"
    goto :do_start
)
if "%~1"=="restart" (
    call :do_stop
    timeout /T 3 /NOBREAK >nul
    set "DEV_MODE=0"
    goto :do_start
)
if "%~1"=="restart-dev" (
    call :do_stop
    timeout /T 3 /NOBREAK >nul
    set "DEV_MODE=1"
    goto :do_start
)

echo [app.cmd] Unknown command: %~1
exit /b 1

:usage
echo Usage: app.cmd [start^|start-dev^|restart^|restart-dev^|stop^|status]
echo.
echo   start       - build binary if needed, kill old process and start cronova with auth
echo   start-dev   - same as start but with auth disabled and a temp DB (for testing)
echo   restart     - stop and start again with auth
echo   restart-dev - stop and start again in dev mode
echo   stop        - kill all cronova processes
echo   status      - show running cronova processes
exit /b 1

:do_stop
echo [app.cmd] Stopping all cronova processes...
taskkill /F /IM cronova.exe 2>nul
timeout /T 2 /NOBREAK >nul
echo [app.cmd] Stopped.
exit /b 0

:do_start
if not exist "%BINARY%" (
    echo [app.cmd] Binary not found, building...
    go build -o "%BINARY%" ./cmd/cronova
    if errorlevel 1 (
        echo [app.cmd] Build failed.
        exit /b 1
    )
)

echo [app.cmd] Stopping any leftover cronova processes...
taskkill /F /IM cronova.exe 2>nul
timeout /T 3 /NOBREAK >nul

if not exist "data" mkdir data
if not exist "%LOGS%" mkdir "%LOGS%"
if not exist "%DAGS%" mkdir "%DAGS%"

if "!DEV_MODE!"=="1" (
    set "DB=.tmp/dev-cronova.db"
    if not exist ".tmp" mkdir .tmp
    if exist "!DB!" del /F /Q "!DB!"
    echo [app.cmd] Starting cronova dev mode on http://%HOST%:%PORT% (auth=false)
    "%BINARY%" serve -http %HOST%:%PORT% -db "!DB!" -dags "%DAGS%" -logs "%LOGS%" -auth=false
    exit /b 0
)

echo [app.cmd] Starting cronova on http://%HOST%:%PORT%
"%BINARY%" serve -config "%CONFIG%" -http %HOST%:%PORT%
exit /b 0
