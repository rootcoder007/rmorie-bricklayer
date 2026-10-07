/* Simulated power analysis: Test Vector Leakage Assessment (TVLA, fixed-vs-random Welch
 * t-test; Goodwill et al. 2011, ISO/IEC 17825) on power traces from an emulated
 * Cortex-M4 under a Hamming-weight leakage model.
 *
 * The kernels (kernels.cpp, the package's own arithmetic) are cross-compiled for a
 * Cortex-M4 and executed instruction by instruction in unicorn. Each instruction is one
 * sample: the Hamming weight of every register value it changed, plus that of every value
 * it stored to memory. That is the standard first-order model of CMOS power consumption
 * (data-dependent switching), the model physical traces of microcontrollers follow to
 * first order. Class 0 runs on a fixed secret, class 1 on a random one, chosen at random
 * per trace; Welch's t at every sample compares the classes. |t| > 4.5 anywhere is the
 * TVLA mark of first-order leakage.
 *
 * What this is and is not: a pre-silicon assessment of the code under a leakage model. It
 * finds the first-order leakage the model expresses (values, not timing; timing is
 * inst/dudect's). It is not a measurement of a physical device: real chips leak through
 * transitions, glitches and coupling the model omits, which is why masked designs are
 * also checked on hardware when hardware is available.
 *
 *   ./tvla KERNEL [traces]     KERNEL: list | all | a name below
 */
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <random>
#include <string>
#include <unordered_map>
#include <vector>
#include <capstone/capstone.h>
#include <unicorn/unicorn.h>

#include "build/symbols.h"   /* addresses of the kernel entry points, from nm */

static const uint64_t kBase = 0x20000000, kSize = 1u << 20;
static const uint64_t kInput = kBase + 0xC0000;   /* input/output buffers */
static const uint64_t kStack = kBase + kSize - 16;
static const uint64_t kRand = kBase + 0x80000;   /* 256 KB of fresh randomness per trace */
static const int16_t kQ = 3329;

struct Run {
    uc_engine *uc = nullptr;
    std::vector<double> trace;
    std::vector<uint32_t> pc;
    uint32_t last[13] = {0};
    uint64_t prev = 0;      /* the instruction executing since the last code hook, 0 = none yet */
    double mem = 0;         /* what its memory writes contributed */
};

static inline int hw32(uint32_t x) { return __builtin_popcount(x); }

static std::vector<uint32_t> g_last_pc;   /* the program counter of every sample, last trace */
/* TVLA_MODEL=hd: the transition (Hamming-distance) model instead of the value model */
static bool g_hd = false;
/* TVLA_DUMP=i: print the values that make up sample i of every trace (debugging a leak) */
static long g_dump = -1;
static std::string g_dump_line;

/* The general-purpose registers each instruction writes, from capstone, cached by address.
 * Index i in 0..12 is r0..r12. Counting written registers (not registers whose value
 * changed) matters: a register overwritten with an equal value is a write all the same,
 * and skipping it would leak whether old == new, which is a transition effect, not a
 * value one. */
static csh g_cs;
static std::unordered_map<uint64_t, std::vector<int>> g_writes;

static int gpr_index(unsigned reg) {
    const char *n = cs_reg_name(g_cs, reg);
    if (!n) return -1;
    static const char *names[] = {"r0", "r1", "r2", "r3", "r4", "r5", "r6", "r7", "r8", "r9", "r10", "r11", "r12",
                                  "sb", "sl", "fp", "ip"};
    for (int i = 0; i < 17; ++i)
        if (std::strcmp(n, names[i]) == 0) return i < 13 ? i : i - 4;
    return -1;
}

static const std::vector<int> &written(uc_engine *uc, uint64_t addr) {
    auto it = g_writes.find(addr);
    if (it != g_writes.end()) return it->second;
    std::vector<int> out;
    unsigned char code[4];
    uc_mem_read(uc, addr, code, 4);
    cs_insn *insn = nullptr;
    if (cs_disasm(g_cs, code, 4, addr, 1, &insn) == 1) {
        cs_regs rr, ww;
        uint8_t nr = 0, nw = 0;
        if (cs_regs_access(g_cs, insn, rr, &nr, ww, &nw) == CS_ERR_OK) {
            for (int k = 0; k < nw; ++k) {
                const int i = gpr_index(ww[k]);
                if (i >= 0 && std::find(out.begin(), out.end(), i) == out.end()) out.push_back(i);
            }
        }
        cs_free(insn, 1);
    } else {
        std::fprintf(stderr, "capstone cannot decode the instruction at 0x%08llx\n", static_cast<unsigned long long>(addr));
        std::exit(2);
    }
    return g_writes.emplace(addr, out).first->second;
}

