# Security

## Reporting

Report a vulnerability privately through GitHub's "Report a vulnerability"
button on this repository (Security tab), or by email to the maintainer
address in `DESCRIPTION`. Please include the version, the platform and a
reproducer. You will get an acknowledgement within 72 hours and a fix or a
documented decision within 30 days; credit is given in `NEWS.md` unless you
ask otherwise.

## Threat model

The package produces provenance records -- digests, signatures, key
encapsulations, timestamps -- for research artifacts, and verifies records
produced elsewhere. The adversary controls every byte the verifier reads
(signatures, certificates, OCSP responses, timestamp tokens, fetched data)
and can observe the timing of operations that use a secret key on the same
machine. The adversary does not have physical access to the machine, and
the operating system's randomness (`getrandom`, `BCryptGenRandom`) is
trusted.

## What is checked, and how

Every item runs in CI on every change; `README.md` has the table.

| Check | Catches | Does not catch |
|---|---|---|
| Known-answer and OpenSSL parity tests | A wrong constant, shift, reduction or domain separator in any standardised scheme | A scheme that is correct but weak by design |
| Wycheproof vectors (1,247) | A verifier that accepts a malformed or non-canonical signature, an out-of-range r/s, an off-curve point, a padding or DigestInfo variant | Vectors for schemes Wycheproof does not cover (the PQC schemes rely on their KATs and parity tests) |
| ctgrind under valgrind memcheck (`inst/ctcheck`) | Any branch, memory index or variable-latency operand that depends on a secret, in the binary the harness builds (GCC and Clang, -O2) | Differences introduced by another compiler, flag set or CPU; micro-architectural channels that are not branches or addresses (e.g. variable-time multiplication on a few old cores); physical channels |
| Dead-stack scan (`inst/ctcheck`) | A secret temporary that was not wiped, or a wipe the optimiser removed | Copies the operating system or R itself made (R's own vectors are the caller's to manage) |
| ASan + UBSan over the test suite | Out-of-bounds access, use-after-free, signed overflow, misaligned access on the paths the tests exercise | Paths no test exercises |
| libFuzzer (`inst/fuzz`) | Crashes and sanitizer reports on inputs no test thought of; a decimal conversion that disagrees with the C library | Logic errors that do not crash; the fuzzers run for minutes per change and hours weekly, not indefinitely |

Beyond the table: timing is measured on real CPUs (`inst/dudect`: x86-64 and arm64 Linux,
Apple silicon, with a control that must be flagged); power leakage is assessed in simulation
(`inst/tvla`: the code compiled for a Cortex-M4 and run under the Hamming-weight and the
Hamming-distance models, TVLA in two experiments); ML-KEM decapsulation and ML-DSA signing
are first-order masked by default, with the masking gadgets written in assembly for
Cortex-M, x86-64 and aarch64 (on any other CPU the same operations run as plain C, with the
same results and without the register discipline); and the standardised schemes are checked against the C2SP
Wycheproof and NIST ACVP sets and differentially fuzzed against OpenSSL 3.5.

Outside what these checks model: electromagnetic emanation and fault injection, glitches and
coupling a leakage model omits, and higher-order attacks on two-share masking. The secret key
is stored in the standard byte formats of FIPS 203 and FIPS 204, so it is split into shares
when an operation starts; reading it from memory is outside the masked computation.

## Supported versions

The current release on CRAN and on r-universe receives fixes. Older
versions do not.
