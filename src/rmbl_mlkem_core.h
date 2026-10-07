#ifndef RMBL_MLKEM_CORE_H
#define RMBL_MLKEM_CORE_H

/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * Shared arithmetic for ML-KEM (FIPS 203): the ring Z_q[X]/(X^256+1)
 * with q = 3329, its number-theoretic transform, and the Montgomery and
 * Barrett reductions that keep coefficients in range.
 *
 * ML-KEM is a key ENCAPSULATION mechanism, not a signature: it
 * establishes a shared secret rather than proving authorship. It sits
 * beside the signature schemes here because the same Keccak sponge and
 * the same kind of lattice arithmetic underlie both, and because a
 * capsule that is signed but transmitted in the clear is only half
 * protected.
 *
 * The NTT here is NOT the one in rmbl_mldsa_core.h. ML-KEM's modulus is
 * 3329 against ML-DSA's 8380417, its transform is incomplete (seven
 * layers, leaving degree-one base cases rather than reaching constants),
 * and its root of unity is 17. Sharing code between them would be a
 * false economy and a good way to produce two subtly wrong transforms.
 */

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <vector>

#include <R.h>
#include <Rinternals.h>
#include "rmbl_ct.h"

/* the FIPS 202 sponge from rmbl_keccak.cpp */
struct RmblKeccak {
    uint64_t s[25];
    size_t rate;
    unsigned char pad;
    size_t pos;
    bool squeezing;
};
extern "C" void rmbl_keccak_init(RmblKeccak *, size_t, unsigned char);
extern "C" void rmbl_keccak_absorb(RmblKeccak *, const unsigned char *, size_t);
extern "C" void rmbl_keccak_finalize(RmblKeccak *);
extern "C" void rmbl_keccak_squeeze(RmblKeccak *, unsigned char *, size_t);
extern "C" void rmbl_shake128(unsigned char *, size_t,
                              const unsigned char *, size_t);
extern "C" void rmbl_shake256(unsigned char *, size_t,
                              const unsigned char *, size_t);
extern "C" void rmbl_sha3_256(unsigned char *, const unsigned char *, size_t);
extern "C" void rmbl_sha3_512(unsigned char *, const unsigned char *, size_t);

/* the ring arithmetic, R-free so the simulated power analysis (inst/tvla) compiles the
 * same code for a Cortex-M target */
#include "rmbl_mlkem_arith.h"

#endif
