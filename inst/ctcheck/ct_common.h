/* Shared by every constant-time check translation unit.
 *
 * The method is ctgrind's (Langley 2010): secret bytes are marked
 * UNDEFINED for valgrind memcheck before the primitive runs. Memcheck
 * then reports every conditional jump and every memory address that
 * depends on them -- which is exactly the set of secret-dependent
 * branches and table lookups a timing attacker can observe. A clean
 * run is a proof that no such branch exists on this binary, for every
 * input of this length: unlike a timing measurement it does not depend
 * on noise, repetitions or the machine.
 *
 * The only values a scheme may branch on are the ones its specification
 * publishes anyway (a rejected sample, a signature's challenge, the
 * public key). Each of those passes through a RMBL_*_DECLASSIFY() hook in
 * the source, which is a no-op in the package and MAKE_MEM_DEFINED here.
 */
#pragma once
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <vector>
#include <valgrind/memcheck.h>

#define RMBL_CT_DECLASSIFY(p, n) ((void)VALGRIND_MAKE_MEM_DEFINED((p), (n)))
#define RMBL_HQC_DECLASSIFY(p, n) RMBL_CT_DECLASSIFY(p, n)
#include "../../src/rmbl_ct.h"
#define RMBL_MLDSA_DECLASSIFY(p, n) RMBL_CT_DECLASSIFY(p, n)
#define RMBL_MLKEM_DECLASSIFY(p, n) RMBL_CT_DECLASSIFY(p, n)
#define RMBL_SLHDSA_DECLASSIFY(p, n) RMBL_CT_DECLASSIFY(p, n)
#define RMBL_XMSS_DECLASSIFY(p, n) RMBL_CT_DECLASSIFY(p, n)

inline void ct_secret(void *p, size_t n) { (void)VALGRIND_MAKE_MEM_UNDEFINED(p, n); }
inline void ct_public(const void *p, size_t n) { (void)VALGRIND_MAKE_MEM_DEFINED(p, n); }
inline void ct_fill(unsigned char *p, size_t n, unsigned seed) {
    for (size_t i = 0; i < n; ++i) {
        p[i] = static_cast<unsigned char>((seed * 2654435761u + static_cast<unsigned>(i) * 40503u) >> 13);
    }
}
/* Scan the dead stack below this frame for copies of a secret: a wipe that
 * the optimiser dropped, or a temporary that was never wiped, shows up here. */
int ct_stack_remnants(const unsigned char *needle, size_t n, const char *what);
int ct_running_memcheck();
