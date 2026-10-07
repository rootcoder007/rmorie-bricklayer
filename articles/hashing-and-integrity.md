# Hashing, keyed digests, key derivation and Merkle trees

Everything a capsule pins is pinned by a digest. This vignette covers
the hashing primitives, how to compare digests safely, how to derive a
key from a passphrase, how to get randomness, and how a Merkle tree lets
a large file be pinned and partially verified.

## Digests of text and files

``` r

core_sha256("hello capsule")
#> [1] "97cdf3978fc8755453e42fb3d0384a6612f1dde79c46cf422abc0563cf8426e2"
core_sha512("hello capsule")
#> [1] "aa92b1aa2bf977ec1c4b3a47795d24e98ab595464236b9c59696c1999794714639df0fa5e66fb7be86bf2d05e4a45b6207a40fc4ae1f3458ca40ceed87a9d76e"
core_blake2b("hello capsule")
#> [1] "061431a711a23d1745664ba6d36ad517ab6f48db421d492f13cd110f2067b9ce"
core_crc32("hello capsule")
#> [1] 1607001718
```

Files are hashed in blocks, so a multi-gigabyte file does not need to
fit in memory:

``` r

f <- tempfile()
writeLines("hello capsule", f)
sha256_file(f)
#> [1] "55d6110230c260319d580bb6274db530b7e751c4f687fc00d0736ec531260a02"
sha512_file(f)
#> [1] "358665f1505b7dced4ab0e1d7cf5b634bc60f8cbdf7c59f8ec6957f8e1a0df990fbaf92e6dc662662cca542e475b0862453a932d9fa58c2bc7a4b3de8cecdfc4"
crc32_file(f)
#> [1] 2347637372

before <- sha256_file(f)
writeLines("hello capsule (edited)", f)
sha256_file(f) == before
#> [1] FALSE
```

CRC-32 is a checksum, not a cryptographic hash: it detects accidental
corruption and nothing more. SHA-256 and SHA-512 (FIPS 180-4) and
BLAKE2b are collision-resistant;
[`verify_sha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_sha256.md)
checks a file against a pinned digest.

## Digests of R objects

[`digest_object()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/digest_object.md)
serialises an object canonically and hashes the bytes, so attributes,
names and types are part of the identity:

``` r

digest_object(list(a = 1L, b = "x"))
#> [1] "bf5d21a8b26f6cec8503a46f69e854bf98fea03b62dfaf90cb780feac7165b27"
identical(digest_object(1:10), digest_object(1:10))
#> [1] TRUE
digest_object(1:10) == digest_object(1:11)
#> [1] FALSE
digest_object(matrix(1:6, nrow = 2)) == digest_object(1:6)   # dimensions count
#> [1] FALSE
digest_object(data.frame(x = 1:3))
#> [1] "24b0995a368ea8d1178b7f6e44c6d8956db4aadfc91d3e6f6911868b38c06d21"
```

## Keyed digests and constant-time comparison

An HMAC (RFC 2104) is a digest that only the holder of the key can
produce, so a manifest cannot be re-signed without the key:

``` r

core_hmac_sha256("Jefe", "what do ya want for nothing?")   # RFC 4231 test case 2
#> [1] "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843"
core_hmac_sha256("key-a", "manifest")
#> [1] "463b8b2c47caadd6334c53e4d9492fdac6fcaca185f56229043e1a025138ceae"
core_hmac_sha256("key-b", "manifest")
#> [1] "f3ebaf1b8fad504c57fd4cf82b163e30eac6eabd31b7c41a2a6e268ec445b134"
```

