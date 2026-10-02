[CmdletBinding()]
param(
    [Alias('w')][string]$Workspace,
    [Alias('p')][string]$Project = 'demo',
    [Alias('k')][string]$Package = 'com.example.demo',
    [Alias('i')][int]$Iterations = 3,
    [Alias('r')][string]$ProviderId,
    [Alias('m')][string]$Model,
    [Alias('y')][string]$Python
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common/toolchain.ps1')
. (Join-Path $PSScriptRoot 'common/ai-provider.ps1')
$repo = Get-RepoRoot
if (-not $Workspace) { $Workspace = Join-Path $repo 'workspaces/springboot-demo' }
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
$db = if ($env:CRONOVA_DB) { $env:CRONOVA_DB } else { Join-Path $repo 'data/cronova.db' }
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

$tmp = Join-Path $repo '.tmp'
$m2 = Join-Path $repo '.m2/repository'
New-Item -ItemType Directory -Force -Path $tmp, $m2 | Out-Null
Set-JavaMavenToolchain
$maven = Get-ConfiguredCommand 'maven'

for ($iteration = 1; $iteration -le $Iterations; $iteration++) {
    Write-Output "=== test iteration $iteration / $Iterations ==="
    $log = Join-Path $tmp 'test.log'
    $stdoutFile = Join-Path $tmp ("test-" + [guid]::NewGuid().ToString('N') + '.stdout')
    $stderrFile = Join-Path $tmp ("test-" + [guid]::NewGuid().ToString('N') + '.stderr')
    try {
        $mavenArgs = @('-B', "-Dmaven.repo.local=$m2", 'test')
        $process = Start-Process -FilePath $maven -ArgumentList (ConvertTo-NativeArgumentString $mavenArgs) -WorkingDirectory $projectDir -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile
        $stdout = if (Test-Path -LiteralPath $stdoutFile) { [IO.File]::ReadAllText($stdoutFile) } else { '' }
        $stderr = if (Test-Path -LiteralPath $stderrFile) { [IO.File]::ReadAllText($stderrFile) } else { '' }
        [IO.File]::WriteAllText($log, $stdout + $stderr, [Text.UTF8Encoding]::new($false))
        $testExitCode = [int]$process.ExitCode
    } finally {
        Remove-Item -LiteralPath $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
    }

    if ($testExitCode -eq 0) {
        Write-Output "Tests succeeded on iteration $iteration"
        exit 0
    }

    Write-Output 'Tests failed. Sending report to AI reviewer...'
    Get-Content -LiteralPath $log -Tail 80
    if ($iteration -eq $Iterations) {
        Write-Output 'Max iterations reached. Giving up.'
        Get-Content -LiteralPath $log
        throw "Max iterations reached. Maven exit code: $testExitCode"
    }

    $sourceFiles = Get-ChildItem -LiteralPath (Join-Path $projectDir 'src/main/java') -Filter '*.java' -Recurse
    $testFiles = Get-ChildItem -LiteralPath (Join-Path $projectDir 'src/test/java') -Filter '*.java' -Recurse
    $sources = ($sourceFiles + $testFiles | ForEach-Object {
        $relativePath = $_.FullName.Substring($projectDir.Length + 1).Replace('\', '/')
        "--- $relativePath ---"
        Get-Content -LiteralPath $_.FullName -Raw
    }) -join "`n"
    $pom = Get-Content -LiteralPath (Join-Path $projectDir 'pom.xml') -Raw
    $testLog = (Get-Content -LiteralPath $log -Tail 80) -join "`n"

    $prompt = @"
You are a Java test-error reviewer. The Maven project below failed its tests.
Fix the code (and pom.xml if needed) so all tests pass. Do not remove tests unless they are invalid.
Return ONLY a JSON object with keys: pom_xml, and for each Java file you change, key = relative path like "src/main/java/com/example/demo/Luhn.java" or "src/test/java/com/example/demo/LuhnTest.java".
Escape newlines in strings as \n and quotes as \".

pom.xml:
$pom

Test error:
$testLog

Source files:
$sources
"@

    $promptFile = Join-Path $tmp 'ai_review_test_prompt.txt'
    $reqFile = Join-Path $tmp 'ai_review_test_request.json'
    $respFile = Join-Path $tmp 'ai_review_test.json'
    [IO.File]::WriteAllText($promptFile, $prompt, [Text.UTF8Encoding]::new($false))
    $aiScript = Join-Path $repo 'internal/scripts/ai/review_fix_v2.py'
    $aiStdoutFile = Join-Path $tmp ("ai-review-test-" + [guid]::NewGuid().ToString('N') + '.stdout')
    $aiStderrFile = Join-Path $tmp ("ai-review-test-" + [guid]::NewGuid().ToString('N') + '.stderr')
    $aiArgs = @($aiScript, $projectDir, $Package.Replace('.', '/'), $promptFile, $reqFile, $respFile, $Model, $baseUrl, $token)
    try {
        $aiProcess = Start-Process -FilePath $Python -ArgumentList (ConvertTo-NativeArgumentString $aiArgs) -Wait -PassThru -NoNewWindow -RedirectStandardOutput $aiStdoutFile -RedirectStandardError $aiStderrFile
        $aiStdout = if (Test-Path -LiteralPath $aiStdoutFile) { [IO.File]::ReadAllText($aiStdoutFile) } else { '' }
        $aiStderr = if (Test-Path -LiteralPath $aiStderrFile) { [IO.File]::ReadAllText($aiStderrFile) } else { '' }
        if ($token) { $aiStderr = $aiStderr.Replace($token, '[REDACTED]') }
        if ($aiStdout) { [Console]::Out.Write($aiStdout) }
        if ($aiProcess.ExitCode -ne 0) {
            [Console]::Error.WriteLine("AI review/fix failed: python=$Python script=$aiScript exit_code=$($aiProcess.ExitCode) stderr=$aiStderr")
            throw "AI review/fix failed."
        }
    } finally {
        Remove-Item -LiteralPath $aiStdoutFile, $aiStderrFile -Force -ErrorAction SilentlyContinue
    }
    # TODO: Apply AI changes (parse $respFile and update files)
}
throw "Test fix loop failed."
