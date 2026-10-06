/* libFuzzer target: the URL policy (url_check) and the redirect rule
 * (redirect_policy), the two pure functions every network byte passes. The
 * input is split at the first NUL into `from` and `to`. rmbl_fetch.cpp is
 * compiled in with RMBL_FUZZ_EXPORTS, which exposes two C wrappers; the
 * barrier symbols it references are stubbed here. */
#include <cstring>
#include <string>
extern "C" {
int rmbl_fuzz_url_check(const char *url, int allow_http, int allow_loopback);
int rmbl_fuzz_redirect_check(const char *from, const char *to, int allow_http, int allow_loopback);
int rmbl_kernel_interrupted = 0;
int rmbl_interrupt_pending(void) { return 0; }
void rmbl_interrupt_raise_unbarriered(void) {}
}

extern "C" int LLVMFuzzerTestOneInput(const unsigned char *data, size_t size) {
    if (size > 8192) return 0;
    const char *d = reinterpret_cast<const char *>(data);
    const char *p = static_cast<const char *>(std::memchr(d, 0, size));
    const std::string from(d, p ? static_cast<size_t>(p - d) : size);
    const std::string to = p ? std::string(p + 1, size - static_cast<size_t>(p + 1 - d)) : std::string();
    for (int lo = 0; lo < 2; ++lo) {
        for (int http = 0; http < 2; ++http) {
            (void)rmbl_fuzz_url_check(from.c_str(), http, lo);
            (void)rmbl_fuzz_redirect_check(from.c_str(), to.c_str(), http, lo);
        }
    }
    return 0;
}
