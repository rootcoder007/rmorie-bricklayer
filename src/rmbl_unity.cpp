// Every C++ source of the package, compiled as one translation unit: the R, C++ standard library
// and package headers are parsed once instead of once per file, which shortens the install (and
// with it the CRAN check). The sources stay separate files (inst/fuzz/build.sh compiles them
// alone); OBJECTS in Makevars.in and Makevars.win lists this file in their place, and
// test-src-hygiene.R checks that it includes each of them exactly once.
#include "rmbl_asn1.cpp"
#include "rmbl_barrier.cpp"
#include "rmbl_core.cpp"
#include "rmbl_digest.cpp"
#include "rmbl_drbg.cpp"
#include "rmbl_ecdsa.cpp"
#include "rmbl_fetch.cpp"
#include "rmbl_hqc.cpp"
#include "rmbl_json.cpp"
#include "rmbl_kdf.cpp"
#include "rmbl_keccak.cpp"
#include "rmbl_mgf1.cpp"
#include "rmbl_mldsa_ntt.cpp"
#include "rmbl_mlkem.cpp"
#include "rmbl_pqc.cpp"
#include "rmbl_series.cpp"
#include "rmbl_siu.cpp"
#include "rmbl_sketch.cpp"
#include "rmbl_slhdsa.cpp"
#include "rmbl_stats.cpp"
#include "rmbl_strtod.cpp"
#include "siu_parse.cpp"
#include "siu_resolve.cpp"
