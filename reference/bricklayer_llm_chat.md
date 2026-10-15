# A conversation with a language model

Sends a whole conversation (system, user and earlier assistant turns) to
the route
[`bricklayer_llm_ask`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_ask.md)
would take, and returns the model's next reply. Use it when you manage
the conversation yourself, for example to keep a multi-turn exchange or
to give the model earlier answers as context. Unlike
[`bricklayer_llm_ask()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_ask.md)
it adds nothing to the conversation (no help pages, no tools) and it
never reads or writes the saved-answer cache.

## Usage

``` r
bricklayer_llm_chat(messages, model = NULL, route = NULL, timeout = 120)
```

## Arguments

- messages:

  A non-empty list of turns, each a list with two character scalars:
  `role`, one of `"system"`, `"user"` or `"assistant"`, and `content`,
  the text of that turn. The last turn is normally a `"user"` turn.
  Other elements of a turn are dropped.

- model:

  Character scalar or `NULL` (the default): the model id to use. `NULL`
  uses the route's own choice: `MORIE_LLM_MODEL` for your own endpoint,
  `OLLAMA_MODEL` or the first pulled model for Ollama, the saved
  `PROVIDER.model` or the provider's default model (see
  [`bricklayer_llm_providers`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_providers.md)).

- route:

  Character scalar or `NULL` (the default: the saved route, else the
  first that is set up). `"auto"` uses the automatic order and ignores a
  saved route; `"own"`, `"ollama"` or a provider id insists on that one.

- timeout:

  Numeric scalar, seconds to wait for each reply; default `120`. With
  `docs = TRUE` the whole exchange gets at most three times this.

## Value

A character scalar: the text of the model's reply.

## Details

The route is resolved exactly as in
[`bricklayer_llm_route_info`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_route_info.md).
The turns are sent in the provider's own wire format (the OpenAI chat
completions format for most providers, your own endpoint and Ollama;
Anthropic's Messages API; Google's Gemini `generateContent`). One
request is made, through the package's own libcurl binding, and waits at
most `timeout` seconds.

Errors, before anything is sent: `messages` is not a non-empty list of
turns each with a single `role` among `"system"`, `"user"` and
`"assistant"` and a single non-missing character `content`;
`route = "hosted"` or an unknown route; no route is set up (the message
says what to set); the route has no model and `model` is not given.
After sending: the server cannot be reached, rejects the key (HTTP 401
or 403), or answers with an error. The key is redacted from any error
text a server echoes back.

## See also

[`bricklayer_llm_ask`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_ask.md)
for one question with the package help at hand.

## Examples

``` r
old <- Sys.getenv(c("XDG_CONFIG_HOME", "OLLAMA_HOST"), unset = NA)
Sys.setenv(XDG_CONFIG_HOME = tempfile(), OLLAMA_HOST = "off")

# a conversation is a list of role/content turns
turns <- list(
  list(role = "system", content = "Answer in one sentence."),
  list(role = "user", content = "Name one type of survey weight.")
)
str(turns)
#> List of 2
#>  $ :List of 2
#>   ..$ role   : chr "system"
#>   ..$ content: chr "Answer in one sentence."
#>  $ :List of 2
#>   ..$ role   : chr "user"
#>   ..$ content: chr "Name one type of survey weight."

# a malformed turn is refused before anything is sent
try(bricklayer_llm_chat(list("Name one type of survey weight.")))
#> Error : `messages` must be a list of list(role = "system"|"user"|"assistant", content = text)

# with no route set up the error says what to set up
try(bricklayer_llm_chat(turns, route = "ollama"))
#> Error : No language-model route is set up on this machine: bring your own key, or run a model locally:
#>   local Ollama: OLLAMA_HOST=off
#> `rmoriebricklayer config setup` walks through it.

for (v in names(old)) {
  if (is.na(old[[v]])) Sys.unsetenv(v) else do.call(Sys.setenv, as.list(old[v]))
}
if (FALSE) { # \dontrun{
# needs a key or a local model, and the network
Sys.setenv(ANTHROPIC_API_KEY = "...")
bricklayer_llm_chat(turns)
bricklayer_llm_chat(c(turns, list(
  list(role = "assistant", content = "A design weight."),
  list(role = "user", content = "And a second one?")
)))
} # }
```
