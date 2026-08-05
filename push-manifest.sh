#!/usr/bin/env bash
# Combines the per-arch tags pushed by build-push.ps1 (amd64) and build-push.sh
# (arm64) into one multi-arch tag, so `docker pull simplz-pdf:<tag>` resolves to
# whichever arch is pulling.
#
# Requires podman: the two builders push different manifest shapes -- podman
# pushes a plain single-arch manifest, Docker/BuildKit pushes an image index
# carrying the image plus a provenance attestation -- and `manifest add` cannot
# take the latter by tag, since it tries to select the entry matching *this*
# host and fails on the foreign arch. So each entry is resolved down to its
# arch-specific digest first. `podman manifest push` also takes an explicit
# destination, which the docker CLI's equivalent does not.
set -euo pipefail

if [ $# -ne 1 ] || [ -z "$1" ]; then
    echo "Usage: $0 <tag>" >&2
    echo "Combines <tag>-amd64 and <tag>-arm64 into a multi-arch <tag>." >&2
    exit 1
fi

tag="$1"
registry="registry.beluggaservices.com"
name="simplz-pdf"
repo="$registry/$name"
list="localhost/simplz-pdf-manifest:$tag"

green() { printf '\033[32m%s\033[0m\n' "$1"; }

# Prints the digest of the $2 (arch) manifest inside the tag $1.
arch_digest() {
    local ref="$1" want="$2" headers body self
    headers="$(mktemp)"
    trap 'rm -f "$headers"' RETURN

    local status
    # -w appends the status code so a 404 (tag not pushed yet) reports itself
    # instead of feeding an empty body to the parser below.
    body="$(curl -sS -m 30 -D "$headers" -w '\n%{http_code}' \
        -H 'Accept: application/vnd.oci.image.index.v1+json' \
        -H 'Accept: application/vnd.docker.distribution.manifest.list.v2+json' \
        -H 'Accept: application/vnd.oci.image.manifest.v1+json' \
        -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' \
        "https://$registry/v2/$name/manifests/$ref")" || {
        echo "error: cannot reach $registry to resolve $ref" >&2
        return 1
    }
    status="${body##*$'\n'}"
    body="${body%$'\n'*}"
    if [ "$status" != "200" ]; then
        echo "error: $repo:$ref returned HTTP $status (has that arch been built and pushed?)" >&2
        return 1
    fi
    self="$(sed -n 's/^[Dd]ocker-[Cc]ontent-[Dd]igest: *//p' "$headers" | tr -d '\r')"

    WANT="$want" SELF="$self" REF="$ref" python3 -c '
import json, os, sys
d = json.load(sys.stdin)
want, self, ref = os.environ["WANT"], os.environ["SELF"], os.environ["REF"]
if "manifests" in d:
    for m in d["manifests"]:
        p = m.get("platform") or {}
        if p.get("architecture") == want and p.get("os") == "linux":
            print(m["digest"])
            break
    else:
        sys.exit(f"{ref} is an index with no linux/{want} entry")
elif self:
    # Plain single-arch manifest -- the tag digest *is* the image. Whether it
    # really is $want gets verified against the assembled list below.
    print(self)
else:
    sys.exit(f"{ref}: registry returned no Docker-Content-Digest")
' <<<"$body"
}

green "Resolving $tag-amd64..."
amd64_digest="$(arch_digest "$tag-amd64" amd64)" || exit 1
echo "  amd64: $amd64_digest"

green "Resolving $tag-arm64..."
arm64_digest="$(arch_digest "$tag-arm64" arm64)" || exit 1
echo "  arm64: $arm64_digest"

podman manifest rm "$list" >/dev/null 2>&1 || true
podman manifest create "$list" >/dev/null
podman manifest add "$list" "$repo@$amd64_digest" >/dev/null
podman manifest add "$list" "$repo@$arm64_digest" >/dev/null

# Guards against pushing a half-built list -- e.g. both tags resolving to the
# same arch because a build was tagged wrongly.
green "Verifying assembled list..."
podman manifest inspect "$list" | python3 -c '
import json, sys
got = sorted({
    f"{(m.get("platform") or {}).get("os")}/{(m.get("platform") or {}).get("architecture")}"
    for m in json.load(sys.stdin).get("manifests", [])
})
print("  contains:", ", ".join(got))
missing = {"linux/amd64", "linux/arm64"} - set(got)
if missing:
    sys.exit(f"assembled list is missing {sorted(missing)}")
'

green "Pushing $repo:$tag..."
podman manifest push --all "$list" "docker://$repo:$tag"

podman manifest rm "$list" >/dev/null 2>&1 || true
green "Successfully pushed multi-arch $repo:$tag"
