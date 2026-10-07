/* libFuzzer target: differential testing against OpenSSL 3.5 (libcrypto). Every input
 * picks a family by its first byte and must give the same answer from this package and
 * from OpenSSL: digests and XOFs byte for byte, HMAC and PBKDF2 byte for byte, ML-KEM-768
 * decapsulation of an arbitrary ciphertext (implicit rejection included), deterministic
 * ML-DSA-44 signatures byte for byte, and the accept/reject verdict of ML-DSA-44 and
 * SLH-DSA-SHA2-128f on mutated signatures and messages. A disagreement aborts with both
 * answers printed; the sanitizers watch both sides. Needs OpenSSL >= 3.5 (ML-KEM, ML-DSA,
 * SLH-DSA in the default provider). */
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>
#include <openssl/core_names.h>
#include <openssl/evp.h>
#include <openssl/params.h>

extern "C" {
int rmbl_kernel_interrupted = 0;
int rmbl_interrupt_pending(void) { return 0; }
void rmbl_interrupt_raise_unbarriered(void) {}
void rmbl_sha224_raw(const unsigned char *, size_t, unsigned char *);
void rmbl_sha256_raw(const unsigned char *, size_t, unsigned char *);
void rmbl_sha384_raw(const unsigned char *, size_t, unsigned char *);
void rmbl_sha512_raw(const unsigned char *, size_t, unsigned char *);
void rmbl_sha512t_raw(int, const unsigned char *, size_t, unsigned char *);
void rmbl_sha3_224(unsigned char *, const unsigned char *, size_t);
void rmbl_sha3_256(unsigned char *, const unsigned char *, size_t);
void rmbl_sha3_384(unsigned char *, const unsigned char *, size_t);
void rmbl_sha3_512(unsigned char *, const unsigned char *, size_t);
void rmbl_shake128(unsigned char *, size_t, const unsigned char *, size_t);
void rmbl_shake256(unsigned char *, size_t, const unsigned char *, size_t);
int rmbl_blake2b(const unsigned char *, size_t, const unsigned char *, size_t, int, unsigned char *);
void rmbl_hmac_shax(int, const unsigned char *, size_t, const unsigned char *, size_t, unsigned char *);
int rmbl_pbkdf2_sha256(const unsigned char *, size_t, const unsigned char *, size_t, int, int,
                       unsigned char *);
}
size_t ox_mlkem768_ct_bytes();
size_t ox_mlkem768_dk_bytes();
size_t ox_mlkem768_ek_bytes();
void ox_mlkem768_keygen(const unsigned char *, unsigned char *, unsigned char *);
void ox_mlkem768_decaps(unsigned char *, const unsigned char *, const unsigned char *);
size_t ox_mldsa44_pk_bytes();
size_t ox_mldsa44_sk_bytes();
size_t ox_mldsa44_sig_bytes();
void ox_mldsa44_keypair(const unsigned char *, unsigned char *, unsigned char *);
int ox_mldsa44_sign(unsigned char *, const unsigned char *, size_t, const unsigned char *, size_t,
                    const unsigned char *);
int ox_mldsa44_verify(const unsigned char *, const unsigned char *, size_t, const unsigned char *,
                      size_t, const unsigned char *);
size_t ox_slh_pk_bytes();
size_t ox_slh_sk_bytes();
size_t ox_slh_sig_bytes();
void ox_slh_keypair(const unsigned char *, unsigned char *, unsigned char *);
void ox_slh_sign(unsigned char *, const unsigned char *, size_t, const unsigned char *);
int ox_slh_verify(const unsigned char *, size_t, const unsigned char *, size_t, const unsigned char *);

static void hexdump(const char *what, const unsigned char *p, size_t n) {
    std::fprintf(stderr, "%s (%zu): ", what, n);
    for (size_t i = 0; i < n && i < 64; ++i) std::fprintf(stderr, "%02x", p[i]);
    std::fprintf(stderr, "%s\n", n > 64 ? "..." : "");
}
#define DIFFER(msg) do { std::fprintf(stderr, "MISMATCH: %s\n", msg); std::abort(); } while (0)
#define CHECK_OSSL(x) do { if (!(x)) { std::fprintf(stderr, "openssl call failed: %s\n", #x); std::abort(); } } while (0)

