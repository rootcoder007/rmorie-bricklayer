/* libFuzzer target: the decimal-to-double conversion, checked against the C
 * library. Any ASCII that both parsers accept in full must give the same
 * double, bit for bit: a wrong last digit is not a crash, so the sanitizers
 * alone would never see it. */
#include <cerrno>
#include <cstdlib>
#include <cstring>
#include "../../src/rmbl_strtod.cpp"

extern "C" int LLVMFuzzerTestOneInput(const unsigned char *data, size_t size) {
    if (size == 0 || size > 400) return 0;
    for (size_t i = 0; i < size; ++i) {
        const char c = static_cast<char>(data[i]);
        if (!((c >= '0' && c <= '9') || c == '.' || c == 'e' || c == 'E' || c == '+' || c == '-')) return 0;
    }
    std::string s(reinterpret_cast<const char *>(data), size);
    bool ok = false;
    const double ours = convert(s.c_str(), s.size(), &ok);
    errno = 0;
    char *end = nullptr;
    const double theirs = std::strtod(s.c_str(), &end);
    const bool libc_ok = end == s.c_str() + s.size() && errno == 0;
    if (ok && libc_ok && std::memcmp(&ours, &theirs, sizeof ours) != 0) {
        std::fprintf(stderr, "MISMATCH on '%s': ours %.17g libc %.17g\n", s.c_str(), ours, theirs);
        __builtin_trap();
    }
    return 0;
}
