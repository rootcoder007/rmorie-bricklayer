# Security

## Reporting

Report a vulnerability privately through GitHub’s “Report a
vulnerability” button on this repository (Security tab), or by email to
the maintainer address in `DESCRIPTION`. Please include the version, the
platform and a reproducer. You will get an acknowledgement within 72
hours and a fix or a documented decision within 30 days; credit is given
in `NEWS.md` unless you ask otherwise.

## Threat model

The package produces provenance records – digests, signatures, key
encapsulations, timestamps – for research artifacts, and verifies
records produced elsewhere. The adversary controls every byte the
verifier reads (signatures, certificates, OCSP responses, timestamp
tokens, fetched data) and can observe the timing of operations that use
a secret key on the same machine. The adversary does not have physical
access to the machine, and the operating system’s randomness
(`getrandom`, `BCryptGenRandom`) is trusted.

## What is checked, and how

Every item runs in CI on every change; `README.md` has the table.

| Check | Catches | Does not catch |
|----|----|----|
| Known-answer and OpenSSL parity tests | A wrong constant, shift, reduction or domain separator in any standardised scheme | A scheme that is correct but weak by design |
| Wycheproof vectors (1,247) | A verifier that accepts a malformed or non-canonical signature, an out-of-range r/s, an off-curve point, a padding or DigestInfo variant | Vectors for schemes Wycheproof does not cover (the PQC schemes rely on their KATs and parity tests) |
| ctgrind under valgrind memcheck (`inst/ctcheck`) | Any branch, memory index or variable-latency operand that depends on a secret, in the binary the harness builds (GCC and Clang, -O2) | Differences introduced by another compiler, flag set or CPU; micro-architectural channels that are not branches or addresses (e.g. variable-time multiplication on a few old cores); physical channels |
| Dead-stack scan (`inst/ctcheck`) | A secret temporary that was not wiped, or a wipe the optimiser removed | Copies the operating system or R itself made (R’s own vectors are the caller’s to manage) |
| ASan + UBSan over the test suite | Out-of-bounds access, use-after-free, signed overflow, misaligned access on the paths the tests exercise | Paths no test exercises |
| libFuzzer (`inst/fuzz`) | Crashes and sanitizer reports on inputs no test thought of; a decimal conversion that disagrees with the C library | Logic errors that do not crash; the fuzzers run for minutes per change and hours weekly, not indefinitely |

What has not been done: no third-party security audit, and no
measurement on hardware (power, EM, fault injection). The package is
written for provenance and research records; if you deploy it where a
key’s secrecy protects something else, read the table above as the exact
list of what has and has not been verified.

## Supported versions

The current release on CRAN and on r-universe receives fixes. Older
versions do not.
