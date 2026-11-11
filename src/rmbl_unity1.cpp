// The package's C++ sources in three translation units (rmbl_unity1/2/3.cpp): the headers are
// parsed three times instead of once per file, which keeps the install short (the CRAN check),
// and no one unit peaks above about 460 MB while compiling (one unit for all of them reached
// 850 MB, which with R CMD check alongside ran a 2 GB machine out of memory). The sources stay
// separate files (inst/fuzz/build.sh compiles them alone); OBJECTS in Makevars.in and
// Makevars.win lists these files in their place, and test-src-hygiene.R checks that together
// they include each source exactly once.
#include "siu_parse.cpp"
#include "siu_resolve.cpp"
#include "rmbl_siu.cpp"
#include "rmbl_json.cpp"
#include "rmbl_strtod.cpp"
