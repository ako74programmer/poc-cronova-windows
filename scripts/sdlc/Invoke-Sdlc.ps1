[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Step,
    [Parameter(Mandatory=$true)][string]$Config,
    [string]$Workspace,
    [string]$Artifacts
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
function Resolve-RepoPath([string]$p) {
    if ([IO.Path]::IsPathRooted($p)) { return $p }
    return (Join-Path $repo $p)
}
function Value([string]$file, [string]$section, [string]$key) {
    $lines = Get-Content -LiteralPath (Resolve-RepoPath $file)
    $inside = $false
    foreach ($line in $lines) {
        if ($line -match ('^' + [regex]::Escape($section) + ':\s*$')) { $inside = $true; continue }
        if ($inside -and $line -match '^\S') { $inside = $false }
        if ($inside -and $line -match ('^\s{2}' + [regex]::Escape($key) + ':\s*(.*)$')) {
            return $Matches[1].Trim().Trim('"').Trim("'")
        }
    }
    return ''
}
function Required([string]$name, [string]$value) { if ([string]::IsNullOrWhiteSpace($value)) { throw "Missing configuration value: $name" } }
function Tool([string]$name) {
    $explicit = switch ($name) {
        'python' { $env:CRONOVA_PYTHON }
        'node' { $env:CRONOVA_NODE }
        'npm' { $env:CRONOVA_NPM }
        'java' { if ($env:CRONOVA_JAVA_HOME) { Join-Path $env:CRONOVA_JAVA_HOME 'bin\java.exe' } elseif ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME 'bin\java.exe' } }
        'mvn' { if ($env:CRONOVA_MAVEN_HOME) { Join-Path $env:CRONOVA_MAVEN_HOME 'bin\mvn.cmd' } elseif ($env:MAVEN_HOME) { Join-Path $env:MAVEN_HOME 'bin\mvn.cmd' } }
        'npx' { if ($env:CRONOVA_NODE) { Join-Path (Split-Path -Parent $env:CRONOVA_NODE) 'npx.cmd' } }
    }
    if ($explicit -and (Test-Path -LiteralPath $explicit)) { return $explicit }
    if ($explicit) {
        $resolvedExplicit = Get-Command $explicit -ErrorAction SilentlyContinue
        if ($resolvedExplicit) { return $resolvedExplicit.Source }
    }
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if (-not $cmd) { throw "Required command not found: $name" }
    return $cmd.Source
}
function Run([string]$exe, [string[]]$args, [string]$cwd=$repo, [string]$log='') {
    if ($log) { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $log) | Out-Null }
    Push-Location $cwd
    try {
        if ($log) { & $exe @args 2>&1 | Tee-Object -FilePath $log; if ($LASTEXITCODE -ne 0) { throw "$exe failed with exit code $LASTEXITCODE" } }
        else { & $exe @args; if ($LASTEXITCODE -ne 0) { throw "$exe failed with exit code $LASTEXITCODE" } }
    } finally { Pop-Location }
}
function Copy-Tree([string]$source, [string]$dest) {
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Copy-Item -LiteralPath $source -Destination $dest -Recurse -Force
}
function Init([string]$componentConfig='') {
    if (-not $Workspace) { $script:Workspace = if ($componentConfig) { Resolve-RepoPath (Value $componentConfig 'workspace' 'directory') } else { $repo } }
    if (-not $Artifacts) { $script:Artifacts = Resolve-RepoPath (Value $Config 'artifacts' 'directory') }
    New-Item -ItemType Directory -Force -Path (Join-Path $Artifacts 'logs'),(Join-Path $Artifacts 'reports'),(Join-Path $Artifacts 'metadata') | Out-Null
}
function JsonFile([string]$path, [hashtable]$data) { $data | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $path -Encoding UTF8 }
function ConfigPath([string]$rootConfig, [string]$section, [string]$key) { Resolve-RepoPath (Value $rootConfig $section $key) }

