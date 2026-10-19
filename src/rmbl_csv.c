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
void rmbl_interrupt_raise_unbarriered(void);   /* rmbl_barrier.cpp: raise R's interrupt condition */

/* A Ctrl-C is looked for every 2^20 fields or blank records, whatever the shape: by rows, a wide table
 * ignored it for 53 s, and blank lines were never counted. It is raised as R's interrupt, not an
 * error (network stress test of 5e1dce5). Only R_alloc'd memory is live, which R frees on the jump. */
static void rmbl_csv_poll(size_t *work, size_t add) {
    *work += add;
    if (*work < ((size_t) 1 << 20)) return;
    *work = 0;
    /* the error is reached only under another package's barrier, which raises the interrupt itself */
    if (rmbl_interrupt_pending()) { rmbl_interrupt_raise_unbarriered(); error("interrupted (Ctrl-C)"); }
}

/* the fields of one record, as spans into the buffer: the field (inside its quotes when quoted),
 * and for a quoted field the blanks before its opening quote and the text after its closing one,
 * which read.csv() keeps around the unquoted text (" "x"" reads as " x", ""x" " as "x ") */
typedef struct { size_t start, len; int quoted; size_t pre_start, pre_len, post_start, post_len; } rmbl_span;

/* the bytes a field's text can take */
static size_t rmbl_span_len(const rmbl_span *sp) { return sp->pre_len + sp->len + sp->post_len; }

/* Scan one record from `pos`: fills `spans` (at most `cap`), returns the field count (which may
 * exceed `cap`: the caller sizes), advances `*pos` past the record's line ending, sets `*empty`
 * when the record was an empty line. `*err` names a malformed record. */
static size_t rmbl_csv_record(const unsigned char *s, size_t n, size_t *pos, rmbl_span *spans, size_t cap,
                              int *empty, const char **err) {
    size_t p = *pos, nf = 0;
    *empty = 0;
    /* with skipNul the NUL bytes are gone before the first record is scanned (C_rmbl_csv_split), so
     * a line that was nothing but NULs is an empty line here and "" with NULs inside is "" */
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
        sp.pre_start = sp.post_start = p;
        sp.pre_len = sp.post_len = 0;
        /* blanks before an opening quote: the field is quoted, the blanks are kept */
        size_t q = p;
        while (q < n && (s[q] == ' ' || s[q] == '\t')) q++;
        if (q < n && q > p && s[q] == '"') { sp.pre_len = q - p; p = q; }
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
            /* whatever follows up to the separator is part of the field, as read.csv() appends it
             * (it was refused here; network stress test of 5e1dce5) */
            sp.post_start = p;
            /* a quote there opens a quoted run again, as scan() reads it: a comma or a line end inside
             * it is text ("x"y",z" is the one field xy,z; it ended at the comma here) */
            int inq = 0;
            while (p < n && (inq || (s[p] != ',' && s[p] != '\n' && s[p] != '\r'))) {
                if (s[p] == '"') {
                    if (inq && p + 1 < n && s[p + 1] == '"') { p += 2; continue; }
                    inq = !inq;
                }
                p++;
            }
            if (inq) { *err = "a quoted field never closes"; return 0; }
            sp.post_len = p - sp.post_start;
        } else {
            while (p < n && s[p] != ',' && s[p] != '\n' && s[p] != '\r') {
                /* read.csv() takes a quote inside an unquoted field as the start of a quoted run and
                 * swallows the rest of the file into it (0 rows and a warning): refused in words */
                if (s[p] == '"') { *err = "a quote inside an unquoted field (ab\"c)"; return 0; }
                p++;
            }
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
    /* a line holding only "" is a blank line to read.csv(): skipped, not a row of NA; so is "" with
     * NUL bytes inside, which were dropped up front (it was a row of NA; CRAN stress test of 0.5.14) */
    if (nf == 1 && cap >= 1 && spans[0].quoted && rmbl_span_len(&spans[0]) == 0) {
        *empty = 2;   /* 2: a blank line that was "", which read.csv() still takes as a header */
        return 0;
    }
    return nf;
}

