#Requires -Version 5.1
<#
.SYNOPSIS
    Re-clone a stopped site-A node (pg-primary or pg-standby-a) so it rejoins
    the cluster as a standby of the promoted DR primary (pg-standby-dr).

.DESCRIPTION
    After a site-A failover, pg-standby-dr is the new primary and the
    site-A containers are stopped.  This script performs a *re-clone*:
    it removes the named Docker volume for the specified node, then starts
    the node with PRIMARY_HOST overridden to pg-standby-dr so that
    cluster-entrypoint.sh re-runs pg_basebackup from the new primary.

    The re-clone is the safe, minimal path.  It requires no pg_rewind,
    no SSH, and no timeline surgery.  The node will come up as a standby
    registered with repmgr under the same node_id.

    WARNING: The node's entire PGDATA volume will be erased.  This is
    intentional and irreversible.  Use -Force to skip the confirmation
    prompt.

.PARAMETER NodeName
    Docker Compose service name of the node to re-clone.
    Accepted values: pg-primary, pg-standby-a.

.PARAMETER EnvFile
    Path to the environment file used by Docker Compose.
    Defaults to .env.example.

.PARAMETER Force
    Skip the confirmation prompt.  Combine with -WhatIf to perform a
    dry-run without Force suppressing the WhatIf guard.

.EXAMPLE
    # Interactive confirmation
    .\Invoke-RejoinNode.ps1 -NodeName pg-primary

.EXAMPLE
    # Unattended re-clone of the standby
    .\Invoke-RejoinNode.ps1 -NodeName pg-standby-a -Force

.NOTES
    Run AFTER Invoke-SiteAFailover.ps1 has completed successfully.
    pg-standby-dr must be running and healthy before calling this script.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
param(
    [Parameter(Mandatory)]
    [ValidateSet("pg-primary", "pg-standby-a")]
    [string]$NodeName,

    [string]$EnvFile = ".env.example",

    [switch]$Force
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
Set-Location $root

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Read-EnvValue([string]$Name) {
    $line = Get-Content -LiteralPath $EnvFile |
        Where-Object { $_ -match "^$([regex]::Escape($Name))=" } |
        Select-Object -Last 1
    if (-not $line) { throw "Variable $Name not found in $EnvFile" }
    return ($line -split "=", 2)[1]
}

function Wait-ContainerHealthy([string]$Service, [int]$TimeoutSeconds = 180) {
    Write-Host "[rejoin] waiting for $Service to become healthy (timeout ${TimeoutSeconds}s)"
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $raw = docker compose --env-file $EnvFile ps --format json $Service 2>$null
        if ($raw) {
            # Compose ps --format json can emit a JSON array or individual objects
            try {
                $info = $raw | ConvertFrom-Json
                # Handle both array and single object
                $entry = if ($info -is [System.Array]) { $info[0] } else { $info }
                if ($entry.State -eq "running" -and $entry.Health -eq "healthy") {
                    return
                }
            } catch {
                # Parsing failed; loop and retry
            }
        }
        if ((Get-Date) -gt $deadline) {
            docker compose --env-file $EnvFile ps $Service
            throw "$Service did not become healthy within ${TimeoutSeconds} seconds"
        }
        Start-Sleep -Seconds 5
    } while ($true)
}

# ---------------------------------------------------------------------------
# Map service name to volume name
# ---------------------------------------------------------------------------

$volumeMap = @{
    "pg-primary"   = "pg_primary_data"
    "pg-standby-a" = "pg_standby_a_data"
}
$volumeName = $volumeMap[$NodeName]

# The Compose project name is used to construct the full volume name.
$projectName = Read-EnvValue "COMPOSE_PROJECT_NAME"
$fullVolumeName = "${projectName}_${volumeName}"

# ---------------------------------------------------------------------------
# Safety: refuse if the node is currently running
# ---------------------------------------------------------------------------

Write-Host "[rejoin] checking whether $NodeName is stopped"
$runningServices = docker compose --env-file $EnvFile ps --status running --services 2>$null
if ($runningServices -and ($runningServices -split "`n" | Where-Object { $_.Trim() -eq $NodeName })) {
    throw "[rejoin] ABORT: $NodeName is still running. Stop it first (e.g. docker compose stop $NodeName)."
}
Write-Host "[rejoin] confirmed: $NodeName is not running"

