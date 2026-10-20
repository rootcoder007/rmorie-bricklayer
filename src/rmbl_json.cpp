/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * A native path for the JSON parser in R/json_native.R. It parses a well-formed document into exactly
 * what .rmbl_json_parse() returns (nested lists, named for objects; strings in UTF-8; TRUE/FALSE; NULL;
 * an integer for a whole number in the integer range, a double otherwise). A whole number of 16 digits
 * or more follows the R parser's rules here (text when asked, else a double, with the inexact ones
 * reported back so R gives its warning); a duplicate key (unless they are kept) and nesting past 100
 * levels are refused with the R parser's words and the character position. What is left -- a syntax
 * error, a \u0000 or lone-surrogate escape, a control character in a string, a double written as a
 * whole number beyond 2^53 -- gives up (returns NULL) on a document of 128 KiB or less, so the R parser
 * says what it has always said, warnings included; past that size it is refused here with the reason,
 * since the R parser went one character at a time through R calls (85 s for a 15 MiB reply; CRAN
 * stress test of 0.5.14) and one bad byte at the end of a large reply cost minutes (final audit of
 * 1.0.0, #5). A staged bundle (which sources the R file without this library) parses in R.
 *
 * Every allocation is R's (R_alloc for scratch, freed when the .Call returns), so an allocation error
 * or an interrupt leaves nothing behind.
 */

#include <R.h>
#include <Rinternals.h>
#include <cstddef>
#include <cstdlib>
#include <cstring>
#include <cstdio>
#include "rmbl_entry.h"

extern "C" double rmbl_strtod_bytes(const char *s, size_t len, int *ok);

namespace {

struct Parser {
    const unsigned char *p;
    size_t n;
    size_t i;
    int depth;
    bool keep_dups;
    bool as_char;      /* a whole number beyond 2^53 is kept as text */
    bool fail;
    const char *why;   /* the first failure's reason, for a document too large for the R parser */
    size_t at;         /* ... and its byte offset */
    char dupkey[256];  /* the duplicate key, in the R parser's words */
    char bigtok[64];   /* the first inexact big integer written, for R's warning */
    unsigned long count;
};

/* the first failure's reason and place; the value the callers return */
inline SEXP failed(Parser &P, const char *why) {
    P.fail = true;
    if (!P.why) { P.why = why; P.at = P.i; }
    return R_NilValue;
}

/* the 1-based character (not byte) position of byte offset `at`, as the R parser counts */
R_xlen_t char_pos(const Parser &P, size_t at) {
    R_xlen_t c = 0;
    for (size_t k = 0; k < at && k < P.n; ++k) if ((P.p[k] & 0xC0) != 0x80) ++c;
    return c + 1;
}

/* valid UTF-8, as validUTF8() judges it: the direct .Call handed an invalid CHARSXP back
 * (final audit of 1.0.0, #11) */
bool valid_utf8(const unsigned char *s, size_t n) {
    size_t i = 0;
    while (i < n) {
        const unsigned char c = s[i];
        if (c < 0x80) { ++i; continue; }
        size_t len;
        unsigned cp;
        if ((c & 0xE0) == 0xC0) { len = 2; cp = c & 0x1F; }
        else if ((c & 0xF0) == 0xE0) { len = 3; cp = c & 0x0F; }
        else if ((c & 0xF8) == 0xF0) { len = 4; cp = c & 0x07; }
        else return false;
        if (i + len > n) return false;
        for (size_t k = 1; k < len; ++k) {
            if ((s[i + k] & 0xC0) != 0x80) return false;
            cp = (cp << 6) | (s[i + k] & 0x3F);
        }
        if ((len == 2 && cp < 0x80) || (len == 3 && cp < 0x800) || (len == 4 && cp < 0x10000) ||
            cp > 0x10FFFF || (cp >= 0xD800 && cp <= 0xDFFF)) return false;
        i += len;
    }
    return true;
}

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
    if (j >= P.n || P.p[j] < 0x20) { return failed(P, "unterminated or invalid string"); }
    if (P.p[j] == '"') {
        P.i = j + 1;
        return Rf_mkCharLenCE(reinterpret_cast<const char *>(P.p + st), static_cast<int>(j - st), CE_UTF8);
    }
    /* an escape: decode into scratch no longer than the rest of the input */
    size_t end = j;
    while (end < P.n && P.p[end] != '"') end += (P.p[end] == '\\') ? 2 : 1;
    if (end >= P.n) { return failed(P, "unterminated or invalid string"); }
    char *buf = R_alloc(end - st + 1, 1);
    size_t o = 0;
    size_t k = st;
    for (;;) {
        if (k >= P.n) { return failed(P, "unterminated or invalid string"); }
        const unsigned char c = P.p[k];
        if (c == '"') break;
        if (c < 0x20) { return failed(P, "unterminated or invalid string"); }
        if (c != '\\') { buf[o++] = static_cast<char>(c); ++k; continue; }
        if (k + 1 >= P.n) { return failed(P, "unterminated or invalid string"); }
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
                if (cp < 0) { return failed(P, "unterminated or invalid string"); }
                k += 4;
                if (cp >= 0xD800 && cp <= 0xDBFF && k + 6 <= P.n && P.p[k] == '\\' && P.p[k + 1] == 'u') {
                    const long lo = hex4(P, k + 2);
                    if (lo >= 0xDC00 && lo <= 0xDFFF) {
                        cp = 0x10000 + (cp - 0xD800) * 1024 + (lo - 0xDC00);
                        k += 6;
                    }
                }
                if (cp == 0 || (cp >= 0xD800 && cp <= 0xDFFF)) { return failed(P, "unterminated or invalid string"); }
                /* the escape is at least six bytes and a character at most four: the scratch suffices */
                o += put_utf8(buf + o, static_cast<unsigned long>(cp));
                break;
            }
            default: return failed(P, "unterminated or invalid string");
        }
    }
    P.i = k + 1;
    return Rf_mkCharLenCE(buf, static_cast<int>(o), CE_UTF8);
}

