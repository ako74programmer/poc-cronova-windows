[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('start', 'start-dev', 'restart', 'restart-dev', 'stop', 'status')]
    [string]$Command,

    [ValidateRange(1, 65535)]
    [int]$Port = 8090
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Binary = Join-Path $RepoRoot 'cronova.exe'
$Config = Join-Path $RepoRoot 'cronova.yaml'
$HostAddress = '127.0.0.1'
$Db = Join-Path $RepoRoot 'data\cronova.db'
$Logs = Join-Path $RepoRoot 'logs'
$Dags = Join-Path $RepoRoot 'dags'
$ToolchainScript = Join-Path $PSScriptRoot 'detect-toolchain.ps1'

function Get-RepoCronovaProcesses {
    # Only processes started from this checkout; never the installed service binary.
    @(Get-CimInstance Win32_Process -Filter "name = 'cronova.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.ExecutablePath -and ($_.ExecutablePath -ieq $Binary) })
}

function Stop-CronovaProcesses {
    $processes = Get-RepoCronovaProcesses
    foreach ($process in $processes) {
        try {
            Stop-Process -Id $process.ProcessId -Force -ErrorAction Stop
        } catch {
            throw "Failed to stop cronova.exe process $($process.ProcessId): $($_.Exception.Message)"
        }
    }
    Start-Sleep -Seconds 2
    $remaining = Get-RepoCronovaProcesses
    if ($remaining.Count -gt 0) {
        throw 'cronova.exe is still running after stop request.'
    }
    Start-Sleep -Seconds 15
}

function Show-CronovaStatus {
    $processes = Get-RepoCronovaProcesses
    if ($processes.Count -eq 0) {
        Write-Host '[app.ps1] No running cronova.exe processes.'
        return
    }
    Write-Host '[app.ps1] Running cronova.exe processes:'
    $processes | Select-Object ProcessId, ExecutablePath, CommandLine | Format-Table -AutoSize
}

function Configure-Toolchain {
    if (-not (Test-Path $ToolchainScript)) {
        Write-Host '[app.ps1] Toolchain discovery script not found; relying on inherited environment.'
        return
    }

    Write-Host "[app.ps1] Running toolchain detector: `"$ToolchainScript`""
    $lines = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ToolchainScript 2>$null
    foreach ($line in $lines) {
        if ($line -notmatch '=') { continue }
        $name, $value = $line -split '=', 2
        if (-not $value) { continue }
        if (-not (Get-ChildItem Env:$name -ErrorAction SilentlyContinue)) {
            [Environment]::SetEnvironmentVariable($name, $value)
            Set-Item -Path "Env:$name" -Value $value
        }
    }

    if ($env:CRONOVA_PYTHON) { $env:PATH = "$(Split-Path -Parent $env:CRONOVA_PYTHON);$env:PATH" }
    if ($env:CRONOVA_NODE) { $env:PATH = "$(Split-Path -Parent $env:CRONOVA_NODE);$env:PATH" }
    if ($env:CRONOVA_JAVA_HOME) { $env:PATH = "$env:CRONOVA_JAVA_HOME\bin;$env:PATH" }
    if ($env:CRONOVA_MAVEN_HOME) { $env:PATH = "$env:CRONOVA_MAVEN_HOME\bin;$env:PATH" }
    $env:CRONOVA_WINDOWS_PATH = $env:PATH

    Write-Host '[app.ps1] Runtime tool paths for this Cronova process:'
    if ($env:CRONOVA_WINDOWS_PATH) { Write-Host '  CRONOVA_WINDOWS_PATH inherited' } else { Write-Host '  CRONOVA_WINDOWS_PATH: not set' }
    if ($env:CRONOVA_PYTHON) { Write-Host "  CRONOVA_PYTHON=$env:CRONOVA_PYTHON" } else { Write-Host '  Python: not detected' }
    if ($env:CRONOVA_NODE) { Write-Host "  CRONOVA_NODE=$env:CRONOVA_NODE" } else { Write-Host '  Node: not detected' }
    if ($env:CRONOVA_NPM) { Write-Host "  CRONOVA_NPM=$env:CRONOVA_NPM" } else { Write-Host '  npm: not detected' }
    if ($env:CRONOVA_JAVA_HOME) { Write-Host "  CRONOVA_JAVA_HOME=$env:CRONOVA_JAVA_HOME" } elseif ($env:JAVA_HOME) { Write-Host "  JAVA_HOME=$env:JAVA_HOME" } else { Write-Host '  Java: not detected' }
    if ($env:CRONOVA_MAVEN_HOME) { Write-Host "  CRONOVA_MAVEN_HOME=$env:CRONOVA_MAVEN_HOME" } elseif ($env:MAVEN_HOME) { Write-Host "  MAVEN_HOME=$env:MAVEN_HOME" } else { Write-Host '  Maven: not detected' }
}

function Ensure-Directories {
    foreach ($path in @((Join-Path $RepoRoot 'data'), $Logs, $Dags)) {
        if (-not (Test-Path $path)) {
            New-Item -ItemType Directory -Force -Path $path | Out-Null
        }
    }
}

function Build-Cronova {
    Write-Host '[app.ps1] Building cronova from the current working tree...'
    & go build -o $Binary '.\cmd\cronova'
    if ($LASTEXITCODE -ne 0) {
        throw '[app.ps1] Build failed.'
    }
}

function Start-Cronova {
    param([switch]$DevMode)

    Build-Cronova
    Configure-Toolchain
    Write-Host '[app.ps1] Stopping any leftover cronova processes...'
    Stop-CronovaProcesses
    Ensure-Directories

    if ($DevMode) {
        $devDb = Join-Path $RepoRoot '.tmp\dev-cronova.db'
        if (-not (Test-Path (Split-Path -Parent $devDb))) {
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $devDb) | Out-Null
        }
        if (Test-Path $devDb) {
            Remove-Item $devDb -Force
        }
        Write-Host "[app.ps1] Starting cronova dev mode on http://$HostAddress`:$Port (auth=false)"
        & $Binary serve -http "$HostAddress`:$Port" -db $devDb -dags $Dags -logs $Logs -auth=false
        return
    }

    Write-Host "[app.ps1] Starting cronova on http://$HostAddress`:$Port"
    & $Binary serve -config $Config -http "$HostAddress`:$Port" -auth=true
}

switch ($Command) {
    'stop' { Write-Host '[app.ps1] Stopping all cronova processes...'; Stop-CronovaProcesses; Write-Host '[app.ps1] Stopped.' }
    'status' { Show-CronovaStatus }
    'start' { Start-Cronova }
    'start-dev' { Start-Cronova -DevMode }
    'restart' { Write-Host '[app.ps1] Stopping all cronova processes...'; Stop-CronovaProcesses; Start-Cronova }
    'restart-dev' { Write-Host '[app.ps1] Stopping all cronova processes...'; Stop-CronovaProcesses; Start-Cronova -DevMode }
    default {
        Write-Host 'Usage: .\scripts\windows\app.ps1 [start|start-dev|restart|restart-dev|stop|status]'
        exit 1
    }
}
