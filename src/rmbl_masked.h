#ifndef RMBL_MASKED_H
#define RMBL_MASKED_H

/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * First-order masking gadgets (two shares) for ML-KEM decapsulation.
 *
 * A secret is held as two shares that are each uniformly random on their own: a Boolean
 * sharing x = x0 ^ x1, or an arithmetic sharing a = a0 + a1 (mod q). Linear operations act
 * on each share separately. The non-linear ones (AND, addition across bits, the
 * conversions between the two kinds of sharing) use fresh randomness so that no single
 * intermediate value depends on the secret. That is first-order security: an adversary
 * who sees any one intermediate value (a power sample, under the usual leakage model)
 * learns nothing about the secret. inst/tvla checks these gadgets, compiled for a
 * Cortex-M4, against that model.
 *
 * Algorithms: Trichina's two-share AND; a ripple-carry adder over Boolean shares
 * (Goubin 2001, bitsliced 32 coefficients to a word as in Bronchain and Cassiers, TCHES
 * 2022); conversion from arithmetic shares mod q by adding the shares inside the Boolean
 * domain and testing the sum against public constants (the decoding of Bos et al., TCHES
 * 2021, and the decompressed comparison of Bhasin et al., TCHES 2021, which replaces the
 * hash-based comparison of Oder et al. 2018 that Bhasin et al. broke); Boolean-to-
 * arithmetic conversion by a masked modular subtraction of a fresh arithmetic share; and
 * the masked Keccak of Bertoni et al. (2010), chi through the masked AND.
 *
 * No R, no allocation, no library calls: the package and the Cortex-M4 build share it.
 */

#include <stddef.h>
#include <stdint.h>

