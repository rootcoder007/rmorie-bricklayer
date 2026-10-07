# Simulated power analysis (TVLA)

`inst/ctcheck` shows no branch or memory address depends on a secret, and `inst/dudect`
measures that timing does not. Neither says anything about **power**: a CPU's power draw
depends on the values it handles even when its timing does not, and that is what power and
electromagnetic attacks read.

This directory assesses the package's ML-KEM code for first-order power leakage before
silicon. `kernels.cpp` compiles the package's own `src/rmbl_mlkem_arith.h` and
`src/rmbl_masked.h` for a Cortex-M4 (the reference target of the post-quantum embedded
literature); `tvla.cpp` runs them instruction by instruction in unicorn and records one
sample per instruction. Capstone decodes which registers each instruction writes, and the
sample is

* **value model** (the default): the Hamming weight of every register value the instruction
  wrote and of every value it stored, the standard first-order model of CMOS power;
* **transition model** (`TVLA_MODEL=hd`): the Hamming distance between each written
  register's or memory word's old and new value, the model of a register or bus that
  switches from one value to the next.

The test is TVLA (Goodwill et al. 2011; ISO/IEC 17825): a fixed secret against random
secrets, Welch's t at every sample, in two independent experiments; a point leaks when
|t| > 4.5 in both with the same sign. A kernel whose instruction count depends on its input
fails outright (that is timing, and it also misaligns the traces).

```sh
bash inst/tvla/build.sh          # arm-none-eabi-g++, unicorn, capstone
cd inst/tvla && ./build/tvla all 5000
TVLA_MODEL=hd ./build/tvla all 5000
```

`TVLA_SEED=n` fixes the run; `TVLA_DUMP=i` prints the values that make up sample `i` of every
trace, which is how a leaking point is traced to an instruction and a value.

## Results (2 x 3,000 traces)

Each masked kernel runs next to its unmasked control: the same code with the second share
zero. A control that does not leak would mean the harness sees nothing. "Points" counts the
samples where |t| > 4.5 in both experiments with the same sign.

| kernel | what it is | value model | transition model |
|---|---|---|---|
| `mlkem_basemul` | s * u in the NTT domain, unmasked | 5,081 points, max \|t\| 133 | 5,647 points, max \|t\| 153 |
| `mlkem_basemul_masked` | arithmetic shares | none, max \|t\| 2.6 | none, max \|t\| 2.4 |
| `mlkem_ntt` | forward NTT, unmasked | 12,367 points, max \|t\| 157 | 12,441 points, max \|t\| 163 |
| `mlkem_ntt_masked` | arithmetic shares | none, max \|t\| 3.0 | none, max \|t\| 3.0 |
| `decode` | ML-KEM message decoding Compress_1, unmasked | 1,939 points, max \|t\| 97 | 1,912 points, max \|t\| 134 |
| `decode_masked` | `sec_decode1` | none, max \|t\| 2.4 | none, max \|t\| 2.6 |
| `keccak` | Keccak-f[1600] on a secret state, unmasked | 1,006 points, max \|t\| 105 | 1,334 points, max \|t\| 122 |
| `keccak_masked` | chi through the masked AND | none, max \|t\| 2.9 | none, max \|t\| 2.8 |
| `cbd` | ML-KEM centred-binomial noise, unmasked | 668 points, max \|t\| 87 | 760 points, max \|t\| 107 |
| `cbd_masked` | `sec_cbd32`, Boolean-to-arithmetic mod 3329 | none, max \|t\| 2.3 | none, max \|t\| 2.3 |
| `dsa_b2a` | ML-DSA y: Boolean-to-arithmetic mod 8380417, unmasked | 2,987 points, max \|t\| 101 | 3,399 points, max \|t\| 110 |
| `dsa_b2a_masked` | `sec_b2a` with the ML-DSA modulus | none, max \|t\| 2.5 | none, max \|t\| 2.7 |
| `dsa_lowbits` | ML-DSA r0 window test, unmasked | 3,601 points, max \|t\| 128 | 3,677 points, max \|t\| 120 |
| `dsa_lowbits_masked` | `dsa_bprime`, `dsa_lowbits_ok` | none, max \|t\| 2.5 | none, max \|t\| 2.4 |
| `dsa_norm` | ML-DSA norm test of z, unmasked | 2,937 points, max \|t\| 101 | 3,178 points, max \|t\| 107 |
| `dsa_norm_masked` | `dsa_norm_acc` | none, max \|t\| 2.3 | none, max \|t\| 2.5 |

Every masked kernel is clean under both models and every control leaks; CI fails on a masked
leak under either. The transition model is the one C alone could not satisfy: the compiler
moved one share into the register that held the other, and the switch between them was the
secret. The gadgets now touch both shares only in assembly (Thumb-2 here, and the same
sequences for x86-64 and aarch64 in the package), with each temporary and destination zeroed
before use, a zero store between the share-0 and share-1 stores, and the registers scrubbed
between passes that handle one share at a time.

## Found by this harness

* Under the transition model the Boolean gadgets compiled from C leaked (masked decoding |t| 62,
  masked Keccak 135, masked CBD 94): the compiler had put share 0 and then share 1 of one value
  in the same register. Rewriting the share-pair operations in assembly closed it.
* The model first counted registers whose value changed rather than registers written. A
  register rewritten with an equal value then dropped out of the sample, which leaked
  whether old equals new (a transition effect) and flagged `decode_masked` under a model
  that claims to be value-only. Capstone's write sets fixed the model.
* `cbd`, `cbd_masked`: two conditional "+ q when negative" corrections compiled to Thumb-2
  `it mi; addmi`, which executes or skips on the share's sign, and so did the share split
  in the masked decapsulation. All three are branch-free (`cadd_q`) now.
* `rand_q` drew by rejection, so the trace length depended on the randomness; it is a
  multiply-and-shift now (distance from uniform below 2^-20).

What this is not: a measurement of a device. Real chips also leak through glitches and
coupling neither model includes, and two-share masking says nothing about higher-order
attacks.
