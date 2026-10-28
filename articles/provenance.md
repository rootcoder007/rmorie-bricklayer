# Provenance you can verify

A manifest with a SHA-256 in it proves the data was not corrupted. It
proves nothing about who produced it, because anyone who can edit the
data can recompute the digest and write it back.

This vignette covers the three things that close that gap: signing a
manifest, pinning a capsule chunk by chunk, and making the *history* of
runs tamper-evident rather than only each run.

## Signing: a shared secret

The simplest case is one team, one secret.
[`cpssign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpssign.md)
with `scheme = "hmac"` produces an HMAC-SHA-256 tag: only a key holder
can compute it, so only a key holder can produce a manifest that
verifies.

``` r

manifest <- paste0(
  "source=https://example.org/extract.csv\n",
  "sha256=", csha256("id,value\n1,2\n"), "\n",
  "fetched=2026-09-12"
)

sig <- cpssign(csha256(manifest), key = "team-secret",
                    scheme = "hmac")
cpsvrf(csha256(manifest), sig, "team-secret")
#> [1] TRUE
```

An edited manifest has a different digest, which the signature does not
cover:

``` r

edited <- sub(
  "fetched=2026-09-12",
  "fetched=2026-01-01",
  manifest,
  fixed = TRUE
)
cpsvrf(csha256(edited), sig, "team-secret")
#> [1] FALSE
```

Do not carry raw key bytes around by hand.
[`drvkey()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drvkey.md)
stretches a passphrase into a full-width key with PBKDF2:

``` r

# Fixed here so the vignette is reproducible. For a real key the salt
# comes from rndbytes(16), which reads the operating system's
# CSPRNG rather than R's generator.
salt <- "9f2c41a7d8e05b36"
key <- drvkey("correct horse battery staple", salt)
nchar(key)
#> [1] 64
```

The salt is not secret and must be stored beside the capsule – without
the same salt and iteration count, the key cannot be re-derived.

HMAC is symmetric, so anyone who can *verify* can also *sign*. That is
fine within one team and useless for publishing.

## Signing: a public verifier, after quantum

For a verifier who should be able to check but not forge, the signature
has to be asymmetric. The classical options (RSA, Ed25519) fall to
Shor’s algorithm.

Worth being precise about what that threatens. Hashing is fine: Grover’s
algorithm only halves the security exponent, so SHA-256 retains roughly
2^128 preimage resistance, and HMAC with a 256-bit key is likewise fine.
**Signatures** are the part that breaks.

[`pqckg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqckg.md)
builds a hash-based signing key – a Merkle tree over Winternitz one-time
keys, the RFC 8391 construction, over the SHA-256 this package already
ships. Its security rests on the hash function alone: no lattice
assumption, no elliptic curve, and no new system dependency.

``` r

# Small for the vignette; the default height 10 gives 1024 signatures.
signingkey <- pqckg(height = 3)
signingkey
#> ╭── Signing key (post-quantum) ───────────────────────────────────────────────╮
#> │   scheme     xmss-sha256                                                    │
#> │   root       c68438da0dad4c134bd5fff899cce163e0f6d7b3357457a290d503ed9d6532 │
#> │              8d                                                             │
#> │   height     3                                                              │
#> │   used       0 of 8 signatures                                              │
#> │   remaining  8                                                              │
#> │   secret     <withheld>                                                     │
#> │   ! one signature per index; never sign twice at one index                  │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
```

Publish the public half. It carries no secret:

``` r

pub <- signpubkey(signingkey)
pub
#> ╭── Public verification key ─────────────────────────────────────────────────╮
#> │   scheme  xmss-sha256                                                      │
#> │   root    c68438da0dad4c134bd5fff899cce163e0f6d7b3357457a290d503ed9d65328d │
#> │   height  3                                                                │
#> ╰────────────────────────────────────────────────────────────────────────────╯
```

``` r

s1 <- cpssign(csha256(manifest), signingkey)
cpsvrf(csha256(manifest), s1, pub)
#> [1] TRUE

# A verifier holding only `pub` cannot forge one.
cpsvrf(csha256(edited), s1, pub)
#> [1] FALSE
```

### One signature per index, and no more

A Winternitz key signs **once**. Signing two different messages at one
leaf index leaks enough chain material to forge a third. So the key is
stateful, and `xmssadv(key, signature)` returns the advanced state for
you to carry forward:

``` r

signingkey <- xmssadv(signingkey, s1)
signingkey$next_index
#> [1] 1

s2 <- cpssign(csha256("a second manifest"), signingkey)
cpsvrf(csha256("a second manifest"), s2, pub)
#> [1] TRUE

# and forward again, for the next signature
signingkey <- xmssadv(signingkey, s2)
```

An exhausted key is an error rather than a silent wrap-around:

``` r

k <- pqckg(height = 1)          # signs exactly 2 messages
k <- xmssadv(k, cpssign("one", k))
k <- xmssadv(k, cpssign("two", k))
#> Warning: this key has used all 2 of its one-time indices: generate a new one
#> with pqckg()
cpssign("three", k)
#> Error:
#> ! this key is exhausted: a height-1 key signs 2 messages and all of them are used. Generate a new key -- reusing an index would break the signature scheme.
```

On the standardised schemes: ML-DSA (FIPS 204) and SLH-DSA (FIPS 205)
are implemented here too, at every parameter set both standards define –
three for ML-DSA, twelve for SLH-DSA – with no system dependency, so the
list
[`pqcbknd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqcbknd.md)
reports is the same on every machine.
[`fipskg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md)
takes any of them,
[`fipskey()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskey.md)
wraps key material that came from elsewhere, and both are stateless: one
key signs any number of messages. The default, SLH-DSA-SHA2-128s, rests
on the hash function alone, the most conservative assumption for a
record meant to outlive its author.

