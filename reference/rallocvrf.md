# Check a Randomisation List at Unblinding

Checks that a list from
[`ralloc()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ralloc.md)
is the one committed to before enrolment, and that the stated procedure
and seed produce exactly it.

## Usage

``` r
rallocvrf(x, digest = NULL, seed = NULL)
```

## Arguments

- x:

  A list from
  [`ralloc()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ralloc.md)
  (kept with [`saveRDS()`](https://rdrr.io/r/base/readRDS.html)).

- digest:

  The commitment published before enrolment, or `NULL` to check against
  the one in `x`.

- seed:

  The seed revealed at unblinding, or `NULL` for the one in `x`.

## Value

An object of class `rmbl_alloc_check`: a list with `ok` (all checks
passed) and `checks` (a data frame of `check`, `ok` and `detail`). It
prints as a box that opens with VERIFIED or NOT VERIFIED.

## Details

Three checks: the list's own commitment, recomputed from its rows,
settings and seed, equals `digest` (the value signed and timestamped
before enrolment; without it, the commitment stored in the list); the
list regenerates row for row from the seed and the settings; and every
participant id is there once. A list edited after the commitment fails
the first; a list that does not come from its seed (one chosen among
many, or written by hand) fails the second.

Errors: `x` that does not come from
[`ralloc()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ralloc.md).

## See also

[`ralloc()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ralloc.md)

## Examples

``` r
a <- ralloc(20, seed = "teaching example")
commitment <- attr(a, "alloc")$digest
rallocvrf(a, digest = commitment)
#> ╭── Randomisation list: verified ─────────────────────────────────────────────╮
#> │ ✔ VERIFIED  · 3 of 3 checks passed                                          │
#> │                                                                             │
#> │   ✔    commitment    the list is the one committed to                       │
#> │   ✔    seed          the seed and the settings give this list, row for row  │
#> │   ✔    participants  20 participants, each once                             │
#> │        commitment    b14ff4ab9155237921eb3d864d48e589c0ce4ffc250dda692efba5 │
#> │                      d809c8c11b                                             │
#> ╰─────────────────────────────────────────────────────────────────────────────╯

# one allocation changed after the commitment
b <- a
b$arm[3] <- if (b$arm[3] == "A") "B" else "A"
rallocvrf(b, digest = commitment)
#> ╭── Randomisation list: NOT verified ─────────────────────────────────────────╮
#> │ ✖ NOT VERIFIED  · 2 of 3 checks failed                                      │
#> │                                                                             │
#> │   ✖    commitment    the list, its settings or the seed differ from the     │
#> │                      commitment                                             │
#> │   ✖    seed          the seed and the settings give a different list        │
#> │   ✔    participants  20 participants, each once                             │
#> │        commitment    5c92aee846760720d34b05844ce66b622148da12ed810894dd1350 │
#> │                      72d7e523c0                                             │
#> ╰─────────────────────────────────────────────────────────────────────────────╯

# a different seed revealed at unblinding
rallocvrf(a, digest = commitment, seed = "another seed")
#> ╭── Randomisation list: NOT verified ─────────────────────────────────────────╮
#> │ ✖ NOT VERIFIED  · 2 of 3 checks failed                                      │
#> │                                                                             │
#> │   ✖    commitment    the list, its settings or the seed differ from the     │
#> │                      commitment                                             │
#> │   ✖    seed          the seed and the settings give a different list        │
#> │   ✔    participants  20 participants, each once                             │
#> │        commitment    827cae9be10ed4b75afad883bf8e4440b1a766d4f53f4977482dc4 │
#> │                      a638f71f4f                                             │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
```
