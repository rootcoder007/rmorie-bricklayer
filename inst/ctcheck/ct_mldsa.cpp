#include "ct_common.h"
#include "../../src/rmbl_mldsa_ntt.cpp"

/* Masking randomness for the masked signer, marked secret as it is produced. */
static uint64_t ct_dsa_xs = 0x9E3779B97F4A7C15ull;
static uint32_t ct_dsa_mask_u32(void *) {
    ct_dsa_xs ^= ct_dsa_xs << 13;
    ct_dsa_xs ^= ct_dsa_xs >> 7;
    ct_dsa_xs ^= ct_dsa_xs << 17;
    uint32_t v = static_cast<uint32_t>(ct_dsa_xs >> 32);
    ct_secret(&v, sizeof v);
    return v;
}

#define MLDSA_CASE(NS, FN)                                                         \
    int FN() {                                                                     \
        namespace M = NS;                                                          \
        unsigned char seed[32], rnd[32], msg[33], ctx[1];                          \
        std::vector<unsigned char> pk(M::kPkBytes), sk(M::kSkBytes), sig(M::kSigBytes); \
        ct_fill(seed, 32, 21);                                                     \
        ct_fill(rnd, 32, 22);                                                      \
        ct_fill(msg, 33, 23);                                                      \
        ct_secret(seed, 32);                                                       \
        M::keypair_from_seed(pk.data(), sk.data(), seed);                          \
        int rem = ct_stack_remnants(seed, 32, "ML-DSA seed");                      \
        ct_public(pk.data(), pk.size()); /* the public key is published */         \
        ct_secret(rnd, 32);                                                        \
        const int rc = M::sign_internal(sig.data(), msg, 33, ctx, 0, rnd, sk.data()); \
        rem += ct_stack_remnants(sk.data() + 32, 32, "ML-DSA signing key K");      \
        if (rc != 0) return 1;                                                     \
        ct_public(sig.data(), sig.size()); /* the signature is published */        \
        if (M::verify_internal(sig.data(), msg, 33, ctx, 0, pk.data()) != 0) return 1; \
        /* the masked signer: same bytes, and no branch on a key or mask bit */      \
        std::vector<unsigned char> sig2(M::kSigBytes);                             \
        rmbl_masked::Rng rng;                                                      \
        rng.fn = ct_dsa_mask_u32;                                                  \
        rng.ctx = nullptr;                                                         \
        if (M::sign_internal_masked(sig2.data(), msg, 33, ctx, 0, rnd, sk.data(), rng) != 0) return 1; \
        ct_public(sig2.data(), sig2.size());                                       \
        if (sig2 != sig) return 1;                                                 \
        return rem ? 3 : 0;                                                        \
    }

MLDSA_CASE(rmbl_mldsa44, ct_mldsa44)
MLDSA_CASE(rmbl_mldsa65, ct_mldsa65)
MLDSA_CASE(rmbl_mldsa87, ct_mldsa87)
