/*
 * A CSV splitter for the curated tables: the bytes of a file become one character vector per
 * column, exactly as utils::read.csv() would read them before its type conversion, and R's
 * type.convert() does the rest. RFC 4180: fields separated by commas, a field in double quotes
 * may hold commas, quotes (doubled) and line breaks; CR, LF and CRLF end a record; a line with
 * nothing on it is skipped; a short record is padded with empty fields; NUL bytes are dropped
 * (skipNul = TRUE, some sources carry them). read.csv() read a 75 MB table in 20 to 28 s, most of
 * it in scan()'s per-field work; this takes a few seconds (review of 29a55d8 and after, CSV speed).
 *
 * What is refused, in words: a record with more fields than the header (read.csv() would take the
 * first column as row names, which no curated table asks for), and a quote that never closes.
 */
#include <R.h>
#include <Rinternals.h>
#include <string.h>
#include <R_ext/Utils.h>   /* R_strtod */

int rmbl_interrupt_pending(void);   /* rmbl_barrier.cpp: a Ctrl-C is pending */

/* the fields of one record, as (start, length, quoted) spans into the buffer */
typedef struct { size_t start, len; int quoted; } rmbl_span;

/* Scan one record from `pos`: fills `spans` (at most `cap`), returns the field count (which may
 * exceed `cap`: the caller sizes), advances `*pos` past the record's line ending, sets `*empty`
 * when the record was an empty line. `*err` names a malformed record. */
static size_t rmbl_csv_record(const unsigned char *s, size_t n, size_t *pos, rmbl_span *spans, size_t cap,
                              int *empty, const char **err) {
    size_t p = *pos, nf = 0;
    *empty = 0;
    if (p < n && (s[p] == '\n' || s[p] == '\r')) {
        *empty = 1;
        if (s[p] == '\r' && p + 1 < n && s[p + 1] == '\n') p++;
        *pos = p + 1;
        return 0;
    }
    for (;;) {
        rmbl_span sp;
        sp.start = p;
        sp.quoted = 0;
        if (p < n && s[p] == '"') {
            /* a quoted field: runs to the closing quote; a doubled quote is one quote (unescaped
             * by the caller), so the span keeps the inner bytes as they are */
            sp.quoted = 1;
            sp.start = ++p;
            for (;;) {
                if (p >= n) { *err = "a quoted field never closes"; return 0; }
                if (s[p] == '"') {
                    if (p + 1 < n && s[p + 1] == '"') { p += 2; continue; }
                    break;
                }
                p++;
            }
            sp.len = p - sp.start;
            p++;   /* the closing quote */
            /* whatever follows up to the separator is taken as part of the field by read.csv()
             * too (it appends it); the curated tables never do this, so it is refused in words */
            if (p < n && s[p] != ',' && s[p] != '\n' && s[p] != '\r') {
                *err = "a quoted field is followed by text before the next comma";
                return 0;
            }
        } else {
            while (p < n && s[p] != ',' && s[p] != '\n' && s[p] != '\r') p++;
            sp.len = p - sp.start;
        }
        if (nf < cap) spans[nf] = sp;
        nf++;
        if (p < n && s[p] == ',') { p++; continue; }
        break;
    }
    if (p < n) {
        if (s[p] == '\r' && p + 1 < n && s[p + 1] == '\n') p++;
        p++;
    }
    *pos = p;
    return nf;
}

/* The field's text with doubled quotes undone and NUL bytes dropped, into `buf` (sized to len). */
static size_t rmbl_csv_field(const unsigned char *s, const rmbl_span *sp, char *buf, int skip_nul) {
    size_t o = 0;
    for (size_t i = 0; i < sp->len; i++) {
        unsigned char c = s[sp->start + i];
        if (c == 0 && skip_nul) continue;
        if (sp->quoted && c == '"' && i + 1 < sp->len && s[sp->start + i + 1] == '"') i++;
        buf[o++] = (char) c;
    }
    return o;
}

/* What type.convert(as.is = TRUE) would make of a column, decided from the bytes: every field a
 * plain integer (fits an int), every field a plain decimal number, every field a logical word, or
 * else text, which R's type.convert() then judges (hex, Inf, 1d5 and the like are its business). An
 * empty field or NA is NA in a typed column, as type.convert() reads it. A field with any blank in
 * it goes the text way, so R decides. */
enum { RMBL_T_LGL = 0, RMBL_T_INT = 1, RMBL_T_NUM = 2, RMBL_T_STR = 3 };

static int rmbl_csv_is_na(const char *b, size_t len) { return len == 0 || (len == 2 && b[0] == 'N' && b[1] == 'A'); }

/* the words type.convert() reads as logical: TRUE, FALSE, T and F (not true or True: those are text) */
static int rmbl_csv_lgl(const char *b, size_t len, int *val) {
    if ((len == 4 && memcmp(b, "TRUE", 4) == 0) || (len == 1 && b[0] == 'T')) { *val = 1; return 1; }
    if ((len == 5 && memcmp(b, "FALSE", 5) == 0) || (len == 1 && b[0] == 'F')) { *val = 0; return 1; }
    return 0;
}

