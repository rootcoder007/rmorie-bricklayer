#include "ct_common.h"
#include "../../src/rmbl_drbg_core.h"

static int drbg_case(int portable) {
    using rmbl_drbg::CtrDrbg;
    using rmbl_drbg::SEEDLEN;
    rmbl_drbg::force_portable() = portable;
    unsigned char entropy[SEEDLEN], out[64];
    ct_fill(entropy, SEEDLEN, 51);
    ct_secret(entropy, SEEDLEN);
    {
        CtrDrbg d;
        d.instantiate(entropy, NULL, 0);
        d.generate(out, sizeof out, NULL, 0);
        d.reseed(entropy, NULL, 0);
        d.generate(out, sizeof out, NULL, 0);
    }
    const int rem = ct_stack_remnants(entropy, SEEDLEN, "CTR_DRBG entropy input");
    ct_public(out, sizeof out);
    return rem ? 3 : 0;
}

int ct_drbg_portable() { return drbg_case(1); }
int ct_drbg_aesni() {
    if (!rmbl_drbg::have_aesni()) {
        std::fprintf(stderr, "drbg-aesni: no AES-NI on this machine, portable path only\n");
        return 0;
    }
    return drbg_case(0);
}