What makes that defensible is the cross-check rather than care. In
deterministic mode this package and OpenSSL 3.5 produce the same bytes
for every parameter set, which is a test a subtly wrong implementation
cannot pass: it would have to be wrong in exactly the same way, in a
construction where a single misplaced field changes every output.

``` r

pqcbknd()
#>  [1] "xmss-sha256"        "ML-DSA-44"          "ML-DSA-65"         
#>  [4] "ML-DSA-87"          "SLH-DSA-SHA2-128s"  "SLH-DSA-SHA2-128f" 
#>  [7] "SLH-DSA-SHA2-192s"  "SLH-DSA-SHA2-192f"  "SLH-DSA-SHA2-256s" 
#> [10] "SLH-DSA-SHA2-256f"  "SLH-DSA-SHAKE-128s" "SLH-DSA-SHAKE-128f"
#> [13] "SLH-DSA-SHAKE-192s" "SLH-DSA-SHAKE-192f" "SLH-DSA-SHAKE-256s"
#> [16] "SLH-DSA-SHAKE-256f"
```

### Signing inside a FIPS 140-3 module

The package’s own ML-DSA and SLH-DSA are not a validated cryptographic
module, and no amount of testing makes them one: validation is a
certificate NIST issues for one exact build. Where a record has to be
signed by a validated module, the package can hand the work to one.
[`fipsmod()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipsmod.md)
loads the OpenSSL FIPS provider on its own (a distribution’s, or an
upstream build it installs with `openssl fipsinstall`), and says which
module it is and whether that exact build is on the package’s list of
certificates: today the Chainguard FIPS Provider for OpenSSL 3.6.0-r4,
CMVP \#5523, which covers ML-DSA and SLH-DSA.
[`fipsmkg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipsmkg.md)
makes the key inside the module, and
[`cpssign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpssign.md)
signs with it there;
[`cpsvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsvrf.md)
and
[`cpsxvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsxvrf.md)
verify the result like any other signature.

``` r

mod <- fipsmod()
mod                       # the module, its build and its certificate
key <- fipsmkg("ML-DSA-65", mod)
sig <- cpssign("a manifest digest", key)
cpsvrf("a manifest digest", sig, key)
```

A module that is not on the list is reported as such, not as
unvalidated: it may hold a certificate the list does not have yet, and
NIST’s list is the authority. The claim to make is about the module
(“signed inside the Chainguard FIPS Provider, CMVP \#5523”), never that
this package is validated.

## Signing something a verifier can check

[`cpssign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpssign.md)
signs a string, which proves the string was signed and leaves three
things implicit: which key, which scheme, which bytes. A verifier handed
a directory still has to be told all three, and a check that depends on
being told what to check is a formality.

[`cpsatst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsatst.md)
records them inside the signed payload.

``` r

m <- mkmnf(list(dataset = "otis", rows = 1200L),
                   env = FALSE)
key <- fipskg("ML-DSA-65")
att <- cpsatst(m, key, note = "counts as published")
cpschkatst(att, m)
#> ╭── Attestation check: OK ────────────────────────────────────────────────────╮
#> │ ✔ VERIFIED  · 3 of 3 checks passed                                          │
#> │                                                                             │
#> │   Checks  3                                                                 │
#> │                                                                             │
#> │   Every check passed: the attestation is complete, names this manifest and  │
#> │   is signed.                                                                │
#> │                                                                             │
#> │   ✔    attestation_complete                                                 │
#> │   ✔    manifest_digest       efa1b7387f225380245de0b5170999e87ad4044f3e8fd2 │
#> │                              ef6a6bfbc2bd0a9c90                             │
#> │   ✔    signature                                                            │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
```

The check needs the attestation and the manifest, nothing else. Change
either – or edit the note, which is covered by the signature because it
is part of the digest – and it fails:

``` r

m2 <- m
m2$meta$rows <- 1201L
cpschkatst(att, m2)$ok
#> [1] FALSE
```

What it does not establish is that the key belongs to whoever you think:
an attestation is only as good as the channel the public key arrived on.
Pass `keyexp` when you know which key should have signed.

## The number in the manifest is the number

A manifest is meant to be checked against later. That only works if it
records what actually happened, at the precision it happened:

``` r

onethird <- mkmnf(list(x = 1 / 3), env = FALSE)
back <- fromjs(mnfcanon(onethird))
identical(back$meta$x, 1 / 3)
#> [1] TRUE
```

Sign
[`mnfdgst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mnfcanon.md)
rather than the pretty JSON. R lists keep insertion order, so building
`meta` before `results` or the other way round gives different bytes for
the same content; the canonical form sorts the keys, so the digest
depends on what the manifest says and not on how a script assembled it.

