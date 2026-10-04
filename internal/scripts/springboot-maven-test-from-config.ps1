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

Set-JavaMavenToolchain
[void](Get-ConfiguredCommand 'java')
[void](Get-ConfiguredCommand 'maven')

$mavenWrapperRelative = if ($settings.MavenWrapper) { $settings.MavenWrapper } else { './mvnw.cmd' }
$mavenWrapperPath = Join-Path $workspacePath ($mavenWrapperRelative -replace '^[.][\\/]', '')
if (-not (Test-Path -LiteralPath $mavenWrapperPath -PathType Leaf)) {
    throw "mvnw.cmd not found in $workspacePath"
}

$logPath = Join-Path $artifactsPath 'logs\springboot-unit-tests.log'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $logPath) | Out-Null

Write-Output "Running Spring Boot tests in $workspacePath"
$base = Join-Path ([IO.Path]::GetTempPath()) ("springboot-test-" + [guid]::NewGuid().ToString('N'))
$stdoutFile = "$base.out"
$stderrFile = "$base.err"
try {
    $process = Start-Process -FilePath $mavenWrapperPath -ArgumentList (ConvertTo-NativeArgumentString @('-B', 'test')) -WorkingDirectory $workspacePath -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile
    $stdout = if (Test-Path -LiteralPath $stdoutFile) { [IO.File]::ReadAllText($stdoutFile) } else { '' }
    $stderr = if (Test-Path -LiteralPath $stderrFile) { [IO.File]::ReadAllText($stderrFile) } else { '' }
    [IO.File]::WriteAllText($logPath, $stdout + $stderr, [Text.UTF8Encoding]::new($false))
    if ($stdout) { [Console]::Out.Write($stdout) }
    if ($stderr) { [Console]::Error.Write($stderr) }
    if ([int]$process.ExitCode -ne 0) {
        throw "$mavenWrapperPath failed with exit code $($process.ExitCode)"
    }
} finally {
    Remove-Item -LiteralPath $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
}