/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * rmbl_pqc.cpp -- post-quantum signatures for capsule provenance.
 *
 * WHY HASH-BASED, AND WHY NOT HAND-ROLLED LATTICES
 * ------------------------------------------------
 * A capsule's provenance needs three primitives, and only one of them
 * is broken by a quantum computer:
 *
 *   * hashing (SHA-256/512) -- Grover only halves the exponent, so
 *     SHA-256 retains ~2^128 preimage resistance. Already adequate.
 *   * HMAC -- symmetric, so likewise adequate with a >=256-bit key.
 *   * signatures -- RSA and the elliptic curves fall to Shor. THIS is
 *     the part that needs replacing.
 *
 * The replacement here is a Winternitz one-time signature (WOTS+) under
 * a Merkle tree, i.e. the XMSS construction of RFC 8391, instantiated
 * with the SHA-256 this package already ships. Its security rests on
 * nothing but the hash function -- no lattice assumption, no new
 * hardness assumption, and no new system dependency, so it builds
 * everywhere bricklayer builds.
 *
 * A lattice scheme (ML-DSA / FIPS 204) is deliberately NOT reimplemented
 * here: an uncertified hand-written NTT, SHAKE and rejection sampler is
 * a worse outcome than no lattice signature at all. Where a standardised
 * lattice signature is wanted, bricklayer defers to liboqs, which is
 * detected at configure time and compiled in only when present (see
 * HAVE_LIBOQS below and ../configure).
 *
 * STATEFULNESS IS A HARD REQUIREMENT
 * ----------------------------------
 * A WOTS+ key signs ONCE. Signing two different messages with one leaf
 * index leaks enough chain material to forge. The R layer therefore
 * tracks the next unused index and refuses to reuse one; this file
 * exposes the index explicitly so that refusal is enforceable and
 * testable. Capsules are signed once at build time, so the statefulness
 * costs nothing here.
 *
 * INTEROPERABILITY
 * ----------------
 * This implements RFC 8391 (parameters n = 32, w = 16, len = 67,
 * SHA-256 as F/PRF/H/H_msg, PRF_keygen per NIST SP 800-208) and is
 * BYTE-COMPATIBLE with the reference implementation: the whole
 * 2500-byte signature for XMSS-SHA2_10_256 matches what
 * github.com/XMSS/xmss-reference produces from the same key material,
 * checked against embedded vectors in tests/testthat/test-xmss-kat.R.
 *
 * That check exists because the security-property tests cannot find a
 * conformance bug. A sound-but-wrong pseudorandom function passes every
 * one of them, and three such divergences were present until the
 * reference was compared against: the WOTS+ chain seeds, the message
 * digest's key, and a missing SK_PRF. It is also verified against those
 * properties -- a signature verifies, a tampered message does not, a
 * tampered signature does not, a foreign key does not, and the WOTS+
 * chains compose as specified. It
 * is NOT claimed to be byte-compatible with other XMSS implementations
 * and must not be used as though it were certified. Within the rmorie
 * ecosystem the same package signs and verifies, which is the use case
 * it is for.
 */

#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

#include <cstdint>
#include <cstddef>
#include <cstring>
#include <string>
#include <vector>

#ifdef HAVE_LIBOQS
#include <oqs/oqs.h>
#endif

extern "C" void rmbl_sha256_raw(const unsigned char *data, size_t len,
                                unsigned char out[32]);

