[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Get-SdlcRepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
}

function Resolve-SdlcRepoPath {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [string]$RepoRoot = (Get-SdlcRepoRoot)
    )

    if ([IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return (Join-Path $RepoRoot $Path)
}

function Get-SdlcConfigValue {
    param(
        [Parameter(Mandatory=$true)][string]$Config,
        [Parameter(Mandatory=$true)][string]$Section,
        [Parameter(Mandatory=$true)][string]$Key,
        [string]$RepoRoot = (Get-SdlcRepoRoot)
    )

    $configPath = Resolve-SdlcRepoPath -Path $Config -RepoRoot $RepoRoot
    $lines = Get-Content -LiteralPath $configPath
    $inside = $false

    foreach ($line in $lines) {
        if ($line -match ('^' + [regex]::Escape($Section) + ':\s*$')) {
            $inside = $true
            continue
        }

        if ($inside -and $line -match '^\S') {
            $inside = $false
        }

        if ($inside -and $line -match ('^\s{2}' + [regex]::Escape($Key) + ':\s*(.*)$')) {
            return $Matches[1].Trim().Trim('"').Trim("'")
        }
    }

    return ''
}

function Get-FullstackSdlcConfig {
    param(
        [Parameter(Mandatory=$true)][string]$Config,
        [string]$RepoRoot = (Get-SdlcRepoRoot)
    )

    $artifactsDirectory = Get-SdlcConfigValue -Config $Config -Section 'artifacts' -Key 'directory' -RepoRoot $RepoRoot

    return [ordered]@{
        RepoRoot = $RepoRoot
        ConfigPath = Resolve-SdlcRepoPath -Path $Config -RepoRoot $RepoRoot
        ArtifactsDirectory = $artifactsDirectory
        ArtifactsPath = if ($artifactsDirectory) { Resolve-SdlcRepoPath -Path $artifactsDirectory -RepoRoot $RepoRoot } else { '' }
        StackId = Get-SdlcConfigValue -Config $Config -Section 'stack' -Key 'id' -RepoRoot $RepoRoot
        AngularConfig = Get-SdlcConfigValue -Config $Config -Section 'stack' -Key 'angular_config' -RepoRoot $RepoRoot
        SpringbootConfig = Get-SdlcConfigValue -Config $Config -Section 'stack' -Key 'springboot_config' -RepoRoot $RepoRoot
        OpenApiFile = Get-SdlcConfigValue -Config $Config -Section 'stack' -Key 'openapi_file' -RepoRoot $RepoRoot
        FrontendManifest = Get-SdlcConfigValue -Config $Config -Section 'artifacts' -Key 'frontend_manifest' -RepoRoot $RepoRoot
        FrontendDist = Get-SdlcConfigValue -Config $Config -Section 'artifacts' -Key 'frontend_dist' -RepoRoot $RepoRoot
        BackendManifest = Get-SdlcConfigValue -Config $Config -Section 'artifacts' -Key 'backend_manifest' -RepoRoot $RepoRoot
        BackendJar = Get-SdlcConfigValue -Config $Config -Section 'artifacts' -Key 'backend_jar' -RepoRoot $RepoRoot
        BackendHealthUrl = Get-SdlcConfigValue -Config $Config -Section 'services' -Key 'backend_health_url' -RepoRoot $RepoRoot
        BackendHost = Get-SdlcConfigValue -Config $Config -Section 'services' -Key 'backend_host' -RepoRoot $RepoRoot
        BackendPort = Get-SdlcConfigValue -Config $Config -Section 'services' -Key 'backend_port' -RepoRoot $RepoRoot
        BackendProfile = Get-SdlcConfigValue -Config $Config -Section 'services' -Key 'backend_profile' -RepoRoot $RepoRoot
        FrontendHost = Get-SdlcConfigValue -Config $Config -Section 'services' -Key 'frontend_host' -RepoRoot $RepoRoot
        FrontendPort = Get-SdlcConfigValue -Config $Config -Section 'services' -Key 'frontend_port' -RepoRoot $RepoRoot
        FrontendUrl = Get-SdlcConfigValue -Config $Config -Section 'services' -Key 'frontend_url' -RepoRoot $RepoRoot
        StartupTimeoutSeconds = Get-SdlcConfigValue -Config $Config -Section 'services' -Key 'startup_timeout_seconds' -RepoRoot $RepoRoot
        PlaywrightDirectory = Get-SdlcConfigValue -Config $Config -Section 'playwright' -Key 'directory' -RepoRoot $RepoRoot
        PlaywrightBrowser = Get-SdlcConfigValue -Config $Config -Section 'playwright' -Key 'browser' -RepoRoot $RepoRoot
        PlaywrightBaseUrl = Get-SdlcConfigValue -Config $Config -Section 'playwright' -Key 'base_url' -RepoRoot $RepoRoot
        PlaywrightApiUrl = Get-SdlcConfigValue -Config $Config -Section 'playwright' -Key 'api_url' -RepoRoot $RepoRoot
    }
}