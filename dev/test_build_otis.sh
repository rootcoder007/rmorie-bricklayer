#!/usr/bin/env bash
# dev/test_build_otis.sh
#
# Smoke test: build the otis-mrp example bundle with mkbndl() and check it
# with mkbndlchk(), from a temporary install of this checkout, so the bundle
# carries this checkout's package files.
#
# USAGE:
#   ./dev/test_build_otis.sh
#   ./dev/test_build_otis.sh --with-data /path/to/a01_RC.csv
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_PATH=""
if [[ "${1:-}" == "--with-data" ]]; then
  DATA_PATH="$2"
fi

cd "${REPO_ROOT}"

LIB="$(mktemp -d)"
trap 'rm -rf "${LIB}"' EXIT
echo "[1/3] Installing this checkout..."
if ! R CMD INSTALL --no-test-load --no-docs --clean -l "${LIB}" . > "${LIB}/install.log" 2>&1; then
  tail -30 "${LIB}/install.log"
  exit 1
fi
mkdir -p dist

# [2/3] the bundle, checked as a recipient's copy runs it: the counts must
# be the ones its config.json pins.
# [3/3] the offline synthetic route, the one path a stranger with no
# internet is told to take; it never runs on a normal pass because the
# download succeeds first.
Rscript -e '
a <- commandArgs(TRUE)
library(rmoriebricklayer, lib.loc = a[[1L]])
cat("[2/3] Building and checking the otis-mrp bundle...\n")
b <- mkbndl("otis-mrp", "dist", data = if (nzchar(a[[2L]])) a[[2L]],
            version = "test", overwrite = TRUE)
print(b)
real <- mkbndlchk(b$path)
print(real)
cat("[3/3] Checking its offline synthetic route...\n")
syn <- mkbndlchk(b$path, synthetic = TRUE)
print(syn)
if (!real$ok || !syn$ok) {
  cat("FAIL: the bundle check failed\n")
  quit(status = 1L)
}
cat("test_build_otis PASSED\n")
' "${LIB}" "${DATA_PATH}"
