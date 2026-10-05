/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * AES-256 (FIPS 197) and the CTR_DRBG of NIST SP 800-90A Rev. 1, section 10.2.1, with AES-256
 * and no derivation function: the generator of the NIST post-quantum known-answer tests (their
 * rng.c is this DRBG without reseeding). seedlen = 48 bytes: a 32-byte key and a 16-byte V.
 *
 * The portable AES computes the S-box arithmetically (the inverse in GF(2^8) as x^254, then the
 * affine map), so no secret byte indexes a table and the cipher runs in constant time; on x86-64
 * with AES-NI the rounds use the AESENC instructions (the key schedule stays portable).
 */
#ifndef RMBL_DRBG_CORE_H
#define RMBL_DRBG_CORE_H

#include <cstddef>
#include <cstdint>
#include <cstring>

#if defined(__x86_64__) && (defined(__GNUC__) || defined(__clang__))
#include <immintrin.h>
#define RMBL_AES_X86_NI 1
#endif

namespace rmbl_drbg {

inline void wipe(void *p, size_t n) {
    volatile uint8_t *v = static_cast<volatile uint8_t *>(p);
    while (n--) *v++ = 0;
}

/* ------------------------------------------------------------ GF(2^8), constant time */

inline uint8_t gmul(uint8_t a, uint8_t b) {
    uint8_t p = 0;
    for (int i = 0; i < 8; ++i) {
        p ^= static_cast<uint8_t>(a & (0u - (b & 1u)));
        uint8_t hi = static_cast<uint8_t>(0u - (a >> 7));
        a = static_cast<uint8_t>((a << 1) ^ (hi & 0x1b));
        b >>= 1;
    }
    return p;
}

inline uint8_t rotl8(uint8_t x, int k) { return static_cast<uint8_t>((x << k) | (x >> (8 - k))); }

/* S(x) = A(x^254) + 0x63; x^254 = x^-1 for x != 0 and 0 for 0, as the S-box wants */
inline uint8_t sbox(uint8_t x) {
    uint8_t x2 = gmul(x, x), x3 = gmul(x2, x), x6 = gmul(x3, x3), x12 = gmul(x6, x6);
    uint8_t x15 = gmul(x12, x3), x30 = gmul(x15, x15), x60 = gmul(x30, x30), x120 = gmul(x60, x60);
    uint8_t x126 = gmul(x120, x6), x252 = gmul(x126, x126), inv = gmul(x252, x2);
    return static_cast<uint8_t>(inv ^ rotl8(inv, 1) ^ rotl8(inv, 2) ^ rotl8(inv, 3) ^ rotl8(inv, 4) ^ 0x63);
}

/* ------------------------------------------------------------ AES-256 */

struct Aes256 {
    uint8_t rk[240]; /* 15 round keys */

    void init(const uint8_t key[32]) {
        std::memcpy(rk, key, 32);
        uint8_t rcon = 1;
        for (int i = 8; i < 60; ++i) {
            uint8_t t[4];
            std::memcpy(t, rk + 4 * (i - 1), 4);
            if (i % 8 == 0) {
                uint8_t u = t[0];
                t[0] = static_cast<uint8_t>(sbox(t[1]) ^ rcon);
                t[1] = sbox(t[2]);
                t[2] = sbox(t[3]);
                t[3] = sbox(u);
                rcon = gmul(rcon, 2);
            } else if (i % 8 == 4) {
                for (auto &b : t) b = sbox(b);
            }
            for (int j = 0; j < 4; ++j) rk[4 * i + j] = static_cast<uint8_t>(rk[4 * (i - 8) + j] ^ t[j]);
        }
    }

    void encrypt_portable(uint8_t out[16], const uint8_t in[16]) const {
        uint8_t s[16], t[16];
        for (int i = 0; i < 16; ++i) s[i] = static_cast<uint8_t>(in[i] ^ rk[i]);
        for (int r = 1; r <= 14; ++r) {
            for (int i = 0; i < 16; ++i) s[i] = sbox(s[i]);
            /* ShiftRows: row j of column c moves to column c - j */
            for (int c = 0; c < 4; ++c)
                for (int j = 0; j < 4; ++j) t[4 * c + j] = s[4 * ((c + j) % 4) + j];
            if (r < 14) {
                for (int c = 0; c < 4; ++c) {
                    uint8_t *a = t + 4 * c;
                    uint8_t a0 = a[0], a1 = a[1], a2 = a[2], a3 = a[3];
                    uint8_t x = static_cast<uint8_t>(a0 ^ a1 ^ a2 ^ a3);
                    a[0] = static_cast<uint8_t>(a0 ^ x ^ gmul(static_cast<uint8_t>(a0 ^ a1), 2));
                    a[1] = static_cast<uint8_t>(a1 ^ x ^ gmul(static_cast<uint8_t>(a1 ^ a2), 2));
                    a[2] = static_cast<uint8_t>(a2 ^ x ^ gmul(static_cast<uint8_t>(a2 ^ a3), 2));
                    a[3] = static_cast<uint8_t>(a3 ^ x ^ gmul(static_cast<uint8_t>(a3 ^ a0), 2));
                }
            }
            for (int i = 0; i < 16; ++i) s[i] = static_cast<uint8_t>(t[i] ^ rk[16 * r + i]);
        }
        std::memcpy(out, s, 16);
        wipe(s, sizeof s);
        wipe(t, sizeof t);
    }

#if defined(RMBL_AES_X86_NI)
    __attribute__((target("aes,sse2"))) void encrypt_ni(uint8_t out[16], const uint8_t in[16]) const {
        __m128i b = _mm_xor_si128(_mm_loadu_si128(reinterpret_cast<const __m128i *>(in)),
                                  _mm_loadu_si128(reinterpret_cast<const __m128i *>(rk)));
        for (int r = 1; r < 14; ++r) b = _mm_aesenc_si128(b, _mm_loadu_si128(reinterpret_cast<const __m128i *>(rk + 16 * r)));
        b = _mm_aesenclast_si128(b, _mm_loadu_si128(reinterpret_cast<const __m128i *>(rk + 224)));
        _mm_storeu_si128(reinterpret_cast<__m128i *>(out), b);
    }
#endif

