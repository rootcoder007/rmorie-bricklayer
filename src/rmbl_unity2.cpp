// The package's C++ sources in three translation units (rmbl_unity1/2/3.cpp): the headers are
// parsed three times instead of once per file, which keeps the install short (the CRAN check),
// and no one unit peaks above about 460 MB while compiling (one unit for all of them reached
// 850 MB, which with R CMD check alongside ran a 2 GB machine out of memory). The sources stay
// separate files (inst/fuzz/build.sh compiles them alone); OBJECTS in Makevars.in and
// Makevars.win lists these files in their place, and test-src-hygiene.R checks that together
// they include each source exactly once.
#include "rmbl_hqc.cpp"
#include "rmbl_mldsa_ntt.cpp"
#include "rmbl_drbg.cpp"
#include "rmbl_slhdsa.cpp"
#include "rmbl_mlkem.cpp"
#include "rmbl_pqc.cpp"
#include "rmbl_keccak.cpp"
#include "rmbl_kdf.cpp"
#include "rmbl_mgf1.cpp"
#include "rmbl_ecdsa.cpp"
#include "rmbl_digest.cpp"
#include "rmbl_asn1.cpp"
