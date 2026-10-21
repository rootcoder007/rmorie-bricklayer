# Read and check a proof ledger

A proof ledger records the theorems of a formal-proof build (Lean and
Mathlib): each theorem's statement, file and line, its status (`proved`,
`sorry` or `axiom`) and number of `sorry` placeholders, the package
functions whose behaviour it states, and optionally a numeric check of
one of them in R. The format is `schemapath("ledger")`, in the style of
the capsule schemas; nothing in it is specific to this package, so any
package can ship a ledger in `inst/ledger/` and any formal-proof project
can write one.

## Usage

``` r
ldgrread(path)

# S3 method for class 'rmbl_ledger'
print(x, ...)

ldgrchk(ledger, pkgs = NULL)
```

## Arguments

- path:

  Character scalar, the ledger JSON file.

- x:

  A `ldgrread()` result.

- ...:

  Not used.

- ledger:

  A `ldgrread()` result, or the path of a ledger file.

- pkgs:

  Character vector: check only the covered functions and checks of these
  packages; `NULL` (the default) checks every package named.

## Value

`ldgrread()`: the ledger, a list of class `rmbl_ledger`, with the
normalised path as the attribute `path`. `ldgrchk()`: a data frame with
the columns `capsule`, `part` (`ledger`, or the capsule parts), `file`,
`check`, `ok`, `detail`, `severity` (`error`, `warn` or `note`) and
`line`.

## Details

`ldgrread()` parses the file and validates it against the schema; a file
that does not validate, or that repeats a theorem id, is refused with
the first problems found.

`ldgrchk()` returns check rows in the shape of `rmbl verify` (the `rows`
of
[`cpschk()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpschk.md)):

- `proved: ID`:

  the theorem is `proved` with `sorry_count` 0. A `sorry` fails as an
  error; an `axiom` fails as a warning (it is assumed, not proved).

- `covered: ID PKG::FN`:

  the covered function is exported by the installed package; a package
  that is not installed here is a note, not a failure (it cannot be
  checked).

- `check: ID`:

  the theorem's `check$expr` evaluates within `check$tol` (default 1e-8)
  of `check$expect`. The expression is evaluated in a sandbox: an
  environment holding only the exported functions of the first R package
  the theorem covers and a short list of base arithmetic and
  constructors (`c`, `list`, `seq`, `rep`, `sum`, `+`, `$`, ...).
  Anything else is refused before evaluation: a call to any other
  function ([`system()`](https://rdrr.io/r/base/system.html),
  [`file()`](https://rdrr.io/r/base/connections.html),
  [`eval()`](https://rdrr.io/r/base/eval.html), another package), a free
  variable, or an expression whose outer call is not a call to that
  package (or an extraction from one). Evaluation is limited to 10
  seconds.

- `ledger_commit_pinned`, `ledger_build_pinned`:

  when the ledger is the data file of a capsule whose provenance says
  `kind: "ledger"`: the provenance's `source$commit` and
  `source$build_digest` equal the ledger's. The capsule's own rows
  ([`vrfcps()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfcps.md),
  the bundle and attestation through
  [`cpsbndlvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsbndl.md),
  the schemas) come with them, as `rmbl verify` reports them;
  `rmbl verify` adds the ledger rows to such a capsule too.

## See also

[`schemapath()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/schemapath.md),
[`cpschk()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpschk.md),
[`cpsbndlvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsbndl.md).

## Examples

``` r
f <- system.file("extdata", "ledger_sample.json", package = "rmoriebricklayer")
l <- ldgrread(f)
l
#> Proof ledger rmoriebricklayer sample ledger: 3 theorems (1 proved, 1 sorry, 1 axiom)
#>   https://github.com/rootcoder007/rmorie-proofs @ 0123456789ab, Lean v4.12.0
r <- ldgrchk(l)
r[, c("check", "ok", "severity", "detail")]
#>                                                check    ok severity
#> 1                                 proved: gini-equal  TRUE    error
#> 2     covered: gini-equal rmoriebricklayer::ginicoef  TRUE    error
#> 3                                  check: gini-equal  TRUE    error
#> 4                            proved: lorenz-monotone FALSE    error
#> 5 covered: lorenz-monotone rmoriebricklayer::lorenzc  TRUE    error
#> 6                                proved: float-round FALSE     warn
#>                                                 detail
#> 1             Rmorie.Gini.gini_const_eq_zero, no sorry
#> 2                    exported by the installed package
#> 3 ginicoef(c(5, 5, 5, 5)) = 0, expected 0 within 1e-12
#> 4    Rmorie.Gini.lorenz_monotone is sorry with 1 sorry
#> 5                    exported by the installed package
#> 6     Rmorie.Float.round_nearest is axiom with 0 sorry

# a file that is not a ledger
bad <- tempfile(fileext = ".json")
writeLines('{"name": "x"}', bad)
try(ldgrread(bad))
#> Error : ldgrread: file1fbb17f1d5d8.json is not a ledger: $: missing required toolchain, source, theorems
unlink(bad)
```
