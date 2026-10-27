# Ask a language model

Sends one prompt to the first language model that is set up on this
machine and returns the reply. Bring your own key, or run a model
locally: nothing is sent anywhere you did not set up. In order:

1.  your own OpenAI-compatible endpoint, `MORIE_LLM_BASE_URL` (with
    `MORIE_LLM_API_KEY` and `MORIE_LLM_MODEL` when it needs them), e.g.
    LM Studio, vLLM, llama.cpp or a company gateway. An `https` address,
    or plain `http` to the loopback host or to a literal private LAN
    address (`10/8`, `172.16/12`, `192.168/16`, `fc00::/7`: an LM Studio
    or vLLM box on your own network); a host name over plain http is
    refused. It is not probed, so a configured endpoint that is down is
    an error, not a silent hop elsewhere;

2.  a provider whose key is set (see
    [`llmprvd`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmprvd.md)):
    OpenAI, Anthropic, Google Gemini, OpenRouter, Groq, Together,
    Fireworks, DeepSeek, Mistral, xAI, Cerebras, Perplexity, Hugging
    Face, OpenCode Zen, Cohere and NVIDIA, each through its own
    documented API with its own key variable (`ANTHROPIC_API_KEY`,
    `OPENAI_API_KEY`, ...);

3.  a local Ollama server at `OLLAMA_HOST`, by default
    `http://localhost:11434`, with the model `OLLAMA_MODEL` or the first
    one pulled; `OLLAMA_HOST=off` skips it.

[`llmstat`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmstat.md)
shows what is set up and which route a question would take.

## Usage

``` r
llmask(
  prompt,
  model = NULL,
  tmout = 120,
  syspro = NULL,
  route = NULL,
  docs = TRUE,
  pkgs = NULL,
  fresh = FALSE
)
```

## Arguments

- prompt:

  Character scalar: the question, in plain text.

- model:

  Character scalar or `NULL` (the default): the model id to use (a value
  shaped like a key is refused, never sent). `NULL` uses the route's own
  choice: `MORIE_LLM_MODEL` for your own endpoint, `OLLAMA_MODEL` or the
  first pulled model for Ollama, the saved `PROVIDER.model` or the
  provider's default model (see
  [`llmprvd`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmprvd.md)).

- tmout:

  Numeric scalar, seconds to wait for each reply; default `120`. With
  `docs = TRUE` the whole exchange gets at most three times this.

- syspro:

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

- pkgs:

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
packages named in `pkgs` (read from the help pages installed here) and
may call five read-only tools before it answers: `search_docs`,
`get_help`, `get_examples`, `list_datasets` and `get_vignette`. How much
help goes into the instructions depends on the model's context size: a
model with at least 32,000 tokens gets an index of every exported
function (name, arguments, title) and up to six rounds of lookups; 8,000
to 32,000 tokens, the 120 functions nearest the question and four
rounds; smaller, the 40 nearest and three rounds. A package with very
many pages is never listed whole: its functions nearest the question are
listed and the tools reach the rest. `"Nearest"` is a BM25 search over
the help text in R (\\k_1 = 1.2\\, \\b = 0.75\\). A model that cannot
call tools gets the best matching pages in the prompt instead. Nothing
the model asks for is run: it answers with code for you to run.

With `docs = TRUE` the whole exchange is given at most three times
`tmout`; a lookup round that would start after that is not started and
the call errors. With `docs = FALSE` one request is made with `syspro`
(when given) and `prompt`.

Saved answers: a person at a terminal (the command line with a terminal
on both stdin and stdout) or in an interactive GUI session gets a saved
answer back at once when the question (spacing aside; case counts),
route, address, model, packages and their versions, and `syspro` all
match. Answers are kept as owner-only files in the folder that
[`tools::R_user_dir()`](https://rdrr.io/r/tools/userdir.html) gives for
`"rmoriebricklayer"` and `"cache"`: for 30 days, which the option
`rmoriebricklayer.llmcachedays` changes, and at most the 200 newest,
which the option `rmoriebricklayer.llmcachemax` changes. The first save
in a session says where answers go. Nothing is saved from a script, a
pipeline, a test run, `R CMD check`, or with
`options(morie.quiet = TRUE)`. Saving is also turned off by
`MORIE_LLM_CACHE=off`, or by the option `rmoriebricklayer.llmcache` set
to `FALSE`.

Errors: `prompt` is not a single non-empty string; `fresh` or `docs` is
not `TRUE` or `FALSE`; `route = "hosted"` or an unknown route; no route
is set up (the message lists what to set); no model is chosen for the
route; `pkgs` names a package that is not installed; and, after sending,
an unreachable server, a rejected key (HTTP 401 or 403) or an error
reply. The key is redacted from any error text a server echoes back.

## See also

[`llmchat`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmchat.md)
for a conversation without the help;
[`llmstat`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmstat.md)
and
[`llmrte`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmrte.md)
to see where a question would go.

## Examples

``` r
old <- Sys.getenv(c("XDG_CONFIG_HOME", "OLLAMA_HOST"), unset = NA)
Sys.setenv(XDG_CONFIG_HOME = tempfile(), OLLAMA_HOST = "off")

# arguments are checked before any route is resolved
try(llmask(c("two", "questions")))
#> Error : llmask: `prompt` must be a single non-empty string

# a provider named explicitly without its key
try(llmask("What is a capsule?", route = "anthropic"))
#> Error : no key for Anthropic: set ANTHROPIC_API_KEY, or `rmoriebricklayer config set anthropic.key` (it asks for the key)

# no route set up: the error lists what to set up
try(llmask("What is a capsule?", route = "ollama", docs = FALSE))
#> Error : No language-model route is set up on this machine: bring your own key, or run a model locally:
#>   local Ollama: OLLAMA_HOST=off
#> `rmoriebricklayer config setup` walks through it.

for (v in names(old)) {
  if (is.na(old[[v]])) {
    Sys.unsetenv(v)
  } else {
    do.call(Sys.setenv, as.list(old[v]))
  }
}
if (FALSE) { # interactive()
# needs your own key or a local model, and the network
Sys.setenv(ANTHROPIC_API_KEY = "...")
llmask("What does a SHA-256 provenance record protect against?")
llmask("Explain an E-value of 2.1", route = "ollama")
llmask("Summarise Benford's law in two lines", docs = FALSE,
                   syspro = "You are terse.")
}
```
