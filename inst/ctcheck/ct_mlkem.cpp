#include "ct_common.h"
#include "../../src/rmbl_mlkem.cpp"

#define MLKEM_CASE(NS, FN)                                                        \
    int FN() {                                                                    \
        namespace M = NS;                                                         \
        unsigned char seed[64], m[32], ss[32], ss2[32], ss3[32];                  \
        std::vector<unsigned char> ek(M::kEkBytes), dk(M::kDkBytes), ct(M::kCtBytes); \
        ct_fill(seed, 64, 11);                                                    \
        ct_fill(m, 32, 12);                                                       \
        ct_secret(seed, 64);                                                      \
        M::keygen(ek.data(), dk.data(), seed);                                    \
        int rem = ct_stack_remnants(seed, 64, "ML-KEM seed (d || z)");            \
        ct_public(ek.data(), ek.size()); /* the encapsulation key is published */ \
        ct_secret(m, 32);                                                         \
        if (M::encaps(ct.data(), ss, ek.data(), m) != 0) return 1;               \
        rem += ct_stack_remnants(m, 32, "ML-KEM encapsulation message m");       \
        ct_public(ct.data(), ct.size()); /* the ciphertext is published */        \
        M::decaps(ss2, dk.data(), ct.data());                                     \
        rem += ct_stack_remnants(dk.data(), 32, "ML-KEM decapsulation key");      \
        ct[0] ^= 1; /* implicit rejection must take the same path */              \
        M::decaps(ss3, dk.data(), ct.data());                                     \
        ct_public(ss, 32);                                                        \
        ct_public(ss2, 32);                                                       \
        ct_public(ss3, 32);                                                       \
        if (std::memcmp(ss, ss2, 32) != 0) return 1;                              \
        if (std::memcmp(ss, ss3, 32) == 0) return 1;                              \
        return rem ? 3 : 0;                                                       \
    }

MLKEM_CASE(rmbl_mlkem512, ct_mlkem512)
MLKEM_CASE(rmbl_mlkem768, ct_mlkem768)
MLKEM_CASE(rmbl_mlkem1024, ct_mlkem1024)