static void on_code(uc_engine *uc, uint64_t addr, uint32_t, void *ud) {
    Run *r = static_cast<Run *>(ud);
    static const int regs[13] = {UC_ARM_REG_R0, UC_ARM_REG_R1, UC_ARM_REG_R2, UC_ARM_REG_R3, UC_ARM_REG_R4,
                                 UC_ARM_REG_R5, UC_ARM_REG_R6, UC_ARM_REG_R7, UC_ARM_REG_R8, UC_ARM_REG_R9,
                                 UC_ARM_REG_R10, UC_ARM_REG_R11, UC_ARM_REG_R12};
    uint32_t v[13];
    void *ptrs[13];
    for (int i = 0; i < 13; ++i) ptrs[i] = &v[i];
    uc_reg_read_batch(uc, const_cast<int *>(regs), ptrs, 13);
    if (r->prev != 0) {
        /* one sample per instruction: the one at prev, which has just completed */
        double s = r->mem;
        for (int i : written(uc, r->prev)) {
            s += hw32(g_hd ? (v[i] ^ r->last[i]) : v[i]);
            if (g_dump >= 0 && static_cast<long>(r->trace.size()) == g_dump) {
                char b[40];
                std::snprintf(b, sizeof b, " r%d=%08x(was %08x)", i, v[i], r->last[i]);
                g_dump_line += b;
            }
        }
        r->trace.push_back(s);
        r->pc.push_back(static_cast<uint32_t>(r->prev));
    }
    for (int i = 0; i < 13; ++i) r->last[i] = v[i];
    r->prev = addr;
    r->mem = 0;
}

static void on_write(uc_engine *uc, uc_mem_type, uint64_t address, int size, int64_t value, void *ud) {
    Run *r = static_cast<Run *>(ud);
    uint64_t v = static_cast<uint64_t>(value);
    if (size < 8) v &= (1ull << (8 * size)) - 1;
    uint64_t old = 0;
    uc_mem_read(uc, address, &old, static_cast<size_t>(size));   /* the hook runs before the store */
    r->mem += __builtin_popcountll(g_hd ? (v ^ old) : v);
    if (g_dump >= 0 && static_cast<long>(r->trace.size()) == g_dump) {
        char b[48];
        std::snprintf(b, sizeof b, " w=%08llx(was %08llx)", static_cast<unsigned long long>(v),
                      static_cast<unsigned long long>(old));
        g_dump_line += b;
    }
}

static std::vector<unsigned char> g_image;

static void load_image(const char *path) {
    FILE *f = std::fopen(path, "rb");
    if (!f) { std::perror(path); std::exit(2); }
    unsigned char buf[65536];
    size_t n;
    while ((n = std::fread(buf, 1, sizeof buf, f)) > 0) g_image.insert(g_image.end(), buf, buf + n);
    std::fclose(f);
}

