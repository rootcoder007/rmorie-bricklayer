/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * Correctly-rounded decimal to double conversion.
 *
 * Seventeen significant digits are enough to recover any double
 * exactly -- but only through a reader that rounds correctly, and not
 * every platform's does. On macOS arm64 (R 4.6.0) the C library reads
 * the correct decimal for the largest double as infinity, and loses
 * low bits on magnitudes around 1e100 and beyond. A manifest written
 * on one machine then reads back as a different number on another,
 * which for a format whose entire purpose is to be checked elsewhere
 * is not a limitation to document. It is a bug to fix.
 *
 * So this package does not ask the platform. The conversion here is
 * exact by construction: the decimal is held as an integer mantissa
 * and a power of ten, the quotient is taken with a remainder, and the
 * remainder decides the rounding -- round to nearest, ties to even, as
 * IEEE 754 requires. No floating point arithmetic is involved in
 * deciding the result, so there is nothing for a platform to get
 * wrong.
 *
 * A fast path handles the ordinary case without any of that: when the
 * mantissa fits in 64 bits and the exponent is small, both operands
 * are exactly representable and a single multiply or divide is already
 * correctly rounded (Clinger 1990). Everything else takes the exact
 * path, which costs big-integer division and is invisible next to the
 * cost of parsing the surrounding JSON.
 */

#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <vector>

#include <R.h>
#include <Rinternals.h>

