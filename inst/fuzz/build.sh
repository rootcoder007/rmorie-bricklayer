#!/usr/bin/env bash
# Build the libFuzzer targets with AddressSanitizer + UndefinedBehaviorSanitizer.
#   CXX=clang++ (default; libFuzzer needs clang)
set -euo pipefail
cd "$(dirname "$0")"
CXX=${CXX:-clang++}
RCPP=$(R CMD config --cppflags)
RLD=$(R CMD config --ldflags)
FLAGS="-std=gnu++17 -g -O1 -fno-omit-frame-pointer -fsanitize=fuzzer,address,undefined -fno-sanitize-recover=undefined -I../../src $RCPP"
OUT=${OUT:-build}
mkdir -p "$OUT"
$CXX $FLAGS fuzz_der.cpp -o "$OUT/fuzz_der" $RLD
$CXX $FLAGS fuzz_strtod.cpp -o "$OUT/fuzz_strtod" $RLD
$CXX $FLAGS fuzz_siu.cpp ../../src/siu_parse.cpp ../../src/siu_resolve.cpp -o "$OUT/fuzz_siu"
echo "built $OUT/fuzz_der $OUT/fuzz_strtod $OUT/fuzz_siu"
