#!/usr/bin/env bash
# Run every dudect target. The positive control must be flagged (exit 3 otherwise: the
# machine cannot see a leak, so nothing below is evidence). Any target the first pass puts
# above dudect's "no evidence" line (|t| > 4.5) is re-measured with three times the samples
# before it is judged: a shared CI runner moves a target by several units of t between two
# consecutive passes (the arm64 runner put the unmasked ML-KEM decapsulation at 6, 9.7 and
# 10.6 within one hour for a difference of seven ticks in eighty-four thousand). The
# re-measurement decides: |t| > 10 fails the job, 4.5 < |t| < 10 is reported as a warning
# with its numbers, below 4.5 passes.
#   N=200000 bash inst/dudect/run.sh
set -uo pipefail
cd "$(dirname "$0")"
N=${N:-200000}
OUT=${OUT:-build}
log=$(mktemp)
"$OUT/dudect" all "$N" | tee "$log"
rc=${PIPESTATUS[0]}
if [ "$rc" -eq 3 ]; then rm -f "$log"; echo "::error::positive control not detected"; exit 3; fi
# Arm promises data-independent timing for these instructions only with PSTATE.DIT set.
# When DIT was asked for and the CPU cannot set it (no FEAT_DIT), the run is the plain
# measurement again: it is reported with its numbers, and it cannot be the gate.
gate=1
if [ "${DUDECT_DIT:-0}" = 1 ] && grep -q "DIT: not available" "$log"; then
  gate=0
  echo "::warning::DIT requested but this CPU has no FEAT_DIT: Arm gives no data-independent-timing guarantee here, so this run is reported, not gating"
fi
again=$(awk '(/inconclusive/ || /LEAKAGE/) && !/control/ {print $1}' "$log")
rm -f "$log"
status=0
if [ -n "$again" ]; then
  echo "== above the no-evidence line at N=$N; re-measuring with N=$((3 * N)): $(echo $again | tr '\n' ' ')"
  for t in $again; do
    line=$("$OUT/dudect" "$t" "$((3 * N))" | tee /dev/stderr)
    if echo "$line" | grep -q "LEAKAGE"; then
      if [ "$gate" = 1 ]; then echo "::error::$t: |t| > 10 after re-measurement: $line"; status=1
      else echo "::warning::$t: |t| > 10 after re-measurement on a CPU without DIT (reported, not gating): $line"; fi
    elif ! echo "$line" | grep -q "no evidence of leakage"; then
      echo "::warning::$t stays in dudect's inconclusive band (4.5 < |t| < 10) after re-measurement: $line"
    fi
  done
fi
exit $status
