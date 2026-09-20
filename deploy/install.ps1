[CmdletBinding()]
param([string]$Source = (Split-Path $PSScriptRoot -Parent), [switch]$Start)
$ErrorActionPreference = "Stop"
$Data = Join-Path $env:ProgramData "Cronova"
$Install = Join-Path $env:ProgramFiles "Cronova"
$Bash = $env:CRONOVA_BASH_PATH
if (-not $Bash) { $Bash = (Get-Command bash.exe -ErrorAction SilentlyContinue).Source }
if (-not $Bash) { foreach ($p in @("$env:ProgramFiles\Git\usr\bin\bash.exe", "$env:ProgramFiles\Git\bin\bash.exe")) { if (Test-Path $p) { $Bash = $p; break } } }
if (-not $Bash) { throw "Git for Windows Bash was not found. Install Git for Windows or set CRONOVA_BASH_PATH to bash.exe." }
& $Bash --version | Out-Host
[Environment]::SetEnvironmentVariable("CRONOVA_BASH_PATH", $Bash, "Machine")
New-Item -ItemType Directory -Force -Path $Install, $Data, "$Data\dags", "$Data\projects", "$Data\workspaces", "$Data\logs", "$Data\state" | Out-Null
Copy-Item (Join-Path $Source "cronova.exe") (Join-Path $Install "cronova.exe") -Force
Copy-Item (Join-Path $Source "cronova-executor.exe") (Join-Path $Install "cronova-executor.exe") -Force
$config = Join-Path $Data "cronova.yaml"
if (-not (Test-Path $config)) { Copy-Item (Join-Path $Source "cronova.yaml") $config }
(Get-Content $config) -replace 'bash_path:.*', "bash_path: '$Bash'" | Set-Content $config
Copy-Item (Join-Path $Source "dags\*.yaml") "$Data\dags" -Force -ErrorAction SilentlyContinue
$exec = Join-Path $Install "cronova-executor.exe"
$sched = Join-Path $Install "cronova.exe"
$execBin = "`"$exec`" -sock 127.0.0.1:19090 -state-dir `"$Data\state`""
$schedBin = "`"$sched`" serve -config `"$config`" -db `"$Data\cronova.db`" -dags `"$Data\dags`" -logs `"$Data\logs`" -projects `"$Data\projects`" -workspaces `"$Data\workspaces`" -executor tcp://127.0.0.1:19090"
sc.exe create CronovaExecutor binPath= $execBin start= auto | Out-Host
sc.exe create Cronova binPath= $schedBin start= auto depend= CronovaExecutor | Out-Host
sc.exe failure CronovaExecutor actions= restart/60000/restart/60000/""/60000 reset= 86400 | Out-Host
sc.exe failure Cronova actions= restart/60000/restart/60000/""/60000 reset= 86400 | Out-Host
Write-Host "Installed Cronova to $Install with data in $Data; Git Bash: $Bash"
if ($Start) { sc.exe start CronovaExecutor | Out-Host; sc.exe start Cronova | Out-Host }
