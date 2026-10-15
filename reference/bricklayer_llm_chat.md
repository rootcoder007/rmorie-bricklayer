# A conversation with a language model

Sends a whole conversation (system, user and assistant turns) to the
route
[`bricklayer_llm_ask`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_ask.md)
would take, and returns the reply. Unlike
[`bricklayer_llm_ask()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_ask.md)
it adds nothing to the conversation: no help pages, no tools.

## Usage

``` r
bricklayer_llm_chat(messages, model = NULL, route = NULL, timeout = 120)
```

## Arguments

- messages:

  A list of turns, each `list(role = , content = )` with role
  `"system"`, `"user"` or `"assistant"`.

- model:

  Model id; default the route's own (see above).

- route:

  `NULL` (the saved route, else the first that is set up), `"auto"` (the
  automatic order this time, ignoring a saved route), or `"own"`,
  `"ollama"` or a provider id to insist on one.

- timeout:

  Seconds to wait for the reply.

## Value

The reply text.

## Examples

``` r
if (FALSE) { # \dontrun{
bricklayer_llm_chat(list(list(role = "user", content = "Name one survey weight type.")))
} # }
```
