[CmdletBinding()]
param(
    [string]$EnvFile = ".env",
    [int]$Samples = 60,
    [string]$User = "app_auditor_ewa",
    [string]$Database = "vehicle_insurance"
)

$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
Set-Location $root

if (-not (Test-Path -LiteralPath $EnvFile)) {
    throw "Env file not found: $EnvFile"
}

function Get-PasswordVariableName([string]$LoginRole) {
    switch ($LoginRole) {
        "app_agent_anna" { return "APP_AGENT_PASSWORD" }
        "app_adjuster_piotr" { return "APP_ADJUSTER_PASSWORD" }
        "app_auditor_ewa" { return "APP_AUDITOR_PASSWORD" }
        "postgres" { return "POSTGRES_SUPERUSER_PASSWORD" }
        default { throw "No password mapping for user $LoginRole" }
    }
}

$passwordName = Get-PasswordVariableName $User

Write-Host "[pgpool-demo] PgPool nodes"
docker compose --env-file $EnvFile exec -T pgpool `
    sh -c "PGPASSWORD=`$(printenv '$passwordName') exec psql -h 127.0.0.1 -p 9999 -U '$User' -d '$Database' -c 'SHOW POOL_NODES;'"
if ($LASTEXITCODE -ne 0) {
    throw "SHOW POOL_NODES failed"
}

Write-Host ""
Write-Host "[pgpool-demo] Sampling $Samples independent read connections"

$addresses = New-Object System.Collections.Generic.List[string]
for ($i = 1; $i -le $Samples; $i++) {
    $address = docker compose --env-file $EnvFile exec -T pgpool `
        sh -c "PGPASSWORD=`$(printenv '$passwordName') exec psql -h 127.0.0.1 -p 9999 -U '$User' -d '$Database' -Atqc 'SELECT inet_server_addr()::text;'"

    if ($LASTEXITCODE -ne 0) {
        throw "Read sample $i failed"
    }

    $cleanAddress = $address.Trim()
    if ($cleanAddress.Length -eq 0) {
        throw "Read sample $i returned an empty backend address"
    }
    $addresses.Add($cleanAddress)
}

$distribution = $addresses |
    Group-Object |
    Sort-Object Count -Descending |
    Select-Object @{Name = "Backend"; Expression = { $_.Name } }, Count

Write-Host ""
Write-Host "[pgpool-demo] Read distribution"
$distribution | Format-Table -AutoSize

if ($distribution.Count -lt 2) {
    throw "Expected reads from at least two backends, got $($distribution.Count)"
}

Write-Host "[pgpool-demo] PASS: $Samples reads reached $($distribution.Count) backend nodes"
