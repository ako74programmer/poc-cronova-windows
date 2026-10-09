[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Source,
    [string]$InstallDir = (Join-Path $env:ProgramFiles 'Cronova')
)

# Replaces cronova.exe / cronova-executor.exe of an installed Cronova and restarts
# both Windows Services. Every sc.exe/service step is checked; if replacing a
# binary or restarting fails, the previous binaries are restored and restarted.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'cronova-service-common.ps1')

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run update.ps1 from an elevated PowerShell session.'
}
foreach ($name in 'CronovaExecutor', 'Cronova') {
    if (-not (Get-CronovaServiceState -Name $name)) {
        throw "Service $name is not installed; run deploy\install.ps1 instead."
    }
}

$binaries = 'cronova.exe', 'cronova-executor.exe'
foreach ($name in $binaries) {
    if (-not (Test-Path (Join-Path $Source $name))) { throw "Missing update binary: $(Join-Path $Source $name)" }
}

Stop-CronovaService -Name 'Cronova' -ForceKill
Stop-CronovaService -Name 'CronovaExecutor' -ForceKill

$swapped = @()
try {
    foreach ($name in $binaries) {
        $dst = Join-Path $InstallDir $name
        Copy-Item (Join-Path $Source $name) "$dst.new" -Force
        if (Test-Path $dst) { Move-Item $dst "$dst.bak" -Force }
        $swapped += $dst
        Move-Item "$dst.new" $dst -Force
    }
    Start-CronovaService -Name 'CronovaExecutor'
    Start-CronovaService -Name 'Cronova'
}
catch {
    $failure = $_
    Write-Warning "Update failed: $($failure.Exception.Message) - restoring previous binaries."
    Stop-CronovaService -Name 'Cronova' -ForceKill
    Stop-CronovaService -Name 'CronovaExecutor' -ForceKill
    foreach ($dst in $swapped) {
        Remove-Item "$dst.new" -Force -ErrorAction SilentlyContinue
        if (Test-Path "$dst.bak") { Move-Item "$dst.bak" $dst -Force }
    }
    Start-CronovaService -Name 'CronovaExecutor'
    Start-CronovaService -Name 'Cronova'
    throw "Update aborted, previous version restored: $($failure.Exception.Message)"
}

foreach ($dst in $swapped) { Remove-Item "$dst.bak" -Force -ErrorAction SilentlyContinue }
foreach ($name in 'CronovaExecutor', 'Cronova') {
    $state = Get-CronovaServiceState -Name $name
    if ($state -ne 'RUNNING') { throw "Service $name is $state after update; expected RUNNING." }
}
Write-Host 'Cronova updated; configuration and ProgramData were preserved.'
