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

function Get-SdlcStandardFile {
    param(
        [Parameter(Mandatory=$true)][string]$Config,
        [string]$RepoRoot = (Get-SdlcRepoRoot)
    )

    return Get-SdlcConfigValue -Config $Config -Section 'standard' -Key 'file' -RepoRoot $RepoRoot
}

function Get-SdlcInheritedConfigValue {
    param(
        [Parameter(Mandatory=$true)][string]$Config,
        [Parameter(Mandatory=$true)][string]$Section,
        [Parameter(Mandatory=$true)][string]$Key,
        [string]$RepoRoot = (Get-SdlcRepoRoot),
        [string[]]$VisitedConfigs = @()
    )

    $configPath = Resolve-SdlcRepoPath -Path $Config -RepoRoot $RepoRoot
    if ($VisitedConfigs -contains $configPath) {
        throw "Circular standard.file reference detected: $configPath"
    }

    $value = Get-SdlcConfigValue -Config $Config -Section $Section -Key $Key -RepoRoot $RepoRoot
    if (-not [string]::IsNullOrWhiteSpace($value)) {
        return $value
    }

    $standardFile = Get-SdlcStandardFile -Config $Config -RepoRoot $RepoRoot
    if ([string]::IsNullOrWhiteSpace($standardFile)) {
        return ''
    }

    return Get-SdlcInheritedConfigValue -Config $standardFile -Section $Section -Key $Key -RepoRoot $RepoRoot -VisitedConfigs ($VisitedConfigs + $configPath)
}

function Get-SdlcMergedConfigValue {
    param(
        [Parameter(Mandatory=$true)][string]$WorkflowConfig,
        [Parameter(Mandatory=$true)][string]$Section,
        [Parameter(Mandatory=$true)][string]$Key,
        [string]$RepoRoot = (Get-SdlcRepoRoot)
    )

    return Get-SdlcInheritedConfigValue -Config $WorkflowConfig -Section $Section -Key $Key -RepoRoot $RepoRoot
}

function Get-SpringbootSdlcConfig {
    param(
        [Parameter(Mandatory=$true)][string]$Config,
        [string]$RepoRoot = (Get-SdlcRepoRoot)
    )

    $workspaceDirectory = Get-SdlcMergedConfigValue -WorkflowConfig $Config -Section 'workspace' -Key 'directory' -RepoRoot $RepoRoot
    $artifactsDirectory = Get-SdlcMergedConfigValue -WorkflowConfig $Config -Section 'artifacts' -Key 'directory' -RepoRoot $RepoRoot
    $standardFile = Get-SdlcStandardFile -Config $Config -RepoRoot $RepoRoot

    return [ordered]@{
        RepoRoot = $RepoRoot
        ConfigPath = Resolve-SdlcRepoPath -Path $Config -RepoRoot $RepoRoot
        StandardFile = $standardFile
        StandardPath = if ($standardFile) { Resolve-SdlcRepoPath -Path $standardFile -RepoRoot $RepoRoot } else { '' }
        WorkspaceDirectory = $workspaceDirectory
        WorkspacePath = if ($workspaceDirectory) { Resolve-SdlcRepoPath -Path $workspaceDirectory -RepoRoot $RepoRoot } else { '' }
        ArtifactsDirectory = $artifactsDirectory
        ArtifactsPath = if ($artifactsDirectory) { Resolve-SdlcRepoPath -Path $artifactsDirectory -RepoRoot $RepoRoot } else { '' }
        ProjectId = Get-SdlcMergedConfigValue -WorkflowConfig $Config -Section 'project' -Key 'id' -RepoRoot $RepoRoot
        ProjectKind = Get-SdlcMergedConfigValue -WorkflowConfig $Config -Section 'project' -Key 'kind' -RepoRoot $RepoRoot
        ProjectDirectory = Get-SdlcMergedConfigValue -WorkflowConfig $Config -Section 'project' -Key 'directory' -RepoRoot $RepoRoot
        ArtifactDirectory = Get-SdlcMergedConfigValue -WorkflowConfig $Config -Section 'project' -Key 'artifact_directory' -RepoRoot $RepoRoot
        ArtifactName = Get-SdlcMergedConfigValue -WorkflowConfig $Config -Section 'project' -Key 'artifact_name' -RepoRoot $RepoRoot
        JavaVersion = Get-SdlcMergedConfigValue -WorkflowConfig $Config -Section 'runtime' -Key 'java_version' -RepoRoot $RepoRoot
        SpringBootVersion = Get-SdlcMergedConfigValue -WorkflowConfig $Config -Section 'runtime' -Key 'spring_boot_version' -RepoRoot $RepoRoot
        BuildTool = Get-SdlcMergedConfigValue -WorkflowConfig $Config -Section 'runtime' -Key 'build_tool' -RepoRoot $RepoRoot
        MavenWrapper = Get-SdlcMergedConfigValue -WorkflowConfig $Config -Section 'runtime' -Key 'maven_wrapper' -RepoRoot $RepoRoot
        GroupId = Get-SdlcMergedConfigValue -WorkflowConfig $Config -Section 'springboot' -Key 'group_id' -RepoRoot $RepoRoot
        ArtifactId = Get-SdlcMergedConfigValue -WorkflowConfig $Config -Section 'springboot' -Key 'artifact_id' -RepoRoot $RepoRoot
        PackageName = Get-SdlcMergedConfigValue -WorkflowConfig $Config -Section 'springboot' -Key 'package_name' -RepoRoot $RepoRoot
        ProfileTest = Get-SdlcMergedConfigValue -WorkflowConfig $Config -Section 'springboot' -Key 'profile_test' -RepoRoot $RepoRoot
        ProfileE2e = Get-SdlcMergedConfigValue -WorkflowConfig $Config -Section 'springboot' -Key 'profile_e2e' -RepoRoot $RepoRoot
        OpenApiFile = Get-SdlcMergedConfigValue -WorkflowConfig $Config -Section 'api' -Key 'openapi_file' -RepoRoot $RepoRoot
        ApiBasePath = Get-SdlcMergedConfigValue -WorkflowConfig $Config -Section 'api' -Key 'base_path' -RepoRoot $RepoRoot
        HealthPath = Get-SdlcMergedConfigValue -WorkflowConfig $Config -Section 'api' -Key 'health_path' -RepoRoot $RepoRoot
        ServerHost = Get-SdlcMergedConfigValue -WorkflowConfig $Config -Section 'server' -Key 'host' -RepoRoot $RepoRoot
        ServerPort = Get-SdlcMergedConfigValue -WorkflowConfig $Config -Section 'server' -Key 'port' -RepoRoot $RepoRoot
        StartupTimeoutSeconds = Get-SdlcMergedConfigValue -WorkflowConfig $Config -Section 'server' -Key 'startup_timeout_seconds' -RepoRoot $RepoRoot
        ShutdownTimeoutSeconds = Get-SdlcMergedConfigValue -WorkflowConfig $Config -Section 'server' -Key 'shutdown_timeout_seconds' -RepoRoot $RepoRoot
        DependencyStarters = Get-SdlcMergedConfigValue -WorkflowConfig $Config -Section 'dependencies' -Key 'starters' -RepoRoot $RepoRoot
    }
}