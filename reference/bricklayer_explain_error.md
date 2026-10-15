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
  ..." is fine), a condition object, or a
  [`try()`](https://rdrr.io/r/base/try.html) result. Default: the last
  error of this session
  ([`geterrmessage()`](https://rdrr.io/r/base/stop.html)).

- packages:

  Character vector of installed packages to search; default `NULL`,
  meaning rmoriebricklayer (or the comma-separated list in the
  environment variable `RMBL_PACKAGES`, which a package built on this
  one sets for its own command line).

- n:

  How many matches to return, best first: a whole number, default 3.

## Value

A data frame with at most `n` rows, best match first, and the character
columns `package`, `raised_by` (the function whose code raises it),
`exported` (the exported functions that reach it, comma-separated),
`kind` (`"error"` or `"warning"`), `message` (the message as written,
with `...` where a value goes) and `match` (`"exact"` or the share of
its words found, such as `"80% of its words"`). No rows when the message
is not one of these packages' own: it came from another package or from
R, and
[`bricklayer_llm_ask`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_ask.md)
can help with it.

## Details

The first call in a session walks the body of every function in the
searched packages and collects each
[`stop()`](https://rdrr.io/r/base/stop.html),
[`warning()`](https://rdrr.io/r/base/warning.html) and usage error whose
literal text has at least 12 letters. A message built with
[`sprintf()`](https://rdrr.io/r/base/sprintf.html),
[`gettextf()`](https://rdrr.io/r/base/sprintf.html),
[`paste()`](https://rdrr.io/r/base/paste.html) or
[`paste0()`](https://rdrr.io/r/base/paste.html) becomes a template with
its computed parts as wildcards. Each raising function is traced up to
four calls to the exported functions that reach it (at most six are
listed). The table is kept in memory for the session (about a second to
build for this package), and, while a person is watching an interactive
session and the answer cache is on, also saved as an `.rds` file in the
answer-cache directory
(`tools::R_user_dir("rmoriebricklayer", "cache")`, or
`options(rmoriebricklayer.llm_cache_dir)`); the cache is off under
`options(morie.quiet = TRUE)`, `MORIE_LLM_CACHE=off`, tests and
`R CMD check`.

The message is cleaned first: an "Error in f(x) :" or "Warning message:"
prefix is dropped, curly quotes become straight ones and white space is
collapsed. A template that matches the start of the message as a regular
expression is an exact match and ranks first (longer templates before
shorter ones). Otherwise a template scores \\0.6 h / \|m\| + 0.4 h /
\|t\|\\, where \\h\\ is the number of shared words (three letters or
more, common words left out, at least two needed), \\\|m\|\\ the words
of the message and \\\|t\|\\ those of the template; scores of 0.55 and
above are kept.

Errors: `message` that is not character text or a condition; `n` not a
whole number of 1 or more; `packages` that are not installed.

## Examples

``` r
msg <- "`prompt` must be a single non-empty string"
bricklayer_explain_error(msg, packages = "rmoriebricklayer")
#>            package            raised_by
#> 1 rmoriebricklayer        .rmbl_string1
#> 2 rmoriebricklayer    .rmbl_fips_scheme
#> 3 rmoriebricklayer use_capsule_template
#>                                                                                                             exported
#> 1 agent_bundle, bricklayer_cli, bricklayer_fetch_parse_siu, bricklayer_fetch_siu, bricklayer_llm_ask, capsule_bundle
#> 2           capsule_attest, capsule_bundle, capsule_bundle_verify, capsule_check_attestation, capsule_sign, fips_key
#> 3                                                                                               use_capsule_template
#>    kind                                    message            match
#> 1 error    `...` must be a single non-empty string            exact
#> 2 error `scheme` must be a single non-empty string 80% of its words
#> 3 error   `name` must be a single non-empty string 80% of its words
r <- try(bricklayer_llm_config(no.such = 1), silent = TRUE)
bricklayer_explain_error(r, packages = "rmoriebricklayer")
#>            package             raised_by                              exported
#> 1 rmoriebricklayer        .bl_cli_config                        bricklayer_cli
#> 2 rmoriebricklayer bricklayer_llm_config bricklayer_cli, bricklayer_llm_config
#>    kind                             message match
#> 1 error unknown setting '...' (one of: ...) exact
#> 2 error unknown setting '...' (one of: ...) exact

# the message as R prints it, with the call in front
bricklayer_explain_error(
  "Error in merkle_proof(x, 9) : `index` must be between 1 and the number of chunks",
  n = 1)
#>            package    raised_by     exported  kind
#> 1 rmoriebricklayer merkle_proof merkle_proof error
#>                                              message match
#> 1 `index` must be between 1 and the number of chunks exact

# a condition object, and a message retyped from memory
e <- tryCatch(kem_sizes(3), error = identity)
bricklayer_explain_error(e, n = 1)
#>            package       raised_by
#> 1 rmoriebricklayer .rmbl_kem_level
#>                                                  exported  kind
#> 1 kem_decapsulate, kem_encapsulate, kem_keygen, kem_sizes error
#>                                   message match
#> 1 `level` must be one of 512, 768 or 1024 exact
bricklayer_explain_error("index between number chunks", n = 1)
#>            package    raised_by     exported  kind
#> 1 rmoriebricklayer merkle_proof merkle_proof error
#>                                              message             match
#> 1 `index` must be between 1 and the number of chunks 100% of its words

# R's own messages are not in the table: no rows
nrow(bricklayer_explain_error("object 'x' not found"))
#> [1] 0

# n must be at least 1
try(bricklayer_explain_error(msg, n = 0))
#> Error : `n` must be a whole number of 1 or more
```