**Never compare a tag with `==`.** A string comparison stops at the
first differing character, so its running time tells an attacker how
many leading characters were right.
[`core_digest_equal()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_keyed_digest.md)
compares every byte regardless and returns `FALSE` for a length mismatch
without erroring:

``` r

tag <- core_hmac_sha256("k", "m")
core_digest_equal(tag, core_hmac_sha256("k", "m"))
#> [1] TRUE
core_digest_equal(tag, core_hmac_sha256("k", "tampered"))
#> [1] FALSE
core_digest_equal(tag, "too-short")
#> [1] FALSE
```

## Deriving a key from a passphrase

A passphrase is not a key: it is short, low-entropy and chosen by a
person. PBKDF2 (RFC 8018) stretches it with a salt and an iteration
count that makes each guess expensive:

``` r

derive_key("password", "salt", iterations = 1)     # the published test vector
#> [1] "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b"
identical(derive_key("pw", "s", 1000), derive_key("pw", "s", 1000))
#> [1] TRUE
derive_key("pw", "salt-a", 1000) == derive_key("pw", "salt-b", 1000)
#> [1] FALSE
```

The salt must be random and stored beside the ciphertext or signature;
the default of 100,000 iterations is the floor for interactive use. A
derived key signs a manifest symmetrically:

``` r

salt <- paste(format(random_bytes(16)), collapse = "")
key <- derive_key("correct horse battery staple", salt)
sig <- capsule_sign("manifest-digest", key, scheme = "hmac")
capsule_verify("manifest-digest", sig, key)
#> [1] TRUE
```

## Randomness

[`random_bytes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/random_bytes.md)
draws from the operating system (`getrandom`, `BCryptGenRandom`) and
does **not** consume R’s seeded stream, so a reproducible analysis is
unaffected by key generation happening beside it:

``` r

set.seed(1)
a <- stats::runif(1)
set.seed(1)
invisible(random_bytes(32))
identical(stats::runif(1), a)
#> [1] TRUE
```

For tests that need reproducible “random” bytes, the package’s AES-256
CTR_DRBG (SP 800-90A) gives the same bytes from the same seed, exactly
as NIST’s known-answer files use it; a personalization string separates
streams:

``` r

d <- drbg_new(as.raw(0:47))
drbg_generate(d, 16)
#>  [1] 06 15 50 23 4d 15 8c 5e c9 55 95 fe 04 ef 7a 25
a <- drbg_new(as.raw(1:48), personalization = charToRaw("session 1"))
b <- drbg_new(as.raw(1:48), personalization = charToRaw("session 2"))
identical(drbg_generate(a, 16), drbg_generate(b, 16))
#> [1] FALSE
```

## Merkle trees: pin a large file, verify a piece

A Merkle tree hashes a file in chunks, then hashes pairs of digests up
to one root. The root pins the whole file; a *proof* of `log2(n)`
digests shows that one chunk belongs without holding the others, and a
diff of the leaves names exactly which chunk changed.

``` r

chunks <- c("row1,row2", "row3,row4", "row5,row6", "row7,row8")
root <- merkle_root(chunks)
root
#> [1] "d2197affda886ecc49807b28c90a8c4ff7a07f122225ecc64788d08df5a312f3"

before <- merkle_leaves(chunks)
after <- merkle_leaves(c(chunks[1:2], "row5,row6-EDITED", chunks[4]))
which(before != after)
#> [1] 3

pr <- merkle_proof(chunks, 3)
merkle_verify(chunks[3], pr, root)
#> [1] TRUE
merkle_verify("row5,row6-EDITED", pr, root)
#> [1] FALSE
```

[`chunk_file()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chunk_file.md)
splits a real file into fixed-size chunks that concatenate back to its
bytes:

``` r

p <- tempfile()
writeLines(rep("some capsule content", 50), p)
ch <- chunk_file(p, chunk_bytes = 128)
length(ch)
#> [1] 9
merkle_root(ch)
#> [1] "c4cb691d88a0dbf1dad9767c19095d54ac6958e6411e06d81dced0dba895c382"
identical(unlist(ch), readBin(p, "raw", file.size(p)))
#> [1] TRUE
```

This is how
[`capsule_bundle()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_bundle.md)
pins data files: a mismatch identifies which part of a capsule changed
rather than only that something did.

## How these implementations are checked

The digests are compared with OpenSSL at every block boundary, run
against the NIST ACVP sets for SHA-3, SHAKE, HMAC and PBKDF2, and fuzzed
differentially against OpenSSL 3.5. The keyed-digest comparison and
PBKDF2 run under valgrind with the key marked undefined to prove their
timing does not depend on it, and dudect measures the comparison and
PBKDF2 on real CPUs.
