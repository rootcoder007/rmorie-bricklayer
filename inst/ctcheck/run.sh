#!/usr/bin/env bash
# Run every case under valgrind memcheck. Any secret-dependent branch or
# address is a memcheck error (exit 1 from valgrind); a functional or
# zeroisation failure is exit 1/3 from the harness. Exit 0 = all clean.
set -uo pipefail
cd "$(dirname "$0")"
BIN=${BIN:-build/ctcheck}
cases=${*:-$($BIN --list)}
fail=0
for c in $cases; do
  log="build/$c.log"
  if valgrind -q --error-exitcode=99 --undef-value-errors=yes --track-origins=no --num-callers=12 "$BIN" "$c" >"$log" 2>&1; then
    printf '%-20s clean\n' "$c"
  else
    rc=$?
    if [ $rc -eq 99 ]; then
      n=$(grep -c "depends on uninitialised\|Use of uninitialised" "$log")
      printf '%-20s %d secret-dependent branch/address report(s)\n' "$c" "$n"
    else
      printf '%-20s harness exit %d\n' "$c" "$rc"
    fi
    fail=1
  fi
done
exit $fail
