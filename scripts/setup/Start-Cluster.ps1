[CmdletBinding()]
param(
    [string]$EnvFile = ".env.example",
    [switch]$Build
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
Set-Location $root

Write-Host "[setup] validating Compose with $EnvFile"
docker compose --env-file $EnvFile config --quiet
if ($LASTEXITCODE -ne 0) { throw "Compose validation failed" }

$arguments = @("compose", "--env-file", $EnvFile, "up", "-d")
if ($Build) { $arguments += "--build" }

Write-Host "[setup] starting five services"
& docker @arguments
if ($LASTEXITCODE -ne 0) { throw "Docker Compose startup failed" }

Write-Host "[setup] waiting for services to become healthy"
$deadline = (Get-Date).AddMinutes(8)
do {
    $status = docker compose --env-file $EnvFile ps --format json |
        ConvertFrom-Json
    $notReady = @($status | Where-Object {
        $_.State -ne "running" -or ($_.Health -and $_.Health -ne "healthy")
    })
    if ($notReady.Count -eq 0 -and @($status).Count -eq 5) { break }
    if ((Get-Date) -gt $deadline) {
        docker compose --env-file $EnvFile ps
        throw "Services did not become healthy before timeout"
    }
    Start-Sleep -Seconds 5
} while ($true)

docker compose --env-file $EnvFile ps
Write-Host "[setup] PASS: all five services are running"
