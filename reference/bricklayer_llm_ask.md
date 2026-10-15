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

  Character scalar.

- model:

  Model id; default the route's own (see above).

- timeout:

  Seconds to wait for the reply.

- system_prompt:

  Optional system message.

- route:

  `NULL` (the saved route, else the first that is set up), `"auto"` (the
  automatic order this time, ignoring a saved route), or `"own"`,
  `"ollama"` or a provider id to insist on one.

- docs:

  Give the model the packages' help (see Details); `FALSE` sends the
  prompt alone.

- packages:

  The installed packages whose help the model gets; default
  rmoriebricklayer (or the comma-separated list in `RMBL_PACKAGES`,
  which a package built on this one sets for its own command line).

- fresh:

  `TRUE` asks the model even when an answer to the same question is
  saved on this machine, and keeps the new one. A person at a terminal
  (the command line with the terminal on stdin and stdout) or in an
  interactive session gets a saved answer back at once when the question
  (spacing aside; case counts), route, model, packages and their
  versions all match, for 30 days; the first save in a session says so.
  The answers are owner-only files under
  `tools::R_user_dir("rmoriebricklayer", "cache")`, nothing is kept
  elsewhere, nothing is kept from a script or a pipeline, and
  `MORIE_LLM_CACHE=off` (or
  `options(rmoriebricklayer.llm_cache = FALSE)`) turns it off.

## Value

Character scalar with the reply; a saved answer carries the time it was
saved as attribute `cached`. Errors, saying what to set up, when no
route answers, and when the server answers with an error.

## Details

With `docs = TRUE` (the default) the model knows the packages: its
instructions carry an index of every exported function of the packages
(`packages`; name, arguments, title, read from the help pages installed
here), and it may call five read-only tools to search the help, read a
page or its examples, list the datasets and read a vignette before it
answers. A model that cannot call tools gets the help pages that best
match the question (a BM25 search in R) instead. Nothing the model asks
for is run: it answers with code for you to run.

## Examples

``` r
if (FALSE) { # \dontrun{
Sys.setenv(ANTHROPIC_API_KEY = "...")   # your own key
bricklayer_llm_ask("What does a SHA-256 provenance record protect against?")
bricklayer_llm_ask("Explain an E-value of 2.1", route = "ollama")
} # }
```
