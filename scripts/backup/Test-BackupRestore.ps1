[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$EnvFile,
    [Parameter(Mandatory)]
    [string]$ProjectName,
    [string[]]$ComposeFiles = @("docker-compose.yml"),
    [string]$BackupDirectory = "backups"
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
Set-Location $root

if ($ProjectName -notmatch '-m5-test$') {
    throw "Refusing to reset vehicle_insurance_restore outside an isolated *-m5-test Compose project."
}

function Read-EnvValue([string]$Name) {
    $line = Get-Content -LiteralPath $EnvFile |
        Where-Object { $_ -match "^$([regex]::Escape($Name))=" } |
        Select-Object -Last 1
    if (-not $line) { throw "Missing $Name in $EnvFile" }
    return ($line -split "=", 2)[1]
}

$composeArgs = @("--env-file", $EnvFile, "--project-name", $ProjectName)
foreach ($composeFile in $ComposeFiles) {
    $composeArgs += @("--file", $composeFile)
}

function Invoke-Compose {
    param([Parameter(ValueFromRemainingArguments)] [string[]]$Arguments)
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $result = & docker compose @composeArgs @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($exitCode -ne 0) { throw "docker compose $($Arguments -join ' ') failed: $result" }
    return $result
}

function Invoke-PgPoolQuery([string]$Database, [string]$Sql) {
    $result = & docker compose @composeArgs exec -T `
        -e "PGPASSWORD=$postgresPassword" -e "PGAPPNAME=pg_restore" pgpool `
        psql -h pgpool -p 9999 -U postgres -d $Database `
        -v ON_ERROR_STOP=1 -Atqc $Sql 2>&1
    if ($LASTEXITCODE -ne 0) { throw "PgPool query failed: $result" }
    return $result
}

$postgresPassword = Read-EnvValue "POSTGRES_SUPERUSER_PASSWORD"
$backupPassword = Read-EnvValue "BACKUP_PASSWORD"
$nodes = @("pg-primary", "pg-standby-a", "pg-standby-dr")
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$marker = "M5BR-$(Get-Date -Format 'yyyyMMddHHmmss')"
$nationalId = "8{0:D10}" -f (Get-Random -Minimum 0 -Maximum 1000000000)
$dumpName = "vehicle_insurance-$timestamp.dump"
$dumpPath = Join-Path $BackupDirectory $dumpName
$containerDumpPath = "/tmp/$dumpName"

New-Item -ItemType Directory -Force -Path $BackupDirectory | Out-Null

try {
    Write-Host "[backup] removing stale M5 markers from previous interrupted test runs"
    Invoke-PgPoolQuery "vehicle_insurance" `
        "DELETE FROM insurance.customers WHERE customer_number LIKE 'M5BR-%';" | Out-Null

    Write-Host "[backup] creating marker $marker through pgpool:9999"
    Invoke-PgPoolQuery "vehicle_insurance" `
        "INSERT INTO insurance.customers(customer_number,first_name,last_name,national_id) VALUES ('$marker','Backup','Marker','$nationalId');" | Out-Null

    Write-Host "[backup] pg_dump --format=custom through pgpool:9999 as backup_operator"
    $dumpOutput = & docker compose @composeArgs exec -T `
        -e "PGPASSWORD=$backupPassword" pgpool `
        pg_dump -h pgpool -p 9999 -U backup_operator -d vehicle_insurance `
        --format=custom --file=$containerDumpPath 2>&1
    if ($LASTEXITCODE -ne 0) { throw "pg_dump through PgPool failed: $dumpOutput" }

    Invoke-Compose -Arguments @("cp", "pgpool:$containerDumpPath", $dumpPath) | Out-Null
    if (-not (Test-Path -LiteralPath $dumpPath)) { throw "Host dump was not created: $dumpPath" }
    Write-Host "[backup] custom archive copied to ignored host path $dumpPath (outside PGDATA volumes)"

    $archiveList = Invoke-Compose -Arguments @("exec", "-T", "pgpool", "pg_restore", "--list", $containerDumpPath)
    if (-not $archiveList) { throw "pg_restore --list returned no archive entries" }

    Write-Host "[backup] deleting marker through pgpool:9999"
    Invoke-PgPoolQuery "vehicle_insurance" `
        "DELETE FROM insurance.customers WHERE customer_number='$marker';" | Out-Null

    $activeCount = (Invoke-PgPoolQuery "vehicle_insurance" `
        "SELECT count(*) FROM insurance.customers WHERE customer_number='$marker';").Trim()
    if ($activeCount -ne "0") { throw "Active database still contains marker after DELETE" }
    Write-Host "[backup] active database has no marker"

    Start-Sleep -Seconds 3
    foreach ($node in $nodes) {
        $recovery = Invoke-Compose -Arguments @(
            "exec", "-T", "-e", "PGPASSWORD=$postgresPassword", $node,
            "psql", "-h", "127.0.0.1", "-U", "postgres", "-d", "vehicle_insurance", "-Atqc",
            "SELECT pg_is_in_recovery();"
        )
        if ($recovery.Trim() -ne "t") { continue }
        $standbyCount = Invoke-Compose -Arguments @(
            "exec", "-T", "-e", "PGPASSWORD=$postgresPassword", $node,
            "psql", "-h", "127.0.0.1", "-U", "postgres", "-d", "vehicle_insurance", "-Atqc",
            "SELECT count(*) FROM insurance.customers WHERE customer_number='$marker';"
        )
        if ($standbyCount.Trim() -ne "0") { throw "Logical DELETE did not reach standby $node" }
        Write-Host "[backup] standby $node also has no marker: DELETE replicated"
    }

    Write-Host "[backup] creating separate vehicle_insurance_restore through pgpool:9999"
    Invoke-Compose -Arguments @(
        "exec", "-T", "-e", "PGPASSWORD=$postgresPassword", "pgpool",
        "dropdb", "-h", "pgpool", "-p", "9999", "-U", "postgres", "--if-exists", "--force",
        "vehicle_insurance_restore"
    ) | Out-Null
    Invoke-Compose -Arguments @(
        "exec", "-T", "-e", "PGPASSWORD=$postgresPassword", "pgpool",
        "createdb", "-h", "pgpool", "-p", "9999", "-U", "postgres", "vehicle_insurance_restore"
    ) | Out-Null

    Write-Host "[backup] pg_restore only into vehicle_insurance_restore through pgpool:9999"
    Invoke-Compose -Arguments @(
        "exec", "-T", "-e", "PGPASSWORD=$postgresPassword", "pgpool",
        "pg_restore", "-h", "pgpool", "-p", "9999", "-U", "postgres",
        "-d", "vehicle_insurance_restore", "--no-owner", "--no-privileges", $containerDumpPath
    ) | Out-Null

    $restored = (Invoke-PgPoolQuery "vehicle_insurance_restore" `
        "SELECT customer_number FROM insurance.customers WHERE customer_number='$marker';").Trim()
    if ($restored -ne $marker) { throw "Deleted marker was not recovered in vehicle_insurance_restore" }
    $activeAfterRestore = (Invoke-PgPoolQuery "vehicle_insurance" `
        "SELECT count(*) FROM insurance.customers WHERE customer_number='$marker';").Trim()
    if ($activeAfterRestore -ne "0") { throw "Restore unexpectedly changed active vehicle_insurance" }

    Write-Host "[backup] PASS: $marker is recovered only in vehicle_insurance_restore"
}
finally {
    & docker compose @composeArgs exec -T pgpool rm -f $containerDumpPath 2>$null | Out-Null
    if (Test-Path -LiteralPath $dumpPath) { Remove-Item -LiteralPath $dumpPath -Force }
}