``` r

identical(
  mnfdgst(mkmnf(list(a = 1, b = 2), env = FALSE)),
  mnfdgst(mkmnf(list(b = 2, a = 1), env = FALSE)))
#> [1] TRUE
```

## Whether the finding survives

Everything above is about the record being intact. None of it says the
number means anything: a capsule can be signed, hashed, chained and
reproduced byte for byte while reporting an artefact. That is a separate
question and it needs controls that can fail.

``` r

set.seed(1)
d <- data.frame(x = rnorm(200))
d$y <- 0.8 * d$x + rnorm(200)
cpsfals(d, function(z) cor(z$x, z$y), trt = "x",
                n = 199, seed = 42)
#> ╭── Falsification controls ───────────────────────────────────────────────────╮
#> │   Observed statistic  0.5812737                                             │
#> │   Permutations        199                                                   │
#> │   Treatment           x                                                     │
#> │   Seed                42                                                    │
#> │   Generator           Mersenne-Twister,Inversion,Rejection                  │
#> │                                                                             │
#> │   The controls that ran passed: a shuffled treatment, a placebo, an added   │
#> │   random cause and subsets of the data did not explain it away.             │
#> │                                                                             │
#> │   ✔    permutation         p = 0.005 with 199 usable permutations; the      │
#> │                            smallest this de                                 │
#> │   ✔    placebo             a permuted exposure gives 0.0702711, against an  │
#> │                            observed 0.5                                     │
#> │   ✔    random_common_cause adding a column of noise moved the statistic by  │
#> │        0; it cannot                                                         │
#> │   ✔    subset_stability    the middle 95% of 199 subsets spans [0.539306,   │
#> │                            0.629292], a                                     │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
```

Four controls, each for a different way of being wrong: permuting the
exposure destroys the association, so the statistic should fall to its
null; a column of noise cannot matter, so the statistic should not move;
a placebo exposure should show nothing; and random subsets should agree.

They can fail, which is the point. A constant fails the permutation test
and nothing else, because everything else about a constant is perfectly
stable:

``` r

cpsfals(d, function(z) 0.5, trt = "x", n = 199,
                seed = 42)$controls[, c("control", "passed")]
#>               control passed
#> 1         permutation  FALSE
#> 2             placebo   TRUE
#> 3 random_common_cause   TRUE
#> 4    subset_stability   TRUE
```

Note what the permutation control reports alongside its p-value: the
smallest p-value the design could have produced. With 199 permutations
that floor is 0.005, and with 19 it is 0.05 – so a p of 0.05 from 19
permutations is not weak evidence, it is no evidence at all.

## Re-deriving the numbers, not just checking them