/* A cursor over the fuzz input: takes bytes, and zero bytes once it runs out. */
struct In {
    const unsigned char *p; size_t n;
    unsigned char u8() { if (!n) return 0; --n; return *p++; }
    void take(unsigned char *out, size_t k) { for (size_t i = 0; i < k; ++i) out[i] = u8(); }
    std::vector<unsigned char> rest() { std::vector<unsigned char> v(p, p + n); p += n; n = 0; return v; }
};

static void ossl_digest(const char *name, const unsigned char *m, size_t n, unsigned char *out, size_t outlen) {
    EVP_MD *md = EVP_MD_fetch(NULL, name, NULL);
    CHECK_OSSL(md);
    EVP_MD_CTX *c = EVP_MD_CTX_new();
    CHECK_OSSL(EVP_DigestInit_ex(c, md, NULL) && EVP_DigestUpdate(c, m, n));
    if (EVP_MD_get_flags(md) & EVP_MD_FLAG_XOF) CHECK_OSSL(EVP_DigestFinalXOF(c, out, outlen));
    else CHECK_OSSL(EVP_DigestFinal_ex(c, out, NULL));
    EVP_MD_CTX_free(c);
    EVP_MD_free(md);
}

static void fuzz_digest(In &in) {
    const int alg = in.u8() % 13;
    const size_t xof = 1 + in.u8();
    std::vector<unsigned char> m = in.rest();
    unsigned char a[256], b[256];
    struct D { const char *name; size_t len; };
    static const D kD[13] = {{"SHA2-224", 28}, {"SHA2-256", 32}, {"SHA2-384", 48}, {"SHA2-512", 64},
                             {"SHA2-512/224", 28}, {"SHA2-512/256", 32}, {"SHA3-224", 28}, {"SHA3-256", 32},
                             {"SHA3-384", 48}, {"SHA3-512", 64}, {"SHAKE128", 0}, {"SHAKE256", 0},
                             {"BLAKE2B-512", 64}};
    const size_t len = kD[alg].len ? kD[alg].len : xof;
    switch (alg) {
    case 0: rmbl_sha224_raw(m.data(), m.size(), a); break;
    case 1: rmbl_sha256_raw(m.data(), m.size(), a); break;
    case 2: rmbl_sha384_raw(m.data(), m.size(), a); break;
    case 3: rmbl_sha512_raw(m.data(), m.size(), a); break;
    case 4: rmbl_sha512t_raw(224, m.data(), m.size(), a); break;
    case 5: rmbl_sha512t_raw(256, m.data(), m.size(), a); break;
    case 6: rmbl_sha3_224(a, m.data(), m.size()); break;
    case 7: rmbl_sha3_256(a, m.data(), m.size()); break;
    case 8: rmbl_sha3_384(a, m.data(), m.size()); break;
    case 9: rmbl_sha3_512(a, m.data(), m.size()); break;
    case 10: rmbl_shake128(a, len, m.data(), m.size()); break;
    case 11: rmbl_shake256(a, len, m.data(), m.size()); break;
    default: rmbl_blake2b(m.data(), m.size(), NULL, 0, 64, a); break;
    }
    ossl_digest(kD[alg].name, m.data(), m.size(), b, len);
    if (std::memcmp(a, b, len) != 0) {
        hexdump("ours", a, len); hexdump("openssl", b, len); DIFFER(kD[alg].name);
    }
}

