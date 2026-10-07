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

/* Decapsulation phase by phase, to place a signal the whole-decapsulation target shows:
 * the K-PKE decryption alone, and the Fujisaki-Okamoto compare-and-select alone (with the
 * valid ciphertext as the re-encryption, so the fixed class selects g and the random class
 * selects K-bar, exactly the secret bit decapsulation must hide). */
static unsigned char g_sel[32] = {0x5a}, kbar_sel[32] = {0xa5};
void dd_mlkem_pdec_run(const unsigned char *in) {
    unsigned char mp[32];
    rmbl_mlkem768::pke_decrypt(mp, dk.data(), in);
    sink[0] ^= mp[0];
}
void dd_mlkem_sel_run(const unsigned char *in) {
    rmbl_mlkem768::fo_select(sink, g_sel, kbar_sel, ct_valid.data(), in, 0);
}

/* The masked decapsulation (the package default). Its randomness comes from a fast
 * generator here: what is timed is the decapsulation, whose running time must not depend
 * on the ciphertext's validity, not the operating system's random source. */
static uint64_t g_xs = 0x9E3779B97F4A7C15ull;
static uint32_t xs_u32(void *) {
    g_xs ^= g_xs << 13;
    g_xs ^= g_xs >> 7;
    g_xs ^= g_xs << 17;
    return static_cast<uint32_t>(g_xs >> 32);
}
void dd_mlkem_decm_run(const unsigned char *in) {
    rmbl_masked::Rng rng;
    rng.fn = xs_u32;
    rng.ctx = nullptr;
    rmbl_mlkem768::decaps_masked(sink, dk.data(), in, rng);
}