[`vrfcps()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfcps.md)
reads a manifest and confirms it is consistent with itself. That catches
an edited manifest and cannot catch one that was wrong when it was
written, because a manifest written from the wrong data is perfectly
consistent too.

``` r

d <- data.frame(x = 1:10)
man <- mkmnf(list(dataset = "demo"), env = FALSE)
man <- recrd(man, "mean_x", obs = mean(d$x), expd = 5.5)
#>   mean_x                                       observed = 5.5000       expected = 5.5000       [PASS]
man <- recrd(man, "n", obs = nrow(d), expd = 10)
#>   n                                            observed = 10.0000      expected = 10.0000      [PASS]

mnfrcmp(man, d, list(mean_x = function(z) mean(z$x),
                                n = function(z) nrow(z)))
#> ╭── Recomputation: everything checked and matched ──────────────────╮
#> │ ✔ VERIFIED                                                        │
#> │                                                                   │
#> │   Recomputed  2                                                   │
#> │   Matched     2                                                   │
#> │                                                                   │
#> │   name    recorded  recomputed  delta       tol  status           │
#> │   ------  --------  ----------  -----  --------  ------           │
#> │   mean_x     5.500       5.500      0  0.000100  MATCH            │
#> │   n         10.000      10.000      0  0.000100  MATCH            │
#> │                                                                   │
#> │   Every recorded result was recomputed from the data and matched. │
#> ╰───────────────────────────────────────────────────────────────────╯
```

Recompute only some of them and the rest are reported as unchecked
rather than passed over, which is the difference between a clean bill of
health and a partial one:

``` r

mnfrcmp(man, d, list(n = function(z) nrow(z)))
#> ╭── Recomputation: see below ────────────────────────────────────────────╮
#> │ ✖ NOT VERIFIED                                                         │
#> │                                                                        │
#> │   Recomputed      1                                                    │
#> │   Matched         1                                                    │
#> │   Not recomputed  1                                                    │
#> │                                                                        │
#> │   name  recorded  recomputed  delta       tol  status                  │
#> │   ----  --------  ----------  -----  --------  ------                  │
#> │   n           10          10      0  0.000100  MATCH                   │
#> │                                                                        │
#> │   Not every recorded result was recomputed and matched: see the notes. │
#> │                                                                        │
#> │   1 recorded result(s) NOT recomputed: mean_x                          │
#> ╰────────────────────────────────────────────────────────────────────────╯
```

For anything stochastic, record the generator state rather than the
seed. `set.seed(1)` reproduces a run only if everything before it does
too – one extra draw anywhere upstream shifts every later value:

``` r

set.seed(1)
m2 <- mnfrecseed(mkmnf(list(a = 1),
                                         env = FALSE))
first <- runif(3)
invisible(runif(1000))          # any amount of other work
mnfrstseed(m2)
identical(runif(3), first)
#> [1] TRUE
```

## Saying in advance what you will report

The falsification controls above are worth much more when the statistics
were named before the data was looked at. A declaration makes the two
ways of departing from a plan visible, and they are different failures:

``` r

plan <- prrgdecl(c(
  ate = "use of force is higher in the exposed division",
  n_rows = "the extract has the row count the source publishes"))

# a declared outcome that was not reported
prrgchk(plan, "n_rows")
#> ╭── Against the declaration of 2026-10-28T05:47:41Z: departures below ──╮
#> │ ✖ NOT VERIFIED                                                        │
#> │                                                                       │
#> │   Declared  2                                                         │
#> │   Reported  1                                                         │
#> │                                                                       │
#> │   statistic  reported                                                 │
#> │   ---------  --------                                                 │
#> │   ate        FALSE                                                    │
#> │   n_rows     TRUE                                                     │
#> │                                                                       │
#> │   The report departs from the declaration: see below.                 │
#> │                                                                       │
#> │   ✖    declared but not reported (outcome switching): ate             │
#> ╰───────────────────────────────────────────────────────────────────────╯

# statistics reported that were never declared
prrgchk(plan, c("ate", "n_rows", "byyear", "byprecinct"))
#> ╭── Against the declaration of 2026-10-28T05:47:41Z: departures below ──╮
#> │ ✖ NOT VERIFIED                                                        │
#> │                                                                       │
#> │   Declared  2                                                         │
#> │   Reported  2                                                         │
#> │                                                                       │
#> │   statistic  reported                                                 │
#> │   ---------  --------                                                 │
#> │   ate        TRUE                                                     │
#> │   n_rows     TRUE                                                     │
#> │                                                                       │
#> │   The report departs from the declaration: see below.                 │
#> │                                                                       │
#> │   ✖    reported but not declared (2 addition(s)): byyear, byprecinct  │
#> ╰───────────────────────────────────────────────────────────────────────╯
```

That second case is why a nominal p-value needs correcting. Run the
permutation control over several statistics and the smallest is not the
finding:

``` r

falsfam(c(ate = 0.02, byyear = 0.3, byprecinct = 0.4,
                 byshift = 0.6, bymonth = 0.7), meth = "holm")
#> ╭── Family of 5, corrected by holm at alpha 0.05 ────────────────────╮
#> │   Method       holm                                                │
#> │   Family size  5                                                   │
#> │   Alpha        0.05                                                │
#> │   Survive      0                                                   │
#> │                                                                    │
#> │   name            p  adjusted_p  survives                          │
#> │   ----------  -----  ----------  --------                          │
#> │   ate         0.020       0.100                                    │
#> │   byyear      0.300       1.000                                    │
#> │   byprecinct  0.400       1.000                                    │
#> │   byshift     0.600       1.000                                    │
#> │   bymonth     0.700       1.000                                    │
#> │                                                                    │
#> │   0 of 5 result(s) survive once the size of the family is counted. │
#> ╰────────────────────────────────────────────────────────────────────╯
```

And for the confounder nobody measured, the E-value says how strong it
would have to be to explain the result away – with both the exposure and
the outcome:

``` r

evlrr(2, lo = 1.4, hi = 2.9)
#> evlpoint evllimit 
#> 3.414214 2.148331
```

## A trial whose allocation nobody can rewrite

In a randomised trial the two records that must not move after the data
are seen are the outcomes and the allocation. The outcomes are declared
above; the allocation is a list made before the first participant and
committed to.

``` r

alloc <- ralloc(arms = c("drug", "placebo"), ratio = c(1, 1),
                strata = c(Toronto = 24, Ottawa = 16), codes = TRUE,
                seed = "a vignette, not a trial")
alloc
#> ╭── Randomisation list ───────────────────────────────────────────────────────╮
#> │   Method        permuted blocks of 4 or 6 within strata                     │
#> │   Participants  40                                                          │
#> │   Arms          drug, placebo (1:1)                                         │
#> │   Strata        2                                                           │
#> │   Kit codes     yes                                                         │
#> │   Seed          concealed: attr(x, "alloc")$seed                            │
#> │   Commitment    b59fe0d8fbf853b88022675bcd64d726c0702405a538bc23daf2757fea1 │
#> │                 b4b30                                                       │
#> │                                                                             │
#> │   stratum  drug  placebo                                                    │
#> │   -------  ----  -------                                                    │
#> │   Toronto    12       12                                                    │
#> │   Ottawa      8        8                                                    │
#> │                                                                             │
#> │   In all: drug 20, placebo 20. Every stratum is exactly in the ratio.       │
#> │   Sign and timestamp the commitment before the first participant; keep the  │
#> │   list and the seed with the unblinded statistician.                        │
#> │                                                                             │
#> │   Give sites and the pharmacy only the id and kit columns.                  │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
```

The box shows how many participants each arm has, never who is in which,
and not the seed. For a real trial leave `seed` out: the seed is then 48
bytes from the operating system, and the list cannot be guessed before
it is opened. Sites and the pharmacy get only the `id` and `kit`
columns.

Sign the commitment, and the declared outcomes with it, before enrolment
(and send the signed record to a timestamp authority;
[`tsvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/tsvrf.md)
checks the token it returns):