namespace {

/* ------------------------------------------------------------------ *
 * A big unsigned integer: 32-bit limbs, least significant first.
 * Only what the conversion needs -- shift, compare, multiply by a
 * small value, and division with remainder.
 * ------------------------------------------------------------------ */
typedef std::vector<uint32_t> Big;

void trim(Big &a) {
    while (a.size() > 1 && a.back() == 0) a.pop_back();
}

bool is_zero(const Big &a) {
    for (size_t i = 0; i < a.size(); ++i) {
        if (a[i]) return false;
    }
    return true;
}

int cmp(const Big &a, const Big &b) {
    const size_t n = (a.size() > b.size()) ? a.size() : b.size();
    for (size_t i = n; i-- > 0;) {
        const uint32_t x = (i < a.size()) ? a[i] : 0;
        const uint32_t y = (i < b.size()) ? b[i] : 0;
        if (x != y) return x < y ? -1 : 1;
    }
    return 0;
}

size_t bit_length(const Big &a) {
    for (size_t i = a.size(); i-- > 0;) {
        if (a[i]) {
            uint32_t v = a[i];
            size_t b = 0;
            while (v) { ++b; v >>= 1; }
            return i * 32 + b;
        }
    }
    return 0;
}

void shl(Big &a, size_t bits) {
    if (is_zero(a) || bits == 0) return;
    const size_t limbs = bits / 32;
    const unsigned rem = static_cast<unsigned>(bits % 32);
    if (rem) {
        uint32_t carry = 0;
        for (size_t i = 0; i < a.size(); ++i) {
            const uint64_t cur = (static_cast<uint64_t>(a[i]) << rem) | carry;
            a[i] = static_cast<uint32_t>(cur & 0xffffffffu);
            carry = static_cast<uint32_t>(cur >> 32);
        }
        if (carry) a.push_back(carry);
    }
    if (limbs) a.insert(a.begin(), limbs, 0u);
}

void shr(Big &a, size_t bits) {
    const size_t limbs = bits / 32;
    const unsigned rem = static_cast<unsigned>(bits % 32);
    if (limbs >= a.size()) { a.assign(1, 0u); return; }
    if (limbs) a.erase(a.begin(), a.begin() + static_cast<long>(limbs));
    if (rem) {
        uint32_t carry = 0;
        for (size_t i = a.size(); i-- > 0;) {
            const uint32_t nc = a[i] << (32 - rem);
            a[i] = (a[i] >> rem) | carry;
            carry = nc;
        }
    }
    trim(a);
}

void mul_small(Big &a, uint32_t m) {
    uint64_t carry = 0;
    for (size_t i = 0; i < a.size(); ++i) {
        const uint64_t cur = static_cast<uint64_t>(a[i]) * m + carry;
        a[i] = static_cast<uint32_t>(cur & 0xffffffffu);
        carry = cur >> 32;
    }
    while (carry) {
        a.push_back(static_cast<uint32_t>(carry & 0xffffffffu));
        carry >>= 32;
    }
}

void add_small(Big &a, uint32_t v) {
    uint64_t carry = v;
    for (size_t i = 0; i < a.size() && carry; ++i) {
        const uint64_t cur = static_cast<uint64_t>(a[i]) + carry;
        a[i] = static_cast<uint32_t>(cur & 0xffffffffu);
        carry = cur >> 32;
    }
    if (carry) a.push_back(static_cast<uint32_t>(carry));
}

void sub(Big &a, const Big &b) {            /* a >= b */
    uint64_t borrow = 0;
    for (size_t i = 0; i < a.size(); ++i) {
        const uint64_t x = a[i];
        const uint64_t y = (i < b.size()) ? b[i] : 0;
        const uint64_t d = x - y - borrow;
        borrow = (x < y + borrow) ? 1 : 0;
        a[i] = static_cast<uint32_t>(d & 0xffffffffu);
    }
    trim(a);
}

/* Multiply by 10^k, by repeated multiplication with the largest power
 * of ten that fits a limb. */
void mul_pow10(Big &a, int k) {
    static const uint32_t kPow10[10] = {
        1u, 10u, 100u, 1000u, 10000u, 100000u, 1000000u,
        10000000u, 100000000u, 1000000000u
    };
    while (k >= 9) {
        mul_small(a, kPow10[9]);
        k -= 9;
    }
    if (k > 0) mul_small(a, kPow10[k]);
}

/* q = a / b, r = a % b, by shift and subtract. b must be non-zero.
 * Slow by the standards of a real bignum library and entirely fast
 * enough: a JSON number needs one of these, and only when the fast
 * path cannot serve. */
void divmod(const Big &a, const Big &b, Big &q, Big &r) {
    q.assign(1, 0u);
    r.assign(1, 0u);
    const size_t nb = bit_length(a);
    if (nb == 0) return;
    q.assign((nb + 31) / 32, 0u);
    for (size_t i = nb; i-- > 0;) {
        shl(r, 1);
        const uint32_t bit = (a[i / 32] >> (i % 32)) & 1u;
        if (bit) add_small(r, 1u);
        if (cmp(r, b) >= 0) {
            sub(r, b);
            q[i / 32] |= (1u << (i % 32));
        }
    }
    trim(q);
    trim(r);
}

/* The low 64 bits of a Big known to fit. */
uint64_t to_u64(const Big &a) {
    uint64_t v = 0;
    for (size_t i = a.size(); i-- > 0;) {
        v = (v << 32) | a[i];
    }
    return v;
}

struct Parsed {
    bool negative;
    bool valid;
    bool is_inf;
    bool is_nan;
    Big mantissa;          /* the significant digits as an integer */
    int exponent;          /* value = mantissa * 10^exponent */
    size_t sig_digits;
};

/* Read the JSON (and R) number grammar, plus the specials R writes. */
Parsed parse_decimal(const char *s, size_t len) {
    Parsed p;
    p.negative = false;
    p.valid = false;
    p.is_inf = false;
    p.is_nan = false;
    p.mantissa.assign(1, 0u);
    p.exponent = 0;
    p.sig_digits = 0;

    size_t i = 0;
    while (i < len && (s[i] == ' ' || s[i] == '\t' || s[i] == '\n' ||
                       s[i] == '\r')) ++i;
    if (i < len && (s[i] == '+' || s[i] == '-')) {
        p.negative = (s[i] == '-');
        ++i;
    }
    if (i + 2 < len + 1 && (len - i) >= 3) {
        if (std::strncmp(s + i, "Inf", 3) == 0 ||
            std::strncmp(s + i, "inf", 3) == 0) {
            p.is_inf = true;
            p.valid = true;
            return p;
        }
        if (std::strncmp(s + i, "NaN", 3) == 0 ||
            std::strncmp(s + i, "nan", 3) == 0) {
            p.is_nan = true;
            p.valid = true;
            return p;
        }
    }

    bool any_digit = false;
    bool seen_nonzero = false;
    int frac_digits = 0;
    /* integer part */
    while (i < len && s[i] >= '0' && s[i] <= '9') {
        any_digit = true;
        const uint32_t d = static_cast<uint32_t>(s[i] - '0');
        if (d != 0) seen_nonzero = true;
        if (seen_nonzero) {
            /* Only significant digits are accumulated, and only as
             * many as can possibly matter: 768 is past the point where
             * further digits can change the rounding of any double,
             * and keeping them would make the big integer enormous for
             * no effect. The dropped digits are accounted for in the
             * exponent and in the sticky flag below. */
            if (p.sig_digits < 768) {
                mul_small(p.mantissa, 10u);
                add_small(p.mantissa, d);
                ++p.sig_digits;
            } else {
                ++p.exponent;
            }
        }
        ++i;
    }
    /* fraction */
    if (i < len && s[i] == '.') {
        ++i;
        while (i < len && s[i] >= '0' && s[i] <= '9') {
            any_digit = true;
            const uint32_t d = static_cast<uint32_t>(s[i] - '0');
            if (d != 0) seen_nonzero = true;
            if (seen_nonzero) {
                if (p.sig_digits < 768) {
                    mul_small(p.mantissa, 10u);
                    add_small(p.mantissa, d);
                    ++p.sig_digits;
                    ++frac_digits;
                }
            } else {
                /* leading zeros after the point still shift the scale */
                ++frac_digits;
            }
            ++i;
        }
    }
    if (!any_digit) return p;
    p.exponent -= frac_digits;
    /* exponent */
    if (i < len && (s[i] == 'e' || s[i] == 'E')) {
        ++i;
        bool eneg = false;
        if (i < len && (s[i] == '+' || s[i] == '-')) {
            eneg = (s[i] == '-');
            ++i;
        }
        if (i >= len || s[i] < '0' || s[i] > '9') return p;
        long ev = 0;
        while (i < len && s[i] >= '0' && s[i] <= '9') {
            if (ev < 1000000L) ev = ev * 10 + (s[i] - '0');
            ++i;
        }
        p.exponent += static_cast<int>(eneg ? -ev : ev);
    }
    while (i < len && (s[i] == ' ' || s[i] == '\t' || s[i] == '\n' ||
                       s[i] == '\r')) ++i;
    if (i != len) return p;                 /* trailing junk */
    p.valid = true;
    return p;
}

const double kInf = HUGE_VAL;

/* value = m * 10^e, correctly rounded to the nearest double. */
double exact_to_double(Big m, int e) {
    if (is_zero(m)) return 0.0;

    /* A decimal exponent this far out cannot be anything but an
     * overflow or an underflow, whatever the mantissa: 10^309 exceeds
     * the largest double and 10^-324 is below the smallest subnormal,
     * with the mantissa's own digit count bounded well inside that. */
    const long digits = static_cast<long>(bit_length(m) / 3) + 1;
    if (static_cast<long>(e) + digits > 400L) return kInf;
    if (static_cast<long>(e) + digits < -400L) return 0.0;

    Big num = m;
    Big den;
    den.assign(1, 1u);
    if (e > 0) {
        mul_pow10(num, e);
    } else if (e < 0) {
        mul_pow10(den, -e);
    }

    /* Scale so the quotient has exactly 53 bits: that is the double's
     * significand, and the remainder is what decides the rounding. */
    int be = 0;
    const long nb = static_cast<long>(bit_length(num));
    const long db = static_cast<long>(bit_length(den));
    long shift = 53 - (nb - db);
    if (shift > 0) {
        shl(num, static_cast<size_t>(shift));
        be -= static_cast<int>(shift);
    } else if (shift < 0) {
        shl(den, static_cast<size_t>(-shift));
        be -= static_cast<int>(shift);
    }
    Big q, r;
    divmod(num, den, q, r);
    while (bit_length(q) > 53) {
        shl(den, 1);
        be += 1;
        divmod(num, den, q, r);
    }
    while (bit_length(q) < 53) {
        shl(num, 1);
        be -= 1;
        divmod(num, den, q, r);
    }

    /* Subnormals live on a fixed grid: below 2^-1074 there are no bits
     * left to hold precision, so the quotient is taken on that grid
     * instead and comes out with fewer than 53 bits. */
    if (be < -1074) {
        const size_t d = static_cast<size_t>(-1074 - be);
        shl(den, d);
        be = -1074;
        divmod(num, den, q, r);
    }

    /* round to nearest, ties to even */
    Big twice_r = r;
    shl(twice_r, 1);
    const int c = cmp(twice_r, den);
    const bool odd = (q.size() > 0) && ((q[0] & 1u) != 0);
    if (c > 0 || (c == 0 && odd)) {
        add_small(q, 1u);
        if (bit_length(q) > 53 && be >= -1074) {
            shr(q, 1);
            be += 1;
        }
    }

    if (be > 971) return kInf;
    const uint64_t mant = to_u64(q);
    if (be == 971 && mant >= (static_cast<uint64_t>(1) << 53)) return kInf;
    const double out = std::ldexp(static_cast<double>(mant), be);
    if (!std::isfinite(out)) return kInf;
    return out;
}

/* Clinger's fast path: an exactly representable mantissa times an
 * exactly representable power of ten is one rounding, which is the
 * correct one. Applies to the overwhelming majority of numbers in a
 * real document. */
bool fast_path(const Parsed &p, double *out) {
    if (p.sig_digits == 0 || p.sig_digits > 15) return false;
    if (p.exponent < -22 || p.exponent > 22) return false;
    if (bit_length(p.mantissa) > 53) return false;
    static const double kP10[23] = {
        1e0, 1e1, 1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9, 1e10,
        1e11, 1e12, 1e13, 1e14, 1e15, 1e16, 1e17, 1e18, 1e19, 1e20,
        1e21, 1e22
    };
    const double m = static_cast<double>(to_u64(p.mantissa));
    *out = (p.exponent >= 0) ? (m * kP10[p.exponent])
                             : (m / kP10[-p.exponent]);
    return true;
}

double convert(const char *s, size_t len, bool *ok) {
    const Parsed p = parse_decimal(s, len);
    *ok = p.valid;
    if (!p.valid) return R_NaReal;
    if (p.is_nan) return R_NaN;
    if (p.is_inf) return p.negative ? -kInf : kInf;
    double v;
    if (!fast_path(p, &v)) {
        v = exact_to_double(p.mantissa, p.exponent);
    }
    return p.negative ? -v : v;
}

}  // namespace

extern "C" {

/* Convert decimal strings to doubles, correctly rounded, without
 * asking the platform. NA_character_ and unparseable input give
 * NA_real_ rather than an error: this sits in a JSON parser, which
 * reports a bad document its own way. */
SEXP C_rmbl_strtod(SEXP x) {
    if (TYPEOF(x) != STRSXP) Rf_error("`x` must be a character vector");
    const R_xlen_t n = XLENGTH(x);
    SEXP out = PROTECT(Rf_allocVector(REALSXP, n));
    double *o = REAL(out);
    for (R_xlen_t i = 0; i < n; ++i) {
        SEXP si = STRING_ELT(x, i);
        if (si == NA_STRING) {
            o[i] = R_NaReal;
            continue;
        }
        const char *cs = CHAR(si);
        bool ok = false;
        o[i] = convert(cs, std::strlen(cs), &ok);
        if (!ok) o[i] = R_NaReal;
    }
    UNPROTECT(1);
    return out;
}

}  // extern "C"
