# inst/ctcheck — constant-time verification

A standalone harness, built from the package's own `src/` files, that runs
every operation touching a secret under **valgrind memcheck** with the secret
marked undefined (the ctgrind method, Langley 2010). Memcheck then reports
every conditional jump and every memory address that depends on the secret:
exactly the set of secret-dependent branches and table lookups a timing
attacker can observe. A clean run is a proof for this binary, for every input
of that length. The same run scans the dead stack after each operation for
copies of the secret (zeroisation).

The package's CI runs it with GCC and with Clang on every change
(`.github/workflows/constant-time.yml`). To run it yourself on Linux:

    bash inst/ctcheck/build.sh     # needs R, a C++17 compiler, <valgrind/memcheck.h>
    bash inst/ctcheck/run.sh       # one memcheck run per case; exit 0 = all clean

Files: `ct_common.h` (taint/declassify helpers), `ctcheck.cpp` (case table,
dead-stack scan), one `ct_<family>.cpp` per scheme family (each includes its
scheme's `.cpp` so static helpers do not collide). The only values the
schemes may branch on are the ones their specifications publish (a rejected
sample, the challenge, the hints, R); each passes through a
`RMBL_*_DECLASSIFY()` hook in `src/`, a no-op in the package.