``` r

trial <- fipskg("ML-DSA-44")
record <- paste(attr(alloc, "alloc")$digest,
                mnfdgst(mkmnf(list(outcomes = plan$statistics),
                              env = FALSE)))
sealed <- cpssign(record, trial, ctx = "trial commitment")
cpsvrf(record, sealed, fipspubkey(trial), ctx = "trial commitment")
#> [1] TRUE
```

At unblinding the statistician reveals the list and the seed, and anyone
can check them against what was signed:

``` r

rallocvrf(alloc, digest = attr(alloc, "alloc")$digest)
#> ╭── Randomisation list: verified ─────────────────────────────────────────────╮
#> │ ✔ VERIFIED  · 3 of 3 checks passed                                          │
#> │                                                                             │
#> │   ✔    commitment    the list is the one committed to                       │
#> │   ✔    seed          the seed and the settings give this list, row for row  │
#> │   ✔    participants  40 participants, each once                             │
#> │        commitment    b59fe0d8fbf853b88022675bcd64d726c0702405a538bc23daf275 │
#> │                      7fea1b4b30                                             │
#> ╰─────────────────────────────────────────────────────────────────────────────╯

# one allocation changed after the commitment is caught
moved <- alloc
moved$arm[1] <- setdiff(c("drug", "placebo"), moved$arm[1])
rallocvrf(moved, digest = attr(alloc, "alloc")$digest)$ok
#> [1] FALSE
```

## Keeping your own copy of the source

A capsule pins a source by its SHA-256, and
[`fetchvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fetchvrf.md)
fetches it from wherever a copy with that SHA-256 still exists: the
source, its Wayback snapshot, any mirror you name, archive.rmorie.com,
and folders of captures you made yourself. Some servers refuse archives
(Statistics Canada answers the Wayback Machine’s crawler with an error),
so the copy has to be made from a connection the server does answer:
yours.

[`arccap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/arccap.md)
downloads each address, writes it as a WARC/1.1 file with a CDXJ index
(a collection pywb and warcio read), and with `upload = "rmorie"` keeps
it at archive.rmorie.com under your data key, with the reason you give.
`upload = "wayback"` asks the Wayback Machine as well.

``` r

cap <- arccap(
  "https://www150.statcan.gc.ca/n1/tbl/csv/35100177-eng.zip",
  "captures",
  upload = c("rmorie", "wayback"),
  reason = "Custody table cited in chapter 3"
)
cap$archive # its page at archive.rmorie.com
arcfind("https://www150.statcan.gc.ca/n1/tbl/csv/35100177-eng.zip")
arcget(cap$capture_id, "table.zip", sha256 = cap$sha256)
```

