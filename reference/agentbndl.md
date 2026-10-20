# Agent-assisted reproducibility-bundle help

Asks a language model to plan a brick-proof, reproducible data bundle,
through
[`llmask`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmask.md):
your own key, your own endpoint or a local Ollama server, with the
packages' help at hand (the model reads the help pages of the functions
it proposes before it answers). Use it to get a first draft of the steps
and R code for packaging an analysis: finding the portal's download URL,
fetching with a Wayback fallback, recording hashes and a manifest,
writing a synthetic stand-in, then packaging, signing and verifying the
bundle.

## Usage

``` r
agentbndl(req, model = NULL, route = NULL)
```

## Arguments

- req:

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
[`llmask()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmask.md);
when no route is set up, the function returns a message saying what to
set up (a provider key, a local Ollama or your own endpoint) instead of
an error, and makes no network request. When a route is set up, the
request and the prompt are sent to that provider or server. The answer
is model output: check the code it proposes against the help pages
before running it.

Errors: `req` not a single non-empty string; `route` not one of the
names listed; `route = "hosted"` (the hosted tier is retired); and
errors raised by
[`llmask()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmask.md).

## Examples

``` r
if (FALSE) { # interactive()
# Needs a language model: a provider key (e.g. ANTHROPIC_API_KEY), your own
# endpoint or a local Ollama.
agentbndl("scaffold a bundle for analysis.R from the Toronto CKAN data")
agentbndl("sign and verify my capsule", route = "ollama")
}

# With every route switched off (no key in the environment and no saved
# settings: the settings folder is pointed at an empty one) the call returns
# a setup hint, not an error, and reaches no network -- safe to run anywhere:
keys <- c("OLLAMA_HOST", "MORIE_LLM_BASE_URL", "XDG_CONFIG_HOME",
          llmprvd()$key_env,
          llmprvd()$alt_env[nzchar(llmprvd()$alt_env)])
old <- Sys.getenv(keys, unset = NA)
Sys.setenv(OLLAMA_HOST = "off", MORIE_LLM_BASE_URL = "off", XDG_CONFIG_HOME = tempfile())
Sys.unsetenv(setdiff(keys, c("OLLAMA_HOST", "MORIE_LLM_BASE_URL", "XDG_CONFIG_HOME")))
cat(agentbndl("hello"))
#> No language-model route is set up on this machine: bring your own key, or run a model locally:
#>   a provider's key: set its variable (OPENAI_API_KEY, ANTHROPIC_API_KEY, GEMINI_API_KEY, OPENROUTER_API_KEY, ...) or `rmoriebricklayer config set PROVIDER.key`; providers: openai, anthropic, gemini, openrouter, groq, together, fireworks, deepseek, mistral, xai, cerebras, perplexity, huggingface, opencode, cohere, nvidia
#>   local Ollama: OLLAMA_HOST=off
#>   own endpoint: `rmoriebricklayer config set own.url URL` (and own.model, own.key) for any OpenAI-compatible server (LM Studio, vLLM, llama.cpp, a company gateway)
#> `rmoriebricklayer config setup` walks through it.
for (v in keys) {
  if (is.na(old[[v]])) Sys.unsetenv(v) else do.call(Sys.setenv, as.list(old[v]))
}

# argument errors come first
try(agentbndl(""))
#> Error : agentbndl: `req` must be a single non-empty string
try(agentbndl("plan a bundle", route = "hosted"))
#> Error : the hosted MORIE language-model tier is retired: bring your own key (a provider's variable such as ANTHROPIC_API_KEY or OPENAI_API_KEY, or `rmoriebricklayer config set <provider>.key`) or run a model locally (Ollama); `rmoriebricklayer config setup` walks through it
```
