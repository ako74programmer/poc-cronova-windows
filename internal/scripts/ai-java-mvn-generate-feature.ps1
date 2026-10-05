[CmdletBinding()]
param(
    [Alias('f')][Parameter(Mandatory=$true)][string]$PromptFile,
    [Alias('w')][string]$Workspace,
    [Alias('p')][string]$Project = 'demo',
    [Alias('k')][string]$Package = 'com.example',
    [Alias('r')][string]$ProviderId,
    [Alias('m')][string]$Model,
    [Alias('y')][string]$Python,
    [Alias('s')][switch]$IncludeSources
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
$pomFile = Join-Path $projectDir 'pom.xml'
$pom = if (Test-Path -LiteralPath $pomFile) { Get-Content -LiteralPath $pomFile -Raw } else { '' }
if (-not $pom) { throw "pom.xml not found in project directory: $projectDir" }

$sourceContext = ''
if ($IncludeSources) {
    $javaFiles = Get-ChildItem -Path $projectDir -Recurse -Filter '*.java' -ErrorAction SilentlyContinue |
        Where-Object { $_.Length -gt 0 } |
        Sort-Object FullName
    if ($javaFiles) {
        $sourceContext = ($javaFiles | ForEach-Object {
            $relative = $_.FullName.Substring($projectDir.Length).TrimStart('\', '/')
            "--- $relative ---`n" + (Get-Content -LiteralPath $_.FullName -Raw)
        }) -join "`n`n"
    }
}

$userPrompt = Get-Content -LiteralPath $promptPath -Raw
$fullPrompt = @"
You are a Java code generator for Maven projects.
$userPrompt

Given the Maven project below, return ONLY a JSON object where:
- keys are relative file paths (e.g. "src/main/java/com/example/luhn/Luhn.java", "src/test/java/com/example/luhn/LuhnTest.java")
- values are full file contents as strings
- optional key "pom_xml" = complete updated pom.xml content ONLY if new dependencies are required; omit this key if no dependency changes are needed

Rules:
- Do NOT add <version> tags to dependencies managed by the Maven parent or BOM.
- Generate new classes for the requested feature and corresponding tests.
- Do NOT assume existing source files have specific names like App.java or AppTest.java.
- If you generate code or tests that require dependencies not present in pom.xml, you MUST return a complete updated pom_xml.
- Before omitting pom_xml, verify that every import used by the generated Java and test files is already satisfied by the current pom.xml.
- If you generate JUnit 4 or JUnit 5 style tests and the current pom.xml only contains older JUnit dependencies, you MUST update pom_xml accordingly.
- For simple Spring controller CRUD features, generate only direct in-memory controller tests that instantiate the controller class and call its methods.
- Do NOT generate tests using MockMvc, WebMvcTest, AutoConfigureMockMvc, MockBean, RestTemplate, TestRestTemplate, random ports, localhost HTTP calls, or any Spring MVC/web test infrastructure unless the user prompt explicitly requires that style.
- For controller tests, assert on the actual ResponseEntity API available in the current dependency set and on the actual return type of the controller method; do not assume List, HTTP clients, or helper methods that are not already present.
- Do NOT use `getStatusCodeValue()`. Prefer `getStatusCode().value()` or boolean/status comparisons supported by the current Spring API.
- Escape JSON string newlines as \n (one backslash followed by n); do not leave literal backslash-n text in generated file contents. Escape quotes as \".

pom.xml:
$pom

$sourceContext
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
