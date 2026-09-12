/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * DER parsing and RSA verification, for RFC 3161 timestamp tokens.
 *
 * The split is deliberate. This file does the two things R cannot do
 * well -- walk a DER structure without heroic string surgery, and raise
 * a 2048-bit number to a power modulo another -- and returns the results
 * plainly. Everything about what the structure MEANS (which OID is the
 * content type, which attribute carries the message digest, how the
 * PKCS#1 padding is laid out) is done in R, where it can be read.
 *
 * The verification implemented here recovers the padded block from a
 * signature and hands it back. It deliberately does NOT decide whether
 * the signature is valid: that decision needs the padding and the
 * DigestInfo checked against a digest of the right bytes, and folding
 * it in here would hide the one step most worth auditing.
 */

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <vector>

#include <R.h>
#include <Rinternals.h>

namespace {

/* ------------------------------------------------------------------ *
 * DER
 * ------------------------------------------------------------------ */

struct Node {
    unsigned int tag_class;    /* 0 universal, 1 application, 2 context,
                                * 3 private */
    bool constructed;
    unsigned long tag;
    size_t header_len;
    size_t length;
    size_t offset;             /* of the value, from the start of input */
    std::vector<Node> children;
};

/* Returns false on any malformation. A parser that guesses at a broken
 * structure is worse than one that refuses: the input is a signature
 * envelope, and a lenient reading is exactly how a verifier ends up
 * checking something other than what it was given. */
bool parse_one(const unsigned char *p, size_t n, size_t &pos, Node &out,
               int depth);

bool parse_seq(const unsigned char *p, size_t start, size_t len,
               std::vector<Node> &out, int depth) {
    size_t pos = start;
    const size_t end = start + len;
    while (pos < end) {
        Node c;
        if (!parse_one(p, end, pos, c, depth + 1)) return false;
        out.push_back(c);
    }
    return pos == end;
}

bool parse_one(const unsigned char *p, size_t n, size_t &pos, Node &out,
               int depth) {
    if (depth > 32) return false;          /* no unbounded recursion */
    if (pos >= n) return false;
    const size_t start = pos;
    unsigned char id = p[pos++];
    out.tag_class = static_cast<unsigned int>((id >> 6) & 0x03);
    out.constructed = ((id & 0x20) != 0);
    unsigned long tag = id & 0x1f;
    if (tag == 0x1f) {                      /* high tag number form */
        tag = 0;
        for (;;) {
            if (pos >= n) return false;
            const unsigned char b = p[pos++];
            if (tag > (~0UL >> 7)) return false;
            tag = (tag << 7) | (b & 0x7f);
            if ((b & 0x80) == 0) break;
        }
    }
    out.tag = tag;
    if (pos >= n) return false;
    size_t len = p[pos++];
    if (len & 0x80) {
        const size_t nbytes = len & 0x7f;
        if (nbytes == 0) return false;      /* indefinite: not DER */
        if (nbytes > sizeof(size_t)) return false;
        if (pos + nbytes > n) return false;
        len = 0;
        for (size_t i = 0; i < nbytes; ++i) {
            len = (len << 8) | p[pos++];
        }
    }
    if (pos + len > n) return false;
    out.header_len = pos - start;
    out.length = len;
    out.offset = pos;
    if (out.constructed) {
        if (!parse_seq(p, pos, len, out.children, depth)) return false;
    }
    pos += len;
    return true;
}

SEXP node_to_sexp(const Node &nd, const unsigned char *base) {
    const int nfield = 8;
    SEXP out = PROTECT(Rf_allocVector(VECSXP, nfield));
    SET_VECTOR_ELT(out, 0, Rf_ScalarInteger(
        static_cast<int>(nd.tag_class)));
    SET_VECTOR_ELT(out, 1, Rf_ScalarLogical(nd.constructed ? TRUE : FALSE));
    SET_VECTOR_ELT(out, 2, Rf_ScalarReal(static_cast<double>(nd.tag)));
    SET_VECTOR_ELT(out, 3, Rf_ScalarReal(static_cast<double>(nd.offset)));
    SET_VECTOR_ELT(out, 4, Rf_ScalarReal(static_cast<double>(nd.length)));
    SET_VECTOR_ELT(out, 5, Rf_ScalarReal(
        static_cast<double>(nd.offset - nd.header_len)));
    {
        /* the value bytes, for a primitive; a constructed node carries
         * its children instead */
        SEXP v = PROTECT(Rf_allocVector(RAWSXP,
            nd.constructed ? 0 : static_cast<R_xlen_t>(nd.length)));
        if (!nd.constructed && nd.length > 0) {
            std::memcpy(RAW(v), base + nd.offset, nd.length);
        }
        SET_VECTOR_ELT(out, 6, v);
        UNPROTECT(1);
    }
    {
        SEXP kids = PROTECT(Rf_allocVector(VECSXP,
            static_cast<R_xlen_t>(nd.children.size())));
        for (size_t i = 0; i < nd.children.size(); ++i) {
            SET_VECTOR_ELT(kids, static_cast<R_xlen_t>(i),
                           node_to_sexp(nd.children[i], base));
        }
        SET_VECTOR_ELT(out, 7, kids);
        UNPROTECT(1);
    }
    SEXP nm = PROTECT(Rf_allocVector(STRSXP, nfield));
    SET_STRING_ELT(nm, 0, Rf_mkChar("class"));
    SET_STRING_ELT(nm, 1, Rf_mkChar("constructed"));
    SET_STRING_ELT(nm, 2, Rf_mkChar("tag"));
    SET_STRING_ELT(nm, 3, Rf_mkChar("offset"));
    SET_STRING_ELT(nm, 4, Rf_mkChar("length"));
    SET_STRING_ELT(nm, 5, Rf_mkChar("start"));
    SET_STRING_ELT(nm, 6, Rf_mkChar("value"));
    SET_STRING_ELT(nm, 7, Rf_mkChar("children"));
    Rf_setAttrib(out, R_NamesSymbol, nm);
    UNPROTECT(2);
    return out;
}

/* ------------------------------------------------------------------ *
 * Just enough bignum for RSA verification: compare, subtract, multiply,
 * and remainder. Limbs are 32 bits, least significant first.
 * ------------------------------------------------------------------ */

typedef std::vector<uint32_t> Big;

void trim(Big &a) {
    while (a.size() > 1 && a.back() == 0) a.pop_back();
}

Big from_bytes(const unsigned char *p, size_t n) {
    Big a;
    /* big-endian in, little-endian limbs out */
    size_t i = n;
    while (i >= 4) {
        a.push_back(static_cast<uint32_t>(p[i - 1]) |
                    (static_cast<uint32_t>(p[i - 2]) << 8) |
                    (static_cast<uint32_t>(p[i - 3]) << 16) |
                    (static_cast<uint32_t>(p[i - 4]) << 24));
        i -= 4;
    }
    if (i > 0) {
        uint32_t v = 0;
        for (size_t k = 0; k < i; ++k) v = (v << 8) | p[k];
        a.push_back(v);
    }
    if (a.empty()) a.push_back(0);
    trim(a);
    return a;
}

void to_bytes(const Big &a, unsigned char *out, size_t n) {
    std::memset(out, 0, n);
    for (size_t i = 0; i < a.size(); ++i) {
        for (int b = 0; b < 4; ++b) {
            const size_t pos = i * 4 + static_cast<size_t>(b);
            if (pos >= n) continue;
            out[n - 1 - pos] = static_cast<unsigned char>(a[i] >> (8 * b));
        }
    }
}

int cmp(const Big &a, const Big &b) {
    if (a.size() != b.size()) return a.size() < b.size() ? -1 : 1;
    for (size_t i = a.size(); i-- > 0;) {
        if (a[i] != b[i]) return a[i] < b[i] ? -1 : 1;
    }
    return 0;
}

void sub_in_place(Big &a, const Big &b) {   /* a >= b */
    uint64_t borrow = 0;
    for (size_t i = 0; i < a.size(); ++i) {
        const uint64_t bv = (i < b.size()) ? b[i] : 0;
        const uint64_t cur = static_cast<uint64_t>(a[i]);
        uint64_t d = cur - bv - borrow;
        borrow = (cur < bv + borrow) ? 1 : 0;
        a[i] = static_cast<uint32_t>(d & 0xffffffffu);
    }
    trim(a);
}

Big mul(const Big &a, const Big &b) {
    Big r(a.size() + b.size(), 0);
    for (size_t i = 0; i < a.size(); ++i) {
        uint64_t carry = 0;
        for (size_t j = 0; j < b.size(); ++j) {
            const uint64_t cur = static_cast<uint64_t>(a[i]) * b[j] +
                                 r[i + j] + carry;
            r[i + j] = static_cast<uint32_t>(cur & 0xffffffffu);
            carry = cur >> 32;
        }
        size_t k = i + b.size();
        while (carry) {
            const uint64_t cur = static_cast<uint64_t>(r[k]) + carry;
            r[k] = static_cast<uint32_t>(cur & 0xffffffffu);
            carry = cur >> 32;
            ++k;
        }
    }
    trim(r);
    return r;
}

void shl1(Big &a) {
    uint32_t carry = 0;
    for (size_t i = 0; i < a.size(); ++i) {
        const uint32_t nc = a[i] >> 31;
        a[i] = (a[i] << 1) | carry;
        carry = nc;
    }
    if (carry) a.push_back(carry);
}

bool bit(const Big &a, size_t i) {
    const size_t limb = i / 32;
    if (limb >= a.size()) return false;
    return ((a[limb] >> (i % 32)) & 1u) != 0;
}

size_t bit_length(const Big &a) {
    for (size_t i = a.size(); i-- > 0;) {
        if (a[i] != 0) {
            uint32_t v = a[i];
            size_t b = 0;
            while (v) { ++b; v >>= 1; }
            return i * 32 + b;
        }
    }
    return 0;
}

/* a mod m, by shift-and-subtract. Slow by the standards of a real
 * bignum library and entirely fast enough: an RSA-2048 verification
 * with e = 65537 needs seventeen of these. */
Big mod(const Big &a, const Big &m) {
    if (cmp(a, m) < 0) return a;
    Big r;
    r.push_back(0);
    const size_t nb = bit_length(a);
    for (size_t i = nb; i-- > 0;) {
        shl1(r);
        if (bit(a, i)) {
            if (r.empty()) r.push_back(1);
            else r[0] |= 1u;
        }
        if (cmp(r, m) >= 0) sub_in_place(r, m);
    }
    trim(r);
    return r;
}

Big modexp(const Big &base, const Big &exp, const Big &m) {
    Big result;
    result.push_back(1);
    Big b = mod(base, m);
    const size_t nb = bit_length(exp);
    for (size_t i = nb; i-- > 0;) {
        result = mod(mul(result, result), m);
        if (bit(exp, i)) result = mod(mul(result, b), m);
    }
    return result;
}

}  // namespace

extern "C" {

/* The whole DER structure as nested lists: class, tag, offsets, the
 * value bytes of every primitive, and children. Navigation is the
 * caller's, which is the point -- the meaning of a field is a matter of
 * which specification you are reading, and that belongs in R next to
 * the OIDs it turns on. */
SEXP C_rmbl_der_parse(SEXP x) {
    if (TYPEOF(x) != RAWSXP) Rf_error("`x` must be a raw vector");
    const unsigned char *p = RAW(x);
    const size_t n = static_cast<size_t>(XLENGTH(x));
    size_t pos = 0;
    Node root;
    if (!parse_one(p, n, pos, root, 0)) {
        Rf_error("not well-formed DER");
    }
    if (pos != n) {
        Rf_error("trailing bytes after the DER structure: %d of %d consumed",
                 static_cast<int>(pos), static_cast<int>(n));
    }
    return node_to_sexp(root, p);
}

/* s^e mod n, with the result left-padded to the length of n. This is
 * the whole of the RSA operation for a verifier: the recovered block
 * comes back untouched for the caller to check. */
SEXP C_rmbl_rsa_recover(SEXP sig, SEXP modulus, SEXP exponent) {
    if (TYPEOF(sig) != RAWSXP || TYPEOF(modulus) != RAWSXP ||
        TYPEOF(exponent) != RAWSXP) {
        Rf_error("`sig`, `modulus` and `exponent` must be raw vectors");
    }
    if (XLENGTH(modulus) == 0 || XLENGTH(exponent) == 0 ||
        XLENGTH(sig) == 0) {
        Rf_error("`sig`, `modulus` and `exponent` must be non-empty");
    }
    if (XLENGTH(modulus) > 1024) {
        Rf_error("the modulus is implausibly large (%d bytes)",
                 static_cast<int>(XLENGTH(modulus)));
    }
    const Big s = from_bytes(RAW(sig), static_cast<size_t>(XLENGTH(sig)));
    const Big nn = from_bytes(RAW(modulus),
                              static_cast<size_t>(XLENGTH(modulus)));
    const Big e = from_bytes(RAW(exponent),
                             static_cast<size_t>(XLENGTH(exponent)));
    if (bit_length(nn) == 0) Rf_error("the modulus is zero");
    if (cmp(s, nn) >= 0) {
        Rf_error("the signature is not less than the modulus");
    }
    const Big r = modexp(s, e, nn);
    const size_t outlen = static_cast<size_t>(XLENGTH(modulus));
    SEXP out = PROTECT(Rf_allocVector(RAWSXP,
                                      static_cast<R_xlen_t>(outlen)));
    to_bytes(r, RAW(out), outlen);
    UNPROTECT(1);
    return out;
}

}  // extern "C"
