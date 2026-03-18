#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sources_file="$repo_root/sources.json"

api_url="https://api.github.com/repos/imputnet/helium-linux/releases/latest"

release_json="$(
  API_URL="$api_url" python3 - <<'PY'
import os
import urllib.request

headers = {
    "Accept": "application/vnd.github+json",
    "User-Agent": "helium-flake-updater",
}

token = os.environ.get("GITHUB_TOKEN")
if token:
    headers["Authorization"] = f"Bearer {token}"

request = urllib.request.Request(os.environ["API_URL"], headers=headers)
with urllib.request.urlopen(request) as response:
    print(response.read().decode())
PY
)"

mapfile -t asset_urls < <(
  RELEASE_JSON="$release_json" python3 - <<'PY'
import json
import os
import re
import sys

data = json.loads(os.environ["RELEASE_JSON"])
assets = data.get("assets", [])
patterns = [
    r"-x86_64_linux\.tar\.xz$",
    r"-x86_64_linux\.tar\.xz\.asc$",
    r"-arm64_linux\.tar\.xz$",
    r"-arm64_linux\.tar\.xz\.asc$",
]

for pattern in patterns:
    matches = [
        asset["browser_download_url"]
        for asset in assets
        if re.search(pattern, asset["name"])
    ]
    if len(matches) != 1:
        print(f"expected exactly one asset matching {pattern!r}, found {len(matches)}", file=sys.stderr)
        sys.exit(1)
    print(matches[0])
PY
)

if [[ "${#asset_urls[@]}" -ne 4 ]]; then
  echo "expected four asset URLs from the latest Helium release, found ${#asset_urls[@]}" >&2
  exit 1
fi

x86_url="${asset_urls[0]}"
x86_sig_url="${asset_urls[1]}"
arm64_url="${asset_urls[2]}"
arm64_sig_url="${asset_urls[3]}"

for value in "$x86_url" "$x86_sig_url" "$arm64_url" "$arm64_sig_url"; do
  if [[ -z "$value" || "$value" == "null" ]]; then
    echo "expected release assets were not found in the latest Helium release" >&2
    exit 1
  fi
done

extract_version() {
  sed -E 's#^.*/helium-([0-9][^/]*)-(x86_64|arm64)_linux\.tar\.xz$#\1#'
}

version_x86="$(printf '%s\n' "$x86_url" | extract_version)"
version_arm64="$(printf '%s\n' "$arm64_url" | extract_version)"

if [[ "$version_x86" != "$version_arm64" ]]; then
  echo "release asset versions do not match: $version_x86 vs $version_arm64" >&2
  exit 1
fi

version="$version_x86"

prefetch_hash() {
  local url="$1"
  nix store prefetch-file --json "$url" | python3 -c 'import json, sys; print(json.load(sys.stdin)["hash"])'
}

x86_hash="$(prefetch_hash "$x86_url")"
x86_sig_hash="$(prefetch_hash "$x86_sig_url")"
arm64_hash="$(prefetch_hash "$arm64_url")"
arm64_sig_hash="$(prefetch_hash "$arm64_sig_url")"

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

VERSION="$version" \
X86_URL="$x86_url" \
X86_HASH="$x86_hash" \
X86_SIG_URL="$x86_sig_url" \
X86_SIG_HASH="$x86_sig_hash" \
ARM64_URL="$arm64_url" \
ARM64_HASH="$arm64_hash" \
ARM64_SIG_URL="$arm64_sig_url" \
ARM64_SIG_HASH="$arm64_sig_hash" \
python3 - <<'PY' >"$tmp_file"
import json
import os
import sys

version = os.environ["VERSION"]

data = {
    "version": version,
    "packages": {
        "x86_64-linux": {
            "url": os.environ["X86_URL"],
            "hash": os.environ["X86_HASH"],
            "signatureUrl": os.environ["X86_SIG_URL"],
            "signatureHash": os.environ["X86_SIG_HASH"],
            "archiveRoot": f"helium-{version}-x86_64_linux",
        },
        "aarch64-linux": {
            "url": os.environ["ARM64_URL"],
            "hash": os.environ["ARM64_HASH"],
            "signatureUrl": os.environ["ARM64_SIG_URL"],
            "signatureHash": os.environ["ARM64_SIG_HASH"],
            "archiveRoot": f"helium-{version}-arm64_linux",
        },
    },
}

json.dump(data, sys.stdout, indent=2)
print()
PY

if ! cmp -s "$tmp_file" "$sources_file"; then
  mv "$tmp_file" "$sources_file"
  echo "updated sources.json to Helium $version"
else
  echo "sources.json already matches Helium $version"
fi
