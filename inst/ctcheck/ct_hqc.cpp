#include "ct_common.h"
#include <vector>
#include "../../src/rmbl_hqc_core.h"

template <class P>
static int hqc_case(const char *nm) {
    using S = rmbl_hqc::Scheme<P>;
    unsigned char seed[32], ss[32], ss2[32], ss3[32];
    std::vector<unsigned char> ek(P::EK), dk(P::DK), ct(P::CT), m(P::K), salt(P::SALT);
    ct_fill(seed, 32, 41);
    ct_fill(m.data(), m.size(), 42);
    ct_fill(salt.data(), salt.size(), 43);
    ct_secret(seed, 32);
    S::keygen(ek.data(), dk.data(), seed);
    int rem = ct_stack_remnants(seed, 32, nm);
    ct_public(ek.data(), ek.size());
    ct_secret(m.data(), m.size());
    S::encaps(ct.data(), ss, ek.data(), m.data(), salt.data());
    ct_public(ct.data(), ct.size());
    S::decaps(ss2, dk.data(), ct.data());
    rem += ct_stack_remnants(dk.data() + P::EK, 32, "HQC decapsulation key seed");
    ct[0] ^= 1;
    S::decaps(ss3, dk.data(), ct.data());
    ct_public(ss, 32);
    ct_public(ss2, 32);
    ct_public(ss3, 32);
    if (std::memcmp(ss, ss2, 32) != 0) return 11;
    if (std::memcmp(ss, ss3, 32) == 0) return 12;
    return rem ? 3 : 0;
}

int ct_hqc1() { return hqc_case<rmbl_hqc::HQC1>("HQC-1 seed"); }
int ct_hqc3() { return hqc_case<rmbl_hqc::HQC3>("HQC-3 seed"); }
int ct_hqc5() { return hqc_case<rmbl_hqc::HQC5>("HQC-5 seed"); }

int ct_hqc1_round4() {
    using P = rmbl_hqc::HQC1;
    using S = rmbl_hqc::Scheme4<P>;
    std::vector<unsigned char> rnd(S::RND), ek(S::EK), dk(S::DK), ct(S::CT), m(P::K), salt(S::SALT);
    std::vector<unsigned char> ss(S::SS), ss2(S::SS), ss3(S::SS);
    ct_fill(rnd.data(), rnd.size(), 44);
    ct_fill(m.data(), m.size(), 45);
    ct_fill(salt.data(), salt.size(), 46);
    ct_secret(rnd.data(), rnd.size());
    S::keygen(ek.data(), dk.data(), rnd.data());
    int rem = ct_stack_remnants(rnd.data(), 32, "HQC round-4 keygen randomness");
    ct_public(ek.data(), ek.size());
    ct_secret(m.data(), m.size());
    S::encaps(ct.data(), ss.data(), ek.data(), m.data(), salt.data());
    ct_public(ct.data(), ct.size());
    S::decaps(ss2.data(), dk.data(), ct.data());
    ct[0] ^= 1;
    S::decaps(ss3.data(), dk.data(), ct.data());
    ct_public(ss.data(), ss.size());
    ct_public(ss2.data(), ss2.size());
    ct_public(ss3.data(), ss3.size());
    if (ss != ss2) return 1;
    if (ss == ss3) return 1;
    return rem ? 3 : 0;
}
