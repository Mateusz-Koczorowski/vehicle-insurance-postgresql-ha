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

function Invoke-Sql(
    [string]$User,
    [string]$Password,
    [string]$Sql,
    [bool]$ShouldSucceed
) {
    $output = docker compose --env-file $EnvFile exec -T `
        -e "PGPASSWORD=$Password" pgpool `
        psql -h 127.0.0.1 -p 9999 -U $User -d vehicle_insurance `
        -v ON_ERROR_STOP=1 -Atqc $Sql 2>&1
    $succeeded = $LASTEXITCODE -eq 0
    Write-Host "[$User] $output"
    if ($succeeded -ne $ShouldSucceed) {
        throw "Unexpected permission result for $User; expected success=$ShouldSucceed"
    }
}

$agent = Read-EnvValue "APP_AGENT_PASSWORD"
$adjuster = Read-EnvValue "APP_ADJUSTER_PASSWORD"
$auditor = Read-EnvValue "APP_AUDITOR_PASSWORD"

Write-Host "[permissions] positive operations as real login roles"
Invoke-Sql "app_agent_anna" $agent `
    "BEGIN; INSERT INTO insurance.customers(first_name,last_name,national_id) VALUES ('Test','Agent','99111111111'); ROLLBACK;" $true
Invoke-Sql "app_adjuster_piotr" $adjuster `
    "BEGIN; INSERT INTO claims.claim_events(claim_id,event_type,note) VALUES (1,'NOTE','permission test'); ROLLBACK;" $true
Invoke-Sql "app_auditor_ewa" $auditor `
    "SELECT count(*) FROM audit.activity_log;" $true

Write-Host "[permissions] negative operations enforced by PostgreSQL"
Invoke-Sql "app_agent_anna" $agent `
    "INSERT INTO claims.payouts(claim_id,amount) VALUES (1,100);" $false
Invoke-Sql "app_adjuster_piotr" $adjuster `
    "UPDATE insurance.policies SET total_premium=total_premium+1 WHERE policy_id=1;" $false
Invoke-Sql "app_auditor_ewa" $auditor `
    "UPDATE insurance.customers SET phone='forbidden' WHERE customer_id=1;" $false
Invoke-Sql "app_auditor_ewa" $auditor `
    "INSERT INTO audit.activity_log(database_user,action,schema_name,table_name,record_key) VALUES ('x','INSERT','x','x','{}');" $false

Write-Host "[permissions] PASS: allowed and forbidden operations verified"
