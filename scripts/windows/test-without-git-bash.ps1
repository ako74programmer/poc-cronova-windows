[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$StartScript = Join-Path $PSScriptRoot 'app.ps1'

$originalBash = $env:CRONOVA_BASH_PATH
try {
    Remove-Item Env:CRONOVA_BASH_PATH -ErrorAction SilentlyContinue

    Write-Host '==> starting cronova without CRONOVA_BASH_PATH'
    $job = Start-Job -ScriptBlock {
        param($scriptPath, $root)
        Set-Location $root
        & $scriptPath start
    } -ArgumentList $StartScript, $RepoRoot

    Start-Sleep -Seconds 20

    $output = Receive-Job -Job $job -Keep -ErrorAction SilentlyContinue | Out-String
    if ($output -match 'Git Bash' -or $output -match 'bash.exe') {
        throw 'Launcher still reports a Git Bash dependency.'
    }

    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:8090/' -TimeoutSec 10
        $statusCode = [int]$response.StatusCode
    } catch {
        $statusCode = [int]$_.Exception.Response.StatusCode.value__
        if (-not $statusCode) {
            throw "Cronova did not start without Git Bash: $($_.Exception.Message)"
        }
    }

    if ($statusCode -lt 200 -or $statusCode -ge 500) {
        throw "Unexpected HTTP status without Git Bash: $statusCode"
    }

    Write-Host '==> stopping cronova'
    & $StartScript stop

    Wait-Job -Job $job -Timeout 10 | Out-Null
    Stop-Job -Job $job -ErrorAction SilentlyContinue | Out-Null
    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue | Out-Null

    Write-Host 'Validated PowerShell runtime without Git Bash.'
} finally {
    if ($null -ne $originalBash) {
        Set-Item -Path Env:CRONOVA_BASH_PATH -Value $originalBash
    }
}
