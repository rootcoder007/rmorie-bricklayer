# Record and restore the random number generator state

`mnfrecseed()` stores the generator's kind and its full state in the
manifest; `mnfrstseed()` puts both back. Together they let a run that
used randomness (a bootstrap, a permutation test, a simulation, a random
split) be repeated exactly, even without knowing what seed was set or
how many draws came before.

## Usage

``` r
mnfrecseed(man)

mnfrstseed(man)
```

## Arguments

- man:

  A manifest, as from
  [`mkmnf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mkmnf.md)
  (a list).

## Value

`mnfrecseed()`: the manifest with an `rng` element, a list of `kind`
(character, the three [`RNGkind()`](https://rdrr.io/r/base/Random.html)
values), `state` (integer, the `.Random.seed` vector) and
`was_initialised` (logical, whether a state existed before the call).
`mnfrstseed()`: the manifest, invisibly, having set the generator.

## Details

Why the state and not just a seed. `set.seed(1)` is reproducible only if
everything before it is too: a single extra draw anywhere upstream
shifts every subsequent value. Recording `.Random.seed` as it stood pins
the actual position in the stream, and recording
[`RNGkind()`](https://rdrr.io/r/base/Random.html) alongside it pins what
that position means – R has changed its default
[`sample()`](https://rdrr.io/r/base/sample.html) algorithm before, and a
seed replayed under a different kind gives different numbers with no
warning.

This is opt-in because the state is 626 integers for R's default
Mersenne-Twister generator, which is a lot of manifest for an analysis
with no randomness in it.

Side effects: if no generator state exists yet (`.Random.seed` is absent
from the global environment), `mnfrecseed()` draws one uniform number to
create it, and records `was_initialised = FALSE`. `mnfrstseed()` calls
[`RNGkind()`](https://rdrr.io/r/base/Random.html) with the recorded
kinds and assigns `.Random.seed` in the global environment, replacing
the current state.

Errors: `man` that is not a list (or is a data frame); for
`mnfrstseed()`, a manifest without a recorded state or with an empty
kind.

## See also

[`capenv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capenv.md),
[`cpsfals()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsfals.md).

## Examples

``` r
set.seed(42)
m <- mnfrecseed(mkmnf(list(a = 1),
                                        env = FALSE))
first <- runif(3)

# any amount of other work can happen in between
invisible(runif(1000))

mnfrstseed(m)
identical(runif(3), first)
#> [1] TRUE

# what is stored
m$rng$kind
#> [1] "Mersenne-Twister" "Inversion"        "Rejection"       
length(m$rng$state)
#> [1] 626

# a manifest without a recorded state cannot restore one
try(mnfrstseed(mkmnf(list(a = 1), env = FALSE)))
#> Error : this manifest carries no recorded generator state; mnfrecseed() adds one
```
