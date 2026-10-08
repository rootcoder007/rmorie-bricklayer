#!/usr/bin/env bash
# Run every dudect target; exit 1 when any shows |t| > 10, or still shows |t| > 4.5
# (dudect's "inconclusive" band) after a second pass with three times the samples.
#   N=200000 bash inst/dudect/run.sh
set -uo pipefail
cd "$(dirname "$0")"
N=${N:-200000}
OUT=${OUT:-build}
log=$(mktemp)
"$OUT/dudect" all "$N" | tee "$log"
rc=${PIPESTATUS[0]}
if [ "$rc" -ne 0 ]; then rm -f "$log"; exit "$rc"; fi
again=$(awk '/inconclusive/ && !/control/ {print $1}' "$log")
rm -f "$log"
if [ -n "$again" ]; then
  echo "== inconclusive at N=$N; re-measuring with N=$((3 * N)): $again"
  for t in $again; do
    "$OUT/dudect" "$t" "$((3 * N))" | tee /dev/stderr | grep -q "no evidence of leakage" || {
      echo "::error::$t stays above |t| = 4.5 after re-measurement"; exit 1; }
  done
fi
exit 0
