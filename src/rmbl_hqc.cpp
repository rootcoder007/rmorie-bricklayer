/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * R entry points for HQC-KEM (rmbl_hqc_core.h). The R side validates
 * lengths and draws randomness; everything here takes raw vectors of the
 * exact sizes and fails loudly on anything else.
 */

#include <cstring>

#include <R.h>
#include <Rinternals.h>

#include "rmbl_hqc_core.h"

namespace {

using rmbl_hqc::HQC1;
using rmbl_hqc::HQC3;
using rmbl_hqc::HQC5;
using rmbl_hqc::Scheme;
using rmbl_hqc::Scheme4;

int hqc_level(SEXP level) {
    if (TYPEOF(level) != INTSXP || XLENGTH(level) != 1) {
        Rf_error("`level` must be a single integer: 1, 3 or 5");
    }
    int l = INTEGER(level)[0];
    if (l != 1 && l != 3 && l != 5) Rf_error("`level` must be 1, 3 or 5");
    return l;
}

void need_raw(SEXP x, size_t n, const char *what) {
    if (TYPEOF(x) != RAWSXP || static_cast<size_t>(XLENGTH(x)) != n) {
        Rf_error("`%s` must be a raw vector of %d bytes", what, static_cast<int>(n));
    }
}

SEXP named_list2(const char *a, SEXP va, const char *b, SEXP vb) {
    SEXP out = PROTECT(Rf_allocVector(VECSXP, 2));
    SET_VECTOR_ELT(out, 0, va);
    SET_VECTOR_ELT(out, 1, vb);
    SEXP nm = PROTECT(Rf_allocVector(STRSXP, 2));
    SET_STRING_ELT(nm, 0, Rf_mkChar(a));
    SET_STRING_ELT(nm, 1, Rf_mkChar(b));
    Rf_setAttrib(out, R_NamesSymbol, nm);
    UNPROTECT(2);
    return out;
}

/* Every R vector is allocated BEFORE any secret is computed, and results are
 * written straight into it: Rf_error / an allocation failure longjmps past
 * C++ destructors, so no secret may sit in a C++ heap buffer across an R
 * call. The scheme's own intermediates are stack arrays it wipes itself. */
template <class P>
SEXP keygen(SEXP seed) {
    need_raw(seed, 32, "seed");
    SEXP pub = PROTECT(Rf_allocVector(RAWSXP, static_cast<R_xlen_t>(P::EK)));
    SEXP sec = PROTECT(Rf_allocVector(RAWSXP, static_cast<R_xlen_t>(P::DK)));
    SEXP out = PROTECT(named_list2("public", pub, "secret", sec));
    Scheme<P>::keygen(RAW(pub), RAW(sec), RAW(seed));
    UNPROTECT(3);
    return out;
}

template <class P>
SEXP encaps(SEXP ek, SEXP m, SEXP salt) {
    need_raw(ek, P::EK, "ek");
    need_raw(m, P::K, "m");
    need_raw(salt, P::SALT, "salt");
    if (!Scheme<P>::ek_ok(RAW(ek))) {
        Rf_error("the encapsulation key is malformed (bits set past the code length)");
    }
    SEXP c = PROTECT(Rf_allocVector(RAWSXP, static_cast<R_xlen_t>(P::CT)));
    SEXP s = PROTECT(Rf_allocVector(RAWSXP, 32));
    SEXP out = PROTECT(named_list2("ciphertext", c, "shared", s));
    Scheme<P>::encaps(RAW(c), RAW(s), RAW(ek), RAW(m), RAW(salt));
    UNPROTECT(3);
    return out;
}

template <class P>
SEXP decaps(SEXP dk, SEXP ct) {
    need_raw(dk, P::DK, "dk");
    need_raw(ct, P::CT, "ct");
    if (!Scheme<P>::dk_ok(RAW(dk))) {
        Rf_error("the decapsulation key is corrupt: its seeds do not derive from each other");
    }
    SEXP ss = PROTECT(Rf_allocVector(RAWSXP, 32));
    Scheme<P>::decaps(RAW(ss), RAW(dk), RAW(ct));
    UNPROTECT(1);
    return ss;
}

template <class P>
SEXP sizes() {
    const int v[7] = {static_cast<int>(P::EK), static_cast<int>(P::DK), static_cast<int>(P::CT), 32,
                      static_cast<int>(P::K), static_cast<int>(P::SALT), 32};
    const char *nm[7] = {"encapsulation_key", "decapsulation_key", "ciphertext", "seed",
                         "message", "salt", "shared_secret"};
    SEXP out = PROTECT(Rf_allocVector(INTSXP, 7));
    SEXP names = PROTECT(Rf_allocVector(STRSXP, 7));
    for (int i = 0; i < 7; ++i) {
        INTEGER(out)[i] = v[i];
        SET_STRING_ELT(names, i, Rf_mkChar(nm[i]));
    }
    Rf_setAttrib(out, R_NamesSymbol, names);
    UNPROTECT(2);
    return out;
}

/* round 4 (2023-04-30): the same contract, 40-byte seeds and a 64-byte secret */
template <class P>
SEXP keygen4(SEXP rnd) {
    using S = Scheme4<P>;
    need_raw(rnd, S::RND, "seed");
    SEXP pub = PROTECT(Rf_allocVector(RAWSXP, static_cast<R_xlen_t>(S::EK)));
    SEXP sec = PROTECT(Rf_allocVector(RAWSXP, static_cast<R_xlen_t>(S::DK)));
    SEXP out = PROTECT(named_list2("public", pub, "secret", sec));
    S::keygen(RAW(pub), RAW(sec), RAW(rnd));
    UNPROTECT(3);
    return out;
}

template <class P>
SEXP encaps4(SEXP ek, SEXP m, SEXP salt) {
    using S = Scheme4<P>;
    need_raw(ek, S::EK, "ek");
    need_raw(m, P::K, "m");
    need_raw(salt, S::SALT, "salt");
    if (!S::ek_ok(RAW(ek))) {
        Rf_error("the encapsulation key is malformed (bits set past the code length)");
    }
    SEXP c = PROTECT(Rf_allocVector(RAWSXP, static_cast<R_xlen_t>(S::CT)));
    SEXP s = PROTECT(Rf_allocVector(RAWSXP, static_cast<R_xlen_t>(S::SS)));
    SEXP out = PROTECT(named_list2("ciphertext", c, "shared", s));
    S::encaps(RAW(c), RAW(s), RAW(ek), RAW(m), RAW(salt));
    UNPROTECT(3);
    return out;
}

template <class P>
SEXP decaps4(SEXP dk, SEXP ct) {
    using S = Scheme4<P>;
    need_raw(dk, S::DK, "dk");
    need_raw(ct, S::CT, "ct");
    if (!S::dk_ok(RAW(dk))) {
        Rf_error("the decapsulation key is corrupt: its public half is not the one its secret seed makes");
    }
    SEXP ss = PROTECT(Rf_allocVector(RAWSXP, static_cast<R_xlen_t>(S::SS)));
    S::decaps(RAW(ss), RAW(dk), RAW(ct));
    UNPROTECT(1);
    return ss;
}

template <class P>
SEXP sizes4() {
    using S = Scheme4<P>;
    const int v[7] = {static_cast<int>(S::EK), static_cast<int>(S::DK), static_cast<int>(S::CT),
                      static_cast<int>(S::RND), static_cast<int>(P::K), static_cast<int>(S::SALT),
                      static_cast<int>(S::SS)};
    const char *nm[7] = {"encapsulation_key", "decapsulation_key", "ciphertext", "seed",
                         "message", "salt", "shared_secret"};
    SEXP out = PROTECT(Rf_allocVector(INTSXP, 7));
    SEXP names = PROTECT(Rf_allocVector(STRSXP, 7));
    for (int i = 0; i < 7; ++i) {
        INTEGER(out)[i] = v[i];
        SET_STRING_ELT(names, i, Rf_mkChar(nm[i]));
    }
    Rf_setAttrib(out, R_NamesSymbol, names);
    UNPROTECT(2);
    return out;
}

/* Decoder self-test, deterministic from `seed`: Reed-Solomon must correct
 * any pattern of up to delta byte errors, and the concatenated code must
 * survive heavy damage to up to delta Reed-Muller blocks plus light noise in
 * the rest. Returns the number of failures (0 when the decoder is right). */
template <class P>
int selftest(int trials, const uint8_t *seed) {
    rmbl_hqc::Xof x;
    x.init(seed, 32);
    auto next = [&x]() {
        uint8_t b[8];
        x.get_raw(b, 8);
        return rmbl_hqc::load_le64(b);
    };
    int bad = 0;
    for (int t = 0; t < trials; ++t) {
        uint8_t m[P::K], c[P::N1], out[P::K], rsw[P::N1];
        for (auto &b : m) b = static_cast<uint8_t>(next());
        rmbl_hqc::rs::encode<P>(c, m);
        /* RS alone: distinct positions by a partial Fisher-Yates */
        uint8_t pos[P::N1], damaged[P::N1];
        std::memcpy(damaged, c, P::N1);
        for (size_t i = 0; i < P::N1; ++i) pos[i] = static_cast<uint8_t>(i);
        size_t nerr = next() % (P::DELTA + 1);
        for (size_t k = 0; k < nerr; ++k) {
            size_t j = k + next() % (P::N1 - k);
            uint8_t tmp = pos[k];
            pos[k] = pos[j];
            pos[j] = tmp;
            damaged[pos[k]] ^= static_cast<uint8_t>(1 + next() % 255);
        }
        rmbl_hqc::rs::decode<P>(out, damaged);
        if (std::memcmp(out, m, P::K) != 0) ++bad;
        /* the concatenated code */
        uint64_t v[P::N1N2W];
        rmbl_hqc::rm::encode<P>(v, c);
        for (size_t blk = 0; blk < P::N1; ++blk) {
            bool heavy = blk < P::DELTA && (next() & 1);
            size_t flips = heavy ? P::N2 / 4 + next() % (P::N2 / 4) : next() % 30;
            for (size_t f = 0; f < flips; ++f) {
                size_t bit = blk * P::N2 + next() % P::N2;
                v[bit / 64] ^= uint64_t(1) << (bit % 64);
            }
        }
        rmbl_hqc::rm::decode<P>(rsw, v);
        rmbl_hqc::rs::decode<P>(out, rsw);
        if (std::memcmp(out, m, P::K) != 0) ++bad;
    }
    return bad;
}

} // namespace

