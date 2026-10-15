# Models a language-model route offers

Asks the provider (or your own server, or Ollama) which models your key
can use, through the package's own libcurl binding.

## Usage

``` r
bricklayer_llm_models(route = NULL, timeout = 15)
```

## Arguments

- route:

  `NULL` (the route
  [`bricklayer_llm_ask`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_ask.md)
  would take) or a route name: `"own"`, `"ollama"` or a provider id (see
  [`bricklayer_llm_providers`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_providers.md)).

- timeout:

  Seconds to wait for the answer.

## Value

A character vector of model names, empty when no route is set up or the
provider does not list its models, with attributes `"default"` (the
model
[`bricklayer_llm_ask()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_ask.md)
uses when none is named) and `"route"`.

## Examples

``` r
# \donttest{
m <- bricklayer_llm_models()
attr(m, "default")
#> NULL
# }
```
