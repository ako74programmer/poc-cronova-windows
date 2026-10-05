[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Config,
    [string]$Workspace,
    [string]$Artifacts
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common\toolchain.ps1')
$repo = Get-RepoRoot
. (Join-Path $repo 'scripts\sdlc\common\AngularConfig.ps1')

function Invoke-ContractFrontendGenerator {
    param(
        [Parameter(Mandatory=$true)][hashtable]$Settings,
        [Parameter(Mandatory=$true)][string]$WorkspacePath,
        [Parameter(Mandatory=$true)][string]$PythonPath
    )

    $apiClientMode = if ($null -eq $Settings.ApiClientMode) { '' } else { $Settings.ApiClientMode.ToString().ToLowerInvariant() }
    if ($apiClientMode -notin @('contract', 'openapi-generated')) {
        return
    }

    $generatorPath = Join-Path $Settings.RepoRoot 'scripts\sdlc\integration\generate_contract_app.py'
    $backendWorkspace = Join-Path $Settings.RepoRoot '.workspaces\springboot'
    $contractPath = Resolve-SdlcRepoPath -Path $Settings.OpenApiFile -RepoRoot $Settings.RepoRoot
    $apiBaseUrl = if ($Settings.ApiBaseUrl) { $Settings.ApiBaseUrl } else { 'http://127.0.0.1:18080/api' }
    $frontendOrigin = "http://{0}:{1}" -f $Settings.ServerHost, $Settings.ServerPort

    if (-not (Test-Path -LiteralPath $generatorPath -PathType Leaf)) {
        throw "Contract frontend generator not found: $generatorPath"
    }

    if (-not (Test-Path -LiteralPath $backendWorkspace -PathType Container)) {
        throw "Expected Spring Boot workspace for contract generation not found: $backendWorkspace"
    }

    Write-Output "Generating contract-driven Angular app in $WorkspacePath"
    Invoke-Native -FilePath $PythonPath -ArgumentList @(
        $generatorPath,
        '--contract', $contractPath,
        '--backend-workspace', $backendWorkspace,
        '--frontend-workspace', $WorkspacePath,
        '--backend-package', 'com.example.items',
        '--api-base-url', $apiBaseUrl,
        '--frontend-origin', $frontendOrigin
    ) -WorkingDirectory $Settings.RepoRoot
}

$settings = Get-AngularSdlcConfig -Config $Config
$workspacePath = if ($Workspace) { Resolve-SdlcRepoPath -Path $Workspace -RepoRoot $settings.RepoRoot } else { $settings.WorkspacePath }
$artifactsPath = if ($Artifacts) { Resolve-SdlcRepoPath -Path $Artifacts -RepoRoot $settings.RepoRoot } else { $settings.ArtifactsPath }

if ([string]::IsNullOrWhiteSpace($workspacePath)) {
    throw 'Workspace path could not be resolved from config or parameters.'
}

if ([string]::IsNullOrWhiteSpace($artifactsPath)) {
    throw 'Artifacts path could not be resolved from config or parameters.'
}

$npx = Get-Command 'npx.cmd' -ErrorAction SilentlyContinue
if (-not $npx) { $npx = Get-Command 'npx' -ErrorAction SilentlyContinue }
if (-not $npx) { throw 'Required command not found: npx' }

$node = Get-Command 'node.exe' -ErrorAction SilentlyContinue
if (-not $node) { $node = Get-Command 'node' -ErrorAction SilentlyContinue }
if (-not $node) { throw 'Required command not found: node' }

$python = Get-Command 'py.exe' -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command 'py' -ErrorAction SilentlyContinue }
if (-not $python) { throw 'Required command not found: py' }

$npm = Get-Command 'npm.cmd' -ErrorAction SilentlyContinue
if (-not $npm) { $npm = Get-Command 'npm' -ErrorAction SilentlyContinue }
if (-not $npm) { throw 'Required command not found: npm' }

$appName = if ($settings.AppName) { $settings.AppName } else { 'item-portal' }
$cliVersion = if ($settings.AngularCliVersion) { $settings.AngularCliVersion } else { 'latest' }

function Test-PackageScript {
    param(
        [Parameter(Mandatory=$true)][string]$PackageJsonPath,
        [Parameter(Mandatory=$true)][string]$ScriptName
    )

    if (-not (Test-Path -LiteralPath $PackageJsonPath -PathType Leaf)) {
        return $false
    }

    $packageJson = Get-Content -LiteralPath $PackageJsonPath -Raw | ConvertFrom-Json
    if ($null -eq $packageJson.scripts) {
        return $false
    }

    return $null -ne ($packageJson.scripts.PSObject.Properties[$ScriptName])
}

