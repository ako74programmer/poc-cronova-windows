<#
.SYNOPSIS
  Runs every project check locally (replaces hosted CI).

.DESCRIPTION
  CI-agnostic: any future pipeline (e.g. GitLab .gitlab-ci.yml on a Windows
  runner) only needs to call this script. Exits 1 on the first failure.

  Default checks: gofmt, go mod verify, embedded docs mirror, AI wiki KB
  freshness, go vet, go test, PowerShell script/service-helper tests.

.PARAMETER Full
  Also run the race detector and govulncheck (slower, needs network).

.PARAMETER Package
  Also build dist\cronova_windows_amd64.zip + SHA256SUMS and verify the
  package's DAG references.
#>
[CmdletBinding()]
param([switch]$Full, [switch]$Package)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $root
$results = [System.Collections.Generic.List[object]]::new()

function Invoke-Check {
    param([string]$Name, [scriptblock]$Body)
    Write-Host "==> $Name" -ForegroundColor Cyan
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try {
        $global:LASTEXITCODE = 0
        & $Body
        if ($LASTEXITCODE -ne 0) { throw "exit code $LASTEXITCODE" }
        $results.Add([pscustomobject]@{ Check = $Name; Result = 'OK'; Seconds = [int]$sw.Elapsed.TotalSeconds })
    }
    catch {
        $results.Add([pscustomobject]@{ Check = $Name; Result = 'FAIL'; Seconds = [int]$sw.Elapsed.TotalSeconds })
        $results | Format-Table -AutoSize | Out-Host
        Write-Host "FAILED: $Name - $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

function Invoke-Native {
    param([string]$Exe, [string[]]$Arguments)
    & $Exe @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Exe $($Arguments -join ' ') failed with exit code $LASTEXITCODE" }
}

Invoke-Check 'gofmt' {
    # Compare against LF-normalized content so CRLF checkouts are not reported.
    $bad = @()
    $files = git ls-files '*.go'
    foreach ($f in $files) {
        $src = [IO.File]::ReadAllText((Join-Path $root $f)).Replace("`r`n", "`n")
        $psi = [Diagnostics.ProcessStartInfo]::new('gofmt')
        $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.UseShellExecute = $false
        $psi.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
        $p = [Diagnostics.Process]::Start($psi)
        $w = [IO.StreamWriter]::new($p.StandardInput.BaseStream, [Text.UTF8Encoding]::new($false))
        $w.Write($src); $w.Close()
        $out = $p.StandardOutput.ReadToEnd(); $p.WaitForExit()
        if ($p.ExitCode -ne 0 -or $out -ne $src) { $bad += $f }
    }
    if ($bad) { $bad | ForEach-Object { Write-Host "  not gofmt-ed: $_" }; throw "$($bad.Count) file(s) need gofmt" }
}
Invoke-Check 'go mod verify' { Invoke-Native go @('mod', 'verify') }
Invoke-Check 'embedded docs in sync' { & (Join-Path $root 'internal\scripts\sync-embedded-docs.ps1') -Check }
Invoke-Check 'AI wiki KB fresh and clean' {
    Invoke-Native python @('internal/ai-wiki/build_knowledge_base.py')
    git diff --quiet -- internal/aiwiki/knowledge-base.json
    if ($LASTEXITCODE -ne 0) { throw 'knowledge-base.json changed after rebuild: commit the regenerated file' }
}
Invoke-Check 'go vet' { Invoke-Native go @('vet', './...') }
Invoke-Check 'go test' { Invoke-Native go @('test', './...') }
Invoke-Check 'PowerShell scripts' { Invoke-Native powershell @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', 'scripts\windows\test-powershell-scripts.ps1') }
Invoke-Check 'service helpers' { Invoke-Native powershell @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', 'scripts\windows\test-service-helpers.ps1') }

if ($Full) {
    Invoke-Check 'go test -race' { Invoke-Native go @('test', '-race', './...') }
    Invoke-Check 'govulncheck' { Invoke-Native go @('run', 'golang.org/x/vuln/cmd/govulncheck@v1.6.0', './...') }
}

if ($Package) {
    Invoke-Check 'package' { & (Join-Path $root 'scripts\package.ps1') }
    Invoke-Check 'package DAG references' {
        $x = Join-Path ([IO.Path]::GetTempPath()) ('cronova-check-' + [guid]::NewGuid())
        try {
            Expand-Archive (Join-Path $root 'dist\cronova_windows_amd64.zip') $x
            & (Join-Path $x 'internal\scripts\cronova-verify-dag-paths.ps1') -Root $x
        }
        finally { Remove-Item $x -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

$results | Format-Table -AutoSize | Out-Host
Write-Host 'All checks passed.' -ForegroundColor Green
