/* Constant-time building blocks shared by every primitive in src/.
 *
 *   wipe()      a zeroing the optimiser cannot drop
 *   Guard       wipes a buffer when the scope ends, on every return path
 *   hexlify()   bytes -> lowercase hex with arithmetic, not a table: a
 *               table lookup indexed by a secret nibble is a memory
 *               address that depends on the secret
 *   unhexlify() hex -> bytes the same way; the only decision -- was the
 *               whole string hex -- is taken once, after the last byte
 *
 * inst/ctcheck runs the primitives under valgrind memcheck with their
 * secrets marked undefined; these helpers are what let that run come
 * back clean. RMBL_CT_DECLASSIFY is the checker's hook for a value the
 * specification publishes anyway; it is a no-op in the package.
 */
#ifndef RMBL_CT_H
#define RMBL_CT_H

#include <cstddef>
#include <cstdint>

#ifndef RMBL_CT_DECLASSIFY
#define RMBL_CT_DECLASSIFY(ptr, len) ((void)0)
#endif

namespace rmbl_ct {

inline void wipe(void *p, size_t n) {
    volatile unsigned char *q = static_cast<volatile unsigned char *>(p);
    while (n--) *q++ = 0;
}

struct Guard {
    void *p;
    size_t n;
    Guard(void *p_, size_t n_) : p(p_), n(n_) {}
    ~Guard() { wipe(p, n); }
    Guard(const Guard &) = delete;
    Guard &operator=(const Guard &) = delete;
};

/* '0' + v for v < 10, 'a' + v - 10 otherwise, with no branch and no table */
inline char hex_digit(unsigned v) {
    v &= 15u;
    const unsigned mask = 0u - ((v + 6u) >> 4); /* all ones exactly when v >= 10 */
    return static_cast<char>('0' + v + (mask & static_cast<unsigned>('a' - '0' - 10)));
}

inline void hexlify(const unsigned char *b, size_t n, char *out) {
    for (size_t i = 0; i < n; ++i) {
        out[i * 2] = hex_digit(static_cast<unsigned>(b[i]) >> 4);
        out[i * 2 + 1] = hex_digit(static_cast<unsigned>(b[i]));
    }
}

/* one hex character's value; accumulates a non-zero `bad` for anything else */
inline unsigned unhex_digit(char ch, unsigned &bad) {
    const unsigned c = static_cast<unsigned char>(ch);
    const unsigned d = c - '0';            /* 0..9 when a digit */
    const unsigned l = (c | 0x20u) - 'a';  /* 0..5 when a-f or A-F */
    const unsigned is_d = 0u - static_cast<unsigned>(d < 10u);
    const unsigned is_l = 0u - static_cast<unsigned>(l < 6u);
    bad |= ~(is_d | is_l);
    return (is_d & d) | (is_l & (l + 10u));
}

/* `len` must be even; returns 0, or -1 when any character was not hex.
 * Whether a string was well-formed is not a secret, so a caller may
 * RMBL_CT_DECLASSIFY the result before branching on it. */
inline int unhexlify(const char *s, size_t len, unsigned char *out) {
    unsigned bad = 0;
    for (size_t i = 0; i < len / 2; ++i) {
        const unsigned hi = unhex_digit(s[i * 2], bad);
        const unsigned lo = unhex_digit(s[i * 2 + 1], bad);
        out[i] = static_cast<unsigned char>((hi << 4) | lo);
    }
    int rc = bad ? -1 : 0;
    return rc;
}

}  // namespace rmbl_ct

#endif
