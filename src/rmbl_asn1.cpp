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
#include <cstdio>
#include <cstring>
#include <exception>
#include <vector>

#include <R.h>
#include <Rinternals.h>
#include <new>
#include "rmbl_entry.h"

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
/* A structure this verifier should ever see has a few hundred nodes. The
 * cap is what stops a hostile length field from turning the parse into
 * unbounded work and allocation: every length is an adversary's input. */
const size_t kMaxNodes = static_cast<size_t>(1) << 16;

bool parse_one(const unsigned char *p, size_t n, size_t &pos, Node &out,
               int depth, size_t &budget);

bool parse_seq(const unsigned char *p, size_t start, size_t len,
               std::vector<Node> &out, int depth, size_t &budget) {
    size_t pos = start;
    const size_t end = start + len;       /* len <= n - start: no wrap */
    while (pos < end) {
        Node c;
        const size_t before = pos;
        if (!parse_one(p, end, pos, c, depth + 1, budget)) return false;
        if (pos <= before) return false;  /* a child always advances */
        out.push_back(c);
    }
    return pos == end;
}

bool parse_one(const unsigned char *p, size_t n, size_t &pos, Node &out,
               int depth, size_t &budget) {
    if (depth > 32) return false;          /* no unbounded recursion */
    if (budget == 0) return false;         /* no unbounded breadth either */
    --budget;
    if (pos >= n) return false;
    const size_t start = pos;
    unsigned char id = p[pos++];
    out.tag_class = static_cast<unsigned int>((id >> 6) & 0x03);
    out.constructed = ((id & 0x20) != 0);
    unsigned long tag = id & 0x1f;
    if (tag == 0x1f) {                      /* high tag number form */
        tag = 0;
        if (pos >= n) return false;
        if ((p[pos] & 0x7f) == 0) return false;  /* a leading zero septet: not the shortest form */
        for (;;) {
            if (pos >= n) return false;
            const unsigned char b = p[pos++];
            if (tag > (~0UL >> 7)) return false;
            tag = (tag << 7) | (b & 0x7f);
            if ((b & 0x80) == 0) break;
        }
        if (tag < 0x1f) return false;       /* 0..30 must use the one-byte form */
    }
    /* DER (X.690 10.1) has no end-of-contents octets, and a universal tag
     * 0 is exactly that: a BER artefact, never a value */
    if (out.tag_class == 0 && tag == 0) return false;
    out.tag = tag;
    if (pos >= n) return false;
    size_t len = p[pos++];
    if (len & 0x80) {
        const size_t nbytes = len & 0x7f;
        if (nbytes == 0) return false;      /* indefinite: not DER */
        /* sizeof(size_t) bytes could encode 2^64-1, and pos + len then
         * wrapped past every bound check below (a 22-byte file aborted R) */
        if (nbytes >= sizeof(size_t)) return false;
        if (nbytes > n - pos) return false;
        /* DER demands the shortest length encoding: no leading zero byte,
         * and the long form only for lengths of 128 and above. A verifier
         * that accepts both encodings of one length accepts two different
         * byte strings as the same signature. */
        if (p[pos] == 0) return false;
        if (nbytes == 1 && p[pos] < 0x80) return false;
        len = 0;
        for (size_t i = 0; i < nbytes; ++i) {
            len = (len << 8) | p[pos++];
        }
    }
    if (len > n - pos) return false;       /* the non-wrapping form */
    out.header_len = pos - start;
    out.length = len;
    out.offset = pos;
    if (out.constructed) {
        if (!parse_seq(p, pos, len, out.children, depth, budget)) return false;
    }
    pos += len;                            /* <= n, by the check above */
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
        const uint32_t w = static_cast<uint32_t>(p[i - 1]) | (static_cast<uint32_t>(p[i - 2]) << 8) |
                           (static_cast<uint32_t>(p[i - 3]) << 16) | (static_cast<uint32_t>(p[i - 4]) << 24);
        a.push_back(w);
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

static unsigned long rmbl_modexp_steps = 0;
Big modexp(const Big &base, const Big &exp, const Big &m) {
    Big result;
    result.push_back(1);
    Big b = mod(base, m);
    const size_t nb = bit_length(exp);
    for (size_t i = nb; i-- > 0;) {
        if ((++rmbl_modexp_steps & 63) == 0) rmbl::check_interrupt();
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
struct ConvCtx {
    Node *root;
    const unsigned char *base;
};
SEXP conv_run(void *d) {
    ConvCtx *c = static_cast<ConvCtx *>(d);
    return node_to_sexp(*c->root, c->base);
}
void conv_cleanup(void *d, Rboolean) {
    ConvCtx *c = static_cast<ConvCtx *>(d);
    delete c->root;
    c->root = NULL;
}

SEXP C_rmbl_der_parse_impl(SEXP x) {
    if (TYPEOF(x) != RAWSXP) Rf_error("`x` must be a raw vector");
    const unsigned char *p = RAW(x);
    const size_t n = static_cast<size_t>(XLENGTH(x));
    /* Two rules at this boundary. No C++ exception may cross it: a
     * std::bad_alloc that escapes an extern "C" function reaches
     * std::terminate, which no tryCatch() can intercept, and the R process
     * dies. And Rf_error() must not longjmp over a live Node tree: its
     * std::vector children would never be destroyed. So the tree lives in
     * its own block, the message is copied into a plain buffer, and the
     * error is raised only after the block has closed. */
    char err[128];
    err[0] = '\0';
    SEXP out = R_NilValue;
    /* The tree lives on the heap and is converted under R_UnwindProtect:
     * node_to_sexp() allocates R vectors, and an allocation failure there is
     * an R longjmp -- the cleanup deletes the tree on that path too, so no
     * destructor is skipped whichever way the block is left. */
    Node *root = new (std::nothrow) Node;
    if (!root) Rf_error("DER parser: out of memory");
    {
        size_t pos = 0;
        size_t budget = kMaxNodes;
        bool ok = false;
        try {
            ok = parse_one(p, n, pos, *root, 0, budget);
        } catch (const std::exception &e) {
            std::snprintf(err, sizeof err, "DER parser: %s", e.what());
        } catch (...) {
            std::snprintf(err, sizeof err, "DER parser: C++ exception");
        }
        if (err[0] == '\0' && !ok) {
            std::snprintf(err, sizeof err, "not well-formed DER");
        } else if (err[0] == '\0' && pos != n) {
            std::snprintf(err, sizeof err,
                          "trailing bytes after the DER structure: %d of %d consumed",
                          static_cast<int>(pos), static_cast<int>(n));
        }
    }
    if (err[0] != '\0') {
        delete root;
        Rf_error("%s", err);
    }
    ConvCtx ctx;
    ctx.root = root;
    ctx.base = p;
    out = R_UnwindProtect(conv_run, &ctx, conv_cleanup, &ctx, NULL);
    return out;
}

/* s^e mod n, with the result left-padded to the length of n. This is
 * the whole of the RSA operation for a verifier: the recovered block
 * comes back untouched for the caller to check. */
SEXP C_rmbl_rsa_recover_impl(SEXP sig, SEXP modulus, SEXP exponent) {
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
    /* modexp is linear in the exponent's bits. A public exponent is 3 or
     * 65537 in every deployed key (RFC 8017 allows larger, nothing issues
     * them); 64 bytes is already a thousand times that, and a megabyte
     * delivered in a hostile certificate was hours of uninterruptible work. */
    if (XLENGTH(exponent) > 64) {
        Rf_error("the public exponent is implausibly large (%d bytes)",
                 static_cast<int>(XLENGTH(exponent)));
    }
    /* the Big values are std::vectors: no Rf_error() while they live */
    const char *err = NULL;
    const size_t outlen = static_cast<size_t>(XLENGTH(modulus));
    SEXP out = PROTECT(Rf_allocVector(RAWSXP,
                                      static_cast<R_xlen_t>(outlen)));
    {
        const Big s = from_bytes(RAW(sig), static_cast<size_t>(XLENGTH(sig)));
        const Big nn = from_bytes(RAW(modulus),
                                  static_cast<size_t>(XLENGTH(modulus)));
        const Big e = from_bytes(RAW(exponent),
                                 static_cast<size_t>(XLENGTH(exponent)));
        if (bit_length(nn) == 0) {
            err = "the modulus is zero";
        } else if (cmp(s, nn) >= 0) {
            err = "the signature is not less than the modulus";
        } else {
            try {
                const Big r = modexp(s, e, nn);
                to_bytes(r, RAW(out), outlen);
            } catch (...) {
                err = "RSA recovery: C++ exception";
            }
        }
    }
    UNPROTECT(1);
    if (err) Rf_error("%s", err);
    return out;
}

}  // extern "C"
