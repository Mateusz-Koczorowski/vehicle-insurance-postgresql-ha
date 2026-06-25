[CmdletBinding()]
param(
    [string]$EnvFile = ".env.example",
    [int]$Samples = 60
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
Set-Location $root

function Read-EnvValue([string]$Name) {
    $line = Get-Content -LiteralPath $EnvFile |
        Where-Object { $_ -match "^$([regex]::Escape($Name))=" } |
        Select-Object -Last 1
    return ($line -split "=", 2)[1]
}

$password = Read-EnvValue "APP_AUDITOR_PASSWORD"
Write-Host "[pgpool] SHOW POOL_NODES"
docker compose --env-file $EnvFile exec -T `
    -e "PGPASSWORD=$password" pgpool `
    psql -h 127.0.0.1 -p 9999 -U app_auditor_ewa -d vehicle_insurance `
    -c "SHOW POOL_NODES"
if ($LASTEXITCODE -ne 0) { throw "SHOW POOL_NODES failed" }

$addresses = @()
for ($i = 1; $i -le $Samples; $i++) {
    $address = docker compose --env-file $EnvFile exec -T `
        -e "PGPASSWORD=$password" pgpool `
        psql -h 127.0.0.1 -p 9999 -U app_auditor_ewa -d vehicle_insurance `
        -Atqc "SELECT inet_server_addr()::text;"
    if ($LASTEXITCODE -ne 0) { throw "Load-balancing sample $i failed" }
    $addresses += $address.Trim()
}

$distribution = $addresses | Group-Object | Sort-Object Name
$distribution | ForEach-Object { Write-Host "[pgpool] backend $($_.Name): $($_.Count) reads" }
if ($distribution.Count -lt 2) {
    throw "Expected reads from at least two backends, got $($distribution.Count)"
}
Write-Host "[pgpool] PASS: $Samples independent reads reached multiple backends"
