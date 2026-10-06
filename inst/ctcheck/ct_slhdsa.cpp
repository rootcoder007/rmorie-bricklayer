#include "ct_common.h"
#include "../../src/rmbl_slhdsa.cpp"

#define SLHDSA_CASE(NS, FN)                                                        \
    int FN() {                                                                     \
        namespace S = NS;                                                          \
        unsigned char seed[3 * 32], opt[32], msg[17], ctx[1];                      \
        std::vector<unsigned char> pk(S::kPkBytes), sk(S::kSkBytes), sig(S::kSigBytes); \
        ct_fill(seed, sizeof seed, 31);                                            \
        ct_fill(opt, sizeof opt, 32);                                              \
        ct_fill(msg, sizeof msg, 33);                                              \
        ct_secret(seed, 2 * S::kN); /* SK.seed || SK.prf; PK.seed is public */     \
        S::seed_keypair(pk.data(), sk.data(), seed);                               \
        int rem = ct_stack_remnants(seed, 2 * S::kN, "SLH-DSA SK.seed");           \
        ct_public(pk.data(), pk.size());                                           \
        ct_secret(opt, S::kN);                                                     \
        S::sign(sig.data(), msg, sizeof msg, ctx, 0, opt, sk.data(), NULL, 0);     \
        rem += ct_stack_remnants(sk.data(), S::kN, "SLH-DSA SK.seed after signing"); \
        ct_public(sig.data(), sig.size());                                         \
        if (S::verify(sig.data(), sig.size(), msg, sizeof msg, ctx, 0, pk.data(), NULL, 0) != 0) return 1; \
        return rem ? 3 : 0;                                                        \
    }

SLHDSA_CASE(rmbl_slhdsa_shake_128f, ct_slhdsa_shake_128f)
SLHDSA_CASE(rmbl_slhdsa_sha2_128f, ct_slhdsa_sha2_128f)
SLHDSA_CASE(rmbl_slhdsa_shake_128s, ct_slhdsa_shake_128s)
