[CmdletBinding()]
param(
    [string[]]$ServiceName = @('Cronova', 'CronovaExecutor')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$scriptRoot = $PSScriptRoot
$getPidScript = Join-Path $scriptRoot 'cronova-get-service-pid.ps1'
$killPidScript = Join-Path $scriptRoot 'cronova-force-kill-pid.ps1'

foreach ($name in $ServiceName) {
    $servicePid = & powershell -ExecutionPolicy Bypass -File $getPidScript -Name $name
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to get PID for service $name."
    }

    if ($servicePid -match '^\d+$') {
        & powershell -ExecutionPolicy Bypass -File $killPidScript -ProcessId ([int]$servicePid)
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "PID $servicePid for service $name was already gone or could not be killed."
        }
    }

    & sc.exe delete $name 2>$null | Out-Host
}
