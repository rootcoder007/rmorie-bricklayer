// SPDX-License-Identifier: AGPL-3.0-or-later
//
// cihi_catalog.cpp -- one-time C++ data-prep tool that builds the bundled
// CIHI data-table catalogue for rmoriedata. It scrapes every page of CIHI's
// "Access data and reports > Data tables" listing, extracts each downloadable
// table (title, url, format), resolves an Internet Archive (Wayback) snapshot
// as a fallback, and writes cihi_data_tables.csv with full provenance.
//
// Pure C++17 + libcurl + std::regex. No Python anywhere in the pipeline.
// Build:  g++ -std=c++17 -O2 cihi_catalog.cpp -lcurl -o cihi_catalog
// Run:    ./cihi_catalog > cihi_data_tables.csv     (run once, by a maintainer)
//
// The SHIPPED artifact is the CSV; this tool is maintainer-only (data-raw).

#include <curl/curl.h>
#include <cstdio>
#include <ctime>
#include <map>
#include <regex>
#include <string>
#include <vector>

namespace {

const char *UA = "morie-bricklayer/1.0 (+https://github.com/rootcoder007/rmorie-bricklayer)";
const char *LISTING =
    "https://www.cihi.ca/en/access-data-and-reports/data-tables"
    "?keyword=&sort_by=field_published_date_value&items_per_page=50&page=";
const char *SRC_PAGE = "https://www.cihi.ca/en/access-data-and-reports/data-tables";
const char *LICENSE =
    "CIHI open data; see https://www.cihi.ca/en/terms-and-conditions-of-use";

size_t sink(char *p, size_t s, size_t n, void *u) {
    static_cast<std::string *>(u)->append(p, s * n);
    return s * n;
}

long http_get(const std::string &url, std::string &out, long tmo) {
    CURL *h = curl_easy_init();
    if (!h) return -1;
    out.clear();
    curl_easy_setopt(h, CURLOPT_URL, url.c_str());
    curl_easy_setopt(h, CURLOPT_FOLLOWLOCATION, 1L);
    curl_easy_setopt(h, CURLOPT_TIMEOUT, tmo);
    curl_easy_setopt(h, CURLOPT_CONNECTTIMEOUT, 30L);
    curl_easy_setopt(h, CURLOPT_NOSIGNAL, 1L);
    curl_easy_setopt(h, CURLOPT_USERAGENT, UA);
    curl_easy_setopt(h, CURLOPT_ACCEPT_ENCODING, "");
    curl_easy_setopt(h, CURLOPT_WRITEFUNCTION, sink);
    curl_easy_setopt(h, CURLOPT_WRITEDATA, &out);
    CURLcode rc = curl_easy_perform(h);
    long code = -1;
    if (rc == CURLE_OK) curl_easy_getinfo(h, CURLINFO_RESPONSE_CODE, &code);
    curl_easy_cleanup(h);
    return (rc == CURLE_OK) ? code : -1;
}

std::string enc(const std::string &s) {
    CURL *h = curl_easy_init();
    char *e = curl_easy_escape(h, s.c_str(), (int) s.size());
    std::string o = e ? e : s;
    if (e) curl_free(e);
    curl_easy_cleanup(h);
    return o;
}

std::string strip(std::string s) {
    s = std::regex_replace(s, std::regex("<[^>]+>"), "");
    s = std::regex_replace(s, std::regex("&amp;"), "&");
    s = std::regex_replace(s, std::regex("&#0?39;|&rsquo;"), "'");
    s = std::regex_replace(s, std::regex("&nbsp;"), " ");
    s = std::regex_replace(s, std::regex("\\s+"), " ");
    size_t a = s.find_first_not_of(" ");
    size_t b = s.find_last_not_of(" ");
    return (a == std::string::npos) ? "" : s.substr(a, b - a + 1);
}

std::string wayback(const std::string &url) {
    std::string body;
    if (http_get("https://archive.org/wayback/available?url=" + enc(url), body, 30) != 200)
        return "";
    size_t c = body.find("\"closest\"");
    if (c == std::string::npos) return "";
    size_t av = body.find("\"available\"", c);
    if (av == std::string::npos) return "";
    size_t t = body.find("true", av);
    if (t == std::string::npos || t - av > 24) return "";
    size_t u = body.find("\"url\"", c);
    if (u == std::string::npos) return "";
    size_t col = body.find(':', u + 5), o = body.find('"', col + 1);
    size_t cl = body.find('"', o + 1);
    std::string snap = body.substr(o + 1, cl - o - 1);
    if (snap.rfind("http://", 0) == 0) snap = "https://" + snap.substr(7);
    return snap;
}

std::string csv_field(const std::string &s) {
    if (s.find_first_of(",\"\n") == std::string::npos) return s;
    std::string o = "\"";
    for (char c : s) { if (c == '"') o += '"'; o += c; }
    return o + "\"";
}

}  // namespace