namespace {

const size_t kN = 32;      /* digest / node size in bytes */
const int    kW = 16;      /* Winternitz parameter */
const int    kLen1 = 64;   /* ceil(8n / lg w) */
const int    kLen2 = 3;    /* floor(lg(len1 (w-1)) / lg w) + 1 */
const int    kLen = kLen1 + kLen2;   /* 67 WOTS+ chains */

const char kHex[] = "0123456789abcdef";

void hexlify(const unsigned char *b, size_t n, std::string &out) {
    out.resize(n * 2);
    for (size_t i = 0; i < n; ++i) {
        out[i * 2] = kHex[(b[i] >> 4) & 0xf];
        out[i * 2 + 1] = kHex[b[i] & 0xf];
    }
}

int unhex_nibble(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

/* Returns false on any non-hex or odd-length input rather than
 * silently decoding garbage. */
bool unhexlify(const char *s, std::vector<unsigned char> &out) {
    const size_t len = std::strlen(s);
    if (len % 2 != 0) return false;
    out.resize(len / 2);
    for (size_t i = 0; i < len / 2; ++i) {
        const int hi = unhex_nibble(s[i * 2]);
        const int lo = unhex_nibble(s[i * 2 + 1]);
        if (hi < 0 || lo < 0) return false;
        out[i] = static_cast<unsigned char>((hi << 4) | lo);
    }
    return true;
}

/* toByte(x, 32) -- big-endian, zero-padded on the left. */
void to_byte32(uint64_t x, unsigned char out[32]) {
    std::memset(out, 0, 32);
    for (int i = 0; i < 8; ++i) {
        out[31 - i] = static_cast<unsigned char>((x >> (i * 8)) & 0xff);
    }
}

/* The four domain-separated hash functions of RFC 8391 section 5.1.
 * The separator prevents a digest computed for one role being replayed
 * in another. */
void hash_dom(uint64_t dom, const unsigned char *key,
              const unsigned char *msg, size_t msglen,
              unsigned char out[32]) {
    std::vector<unsigned char> buf(32 + kN + msglen);
    to_byte32(dom, buf.data());
    std::memcpy(buf.data() + 32, key, kN);
    if (msglen > 0) std::memcpy(buf.data() + 32 + kN, msg, msglen);
    rmbl_sha256_raw(buf.data(), buf.size(), out);
}

void fn_F(const unsigned char *key, const unsigned char *m,
          unsigned char out[32]) {
    hash_dom(0, key, m, kN, out);
}

void fn_H(const unsigned char *key, const unsigned char *m64,
          unsigned char out[32]) {
    hash_dom(1, key, m64, 2 * kN, out);
}

/* H_msg as RFC 8391 section 4.1.9 specifies it:
 *
 *   SHA-256( toByte(2, 32) || R || root || toByte(idx, n) || M )
 *
 * The randomiser R, the tree root and the leaf index are part of the
 * KEY, not part of the message, and R -- which is PRF(SK_PRF,
 * toByte(idx, 32)) -- binds the digest to this signature. An earlier
 * version keyed this with the public seed and pushed idx || root into
 * the message instead; that is a sound domain-separated hash and is not
 * the specified one, so the digest signed here could not be reproduced
 * by any other implementation.
 */
void fn_Hmsg_bound(const unsigned char *r, const unsigned char *root,
                   uint64_t idx, const unsigned char *m, size_t mlen,
                   unsigned char out[32]) {
    std::vector<unsigned char> buf(32 + 3 * kN + mlen);
    to_byte32(2, buf.data());
    std::memcpy(buf.data() + 32, r, kN);
    std::memcpy(buf.data() + 32 + kN, root, kN);
    to_byte32(idx, buf.data() + 32 + 2 * kN);
    if (mlen > 0) std::memcpy(buf.data() + 32 + 3 * kN, m, mlen);
    rmbl_sha256_raw(buf.data(), buf.size(), out);
}


/* PRF_keygen -- domain 4, and its message is pub_seed || ADRS, i.e.
 * n + 32 bytes rather than PRF's 32. NIST SP 800-208 separates this
 * from PRF so that the value used to expand a secret key can never
 * collide with one used to mask a hash. */
void fn_PRFkeygen(const unsigned char *key, const unsigned char *pub_seed,
                  const unsigned char adrs_bytes[32],
                  unsigned char out[32]) {
    std::vector<unsigned char> buf(32 + kN + kN + 32);
    to_byte32(4, buf.data());
    std::memcpy(buf.data() + 32, key, kN);
    std::memcpy(buf.data() + 32 + kN, pub_seed, kN);
    std::memcpy(buf.data() + 32 + kN + kN, adrs_bytes, 32);
    rmbl_sha256_raw(buf.data(), buf.size(), out);
}

void fn_PRF(const unsigned char *key, const unsigned char *m32,
            unsigned char out[32]) {
    hash_dom(3, key, m32, kN, out);
}

/* Hash address: eight 32-bit big-endian words (RFC 8391 section 2.5). */
struct Adrs {
    uint32_t w[8];
    Adrs() { std::memset(w, 0, sizeof(w)); }
    void bytes(unsigned char out[32]) const {
        for (int i = 0; i < 8; ++i) {
            out[i * 4 + 0] = static_cast<unsigned char>((w[i] >> 24) & 0xff);
            out[i * 4 + 1] = static_cast<unsigned char>((w[i] >> 16) & 0xff);
            out[i * 4 + 2] = static_cast<unsigned char>((w[i] >> 8) & 0xff);
            out[i * 4 + 3] = static_cast<unsigned char>(w[i] & 0xff);
        }
    }
    void set_type(uint32_t t) {
        w[3] = t;
        w[4] = w[5] = w[6] = w[7] = 0;
    }
    void set_ots(uint32_t i)        { w[4] = i; }
    void set_chain(uint32_t i)      { w[5] = i; }
    void set_hash(uint32_t i)       { w[6] = i; }
    void set_key_and_mask(uint32_t i) { w[7] = i; }
    void set_ltree(uint32_t i)      { w[4] = i; }
    void set_tree_height(uint32_t i){ w[5] = i; }
    void set_tree_index(uint32_t i) { w[6] = i; }
};

/* RAND_HASH: keyed, bitmasked compression of two nodes. */
void rand_hash(const unsigned char *l, const unsigned char *r,
               const unsigned char *seed, Adrs adrs, unsigned char out[32]) {
    unsigned char ab[32], key[32], bm0[32], bm1[32];
    adrs.set_key_and_mask(0);
    adrs.bytes(ab);
    fn_PRF(seed, ab, key);
    adrs.set_key_and_mask(1);
    adrs.bytes(ab);
    fn_PRF(seed, ab, bm0);
    adrs.set_key_and_mask(2);
    adrs.bytes(ab);
    fn_PRF(seed, ab, bm1);
    unsigned char m[64];
    for (size_t i = 0; i < kN; ++i) {
        m[i] = static_cast<unsigned char>(l[i] ^ bm0[i]);
        m[kN + i] = static_cast<unsigned char>(r[i] ^ bm1[i]);
    }
    fn_H(key, m, out);
}

/* WOTS+ chaining: s applications of F starting from step i, each with a
 * fresh key and bitmask drawn from the public seed and the address. */
void chain(const unsigned char *x, int i, int s, const unsigned char *seed,
           Adrs adrs, unsigned char out[32]) {
    std::memcpy(out, x, kN);
    if (s == 0) return;
    for (int j = i; j < i + s && j < kW - 1 + 1; ++j) {
        adrs.set_hash(static_cast<uint32_t>(j));
        unsigned char ab[32], key[32], bm[32], tmp[32];
        adrs.set_key_and_mask(0);
        adrs.bytes(ab);
        fn_PRF(seed, ab, key);
        adrs.set_key_and_mask(1);
        adrs.bytes(ab);
        fn_PRF(seed, ab, bm);
        for (size_t k = 0; k < kN; ++k) {
            tmp[k] = static_cast<unsigned char>(out[k] ^ bm[k]);
        }
        fn_F(key, tmp, out);
    }
}

/* base-w expansion of a byte string, w = 16 so two digits per byte. */
void base_w(const unsigned char *in, size_t inlen, int *out, int outlen) {
    int k = 0;
    for (size_t i = 0; i < inlen && k < outlen; ++i) {
        out[k++] = (in[i] >> 4) & 0x0f;
        if (k < outlen) out[k++] = in[i] & 0x0f;
    }
}

/* The Winternitz checksum. Without it an adversary could lower every
 * digit and walk the chains forward to forge. */
void wots_digits(const unsigned char *msg32, int *digits) {
    base_w(msg32, kN, digits, kLen1);
    int csum = 0;
    for (int i = 0; i < kLen1; ++i) csum += (kW - 1) - digits[i];
    /* left-shift so the checksum occupies whole base-w digits */
    csum <<= 4;
    unsigned char csbytes[2];
    csbytes[0] = static_cast<unsigned char>((csum >> 8) & 0xff);
    csbytes[1] = static_cast<unsigned char>(csum & 0xff);
    int cs[4];
    base_w(csbytes, 2, cs, 4);
    for (int i = 0; i < kLen2; ++i) digits[kLen1 + i] = cs[i];
}

/* WOTS+ private chain starts, derived from the secret seed so the key is
 * a single 32-byte secret rather than 67 stored values.
 *
 * This is RFC 8391's expand_seed as amended by NIST SP 800-208: the
 * chain seed is PRF_keygen(SK_SEED, PUB_SEED || ADRS) with the OTS and
 * chain addresses set and the hash and keyAndMask words zeroed. An
 * earlier version keyed a plain PRF with toByte(ots_index << 32 | i),
 * which is a sound pseudorandom function and is not the specified one,
 * so nothing it produced could verify against another implementation.
 */
void wots_sk(const unsigned char *sk_seed, const unsigned char *pub_seed,
             uint32_t ots_index, int i, unsigned char out[32]) {
    Adrs adrs;
    adrs.set_type(0);
    adrs.set_ots(ots_index);
    adrs.set_chain(static_cast<uint32_t>(i));
    adrs.set_hash(0);
    adrs.set_key_and_mask(0);
    unsigned char ab[32];
    adrs.bytes(ab);
    fn_PRFkeygen(sk_seed, pub_seed, ab, out);
}

void wots_pk(const unsigned char *sk_seed, const unsigned char *pub_seed,
             uint32_t ots_index, std::vector<unsigned char> &pk) {
    pk.resize(static_cast<size_t>(kLen) * kN);
    Adrs adrs;
    adrs.set_type(0);
    adrs.set_ots(ots_index);
    for (int i = 0; i < kLen; ++i) {
        unsigned char sk[32];
        wots_sk(sk_seed, pub_seed, ots_index, i, sk);
        adrs.set_chain(static_cast<uint32_t>(i));
        chain(sk, 0, kW - 1, pub_seed, adrs,
              pk.data() + static_cast<size_t>(i) * kN);
    }
}

/* L-tree: compress the 67 WOTS+ public chains into one Merkle leaf. */
void ltree(std::vector<unsigned char> pk, const unsigned char *pub_seed,
           uint32_t ots_index, unsigned char out[32]) {
    Adrs adrs;
    adrs.set_type(1);
    adrs.set_ltree(ots_index);
    size_t len = static_cast<size_t>(kLen);
    uint32_t height = 0;
    while (len > 1) {
        adrs.set_tree_height(height);
        const size_t pairs = len / 2;
        for (size_t i = 0; i < pairs; ++i) {
            adrs.set_tree_index(static_cast<uint32_t>(i));
            unsigned char node[32];
            rand_hash(pk.data() + (2 * i) * kN, pk.data() + (2 * i + 1) * kN,
                      pub_seed, adrs, node);
            std::memcpy(pk.data() + i * kN, node, kN);
        }
        if (len % 2 == 1) {
            std::memcpy(pk.data() + pairs * kN,
                        pk.data() + (len - 1) * kN, kN);
            len = pairs + 1;
        } else {
            len = pairs;
        }
        ++height;
    }
    std::memcpy(out, pk.data(), kN);
}

void compute_leaf(const unsigned char *sk_seed, const unsigned char *pub_seed,
                  uint32_t idx, unsigned char out[32]) {
    std::vector<unsigned char> pk;
    wots_pk(sk_seed, pub_seed, idx, pk);
    ltree(pk, pub_seed, idx, out);
}

/* Full Merkle tree of 2^h leaves; returns the root and, when `auth` is
 * non-null, the authentication path for leaf `leaf_idx`. */
void tree_root(const unsigned char *sk_seed, const unsigned char *pub_seed,
               int h, uint32_t leaf_idx, unsigned char root[32],
               std::vector<unsigned char> *auth) {
    const size_t nleaves = static_cast<size_t>(1) << h;
    std::vector<unsigned char> lvl(nleaves * kN);
    for (size_t i = 0; i < nleaves; ++i) {
        compute_leaf(sk_seed, pub_seed, static_cast<uint32_t>(i),
                     lvl.data() + i * kN);
    }
    if (auth != nullptr) auth->clear();
    Adrs adrs;
    adrs.set_type(2);
    size_t len = nleaves;
    uint32_t height = 0;
    size_t pos = static_cast<size_t>(leaf_idx);
    while (len > 1) {
        if (auth != nullptr) {
            const size_t sib = (pos % 2 == 0) ? pos + 1 : pos - 1;
            auth->insert(auth->end(), lvl.data() + sib * kN,
                         lvl.data() + (sib + 1) * kN);
        }
        adrs.set_tree_height(height);
        for (size_t i = 0; i < len / 2; ++i) {
            adrs.set_tree_index(static_cast<uint32_t>(i));
            unsigned char node[32];
            rand_hash(lvl.data() + (2 * i) * kN, lvl.data() + (2 * i + 1) * kN,
                      pub_seed, adrs, node);
            std::memcpy(lvl.data() + i * kN, node, kN);
        }
        len /= 2;
        pos /= 2;
        ++height;
    }
    std::memcpy(root, lvl.data(), kN);
}

}  // namespace

extern "C" {

int rmbl_xmss_len(void) { return kLen; }

SEXP C_rmbl_xmss_keygen(SEXP sk_seed_hex, SEXP pub_seed_hex, SEXP height) {
    std::vector<unsigned char> sks, pubs;
    if (!unhexlify(CHAR(STRING_ELT(sk_seed_hex, 0)), sks) || sks.size() != kN) {
        Rf_error("`sk_seed` must be 64 hex characters (32 bytes)");
    }
    if (!unhexlify(CHAR(STRING_ELT(pub_seed_hex, 0)), pubs) ||
        pubs.size() != kN) {
        Rf_error("`pub_seed` must be 64 hex characters (32 bytes)");
    }
    const int h = Rf_asInteger(height);
    if (h < 1 || h > 16) Rf_error("`height` must be between 1 and 16");

    unsigned char root[32];
    tree_root(sks.data(), pubs.data(), h, 0, root, nullptr);
    std::string rh;
    hexlify(root, kN, rh);
    return Rf_mkString(rh.c_str());
}

SEXP C_rmbl_xmss_sign(SEXP sk_seed_hex, SEXP sk_prf_hex, SEXP pub_seed_hex,
                      SEXP height, SEXP index, SEXP msg) {
    std::vector<unsigned char> sks, prfs, pubs;
    if (!unhexlify(CHAR(STRING_ELT(sk_seed_hex, 0)), sks) || sks.size() != kN) {
        Rf_error("`sk_seed` must be 64 hex characters (32 bytes)");
    }
    if (!unhexlify(CHAR(STRING_ELT(sk_prf_hex, 0)), prfs) ||
        prfs.size() != kN) {
        Rf_error("`sk_prf` must be 64 hex characters (32 bytes)");
    }
    if (!unhexlify(CHAR(STRING_ELT(pub_seed_hex, 0)), pubs) ||
        pubs.size() != kN) {
        Rf_error("`pub_seed` must be 64 hex characters (32 bytes)");
    }
    const int h = Rf_asInteger(height);
    if (h < 1 || h > 16) Rf_error("`height` must be between 1 and 16");
    const uint32_t idx = static_cast<uint32_t>(Rf_asInteger(index));
    if (idx >= (static_cast<uint32_t>(1) << h)) {
        Rf_error("`index` exhausted: a height-%d key signs 2^%d messages", h, h);
    }

    std::vector<unsigned char> mb;
    if (TYPEOF(msg) == RAWSXP) {
        mb.assign(RAW(msg), RAW(msg) + XLENGTH(msg));
    } else {
        const char *s = CHAR(STRING_ELT(msg, 0));
        mb.assign(s, s + std::strlen(s));
    }

    /* Bind the digest to the leaf index and the root, so a signature
     * cannot be replayed at a different index or under another key. */
    unsigned char root[32];
    std::vector<unsigned char> auth;
    tree_root(sks.data(), pubs.data(), h, idx, root, &auth);

    /* R = PRF(SK_PRF, toByte(idx, 32)), then the specified binding */
    unsigned char ridx[32];
    to_byte32(idx, ridx);
    unsigned char rnd[32];
    fn_PRF(prfs.data(), ridx, rnd);
    unsigned char dig[32];
    fn_Hmsg_bound(rnd, root, idx, mb.data(), mb.size(), dig);

    int digits[kLen];
    wots_digits(dig, digits);

    Adrs adrs;
    adrs.set_type(0);
    adrs.set_ots(idx);
    std::vector<unsigned char> sig(static_cast<size_t>(kLen) * kN);
    for (int i = 0; i < kLen; ++i) {
        unsigned char sk[32];
        wots_sk(sks.data(), pubs.data(), idx, i, sk);
        adrs.set_chain(static_cast<uint32_t>(i));
        chain(sk, 0, digits[i], pubs.data(), adrs,
              sig.data() + static_cast<size_t>(i) * kN);
    }

    std::string sigh, authh, rooth, rh, serial;
    hexlify(sig.data(), sig.size(), sigh);
    hexlify(auth.data(), auth.size(), authh);
    hexlify(root, kN, rooth);
    hexlify(rnd, kN, rh);

    /* The RFC 8391 wire format, so a signature can be handed to another
     * implementation as bytes: idx (4, big endian) || R || WOTS sig ||
     * auth path. For XMSS-SHA2_10_256 that is 4 + 32 + 2144 + 320 =
     * 2500 bytes. */
    std::vector<unsigned char> wire;
    wire.reserve(4 + kN + sig.size() + auth.size());
    for (int b = 3; b >= 0; --b) {
        wire.push_back(static_cast<unsigned char>((idx >> (8 * b)) & 0xff));
    }
    wire.insert(wire.end(), rnd, rnd + kN);
    wire.insert(wire.end(), sig.begin(), sig.end());
    wire.insert(wire.end(), auth.begin(), auth.end());
    hexlify(wire.data(), wire.size(), serial);

    SEXP out = PROTECT(Rf_allocVector(VECSXP, 6));
    SET_VECTOR_ELT(out, 0, Rf_mkString(sigh.c_str()));
    SET_VECTOR_ELT(out, 1, Rf_mkString(authh.c_str()));
    SET_VECTOR_ELT(out, 2, Rf_ScalarInteger(static_cast<int>(idx)));
    SET_VECTOR_ELT(out, 3, Rf_mkString(rooth.c_str()));
    SET_VECTOR_ELT(out, 4, Rf_mkString(rh.c_str()));
    SET_VECTOR_ELT(out, 5, Rf_mkString(serial.c_str()));
    SEXP nm = PROTECT(Rf_allocVector(STRSXP, 6));
    SET_STRING_ELT(nm, 0, Rf_mkChar("wots"));
    SET_STRING_ELT(nm, 1, Rf_mkChar("auth"));
    SET_STRING_ELT(nm, 2, Rf_mkChar("index"));
    SET_STRING_ELT(nm, 3, Rf_mkChar("root"));
    SET_STRING_ELT(nm, 4, Rf_mkChar("randomizer"));
    SET_STRING_ELT(nm, 5, Rf_mkChar("wire"));
    Rf_setAttrib(out, R_NamesSymbol, nm);
    UNPROTECT(2);
    return out;
}

SEXP C_rmbl_xmss_verify(SEXP pub_seed_hex, SEXP root_hex, SEXP height,
                        SEXP index, SEXP msg, SEXP sig_hex, SEXP auth_hex,
                        SEXP r_hex) {
    std::vector<unsigned char> pubs, root, sig, auth;
    if (!unhexlify(CHAR(STRING_ELT(pub_seed_hex, 0)), pubs) ||
        pubs.size() != kN) {
        return Rf_ScalarLogical(FALSE);
    }
    if (!unhexlify(CHAR(STRING_ELT(root_hex, 0)), root) || root.size() != kN) {
        return Rf_ScalarLogical(FALSE);
    }
    if (!unhexlify(CHAR(STRING_ELT(sig_hex, 0)), sig) ||
        sig.size() != static_cast<size_t>(kLen) * kN) {
        return Rf_ScalarLogical(FALSE);
    }
    if (!unhexlify(CHAR(STRING_ELT(auth_hex, 0)), auth)) {
        return Rf_ScalarLogical(FALSE);
    }
    const int h = Rf_asInteger(height);
    if (h < 1 || h > 16) return Rf_ScalarLogical(FALSE);
    if (auth.size() != static_cast<size_t>(h) * kN) {
        return Rf_ScalarLogical(FALSE);
    }
    const uint32_t idx = static_cast<uint32_t>(Rf_asInteger(index));
    if (idx >= (static_cast<uint32_t>(1) << h)) {
        return Rf_ScalarLogical(FALSE);
    }

    std::vector<unsigned char> mb;
    if (TYPEOF(msg) == RAWSXP) {
        mb.assign(RAW(msg), RAW(msg) + XLENGTH(msg));
    } else {
        const char *s = CHAR(STRING_ELT(msg, 0));
        mb.assign(s, s + std::strlen(s));
    }

    /* The verifier has no SK_PRF, so R travels with the signature. */
    std::vector<unsigned char> rnd;
    if (!unhexlify(CHAR(STRING_ELT(r_hex, 0)), rnd) || rnd.size() != kN) {
        Rf_error("`randomizer` must be 64 hex characters (32 bytes)");
    }
    unsigned char dig[32];
    fn_Hmsg_bound(rnd.data(), root.data(), idx, mb.data(), mb.size(), dig);

    int digits[kLen];
    wots_digits(dig, digits);

    /* Walk each chain the REMAINING way to its end: a valid signature
     * sits exactly digits[i] steps along, so w-1-digits[i] more steps
     * must land on the public chain value. */
    std::vector<unsigned char> pk(static_cast<size_t>(kLen) * kN);
    Adrs adrs;
    adrs.set_type(0);
    adrs.set_ots(idx);
    for (int i = 0; i < kLen; ++i) {
        adrs.set_chain(static_cast<uint32_t>(i));
        chain(sig.data() + static_cast<size_t>(i) * kN, digits[i],
              kW - 1 - digits[i], pubs.data(), adrs,
              pk.data() + static_cast<size_t>(i) * kN);
    }

    unsigned char node[32];
    ltree(pk, pubs.data(), idx, node);

    Adrs tadrs;
    tadrs.set_type(2);
    size_t pos = static_cast<size_t>(idx);
    for (int k = 0; k < h; ++k) {
        tadrs.set_tree_height(static_cast<uint32_t>(k));
        tadrs.set_tree_index(static_cast<uint32_t>(pos / 2));
        unsigned char up[32];
        if (pos % 2 == 0) {
            rand_hash(node, auth.data() + static_cast<size_t>(k) * kN,
                      pubs.data(), tadrs, up);
        } else {
            rand_hash(auth.data() + static_cast<size_t>(k) * kN, node,
                      pubs.data(), tadrs, up);
        }
        std::memcpy(node, up, kN);
        pos /= 2;
    }

    unsigned char diff = 0;
    for (size_t i = 0; i < kN; ++i) {
        diff = static_cast<unsigned char>(diff | (node[i] ^ root[i]));
    }
    return Rf_ScalarLogical(diff == 0 ? TRUE : FALSE);
}

/* ------------------------------------------------------------------ */
/* Optional standardised lattice / hash signatures via liboqs.         */
/* Compiled in only when ../configure found the library, so the        */
/* package still builds where liboqs is absent (CRAN included).        */
/* ------------------------------------------------------------------ */

/* The standardised schemes bricklayer exposes when liboqs is present.
 * Deliberately a short list: ML-DSA-65 is the FIPS 204 middle security
 * level and the sensible default, ML-DSA-87 for a longer horizon, and
 * SLH-DSA as a hash-based alternative for anyone who would rather not
 * rest on a lattice assumption at all. */
#ifdef HAVE_LIBOQS
/* Inside the guard: without liboqs nothing reads this table, and an
 * unused-variable warning on every platform is noise that hides a real
 * one. */
static const char *kOqsSchemes[] = {
    "ML-DSA-44", "ML-DSA-65", "ML-DSA-87", "SPHINCS+-SHA2-128s-simple"
};
static const int kNumOqsSchemes = 4;
#endif

SEXP C_rmbl_pqc_backends(void) {
    SEXP out;
#ifdef HAVE_LIBOQS
    /* Report only the schemes this build of liboqs actually enabled --
     * the library is configurable and a scheme can be compiled out. */
    int n = 1;
    for (int i = 0; i < kNumOqsSchemes; ++i) {
        if (OQS_SIG_alg_is_enabled(kOqsSchemes[i])) ++n;
    }
    out = PROTECT(Rf_allocVector(STRSXP, n));
    SET_STRING_ELT(out, 0, Rf_mkChar("xmss-sha256"));
    int k = 1;
    for (int i = 0; i < kNumOqsSchemes; ++i) {
        if (OQS_SIG_alg_is_enabled(kOqsSchemes[i])) {
            SET_STRING_ELT(out, k++, Rf_mkChar(kOqsSchemes[i]));
        }
    }
    UNPROTECT(1);
    return out;
#else
    out = PROTECT(Rf_allocVector(STRSXP, 1));
    SET_STRING_ELT(out, 0, Rf_mkChar("xmss-sha256"));
    UNPROTECT(1);
    return out;
#endif
}

/* ------------------------------------------------------------------ */
/* liboqs-backed keygen / sign / verify.                               */
/*                                                                     */
/* These delegate entirely to liboqs. bricklayer does not implement any */
/* lattice arithmetic: the point of routing through the library is that */
/* its ML-DSA is the tested, maintained one. Without liboqs each entry  */
/* point returns NULL or FALSE and the R layer reports the scheme as    */
/* unavailable -- never a silent fallback to a weaker signature.        */
/* ------------------------------------------------------------------ */

#ifdef HAVE_LIBOQS

SEXP C_rmbl_oqs_keygen(SEXP alg) {
    const char *name = CHAR(STRING_ELT(alg, 0));
    if (!OQS_SIG_alg_is_enabled(name)) return R_NilValue;
    OQS_SIG *sig = OQS_SIG_new(name);
    if (sig == NULL) return R_NilValue;

    std::vector<unsigned char> pk(sig->length_public_key);
    std::vector<unsigned char> sk(sig->length_secret_key);
    if (OQS_SIG_keypair(sig, pk.data(), sk.data()) != OQS_SUCCESS) {
        OQS_SIG_free(sig);
        return R_NilValue;
    }
    std::string pkh, skh;
    hexlify(pk.data(), pk.size(), pkh);
    hexlify(sk.data(), sk.size(), skh);
    OQS_SIG_free(sig);

    SEXP out = PROTECT(Rf_allocVector(VECSXP, 3));
    SET_VECTOR_ELT(out, 0, Rf_mkString(pkh.c_str()));
    SET_VECTOR_ELT(out, 1, Rf_mkString(skh.c_str()));
    SET_VECTOR_ELT(out, 2, Rf_mkString(name));
    SEXP nm = PROTECT(Rf_allocVector(STRSXP, 3));
    SET_STRING_ELT(nm, 0, Rf_mkChar("public"));
    SET_STRING_ELT(nm, 1, Rf_mkChar("secret"));
    SET_STRING_ELT(nm, 2, Rf_mkChar("scheme"));
    Rf_setAttrib(out, R_NamesSymbol, nm);
    UNPROTECT(2);
    return out;
}

SEXP C_rmbl_oqs_sign(SEXP alg, SEXP sk_hex, SEXP msg) {
    const char *name = CHAR(STRING_ELT(alg, 0));
    if (!OQS_SIG_alg_is_enabled(name)) return R_NilValue;
    OQS_SIG *sig = OQS_SIG_new(name);
    if (sig == NULL) return R_NilValue;

    std::vector<unsigned char> sk;
    if (!unhexlify(CHAR(STRING_ELT(sk_hex, 0)), sk) ||
        sk.size() != sig->length_secret_key) {
        OQS_SIG_free(sig);
        Rf_error("the secret key is not a %s key of the expected length",
                 name);
    }
    std::vector<unsigned char> mb;
    if (TYPEOF(msg) == RAWSXP) {
        mb.assign(RAW(msg), RAW(msg) + XLENGTH(msg));
    } else {
        const char *m = CHAR(STRING_ELT(msg, 0));
        mb.assign(m, m + std::strlen(m));
    }

    std::vector<unsigned char> out(sig->length_signature);
    size_t siglen = 0;
    const OQS_STATUS rc = OQS_SIG_sign(sig, out.data(), &siglen, mb.data(),
                                       mb.size(), sk.data());
    if (rc != OQS_SUCCESS) {
        OQS_SIG_free(sig);
        return R_NilValue;
    }
    std::string hex;
    hexlify(out.data(), siglen, hex);
    OQS_SIG_free(sig);
    return Rf_mkString(hex.c_str());
}

SEXP C_rmbl_oqs_verify(SEXP alg, SEXP pk_hex, SEXP msg, SEXP sig_hex) {
    const char *name = CHAR(STRING_ELT(alg, 0));
    if (!OQS_SIG_alg_is_enabled(name)) return Rf_ScalarLogical(FALSE);
    OQS_SIG *sig = OQS_SIG_new(name);
    if (sig == NULL) return Rf_ScalarLogical(FALSE);

    std::vector<unsigned char> pk, sg;
    /* A malformed key or signature is "not verified", not an error: a
     * verifier must treat unparseable input as failure. */
    if (!unhexlify(CHAR(STRING_ELT(pk_hex, 0)), pk) ||
        pk.size() != sig->length_public_key ||
        !unhexlify(CHAR(STRING_ELT(sig_hex, 0)), sg) ||
        sg.size() == 0 || sg.size() > sig->length_signature) {
        OQS_SIG_free(sig);
        return Rf_ScalarLogical(FALSE);
    }
    std::vector<unsigned char> mb;
    if (TYPEOF(msg) == RAWSXP) {
        mb.assign(RAW(msg), RAW(msg) + XLENGTH(msg));
    } else {
        const char *m = CHAR(STRING_ELT(msg, 0));
        mb.assign(m, m + std::strlen(m));
    }
    const OQS_STATUS rc = OQS_SIG_verify(sig, mb.data(), mb.size(),
                                         sg.data(), sg.size(), pk.data());
    OQS_SIG_free(sig);
    return Rf_ScalarLogical(rc == OQS_SUCCESS ? TRUE : FALSE);
}

#else

SEXP C_rmbl_oqs_keygen(SEXP alg) { (void) alg; return R_NilValue; }
SEXP C_rmbl_oqs_sign(SEXP alg, SEXP sk_hex, SEXP msg) {
    (void) alg; (void) sk_hex; (void) msg;
    return R_NilValue;
}
SEXP C_rmbl_oqs_verify(SEXP alg, SEXP pk_hex, SEXP msg, SEXP sig_hex) {
    (void) alg; (void) pk_hex; (void) msg; (void) sig_hex;
    return Rf_ScalarLogical(FALSE);
}

#endif  /* HAVE_LIBOQS */

}  // extern "C"