# ---------------------------------------------------------------------------
# Safety: confirm pg-standby-dr is the live primary
# ---------------------------------------------------------------------------

Write-Host "[rejoin] verifying pg-standby-dr is running and not in recovery"
$drStatus = docker compose --env-file $EnvFile ps --status running --services 2>$null
if (-not ($drStatus -and ($drStatus -split "`n" | Where-Object { $_.Trim() -eq "pg-standby-dr" }))) {
    throw "[rejoin] ABORT: pg-standby-dr is not running. Ensure the DR failover has completed."
}

# ---------------------------------------------------------------------------
# Confirmation gate
# ---------------------------------------------------------------------------

$actionDescription = "erase volume '$fullVolumeName' and re-clone $NodeName from pg-standby-dr"
$warningMessage    = @"
WARNING: This will permanently ERASE all data in volume '$fullVolumeName'.
The node '$NodeName' will be cloned fresh from the current primary (pg-standby-dr).
This cannot be undone.
"@

Write-Host ""
Write-Host $warningMessage
Write-Host ""

if (-not $Force -and -not $PSCmdlet.ShouldProcess($fullVolumeName, $actionDescription)) {
    Write-Host "[rejoin] cancelled — no changes made"
    return
}

# ---------------------------------------------------------------------------
# Create a temporary docker-compose.override.yml
# ---------------------------------------------------------------------------
# cluster-entrypoint.sh reads PRIMARY_HOST from environment.
# After DR failover, the container 'pg-primary' may not be running, so
# we override PRIMARY_HOST to pg-standby-dr for the re-clone run.

$overrideFile = Join-Path $root "docker-compose.override.yml"
$overrideExists = Test-Path $overrideFile

if ($overrideExists) {
    throw "[rejoin] ABORT: docker-compose.override.yml already exists at $overrideFile. Remove it manually before proceeding to avoid unexpected interactions."
}

Write-Host "[rejoin] creating temporary docker-compose.override.yml to set PRIMARY_HOST=pg-standby-dr for $NodeName"

$overrideContent = @"
# Temporary override created by Invoke-RejoinNode.ps1
# Removed automatically after re-clone completes.
services:
  ${NodeName}:
    environment:
      PRIMARY_HOST: pg-standby-dr
"@

Set-Content -LiteralPath $overrideFile -Value $overrideContent -Encoding utf8
Write-Host "[rejoin] override file written: $overrideFile"

# Register cleanup so the override is always removed on exit.
$cleanupBlock = {
    if (Test-Path $overrideFile) {
        Remove-Item -LiteralPath $overrideFile -Force -ErrorAction SilentlyContinue
        Write-Host "[rejoin] temporary docker-compose.override.yml removed"
    }
}

try {
    # -----------------------------------------------------------------------
    # Remove the PGDATA volume
    # -----------------------------------------------------------------------

    Write-Host "[rejoin] removing Docker volume: $fullVolumeName"
    docker volume rm $fullVolumeName
    if ($LASTEXITCODE -ne 0) { throw "docker volume rm $fullVolumeName failed (exit $LASTEXITCODE)" }
    Write-Host "[rejoin] volume $fullVolumeName removed"

    # -----------------------------------------------------------------------
    # Start the node — cluster-entrypoint.sh detects empty PGDATA and clones
    # -----------------------------------------------------------------------

    Write-Host "[rejoin] starting $NodeName — cluster-entrypoint.sh will clone from pg-standby-dr"
    docker compose --env-file $EnvFile up -d $NodeName
    if ($LASTEXITCODE -ne 0) { throw "docker compose up -d $NodeName failed (exit $LASTEXITCODE)" }

    # -----------------------------------------------------------------------
    # Wait for healthy
    # -----------------------------------------------------------------------

    Wait-ContainerHealthy -Service $NodeName -TimeoutSeconds 300

} finally {
    & $cleanupBlock
}

Write-Host ""
Write-Host "[rejoin] PASS: $NodeName has been re-cloned and is now a standby of pg-standby-dr"
Write-Host "[rejoin] Run Test-Cluster.ps1 to verify replication status after updating the cluster"
Write-Host "[rejoin] Note: repmgr cluster show will reflect the new topology once pg-standby-dr"
Write-Host "[rejoin]       has been promoted. The $NodeName node re-registers itself on startup."
