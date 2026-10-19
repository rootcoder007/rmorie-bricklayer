# Report the language-model routes available from this machine

Shows, in one table, every way
[`llmask`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmask.md)
could reach a language model from this machine and whether each is
ready: your own endpoint, each provider whose key is set, and a local
Ollama server. Use it to find out why a question fails with "no route",
or which model a route would use. The command line prints it as part of
`rmoriebricklayer doctor`.

## Usage

``` r
llmstat()
```

## Value

A data frame with one row per route and three character columns: `route`
(`"own endpoint"`, a provider label such as `"Anthropic"`,
`"other providers"` or `"local Ollama"`), `status` (`"not set"` or
`"configured"` for your own endpoint; `"key set"` for a provider;
`"no key"` for the shared row; `"disabled"`, `"not running"`,
`"no models"` or `"available"` for Ollama) and `detail` (the address and
model, or what to set up).

## Details

Rows come in the order
[`llmask()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmask.md)
tries the routes. The providers without a key share one row that names
each one with its key variable. Key values are never shown. Nothing is
sent to a provider; the only network contact is a `GET /api/tags` to the
Ollama address (`OLLAMA_HOST`, default `http://localhost:11434`; 2
second timeout) unless `OLLAMA_HOST=off`.

A settings file (`llm.json` next to the credentials file) that cannot be
read does not make the call fail: the result is then a single row with
`route = "settings"` and `status = "unreadable"`, with the reason and
the command that moves the file aside.

## See also

[`llmrte`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmrte.md)
for the one route a question would take;
[`llmprvd`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmprvd.md).

## Examples

``` r
old <- Sys.getenv(c("XDG_CONFIG_HOME", "OLLAMA_HOST",
                    "MORIE_LLM_BASE_URL", "MORIE_LLM_MODEL"),
                  unset = NA)
# a scratch settings folder and the local route off: no network at all
Sys.setenv(XDG_CONFIG_HOME = tempfile(), OLLAMA_HOST = "off")
st <- llmstat()
st[, c("route", "status")]
#>             route   status
#> 1    own endpoint  not set
#> 2 other providers   no key
#> 3    local Ollama disabled

# your own OpenAI-compatible server shows as configured (it is not contacted)
Sys.setenv(MORIE_LLM_BASE_URL = "http://localhost:8080", MORIE_LLM_MODEL = "llama3")
llmstat()[1, ]
#>          route     status                               detail
#> 1 own endpoint configured http://localhost:8080  model: llama3

for (v in names(old)) {
  if (is.na(old[[v]])) Sys.unsetenv(v) else do.call(Sys.setenv, as.list(old[v]))
}
```