function Test-PackageDependency {
    param(
        [Parameter(Mandatory=$true)][string]$PackageJsonPath,
        [Parameter(Mandatory=$true)][string]$DependencyName
    )

    if (-not (Test-Path -LiteralPath $PackageJsonPath -PathType Leaf)) {
        return $false
    }

    $packageJson = Get-Content -LiteralPath $PackageJsonPath -Raw | ConvertFrom-Json
    $hasDevDependency = ($null -ne $packageJson.devDependencies) -and ($null -ne $packageJson.devDependencies.PSObject.Properties[$DependencyName])
    $hasDependency = ($null -ne $packageJson.dependencies) -and ($null -ne $packageJson.dependencies.PSObject.Properties[$DependencyName])
    return $hasDevDependency -or $hasDependency
}

function Ensure-LintSetup {
    param(
        [Parameter(Mandatory=$true)][string]$WorkspacePath,
        [Parameter(Mandatory=$true)][string]$CliVersion,
        [Parameter(Mandatory=$true)][string]$NpxPath
    )

    $packageJsonPath = Join-Path $WorkspacePath 'package.json'
    if (Test-PackageScript -PackageJsonPath $packageJsonPath -ScriptName 'lint') {
        return
    }

    Write-Output "Adding angular-eslint to Angular workspace: $WorkspacePath"
    Invoke-Native -FilePath $NpxPath -ArgumentList @('--yes', "@angular/cli@$CliVersion", 'add', "@angular-eslint/schematics@$CliVersion", '--skip-confirmation') -WorkingDirectory $WorkspacePath
}

function Ensure-TestBrowserSetup {
    param(
        [Parameter(Mandatory=$true)][string]$WorkspacePath,
        [Parameter(Mandatory=$true)][string]$NpmPath
    )

    $packageJsonPath = Join-Path $WorkspacePath 'package.json'
    if (Test-PackageDependency -PackageJsonPath $packageJsonPath -DependencyName 'puppeteer') {
        return
    }

    Write-Output "Adding Puppeteer Chromium for Angular unit tests: $WorkspacePath"
    Invoke-Native -FilePath $NpmPath -ArgumentList @('install', '--save-dev', '--package-lock-only', 'puppeteer@24') -WorkingDirectory $WorkspacePath
}

$packageJsonPath = Join-Path $workspacePath 'package.json'
if (Test-Path -LiteralPath $packageJsonPath -PathType Leaf) {
    Write-Output "Angular project already exists: $workspacePath"
    Invoke-ContractFrontendGenerator -Settings $settings -WorkspacePath $workspacePath -PythonPath $python.Source
    Ensure-LintSetup -WorkspacePath $workspacePath -CliVersion $cliVersion -NpxPath $npx.Source
    Ensure-TestBrowserSetup -WorkspacePath $workspacePath -NpmPath $npm.Source
    $packageLockPath = Join-Path $workspacePath 'package-lock.json'
    if (-not (Test-Path -LiteralPath $packageLockPath -PathType Leaf)) {
        Write-Output "Generating missing package-lock.json: $workspacePath"
        Invoke-Native -FilePath $npm.Source -ArgumentList @('install', '--package-lock-only', '--ignore-scripts') -WorkingDirectory $workspacePath
    }
    exit 0
}

New-Item -ItemType Directory -Force -Path $workspacePath | Out-Null

$cliDirectory = $workspacePath
$repoRootWithSeparator = $settings.RepoRoot.TrimEnd('\') + '\'
if ($workspacePath.StartsWith($repoRootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
    $cliDirectory = $workspacePath.Substring($repoRootWithSeparator.Length)
}

Invoke-Native -FilePath $npx.Source -ArgumentList @(
    '--yes',
    "@angular/cli@$cliVersion",
    'new',
    $appName,
    '--directory', $cliDirectory,
    '--routing',
    '--style=scss',
    '--standalone',
    '--skip-git',
    '--package-manager=npm',
    '--skip-install'
) -WorkingDirectory $settings.RepoRoot

Invoke-ContractFrontendGenerator -Settings $settings -WorkspacePath $workspacePath -PythonPath $python.Source
Ensure-LintSetup -WorkspacePath $workspacePath -CliVersion $cliVersion -NpxPath $npx.Source
Ensure-TestBrowserSetup -WorkspacePath $workspacePath -NpmPath $npm.Source
Invoke-Native -FilePath $npm.Source -ArgumentList @('install', '--package-lock-only', '--ignore-scripts') -WorkingDirectory $workspacePath

Write-Output "Angular scaffold created in $workspacePath"