    void encrypt(uint8_t out[16], const uint8_t in[16]) const;
    ~Aes256() { wipe(rk, sizeof rk); }
};

/* set to 1 to force the portable cipher (the tests run the vectors through both) */
inline int &force_portable() {
    static int f = 0;
    return f;
}

inline bool have_aesni() {
#if defined(RMBL_AES_X86_NI)
    static const int ok = __builtin_cpu_supports("aes") ? 1 : 0;
    return ok != 0;
#else
    return false;
#endif
}

inline void Aes256::encrypt(uint8_t out[16], const uint8_t in[16]) const {
#if defined(RMBL_AES_X86_NI)
    if (!force_portable() && have_aesni()) {
        encrypt_ni(out, in);
        return;
    }
#endif
    encrypt_portable(out, in);
}

/* ------------------------------------------------------------ CTR_DRBG (AES-256, no df) */

constexpr size_t SEEDLEN = 48;

struct CtrDrbg {
    uint8_t key[32];
    uint8_t v[16];

    static void increment(uint8_t v[16]) {
        /* V = (V + 1) mod 2^128, big-endian, without a data-dependent branch */
        unsigned carry = 1;
        for (int j = 15; j >= 0; --j) {
            unsigned s = v[j] + carry;
            v[j] = static_cast<uint8_t>(s);
            carry = s >> 8;
        }
    }

    /* CTR_DRBG_Update(provided_data, Key, V), section 10.2.1.2 */
    void update(const uint8_t provided[SEEDLEN]) {
        uint8_t temp[SEEDLEN];
        Aes256 aes;
        aes.init(key);
        for (size_t i = 0; i < SEEDLEN; i += 16) {
            increment(v);
            aes.encrypt(temp + i, v);
        }
        for (size_t i = 0; i < SEEDLEN; ++i) temp[i] ^= provided[i];
        std::memcpy(key, temp, 32);
        std::memcpy(v, temp + 32, 16);
        wipe(temp, sizeof temp);
    }

    /* 10.2.1.3.1: seed_material = entropy_input XOR personalization (zero-padded) */
    void instantiate(const uint8_t entropy[SEEDLEN], const uint8_t *pers, size_t perslen) {
        uint8_t seed[SEEDLEN];
        std::memcpy(seed, entropy, SEEDLEN);
        for (size_t i = 0; i < perslen; ++i) seed[i] ^= pers[i];
        std::memset(key, 0, sizeof key);
        std::memset(v, 0, sizeof v);
        update(seed);
        wipe(seed, sizeof seed);
    }

    /* 10.2.1.4.1: seed_material = entropy_input XOR additional_input (zero-padded) */
    void reseed(const uint8_t entropy[SEEDLEN], const uint8_t *add, size_t addlen) {
        uint8_t seed[SEEDLEN];
        std::memcpy(seed, entropy, SEEDLEN);
        for (size_t i = 0; i < addlen; ++i) seed[i] ^= add[i];
        update(seed);
        wipe(seed, sizeof seed);
    }

    /* 10.2.1.5.1: the additional input (zero-padded, all zeros when absent) updates the state
     * before and after the output blocks; a partial last block keeps its leftmost bytes */
    void generate(uint8_t *out, size_t n, const uint8_t *add, size_t addlen) {
        uint8_t a[SEEDLEN] = {0};
        for (size_t i = 0; i < addlen; ++i) a[i] = add[i];
        if (addlen) update(a);
        Aes256 aes;
        aes.init(key);
        uint8_t block[16];
        while (n) {
            increment(v);
            aes.encrypt(block, v);
            size_t k = n < 16 ? n : 16;
            std::memcpy(out, block, k);
            out += k;
            n -= k;
        }
        update(a);
        wipe(block, sizeof block);
        wipe(a, sizeof a);
    }

    ~CtrDrbg() {
        wipe(key, sizeof key);
        wipe(v, sizeof v);
    }
};

} // namespace rmbl_drbg

#endif
