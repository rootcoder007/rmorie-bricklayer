# Record Correctness Evidence in a Manifest

Adds the outcome of a correctness check to a manifest, so the capsule
carries not only the reported numbers but the checks they passed. Each
planted effect from
[`cpsplant()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsplant.md)
becomes a record (recovered against planted, within the tolerance); a
[`cpsspec()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsspec.md)
check records the share of specifications agreeing in sign (which should
be 1); a
[`cpsfals()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsfals.md)
result records each control that ran (1 for passed).

## Usage

``` r
recevid(man, x, grp = "evidence")
```

## Arguments

- man:

  A manifest from
  [`mkmnf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mkmnf.md).

- x:

  A result of
  [`cpsplant()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsplant.md),
  [`cpsspec()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsspec.md)
  or
  [`cpsfals()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsfals.md).

- grp:

  The records' group.

## Value

The manifest, with the new records.

## See also

[`recrd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/recrd.md),
[`cpsbndl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsbndl.md).

## Examples

``` r
set.seed(1)
d <- data.frame(x = rbinom(100, 1, 0.5))
d$y <- d$x + rnorm(100)
dm <- function(df) mean(df$y[df$x == 1]) - mean(df$y[df$x == 0])
man <- mkmnf(list(project = "demo"), env = FALSE)
man <- recevid(man, cpsplant(d, dm, "y", "x", n = 20, seed = 1))
#>   planted effect 0 recovered                   observed = 0.0525       expected = 0.0000       [INFO]
#>   planted effect 0.5 recovered                 observed = 0.3880       expected = 0.5000       [INFO]
#>   planted effect 1 recovered                   observed = 1.0259       expected = 1.0000       [INFO]
man
#> ╭── Run manifest ────────────────────────────────────────────────────────────╮
#> │   project       demo                                                       │
#> │   synthetic     TRUE                                                       │
#> │   Cross-checks  3 (INFO 3)                                                 │
#> │   Environment   not captured                                               │
#> │                                                                            │
#> │   Cross-checks                                                             │
#> │   check                         group     observed    expected  diff       │
#> │   ----------------------------  --------  ----------  --------  ---------- │
#> │   planted effect 0 recovered    evidence  0.05246858  0         0.05246858 │
#> │   planted effect 0.5 recovered  evidence  0.3879529   0.5       0.1120471  │
#> │   planted effect 1 recovered    evidence  1.02593     1         0.02593038 │
#> │                                                                            │
#> │   check                         tol        status                          │
#> │   ----------------------------  ---------  ------                          │
#> │   planted effect 0 recovered    0.2304338  INFO                            │
#> │   planted effect 0.5 recovered  0.2105028  INFO                            │
#> │   planted effect 1 recovered    0.2635938  INFO                            │
#> │                                                                            │
#> │   No cross-check differs; 0 of 3 pass and the rest are INFO.               │
#> │   Built on synthetic data: every cross-check is INFO, not evidence.        │
#> │                                                                            │
#> │   wrmnfjs() writes it as JSON; mnfdgst() is the digest a signature         │
#> │   covers. Neither depends on how it prints.                                │
#> ╰────────────────────────────────────────────────────────────────────────────╯
```
