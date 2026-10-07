#!/usr/bin/env bash
# Fetch the pinned C2SP Wycheproof and NIST ACVP vector sets into DIR (default: vectors)
# and verify every file against tools/vectors/SHA256SUMS. A moved upstream file is a
# checksum failure here, never a silently different test.
#   bash tools/vectors/fetch.sh [DIR]
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
dir=${1:-vectors}
WYCHEPROOF=12fd3aaf33eb5fa1f52e026912ee00c054f9d984   # C2SP/wycheproof
ACVP=975de31eb83d87039ec88934fdc47d8c312b892d         # usnistgov/ACVP-Server
mkdir -p "$dir"
cd "$dir"
while read -r sum path; do
  [ -n "$path" ] || continue
  mkdir -p "$(dirname "$path")"
  case "$path" in
    wycheproof/*) url="https://raw.githubusercontent.com/C2SP/wycheproof/$WYCHEPROOF/testvectors_v1/${path#wycheproof/}" ;;
    acvp/*)       url="https://raw.githubusercontent.com/usnistgov/ACVP-Server/$ACVP/gen-val/json-files/${path#acvp/}" ;;
    *) echo "unknown path $path" >&2; exit 1 ;;
  esac
  if [ ! -f "$path" ] || [ "$(sha256sum "$path" | cut -c1-64)" != "$sum" ]; then
    curl -sSfL --retry 3 -o "$path" "$url"
  fi
done < "$here/SHA256SUMS"
sha256sum -c --quiet "$here/SHA256SUMS"
echo "vectors: $(wc -l < "$here/SHA256SUMS") files verified in $dir"
