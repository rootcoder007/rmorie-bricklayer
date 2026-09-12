#ifndef RMBL_SLHDSA_CORE_H
#define RMBL_SLHDSA_CORE_H

/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * Shared declarations for SLH-DSA (FIPS 205). The parameter-dependent
 * code is in rmbl_slhdsa_body.h, included once per parameter set.
 *
 * The construction is a hypertree of Merkle trees whose leaves are
 * WOTS+ public keys, certifying a FORS key that in turn signs the
 * message digest. Nothing in it is number-theoretic: it is one hash
 * function all the way down, which is why an SLH-DSA signature is
 * kilobytes where an ML-DSA one is hundreds of bytes.
 *
 * FIPS 205 defines two instantiations of that hash function and they
 * are NOT interchangeable:
 *
 *   - SHAKE. The address is 32 bytes, and PRF, H_msg and the tweakable
 *     hash are all SHAKE256 over PK.seed || ADRS || input.
 *   - SHA-2. The address is COMPRESSED to 22 bytes with different
 *     field offsets; PRF and the single-block tweakable hash are
 *     SHA-256 over PK.seed padded to the block size, the multi-block
 *     tweakable hash is SHA-512 at 192-bit security and above, the
 *     message randomiser is HMAC, and the digest is MGF1.
 *
 * Two things here are easy to get wrong and produce a scheme that
 * verifies only against itself:
 *
 *   - Mixing up those two instantiations, in particular the address
 *     layout, which no test that only signs and verifies can catch.
 *   - FIPS 205 prepends a domain separator to the message, exactly as
 *     FIPS 204 does for ML-DSA, and reads the FORS indices most
 *     significant bit first. The round-3 SPHINCS+ submission does
 *     neither, so matching that reference is NOT conformance -- the
 *     same trap this package walked into once with ML-DSA.
 */

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <vector>

#include <R.h>
#include <Rinternals.h>

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
extern "C" void rmbl_shake256(unsigned char *, size_t,
                              const unsigned char *, size_t);

/* the SHA-2 family from rmbl_core.cpp and rmbl_sha512.cpp */
extern "C" void rmbl_sha256_raw(const unsigned char *, size_t,
                                unsigned char[32]);
extern "C" void rmbl_sha512_raw(const unsigned char *, size_t,
                                unsigned char[64]);
extern "C" void rmbl_hmac_shax(int, const unsigned char *, size_t,
                               const unsigned char *, size_t,
                               unsigned char *);
extern "C" void rmbl_mgf1_shax(int, unsigned char *, size_t,
                               const unsigned char *, size_t);

#endif
