#!/usr/bin/env bash
# Run every dudect target; exit 1 when any shows |t| > 10. A target in dudect's
# "inconclusive" band (4.5 < |t| < 10) is re-measured with three times the samples and,
# if it stays there, reported as a warning with its numbers: on a shared CI runner the
# unmasked ML-KEM decapsulation sits at |t| of about 6 for a difference of three ticks in
# eighty thousand, which the convention does not call a leak and more samples do not move.
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
    line=$("$OUT/dudect" "$t" "$((3 * N))" | tee /dev/stderr)
    echo "$line" | grep -q "LEAKAGE" && { echo "::error::$t: |t| > 10 after re-measurement"; exit 1; }
    echo "$line" | grep -q "no evidence of leakage" || echo "::warning::$t stays in dudect's inconclusive band (4.5 < |t| < 10) after re-measurement: $line"
  done
fi
exit 0
