[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][Alias('t')][string]$Template,
    [Alias('w')][string]$Workspace,
    [Alias('p')][string]$Project = 'demo',
    [Alias('c')][switch]$Clean
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common\toolchain.ps1')
$repo = Get-RepoRoot
$templateDir = Join-Path $repo "templates\$Template"
if (-not (Test-Path -LiteralPath $templateDir -PathType Container)) { throw "Template directory not found: $templateDir" }
if (-not $Workspace) { $Workspace = Join-Path $repo 'workspaces\springboot-demo' }
$target = Join-Path $Workspace $Project
if ($Clean -and (Test-Path -LiteralPath $target)) { Write-Output "Cleaning target directory: $target"; Remove-Item -LiteralPath $target -Recurse -Force }
New-Item -ItemType Directory -Force -Path $target | Out-Null
Write-Output "Copying template '$Template' to '$target'..."
Get-ChildItem -LiteralPath $templateDir -Force | Copy-Item -Destination $target -Recurse -Force
Write-Output "Template copied successfully to $target"
