[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string[]]$Name,
    [switch]$RequireMatch
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$matched = @()
foreach ($processName in $Name) {
    $processes = @(Get-Process -Name $processName -ErrorAction SilentlyContinue)
    foreach ($process in $processes) {
        Stop-Process -Id $process.Id -Force
        $matched += $process.Id
    }
}

if ($RequireMatch -and $matched.Count -eq 0) {
    throw 'No matching processes found.'
}

if ($matched.Count -gt 0) {
    Write-Host ('Stopped PIDs: ' + (($matched | Sort-Object -Unique) -join ', '))
}
else {
    Write-Host 'No matching processes found.'
}