namespace rmbl_masked {

/* An opaque copy: stops the optimiser from seeing through a share computation and
 * recombining the shares (x0 ^ x1 computed in a register would unmask x). */
#if defined(__GNUC__) || defined(__clang__)
template <class T> inline T opaque(T x) {
    __asm__ volatile("" : "+r"(x));
    return x;
}
#else
template <class T> inline T opaque(T x) { return x; }
#endif

/* The randomness source: the package passes the operating system's CSPRNG, the Cortex-M4
 * build a buffer the host fills. */
struct Rng {
    uint32_t (*fn)(void *);
    void *ctx;
    uint32_t u32() { return fn(ctx); }
    uint64_t u64() {
        const uint64_t h = u32();
        return (h << 32) | u32();
    }
};

/* A modulus and the width of the bitsliced arithmetic that works on it: `bits` is the
 * two's-complement width of a comparison, so every value compared (below 2q) and every
 * constant must stay below 2^(bits - 1). */
struct Mod {
    int32_t q;
    int bits;
};
const int16_t kQ = 3329;                     /* ML-KEM, FIPS 203 */
const Mod kKem = {3329, 14};                 /* 2q < 2^13 */
const Mod kDsa = {8380417, 25};              /* ML-DSA, FIPS 204: 2q < 2^24 */

/* A value in [0, q) from 64 random bits by multiply-and-shift, floor(r q / 2^64) computed in
 * 32-bit halves (no 128-bit type on a 32-bit target): no loop, so the running time never
 * depends on the randomness (a rejection loop made the trace length vary). Its distance
 * from uniform is below q / 2^64 + 2^-32. */
inline int32_t rand_mod(Rng &rng, int32_t q) {
    const uint64_t r = rng.u64();
    const uint64_t lo = (static_cast<uint64_t>(static_cast<uint32_t>(r)) * static_cast<uint32_t>(q)) >> 32;
    const uint64_t hi = static_cast<uint64_t>(static_cast<uint32_t>(r >> 32)) * static_cast<uint32_t>(q) + lo;
    return static_cast<int32_t>(hi >> 32);
}
inline int16_t rand_q(Rng &rng) { return static_cast<int16_t>(rand_mod(rng, kQ)); }

/* v + q when v < 0, else v, for v in (-2^31, 2^31 - q): the sign becomes an all-ones or
 * all-zero mask through opaque(), so the compiler cannot turn it back into a conditional
 * (an IT block on Thumb-2 executes or skips the add depending on the share). */
inline int32_t cadd_mod(int32_t v, int32_t q) {
    const uint32_t m = opaque(static_cast<uint32_t>(0u - (static_cast<uint32_t>(v) >> 31)));
    return static_cast<int32_t>(static_cast<uint32_t>(v) + (static_cast<uint32_t>(q) & m));
}
inline int32_t cadd_q(int32_t v) { return cadd_mod(v, kQ); }

/* ---- share-pair primitives ---------------------------------------------------------------
 *
 * Every operation that reads or writes both shares of one value goes through the functions
 * below, which work memory to memory. On a Cortex-M (Thumb-2) they are assembly with a fixed
 * register order: each temporary is zeroed before it takes a new operand, each destination
 * word is zeroed before it is written, and a zero is stored to a scratch word between the
 * share-0 store and the share-1 store. So no register, memory word or store bus ever goes
 * from a value of one share to a value of the other share of the same secret: the switching
 * a power trace records (the transition, or Hamming-distance, model) carries no first-order
 * information, as the values themselves (the Hamming-weight model) already did not.
 * The same instruction sequences are written for x86-64 and aarch64, so the package's builds
 * keep the same discipline; inst/tvla checks both models on the Cortex-M4 build. Any other
 * target uses plain C with the same arithmetic.
 *
 * Code that touches one share at a time (bitslicing one arithmetic share, the linear layers
 * of Keccak) runs share 0 and share 1 in separate passes with rmbl_mask_scrub() between, which
 * zeroes the general-purpose registers so the second pass never overwrites a value of the
 * first. */
struct P2 {
    uint32_t *z0, *z1;
    const uint32_t *x0, *x1, *y0, *y1;
};

inline volatile uint32_t *mask_bus() {
    static volatile uint32_t b = 0;
    return &b;
}

#if defined(__arm__) && defined(__thumb2__) && !defined(RMBL_MASK_PORTABLE)
#define RMBL_MASK_THUMB2 1
#define RMBL_MASK_ASM 1
inline void rmbl_mask_scrub() {
    __asm__ volatile(
        "mov r0, #0\n\tmov r1, #0\n\tmov r2, #0\n\tmov r3, #0\n\tmov r4, #0\n\tmov r5, #0\n\t"
        "mov r6, #0\n\tmov r8, #0\n\tmov r9, #0\n\tmov r10, #0\n\tmov r11, #0\n\tmov r12, #0"
        ::: "r0", "r1", "r2", "r3", "r4", "r5", "r6", "r8", "r9", "r10", "r11", "r12", "memory");
}
#elif defined(__x86_64__) && (defined(__GNUC__) || defined(__clang__)) && !defined(RMBL_MASK_PORTABLE)
#define RMBL_MASK_X64 1
#define RMBL_MASK_ASM 1
inline void rmbl_mask_scrub() {
    __asm__ volatile(
        "xorl %%eax, %%eax\n\txorl %%ecx, %%ecx\n\txorl %%edx, %%edx\n\txorl %%esi, %%esi\n\txorl %%edi, %%edi\n\t"
        "xorl %%r8d, %%r8d\n\txorl %%r9d, %%r9d\n\txorl %%r10d, %%r10d\n\txorl %%r11d, %%r11d\n\t"
        "xorl %%ebx, %%ebx\n\txorl %%r12d, %%r12d\n\txorl %%r13d, %%r13d\n\txorl %%r14d, %%r14d\n\txorl %%r15d, %%r15d\n\t"
        "pxor %%xmm0, %%xmm0\n\tpxor %%xmm1, %%xmm1\n\tpxor %%xmm2, %%xmm2\n\tpxor %%xmm3, %%xmm3\n\t"
        "pxor %%xmm4, %%xmm4\n\tpxor %%xmm5, %%xmm5\n\tpxor %%xmm6, %%xmm6\n\tpxor %%xmm7, %%xmm7\n\t"
        "pxor %%xmm8, %%xmm8\n\tpxor %%xmm9, %%xmm9\n\tpxor %%xmm10, %%xmm10\n\tpxor %%xmm11, %%xmm11\n\t"
        "pxor %%xmm12, %%xmm12\n\tpxor %%xmm13, %%xmm13\n\tpxor %%xmm14, %%xmm14\n\tpxor %%xmm15, %%xmm15"
        ::: "rax", "rcx", "rdx", "rsi", "rdi", "r8", "r9", "r10", "r11", "rbx", "r12", "r13", "r14", "r15",
            "xmm0", "xmm1", "xmm2", "xmm3", "xmm4", "xmm5", "xmm6", "xmm7", "xmm8", "xmm9", "xmm10", "xmm11",
            "xmm12", "xmm13", "xmm14", "xmm15", "memory", "cc");
}
#elif defined(__aarch64__) && (defined(__GNUC__) || defined(__clang__)) && !defined(RMBL_MASK_PORTABLE)
#define RMBL_MASK_A64 1
#define RMBL_MASK_ASM 1
inline void rmbl_mask_scrub() {
    /* x18 is the platform register (macOS, Windows) and x29/x30 the frame and link registers */
    __asm__ volatile(
        "mov x0, xzr\n\tmov x1, xzr\n\tmov x2, xzr\n\tmov x3, xzr\n\tmov x4, xzr\n\tmov x5, xzr\n\t"
        "mov x6, xzr\n\tmov x7, xzr\n\tmov x8, xzr\n\tmov x9, xzr\n\tmov x10, xzr\n\tmov x11, xzr\n\t"
        "mov x12, xzr\n\tmov x13, xzr\n\tmov x14, xzr\n\tmov x15, xzr\n\tmov x16, xzr\n\tmov x17, xzr\n\t"
        "mov x19, xzr\n\tmov x20, xzr\n\tmov x21, xzr\n\tmov x22, xzr\n\tmov x23, xzr\n\tmov x24, xzr\n\t"
        "mov x25, xzr\n\tmov x26, xzr\n\tmov x27, xzr\n\tmov x28, xzr\n\t"
        "movi v0.2d, #0\n\tmovi v1.2d, #0\n\tmovi v2.2d, #0\n\tmovi v3.2d, #0\n\tmovi v4.2d, #0\n\tmovi v5.2d, #0\n\t"
        "movi v6.2d, #0\n\tmovi v7.2d, #0\n\tmovi v8.2d, #0\n\tmovi v9.2d, #0\n\tmovi v10.2d, #0\n\tmovi v11.2d, #0\n\t"
        "movi v12.2d, #0\n\tmovi v13.2d, #0\n\tmovi v14.2d, #0\n\tmovi v15.2d, #0\n\tmovi v16.2d, #0\n\tmovi v17.2d, #0\n\t"
        "movi v18.2d, #0\n\tmovi v19.2d, #0\n\tmovi v20.2d, #0\n\tmovi v21.2d, #0\n\tmovi v22.2d, #0\n\tmovi v23.2d, #0\n\t"
        "movi v24.2d, #0\n\tmovi v25.2d, #0\n\tmovi v26.2d, #0\n\tmovi v27.2d, #0\n\tmovi v28.2d, #0\n\tmovi v29.2d, #0\n\t"
        "movi v30.2d, #0\n\tmovi v31.2d, #0"
        ::: "x0", "x1", "x2", "x3", "x4", "x5", "x6", "x7", "x8", "x9", "x10", "x11", "x12", "x13", "x14", "x15",
            "x16", "x17", "x19", "x20", "x21", "x22", "x23", "x24", "x25", "x26", "x27", "x28",
            "v0", "v1", "v2", "v3", "v4", "v5", "v6", "v7", "v8", "v9", "v10", "v11", "v12", "v13", "v14", "v15",
            "v16", "v17", "v18", "v19", "v20", "v21", "v22", "v23", "v24", "v25", "v26", "v27", "v28", "v29",
            "v30", "v31", "memory", "cc");
}
#else
inline void rmbl_mask_scrub() {
#if defined(__GNUC__) || defined(__clang__)
    __asm__ volatile("" ::: "memory");
#endif
}
#endif

/* z = x & y, Trichina: z0 = r, z1 = r ^ x0y0 ^ x0y1 ^ x1y0 ^ x1y1, each partial product in a
 * freshly zeroed register. All loads precede all stores, so z may alias x or y. The three
 * instruction sequences are written to the same pattern, operation for operation. */
inline void m_and(const P2 &p, uint32_t r) {
#if RMBL_MASK_THUMB2
    uint32_t t, a, b;
    uint32_t q;
    __asm__ volatile(
            "mov %[a], #0\n\t"
            "mov %[b], #0\n\t"
            "mov %[t], %[r]\n\t"
            "ldr %[q], [%[p], #8]\n\t"
            "ldr %[a], [%[q]]\n\t"
            "ldr %[q], [%[p], #16]\n\t"
            "ldr %[b], [%[q]]\n\t"
            "and %[a], %[a], %[b]\n\t"
            "eor %[t], %[t], %[a]\n\t"
            "mov %[a], #0\n\t"
            "mov %[b], #0\n\t"
            "ldr %[q], [%[p], #8]\n\t"
            "ldr %[a], [%[q]]\n\t"
            "ldr %[q], [%[p], #20]\n\t"
            "ldr %[b], [%[q]]\n\t"
            "and %[a], %[a], %[b]\n\t"
            "eor %[t], %[t], %[a]\n\t"
            "mov %[a], #0\n\t"
            "mov %[b], #0\n\t"
            "ldr %[q], [%[p], #12]\n\t"
            "ldr %[a], [%[q]]\n\t"
            "ldr %[q], [%[p], #16]\n\t"
            "ldr %[b], [%[q]]\n\t"
            "and %[a], %[a], %[b]\n\t"
            "eor %[t], %[t], %[a]\n\t"
            "mov %[a], #0\n\t"
            "mov %[b], #0\n\t"
            "ldr %[q], [%[p], #12]\n\t"
            "ldr %[a], [%[q]]\n\t"
            "ldr %[q], [%[p], #20]\n\t"
            "ldr %[b], [%[q]]\n\t"
            "and %[a], %[a], %[b]\n\t"
            "eor %[t], %[t], %[a]\n\t"
            "mov %[a], #0\n\t"
            "mov %[b], #0\n\t"
            "ldr %[q], [%[p], #4]\n\t"
            "str %[a], [%[q]]\n\t"
            "str %[t], [%[q]]\n\t"
            "str %[a], [%[bus]]\n\t"
            "mov %[t], #0\n\t"
            "ldr %[q], [%[p], #0]\n\t"
            "str %[a], [%[q]]\n\t"
            "str %[r], [%[q]]\n\t"
            "mov %[q], #0"
            : [t] "=&r"(t), [a] "=&r"(a), [b] "=&r"(b), [q] "=&r"(q)
            : [p] "r"(&p), [r] "r"(r), [bus] "r"(mask_bus())
            : "memory", "cc");
#elif RMBL_MASK_X64
    uint32_t t, a, b;
    uintptr_t q;
    __asm__ volatile(
            "xorl %k[a], %k[a]\n\t"
            "xorl %k[b], %k[b]\n\t"
            "movl %k[r], %k[t]\n\t"
            "movq 16(%[p]), %[q]\n\t"
            "movl (%[q]), %k[a]\n\t"
            "movq 32(%[p]), %[q]\n\t"
            "movl (%[q]), %k[b]\n\t"
            "andl %k[b], %k[a]\n\t"
            "xorl %k[a], %k[t]\n\t"
            "xorl %k[a], %k[a]\n\t"
            "xorl %k[b], %k[b]\n\t"
            "movq 16(%[p]), %[q]\n\t"
            "movl (%[q]), %k[a]\n\t"
            "movq 40(%[p]), %[q]\n\t"
            "movl (%[q]), %k[b]\n\t"
            "andl %k[b], %k[a]\n\t"
            "xorl %k[a], %k[t]\n\t"
            "xorl %k[a], %k[a]\n\t"
            "xorl %k[b], %k[b]\n\t"
            "movq 24(%[p]), %[q]\n\t"
            "movl (%[q]), %k[a]\n\t"
            "movq 32(%[p]), %[q]\n\t"
            "movl (%[q]), %k[b]\n\t"
            "andl %k[b], %k[a]\n\t"
            "xorl %k[a], %k[t]\n\t"
            "xorl %k[a], %k[a]\n\t"
            "xorl %k[b], %k[b]\n\t"
            "movq 24(%[p]), %[q]\n\t"
            "movl (%[q]), %k[a]\n\t"
            "movq 40(%[p]), %[q]\n\t"
            "movl (%[q]), %k[b]\n\t"
            "andl %k[b], %k[a]\n\t"
            "xorl %k[a], %k[t]\n\t"
            "xorl %k[a], %k[a]\n\t"
            "xorl %k[b], %k[b]\n\t"
            "movq 8(%[p]), %[q]\n\t"
            "movl %k[a], (%[q])\n\t"
            "movl %k[t], (%[q])\n\t"
            "movl %k[a], (%[bus])\n\t"
            "xorl %k[t], %k[t]\n\t"
            "movq 0(%[p]), %[q]\n\t"
            "movl %k[a], (%[q])\n\t"
            "movl %k[r], (%[q])\n\t"
            "xorl %k[q], %k[q]"
            : [t] "=&r"(t), [a] "=&r"(a), [b] "=&r"(b), [q] "=&r"(q)
            : [p] "r"(&p), [r] "r"(r), [bus] "r"(mask_bus())
            : "memory", "cc");
#elif RMBL_MASK_A64
    uint32_t t, a, b;
    uintptr_t q;
    __asm__ volatile(
            "mov %w[a], wzr\n\t"
            "mov %w[b], wzr\n\t"
            "mov %w[t], %w[r]\n\t"
            "ldr %[q], [%[p], #16]\n\t"
            "ldr %w[a], [%[q]]\n\t"
            "ldr %[q], [%[p], #32]\n\t"
            "ldr %w[b], [%[q]]\n\t"
            "and %w[a], %w[a], %w[b]\n\t"
            "eor %w[t], %w[t], %w[a]\n\t"
            "mov %w[a], wzr\n\t"
            "mov %w[b], wzr\n\t"
            "ldr %[q], [%[p], #16]\n\t"
            "ldr %w[a], [%[q]]\n\t"
            "ldr %[q], [%[p], #40]\n\t"
            "ldr %w[b], [%[q]]\n\t"
            "and %w[a], %w[a], %w[b]\n\t"
            "eor %w[t], %w[t], %w[a]\n\t"
            "mov %w[a], wzr\n\t"
            "mov %w[b], wzr\n\t"
            "ldr %[q], [%[p], #24]\n\t"
            "ldr %w[a], [%[q]]\n\t"
            "ldr %[q], [%[p], #32]\n\t"
            "ldr %w[b], [%[q]]\n\t"
            "and %w[a], %w[a], %w[b]\n\t"
            "eor %w[t], %w[t], %w[a]\n\t"
            "mov %w[a], wzr\n\t"
            "mov %w[b], wzr\n\t"
            "ldr %[q], [%[p], #24]\n\t"
            "ldr %w[a], [%[q]]\n\t"
            "ldr %[q], [%[p], #40]\n\t"
            "ldr %w[b], [%[q]]\n\t"
            "and %w[a], %w[a], %w[b]\n\t"
            "eor %w[t], %w[t], %w[a]\n\t"
            "mov %w[a], wzr\n\t"
            "mov %w[b], wzr\n\t"
            "ldr %[q], [%[p], #8]\n\t"
            "str %w[a], [%[q]]\n\t"
            "str %w[t], [%[q]]\n\t"
            "str %w[a], [%[bus]]\n\t"
            "mov %w[t], wzr\n\t"
            "ldr %[q], [%[p], #0]\n\t"
            "str %w[a], [%[q]]\n\t"
            "str %w[r], [%[q]]\n\t"
            "mov %[q], xzr"
            : [t] "=&r"(t), [a] "=&r"(a), [b] "=&r"(b), [q] "=&r"(q)
            : [p] "r"(&p), [r] "r"(r), [bus] "r"(mask_bus())
            : "memory", "cc");
#else
    const uint32_t x0 = *p.x0, x1 = *p.x1, y0 = *p.y0, y1 = *p.y1;
    uint32_t t = opaque(static_cast<uint32_t>(r ^ (x0 & y0)));
    t = opaque(static_cast<uint32_t>(t ^ (x0 & y1)));
    t = opaque(static_cast<uint32_t>(t ^ (x1 & y0)));
    t = opaque(static_cast<uint32_t>(t ^ (x1 & y1)));
    *p.z0 = r;
    *p.z1 = t;
#endif
}

/* z = x ^ y, share by share */
inline void m_xor(const P2 &p) {
#if RMBL_MASK_THUMB2
    uint32_t a, b;
    uint32_t q;
    __asm__ volatile(
            "mov %[a], #0\n\t"
            "mov %[b], #0\n\t"
            "ldr %[q], [%[p], #8]\n\t"
            "ldr %[a], [%[q]]\n\t"
            "ldr %[q], [%[p], #16]\n\t"
            "ldr %[b], [%[q]]\n\t"
            "eor %[a], %[a], %[b]\n\t"
            "mov %[b], #0\n\t"
            "ldr %[q], [%[p], #0]\n\t"
            "str %[b], [%[q]]\n\t"
            "str %[a], [%[q]]\n\t"
            "mov %[a], #0\n\t"
            "str %[a], [%[bus]]\n\t"
            "ldr %[q], [%[p], #12]\n\t"
            "ldr %[a], [%[q]]\n\t"
            "ldr %[q], [%[p], #20]\n\t"
            "ldr %[b], [%[q]]\n\t"
            "eor %[a], %[a], %[b]\n\t"
            "mov %[b], #0\n\t"
            "ldr %[q], [%[p], #4]\n\t"
            "str %[b], [%[q]]\n\t"
            "str %[a], [%[q]]\n\t"
            "mov %[a], #0\n\t"
            "mov %[q], #0"
            : [a] "=&r"(a), [b] "=&r"(b), [q] "=&r"(q)
            : [p] "r"(&p), [bus] "r"(mask_bus())
            : "memory", "cc");
#elif RMBL_MASK_X64
    uint32_t a, b;
    uintptr_t q;
    __asm__ volatile(
            "xorl %k[a], %k[a]\n\t"
            "xorl %k[b], %k[b]\n\t"
            "movq 16(%[p]), %[q]\n\t"
            "movl (%[q]), %k[a]\n\t"
            "movq 32(%[p]), %[q]\n\t"
            "movl (%[q]), %k[b]\n\t"
            "xorl %k[b], %k[a]\n\t"
            "xorl %k[b], %k[b]\n\t"
            "movq 0(%[p]), %[q]\n\t"
            "movl %k[b], (%[q])\n\t"
            "movl %k[a], (%[q])\n\t"
            "xorl %k[a], %k[a]\n\t"
            "movl %k[a], (%[bus])\n\t"
            "movq 24(%[p]), %[q]\n\t"
            "movl (%[q]), %k[a]\n\t"
            "movq 40(%[p]), %[q]\n\t"
            "movl (%[q]), %k[b]\n\t"
            "xorl %k[b], %k[a]\n\t"
            "xorl %k[b], %k[b]\n\t"
            "movq 8(%[p]), %[q]\n\t"
            "movl %k[b], (%[q])\n\t"
            "movl %k[a], (%[q])\n\t"
            "xorl %k[a], %k[a]\n\t"
            "xorl %k[q], %k[q]"
            : [a] "=&r"(a), [b] "=&r"(b), [q] "=&r"(q)
            : [p] "r"(&p), [bus] "r"(mask_bus())
            : "memory", "cc");
#elif RMBL_MASK_A64
    uint32_t a, b;
    uintptr_t q;
    __asm__ volatile(
            "mov %w[a], wzr\n\t"
            "mov %w[b], wzr\n\t"
            "ldr %[q], [%[p], #16]\n\t"
            "ldr %w[a], [%[q]]\n\t"
            "ldr %[q], [%[p], #32]\n\t"
            "ldr %w[b], [%[q]]\n\t"
            "eor %w[a], %w[a], %w[b]\n\t"
            "mov %w[b], wzr\n\t"
            "ldr %[q], [%[p], #0]\n\t"
            "str %w[b], [%[q]]\n\t"
            "str %w[a], [%[q]]\n\t"
            "mov %w[a], wzr\n\t"
            "str %w[a], [%[bus]]\n\t"
            "ldr %[q], [%[p], #24]\n\t"
            "ldr %w[a], [%[q]]\n\t"
            "ldr %[q], [%[p], #40]\n\t"
            "ldr %w[b], [%[q]]\n\t"
            "eor %w[a], %w[a], %w[b]\n\t"
            "mov %w[b], wzr\n\t"
            "ldr %[q], [%[p], #8]\n\t"
            "str %w[b], [%[q]]\n\t"
            "str %w[a], [%[q]]\n\t"
            "mov %w[a], wzr\n\t"
            "mov %[q], xzr"
            : [a] "=&r"(a), [b] "=&r"(b), [q] "=&r"(q)
            : [p] "r"(&p), [bus] "r"(mask_bus())
            : "memory", "cc");
#else
    const uint32_t a = *p.x0 ^ *p.y0;
    *p.z0 = opaque(a);
    const uint32_t b = *p.x1 ^ *p.y1;
    *p.z1 = opaque(b);
#endif
}

/* z = x op c for a public word c: op 0 xor (into share 0 only), 1 and (both shares), 2 shift
 * right by c (both shares), 3 copy, 4 bit 0 to an all-zero or all-one word (both shares: the
 * XOR of the two results is all ones exactly when the shared bit is 1) */
inline void m_pub(const P2 &p, uint32_t c, int op) {
#if RMBL_MASK_THUMB2
    uint32_t a, b;
    uint32_t q;
    if (op == 0) {
        __asm__ volatile(
                "mov %[a], #0\n\t"
                "mov %[b], #0\n\t"
                "ldr %[q], [%[p], #8]\n\t"
                "ldr %[a], [%[q]]\n\t"
                "eor %[a], %[a], %[c]\n\t"
                "ldr %[q], [%[p], #0]\n\t"
                "str %[b], [%[q]]\n\t"
                "str %[a], [%[q]]\n\t"
                "mov %[a], #0\n\t"
                "str %[a], [%[bus]]\n\t"
                "ldr %[q], [%[p], #12]\n\t"
                "ldr %[a], [%[q]]\n\t"
                "ldr %[q], [%[p], #4]\n\t"
                "str %[b], [%[q]]\n\t"
                "str %[a], [%[q]]\n\t"
                "mov %[a], #0\n\t"
                "mov %[q], #0"
                : [a] "=&r"(a), [b] "=&r"(b), [q] "=&r"(q)
                : [p] "r"(&p), [bus] "r"(mask_bus()), [c] "r"(c)
                : "memory", "cc");
    }
    else if (op == 1) {
        __asm__ volatile(
                "mov %[a], #0\n\t"
                "mov %[b], #0\n\t"
                "ldr %[q], [%[p], #8]\n\t"
                "ldr %[a], [%[q]]\n\t"
                "and %[a], %[a], %[c]\n\t"
                "ldr %[q], [%[p], #0]\n\t"
                "str %[b], [%[q]]\n\t"
                "str %[a], [%[q]]\n\t"
                "mov %[a], #0\n\t"
                "str %[a], [%[bus]]\n\t"
                "ldr %[q], [%[p], #12]\n\t"
                "ldr %[a], [%[q]]\n\t"
                "and %[a], %[a], %[c]\n\t"
                "ldr %[q], [%[p], #4]\n\t"
                "str %[b], [%[q]]\n\t"
                "str %[a], [%[q]]\n\t"
                "mov %[a], #0\n\t"
                "mov %[q], #0"
                : [a] "=&r"(a), [b] "=&r"(b), [q] "=&r"(q)
                : [p] "r"(&p), [bus] "r"(mask_bus()), [c] "r"(c)
                : "memory", "cc");
    }
    else if (op == 2) {
        __asm__ volatile(
                "mov %[a], #0\n\t"
                "mov %[b], #0\n\t"
                "ldr %[q], [%[p], #8]\n\t"
                "ldr %[a], [%[q]]\n\t"
                "lsr %[a], %[a], %[c]\n\t"
                "ldr %[q], [%[p], #0]\n\t"
                "str %[b], [%[q]]\n\t"
                "str %[a], [%[q]]\n\t"
                "mov %[a], #0\n\t"
                "str %[a], [%[bus]]\n\t"
                "ldr %[q], [%[p], #12]\n\t"
                "ldr %[a], [%[q]]\n\t"
                "lsr %[a], %[a], %[c]\n\t"
                "ldr %[q], [%[p], #4]\n\t"
                "str %[b], [%[q]]\n\t"
                "str %[a], [%[q]]\n\t"
                "mov %[a], #0\n\t"
                "mov %[q], #0"
                : [a] "=&r"(a), [b] "=&r"(b), [q] "=&r"(q)
                : [p] "r"(&p), [bus] "r"(mask_bus()), [c] "r"(c)
                : "memory", "cc");
    }
    else if (op == 3) {
        __asm__ volatile(
                "mov %[a], #0\n\t"
                "mov %[b], #0\n\t"
                "ldr %[q], [%[p], #8]\n\t"
                "ldr %[a], [%[q]]\n\t"
                "ldr %[q], [%[p], #0]\n\t"
                "str %[b], [%[q]]\n\t"
                "str %[a], [%[q]]\n\t"
                "mov %[a], #0\n\t"
                "str %[a], [%[bus]]\n\t"
                "ldr %[q], [%[p], #12]\n\t"
                "ldr %[a], [%[q]]\n\t"
                "ldr %[q], [%[p], #4]\n\t"
                "str %[b], [%[q]]\n\t"
                "str %[a], [%[q]]\n\t"
                "mov %[a], #0\n\t"
                "mov %[q], #0"
                : [a] "=&r"(a), [b] "=&r"(b), [q] "=&r"(q)
                : [p] "r"(&p), [bus] "r"(mask_bus())
                : "memory", "cc");
    }
    else if (op == 4) {
        __asm__ volatile(
                "mov %[a], #0\n\t"
                "mov %[b], #0\n\t"
                "ldr %[q], [%[p], #8]\n\t"
                "ldr %[a], [%[q]]\n\t"
                "and %[a], %[a], #1\n\t"
                "rsb %[a], %[a], #0\n\t"
                "ldr %[q], [%[p], #0]\n\t"
                "str %[b], [%[q]]\n\t"
                "str %[a], [%[q]]\n\t"
                "mov %[a], #0\n\t"
                "str %[a], [%[bus]]\n\t"
                "ldr %[q], [%[p], #12]\n\t"
                "ldr %[a], [%[q]]\n\t"
                "and %[a], %[a], #1\n\t"
                "rsb %[a], %[a], #0\n\t"
                "ldr %[q], [%[p], #4]\n\t"
                "str %[b], [%[q]]\n\t"
                "str %[a], [%[q]]\n\t"
                "mov %[a], #0\n\t"
                "mov %[q], #0"
                : [a] "=&r"(a), [b] "=&r"(b), [q] "=&r"(q)
                : [p] "r"(&p), [bus] "r"(mask_bus())
                : "memory", "cc");
    }
    (void)a; (void)b; (void)q;
#elif RMBL_MASK_X64
    uint32_t a, b;
    uintptr_t q;
    if (op == 0) {
        __asm__ volatile(
                "xorl %k[a], %k[a]\n\t"
                "xorl %k[b], %k[b]\n\t"
                "movq 16(%[p]), %[q]\n\t"
                "movl (%[q]), %k[a]\n\t"
                "xorl %k[c], %k[a]\n\t"
                "movq 0(%[p]), %[q]\n\t"
                "movl %k[b], (%[q])\n\t"
                "movl %k[a], (%[q])\n\t"
                "xorl %k[a], %k[a]\n\t"
                "movl %k[a], (%[bus])\n\t"
                "movq 24(%[p]), %[q]\n\t"
                "movl (%[q]), %k[a]\n\t"
                "movq 8(%[p]), %[q]\n\t"
                "movl %k[b], (%[q])\n\t"
                "movl %k[a], (%[q])\n\t"
                "xorl %k[a], %k[a]\n\t"
                "xorl %k[q], %k[q]"
                : [a] "=&r"(a), [b] "=&r"(b), [q] "=&r"(q)
                : [p] "r"(&p), [bus] "r"(mask_bus()), [c] "r"(c)
                : "memory", "cc");
    }
    else if (op == 1) {
        __asm__ volatile(
                "xorl %k[a], %k[a]\n\t"
                "xorl %k[b], %k[b]\n\t"
                "movq 16(%[p]), %[q]\n\t"
                "movl (%[q]), %k[a]\n\t"
                "andl %k[c], %k[a]\n\t"
                "movq 0(%[p]), %[q]\n\t"
                "movl %k[b], (%[q])\n\t"
                "movl %k[a], (%[q])\n\t"
                "xorl %k[a], %k[a]\n\t"
                "movl %k[a], (%[bus])\n\t"
                "movq 24(%[p]), %[q]\n\t"
                "movl (%[q]), %k[a]\n\t"
                "andl %k[c], %k[a]\n\t"
                "movq 8(%[p]), %[q]\n\t"
                "movl %k[b], (%[q])\n\t"
                "movl %k[a], (%[q])\n\t"
                "xorl %k[a], %k[a]\n\t"
                "xorl %k[q], %k[q]"
                : [a] "=&r"(a), [b] "=&r"(b), [q] "=&r"(q)
                : [p] "r"(&p), [bus] "r"(mask_bus()), [c] "r"(c)
                : "memory", "cc");
    }
    else if (op == 2) {
        __asm__ volatile(
                "xorl %k[a], %k[a]\n\t"
                "xorl %k[b], %k[b]\n\t"
                "movq 16(%[p]), %[q]\n\t"
                "movl (%[q]), %k[a]\n\t"
                "shrl %%cl, %k[a]\n\t"
                "movq 0(%[p]), %[q]\n\t"
                "movl %k[b], (%[q])\n\t"
                "movl %k[a], (%[q])\n\t"
                "xorl %k[a], %k[a]\n\t"
                "movl %k[a], (%[bus])\n\t"
                "movq 24(%[p]), %[q]\n\t"
                "movl (%[q]), %k[a]\n\t"
                "shrl %%cl, %k[a]\n\t"
                "movq 8(%[p]), %[q]\n\t"
                "movl %k[b], (%[q])\n\t"
                "movl %k[a], (%[q])\n\t"
                "xorl %k[a], %k[a]\n\t"
                "xorl %k[q], %k[q]"
                : [a] "=&r"(a), [b] "=&r"(b), [q] "=&r"(q)
                : [p] "r"(&p), [bus] "r"(mask_bus()), [c] "c"(c)
                : "memory", "cc");
    }
    else if (op == 3) {
        __asm__ volatile(
                "xorl %k[a], %k[a]\n\t"
                "xorl %k[b], %k[b]\n\t"
                "movq 16(%[p]), %[q]\n\t"
                "movl (%[q]), %k[a]\n\t"
                "movq 0(%[p]), %[q]\n\t"
                "movl %k[b], (%[q])\n\t"
                "movl %k[a], (%[q])\n\t"
                "xorl %k[a], %k[a]\n\t"
                "movl %k[a], (%[bus])\n\t"
                "movq 24(%[p]), %[q]\n\t"
                "movl (%[q]), %k[a]\n\t"
                "movq 8(%[p]), %[q]\n\t"
                "movl %k[b], (%[q])\n\t"
                "movl %k[a], (%[q])\n\t"
                "xorl %k[a], %k[a]\n\t"
                "xorl %k[q], %k[q]"
                : [a] "=&r"(a), [b] "=&r"(b), [q] "=&r"(q)
                : [p] "r"(&p), [bus] "r"(mask_bus())
                : "memory", "cc");
    }
    else if (op == 4) {
        __asm__ volatile(
                "xorl %k[a], %k[a]\n\t"
                "xorl %k[b], %k[b]\n\t"
                "movq 16(%[p]), %[q]\n\t"
                "movl (%[q]), %k[a]\n\t"
                "andl $1, %k[a]\n\t"
                "negl %k[a]\n\t"
                "movq 0(%[p]), %[q]\n\t"
                "movl %k[b], (%[q])\n\t"
                "movl %k[a], (%[q])\n\t"
                "xorl %k[a], %k[a]\n\t"
                "movl %k[a], (%[bus])\n\t"
                "movq 24(%[p]), %[q]\n\t"
                "movl (%[q]), %k[a]\n\t"
                "andl $1, %k[a]\n\t"
                "negl %k[a]\n\t"
                "movq 8(%[p]), %[q]\n\t"
                "movl %k[b], (%[q])\n\t"
                "movl %k[a], (%[q])\n\t"
                "xorl %k[a], %k[a]\n\t"
                "xorl %k[q], %k[q]"
                : [a] "=&r"(a), [b] "=&r"(b), [q] "=&r"(q)
                : [p] "r"(&p), [bus] "r"(mask_bus())
                : "memory", "cc");
    }
    (void)a; (void)b; (void)q;
#elif RMBL_MASK_A64
    uint32_t a, b;
    uintptr_t q;
    if (op == 0) {
        __asm__ volatile(
                "mov %w[a], wzr\n\t"
                "mov %w[b], wzr\n\t"
                "ldr %[q], [%[p], #16]\n\t"
                "ldr %w[a], [%[q]]\n\t"
                "eor %w[a], %w[a], %w[c]\n\t"
                "ldr %[q], [%[p], #0]\n\t"
                "str %w[b], [%[q]]\n\t"
                "str %w[a], [%[q]]\n\t"
                "mov %w[a], wzr\n\t"
                "str %w[a], [%[bus]]\n\t"
                "ldr %[q], [%[p], #24]\n\t"
                "ldr %w[a], [%[q]]\n\t"
                "ldr %[q], [%[p], #8]\n\t"
                "str %w[b], [%[q]]\n\t"
                "str %w[a], [%[q]]\n\t"
                "mov %w[a], wzr\n\t"
                "mov %[q], xzr"
                : [a] "=&r"(a), [b] "=&r"(b), [q] "=&r"(q)
                : [p] "r"(&p), [bus] "r"(mask_bus()), [c] "r"(c)
                : "memory", "cc");
    }
    else if (op == 1) {
        __asm__ volatile(
                "mov %w[a], wzr\n\t"
                "mov %w[b], wzr\n\t"
                "ldr %[q], [%[p], #16]\n\t"
                "ldr %w[a], [%[q]]\n\t"
                "and %w[a], %w[a], %w[c]\n\t"
                "ldr %[q], [%[p], #0]\n\t"
                "str %w[b], [%[q]]\n\t"
                "str %w[a], [%[q]]\n\t"
                "mov %w[a], wzr\n\t"
                "str %w[a], [%[bus]]\n\t"
                "ldr %[q], [%[p], #24]\n\t"
                "ldr %w[a], [%[q]]\n\t"
                "and %w[a], %w[a], %w[c]\n\t"
                "ldr %[q], [%[p], #8]\n\t"
                "str %w[b], [%[q]]\n\t"
                "str %w[a], [%[q]]\n\t"
                "mov %w[a], wzr\n\t"
                "mov %[q], xzr"
                : [a] "=&r"(a), [b] "=&r"(b), [q] "=&r"(q)
                : [p] "r"(&p), [bus] "r"(mask_bus()), [c] "r"(c)
                : "memory", "cc");
    }
    else if (op == 2) {
        __asm__ volatile(
                "mov %w[a], wzr\n\t"
                "mov %w[b], wzr\n\t"
                "ldr %[q], [%[p], #16]\n\t"
                "ldr %w[a], [%[q]]\n\t"
                "lsr %w[a], %w[a], %w[c]\n\t"
                "ldr %[q], [%[p], #0]\n\t"
                "str %w[b], [%[q]]\n\t"
                "str %w[a], [%[q]]\n\t"
                "mov %w[a], wzr\n\t"
                "str %w[a], [%[bus]]\n\t"
                "ldr %[q], [%[p], #24]\n\t"
                "ldr %w[a], [%[q]]\n\t"
                "lsr %w[a], %w[a], %w[c]\n\t"
                "ldr %[q], [%[p], #8]\n\t"
                "str %w[b], [%[q]]\n\t"
                "str %w[a], [%[q]]\n\t"
                "mov %w[a], wzr\n\t"
                "mov %[q], xzr"
                : [a] "=&r"(a), [b] "=&r"(b), [q] "=&r"(q)
                : [p] "r"(&p), [bus] "r"(mask_bus()), [c] "r"(c)
                : "memory", "cc");
    }
    else if (op == 3) {
        __asm__ volatile(
                "mov %w[a], wzr\n\t"
                "mov %w[b], wzr\n\t"
                "ldr %[q], [%[p], #16]\n\t"
                "ldr %w[a], [%[q]]\n\t"
                "ldr %[q], [%[p], #0]\n\t"
                "str %w[b], [%[q]]\n\t"
                "str %w[a], [%[q]]\n\t"
                "mov %w[a], wzr\n\t"
                "str %w[a], [%[bus]]\n\t"
                "ldr %[q], [%[p], #24]\n\t"
                "ldr %w[a], [%[q]]\n\t"
                "ldr %[q], [%[p], #8]\n\t"
                "str %w[b], [%[q]]\n\t"
                "str %w[a], [%[q]]\n\t"
                "mov %w[a], wzr\n\t"
                "mov %[q], xzr"
                : [a] "=&r"(a), [b] "=&r"(b), [q] "=&r"(q)
                : [p] "r"(&p), [bus] "r"(mask_bus())
                : "memory", "cc");
    }
    else if (op == 4) {
        __asm__ volatile(
                "mov %w[a], wzr\n\t"
                "mov %w[b], wzr\n\t"
                "ldr %[q], [%[p], #16]\n\t"
                "ldr %w[a], [%[q]]\n\t"
                "and %w[a], %w[a], #1\n\t"
                "neg %w[a], %w[a]\n\t"
                "ldr %[q], [%[p], #0]\n\t"
                "str %w[b], [%[q]]\n\t"
                "str %w[a], [%[q]]\n\t"
                "mov %w[a], wzr\n\t"
                "str %w[a], [%[bus]]\n\t"
                "ldr %[q], [%[p], #24]\n\t"
                "ldr %w[a], [%[q]]\n\t"
                "and %w[a], %w[a], #1\n\t"
                "neg %w[a], %w[a]\n\t"
                "ldr %[q], [%[p], #8]\n\t"
                "str %w[b], [%[q]]\n\t"
                "str %w[a], [%[q]]\n\t"
                "mov %w[a], wzr\n\t"
                "mov %[q], xzr"
                : [a] "=&r"(a), [b] "=&r"(b), [q] "=&r"(q)
                : [p] "r"(&p), [bus] "r"(mask_bus())
                : "memory", "cc");
    }
    (void)a; (void)b; (void)q;
#else
    const uint32_t x0 = *p.x0;
    *p.z0 = opaque(static_cast<uint32_t>(op == 0 ? x0 ^ c : op == 1 ? x0 & c : op == 2 ? x0 >> c : op == 4 ? 0u - (x0 & 1u) : x0));
    const uint32_t x1 = *p.x1;
    *p.z1 = opaque(static_cast<uint32_t>(op == 0 ? x1 : op == 1 ? x1 & c : op == 2 ? x1 >> c : op == 4 ? 0u - (x1 & 1u) : x1));
#endif
}

/* pair builders: a share pair is two words, wherever they live */
inline P2 pz(uint32_t *z0, uint32_t *z1, const uint32_t *x0, const uint32_t *x1,
             const uint32_t *y0 = nullptr, const uint32_t *y1 = nullptr) {
    P2 p;
    p.z0 = z0;
    p.z1 = z1;
    p.x0 = x0;
    p.x1 = x1;
    p.y0 = y0;
    p.y1 = y1;
    return p;
}
inline void and2(uint32_t z[2], const uint32_t x[2], const uint32_t y[2], uint32_t r) { m_and(pz(z, z + 1, x, x + 1, y, y + 1), r); }
inline void xor2(uint32_t z[2], const uint32_t x[2], const uint32_t y[2]) { m_xor(pz(z, z + 1, x, x + 1, y, y + 1)); }
inline void not2(uint32_t z[2], const uint32_t x[2]) { m_pub(pz(z, z + 1, x, x + 1), 0xffffffffu, 0); }

/* Trichina's AND on values (kept for callers that hold shares in variables) */
template <class T>
inline void sec_and(T &z0, T &z1, T x0, T x1, T y0, T y1, T r) {
    T t = opaque(static_cast<T>(r ^ (x0 & y0)));
    t = opaque(static_cast<T>(t ^ (x0 & y1)));
    t = opaque(static_cast<T>(t ^ (x1 & y0)));
    t = opaque(static_cast<T>(t ^ (x1 & y1)));
    z0 = r;
    z1 = t;
}

/* ---- bitsliced Boolean numbers: 32 lanes, bit b of every lane in word w[share][b] ---- */
const int kMaxBits = 26;
struct Bs {
    uint32_t w[2][kMaxBits];
};
inline P2 bit3(Bs &z, const Bs &x, const Bs &y, int i) {
    return pz(&z.w[0][i], &z.w[1][i], &x.w[0][i], &x.w[1][i], &y.w[0][i], &y.w[1][i]);
}

/* One share's 32 values, bitsliced: a function of that share alone. */
template <class T>
inline void bitslice(uint32_t out[kMaxBits], const T v[32], int bits) {
    for (int b = 0; b < bits; ++b) {
        uint32_t w = 0;
        for (int j = 0; j < 32; ++j) {
            w |= ((static_cast<uint32_t>(v[j]) >> b) & 1u) << j;
        }
        out[b] = w;
    }
    for (int b = bits; b < kMaxBits; ++b) out[b] = 0;
}

/* Boolean shares of one arithmetic share's values, re-masked with fresh randomness: two
 * arithmetic shares must never meet unmasked inside one Boolean sharing, or their XOR (a
 * function of the secret) would appear in a register. */
template <class T>
inline void boolean_of_share(Bs &out, const T v[32], int bits, Rng &rng) {
    uint32_t w[kMaxBits];
    bitslice(w, v, bits);
    for (int b = 0; b < bits; ++b) {
        const uint32_t r = rng.u32();
        out.w[0][b] = opaque(static_cast<uint32_t>(w[b] ^ r));
        out.w[1][b] = r;
    }
    for (int b = bits; b < kMaxBits; ++b) out.w[0][b] = out.w[1][b] = 0;
    rmbl_mask_scrub();
}

inline void bs_clear_from(Bs &z, int bits) {
    for (int i = bits; i < kMaxBits; ++i) z.w[0][i] = z.w[1][i] = 0;
}

/* z = x + y (mod 2^bits), ripple-carry over Boolean shares. */
inline void sec_add(Bs &z, const Bs &x, const Bs &y, int bits, Rng &rng) {
    uint32_t c[2] = {0, 0}, p[2], g[2], h[2];
    for (int i = 0; i < bits; ++i) {
        m_xor(pz(p, p + 1, &x.w[0][i], &x.w[1][i], &y.w[0][i], &y.w[1][i]));
        m_xor(pz(&z.w[0][i], &z.w[1][i], p, p + 1, c, c + 1));
        if (i + 1 < bits) {
            m_and(pz(g, g + 1, &x.w[0][i], &x.w[1][i], &y.w[0][i], &y.w[1][i]), rng.u32());
            and2(h, c, p, rng.u32());
            xor2(c, g, h);
        }
    }
    bs_clear_from(z, bits);
}

/* z = x + c (mod 2^bits) for a public constant per lane. */
template <class T>
inline void sec_add_public(Bs &z, const Bs &x, const T c[32], int bits, Rng &rng) {
    uint32_t cw[kMaxBits];
    bitslice(cw, c, bits);
    uint32_t k[2] = {0, 0}, p[2], g[2], h[2];
    for (int i = 0; i < bits; ++i) {
        m_pub(pz(p, p + 1, &x.w[0][i], &x.w[1][i]), cw[i], 0);   /* p = x ^ c */
        m_xor(pz(&z.w[0][i], &z.w[1][i], p, p + 1, k, k + 1));
        if (i + 1 < bits) {
            m_pub(pz(g, g + 1, &x.w[0][i], &x.w[1][i]), cw[i], 1); /* g = x & c, linear */
            and2(h, k, p, rng.u32());
            xor2(k, g, h);
        }
    }
    bs_clear_from(z, bits);
}

/* Masked "x < c" per lane, for x and a public c both below 2^(bits - 1): the sign of x - c
 * in `bits`-bit two's complement. s holds the shares of a word whose bit j is lane j's
 * answer. */
template <class T>
inline void sec_less(uint32_t s[2], const Bs &x, const T c[32], Rng &rng, const Mod &M = kKem) {
    int32_t neg[32];
    for (int j = 0; j < 32; ++j) neg[j] = static_cast<int32_t>((1 << M.bits) - static_cast<int32_t>(c[j]));
    Bs d;
    sec_add_public(d, x, neg, M.bits, rng);
    m_pub(pz(s, s + 1, &d.w[0][M.bits - 1], &d.w[1][M.bits - 1]), 0, 3);
}

inline void sec_less_const(uint32_t s[2], const Bs &x, int32_t c, Rng &rng, const Mod &M) {
    int32_t cs[32];
    for (int j = 0; j < 32; ++j) cs[j] = c;
    sec_less(s, x, cs, rng, M);
}

/* The integer sum T = a0 + a1 (in [0, 2q - 2]) of two arithmetic shares in [0, q), as
 * Boolean shares, 32 lanes. */
template <class T>
inline void share_sum(Bs &t, const T a0[32], const T a1[32], Rng &rng, const Mod &M = kKem) {
    Bs x, y;
    boolean_of_share(x, a0, M.bits, rng);
    boolean_of_share(y, a1, M.bits, rng);
    sec_add(t, x, y, M.bits, rng);
}

/* z = (s ? x : y) per lane: y ^ (s & (x ^ y)). */
inline void sec_select(Bs &z, const uint32_t s[2], const Bs &x, const Bs &y, int bits, Rng &rng) {
    uint32_t d[2], t[2];
    for (int b = 0; b < bits; ++b) {
        m_xor(pz(d, d + 1, &x.w[0][b], &x.w[1][b], &y.w[0][b], &y.w[1][b]));
        and2(t, s, d, rng.u32());
        m_xor(pz(&z.w[0][b], &z.w[1][b], &y.w[0][b], &y.w[1][b], t, t + 1));
    }
    bs_clear_from(z, bits);
}

/* T mod q for T in [0, 2q), in the Boolean domain: T - q when T >= q. */
inline void sec_reduce_q(Bs &out, const Bs &t, Rng &rng, const Mod &M) {
    int32_t negq[32];
    for (int j = 0; j < 32; ++j) negq[j] = (1 << M.bits) - M.q;
    Bs tm;
    sec_add_public(tm, t, negq, M.bits, rng);    /* T - q */
    uint32_t s[2];
    sec_less_const(s, t, M.q, rng, M);           /* T < q: keep T */
    sec_select(out, s, t, tm, M.bits, rng);
}

/* Shares of the AND of all 32 lanes of a masked word, in bit 0: five halvings, each a masked
 * AND of the word with itself shifted (the shift acts on each share). */
inline void sec_all_lanes(uint32_t o[2], const uint32_t x[2], Rng &rng) {
    uint32_t a[2], t[2];
    m_pub(pz(a, a + 1, x, x + 1), 0, 3);
    for (int k = 16; k >= 1; k >>= 1) {
        m_pub(pz(t, t + 1, a, a + 1), static_cast<uint32_t>(k), 2);
        and2(a, a, t, rng.u32());
    }
    m_pub(pz(o, o + 1, a, a + 1), 1u, 1);
}

/* Masked Compress_1 (FIPS 203 decoding of one message bit per coefficient): the bit is 1
 * exactly when the coefficient x lies in [833, 2496]. With T = a0 + a1, x is T or T - q,
 * so the bit is [833 <= T < 2497] xor [4162 <= T < 5826]. */
inline void sec_decode1(uint32_t &b0, uint32_t &b1, const int16_t a0[32], const int16_t a1[32],
                        Rng &rng) {
    Bs t;
    share_sum(t, a0, a1, rng);
    uint32_t l[4][2];
    const int32_t k[4] = {833, 2497, 4162, 5826};
    for (int i = 0; i < 4; ++i) sec_less_const(l[i], t, k[i], rng, kKem);
    /* [T >= 833] & [T < 2497]: the complement of a Boolean sharing flips one share */
    uint32_t n1[2], n3[2], p[2], q[2];
    not2(n1, l[0]);
    and2(p, n1, l[1], rng.u32());
    not2(n3, l[2]);
    and2(q, n3, l[3], rng.u32());
    m_xor(pz(&b0, &b1, p, p + 1, q, q + 1));
}

/* Masked interval test: lane j's value x (shares in [0, q)) satisfies (x - lo_j) mod q < w_j,
 * for 0 < w_j <= q. a0 is shifted by the public lo first. */
template <class T, class C>
inline void sec_in_interval(uint32_t &o0, uint32_t &o1, const T a0[32], const T a1[32],
                            const C lo[32], const C w[32], Rng &rng, const Mod &M = kKem) {
    T s0[32];
    for (int j = 0; j < 32; ++j) {
        s0[j] = static_cast<T>(cadd_mod(static_cast<int32_t>(a0[j]) - static_cast<int32_t>(lo[j]), M.q));
    }
    rmbl_mask_scrub();
    Bs t;
    share_sum(t, s0, a1, rng, M);
    int32_t cw[32], cqw[32];
    for (int j = 0; j < 32; ++j) {
        cw[j] = static_cast<int32_t>(w[j]);
        cqw[j] = M.q + static_cast<int32_t>(w[j]);
    }
    uint32_t a[2], b[2], c[2], nb[2], d[2];
    sec_less(a, t, cw, rng, M);        /* T < w */
    sec_less_const(b, t, M.q, rng, M); /* T < q */
    sec_less(c, t, cqw, rng, M);       /* T < q + w */
    not2(nb, b);
    and2(d, nb, c, rng.u32());
    m_xor(pz(&o0, &o1, a, a + 1, d, d + 1));
}

/* Boolean (bitsliced, non-negative values below q) to arithmetic shares mod q: a1 is a fresh
 * uniform share; a0 = (v - a1) mod q is computed inside the Boolean domain and only then
 * recombined, which reveals a value uniform on its own. */
template <class T>
inline void sec_b2a(T a0[32], T a1[32], const Bs &v, Rng &rng, const Mod &M = kKem) {
    int32_t r[32], nr[32];
    for (int j = 0; j < 32; ++j) {
        r[j] = rand_mod(rng, M.q);
        nr[j] = M.q - r[j];                          /* in [1, q] */
    }
    Bs m, y, z;
    boolean_of_share(m, nr, M.bits, rng);
    sec_add(y, v, m, M.bits, rng);                   /* v + q - r, in [1, 2q) */
    sec_reduce_q(z, y, rng, M);
    /* recombine: (v - r) mod q is uniform whatever v is */
    for (int j = 0; j < 32; ++j) {
        uint32_t val = 0;
        for (int b = 0; b < M.bits; ++b) {
            const uint32_t bit = ((z.w[0][b] ^ z.w[1][b]) >> j) & 1u;
            val |= bit << b;
        }
        a0[j] = static_cast<T>(val);
    }
    rmbl_mask_scrub();
    for (int j = 0; j < 32; ++j) a1[j] = static_cast<T>(r[j]);
    rmbl_mask_scrub();
}

/* Masked SamplePolyCBD_eta for 32 coefficients: buf0 ^ buf1 is the PRF output; lane j is
 * coefficient lane0 + j. Each coefficient is popcount(x bits) - popcount(y bits), shifted
 * by eta into [0, 2 eta] in the Boolean domain, converted, and shifted back mod q. */
inline void sec_cbd32(int16_t a0[32], int16_t a1[32], const unsigned char *buf0,
                      const unsigned char *buf1, int lane0, int eta, Rng &rng) {
    /* sum of eta one-bit values, as a 2-bit Boolean number (eta <= 3) */
    Bs acc_x, acc_y, bit, sum;
    for (int s = 0; s < 2; ++s)
        for (int b = 0; b < kMaxBits; ++b) acc_x.w[s][b] = acc_y.w[s][b] = bit.w[s][b] = 0;
    for (int k = 0; k < 2 * eta; ++k) {
        for (int s = 0; s < 2; ++s) {   /* one share per pass */
            const unsigned char *buf = s ? buf1 : buf0;
            uint32_t w = 0;
            for (int j = 0; j < 32; ++j) {
                const size_t pos = static_cast<size_t>(2 * eta) * static_cast<size_t>(lane0 + j) + static_cast<size_t>(k);
                w |= static_cast<uint32_t>((buf[pos >> 3] >> (pos & 7u)) & 1u) << j;
            }
            bit.w[s][0] = w;
            rmbl_mask_scrub();
        }
        Bs &acc = k < eta ? acc_x : acc_y;
        sec_add(sum, acc, bit, 2, rng);
        for (int b = 0; b < 2; ++b) m_pub(pz(&acc.w[0][b], &acc.w[1][b], &sum.w[0][b], &sum.w[1][b]), 0, 3);
    }
    /* v = x + ~y + 1 + eta = x - y + eta, in 4-bit arithmetic (2 eta <= 6) */
    Bs ny;
    for (int b = 0; b < kMaxBits; ++b) ny.w[0][b] = ny.w[1][b] = 0;
    for (int b = 0; b < 4; ++b) m_pub(pz(&ny.w[0][b], &ny.w[1][b], &acc_y.w[0][b], &acc_y.w[1][b]), 0xffffffffu, 0);
    Bs v1, v;
    sec_add(v1, acc_x, ny, 4, rng);
    int16_t c[32];
    for (int j = 0; j < 32; ++j) c[j] = static_cast<int16_t>(eta + 1);
    sec_add_public(v, v1, c, 4, rng);                   /* x - y + eta, in [0, 2 eta] */
    bs_clear_from(v, 4);
    sec_b2a(a0, a1, v, rng);
    for (int j = 0; j < 32; ++j) {                      /* undo the shift by eta, mod q */
        a0[j] = static_cast<int16_t>(cadd_q(static_cast<int32_t>(a0[j]) - eta));
    }
    rmbl_mask_scrub();
}

/* ---- ML-DSA (FIPS 204) gadgets: q = 8380417, gamma2 = (q - 1) / 88 or (q - 1) / 32 ---- */

/* Hook for inst/ctcheck: a value the algorithm publishes (a bit of HighBits, an accept or
 * reject decision) is declared public to the checker. A no-op elsewhere. */
#ifndef RMBL_MASKED_DECLASSIFY
#define RMBL_MASKED_DECLASSIFY(ptr, len) ((void)0)
#endif

/* b' for 32 lanes of a = a0 + a1 mod q, as Boolean shares: a + gamma2 - 1, less q - 1 when
 * that reaches q - 1. Then HighBits(a) = floor(b' / (2 gamma2)) for every a, the top
 * interval (which FIPS 204 Decompose folds to 0) included. */
inline void dsa_bprime(Bs &bp, const int32_t *a0, const int32_t *a1, int32_t gamma2, Rng &rng) {
    Bs t, a, b, bm;
    share_sum(t, a0, a1, rng, kDsa);
    sec_reduce_q(a, t, rng, kDsa);
    int32_t c[32], nc[32];
    for (int j = 0; j < 32; ++j) {
        c[j] = gamma2 - 1;
        nc[j] = (1 << kDsa.bits) - (kDsa.q - 1);
    }
    sec_add_public(b, a, c, kDsa.bits, rng);
    sec_add_public(bm, b, nc, kDsa.bits, rng);
    uint32_t s[2];
    sec_less_const(s, b, kDsa.q - 1, rng, kDsa);
    sec_select(bp, s, b, bm, kDsa.bits, rng);
}

/* HighBits per lane, revealed by a binary search whose comparisons each reveal one bit of
 * the result and nothing else (w1 is hashed into the challenge and recomputed by every
 * verifier). */
inline void dsa_reveal_highbits(int32_t *w1, const Bs &bp, int32_t gamma2, Rng &rng) {
    const int32_t high = (kDsa.q - 1) / (2 * gamma2);
    for (int j = 0; j < 32; ++j) w1[j] = 0;
    for (int p = 32; p >= 1; p >>= 1) {
        int32_t thr[32];
        for (int j = 0; j < 32; ++j) {
            const int32_t c = w1[j] + p;
            thr[j] = c <= high - 1 ? 2 * c * gamma2 : (1 << (kDsa.bits - 1)) - 1;
        }
        uint32_t s[2];
        sec_less(s, bp, thr, rng, kDsa);
        uint32_t ge = ~(s[0] ^ s[1]);   /* bits of w1 */
        RMBL_MASKED_DECLASSIFY(&ge, sizeof ge);
        for (int j = 0; j < 32; ++j) w1[j] += p & -static_cast<int32_t>((ge >> j) & 1u);
    }
    rmbl_mask_scrub();
}

/* Lane j set when LowBits(v) lies inside +-(gamma2 - beta - 1), given HighBits(v) == w1: the
 * r0 check of FIPS 204. If HighBits(v) differs from w1 the test fails, as the FIPS check
 * would (|LowBits| >= gamma2 - beta then). The top interval's low bits are one less than
 * b' - (gamma2 - 1) (Decompose subtracts one there), hence the bound beta + 1 at w1 = 0. */
inline void dsa_lowbits_ok(uint32_t o[2], const Bs &bp, const int32_t *w1, int32_t gamma2, int32_t beta,
                           Rng &rng) {
    int32_t lo[32], hi[32];
    for (int j = 0; j < 32; ++j) {
        const int32_t base = 2 * gamma2 * w1[j];
        lo[j] = base + (w1[j] == 0 ? beta + 1 : beta);
        hi[j] = base + 2 * gamma2 - beta - 1;
    }
    uint32_t a[2], b[2], na[2];
    sec_less(a, bp, lo, rng, kDsa);
    sec_less(b, bp, hi, rng, kDsa);
    not2(na, a);
    and2(o, na, b, rng.u32());
}

/* Shares of an all-lanes AND accumulated over many words; reveal() gives the one bit. */
struct AllOk {
    uint32_t a[2] = {0xffffffffu, 0};
    void add(const uint32_t o[2], Rng &rng) { and2(a, a, o, rng.u32()); }
    int reveal(Rng &rng) const {
        uint32_t b[2];
        sec_all_lanes(b, a, rng);
        int ok = static_cast<int>((b[0] ^ b[1]) & 1u);
        RMBL_MASKED_DECLASSIFY(&ok, sizeof ok);   /* the accept/reject decision */
        return ok;
    }
};

/* ||a||_inf < B (centred mod q) for n coefficients held as shares in [0, q), n a multiple
 * of 32, accumulated into acc. */
inline void dsa_norm_acc(AllOk &acc, const int32_t *a0, const int32_t *a1, int n, int32_t B, Rng &rng) {
    int32_t lo[32], w[32];
    for (int j = 0; j < 32; ++j) {
        lo[j] = kDsa.q - B + 1;
        w[j] = 2 * B - 1;
    }
    for (int i = 0; i < n; i += 32) {
        uint32_t o[2];
        sec_in_interval(o[0], o[1], a0 + i, a1 + i, lo, w, rng, kDsa);
        acc.add(o, rng);
    }
}

/* ---- masked Keccak-f[1600] ------------------------------------------------------------ */
const uint64_t kRC[24] = {
    0x0000000000000001ULL, 0x0000000000008082ULL, 0x800000000000808aULL, 0x8000000080008000ULL,
    0x000000000000808bULL, 0x0000000080000001ULL, 0x8000000080008081ULL, 0x8000000000008009ULL,
    0x000000000000008aULL, 0x0000000000000088ULL, 0x0000000080008009ULL, 0x000000008000000aULL,
    0x000000008000808bULL, 0x800000000000008bULL, 0x8000000000008089ULL, 0x8000000000008003ULL,
    0x8000000000008002ULL, 0x8000000000000080ULL, 0x000000000000800aULL, 0x800000008000000aULL,
    0x8000000080008081ULL, 0x8000000000008080ULL, 0x0000000080000001ULL, 0x8000000080008008ULL};
const int kRho[25] = {0, 1, 62, 28, 27, 36, 44, 6, 55, 20, 3, 10, 43, 25, 39, 41, 45, 15, 21, 8, 18, 2, 61, 56, 14};

inline uint64_t rotl(uint64_t x, int n) { return n ? (x << n) | (x >> (64 - n)) : x; }

template <class T>
inline void wipe_words(T *p, size_t n) {
    volatile T *v = p;
    for (size_t i = 0; i < n; ++i) v[i] = 0;
}

/* theta, rho, pi on one share (linear). Its scratch is wiped before it returns, so the pass
 * over the other share does not overwrite this share's values in the same stack words. */
inline void keccak_linear(uint64_t a[25]) {
    uint64_t c[5], b[25];
    for (int x = 0; x < 5; ++x) c[x] = a[x] ^ a[x + 5] ^ a[x + 10] ^ a[x + 15] ^ a[x + 20];
    for (int x = 0; x < 5; ++x) {
        const uint64_t d = c[(x + 4) % 5] ^ rotl(c[(x + 1) % 5], 1);
        for (int y = 0; y < 25; y += 5) a[y + x] ^= d;
    }
    for (int x = 0; x < 5; ++x)
        for (int y = 0; y < 5; ++y) b[y + 5 * ((2 * x + 3 * y) % 5)] = rotl(a[x + 5 * y], kRho[x + 5 * y]);
    for (int i = 0; i < 25; ++i) a[i] = b[i];
    wipe_words(c, 5);
    wipe_words(b, 25);
}

/* one share's row of five lanes as ten 32-bit words, and back */
inline void row_split(uint32_t w[10], const uint64_t *row) {
    for (int x = 0; x < 5; ++x) {
        w[2 * x] = static_cast<uint32_t>(row[x]);
        w[2 * x + 1] = static_cast<uint32_t>(row[x] >> 32);
    }
}
inline void row_join(uint64_t *row, const uint32_t w[10]) {
    for (int x = 0; x < 5; ++x) row[x] = static_cast<uint64_t>(w[2 * x]) | (static_cast<uint64_t>(w[2 * x + 1]) << 32);
}

inline void keccakf_masked(uint64_t s0[25], uint64_t s1[25], Rng &rng) {
    for (int round = 0; round < 24; ++round) {
        keccak_linear(s0);
        rmbl_mask_scrub();
        keccak_linear(s1);
        rmbl_mask_scrub();
        for (int y = 0; y < 25; y += 5) {
            uint32_t b0[10], b1[10], o0[10], o1[10], n[2], t[2];
            row_split(b0, s0 + y);
            rmbl_mask_scrub();
            row_split(b1, s1 + y);
            rmbl_mask_scrub();
            /* chi: a ^ (~b & c), on each 32-bit half; the complement flips one share */
            for (int x = 0; x < 5; ++x) {
                for (int h = 0; h < 2; ++h) {
                    const int i0 = 2 * x + h, i1 = 2 * ((x + 1) % 5) + h, i2 = 2 * ((x + 2) % 5) + h;
                    m_pub(pz(n, n + 1, &b0[i1], &b1[i1]), 0xffffffffu, 0);
                    m_and(pz(t, t + 1, n, n + 1, &b0[i2], &b1[i2]), rng.u32());
                    m_xor(pz(&o0[i0], &o1[i0], &b0[i0], &b1[i0], t, t + 1));
                }
            }
            row_join(s0 + y, o0);
            rmbl_mask_scrub();
            row_join(s1 + y, o1);
            rmbl_mask_scrub();
            wipe_words(b0, 10);
            wipe_words(b1, 10);
            wipe_words(o0, 10);
            wipe_words(o1, 10);
        }
        s0[0] ^= kRC[round];   /* iota, into one share */
    }
}

/* A masked sponge: in0 ^ in1 is the input (in1 may be NULL for a public tail), out0 ^ out1
 * the output. rate in bytes, domain the padding byte (0x06 SHA-3, 0x1f SHAKE). Each block is
 * absorbed and squeezed one share at a time. */
inline void sponge_masked(unsigned char *out0, unsigned char *out1, size_t outlen,
                          const unsigned char *in0, const unsigned char *in1, size_t inlen,
                          size_t rate, unsigned char domain, Rng &rng) {
    uint64_t s0[25], s1[25];
    for (int i = 0; i < 25; ++i) s0[i] = s1[i] = 0;
    size_t off = 0;
    for (;;) {
        const size_t take = inlen - off < rate ? inlen - off : rate;
        for (size_t i = 0; i < take; ++i) s0[i / 8] ^= static_cast<uint64_t>(in0[off + i]) << (8 * (i % 8));
        rmbl_mask_scrub();
        if (in1) {
            for (size_t i = 0; i < take; ++i) s1[i / 8] ^= static_cast<uint64_t>(in1[off + i]) << (8 * (i % 8));
            rmbl_mask_scrub();
        }
        off += take;
        if (take < rate) {
            s0[take / 8] ^= static_cast<uint64_t>(domain) << (8 * (take % 8));
            s0[(rate - 1) / 8] ^= static_cast<uint64_t>(0x80) << (8 * ((rate - 1) % 8));
            keccakf_masked(s0, s1, rng);
            break;
        }
        keccakf_masked(s0, s1, rng);
    }
    for (size_t pos = 0;;) {
        const size_t take = outlen - pos < rate ? outlen - pos : rate;
        for (size_t i = 0; i < take; ++i) out0[pos + i] = static_cast<unsigned char>(s0[i / 8] >> (8 * (i % 8)));
        rmbl_mask_scrub();
        for (size_t i = 0; i < take; ++i) out1[pos + i] = static_cast<unsigned char>(s1[i / 8] >> (8 * (i % 8)));
        rmbl_mask_scrub();
        pos += take;
        if (pos >= outlen) break;
        keccakf_masked(s0, s1, rng);
    }
    wipe_words(s0, 25);
    wipe_words(s1, 25);
}

}  // namespace rmbl_masked

#endif
