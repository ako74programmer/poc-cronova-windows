[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][int]$ProcessId
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($ProcessId -le 0) {
    Write-Host "PID $ProcessId is not killable"
    exit 0
}

$process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
if ($null -eq $process) {
    Write-Host "PID $ProcessId already stopped"
    exit 0
}

Stop-Process -Id $ProcessId -Force
Write-Host "Stopped PID $ProcessId"
