#!/usr/bin/env bash
# Build the constant-time harness against the package sources.
#   VALGRIND_INC=/path/to/include  (when <valgrind/memcheck.h> is not on the default path)
#   CXX=clang++                    (default g++)
set -euo pipefail
cd "$(dirname "$0")"
CXX=${CXX:-g++}
RCPP=$(R CMD config --cppflags)
RLD=$(R CMD config --ldflags)
AES=""
if grep -q "RMBL_AES_X86_NI" ../../src/Makevars.in 2>/dev/null || grep -q "RMBL_AES_X86_NI" ../../src/Makevars 2>/dev/null; then
  AES="-DRMBL_AES_X86_NI -maes -msse2"
fi
FLAGS="-std=gnu++17 -O2 -g -fPIE -fno-omit-frame-pointer -Wall -Wno-unused-function -I../../src ${VALGRIND_INC:+-I$VALGRIND_INC} $RCPP $AES"
OUT=${OUT:-build}
mkdir -p "$OUT"
for f in ctcheck ct_mlkem ct_mldsa ct_slhdsa ct_hqc ct_xmss ct_drbg ct_kdf; do
  $CXX $FLAGS -c "$f.cpp" -o "$OUT/$f.o"
done
for f in rmbl_keccak rmbl_digest rmbl_kdf rmbl_mgf1 rmbl_core; do
  $CXX $FLAGS -c "../../src/$f.cpp" -o "$OUT/$f.o"
done
$CXX "$OUT"/*.o $RLD -o "$OUT/ctcheck"
echo "built $OUT/ctcheck"
