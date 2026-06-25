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

$pgPassword  = Read-EnvValue "POSTGRES_SUPERUSER_PASSWORD"
$agentPw     = Read-EnvValue "APP_AGENT_PASSWORD"
$adjusterPw  = Read-EnvValue "APP_ADJUSTER_PASSWORD"
$auditorPw   = Read-EnvValue "APP_AUDITOR_PASSWORD"

# --------------------------------------------------------------------------
# TEST 1: password_encryption is scram-sha-256
# --------------------------------------------------------------------------
Write-Host "[security] TEST 1: SHOW password_encryption on pg-primary"
$enc = docker compose --env-file $EnvFile exec -T `
    -e "PGPASSWORD=$pgPassword" pg-primary `
    psql -h 127.0.0.1 -U postgres -d vehicle_insurance `
    -Atqc "SHOW password_encryption;"
if ($LASTEXITCODE -ne 0) { throw "psql connection to pg-primary failed" }
$enc = $enc.Trim()
Write-Host "[security] password_encryption = $enc"
if ($enc -ne "scram-sha-256") {
    throw "Expected scram-sha-256, got: $enc"
}

# --------------------------------------------------------------------------
# TEST 2: Business roles authenticate successfully through PgPool-II
# --------------------------------------------------------------------------
Write-Host "[security] TEST 2: SCRAM auth success for all three business roles via PgPool-II"

foreach ($pair in @(
    @{ User = "app_agent_anna";    Password = $agentPw    },
    @{ User = "app_adjuster_piotr"; Password = $adjusterPw },
    @{ User = "app_auditor_ewa";   Password = $auditorPw  }
)) {
    $result = docker compose --env-file $EnvFile exec -T `
        -e "PGPASSWORD=$($pair.Password)" pgpool `
        psql -h 127.0.0.1 -p 9999 -U $pair.User -d vehicle_insurance `
        -Atqc "SELECT current_user;" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "SCRAM auth failed for $($pair.User): $result"
    }
    Write-Host "[security] $($pair.User) authenticated: $($result.Trim())"
}

# --------------------------------------------------------------------------
# TEST 3: Wrong password is rejected
# --------------------------------------------------------------------------
Write-Host "[security] TEST 3: Wrong password rejected for app_agent_anna"
$wrongResult = docker compose --env-file $EnvFile exec -T `
    -e "PGPASSWORD=deliberately_wrong_password_xyz" pgpool `
    psql -h 127.0.0.1 -p 9999 -U app_agent_anna -d vehicle_insurance `
    --connect-timeout 3 `
    -Atqc "SELECT current_user;" 2>&1
if ($LASTEXITCODE -eq 0) {
    throw "Expected connection with wrong password to fail, but it succeeded"
}
Write-Host "[security] Connection with wrong password correctly rejected"

# --------------------------------------------------------------------------
# TEST 4: pg_hba.conf contains no trust entries
# --------------------------------------------------------------------------
Write-Host "[security] TEST 4: Checking pg_hba.conf for trust entries"
$trustCount = docker compose --env-file $EnvFile exec -T pg-primary `
    sh -c "grep -c '\btrust\b' /etc/postgresql/project-pg_hba.conf || true" 2>&1
$trustCount = $trustCount.Trim()
Write-Host "[security] trust match count: $trustCount"
if ($trustCount -ne "0") {
    throw "pg_hba.conf contains $trustCount trust entry/entries — must be zero"
}

# --------------------------------------------------------------------------
# TEST 5: PostgreSQL and PCP ports are NOT published on the host
# --------------------------------------------------------------------------
Write-Host "[security] TEST 5: PostgreSQL and PCP ports not published on host"

foreach ($node in @("pg-primary", "pg-standby-a", "pg-standby-dr")) {
    $portOutput = docker compose --env-file $EnvFile port $node 5432 2>&1
    $exitCode = $LASTEXITCODE
    $portOutput = $portOutput.Trim()
    Write-Host "[security] $node port 5432 -> '$portOutput' (exit $exitCode)"
    if ($exitCode -eq 0 -and $portOutput -ne "") {
        throw "$node port 5432 is published on host: $portOutput"
    }
}

$pcpOutput = docker compose --env-file $EnvFile port pgpool 9898 2>&1
$pcpExit = $LASTEXITCODE
$pcpOutput = $pcpOutput.Trim()
Write-Host "[security] pgpool port 9898 (PCP) -> '$pcpOutput' (exit $pcpExit)"
if ($pcpExit -eq 0 -and $pcpOutput -ne "") {
    throw "PCP port 9898 is published on host: $pcpOutput"
}

Write-Host "[security] PASS: SCRAM verified, wrong password denied, no trust rules, ports not published"