/* Run one kernel call; returns the trace. args are r0..r4 (r4 goes on the stack per AAPCS). */
static std::vector<double> run_kernel(uint32_t entry, const std::vector<uint32_t> &args,
                                      const std::vector<std::pair<uint64_t, std::vector<unsigned char>>> &mem) {
    Run r;
    if (uc_open(UC_ARCH_ARM, static_cast<uc_mode>(UC_MODE_THUMB | UC_MODE_MCLASS), &r.uc) != UC_ERR_OK) { std::fprintf(stderr, "uc_open\n"); std::exit(2); }
    uc_mem_map(r.uc, kBase, kSize, UC_PROT_ALL);
    uc_mem_write(r.uc, kBase, g_image.data(), g_image.size());
    for (const auto &m : mem) uc_mem_write(r.uc, m.first, m.second.data(), m.second.size());
    uint32_t sp = static_cast<uint32_t>(kStack);
    if (args.size() > 4) {
        sp -= 8;
        uint32_t a4 = args[4];
        uc_mem_write(r.uc, sp, &a4, 4);
    }
    const int ar[4] = {UC_ARM_REG_R0, UC_ARM_REG_R1, UC_ARM_REG_R2, UC_ARM_REG_R3};
    for (size_t i = 0; i < args.size() && i < 4; ++i) { uint32_t a = args[i]; uc_reg_write(r.uc, ar[i], &a); }
    uc_reg_write(r.uc, UC_ARM_REG_SP, &sp);
    uint32_t lr = static_cast<uint32_t>(TVLA_HALT) | 1u;
    uc_reg_write(r.uc, UC_ARM_REG_LR, &lr);
    uc_hook h1, h2;
    uc_hook_add(r.uc, &h1, UC_HOOK_CODE, reinterpret_cast<void *>(on_code), &r, 1, 0);
    uc_hook_add(r.uc, &h2, UC_HOOK_MEM_WRITE, reinterpret_cast<void *>(on_write), &r, 1, 0);
    const uc_err e = uc_emu_start(r.uc, entry | 1u, TVLA_HALT & ~1u, 0, 0);
    if (e != UC_ERR_OK) { std::fprintf(stderr, "emulation failed: %s\n", uc_strerror(e)); std::exit(2); }
    uc_close(r.uc);
    g_last_pc = r.pc;
    return r.trace;
}

/* ---- kernels and their input classes -------------------------------------------------- */
static std::vector<unsigned char> bytes16(const std::vector<int16_t> &v) {
    std::vector<unsigned char> b(v.size() * 2);
    std::memcpy(b.data(), v.data(), b.size());
    return b;
}
static std::vector<int16_t> poly(std::mt19937_64 &g) {
    std::vector<int16_t> p(256);
    for (auto &x : p) x = static_cast<int16_t>(g() % kQ);
    return p;
}
static std::vector<int16_t> sub_mod(const std::vector<int16_t> &a, const std::vector<int16_t> &b) {
    std::vector<int16_t> c(256);
    for (int i = 0; i < 256; ++i) c[i] = static_cast<int16_t>(((a[i] - b[i]) % kQ + kQ) % kQ);
    return c;
}

struct Kernel {
    const char *name;
    const char *what;
    bool masked;
    std::vector<double> (*trace)(const std::vector<int16_t> &secret, std::mt19937_64 &g);
};

static std::vector<int16_t> g_public;   /* the fixed public operand (u) */

static std::vector<double> k_basemul(const std::vector<int16_t> &s, std::mt19937_64 &) {
    const uint64_t a = kInput, b = a + 512, o = b + 512;
    return run_kernel(TVLA_MLKEM_BASEMUL, {uint32_t(a), uint32_t(b), uint32_t(o)},
                      {{a, bytes16(s)}, {b, bytes16(g_public)}});
}
static std::vector<double> k_basemul_masked(const std::vector<int16_t> &s, std::mt19937_64 &g) {
    const std::vector<int16_t> s0 = poly(g), s1 = sub_mod(s, s0);   /* fresh shares every run */
    const uint64_t a = kInput, a1 = a + 512, b = a1 + 512, o0 = b + 512, o1 = o0 + 512;
    return run_kernel(TVLA_MLKEM_BASEMUL_MASKED, {uint32_t(a), uint32_t(a1), uint32_t(b), uint32_t(o0), uint32_t(o1)},
                      {{a, bytes16(s0)}, {a1, bytes16(s1)}, {b, bytes16(g_public)}});
}
static std::vector<double> k_ntt(const std::vector<int16_t> &s, std::mt19937_64 &) {
    const uint64_t a = kInput;
    return run_kernel(TVLA_MLKEM_NTT, {uint32_t(a)}, {{a, bytes16(s)}});
}
static std::vector<double> k_ntt_masked(const std::vector<int16_t> &s, std::mt19937_64 &g) {
    const std::vector<int16_t> s0 = poly(g), s1 = sub_mod(s, s0);
    const uint64_t a = kInput, a1 = a + 512;
    return run_kernel(TVLA_MLKEM_NTT_MASKED, {uint32_t(a), uint32_t(a1)}, {{a, bytes16(s0)}, {a1, bytes16(s1)}});
}

