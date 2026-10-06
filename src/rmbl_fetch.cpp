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

/* C++ standard headers first: Rinternals.h defines a `length` macro that
 * breaks libc++'s <locale>, which <vector> pulls in on macOS. */
#include <cctype>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>
#include <cerrno>
#include <cstdlib>
#include <functional>
#include <chrono>
#include <R.h>
#include <Rinternals.h>
#include <curl/curl.h>
#include "rmbl_entry.h"
#ifdef _WIN32
#include <winsock2.h>
#include <ws2tcpip.h>
#else
#include <arpa/inet.h>
#include <netdb.h>
#include <netinet/in.h>
#include <sys/socket.h>
#endif

namespace {

const char *kUA = "morie-bricklayer/1.0 (+https://github.com/rootcoder007/rmorie-bricklayer)";

/* Caps every transfer gets. Redirects are bounded and pinned to http(s)
 * (a file:// URL, or a redirect to one, is refused), a download to a file
 * is bounded in size, and a response read into memory is bounded too:
 * write_to_string() appended without limit, so one hostile response could
 * exhaust memory. CURLOPT_PROTOCOLS_STR arrived in libcurl 7.85; older
 * builds take the bitmask form, so the pin holds everywhere. */
const curl_off_t kMaxDownload = static_cast<curl_off_t>(2) << 30;  /* 2 GiB */
const size_t kMaxBody = static_cast<size_t>(64) << 20;             /* 64 MiB */

/* ------------------------------------------------------------------ *
 * Where a request may go.
 *
 * Every URL this file fetches is checked HERE, in one place, before the
 * transport sees it, and again on every redirect: the resolvers hand the
 * package URLs a CKAN or Socrata record (or a tampered one) chose, so an
 * unchecked hop is a request to the cloud metadata service, a loopback
 * admin port or an internal mirror, made with this host's standing.
 *
 * The check does not pattern-match spellings. It parses the authority the
 * way a URL parser does (the host ends at the first "/", "?" or "#"; a "@"
 * anywhere in it is refused outright), reads an IPv4 literal with the
 * inet_aton grammar every stack accepts (127.1, 0177.0.0.1, 0x7f000001,
 * 2130706433 are all 127.0.0.1), parses IPv6 literals with inet_pton, and
 * for a hostname resolves it and tests every address it resolves to --
 * then pins the connection to exactly those addresses with CURLOPT_RESOLVE,
 * so a second lookup cannot answer differently (DNS rebinding). Redirects
 * are not followed by libcurl; each Location is run through the same check.
 * ------------------------------------------------------------------ */
struct UrlParts {
    std::string scheme, host, port;
    bool bracketed = false;
};

bool parse_url(const std::string &url, UrlParts &u, std::string &why) {
    const size_t p = url.find("://");
    if (p == std::string::npos || p == 0) { why = "no URL scheme"; return false; }
    u.scheme = url.substr(0, p);
    for (char &c : u.scheme) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    size_t a = p + 3;
    size_t e = url.find_first_of("/?#", a);
    if (e == std::string::npos) e = url.size();
    std::string auth = url.substr(a, e - a);
    if (auth.empty()) { why = "empty host"; return false; }
    if (auth.find('@') != std::string::npos) {
        why = "userinfo in the authority is refused";
        return false;
    }
    if (auth[0] == '[') {
        const size_t rb = auth.find(']');
        if (rb == std::string::npos) { why = "unterminated IPv6 literal"; return false; }
        u.host = auth.substr(1, rb - 1);
        u.bracketed = true;
        std::string rest = auth.substr(rb + 1);
        if (!rest.empty()) {
            if (rest[0] != ':') { why = "malformed authority"; return false; }
            u.port = rest.substr(1);
        }
    } else {
        const size_t c = auth.rfind(':');
        if (c != std::string::npos) { u.host = auth.substr(0, c); u.port = auth.substr(c + 1); }
        else u.host = auth;
    }
    for (char &c : u.host) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    if (!u.port.empty()) {
        for (char c : u.port) if (c < '0' || c > '9') { why = "malformed port"; return false; }
        if (u.port.size() > 5 || std::atoi(u.port.c_str()) > 65535) { why = "port out of range"; return false; }
    }
    if (u.host.empty()) { why = "empty host"; return false; }
    return true;
}

/* inet_aton semantics: 1-4 parts, each decimal, octal (leading 0) or hex
 * (0x); the last part fills the remaining bytes. Returns false when the
 * text is not an IPv4 literal at all (then it may be a hostname). */
bool ipv4_literal(const std::string &h, uint32_t &out) {
    std::vector<unsigned long> parts;
    size_t i = 0;
    while (i <= h.size()) {
        size_t j = h.find('.', i);
        if (j == std::string::npos) j = h.size();
        std::string t = h.substr(i, j - i);
        if (t.empty()) return false;
        int base = 10;
        if (t.size() > 1 && t[0] == '0' && (t[1] == 'x' || t[1] == 'X')) { base = 16; t = t.substr(2); if (t.empty()) return false; }
        else if (t.size() > 1 && t[0] == '0') { base = 8; }
        for (char c : t) {
            const bool ok = base == 16 ? std::isxdigit(static_cast<unsigned char>(c)) != 0
                          : base == 8 ? (c >= '0' && c <= '7') : (c >= '0' && c <= '9');
            if (!ok) return false;
        }
        errno = 0;
        char *end = nullptr;
        unsigned long v = std::strtoul(t.c_str(), &end, base);
        if (errno != 0 || (end && *end)) return false;
        parts.push_back(v);
        if (parts.size() > 4) return false;
        if (j == h.size()) break;
        i = j + 1;
    }
    if (parts.empty()) return false;
    const size_t n = parts.size();
    for (size_t k = 0; k + 1 < n; ++k) if (parts[k] > 255) return false;
    const int fill = static_cast<int>(4 - (n - 1));            /* bytes the last part covers */
    const unsigned long maxlast = fill == 4 ? 0xFFFFFFFFul : (1ul << (8 * fill)) - 1ul;
    if (parts[n - 1] > maxlast) return false;
    uint32_t v = 0;
    for (size_t k = 0; k + 1 < n; ++k) v = (v << 8) | static_cast<uint32_t>(parts[k]);
    /* fill == 4 only when the literal is one number: it is the whole address
     * (a shift by 32 of a 32-bit value is undefined) */
    v = (fill == 4) ? static_cast<uint32_t>(parts[0]) : ((v << (8 * fill)) | static_cast<uint32_t>(parts[n - 1]));
    out = v;
    return true;
}

/* loopback, unspecified, private, link-local, CGNAT, benchmark, documentation,
 * multicast and reserved: everything a request from this host must not reach
 * on a stranger's say-so */
bool ipv4_private(uint32_t a) {
    const uint32_t b0 = a >> 24, b1 = (a >> 16) & 0xff, b2 = (a >> 8) & 0xff;
    if (b0 == 0 || b0 == 10 || b0 == 127) return true;
    if (b0 == 100 && b1 >= 64 && b1 <= 127) return true;
    if (b0 == 169 && b1 == 254) return true;
    if (b0 == 172 && b1 >= 16 && b1 <= 31) return true;
    if (b0 == 192 && b1 == 0 && (b2 == 0 || b2 == 2)) return true;
    if (b0 == 192 && b1 == 88 && b2 == 99) return true;
    if (b0 == 192 && b1 == 168) return true;
    if (b0 == 198 && (b1 == 18 || b1 == 19)) return true;
    if (b0 == 198 && b1 == 51 && b2 == 100) return true;
    if (b0 == 203 && b1 == 0 && b2 == 113) return true;
    if (b0 >= 224) return true;
    return false;
}

bool ipv6_private(const unsigned char b[16]) {
    bool zero12 = true;
    for (int i = 0; i < 10; ++i) if (b[i]) zero12 = false;
    if (zero12 && b[10] == 0 && b[11] == 0) {
        /* ::, ::1 and ::a.b.c.d (deprecated compatible form): check as v4 */
        const uint32_t v4 = (static_cast<uint32_t>(b[12]) << 24) | (b[13] << 16) | (b[14] << 8) | b[15];
        if (v4 <= 1) return true;
        return ipv4_private(v4);
    }
    if (zero12 && b[10] == 0xff && b[11] == 0xff) {   /* ::ffff:a.b.c.d */
        const uint32_t v4 = (static_cast<uint32_t>(b[12]) << 24) | (b[13] << 16) | (b[14] << 8) | b[15];
        return ipv4_private(v4);
    }
    if (b[0] == 0 && b[1] == 0x64 && b[2] == 0xff && b[3] == 0x9b) { /* 64:ff9b::/96 NAT64 */
        bool mid = true;
        for (int i = 4; i < 12; ++i) if (b[i]) mid = false;
        if (mid) {
            const uint32_t v4 = (static_cast<uint32_t>(b[12]) << 24) | (b[13] << 16) | (b[14] << 8) | b[15];
            return ipv4_private(v4);
        }
    }
    if ((b[0] & 0xfe) == 0xfc) return true;                  /* fc00::/7 unique local */
    if (b[0] == 0xfe && (b[1] & 0xc0) == 0x80) return true;  /* fe80::/10 link-local */
    if (b[0] == 0xfe && (b[1] & 0xc0) == 0xc0) return true;  /* fec0::/10 site-local */
    if (b[0] == 0xff) return true;                           /* multicast */
    if (b[0] == 0x20 && b[1] == 0x01 && b[2] == 0x0d && b[3] == 0xb8) return true; /* 2001:db8::/32 */
    return false;
}

bool ipv6_literal(const std::string &h, unsigned char out[16]) {
    std::string t = h;
    const size_t z = t.find('%');            /* zone id */
    if (z != std::string::npos) t = t.substr(0, z);
    struct in6_addr a6;
    if (inet_pton(AF_INET6, t.c_str(), &a6) != 1) return false;
    std::memcpy(out, &a6, 16);
    return true;
}

/* a hostname is letters, digits and hyphens in dot-separated labels; the
 * names below are local by definition whatever DNS says */
bool hostname_ok(std::string &h, std::string &why) {
    if (!h.empty() && h.back() == '.') h.pop_back();
    if (h.empty() || h.size() > 253) { why = "malformed hostname"; return false; }
    size_t i = 0;
    bool all_digits_tld = true;
    while (i <= h.size()) {
        size_t j = h.find('.', i);
        if (j == std::string::npos) j = h.size();
        const size_t len = j - i;
        if (len == 0 || len > 63) { why = "malformed hostname"; return false; }
        all_digits_tld = true;
        for (size_t k = i; k < j; ++k) {
            const char c = h[k];
            /* '_' is outside RFC 1123 but common in deployed names (and harmless
             * to the checks here: it never forms an address) */
            const bool ok = (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-' || c == '_';
            if (!ok) { why = "hostname has characters outside letters, digits, hyphens and underscores"; return false; }
            if (c < '0' || c > '9') all_digits_tld = false;
        }
        if (h[i] == '-' || h[j - 1] == '-') { why = "malformed hostname"; return false; }
        if (j == h.size()) break;
        i = j + 1;
    }
    if (all_digits_tld) { why = "malformed address"; return false; }
    /* a public name has a registrable suffix: "metadata", "instance-data" and
     * every other single label resolve only inside some network (the cloud
     * metadata hosts among them), so the pre-flight refuses them by shape
     * without a DNS lookup */
    if (h.find('.') == std::string::npos) { why = "a single-label name is not a public host"; return false; }
    static const char *const kLocal[] = {"localhost", ".localhost", ".local", ".internal",
                                         ".localdomain", ".home.arpa", ".in-addr.arpa", ".ip6.arpa"};
    for (const char *suf : kLocal) {
        const std::string sfx(suf);
        if (sfx[0] != '.') { if (h == sfx) { why = "a local name"; return false; } continue; }
        if (h.size() >= sfx.size() && h.compare(h.size() - sfx.size(), sfx.size(), sfx) == 0) {
            why = "a local or internal name";
            return false;
        }
    }
    return true;
}

bool allow_http_option() {
    SEXP v = Rf_GetOption1(Rf_install("rmoriebricklayer.allow_http"));
    return v != R_NilValue && Rf_asLogical(v) == TRUE;
}

/* A local model server (Ollama on 127.0.0.1:11434) is plain http on the
 * loopback interface, which the policy refuses twice over. The R caller that
 * KNOWS the address came from the user's own environment sets
 * options(rmoriebricklayer.allow_loopback = TRUE) for the duration of that
 * one call: exactly the loopback host is admitted, nothing else private, and
 * a redirect off it meets the ordinary rules. */
bool allow_loopback_option() {
    SEXP v = Rf_GetOption1(Rf_install("rmoriebricklayer.allow_loopback"));
    return v != R_NilValue && Rf_asLogical(v) == TRUE;
}

bool loopback_host(const UrlParts &u) {
    if (u.bracketed) {
        unsigned char b[16];
        if (!ipv6_literal(u.host, b)) return false;
        for (int i = 0; i < 15; ++i) if (b[i]) return false;
        return b[15] == 1;
    }
    uint32_t a = 0;
    if (ipv4_literal(u.host, a)) return (a >> 24) == 127u;
    std::string h = u.host;
    for (char &c : h) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    return h == "localhost";
}

/* The whole check. `addrs` receives the dotted/colon addresses the host
 * resolved to (empty for a literal), for CURLOPT_RESOLVE. `resolve = false`
 * (the R validator's pre-flight) stops at the literal checks. Returns "" when
 * the URL may be fetched, else the reason. */
std::string url_check(const std::string &url, bool allow_http, bool resolve,
                      UrlParts *parts_out, std::vector<std::string> *addrs) {
    UrlParts u;
    std::string why;
    std::string sch;
    {
        const size_t p = url.find("://");
        sch = p == std::string::npos ? "" : url.substr(0, p);
        for (char &c : sch) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
        if (sch != "https" && sch != "http") return "scheme " + sch + ":// is refused";
    }
    if (!parse_url(url, u, why)) return why;
    if (allow_loopback_option() && loopback_host(u)) {
        if (parts_out) *parts_out = u;
        return "";
    }
    if (sch == "http" && !allow_http) {
        return "plain http is refused (options(rmoriebricklayer.allow_http = TRUE) admits a trusted mirror)";
    }
    uint32_t v4 = 0;
    unsigned char v6[16];
    if (u.bracketed) {
        if (!ipv6_literal(u.host, v6)) return "malformed IPv6 literal";
        if (ipv6_private(v6)) return "a local or private address (" + u.host + ")";
    } else if (ipv4_literal(u.host, v4)) {
        if (ipv4_private(v4)) return "a local or private address (" + u.host + ")";
    } else {
        if (!hostname_ok(u.host, why)) return why + " (" + u.host + ")";
        if (resolve) {
            struct addrinfo hints;
            std::memset(&hints, 0, sizeof hints);
            hints.ai_family = AF_UNSPEC;
            hints.ai_socktype = SOCK_STREAM;
            struct addrinfo *res = nullptr;
            if (getaddrinfo(u.host.c_str(), nullptr, &hints, &res) != 0 || !res) {
                return "could not resolve " + u.host;
            }
            std::string bad;
            for (struct addrinfo *ai = res; ai; ai = ai->ai_next) {
                char buf[INET6_ADDRSTRLEN];
                buf[0] = '\0';
                if (ai->ai_family == AF_INET) {
                    const struct sockaddr_in *sa = reinterpret_cast<const struct sockaddr_in *>(ai->ai_addr);
                    const uint32_t a = ntohl(sa->sin_addr.s_addr);
                    inet_ntop(AF_INET, &sa->sin_addr, buf, sizeof buf);
                    if (ipv4_private(a)) { bad = buf; break; }
                } else if (ai->ai_family == AF_INET6) {
                    const struct sockaddr_in6 *sa = reinterpret_cast<const struct sockaddr_in6 *>(ai->ai_addr);
                    unsigned char b[16];
                    std::memcpy(b, &sa->sin6_addr, 16);
                    inet_ntop(AF_INET6, &sa->sin6_addr, buf, sizeof buf);
                    if (ipv6_private(b)) { bad = buf; break; }
                } else {
                    continue;
                }
                if (addrs && buf[0]) addrs->push_back(buf);
            }
            freeaddrinfo(res);
            if (!bad.empty()) return u.host + " resolves to a local or private address (" + bad + ")";
            if (addrs && addrs->empty()) return "could not resolve " + u.host;
        }
    }
    if (parts_out) *parts_out = u;
    return "";
}

/* A request header that identifies the caller to the FIRST host and must not
 * travel to another one on a redirect (libcurl's own FOLLOWLOCATION drops
 * these across hosts; the hand-rolled loop here has to do the same). */
bool credential_header(const std::string &hdr) {
    std::string name = hdr.substr(0, hdr.find(':'));
    for (char &c : name) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    while (!name.empty() && name.back() == ' ') name.pop_back();
    return name == "authorization" || name == "cookie" || name == "proxy-authorization";
}

/* The redirect rule, as one pure function so it can be tested without a
 * network: `to` must pass the same URL check as a first request, an https
 * start may not be bounced to plain http (even when the option admits http),
 * and `drop_auth` says whether the credential headers must be left behind
 * (the host changed). Returns "" when the hop may be followed. */
std::string redirect_policy(const std::string &from, const std::string &to,
                            bool allow_http, bool resolve, bool *drop_auth,
                            UrlParts *to_parts, std::vector<std::string> *addrs) {
    UrlParts f;
    std::string why;
    if (!parse_url(from, f, why)) return "the request URL is malformed: " + why;
    std::string fs = f.scheme;
    for (char &c : fs) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    UrlParts t;
    why = url_check(to, allow_http && fs != "https", resolve, &t, addrs);
    if (!why.empty()) {
        std::string ts = to.substr(0, to.find("://"));
        for (char &c : ts) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
        if (fs == "https" && ts == "http") return "a redirect from https to plain http is refused";
        return why;
    }
    std::string fh = f.host, th = t.host;
    for (char &c : fh) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    for (char &c : th) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    if (drop_auth) *drop_auth = (fh != th);
    if (to_parts) *to_parts = t;
    return "";
}

/* One request, redirects included, every hop checked and pinned. `reset`
 * discards whatever a redirect response wrote to the sink. `headers` are the
 * request headers; the credential ones are sent to the first host only. */
CURLcode secure_perform(CURL *h, const std::string &start_url,
                        const std::function<void()> &reset, std::string *err,
                        const std::vector<std::string> *headers) {
    const bool allow_http = allow_http_option();
    std::string url = start_url;
    bool drop_auth = false;
    for (int hop = 0; hop <= 5; ++hop) {
        UrlParts u;
        std::vector<std::string> addrs;
        std::string why;
        if (hop == 0) {
            why = url_check(url, allow_http, true, &u, &addrs);
        } else {
            bool drop = false;
            why = redirect_policy(start_url, url, allow_http, true, &drop, &u, &addrs);
            drop_auth = drop_auth || drop;
        }
        if (!why.empty()) {
            if (err) *err = "refused: " + why;
            return CURLE_URL_MALFORMAT;
        }
        struct curl_slist *pin = nullptr;
        if (!addrs.empty()) {
            std::string entry = u.host + ":" + (u.port.empty() ? (u.scheme == "https" ? "443" : "80") : u.port) + ":";
            for (size_t i = 0; i < addrs.size(); ++i) entry += (i ? "," : "") + addrs[i];
            pin = curl_slist_append(nullptr, entry.c_str());
        }
        struct curl_slist *hdr = nullptr;
        if (headers) {
            for (const std::string &line : *headers) {
                if (drop_auth && credential_header(line)) continue;
                hdr = curl_slist_append(hdr, line.c_str());
            }
        }
        curl_easy_setopt(h, CURLOPT_URL, url.c_str());
        curl_easy_setopt(h, CURLOPT_RESOLVE, pin);
        curl_easy_setopt(h, CURLOPT_HTTPHEADER, hdr);
        const CURLcode rc = curl_easy_perform(h);
        long code = 0;
        if (rc == CURLE_OK) curl_easy_getinfo(h, CURLINFO_RESPONSE_CODE, &code);
        std::string next;
        if (rc == CURLE_OK && (code == 301 || code == 302 || code == 303 || code == 307 || code == 308)) {
            char *loc = nullptr;
            curl_easy_getinfo(h, CURLINFO_REDIRECT_URL, &loc);
            if (loc) next = loc;
        }
        curl_easy_setopt(h, CURLOPT_RESOLVE, static_cast<struct curl_slist *>(nullptr));
        curl_easy_setopt(h, CURLOPT_HTTPHEADER, static_cast<struct curl_slist *>(nullptr));
        if (pin) curl_slist_free_all(pin);
        if (hdr) curl_slist_free_all(hdr);
        if (next.empty()) return rc;
        if (hop == 5) {
            if (err) *err = "too many redirects";
            return CURLE_TOO_MANY_REDIRECTS;
        }
        /* a redirected POST becomes a GET, as every browser does; the
         * redirect's own body is not the answer */
        curl_easy_setopt(h, CURLOPT_HTTPGET, 1L);
        reset();
        url = next;
    }
    return CURLE_TOO_MANY_REDIRECTS;
}

/* Download progress: the R closure (bytes so far, total or 0) at most ten
 * times a second, and a pending Ctrl-C ends the transfer. */
struct Progress {
    SEXP fn;
    std::chrono::steady_clock::time_point last;
    bool first;
    bool interrupted;
    bool failed;
};

int xferinfo(void *ud, curl_off_t dltotal, curl_off_t dlnow, curl_off_t, curl_off_t) {
    Progress *p = static_cast<Progress *>(ud);
    if (rmbl_interrupt_pending()) {
        p->interrupted = true;
        return 1;
    }
    if (p->fn == R_NilValue) return 0;
    const auto now = std::chrono::steady_clock::now();
    if (!p->first && std::chrono::duration<double>(now - p->last).count() < 0.1) return 0;
    p->first = false;
    p->last = now;
    SEXP call = PROTECT(Rf_lang3(p->fn, Rf_ScalarReal(static_cast<double>(dlnow)),
                                 Rf_ScalarReal(static_cast<double>(dltotal))));
    int errored = 0;
    R_tryEvalSilent(call, R_GlobalEnv, &errored);
    UNPROTECT(1);
    if (errored) {
        p->failed = true;
        return 1;
    }
    return 0;
}

struct FileSink {
    std::FILE *fp;
    std::string path;
    curl_off_t written;
};

void harden(CURL *h) {
    /* redirects are followed by secure_perform(), one checked hop at a time */
    curl_easy_setopt(h, CURLOPT_FOLLOWLOCATION, 0L);
    curl_easy_setopt(h, CURLOPT_MAXREDIRS, 0L);
#if LIBCURL_VERSION_NUM >= 0x075500
    curl_easy_setopt(h, CURLOPT_PROTOCOLS_STR, "http,https");
    curl_easy_setopt(h, CURLOPT_REDIR_PROTOCOLS_STR, "http,https");
#else
    curl_easy_setopt(h, CURLOPT_PROTOCOLS, CURLPROTO_HTTP | CURLPROTO_HTTPS);
    curl_easy_setopt(h, CURLOPT_REDIR_PROTOCOLS, CURLPROTO_HTTP | CURLPROTO_HTTPS);
#endif
    curl_easy_setopt(h, CURLOPT_MAXFILESIZE_LARGE, kMaxDownload);
}

size_t write_to_string(char *ptr, size_t sz, size_t nm, void *ud) {
    std::string *s = static_cast<std::string *>(ud);
    if (s->size() + sz * nm > kMaxBody) return 0;  /* aborts the transfer */
    s->append(ptr, sz * nm);
    return sz * nm;
}

size_t write_to_file(char *ptr, size_t sz, size_t nm, void *ud) {
    FileSink *fs = static_cast<FileSink *>(ud);
    const size_t n = sz * nm;
    if (fs->written + static_cast<curl_off_t>(n) > kMaxDownload) return 0;  /* a chunked body has no Content-Length to cap */
    fs->written += static_cast<curl_off_t>(n);
    return std::fwrite(ptr, 1, n, fs->fp);
}

/* GET a URL into a std::string. Returns HTTP status, or -1 on transport
 * failure. Follows redirects; hard total-timeout so nothing can hang. */
long http_get_string(const std::string &url, std::string &out, long timeout_s) {
    CURL *h = curl_easy_init();
    if (!h) return -1;
    out.clear();
    curl_easy_setopt(h, CURLOPT_URL, url.c_str());
    harden(h);
    curl_easy_setopt(h, CURLOPT_TIMEOUT, timeout_s);
    curl_easy_setopt(h, CURLOPT_CONNECTTIMEOUT, 30L);
    curl_easy_setopt(h, CURLOPT_NOSIGNAL, 1L);
    curl_easy_setopt(h, CURLOPT_USERAGENT, kUA);
    curl_easy_setopt(h, CURLOPT_ACCEPT_ENCODING, "");
    curl_easy_setopt(h, CURLOPT_WRITEFUNCTION, write_to_string);
    curl_easy_setopt(h, CURLOPT_WRITEDATA, &out);
    CURLcode rc = secure_perform(h, url, [&out] { out.clear(); }, NULL, nullptr);
    long code = -1;
    if (rc == CURLE_OK) curl_easy_getinfo(h, CURLINFO_RESPONSE_CODE, &code);
    curl_easy_cleanup(h);
    return (rc == CURLE_OK) ? code : -1;
}

/* POST bytes to a URL and collect the reply as bytes.
 *
 * Exists for OCSP (RFC 6960 appendix A.1.1), which is the one thing
 * here that has to send a body: a responder identifies the certificate
 * being asked about from the DER request. The GET form, with the
 * request base64'd into the path, is optional for responders and many
 * refuse it, so a verifier limited to GET is a verifier that usually
 * cannot check revocation at all.
 */
long http_post_bytes(const std::string &url, const unsigned char *body,
                     size_t bodylen, const std::string &content_type,
                     std::string &out, long timeout_s,
                     const std::vector<std::string> &extra_headers,
                     std::string *err = NULL) {
    CURL *h = curl_easy_init();
    if (!h) return -1;
    out.clear();
    /* the request headers travel with secure_perform(), which drops the
     * credential ones on a cross-host redirect */
    std::vector<std::string> hdrs;
    hdrs.push_back("Content-Type: " + content_type);
    /* e.g. "Authorization: Bearer ..." for the hosted MORIE LLM tier */
    for (size_t i = 0; i < extra_headers.size(); ++i) hdrs.push_back(extra_headers[i]);
    /* libcurl would otherwise announce Expect: 100-continue and wait */
    hdrs.push_back("Expect:");
    curl_easy_setopt(h, CURLOPT_URL, url.c_str());
    curl_easy_setopt(h, CURLOPT_POST, 1L);
    curl_easy_setopt(h, CURLOPT_POSTFIELDS, body);
    curl_easy_setopt(h, CURLOPT_POSTFIELDSIZE,
                     static_cast<long>(bodylen));
    harden(h);
    curl_easy_setopt(h, CURLOPT_TIMEOUT, timeout_s);
    curl_easy_setopt(h, CURLOPT_CONNECTTIMEOUT, 30L);
    curl_easy_setopt(h, CURLOPT_NOSIGNAL, 1L);
    curl_easy_setopt(h, CURLOPT_USERAGENT, kUA);
    curl_easy_setopt(h, CURLOPT_WRITEFUNCTION, write_to_string);
    curl_easy_setopt(h, CURLOPT_WRITEDATA, &out);
    std::string refused;
    CURLcode rc = secure_perform(h, url, [&out] { out.clear(); }, &refused, &hdrs);
    long code = -1;
    if (rc == CURLE_OK) curl_easy_getinfo(h, CURLINFO_RESPONSE_CODE, &code);
    else if (err) *err = refused.empty() ? curl_easy_strerror(rc) : refused;  /* why no HTTP answer came */
    curl_easy_cleanup(h);
    return (rc == CURLE_OK) ? code : -1;
}

/* GET a URL into a string with extra headers (the bearer key of the hosted
 * MORIE tier). Returns HTTP status, -1 on failure. */
long http_get_string(const std::string &url, std::string &out, long timeout_s,
                     const std::vector<std::string> &extra_headers,
                     std::string *err = NULL) {
    CURL *h = curl_easy_init();
    if (!h) return -1;
    out.clear();
    curl_easy_setopt(h, CURLOPT_URL, url.c_str());
    curl_easy_setopt(h, CURLOPT_HTTPGET, 1L);
    harden(h);
    curl_easy_setopt(h, CURLOPT_TIMEOUT, timeout_s);
    curl_easy_setopt(h, CURLOPT_CONNECTTIMEOUT, 30L);
    curl_easy_setopt(h, CURLOPT_NOSIGNAL, 1L);
    curl_easy_setopt(h, CURLOPT_USERAGENT, kUA);
    curl_easy_setopt(h, CURLOPT_WRITEFUNCTION, write_to_string);
    curl_easy_setopt(h, CURLOPT_WRITEDATA, &out);
    std::string refused;
    CURLcode rc = secure_perform(h, url, [&out] { out.clear(); }, &refused, &extra_headers);
    long code = -1;
    if (rc == CURLE_OK) curl_easy_getinfo(h, CURLINFO_RESPONSE_CODE, &code);
    else if (err) *err = refused.empty() ? curl_easy_strerror(rc) : refused;
    curl_easy_cleanup(h);
    return (rc == CURLE_OK) ? code : -1;
}

/* GET a URL straight to a file path. Returns HTTP status, -1 on failure.
 * A 4xx/5xx still writes the error body; callers check the return code. */
/* `headers` and `progress` may be null / R_NilValue (the C API passes none).
 * The body is written beside the destination and moved over it only on a
 * 2xx, so a refused URL or a failed transfer leaves whatever was at `path`
 * untouched. `written` receives the byte count; `err` the refusal or curl
 * error; `interrupted` whether a pending Ctrl-C ended the transfer. */
long http_get_file(const std::string &url, const std::string &path, long timeout_s,
                   const std::vector<std::string> *headers, SEXP progress,
                   curl_off_t *written, std::string *err, bool *interrupted) {
    if (written) *written = 0;
    if (interrupted) *interrupted = false;
    {
        /* refuse before touching the file system (the transport checks and
         * pins again, hop by hop) */
        const std::string why = url_check(url, allow_http_option(), false, NULL, NULL);
        if (!why.empty()) {
            if (err) *err = "refused: " + why;
            return -1;
        }
    }
    const std::string part = path + ".rmbl-part";
    FileSink fs;
    fs.fp = std::fopen(part.c_str(), "wb");
    fs.path = part;
    fs.written = 0;
    if (!fs.fp) {
        if (err) *err = "cannot write " + part;
        return -1;
    }
    CURL *h = curl_easy_init();
    if (!h) { std::fclose(fs.fp); std::remove(part.c_str()); return -1; }
    curl_easy_setopt(h, CURLOPT_URL, url.c_str());
    harden(h);
    curl_easy_setopt(h, CURLOPT_TIMEOUT, timeout_s);
    curl_easy_setopt(h, CURLOPT_CONNECTTIMEOUT, 30L);
    curl_easy_setopt(h, CURLOPT_NOSIGNAL, 1L);
    curl_easy_setopt(h, CURLOPT_USERAGENT, kUA);
    curl_easy_setopt(h, CURLOPT_WRITEFUNCTION, write_to_file);
    curl_easy_setopt(h, CURLOPT_WRITEDATA, &fs);
    Progress prog;
    prog.fn = progress ? progress : R_NilValue;
    prog.last = std::chrono::steady_clock::now();
    prog.first = true;
    prog.interrupted = false;
    prog.failed = false;
    curl_easy_setopt(h, CURLOPT_NOPROGRESS, 0L);
    curl_easy_setopt(h, CURLOPT_XFERINFOFUNCTION, xferinfo);
    curl_easy_setopt(h, CURLOPT_XFERINFODATA, &prog);
    std::string refused;
    CURLcode rc = secure_perform(h, url, [&fs] {
        /* a redirect response's body is not the file: start over */
        std::FILE *re = std::freopen(fs.path.c_str(), "wb", fs.fp);
        if (re) fs.fp = re;
        fs.written = 0;
    }, &refused, headers);
    long code = -1;
    curl_easy_getinfo(h, CURLINFO_RESPONSE_CODE, &code);
    curl_easy_cleanup(h);
    std::fclose(fs.fp);
    if (written) *written = fs.written;
    if (interrupted) *interrupted = prog.interrupted;
    /* a completed transfer with a 4xx/5xx status is the server's answer: report the status,
     * not "never reached" (read from the response itself, not from FAILONERROR, whose
     * error code differs across libcurl builds and protocols; macOS reported a 404 as -1) */
    if (rc == CURLE_OK && code >= 400) {
        std::remove(part.c_str());
        if (err) *err = "HTTP " + std::to_string(code);
        return code;
    }
    if (rc != CURLE_OK) {
        std::remove(part.c_str());
        if (err) {
            *err = prog.interrupted ? "interrupted"
                 : prog.failed ? "the progress callback failed"
                 : refused.empty() ? curl_easy_strerror(rc) : refused;
        }
        return -1;
    }
    /* move the finished body over the destination (rename cannot replace on
     * Windows, so clear the destination first) */
    std::remove(path.c_str());
    if (std::rename(part.c_str(), path.c_str()) != 0) {
        std::remove(part.c_str());
        if (err) *err = "cannot move the download into place at " + path;
        return -1;
    }
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
    /* the availability API answers 429 / 5xx now and then: one more try before "no snapshot" */
    if (http_get_string(api, body, timeout_s) != 200) {
        body.clear();
        if (http_get_string(api, body, timeout_s) != 200) return "";
    }
    size_t c = body.find("\"closest\"");
    if (c == std::string::npos) return "";
    /* require "available": true within the closest object */
    size_t avail = body.find("\"available\"", c);
    if (avail == std::string::npos) return "";
    /* the value right after the colon must be the literal true: a string
     * value containing "true" within 24 bytes used to satisfy this */
    size_t colon0 = body.find(':', avail);
    if (colon0 == std::string::npos) return "";
    size_t v0 = colon0 + 1;
    while (v0 < body.size() && (body[v0] == ' ' || body[v0] == '\t' ||
                                body[v0] == '\n' || body[v0] == '\r')) ++v0;
    if (body.compare(v0, 4, "true") != 0) return "";
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
    /* anything that is not an https URL is not a snapshot to fetch */
    if (snap.rfind("https://", 0) != 0) return "";
    return snap;
}

}  // namespace

extern "C" {

/* Download `url` to `path`; on failure, try `wayback` (if given) or an
 * auto-resolved Wayback snapshot. Returns:
 *   0  live URL succeeded
 *   1  live failed, wayback fallback succeeded
 *  <0  both failed (nothing written): -(10 * live + w), where live is the
 *      live URL's HTTP status (1 when the server was never reached) and
 *      w is 1 when a snapshot was found but its download failed, 0 when
 *      the Wayback Machine had none (so the caller can say which).
 */
int rmbl_fetch_with_fallback(const char *url, const char *wayback,
                             const char *path, int timeout_s) {
    long code = http_get_file(url, path, timeout_s, nullptr, R_NilValue, nullptr, nullptr, nullptr);
    if (code >= 200 && code < 300) return 0;
    std::string wb = (wayback && wayback[0]) ? std::string(wayback)
                                             : wayback_snapshot(url, timeout_s);
    if (!wb.empty()) {
        long c2 = http_get_file(wb, path, timeout_s, nullptr, R_NilValue, nullptr, nullptr, nullptr);
        if (c2 >= 200 && c2 < 300) return 1;
    }
    long live = code > 0 ? code : 1;
    return (int) -(10 * live + (wb.empty() ? 0 : 1));
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

/* POST raw bytes, return the reply as raw bytes and the HTTP status.
 * Used only by the OCSP path, which is opt-in. */
SEXP C_rmbl_http_post_impl(SEXP url, SEXP body, SEXP content_type,
                      SEXP timeout, SEXP headers) {
    if (TYPEOF(url) != STRSXP || XLENGTH(url) != 1) {
        Rf_error("`url` must be a single string");
    }
    if (TYPEOF(body) != RAWSXP) Rf_error("`body` must be a raw vector");
    if (TYPEOF(content_type) != STRSXP || XLENGTH(content_type) != 1) {
        Rf_error("`content_type` must be a single string");
    }
    const long tmo = (TYPEOF(timeout) == INTSXP && XLENGTH(timeout) == 1)
        ? static_cast<long>(INTEGER(timeout)[0]) : 30L;
    std::vector<std::string> extra;
    if (TYPEOF(headers) == STRSXP) {
        for (R_xlen_t i = 0; i < XLENGTH(headers); ++i) {
            extra.push_back(rmbl_str_at(headers, i, "headers"));
        }
    } else if (headers != R_NilValue) {
        Rf_error("`headers` must be a character vector or NULL");
    }
    std::string out, err;
    const long code = http_post_bytes(
        rmbl_str0(url, "url"), RAW(body),
        static_cast<size_t>(XLENGTH(body)),
        rmbl_str0(content_type, "content_type"), out, tmo, extra, &err);
    SEXP res = PROTECT(Rf_allocVector(VECSXP, 3));
    SEXP raw_out = PROTECT(Rf_allocVector(RAWSXP,
        static_cast<R_xlen_t>(out.size())));
    if (!out.empty()) {
        std::memcpy(RAW(raw_out), out.data(), out.size());
    }
    SET_VECTOR_ELT(res, 0, Rf_ScalarInteger(static_cast<int>(code)));
    SET_VECTOR_ELT(res, 1, raw_out);
    SET_VECTOR_ELT(res, 2, Rf_mkString(err.c_str()));
    SEXP nm = PROTECT(Rf_allocVector(STRSXP, 3));
    SET_STRING_ELT(nm, 0, Rf_mkChar("status"));
    SET_STRING_ELT(nm, 1, Rf_mkChar("body"));
    SET_STRING_ELT(nm, 2, Rf_mkChar("error"));
    Rf_setAttrib(res, R_NamesSymbol, nm);
    UNPROTECT(3);
    return res;
}

/* GET with headers, reply as raw bytes plus the HTTP status: the hosted
 * tier's model list. */
SEXP C_rmbl_http_get_impl(SEXP url, SEXP timeout, SEXP headers) {
    if (TYPEOF(url) != STRSXP || XLENGTH(url) != 1) {
        Rf_error("`url` must be a single string");
    }
    const long tmo = (TYPEOF(timeout) == INTSXP && XLENGTH(timeout) == 1)
        ? static_cast<long>(INTEGER(timeout)[0]) : 30L;
    std::vector<std::string> extra;
    if (TYPEOF(headers) == STRSXP) {
        for (R_xlen_t i = 0; i < XLENGTH(headers); ++i) {
            extra.push_back(rmbl_str_at(headers, i, "headers"));
        }
    } else if (headers != R_NilValue) {
        Rf_error("`headers` must be a character vector or NULL");
    }
    std::string out, err;
    const long code = http_get_string(rmbl_str0(url, "url"), out, tmo, extra, &err);
    SEXP res = PROTECT(Rf_allocVector(VECSXP, 3));
    SEXP raw_out = PROTECT(Rf_allocVector(RAWSXP,
        static_cast<R_xlen_t>(out.size())));
    if (!out.empty()) {
        std::memcpy(RAW(raw_out), out.data(), out.size());
    }
    SET_VECTOR_ELT(res, 0, Rf_ScalarInteger(static_cast<int>(code)));
    SET_VECTOR_ELT(res, 1, raw_out);
    SET_VECTOR_ELT(res, 2, Rf_mkString(err.c_str()));
    SEXP nm = PROTECT(Rf_allocVector(STRSXP, 3));
    SET_STRING_ELT(nm, 0, Rf_mkChar("status"));
    SET_STRING_ELT(nm, 1, Rf_mkChar("body"));
    SET_STRING_ELT(nm, 2, Rf_mkChar("error"));
    Rf_setAttrib(res, R_NamesSymbol, nm);
    UNPROTECT(3);
    return res;
}

SEXP C_rmbl_fetch_fallback_impl(SEXP url, SEXP wayback, SEXP path, SEXP timeout) {
    const char *u = rmbl_str0(url, "url");
    const char *w = (wayback == R_NilValue || Rf_length(wayback) == 0 ||
                     (TYPEOF(wayback) == STRSXP && STRING_ELT(wayback, 0) == NA_STRING))
                        ? "" : rmbl_str0(wayback, "wayback");
    const char *p = rmbl_str0(path, "path");
    int t = Rf_asInteger(timeout);
    if (t == NA_INTEGER || t < 1) t = 120;
    return Rf_ScalarInteger(rmbl_fetch_with_fallback(u, w, p, t));
}

static std::vector<std::string> header_lines(SEXP headers) {
    std::vector<std::string> extra;
    if (TYPEOF(headers) == STRSXP) {
        for (R_xlen_t i = 0; i < XLENGTH(headers); ++i) {
            extra.push_back(rmbl_str_at(headers, i, "headers"));
        }
    } else if (headers != R_NilValue) {
        Rf_error("`headers` must be a character vector or NULL");
    }
    return extra;
}

/* GET a URL to a file through the hardened transport, with request headers
 * and an R progress closure: bricklayer_download()'s transport. Returns
 * list(status, bytes, error); a pending Ctrl-C is raised by the barrier. */
SEXP C_rmbl_http_download_impl(SEXP url, SEXP path, SEXP timeout, SEXP headers, SEXP progress) {
    const std::string u = rmbl_str0(url, "url");
    const std::string p = rmbl_str0(path, "path");
    long tmo = (TYPEOF(timeout) == INTSXP || TYPEOF(timeout) == REALSXP) && XLENGTH(timeout) == 1
        ? static_cast<long>(Rf_asReal(timeout)) : 3600L;
    if (tmo < 1) tmo = 3600L;
    if (progress != R_NilValue && !Rf_isFunction(progress)) {
        Rf_error("`progress` must be a function or NULL");
    }
    const std::vector<std::string> extra = header_lines(headers);
    curl_off_t written = 0;
    std::string err;
    bool interrupted = false;
    const long code = http_get_file(u, p, tmo, &extra, progress, &written, &err, &interrupted);
    if (interrupted) rmbl_kernel_interrupted = 1;
    SEXP res = PROTECT(Rf_allocVector(VECSXP, 3));
    SET_VECTOR_ELT(res, 0, Rf_ScalarInteger(static_cast<int>(code)));
    SET_VECTOR_ELT(res, 1, Rf_ScalarReal(static_cast<double>(written)));
    SET_VECTOR_ELT(res, 2, Rf_mkString(err.c_str()));
    SEXP nm = PROTECT(Rf_allocVector(STRSXP, 3));
    SET_STRING_ELT(nm, 0, Rf_mkChar("status"));
    SET_STRING_ELT(nm, 1, Rf_mkChar("bytes"));
    SET_STRING_ELT(nm, 2, Rf_mkChar("error"));
    Rf_setAttrib(res, R_NamesSymbol, nm);
    UNPROTECT(2);
    return res;
}

/* The redirect rule for the tests: list(ok, why, drop_auth) for a hop from
 * `from` to `to`, without resolving or connecting. */
SEXP C_rmbl_redirect_check_impl(SEXP from, SEXP to, SEXP allow_http) {
    bool drop = false;
    const std::string why = redirect_policy(rmbl_str0(from, "from"), rmbl_str0(to, "to"),
                                            Rf_asLogical(allow_http) == TRUE, false, &drop, NULL, NULL);
    SEXP res = PROTECT(Rf_allocVector(VECSXP, 3));
    SET_VECTOR_ELT(res, 0, Rf_ScalarLogical(why.empty()));
    SET_VECTOR_ELT(res, 1, Rf_mkString(why.c_str()));
    SET_VECTOR_ELT(res, 2, Rf_ScalarLogical(drop));
    SEXP nm = PROTECT(Rf_allocVector(STRSXP, 3));
    SET_STRING_ELT(nm, 0, Rf_mkChar("ok"));
    SET_STRING_ELT(nm, 1, Rf_mkChar("why"));
    SET_STRING_ELT(nm, 2, Rf_mkChar("drop_auth"));
    Rf_setAttrib(res, R_NamesSymbol, nm);
    UNPROTECT(2);
    return res;
}

SEXP C_rmbl_wayback_impl(SEXP url, SEXP timeout) {
    const char *u = rmbl_str0(url, "url");
    char buf[2048];
    int n = rmbl_wayback_snapshot(u, buf, (int) sizeof(buf), Rf_asInteger(timeout));
    return Rf_ScalarString(n > 0 ? Rf_mkChar(buf) : R_BlankString);
}

/* The URL check for the R-level validator: "" when the URL may be fetched,
 * else the reason. `resolve` adds the DNS step (every address checked). */
SEXP C_rmbl_url_check_impl(SEXP url, SEXP allow_http, SEXP resolve) {
    const std::string u = rmbl_str0(url, "url");
    const bool http = Rf_asLogical(allow_http) == TRUE;
    const bool res = Rf_asLogical(resolve) == TRUE;
    const std::string why = url_check(u, http, res, NULL, NULL);
    return Rf_mkString(why.c_str());
}
}  // extern "C"
