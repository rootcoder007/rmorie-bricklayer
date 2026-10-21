/* The FIPS 202 sponge of rmbl_keccak.cpp, declared once for every scheme that uses it (SHA-3 and
 * SHAKE, ML-KEM, ML-DSA, SLH-DSA, HQC). The state is exposed so a scheme can squeeze
 * incrementally rather than ask for a fixed output length up front: ML-DSA's rejection sampling
 * does not know in advance how many bytes it will need. */
#ifndef RMBL_KECCAK_H
#define RMBL_KECCAK_H

#include <cstddef>
#include <cstdint>

struct RmblKeccak {
    uint64_t s[25];
    size_t rate;        /* bytes absorbed per permutation */
    unsigned char pad;  /* domain separation byte */
    size_t pos;         /* bytes buffered in the current block */
    bool squeezing;
};

extern "C" void rmbl_keccak_init(RmblKeccak *, size_t, unsigned char);
extern "C" void rmbl_keccak_absorb(RmblKeccak *, const unsigned char *, size_t);
extern "C" void rmbl_keccak_finalize(RmblKeccak *);
extern "C" void rmbl_keccak_squeeze(RmblKeccak *, unsigned char *, size_t);

#endif
