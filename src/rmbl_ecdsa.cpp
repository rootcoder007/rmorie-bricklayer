/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * ECDSA verification over the NIST prime curves P-256, P-384 and P-521,
 * for RFC 3161 tokens and X.509 certificates signed with them.
 *
 * Verification only. There is no signing here and no private-key
 * arithmetic, which is why this file can be as plain as it is: the
 * verifier's inputs are all public, so the constant-time discipline a
 * signer needs does not apply. A scalar multiplication that leaks its
 * scalar through timing leaks nothing here, because the scalar is the
 * published signature.
 *
 * The arithmetic is schoolbook: fixed-width limbs, Montgomery-free
 * modular reduction by shift-and-subtract, and double-and-add on
 * Jacobian coordinates. Slow by the standards of a real EC library and
 * entirely fast enough for what a verifier does -- two scalar
 * multiplications per signature, a few times per capsule.
 */

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <vector>

#include <R.h>
#include <Rinternals.h>

namespace {

/* 521 bits needs 17 limbs; one spare for carries during multiply. */
const int kMaxLimbs = 36;

struct Num {
    uint32_t v[kMaxLimbs];
    int n;                    /* limbs in use, least significant first */
};

void zero(Num *a) {
    std::memset(a->v, 0, sizeof a->v);
    a->n = 1;
}

void trim(Num *a) {
    while (a->n > 1 && a->v[a->n - 1] == 0) --a->n;
}

void set_u32(Num *a, uint32_t x) {
    zero(a);
    a->v[0] = x;
}

bool is_zero(const Num *a) {
    for (int i = 0; i < a->n; ++i) {
        if (a->v[i]) return false;
    }
    return true;
}

int cmp(const Num *a, const Num *b) {
    const int n = (a->n > b->n) ? a->n : b->n;
    for (int i = n; i-- > 0;) {
        const uint32_t x = (i < a->n) ? a->v[i] : 0;
        const uint32_t y = (i < b->n) ? b->v[i] : 0;
        if (x != y) return x < y ? -1 : 1;
    }
    return 0;
}

void from_bytes(Num *a, const unsigned char *p, size_t len) {
    zero(a);
    int limb = 0;
    size_t i = len;
    while (i > 0 && limb < kMaxLimbs) {
        uint32_t v = 0;
        for (int k = 0; k < 4 && i > 0; ++k) {
            v |= static_cast<uint32_t>(p[--i]) << (8 * k);
        }
        a->v[limb++] = v;
    }
    a->n = (limb > 0) ? limb : 1;
    trim(a);
}

void to_bytes(const Num *a, unsigned char *out, size_t len) {
    std::memset(out, 0, len);
    for (size_t i = 0; i < len; ++i) {
        const size_t limb = i / 4;
        if (limb >= static_cast<size_t>(a->n)) break;
        out[len - 1 - i] =
            static_cast<unsigned char>(a->v[limb] >> (8 * (i % 4)));
    }
}

void add(Num *r, const Num *a, const Num *b) {
    const int n = ((a->n > b->n) ? a->n : b->n) + 1;
    uint64_t carry = 0;
    Num t;
    zero(&t);
    for (int i = 0; i < n && i < kMaxLimbs; ++i) {
        const uint64_t x = (i < a->n) ? a->v[i] : 0;
        const uint64_t y = (i < b->n) ? b->v[i] : 0;
        const uint64_t s = x + y + carry;
        t.v[i] = static_cast<uint32_t>(s & 0xffffffffu);
        carry = s >> 32;
    }
    t.n = (n < kMaxLimbs) ? n : kMaxLimbs;
    trim(&t);
    *r = t;
}

/* a - b, for a >= b. */
void sub(Num *r, const Num *a, const Num *b) {
    Num t;
    zero(&t);
    uint64_t borrow = 0;
    for (int i = 0; i < a->n; ++i) {
        const uint64_t x = a->v[i];
        const uint64_t y = (i < b->n) ? b->v[i] : 0;
        const uint64_t d = x - y - borrow;
        borrow = (x < y + borrow) ? 1 : 0;
        t.v[i] = static_cast<uint32_t>(d & 0xffffffffu);
    }
    t.n = a->n;
    trim(&t);
    *r = t;
}

void mul(Num *r, const Num *a, const Num *b) {
    Num t;
    zero(&t);
    const int n = a->n + b->n;
    for (int i = 0; i < a->n; ++i) {
        uint64_t carry = 0;
        for (int j = 0; j < b->n; ++j) {
            if (i + j >= kMaxLimbs) break;
            const uint64_t cur = static_cast<uint64_t>(a->v[i]) * b->v[j] +
                                 t.v[i + j] + carry;
            t.v[i + j] = static_cast<uint32_t>(cur & 0xffffffffu);
            carry = cur >> 32;
        }
        int k = i + b->n;
        while (carry && k < kMaxLimbs) {
            const uint64_t cur = static_cast<uint64_t>(t.v[k]) + carry;
            t.v[k] = static_cast<uint32_t>(cur & 0xffffffffu);
            carry = cur >> 32;
            ++k;
        }
    }
    t.n = (n < kMaxLimbs) ? n : kMaxLimbs;
    trim(&t);
    *r = t;
}

void shl1(Num *a) {
    uint32_t carry = 0;
    for (int i = 0; i < a->n; ++i) {
        const uint32_t nc = a->v[i] >> 31;
        a->v[i] = (a->v[i] << 1) | carry;
        carry = nc;
    }
    if (carry && a->n < kMaxLimbs) a->v[a->n++] = carry;
}

size_t bit_length(const Num *a) {
    for (int i = a->n; i-- > 0;) {
        if (a->v[i]) {
            uint32_t x = a->v[i];
            size_t b = 0;
            while (x) { ++b; x >>= 1; }
            return static_cast<size_t>(i) * 32 + b;
        }
    }
    return 0;
}

bool bit(const Num *a, size_t i) {
    const size_t limb = i / 32;
    if (limb >= static_cast<size_t>(a->n)) return false;
    return ((a->v[limb] >> (i % 32)) & 1u) != 0;
}

/* a mod m, by shift and subtract. */
void mod(Num *r, const Num *a, const Num *m) {
    if (cmp(a, m) < 0) { *r = *a; return; }
    Num acc;
    zero(&acc);
    const size_t nb = bit_length(a);
    for (size_t i = nb; i-- > 0;) {
        shl1(&acc);
        if (bit(a, i)) acc.v[0] |= 1u;
        if (cmp(&acc, m) >= 0) {
            Num t;
            sub(&t, &acc, m);
            acc = t;
        }
    }
    *r = acc;
}

void addmod(Num *r, const Num *a, const Num *b, const Num *m) {
    Num t;
    add(&t, a, b);
    if (cmp(&t, m) >= 0) {
        Num u;
        sub(&u, &t, m);
        *r = u;
    } else {
        *r = t;
    }
}

void submod(Num *r, const Num *a, const Num *b, const Num *m) {
    if (cmp(a, b) >= 0) {
        sub(r, a, b);
    } else {
        Num t;
        add(&t, a, m);
        sub(r, &t, b);
    }
}

void mulmod(Num *r, const Num *a, const Num *b, const Num *m) {
    Num t;
    mul(&t, a, b);
    mod(r, &t, m);
}

void modexp(Num *r, const Num *base, const Num *e, const Num *m) {
    Num result, b;
    set_u32(&result, 1);
    mod(&b, base, m);
    const size_t nb = bit_length(e);
    for (size_t i = nb; i-- > 0;) {
        Num t;
        mulmod(&t, &result, &result, m);
        result = t;
        if (bit(e, i)) {
            mulmod(&t, &result, &b, m);
            result = t;
        }
    }
    *r = result;
}

/* The inverse by Fermat: a^(p-2) mod p. Valid because every curve here
 * has a prime field, and it avoids a second algorithm (and a second
 * chance to be wrong) for the extended Euclidean version. */
void invmod(Num *r, const Num *a, const Num *p) {
    Num two, e;
    set_u32(&two, 2);
    sub(&e, p, &two);
    modexp(r, a, &e, p);
}

struct Curve {
    Num p;        /* field */
    Num n;        /* group order */
    Num a;        /* -3 for all three curves, stored as p - 3 */
    Num b;
    Num gx;
    Num gy;
    int bytes;    /* field element width */
};

/* Jacobian coordinates: (X : Y : Z) is (X/Z^2, Y/Z^3). Z = 0 is the
 * point at infinity, which is why no separate flag is needed. */
struct Point {
    Num x, y, z;
};

void set_infinity(Point *q) {
    set_u32(&q->x, 1);
    set_u32(&q->y, 1);
    zero(&q->z);
}

bool is_infinity(const Point *q) {
    return is_zero(&q->z);
}

/* Doubling, for a = -3: the standard formulas, which are why every NIST
 * prime curve chooses that value. */
void dbl(Point *r, const Point *q, const Curve *c) {
    if (is_infinity(q)) { *r = *q; return; }
    Num delta, gamma, beta, alpha, t1, t2, t3;
    mulmod(&delta, &q->z, &q->z, &c->p);            /* Z^2 */
    mulmod(&gamma, &q->y, &q->y, &c->p);            /* Y^2 */
    mulmod(&beta, &q->x, &gamma, &c->p);            /* X*Y^2 */
    submod(&t1, &q->x, &delta, &c->p);              /* X - Z^2 */
    addmod(&t2, &q->x, &delta, &c->p);              /* X + Z^2 */
    mulmod(&t3, &t1, &t2, &c->p);                   /* X^2 - Z^4 */
    set_u32(&t1, 3);
    mulmod(&alpha, &t3, &t1, &c->p);                /* 3(X^2 - Z^4) */

    Num x3, y3, z3;
    mulmod(&x3, &alpha, &alpha, &c->p);
    set_u32(&t1, 8);
    mulmod(&t2, &beta, &t1, &c->p);
    submod(&x3, &x3, &t2, &c->p);                   /* alpha^2 - 8beta */

    addmod(&t1, &q->y, &q->z, &c->p);
    mulmod(&z3, &t1, &t1, &c->p);
    submod(&z3, &z3, &gamma, &c->p);
    submod(&z3, &z3, &delta, &c->p);                /* (Y+Z)^2 - Y^2 - Z^2 */

    set_u32(&t1, 4);
    mulmod(&t2, &beta, &t1, &c->p);
    submod(&t2, &t2, &x3, &c->p);                   /* 4beta - X3 */
    mulmod(&y3, &alpha, &t2, &c->p);
    mulmod(&t1, &gamma, &gamma, &c->p);
    set_u32(&t2, 8);
    mulmod(&t3, &t1, &t2, &c->p);
    submod(&y3, &y3, &t3, &c->p);                   /* ... - 8gamma^2 */

    r->x = x3;
    r->y = y3;
    r->z = z3;
}

/* Addition of a Jacobian point and an affine one. */
void add_affine(Point *r, const Point *q, const Num *px, const Num *py,
                const Curve *c) {
    if (is_infinity(q)) {
        r->x = *px;
        r->y = *py;
        set_u32(&r->z, 1);
        return;
    }
    Num z2, u2, s2, h, hh, i, j, rr, v, t1, t2;
    mulmod(&z2, &q->z, &q->z, &c->p);
    mulmod(&u2, px, &z2, &c->p);                    /* X2 * Z1^2 */
    mulmod(&t1, &z2, &q->z, &c->p);
    mulmod(&s2, py, &t1, &c->p);                    /* Y2 * Z1^3 */
    submod(&h, &u2, &q->x, &c->p);
    submod(&rr, &s2, &q->y, &c->p);
    if (is_zero(&h)) {
        if (is_zero(&rr)) {
            /* the same point: doubling, not addition */
            Point p2;
            p2.x = *px;
            p2.y = *py;
            set_u32(&p2.z, 1);
            dbl(r, &p2, c);
        } else {
            set_infinity(r);
        }
        return;
    }
    set_u32(&t1, 2);
    mulmod(&t2, &h, &t1, &c->p);
    mulmod(&i, &t2, &t2, &c->p);                    /* (2h)^2 */
    mulmod(&j, &h, &i, &c->p);
    set_u32(&t1, 2);
    mulmod(&t2, &rr, &t1, &c->p);                   /* 2r */
    mulmod(&v, &q->x, &i, &c->p);

    Num x3, y3, z3;
    mulmod(&x3, &t2, &t2, &c->p);
    submod(&x3, &x3, &j, &c->p);
    Num twov;
    set_u32(&t1, 2);
    mulmod(&twov, &v, &t1, &c->p);
    submod(&x3, &x3, &twov, &c->p);

    submod(&t1, &v, &x3, &c->p);
    mulmod(&y3, &t2, &t1, &c->p);
    set_u32(&t1, 2);
    mulmod(&hh, &q->y, &t1, &c->p);
    mulmod(&t1, &hh, &j, &c->p);
    submod(&y3, &y3, &t1, &c->p);

    addmod(&t1, &q->z, &h, &c->p);
    mulmod(&z3, &t1, &t1, &c->p);
    submod(&z3, &z3, &z2, &c->p);
    mulmod(&t1, &h, &h, &c->p);
    submod(&z3, &z3, &t1, &c->p);

    r->x = x3;
    r->y = y3;
    r->z = z3;
}

void to_affine(Num *x, Num *y, const Point *q, const Curve *c) {
    if (is_infinity(q)) {
        zero(x);
        zero(y);
        return;
    }
    Num zi, zi2, zi3;
    invmod(&zi, &q->z, &c->p);
    mulmod(&zi2, &zi, &zi, &c->p);
    mulmod(&zi3, &zi2, &zi, &c->p);
    mulmod(x, &q->x, &zi2, &c->p);
    mulmod(y, &q->y, &zi3, &c->p);
}

/* k*P by double-and-add. Not constant time, and it does not need to be:
 * every scalar a verifier multiplies by is public. */
void scalar_mul(Point *r, const Num *k, const Num *px, const Num *py,
                const Curve *c) {
    Point acc;
    set_infinity(&acc);
    const size_t nb = bit_length(k);
    for (size_t i = nb; i-- > 0;) {
        Point t;
        dbl(&t, &acc, c);
        acc = t;
        if (bit(k, i)) {
            add_affine(&t, &acc, px, py, c);
            acc = t;
        }
    }
    *r = acc;
}

/* The curve parameters, as hex, exactly as FIPS 186-4 publishes them.
 * Hex rather than limb arrays so that they can be compared against the
 * standard by eye. */
struct CurveHex {
    const char *p;
    const char *n;
    const char *b;
    const char *gx;
    const char *gy;
    int bytes;
};

const CurveHex kP256 = {
    "ffffffff00000001000000000000000000000000ffffffffffffffffffffffff",
    "ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551",
    "5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b",
    "6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296",
    "4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5",
    32
};

const CurveHex kP384 = {
    "fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe"
    "ffffffff0000000000000000ffffffff",
    "ffffffffffffffffffffffffffffffffffffffffffffffffc7634d81f4372ddf"
    "581a0db248b0a77aecec196accc52973",
    "b3312fa7e23ee7e4988e056be3f82d19181d9c6efe8141120314088f5013875a"
    "c656398d8a2ed19d2a85c8edd3ec2aef",
    "aa87ca22be8b05378eb1c71ef320ad746e1d3b628ba79b9859f741e082542a38"
    "5502f25dbf55296c3a545e3872760ab7",
    "3617de4a96262c6f5d9e98bf9292dc29f8f41dbd289a147ce9da3113b5f0b8c0"
    "0a60b1ce1d7e819d7a431d7c90ea0e5f",
    48
};

const CurveHex kP521 = {
    "01ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
    "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
    "ffff",
    "01ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
    "fffa51868783bf2f966b7fcc0148f709a5d03bb5c9b8899c47aebb6fb71e9138"
    "6409",
    "0051953eb9618e1c9a1f929a21a0b68540eea2da725b99b315f3b8b489918ef1"
    "09e156193951ec7e937b1652c0bd3bb1bf073573df883d2c34f1ef451fd46b50"
    "3f00",
    "00c6858e06b70404e9cd9e3ecb662395b4429c648139053fb521f828af606b4d"
    "3dbaa14b5e77efe75928fe1dc127a2ffa8de3348b3c1856a429bf97e7e31c2e5"
    "bd66",
    "011839296a789a3bc0045c8a5fb42c7d1bd998f54449579b446817afbd17273e"
    "662c97ee72995ef42640c550b9013fad0761353c7086a272c24088be94769fd1"
    "6650",
    66
};

int hexval(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

void num_from_hex(Num *a, const char *h) {
    const size_t len = std::strlen(h);
    std::vector<unsigned char> b((len + 1) / 2, 0);
    size_t bi = b.size();
    size_t i = len;
    while (i > 0) {
        const int lo = hexval(h[--i]);
        int hi = 0;
        if (i > 0) hi = hexval(h[--i]);
        b[--bi] = static_cast<unsigned char>((hi << 4) | lo);
    }
    from_bytes(a, b.data(), b.size());
}

bool load_curve(Curve *c, const char *name) {
    const CurveHex *h = NULL;
    if (std::strcmp(name, "P-256") == 0) h = &kP256;
    else if (std::strcmp(name, "P-384") == 0) h = &kP384;
    else if (std::strcmp(name, "P-521") == 0) h = &kP521;
    else return false;
    /* Every parameter is exactly one field element wide. A constant
     * written short is the failure this guards: the group order was
     * once four hex digits short here, which left the curve arithmetic
     * correct -- it uses only p and b, and the published base-point
     * multiples still matched -- while everything mod n was wrong and
     * no signature verified. A length check catches in one line what
     * cost an afternoon to find. */
    const size_t want = static_cast<size_t>(h->bytes) * 2u;
    if (std::strlen(h->p) != want || std::strlen(h->n) != want ||
        std::strlen(h->b) != want || std::strlen(h->gx) != want ||
        std::strlen(h->gy) != want) {
        Rf_error("curve %s has a parameter of the wrong width", name);
    }
    num_from_hex(&c->p, h->p);
    num_from_hex(&c->n, h->n);
    num_from_hex(&c->b, h->b);
    num_from_hex(&c->gx, h->gx);
    num_from_hex(&c->gy, h->gy);
    c->bytes = h->bytes;
    /* a = -3 mod p, for all three */
    Num three;
    set_u32(&three, 3);
    sub(&c->a, &c->p, &three);
    return true;
}

/* y^2 == x^3 + ax + b, the check that a point is on the curve. A
 * verifier that skips it can be walked onto a weaker curve. */
bool on_curve(const Num *x, const Num *y, const Curve *c) {
    Num lhs, x3, ax, rhs, t;
    mulmod(&lhs, y, y, &c->p);
    mulmod(&t, x, x, &c->p);
    mulmod(&x3, &t, x, &c->p);
    mulmod(&ax, &c->a, x, &c->p);
    addmod(&rhs, &x3, &ax, &c->p);
    addmod(&rhs, &rhs, &c->b, &c->p);
    return cmp(&lhs, &rhs) == 0;
}

}  // namespace

extern "C" {

/* ECDSA verification (FIPS 186-4 section 6.4.2).
 *
 * Returns TRUE only if every condition holds: r and s in [1, n-1], the
 * public key on the curve, and R's affine x congruent to r mod n. Each
 * of those is load-bearing -- s = 0 or a key off the curve are the two
 * classic ways a lax verifier accepts a forgery.
 */
SEXP C_rmbl_ecdsa_verify(SEXP curve, SEXP qx, SEXP qy, SEXP r, SEXP s,
                         SEXP digest) {
    if (TYPEOF(curve) != STRSXP || XLENGTH(curve) != 1) {
        Rf_error("`curve` must be \"P-256\", \"P-384\" or \"P-521\"");
    }
    Curve c;
    if (!load_curve(&c, CHAR(STRING_ELT(curve, 0)))) {
        Rf_error("unsupported curve: %s", CHAR(STRING_ELT(curve, 0)));
    }
    if (TYPEOF(qx) != RAWSXP || TYPEOF(qy) != RAWSXP ||
        TYPEOF(r) != RAWSXP || TYPEOF(s) != RAWSXP ||
        TYPEOF(digest) != RAWSXP) {
        Rf_error("the key, signature and digest must be raw vectors");
    }
    Num nqx, nqy, nr, ns, e, one;
    from_bytes(&nqx, RAW(qx), static_cast<size_t>(XLENGTH(qx)));
    from_bytes(&nqy, RAW(qy), static_cast<size_t>(XLENGTH(qy)));
    from_bytes(&nr, RAW(r), static_cast<size_t>(XLENGTH(r)));
    from_bytes(&ns, RAW(s), static_cast<size_t>(XLENGTH(s)));
    set_u32(&one, 1);

    /* r and s must be in [1, n-1] */
    if (is_zero(&nr) || is_zero(&ns) ||
        cmp(&nr, &c.n) >= 0 || cmp(&ns, &c.n) >= 0) {
        return Rf_ScalarLogical(FALSE);
    }
    /* the key must be on the curve and not the point at infinity */
    if (cmp(&nqx, &c.p) >= 0 || cmp(&nqy, &c.p) >= 0 ||
        !on_curve(&nqx, &nqy, &c)) {
        return Rf_ScalarLogical(FALSE);
    }

    /* e is the leftmost bits of the digest, as many as the order has */
    {
        const size_t dlen = static_cast<size_t>(XLENGTH(digest));
        const size_t nbits = bit_length(&c.n);
        const size_t want = (nbits + 7) / 8;
        const size_t take = (dlen < want) ? dlen : want;
        from_bytes(&e, RAW(digest), take);
        /* when the digest is longer in BITS than the order, the extra
         * low bits are shifted off, not masked */
        if (dlen * 8 > nbits) {
            const size_t excess = take * 8 - nbits;
            for (size_t i = 0; i < excess; ++i) {
                /* a right shift by one */
                uint32_t carry = 0;
                for (int k = e.n; k-- > 0;) {
                    const uint32_t nc = e.v[k] & 1u;
                    e.v[k] = (e.v[k] >> 1) | (carry << 31);
                    carry = nc;
                }
                trim(&e);
            }
        }
    }

    Num sinv, u1, u2;
    invmod(&sinv, &ns, &c.n);
    mulmod(&u1, &e, &sinv, &c.n);
    mulmod(&u2, &nr, &sinv, &c.n);

    Point p1, p2;
    scalar_mul(&p1, &u1, &c.gx, &c.gy, &c);
    scalar_mul(&p2, &u2, &nqx, &nqy, &c);

    /* p1 + p2, both in Jacobian form: bring the second to affine first,
     * which is one inversion and keeps the addition to the one case
     * already written */
    Num ax, ay;
    to_affine(&ax, &ay, &p2, &c);
    Point sum;
    if (is_infinity(&p2)) {
        sum = p1;
    } else {
        add_affine(&sum, &p1, &ax, &ay, &c);
    }
    if (is_infinity(&sum)) return Rf_ScalarLogical(FALSE);

    Num rx, ry, v;
    to_affine(&rx, &ry, &sum, &c);
    mod(&v, &rx, &c.n);
    return Rf_ScalarLogical(cmp(&v, &nr) == 0 ? TRUE : FALSE);
}

/* The group order, so a test can multiply the base point by it and
 * confirm the result is the point at infinity -- the one check that
 * fails if the order is wrong, whatever else looks right. */
SEXP C_rmbl_ec_order(SEXP curve) {
    if (TYPEOF(curve) != STRSXP || XLENGTH(curve) != 1) {
        Rf_error("`curve` must be a single string");
    }
    Curve c;
    if (!load_curve(&c, CHAR(STRING_ELT(curve, 0)))) {
        Rf_error("unsupported curve: %s", CHAR(STRING_ELT(curve, 0)));
    }
    SEXP out = PROTECT(Rf_allocVector(RAWSXP, c.bytes));
    to_bytes(&c.n, RAW(out), static_cast<size_t>(c.bytes));
    UNPROTECT(1);
    return out;
}

/* Exposed so the curve arithmetic can be checked against the published
 * base-point multiples rather than only through a signature. TRUE in
 * `infinity` means the scalar was a multiple of the order. */
SEXP C_rmbl_ec_mul(SEXP curve, SEXP k) {
    if (TYPEOF(curve) != STRSXP || XLENGTH(curve) != 1) {
        Rf_error("`curve` must be a single string");
    }
    Curve c;
    if (!load_curve(&c, CHAR(STRING_ELT(curve, 0)))) {
        Rf_error("unsupported curve: %s", CHAR(STRING_ELT(curve, 0)));
    }
    if (TYPEOF(k) != RAWSXP) Rf_error("`k` must be a raw vector");
    Num nk;
    from_bytes(&nk, RAW(k), static_cast<size_t>(XLENGTH(k)));
    Point q;
    scalar_mul(&q, &nk, &c.gx, &c.gy, &c);
    Num x, y;
    const bool inf = is_infinity(&q);
    to_affine(&x, &y, &q, &c);
    SEXP out = PROTECT(Rf_allocVector(VECSXP, 3));
    SEXP sx = PROTECT(Rf_allocVector(RAWSXP, c.bytes));
    SEXP sy = PROTECT(Rf_allocVector(RAWSXP, c.bytes));
    to_bytes(&x, RAW(sx), static_cast<size_t>(c.bytes));
    to_bytes(&y, RAW(sy), static_cast<size_t>(c.bytes));
    SET_VECTOR_ELT(out, 0, sx);
    SET_VECTOR_ELT(out, 1, sy);
    SET_VECTOR_ELT(out, 2, Rf_ScalarLogical(inf ? TRUE : FALSE));
    SEXP nm = PROTECT(Rf_allocVector(STRSXP, 3));
    SET_STRING_ELT(nm, 0, Rf_mkChar("x"));
    SET_STRING_ELT(nm, 1, Rf_mkChar("y"));
    SET_STRING_ELT(nm, 2, Rf_mkChar("infinity"));
    Rf_setAttrib(out, R_NamesSymbol, nm);
    UNPROTECT(4);
    return out;
}

}  // extern "C"
