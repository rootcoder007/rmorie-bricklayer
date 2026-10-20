# The language-model route that would answer

Reports which route
[`llmask`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmask.md)
and
[`llmchat`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmchat.md)
would take right now, without sending a prompt anywhere. Use it to
check, before asking a question, that the question would go to the
server you expect (your own endpoint, a provider whose key is set, or a
local Ollama server) and which model it would use.

## Usage

``` r
llmrte(route = NULL)
```

## Arguments

- route:

  Character scalar or `NULL` (the default). `NULL` uses the saved route,
  else the automatic order; `"auto"` uses the automatic order and
  ignores a saved route; `"own"`, `"ollama"` or a provider id from the
  `id` column of
  [`llmprvd`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmprvd.md)
  (such as `"anthropic"`) asks about that one route only.

## Value

`NULL` when no route is set up (or the named one is not available), else
a list of four elements: `route` (character, the id that `route =`
takes: `"own"`, `"ollama"` or a provider id), `name` (character, a
readable label such as `"own endpoint"`, `"local Ollama"` or
`"Anthropic"`), `model` (character, or `NULL` when no model is chosen)
and `base` (character, the base address requests go to, without a
trailing `/v1` for your own endpoint).

## Details

The automatic order is: an OpenAI-compatible endpoint of your own
(`MORIE_LLM_BASE_URL`, or `own.url` saved with
`rmoriebricklayer config set`); then every provider of
[`llmprvd`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmprvd.md)
whose key is set, in the order of that table; then a local Ollama
server, at `OLLAMA_HOST` or by default at `http://localhost:11434`, when
it answers with at least one pulled model or `OLLAMA_MODEL` is set. A
saved route replaces the automatic order when `route = NULL`; it comes
from `MORIE_LLM_ROUTE` or from the `route` saved in the settings file.

Nothing is sent to a provider. The only network contact is the Ollama
probe, a `GET /api/tags` to the Ollama address with a 2 second timeout;
`OLLAMA_HOST=off` skips it. Your own endpoint is not probed.

Errors: `route = "hosted"` (the hosted MORIE tier is retired); a `route`
that is not one of the accepted names; a provider route named explicitly
with no key set; a `MORIE_LLM_BASE_URL` that is not `https` to a public
address or plain `http` to the loopback host or a literal private LAN
address. When automatic resolution skips a route that is half set up (a
model or key without an address, an Ollama that does not answer) a
message says so.

## See also

[`llmstat`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmstat.md)
for every route at once,
[`llmprvd`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmprvd.md)
for the provider ids.

## Examples

``` r
# keep the examples away from your real settings and from the network
old <- Sys.getenv(c("XDG_CONFIG_HOME", "OLLAMA_HOST",
                    "MORIE_LLM_BASE_URL", "MORIE_LLM_MODEL"),
                  unset = NA)
Sys.setenv(XDG_CONFIG_HOME = tempfile(), OLLAMA_HOST = "off")

# Ollama switched off: that route is not available
llmrte("ollama")
#> NULL

# an OpenAI-compatible server of your own on this machine (not contacted here)
Sys.setenv(MORIE_LLM_BASE_URL = "http://localhost:8080/v1", MORIE_LLM_MODEL = "llama3")
str(llmrte())
#> List of 4
#>  $ route: chr "own"
#>  $ name : chr "own endpoint"
#>  $ model: chr "llama3"
#>  $ base : chr "http://localhost:8080"

# the retired hosted tier, and a route name that does not exist
try(llmrte("hosted"))
#> Error : the hosted MORIE language-model tier is retired: bring your own key (a provider's variable such as ANTHROPIC_API_KEY or OPENAI_API_KEY, or `rmoriebricklayer config set <provider>.key`) or run a model locally (Ollama); `rmoriebricklayer config setup` walks through it
try(llmrte("nope"))
#> Error : llmrte: `route` must be one of "auto", "own", "openai", "anthropic", "gemini", "openrouter", "groq", "together", "fireworks", "deepseek", "mistral", "xai", "cerebras", "perplexity", "huggingface", "opencode", "cohere", "nvidia", "ollama", not "nope"

for (v in names(old)) {
  if (is.na(old[[v]])) Sys.unsetenv(v) else do.call(Sys.setenv, as.list(old[v]))
}
```
