// siu_parse.cpp and siu_resolve.cpp built as one translation unit: both use <regex>,
// and parsing and instantiating it once instead of twice saves a third of their compile
// time (CRAN check time). The two files stay as they are (inst/fuzz/build.sh compiles
// them alone); OBJECTS in Makevars.in and Makevars.win lists this file instead of them.
#include "siu_parse.cpp"
#include "siu_resolve.cpp"
