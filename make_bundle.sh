#!/usr/bin/env bash
# make_bundle.sh — build dist/<project>_v<N>.zip from this checkout.
#
# A thin wrapper over the package function mkbndl(): it installs this
# checkout into a temporary library (a bundle carries the installed copies
# of the package R files) and builds the zip with it, so the bundle is
# exactly what this checkout's package builds. With the package installed,
# call rmoriebricklayer::mkbndl() from R instead; it needs no shell.
#
# USAGE:
#   ./make_bundle.sh <project>                   # a shipped example or a folder
#   ./make_bundle.sh <project> --with-data PATH  # also include the data file
#   ./make_bundle.sh <project> --version 2       # version suffix (default: 1)
#
# Licence: AGPL-3.0-or-later.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT=""
DATA_PATH=""
VERSION="1"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-data) DATA_PATH="$2"; shift 2 ;;
    --version)   VERSION="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) PROJECT="$1"; shift ;;
  esac
done
[[ -z "${PROJECT}" ]] && { echo "ERROR: project required (e.g. ./make_bundle.sh otis-mrp)"; exit 1; }

# a shipped example is read from this checkout, not from the installed copy
if [[ -d "${ROOT}/inst/bundle/${PROJECT}" ]]; then
  PROJECT="${ROOT}/inst/bundle/${PROJECT}"
fi

LIB="$(mktemp -d)"
trap 'rm -rf "${LIB}"' EXIT
echo "Installing this checkout into a temporary library..."
if ! R CMD INSTALL --no-test-load --no-docs --clean -l "${LIB}" "${ROOT}" > "${LIB}/install.log" 2>&1; then
  tail -30 "${LIB}/install.log"
  exit 1
fi
mkdir -p "${ROOT}/dist"
Rscript -e '
a <- commandArgs(TRUE)
library(rmoriebricklayer, lib.loc = a[[1L]])
b <- mkbndl(a[[2L]], a[[3L]], data = if (nzchar(a[[4L]])) a[[4L]],
            version = a[[5L]], overwrite = TRUE)
print(b)
' "${LIB}" "${PROJECT}" "${ROOT}/dist" "${DATA_PATH}" "${VERSION}"
