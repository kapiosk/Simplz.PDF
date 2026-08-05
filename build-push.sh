#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ] || [ -z "$1" ]; then
    echo "Usage: $0 <tag>" >&2
    echo "Builds and pushes the arm64 half of <tag>, as <tag>-arm64." >&2
    echo "Run push-manifest.sh <tag> once both arches are pushed." >&2
    exit 1
fi

tag="$1"
image_name="registry.beluggaservices.com/simplz-pdf:$tag-arm64"

green() { printf '\033[32m%s\033[0m\n' "$1"; }

green "Building $image_name for linux/arm64..."
docker build --platform linux/arm64 --tag "$image_name" .

green "Pushing $image_name..."
docker push "$image_name"

green "Successfully pushed $image_name"
echo "Next: build $tag-amd64 (build-push.ps1), then ./push-manifest.sh $tag"
