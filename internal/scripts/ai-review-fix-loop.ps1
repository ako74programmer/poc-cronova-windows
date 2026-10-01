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
. (Join-Path $PSScriptRoot 'common\toolchain.ps1')
. (Join-Path $PSScriptRoot 'common\ai-provider.ps1')
$repo=Get-RepoRoot; if (-not $Workspace) {$Workspace=Join-Path $repo 'workspaces\springboot-demo'}; $projectDir=Resolve-RepoPath (Join-Path $Workspace $Project)
if (-not (Test-Path $projectDir -PathType Container)) {throw "Project directory not found: $projectDir"}
if (-not $Python -or $Python -in @('python','python3')) {$Python=$env:CRONOVA_PYTHON}; if (-not $Python) {$Python=Get-ConfiguredCommand 'python'} else {$r=Get-Command $Python -ErrorAction SilentlyContinue;if($r){$Python=$r.Source}}
$baseUrl=$env:CRONOVA_AI_BASE_URL;$token=$env:CRONOVA_AI_TOKEN;$db=if($env:CRONOVA_DB){$env:CRONOVA_DB}else{Join-Path $repo 'data\cronova.db'}
if(-not $Model -or -not $baseUrl){$provider=Resolve-AiProvider $db $ProviderId;if($provider){if(-not $baseUrl){$baseUrl=$provider[0]};if(-not $Model){$Model=$provider[1]};if(-not $token){$token=$provider[2]}}}
if(-not $Model -or -not $baseUrl){throw 'Could not determine AI provider. Configure a default AI provider or pass -r and -m.'}
$tmp=Join-Path $repo '.tmp';New-Item -ItemType Directory -Force $tmp|Out-Null;Set-JavaMavenToolchain;$maven=Get-ConfiguredCommand 'maven';$m2=Join-Path $repo '.m2\repository';New-Item -ItemType Directory -Force $m2|Out-Null
for($iter=1;$iter -le $Iterations;$iter++){
    Write-Output "=== compile iteration $iter / $Iterations ==="
    $log=Join-Path $tmp 'compile.log'; Push-Location $projectDir; try {& $maven '-B' "-Dmaven.repo.local=$m2" '-DskipTests' 'compile' 2>&1 | Tee-Object $log;$code=if(Test-Path variable:LASTEXITCODE){[int]$LASTEXITCODE}else{0}} finally {Pop-Location}
    if($code -eq 0){Write-Output "Compile succeeded on iteration $iter";exit 0}
    Get-Content $log -Tail 80
    if($iter -eq $Iterations){throw 'Max iterations reached. Giving up.'}
    $sources=(Get-ChildItem (Join-Path $projectDir 'src\main\java') -Filter '*.java' -Recurse | ForEach-Object {"--- $($_.FullName.Substring($projectDir.Length+1)) ---";Get-Content $_.FullName -Raw}) -join "`n"
    $pom=Get-Content (Join-Path $projectDir 'pom.xml') -Raw;$compileLog=(Get-Content $log -Tail 80)-join "`n"
    $prompt=@"
You are a Java build-error reviewer. Fix the Spring Boot project below so it compiles. Keep the Item CRUD functionality. Do not add versions to Spring Boot managed dependencies. Use jakarta validation, not javax. Return ONLY a JSON object with key pom_xml and keys for changed Java files using relative paths.
pom.xml:
$pom
Compile error:
$compileLog
Source files:
$sources
"@
    $promptFile=Join-Path $tmp 'ai_review_prompt.txt';$reqFile=Join-Path $tmp 'ai_review_request.json';$respFile=Join-Path $tmp 'ai_review.json';Set-Content $promptFile $prompt -Encoding UTF8
    & $Python (Join-Path $repo 'internal\scripts\ai\review_fix_v2.py') $projectDir ($Package.Replace('.','/')) $promptFile $reqFile $respFile $Model $baseUrl $token
    $exitCode=if(Test-Path variable:LASTEXITCODE){[int]$LASTEXITCODE}else{0}; if($exitCode -ne 0){throw "AI review/fix failed with exit code $exitCode"}
}
