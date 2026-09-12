/* SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * The parameter-dependent half of SLH-DSA (FIPS 205). Included once per
 * parameter set, with SLH_NS and the SLH_* parameters defined by the
 * includer -- deliberately NOT guarded against multiple inclusion.
 *
 * Requires: SLH_NS, SLH_N, SLH_H, SLH_D, SLH_A, SLH_K, and SLH_SHA2
 * set to 1 for the SHA-2 instantiation or 0 for SHAKE.
 */

namespace SLH_NS {


/* The parameter set, supplied by whichever translation unit includes
 * this body. FIPS 205 tables six SHAKE sets; w = 16 in all of them. */
const int kN = SLH_N;
const int kFullHeight = SLH_H;
const int kD = SLH_D;
const int kTreeHeight = kFullHeight / kD;
const int kForsHeight = SLH_A;
const int kForsTrees = SLH_K;
const int kW = 16;
const int kLogW = 4;
const int kWotsLen1 = 8 * kN / kLogW;              /* 32 */
const int kWotsLen2 = 3;
const int kWotsLen = kWotsLen1 + kWotsLen2;        /* 35 */
const int kWotsBytes = kWotsLen * kN;              /* 560 */
const int kForsMsgBytes = (kForsHeight * kForsTrees + 7) / 8;  /* 21 */
const int kForsBytes = (kForsHeight + 1) * kForsTrees * kN;    /* 2912 */
const int kPkBytes = 2 * kN;                       /* 32 */
const int kSkBytes = 2 * kN + kPkBytes;            /* 64 */
const int kSigBytes = kN + kForsBytes + kD * kWotsBytes
                      + kFullHeight * kN;          /* 7856 */

/* The largest tweakable-hash input: the padded seed, the address, and
 * as many n-byte blocks as the widest caller passes -- WOTS+ has
 * kWotsLen and FORS has kForsTrees. Asserted below rather than
 * assumed. */
const int kThashBlocks = (kWotsLen > kForsTrees) ? kWotsLen : kForsTrees;
const int kThashMax = 128 + 32 + kThashBlocks * kN + 64;

const int kTreeBits = kTreeHeight * (kD - 1);      /* 54 */
const int kTreeBytesDgst = (kTreeBits + 7) / 8;    /* 7 */
const int kLeafBits = kTreeHeight;                 /* 9 */
const int kLeafBytesDgst = (kLeafBits + 7) / 8;    /* 2 */
const int kDgstBytes = kForsMsgBytes + kTreeBytesDgst + kLeafBytesDgst;

/* ADRS layout. The SHA-2 instantiation compresses the address to 22
 * bytes and moves every field; using one layout with the other
 * instantiation's hash gives a scheme that signs and verifies happily
 * and interoperates with nothing. */
#if SLH_SHA2
const int kAdrsBytes = 22;
const int kOffLayer = 0;
const int kOffTree = 1;
const int kOffType = 9;
const int kOffKeyPair = 10;
const int kOffChain = 17;
const int kOffHash = 21;
const int kOffTreeHeight = 17;
const int kOffTreeIndex = 18;
#else
const int kAdrsBytes = 32;
const int kOffLayer = 3;
const int kOffTree = 8;
const int kOffType = 19;
const int kOffKeyPair = 20;
const int kOffChain = 27;
const int kOffHash = 31;
const int kOffTreeHeight = 27;
const int kOffTreeIndex = 28;
#endif

/* SHA-512 takes over the multi-block tweakable hash and the message
 * randomiser at 192-bit security and above. */
#if SLH_SHA2
const int kShaXOut = (kN >= 24) ? 64 : 32;
const int kShaXBlock = (kN >= 24) ? 128 : 64;
#endif

const int kAddrTypeWots = 0;
const int kAddrTypeWotsPk = 1;
const int kAddrTypeHashTree = 2;
const int kAddrTypeForsTree = 3;
const int kAddrTypeForsRoots = 4;
const int kAddrTypeWotsPrf = 5;
const int kAddrTypeForsPrf = 6;

struct Ctx {
    unsigned char pub_seed[kN];
    unsigned char sk_seed[kN];
#if SLH_SHA2
    /* PK.seed padded to a compression block is the prefix of every
     * SHA-2 hash in the scheme. Compressing it once per operation
     * rather than per call halves the work; prepare() fills these and
     * everything below assumes it has been called. */
    uint32_t mid256[8];
    uint64_t mid512[8];
    void prepare() {
        unsigned char block[128];
        std::memset(block, 0, sizeof block);
        std::memcpy(block, pub_seed, kN);
        rmbl_sha256_midstate(block, mid256);
        if (kShaXOut == 64) rmbl_sha512_midstate(block, mid512);
    }
#else
    void prepare() {}
#endif
};

/* A 32-byte address, manipulated bytewise so the field offsets are the
 * spec's and not a compiler's idea of struct layout. */
struct Adrs {
    unsigned char a[kAdrsBytes];
    Adrs() { std::memset(a, 0, kAdrsBytes); }
    void set_layer(uint32_t l) { a[kOffLayer] = static_cast<unsigned char>(l); }
    void set_tree(uint64_t t) {
        /* 8 bytes, big endian */
        for (int i = 0; i < 8; ++i) {
            a[kOffTree + i] = static_cast<unsigned char>(t >> (8 * (7 - i)));
        }
    }
    void set_type(uint32_t ty) {
        a[kOffType] = static_cast<unsigned char>(ty);
        /* FIPS 205: setting the type zeroes the subsequent fields, so a
         * stale chain or index from a previous use cannot leak in */
        std::memset(a + kOffType + 1, 0,
                    static_cast<size_t>(kAdrsBytes - kOffType - 1));
    }
    void copy_subtree(const Adrs &o) {
        std::memcpy(a, o.a, kOffTree + 8);
    }
    /* layer, tree and key pair -- everything identifying which WOTS+ key
     * this address hangs under, and nothing below it */
    void copy_keypair(const Adrs &o) {
        std::memcpy(a, o.a, kOffTree + 8);
        std::memcpy(a + kOffKeyPair, o.a + kOffKeyPair, 4);
    }
    void set_keypair(uint32_t k) {
        for (int i = 0; i < 4; ++i) {
            a[kOffKeyPair + i] = static_cast<unsigned char>(k >> (8 * (3 - i)));
        }
    }
    uint32_t keypair() const {
        uint32_t v = 0;
        for (int i = 0; i < 4; ++i) {
            v = (v << 8) | a[kOffKeyPair + i];
        }
        return v;
    }
    void set_chain(uint32_t c) {
        a[kOffChain] = static_cast<unsigned char>(c);
    }
    void set_hash(uint32_t h) {
        a[kOffHash] = static_cast<unsigned char>(h);
    }
    void set_tree_height(uint32_t h) {
        a[kOffTreeHeight] = static_cast<unsigned char>(h);
    }
    void set_tree_index(uint32_t i) {
        for (int k = 0; k < 4; ++k) {
            a[kOffTreeIndex + k] = static_cast<unsigned char>(i >> (8 * (3 - k)));
        }
    }
    uint32_t tree_index() const {
        uint32_t v = 0;
        for (int i = 0; i < 4; ++i) {
            v = (v << 8) | a[kOffTreeIndex + i];
        }
        return v;
    }
};

/* PRF(pub_seed, adrs, sk_seed) -- where every secret chain starts.
 *
 * SHAKE absorbs PK.seed || ADRS || SK.seed. SHA-2 pads PK.seed out to a
 * full 64-byte compression block first, which is what lets the
 * reference precompute a midstate; the result is identical to hashing
 * the padded buffer, which is what happens here. */
void prf_addr(unsigned char out[kN], const Ctx &ctx, const Adrs &adrs) {
#if SLH_SHA2
    unsigned char tail[kAdrsBytes + kN];
    std::memcpy(tail, adrs.a, kAdrsBytes);
    std::memcpy(tail + kAdrsBytes, ctx.sk_seed, kN);
    unsigned char h[32];
    /* one block of PK.seed is already in the midstate */
    rmbl_sha256_finish(ctx.mid256, 1, tail, sizeof tail, h);
    std::memcpy(out, h, kN);
#else
    unsigned char buf[2 * kN + kAdrsBytes];
    std::memcpy(buf, ctx.pub_seed, kN);
    std::memcpy(buf + kN, adrs.a, kAdrsBytes);
    std::memcpy(buf + kN + kAdrsBytes, ctx.sk_seed, kN);
    rmbl_shake256(out, kN, buf, sizeof buf);
#endif
}

/* The tweakable hash over `inblocks` n-byte blocks.
 *
 * SHAKE: SHAKE256(PK.seed || ADRS || in). SHA-2: SHA-256 over the
 * padded PK.seed, except that at 192-bit security and above a
 * MULTI-block input switches to SHA-512 -- a single-block input stays
 * on SHA-256 even there. That asymmetry is in the standard, and getting
 * it wrong changes only the interior nodes of the trees, which no
 * round-trip test can see. */
void thash(unsigned char *out, const unsigned char *in, unsigned int inblocks,
           const Ctx &ctx, const Adrs &adrs) {
    /* A stack buffer, not a vector. Signing an s parameter set calls
     * this a few million times, and a heap allocation per call was
     * costing more than the hashing. The bound is the largest input any
     * caller passes: the WOTS+ public key, or the FORS roots. */
    unsigned char buf[kThashMax];
#if SLH_SHA2
    const bool wide = (kShaXOut == 64 && inblocks > 1);
    const size_t taillen = static_cast<size_t>(kAdrsBytes)
                           + static_cast<size_t>(inblocks) * kN;
    std::memcpy(buf, adrs.a, kAdrsBytes);
    std::memcpy(buf + kAdrsBytes, in,
                static_cast<size_t>(inblocks) * kN);
    unsigned char h[64];
    if (wide) {
        rmbl_sha512_finish(ctx.mid512, 1, buf, taillen, h);
    } else {
        rmbl_sha256_finish(ctx.mid256, 1, buf, taillen, h);
    }
    std::memcpy(out, h, kN);
#else
    const size_t len = static_cast<size_t>(kN) + kAdrsBytes
                       + static_cast<size_t>(inblocks) * kN;
    std::memcpy(buf, ctx.pub_seed, kN);
    std::memcpy(buf + kN, adrs.a, kAdrsBytes);
    std::memcpy(buf + kN + kAdrsBytes, in,
                static_cast<size_t>(inblocks) * kN);
    rmbl_shake256(out, kN, buf, len);
#endif
}

inline uint64_t bytes_to_ull(const unsigned char *in, unsigned int n) {
    uint64_t v = 0;
    for (unsigned int i = 0; i < n; ++i) {
        v |= static_cast<uint64_t>(in[i]) << (8 * (n - 1 - i));
    }
    return v;
}

inline void ull_to_bytes(unsigned char *out, unsigned int n, uint64_t v) {
    for (int i = static_cast<int>(n) - 1; i >= 0; --i) {
        out[i] = static_cast<unsigned char>(v & 0xff);
        v >>= 8;
    }
}

/* ---------------------------------------------------------------------
 * WOTS+
 * ------------------------------------------------------------------ */

/* base-w expansion, most significant digit first. */
void base_w(unsigned int *out, int outlen, const unsigned char *in) {
    int in_pos = 0, out_pos = 0, bits = 0;
    unsigned char total = 0;
    for (int consumed = 0; consumed < outlen; ++consumed) {
        if (bits == 0) {
            total = in[in_pos++];
            bits = 8;
        }
        bits -= kLogW;
        out[out_pos++] = (total >> bits) & (kW - 1);
    }
}

void wots_checksum(unsigned int *csum_base_w, const unsigned int *msg_base_w) {
    unsigned int csum = 0;
    for (int i = 0; i < kWotsLen1; ++i) {
        csum += static_cast<unsigned int>(kW - 1) - msg_base_w[i];
    }
    /* left-shift so the checksum's base-w digits are byte aligned */
    csum <<= ((8 - ((kWotsLen2 * kLogW) % 8)) % 8);
    unsigned char buf[(kWotsLen2 * kLogW + 7) / 8];
    ull_to_bytes(buf, sizeof buf, csum);
    base_w(csum_base_w, kWotsLen2, buf);
}

void chain_lengths(unsigned int *lengths, const unsigned char *msg) {
    base_w(lengths, kWotsLen1, msg);
    wots_checksum(lengths + kWotsLen1, lengths);
}

/* s applications of the tweakable hash starting at step `start`. */
void gen_chain(unsigned char *out, const unsigned char *in,
               unsigned int start, unsigned int steps,
               const Ctx &ctx, Adrs adrs) {
    std::memcpy(out, in, kN);
    for (unsigned int i = start; i < start + steps && i < static_cast<unsigned>(kW); ++i) {
        adrs.set_hash(i);
        thash(out, out, 1, ctx, adrs);
    }
}

/* FIPS 205 derives every WOTS+ secret under a WOTS_PRF address: the type
 * is set first (which clears the fields below it), then the key pair and
 * chain are written back. Using the WOTS address here instead produces a
 * scheme that verifies against itself and against nothing else. */
Adrs wots_prf_adrs(const Adrs &base, uint32_t chain) {
    const uint32_t kp = base.keypair();
    Adrs p = base;
    p.set_type(kAddrTypeWotsPrf);
    p.set_keypair(kp);
    p.set_chain(chain);
    p.set_hash(0);
    return p;
}

void wots_gen_pk(unsigned char *pk, const Ctx &ctx, Adrs adrs) {
    for (int i = 0; i < kWotsLen; ++i) {
        adrs.set_chain(static_cast<uint32_t>(i));
        unsigned char sk[kN];
        adrs.set_hash(0);
        prf_addr(sk, ctx, wots_prf_adrs(adrs, static_cast<uint32_t>(i)));
        gen_chain(pk + i * kN, sk, 0, kW - 1, ctx, adrs);
    }
}

void wots_sign(unsigned char *sig, const unsigned char *msg,
               const Ctx &ctx, Adrs adrs) {
    unsigned int lengths[kWotsLen];
    chain_lengths(lengths, msg);
    for (int i = 0; i < kWotsLen; ++i) {
        adrs.set_chain(static_cast<uint32_t>(i));
        unsigned char sk[kN];
        adrs.set_hash(0);
        prf_addr(sk, ctx, wots_prf_adrs(adrs, static_cast<uint32_t>(i)));
        gen_chain(sig + i * kN, sk, 0, lengths[i], ctx, adrs);
    }
}

void wots_pk_from_sig(unsigned char *pk, const unsigned char *sig,
                      const unsigned char *msg, const Ctx &ctx, Adrs adrs) {
    unsigned int lengths[kWotsLen];
    chain_lengths(lengths, msg);
    for (int i = 0; i < kWotsLen; ++i) {
        adrs.set_chain(static_cast<uint32_t>(i));
        gen_chain(pk + i * kN, sig + i * kN, lengths[i],
                  static_cast<unsigned>(kW - 1) - lengths[i], ctx, adrs);
    }
}

/* ---------------------------------------------------------------------
 * Merkle treehash.
 *
 * Computes a subtree root and, optionally, the authentication path for
 * one leaf, in a single left-to-right sweep with a stack of height
 * `tree_height`. Passing leaf_idx = ~0 asks for the root alone.
 * ------------------------------------------------------------------ */

typedef void (*LeafGen)(unsigned char *leaf, const Ctx &ctx,
                        uint32_t idx, void *info);

void treehash(unsigned char *root, unsigned char *auth_path, const Ctx &ctx,
              uint32_t leaf_idx, uint32_t idx_offset, uint32_t tree_height,
              LeafGen gen_leaf, Adrs tree_adrs, void *info) {
    std::vector<unsigned char> stack(
        static_cast<size_t>(tree_height) * kN);
    for (uint32_t idx = 0;; ++idx) {
        unsigned char current[2 * kN];
        gen_leaf(current + kN, ctx, idx + idx_offset, info);
        uint32_t internal_idx_offset = idx_offset;
        uint32_t internal_idx = idx;
        uint32_t internal_leaf = leaf_idx;
        for (uint32_t h = 0;; ++h, internal_idx >>= 1, internal_leaf >>= 1) {
            if (h == tree_height) {
                std::memcpy(root, current + kN, kN);
                return;
            }
            /* a sibling of the target leaf's path is part of the
             * authentication path */
            if (auth_path != nullptr && (internal_idx ^ internal_leaf) == 1) {
                std::memcpy(auth_path + h * kN, current + kN, kN);
            }
            /* a left child waits on the stack for its sibling */
            if ((internal_idx & 1) == 0 && idx < ((1u << tree_height) - 1)) {
                std::memcpy(stack.data() + h * kN, current + kN, kN);
                break;
            }
            internal_idx_offset >>= 1;
            tree_adrs.set_tree_height(h + 1);
            tree_adrs.set_tree_index(internal_idx / 2 + internal_idx_offset);
            std::memcpy(current, stack.data() + h * kN, kN);
            thash(current + kN, current, 2, ctx, tree_adrs);
        }
    }
}

/* ---------------------------------------------------------------------
 * The Merkle layer: leaves are WOTS+ public keys.
 * ------------------------------------------------------------------ */

struct LeafInfo {
    Adrs leaf_adrs;
    Adrs pk_adrs;
    const unsigned int *wots_steps;
    unsigned char *wots_sig;
    uint32_t wots_sign_leaf;   /* ~0 for "no signature wanted" */
};

void wots_gen_leaf(unsigned char *leaf, const Ctx &ctx, uint32_t addr_idx,
                   void *info) {
    LeafInfo *li = static_cast<LeafInfo *>(info);
    unsigned char pk[kWotsBytes];
    Adrs wadrs = li->leaf_adrs;
    Adrs padrs = li->pk_adrs;
    wadrs.set_type(kAddrTypeWots);
    wadrs.set_keypair(addr_idx);
    padrs.set_type(kAddrTypeWotsPk);
    padrs.set_keypair(addr_idx);
    for (int i = 0; i < kWotsLen; ++i) {
        Adrs sadrs = wadrs;
        sadrs.set_chain(static_cast<uint32_t>(i));
        sadrs.set_hash(0);
        unsigned char sk[kN];
        prf_addr(sk, ctx, wots_prf_adrs(sadrs, static_cast<uint32_t>(i)));
        /* when this leaf is the one being signed, the chain is stopped
         * at the message digit and that prefix IS the signature */
        if (li->wots_sign_leaf == addr_idx) {
            gen_chain(li->wots_sig + i * kN, sk, 0, li->wots_steps[i],
                      ctx, sadrs);
        }
        gen_chain(pk + i * kN, sk, 0, kW - 1, ctx, sadrs);
    }
    thash(leaf, pk, kWotsLen, ctx, padrs);
}

void merkle_sign(unsigned char *sig, unsigned char *root, const Ctx &ctx,
                 Adrs wots_adrs, Adrs tree_adrs, uint32_t idx_leaf) {
    unsigned char *auth_path = sig + kWotsBytes;
    LeafInfo info;
    unsigned int steps[kWotsLen];
    info.wots_sig = sig;
    chain_lengths(steps, root);
    info.wots_steps = steps;
    tree_adrs.set_type(kAddrTypeHashTree);
    info.pk_adrs.set_type(kAddrTypeWotsPk);
    info.leaf_adrs.copy_subtree(wots_adrs);
    info.pk_adrs.copy_subtree(wots_adrs);
    info.wots_sign_leaf = idx_leaf;
    treehash(root, idx_leaf == ~0u ? nullptr : auth_path, ctx, idx_leaf, 0,
             static_cast<uint32_t>(kTreeHeight), wots_gen_leaf, tree_adrs,
             &info);
}

void merkle_gen_root(unsigned char *root, const Ctx &ctx) {
    unsigned char scratch[kTreeHeight * kN + kWotsBytes];
    Adrs top_tree, wots_adrs;
    top_tree.set_layer(static_cast<uint32_t>(kD - 1));
    wots_adrs.set_layer(static_cast<uint32_t>(kD - 1));
    merkle_sign(scratch, root, ctx, wots_adrs, top_tree, ~0u);
}

/* ---------------------------------------------------------------------
 * FORS: forest of random subsets. This is what actually signs the
 * message digest; the hypertree above only certifies the FORS key.
 * ------------------------------------------------------------------ */

struct ForsLeafInfo { Adrs leaf_adrs; };

void compute_root(unsigned char *root, const unsigned char *leaf,
                  uint32_t leaf_idx, uint32_t idx_offset,
                  const unsigned char *auth_path, uint32_t tree_height,
                  const Ctx &ctx, Adrs adrs);

void fors_gen_leaf(unsigned char *leaf, const Ctx &ctx, uint32_t addr_idx,
                   void *info) {
    ForsLeafInfo *fi = static_cast<ForsLeafInfo *>(info);
    Adrs a = fi->leaf_adrs;
    /* setting the type clears the key pair, tree height and tree index
     * below it, so all three are written back afterwards; leaving any of
     * them stale silently changes every leaf */
    a.set_type(kAddrTypeForsPrf);
    a.copy_keypair(fi->leaf_adrs);
    a.set_tree_height(0);
    a.set_tree_index(addr_idx);
    prf_addr(leaf, ctx, a);
    a.set_type(kAddrTypeForsTree);
    a.copy_keypair(fi->leaf_adrs);
    a.set_tree_height(0);
    a.set_tree_index(addr_idx);
    thash(leaf, leaf, 1, ctx, a);
}

/* The digest's bits select one leaf from each of the 14 trees.
 *
 * FIPS 205 reads them with base_2b (Algorithm 4): most significant bit
 * first, straight across the byte string. The round-3 SPHINCS+ reference
 * read each group of 12 bits least-significant-bit first, which picks a
 * different leaf from every tree -- a scheme that verifies against itself
 * and against no conforming implementation. */
void message_to_indices(uint32_t *indices, const unsigned char *m) {
    unsigned int in = 0, bits = 0;
    uint32_t total = 0;
    for (int i = 0; i < kForsTrees; ++i) {
        while (bits < static_cast<unsigned int>(kForsHeight)) {
            total = (total << 8) + m[in++];
            bits += 8;
        }
        bits -= static_cast<unsigned int>(kForsHeight);
        indices[i] = (total >> bits) & ((1u << kForsHeight) - 1u);
    }
}

void fors_sign(unsigned char *sig, unsigned char *pk, const unsigned char *m,
               const Ctx &ctx, const Adrs &fors_adrs) {
    uint32_t indices[kForsTrees];
    unsigned char roots[kForsTrees * kN];
    Adrs tree_adrs, pk_adrs;
    ForsLeafInfo info;
    /* the keypair field identifies which hypertree leaf this FORS key
     * belongs to, and must be carried into every address below it */
    tree_adrs.copy_keypair(fors_adrs);
    info.leaf_adrs.copy_keypair(fors_adrs);
    pk_adrs.copy_keypair(fors_adrs);
    pk_adrs.set_type(kAddrTypeForsRoots);
    pk_adrs.copy_keypair(fors_adrs);
    const uint32_t kp = fors_adrs.keypair();
    (void) kp;
    message_to_indices(indices, m);
    for (int i = 0; i < kForsTrees; ++i) {
        const uint32_t idx_offset =
            static_cast<uint32_t>(i) << kForsHeight;
        tree_adrs.set_type(kAddrTypeForsPrf);
        tree_adrs.copy_keypair(fors_adrs);
        tree_adrs.set_tree_height(0);
        tree_adrs.set_tree_index(indices[i] + idx_offset);
        prf_addr(sig, ctx, tree_adrs);
        tree_adrs.set_type(kAddrTypeForsTree);
        tree_adrs.copy_keypair(fors_adrs);
        tree_adrs.set_tree_height(0);
        tree_adrs.set_tree_index(indices[i] + idx_offset);
        sig += kN;
        treehash(roots + i * kN, sig, ctx, indices[i], idx_offset,
                 static_cast<uint32_t>(kForsHeight), fors_gen_leaf,
                 tree_adrs, &info);
        sig += static_cast<size_t>(kN) * kForsHeight;
    }
    thash(pk, roots, kForsTrees, ctx, pk_adrs);
}

void fors_pk_from_sig(unsigned char *pk, const unsigned char *sig,
                      const unsigned char *m, const Ctx &ctx,
                      const Adrs &fors_adrs) {
    uint32_t indices[kForsTrees];
    unsigned char roots[kForsTrees * kN];
    unsigned char leaf[kN];
    Adrs tree_adrs, pk_adrs;
    tree_adrs.copy_keypair(fors_adrs);
    pk_adrs.copy_keypair(fors_adrs);
    pk_adrs.set_type(kAddrTypeForsRoots);
    pk_adrs.copy_keypair(fors_adrs);
    message_to_indices(indices, m);
    for (int i = 0; i < kForsTrees; ++i) {
        const uint32_t idx_offset =
            static_cast<uint32_t>(i) << kForsHeight;
        tree_adrs.set_type(kAddrTypeForsTree);
        tree_adrs.copy_keypair(fors_adrs);
        tree_adrs.set_tree_height(0);
        tree_adrs.set_tree_index(indices[i] + idx_offset);
        /* the signature carries the secret leaf; hash it once to the
         * leaf node, then walk the authentication path up */
        thash(leaf, sig, 1, ctx, tree_adrs);
        sig += kN;
        compute_root(roots + i * kN, leaf, indices[i], idx_offset, sig,
                     static_cast<uint32_t>(kForsHeight), ctx, tree_adrs);
        sig += static_cast<size_t>(kN) * kForsHeight;
    }
    thash(pk, roots, kForsTrees, ctx, pk_adrs);
}

/* Compute a Merkle root from a leaf and an authentication path. */
void compute_root(unsigned char *root, const unsigned char *leaf,
                  uint32_t leaf_idx, uint32_t idx_offset,
                  const unsigned char *auth_path, uint32_t tree_height,
                  const Ctx &ctx, Adrs adrs) {
    unsigned char buf[2 * kN];
    /* the first step is written out because the leaf is not yet in buf */
    if ((leaf_idx & 1) != 0) {
        std::memcpy(buf + kN, leaf, kN);
        std::memcpy(buf, auth_path, kN);
    } else {
        std::memcpy(buf, leaf, kN);
        std::memcpy(buf + kN, auth_path, kN);
    }
    auth_path += kN;
    for (uint32_t i = 0; i < tree_height - 1; ++i) {
        leaf_idx >>= 1;
        idx_offset >>= 1;
        adrs.set_tree_height(i + 1);
        adrs.set_tree_index(leaf_idx + idx_offset);
        if ((leaf_idx & 1) != 0) {
            thash(buf + kN, buf, 2, ctx, adrs);
            std::memcpy(buf, auth_path, kN);
        } else {
            thash(buf, buf, 2, ctx, adrs);
            std::memcpy(buf + kN, auth_path, kN);
        }
        auth_path += kN;
    }
    leaf_idx >>= 1;
    idx_offset >>= 1;
    adrs.set_tree_height(tree_height);
    adrs.set_tree_index(leaf_idx + idx_offset);
    thash(root, buf, 2, ctx, adrs);
}

/* ---------------------------------------------------------------------
 * The digest, and the domain separator FIPS 205 requires.
 *
 * R = PRF_msg(SK_PRF, opt_rand, M') and the digest is
 * H_msg(R, PK, M'), where M' carries the same (0x00, len(ctx), ctx)
 * prefix that FIPS 204 puts in front of an ML-DSA message. The round-3
 * SPHINCS+ submission omits it, so matching that reference is not
 * conformance -- the identical trap this package already hit once.
 * ------------------------------------------------------------------ */

void gen_message_random(unsigned char *R, const unsigned char *sk_prf,
                        const unsigned char *opt_rand,
                        const unsigned char *ctxb, size_t ctxlen,
                        const unsigned char *m, size_t mlen,
                        const unsigned char *oid, size_t oidlen) {
#if SLH_SHA2
    /* HMAC, keyed with SK.prf, over opt_rand || M' */
    std::vector<unsigned char> msg;
    msg.reserve(static_cast<size_t>(kN) + 2 + ctxlen + oidlen + mlen);
    msg.insert(msg.end(), opt_rand, opt_rand + kN);
    msg.push_back(oidlen > 0 ? 1 : 0);
    msg.push_back(static_cast<unsigned char>(ctxlen));
    msg.insert(msg.end(), ctxb, ctxb + ctxlen);
    if (oidlen > 0) msg.insert(msg.end(), oid, oid + oidlen);
    msg.insert(msg.end(), m, m + mlen);
    unsigned char h[64];
    rmbl_hmac_shax(kShaXOut, sk_prf, kN, msg.data(), msg.size(), h);
    std::memcpy(R, h, kN);
#else
    RmblKeccak st;
    rmbl_keccak_init(&st, 136, 0x1f);
    rmbl_keccak_absorb(&st, sk_prf, kN);
    rmbl_keccak_absorb(&st, opt_rand, kN);
    unsigned char pre[2];
    pre[0] = oidlen > 0 ? 1 : 0;
    pre[1] = static_cast<unsigned char>(ctxlen);
    rmbl_keccak_absorb(&st, pre, 2);
    if (ctxlen > 0) rmbl_keccak_absorb(&st, ctxb, ctxlen);
    if (oidlen > 0) rmbl_keccak_absorb(&st, oid, oidlen);
    rmbl_keccak_absorb(&st, m, mlen);
    rmbl_keccak_finalize(&st);
    rmbl_keccak_squeeze(&st, R, kN);
#endif
}

void hash_message(unsigned char *digest, uint64_t *tree, uint32_t *leaf_idx,
                  const unsigned char *R, const unsigned char *pk,
                  const unsigned char *ctxb, size_t ctxlen,
                  const unsigned char *m, size_t mlen,
                  const unsigned char *oid, size_t oidlen) {
    unsigned char buf[kDgstBytes];
#if SLH_SHA2
    /* SHA-2: the digest is MGF1 over R || PK.seed || H(R || PK || M'),
     * hashing the message once rather than once per MGF1 block. */
    std::vector<unsigned char> inbuf;
    inbuf.reserve(static_cast<size_t>(kN) + kPkBytes + 2 + ctxlen + mlen);
    inbuf.insert(inbuf.end(), R, R + kN);
    inbuf.insert(inbuf.end(), pk, pk + kPkBytes);
    inbuf.push_back(oidlen > 0 ? 1 : 0);
    inbuf.push_back(static_cast<unsigned char>(ctxlen));
    inbuf.insert(inbuf.end(), ctxb, ctxb + ctxlen);
    if (oidlen > 0) inbuf.insert(inbuf.end(), oid, oid + oidlen);
    inbuf.insert(inbuf.end(), m, m + mlen);
    std::vector<unsigned char> seed(static_cast<size_t>(2) * kN + kShaXOut);
    std::memcpy(seed.data(), R, kN);
    std::memcpy(seed.data() + kN, pk, kN);
    if (kShaXOut == 64) {
        rmbl_sha512_raw(inbuf.data(), inbuf.size(), seed.data() + 2 * kN);
    } else {
        rmbl_sha256_raw(inbuf.data(), inbuf.size(), seed.data() + 2 * kN);
    }
    rmbl_mgf1_shax(kShaXOut, buf, sizeof buf, seed.data(), seed.size());
#else
    RmblKeccak st;
    rmbl_keccak_init(&st, 136, 0x1f);
    rmbl_keccak_absorb(&st, R, kN);
    rmbl_keccak_absorb(&st, pk, kPkBytes);
    unsigned char pre[2];
    pre[0] = oidlen > 0 ? 1 : 0;
    pre[1] = static_cast<unsigned char>(ctxlen);
    rmbl_keccak_absorb(&st, pre, 2);
    if (ctxlen > 0) rmbl_keccak_absorb(&st, ctxb, ctxlen);
    if (oidlen > 0) rmbl_keccak_absorb(&st, oid, oidlen);
    rmbl_keccak_absorb(&st, m, mlen);
    rmbl_keccak_finalize(&st);
    rmbl_keccak_squeeze(&st, buf, sizeof buf);
#endif
    const unsigned char *bufp = buf;
    std::memcpy(digest, bufp, kForsMsgBytes);
    bufp += kForsMsgBytes;
    *tree = bytes_to_ull(bufp, kTreeBytesDgst);
    *tree &= (~static_cast<uint64_t>(0)) >> (64 - kTreeBits);
    bufp += kTreeBytesDgst;
    *leaf_idx = static_cast<uint32_t>(bytes_to_ull(bufp, kLeafBytesDgst));
    *leaf_idx &= (~static_cast<uint32_t>(0)) >> (32 - kLeafBits);
}

/* ---------------------------------------------------------------------
 * keypair, sign, verify
 * ------------------------------------------------------------------ */

void seed_keypair(unsigned char *pk, unsigned char *sk,
                  const unsigned char *seed) {
    /* the 48-byte seed is SK_SEED || SK_PRF || PUB_SEED */
    std::memcpy(sk, seed, 3 * kN);
    std::memcpy(pk, sk + 2 * kN, kN);
    Ctx ctx;
    std::memcpy(ctx.pub_seed, pk, kN);
    std::memcpy(ctx.sk_seed, sk, kN);
    ctx.prepare();
    merkle_gen_root(sk + 3 * kN, ctx);
    std::memcpy(pk + kN, sk + 3 * kN, kN);
}

void sign(unsigned char *sig, const unsigned char *m, size_t mlen,
          const unsigned char *ctxb, size_t ctxlen,
          const unsigned char *opt_rand, const unsigned char *sk,
          const unsigned char *oid, size_t oidlen) {
    Ctx ctx;
    const unsigned char *sk_prf = sk + kN;
    const unsigned char *pk = sk + 2 * kN;
    unsigned char mhash[kForsMsgBytes];
    unsigned char root[kN];
    uint64_t tree;
    uint32_t idx_leaf;
    std::memcpy(ctx.sk_seed, sk, kN);
    std::memcpy(ctx.pub_seed, pk, kN);
    ctx.prepare();

    gen_message_random(sig, sk_prf, opt_rand, ctxb, ctxlen, m, mlen,
                       oid, oidlen);
    hash_message(mhash, &tree, &idx_leaf, sig, pk, ctxb, ctxlen, m, mlen,
                 oid, oidlen);
    sig += kN;

    Adrs wots_adrs, tree_adrs;
    wots_adrs.set_type(kAddrTypeWots);
    tree_adrs.set_type(kAddrTypeHashTree);
    wots_adrs.set_tree(tree);
    wots_adrs.set_keypair(idx_leaf);

    fors_sign(sig, root, mhash, ctx, wots_adrs);
    sig += kForsBytes;

    for (int i = 0; i < kD; ++i) {
        tree_adrs.set_layer(static_cast<uint32_t>(i));
        tree_adrs.set_tree(tree);
        wots_adrs.copy_subtree(tree_adrs);
        wots_adrs.set_keypair(idx_leaf);
        merkle_sign(sig, root, ctx, wots_adrs, tree_adrs, idx_leaf);
        sig += kWotsBytes + kTreeHeight * kN;
        /* climb one layer: this subtree's index becomes the leaf index
         * of the layer above */
        idx_leaf = static_cast<uint32_t>(tree & ((1u << kTreeHeight) - 1));
        tree >>= kTreeHeight;
    }
}

int verify(const unsigned char *sig, size_t siglen, const unsigned char *m,
           size_t mlen, const unsigned char *ctxb, size_t ctxlen,
           const unsigned char *pk, const unsigned char *oid,
           size_t oidlen) {
    if (siglen != static_cast<size_t>(kSigBytes)) return -1;
    Ctx ctx;
    const unsigned char *pub_root = pk + kN;
    unsigned char mhash[kForsMsgBytes];
    unsigned char wots_pk[kWotsBytes];
    unsigned char root[kN], leaf[kN];
    uint64_t tree;
    uint32_t idx_leaf;
    std::memcpy(ctx.pub_seed, pk, kN);
    std::memset(ctx.sk_seed, 0, kN);   /* a verifier has no secret */
    ctx.prepare();

    const unsigned char *R = sig;
    sig += kN;
    hash_message(mhash, &tree, &idx_leaf, R, pk, ctxb, ctxlen, m, mlen,
                 oid, oidlen);

    Adrs wots_adrs, tree_adrs, wots_pk_adrs;
    wots_adrs.set_type(kAddrTypeWots);
    tree_adrs.set_type(kAddrTypeHashTree);
    wots_pk_adrs.set_type(kAddrTypeWotsPk);
    wots_adrs.set_tree(tree);
    wots_adrs.set_keypair(idx_leaf);

    fors_pk_from_sig(root, sig, mhash, ctx, wots_adrs);
    sig += kForsBytes;

    for (int i = 0; i < kD; ++i) {
        tree_adrs.set_layer(static_cast<uint32_t>(i));
        tree_adrs.set_tree(tree);
        wots_adrs.copy_subtree(tree_adrs);
        wots_adrs.set_keypair(idx_leaf);
        wots_pk_adrs.copy_subtree(wots_adrs);
        wots_pk_adrs.set_keypair(idx_leaf);
        wots_pk_from_sig(wots_pk, sig, root, ctx, wots_adrs);
        sig += kWotsBytes;
        thash(leaf, wots_pk, kWotsLen, ctx, wots_pk_adrs);
        compute_root(root, leaf, idx_leaf, 0, sig,
                     static_cast<uint32_t>(kTreeHeight), ctx, tree_adrs);
        sig += kTreeHeight * kN;
        idx_leaf = static_cast<uint32_t>(tree & ((1u << kTreeHeight) - 1));
        tree >>= kTreeHeight;
    }
    /* no early exit on the first differing byte */
    unsigned char diff = 0;
    for (int i = 0; i < kN; ++i) diff |= root[i] ^ pub_root[i];
    return diff == 0 ? 0 : -1;
}

}  // namespace SLH_NS
