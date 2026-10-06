#!/usr/bin/env bash
# Run each target for FUZZ_SECONDS (default 60) from its seed corpus. A
# sanitizer report, a timeout or a strtod mismatch leaves a crash-* file and
# a non-zero exit.
set -uo pipefail
cd "$(dirname "$0")"
SECS=${FUZZ_SECONDS:-60}
OUT=${OUT:-build}
fail=0
# R's main thread has an 8 MB C stack; libFuzzer's default is far larger and would
# hide exactly the recursion the SIU target exists to find
ulimit -s 8192 2>/dev/null || true
for t in der strtod siu url; do
  mkdir -p "$OUT/corpus-$t"
  if "$OUT/fuzz_$t" "$OUT/corpus-$t" "corpus/$t" -max_total_time="$SECS" -timeout=10 -rss_limit_mb=2048 -artifact_prefix="$OUT/crash-$t-" -print_final_stats=1 >"$OUT/fuzz-$t.log" 2>&1; then
    printf '%-8s clean  (%s)\n' "$t" "$(grep -oE 'stat::number_of_executed_units: [0-9]+' "$OUT/fuzz-$t.log" | grep -oE '[0-9]+$') executions"
  else
    printf '%-8s FAILED -- see %s\n' "$t" "$OUT/fuzz-$t.log"
    grep -E "ERROR: |MISMATCH|runtime error|SUMMARY" "$OUT/fuzz-$t.log" | head -5
    fail=1
  fi
done
exit $fail