When the source is gone and the Wayback Machine cannot be reached,
[`fetchvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fetchvrf.md)
takes the copy from the archive, and failing that from the WARC files in
your own folder, still checked against the pin:

``` r

fetchvrf(
  "https://www150.statcan.gc.ca/n1/tbl/csv/35100177-eng.zip",
  "table.zip",
  sha256 = cap$sha256,
  arcs = c("rmorie", "captures")
)
```

From a terminal the same steps are
`rmbl archive save URL --reason "..."`, `rmbl archive find URL` and
`rmbl archive get ID -o FILE`.

In continuous integration, `cpschk(path, "drift", archive = TRUE)` (the
rmbl GitHub Action’s `archive: true`) takes the archived copy with the
pinned SHA-256 when a capsule’s source and its Wayback snapshot are both
down; reading a public copy needs no key. Saving needs one, except in a
GitHub Actions job allowed `id-token: write`: there the package asks
GitHub for the job’s short-lived OIDC token, the archive checks GitHub’s
signature, and the repository is the saver, so no secret is stored.

``` yaml
permissions:
  contents: read
  id-token: write
steps:
  - uses: rootcoder007/rmbl-action@v1
    with:
      path: capsules
      mode: refresh
      wayback: true
      archive: true
```

## One file to hand someone

A bundle carries a digest of every file, the manifest digest, and an
attestation over both. The file digests are inside the signature, which
is the point: a list of hashes that is not itself signed can be
rewritten to match whatever the files now say.

``` r

dir <- tempfile()
dir.create(dir)
write.csv(data.frame(x = 1:3), file.path(dir, "data.csv"),
          row.names = FALSE)
b <- cpsbndl(dir, man, key, note = "as published")
cpsbndlvrf(attr(b, "path"), dir, man = man)
#> ╭── Bundle check: OK ─────────────────────────────────────────────────────────╮
#> │ ✔ VERIFIED  · 6 of 6 checks passed                                          │
#> │                                                                             │
#> │   Checks  6                                                                 │
#> │                                                                             │
#> │   Every check passed: every file is the one that was signed and the         │
#> │   signature holds.                                                          │
#> │                                                                             │
#> │   ✔    file:data.csv                                                        │
#> │        95aecaa7399a39092c9e716ce1e18bb1c606c82f9503d679ac55c82988f6c38e     │
#> │   ✔    no_unlisted_files                                                    │
#> │   ✔    attestation:attestation_complete                                     │
#> │   ✔    attestation:manifest_digest                                          │
#> │        3f8b620b03ac3ef16f1ee1c0db3bec5eae973f4f14d3f75d697789d20e87ebe2     │
#> │   ✔    attestation:signature                                                │
#> │   ✔    manifest_digest                                                      │
#> │        5f711161c72a5bcf5b5918d69a6a59fbe38ab9399dd140e9281cb9867d23826f     │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
```

Files sitting in the directory that the bundle does not mention are
reported as well: a signed list of what should be there says nothing
about what else was put beside it.

``` r

unlink(dir, recursive = TRUE)
```

## A bundle a reviewer double-clicks

The capsule above is for someone who runs R. A reproducibility bundle is
for anyone: one zip a reviewer unzips and double-clicks
(`START_HERE.command` on macOS, `START_HERE.bat` on Windows,
`start_here.sh` on Linux), with nothing installed but R. The runner
inside finds the data, checks it against the pinned SHA-256, runs your
analysis and says, for every number you report, what it got.

**Step 1: start a project.**
[`mkbndlproj()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mkbndlproj.md)
writes three files that already build and run, so every step can be
tried before the analysis is written.

``` r

proj <- file.path(tempdir(), "my-study")
p <- mkbndlproj(proj, title = "My study", author = "A. Researcher",
                contact = "a.researcher@example.org", overwrite = TRUE)
p
#> ╭── Bundle project ───────────────────────────────────────────────────────────╮
#> │   Folder  /tmp/RtmpppHH33/my-study                                          │
#> │   Files   config.json, data_provenance.json, analysis.R                     │
#> │                                                                             │
#> │   Edit config.json (who and what), data_provenance.json (the data file,     │
#> │   its URL and SHA-256) and analysis.R (the checks), then build the zip      │
#> │   with mkbndl().                                                            │
#> │   It runs as it is on synthetic data, so the bundle can be tried before     │
#> │   the analysis is written.                                                  │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
```

`config.json` says who and what (and `r_packages`, the packages your
analysis needs); `data_provenance.json` names the data file, where it
can be downloaded and its SHA-256, plus a recipe for synthetic data;
`analysis.R` reads the data and records one check per number the paper
reports with
[`recrd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/recrd.md).

**Step 2: pin your data.** Point the provenance at the real file and its
digest. A reviewer whose copy differs is stopped, not given different
numbers.

``` r

dat <- data.frame(group = rep(c("a", "b"), 50), value = rep(c(4, 6), 50),
                  stringsAsFactors = FALSE)
csv <- file.path(tempdir(), "my_data.csv")
write.csv(dat, csv, row.names = FALSE)
pv <- file.path(proj, "data_provenance.json")
prov <- fromjs(pv, simplifyVector = FALSE)
prov$resource$sha256 <- sha256file(csv)
writeLines(tojs(prov, auto_unbox = TRUE, pretty = TRUE), pv)
```

With `resource$direct_url` set too, a bundle without the data downloads
it and checks it; here the data travels inside.

**Step 3: build the zip.** Before writing it,
[`mkbndl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mkbndl.md)
checks that every function the bundled files call is in the bundle, so
it cannot stop on the reviewer’s machine with “could not find function”.

