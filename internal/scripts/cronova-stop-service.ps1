[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Name,
    [int]$TimeoutSeconds = 20,
    [switch]$ForceKill
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'cronova-service-common.ps1')

Stop-CronovaService -Name $Name -TimeoutSeconds $TimeoutSeconds -ForceKill:$ForceKill
