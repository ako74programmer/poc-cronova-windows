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

function Get-AngularSdlcConfig {
    param(
        [Parameter(Mandatory=$true)][string]$Config,
        [string]$RepoRoot = (Get-SdlcRepoRoot)
    )

    $workspaceDirectory = Get-SdlcConfigValue -Config $Config -Section 'workspace' -Key 'directory' -RepoRoot $RepoRoot
    $artifactsDirectory = Get-SdlcConfigValue -Config $Config -Section 'artifacts' -Key 'directory' -RepoRoot $RepoRoot

    return [ordered]@{
        RepoRoot = $RepoRoot
        ConfigPath = Resolve-SdlcRepoPath -Path $Config -RepoRoot $RepoRoot
        WorkspaceDirectory = $workspaceDirectory
        WorkspacePath = if ($workspaceDirectory) { Resolve-SdlcRepoPath -Path $workspaceDirectory -RepoRoot $RepoRoot } else { '' }
        ArtifactsDirectory = $artifactsDirectory
        ArtifactsPath = if ($artifactsDirectory) { Resolve-SdlcRepoPath -Path $artifactsDirectory -RepoRoot $RepoRoot } else { '' }
        ProjectId = Get-SdlcConfigValue -Config $Config -Section 'project' -Key 'id' -RepoRoot $RepoRoot
        ProjectKind = Get-SdlcConfigValue -Config $Config -Section 'project' -Key 'kind' -RepoRoot $RepoRoot
        ProjectDirectory = Get-SdlcConfigValue -Config $Config -Section 'project' -Key 'directory' -RepoRoot $RepoRoot
        ArtifactDirectory = Get-SdlcConfigValue -Config $Config -Section 'project' -Key 'artifact_directory' -RepoRoot $RepoRoot
        NodeVersion = Get-SdlcConfigValue -Config $Config -Section 'runtime' -Key 'node_version' -RepoRoot $RepoRoot
        AngularCliVersion = Get-SdlcConfigValue -Config $Config -Section 'runtime' -Key 'angular_cli_version' -RepoRoot $RepoRoot
        PackageManager = Get-SdlcConfigValue -Config $Config -Section 'runtime' -Key 'package_manager' -RepoRoot $RepoRoot
        InstallCommand = Get-SdlcConfigValue -Config $Config -Section 'runtime' -Key 'install_command' -RepoRoot $RepoRoot
        AppName = Get-SdlcConfigValue -Config $Config -Section 'angular' -Key 'app_name' -RepoRoot $RepoRoot
        BuildConfiguration = Get-SdlcConfigValue -Config $Config -Section 'angular' -Key 'build_configuration' -RepoRoot $RepoRoot
        OutputPath = Get-SdlcConfigValue -Config $Config -Section 'angular' -Key 'output_path' -RepoRoot $RepoRoot
        ApiClientMode = Get-SdlcConfigValue -Config $Config -Section 'angular' -Key 'api_client_mode' -RepoRoot $RepoRoot
        OpenApiFile = Get-SdlcConfigValue -Config $Config -Section 'api' -Key 'openapi_file' -RepoRoot $RepoRoot
        ApiBaseUrl = Get-SdlcConfigValue -Config $Config -Section 'api' -Key 'base_url' -RepoRoot $RepoRoot
        ServerHost = Get-SdlcConfigValue -Config $Config -Section 'server' -Key 'host' -RepoRoot $RepoRoot
        ServerPort = Get-SdlcConfigValue -Config $Config -Section 'server' -Key 'port' -RepoRoot $RepoRoot
        StartupTimeoutSeconds = Get-SdlcConfigValue -Config $Config -Section 'server' -Key 'startup_timeout_seconds' -RepoRoot $RepoRoot
        ShutdownTimeoutSeconds = Get-SdlcConfigValue -Config $Config -Section 'server' -Key 'shutdown_timeout_seconds' -RepoRoot $RepoRoot
    }
}