#!/usr/bin/env bash
# Run the whole test suite. The lint checks need only python3; the unit tests need
# sqf-vm at tools/sqfvm (see get_sqfvm.sh). Exit non-zero if anything fails.
# Pass --no-unit to skip the unit tests where sqf-vm is unavailable.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
rc=0

echo "== lint: syntax (bracket/string/comment balance) =="
python3 "$HERE/lint/check_syntax.py" || rc=1
echo
echo "== lint: paths (execVM / #include -> real file) =="
python3 "$HERE/lint/check_paths.py" || rc=1
echo
echo "== lint: retired dialogue functions =="
python3 "$HERE/lint/check_retired.py" || rc=1
echo
echo "== lint: composition fences (role/token resolution) =="
python3 "$HERE/lint/check_compositions.py" || rc=1
echo
echo "== lint: furniture catalog (row shape / vocabulary) =="
python3 "$HERE/lint/check_furniture_catalog.py" || rc=1
echo
echo "== lint: missing broadcast (client-called registry entry not publicVariable'd) =="
python3 "$HERE/lint/check_broadcast.py" || rc=1
echo
echo "== lint: registry load order (load-time read resolves to an earlier entry) =="
python3 "$HERE/lint/check_load_order.py" || rc=1
echo

if [ "${1:-}" = "--no-unit" ]; then
  echo "== unit tests (skipped: --no-unit) =="
else
  echo "== unit tests (sqf-vm) =="
  if [ -x "$HERE/../tools/sqfvm" ]; then
    bash "$HERE/unit/run.sh" || rc=1
  else
    echo "[unit] SKIP: no sqf-vm at tools/sqfvm — run tests/get_sqfvm.sh (lint still gates)"
  fi
fi

echo
[ "$rc" = 0 ] && echo "== ALL PASS ==" || echo "== FAILURES (rc=$rc) =="
exit "$rc"
