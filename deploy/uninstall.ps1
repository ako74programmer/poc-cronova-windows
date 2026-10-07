[CmdletBinding()]
param(
    [switch]$Purge,
    [switch]$KillAll
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$script = Join-Path (Split-Path $PSScriptRoot -Parent) 'internal\scripts\cronova-uninstall.ps1'
& $script @PSBoundParameters
