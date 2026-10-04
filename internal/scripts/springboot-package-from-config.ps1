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

$logPath = Join-Path $artifactsPath 'logs\springboot-package.log'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $logPath) | Out-Null

Write-Output "Running Spring Boot package in $workspacePath"
$base = Join-Path ([IO.Path]::GetTempPath()) ("springboot-package-" + [guid]::NewGuid().ToString('N'))
$stdoutFile = "$base.out"
$stderrFile = "$base.err"
try {
    $process = Start-Process -FilePath $mavenWrapperPath -ArgumentList (ConvertTo-NativeArgumentString @('-B', 'package', '-DskipTests')) -WorkingDirectory $workspacePath -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile
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

$artifactName = if ($settings.ArtifactName) { $settings.ArtifactName } else { 'item-service.jar' }
$manifestName = 'backend-manifest.json'
$artifactDirectory = if ($settings.ArtifactDirectory) { $settings.ArtifactDirectory } else { 'target' }
$targetPath = Join-Path $workspacePath $artifactDirectory
$jar = Get-ChildItem -LiteralPath $targetPath -Filter *.jar | Where-Object { $_.Name -notlike '*-plain.jar' } | Select-Object -First 1
if (-not $jar) {
    throw 'Executable Spring Boot JAR not found'
}

$outputJar = Join-Path $artifactsPath (Join-Path 'package' $artifactName)
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outputJar) | Out-Null
Copy-Item -LiteralPath $jar.FullName -Destination $outputJar -Force

$hash = (Get-FileHash -LiteralPath $jar.FullName -Algorithm SHA256).Hash
$hash | Set-Content -LiteralPath ($outputJar + '.sha256') -Encoding UTF8

$manifestPath = Join-Path $artifactsPath $manifestName
@{
    component = 'springboot'
    artifact = $outputJar
    source_directory = $workspacePath
    result = 'success'
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

Write-Output "Spring Boot package created: $outputJar"