switch ($Step) {
'validate-stack' {
    Init
    Tool python | Out-Null
    $angular = ConfigPath $Config 'stack' 'angular_config'; $spring = ConfigPath $Config 'stack' 'springboot_config'; $openapi = ConfigPath $Config 'stack' 'openapi_file'
    foreach ($p in @($angular,$spring,$openapi)) { if (-not (Test-Path $p)) { throw "Configured file not found: $p" } }
    Run (Tool python) @((Join-Path $repo 'scripts\sdlc\integration\generate_contract_app.py'),'--contract',$openapi) $repo (Join-Path $Artifacts 'logs\contract-validation.log')
    Write-Output "Full-stack configuration is valid: $Config"
}
'validate-frontend' {
    $cfg = 'configs\sdlc-angular.yaml'; Init $cfg; Tool node | Out-Null; Tool npm | Out-Null
    if ((Get-Content (Resolve-RepoPath $cfg) -join "`n") -notmatch 'kind:\s*angular') { throw 'Angular config kind is invalid' }
    & node --version | Tee-Object (Join-Path $Artifacts 'metadata\node-version.txt'); & npm --version | Tee-Object (Join-Path $Artifacts 'metadata\npm-version.txt')
}
'validate-backend' {
    $cfg = 'configs\sdlc-springboot.yaml'; Init $cfg; Tool java | Out-Null
    if ((Get-Content (Resolve-RepoPath $cfg) -join "`n") -notmatch 'kind:\s*springboot') { throw 'Spring Boot config kind is invalid' }
    & java -version 2> (Join-Path $Artifacts 'metadata\java-version.txt'); if ($LASTEXITCODE -ne 0) { throw 'java -version failed' }
}
'scaffold-frontend' {
    $cfg='configs\sdlc-angular.yaml'; Init $cfg; Tool npx | Out-Null
    $cli=Value $cfg 'runtime' 'angular_cli_version'; if (-not $cli) {$cli='20'}; $name=Value $cfg 'angular' 'app_name'; if (-not $name) {$name='item-portal'}
    if (-not (Test-Path (Join-Path $Workspace 'package.json'))) { New-Item -ItemType Directory -Force -Path $Workspace | Out-Null; Run (Tool npx) @('--yes',"@angular/cli@$cli",'new',$name,'--directory',$Workspace,'--routing','--style=scss','--standalone','--skip-git','--package-manager=npm','--skip-install') }
    Run (Tool npm) @('install','--package-lock-only','--ignore-scripts') $Workspace (Join-Path $Artifacts 'logs\angular-scaffold.log')
}
'scaffold-backend' {
    $cfg='configs\sdlc-springboot.yaml'; Init $cfg; Tool curl | Out-Null
    if (-not (Test-Path (Join-Path $Workspace 'pom.xml'))) {
        $boot=Value $cfg 'runtime' 'spring_boot_version'; if (-not $boot){$boot='3.5.5'}; $java=Value $cfg 'runtime' 'java_version'; if (-not $java){$java='21'}; $group=Value $cfg 'springboot' 'group_id'; if (-not $group){$group='com.example'}; $artifact=Value $cfg 'springboot' 'artifact_id'; if (-not $artifact){$artifact='item-service'}; $pkg=Value $cfg 'springboot' 'package_name'; if (-not $pkg){$pkg='com.example.item'}
        $url="https://start.spring.io/starter.zip?type=maven-project&language=java&bootVersion=$boot&javaVersion=$java&groupId=$group&artifactId=$artifact&name=$artifact&packageName=$pkg&packaging=jar&configFormat=yaml&dependencies=web,validation,actuator"
        $zip=Join-Path $Artifacts 'metadata\springboot-starter.zip'; Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $zip; Expand-Archive -LiteralPath $zip -DestinationPath $Workspace -Force
    }
}
'generate-contract' {
    Init; Tool python | Out-Null; $openapi=ConfigPath $Config 'stack' 'openapi_file'; $angular=ConfigPath $Config 'stack' 'angular_config'; $spring=ConfigPath $Config 'stack' 'springboot_config'; $aw=Resolve-RepoPath (Value $angular 'workspace' 'directory'); $sw=Resolve-RepoPath (Value $spring 'workspace' 'directory'); $pkg=Value $spring 'springboot' 'package_name'; $api=Value $angular 'api' 'base_url'; $origin=Value $Config 'services' 'frontend_url'
    Run (Tool python) @((Join-Path $repo 'scripts\sdlc\integration\generate_contract_app.py'),'--contract',$openapi,'--backend-workspace',$sw,'--frontend-workspace',$aw,'--backend-package',$pkg,'--api-base-url',$api,'--frontend-origin',$origin)
}
'install-frontend' { Init 'configs\sdlc-angular.yaml'; Run (Tool npm) @('ci') $Workspace (Join-Path $Artifacts 'logs\angular-npm-ci.log') }
'lint-frontend' { Init 'configs\sdlc-angular.yaml'; Run (Tool npm) @('run','lint') $Workspace (Join-Path $Artifacts 'logs\angular-lint.log') }
'test-frontend' { Init 'configs\sdlc-angular.yaml'; Run (Tool npm) @('test','--','--watch=false') $Workspace (Join-Path $Artifacts 'logs\angular-unit-tests.log') }
'build-frontend' {
    Init 'configs\sdlc-angular.yaml'; $conf=Value 'configs\sdlc-angular.yaml' 'angular' 'build_configuration'; if (-not $conf){$conf='production'}; Run (Tool npm) @('run','build','--','--configuration',$conf) $Workspace (Join-Path $Artifacts 'logs\angular-build.log')
    $dist=Join-Path $Workspace (Value 'configs\sdlc-angular.yaml' 'angular' 'output_path'); if (-not (Test-Path (Join-Path $dist 'index.html'))) { $dist=(Get-ChildItem (Join-Path $Workspace 'dist') -Filter index.html -Recurse | Select-Object -First 1).DirectoryName }; if (-not $dist){throw 'Angular build did not produce index.html'}
    $out=Join-Path $Artifacts 'dist\browser'; if (Test-Path $out){Remove-Item $out -Recurse -Force}; Copy-Tree $dist $out; (Get-FileHash (Join-Path $dist 'index.html') -Algorithm SHA256).Hash | Set-Content (Join-Path $Artifacts 'metadata\frontend-index.sha256'); JsonFile (Join-Path $Artifacts 'frontend-manifest.json') @{component='angular'; project=$Workspace; artifact_directory=$out; result='success'}
}
'smoke-frontend' { Init 'configs\sdlc-angular.yaml'; $index=Join-Path $Artifacts 'dist\browser\index.html'; if (-not (Test-Path $index)){throw 'Frontend artifact missing'}; if ((Get-Content $index -Raw) -notmatch '(?i)<html'){throw 'index.html is not valid HTML'} }
'compile-backend' { Init 'configs\sdlc-springboot.yaml'; Run (Join-Path $Workspace 'mvnw.cmd') @('-B','-DskipTests','compile') $Workspace (Join-Path $Artifacts 'logs\springboot-compile.log') }
'test-backend' { Init 'configs\sdlc-springboot.yaml'; Run (Join-Path $Workspace 'mvnw.cmd') @('-B','test') $Workspace (Join-Path $Artifacts 'logs\springboot-unit-tests.log') }
'package-backend' {
    Init 'configs\sdlc-springboot.yaml'; Run (Join-Path $Workspace 'mvnw.cmd') @('-B','package','-DskipTests') $Workspace (Join-Path $Artifacts 'logs\springboot-package.log'); $jar=Get-ChildItem (Join-Path $Workspace 'target') -Filter *.jar | Where-Object {$_.Name -notlike '*-plain.jar'} | Select-Object -First 1; if (-not $jar){throw 'Executable Spring Boot JAR not found'}; $out=Join-Path $Artifacts 'package\item-service.jar'; New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null; Copy-Item $jar.FullName $out -Force; (Get-FileHash $jar.FullName -Algorithm SHA256).Hash | Set-Content "$out.sha256"; JsonFile (Join-Path $Artifacts 'backend-manifest.json') @{component='springboot';artifact=$out;source_directory=$Workspace;result='success'}
}
'install-playwright' { Init; $e2e=Resolve-RepoPath (Value $Config 'playwright' 'directory'); Run (Tool npm) @('ci') $e2e (Join-Path $Artifacts 'logs\playwright-install.log'); Run (Tool npx) @('playwright','install',(Value $Config 'playwright' 'browser')) $e2e }
'start-backend' {
    Init; $jar=Resolve-RepoPath (Value $Config 'artifacts' 'backend_jar'); $backendHost=Value $Config 'services' 'backend_host'; $port=Value $Config 'services' 'backend_port'; $profile=Value $Config 'services' 'backend_profile'; New-Item -ItemType Directory -Force (Join-Path $Artifacts 'runtime') | Out-Null; $log=Join-Path $Artifacts 'runtime\backend.log'; $javaCmdArgs=@('-jar',$jar,"--server.address=$backendHost","--server.port=$port"); if($profile){$javaCmdArgs += "--spring.profiles.active=$profile"}; $p=Start-Process -FilePath (Tool java) -ArgumentList $javaCmdArgs -RedirectStandardOutput $log -RedirectStandardError ($log + '.err') -PassThru; $p.Id | Set-Content (Join-Path $Artifacts 'runtime\backend.pid')
}
'start-frontend' {
    Init; $dist=Resolve-RepoPath (Value $Config 'artifacts' 'frontend_dist'); $frontendHost=Value $Config 'services' 'frontend_host'; $port=Value $Config 'services' 'frontend_port'; New-Item -ItemType Directory -Force (Join-Path $Artifacts 'runtime') | Out-Null; $log=Join-Path $Artifacts 'runtime\frontend.log'; $p=Start-Process -FilePath (Tool npx) -ArgumentList @('--yes','http-server',$dist,'-a',$frontendHost,'-p',$port) -RedirectStandardOutput $log -RedirectStandardError ($log + '.err') -PassThru; $p.Id | Set-Content (Join-Path $Artifacts 'runtime\frontend.pid')
}
'wait-services' { Init; $timeout=[int](Value $Config 'services' 'startup_timeout_seconds'); if(-not $timeout){$timeout=90}; foreach($url in @((Value $Config 'services' 'backend_health_url'),(Value $Config 'services' 'frontend_url'))){$sw=[Diagnostics.Stopwatch]::StartNew(); do { try { Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 5 | Out-Null; break } catch { Start-Sleep 2 } } while($sw.Elapsed.TotalSeconds -lt $timeout); if($sw.Elapsed.TotalSeconds -ge $timeout){throw "Timeout waiting for $url"} }
}
'run-e2e' { Init; $e2e=Resolve-RepoPath (Value $Config 'playwright' 'directory'); Run (Tool npx) @('playwright','test') $e2e (Join-Path $Artifacts 'logs\playwright.log') }
'run-stack-e2e' {
    Init
    try {
        & $PSCommandPath -Step start-backend -Config $Config -Artifacts $Artifacts
        & $PSCommandPath -Step start-frontend -Config $Config -Artifacts $Artifacts
        & $PSCommandPath -Step wait-services -Config $Config -Artifacts $Artifacts
        & $PSCommandPath -Step run-e2e -Config $Config -Artifacts $Artifacts
        if ($LASTEXITCODE -ne 0) { throw "Playwright E2E failed with exit code $LASTEXITCODE" }
    } finally { & $PSCommandPath -Step stop-services -Config $Config -Artifacts $Artifacts }
}
'stop-services' { Init; foreach($name in @('frontend','backend')) { $f=Join-Path $Artifacts "runtime\$name.pid"; if(Test-Path $f){$pid=[int](Get-Content $f); Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue; Remove-Item $f -Force} } }
'collect-logs' { Init; foreach($name in @('frontend','backend')) { $src=Join-Path $Artifacts "runtime\$name.log"; if(Test-Path $src){Copy-Item $src (Join-Path $Artifacts "logs\$name.log") -Force} } }
'archive' { Init; $files=Get-ChildItem $Artifacts -File -Recurse | Where-Object {$_.Name -ne 'manifest.json'} | ForEach-Object { $_.FullName.Substring($Artifacts.Length).TrimStart('\','/') -replace '\\','/' }; JsonFile (Join-Path $Artifacts 'manifest.json') @{config=(Resolve-RepoPath $Config);artifacts=$Artifacts;files=@($files | Sort-Object)} }
default { throw "Unknown SDLC PowerShell step: $Step" }
}
