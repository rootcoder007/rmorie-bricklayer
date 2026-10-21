/* Unsigned arbitrary-precision integers as little-endian 32-bit limbs, shared by the RSA key
 * parser (rmbl_asn1.cpp) and the exact decimal parser (rmbl_strtod.cpp). */
#ifndef RMBL_BIGNUM_H
#define RMBL_BIGNUM_H

#include <cstddef>
#include <cstdint>
#include <vector>

namespace rmbl_big {

typedef std::vector<uint32_t> Big;

/* drop leading zero limbs, keeping at least one */
inline void trim(Big &a) {
    while (a.size() > 1 && a.back() == 0) a.pop_back();
}

/* -1, 0 or 1; leading zero limbs do not count, so untrimmed operands compare by value */
inline int cmp(const Big &a, const Big &b) {
    const size_t n = (a.size() > b.size()) ? a.size() : b.size();
    for (size_t i = n; i-- > 0;) {
        const uint32_t x = (i < a.size()) ? a[i] : 0;
        const uint32_t y = (i < b.size()) ? b[i] : 0;
        if (x != y) return x < y ? -1 : 1;
    }
    return 0;
}

/* the number of significant bits; 0 for zero */
inline size_t bit_length(const Big &a) {
    for (size_t i = a.size(); i-- > 0;) {
        if (a[i] != 0) {
            uint32_t v = a[i];
            size_t b = 0;
            while (v) { ++b; v >>= 1; }
            return i * 32 + b;
        }
    }
    return 0;
}

}  // namespace rmbl_big

#endif
