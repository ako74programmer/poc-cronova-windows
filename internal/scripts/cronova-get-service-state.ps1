[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Name
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'cronova-service-common.ps1')

$state = Get-CronovaServiceState -Name $Name
if ($null -eq $state) {
    Write-Host 'NOT_FOUND'
    exit 0
}

Write-Host $state
