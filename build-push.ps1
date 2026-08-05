param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Tag
)

$ErrorActionPreference = "Stop"
$imageName = "registry.beluggaservices.com/simplz-pdf:$Tag"

Write-Host "Building $imageName..." -ForegroundColor Green
docker build --tag $imageName .

if ($LASTEXITCODE -ne 0) {
    throw "Docker build failed."
}

Write-Host "Pushing $imageName..." -ForegroundColor Green
docker push $imageName

if ($LASTEXITCODE -ne 0) {
    throw "Docker push failed."
}

Write-Host "Successfully pushed $imageName" -ForegroundColor Green