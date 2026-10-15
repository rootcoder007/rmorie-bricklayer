# Ask a language model

Sends one prompt to the first language model that is set up on this
machine and returns the reply. Bring your own key, or run a model
locally: nothing is sent anywhere you did not set up. In order:

1.  an OpenAI-compatible endpoint of your own: `MORIE_LLM_BASE_URL`
    (with `MORIE_LLM_API_KEY` and `MORIE_LLM_MODEL` when it needs them),
    e.g. LM Studio, vLLM, llama.cpp or a company gateway. An `https`
    address, or plain `http` to the loopback host or to a literal
    private LAN address (`10/8`, `172.16/12`, `192.168/16`, `fc00::/7`:
    an LM Studio or vLLM box on your own network); a host name over
    plain http is refused. It is not probed, so a configured endpoint
    that is down is an error, not a silent hop elsewhere;

2.  a provider whose key is set (see
    [`bricklayer_llm_providers`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_providers.md)):
    OpenAI, Anthropic, Google Gemini, OpenRouter, Groq, Together,
    Fireworks, DeepSeek, Mistral, xAI, Cerebras, Perplexity, Hugging
    Face, OpenCode Zen, Cohere and NVIDIA, each through its own
    documented API with its own key variable (`ANTHROPIC_API_KEY`,
    `OPENAI_API_KEY`, ...);

3.  a local Ollama server: `OLLAMA_HOST` (default
    `http://localhost:11434`), model `OLLAMA_MODEL` or the first one
    pulled; `OLLAMA_HOST=off` skips it.

[`bricklayer_llm_status`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_status.md)
shows what is set up and which route a question would take.

## Usage

``` r
bricklayer_llm_ask(
  prompt,
  model = NULL,
  timeout = 120,
  system_prompt = NULL,
  route = NULL,
  docs = TRUE,
  packages = NULL,
  fresh = FALSE
)
```

## Arguments

- prompt:

  Character scalar: the question, in plain text.

- model:

  Character scalar or `NULL` (the default): the model id to use. `NULL`
  uses the route's own choice: `MORIE_LLM_MODEL` for your own endpoint,
  `OLLAMA_MODEL` or the first pulled model for Ollama, the saved
  `PROVIDER.model` or the provider's default model (see
  [`bricklayer_llm_providers`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_providers.md)).

- timeout:

  Numeric scalar, seconds to wait for each reply; default `120`. With
  `docs = TRUE` the whole exchange gets at most three times this.

- system_prompt:

  Character scalar or `NULL` (the default): extra instructions sent as
  the system message (added to the package's own instructions when
  `docs = TRUE`).

- route:

  Character scalar or `NULL` (the default: the saved route, else the
  first that is set up). `"auto"` uses the automatic order and ignores a
  saved route; `"own"`, `"ollama"` or a provider id insists on that one.

- docs:

  Logical scalar, default `TRUE`: give the model the packages' help and
  the lookup tools (see Details). `FALSE` sends the prompt alone.

- packages:

  Character vector or `NULL` (the default): the installed packages whose
  help the model gets. `NULL` means `"rmoriebricklayer"`, or the
  comma-separated list in the environment variable `RMBL_PACKAGES`
  (which a package built on this one sets for its own command line).
  Ignored when `docs = FALSE`.

- fresh:

  Logical scalar, default `FALSE`. `TRUE` asks the model even when a
  saved answer matches (see Details), and saves the new answer in its
  place.

## Value

A character scalar with the reply. A saved answer carries the time it
was saved as attribute `cached`.

## Details

With `docs = TRUE` (the default) the model is given the help of the
packages named in `packages` (read from the help pages installed here)
and may call five read-only tools before it answers: `search_docs`,
`get_help`, `get_examples`, `list_datasets` and `get_vignette`. How much
help goes into the instructions depends on the model's context size: a
model with at least 32,000 tokens gets an index of every exported
function (name, arguments, title) and up to six rounds of lookups; 8,000
to 32,000 tokens, the 120 functions nearest the question and four
rounds; smaller, the 40 nearest and three rounds. A package with very
many pages is never listed whole: its functions nearest the question are
listed and the tools reach the rest. "Nearest" is a BM25 search over the
help text in R (\\k_1 = 1.2\\, \\b = 0.75\\). A model that cannot call
tools gets the best matching pages in the prompt instead. Nothing the
model asks for is run: it answers with code for you to run.

With `docs = TRUE` the whole exchange is given at most three times
`timeout`; a lookup round that would start after that is not started and
the call errors. With `docs = FALSE` one request is made with
`system_prompt` (when given) and `prompt`.

Saved answers: a person at a terminal (the command line with a terminal
on both stdin and stdout) or in an interactive GUI session gets a saved
answer back at once when the question (spacing aside; case counts),
route, address, model, packages and their versions, and `system_prompt`
all match. Answers are kept 30 days
(`options(rmoriebricklayer.llm_cache_days)`), at most the 200 newest
(`options(rmoriebricklayer.llm_cache_max)`), as owner-only files under
`tools::R_user_dir("rmoriebricklayer", "cache")`. The first save in a
session says where answers go. Nothing is saved from a script, a
pipeline, a test run, `R CMD check`, or with
`options(morie.quiet = TRUE)`; `MORIE_LLM_CACHE=off` or
`options(rmoriebricklayer.llm_cache = FALSE)` turns saving off.

Errors: `prompt` is not a single non-empty string; `fresh` or `docs` is
not `TRUE` or `FALSE`; `route = "hosted"` or an unknown route; no route
is set up (the message lists what to set); no model is chosen for the
route; `packages` names a package that is not installed; and, after
sending, an unreachable server, a rejected key (HTTP 401 or 403) or an
error reply. The key is redacted from any error text a server echoes
back.

## See also

[`bricklayer_llm_chat`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_chat.md)
for a conversation without the help;
[`bricklayer_llm_status`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_status.md)
and
[`bricklayer_llm_route_info`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_route_info.md)
to see where a question would go.

## Examples

``` r
old <- Sys.getenv(c("XDG_CONFIG_HOME", "OLLAMA_HOST"), unset = NA)
Sys.setenv(XDG_CONFIG_HOME = tempfile(), OLLAMA_HOST = "off")

# arguments are checked before any route is resolved
try(bricklayer_llm_ask(c("two", "questions")))
#> Error : `prompt` must be a single non-empty string

# a provider named explicitly without its key
try(bricklayer_llm_ask("What is a capsule?", route = "anthropic"))
#> Error : no key for Anthropic: set ANTHROPIC_API_KEY, or `rmoriebricklayer config set anthropic.key` (it asks for the key)

# no route set up: the error lists what to set up
try(bricklayer_llm_ask("What is a capsule?", route = "ollama", docs = FALSE))
#> Error : No language-model route is set up on this machine: bring your own key, or run a model locally:
#>   local Ollama: OLLAMA_HOST=off
#> `rmoriebricklayer config setup` walks through it.

for (v in names(old)) {
  if (is.na(old[[v]])) Sys.unsetenv(v) else do.call(Sys.setenv, as.list(old[v]))
}
if (FALSE) { # \dontrun{
# needs your own key or a local model, and the network
Sys.setenv(ANTHROPIC_API_KEY = "...")
bricklayer_llm_ask("What does a SHA-256 provenance record protect against?")
bricklayer_llm_ask("Explain an E-value of 2.1", route = "ollama")
bricklayer_llm_ask("Summarise Benford's law in two lines", docs = FALSE,
                   system_prompt = "You are terse.")
} # }
```
