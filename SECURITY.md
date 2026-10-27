# Security

## Reporting a vulnerability

Report privately, never in a public issue:

1. **GitHub private reporting (preferred):** the "Report a vulnerability"
   button on this repository's Security tab, or directly at
   <https://github.com/rootcoder007/rmorie-bricklayer/security/advisories/new>.
2. **Email** the maintainer address in `DESCRIPTION`.

A useful report says which version and platform, what an attacker gains
(impact), how to reproduce it (a script or input file), and, if you can,
the cause. Please give us time to fix it before telling anyone else.

### Scope

In scope: the code in this repository, the package as released on CRAN and
r-universe, the Docker image `ghcr.io/rootcoder007/rmorie-bricklayer`, and
the signed service document in `inst/services`. Most valuable: a signature,
capsule, attestation or timestamp that verifies when it should not; a
secret that leaks through timing, memory or files; a crash or memory error
on hostile input; and anything that writes outside the folder it was given.

Out of scope: the statistical estimators' modelling choices (report those
as ordinary issues), denial of service by inputs that are merely large, and
vulnerabilities in R, libcurl or zlib themselves (report those upstream).

### What happens next

| Step | When |
|---|---|
| Acknowledgement, and a named person handling it | within 72 hours |
| Triage: reproduce, judge impact and severity (CVSS), confirm with you | within 7 days |
| Fix, a test that reproduces the issue, and a release | within 30 days for high and critical; a documented decision otherwise |
| GitHub security advisory, with a CVE requested through GitHub | when the fix is released |
| Credit in the advisory and `NEWS.md` | unless you ask otherwise |

We keep you informed at each step and ask you to check the fix.

### Good-faith research

Testing this package on your own machines, with your own keys and data, to
find and report vulnerabilities is welcome. We will not pursue or support
legal action against research done in good faith under this policy. Do not
test against other people's systems or data, or the data service at
data.rmorie.com beyond normal use.

There is no bug bounty; reports are credited.

### Incidents

A security incident (a leaked CI secret or signing key, a tampered release,
a compromised account or machine) is handled as follows: contain it (revoke
the secret or key, disable the affected workflow), find the cause and the
releases affected, fix and re-release, then publish an advisory saying
what happened and what users should do. A compromised key for the signed
service document is replaced in a package release, and the old key is
listed as revoked. Incidents that the law requires to be reported (for
example under Canadian privacy law) are reported.

## Threat model

The package produces provenance records -- digests, signatures, key
encapsulations, timestamps -- for research artifacts, and verifies records
produced elsewhere. The adversary controls every byte the verifier reads
(signatures, certificates, OCSP responses, timestamp tokens, fetched data)
and can observe the timing of operations that use a secret key on the same
machine. The adversary does not have physical access to the machine, and
the operating system's randomness (`getrandom` or `/dev/urandom`, and on
Windows `RtlGenRandom`, `SystemFunction036`) is trusted.

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

What has not been done: no measurement on hardware beyond timing (no power or electromagnetic capture; the leakage
assessment is a simulation). The package is written for provenance and research records; if
you deploy it where a key's secrecy protects something else, read the table above as the
exact list of what has been checked.

## Supported versions

The current release on CRAN and on r-universe receives fixes. Older
versions do not.

## Who has access

| Access | Held by |
|---|---|
| Repository admin, release tags, CRAN maintainer | the maintainer only |
| Commit signing | the maintainer's SSH and GPG keys; every commit and tag on `main` is signed |

CI secrets, each limited to what one workflow needs:

| Secret | Used for | If it leaked |
|---|---|---|
| `GITHUB_TOKEN` | per-workflow, read-only by default | expires with the run |
| `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN` | pushing the image to Docker Hub | rotate; images are rebuilt and re-scanned weekly |
| `HOMEBREW_TAP_TOKEN` | telling the Homebrew tap a release exists | rotate; it can only dispatch to the tap |
| `CODECOV_TOKEN` | uploading coverage | rotate; no access to code |
| `MORIE_SMOKE_KEY` | the smoke test's data-service sign-in | revoke the key in the key registry |

Secret scanning with push protection is on for this repository.

## Third-party components

At run time the package imports only base R (`graphics`, `grDevices`,
`methods`, `parallel`, `stats`, `tools`, `utils`) and links the system's
libcurl and zlib; every cryptographic primitive is its own code. GitHub's
dependency graph exports a software bill of materials (SPDX) for each
release under Insights > Dependency graph > Export SBOM.

## Staying current

Dependabot updates the GitHub Actions (all pinned to commit hashes) and the
Docker base image weekly. CodeQL scans the C and C++ code and the
workflows; OpenSSF Scorecard rates the repository's practices; Trivy
refuses to publish an image with a vulnerability that has a fix. The
maintainer follows the R, OpenSSL, curl and zlib security announcements.
