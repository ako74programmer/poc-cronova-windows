[CmdletBinding()]
param(
    [Alias('w')][string]$Workspace,
    [Alias('p')][string]$Project = 'demo',
    [Alias('k')][string]$Package = 'com.example.demo',
    [Alias('r')][string]$ProviderId,
    [Alias('m')][string]$Model,
    [Alias('y')][string]$Python
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common\toolchain.ps1')
. (Join-Path $PSScriptRoot 'common\ai-provider.ps1')
$repo = Get-RepoRoot
if (-not $Workspace) { $Workspace = Join-Path $repo 'workspaces\springboot-demo' }
$projectDir = Resolve-RepoPath (Join-Path $Workspace $Project)
if (-not (Test-Path -LiteralPath $projectDir -PathType Container)) { throw "Project directory not found: $projectDir" }
if (-not $Python -or $Python -in @('python','python3')) { $Python = $env:CRONOVA_PYTHON }
if (-not $Python) { $Python = Get-ConfiguredCommand 'python' } else { $resolved = Get-Command $Python -ErrorAction SilentlyContinue; if ($resolved) { $Python = $resolved.Source } }
$baseUrl = $env:CRONOVA_AI_BASE_URL; $token = $env:CRONOVA_AI_TOKEN
$db = if ($env:CRONOVA_DB) { $env:CRONOVA_DB } else { Join-Path $repo 'data\cronova.db' }
if (-not $Model -or -not $baseUrl) { $provider = Resolve-AiProvider $db $ProviderId; if ($provider) { if (-not $baseUrl) {$baseUrl=$provider[0]}; if (-not $Model) {$Model=$provider[1]}; if (-not $token) {$token=$provider[2]} } }
if (-not $Model -or -not $baseUrl) { throw 'Could not determine AI provider. Configure a default AI provider or pass -r and -m.' }
$tmp = Join-Path $repo '.tmp'; New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$packagePath = $Package.Replace('.', '\')
New-Item -ItemType Directory -Force -Path (Join-Path $projectDir "src\main\java\$packagePath\api"),(Join-Path $projectDir "src\main\java\$packagePath\model") | Out-Null
$pom = Get-Content (Join-Path $projectDir 'pom.xml') -Raw
$app = Get-Content (Join-Path $projectDir "src\main\java\$packagePath\DemoApplication.java") -Raw
$prompt = @"
You are a Java/Spring Boot code generator.
Given the pom.xml and DemoApplication.java below, do two things:
1. Ensure pom.xml contains dependencies for Spring Boot web and validation. Do not add version tags for dependencies managed by the Spring Boot parent POM.
2. Add a simple Item CRUD: create Item.java in model package and ItemController.java in api package. Item fields: Long id, String name. Controller endpoints GET /items, POST /items, GET /items/{id}, DELETE /items/{id}. Store items in a java.util.Map<Long, Item>. Use jakarta.validation.constraints.NotBlank and jakarta.validation.Valid, not javax.validation.
Return ONLY a JSON object with keys: pom_xml, Item_java, ItemController_java.

pom.xml:
$pom
DemoApplication.java:
$app
"@
$promptFile=Join-Path $tmp 'ai_prompt.txt'; $reqFile=Join-Path $tmp 'ai_request.json'; $respFile=Join-Path $tmp 'ai_response.json'; Set-Content $promptFile $prompt -Encoding UTF8
$script=Join-Path $repo 'internal\scripts\ai\add_crud.py'
& $Python $script $projectDir ($Package.Replace('.','/')) $promptFile $reqFile $respFile $Model $baseUrl $token
if ($LASTEXITCODE -ne 0) { throw "AI CRUD generation failed with exit code $LASTEXITCODE" }
Write-Output "AI added CRUD to $projectDir"