/* ---- the masked gadgets: the secret is a byte string; class 0 fixed, class 1 random ---- */
static std::vector<unsigned char> rnd_bytes(std::mt19937_64 &g, size_t n) {
    std::vector<unsigned char> b(n);
    for (auto &x : b) x = static_cast<unsigned char>(g());
    return b;
}
/* decode: 32 coefficients in [0, q), as arithmetic shares (or share 1 zero for the control) */
static std::vector<double> k_decode(const std::vector<int16_t> &sec, std::mt19937_64 &g, bool masked) {
    std::vector<int16_t> a0(32), a1(32, 0);
    for (int j = 0; j < 32; ++j) a0[j] = sec[j];
    if (masked) {
        for (int j = 0; j < 32; ++j) {
            a1[j] = static_cast<int16_t>(g() % kQ);
            a0[j] = static_cast<int16_t>(((sec[j] - a1[j]) % kQ + kQ) % kQ);
        }
    }
    const uint64_t p0 = kInput, p1 = p0 + 64, o = p1 + 64;
    return run_kernel(TVLA_DECODE, {uint32_t(p0), uint32_t(p1), uint32_t(kRand), uint32_t(o)},
                      {{p0, bytes16(a0)}, {p1, bytes16(a1)}, {kRand, rnd_bytes(g, 65536)}});
}
static std::vector<double> k_decode_plain(const std::vector<int16_t> &s, std::mt19937_64 &g) { return k_decode(s, g, false); }
static std::vector<double> k_decode_masked(const std::vector<int16_t> &s, std::mt19937_64 &g) { return k_decode(s, g, true); }
/* Keccak-f[1600]: the secret is the 200-byte state (from the 256 coefficients' low bytes) */
static std::vector<double> k_keccak(const std::vector<int16_t> &sec, std::mt19937_64 &g, bool masked) {
    std::vector<unsigned char> st(200), m(200, 0);
    for (int i = 0; i < 200; ++i) st[i] = static_cast<unsigned char>(sec[i]);
    if (masked) {
        m = rnd_bytes(g, 200);
        for (int i = 0; i < 200; ++i) st[i] ^= m[i];
    }
    const uint64_t p0 = kInput, p1 = p0 + 200;
    return run_kernel(TVLA_KECCAK, {uint32_t(p0), uint32_t(p1), uint32_t(kRand)},
                      {{p0, st}, {p1, m}, {kRand, rnd_bytes(g, 24 * 25 * 8 + 64)}});
}
static std::vector<double> k_keccak_plain(const std::vector<int16_t> &s, std::mt19937_64 &g) { return k_keccak(s, g, false); }
static std::vector<double> k_keccak_masked(const std::vector<int16_t> &s, std::mt19937_64 &g) { return k_keccak(s, g, true); }
/* centred-binomial noise for 32 coefficients (eta = 2): the secret is the 16-byte PRF output */
static std::vector<double> k_cbd(const std::vector<int16_t> &sec, std::mt19937_64 &g, bool masked) {
    std::vector<unsigned char> b0(16), b1(16, 0);
    for (int i = 0; i < 16; ++i) b0[i] = static_cast<unsigned char>(sec[i]);
    if (masked) {
        b1 = rnd_bytes(g, 16);
        for (int i = 0; i < 16; ++i) b0[i] ^= b1[i];
    }
    const uint64_t p0 = kInput, p1 = p0 + 16, o = p1 + 16;
    return run_kernel(TVLA_CBD, {uint32_t(p0), uint32_t(p1), uint32_t(kRand), uint32_t(o)},
                      {{p0, b0}, {p1, b1}, {kRand, rnd_bytes(g, 65536)}});
}
static std::vector<double> k_cbd_plain(const std::vector<int16_t> &s, std::mt19937_64 &g) { return k_cbd(s, g, false); }
static std::vector<double> k_cbd_masked(const std::vector<int16_t> &s, std::mt19937_64 &g) { return k_cbd(s, g, true); }
/* ---- ML-DSA signing gadgets: q = 8380417 ---- */
static const int32_t kDsaQ = 8380417;
/* 32 secret values below 2^20 (y's packed fields), from the class's coefficients */
static std::vector<uint32_t> dsa_fields(const std::vector<int16_t> &sec) {
    std::vector<uint32_t> v(32);
    for (int j = 0; j < 32; ++j) v[j] = (static_cast<uint32_t>(sec[j]) * 317u + static_cast<uint32_t>(sec[j + 32])) & 0xFFFFFu;
    return v;
}
static std::vector<unsigned char> pack20(const std::vector<uint32_t> &v) {
    std::vector<unsigned char> b(80, 0);
    for (int j = 0; j < 32; ++j)
        for (int k = 0; k < 20; ++k)
            if ((v[j] >> k) & 1u) b[(20 * j + k) >> 3] |= static_cast<unsigned char>(1u << ((20 * j + k) & 7));
    return b;
}
static std::vector<double> k_dsa_b2a(const std::vector<int16_t> &sec, std::mt19937_64 &g, bool masked) {
    std::vector<uint32_t> v = dsa_fields(sec), m(32, 0);
    if (masked) {
        for (int j = 0; j < 32; ++j) {
            m[j] = static_cast<uint32_t>(g()) & 0xFFFFFu;
            v[j] ^= m[j];
        }
    }
    const uint64_t p0 = kInput, p1 = p0 + 80, o = p1 + 80;
    return run_kernel(TVLA_DSA_B2A, {uint32_t(p0), uint32_t(p1), uint32_t(kRand), uint32_t(o)},
                      {{p0, pack20(v)}, {p1, pack20(m)}, {kRand, rnd_bytes(g, 65536)}});
}
static std::vector<double> k_dsa_b2a_plain(const std::vector<int16_t> &s, std::mt19937_64 &g) { return k_dsa_b2a(s, g, false); }
static std::vector<double> k_dsa_b2a_masked(const std::vector<int16_t> &s, std::mt19937_64 &g) { return k_dsa_b2a(s, g, true); }
/* 32 secret values mod q, as arithmetic shares (share 1 zero for the control) */
static std::vector<double> dsa_arith(uint64_t entry, int32_t (*val)(const std::vector<int16_t> &, int),
                                     const std::vector<int16_t> &sec, std::mt19937_64 &g, bool masked) {
    std::vector<int32_t> a0(32), a1(32, 0);
    for (int j = 0; j < 32; ++j) {
        const int32_t a = val(sec, j);
        if (masked) {
            a1[j] = static_cast<int32_t>(g() % static_cast<uint64_t>(kDsaQ));
            a0[j] = ((a - a1[j]) % kDsaQ + kDsaQ) % kDsaQ;
        } else {
            a0[j] = a;
        }
    }
    auto bytes32 = [](const std::vector<int32_t> &v) {
        std::vector<unsigned char> b(v.size() * 4);
        std::memcpy(b.data(), v.data(), b.size());
        return b;
    };
    const uint64_t p0 = kInput, p1 = p0 + 128, o = p1 + 128;
    return run_kernel(entry, {uint32_t(p0), uint32_t(p1), uint32_t(kRand), uint32_t(o)},
                      {{p0, bytes32(a0)}, {p1, bytes32(a1)}, {kRand, rnd_bytes(g, 65536)}});
}
/* w - c s2 near a multiple of 2 gamma2: some lanes pass the window, some do not */
static int32_t dsa_val_w(const std::vector<int16_t> &sec, int j) {
    return static_cast<int32_t>((static_cast<int64_t>(sec[j]) * 2521 + sec[j + 32]) % kDsaQ);
}
/* z = y + c s1, centred near the norm bound, both signs */
static int32_t dsa_val_z(const std::vector<int16_t> &sec, int j) {
    const int32_t d = static_cast<int32_t>(sec[j]) * 160 - 266320;   /* in about +-2^19 */
    return d < 0 ? d + kDsaQ : d;
}
static std::vector<double> k_dsa_low_plain(const std::vector<int16_t> &s, std::mt19937_64 &g) { return dsa_arith(TVLA_DSA_LOWBITS, dsa_val_w, s, g, false); }
static std::vector<double> k_dsa_low_masked(const std::vector<int16_t> &s, std::mt19937_64 &g) { return dsa_arith(TVLA_DSA_LOWBITS, dsa_val_w, s, g, true); }
static std::vector<double> k_dsa_norm_plain(const std::vector<int16_t> &s, std::mt19937_64 &g) { return dsa_arith(TVLA_DSA_NORM, dsa_val_z, s, g, false); }
static std::vector<double> k_dsa_norm_masked(const std::vector<int16_t> &s, std::mt19937_64 &g) { return dsa_arith(TVLA_DSA_NORM, dsa_val_z, s, g, true); }


