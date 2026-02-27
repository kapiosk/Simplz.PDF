param(
    [ValidateSet("deploy", "restart", "stop", "logs")]
    [string]$Action = "deploy",
    [switch]$NoBuild,
    [switch]$FollowLogs
)

$ErrorActionPreference = "Stop"

function Assert-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found in PATH."
    }
}

Assert-Command -Name "docker"

Write-Host "Using project directory: $PSScriptRoot"
Push-Location $PSScriptRoot

try {
    switch ($Action) {
        "deploy" {
            if ($NoBuild) {
                docker compose up -d
            }
            else {
                docker compose up -d --build
            }
            docker compose ps
        }
        "restart" {
            docker compose restart
            docker compose ps
        }
        "stop" {
            docker compose down
        }
        "logs" {
            if ($FollowLogs) {
                docker compose logs -f --tail=200
            }
            else {
                docker compose logs --tail=200
            }
        }
    }
}
finally {
    Pop-Location
}
