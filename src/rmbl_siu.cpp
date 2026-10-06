/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * rmbl_siu.cpp -- .Call glue over the vendored SIU parse/resolve core
 * (siu_parse.h / siu_resolve.h / siu_schema.h, canonical home: the `siu`
 * package). Same hand-rolled zero-dependency style as rmbl_core/rmbl_fetch:
 * no Rcpp, Rf_-prefixed API only.
 */
#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>

#include <string>

#include "siu_parse.h"
#include "siu_resolve.h"
#include "siu_schema.h"

namespace {

std::string as_string(SEXP x, const char *what) {
    if (TYPEOF(x) != STRSXP || Rf_xlength(x) != 1 ||
        STRING_ELT(x, 0) == NA_STRING) {
        Rf_error("%s must be a single non-NA character string", what);
    }
    /* an SIU report page is a few hundred KB; the parsers run regular
     * expressions over lines of it (normalize_text() caps the lines), and
     * the whole input is copied a dozen times on the way */
    if (LENGTH(STRING_ELT(x, 0)) > (2 << 20)) {
        Rf_error("%s is larger than 2 MiB: not a report page", what);
    }
    return std::string(CHAR(STRING_ELT(x, 0)));
}

}  // namespace

extern "C" {

SEXP C_rmbl_siu_html_to_text_impl(SEXP html) {
    const std::string out = siu::html_to_text(as_string(html, "html"));
    SEXP ans = PROTECT(Rf_allocVector(STRSXP, 1));
    SET_STRING_ELT(ans, 0, Rf_mkCharCE(out.c_str(), CE_UTF8));
    UNPROTECT(1);
    return ans;
}

SEXP C_rmbl_siu_parse_html_impl(SEXP html) {
    const siu::ParsedFields fields =
        siu::parse_report_html(as_string(html, "html"));
    const R_xlen_t n = static_cast<R_xlen_t>(fields.size());
    SEXP ans = PROTECT(Rf_allocVector(STRSXP, n));
    SEXP nms = PROTECT(Rf_allocVector(STRSXP, n));
    R_xlen_t i = 0;
    for (const auto &kv : fields) {
        SET_STRING_ELT(nms, i, Rf_mkCharCE(kv.first.c_str(), CE_UTF8));
        SET_STRING_ELT(ans, i, Rf_mkCharCE(kv.second.c_str(), CE_UTF8));
        ++i;
    }
    Rf_setAttrib(ans, R_NamesSymbol, nms);
    UNPROTECT(2);
    return ans;
}

SEXP C_rmbl_siu_to_iso_date_impl(SEXP human) {
    const std::string in = as_string(human, "x");
    /* a date string is a few dozen bytes; the regex engine is recursive and a
     * 100,000-character input overflowed the C stack */
    if (in.size() > 4096) {
        SEXP ans0 = PROTECT(Rf_allocVector(STRSXP, 1));
        SET_STRING_ELT(ans0, 0, Rf_mkCharCE("", CE_UTF8));
        UNPROTECT(1);
        return ans0;
    }
    const std::string out = siu::to_iso_date(in);
    SEXP ans = PROTECT(Rf_allocVector(STRSXP, 1));
    SET_STRING_ELT(ans, 0, Rf_mkCharCE(out.c_str(), CE_UTF8));
    UNPROTECT(1);
    return ans;
}

SEXP C_rmbl_siu_resolve_so_impl(SEXP text) {
    /* plain text from the caller: the same whitespace/line discipline the
     * HTML path gets, before any regex sees it */
    const siu::SoResolution res =
        siu::resolve_subject_officials(siu::normalize_text(as_string(text, "text")));
    SEXP ans = PROTECT(Rf_allocVector(VECSXP, 2));
    SEXP nms = PROTECT(Rf_allocVector(STRSXP, 2));
    SET_STRING_ELT(nms, 0, Rf_mkChar("count"));
    SET_STRING_ELT(nms, 1, Rf_mkChar("reason"));
    SEXP cnt = PROTECT(Rf_allocVector(INTSXP, 1));
    INTEGER(cnt)[0] = res.count.has_value() ? *res.count : NA_INTEGER;
    SEXP rsn = PROTECT(Rf_allocVector(STRSXP, 1));
    SET_STRING_ELT(rsn, 0, Rf_mkCharCE(res.reason.c_str(), CE_UTF8));
    SET_VECTOR_ELT(ans, 0, cnt);
    SET_VECTOR_ELT(ans, 1, rsn);
    Rf_setAttrib(ans, R_NamesSymbol, nms);
    UNPROTECT(4);
    return ans;
}

SEXP C_rmbl_siu_schema_impl(SEXP unused) {
    (void) unused;
    const auto &fields = siu::schema();
    const R_xlen_t n = static_cast<R_xlen_t>(fields.size());
    SEXP name = PROTECT(Rf_allocVector(STRSXP, n));
    SEXP is_count = PROTECT(Rf_allocVector(LGLSXP, n));
    SEXP desc = PROTECT(Rf_allocVector(STRSXP, n));
    for (R_xlen_t i = 0; i < n; ++i) {
        const siu::Field &f = fields[static_cast<size_t>(i)];
        SET_STRING_ELT(name, i, Rf_mkCharCE(f.name.c_str(), CE_UTF8));
        LOGICAL(is_count)[i] = f.is_count ? TRUE : FALSE;
        SET_STRING_ELT(desc, i, Rf_mkCharCE(f.desc.c_str(), CE_UTF8));
    }
    SEXP ans = PROTECT(Rf_allocVector(VECSXP, 3));
    SEXP nms = PROTECT(Rf_allocVector(STRSXP, 3));
    SET_STRING_ELT(nms, 0, Rf_mkChar("name"));
    SET_STRING_ELT(nms, 1, Rf_mkChar("is_count"));
    SET_STRING_ELT(nms, 2, Rf_mkChar("description"));
    SET_VECTOR_ELT(ans, 0, name);
    SET_VECTOR_ELT(ans, 1, is_count);
    SET_VECTOR_ELT(ans, 2, desc);
    Rf_setAttrib(ans, R_NamesSymbol, nms);
    UNPROTECT(5);
    return ans;
}

}  // extern "C"
