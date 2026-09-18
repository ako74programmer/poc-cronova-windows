@echo off
setlocal enabledelayedexpansion

REM Start cronova scheduler + web console on Windows.
REM Uses cronova.yaml in the project root and creates required dirs if missing.

cd /d "%~dp0"

set BINARY=cronova.exe
set CONFIG=cronova.yaml

if not exist "%BINARY%" (
    echo [start.cmd] ERROR: %BINARY% not found in project root.
    echo [start.cmd] Build it first with: go build -o %BINARY% ./cmd/cronova
    exit /b 1
)

if not exist "%CONFIG%" (
    echo [start.cmd] WARNING: %CONFIG% not found. Using built-in defaults.
)

if not exist "data" mkdir data
if not exist "logs" mkdir logs
if not exist "dags" mkdir dags

echo [start.cmd] Starting cronova serve...
echo [start.cmd] Console will be available at http://127.0.0.1:8090

"%BINARY%" serve -config "%CONFIG%"
