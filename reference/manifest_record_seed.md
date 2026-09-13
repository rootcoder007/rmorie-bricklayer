# Record and restore the random number generator state

`manifest_record_seed()` stores the generator's kind and its full state
in the manifest; `manifest_restore_seed()` puts both back. Together they
let a run that used randomness be repeated exactly.

## Usage

``` r
manifest_record_seed(manifest)

manifest_restore_seed(manifest)
```

## Arguments

- manifest:

  A manifest, as from
  [`make_manifest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/make_manifest.md).

## Value

`manifest_record_seed()` the manifest with an `rng` element;
`manifest_restore_seed()` the manifest, invisibly, having set the
generator.

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

This is opt-in because the state is 626 integers, which is a lot of
manifest for an analysis with no randomness in it.

## See also

[`capture_environment()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capture_environment.md),
[`capsule_falsify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_falsify.md).

## Examples

``` r
set.seed(42)
m <- manifest_record_seed(make_manifest(list(a = 1),
                                        environment = FALSE))
first <- runif(3)

# any amount of other work can happen in between
invisible(runif(1000))

manifest_restore_seed(m)
identical(runif(3), first)
#> [1] TRUE
```
