[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Name,
    [switch]$ForceKill
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'cronova-service-common.ps1')

Remove-CronovaService -Name $Name -ForceKill:$ForceKill
