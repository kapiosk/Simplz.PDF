$ErrorActionPreference = "Stop"

Write-Host "Stopping existing containers..." -ForegroundColor Yellow
docker compose down

Write-Host "Building and starting services..." -ForegroundColor Green
docker compose up -d --build

if ($LASTEXITCODE -eq 0) {
    Write-Host "Deployment successful!" -ForegroundColor Green
    docker compose ps
} else {
    Write-Host "Deployment failed!" -ForegroundColor Red
    exit 1
}
# Write-Host "Displaying logs for verification..." -ForegroundColor Cyan
# docker compose logs -f
