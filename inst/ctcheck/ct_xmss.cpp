#include "ct_common.h"
#include "../../src/rmbl_pqc.cpp"

/* The XMSS signing path of C_rmbl_xmss_sign, with SK_SEED and SK_PRF
 * secret: the WOTS+ secret chains, the Merkle leaves and R = PRF(SK_PRF, idx).
 * The root, the authentication path and R are published, so they are
 * declassified as soon as they exist. */
int ct_xmss() {
    unsigned char sks[kN], prfs[kN], pubs[kN], msg[29];
    ct_fill(sks, kN, 71);
    ct_fill(prfs, kN, 72);
    ct_fill(pubs, kN, 73);
    ct_fill(msg, sizeof msg, 74);
    const int h = 2;
    const uint32_t idx = 1;
    ct_secret(sks, kN);
    ct_secret(prfs, kN);

    unsigned char root[32];
    std::vector<unsigned char> auth;
    tree_root(sks, pubs, h, idx, root, &auth);
    ct_public(root, kN);
    ct_public(auth.data(), auth.size());

    unsigned char ridx[32], rnd[32], dig[32];
    to_byte32(idx, ridx);
    fn_PRF(prfs, ridx, rnd);
    ct_public(rnd, kN);
    fn_Hmsg_bound(rnd, root, idx, msg, sizeof msg, dig);

    int digits[kLen];
    wots_digits(dig, digits);
    Adrs adrs;
    adrs.set_type(0);
    adrs.set_ots(idx);
    std::vector<unsigned char> sig(static_cast<size_t>(kLen) * kN);
    for (int i = 0; i < kLen; ++i) {
        unsigned char sk[32];
        wots_sk(sks, pubs, idx, i, sk);
        adrs.set_chain(static_cast<uint32_t>(i));
        chain(sk, 0, digits[i], pubs, adrs, sig.data() + static_cast<size_t>(i) * kN);
    }
    /* the R entry points move the seeds as hex: both directions must be branch-free too */
    std::string hex;
    hexlify(sks, kN, hex);
    std::vector<unsigned char> back;
    if (!unhexlify(hex.c_str(), hex.size(), back) || back.size() != kN) return 1;
    const int rem = ct_stack_remnants(sks, kN, "XMSS SK_SEED");
    ct_public(sig.data(), sig.size());
    return rem ? 3 : 0;
}
