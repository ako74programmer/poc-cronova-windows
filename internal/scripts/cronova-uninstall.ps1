[CmdletBinding()]
param(
    [string[]]$ServiceName = @('Cronova', 'CronovaExecutor'),
    [string]$InstallDir = (Join-Path $env:ProgramFiles 'Cronova'),
    [string]$DataDir = (Join-Path $env:ProgramData 'Cronova'),
    [switch]$Purge,
    [switch]$KillAll,
    [int]$RetrySeconds = 15
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'cronova-service-common.ps1')

$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script from an elevated (Administrator) PowerShell.'
}

function Get-ProcessTreeIds {
    param([Parameter(Mandatory = $true)][int[]]$RootIds)

    $all = @(Get-CimInstance Win32_Process -Property ProcessId, ParentProcessId)
    $result = New-Object System.Collections.Generic.List[int]
    $queue = New-Object System.Collections.Generic.Queue[int]
    foreach ($id in $RootIds) { $queue.Enqueue($id) }
    while ($queue.Count -gt 0) {
        $current = $queue.Dequeue()
        if ($result.Contains($current)) { continue }
        $result.Add($current)
        foreach ($child in $all | Where-Object { $_.ParentProcessId -eq $current -and $_.ProcessId -ne $current }) {
            $queue.Enqueue([int]$child.ProcessId)
        }
    }
    return $result.ToArray()
}

function Stop-ProcessTree {
    param([int[]]$RootIds)

    $roots = @($RootIds | Where-Object { $_ -gt 0 -and $_ -ne $PID } | Sort-Object -Unique)
    if ($roots.Count -eq 0) { return }

    $ids = @(Get-ProcessTreeIds -RootIds $roots)
    # Kill children first so nothing gets re-parented or respawned.
    [array]::Reverse($ids)
    foreach ($id in $ids) {
        if ($id -eq $PID) { continue }
        $proc = Get-Process -Id $id -ErrorAction SilentlyContinue
        if ($proc) {
            Write-Host "Stopping $($proc.ProcessName) (PID $id)"
            Stop-Process -Id $id -Force -ErrorAction SilentlyContinue
        }
    }
}

function Get-CronovaProcessIds {
    $installPrefix = $InstallDir.TrimEnd('\') + '\'
    $ids = @()
    foreach ($p in Get-CimInstance Win32_Process -Property ProcessId, Name, ExecutablePath) {
        $inInstall = $p.ExecutablePath -and $p.ExecutablePath.StartsWith($installPrefix, [StringComparison]::OrdinalIgnoreCase)
        $byName = $KillAll -and ($p.Name -in @('cronova.exe', 'cronova-executor.exe'))
        if ($inInstall -or $byName) { $ids += [int]$p.ProcessId }
    }
    return $ids
}

function Remove-DirWithRetry {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path $Path)) { return }
    $deadline = (Get-Date).AddSeconds($RetrySeconds)
    while ($true) {
        try {
            Remove-Item $Path -Recurse -Force -ErrorAction Stop
            Write-Host "Removed $Path"
            return
        }
        catch {
            if ((Get-Date) -ge $deadline) {
                throw "Could not remove ${Path}: $($_.Exception.Message)"
            }
            Stop-ProcessTree -RootIds @(Get-CronovaProcessIds)
            Start-Sleep -Milliseconds 500
        }
    }
}

# 1. Disable auto-restart so SCM recovery does not respawn processes we kill.
foreach ($name in $ServiceName) {
    if (Get-Service -Name $name -ErrorAction SilentlyContinue) {
        Invoke-CronovaSc -Arguments @('failure', $name, 'reset=', '0', 'actions=', '""') -Action "Clearing recovery for $name" -IgnoreExitCode | Out-Null
        Invoke-CronovaSc -Arguments @('config', $name, 'start=', 'disabled') -Action "Disabling $name" -IgnoreExitCode | Out-Null
    }
}

# 2. Kill service process trees (including spawned task processes).
$roots = @()
foreach ($name in $ServiceName) {
    $servicePid = Get-CronovaServicePid -Name $name
    if ($servicePid) { $roots += $servicePid }
}
$roots += @(Get-CronovaProcessIds)
Stop-ProcessTree -RootIds $roots

# 3. Stop and delete services.
foreach ($name in $ServiceName) {
    if (Get-Service -Name $name -ErrorAction SilentlyContinue) {
        Remove-CronovaService -Name $name -ForceKill
    }
}

# 4. Remove binaries (and data with -Purge).
Remove-DirWithRetry -Path $InstallDir
if ($Purge) {
    Remove-DirWithRetry -Path $DataDir
}

# 5. Verify.
$problems = @()
foreach ($name in $ServiceName) {
    if (Get-Service -Name $name -ErrorAction SilentlyContinue) {
        $problems += "service $name still registered (a reboot may be required if it is marked for deletion)"
    }
}
$left = @(Get-CronovaProcessIds)
if ($left.Count -gt 0) { $problems += "processes still running: $($left -join ', ')" }
if (Test-Path $InstallDir) { $problems += "$InstallDir still exists" }
if ($Purge -and (Test-Path $DataDir)) { $problems += "$DataDir still exists" }

if ($problems.Count -gt 0) {
    throw "Uninstall incomplete: $($problems -join '; ')"
}

if ($Purge) {
    Write-Host 'Cronova removed including data.'
}
else {
    Write-Host "Cronova services and binaries removed; data retained under $DataDir."
}
