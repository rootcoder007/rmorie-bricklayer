#include "ct_common.h"
#include "../../src/rmbl_mldsa_ntt.cpp"

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
        return rem ? 3 : 0;                                                        \
    }

MLDSA_CASE(rmbl_mldsa44, ct_mldsa44)
MLDSA_CASE(rmbl_mldsa65, ct_mldsa65)
MLDSA_CASE(rmbl_mldsa87, ct_mldsa87)
