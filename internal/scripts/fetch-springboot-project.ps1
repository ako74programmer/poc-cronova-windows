[CmdletBinding()]
param(
    [Alias('t')][string]$Type = 'maven-project',
    [Alias('l')][string]$Language = 'java',
    [Alias('b')][string]$Boot,
    [Alias('g')][string]$Group = 'com.example',
    [Alias('a')][string]$Artifact = 'demo',
    [Alias('n')][string]$Name,
    [Alias('p')][string]$Packaging = 'jar',
    [Alias('c')][string]$Config = 'properties',
    [Alias('j')][string]$Java = '21',
    [Alias('d')][string]$Dependencies,
    [Alias('w')][string]$Workspace,
    [string]$Project = 'demo',
    [Alias('y')][string]$Python,
    [switch]$Clean
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common\toolchain.ps1')
$repo = Get-RepoRoot

if (-not $Name) { $Name = "$Group.$Artifact" }
if (-not $Workspace) { $Workspace = Join-Path $repo 'workspaces\springboot-demo' }
$targetDir = Resolve-RepoPath (Join-Path $Workspace $Project)
$tmpDir = Join-Path $repo '.tmp'
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null

if (-not $Python -or $Python -in @('python', 'python3')) { $Python = $env:CRONOVA_PYTHON }
if (-not $Python) { $Python = Get-ConfiguredCommand 'python' }
else {
    $resolvedPython = Get-Command $Python -ErrorAction SilentlyContinue
    if ($resolvedPython) { $Python = $resolvedPython.Source }
    elseif (-not (Test-Path -LiteralPath $Python -PathType Leaf)) { throw "Configured Python is not executable: $Python" }
}

function ConvertTo-InitializrValue([string]$Value) {
    # Python urllib.parse.quote(value.strip()) in the Bash reference leaves slash unescaped.
    return ([Uri]::EscapeDataString($Value.Trim())).Replace('%2F', '/')
}

$query = @(
    'type=' + (ConvertTo-InitializrValue $Type)
    'language=' + (ConvertTo-InitializrValue $Language)
)
if ($Boot) { $query += 'bootVersion=' + (ConvertTo-InitializrValue $Boot) }
$query += 'groupId=' + (ConvertTo-InitializrValue $Group)
$query += 'artifactId=' + (ConvertTo-InitializrValue $Artifact)
# Preserve the Bash script's existing URL contract: name is populated from Artifact.
$query += 'name=' + (ConvertTo-InitializrValue $Artifact)
$query += 'packageName=' + (ConvertTo-InitializrValue $Name)
$query += 'packaging=' + (ConvertTo-InitializrValue $Packaging)
$query += 'configFormat=' + (ConvertTo-InitializrValue $Config)
$query += 'javaVersion=' + (ConvertTo-InitializrValue $Java)
if ($Dependencies) { $query += 'dependencies=' + (ConvertTo-InitializrValue $Dependencies) }
$url = 'https://start.spring.io/starter.zip?' + ($query -join '&')

Write-Output 'Downloading Spring Boot project from start.spring.io...'
Write-Output "Using Python: $Python"
Write-Output "URL: $url"
$zipFile = Join-Path $tmpDir 'springboot-project.zip'
$curl = Get-Command 'curl.exe' -ErrorAction SilentlyContinue
$wget = if (-not $curl) { Get-Command 'wget.exe' -ErrorAction SilentlyContinue }
if ($curl) {
    $downloader = $curl.Source
    $downloadArgs = @('-L', '-o', $zipFile, $url)
} elseif ($wget) {
    $downloader = $wget.Source
    $downloadArgs = @('-O', $zipFile, $url)
} else {
    throw 'Error: curl.exe or wget.exe is required.'
}
$downloadStdout = Join-Path $tmpDir ("springboot-download-" + [guid]::NewGuid().ToString('N') + '.stdout')
$downloadStderr = Join-Path $tmpDir ("springboot-download-" + [guid]::NewGuid().ToString('N') + '.stderr')
try {
    $downloadProcess = Start-Process -FilePath $downloader -ArgumentList (ConvertTo-NativeArgumentString $downloadArgs) -Wait -PassThru -NoNewWindow -RedirectStandardOutput $downloadStdout -RedirectStandardError $downloadStderr
    $stdout = if (Test-Path -LiteralPath $downloadStdout) { [IO.File]::ReadAllText($downloadStdout) } else { '' }
    $stderr = if (Test-Path -LiteralPath $downloadStderr) { [IO.File]::ReadAllText($downloadStderr) } else { '' }
    if ($stdout) { [Console]::Out.Write($stdout) }
    if ($stderr) { [Console]::Error.Write($stderr) }
    if ($downloadProcess.ExitCode -ne 0) {
        [Console]::Error.WriteLine("Spring Initializr download failed: program=$downloader exit_code=$($downloadProcess.ExitCode) stderr=$stderr")
        exit [int]$downloadProcess.ExitCode
    }
} finally {
    Remove-Item -LiteralPath $downloadStdout, $downloadStderr -Force -ErrorAction SilentlyContinue
}

if ($Clean) {
    Write-Output "Cleaning target directory: $targetDir"
    if (Test-Path -LiteralPath $targetDir) { Remove-Item -LiteralPath $targetDir -Recurse -Force }
}

New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
Write-Output "Extracting project to $targetDir..."
Expand-Archive -LiteralPath $zipFile -DestinationPath $targetDir -Force
Write-Output "Spring Boot project downloaded and extracted to $targetDir"
