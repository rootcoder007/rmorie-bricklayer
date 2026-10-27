# Make, read and verify an identity card for your signing key

An identity card ties your public signing key to who you are: your name
and, if you give them, your ORCID iD, e-mail address, web page and
affiliation, all signed with the key itself. Publish the card (on your
web page, in a repository, beside a paper) and give its fingerprint
somewhere people already know you by (the paper, your ORCID record, a
talk). Anyone can then check with `idcrdvrf()` that the card is intact
and in date, that its fingerprint is the one you gave, and that an
attestation or a bundle was signed by the key it carries.

`idcrd()` makes a card from a key of
[`fipskg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md)
(ML-DSA or SLH-DSA) or
[`pqckg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqckg.md)
(XMSS; making the card uses one of the key's signatures). `idcrdrd()`
reads a card written with `file`. `idcrdvrf()` checks one.

## Usage

``` r
idcrd(
  key,
  name,
  orcid = NULL,
  email = NULL,
  url = NULL,
  affil = NULL,
  days = 730,
  file = NULL
)

idcrdrd(path)

idcrdvrf(card, fpr = NULL, at = Sys.time(), atst = NULL)
```

## Arguments

- key:

  Your private signing key, from
  [`fipskg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md)
  or
  [`pqckg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqckg.md).

- name:

  Your name as you want it shown, one string.

- orcid, email, url, affil:

  Optional, one string each: your ORCID iD (`"0000-0002-1825-0097"`, or
  its `https://orcid.org/` address), e-mail address, web page
  (`https://`) and affiliation.

- days:

  How many days the card is valid for, from now. Default 730.

- file:

  Optional path to write the card to, as JSON.

- path:

  The path of a card file written by `idcrd()`.

- card:

  A card, from `idcrd()` or `idcrdrd()`, or the path of one.

- fpr:

  Optional: the fingerprint you were given for this person, with or
  without its spaces. Without it the card is checked only against
  itself.

- at:

  The time to check the card's dates at: a `POSIXct` or anything
  [`as.POSIXct()`](https://rdrr.io/r/base/as.POSIXlt.html) reads, taken
  as UTC. Defaults to now.

- atst:

  Optional: an attestation of
  [`cpsatst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsatst.md),
  or a bundle of
  [`cpsbndl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsbndl.md)
  or
  [`cpsbndlrd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsbndl.md),
  to check was signed by the card's key. Check the attestation itself
  with
  [`cpschkatst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsatst.md)
  or
  [`cpsbndlvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsbndl.md).

## Value

`idcrd()` and `idcrdrd()`: a list of class `rmbl_id_card` with the
card's fields (`type`, `version`, `name`, `orcid`, `email`, `url`,
`affil`, `scheme`, `public`, `context`, `prehash`, `issued_utc`,
`expires_utc`, `signature`) and its `fingerprint`; `idcrd()` returns it
invisibly when it writes `file`. `idcrdvrf()`: a list of class
`rmbl_id_check` with `ok`, `checks` (a data frame with `check`, `ok` and
`detail`), `fingerprint` and `card`.
[`print()`](https://rdrr.io/r/base/print.html) shows a summary.

## Details

A card is self-signed. Its signature proves that the card was made by
whoever holds the private key and that nothing in it has changed since;
it cannot prove that the name on it is true. That is what the
fingerprint is for: a card whose fingerprint matches the one you
published where people know you is the key you meant. The card's
signature is made under its own context string (or, for XMSS, over a
payload naming the card type), so it can never be passed off as an
attestation, nor an attestation as a card.

The fingerprint is the SHA-256 digest of the scheme and the public key,
written as 16 groups of four hexadecimal digits; compare all of it. An
ORCID iD is checked against its check digit (ISO 7064 MOD 11-2), an
e-mail address for its shape and a web page for an `https://` address.

`idcrdvrf()` records every step as a row of `checks`: `card_complete`,
`card_type`, `signature`, `in_date` (at `at`), and `orcid` when the card
has one, `fingerprint` when `fpr` is given, `signed_by_card` when `atst`
is given. `ok` is `TRUE` only when every row passed; a failed check is a
row, not an error.

Errors: `key` not a private key of
[`fipskg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md)
or
[`pqckg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqckg.md);
`name` not one non-empty string; an optional field that is not one
string, an ORCID iD with a wrong check digit, an e-mail address or a web
page of the wrong shape; `days` not a positive whole number; `path` not
a card file.

## See also

[`fipskg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md),
[`pqckg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqckg.md),
[`cpsatst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsatst.md),
[`cpschkatst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsatst.md),
[`cpsbndlvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsbndl.md).

## Examples

``` r
# once: make a key and a card, publish the card, give out the fingerprint
key <- fipskg("ML-DSA-44")
f <- tempfile(fileext = ".json")
idcrd(
  key,
  "Ada Lovelace",
  orcid = "0000-0002-1825-0097",
  url = "https://example.org/ada",
  file = f
)
card <- idcrdrd(f)
card
#> ╭── Identity card ────────────────────────────────────────────────────────────╮
#> │   name         Ada Lovelace                                                 │
#> │   orcid        0000-0002-1825-0097                                          │
#> │   web          https://example.org/ada                                      │
#> │   key          ML-DSA-44                                                    │
#> │   fingerprint  DF6E 6FF6 997E A305 FBBF EB4F D192 792E 4716 3074 5473 C086  │
#> │                0067 1591 5504 4260                                          │
#> │   issued       2026-10-27T16:22:40Z                                         │
#> │   expires      2028-10-26T16:22:40Z                                         │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
card$fingerprint
#> [1] "DF6E 6FF6 997E A305 FBBF EB4F D192 792E 4716 3074 5473 C086 0067 1591 5504 4260"

# anyone, later: is this the card I was told about, and did it sign this?
man <- mkmnf(list(project = "demo"), env = FALSE)
a <- cpsatst(man, key)
res <- idcrdvrf(f, fpr = card$fingerprint, atst = a)
res$ok
#> [1] TRUE
res$checks
#>            check   ok
#> 1  card_complete TRUE
#> 2      card_type TRUE
#> 3      signature TRUE
#> 4        in_date TRUE
#> 5          orcid TRUE
#> 6    fingerprint TRUE
#> 7 signed_by_card TRUE
#>                                                                                detail
#> 1                                                                                    
#> 2                                 an rmbl identity card, signed under its own context
#> 3                               made by the holder of the card's key; unchanged since
#> 4 valid 2026-10-27T16:22:40Z to 2028-10-26T16:22:40Z; checked at 2026-10-27T16:22:40Z
#> 5                                                                 0000-0002-1825-0097
#> 6                                            the card's key is the one you were given
#> 7                                              the attestation carries the card's key

# a card edited after signing fails
bad <- card
bad$name <- "Someone Else"
idcrdvrf(bad)$ok
#> [1] FALSE

# an attestation made with another key is not the card's
other <- cpsatst(man, fipskg("ML-DSA-44"))
idcrdvrf(card, atst = other)$ok
#> [1] FALSE

# an ORCID iD with a wrong check digit is refused
try(idcrd(key, "Ada Lovelace", orcid = "0000-0002-1825-0098"))
#> Error : idcrd: `orcid` 0000-0002-1825-0098 has a wrong check digit
```
