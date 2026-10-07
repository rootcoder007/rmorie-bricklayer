/* HQC targets for dudect.cpp (own translation unit; see dudect_mlkem.cpp). */
#include <cstring>
#include <vector>
#include "../../src/rmbl_hqc_core.h"

using HQ = rmbl_hqc::Scheme<rmbl_hqc::HQC1>;
using HP = rmbl_hqc::HQC1;
static std::vector<unsigned char> ek, dk, ct_valid;
static unsigned char sink[64];

size_t dd_hqc_ct_bytes() { return HP::CT; }
size_t dd_hqc_k_bytes() { return HP::K; }
size_t dd_hqc_salt_bytes() { return HP::SALT; }
void dd_hqc_prep(const unsigned char *seed32, const unsigned char *m, const unsigned char *salt) {
    unsigned char ss[64];
    ek.assign(HP::EK, 0);
    dk.assign(HP::DK, 0);
    ct_valid.assign(HP::CT, 0);
    HQ::keygen(ek.data(), dk.data(), seed32);
    HQ::encaps(ct_valid.data(), ss, ek.data(), m, salt);
}
void dd_hqc_dec_fixed(unsigned char *in) { std::memcpy(in, ct_valid.data(), ct_valid.size()); }
void dd_hqc_dec_run(const unsigned char *in) { HQ::decaps(sink, dk.data(), in); }
