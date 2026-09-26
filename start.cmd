@echo off
setlocal enabledelayedexpansion

REM Start cronova scheduler + web console on Windows.
REM Uses cronova.yaml in the project root and creates required dirs if missing.

cd /d "%~dp0"

set BINARY=cronova.exe
set CONFIG=cronova.yaml
if not defined CRONOVA_BASH_PATH set "CRONOVA_BASH_PATH=%ProgramFiles%\Git\bin\bash.exe"

if not exist "%CRONOVA_BASH_PATH%" if exist "%ProgramFiles%\Git\usr\bin\bash.exe" set "CRONOVA_BASH_PATH=%ProgramFiles%\Git\usr\bin\bash.exe"
if not exist "%CRONOVA_BASH_PATH%" (
    echo [start.cmd] ERROR: Git for Windows bash.exe not found.
    echo [start.cmd] Set CRONOVA_BASH_PATH to the full path of Git Bash.
    exit /b 1
)

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

REM Respect JAVA_HOME/MAVEN_HOME supplied by the operator or system.
if not defined CRONOVA_JAVA_HOME if defined JAVA_HOME set "CRONOVA_JAVA_HOME=%JAVA_HOME%"
if not defined JAVA_HOME if defined CRONOVA_JAVA_HOME set "JAVA_HOME=%CRONOVA_JAVA_HOME%"
if not defined CRONOVA_MAVEN_HOME if defined MAVEN_HOME set "CRONOVA_MAVEN_HOME=%MAVEN_HOME%"
if not defined MAVEN_HOME if defined CRONOVA_MAVEN_HOME set "MAVEN_HOME=%CRONOVA_MAVEN_HOME%"
if not defined CRONOVA_PYTHON for /f "delims=" %%P in ('where python 2^>nul') do if not defined CRONOVA_PYTHON set "CRONOVA_PYTHON=%%P"
if not defined CRONOVA_NODE for /f "delims=" %%P in ('where node 2^>nul') do if not defined CRONOVA_NODE set "CRONOVA_NODE=%%P"
if not defined CRONOVA_NPM for /f "delims=" %%P in ('where npm 2^>nul') do if not defined CRONOVA_NPM set "CRONOVA_NPM=%%P"
if defined JAVA_HOME set "PATH=%JAVA_HOME%\bin;%PATH%"
if defined MAVEN_HOME set "PATH=%MAVEN_HOME%\bin;%PATH%"

echo [start.cmd] JAVA_HOME=%JAVA_HOME%
echo [start.cmd] MAVEN_HOME=%MAVEN_HOME%
echo [start.cmd] CRONOVA_BASH_PATH=%CRONOVA_BASH_PATH%
echo [start.cmd] CRONOVA_PYTHON=%CRONOVA_PYTHON%
echo [start.cmd] CRONOVA_NODE=%CRONOVA_NODE%
echo [start.cmd] CRONOVA_NPM=%CRONOVA_NPM%

"%BINARY%" serve -config "%CONFIG%"