int main() {
    std::regex link(
        "<a\\b[^>]*href=\"([^\"]+/files/[^\"]+\\.(?:xlsx|xls|zip|csv))\"[^>]*>(.*?)</a>",
        std::regex::icase);
    std::regex heading("<(?:h2|h3|h4)[^>]*>(.*?)</(?:h2|h3|h4)>", std::regex::icase);

    std::map<std::string, std::vector<std::string>> rows;  // url -> {title, format}
    std::vector<std::string> order;

    for (int page = 0; page < 6; ++page) {
        std::string html;
        if (http_get(LISTING + std::to_string(page), html, 45) != 200) {
            fprintf(stderr, "page %d: fetch failed\n", page);
            continue;
        }
        int found = 0;
        for (auto it = std::sregex_iterator(html.begin(), html.end(), link);
             it != std::sregex_iterator(); ++it) {
            std::string url = (*it)[1];
            if (url.rfind("/", 0) == 0) url = "https://www.cihi.ca" + url;
            if (rows.count(url)) continue;
            std::string anchor = strip((*it)[2].str());
            std::string title = anchor;
            std::string low = title;
            for (auto &ch : low) ch = (char) tolower(ch);
            if (title.empty() || low == "download" || low == "data tables") {
                // fall back to nearest preceding heading
                size_t pos = it->position(0);
                std::string pre = html.substr(pos > 1200 ? pos - 1200 : 0,
                                              pos > 1200 ? 1200 : pos);
                std::string last;
                for (auto h = std::sregex_iterator(pre.begin(), pre.end(), heading);
                     h != std::sregex_iterator(); ++h)
                    last = strip((*h)[1].str());
                if (!last.empty()) title = last;
            }
            std::string fmt = url.substr(url.rfind('.') + 1);
            for (auto &ch : fmt) ch = (char) tolower(ch);
            rows[url] = {title.empty() ? "(untitled)" : title, fmt};
            order.push_back(url);
            ++found;
        }
        fprintf(stderr, "page %d: %d new (total %zu)\n", page, found, rows.size());
        if (found == 0 && page > 0) break;
    }

    char today[16];
    // Fixed retrieval date passed in via env for reproducibility; else "now".
    const char *env = getenv("CIHI_RETRIEVED");
    if (env) snprintf(today, sizeof(today), "%s", env);
    else { time_t t = time(nullptr); strftime(today, sizeof(today), "%Y-%m-%d", gmtime(&t)); }

    printf("title,url,format,wayback_url,retrieved,source_page_url,license\n");
    int have = 0, i = 0;
    for (const auto &url : order) {
        const auto &r = rows[url];
        std::string wb = wayback(url);
        if (wb.empty()) wb = wayback(url);  // one retry (archive.org is flaky)
        if (!wb.empty()) ++have;
        printf("%s,%s,%s,%s,%s,%s,%s\n",
               csv_field(r[0]).c_str(), csv_field(url).c_str(),
               r[1].c_str(), csv_field(wb).c_str(), today,
               csv_field(SRC_PAGE).c_str(), csv_field(LICENSE).c_str());
        if (++i % 25 == 0) fprintf(stderr, "  wayback %d/%zu (have %d)\n", i, order.size(), have);
    }
    fprintf(stderr, "DONE: %zu tables, %d with wayback\n", order.size(), have);
    return 0;
}