static void fuzz_hmac_pbkdf2(In &in) {
    const int which = in.u8() % 3;
    const size_t klen = in.u8() % 200;
    std::vector<unsigned char> key(klen);
    in.take(key.data(), klen);
    if (which < 2) {
        std::vector<unsigned char> m = in.rest();
        const int out = which ? 64 : 32;
        unsigned char a[64], b[64];
        size_t blen = sizeof b;
        rmbl_hmac_shax(out, key.data(), klen, m.data(), m.size(), a);
        EVP_MAC *mac = EVP_MAC_fetch(NULL, "HMAC", NULL);
        EVP_MAC_CTX *c = EVP_MAC_CTX_new(mac);
        OSSL_PARAM ps[] = {OSSL_PARAM_construct_utf8_string("digest", const_cast<char *>(which ? "SHA2-512" : "SHA2-256"), 0),
                           OSSL_PARAM_construct_end()};
        /* a NULL key tells EVP_MAC_init to reuse the previous one: an empty key is a
         * non-NULL pointer of length 0 */
        static const unsigned char kEmpty[1] = {0};
        const unsigned char *kp = klen ? key.data() : kEmpty;
        CHECK_OSSL(EVP_MAC_init(c, kp, klen, ps) && EVP_MAC_update(c, m.data(), m.size()) &&
                   EVP_MAC_final(c, b, &blen, sizeof b));
        EVP_MAC_CTX_free(c);
        EVP_MAC_free(mac);
        if (std::memcmp(a, b, static_cast<size_t>(out)) != 0) { hexdump("ours", a, out); hexdump("openssl", b, out); DIFFER("HMAC"); }
        return;
    }
    const int iter = 1 + in.u8() % 32;
    const int dklen = 1 + in.u8() % 80;
    std::vector<unsigned char> salt = in.rest();
    unsigned char a[80], b[80];
    if (rmbl_pbkdf2_sha256(key.data(), klen, salt.data(), salt.size(), iter, dklen, a) != 0) DIFFER("PBKDF2 refused");
    CHECK_OSSL(PKCS5_PBKDF2_HMAC(reinterpret_cast<const char *>(key.data()), static_cast<int>(klen), salt.data(),
                                 static_cast<int>(salt.size()), iter, EVP_sha256(), dklen, b));
    if (std::memcmp(a, b, static_cast<size_t>(dklen)) != 0) DIFFER("PBKDF2");
}

/* OpenSSL derives a key from a seed at key generation, with the seed set as a parameter
 * (ML-KEM: d || z, 64 bytes; ML-DSA: xi, 32 bytes; SLH-DSA: SK.seed || SK.prf || PK.seed). */
static EVP_PKEY *ossl_from_seed(const char *alg, const unsigned char *seed, size_t n) {
    EVP_PKEY_CTX *c = EVP_PKEY_CTX_new_from_name(NULL, alg, NULL);
    EVP_PKEY *k = NULL;
    OSSL_PARAM ps[] = {OSSL_PARAM_construct_octet_string("seed", const_cast<unsigned char *>(seed), n),
                       OSSL_PARAM_construct_end()};
    CHECK_OSSL(c && EVP_PKEY_keygen_init(c) > 0 && EVP_PKEY_CTX_set_params(c, ps) > 0 &&
               EVP_PKEY_generate(c, &k) > 0);
    EVP_PKEY_CTX_free(c);
    return k;
}
static std::vector<unsigned char> ossl_pub(EVP_PKEY *k) {
    size_t n = 0;
    EVP_PKEY_get_octet_string_param(k, OSSL_PKEY_PARAM_PUB_KEY, NULL, 0, &n);
    std::vector<unsigned char> v(n);
    CHECK_OSSL(EVP_PKEY_get_octet_string_param(k, OSSL_PKEY_PARAM_PUB_KEY, v.data(), n, &n));
    return v;
}

