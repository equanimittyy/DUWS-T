#!/usr/bin/env bash
# Fetch the sqf-vm binary used by the unit tests into the repo-root tools/ dir.
#
# We pin the 1.3.2-RC1 Linux build: it links against an older glibc so it runs in
# the devcontainer (newer official builds require glibc 2.38+), and it is new enough
# to execute the pure helper functions the tests extract. tools/sqfvm is git-ignored
# — this binary is per-environment, like tools/PBO Manager/.
#
# On Windows/macOS, grab the matching asset from
#   https://github.com/SQFvm/runtime/releases
# and drop the binary at tools/sqfvm (or tools/sqfvm.exe).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
TOOLS="$(cd "$HERE/.." && pwd)/tools"
mkdir -p "$TOOLS"

os="$(uname -s)"
if [ "$os" != "Linux" ]; then
  echo "Auto-download is wired for Linux only. On $os, download the matching sqfvm"
  echo "asset from https://github.com/SQFvm/runtime/releases into tools/."
  exit 1
fi

url="$(curl -sL "https://api.github.com/repos/SQFvm/runtime/releases/tags/1.3.2-RC1" \
  | python3 -c "import sys,json
for a in json.load(sys.stdin)['assets']:
    if 'Linux' in a['name']: print(a['browser_download_url'])" | head -1)"
[ -n "$url" ] || { echo "could not locate the Linux sqfvm asset"; exit 1; }

tmp="$(mktemp -d)"
curl -sL -o "$tmp/sqfvm.zip" "$url"
unzip -o -q "$tmp/sqfvm.zip" -d "$tmp"
bin="$(find "$tmp" -type f -name sqfvm | head -1)"
[ -n "$bin" ] || { echo "no sqfvm binary in the archive"; exit 1; }
cp "$bin" "$TOOLS/sqfvm"
chmod +x "$TOOLS/sqfvm"
rm -rf "$tmp"
echo "installed sqf-vm at tools/sqfvm"
