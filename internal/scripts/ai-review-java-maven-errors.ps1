[CmdletBinding()]
param(
    [Alias('w')][string]$Workspace,
    [Alias('p')][string]$Project = 'demo',
    [Alias('k')][string]$Package = 'com.example.demo',
    [Alias('r')][string]$ProviderId,
    [Alias('m')][string]$Model,
    [Alias('y')][string]$Python,
    [Parameter(Mandatory=$true)][string]$PromptFile,
    [Parameter(Mandatory=$true)][string]$RequestFile,
    [Parameter(Mandatory=$true)][string]$ResponseFile
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common\toolchain.ps1')
. (Join-Path $PSScriptRoot 'common\ai-provider.ps1')

$repo = Get-RepoRoot
if (-not $Workspace) { $Workspace = Join-Path $repo 'workspaces\springboot-demo' }
$projectDir = Resolve-RepoPath (Join-Path $Workspace $Project)
if (-not (Test-Path -LiteralPath $projectDir -PathType Container)) { throw "Project directory not found: $projectDir" }

if (-not $Python -or $Python -in @('python', 'python3')) { $Python = $env:CRONOVA_PYTHON }
if (-not $Python) { $Python = Get-ConfiguredCommand 'python' }
else {
    $resolvedPython = Get-Command $Python -ErrorAction SilentlyContinue
    if ($resolvedPython) { $Python = $resolvedPython.Source }
}

$baseUrl = $env:CRONOVA_AI_BASE_URL
$token = $env:CRONOVA_AI_TOKEN
$db = if ($env:CRONOVA_DB) { $env:CRONOVA_DB } else { Join-Path $repo 'data\cronova.db' }
if (-not $Model -or -not $baseUrl) {
    $provider = Resolve-AiProvider $db $ProviderId $Python
    if ($provider) {
        if (-not $baseUrl) { $baseUrl = $provider[0] }
        if (-not $Model) { $Model = $provider[1] }
        if (-not $token) { $token = $provider[2] }
    }
}
if (-not $Model -or -not $baseUrl) {
    throw 'Could not determine AI provider. Configure a default AI provider, set CRONOVA_AI_BASE_URL and CRONOVA_AI_MODEL, or pass -r PROVIDER_ID and -m MODEL.'
}

$resolvedPromptFile = Resolve-RepoPath $PromptFile
$resolvedRequestFile = Resolve-RepoPath $RequestFile
$resolvedResponseFile = Resolve-RepoPath $ResponseFile
$requestDir = Split-Path $resolvedRequestFile -Parent
$responseDir = Split-Path $resolvedResponseFile -Parent
if ($requestDir) { New-Item -ItemType Directory -Force -Path $requestDir | Out-Null }
if ($responseDir) { New-Item -ItemType Directory -Force -Path $responseDir | Out-Null }

$aiScript = Join-Path $repo 'internal\scripts\ai\review_fix_v2.py'
$aiStdoutFile = Join-Path ([IO.Path]::GetTempPath()) ("ai-review-" + [guid]::NewGuid().ToString('N') + '.stdout')
$aiStderrFile = Join-Path ([IO.Path]::GetTempPath()) ("ai-review-" + [guid]::NewGuid().ToString('N') + '.stderr')
$aiArgs = @($aiScript, $projectDir, $Package.Replace('.', '/'), $resolvedPromptFile, $resolvedRequestFile, $resolvedResponseFile, $Model, $baseUrl, $token)
try {
    $aiProcess = Start-Process -FilePath $Python -ArgumentList (ConvertTo-NativeArgumentString $aiArgs) -Wait -PassThru -NoNewWindow -RedirectStandardOutput $aiStdoutFile -RedirectStandardError $aiStderrFile
    $aiStdout = if (Test-Path -LiteralPath $aiStdoutFile) { [IO.File]::ReadAllText($aiStdoutFile) } else { '' }
    $aiStderr = if (Test-Path -LiteralPath $aiStderrFile) { [IO.File]::ReadAllText($aiStderrFile) } else { '' }
    if ($token) { $aiStderr = $aiStderr.Replace($token, '[REDACTED]') }
    if ($aiStdout) { [Console]::Out.Write($aiStdout) }
    if ($aiProcess.ExitCode -ne 0) {
        [Console]::Error.WriteLine("AI review/fix failed: python=$Python script=$aiScript exit_code=$($aiProcess.ExitCode) stderr=$aiStderr")
        exit [int]$aiProcess.ExitCode
    }
} finally {
    Remove-Item -LiteralPath $aiStdoutFile, $aiStderrFile -Force -ErrorAction SilentlyContinue
}