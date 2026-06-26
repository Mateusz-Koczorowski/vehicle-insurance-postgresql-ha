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
$repmgrPassword   = Read-EnvValue "REPMGR_PASSWORD"
$agentPassword    = Read-EnvValue "APP_AGENT_PASSWORD"

Write-Host "[failover] fencing location A: stopping pg-primary and pg-standby-a"
docker compose --env-file $EnvFile stop pg-primary pg-standby-a
if ($LASTEXITCODE -ne 0) { throw "Could not stop location A" }

$runningA = docker compose --env-file $EnvFile ps --status running `
    --services pg-primary pg-standby-a
if ($runningA) { throw "Fencing failed; a location-A database is still running: $runningA" }
Write-Host "[failover] fencing confirmed: both site-A database containers are stopped"

Write-Host "[failover] promoting pg-standby-dr manually with repmgr"
docker compose --env-file $EnvFile exec -T --user postgres `
    -e "PGPASSWORD=$repmgrPassword" pg-standby-dr `
    repmgr -f /run/repmgr/repmgr.conf standby promote
if ($LASTEXITCODE -ne 0) { throw "DR promotion failed" }

$recovery = "t"
for ($attempt = 0; $attempt -lt 30; $attempt++) {
    $recovery = docker compose --env-file $EnvFile exec -T `
        -e "PGPASSWORD=$postgresPassword" pg-standby-dr `
        psql -h 127.0.0.1 -U postgres -d vehicle_insurance `
        -Atqc "SELECT pg_is_in_recovery();" 2>$null
    if ($recovery.Trim() -eq "f") { break }
    Start-Sleep -Seconds 2
}
if ($recovery.Trim() -ne "f") { throw "DR node is still in recovery" }

Write-Host "[failover] waiting for PgPool-II to recognize pg-standby-dr as primary"
$poolPrimary = $false
for ($attempt = 0; $attempt -lt 30; $attempt++) {
    $poolNodes = docker compose --env-file $EnvFile exec -T `
        -e "PGPASSWORD=$agentPassword" pgpool `
        psql -h 127.0.0.1 -p 9999 -U app_agent_anna -d vehicle_insurance `
        -At -F "|" -c "SHOW POOL_NODES" 2>$null
    if ($LASTEXITCODE -eq 0 -and ($poolNodes | Where-Object {
        $_ -match '^2\|pg-standby-dr\|5432\|up\|up\|.*\|primary\|primary\|'
    })) {
        $poolPrimary = $true
        break
    }
    Start-Sleep -Seconds 2
}
if (-not $poolPrimary) { throw "PgPool-II did not recognize pg-standby-dr as primary" }

$suffix = Get-Random -Minimum 10000000000 -Maximum 99999999999
$customerNumber = "DR-" + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$sql = "INSERT INTO insurance.customers(customer_number,first_name,last_name,national_id) VALUES ('$customerNumber','Failover','Probe','$suffix') RETURNING customer_number;"
$result = docker compose --env-file $EnvFile exec -T `
    -e "PGPASSWORD=$agentPassword" pgpool `
    psql -h 127.0.0.1 -p 9999 -U app_agent_anna -d vehicle_insurance `
    -v ON_ERROR_STOP=1 -Atqc $sql
if ($LASTEXITCODE -ne 0 -or $result.Trim() -ne $customerNumber) {
    throw "Write through PgPool-II after failover failed"
}

Write-Host "[failover] PASS: DR promoted and write $customerNumber succeeded through pgpool:9999"
