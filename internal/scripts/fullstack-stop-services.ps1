[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Config,
    [string]$Artifacts
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common\toolchain.ps1')
$repo = Get-RepoRoot
. (Join-Path $repo 'scripts\sdlc\common\FullstackConfig.ps1')

$settings = Get-FullstackSdlcConfig -Config $Config
$artifactsPath = if ($Artifacts) { Resolve-SdlcRepoPath -Path $Artifacts -RepoRoot $settings.RepoRoot } else { $settings.ArtifactsPath }

if ([string]::IsNullOrWhiteSpace($artifactsPath)) {
    throw 'Artifacts path could not be resolved from config or parameters.'
}

foreach ($name in @('frontend', 'backend')) {
    $pidPath = Join-Path $artifactsPath "runtime\$name.pid"
    if (Test-Path -LiteralPath $pidPath -PathType Leaf) {
        $processId = [int](Get-Content -LiteralPath $pidPath)
        # npx/java may spawn children (cmd -> node http-server); stop the whole tree.
        if (Get-Process -Id $processId -ErrorAction SilentlyContinue) {
            & taskkill.exe /PID $processId /T /F 2>&1 | Out-Null
        }
        Remove-Item -LiteralPath $pidPath -Force -ErrorAction SilentlyContinue
        Write-Output "Stopped $name PID $processId"
    }
}