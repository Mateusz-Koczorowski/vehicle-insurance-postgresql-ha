[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path

$requiredFiles = @(
    "README.md",
    ".gitignore",
    ".env.example",
    "docker-compose.yml",
    "docs/architecture/ARCHITECTURE_CONTRACT.md",
    "docs/architecture/architecture.mmd",
    "docs/review-checklist.md"
)

$requiredDirectories = @(
    "app/src",
    "app/templates",
    "app/static",
    "app/tests",
    "database/migrations",
    "database/seed",
    "database/roles",
    "database/audit",
    "database/tests",
    "infrastructure/postgres",
    "infrastructure/repmgr",
    "infrastructure/pgpool",
    "infrastructure/networks",
    "scripts/setup",
    "scripts/demo",
    "scripts/backup",
    "scripts/failover",
    "scripts/evidence",
    "docs/evidence"
)

Write-Host "[structure] repository: $repositoryRoot"

foreach ($relativePath in $requiredFiles) {
    $path = Join-Path $repositoryRoot $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing required file: $relativePath"
    }
}

foreach ($relativePath in $requiredDirectories) {
    $path = Join-Path $repositoryRoot $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Container)) {
        throw "Missing required directory: $relativePath"
    }
}

$ignoredSecret = git -C $repositoryRoot check-ignore .env
if ($LASTEXITCODE -ne 0 -or $ignoredSecret -ne ".env") {
    throw ".env is not ignored by Git"
}

$forbiddenTracked = git -C $repositoryRoot ls-files |
    Where-Object {
        $_ -match '(^|/)(data|pgdata|backups|restore)(/|$)' -or
        $_ -match '\.(key|pem|p12|pfx|dump|backup|wal)$'
    }

if ($forbiddenTracked) {
    throw "Forbidden generated or secret-like files are tracked: $($forbiddenTracked -join ', ')"
}

Write-Host "[structure] PASS: required structure exists and forbidden artifacts are not tracked."
