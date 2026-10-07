# Ask a language model

Sends one prompt to the first language-model route that is set up on
this machine and returns the reply. An endpoint of your own counts as
set up when it is configured (it is not probed: a configured endpoint
that is down is an error, not a silent hop to the hosted tier); a local
Ollama counts when it answers; the hosted tier when a key is stored.
Routes, in order:

1.  an OpenAI-compatible endpoint of your own: `MORIE_LLM_BASE_URL`,
    with `MORIE_LLM_API_KEY` and `MORIE_LLM_MODEL` when it needs them.
    An `https` address, or plain `http` to the loopback host or to a
    literal private LAN address (`10/8`, `172.16/12`, `192.168/16`,
    `fc00::/7`: an LM Studio or vLLM box on your own network); a host
    name over plain http is refused;

2.  a local Ollama server: `OLLAMA_HOST` (or `OLLAMA_BASE_URL`), default
    `http://localhost:11434`, model `OLLAMA_MODEL` or the first one the
    server lists; `OLLAMA_HOST=off` skips it;

3.  the hosted MORIE tier, a last resort for people who can run neither:
    its address comes from
    [`bricklayer_services`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_services.md)
    and it needs the key stored by
    [`bricklayer_llm_login`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_login.md)
    (or `MORIE_HOSTED_KEY`). Keys are personal and issued on request at
    <https://rmorie.com/access/>.

[`bricklayer_llm_status`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_status.md)
shows which route a question would take.

## Usage

``` r
bricklayer_llm_ask(
  prompt,
  model = NULL,
  timeout = 120,
  system_prompt = NULL,
  route = NULL
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

  `NULL` (the first that is set up) or one of `"own"`, `"ollama"`,
  `"hosted"` to insist on a route.

## Value

Character scalar with the reply. Errors, saying what to set up, when no
route answers, and when the server answers with an error.

## Examples

``` r
if (FALSE) { # \dontrun{
bricklayer_llm_ask("What does a SHA-256 provenance record protect against?")
bricklayer_llm_ask("Explain an E-value of 2.1", route = "ollama")
} # }
```
