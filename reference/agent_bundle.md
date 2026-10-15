# Agent-assisted reproducibility-bundle help

Asks a language model to plan a brick-proof, reproducible data bundle,
through
[`bricklayer_llm_ask`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_ask.md):
your own key, your own endpoint or a local Ollama server, with the
packages' help at hand (the model reads the help pages of the functions
it proposes before it answers).

## Usage

``` r
agent_bundle(request, model = NULL, route = NULL)
```

## Arguments

- request:

  Character scalar describing the bundle task.

- model:

  Optional model id; `NULL` uses the route's model (`rmbl models` lists
  them).

- route:

  `NULL` (the saved route, else the first that is set up), `"auto"`,
  `"own"`, `"ollama"` or a provider id.

## Value

Character scalar: the answer, or a message saying what to set up when no
route answers.

## Examples

``` r
# \donttest{
# Needs a language model: a provider key (e.g. ANTHROPIC_API_KEY), your own
# endpoint or a local Ollama. try() keeps the example graceful when none answers.
try(agent_bundle("scaffold a bundle for analysis.R from the Toronto CKAN data"))
#> [1] "No language-model route is set up on this machine: bring your own key, or run a model locally:\n  a provider's key: set its variable (OPENAI_API_KEY, ANTHROPIC_API_KEY, GEMINI_API_KEY, OPENROUTER_API_KEY, ...) or `rmoriebricklayer config set PROVIDER.key`; providers: openai, anthropic, gemini, openrouter, groq, together, fireworks, deepseek, mistral, xai, cerebras, perplexity, huggingface, opencode, cohere, nvidia\n  local Ollama: nothing answers at http://localhost:11434 (installed? start its server with `ollama serve`, or open the Ollama app; not installed: https://ollama.com, then `ollama pull NAME`; on another machine: `rmoriebricklayer config set ollama.url ADDRESS`)\n  own endpoint: `rmoriebricklayer config set own.url URL` (and own.model, own.key) for any OpenAI-compatible server (LM Studio, vLLM, llama.cpp, a company gateway)\n`rmoriebricklayer config setup` walks through it."
# }

# With every route switched off the call returns a setup hint, not an
# error, and reaches no network -- safe to run anywhere:
keys <- c("OLLAMA_HOST", "MORIE_LLM_BASE_URL", bricklayer_llm_providers()$key_env,
          bricklayer_llm_providers()$alt_env[nzchar(bricklayer_llm_providers()$alt_env)])
old <- Sys.getenv(keys, unset = NA)
Sys.setenv(OLLAMA_HOST = "off", MORIE_LLM_BASE_URL = "off")
Sys.unsetenv(setdiff(keys, c("OLLAMA_HOST", "MORIE_LLM_BASE_URL")))
agent_bundle("hello")
#> [1] "No language-model route is set up on this machine: bring your own key, or run a model locally:\n  a provider's key: set its variable (OPENAI_API_KEY, ANTHROPIC_API_KEY, GEMINI_API_KEY, OPENROUTER_API_KEY, ...) or `rmoriebricklayer config set PROVIDER.key`; providers: openai, anthropic, gemini, openrouter, groq, together, fireworks, deepseek, mistral, xai, cerebras, perplexity, huggingface, opencode, cohere, nvidia\n  local Ollama: OLLAMA_HOST=off\n  own endpoint: `rmoriebricklayer config set own.url URL` (and own.model, own.key) for any OpenAI-compatible server (LM Studio, vLLM, llama.cpp, a company gateway)\n`rmoriebricklayer config setup` walks through it."
for (v in keys) {
  if (is.na(old[[v]])) Sys.unsetenv(v) else do.call(Sys.setenv, as.list(old[v]))
}
```
