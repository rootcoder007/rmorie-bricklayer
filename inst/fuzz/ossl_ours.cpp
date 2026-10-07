/* The package's ML-KEM, ML-DSA and SLH-DSA kernels for fuzz_ossl.cpp. Each scheme's source
 * goes in its own translation unit (they share helper names), as in inst/ctcheck. */
#if defined(OX_MLKEM)
#include "../../src/rmbl_mlkem.cpp"
size_t ox_mlkem768_ct_bytes() { return rmbl_mlkem768::kCtBytes; }
size_t ox_mlkem768_dk_bytes() { return rmbl_mlkem768::kDkBytes; }
size_t ox_mlkem768_ek_bytes() { return rmbl_mlkem768::kEkBytes; }
void ox_mlkem768_keygen(const unsigned char *seed64, unsigned char *ek, unsigned char *dk) {
    rmbl_mlkem768::keygen(ek, dk, seed64);
}
void ox_mlkem768_decaps(unsigned char *ss, const unsigned char *dk, const unsigned char *ct) {
    rmbl_mlkem768::decaps(ss, dk, ct);
}
#elif defined(OX_MLDSA)
#include "../../src/rmbl_mldsa_ntt.cpp"
size_t ox_mldsa44_pk_bytes() { return rmbl_mldsa44::kPkBytes; }
size_t ox_mldsa44_sk_bytes() { return rmbl_mldsa44::kSkBytes; }
size_t ox_mldsa44_sig_bytes() { return rmbl_mldsa44::kSigBytes; }
void ox_mldsa44_keypair(const unsigned char *seed32, unsigned char *pk, unsigned char *sk) {
    rmbl_mldsa44::keypair_from_seed(pk, sk, seed32);
}
int ox_mldsa44_sign(unsigned char *sig, const unsigned char *m, size_t mlen,
                    const unsigned char *ctx, size_t ctxlen, const unsigned char *sk) {
    static const unsigned char rnd[32] = {0}; /* deterministic variant */
    return rmbl_mldsa44::sign_internal(sig, m, mlen, ctx, ctxlen, rnd, sk);
}
int ox_mldsa44_verify(const unsigned char *sig, const unsigned char *m, size_t mlen,
                      const unsigned char *ctx, size_t ctxlen, const unsigned char *pk) {
    return rmbl_mldsa44::verify_internal(sig, m, mlen, ctx, ctxlen, pk);
}
#elif defined(OX_SLHDSA)
#include "../../src/rmbl_slhdsa.cpp"
namespace S = rmbl_slhdsa_sha2_128f;
size_t ox_slh_pk_bytes() { return S::kPkBytes; }
size_t ox_slh_sk_bytes() { return S::kSkBytes; }
size_t ox_slh_sig_bytes() { return S::kSigBytes; }
void ox_slh_keypair(const unsigned char *seed48, unsigned char *pk, unsigned char *sk) {
    S::seed_keypair(pk, sk, seed48);
}
void ox_slh_sign(unsigned char *sig, const unsigned char *m, size_t mlen, const unsigned char *sk) {
    S::sign(sig, m, mlen, NULL, 0, sk + 2 * S::kN, sk, NULL, 0);
}
int ox_slh_verify(const unsigned char *sig, size_t siglen, const unsigned char *m, size_t mlen,
                  const unsigned char *pk) {
    return S::verify(sig, siglen, m, mlen, NULL, 0, pk, NULL, 0);
}
#endif
