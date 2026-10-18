/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * A native path for the JSON parser in R/json_native.R. It parses a well-formed document into exactly
 * what .rmbl_json_parse() returns (nested lists, named for objects; strings in UTF-8; TRUE/FALSE; NULL;
 * an integer for a whole number in the integer range, a double otherwise) and gives up -- returns NULL,
 * so the R parser runs -- on everything else: a syntax error, nesting past 100 levels, a duplicate key
 * (unless they are kept), a whole number of 16 digits or more or a double that holds one beyond 2^53, a
 * \u0000 or lone-surrogate escape, a control character in a string. The R parser then says what it
 * has always said, warnings included, and a staged bundle (which sources the R file without this
 * library) parses the same way. The R parser went one character at a time through R calls: a 15 MiB
 * reply took 85 s (CRAN stress test of 0.5.14).
 *
 * Every allocation is R's (R_alloc for scratch, freed when the .Call returns), so an allocation error
 * or an interrupt leaves nothing behind.
 */

#include <R.h>
#include <Rinternals.h>
#include <cstddef>
#include <cstdlib>
#include <cstring>
#include "rmbl_entry.h"

extern "C" double rmbl_strtod_bytes(const char *s, size_t len, int *ok);

namespace {

struct Parser {
    const unsigned char *p;
    size_t n;
    size_t i;
    int depth;
    bool keep_dups;
    bool fail;
    unsigned long count;
};

inline void ws(Parser &P) {
    while (P.i < P.n) {
        const unsigned char c = P.p[P.i];
        if (c == ' ' || c == '\t' || c == '\n' || c == '\r') ++P.i; else break;
    }
}

inline int hexval(unsigned char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

/* the four hex digits at `at`, -1 when they are not */
int hex4(const Parser &P, size_t at) {
    if (at + 4 > P.n) return -1;
    int v = 0;
    for (size_t k = 0; k < 4; ++k) {
        const int h = hexval(P.p[at + k]);
        if (h < 0) return -1;
        v = v * 16 + h;
    }
    return v;
}

size_t put_utf8(char *o, unsigned long cp) {
    if (cp < 0x80) { o[0] = static_cast<char>(cp); return 1; }
    if (cp < 0x800) {
        o[0] = static_cast<char>(0xC0 | (cp >> 6));
        o[1] = static_cast<char>(0x80 | (cp & 0x3F));
        return 2;
    }
    if (cp < 0x10000) {
        o[0] = static_cast<char>(0xE0 | (cp >> 12));
        o[1] = static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
        o[2] = static_cast<char>(0x80 | (cp & 0x3F));
        return 3;
    }
    o[0] = static_cast<char>(0xF0 | (cp >> 18));
    o[1] = static_cast<char>(0x80 | ((cp >> 12) & 0x3F));
    o[2] = static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
    o[3] = static_cast<char>(0x80 | (cp & 0x3F));
    return 4;
}

/* the CHARSXP of the string whose opening quote is at P.i, or NULL (give up) */
SEXP string_(Parser &P) {
    size_t st = ++P.i;
    size_t j = st;
    while (j < P.n && P.p[j] != '"' && P.p[j] != '\\' && P.p[j] >= 0x20) ++j;
    if (j >= P.n || P.p[j] < 0x20) { P.fail = true; return R_NilValue; }
    if (P.p[j] == '"') {
        P.i = j + 1;
        return Rf_mkCharLenCE(reinterpret_cast<const char *>(P.p + st), static_cast<int>(j - st), CE_UTF8);
    }
    /* an escape: decode into scratch no longer than the rest of the input */
    size_t end = j;
    while (end < P.n && P.p[end] != '"') end += (P.p[end] == '\\') ? 2 : 1;
    if (end >= P.n) { P.fail = true; return R_NilValue; }
    char *buf = R_alloc(end - st + 1, 1);
    size_t o = 0;
    size_t k = st;
    for (;;) {
        if (k >= P.n) { P.fail = true; return R_NilValue; }
        const unsigned char c = P.p[k];
        if (c == '"') break;
        if (c < 0x20) { P.fail = true; return R_NilValue; }
        if (c != '\\') { buf[o++] = static_cast<char>(c); ++k; continue; }
        if (k + 1 >= P.n) { P.fail = true; return R_NilValue; }
        const unsigned char e = P.p[k + 1];
        k += 2;
        switch (e) {
            case 'n': buf[o++] = '\n'; break;
            case 't': buf[o++] = '\t'; break;
            case 'r': buf[o++] = '\r'; break;
            case 'b': buf[o++] = '\b'; break;
            case 'f': buf[o++] = '\f'; break;
            case '"': buf[o++] = '"'; break;
            case '\\': buf[o++] = '\\'; break;
            case '/': buf[o++] = '/'; break;
            case 'u': {
                long cp = hex4(P, k);
                if (cp < 0) { P.fail = true; return R_NilValue; }
                k += 4;
                if (cp >= 0xD800 && cp <= 0xDBFF && k + 6 <= P.n && P.p[k] == '\\' && P.p[k + 1] == 'u') {
                    const long lo = hex4(P, k + 2);
                    if (lo >= 0xDC00 && lo <= 0xDFFF) {
                        cp = 0x10000 + (cp - 0xD800) * 1024 + (lo - 0xDC00);
                        k += 6;
                    }
                }
                if (cp == 0 || (cp >= 0xD800 && cp <= 0xDFFF)) { P.fail = true; return R_NilValue; }
                /* the escape is at least six bytes and a character at most four: the scratch suffices */
                o += put_utf8(buf + o, static_cast<unsigned long>(cp));
                break;
            }
            default: P.fail = true; return R_NilValue;
        }
    }
    P.i = k + 1;
    return Rf_mkCharLenCE(buf, static_cast<int>(o), CE_UTF8);
}

SEXP number_(Parser &P) {
    const size_t st = P.i;
    if (P.p[P.i] == '-') ++P.i;
    if (P.i >= P.n || P.p[P.i] < '0' || P.p[P.i] > '9') { P.fail = true; return R_NilValue; }
    if (P.p[P.i] == '0') ++P.i; else while (P.i < P.n && P.p[P.i] >= '0' && P.p[P.i] <= '9') ++P.i;
    bool isint = true;
    if (P.i < P.n && P.p[P.i] == '.') {
        isint = false;
        ++P.i;
        if (P.i >= P.n || P.p[P.i] < '0' || P.p[P.i] > '9') { P.fail = true; return R_NilValue; }
        while (P.i < P.n && P.p[P.i] >= '0' && P.p[P.i] <= '9') ++P.i;
    }
    if (P.i < P.n && (P.p[P.i] == 'e' || P.p[P.i] == 'E')) {
        isint = false;
        ++P.i;
        if (P.i < P.n && (P.p[P.i] == '+' || P.p[P.i] == '-')) ++P.i;
        if (P.i >= P.n || P.p[P.i] < '0' || P.p[P.i] > '9') { P.fail = true; return R_NilValue; }
        while (P.i < P.n && P.p[P.i] >= '0' && P.p[P.i] <= '9') ++P.i;
    }
    const size_t len = P.i - st;
    /* 16 characters or more of a whole number may pass 2^53: the R parser's rules (a warning, text) */
    if (isint && len >= 16) { P.fail = true; return R_NilValue; }
    int ok = 0;
    const double v = rmbl_strtod_bytes(reinterpret_cast<const char *>(P.p + st), len, &ok);
    if (!ok) { P.fail = true; return R_NilValue; }
    if (isint) {
        if (v > 2147483647.0 || v < -2147483647.0) return Rf_ScalarReal(v);
        return Rf_ScalarInteger(static_cast<int>(v));
    }
    /* a double that holds a whole number in [2^53, 2^64) may be an identifier the R parser warns of */
    const double a = v < 0 ? -v : v;
    /* (every double of 2^53 or more is a whole number) */
    if (R_FINITE(v) && a >= 9007199254740992.0 && a < 18446744073709551616.0) {
        P.fail = true;
        return R_NilValue;
    }
    return Rf_ScalarReal(v);
}

SEXP value(Parser &P);

/* the CHARSXPs of the keys, sorted by bytes, compared neighbour to neighbour */
int cmp_chars(const void *a, const void *b) {
    SEXP x = *static_cast<SEXP const *>(a), y = *static_cast<SEXP const *>(b);
    const int lx = LENGTH(x), ly = LENGTH(y);
    const int c = std::memcmp(CHAR(x), CHAR(y), static_cast<size_t>(lx < ly ? lx : ly));
    if (c) return c;
    return (lx > ly) - (lx < ly);
}

bool has_dup(SEXP names, R_xlen_t k) {
    if (k < 2) return false;
    SEXP *v = reinterpret_cast<SEXP *>(R_alloc(static_cast<size_t>(k), sizeof(SEXP)));
    for (R_xlen_t t = 0; t < k; ++t) v[t] = STRING_ELT(names, t);
    std::qsort(v, static_cast<size_t>(k), sizeof(SEXP), cmp_chars);
    for (R_xlen_t t = 1; t < k; ++t) if (cmp_chars(&v[t - 1], &v[t]) == 0) return true;
    return false;
}

SEXP container(Parser &P, bool obj) {
    ++P.i;
    ws(P);
    const unsigned char close = obj ? '}' : ']';
    R_xlen_t cap = 8, k = 0;
    PROTECT_INDEX iv, inm;
    SEXP vals, nms = R_NilValue;
    PROTECT_WITH_INDEX(vals = Rf_allocVector(VECSXP, cap), &iv);
    PROTECT_WITH_INDEX(nms = obj ? Rf_allocVector(STRSXP, cap) : R_NilValue, &inm);
    if (P.i < P.n && P.p[P.i] == close) {
        ++P.i;
    } else {
        for (;;) {
            SEXP key = R_NilValue;
            if (obj) {
                ws(P);
                if (P.i >= P.n || P.p[P.i] != '"') { P.fail = true; break; }
                key = string_(P);
                if (P.fail) break;
                PROTECT(key);
                ws(P);
                if (P.i >= P.n || P.p[P.i] != ':') { UNPROTECT(1); P.fail = true; break; }
                ++P.i;
            }
            SEXP v = value(P);
            if (P.fail) { if (obj) UNPROTECT(1); break; }
            PROTECT(v);
            if (k == cap) {
                const R_xlen_t nc = cap * 2;
                SEXP nv = Rf_allocVector(VECSXP, nc);
                for (R_xlen_t t = 0; t < k; ++t) SET_VECTOR_ELT(nv, t, VECTOR_ELT(vals, t));
                REPROTECT(vals = nv, iv);
                if (obj) {
                    SEXP nn = Rf_allocVector(STRSXP, nc);
                    for (R_xlen_t t = 0; t < k; ++t) SET_STRING_ELT(nn, t, STRING_ELT(nms, t));
                    REPROTECT(nms = nn, inm);
                }
                cap = nc;
            }
            SET_VECTOR_ELT(vals, k, v);
            if (obj) SET_STRING_ELT(nms, k, key);
            ++k;
            UNPROTECT(obj ? 2 : 1);
            ws(P);
            if (P.i < P.n && P.p[P.i] == ',') { ++P.i; continue; }
            if (P.i < P.n && P.p[P.i] == close) { ++P.i; break; }
            P.fail = true;
            break;
        }
    }
    if (P.fail) { UNPROTECT(2); return R_NilValue; }
    if (obj && !P.keep_dups && has_dup(nms, k)) { P.fail = true; UNPROTECT(2); return R_NilValue; }
    SEXP out = PROTECT(Rf_allocVector(VECSXP, k));
    for (R_xlen_t t = 0; t < k; ++t) SET_VECTOR_ELT(out, t, VECTOR_ELT(vals, t));
    if (obj) {
        SEXP nn = PROTECT(Rf_allocVector(STRSXP, k));
        for (R_xlen_t t = 0; t < k; ++t) SET_STRING_ELT(nn, t, STRING_ELT(nms, t));
        Rf_setAttrib(out, R_NamesSymbol, nn);
        UNPROTECT(1);
    }
    UNPROTECT(3);
    return out;
}

SEXP value(Parser &P) {
    /* the R parser counts every value, a scalar too, and refuses past 100 */
    if (++P.depth > 100) { P.fail = true; return R_NilValue; }
    if ((++P.count & 4095UL) == 0) rmbl::check_interrupt();
    ws(P);
    SEXP r = R_NilValue;
    if (P.i >= P.n) {
        P.fail = true;
    } else {
        const unsigned char c = P.p[P.i];
        if (c == '{' || c == '[') {
            r = container(P, c == '{');
        } else if (c == '"') {
            SEXP s = string_(P);
            if (!P.fail) r = Rf_ScalarString(s);
        } else if (c == 't' && P.i + 4 <= P.n && std::memcmp(P.p + P.i, "true", 4) == 0) {
            P.i += 4;
            r = Rf_ScalarLogical(1);
        } else if (c == 'f' && P.i + 5 <= P.n && std::memcmp(P.p + P.i, "false", 5) == 0) {
            P.i += 5;
            r = Rf_ScalarLogical(0);
        } else if (c == 'n' && P.i + 4 <= P.n && std::memcmp(P.p + P.i, "null", 4) == 0) {
            P.i += 4;
        } else if (c == '-' || (c >= '0' && c <= '9')) {
            r = number_(P);
        } else {
            P.fail = true;
        }
    }
    --P.depth;
    return P.fail ? R_NilValue : r;
}

}  // namespace

extern "C" {

/* list(value) for a document the fast path parses, NULL for the R parser to take */
SEXP C_rmbl_json_fast_impl(SEXP txt, SEXP keep_dups) {
    if (TYPEOF(txt) != STRSXP || XLENGTH(txt) != 1 || STRING_ELT(txt, 0) == NA_STRING) {
        RMBL_ARG_ERROR("`txt` must be one string");
    }
    const char *s = Rf_translateCharUTF8(STRING_ELT(txt, 0));
    Parser P;
    P.p = reinterpret_cast<const unsigned char *>(s);
    P.n = std::strlen(s);
    P.i = 0;
    P.depth = 0;
    P.keep_dups = Rf_asLogical(keep_dups) == 1;
    P.fail = false;
    P.count = 0;
    SEXP v = PROTECT(value(P));
    if (!P.fail) {
        ws(P);
        if (P.i < P.n) P.fail = true;
    }
    if (P.fail) {
        UNPROTECT(1);
        return R_NilValue;
    }
    SEXP out = PROTECT(Rf_allocVector(VECSXP, 1));
    SET_VECTOR_ELT(out, 0, v);
    UNPROTECT(2);
    return out;
}

}  // extern "C"
