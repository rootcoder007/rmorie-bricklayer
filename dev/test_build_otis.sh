#!/usr/bin/env bash
# tests/test_build_otis.sh
#
# Smoke test: build the otis-mrp example bundle and verify it.
# Used as the canonical "does the framework actually work?" check.
#
# USAGE:
#   ./tests/test_build_otis.sh
#   ./tests/test_build_otis.sh --with-data /path/to/a01_RC.csv
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_PATH=""
if [[ "${1:-}" == "--with-data" ]]; then
  DATA_PATH="$2"
fi

cd "${REPO_ROOT}"

echo "[1/4] Building otis-mrp bundle..."
if [[ -n "${DATA_PATH}" ]]; then
  ./make_bundle.sh otis-mrp --with-data "${DATA_PATH}" --version test
else
  ./make_bundle.sh otis-mrp --version test
fi

echo
echo "[2/4] Locating built bundle..."
BUNDLE="$(ls -1t dist/otis-mrp_vtest*.zip 2>/dev/null | head -1)"
if [[ -z "${BUNDLE}" ]]; then
  echo "FAIL: no bundle built"
  exit 1
fi
echo "  Found: ${BUNDLE}"

echo
echo "[3/4] Auditing via verify_bundle.sh..."
./scripts/verify_bundle.sh "${BUNDLE}" --clean
RC=$?

echo
echo "[4/4] Running the bundle's offline synthetic route (--synthetic --quick)..."
# The one path a stranger with no internet is told to take; it never runs
# on a normal CI pass because the download succeeds first.
SYN_DIR="$(mktemp -d)"
unzip -q "${BUNDLE}" -d "${SYN_DIR}"
SYN_ROOT="$(find "${SYN_DIR}" -maxdepth 2 -name setup_and_run.R -exec dirname {} \; | head -1)"
if ( cd "${SYN_ROOT}" && Rscript setup_and_run.R --synthetic --quick > synthetic_run.log 2>&1 ) \
   && [[ -n "$(find "${SYN_ROOT}" -path "*/results_*/manifest.json" | head -1)" ]]; then
  echo "  synthetic route: OK (manifest.json written)"
else
  echo "FAIL: synthetic route did not complete"
  tail -30 "${SYN_ROOT}/synthetic_run.log" 2>/dev/null
  RC=1
fi
rm -rf "${SYN_DIR}"

if [[ ${RC} -eq 0 ]]; then
  echo
  echo "=========================================================="
  echo "  ✓ test_build_otis PASSED"
  echo "=========================================================="
  exit 0
else
  echo "FAIL: verify_bundle exited ${RC}"
  exit ${RC}
fi
