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
format(x, ...)

ldgrchk(ledger, pkgs = NULL)

# S3 method for class 'rmbl_ledger_check'
format(x, ...)

# S3 method for class 'rmbl_ledger_check'
print(x, ...)

# S3 method for class 'rmbl_ledger'
print(x, ...)
```

## Arguments

- path:

  Character scalar, the ledger JSON file.

- x:

  A `ldgrread()` or `ldgrchk()` result.

- ...:

  Not used.

- ledger:

  A `ldgrread()` result, or the path of a ledger file.

- pkgs:

  Character vector: check only the covered functions and checks of these
  packages; `NULL` (the default) checks every package named.

## Value

`ldgrread()`: the ledger, a list of class `rmbl_ledger`, with the
normalised path as the attribute `path`. `ldgrchk()`: a data frame
(class `rmbl_ledger_check`, which prints as a box) with the columns
`capsule`, `part` (`ledger`, or the capsule parts), `file`, `check`,
`ok`, `detail`, `severity` (`error`, `warn` or `note`) and `line`.

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
f <- system.file(
  "extdata",
  "ledger_sample.json",
  package = "rmoriebricklayer"
)
l <- ldgrread(f)
l
#> ╭── Proof ledger rmoriebricklayer sample ledger ──────────────────────────────╮
#> │   Theorems  3 theorems (1 proved, 1 sorry, 1 axiom)                         │
#> │   Source    https://github.com/rootcoder007/rmorie-proofs @ 0123456789ab    │
#> │   Lean      v4.12.0                                                         │
#> │   File      /tmp/Rtmp5MSEQX/temp_libpath1e786a31c741/rmoriebricklayer/extda │
#> │             ta/ledger_sample.json                                           │
#> │                                                                             │
#> │   id               theorem                         status  sorry            │
#> │   ---------------  ------------------------------  ------  -----            │
#> │   gini-equal       Rmorie.Gini.gini_const_eq_zero  proved      0            │
#> │   lorenz-monotone  Rmorie.Gini.lorenz_monotone     sorry       1            │
#> │   float-round      Rmorie.Float.round_nearest      axiom       0            │
#> │                                                                             │
#> │   1 of 3 theorems are proved; the others are 1 axiom and 1 sorry: not       │
#> │   proofs yet.                                                               │
#> │                                                                             │
#> │   A theorem marked proved has a machine-checked proof with no sorry;        │
#> │   ldgrchk() checks that and that the R functions it covers exist.           │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
r <- ldgrchk(l)
r[, c("check", "ok", "severity", "detail")]
#> ╭── Proof ledger check ───────────────────────────────────────────────────────╮
#> │ ✖ NOT VERIFIED  · 2 of 6 checks failed                                      │
#> │                                                                             │
#> │   Checks  4 of 6 passed (1 warnings)                                        │
#> │                                                                             │
#> │   At least one check failed, so a theorem is not proved, or a function it   │
#> │   covers is missing.                                                        │
#> │                                                                             │
#> │   ✔    proved: gini-equal       Rmorie.Gini.gini_const_eq_zero, no sorry    │
#> │   ✔    covered: gini-equal rmoriebricklayer::ginicoef                       │
#> │          exported by the installed package                                  │
#> │   ✔    check: gini-equal        ginicoef(c(5, 5, 5, 5)) = 0, expected 0     │
#> │                                 within 1e-12                                │
#> │   ✖    proved: lorenz-monotone  Rmorie.Gini.lorenz_monotone is sorry with   │
#> │                                 1 sorry                                     │
#> │   ✔    covered: lorenz-monotone rmoriebricklayer::lorenzc                   │
#> │          exported by the installed package                                  │
#> │   WARN proved: float-round      Rmorie.Float.round_nearest is axiom with 0  │
#> │                                 sorry                                       │
#> ╰─────────────────────────────────────────────────────────────────────────────╯

# a file that is not a ledger
bad <- tempfile(fileext = ".json")
writeLines('{"name": "x"}', bad)
try(ldgrread(bad))
#> Error : ldgrread: file1e78ba96c7.json is not a ledger: $: missing required toolchain, source, theorems
unlink(bad)
```
