[CmdletBinding()]
param([string]$EnvFile = ".env.example")

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
Set-Location $root

function Read-EnvValue([string]$Name) {
    $line = Get-Content -LiteralPath $EnvFile |
        Where-Object { $_ -match "^$([regex]::Escape($Name))=" } |
        Select-Object -Last 1
    return ($line -split "=", 2)[1]
}

$postgresPassword = Read-EnvValue "POSTGRES_SUPERUSER_PASSWORD"
$repmgrPassword = Read-EnvValue "REPMGR_PASSWORD"
$marker = "REPL-" + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

Write-Host "[cluster] repmgr cluster show"
docker compose --env-file $EnvFile exec -T --user postgres `
    -e "PGPASSWORD=$repmgrPassword" pg-primary `
    repmgr -f /run/repmgr/repmgr.conf cluster show
if ($LASTEXITCODE -ne 0) { throw "repmgr cluster show failed" }

$replicas = docker compose --env-file $EnvFile exec -T `
    -e "PGPASSWORD=$postgresPassword" pg-primary `
    psql -h 127.0.0.1 -U postgres -d vehicle_insurance -Atqc `
    "SELECT count(*) FROM pg_stat_replication WHERE state='streaming';"
if ([int]$replicas.Trim() -ne 2) { throw "Expected 2 streaming standbys, got $replicas" }

Write-Host "[cluster] writing marker $marker on primary"
docker compose --env-file $EnvFile exec -T `
    -e "PGPASSWORD=$postgresPassword" pg-primary `
    psql -h 127.0.0.1 -U postgres -d vehicle_insurance -v ON_ERROR_STOP=1 -c `
    "CREATE TABLE IF NOT EXISTS public.replication_probe(marker text PRIMARY KEY, created_at timestamptz DEFAULT clock_timestamp()); INSERT INTO public.replication_probe(marker) VALUES ('$marker');"
if ($LASTEXITCODE -ne 0) { throw "Primary replication marker write failed" }

foreach ($node in @("pg-standby-a", "pg-standby-dr")) {
    $seen = ""
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        $seen = docker compose --env-file $EnvFile exec -T `
            -e "PGPASSWORD=$postgresPassword" $node `
            psql -h 127.0.0.1 -U postgres -d vehicle_insurance -Atqc `
            "SELECT count(*) FROM public.replication_probe WHERE marker='$marker';"
        if ($seen.Trim() -eq "1") { break }
        Start-Sleep -Seconds 1
    }
    if ($seen.Trim() -ne "1") { throw "$node did not receive marker $marker" }
    Write-Host "[cluster] $node received $marker"
}

Write-Host "[cluster] PASS: one primary, two streaming standbys, marker replicated"