SEXP number_(Parser &P) {
    const size_t st = P.i;
    if (P.p[P.i] == '-') ++P.i;
    if (P.i >= P.n || P.p[P.i] < '0' || P.p[P.i] > '9') { return failed(P, "invalid number"); }
    if (P.p[P.i] == '0') ++P.i; else while (P.i < P.n && P.p[P.i] >= '0' && P.p[P.i] <= '9') ++P.i;
    bool isint = true;
    if (P.i < P.n && P.p[P.i] == '.') {
        isint = false;
        ++P.i;
        if (P.i >= P.n || P.p[P.i] < '0' || P.p[P.i] > '9') { return failed(P, "invalid number"); }
        while (P.i < P.n && P.p[P.i] >= '0' && P.p[P.i] <= '9') ++P.i;
    }
    if (P.i < P.n && (P.p[P.i] == 'e' || P.p[P.i] == 'E')) {
        isint = false;
        ++P.i;
        if (P.i < P.n && (P.p[P.i] == '+' || P.p[P.i] == '-')) ++P.i;
        if (P.i >= P.n || P.p[P.i] < '0' || P.p[P.i] > '9') { return failed(P, "invalid number"); }
        while (P.i < P.n && P.p[P.i] >= '0' && P.p[P.i] <= '9') ++P.i;
    }
    const size_t len = P.i - st;
    int ok = 0;
    const double v = rmbl_strtod_bytes(reinterpret_cast<const char *>(P.p + st), len, &ok);
    if (!ok) return failed(P, "invalid number");
    if (isint && len >= 16) {
        /* the R parser's rules for a whole number of 16 digits or more: its digits without the sign
         * and leading zeros; past 2^53 it is text when asked, else a double, and when the double does
         * not hold the digits written R warns once (the token is handed back for that). A 15 MiB reply
         * ending in one such number ran through the R parser for minutes (final audit of 1.0.0, #5) */
        size_t d0 = st;
        if (P.p[d0] == '-') ++d0;
        while (d0 + 1 < P.i && P.p[d0] == '0') ++d0;
        const size_t nd = P.i - d0;
        bool big = nd > 16;
        if (nd == 16) big = std::memcmp(P.p + d0, "9007199254740992", 16) > 0;
        if (big) {
            if (P.as_char) {
                return Rf_ScalarString(Rf_mkCharLenCE(reinterpret_cast<const char *>(P.p + st),
                                                      static_cast<int>(len), CE_UTF8));
            }
            if (R_FINITE(v) && !P.bigtok[0]) {
                char held[64];
                std::snprintf(held, sizeof held, "%.0f", v < 0 ? -v : v);
                if (std::strlen(held) != nd || std::memcmp(held, P.p + d0, nd) != 0) {
                    const size_t keep = len < sizeof P.bigtok - 1 ? len : sizeof P.bigtok - 1;
                    std::memcpy(P.bigtok, P.p + st, keep);
                    P.bigtok[keep] = '\0';
                }
            }
            return Rf_ScalarReal(v);
        }
    }
    if (isint) {
        if (v > 2147483647.0 || v < -2147483647.0) return Rf_ScalarReal(v);
        return Rf_ScalarInteger(static_cast<int>(v));
    }
    /* a double that holds a whole number in [2^53, 2^64) may be an identifier the R parser warns of:
     * the R parser's comparison of the digits written is left to it */
    const double a = v < 0 ? -v : v;
    /* (every double of 2^53 or more is a whole number) */
    if (R_FINITE(v) && a >= 9007199254740992.0 && a < 18446744073709551616.0) {
        return failed(P, "a whole number beyond 2^53 written as a decimal");
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

/* the first key, in document order, that repeats an earlier one (keys[duplicated(keys)][1] in the R
 * parser), or NULL */
SEXP first_dup(SEXP names, R_xlen_t k) {
    if (k < 2) return R_NilValue;
    SEXP *v = reinterpret_cast<SEXP *>(R_alloc(static_cast<size_t>(k), sizeof(SEXP)));
    for (R_xlen_t t = 0; t < k; ++t) v[t] = STRING_ELT(names, t);
    std::qsort(v, static_cast<size_t>(k), sizeof(SEXP), cmp_chars);
    SEXP dup = R_NilValue;
    for (R_xlen_t t = 1; t < k; ++t) if (cmp_chars(&v[t - 1], &v[t]) == 0) { dup = v[t]; break; }
    if (dup == R_NilValue) return R_NilValue;
    /* which repeated key comes first: the earliest second occurrence */
    for (R_xlen_t t = 1; t < k; ++t) {
        for (R_xlen_t u = 0; u < t; ++u) {
            if (STRING_ELT(names, t) == STRING_ELT(names, u)) return STRING_ELT(names, t);   /* CHARSXPs are cached */
        }
        if (t > 4096) break;   /* a huge object: the sorted scan said there is one; name the first repeat found */
    }
    return dup;
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
                if (P.i >= P.n || P.p[P.i] != '"') { failed(P, "expected a key in double quotes"); break; }
                key = string_(P);
                if (P.fail) break;
                PROTECT(key);
                ws(P);
                if (P.i >= P.n || P.p[P.i] != ':') { UNPROTECT(1); failed(P, "expected ':'"); break; }
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
            failed(P, obj ? "expected ',' or '}'" : "expected ',' or ']'");
            break;
        }
    }
    if (P.fail) { UNPROTECT(2); return R_NilValue; }
    if (obj && !P.keep_dups) {
        SEXP d = first_dup(nms, k);
        if (d != R_NilValue) {
            /* the R parser's refusal, at the position just past the object */
            std::snprintf(P.dupkey, sizeof P.dupkey, "%s", CHAR(d));
            UNPROTECT(2);
            return failed(P, "duplicate key");
        }
    }
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
    if (++P.depth > 100) { ws(P); return failed(P, "nesting deeper than 100 levels"); }
    if ((++P.count & 4095UL) == 0) rmbl::check_interrupt();
    ws(P);
    SEXP r = R_NilValue;
    if (P.i >= P.n) {
        failed(P, "unexpected end of the text");
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
            failed(P, "unexpected character");
        }
    }
    --P.depth;
    return P.fail ? R_NilValue : r;
}

}  // namespace

