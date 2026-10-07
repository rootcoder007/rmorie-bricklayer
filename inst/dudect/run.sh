#!/usr/bin/env bash
# Run every dudect target; exit 1 when any shows |t| > 10.
#   N=200000 bash inst/dudect/run.sh
set -uo pipefail
cd "$(dirname "$0")"
N=${N:-200000}
OUT=${OUT:-build}
"$OUT/dudect" all "$N"
