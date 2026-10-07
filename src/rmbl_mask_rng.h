#ifndef RMBL_MASK_RNG_H
#define RMBL_MASK_RNG_H

/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * The randomness the masking gadgets (rmbl_masked.h) draw in the package: the operating
 * system's CSPRNG through a 4 KiB buffer. A failed read is recorded, not raised, so no
 * Rf_error() longjmps over the masked computation's buffers; the entry point raises once
 * they are gone. Shared by the masked ML-KEM decapsulation and ML-DSA signing. */

#include <cstddef>
#include <cstdint>
#include <cstring>

extern "C" int rmbl_os_random(unsigned char *out, size_t n);

struct MaskRng {
    unsigned char buf[4096];
    size_t pos = sizeof buf;
    bool failed = false;
};

static inline uint32_t mask_rng_u32(void *ctx) {
    MaskRng *m = static_cast<MaskRng *>(ctx);
    if (m->pos + 4 > sizeof m->buf) {
        if (rmbl_os_random(m->buf, sizeof m->buf) != 0) m->failed = true;
        m->pos = 0;
    }
    uint32_t v;
    std::memcpy(&v, m->buf + m->pos, 4);
    m->pos += 4;
    return v;
}

#endif
