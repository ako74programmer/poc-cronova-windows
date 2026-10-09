[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$InstallDir,
    [Parameter(Mandatory = $true)][string]$DataDir,
    [int]$ExecutorPort = 19190
)

# Foreground supervisor for the per-user install (started by the logon task).
# Runs executor + scheduler and restarts the pair when either dies (Task Scheduler
# only retries failed starts, not exits). Gives up after 5 crashes in 5 minutes.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$log = Join-Path $DataDir 'logs\cronova-user.log'
New-Item -ItemType Directory -Force -Path (Split-Path $log) | Out-Null
function Write-Log([string]$m) { Add-Content -LiteralPath $log -Value ("{0:u} {1}" -f (Get-Date), $m) }

$envFile = Join-Path $DataDir 'cronova.env'
if (Test-Path $envFile) {
    foreach ($line in [IO.File]::ReadAllLines($envFile)) {
        if ($line -match '^(?<k>[A-Za-z_][A-Za-z0-9_]*)=(?<v>.*)$') {
            [Environment]::SetEnvironmentVariable($Matches.k, $Matches.v, 'Process')
            if ($Matches.k -eq 'CRONOVA_JAVA_HOME') { $env:JAVA_HOME = $Matches.v; $env:Path = (Join-Path $Matches.v 'bin') + ';' + $env:Path }
            if ($Matches.k -eq 'CRONOVA_MAVEN_HOME') { $env:MAVEN_HOME = $Matches.v; $env:Path = (Join-Path $Matches.v 'bin') + ';' + $env:Path }
            if ($Matches.k -in 'CRONOVA_PYTHON', 'CRONOVA_NODE', 'CRONOVA_NPM') { $env:Path = (Split-Path -Parent $Matches.v) + ';' + $env:Path }
        }
    }
}

$exec = Join-Path $InstallDir 'cronova-executor.exe'
$sched = Join-Path $InstallDir 'cronova.exe'
$endpoint = "127.0.0.1:$ExecutorPort"

$crashes = New-Object System.Collections.Generic.List[datetime]
while ($true) {
    Write-Log "starting executor ($endpoint) and scheduler"
    $e = Start-Process -FilePath $exec -WorkingDirectory $DataDir -WindowStyle Hidden -PassThru `
        -RedirectStandardError (Join-Path $DataDir 'logs\executor.err.log') -RedirectStandardOutput (Join-Path $DataDir 'logs\executor.out.log') `
        -ArgumentList @('-sock', $endpoint, '-state-dir', (Join-Path $DataDir 'state'), '-workdir', $DataDir)
    Start-Sleep -Seconds 2
    $s = Start-Process -FilePath $sched -WorkingDirectory $DataDir -WindowStyle Hidden -PassThru `
        -RedirectStandardError (Join-Path $DataDir 'logs\scheduler.err.log') -RedirectStandardOutput (Join-Path $DataDir 'logs\scheduler.out.log') `
        -ArgumentList @('serve', '-config', (Join-Path $DataDir 'cronova.yaml'), '-db', (Join-Path $DataDir 'cronova.db'),
            '-dags', (Join-Path $DataDir 'dags'), '-logs', (Join-Path $DataDir 'logs'), '-projects', (Join-Path $DataDir 'projects'),
            '-workspaces', (Join-Path $DataDir 'workspaces'), '-executor', "tcp://$endpoint")

    try {
        while (-not $e.HasExited -and -not $s.HasExited) { Start-Sleep -Seconds 2 }
    }
    finally {
        $died = if ($e.HasExited) { "executor (exit $($e.ExitCode))" } elseif ($s.HasExited) { "scheduler (exit $($s.ExitCode))" } else { 'supervisor' }
        Write-Log "$died stopped; stopping the pair"
        foreach ($p in $s, $e) { if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } }
    }

    $now = Get-Date
    $crashes.Add($now)
    $crashes.RemoveAll([Predicate[datetime]] { param($d) $d -lt $now.AddMinutes(-5) }) | Out-Null
    if ($crashes.Count -ge 5) { Write-Log 'too many crashes (5 in 5 min); giving up'; exit 1 }
    Start-Sleep -Seconds 10
}