``` r

b <- mkbndl(proj, dest = tempdir(), data = csv, overwrite = TRUE)
b
#> ╭── Reproducibility bundle ───────────────────────────────────────────────────╮
#> │   Project    my-study                                                       │
#> │   Zip        my-study_v1_with_data.zip                                      │
#> │   Folder     /tmp/RtmpppHH33                                                │
#> │   Size       193.4 KB                                                       │
#> │   Files      28                                                             │
#> │   Data file  inside                                                         │
#> │   SHA-256    efedf32a8bf2806196941f9e246f53cf986f3fc681f7127cf49870fdb08a92 │
#> │              ab                                                             │
#> │                                                                             │
#> │   Recipients unzip it and double-click START_HERE.command (macOS) or        │
#> │   START_HERE.bat (Windows), or run ./start_here.sh (Linux).                 │
#> │                                                                             │
#> │   Send the SHA-256 separately from the zip, so recipients can check the     │
#> │   copy they received was not altered.                                       │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
```

Send `b$sha256` separately from the zip: the reviewer checks it before
opening anything.

**Step 4: what the reviewer sees.** Unzipped and started (here from R; a
reviewer double-clicks), the runner uses the data inside, checks it and
runs the analysis:

``` r

out <- file.path(tempdir(), "reviewer")
unzip(b$path, exdir = out)
st <- file.path(out, sub("[.]zip$", "", basename(b$path)))
res <- system2(file.path(R.home("bin"), "Rscript"),
               c(shQuote(file.path(st, "setup_and_run.R")), "--quick"),
               stdout = TRUE, stderr = TRUE)
cat(grep("PASS:|DIFFER:|INFO:", res, value = TRUE), sep = "\n")
#>   PASS:   2
#>   DIFFER: 0
#>   INFO:   0
```

Both checks pass on the real data. Run with `--synthetic` the same
checks come out INFO: generated data never counts as a reproduction.
`--data FILE` takes a copy the reviewer already has.

The same from a terminal, once
[`instcli()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/instcli.md)
has put `rmbl` on the path:

``` sh
rmbl pack --new my-study --title "My study"
rmbl pack my-study --data my_data.csv       # writes my-study_v1_with_data.zip here
```

The package ships a full example, the Ontario restrictive confinement
analysis with 55 checks: `mkbndl("otis-mrp", dest = tempdir())`.

``` r

unlink(c(proj, out, csv, b$path), recursive = TRUE)
```

## When, not just in what order

The chain proves the order of a sequence of manifests. It does not prove
that any of them existed at a particular time – the whole chain can be
built in an afternoon and dated however one likes. An RFC 3161 timestamp
token from a third party supplies the date, and
[`tsvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/tsvrf.md)
checks three separate things: that the token is about these bytes, what
time it asserts, and that the authority’s signature holds.

``` r

res <- tsvrf("response.tsr", data = "manifest.json")
res$time
res$checks
```

What it does not check, and this is the difference between it and a
browser’s padlock: whether the certificate should be trusted. There is
no chain building, no validity dates, no revocation and no check of the
timeStamping key usage. Pass the certificate you have independently
decided to trust, and read a pass as “this key said so” rather than
“this is true”.

## Pinning chunk by chunk

A single digest over a file tells you it changed. A Merkle tree over its
chunks tells you *which* chunk changed, and lets you prove one chunk
belongs without re-reading the rest.

``` r

chunks <- c("id,value", "1,2", "3,4", "5,6")
root <- mrkroot(chunks)
root
#> [1] "80332968a476e13898f2d88c2632603b3fa6bcc746bf05be7ed178aced51ab16"
```

``` r

# Editing one chunk moves exactly one leaf.
editedchunks <- chunks
editedchunks[3] <- "3,5"
which(mrklvs(chunks) != mrklvs(editedchunks))
#> [1] 3
```

``` r

# Prove chunk 3 belongs, holding only it and log2(n) sibling digests.
proof <- mrkprf(chunks, 3)
proof
#> $sibling
#> [1] "2191ddd39af84a2334704f1bc99d7c53fc4735a5f1f44cdebdf0c3c52f5d5681"
#> [2] "8f71896ada80f49aab101ab39dff71d81b3470c5abc14cb58f1806b16c8fe6af"
#> 
#> $side
#> [1] "right" "left" 
#> 
#> $scheme
#> [1] 2
mrkvrf(chunks[3], proof, root)
#> [1] TRUE
mrkvrf("3,5", proof, root)
#> [1] FALSE
```

