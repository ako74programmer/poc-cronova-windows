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
if not defined CRONOVA_BASH_PATH set "CRONOVA_BASH_PATH=%ProgramFiles%\Git\usr\bin\bash.exe"
if not exist "%CRONOVA_BASH_PATH%" if exist "%ProgramFiles%\Git\bin\bash.exe" set "CRONOVA_BASH_PATH=%ProgramFiles%\Git\bin\bash.exe"

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

call :configure_toolchain

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

:configure_toolchain
set "TOOLCHAIN_SCRIPT=%~dp0scripts\windows\detect-toolchain.ps1"
if not exist "%TOOLCHAIN_SCRIPT%" (
    echo [app.cmd] Toolchain discovery script not found; relying on inherited environment.
    goto :eof
)

set "POWERSHELL_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%POWERSHELL_EXE%" set "POWERSHELL_EXE=powershell.exe"
echo [app.cmd] Running toolchain detector: "%TOOLCHAIN_SCRIPT%"
for /f "tokens=1,* delims==" %%A in ('"%POWERSHELL_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%TOOLCHAIN_SCRIPT%"') do (
    if /i "%%A"=="CRONOVA_PYTHON" if not defined CRONOVA_PYTHON set "CRONOVA_PYTHON=%%B"
    if /i "%%A"=="CRONOVA_NODE" if not defined CRONOVA_NODE set "CRONOVA_NODE=%%B"
    if /i "%%A"=="CRONOVA_NPM" if not defined CRONOVA_NPM set "CRONOVA_NPM=%%B"
    if /i "%%A"=="CRONOVA_JAVA_HOME" if not defined CRONOVA_JAVA_HOME set "CRONOVA_JAVA_HOME=%%B"
    if /i "%%A"=="CRONOVA_MAVEN_HOME" if not defined CRONOVA_MAVEN_HOME set "CRONOVA_MAVEN_HOME=%%B"
)

echo [app.cmd] Runtime tool paths for this Cronova process:
if defined CRONOVA_PYTHON (echo   CRONOVA_PYTHON=!CRONOVA_PYTHON!) else (echo   Python: not detected)
if defined CRONOVA_NODE (echo   CRONOVA_NODE=!CRONOVA_NODE!) else (echo   Node: not detected)
if defined CRONOVA_NPM (echo   CRONOVA_NPM=!CRONOVA_NPM!) else (echo   npm: not detected)
if defined CRONOVA_JAVA_HOME (echo   CRONOVA_JAVA_HOME=!CRONOVA_JAVA_HOME!) else if defined JAVA_HOME (echo   JAVA_HOME=!JAVA_HOME!) else (echo   Java: not detected)
if defined CRONOVA_MAVEN_HOME (echo   CRONOVA_MAVEN_HOME=!CRONOVA_MAVEN_HOME!) else if defined MAVEN_HOME (echo   MAVEN_HOME=!MAVEN_HOME!) else (echo   Maven: not detected)
goto :eof
