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
$backupPassword = Read-EnvValue "BACKUP_PASSWORD"
$nodes = @("pg-primary", "pg-standby-a", "pg-standby-dr")
$primary = $null

foreach ($node in $nodes) {
    $isRunning = docker compose --env-file $EnvFile ps --status running --services $node
    if (-not $isRunning) { continue }
    $recovery = docker compose --env-file $EnvFile exec -T `
        -e "PGPASSWORD=$postgresPassword" $node `
        psql -h 127.0.0.1 -U postgres -d vehicle_insurance -Atqc `
        "SELECT pg_is_in_recovery();"
    if ($LASTEXITCODE -eq 0 -and $recovery.Trim() -eq "f") {
        $primary = $node
        break
    }
}
if (-not $primary) { throw "No writable primary found" }

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$marker = "BACKUP-$timestamp"
$nationalId = Get-Random -Minimum 10000000000 -Maximum 99999999999
$dumpName = "vehicle_insurance-$timestamp.dump"

Write-Host "[backup] primary: $primary; creating marker $marker"
docker compose --env-file $EnvFile exec -T `
    -e "PGPASSWORD=$postgresPassword" $primary `
    psql -h 127.0.0.1 -U postgres -d vehicle_insurance -v ON_ERROR_STOP=1 -c `
    "INSERT INTO insurance.customers(customer_number,first_name,last_name,national_id) VALUES ('$marker','Backup','Marker','$nationalId');"
if ($LASTEXITCODE -ne 0) { throw "Could not create backup marker" }

Write-Host "[backup] pg_dump --format=custom to ignored host bind ./backups/$dumpName"
docker compose --env-file $EnvFile exec -T `
    -e "PGPASSWORD=$backupPassword" $primary `
    pg_dump -h 127.0.0.1 -U backup_operator -d vehicle_insurance `
    --format=custom --file="/backups/$dumpName"
if ($LASTEXITCODE -ne 0) { throw "pg_dump failed" }

docker compose --env-file $EnvFile exec -T $primary `
    pg_restore --list "/backups/$dumpName" | Select-Object -First 5
if ($LASTEXITCODE -ne 0) { throw "Dump is not a readable custom archive" }

Write-Host "[backup] deleting marker from active database"
docker compose --env-file $EnvFile exec -T `
    -e "PGPASSWORD=$postgresPassword" $primary `
    psql -h 127.0.0.1 -U postgres -d vehicle_insurance -v ON_ERROR_STOP=1 -c `
    "DELETE FROM insurance.customers WHERE customer_number='$marker';"
if ($LASTEXITCODE -ne 0) { throw "Marker deletion failed" }

Start-Sleep -Seconds 3
foreach ($node in $nodes) {
    if ($node -eq $primary) { continue }
    $isRunning = docker compose --env-file $EnvFile ps --status running --services $node
    if (-not $isRunning) { continue }
    $count = docker compose --env-file $EnvFile exec -T `
        -e "PGPASSWORD=$postgresPassword" $node `
        psql -h 127.0.0.1 -U postgres -d vehicle_insurance -Atqc `
        "SELECT count(*) FROM insurance.customers WHERE customer_number='$marker';"
    if ($count.Trim() -ne "0") { throw "Logical DELETE did not reach $node" }
    Write-Host "[backup] $node also has no marker: replication propagated DELETE"
}

Write-Host "[backup] restoring to separate vehicle_insurance_restore database"
docker compose --env-file $EnvFile exec -T `
    -e "PGPASSWORD=$postgresPassword" $primary `
    dropdb -h 127.0.0.1 -U postgres --if-exists vehicle_insurance_restore
docker compose --env-file $EnvFile exec -T `
    -e "PGPASSWORD=$postgresPassword" $primary `
    createdb -h 127.0.0.1 -U postgres vehicle_insurance_restore
docker compose --env-file $EnvFile exec -T `
    -e "PGPASSWORD=$postgresPassword" $primary `
    pg_restore -h 127.0.0.1 -U postgres -d vehicle_insurance_restore `
    --no-owner --no-privileges "/backups/$dumpName"
if ($LASTEXITCODE -ne 0) { throw "pg_restore failed" }

$restored = docker compose --env-file $EnvFile exec -T `
    -e "PGPASSWORD=$postgresPassword" $primary `
    psql -h 127.0.0.1 -U postgres -d vehicle_insurance_restore -Atqc `
    "SELECT customer_number FROM insurance.customers WHERE customer_number='$marker';"
if ($restored.Trim() -ne $marker) { throw "Deleted marker was not recovered" }

Write-Host "[backup] PASS: $marker recovered only in vehicle_insurance_restore"
Write-Host "[backup] artifact: backups/$dumpName (ignored by Git; outside PGDATA volumes)"
