[CmdletBinding()]
param(
    [Alias('f')][Parameter(Mandatory=$true)][string]$PromptFile,
    [Alias('w')][string]$Workspace,
    [Alias('p')][string]$Project = 'demo',
    [Alias('k')][string]$Package = 'com.example',
    [Alias('r')][string]$ProviderId,
    [Alias('m')][string]$Model,
    [Alias('y')][string]$Python
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common\toolchain.ps1')
. (Join-Path $PSScriptRoot 'common\ai-provider.ps1')
$repo = Get-RepoRoot
if (-not $PromptFile) { throw 'Prompt file is required.' }
$promptPath = Resolve-RepoPath $PromptFile
if (-not (Test-Path -LiteralPath $promptPath -PathType Leaf)) { throw "Prompt file not found: $promptPath" }
if (-not $Workspace) { $Workspace = Join-Path $repo 'workspaces\maven-demo' }
$projectDir = Resolve-RepoPath (Join-Path $Workspace $Project)
if (-not (Test-Path -LiteralPath $projectDir -PathType Container)) { throw "Project directory not found: $projectDir" }
if (-not $Python -or $Python -in @('python','python3')) { $Python = $env:CRONOVA_PYTHON }
if (-not $Python) { $Python = Get-ConfiguredCommand 'python' }
else { $resolved = Get-Command $Python -ErrorAction SilentlyContinue; if ($resolved) { $Python = $resolved.Source } }
$baseUrl = $env:CRONOVA_AI_BASE_URL
$token = $env:CRONOVA_AI_TOKEN
$db = if ($env:CRONOVA_DB) { $env:CRONOVA_DB } else { Join-Path $repo 'data\cronova.db' }
if (-not $Model -or -not $baseUrl) {
    $provider = Resolve-AiProvider $db $ProviderId $Python
    if ($provider) { if (-not $baseUrl) {$baseUrl=$provider[0]}; if (-not $Model) {$Model=$provider[1]}; if (-not $token) {$token=$provider[2]} }
}
if (-not $Model -or -not $baseUrl) { throw 'Could not determine AI provider. Configure a default AI provider or pass -r and -m.' }
$tmp = Join-Path $repo '.tmp'; New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$packagePath = $Package.Replace('.', '\')
$pom = if (Test-Path (Join-Path $projectDir 'pom.xml')) { Get-Content (Join-Path $projectDir 'pom.xml') -Raw } else { '' }
$appFile = Join-Path $projectDir "src\main\java\$packagePath\App.java"
$testFile = Join-Path $projectDir "src\test\java\$packagePath\AppTest.java"
$app = if (Test-Path $appFile) { Get-Content $appFile -Raw } else { '' }
$test = if (Test-Path $testFile) { Get-Content $testFile -Raw } else { '' }
$userPrompt = Get-Content -LiteralPath $promptPath -Raw
$fullPrompt = @"
You are a Java code generator.
$userPrompt

Given the project below, return ONLY a JSON object where:
- key = relative file path (e.g. "src/main/java/com/example/luhn/Luhn.java" or "src/test/java/com/example/luhn/LuhnTest.java")
- value = full file content as a string
- optional key "pom_xml" = updated pom.xml if dependencies need changes

Do NOT add <version> tags to dependencies managed by the Maven parent or BOM.
Escape JSON string newlines as \n (one backslash followed by n); do not leave literal backslash-n text in generated file contents. Escape quotes as \".

pom.xml:
$pom

App.java:
$app

AppTest.java:
$test
"@
$fullPromptFile=Join-Path $tmp 'ai_feature_prompt.txt'; $reqFile=Join-Path $tmp 'ai_feature_request.json'; $respFile=Join-Path $tmp 'ai_feature_response.json'
Set-Content -LiteralPath $fullPromptFile -Value $fullPrompt -Encoding UTF8
Write-Output "Calling AI provider (model: $Model, url: $baseUrl)..."
$aiScript = Join-Path $repo 'internal\scripts\ai_generate_feature.py'
$stdoutFile=Join-Path $tmp 'ai_feature.stdout'; $stderrFile=Join-Path $tmp 'ai_feature.stderr'
try {
    $aiArgs=@($aiScript,$projectDir,$fullPromptFile,$reqFile,$respFile,$Model,$baseUrl)
    if($token){$aiArgs += $token}
    $process=Start-Process -FilePath $Python -ArgumentList $aiArgs -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile
    $stdout=Get-Content $stdoutFile -ErrorAction SilentlyContinue; $stderr=(Get-Content $stderrFile -ErrorAction SilentlyContinue)-join [Environment]::NewLine
    $stdout | Write-Output
    if($process.ExitCode -ne 0){throw "AI feature generation failed with exit code $($process.ExitCode): $stderr"}
} finally { Remove-Item -LiteralPath $stdoutFile,$stderrFile -Force -ErrorAction SilentlyContinue }
Write-Output "AI added feature to $projectDir"
