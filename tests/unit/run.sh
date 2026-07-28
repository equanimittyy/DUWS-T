#!/usr/bin/env bash
# Run the unit tests: extract each pure function from real source, define it in a
# headless SQF VM (sqf-vm), then run the assertions in cases.sqf.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SRC="$ROOT/src"
SQFVM="$ROOT/tools/sqfvm"

if [ ! -x "$SQFVM" ]; then
  echo "[unit] sqf-vm not found at tools/sqfvm — run tests/get_sqfvm.sh first"
  exit 2
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
DEFS="$TMP/defs.sqf"; : > "$DEFS"

while IFS= read -r line; do
  line="${line%%#*}"
  line="$(echo "$line" | tr -d '[:space:]')"
  [ -z "$line" ] && continue
  file="${line%%::*}"; fn="${line##*::}"
  if [ "${fn#\*}" != "$fn" ]; then
    # A `*name` entry is a whole-file function: the mission compiles the file itself, so there is
    # no `name = {` for the extractor to match. Wrap the file body under the name it is bound to.
    fn="${fn#\*}"
    { printf '%s = {\n' "$fn"; cat "$SRC/$file"; printf '\n};\n'; } >> "$DEFS"
  elif ! python3 "$ROOT/tests/lib/extract_fn.py" "$SRC/$file" "$fn" >> "$DEFS"; then
    echo "[unit] extract failed: $fn from $file"; exit 2
  fi
done < "$HERE/functions.txt"

ALL="$TMP/all.sqf"
cat "$HERE/harness.sqf" "$DEFS" "$HERE/cases.sqf" > "$ALL"
echo 'diag_log format ["TEST-SUMMARY| pass=%1 fail=%2", TEST_PASS, TEST_FAIL];' >> "$ALL"

OUT="$("$SQFVM" -a -i "$ALL" 2>&1)"
echo "$OUT" | grep -E 'TEST-(PASS|FAIL)\|' | sed -E 's/^\[DIAG\][[:space:]]*/  /'

if echo "$OUT" | grep -q '\[ERR\]'; then
  echo "[unit] FAIL: sqf-vm reported parse/run errors:"
  echo "$OUT" | grep '\[ERR\]' | head
  exit 1
fi

summary="$(echo "$OUT" | grep -oE 'pass=[0-9]+ fail=[0-9]+' | tail -1)"
fails="$(echo "$summary" | grep -oE 'fail=[0-9]+' | grep -oE '[0-9]+')"
echo "[unit] $summary"
if [ -n "$summary" ] && [ "${fails:-1}" = "0" ]; then
  echo "[unit] OK"; exit 0
else
  echo "[unit] FAIL"; exit 1
fi