[`chnkfile()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chnkfile.md)
produces the chunks from a file.

An unpaired node at an odd level is *promoted* rather than hashed
against a duplicate of itself. That is a correctness requirement, not a
preference: duplicating the last leaf lets two different chunk lists
produce the same root, which is the CVE-2012-2459 weakness.

``` r

mrkroot(c("a", "b", "c")) == mrkroot(c("a", "b", "c", "c"))
#> [1] FALSE
```

## The history, not just the run

Every manifest above verifies on its own. That says nothing about
whether any were *removed* – delete an inconvenient run and the
remaining manifests are all still perfectly valid.

A chain fixes that by linking each entry to the digest of the one
before:

``` r

chain <- chnnew()
chain <- chnapp(chain, "manifest for run 1", label = "run-1")
chain <- chnapp(chain, "manifest for run 2", label = "run-2")
chain <- chnapp(chain, "manifest for run 3", label = "run-3")
chain
#> ╭── Manifest chain ───────────────────────────────────────────────────────────╮
#> │   Status   ✓ chain intact (3 entries)                                       │
#> │   Entries  3                                                                │
#> │   Head     b9ccb96106a68f3d4d2a0cfb8e2ae160f7996393e28e93d7f4650c2bbd81ff49 │
#> │   Seal     940721e3704268b570bcbf1c9ae841bde02927f584ec44dc3cf053ef7404d8a0 │
#> │                                                                             │
#> │   Every entry links to the one before it, so none was edited, dropped or    │
#> │   reordered after it was added.                                             │
#> │                                                                             │
#> │     #  label            digest                                              │
#> │     1  run-1            cb25fa776c693a106b2d08a1                            │
#> │     2  run-2            03a645a531c93fbb12bb2c07                            │
#> │     3  run-3            b9ccb96106a68f3d4d2a0cfb                            │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
```

``` r

# Deleting an entry from the middle breaks the links, and names where.
tampered <- chain
tampered$entries[[2]] <- NULL
chnvrf(tampered)
#> ╭── Manifest chain check ─────────────────────────────────────────────────────╮
#> │   Status     ✗ chain BROKEN: broken at entry 2 of 2                         │
#> │   Entries    2                                                              │
#> │   Broken at  2                                                              │
#> │   Head       b9ccb96106a68f3d4d2a0cfb8e2ae160f7996393e28e93d7f4650c2bbd81ff │
#> │              49                                                             │
#> │                                                                             │
#> │   An entry no longer links to the one before it: the chain was edited at    │
#> │   or before that entry, and nothing from there on can be relied on.         │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
```

### Sign the seal, not the head

Two failure modes, and neither single value catches both:

- Deleting from the **middle** leaves the last entry’s stored digest
  untouched, so the head is unchanged – but
  [`chnvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chn.md)
  fails.
- Truncating from the **end** leaves a valid prefix that
  [`chnvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chn.md)
  accepts – but the head changes.

``` r

truncated <- chain
truncated$entries[[3]] <- NULL

c(headuncbymiddel =
    chnhead(tampered) == chnhead(chain),
  linksacctru = chnvrf(truncated)$valid)
#> headuncbymiddel     linksacctru 
#>            TRUE            TRUE
```

[`chnseal()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chn.md)
folds the entry count and every link digest into one value, which covers
both. It is the thing to sign:

``` r

sealsig <- cpssign(chnseal(chain), signingkey)
cpsvrf(chnseal(chain), sealsig, pub)
#> [1] TRUE

# The truncated chain seals to a different value.
cpsvrf(chnseal(truncated), sealsig, pub)
#> [1] FALSE

# A chain whose links disagree has no seal to offer at all.
chnseal(tampered)
#> [1] NA
```

## What is verified, and what is not

Every primitive with a published test vector is checked against it:
SHA-512 against FIPS 180-4, HMAC-SHA-256 against RFC 4231, PBKDF2
against the published vectors, BLAKE2b against RFC 7693, CRC-32 against
the ITU V.42 check value.

The XMSS signature scheme is the exception. No official RFC 8391
known-answer vectors ship with the RFC itself, which carries only XDR
formats. The check is instead made against the **reference
implementation**: the whole 2500-byte signature for XMSS-SHA2_10_256 –
index, randomiser, WOTS+ signature and authentication path – is
byte-identical to what `github.com/XMSS/xmss-reference` produces from
the same key material, and those vectors are embedded in the test suite
so the check needs no network. A signature written here can therefore be
handed to another XMSS implementation as bytes.

It is verified against its security properties as well: a genuine
signature verifies, and every tampering of the message, the signature,
the authentication path, the leaf index or the key fails. The scheme is
not *certified*, which is a statement about process rather than about
the bytes.

## Provenance for Indigenous data

The bundled Indigenous tables name their sources (Statistics Canada
table numbers, retrieval dates and licence) in the package’s COPYRIGHTS
file:

``` r

cr <- readLines(system.file("COPYRIGHTS", package = "rmoriebricklayer"))
cat(cr[grep("indigenouslifeexpectancy", cr, fixed = TRUE) + 0:4], sep = "\n")
```

With a data key
([`dlogin()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dlogin.md)),
[`indtabs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/indtabs.md)
lists the mirrored tables themselves:

``` r

head(indtabs()[, c("key", "rows")])
```

[`indtabs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/indtabs.md)
lists the Statistics Canada tables on data.rmorie.com with their source,
licence and table number, so a result can name the exact table it used.

## The pinned data in a picture

The manifest above pins these ten values. A verifier that recomputes the
digest is checking exactly what this chart shows.

``` r

barplot(
  d$x,
  names.arg = seq_len(nrow(d)),
  col = blpal()[1],
  xlab = "row",
  ylab = "x",
  main = "The values the manifest pins"
)
```

![](provenance_files/figure-html/provenance-provenance-plot-1.png)
