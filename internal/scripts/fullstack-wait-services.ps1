[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Config,
    [string]$Artifacts
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common\toolchain.ps1')
$repo = Get-RepoRoot
. (Join-Path $repo 'scripts\sdlc\common\FullstackConfig.ps1')

$settings = Get-FullstackSdlcConfig -Config $Config
$timeoutSeconds = if ($settings.StartupTimeoutSeconds) { [int]$settings.StartupTimeoutSeconds } else { 90 }

foreach ($url in @($settings.BackendHealthUrl, $settings.FrontendUrl)) {
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $ready = $false
    do {
        try {
            Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 5 | Out-Null
            $ready = $true
            break
        } catch {
            Start-Sleep -Seconds 2
        }
    } while ($stopwatch.Elapsed.TotalSeconds -lt $timeoutSeconds)

    if (-not $ready) {
        throw "Timeout waiting for $url"
    }
}

Write-Output 'All services are ready'