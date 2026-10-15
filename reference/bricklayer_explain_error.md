# Explain an error from rmoriebricklayer (or a package built on it)

Finds where an error or warning message comes from, without a language
model and without the network: every message the packages raise is
written in their code, so the code is searched. A message built from
parts (a file name, a number) matches with those parts as wildcards; one
that was cut short or retyped matches by its words. For each match you
get the function that raises it, the exported functions it is reached
from (their help pages say what they expect), and the message as
written, which usually says what to do.

## Usage

``` r
bricklayer_explain_error(message = geterrmessage(), packages = NULL, n = 3L)
```

## Arguments

- message:

  The message: the text of an error, as R printed it ("Error in f(x) :
  ..." is fine), or a condition. Default: the last error of this session
  ([`geterrmessage()`](https://rdrr.io/r/base/stop.html)).

- packages:

  The installed packages to search; default rmoriebricklayer (or the
  comma-separated list in `RMBL_PACKAGES`, which a package built on this
  one sets for its own command line).

- n:

  How many matches to return, best first.

## Value

A data frame, best match first: `package`, `raised_by` (the function
whose code raises it), `exported` (the exported functions that reach
it), `kind` (error or warning), `message` (the message as written, with
`...` where a value goes) and `match` ("exact" or the share of its words
found). No rows when the message is not one of these packages' own: it
came from another package or from R, and
[`bricklayer_llm_ask`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_ask.md)
can help with it.

## Examples

``` r
msg <- "`prompt` must be a single non-empty string"
bricklayer_explain_error(msg, packages = "rmoriebricklayer")
#>            package                   raised_by
#> 1 rmoriebricklayer               .rmbl_string1
#> 2 rmoriebricklayer           .rmbl_fips_scheme
#> 3 rmoriebricklayer wayback_snapshot_url_native
#>                                                                                                             exported
#> 1 agent_bundle, bricklayer_cli, bricklayer_fetch_parse_siu, bricklayer_fetch_siu, bricklayer_llm_ask, capsule_bundle
#> 2           capsule_attest, capsule_bundle, capsule_bundle_verify, capsule_check_attestation, capsule_sign, fips_key
#> 3                                           bricklayer_cli, wayback_retry, wayback_save, wayback_snapshot_url_native
#>    kind                                    message            match
#> 1 error    `...` must be a single non-empty string            exact
#> 2 error `scheme` must be a single non-empty string 80% of its words
#> 3 error    `url` must be a single non-empty string 80% of its words
r <- try(bricklayer_llm_config(no.such = 1), silent = TRUE)
bricklayer_explain_error(r, packages = "rmoriebricklayer")
#>            package             raised_by                              exported
#> 1 rmoriebricklayer        .bl_cli_config                        bricklayer_cli
#> 2 rmoriebricklayer bricklayer_llm_config bricklayer_cli, bricklayer_llm_config
#>    kind                             message match
#> 1 error unknown setting '...' (one of: ...) exact
#> 2 error unknown setting '...' (one of: ...) exact
```
