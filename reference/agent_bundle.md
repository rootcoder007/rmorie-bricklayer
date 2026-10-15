# Agent-assisted reproducibility-bundle help

Asks a language model to plan a brick-proof, reproducible data bundle,
through
[`bricklayer_llm_ask`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_ask.md):
your own key, your own endpoint or a local Ollama server, with the
packages' help at hand (the model reads the help pages of the functions
it proposes before it answers). Use it to get a first draft of the steps
and R code for packaging an analysis: finding the portal's download URL,
fetching with a Wayback fallback, recording hashes and a manifest,
writing a synthetic stand-in, then packaging, signing and verifying the
bundle.

## Usage

``` r
agent_bundle(request, model = NULL, route = NULL)
```

## Arguments

- request:

  Character scalar describing the bundle task.

- model:

  Optional model id, a string; `NULL` uses the route's model
  (`rmbl models` lists them).

- route:

  `NULL` (the saved route, else the first that is set up), `"auto"`,
  `"own"`, `"ollama"` or a provider id such as `"anthropic"` or
  `"openai"`.

## Value

Character scalar: the answer, or a message saying what to set up when no
route answers.

## Details

The request is sent with a fixed system prompt that describes that task
and asks for a short plan and R code. The route is chosen as in
[`bricklayer_llm_ask()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_ask.md);
when no route is set up, the function returns a message saying what to
set up (a provider key, a local Ollama or your own endpoint) instead of
an error, and makes no network request. When a route is set up, the
request and the prompt are sent to that provider or server. The answer
is model output: check the code it proposes against the help pages
before running it.

Errors: `request` not a single non-empty string; `route` not one of the
names listed; `route = "hosted"` (the hosted tier is retired); and
errors raised by
[`bricklayer_llm_ask()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_ask.md).

## Examples

``` r
if (FALSE) { # \dontrun{
# Needs a language model: a provider key (e.g. ANTHROPIC_API_KEY), your own
# endpoint or a local Ollama.
agent_bundle("scaffold a bundle for analysis.R from the Toronto CKAN data")
agent_bundle("sign and verify my capsule", route = "ollama")
} # }

# With every route switched off the call returns a setup hint, not an
# error, and reaches no network -- safe to run anywhere:
keys <- c("OLLAMA_HOST", "MORIE_LLM_BASE_URL", bricklayer_llm_providers()$key_env,
          bricklayer_llm_providers()$alt_env[nzchar(bricklayer_llm_providers()$alt_env)])
old <- Sys.getenv(keys, unset = NA)
Sys.setenv(OLLAMA_HOST = "off", MORIE_LLM_BASE_URL = "off")
Sys.unsetenv(setdiff(keys, c("OLLAMA_HOST", "MORIE_LLM_BASE_URL")))
cat(agent_bundle("hello"))
#> No language-model route is set up on this machine: bring your own key, or run a model locally:
#>   a provider's key: set its variable (OPENAI_API_KEY, ANTHROPIC_API_KEY, GEMINI_API_KEY, OPENROUTER_API_KEY, ...) or `rmoriebricklayer config set PROVIDER.key`; providers: openai, anthropic, gemini, openrouter, groq, together, fireworks, deepseek, mistral, xai, cerebras, perplexity, huggingface, opencode, cohere, nvidia
#>   local Ollama: OLLAMA_HOST=off
#>   own endpoint: `rmoriebricklayer config set own.url URL` (and own.model, own.key) for any OpenAI-compatible server (LM Studio, vLLM, llama.cpp, a company gateway)
#> `rmoriebricklayer config setup` walks through it.
for (v in keys) {
  if (is.na(old[[v]])) Sys.unsetenv(v) else do.call(Sys.setenv, as.list(old[v]))
}

# argument errors come first
try(agent_bundle(""))
#> Error : `request` must be a single non-empty string
try(agent_bundle("plan a bundle", route = "hosted"))
#> Error : the hosted MORIE language-model tier is retired: bring your own key (a provider's variable such as ANTHROPIC_API_KEY or OPENAI_API_KEY, or `rmoriebricklayer config set <provider>.key`) or run a model locally (Ollama); `rmoriebricklayer config setup` walks through it
```
