/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * rmbl_fetch.cpp -- the shared C++ data-fetch foundation for the morie
 * ecosystem. libcurl-backed HTTP with an Internet Archive (Wayback)
 * fallback: fetch a live URL, and if it fails (404 / network), retry the
 * archived snapshot so a rotated or removed source file stays retrievable.
 *
 * These are plain-C-linkable kernels (extern "C") so that:
 *   - rmoriebricklayer's own R wrappers reach them via .Call, and
 *   - sibling packages (rmoriedata, rmorie) reach them through
 *     `LinkingTo: rmoriebricklayer` + R_RegisterCCallable (see init.c), and
 *   - morie's Python side binds the SAME sources.
 *
 * One implementation, every language -- the ecosystem's C++-first rule.
 */

#include <R.h>
#include <Rinternals.h>
#include <curl/curl.h>
#include <cstdio>
#include <cstring>
#include <string>

namespace {

const char *kUA = "morie-bricklayer/1.0 (+https://github.com/rootcoder007/rmorie-bricklayer)";

size_t write_to_string(char *ptr, size_t sz, size_t nm, void *ud) {
    static_cast<std::string *>(ud)->append(ptr, sz * nm);
    return sz * nm;
}

size_t write_to_file(char *ptr, size_t sz, size_t nm, void *ud) {
    return std::fwrite(ptr, sz, nm, static_cast<std::FILE *>(ud));
}

/* GET a URL into a std::string. Returns HTTP status, or -1 on transport
 * failure. Follows redirects; hard total-timeout so nothing can hang. */
long http_get_string(const std::string &url, std::string &out, long timeout_s) {
    CURL *h = curl_easy_init();
    if (!h) return -1;
    out.clear();
    curl_easy_setopt(h, CURLOPT_URL, url.c_str());
    curl_easy_setopt(h, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(h, CURLOPT_TIMEOUT, timeout_s);
    curl_easy_setopt(h, CURLOPT_CONNECTTIMEOUT, 30L);
    curl_easy_setopt(h, CURLOPT_NOSIGNAL, 1L);
    curl_easy_setopt(h, CURLOPT_USERAGENT, kUA);
    curl_easy_setopt(h, CURLOPT_ACCEPT_ENCODING, "");
    curl_easy_setopt(h, CURLOPT_WRITEFUNCTION, write_to_string);
    curl_easy_setopt(h, CURLOPT_WRITEDATA, &out);
    CURLcode rc = curl_easy_perform(h);
    long code = -1;
    if (rc == CURLE_OK) curl_easy_getinfo(h, CURLINFO_RESPONSE_CODE, &code);
    curl_easy_cleanup(h);
    return (rc == CURLE_OK) ? code : -1;
}

/* GET a URL straight to a file path. Returns HTTP status, -1 on failure.
 * A 4xx/5xx still writes the error body; callers check the return code. */
long http_get_file(const std::string &url, const std::string &path, long timeout_s) {
    std::FILE *fp = std::fopen(path.c_str(), "wb");
    if (!fp) return -1;
    CURL *h = curl_easy_init();
    if (!h) { std::fclose(fp); return -1; }
    curl_easy_setopt(h, CURLOPT_URL, url.c_str());
    curl_easy_setopt(h, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(h, CURLOPT_TIMEOUT, timeout_s);
    curl_easy_setopt(h, CURLOPT_CONNECTTIMEOUT, 30L);
    curl_easy_setopt(h, CURLOPT_NOSIGNAL, 1L);
    curl_easy_setopt(h, CURLOPT_USERAGENT, kUA);
    curl_easy_setopt(h, CURLOPT_FAILONERROR, 1L);   /* 4xx -> CURLE_HTTP_RETURNED_ERROR */
    curl_easy_setopt(h, CURLOPT_WRITEFUNCTION, write_to_file);
    curl_easy_setopt(h, CURLOPT_WRITEDATA, fp);
    CURLcode rc = curl_easy_perform(h);
    long code = -1;
    curl_easy_getinfo(h, CURLINFO_RESPONSE_CODE, &code);
    curl_easy_cleanup(h);
    std::fclose(fp);
    if (rc != CURLE_OK) { std::remove(path.c_str()); return -1; }
    return code;
}

std::string url_encode(const std::string &s) {
    CURL *h = curl_easy_init();
    if (!h) return s;
    char *e = curl_easy_escape(h, s.c_str(), (int) s.size());
    std::string out = e ? e : s;
    if (e) curl_free(e);
    curl_easy_cleanup(h);
    return out;
}

/* Query the Wayback "available" API for the closest archived snapshot of
 * `url`. Returns the https snapshot URL, or "" if none is archived. Uses a
 * tiny hand-rolled extract (no JSON dep) -- the response shape is fixed:
 * {"archived_snapshots":{"closest":{..."url":"http://web.archive.org/..."}}} */
std::string wayback_snapshot(const std::string &url, long timeout_s) {
    std::string api = "https://archive.org/wayback/available?url=" + url_encode(url);
    std::string body;
    if (http_get_string(api, body, timeout_s) != 200) return "";
    size_t c = body.find("\"closest\"");
    if (c == std::string::npos) return "";
    /* require "available": true within the closest object */
    size_t avail = body.find("\"available\"", c);
    if (avail == std::string::npos) return "";
    size_t t = body.find("true", avail);
    if (t == std::string::npos || t - avail > 24) return "";
    /* extract the value of "url": the FIRST quoted string after "url": */
    size_t u = body.find("\"url\"", c);
    if (u == std::string::npos) return "";
    size_t colon = body.find(':', u + 5);
    if (colon == std::string::npos) return "";
    size_t open = body.find('"', colon + 1);   /* opening quote of value */
    if (open == std::string::npos) return "";
    size_t close = body.find('"', open + 1);    /* closing quote of value */
    if (close == std::string::npos) return "";
    std::string snap = body.substr(open + 1, close - open - 1);
    if (snap.rfind("http://", 0) == 0) snap = "https://" + snap.substr(7);
    return snap;
}

}  // namespace

extern "C" {

/* Download `url` to `path`; on failure, try `wayback` (if given) or an
 * auto-resolved Wayback snapshot. Returns:
 *   0  live URL succeeded
 *   1  live failed, wayback fallback succeeded
 *  -1  both failed (nothing written)
 */
int rmbl_fetch_with_fallback(const char *url, const char *wayback,
                             const char *path, int timeout_s) {
    long code = http_get_file(url, path, timeout_s);
    if (code >= 200 && code < 300) return 0;
    std::string wb = (wayback && wayback[0]) ? std::string(wayback)
                                             : wayback_snapshot(url, timeout_s);
    if (!wb.empty()) {
        long c2 = http_get_file(wb, path, timeout_s);
        if (c2 >= 200 && c2 < 300) return 1;
    }
    return -1;
}

/* Resolve a Wayback snapshot URL for `url` into `out` (size `cap`). Returns
 * strlen written (0 if none / truncated-safe). */
int rmbl_wayback_snapshot(const char *url, char *out, int cap, int timeout_s) {
    std::string s = wayback_snapshot(url, timeout_s);
    if (s.empty() || cap <= 0) { if (cap > 0) out[0] = '\0'; return 0; }
    int n = (int) s.size();
    if (n >= cap) n = cap - 1;
    std::memcpy(out, s.data(), n);
    out[n] = '\0';
    return n;
}

/* ---- .Call wrappers for bricklayer's own R side ------------------------ */

SEXP C_rmbl_fetch_fallback(SEXP url, SEXP wayback, SEXP path, SEXP timeout) {
    const char *u = CHAR(STRING_ELT(url, 0));
    const char *w = (wayback == R_NilValue || Rf_length(wayback) == 0)
                        ? "" : CHAR(STRING_ELT(wayback, 0));
    const char *p = CHAR(STRING_ELT(path, 0));
    int t = Rf_asInteger(timeout);
    return Rf_ScalarInteger(rmbl_fetch_with_fallback(u, w, p, t));
}

SEXP C_rmbl_wayback(SEXP url, SEXP timeout) {
    const char *u = CHAR(STRING_ELT(url, 0));
    char buf[2048];
    int n = rmbl_wayback_snapshot(u, buf, (int) sizeof(buf), Rf_asInteger(timeout));
    return Rf_ScalarString(n > 0 ? Rf_mkChar(buf) : R_BlankString);
}

}  // extern "C"
