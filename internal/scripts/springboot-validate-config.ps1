[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Config,
    [string]$Artifacts
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common\toolchain.ps1')
$repo = Get-RepoRoot
. (Join-Path $repo 'scripts\sdlc\common\SpringbootConfig.ps1')

$settings = Get-SpringbootSdlcConfig -Config $Config
$configPath = $settings.ConfigPath
$artifactsPath = if ($Artifacts) { Resolve-SdlcRepoPath -Path $Artifacts -RepoRoot $settings.RepoRoot } else { $settings.ArtifactsPath }

if ([string]::IsNullOrWhiteSpace($artifactsPath)) {
    throw 'Artifacts path could not be resolved from config or parameters.'
}

New-Item -ItemType Directory -Force -Path (Join-Path $artifactsPath 'metadata') | Out-Null

Set-JavaMavenToolchain
[void](Get-ConfiguredCommand 'java')

$configText = Get-Content -LiteralPath $configPath -Raw
if ($configText -match '(/c/Users/|/home/|/tmp/|/var/|systemd|launchd)') {
    throw 'Configuration contains a non-portable Unix/private path.'
}

if (-not $settings.ProjectId) {
    throw 'Spring Boot config lacks project.id.'
}

if ($settings.ProjectKind -ne 'springboot') {
    throw 'Config kind must be springboot.'
}

$javaVersionFile = Join-Path $artifactsPath 'metadata\java-version.txt'
$toolchainRuntimeFile = Join-Path $artifactsPath 'metadata\toolchain-runtime.txt'

$java = Get-ConfiguredCommand 'java'
$base = Join-Path ([IO.Path]::GetTempPath()) ("springboot-validate-" + [guid]::NewGuid().ToString('N'))
$stdoutFile = "$base.out"
$stderrFile = "$base.err"
try {
    $process = Start-Process -FilePath $java -ArgumentList '-version' -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile
    $stdout = if (Test-Path -LiteralPath $stdoutFile) { [IO.File]::ReadAllText($stdoutFile) } else { '' }
    $stderr = if (Test-Path -LiteralPath $stderrFile) { [IO.File]::ReadAllText($stderrFile) } else { '' }
    ($stdout + $stderr).Trim() | Set-Content -LiteralPath $javaVersionFile -Encoding UTF8
    if ($stdout) { [Console]::Out.Write($stdout) }
    if ($stderr) { [Console]::Error.Write($stderr) }
    if ([int]$process.ExitCode -ne 0) {
        throw 'java -version failed'
    }
} finally {
    Remove-Item -LiteralPath $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
}

Write-ToolchainRuntime $toolchainRuntimeFile
Write-Output "Spring Boot configuration is valid: $configPath"