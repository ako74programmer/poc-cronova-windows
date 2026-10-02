[CmdletBinding()]
param(
    [Alias('a')][string]$Archetype = 'maven-archetype-quickstart',
    [Alias('v')][string]$ArchetypeVersion,
    [Alias('g')][string]$Group = 'com.example',
    [Alias('r')][string]$Artifact = 'demo',
    [Alias('k')][string]$Package,
    [Alias('j')][string]$JavaVersion = '21',
    [Alias('w')][string]$Workspace,
    [Alias('p')][string]$Project = 'demo',
    [Alias('C')][switch]$Clean
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common\toolchain.ps1')
$repo = Get-RepoRoot
if (-not $Package) { $Package = $Group }
if (-not $Workspace) { $Workspace = Join-Path $repo 'workspaces\maven-demo' }
$workspaceDir = Resolve-RepoPath $Workspace
$targetDir = Join-Path $workspaceDir $Project
$workspacePathInfo = Resolve-Path $workspaceDir -ErrorAction SilentlyContinue
$absoluteWorkspace = if ($workspacePathInfo) { $workspacePathInfo.Path } else { $null }
if (-not $absoluteWorkspace) {
    New-Item -ItemType Directory -Force -Path $workspaceDir | Out-Null
    $absoluteWorkspace = (Resolve-Path $workspaceDir).Path
}
$targetDir = Join-Path $absoluteWorkspace $Project
$tmpOut = Join-Path $absoluteWorkspace ('.archetype-out-' + [guid]::NewGuid().ToString('N'))
if ($Clean) {
    Write-Output "Cleaning target directory: $targetDir"
    Remove-Item -LiteralPath $targetDir -Recurse -Force -ErrorAction SilentlyContinue
}
Remove-Item -LiteralPath $tmpOut -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $tmpOut | Out-Null
Set-JavaMavenToolchain
$maven = Get-ConfiguredCommand 'maven'
$args = @('-B', 'archetype:generate', "-DgroupId=$Group", "-DartifactId=$Artifact", "-Dpackage=$Package", '-Dversion=1.0-SNAPSHOT', "-DarchetypeArtifactId=$Archetype")
if ($ArchetypeVersion) { $args += "-DarchetypeVersion=$ArchetypeVersion" }
$args += @('-DinteractiveMode=false', "-DoutputDirectory=$tmpOut")
Write-Output "Generating Maven archetype $Archetype..."
$stdoutFile = Join-Path $tmpOut 'maven.stdout.log'
$stderrFile = Join-Path $tmpOut 'maven.stderr.log'
try {
    $process = Start-Process -FilePath $maven -ArgumentList $args -WorkingDirectory $repo -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile
    Get-Content -LiteralPath $stdoutFile -ErrorAction SilentlyContinue | Write-Output
    Get-Content -LiteralPath $stderrFile -ErrorAction SilentlyContinue | Write-Output
    if ([int]$process.ExitCode -ne 0) {
        throw "Maven archetype generation failed with exit code $($process.ExitCode)"
    }
} finally {
    Remove-Item -LiteralPath $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
}
$generatedDir = Join-Path $tmpOut $Artifact
if (-not (Test-Path -LiteralPath $generatedDir -PathType Container)) {
    Remove-Item -LiteralPath $tmpOut -Recurse -Force -ErrorAction SilentlyContinue
    throw "Archetype did not generate expected directory: $generatedDir"
}
Remove-Item -LiteralPath $targetDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path (Split-Path $targetDir -Parent) | Out-Null
Copy-Item -LiteralPath $generatedDir -Destination $targetDir -Recurse -Force
Remove-Item -LiteralPath $tmpOut -Recurse -Force -ErrorAction SilentlyContinue
$pom = Join-Path $targetDir 'pom.xml'
if (Test-Path -LiteralPath $pom -PathType Leaf) {
    $xml = Get-Content -LiteralPath $pom -Raw
    $changed = $false
    foreach ($tag in @('source', 'target', 'release')) {
        $pattern = "<$($tag -replace '^','maven.compiler.')>[^<]*</$($tag -replace '^','maven.compiler.')>"
        $fullTag = "maven.compiler.$tag"
        if ($xml -match "<$fullTag>[^<]*</$fullTag>") {
            $xml = [regex]::Replace($xml, "<$fullTag>[^<]*</$fullTag>", "<$fullTag>$JavaVersion</$fullTag>")
            $changed = $true
        }
    }
    if ($xml -notmatch '<maven\.compiler\.(source|target|release)>') {
        $xml = $xml -replace '</project>', "<properties><maven.compiler.source>$JavaVersion</maven.compiler.source><maven.compiler.target>$JavaVersion</maven.compiler.target></properties></project>"
        $changed = $true
    }
    if ($changed) { Set-Content -LiteralPath $pom -Value $xml -Encoding UTF8 }
}
Write-Output "Maven archetype generated successfully in $targetDir"