static const Kernel kKernels[] = {
    {"decode", "message decoding Compress_1, unmasked (control)", false, k_decode_plain},
    {"decode_masked", "masked decoding (sec_decode1)", true, k_decode_masked},
    {"keccak", "Keccak-f[1600] on a secret state, unmasked (control)", false, k_keccak_plain},
    {"keccak_masked", "masked Keccak-f[1600] (chi through the masked AND)", true, k_keccak_masked},
    {"cbd", "centred-binomial noise from a secret PRF output, unmasked (control)", false, k_cbd_plain},
    {"cbd_masked", "masked noise sampling (sec_cbd32 with Boolean-to-arithmetic)", true, k_cbd_masked},
    {"dsa_b2a", "ML-DSA y: Boolean-to-arithmetic mod 8380417, unmasked (control)", false, k_dsa_b2a_plain},
    {"dsa_b2a_masked", "ML-DSA y: masked Boolean-to-arithmetic (sec_b2a, kDsa)", true, k_dsa_b2a_masked},
    {"dsa_lowbits", "ML-DSA r0 window test (b' and the bounds), unmasked (control)", false, k_dsa_low_plain},
    {"dsa_lowbits_masked", "ML-DSA masked r0 window test (dsa_bprime, dsa_lowbits_ok)", true, k_dsa_low_masked},
    {"dsa_norm", "ML-DSA norm test of z, unmasked (control)", false, k_dsa_norm_plain},
    {"dsa_norm_masked", "ML-DSA masked norm test of z (dsa_norm_acc)", true, k_dsa_norm_masked},
    {"mlkem_basemul", "ML-KEM secret-key product s*u (NTT domain), unmasked", false, k_basemul},
    {"mlkem_basemul_masked", "ML-KEM secret-key product, first-order arithmetic masking", true, k_basemul_masked},
    {"mlkem_ntt", "ML-KEM forward NTT of a secret polynomial, unmasked", false, k_ntt},
    {"mlkem_ntt_masked", "ML-KEM forward NTT, first-order arithmetic masking", true, k_ntt_masked},
};