static void fuzz_mlkem(In &in) {
    unsigned char seed[64];
    in.take(seed, 64);
    std::vector<unsigned char> ct(ox_mlkem768_ct_bytes());
    in.take(ct.data(), ct.size());
    std::vector<unsigned char> ek(ox_mlkem768_ek_bytes()), dk(ox_mlkem768_dk_bytes());
    ox_mlkem768_keygen(seed, ek.data(), dk.data());
    EVP_PKEY *k = ossl_from_seed("ML-KEM-768", seed, 64);
    if (ossl_pub(k) != ek) DIFFER("ML-KEM-768 encapsulation key from the same seed");
    unsigned char a[32], b[32];
    size_t blen = sizeof b;
    ox_mlkem768_decaps(a, dk.data(), ct.data());
    EVP_PKEY_CTX *c = EVP_PKEY_CTX_new_from_pkey(NULL, k, NULL);
    CHECK_OSSL(EVP_PKEY_decapsulate_init(c, NULL) > 0 && EVP_PKEY_decapsulate(c, b, &blen, ct.data(), ct.size()) > 0);
    EVP_PKEY_CTX_free(c);
    EVP_PKEY_free(k);
    if (std::memcmp(a, b, 32) != 0) { hexdump("ours", a, 32); hexdump("openssl", b, 32); DIFFER("ML-KEM-768 decapsulation"); }
}

static int ossl_verify(EVP_PKEY *k, const char *alg, const unsigned char *sig, size_t siglen,
                       const unsigned char *m, size_t mlen, const unsigned char *ctx, size_t ctxlen) {
    EVP_SIGNATURE *s = EVP_SIGNATURE_fetch(NULL, alg, NULL);
    EVP_PKEY_CTX *c = EVP_PKEY_CTX_new_from_pkey(NULL, k, NULL);
    OSSL_PARAM ps[] = {OSSL_PARAM_construct_octet_string("context-string", const_cast<unsigned char *>(ctx), ctxlen),
                       OSSL_PARAM_construct_end()};
    int r = 0;
    if (EVP_PKEY_verify_message_init(c, s, ctxlen ? ps : NULL) > 0) r = EVP_PKEY_verify(c, sig, siglen, m, mlen) == 1;
    EVP_PKEY_CTX_free(c);
    EVP_SIGNATURE_free(s);
    return r;
}

static void fuzz_mldsa(In &in, bool mutate) {
    unsigned char seed[32];
    in.take(seed, 32);
    const size_t ctxlen = in.u8() % 64;
    unsigned char ctx[64];
    in.take(ctx, ctxlen);
    const size_t flips = mutate ? in.u8() % 4 : 0;
    unsigned char where[8];
    in.take(where, 2 * flips);
    std::vector<unsigned char> m = in.rest();
    std::vector<unsigned char> pk(ox_mldsa44_pk_bytes()), sk(ox_mldsa44_sk_bytes()), sig(ox_mldsa44_sig_bytes());
    ox_mldsa44_keypair(seed, pk.data(), sk.data());
    EVP_PKEY *k = ossl_from_seed("ML-DSA-44", seed, 32);
    if (ossl_pub(k) != pk) DIFFER("ML-DSA-44 public key from the same seed");
    if (ox_mldsa44_sign(sig.data(), m.data(), m.size(), ctx, ctxlen, sk.data()) != 0) DIFFER("ML-DSA sign failed");
    if (!mutate) {
        EVP_SIGNATURE *s = EVP_SIGNATURE_fetch(NULL, "ML-DSA-44", NULL);
        EVP_PKEY_CTX *c = EVP_PKEY_CTX_new_from_pkey(NULL, k, NULL);
        int det = 1;
        OSSL_PARAM ps[] = {OSSL_PARAM_construct_int("deterministic", &det),
                           OSSL_PARAM_construct_octet_string("context-string", ctx, ctxlen),
                           OSSL_PARAM_construct_end()};
        std::vector<unsigned char> os(sig.size());
        size_t oslen = os.size();
        CHECK_OSSL(EVP_PKEY_sign_message_init(c, s, ps) > 0 &&
                   EVP_PKEY_sign(c, os.data(), &oslen, m.data(), m.size()) > 0);
        EVP_PKEY_CTX_free(c);
        EVP_SIGNATURE_free(s);
        if (oslen != sig.size() || os != sig) { hexdump("ours", sig.data(), sig.size()); hexdump("openssl", os.data(), oslen); DIFFER("ML-DSA-44 deterministic signature"); }
    } else {
        for (size_t f = 0; f < flips; ++f) {
            const size_t pos = (static_cast<size_t>(where[2 * f]) << 4 | where[2 * f + 1]) % (sig.size() + m.size() + 1);
            if (pos < sig.size()) sig[pos] ^= static_cast<unsigned char>(1u << (where[2 * f] & 7));
            else if (pos - sig.size() < m.size()) m[pos - sig.size()] ^= 1;
        }
        const int ours = ox_mldsa44_verify(sig.data(), m.data(), m.size(), ctx, ctxlen, pk.data()) == 0;
        const int theirs = ossl_verify(k, "ML-DSA-44", sig.data(), sig.size(), m.data(), m.size(), ctx, ctxlen);
        if (ours != theirs) { std::fprintf(stderr, "ours=%d openssl=%d\n", ours, theirs); DIFFER("ML-DSA-44 verify verdict"); }
    }
    EVP_PKEY_free(k);
}