extern "C" {

/* list(value, bigtoken) for a document the fast path parses (bigtoken: the first inexact whole
 * number beyond 2^53, or NULL, for the R side's warning); NULL for the R parser to take; an error, in
 * the R parser's words, for a duplicate key, nesting past 100 levels, and, past 128 KiB, any failure */
SEXP C_rmbl_json_fast_impl(SEXP txt, SEXP keep_dups, SEXP bigint_as_char) {
    if (TYPEOF(txt) != STRSXP || XLENGTH(txt) != 1 || STRING_ELT(txt, 0) == NA_STRING) {
        RMBL_ARG_ERROR("`txt` must be one string");
    }
    /* the bytes as given: translateCharUTF8() in a C locale rewrote every byte past 0x7f as an
     * escape (<ff>), so a string that is not UTF-8 passed the check below and the C-locale check
     * failed; a latin1-marked string alone is translated (final audit of 1.0.0) */
    SEXP cs = STRING_ELT(txt, 0);
    const char *s = Rf_getCharCE(cs) == CE_LATIN1 ? Rf_translateCharUTF8(cs) : CHAR(cs);
    Parser P;
    P.p = reinterpret_cast<const unsigned char *>(s);
    P.n = std::strlen(s);
    P.i = 0;
    P.depth = 0;
    P.keep_dups = Rf_asLogical(keep_dups) == 1;
    P.as_char = Rf_asLogical(bigint_as_char) == 1;
    P.fail = false;
    P.why = nullptr;
    P.at = 0;
    P.dupkey[0] = '\0';
    P.bigtok[0] = '\0';
    P.count = 0;
    if (!valid_utf8(P.p, P.n)) RMBL_ARG_ERROR("the JSON text is not valid UTF-8");
    SEXP v = PROTECT(value(P));
    if (!P.fail) {
        ws(P);
        if (P.i < P.n) failed(P, "trailing characters");
    }
    if (P.fail) {
        UNPROTECT(1);
        const bool strict = P.n > 131072;
        if (P.dupkey[0]) {
            Rf_errorcall(R_NilValue, "duplicate key \"%s\" at character %lld", P.dupkey,
                         static_cast<long long>(char_pos(P, P.at)));
        }
        if (P.why && std::strcmp(P.why, "nesting deeper than 100 levels") == 0) {
            Rf_errorcall(R_NilValue, "%s at character %lld", P.why, static_cast<long long>(char_pos(P, P.at)));
        }
        if (strict) {
            Rf_errorcall(R_NilValue, "%s at character %lld", P.why ? P.why : "the JSON text could not be parsed",
                         static_cast<long long>(char_pos(P, P.at)));
        }
        return R_NilValue;
    }
    SEXP out = PROTECT(Rf_allocVector(VECSXP, 2));
    SET_VECTOR_ELT(out, 0, v);
    SET_VECTOR_ELT(out, 1, P.bigtok[0] ? Rf_mkString(P.bigtok) : R_NilValue);
    UNPROTECT(2);
    return out;
}

}  // extern "C"
