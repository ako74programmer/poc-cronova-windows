[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Source
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'cronova-service-common.ps1')

$resolved = Resolve-CronovaPackageSource -SourcePath $Source
try {
    Write-Host $resolved.Root
}
finally {
    if ($resolved.Cleanup) {
        & $resolved.Cleanup $resolved.Root
    }
}