/* [+-]?digits, within int: the shape type.convert() reads as an integer (a longer run of digits is
 * a double there, so it is not taken here) */
static int rmbl_csv_int(const char *b, size_t len, int *val) {
    size_t i = 0;
    int neg = 0;
    if (len && (b[0] == '+' || b[0] == '-')) { neg = b[0] == '-'; i = 1; }
    if (i >= len || len - i > 10) return 0;
    long long v = 0;
    for (; i < len; i++) {
        if (b[i] < '0' || b[i] > '9') return 0;
        v = v * 10 + (b[i] - '0');
    }
    if (neg) v = -v;
    if (v > 2147483647LL || v < -2147483647LL) return 0;   /* -2^31 is NA_integer_ in R */
    *val = (int) v;
    return 1;
}

/* [+-]?(digits[.digits] | .digits)([eE][+-]?digits)?: read with R_strtod, as type.convert() does */
static int rmbl_csv_num(const char *b, size_t len, double *val) {
    size_t i = 0, nd = 0;
    if (len && (b[0] == '+' || b[0] == '-')) i = 1;
    while (i < len && b[i] >= '0' && b[i] <= '9') { i++; nd++; }
    if (i < len && b[i] == '.') { i++; while (i < len && b[i] >= '0' && b[i] <= '9') { i++; nd++; } }
    if (nd == 0) return 0;
    if (i < len && (b[i] == 'e' || b[i] == 'E')) {
        i++;
        if (i < len && (b[i] == '+' || b[i] == '-')) i++;
        size_t ne = 0;
        while (i < len && b[i] >= '0' && b[i] <= '9') { i++; ne++; }
        if (ne == 0) return 0;
    }
    if (i != len) return 0;
    char tmp[64];
    if (len >= sizeof tmp) return 0;
    memcpy(tmp, b, len);
    tmp[len] = '\0';
    char *end = NULL;
    *val = R_strtod(tmp, &end);
    return end == tmp + len;
}

/* list(names = <character>, columns = <list>): the header's fields and the records below it, as
 * read.csv() sees them after scan() and the type conversion that the bytes alone decide; a column
 * left as text is for R's type.convert(). A field reading NA, quoted or not, is NA, as scan()'s
 * na.strings make it after the quotes are removed. */
