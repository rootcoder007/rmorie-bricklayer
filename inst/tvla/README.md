# Simulated power analysis (TVLA)

`inst/ctcheck` shows no branch or memory address depends on a secret, and `inst/dudect`
measures that timing does not. Neither says anything about **power**: a CPU's power draw
depends on the values it handles even when its timing does not, and that is what power and
electromagnetic attacks read.

This directory assesses the package's ML-KEM arithmetic for first-order power leakage
before silicon. `kernels.cpp` compiles the package's own `src/rmbl_mlkem_arith.h` for a
Cortex-M4 (the reference target of the post-quantum embedded literature); `tvla.cpp` runs it
instruction by instruction in unicorn and records one sample per instruction, the Hamming
weight of every register value the instruction changed and of every value it stored. That is
the standard first-order model of CMOS power consumption. The test is TVLA (Goodwill et al.
2011; ISO/IEC 17825): a fixed secret against random secrets, Welch's t at every sample, in
two independent experiments; a point leaks when |t| > 4.5 in both with the same sign.

```sh
bash inst/tvla/build.sh          # arm-none-eabi-g++ and unicorn
cd inst/tvla && ./build/tvla all 5000
```

| kernel | protection | result (2 x 5,000 traces) |
|---|---|---|
| `mlkem_basemul` | none | leaks at 4,827 points, max \|t\| 167 (positive control) |
| `mlkem_basemul_masked` | first-order arithmetic masking | no point leaks, max \|t\| 2.7 |
| `mlkem_ntt` | none | leaks at 11,842 points, max \|t\| 221 (positive control) |
| `mlkem_ntt_masked` | first-order arithmetic masking | no point leaks, max \|t\| 2.8 |

The masked kernels take the secret as two shares, s = s0 + s1 mod q, split afresh for every
execution, and never combine them, so every value is a function of one uniform share.

What this is not: a measurement of a device. Real chips also leak through transitions
between values, glitches and coupling that the Hamming-weight model leaves out, and the
model says nothing about higher-order attacks on two-share masking. It is the pre-silicon
assessment the masked designs in the literature are checked with before a capture bench.
