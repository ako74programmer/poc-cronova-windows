[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Config,
    [string]$Workspace,
    [string]$Artifacts
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common\toolchain.ps1')
$repo = Get-RepoRoot
. (Join-Path $repo 'scripts\sdlc\common\SpringbootConfig.ps1')

$settings = Get-SpringbootSdlcConfig -Config $Config

$workspacePath = if ($Workspace) { Resolve-SdlcRepoPath -Path $Workspace -RepoRoot $settings.RepoRoot } else { $settings.WorkspacePath }
$artifactsPath = if ($Artifacts) { Resolve-SdlcRepoPath -Path $Artifacts -RepoRoot $settings.RepoRoot } else { $settings.ArtifactsPath }

if ([string]::IsNullOrWhiteSpace($workspacePath)) {
    throw 'Workspace path could not be resolved from config or parameters.'
}

if ([string]::IsNullOrWhiteSpace($artifactsPath)) {
    throw 'Artifacts path could not be resolved from config or parameters.'
}

New-Item -ItemType Directory -Force -Path $workspacePath | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $artifactsPath 'metadata') | Out-Null

$pomPath = Join-Path $workspacePath 'pom.xml'
if (Test-Path -LiteralPath $pomPath -PathType Leaf) {
    Write-Output "Spring Boot project already exists: $workspacePath"
    exit 0
}

$bootVersion = if ($settings.SpringBootVersion) { $settings.SpringBootVersion } else { '3.5.5' }
$javaVersion = if ($settings.JavaVersion) { $settings.JavaVersion } else { '21' }
$groupId = if ($settings.GroupId) { $settings.GroupId } else { 'com.example' }
$artifactId = if ($settings.ArtifactId) { $settings.ArtifactId } else { 'item-service' }
$packageName = if ($settings.PackageName) { $settings.PackageName } else { 'com.example.item' }
$dependencyStarters = if ($settings.DependencyStarters) { $settings.DependencyStarters } else { 'web,validation,actuator' }

$zipPath = Join-Path $artifactsPath 'metadata\springboot-starter.zip'
$url = "https://start.spring.io/starter.zip?type=maven-project&language=java&bootVersion=$bootVersion&javaVersion=$javaVersion&groupId=$groupId&artifactId=$artifactId&name=$artifactId&packageName=$packageName&packaging=jar&configFormat=yaml&dependencies=$dependencyStarters"

Write-Output "Downloading Spring Boot scaffold from start.spring.io..."
Write-Output "URL: $url"
Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $zipPath
Expand-Archive -LiteralPath $zipPath -DestinationPath $workspacePath -Force

if (-not (Test-Path -LiteralPath $pomPath -PathType Leaf)) {
    throw "Initializr response did not contain pom.xml in $workspacePath"
}

Write-Output "Spring Boot scaffold created in $workspacePath"