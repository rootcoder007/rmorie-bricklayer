#!/usr/bin/env bash
# Build the dudect timing harness against the package sources (see dudect.cpp).
#   CXX=clang++  (default g++)
set -euo pipefail
cd "$(dirname "$0")"
CXX=${CXX:-g++}
RCPP=$(R CMD config --cppflags)
RLIB=$(R RHOME)/lib
RLD="-L$RLIB -Wl,-rpath,$RLIB -lR"
FLAGS="-std=gnu++17 -O2 -g -fPIE -Wall -Wno-unused-function -I../../src $RCPP"
OUT=${OUT:-build}
mkdir -p "$OUT"
for f in dudect dudect_mlkem dudect_hqc; do
  $CXX $FLAGS -c "$f.cpp" -o "$OUT/$f.o"
done
for f in rmbl_keccak rmbl_digest rmbl_kdf rmbl_mgf1 rmbl_core; do
  $CXX $FLAGS -c "../../src/$f.cpp" -o "$OUT/$f.o"
done
$CXX "$OUT"/*.o $RLD -o "$OUT/dudect"
echo "built $OUT/dudect"
