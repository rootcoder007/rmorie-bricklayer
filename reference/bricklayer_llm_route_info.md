# The language-model route that would answer

Which route
[`bricklayer_llm_ask`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_ask.md)
would take now, without sending anything: your own endpoint, a provider
whose key is set, or Ollama, in that order (or the one `route` names).

## Usage

``` r
bricklayer_llm_route_info(route = NULL)
```

## Arguments

- route:

  `NULL` (the saved setting, else the automatic order), `"auto"`,
  `"own"`, `"ollama"` or a provider id from
  [`bricklayer_llm_providers`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_providers.md).

## Value

`NULL` when no route is set up, else a list with `route` (the id
`route =` takes), `name`, `model` (`NULL` when none is chosen) and
`base` (the address requests go to).

## Examples

``` r
old <- Sys.getenv("OLLAMA_HOST", unset = NA)
Sys.setenv(OLLAMA_HOST = "off")
str(bricklayer_llm_route_info("ollama"))
#>  NULL
if (is.na(old)) Sys.unsetenv("OLLAMA_HOST") else Sys.setenv(OLLAMA_HOST = old)
```
