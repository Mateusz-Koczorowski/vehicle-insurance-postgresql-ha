[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
Set-Location $root

$forbiddenTracked = git ls-files | Where-Object {
    $_ -match '(^|/)(data|pgdata|backups|restore)(/|$)' -or
    $_ -match '\.(key|pem|p12|pfx|dump|backup|wal)$'
}
if ($forbiddenTracked) {
    throw "Forbidden generated artifacts are tracked: $($forbiddenTracked -join ', ')"
}

$dangerousHba = rg -n "^\s*host.*\btrust\b|^\s*host.*0\.0\.0\.0/0" `
    infrastructure database docker-compose.yml
if ($LASTEXITCODE -eq 0) { throw "Unsafe HBA rule found: $dangerousHba" }

$published = docker compose --env-file .env.example config --format json |
    ConvertFrom-Json
foreach ($serviceName in @("pg-primary", "pg-standby-a", "pg-standby-dr")) {
    if ($published.services.$serviceName.ports) {
        throw "$serviceName unexpectedly publishes PostgreSQL"
    }
}

$secretPatterns = @(
    "-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----",
    "postgresql://[^:`"\s]+:[^@`"\s]+@"
)
foreach ($pattern in $secretPatterns) {
    $matches = rg -n $pattern . -g "!.git/**" -g "!backups/**"
    if ($LASTEXITCODE -eq 0) { throw "Potential secret found: $matches" }
}

Write-Host "[safety] PASS: no tracked dumps/PGDATA/keys, no network trust, no published PostgreSQL"
