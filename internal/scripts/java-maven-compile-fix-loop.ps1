[CmdletBinding()]
param(
    [Alias('LoopWorkspace')][string]$WorkspacePath,
    [Alias('LoopProject')][string]$ProjectName = 'demo',
    [Alias('LoopPackage')][string]$JavaPackage = 'com.example.demo',
    [Alias('LoopIterations')][int]$Iterations = 3,
    [Alias('LoopProvider')][string]$ProviderId,
    [Alias('LoopModel')][string]$Model,
    [Alias('LoopPython')][string]$Python
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common\toolchain.ps1')
. (Join-Path $PSScriptRoot 'common\ai-provider.ps1')

$repo = Get-RepoRoot
$workspace = if ($WorkspacePath) { $WorkspacePath } else { Join-Path $repo 'workspaces\springboot-demo' }
$projectDir = Resolve-RepoPath (Join-Path $workspace $ProjectName)
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

$tmp = Join-Path $repo '.tmp'
$m2 = Join-Path $repo '.m2\repository'
New-Item -ItemType Directory -Force -Path $tmp, $m2 | Out-Null
Set-JavaMavenToolchain
$maven = Get-ConfiguredCommand 'maven'

for ($iteration = 1; $iteration -le $Iterations; $iteration++) {
    Write-Output "=== compile iteration $iteration / $Iterations ==="
    $log = Join-Path $tmp 'compile.log'
    $stdoutFile = Join-Path $tmp ("compile-" + [guid]::NewGuid().ToString('N') + '.stdout')
    $stderrFile = Join-Path $tmp ("compile-" + [guid]::NewGuid().ToString('N') + '.stderr')
    try {
        $mavenArgs = @('-B', "-Dmaven.repo.local=$m2", '-DskipTests', 'test-compile')
        $process = Start-Process -FilePath $maven -ArgumentList (ConvertTo-NativeArgumentString $mavenArgs) -WorkingDirectory $projectDir -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile
        $stdout = if (Test-Path -LiteralPath $stdoutFile) { [IO.File]::ReadAllText($stdoutFile) } else { '' }
        $stderr = if (Test-Path -LiteralPath $stderrFile) { [IO.File]::ReadAllText($stderrFile) } else { '' }
        [IO.File]::WriteAllText($log, $stdout + $stderr, [Text.UTF8Encoding]::new($false))
        $compileExitCode = [int]$process.ExitCode
    } finally {
        Remove-Item -LiteralPath $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
    }

    if ($compileExitCode -eq 0) {
        Write-Output "Test compile succeeded on iteration $iteration"
        exit 0
    }

    Write-Output 'Test compile failed. Sending report to AI reviewer...'
    Get-Content -LiteralPath $log -Tail 80
    if ($iteration -eq $Iterations) {
        Write-Output 'Max iterations reached. Giving up.'
        Get-Content -LiteralPath $log
        throw "Max iterations reached. Maven exit code: $compileExitCode"
    }

    $sourceFiles = @(
        Get-ChildItem -LiteralPath (Join-Path $projectDir 'src\main\java') -Filter '*.java' -Recurse -ErrorAction SilentlyContinue
        Get-ChildItem -LiteralPath (Join-Path $projectDir 'src\test\java') -Filter '*.java' -Recurse -ErrorAction SilentlyContinue
    )
    $sources = ($sourceFiles | Sort-Object FullName | ForEach-Object {
        $relativePath = $_.FullName.Substring($projectDir.Length + 1).Replace('\\', '/')
        "--- $relativePath ---"
        Get-Content -LiteralPath $_.FullName -Raw
    }) -join "`n"
    $pom = Get-Content -LiteralPath (Join-Path $projectDir 'pom.xml') -Raw
    $compileLog = (Get-Content -LiteralPath $log -Tail 80) -join "`n"

    $prompt = @"
You are a Java build-error reviewer. The Maven project below failed during test compilation.
Fix the code (and pom.xml if needed) so both main and test sources compile.
IMPORTANT:
- do NOT add <version> tags to dependencies that are managed by the Spring Boot parent POM. Use only <groupId> and <artifactId> for Spring Boot starters.
- preserve the existing Spring Boot version and starter family already present in pom.xml.
- if pom.xml already uses Spring Boot 4 webmvc starters, keep using the matching webmvc/webmvc-test family instead of switching to Boot 3 style starter names.
- do not leave test imports that are unsupported by the current pom.xml.
- if test imports from org.springframework.boot.test.autoconfigure.web.servlet are unsupported, replace those tests with simpler scaffold-compatible tests instead of keeping unsupported annotations.
- for simple CRUD/controller slices, prefer only direct in-memory controller tests that instantiate the controller and call its methods.
- do NOT generate or keep tests using MockMvc, WebMvcTest, AutoConfigureMockMvc, MockBean, RestTemplate, TestRestTemplate, localhost HTTP calls, random ports, or full HTTP integration paths unless the compile error explicitly proves that such infrastructure is already supported and required.
- do NOT switch test style between iterations; keep or rewrite tests to the simplest direct-controller style when fixing compile errors in CRUD scaffolds.
- when asserting ResponseEntity values, use only methods that are supported by the currently compiled Spring version and the actual return type in source; do not invent helper methods.
- do NOT use `getStatusCodeValue()`; prefer `getStatusCode().value()` or another compatible assertion on `getStatusCode()`.
- Use jakarta.validation.constraints.NotBlank and jakarta.validation.Valid (NOT javax.validation).
Return ONLY a JSON object with keys: pom_xml, and for each Java file you change, key = relative path like "src/main/java/com/example/demo/api/ItemController.java".
Escape newlines in strings as \n and quotes as \".

pom.xml:
$pom

Test compile error:
$compileLog

Source files:
$sources
"@

    $promptFile = Join-Path $tmp 'ai_review_prompt.txt'
    $reqFile = Join-Path $tmp 'ai_review_request.json'
    $respFile = Join-Path $tmp 'ai_review.json'
    [IO.File]::WriteAllText($promptFile, $prompt, [Text.UTF8Encoding]::new($false))
    $reviewParams = @{
        Workspace = $workspace
        Project = $ProjectName
        Package = $JavaPackage
        ProviderId = $ProviderId
        Model = $Model
        Python = $Python
        PromptFile = $promptFile
        RequestFile = $reqFile
        ResponseFile = $respFile
    }
    & (Join-Path $PSScriptRoot 'ai-review-java-maven-errors.ps1') @reviewParams
}