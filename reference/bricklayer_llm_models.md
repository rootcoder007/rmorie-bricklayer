# Models offered by the hosted MORIE LLM tier

Asks the gateway (`GET /v1/models`) which models the stored key may use,
through the package's own libcurl binding.

## Usage

``` r
bricklayer_llm_models(timeout = 10)
```

## Arguments

- timeout:

  Seconds to wait for the gateway.

## Value

A character vector of model names, empty when the tier is disabled, no
key is stored, or the gateway does not answer, with attribute
`"default"`: the model
[`bricklayer_llm_ask()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_ask.md)
uses when none is named (the configured one when offered, else the first
listed).

## Examples

``` r
# \donttest{
m <- bricklayer_llm_models()
attr(m, "default")
#> NULL
# }
```
