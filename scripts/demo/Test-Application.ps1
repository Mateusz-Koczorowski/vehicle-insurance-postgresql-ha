[CmdletBinding()]
param([string]$BaseUrl = "http://127.0.0.1:8000")

$ErrorActionPreference = "Stop"
$paths = @(
    "/health",
    "/?persona=agent",
    "/customers?persona=agent",
    "/policies?persona=agent",
    "/claims?persona=adjuster",
    "/audit?persona=auditor"
)

foreach ($path in $paths) {
    $response = Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl$path"
    if ($response.StatusCode -ne 200) { throw "$path returned $($response.StatusCode)" }
    Write-Host "[app] PASS $path"
}

$agent = Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/?persona=agent"
if ($agent.Content -notmatch "app_agent_anna" -or $agent.Content -notmatch "backend") {
    throw "Application diagnostics do not show current_user and backend"
}
Write-Host "[app] PASS: pages and persona diagnostics are available"
