[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$PackageScript = Join-Path $RepoRoot 'scripts\package.ps1'
$DistDir = Join-Path $RepoRoot 'dist'
$ZipPath = Join-Path $DistDir 'cronova_windows_amd64.zip'
$ExtractDir = Join-Path ([IO.Path]::GetTempPath()) ("cronova-package-smoke-" + [guid]::NewGuid())

$requiredFiles = @(
    'cronova.exe',
    'cronova-executor.exe',
    'cronova.yaml',
    'deploy\install.ps1',
    'deploy\uninstall.ps1',
    'deploy\update.ps1',
    'docs\DEPLOY.md',
    'configs\sdlc-angular.yaml',
    'configs\sdlc-fullstack.yaml',
    'configs\sdlc-springboot.yaml',
    'contracts\openapi.yaml',
    'internal\scripts\angular-validate-config.ps1',
    'internal\scripts\fullstack-run-stack-e2e.ps1',
    'internal\scripts\generate-maven-archetype.ps1',
    'internal\scripts\maven-compile.ps1',
    'internal\scripts\springboot-validate-config.ps1',
    'prompts\luhn.txt',
    'prompts\springboot_crud.txt',
    'templates\springboot-simple\pom.xml',
    'e2e\playwright\playwright.config.ts',
    'dags\sdlc_angular.yaml',
    'dags\sdlc_fullstack.yaml',
    'dags\sdlc_maven_luhn.yaml',
    'dags\sdlc_springboot_rest.yaml',
    'dags\sdlc_springboot_startio.yaml',
    'dags\sdlc_springboot_template_crud.yaml',
    'dags\sdlc_springboot_variant.yaml'
)

try {
    & $PackageScript
    if ($LASTEXITCODE -ne 0) {
        throw "Packaging failed with exit code $LASTEXITCODE"
    }

    if (-not (Test-Path $ZipPath)) {
        throw "Package not found: $ZipPath"
    }

    Expand-Archive -LiteralPath $ZipPath -DestinationPath $ExtractDir -Force

    $missing = @()
    foreach ($relativePath in $requiredFiles) {
        $target = Join-Path $ExtractDir $relativePath
        if (-not (Test-Path $target)) {
            $missing += $relativePath
        }
    }

    if ($missing.Count -gt 0) {
        $missing | ForEach-Object { Write-Error "Missing packaged file: $_" }
        throw "Package smoke test failed for $($missing.Count) missing file(s)."
    }

    Write-Host "Validated package contents in $ZipPath"
} finally {
    if (Test-Path $ExtractDir) {
        Remove-Item $ExtractDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
