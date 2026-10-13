/*
 * rmbl_gunzip.c: gzip decompression that checks what R's gzfile() does not.
 *
 * gzfile() and gzcon() return whatever a truncated .gz decodes to, without an error or a warning,
 * so half an exposure CSV was read as a whole one (review of 02a38be, C3). Here zlib inflates
 * every member of the file (gzip -c a b > c and data.table::fwrite write several), checks each
 * member's CRC-32 and length trailer, and refuses: a stream that ends before its trailer, a CRC
 * or length that does not match, bytes after the last member that are not zero padding, and an
 * output larger than the caller's limit (checked while inflating, so a small file that would
 * expand to gigabytes is refused before it does).
 *
 * All memory, zlib's own state included, comes from R_alloc(), which R frees when the call
 * returns or errors: an R error anywhere in here leaks nothing.
 */
#include <R.h>
#include <Rinternals.h>
#include <string.h>
#include <zlib.h>

static voidpf rmbl_zalloc(voidpf opaque, uInt items, uInt size) {
    (void) opaque;
    return (voidpf) R_alloc((size_t) items, (int) size);
}
static void rmbl_zfree(voidpf opaque, voidpf address) { (void) opaque; (void) address; }

SEXP C_rmbl_gunzip_checked(SEXP in, SEXP max_out) {
    if (TYPEOF(in) != RAWSXP) error("the compressed data must be a raw vector");
    double lim = asReal(max_out);
    if (!R_FINITE(lim) || lim < 0) error("the output limit must be a non-negative number");
    const unsigned char *src = RAW(in);
    size_t n = (size_t) XLENGTH(in), pos = 0, len = 0, cap = n * 4 + 65536;
    if ((double) cap > lim + 1) cap = (size_t) lim + 1;
    unsigned char *out = (unsigned char *) R_alloc(cap, 1);
    const char *why = NULL;
    int members = 0;
    if (n > 0x7fffffffu) error("is larger than 2 GB compressed, which this reader does not take");
    while (why == NULL && pos < n) {
        if (members > 0) {                        /* after a member: zero padding, or the next member */
            size_t z = pos;
            while (z < n && src[z] == 0) z++;
            if (z == n) break;
            if (n - pos < 2 || src[pos] != 0x1f || src[pos + 1] != 0x8b) { why = "has bytes after the end of its gzip stream"; break; }
        }
        z_stream zs;
        memset(&zs, 0, sizeof zs);
        zs.zalloc = rmbl_zalloc; zs.zfree = rmbl_zfree;
        if (inflateInit2(&zs, 16 + MAX_WBITS) != Z_OK) { why = "could not start the gzip decoder"; break; }
        zs.next_in = (Bytef *) (src + pos);
        zs.avail_in = (uInt) ((n - pos) > 0x7fffffffu ? 0x7fffffffu : (n - pos));
        int rc = Z_OK;
        for (;;) {
            if (len == cap) {                     /* output full: grow, or refuse past the limit */
                if ((double) len > lim) { why = "decompresses to more than the size limit"; break; }
                size_t ncap = cap * 2;
                if ((double) ncap > lim + 1) ncap = (size_t) lim + 1;
                unsigned char *grown = (unsigned char *) R_alloc(ncap, 1);
                memcpy(grown, out, len);
                out = grown; cap = ncap;
            }
            zs.next_out = out + len;
            zs.avail_out = (uInt) ((cap - len) > 0x7fffffffu ? 0x7fffffffu : (cap - len));
            uInt room = zs.avail_out;
            rc = inflate(&zs, Z_NO_FLUSH);
            len += (size_t) (room - zs.avail_out);
            if (rc == Z_STREAM_END) break;
            if (rc != Z_OK && rc != Z_BUF_ERROR) break;
            if (zs.avail_out == 0) continue;      /* more output to come */
            if (zs.avail_in == 0) { rc = Z_BUF_ERROR; break; }  /* wants input there is none of */
        }
        if (why == NULL) {
            if (rc == Z_STREAM_END) { pos += (size_t) (zs.next_in - (src + pos)); members++; }
            else if (rc == Z_DATA_ERROR) why = (zs.msg && strstr(zs.msg, "check")) ? "fails its CRC-32 check (the file is damaged)" : "is not valid gzip data (the file is damaged)";
            else if (rc == Z_MEM_ERROR) why = "ran out of memory while decompressing";
            else if (rc == Z_BUF_ERROR) why = "is truncated: the gzip stream ends before its last block and checksum";
            else why = "could not be decompressed";
        }
        inflateEnd(&zs);
        if ((double) len > lim) why = "decompresses to more than the size limit";
    }
    if (why == NULL && members == 0) why = "is not gzip data";
    if (why != NULL) error("%s", why);
    SEXP res = PROTECT(allocVector(RAWSXP, (R_xlen_t) len));
    if (len) memcpy(RAW(res), out, len);
    UNPROTECT(1);
    return res;
}
