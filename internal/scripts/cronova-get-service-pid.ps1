[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Name
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'cronova-service-common.ps1')

$servicePid = Get-CronovaServicePid -Name $Name
if ($null -eq $servicePid) {
    Write-Host 'NOT_FOUND'
    exit 0
}

Write-Host $servicePid
