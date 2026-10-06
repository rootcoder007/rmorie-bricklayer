#!/usr/bin/env bash
# Build the libFuzzer targets with AddressSanitizer + UndefinedBehaviorSanitizer.
#   CXX=clang++ (default; libFuzzer needs clang)
set -euo pipefail
cd "$(dirname "$0")"
CXX=${CXX:-clang++}
RCPP=$(R CMD config --cppflags)
# only R itself: `R CMD config --ldflags` lists libraries R was built against
# (-ltirpc, -licuuc ...) that a plain runner does not carry
RLIB=$(R RHOME)/lib
RLD="-L$RLIB -Wl,-rpath,$RLIB -lR"
FLAGS="-std=gnu++17 -g -O1 -fno-omit-frame-pointer -fsanitize=fuzzer,address,undefined -fno-sanitize-recover=undefined -I../../src $RCPP"
OUT=${OUT:-build}
mkdir -p "$OUT"
$CXX $FLAGS fuzz_der.cpp -o "$OUT/fuzz_der" $RLD
$CXX $FLAGS fuzz_strtod.cpp -o "$OUT/fuzz_strtod" $RLD
$CXX $FLAGS fuzz_siu.cpp ../../src/siu_parse.cpp ../../src/siu_resolve.cpp -o "$OUT/fuzz_siu"
echo "built $OUT/fuzz_der $OUT/fuzz_strtod $OUT/fuzz_siu"
