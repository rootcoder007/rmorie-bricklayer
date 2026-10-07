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
# the URL policy needs libR only for Rf_GetOption1 (the allow_http option)
$CXX $FLAGS -DRMBL_FUZZ_EXPORTS fuzz_url.cpp ../../src/rmbl_fetch.cpp -o "$OUT/fuzz_url" $RLD $(curl-config --libs 2>/dev/null || echo -lcurl)
# differential target against OpenSSL: needs libcrypto >= 3.5 (ML-KEM, ML-DSA, SLH-DSA);
# REQUIRE_OSSL35=1 (CI) makes its absence an error rather than a skip
if pkg-config --atleast-version=3.5 openssl 2>/dev/null || pkg-config --atleast-version=3.5 libcrypto 2>/dev/null; then
  mkdir -p "$OUT/ox"
  NOLINK="${FLAGS/-fsanitize=fuzzer,/-fsanitize=fuzzer-no-link,}"
  for d in MLKEM MLDSA SLHDSA; do
    $CXX $NOLINK -DOX_$d -c ossl_ours.cpp -o "$OUT/ox/ours_$d.o"
  done
  for f in rmbl_keccak rmbl_digest rmbl_kdf rmbl_mgf1 rmbl_core; do
    $CXX $NOLINK -c "../../src/$f.cpp" -o "$OUT/ox/$f.o"
  done
  $CXX $FLAGS fuzz_ossl.cpp "$OUT"/ox/*.o -o "$OUT/fuzz_ossl" -lcrypto $RLD
  echo "built $OUT/fuzz_ossl (OpenSSL $(pkg-config --modversion openssl 2>/dev/null || pkg-config --modversion libcrypto))"
elif [ "${REQUIRE_OSSL35:-0}" = 1 ]; then
  echo "OpenSSL >= 3.5 is required for fuzz_ossl" >&2
  exit 1
else
  echo "skipping fuzz_ossl: OpenSSL >= 3.5 not found"
fi
echo "built $OUT/fuzz_der $OUT/fuzz_strtod $OUT/fuzz_siu $OUT/fuzz_url"
