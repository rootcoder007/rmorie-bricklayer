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
zero. A control that does not leak would mean the harness sees nothing.

| kernel | what it is | value model | transition model |
|---|---|---|---|
| `mlkem_basemul` | s * u in the NTT domain, unmasked | leaks: 5,087 points, max \|t\| 131 | leaks: 5,667 points, max \|t\| 132 |
| `mlkem_basemul_masked` | arithmetic shares | no leak, max \|t\| 2.4 | no leak, max \|t\| 3.0 |
| `mlkem_ntt` | forward NTT, unmasked | leaks: 12,561 points, max \|t\| 162 | leaks: 12,392 points, max \|t\| 159 |
| `mlkem_ntt_masked` | arithmetic shares | no leak, max \|t\| 2.8 | no leak, max \|t\| 2.9 |
| `decode` | message decoding Compress_1, unmasked | leaks: 1,956 points, max \|t\| 100 | leaks: 2,001 points, max \|t\| 126 |
| `decode_masked` | `sec_decode1` (Boolean shares) | no leak, max \|t\| 2.2 | leaks: 67 points, max \|t\| 62 |
| `keccak` | Keccak-f[1600] on a secret state | leaks: 814 points, max \|t\| 134 | leaks: 2,561 points, max \|t\| 162 |
| `keccak_masked` | chi through the masked AND | no leak, max \|t\| 2.9 | leaks: 1,712 points, max \|t\| 135 |
| `cbd` | centred-binomial noise, unmasked | leaks: 626 points, max \|t\| 102 | leaks: 746 points, max \|t\| 109 |
| `cbd_masked` | `sec_cbd32` with Boolean-to-arithmetic | no leak, max \|t\| 2.2 | leaks: 16 points, max \|t\| 94 |

Under the value model every masked kernel is clean and every control leaks; CI fails on any
masked leak there. Under the transition model the arithmetic kernels stay clean (each share
is processed in its own pass, so no register ever goes from one share to the other), and the
Boolean gadgets do not: their outputs come as pairs such as (r, r ^ x & y), and the compiler
routes both through one register, so the switch between them is x & y itself. C does not
control register allocation; closing that needs the gadgets written in assembly with the
shares kept in disjoint registers, as the hardened Cortex-M4 implementations do. CI reports
the transition model on every run without failing on it.

## Found by this harness

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
