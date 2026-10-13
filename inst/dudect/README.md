# dudect: timing measured on hardware

`inst/ctcheck` proves statically, under valgrind, that no branch or memory address depends
on a secret. This directory measures the compiled code on a real CPU instead, with the
fixed-vs-random method of Reparaz, Balasch and Verbauwhede, *Dude, is my code constant
time?* (DATE 2017): each measurement times the operation on an input from one of two
classes, a fixed input or a random one, chosen at random per measurement; Welch's t-test
compares the two timing distributions, raw and over 100 upper-tail crops. |t| > 10 marks a
real difference, |t| < 4.5 none.

```sh
bash inst/dudect/build.sh                 # CXX=clang++ to use clang
N=300000 bash inst/dudect/run.sh          # every target; exit 1 on any |t| > 10
inst/dudect/build/dudect list
```

| target | fixed class | random class |
|---|---|---|
| `mlkem768_decaps` | a valid ciphertext | random ciphertexts (implicit rejection) |
| `mlkem768_decaps_validity` | fresh valid ciphertexts from a pool | random ciphertexts |
| `mlkem768_decaps_masked`, `..._masked_validity` | as the two above, masked decapsulation | |
| `mlkem768_pke_decrypt` | K-PKE decryption alone, a valid ciphertext | random ciphertexts |
| `mlkem768_fo_select` | compare and select alone: the ciphertext against itself (match) | random ciphertexts (mismatch) |
| `mlkem768_fo_select_validity` | a pool ciphertext against itself | two different pool ciphertexts |
| `mlkem768_encaps` | a fixed message m | random messages |
| `hqc1_decaps` | a valid ciphertext | random ciphertexts |
| `digest_equal` | the equal 64-byte digest | random unequal digests |
| `pbkdf2_sha256` | a fixed password | random passwords |
| `control_leaky` | positive control: an early-exit compare, which must be flagged | |

Inputs for each chunk of 2,048 measurements are generated before any is timed: generating a
random input just before timing it, and copying a fixed one, leave the caches and branch
predictors in different states and show a difference that is not the code's.
Both classes are also written into their slots the same way, by a copy: random bytes go
through a scratch buffer first. Made in place, they left the slot in a different cache state
from a copied fixed input, and on GitHub's x86 runners that alone moved the 150-tick
compare-and-select by two ticks (|t| up to 30) while the compiled code is branch-free with a
fixed memory access pattern. `mlkem768_fo_select_validity` makes both classes from the same
pool of real ciphertexts by the same copy, so the match bit is the only difference.

Not measured here, on purpose: ML-DSA signing and the key generators. Their running time
depends on public data by design (rejection sampling over a public matrix and a published
challenge), which this method would report without anything secret leaking; ctcheck covers
their secret-dependence with the declassification points the standards allow.

The clock is `rdtsc` on x86-64 and `cntvct_el0` on arm64. CI runs on x86-64 Linux, arm64
Linux and Apple-silicon macOS. Timing is one physical channel; power and electromagnetic
emanation are not measured (see `inst/tvla` for the simulated power analysis).
