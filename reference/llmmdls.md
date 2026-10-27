# Models a language-model route offers

Asks the provider (or your own server, or a local Ollama server) which
models your key can use, so you can pick one for the `model` argument of
[`llmask`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmask.md)
or save it with `rmoriebricklayer config set PROVIDER.model NAME`. The
request goes through the package's own libcurl binding; no prompt is
sent.

## Usage

``` r
llmmdls(route = NULL, tmout = 15)
```

## Arguments

- route:

  Character scalar or `NULL` (the default: the route
  [`llmask`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmask.md)
  would take). Otherwise `"auto"`, `"own"`, `"ollama"` or a provider id
  from
  [`llmprvd`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmprvd.md).

- tmout:

  Numeric scalar, seconds to wait for the model list; default `15`.

## Value

A character vector of model ids (possibly empty) with two attributes:
`"default"`, the model
[`llmask()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmask.md)
uses when `model` is not given (character, or `NULL` when none is
chosen), and `"route"`, the readable name of the route asked (such as
`"OpenAI"` or `"local Ollama"`; `NULL` when no route is set up).

## Details

The route is resolved as in
[`llmrte`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmrte.md).
The list comes from the provider's model endpoint: `GET /models` in the
OpenAI format (own endpoint and most providers), `GET /v1/models` for
Anthropic, `GET /v1beta/models` for Gemini (only models that support
`generateContent` are kept), and `GET /api/tags` for Ollama. Perplexity
publishes no model list, so its route returns an empty vector. A failed
request, a non-200 answer or a reply that is not JSON also gives an
empty vector, not an error, so check
[`llmstat`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmstat.md)
when the list is unexpectedly empty. Names are cleaned of control
characters before they are returned.

Errors only while resolving the route: `"hosted"`, an unknown route, a
provider named with no key set, or a `tmout` that is not a single
positive number.

## Examples

``` r
old <- Sys.getenv(c("XDG_CONFIG_HOME", "OLLAMA_HOST"), unset = NA)
Sys.setenv(XDG_CONFIG_HOME = tempfile(), OLLAMA_HOST = "off")

# no route set up: an empty vector, nothing contacted
m <- llmmdls(route = "ollama")
length(m)
#> [1] 0
attributes(m)
#> NULL

# a provider named without its key is an error
try(llmmdls(route = "anthropic"))
#> Error : no key for Anthropic: set ANTHROPIC_API_KEY, or `rmoriebricklayer config set anthropic.key` (it asks for the key)

for (v in names(old)) {
  if (is.na(old[[v]])) {
    Sys.unsetenv(v)
  } else {
    do.call(Sys.setenv, as.list(old[v]))
  }
}
if (FALSE) { # interactive()
# with a key set, the provider is asked (network)
m <- llmmdls(route = "openai", tmout = 10)
head(m)
attr(m, "default")
}
```
