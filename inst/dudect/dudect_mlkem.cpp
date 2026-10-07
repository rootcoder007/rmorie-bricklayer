/* ML-KEM targets for dudect.cpp, in their own translation unit: rmbl_mlkem.cpp and the HQC
 * core each define the Keccak state, as in inst/ctcheck. */
#include <cstring>
#include <vector>
#include "../../src/rmbl_mlkem.cpp"

static std::vector<unsigned char> ek, dk, ct_valid;
static unsigned char sink[32];
static unsigned char ct_out[rmbl_mlkem768::kCtBytes];

size_t dd_mlkem_ct_bytes() { return rmbl_mlkem768::kCtBytes; }
void dd_mlkem_prep(const unsigned char *seed64, const unsigned char *m32) {
    namespace M = rmbl_mlkem768;
    unsigned char ss[32];
    ek.assign(M::kEkBytes, 0);
    dk.assign(M::kDkBytes, 0);
    ct_valid.assign(M::kCtBytes, 0);
    M::keygen(ek.data(), dk.data(), seed64);
    M::encaps(ct_valid.data(), ss, ek.data(), m32);
}
void dd_mlkem_dec_fixed(unsigned char *in) { std::memcpy(in, ct_valid.data(), ct_valid.size()); }
void dd_mlkem_dec_run(const unsigned char *in) { rmbl_mlkem768::decaps(sink, dk.data(), in); }
void dd_mlkem_enc_run(const unsigned char *m32) { rmbl_mlkem768::encaps(ct_out, sink, ek.data(), m32); }
