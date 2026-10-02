Set-StrictMode -Version 3.0

$script:ToolchainRepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path

function Get-RepoRoot {
    return $script:ToolchainRepoRoot
}

function Resolve-RepoPath([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return $Path }
    return (Join-Path (Get-RepoRoot) $Path)
}

function Get-ConfiguredCommand([string]$Name) {
    $candidate = switch ($Name) {
        'python' { $env:CRONOVA_PYTHON }
        'maven' { if ($env:CRONOVA_MAVEN_HOME) { Join-Path $env:CRONOVA_MAVEN_HOME 'bin\mvn.cmd' } elseif ($env:MAVEN_HOME) { Join-Path $env:MAVEN_HOME 'bin\mvn.cmd' } }
        'java' { if ($env:CRONOVA_JAVA_HOME) { Join-Path $env:CRONOVA_JAVA_HOME 'bin\java.exe' } elseif ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME 'bin\java.exe' } }
    }
    if ($candidate -and (Test-Path -LiteralPath $candidate)) { return $candidate }
    if ($candidate) {
        $resolved = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($resolved) { return $resolved.Source }
    }
    $names = switch ($Name) {
        'python' { @('python.exe', 'python3.exe', 'python') }
        'maven' { @('mvn.cmd', 'mvn') }
        'java' { @('java.exe', 'java') }
    }
    foreach ($item in $names) {
        $resolved = Get-Command $item -ErrorAction SilentlyContinue
        if ($resolved) { return $resolved.Source }
    }
    throw "Required command not found: $Name"
}

function Set-JavaMavenToolchain {
    $javaHome = if ($env:CRONOVA_JAVA_HOME) { $env:CRONOVA_JAVA_HOME } else { $env:JAVA_HOME }
    $mavenHome = if ($env:CRONOVA_MAVEN_HOME) { $env:CRONOVA_MAVEN_HOME } else { $env:MAVEN_HOME }
    if ($javaHome) {
        $env:JAVA_HOME = $javaHome
        $javaBin = Join-Path $javaHome 'bin'
        if (Test-Path $javaBin) { $env:Path = "$javaBin;$env:Path" }
    }
    if ($mavenHome) {
        $env:MAVEN_HOME = $mavenHome
        $mavenBin = Join-Path $mavenHome 'bin'
        if (Test-Path $mavenBin) { $env:Path = "$mavenBin;$env:Path" }
    }
    [void](Get-ConfiguredCommand 'java')
    [void](Get-ConfiguredCommand 'maven')
}

function Write-ToolchainRuntime([string]$Path) {
    $java = Get-ConfiguredCommand 'java'
    $maven = Get-ConfiguredCommand 'maven'
    function Capture-NativeVersion([string]$FilePath) {
        $base = Join-Path ([IO.Path]::GetTempPath()) ("cronova-version-" + [guid]::NewGuid().ToString('N'))
        $stdout = "$base.out"
        $stderr = "$base.err"
        try {
            $process = Start-Process -FilePath $FilePath -ArgumentList '-version' -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdout -RedirectStandardError $stderr
            $text = @((Get-Content -LiteralPath $stdout -ErrorAction SilentlyContinue), (Get-Content -LiteralPath $stderr -ErrorAction SilentlyContinue))
            return (($text | Where-Object { $_ }) -join [Environment]::NewLine).Trim()
        } finally {
            Remove-Item -LiteralPath $stdout, $stderr -Force -ErrorAction SilentlyContinue
        }
    }
    @(
        "PATH=$env:Path"
        "JAVA_HOME=$($env:JAVA_HOME)"
        "CRONOVA_JAVA_HOME=$($env:CRONOVA_JAVA_HOME)"
        "MAVEN_HOME=$($env:MAVEN_HOME)"
        "CRONOVA_MAVEN_HOME=$($env:CRONOVA_MAVEN_HOME)"
        "java=$java"
        (Capture-NativeVersion $java)
        "mvn=$maven"
        ((Capture-NativeVersion $maven) -split [Environment]::NewLine | Select-Object -First 3) -join [Environment]::NewLine
    ) | Set-Content -LiteralPath $Path -Encoding UTF8
}

function ConvertTo-NativeArgumentString([string[]]$ArgumentList) {
    $quotedArguments = foreach ($argument in $ArgumentList) {
        $text = if ($null -eq $argument) { '' } else { [string]$argument }
        $builder = New-Object System.Text.StringBuilder
        [void]$builder.Append([char]34)
        $backslashes = 0
        foreach ($character in $text.ToCharArray()) {
            if ($character -eq [char]92) { $backslashes++; continue }
            if ($character -eq [char]34) {
                [void]$builder.Append([char]92, (2 * $backslashes) + 1)
                [void]$builder.Append([char]34)
                $backslashes = 0
                continue
            }
            if ($backslashes -gt 0) { [void]$builder.Append([char]92, $backslashes); $backslashes = 0 }
            [void]$builder.Append($character)
        }
        if ($backslashes -gt 0) { [void]$builder.Append([char]92, 2 * $backslashes) }
        [void]$builder.Append([char]34)
        $builder.ToString()
    }
    return ($quotedArguments -join ' ')
}

function Invoke-Native([string]$FilePath, [string[]]$ArgumentList, [string]$WorkingDirectory=(Get-Location).Path) {
    $base = Join-Path ([IO.Path]::GetTempPath()) ("cronova-native-" + [guid]::NewGuid().ToString('N'))
    $stdoutFile = "$base.out"
    $stderrFile = "$base.err"
    $argumentString = ConvertTo-NativeArgumentString $ArgumentList
    try {
        $process = Start-Process -FilePath $FilePath -ArgumentList $argumentString -WorkingDirectory $WorkingDirectory -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile
        $stdout = if (Test-Path -LiteralPath $stdoutFile) { [IO.File]::ReadAllText($stdoutFile) } else { '' }
        $stderr = if (Test-Path -LiteralPath $stderrFile) { [IO.File]::ReadAllText($stderrFile) } else { '' }
        if ($stdout) { [Console]::Out.Write($stdout) }
        if ($stderr) { [Console]::Error.Write($stderr) }
        if ([int]$process.ExitCode -ne 0) {
            [Console]::Error.WriteLine("$FilePath failed with exit code $($process.ExitCode). stderr: $stderr")
            exit [int]$process.ExitCode
        }
    } finally {
        Remove-Item -LiteralPath $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
    }
}
