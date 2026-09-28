$ErrorActionPreference = 'SilentlyContinue'

function Get-InstallVersion([string]$Name) {
    if ($Name -match '^Python(?<major>\d)(?<minor>\d{1,2})$') {
        return [version]::Parse("$($Matches.major).$($Matches.minor)")
    }
    $dotted = [regex]::Match($Name, '\d+(?:\.\d+)+')
    if ($dotted.Success) {
        return [version]::Parse($dotted.Value)
    }
    $integer = [regex]::Match($Name, '\d+')
    if ($integer.Success) {
        return [version]::Parse($integer.Value)
    }
    return [version]'0.0'
}

function Get-NewestInstall([string[]]$Patterns, [string]$RequiredRelativePath) {
    $directories = @()
    foreach ($pattern in $Patterns) {
        $directories += @(Get-ChildItem -Path $pattern -Directory -ErrorAction SilentlyContinue)
    }
    return $directories |
        Sort-Object -Property @{ Expression = { Get-InstallVersion $_.Name }; Descending = $true } |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName $RequiredRelativePath) } |
        Select-Object -First 1
}

if (-not $env:CRONOVA_PYTHON) {
    $pythonPatterns = @()
    if ($env:LOCALAPPDATA) { $pythonPatterns += (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python*') }
    if ($env:ProgramFiles) { $pythonPatterns += (Join-Path $env:ProgramFiles 'Python*') }
    if (${env:ProgramFiles(x86)}) { $pythonPatterns += (Join-Path ${env:ProgramFiles(x86)} 'Python*') }
    if ($env:SystemDrive) { $pythonPatterns += "$($env:SystemDrive)\Python*" }

    $pythonInstall = Get-NewestInstall -Patterns $pythonPatterns -RequiredRelativePath 'python.exe'
    if ($pythonInstall) {
        Write-Output "CRONOVA_PYTHON=$(Join-Path $pythonInstall.FullName 'python.exe')"
    } else {
        $pythonCommand = Get-Command python.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($pythonCommand) { Write-Output "CRONOVA_PYTHON=$($pythonCommand.Source)" }
    }
}

$nodeCandidates = @()
if ($env:ProgramFiles) { $nodeCandidates += (Join-Path $env:ProgramFiles 'nodejs\node.exe') }
if (${env:ProgramFiles(x86)}) { $nodeCandidates += (Join-Path ${env:ProgramFiles(x86)} 'nodejs\node.exe') }
if ($env:LOCALAPPDATA) { $nodeCandidates += (Join-Path $env:LOCALAPPDATA 'Programs\nodejs\node.exe') }
if ($env:NVM_SYMLINK) { $nodeCandidates += (Join-Path $env:NVM_SYMLINK 'node.exe') }
$node = $env:CRONOVA_NODE
if (-not $node) {
    $node = $nodeCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
}
if (-not $node) {
    $nodeCommand = Get-Command node.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($nodeCommand) { $node = $nodeCommand.Source }
}
if ($node -and -not $env:CRONOVA_NODE) { Write-Output "CRONOVA_NODE=$node" }

if (-not $env:CRONOVA_NPM) {
    $npm = $null
    if ($node) {
        $candidate = Join-Path (Split-Path -Parent $node) 'npm.cmd'
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { $npm = $candidate }
    }
    if (-not $npm) {
        $npmCommand = Get-Command npm.cmd -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($npmCommand) { $npm = $npmCommand.Source }
    }
    if ($npm) { Write-Output "CRONOVA_NPM=$npm" }
}

if (-not $env:CRONOVA_JAVA_HOME -and -not $env:JAVA_HOME) {
    $javaPatterns = @()
    if ($env:ProgramFiles) {
        $javaPatterns += (Join-Path $env:ProgramFiles 'Java\jdk-*')
        $javaPatterns += (Join-Path $env:ProgramFiles 'Eclipse Adoptium\jdk-*')
        $javaPatterns += (Join-Path $env:ProgramFiles 'Microsoft\jdk-*')
    }
    if (${env:ProgramFiles(x86)}) { $javaPatterns += (Join-Path ${env:ProgramFiles(x86)} 'Java\jdk-*') }
    if ($env:SystemDrive) {
        $javaPatterns += "$($env:SystemDrive)\Java\jdk-*"
        $javaPatterns += "$($env:SystemDrive)\jdk-*"
    }
    $jdk = Get-NewestInstall -Patterns $javaPatterns -RequiredRelativePath 'bin\java.exe'
    if ($jdk) {
        Write-Output "CRONOVA_JAVA_HOME=$($jdk.FullName)"
    } else {
        $javaCommand = Get-Command java.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($javaCommand) {
            $javaBin = Split-Path -Parent $javaCommand.Source
            if ((Split-Path -Leaf $javaBin) -ieq 'bin') { Write-Output "CRONOVA_JAVA_HOME=$(Split-Path -Parent $javaBin)" }
        }
    }
}

if (-not $env:CRONOVA_MAVEN_HOME -and -not $env:MAVEN_HOME) {
    $mavenPatterns = @()
    if ($env:ProgramFiles) { $mavenPatterns += (Join-Path $env:ProgramFiles 'Apache\Maven\apache-maven-*') }
    if ($env:SystemDrive) {
        $mavenPatterns += "$($env:SystemDrive)\apache-maven-*"
        $mavenPatterns += "$($env:SystemDrive)\tools\apache-maven-*"
    }
    if ($env:USERPROFILE) { $mavenPatterns += (Join-Path $env:USERPROFILE 'tools\apache-maven-*') }
    $maven = Get-NewestInstall -Patterns $mavenPatterns -RequiredRelativePath 'bin\mvn.cmd'
    if ($maven) {
        Write-Output "CRONOVA_MAVEN_HOME=$($maven.FullName)"
    } else {
        $mavenCommand = Get-Command mvn.cmd -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($mavenCommand) {
            $mavenBin = Split-Path -Parent $mavenCommand.Source
            if ((Split-Path -Leaf $mavenBin) -ieq 'bin') { Write-Output "CRONOVA_MAVEN_HOME=$(Split-Path -Parent $mavenBin)" }
        }
    }
}
