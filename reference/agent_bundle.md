# Agent-assisted reproducibility-bundle help

Sends a bundle-building request, with a rmoriebricklayer-focused
preamble, to the hosted MORIE language model at <https://llm.rmorie.com>
with the key stored by
[`bricklayer_llm_login`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_login.md)
(`rmbl login` from the shell).

## Usage

``` r
agent_bundle(request, model = NULL, backend = "auto")
```

## Arguments

- request:

  Character scalar describing the bundle task.

- model:

  Optional model id, e.g. `"minimax-m3:cloud"`; `NULL` uses the default
  (`rmbl models` lists them).

- backend:

  `"auto"` (default) or `"hosted"`: both send the request to the hosted
  MORIE tier.

## Value

Character scalar: the answer, or a message saying what to set up when no
key is stored.

## Examples

``` r
# \donttest{
agent_bundle("scaffold a bundle for analysis.R from the Toronto CKAN data")
#> [1] "No language-model route is set up: sign in to the hosted MORIE tier with bricklayer_llm_login() or `rmbl login` (GitHub, an emailed code, or a key from https://llm.rmorie.com)."
agent_bundle("add a Wayback fallback to my fetch step", model = "minimax-m3:cloud")
#> [1] "No language-model route is set up: sign in to the hosted MORIE tier with bricklayer_llm_login() or `rmbl login` (GitHub, an emailed code, or a key from https://llm.rmorie.com)."
# }

# With the hosted tier switched off the call returns a setup hint, not
# an error, and reaches no network -- safe to run anywhere:
old <- Sys.getenv("MORIE_HOSTED_BASE_URL", unset = NA)
Sys.setenv(MORIE_HOSTED_BASE_URL = "off")
agent_bundle("hello")
#> [1] "No language-model route is set up: sign in to the hosted MORIE tier with bricklayer_llm_login() or `rmbl login` (GitHub, an emailed code, or a key from https://llm.rmorie.com)."
if (is.na(old)) Sys.unsetenv("MORIE_HOSTED_BASE_URL") else
  Sys.setenv(MORIE_HOSTED_BASE_URL = old)
```
