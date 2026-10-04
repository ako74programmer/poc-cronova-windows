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

New-Item -ItemType Directory -Force -Path (Join-Path $artifactsPath 'logs') | Out-Null

$openApiPath = if ($settings.OpenApiFile) { Resolve-SdlcRepoPath -Path $settings.OpenApiFile -RepoRoot $settings.RepoRoot } else { '' }
if ([string]::IsNullOrWhiteSpace($openApiPath) -or -not (Test-Path -LiteralPath $openApiPath -PathType Leaf)) {
    throw "Configured OpenAPI file not found: $openApiPath"
}

$python = Get-ConfiguredCommand 'python'
$logPath = Join-Path $artifactsPath 'logs\springboot-openapi-validation.log'
$script = @"
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding='utf-8')
required = ['openapi:', 'paths:', '/api/items']
missing = [item for item in required if item not in text]
if missing:
    raise SystemExit(f"Missing required OpenAPI markers: {', '.join(missing)}")
print(f"OpenAPI contract is valid: {path}")
"@

$base = Join-Path ([IO.Path]::GetTempPath()) ("springboot-openapi-" + [guid]::NewGuid().ToString('N'))
$scriptFile = "$base.py"
$stdoutFile = "$base.out"
$stderrFile = "$base.err"
try {
    Set-Content -LiteralPath $scriptFile -Value $script -Encoding UTF8
    $process = Start-Process -FilePath $python -ArgumentList (ConvertTo-NativeArgumentString @($scriptFile, $openApiPath)) -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile
    $stdout = if (Test-Path -LiteralPath $stdoutFile) { [IO.File]::ReadAllText($stdoutFile) } else { '' }
    $stderr = if (Test-Path -LiteralPath $stderrFile) { [IO.File]::ReadAllText($stderrFile) } else { '' }
    [IO.File]::WriteAllText($logPath, $stdout + $stderr, [Text.UTF8Encoding]::new($false))
    if ($stdout) { [Console]::Out.Write($stdout) }
    if ($stderr) { [Console]::Error.Write($stderr) }
    if ([int]$process.ExitCode -ne 0) {
        throw "OpenAPI validation failed for $configPath"
    }
} finally {
    Remove-Item -LiteralPath $scriptFile, $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
}