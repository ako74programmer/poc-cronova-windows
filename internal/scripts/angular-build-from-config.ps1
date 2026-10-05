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

$settings = Get-AngularSdlcConfig -Config $Config
$workspacePath = if ($Workspace) { Resolve-SdlcRepoPath -Path $Workspace -RepoRoot $settings.RepoRoot } else { $settings.WorkspacePath }
$artifactsPath = if ($Artifacts) { Resolve-SdlcRepoPath -Path $Artifacts -RepoRoot $settings.RepoRoot } else { $settings.ArtifactsPath }

if ([string]::IsNullOrWhiteSpace($workspacePath)) {
    throw 'Workspace path could not be resolved from config or parameters.'
}

if ([string]::IsNullOrWhiteSpace($artifactsPath)) {
    throw 'Artifacts path could not be resolved from config or parameters.'
}

$npm = Get-Command 'npm.cmd' -ErrorAction SilentlyContinue
if (-not $npm) { $npm = Get-Command 'npm' -ErrorAction SilentlyContinue }
if (-not $npm) { throw 'Required command not found: npm' }

$packageJsonPath = Join-Path $workspacePath 'package.json'
if (-not (Test-Path -LiteralPath $packageJsonPath -PathType Leaf)) {
    throw "package.json not found in $workspacePath"
}

$buildConfiguration = if ($settings.BuildConfiguration) { $settings.BuildConfiguration } else { 'production' }

$logPath = Join-Path $artifactsPath 'logs\angular-build.log'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $logPath) | Out-Null

Write-Output "Running npm run build -- --configuration $buildConfiguration in $workspacePath"
$base = Join-Path ([IO.Path]::GetTempPath()) ("angular-build-" + [guid]::NewGuid().ToString('N'))
$stdoutFile = "$base.out"
$stderrFile = "$base.err"
try {
    $process = Start-Process -FilePath $npm.Source -ArgumentList (ConvertTo-NativeArgumentString @('run', 'build', '--', '--configuration', $buildConfiguration)) -WorkingDirectory $workspacePath -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile
    $stdout = if (Test-Path -LiteralPath $stdoutFile) { [IO.File]::ReadAllText($stdoutFile) } else { '' }
    $stderr = if (Test-Path -LiteralPath $stderrFile) { [IO.File]::ReadAllText($stderrFile) } else { '' }
    [IO.File]::WriteAllText($logPath, $stdout + $stderr, [Text.UTF8Encoding]::new($false))
    if ($stdout) { [Console]::Out.Write($stdout) }
    if ($stderr) { [Console]::Error.Write($stderr) }
    if ([int]$process.ExitCode -ne 0) {
        throw "$($npm.Source) failed with exit code $($process.ExitCode)"
    }
} finally {
    Remove-Item -LiteralPath $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
}

$distDir = ''
if ($settings.OutputPath) {
    $configuredDist = Join-Path $workspacePath ($settings.OutputPath -replace '/', '\')
    if (Test-Path -LiteralPath $configuredDist -PathType Container) {
        $distDir = $configuredDist
    }
}

if (-not $distDir) {
    $defaultBrowserDist = Join-Path $workspacePath 'dist\item-portal\browser'
    if (Test-Path -LiteralPath $defaultBrowserDist -PathType Container) {
        $distDir = $defaultBrowserDist
    }
}

if (-not $distDir) {
    $distRoot = Join-Path $workspacePath 'dist'
    if (Test-Path -LiteralPath $distRoot -PathType Container) {
        $indexFile = Get-ChildItem -Path $distRoot -Recurse -Filter 'index.html' -File | Select-Object -First 1
        if ($indexFile) {
            $distDir = $indexFile.Directory.FullName
        }
    }
}

if (-not $distDir -or -not (Test-Path -LiteralPath (Join-Path $distDir 'index.html') -PathType Leaf)) {
    throw 'Angular build did not produce index.html'
}

$artifactDistRoot = Join-Path $artifactsPath 'dist'
$artifactBrowserDir = Join-Path $artifactDistRoot 'browser'
New-Item -ItemType Directory -Force -Path $artifactDistRoot | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $artifactsPath 'metadata') | Out-Null
Remove-Item -LiteralPath $artifactBrowserDir -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -LiteralPath $distDir -Destination $artifactBrowserDir -Recurse

$indexPath = Join-Path $distDir 'index.html'
$hash = Get-FileHash -LiteralPath $indexPath -Algorithm SHA256
"$($hash.Hash)  $indexPath" | Set-Content -LiteralPath (Join-Path $artifactsPath 'metadata\frontend-index.sha256') -Encoding UTF8

$manifestName = if ($settings.ArtifactsDirectory) { Get-SdlcConfigValue -Config $Config -Section 'artifacts' -Key 'manifest' -RepoRoot $settings.RepoRoot } else { '' }
if ([string]::IsNullOrWhiteSpace($manifestName)) {
    $manifestName = 'frontend-manifest.json'
}

$manifestPath = Join-Path $artifactsPath $manifestName
$manifestDirectory = Split-Path -Parent $manifestPath
if ($manifestDirectory) {
    New-Item -ItemType Directory -Force -Path $manifestDirectory | Out-Null
}

$manifest = [ordered]@{
    component = 'angular'
    project = $workspacePath
    artifact_directory = $artifactBrowserDir
    openapi = $settings.OpenApiFile
    result = 'success'
} | ConvertTo-Json -Depth 3

$manifest | Set-Content -LiteralPath $manifestPath -Encoding UTF8