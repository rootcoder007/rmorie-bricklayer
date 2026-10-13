/*
 * rmbl_gunzip.c: gzip decompression that checks what R's gzfile() does not.
 *
 * gzfile() and gzcon() return whatever a truncated .gz decodes to, without an error or a warning,
 * so half an exposure CSV was read as a whole one (review of 02a38be, C3). Here zlib inflates
 * every member of the file (gzip -c a b > c and data.table::fwrite write several), checks each
 * member's CRC-32 and length trailer, and refuses: a stream that ends before its trailer, a CRC
 * or length that does not match, bytes after the last member that are not zero padding, and an
 * output larger than the caller's limit.
 *
 * Memory is bounded by the output (review of e57fed5, E8): the file is inflated twice. The first
 * pass writes into one 64 kB scratch buffer, checks everything above and counts the output,
 * stopping as soon as the count passes the limit, so a small file that would expand to gigabytes
 * is refused having held 64 kB; the second pass inflates into the R vector, allocated once at its
 * exact size. One zlib state (and window) serves every member, reset between them: a million
 * empty members had taken a fresh 40 kB window each from R_alloc, 3.5 GB in all, and the doubling
 * output buffers were all kept until the call returned. More than RMBL_GUNZIP_MAX_MEMBERS members
 * are refused. No R error is raised while zlib holds memory: every failure is noted, the state
 * freed, and only then the error raised.
 */
#include <R.h>
#include <Rinternals.h>
#include <string.h>
#include <zlib.h>

#define RMBL_GUNZIP_MAX_MEMBERS 100000
#define RMBL_GUNZIP_SCRATCH 65536

/* zlib's word for a member it refused, said in the reader's terms */
static const char *rmbl_gunzip_why(int rc, const char *msg) {
    if (rc == Z_DATA_ERROR) {
        if (msg && strstr(msg, "incorrect data check")) return "fails its CRC-32 check (the file is damaged)";
        if (msg && strstr(msg, "incorrect length check")) {
            return "has a length trailer that does not match its data (the file is damaged)";
        }
        if (msg && strstr(msg, "header")) return "has a damaged gzip header";
        return "is not valid gzip data (the file is damaged)";
    }
    if (rc == Z_MEM_ERROR) return "ran out of memory while decompressing";
    if (rc == Z_BUF_ERROR) return "is truncated: the gzip stream ends before its last block and checksum";
    return "could not be decompressed";
}

/* One pass over every member. With `dst` NULL the output goes to `scratch` and is only counted
 * (stopping past `lim`); with `dst` it fills dst[0 .. cap). Returns NULL, or why the file is refused;
 * `*total` is the output size. */
static const char *rmbl_gunzip_pass(z_stream *zs, const unsigned char *src, size_t n, double lim,
                                    unsigned char *scratch, unsigned char *dst, size_t cap, size_t *total) {
    size_t pos = 0, len = 0;
    long members = 0;
    while (pos < n) {
        if (members > 0) {                        /* after a member: zero padding, or the next member */
            size_t z = pos;
            while (z < n && src[z] == 0) z++;
            if (z == n) break;
            if (n - pos < 2 || src[pos] != 0x1f || src[pos + 1] != 0x8b) return "has bytes after the end of its gzip stream";
            if (members >= RMBL_GUNZIP_MAX_MEMBERS) {
                return "has more than 100000 gzip members, which this reader does not take";
            }
        }
        if (inflateReset(zs) != Z_OK) return "could not restart the gzip decoder";
        zs->next_in = (Bytef *) (src + pos);
        zs->avail_in = (uInt) (n - pos);
        int rc = Z_OK;
        for (;;) {
            uInt room;
            /* the scratch buffer when counting, and also once the vector is full: inflate may need a
             * call with room to read the last trailer, and any byte it writes there is more output
             * than the first pass counted */
            const int spill = dst == NULL || len >= cap;
            if (spill) {
                zs->next_out = scratch;
                room = RMBL_GUNZIP_SCRATCH;
            } else {
                room = (uInt) ((cap - len) > 0x7fffffffu ? 0x7fffffffu : (cap - len));
                zs->next_out = dst + len;
            }
            zs->avail_out = room;
            rc = inflate(zs, Z_NO_FLUSH);
            len += (size_t) (room - zs->avail_out);
            if (dst != NULL && spill && room != zs->avail_out) return "decompressed differently on the second pass";
            if (dst == NULL && (double) len > lim) return "decompresses to more than the size limit";
            if (rc == Z_STREAM_END) break;
            if (rc != Z_OK && rc != Z_BUF_ERROR) break;
            if (zs->avail_out == 0) continue;     /* more output to come */
            if (zs->avail_in == 0) { rc = Z_BUF_ERROR; break; }  /* wants input there is none of */
        }
        if (rc != Z_STREAM_END) return rmbl_gunzip_why(rc, zs->msg);
        pos += (size_t) (zs->next_in - (src + pos));
        members++;
    }
    if (members == 0) return "is not gzip data";
    *total = len;
    return NULL;
}

SEXP C_rmbl_gunzip_checked(SEXP in, SEXP max_out) {
    if (TYPEOF(in) != RAWSXP) error("the compressed data must be a raw vector");
    const double lim = asReal(max_out);
    if (!R_FINITE(lim) || lim < 0) error("the output limit must be a non-negative number");
    const unsigned char *src = RAW(in);
    const size_t n = (size_t) XLENGTH(in);
    if (n > 0x7fffffffu) error("is larger than 2 GB compressed, which this reader does not take");
    if (n < 2 || src[0] != 0x1f || src[1] != 0x8b) error("is not gzip data (no gzip magic number)");
    /* the scratch buffer is R_alloc'd: R frees it when the call returns or errors */
    unsigned char *scratch = (unsigned char *) R_alloc(RMBL_GUNZIP_SCRATCH, 1);
    z_stream zs;
    memset(&zs, 0, sizeof zs);
    if (inflateInit2(&zs, 16 + MAX_WBITS) != Z_OK) error("could not start the gzip decoder");
    size_t total = 0;
    const char *why = rmbl_gunzip_pass(&zs, src, n, lim, scratch, NULL, 0, &total);
    inflateEnd(&zs);
    if (why != NULL) error("%s", why);
    /* nothing of zlib's is held here, so an allocation error leaks nothing */
    SEXP res = PROTECT(allocVector(RAWSXP, (R_xlen_t) total));
    if (total > 0) {
        memset(&zs, 0, sizeof zs);
        if (inflateInit2(&zs, 16 + MAX_WBITS) != Z_OK) error("could not start the gzip decoder");
        size_t got = 0;
        why = rmbl_gunzip_pass(&zs, src, n, lim, scratch, RAW(res), total, &got);
        inflateEnd(&zs);
        if (why == NULL && got != total) why = "decompressed differently on the second pass";
        if (why != NULL) error("%s", why);
    }
    UNPROTECT(1);
    return res;
}
