[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory = $true)]
    [ValidateSet('start', 'stop', 'restart', 'status', 'uninstall')]
    [string]$Command,
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'Programs\Cronova'),
    [string]$DataDir = (Join-Path $env:LOCALAPPDATA 'Cronova'),
    # uninstall: also delete data (DB, logs, DAGs, workspaces).
    [switch]$Purge
)

# Control a per-user (no admin) Cronova install.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'cronova-user-common.ps1')

switch ($Command) {
    'start' { Start-CronovaUser -InstallDir $InstallDir -DataDir $DataDir }
    'stop' { Stop-CronovaUser -InstallDir $InstallDir; Write-Host 'Cronova (per-user) stopped.' }
    'restart' { Stop-CronovaUser -InstallDir $InstallDir; Start-CronovaUser -InstallDir $InstallDir -DataDir $DataDir }
    'status' {
        $procs = Get-CronovaUserProcesses -InstallDir $InstallDir
        $task = Get-ScheduledTask -TaskName $script:CronovaUserTaskName -ErrorAction SilentlyContinue
        $port = Get-CronovaUserPort -DataDir $DataDir
        Write-Host ("Install : {0}" -f $InstallDir)
        Write-Host ("Data    : {0}" -f $DataDir)
        Write-Host ("Autostart: {0}" -f $(if ($task) { "scheduled task '$($task.TaskName)' ($($task.State))" } elseif (Test-Path (Join-Path ([Environment]::GetFolderPath('Startup')) 'Cronova.lnk')) { 'Startup folder shortcut' } else { 'none' }))
        foreach ($p in $procs) { Write-Host ("{0,-22} RUNNING (pid {1})" -f $p.Name, $p.ProcessId) }
        if (-not $procs) { Write-Host 'Processes: not running'; exit 1 }
        Write-Host "Console : http://127.0.0.1:$port/"
    }
    'uninstall' {
        Stop-CronovaUser -InstallDir $InstallDir
        Unregister-CronovaUserTask
        Remove-Item $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
        if ($Purge) {
            Remove-Item $DataDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Cronova (per-user) removed, including data in $DataDir."
        }
        else {
            Write-Host "Cronova (per-user) removed. Data kept in $DataDir (use -Purge to delete)."
        }
    }
}
