[CmdletBinding()]
param(
    [int]$Port = 18090,
    [int]$ExecutorPort = 19190
)

# Verifies Cronova runs tasks with PowerShell only: no Bash on PATH, `powershell`
# and default-typed tasks succeed, `shell`/`bash` task types are rejected.
# Uses an isolated instance (own ports, temp data) and never touches the
# installed Windows services, so it runs without administrator rights.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Work = Join-Path ([IO.Path]::GetTempPath()) ("cronova-psonly-" + [guid]::NewGuid())
$Bin = Join-Path $Work 'bin'
$Dags = Join-Path $Work 'dags'
$Logs = Join-Path $Work 'logs'
$Db = Join-Path $Work 'cronova.db'
New-Item -ItemType Directory -Force -Path $Bin, $Dags, $Logs, (Join-Path $Work 'state') | Out-Null

$procs = @()
try {
    Push-Location $RepoRoot
    try {
        $env:GOOS = 'windows'
        & go build -o (Join-Path $Bin 'cronova.exe') ./cmd/cronova
        if ($LASTEXITCODE -ne 0) { throw 'go build cronova failed' }
        & go build -o (Join-Path $Bin 'cronova-executor.exe') ./cmd/cronova-executor
        if ($LASTEXITCODE -ne 0) { throw 'go build cronova-executor failed' }
    } finally { Pop-Location }

    Set-Content -Path (Join-Path $Dags 'ps_only.yaml') -Value @'
dag_id: ps_only
start_date: "2026-01-01"
tasks:
  - id: explicit
    type: powershell
    command: 'Write-Output ("edition=" + $PSVersionTable.PSEdition)'
  - id: default_type
    command: 'if (Get-Command bash.exe -ErrorAction SilentlyContinue) { Write-Output "bash=present" } else { Write-Output "bash=absent" }'
    deps: [explicit]
'@
    Set-Content -Path (Join-Path $Dags 'legacy_shell.yaml') -Value "dag_id: legacy_shell`ntasks:`n  - id: a`n    type: shell`n    command: echo hi`n"
    Set-Content -Path (Join-Path $Dags 'legacy_bash.yaml') -Value "dag_id: legacy_bash`ntasks:`n  - id: a`n    type: bash`n    command: echo hi`n"

    # PATH without any directory that contains bash.exe/sh.exe (Git, MSYS, WSL launcher).
    $cleanPath = ($env:PATH -split ';' | Where-Object {
            $_ -and -not (Test-Path (Join-Path $_ 'bash.exe')) -and -not (Test-Path (Join-Path $_ 'sh.exe'))
        }) -join ';'
    $savedPath = $env:PATH
    $env:PATH = $cleanPath
    try {
        $procs += Start-Process -FilePath (Join-Path $Bin 'cronova-executor.exe') -ArgumentList @('-sock', "127.0.0.1:$ExecutorPort", '-state-dir', (Join-Path $Work 'state'), '-workdir', $Work) -WindowStyle Hidden -PassThru
        Start-Sleep -Seconds 2
        $serveLog = Join-Path $Work 'serve.log'
        $procs += Start-Process -FilePath (Join-Path $Bin 'cronova.exe') -ArgumentList @('serve', '-http', "127.0.0.1:$Port", '-db', $Db, '-dags', $Dags, '-logs', $Logs, '-executor', "tcp://127.0.0.1:$ExecutorPort", '-auth=false') -WindowStyle Hidden -RedirectStandardError $serveLog -PassThru
    } finally { $env:PATH = $savedPath }

    $up = $false
    for ($i = 0; $i -lt 30; $i++) {
        try { Invoke-WebRequest -UseBasicParsing "http://127.0.0.1:$Port/" -TimeoutSec 2 | Out-Null; $up = $true; break } catch { Start-Sleep 1 }
    }
    if (-not $up) { throw "Cronova did not start on port $Port. Log: $(Get-Content $serveLog -Raw)" }

    $ErrorActionPreference = 'Continue'
    & (Join-Path $Bin 'cronova.exe') trigger -db $Db -dags $Dags ps_only 2>&1 | Out-Null
    $ErrorActionPreference = 'Stop'

    $runLogs = $null
    for ($i = 0; $i -lt 30 -and -not $runLogs; $i++) {
        Start-Sleep 1
        $runLogs = Get-ChildItem (Join-Path $Logs 'ps_only') -Directory -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
    }
    if (-not $runLogs) { throw "Run for ps_only did not start. Log: $(Get-Content $serveLog -Raw)" }

    $results = @{}
    for ($i = 0; $i -lt 60 -and $results.Count -lt 2; $i++) {
        Start-Sleep 1
        foreach ($task in 'explicit', 'default_type') {
            $file = Join-Path $runLogs "$task.log"
            if (-not $results.ContainsKey($task) -and (Test-Path $file)) {
                $text = Get-Content $file -Raw
                if ($text -match 'exited with code (\d+)') { $results[$task] = @{ Code = [int]$Matches[1]; Text = $text } }
            }
        }
    }

    $failures = @()
    foreach ($task in 'explicit', 'default_type') {
        if (-not $results.ContainsKey($task)) { $failures += "task $task did not finish"; continue }
        if ($results[$task].Code -ne 0) { $failures += "task $task exited with $($results[$task].Code)" }
    }
    if ($results.ContainsKey('explicit') -and $results['explicit'].Text -notmatch 'edition=Desktop|edition=Core') { $failures += 'explicit task did not run in PowerShell' }
    if ($results.ContainsKey('default_type') -and $results['default_type'].Text -notmatch 'bash=absent') { $failures += 'bash.exe was reachable from the task' }

    $serveText = Get-Content $serveLog -Raw
    if ($serveText -notmatch 'legacy_shell[^\r\n]*use type: powershell') { $failures += 'type: shell was not rejected' }
    if ($serveText -notmatch 'legacy_bash[^\r\n]*unsupported type \\?"bash\\?"') { $failures += 'type: bash was not rejected' }

    if ($failures.Count -gt 0) {
        $failures | ForEach-Object { Write-Host "FAIL: $_" -ForegroundColor Red }
        throw "PowerShell-only runtime test failed ($($failures.Count) issue(s)). Work dir: $Work"
    }

    Write-Host 'OK: powershell + default-type tasks ran in PowerShell without Bash; shell/bash types rejected.'
} finally {
    foreach ($p in $procs) { if ($p -and -not $p.HasExited) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } }
    Start-Sleep 1
    if (Test-Path $Work) { Remove-Item $Work -Recurse -Force -ErrorAction SilentlyContinue }
}
