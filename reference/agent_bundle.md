# Agent-assisted reproducibility-bundle help

Sends a bundle-building request, with a rmoriebricklayer-focused
preamble, to a language model: the hosted MORIE tier at
<https://llm.rmorie.com> when a key is stored
([`bricklayer_llm_login`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_login.md)),
otherwise the optional `rmorie` command-line agent from rmorie-cli if it
is on the PATH.

## Usage

``` r
agent_bundle(request, model = NULL, backend = "auto")
```

## Arguments

- request:

  Character scalar describing the bundle task.

- model:

  Optional model id, e.g. `"minimax-m3:cloud"` for the hosted tier,
  `"claude-sonnet-5"` for the Anthropic route of the CLI agent; `NULL`
  lets the route pick.

- backend:

  `"auto"` (default: hosted tier, then the CLI agent), `"hosted"` (only
  the hosted tier), `"ollama"` or `"anthropic"` (only the CLI agent,
  with its `$RMORIE_AGENT_OLLAMA_URL` / `$RMORIE_AGENT_API_KEY`).

## Value

Character scalar: the answer, or a message saying what to set up when no
route is available.

## Examples

``` r
# \donttest{
agent_bundle("scaffold a bundle for analysis.R from the Toronto CKAN data")
#> [1] "No language-model route is set up. Sign in to the hosted MORIE tier with bricklayer_llm_login() (key from https://llm.rmorie.com), or put the rmorie-cli agent on the PATH."
agent_bundle("add a Wayback fallback to my fetch step", backend = "hosted")
#> [1] "No key for the hosted MORIE LLM tier: bricklayer_llm_login() (GitHub, an emailed code, or a key from https://llm.rmorie.com), or `rmoriebricklayer login` from the shell."
agent_bundle("repair the SHA256 provenance for my capsule",
             backend = "anthropic", model = "claude-sonnet-5")
#> [1] "No language-model route is set up. Sign in to the hosted MORIE tier with bricklayer_llm_login() (key from https://llm.rmorie.com), or put the rmorie-cli agent on the PATH."
# }

# With no route configured the call returns a setup hint, not an
# error -- safe to run anywhere:
if (!nzchar(Sys.getenv("MORIE_HOSTED_KEY"))) agent_bundle("hello")
#> [1] "No language-model route is set up. Sign in to the hosted MORIE tier with bricklayer_llm_login() (key from https://llm.rmorie.com), or put the rmorie-cli agent on the PATH."
```
