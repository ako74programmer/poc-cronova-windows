[CmdletBinding()]
param([string]$Source = (Split-Path $PSScriptRoot -Parent), [switch]$Start)
$ErrorActionPreference = "Stop"

function Invoke-SC {
  param(
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [string]$Action = "sc.exe command"
  )

  & sc.exe @Arguments | Out-Host
  if ($LASTEXITCODE -ne 0) {
    throw "$Action failed with exit code $LASTEXITCODE."
  }
}

$Data = Join-Path $env:ProgramData "Cronova"
$Install = Join-Path $env:ProgramFiles "Cronova"
New-Item -ItemType Directory -Force -Path $Install, $Data, "$Data\dags", "$Data\projects", "$Data\workspaces", "$Data\logs", "$Data\state" | Out-Null
Copy-Item (Join-Path $Source "cronova.exe") (Join-Path $Install "cronova.exe") -Force
Copy-Item (Join-Path $Source "cronova-executor.exe") (Join-Path $Install "cronova-executor.exe") -Force
$config = Join-Path $Data "cronova.yaml"
if (-not (Test-Path $config)) { Copy-Item (Join-Path $Source "cronova.yaml") $config }
Copy-Item (Join-Path $Source "dags\*.yaml") "$Data\dags" -Force -ErrorAction SilentlyContinue
$exec = Join-Path $Install "cronova-executor.exe"
$sched = Join-Path $Install "cronova.exe"
$execBin = "`"$exec`" -sock 127.0.0.1:19090 -state-dir `"$Data\state`""
$schedBin = "`"$sched`" serve -config `"$config`" -db `"$Data\cronova.db`" -dags `"$Data\dags`" -logs `"$Data\logs`" -projects `"$Data\projects`" -workspaces `"$Data\workspaces`" -executor tcp://127.0.0.1:19090"
Invoke-SC -Arguments @("create", "CronovaExecutor", "binPath=", $execBin, "start=", "auto") -Action "Creating CronovaExecutor service"
Invoke-SC -Arguments @("create", "Cronova", "binPath=", $schedBin, "start=", "auto", "depend=", "CronovaExecutor") -Action "Creating Cronova service"
Invoke-SC -Arguments @("failure", "CronovaExecutor", "actions=", "restart/60000/restart/60000//60000", "reset=", "86400") -Action "Configuring CronovaExecutor recovery"
Invoke-SC -Arguments @("failure", "Cronova", "actions=", "restart/60000/restart/60000//60000", "reset=", "86400") -Action "Configuring Cronova recovery"
Write-Host "Installed Cronova to $Install with data in $Data"
if ($Start) {
  Invoke-SC -Arguments @("start", "CronovaExecutor") -Action "Starting CronovaExecutor service"
  Invoke-SC -Arguments @("start", "Cronova") -Action "Starting Cronova service"
}
Invoke-SC -Arguments @("query", "CronovaExecutor") -Action "Querying CronovaExecutor service"
Invoke-SC -Arguments @("query", "Cronova") -Action "Querying Cronova service"