static void fuzz_slh(In &in) {
    static std::vector<unsigned char> pk, sk, sig0;
    static EVP_PKEY *k = NULL;
    static const unsigned char msg0[] = "rmoriebricklayer differential SLH-DSA";
    if (!k) {
        unsigned char seed[48];
        for (int i = 0; i < 48; ++i) seed[i] = static_cast<unsigned char>(i * 7 + 1);
        pk.resize(ox_slh_pk_bytes()); sk.resize(ox_slh_sk_bytes()); sig0.resize(ox_slh_sig_bytes());
        ox_slh_keypair(seed, pk.data(), sk.data());
        k = ossl_from_seed("SLH-DSA-SHA2-128f", seed, 48);
        if (ossl_pub(k) != pk) DIFFER("SLH-DSA-SHA2-128f public key from the same seed");
        ox_slh_sign(sig0.data(), msg0, sizeof msg0 - 1, sk.data());
        if (!ossl_verify(k, "SLH-DSA-SHA2-128f", sig0.data(), sig0.size(), msg0, sizeof msg0 - 1, NULL, 0)) DIFFER("OpenSSL rejects our SLH-DSA signature");
    }
    std::vector<unsigned char> sig(sig0);
    std::vector<unsigned char> m(msg0, msg0 + sizeof msg0 - 1);
    const size_t flips = in.u8() % 4;
    for (size_t f = 0; f < flips; ++f) {
        const size_t pos = (static_cast<size_t>(in.u8()) << 8 | in.u8()) % (sig.size() + m.size());
        const unsigned char bit = static_cast<unsigned char>(1u << (in.u8() & 7));
        if (pos < sig.size()) sig[pos] ^= bit; else m[pos - sig.size()] ^= bit;
    }
    const size_t cut = in.u8() == 0xff ? in.u8() : 0;   /* now and then, a truncated signature */
    const size_t siglen = sig.size() - (cut < sig.size() ? cut : 0);
    const int ours = ox_slh_verify(sig.data(), siglen, m.data(), m.size(), pk.data()) == 0;
    const int theirs = ossl_verify(k, "SLH-DSA-SHA2-128f", sig.data(), siglen, m.data(), m.size(), NULL, 0);
    if (ours != theirs) { std::fprintf(stderr, "ours=%d openssl=%d\n", ours, theirs); DIFFER("SLH-DSA-SHA2-128f verify verdict"); }
}

extern "C" int LLVMFuzzerTestOneInput(const unsigned char *data, size_t size) {
    if (size == 0) return 0;
    In in{data + 1, size - 1};
    switch (data[0] % 6) {
    case 0: fuzz_digest(in); break;
    case 1: fuzz_hmac_pbkdf2(in); break;
    case 2: fuzz_mlkem(in); break;
    case 3: fuzz_mldsa(in, false); break;
    case 4: fuzz_mldsa(in, true); break;
    default: fuzz_slh(in); break;
    }
    return 0;
}