extern "C" {

SEXP C_rmbl_hqc_sizes(SEXP level) {
    switch (hqc_level(level)) {
    case 1: return sizes<HQC1>();
    case 3: return sizes<HQC3>();
    default: return sizes<HQC5>();
    }
}

SEXP C_rmbl_hqc_keygen(SEXP level, SEXP seed) {
    switch (hqc_level(level)) {
    case 1: return keygen<HQC1>(seed);
    case 3: return keygen<HQC3>(seed);
    default: return keygen<HQC5>(seed);
    }
}

SEXP C_rmbl_hqc_encaps(SEXP level, SEXP ek, SEXP m, SEXP salt) {
    switch (hqc_level(level)) {
    case 1: return encaps<HQC1>(ek, m, salt);
    case 3: return encaps<HQC3>(ek, m, salt);
    default: return encaps<HQC5>(ek, m, salt);
    }
}

SEXP C_rmbl_hqc_decaps(SEXP level, SEXP dk, SEXP ct) {
    switch (hqc_level(level)) {
    case 1: return decaps<HQC1>(dk, ct);
    case 3: return decaps<HQC3>(dk, ct);
    default: return decaps<HQC5>(dk, ct);
    }
}

SEXP C_rmbl_hqc4_sizes(SEXP level) {
    switch (hqc_level(level)) {
    case 1: return sizes4<HQC1>();
    case 3: return sizes4<HQC3>();
    default: return sizes4<HQC5>();
    }
}

SEXP C_rmbl_hqc4_keygen(SEXP level, SEXP rnd) {
    switch (hqc_level(level)) {
    case 1: return keygen4<HQC1>(rnd);
    case 3: return keygen4<HQC3>(rnd);
    default: return keygen4<HQC5>(rnd);
    }
}

SEXP C_rmbl_hqc4_encaps(SEXP level, SEXP ek, SEXP m, SEXP salt) {
    switch (hqc_level(level)) {
    case 1: return encaps4<HQC1>(ek, m, salt);
    case 3: return encaps4<HQC3>(ek, m, salt);
    default: return encaps4<HQC5>(ek, m, salt);
    }
}

SEXP C_rmbl_hqc4_decaps(SEXP level, SEXP dk, SEXP ct) {
    switch (hqc_level(level)) {
    case 1: return decaps4<HQC1>(dk, ct);
    case 3: return decaps4<HQC3>(dk, ct);
    default: return decaps4<HQC5>(dk, ct);
    }
}

/* which multiplier runs: "pclmul" (x86-64), "pmull" (ARMv8 crypto) or
 * "portable"; `portable = TRUE` forces the portable one (tests compare) */
SEXP C_rmbl_hqc_backend(SEXP portable) {
    if (TYPEOF(portable) == LGLSXP && XLENGTH(portable) == 1 && LOGICAL(portable)[0] != NA_LOGICAL) {
        rmbl_hqc::gf2x::force_portable() = LOGICAL(portable)[0] ? 1 : 0;
    }
    const char *name = "portable";
    if (!rmbl_hqc::gf2x::force_portable()) {
#if defined(RMBL_HQC_X86_PCLMUL)
        if (rmbl_hqc::gf2x::have_pclmul()) name = "pclmul";
#endif
#if defined(RMBL_HQC_ARM_PMULL)
        name = "pmull";
#endif
    }
    return Rf_mkString(name);
}

SEXP C_rmbl_hqc_selftest(SEXP level, SEXP trials, SEXP seed) {
    need_raw(seed, 32, "seed");
    int n = Rf_asInteger(trials);
    if (n == NA_INTEGER || n < 0) Rf_error("`trials` must be a non-negative integer");
    int bad = 0;
    switch (hqc_level(level)) {
    case 1: bad = selftest<HQC1>(n, RAW(seed)); break;
    case 3: bad = selftest<HQC3>(n, RAW(seed)); break;
    default: bad = selftest<HQC5>(n, RAW(seed)); break;
    }
    return Rf_ScalarInteger(bad);
}

} // extern "C"
