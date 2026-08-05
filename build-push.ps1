param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Tag
)

$ErrorActionPreference = "Stop"

# Pushes the amd64 half only. build-push.sh pushes $Tag-arm64 on an arm64 host,
# and push-manifest.sh then combines the two into a multi-arch $Tag.
$imageName = "registry.beluggaservices.com/simplz-pdf:$Tag-amd64"

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
Write-Host "Next: build $Tag-arm64 (build-push.sh), then ./push-manifest.sh $Tag" -ForegroundColor Cyan