struct Acc {
    std::vector<double> mean[2], m2[2];
    double n[2] = {0, 0};
    void push(const std::vector<double> &x, int c) {
        if (mean[c].empty()) { mean[c].assign(x.size(), 0); m2[c].assign(x.size(), 0); }
        n[c] += 1;
        for (size_t i = 0; i < x.size(); ++i) {
            const double d = x[i] - mean[c][i];
            mean[c][i] += d / n[c];
            m2[c][i] += d * (x[i] - mean[c][i]);
        }
    }
};

/* Welch's t at every sample of one experiment. */
static std::vector<double> tvec(const Acc &acc, size_t len) {
    std::vector<double> t(len, 0);
    for (size_t i = 0; i < len; ++i) {
        const double v0 = acc.n[0] > 1 ? acc.m2[0][i] / (acc.n[0] - 1) : 0;
        const double v1 = acc.n[1] > 1 ? acc.m2[1][i] / (acc.n[1] - 1) : 0;
        const double den = std::sqrt(v0 / acc.n[0] + v1 / acc.n[1]);
        t[i] = den > 0 ? (acc.mean[0][i] - acc.mean[1][i]) / den : 0;
    }
    return t;
}

/* Two independent experiments, as the TVLA procedure prescribes: a sample point counts as
 * leaking only when |t| > 4.5 in both, with the same sign. With tens of thousands of points
 * a single experiment crosses 4.5 somewhere by chance (P(|t| > 4.5) is about 7e-6 per
 * point); two independent crossings at the same point do not happen by chance. */
