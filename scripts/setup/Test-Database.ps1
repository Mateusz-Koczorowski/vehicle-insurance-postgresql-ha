[CmdletBinding()]
param([string]$EnvFile = ".env.example")

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
Set-Location $root

function Read-EnvValue([string]$Name) {
    $line = Get-Content -LiteralPath $EnvFile |
        Where-Object { $_ -match "^$([regex]::Escape($Name))=" } |
        Select-Object -Last 1
    if (-not $line) { throw "Missing $Name in $EnvFile" }
    return ($line -split "=", 2)[1]
}

$postgresPassword = Read-EnvValue "POSTGRES_SUPERUSER_PASSWORD"

Write-Host "[database] running constraint tests on pg-primary"
docker compose --env-file $EnvFile exec -T `
    -e "PGPASSWORD=$postgresPassword" pg-primary `
    psql -h 127.0.0.1 -U postgres -d vehicle_insurance `
    -v ON_ERROR_STOP=1 -f /opt/project/database/tests/constraints.sql
if ($LASTEXITCODE -ne 0) { throw "Constraint tests failed" }

$inventory = docker compose --env-file $EnvFile exec -T `
    -e "PGPASSWORD=$postgresPassword" pg-primary `
    psql -h 127.0.0.1 -U postgres -d vehicle_insurance -Atqc `
    "SELECT count(*) FROM information_schema.tables WHERE table_schema IN ('insurance','claims','audit') AND table_type='BASE TABLE';"
if ($inventory.Trim() -ne "8") { throw "Expected exactly 8 business tables, got $inventory" }

Write-Host "[database] PASS: constraints and exact 8-table inventory"