/* The field's text with doubled quotes undone and a CR or CRLF inside quotes made a newline (as
 * read.csv() reads the file in text mode), into `buf` (sized to rmbl_span_len). NUL bytes, under
 * skipNul, were dropped before the scan. */
static size_t rmbl_csv_field(const unsigned char *s, const rmbl_span *sp, char *buf) {
    size_t o = 0;
    for (size_t i = 0; i < sp->pre_len; i++) buf[o++] = (char) s[sp->pre_start + i];
    for (size_t i = 0; i < sp->len; i++) {
        unsigned char c = s[sp->start + i];
        if (sp->quoted && c == '"' && i + 1 < sp->len && s[sp->start + i + 1] == '"') i++;
        if (sp->quoted && c == '\r') {
            if (i + 1 < sp->len && s[sp->start + i + 1] == '\n') continue;
            c = '\n';
        }
        buf[o++] = (char) c;
    }
    /* after the closing quote scan() goes on reading quotes as quotes: "x"y"z" is xyz, and a doubled
     * quote inside a reopened one is one quote (it was xy"z" here; CRAN stress test of b617a3f) */
    int inq = 0;
    for (size_t i = 0; i < sp->post_len; i++) {
        unsigned char c = s[sp->post_start + i];
        if (c == '"') {
            if (inq && i + 1 < sp->post_len && s[sp->post_start + i + 1] == '"') { buf[o++] = '"'; i++; continue; }
            inq = !inq;
            continue;
        }
        if (inq && c == '\r') {   /* a CR or CRLF inside quotes is a newline, as in the quoted part */
            if (i + 1 < sp->post_len && s[sp->post_start + i + 1] == '\n') continue;
            c = '\n';
        }
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
    if (i >= len) return 0;
    /* leading zeros do not count against the ten digits: type.convert() reads 00000000000012 as the
     * integer 12 (it was a double here; CRAN stress test of b617a3f) */
    while (i + 1 < len && b[i] == '0') i++;
    if (len - i > 10) return 0;
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
    size_t n = (size_t) XLENGTH(bytes);
    /* read.csv(skipNul = TRUE) drops NUL bytes as it reads, before a quote or a line end is seen: a
     * quote, a NUL and a quote is a doubled quote, a NUL before a byte-order mark leaves the mark at
     * the start of its line (both read otherwise here; CRAN stress test of 0.5.14) */
    if (skip_nul && n && memchr(s, 0, n)) {
        unsigned char *t = (unsigned char *) R_alloc(n, 1);
        size_t m = 0;
        for (size_t i = 0; i < n; i++) if (s[i]) t[m++] = s[i];
        s = t;
        n = m;
    }
    size_t start = 0;
    /* a UTF-8 byte-order mark is not a column name, after blank lines too (read.csv() drops it from
     * the first line it reads); a header that is the mark alone is a header of no columns, as a
     * header of "" is */
    int quoted_blank_header = 0;
    {
        size_t q = 0;
        while (q < n && (s[q] == '\n' || s[q] == '\r')) q++;
        if (q + 3 <= n && s[q] == 0xEF && s[q + 1] == 0xBB && s[q + 2] == 0xBF) {
            start = q + 3;
            if (start == n || s[start] == '\n' || s[start] == '\r') {
                if (start < n && s[start] == '\r') start++;
                if (start < n && s[start] == '\n') start++;
                quoted_blank_header = 1;
            }
        }
    }
    const char *err = NULL;
    int empty = 1;
    /* the header: the first line with something on it */
    size_t cap = 64, pos = start, nh = 0;
    rmbl_span *spans = (rmbl_span *) R_alloc(cap, sizeof(rmbl_span));
    while (!quoted_blank_header && pos < n) {
        nh = rmbl_csv_record(s, n, &pos, spans, cap, &empty, &err);
        if (err) error("the CSV cannot be read: %s (in its header)", err);
        /* a header line of "" alone: read.csv() takes it as the header, a table of no columns, and
         * the lines below as its rows (here it was skipped and the first row became the header; CRAN
         * stress test of b617a3f). Its rows are counted below. */
        if (empty == 2) { quoted_blank_header = 1; nh = 0; break; }
        if (!empty) break;
    }
    /* a header line of blanks alone is a header of no columns to read.csv(), as "" is (it was one
     * column named X; re-test of the b617a3f CRAN stress fixes) */
    if (!quoted_blank_header && nh == 1 && !spans[0].quoted) {
        int blank = 1;
        const size_t a[3] = {spans[0].pre_start, spans[0].start, spans[0].post_start};
        const size_t l[3] = {spans[0].pre_len, spans[0].len, spans[0].post_len};
        for (int k = 0; k < 3 && blank; k++)
            for (size_t q = 0; q < l[k]; q++) if (s[a[k] + q] != ' ' && s[a[k] + q] != '\t') { blank = 0; break; }
        if (blank) { quoted_blank_header = 1; nh = 0; }
    }
    /* each field holds a span of 56 bytes and each column a vector: a 10-million-comma header asked
     * for 1.4 GB before a row was read (CRAN stress test of b617a3f) */
    if (nh > 1000000) {
        error("the header has %lu fields: more columns than this reader takes (at most a million)",
              (unsigned long) nh);
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
        size_t rows = 0, work = 0;
        while (quoted_blank_header && pos < n) {
            rmbl_csv_record(s, n, &pos, spans, cap, &empty, &err);
            rmbl_csv_poll(&work, 1);
            if (err) error("the CSV cannot be read: %s (record %lu)", err, (unsigned long) (rows + 2));
            if (!empty) rows++;
        }
        setAttrib(out, install("nrow"), ScalarReal((double) rows));
        UNPROTECT(2);
        return out;
    }
    const size_t ncol = nh;
    size_t maxlen = 0;
    for (size_t j = 0; j < ncol; j++) if (rmbl_span_len(&spans[j]) > maxlen) maxlen = rmbl_span_len(&spans[j]);
    /* read.csv() reads the header apart, and scan() then drops a byte-order mark at the start of
     * what follows, inside an opening quote too: a mark there is no part of the first row's first
     * field (`\ufeffT` read as text, a line of the mark alone as a row; re-test of the b617a3f CRAN
     * stress fixes). The header's spans point before it, so the bytes may be moved. */
    {
        size_t q = pos;   /* blank lines first: scan() skips them before it looks */
        while (q < n && (s[q] == '\n' || s[q] == '\r')) q++;
        if (q + 3 <= n && s[q] == 0xEF && s[q + 1] == 0xBB && s[q + 2] == 0xBF) {
            pos = q + 3;
        } else if (q + 5 <= n && s[q] == '"' && s[q + 1] == '"' && s[q + 2] == 0xEF && s[q + 3] == 0xBB &&
                   s[q + 4] == 0xBF) {
            /* after an empty quoted field the field is still empty, and scan() drops the mark there too:
             * a line of "" and the mark is a blank line (it was a row of the mark; CRAN stress test of
             * 0.5.14) */
            unsigned char *c = (unsigned char *) R_alloc(n - 3, 1);
            memcpy(c, s, q + 2);
            memcpy(c + q + 2, s + q + 5, n - q - 5);
            s = c;
            n -= 3;
        } else if (q + 4 <= n && s[q] == '"' && s[q + 1] == 0xEF && s[q + 2] == 0xBB && s[q + 3] == 0xBF) {
            unsigned char *c = (unsigned char *) R_alloc(n - 3, 1);
            memcpy(c, s, q + 1);
            memcpy(c + q + 1, s + q + 4, n - q - 4);
            s = c;
            n -= 3;
        }
    }
    const size_t body = pos;
    /* first pass: the rows are counted and each column's type decided, with no allocation */
    int *type = (int *) R_alloc(ncol, sizeof(int));
    int *word = (int *) R_alloc(ncol, sizeof(int));   /* a logical word was seen: a number after it is text */
    for (size_t j = 0; j < ncol; j++) { type[j] = RMBL_T_LGL; word[j] = 0; }
    char *buf = NULL;
    size_t bufcap = 0;
    size_t nrow = 0, work = 0;
    while (pos < n) {
        size_t nf = rmbl_csv_record(s, n, &pos, spans, cap, &empty, &err);
        rmbl_csv_poll(&work, nf + 1);
        if (err) error("the CSV cannot be read: %s (record %lu)", err, (unsigned long) (nrow + 2));
        if (empty) continue;
        if (nf > ncol) {
            error("record %lu has %lu fields where the header has %lu: not a table this reader takes",
                  (unsigned long) (nrow + 2), (unsigned long) nf, (unsigned long) ncol);
        }
        for (size_t j = 0; j < nf; j++) {
            const size_t fl = rmbl_span_len(&spans[j]);
            if (fl > maxlen) maxlen = fl;
            if (type[j] == RMBL_T_STR) continue;
            if (fl + 1 > bufcap) { bufcap = fl * 2 + 16; buf = (char *) R_alloc(bufcap, 1); }
            size_t len = rmbl_csv_field(s, &spans[j], buf);
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
    }
    /* short records are filled to the header's width, as read.csv(fill = TRUE) fills them; a wide header
     * over many short lines made 4e8 cells from a few megabytes (network stress test of 5e1dce5). A
     * cell present in the text takes at least one byte, so more cells than bytes and ten million is
     * mostly filling */
    if ((double) nrow * (double) ncol > (double) n + 1e7) {
        error("%lu records under a %lu-column header make %.3g cells from %lu bytes, mostly filling short "
              "records: not a table this reader takes", (unsigned long) nrow, (unsigned long) ncol,
              (double) nrow * (double) ncol, (unsigned long) n);
    }
    /* a logical column that mixed TRUE with 1 is text for type.convert(); a column with no value at
     * all is logical NA, as type.convert() makes it */
    buf = (char *) R_alloc(maxlen + 1, 1);
    SEXP names = PROTECT(allocVector(STRSXP, (R_xlen_t) ncol));
    pos = start;
    do { rmbl_csv_record(s, n, &pos, spans, cap, &empty, &err); } while (empty && pos < n);
    for (size_t j = 0; j < ncol; j++) {
        size_t len = rmbl_csv_field(s, &spans[j], buf);
        size_t b = 0;
        /* an unquoted name is trimmed, as read.csv() reads the header with strip.white = TRUE
         * (" Operational_Capacity " came out X.Operational_Capacity.; statistics stress test of
         * 5e1dce5); a quoted one keeps its blanks, as there */
        if (!spans[j].quoted) {
            while (b < len && (buf[b] == ' ' || buf[b] == '\t')) b++;
            while (len > b && (buf[len - 1] == ' ' || buf[len - 1] == '\t')) len--;
        } else {
            /* nor are the blanks outside a quoted name's quotes: ' "a" ,b' names a, as there (X.a.
             * here before; CRAN stress test of b617a3f) */
            b = spans[j].pre_len;
            size_t tail = 0;
            while (tail < spans[j].post_len && len > b &&
                   (buf[len - 1 - tail] == ' ' || buf[len - 1 - tail] == '\t')) tail++;
            len -= tail;
        }
        SET_STRING_ELT(names, (R_xlen_t) j, mkCharLenCE(buf + b, (int) (len - b), CE_NATIVE));
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
        rmbl_csv_poll(&work, ncol + 1);
        if (empty) continue;
        for (size_t j = 0; j < ncol; j++) {
            SEXP col = VECTOR_ELT(columns, (R_xlen_t) j);
            size_t len = j < nf ? rmbl_csv_field(s, &spans[j], buf) : 0;   /* a short record is filled */
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
    }
    SET_VECTOR_ELT(out, 0, names);
    SET_VECTOR_ELT(out, 1, columns);
    UNPROTECT(4);
    return out;
}