static int run(const Kernel &k, int traces, std::mt19937_64 &g) {
    const std::vector<int16_t> fixed = poly(g);
    Acc acc[2];
    size_t len = 0;
    std::vector<uint32_t> first_pc;
    for (int e = 0; e < 2; ++e) {
        for (int i = 0; i < traces; ++i) {
            const int c = static_cast<int>(g() & 1u);
            const std::vector<double> t = k.trace(c == 0 ? fixed : poly(g), g);
            if (len == 0) { len = t.size(); first_pc = g_last_pc; }
            if (t.size() != len) {
                size_t d = 0;
                while (d < first_pc.size() && d < g_last_pc.size() && first_pc[d] == g_last_pc[d]) ++d;
                std::printf("%-22s trace length varies (%zu vs %zu): timing depends on the input; paths part after pc 0x%08x\n",
                            k.name, t.size(), len, d > 0 ? first_pc[d - 1] : 0u);
                return 1;
            }
            acc[e].push(t, c);
            if (g_dump >= 0) { std::fprintf(stderr, "DUMP c=%d%s\n", c, g_dump_line.c_str()); g_dump_line.clear(); }
        }
    }
    const std::vector<double> t1 = tvec(acc[0], len), t2 = tvec(acc[1], len);
    double tmax = 0;
    size_t both = 0, at = 0;
    for (size_t i = 0; i < len; ++i) {
        const double m = std::min(std::fabs(t1[i]), std::fabs(t2[i]));
        if (m > 4.5 && (t1[i] > 0) == (t2[i] > 0)) ++both;
        if (m > tmax) { tmax = m; at = i; }
    }
    const bool leaks = both > 0;
    if (leaks && at < g_last_pc.size()) {
        /* sample i records the instruction completed just before pc[i] */
        std::printf("  strongest leaking sample %zu: instruction at pc 0x%08x\n", at, g_last_pc[at]);
        for (size_t i = 0; i < len && i < g_last_pc.size(); ++i) {
            const double m = std::min(std::fabs(t1[i]), std::fabs(t2[i]));
            if (m > 4.5 && (t1[i] > 0) == (t2[i] > 0) && k.masked)
                std::printf("  leaking sample %zu: |t| %.1f, pc 0x%08x\n", i, m, g_last_pc[i]);
        }
    }
    std::printf("%-22s traces=2x%-5d samples=%-7zu min-of-two max|t|=%8.2f at %-6zu points leaking in both: %-6zu %s  (%s)\n",
                k.name, traces, len, tmax, at, both, leaks ? "FIRST-ORDER LEAKAGE" : "no first-order leakage", k.what);
    std::fflush(stdout);
    /* the unmasked kernels are expected to leak (they are the positive controls); a
     * masked kernel that leaks is the failure */
    if (k.masked && leaks) return 1;
    if (!k.masked && !leaks) { std::printf("  control NOT detected: the model sees nothing here\n"); return 1; }
    return 0;
}

int main(int argc, char **argv) {
    if (const char *d = std::getenv("TVLA_DUMP")) g_dump = std::atol(d);
    if (const char *m = std::getenv("TVLA_MODEL")) g_hd = std::strcmp(m, "hd") == 0;
    if (cs_open(CS_ARCH_ARM, static_cast<cs_mode>(CS_MODE_THUMB | CS_MODE_MCLASS), &g_cs) != CS_ERR_OK) {
        std::fprintf(stderr, "cs_open failed\n");
        return 2;
    }
    cs_option(g_cs, CS_OPT_DETAIL, CS_OPT_ON);
    const char *which = argc > 1 ? argv[1] : "all";
    const int traces = argc > 2 ? std::atoi(argv[2]) : 2000;
    if (std::strcmp(which, "list") == 0) {
        for (const auto &k : kKernels) std::printf("%-22s %s\n", k.name, k.what);
        return 0;
    }
    const char *img = std::getenv("TVLA_IMAGE");
    load_image(img ? img : "build/kernels.bin");
    std::random_device rd;
    std::mt19937_64 g(std::getenv("TVLA_SEED") ? std::strtoull(std::getenv("TVLA_SEED"), nullptr, 10) : (static_cast<uint64_t>(rd()) << 32) ^ rd());
    g_public = poly(g);
    int bad = 0, ran = 0;
    for (const auto &k : kKernels) {
        if (std::strcmp(which, "all") != 0 && std::strcmp(which, k.name) != 0) continue;
        bad += run(k, traces, g);
        ++ran;
    }
    if (!ran) { std::fprintf(stderr, "unknown kernel %s (try: list)\n", which); return 2; }
    return bad ? 1 : 0;
}
