[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Config,
    [string]$Artifacts
)

$ErrorActionPreference = 'Stop'

$scriptRoot = $PSScriptRoot

try {
    & (Join-Path $scriptRoot 'fullstack-start-backend.ps1') -Config $Config -Artifacts $Artifacts
    & (Join-Path $scriptRoot 'fullstack-start-frontend.ps1') -Config $Config -Artifacts $Artifacts
    & (Join-Path $scriptRoot 'fullstack-wait-services.ps1') -Config $Config -Artifacts $Artifacts
    & (Join-Path $scriptRoot 'fullstack-run-playwright-e2e.ps1') -Config $Config -Artifacts $Artifacts
} finally {
    & (Join-Path $scriptRoot 'fullstack-stop-services.ps1') -Config $Config -Artifacts $Artifacts
}