SEXP C_rmbl_csv_split(SEXP bytes, SEXP skip_nul_) {
    if (TYPEOF(bytes) != RAWSXP) error("the CSV text must be a raw vector");
    const int skip_nul = asLogical(skip_nul_) == TRUE;
    const unsigned char *s = RAW(bytes);
    const size_t n = (size_t) XLENGTH(bytes);
    size_t start = 0;
    /* a UTF-8 byte-order mark is not a column name */
    if (n >= 3 && s[0] == 0xEF && s[1] == 0xBB && s[2] == 0xBF) start = 3;
    const char *err = NULL;
    int empty = 1;
    /* the header: the first line with something on it */
    size_t cap = 64, pos = start, nh = 0;
    rmbl_span *spans = (rmbl_span *) R_alloc(cap, sizeof(rmbl_span));
    while (pos < n) {
        nh = rmbl_csv_record(s, n, &pos, spans, cap, &empty, &err);
        if (err) error("the CSV cannot be read: %s (in its header)", err);
        if (!empty) break;
    }
    if (nh > cap) {
        cap = nh;
        spans = (rmbl_span *) R_alloc(cap, sizeof(rmbl_span));
        pos = start;
        do { nh = rmbl_csv_record(s, n, &pos, spans, cap, &empty, &err); } while (!err && empty && pos < n);
    }
    SEXP out = PROTECT(allocVector(VECSXP, 2));
    SEXP nm = PROTECT(allocVector(STRSXP, 2));
    SET_STRING_ELT(nm, 0, mkChar("names"));
    SET_STRING_ELT(nm, 1, mkChar("columns"));
    setAttrib(out, R_NamesSymbol, nm);
    if (nh == 0) {
        SET_VECTOR_ELT(out, 0, allocVector(STRSXP, 0));
        SET_VECTOR_ELT(out, 1, allocVector(VECSXP, 0));
        UNPROTECT(2);
        return out;
    }
    const size_t ncol = nh;
    size_t maxlen = 0;
    for (size_t j = 0; j < ncol; j++) if (spans[j].len > maxlen) maxlen = spans[j].len;
    const size_t body = pos;
    /* first pass: the rows are counted and each column's type decided, with no allocation */
    int *type = (int *) R_alloc(ncol, sizeof(int));
    int *word = (int *) R_alloc(ncol, sizeof(int));   /* a logical word was seen: a number after it is text */
    for (size_t j = 0; j < ncol; j++) { type[j] = RMBL_T_LGL; word[j] = 0; }
    char *buf = NULL;
    size_t bufcap = 0;
    size_t nrow = 0;
    while (pos < n) {
        size_t nf = rmbl_csv_record(s, n, &pos, spans, cap, &empty, &err);
        if (err) error("the CSV cannot be read: %s (record %lu)", err, (unsigned long) (nrow + 2));
        if (empty) continue;
        if (nf > ncol) {
            error("record %lu has %lu fields where the header has %lu: not a table this reader takes",
                  (unsigned long) (nrow + 2), (unsigned long) nf, (unsigned long) ncol);
        }
        for (size_t j = 0; j < nf; j++) {
            if (spans[j].len > maxlen) maxlen = spans[j].len;
            if (type[j] == RMBL_T_STR) continue;
            if (spans[j].len + 1 > bufcap) { bufcap = spans[j].len * 2 + 16; buf = (char *) R_alloc(bufcap, 1); }
            size_t len = rmbl_csv_field(s, &spans[j], buf, skip_nul);
            if (rmbl_csv_is_na(buf, len)) continue;
            int iv; double dv;
            int blank = 0;
            for (size_t q = 0; q < len; q++) if (buf[q] == ' ' || buf[q] == '\t') { blank = 1; break; }
            if (blank) { type[j] = RMBL_T_STR; continue; }
            if (type[j] == RMBL_T_LGL && rmbl_csv_lgl(buf, len, &iv)) { word[j] = 1; continue; }
            if (word[j]) { type[j] = RMBL_T_STR; continue; }
            if (type[j] <= RMBL_T_INT && rmbl_csv_int(buf, len, &iv)) { type[j] = RMBL_T_INT; continue; }
            if (type[j] <= RMBL_T_NUM && rmbl_csv_num(buf, len, &dv)) { type[j] = RMBL_T_NUM; continue; }
            type[j] = RMBL_T_STR;
        }
        nrow++;
        if ((nrow & 0xffff) == 0 && rmbl_interrupt_pending()) error("interrupted (Ctrl-C)");
    }
    /* a logical column that mixed TRUE with 1 is text for type.convert(); a column with no value at
     * all is logical NA, as type.convert() makes it */
    buf = (char *) R_alloc(maxlen + 1, 1);
    SEXP names = PROTECT(allocVector(STRSXP, (R_xlen_t) ncol));
    pos = start;
    do { rmbl_csv_record(s, n, &pos, spans, cap, &empty, &err); } while (empty && pos < n);
    for (size_t j = 0; j < ncol; j++) {
        size_t len = rmbl_csv_field(s, &spans[j], buf, skip_nul);
        SET_STRING_ELT(names, (R_xlen_t) j, mkCharLenCE(buf, (int) len, CE_NATIVE));
    }
    SEXP columns = PROTECT(allocVector(VECSXP, (R_xlen_t) ncol));
    for (size_t j = 0; j < ncol; j++) {
        SEXPTYPE st = type[j] == RMBL_T_INT ? INTSXP : type[j] == RMBL_T_NUM ? REALSXP :
                      type[j] == RMBL_T_LGL ? LGLSXP : STRSXP;
        SET_VECTOR_ELT(columns, (R_xlen_t) j, allocVector(st, (R_xlen_t) nrow));
    }
    pos = body;
    size_t i = 0;
    while (pos < n) {
        size_t nf = rmbl_csv_record(s, n, &pos, spans, cap, &empty, &err);
        if (empty) continue;
        for (size_t j = 0; j < ncol; j++) {
            SEXP col = VECTOR_ELT(columns, (R_xlen_t) j);
            size_t len = j < nf ? rmbl_csv_field(s, &spans[j], buf, skip_nul) : 0;   /* a short record is filled */
            const int na = rmbl_csv_is_na(buf, len);
            switch (type[j]) {
            case RMBL_T_INT: { int v = NA_INTEGER; if (!na) rmbl_csv_int(buf, len, &v); INTEGER(col)[i] = v; break; }
            case RMBL_T_NUM: { double v = NA_REAL; if (!na) rmbl_csv_num(buf, len, &v); REAL(col)[i] = v; break; }
            case RMBL_T_LGL: { int v = NA_LOGICAL; if (!na) rmbl_csv_lgl(buf, len, &v); LOGICAL(col)[i] = v; break; }
            default:
                if (len == 2 && buf[0] == 'N' && buf[1] == 'A') SET_STRING_ELT(col, (R_xlen_t) i, NA_STRING);
                else SET_STRING_ELT(col, (R_xlen_t) i, mkCharLenCE(buf, (int) len, CE_NATIVE));
            }
        }
        i++;
        if ((i & 0xffff) == 0 && rmbl_interrupt_pending()) error("interrupted (Ctrl-C)");
    }
    SET_VECTOR_ELT(out, 0, names);
    SET_VECTOR_ELT(out, 1, columns);
    UNPROTECT(4);
    return out;
}
