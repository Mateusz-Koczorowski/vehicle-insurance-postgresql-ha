[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
param(
    [string]$EnvFile = ".env.example",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
Set-Location $root

if (-not $Force -and -not $PSCmdlet.ShouldProcess(
    "three named PostgreSQL volumes",
    "delete and rebuild the demonstration cluster"
)) {
    return
}

Write-Host "[reset] deleting only this Compose project's containers and named volumes"
docker compose --env-file $EnvFile down --volumes --remove-orphans
if ($LASTEXITCODE -ne 0) { throw "Compose teardown failed" }

& (Join-Path $PSScriptRoot "../setup/Start-Cluster.ps1") -EnvFile $EnvFile
