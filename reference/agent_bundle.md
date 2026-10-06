# Agent-assisted reproducibility-bundle help

Sends a bundle-building request, with a rmoriebricklayer-focused
preamble, to the first language-model route that answers (your own
endpoint, a local Ollama server, then the hosted MORIE tier; see
[`bricklayer_llm_ask`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_ask.md)).

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

  `"auto"` (default): the first route that answers; `"hosted"`: the
  hosted MORIE tier only.

## Value

Character scalar: the answer, or a message saying what to set up when no
route answers.

## Examples

``` r
# \donttest{
agent_bundle("scaffold a bundle for analysis.R from the Toronto CKAN data")
#> [1] "No language-model route is set up on this machine:\n  own endpoint: set MORIE_LLM_BASE_URL (and MORIE_LLM_API_KEY, MORIE_LLM_MODEL) to any OpenAI-compatible server\n  local Ollama: nothing answers at http://localhost:11434 (install Ollama and pull a model, or point OLLAMA_HOST at a server)\n  hosted MORIE tier: no key stored; request a key at https://rmorie.com/access, then `rmoriebricklayer login --token KEY` (R: bricklayer_llm_login(token = )); `rmoriebricklayer login` signs in with GitHub or an emailed code"
agent_bundle("add a Wayback fallback to my fetch step", model = "minimax-m3:cloud")
#> [1] "No language-model route is set up on this machine:\n  own endpoint: set MORIE_LLM_BASE_URL (and MORIE_LLM_API_KEY, MORIE_LLM_MODEL) to any OpenAI-compatible server\n  local Ollama: nothing answers at http://localhost:11434 (install Ollama and pull a model, or point OLLAMA_HOST at a server)\n  hosted MORIE tier: no key stored; request a key at https://rmorie.com/access, then `rmoriebricklayer login --token KEY` (R: bricklayer_llm_login(token = )); `rmoriebricklayer login` signs in with GitHub or an emailed code"
# }

# With every route switched off the call returns a setup hint, not an
# error, and reaches no network -- safe to run anywhere:
routes <- c("MORIE_HOSTED_BASE_URL", "OLLAMA_HOST", "MORIE_LLM_BASE_URL")
old <- Sys.getenv(routes, unset = NA)
Sys.setenv(MORIE_HOSTED_BASE_URL = "off", OLLAMA_HOST = "off",
           MORIE_LLM_BASE_URL = "off")
agent_bundle("hello")
#> [1] "No language-model route is set up on this machine:\n  own endpoint: set MORIE_LLM_BASE_URL (and MORIE_LLM_API_KEY, MORIE_LLM_MODEL) to any OpenAI-compatible server\n  local Ollama: OLLAMA_HOST=off\n  hosted MORIE tier: disabled (MORIE_HOSTED_BASE_URL=off); request a key at https://rmorie.com/access, then `rmoriebricklayer login --token KEY` (R: bricklayer_llm_login(token = )); `rmoriebricklayer login` signs in with GitHub or an emailed code"
for (v in routes) {
  if (is.na(old[[v]])) Sys.unsetenv(v) else do.call(Sys.setenv, as.list(old[v]))
}
```
