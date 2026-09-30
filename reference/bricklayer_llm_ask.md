# Ask the hosted MORIE language model

Sends one prompt to the MORIE LLM tier at <https://llm.rmorie.com> with
the key stored by
[`bricklayer_llm_login`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_login.md)
(or `MORIE_HOSTED_KEY`) and returns the reply.

## Usage

``` r
bricklayer_llm_ask(prompt, model = NULL, timeout = 120, system_prompt = NULL)
```

## Arguments

- prompt:

  Character scalar.

- model:

  Model id; default `MORIE_HOSTED_MODEL` or `"minimax-m3:cloud"`.

- timeout:

  Seconds to wait for the reply.

- system_prompt:

  Optional system message.

## Value

Character scalar with the reply. Errors when no key is stored, the tier
is disabled (`MORIE_HOSTED_BASE_URL=off`) or the gateway answers with an
error.

## Examples

``` r
if (FALSE) { # \dontrun{
bricklayer_llm_login(email = "you@example.com")
bricklayer_llm_ask("What does a SHA-256 provenance record protect against?")
} # }
```
