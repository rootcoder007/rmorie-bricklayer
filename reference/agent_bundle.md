# Agent-assisted reproducibility-bundle help

Forwards a bundle-building request to the `rmorie` command-line agent
(optional binary from rmorie-cli), with a rmoriebricklayer-focused
preamble. The agent can run R and read/write files to help assemble or
repair a brick-proof bundle. See `rmorie::agent` for requirements.

## Usage

``` r
agent_bundle(request, model = NULL, backend = "auto")
```

## Arguments

- request:

  Character scalar describing the bundle task.

- model:

  Optional model id, e.g. `"minimax-m3:cloud"` for an Ollama server or
  `"claude-sonnet-5"` for Anthropic; defaults to `$RMORIE_AGENT_MODEL`
  or the CLI's auto-pick.

- backend:

  `"auto"` (default), `"ollama"` (server from
  `$RMORIE_AGENT_OLLAMA_URL`) or `"anthropic"`
  (`$RMORIE_AGENT_API_KEY`).

## Value

Character scalar: the agent's output, or a message if the `rmorie`
binary is not installed.

## Examples

``` r
# \donttest{
# Routed to the optional rmorie CLI agent when it is installed; with no
# binary on PATH each call returns an install hint instantly (no error,
# no network), so this is safe to execute anywhere.
agent_bundle("scaffold a bundle for analysis.R using the Toronto CKAN dataset")
#> [1] "rmorie CLI not found on PATH. Install rmorie-cli to use agent_bundle()."

# Free local/cloud route: an Ollama server (RMORIE_AGENT_OLLAMA_URL, default
# http://localhost:11434) serving the model the MORIE stack uses.
agent_bundle("add a Wayback fallback to my fetch step",
             backend = "ollama", model = "minimax-m3:cloud")
#> [1] "rmorie CLI not found on PATH. Install rmorie-cli to use agent_bundle()."

# Anthropic route (needs RMORIE_AGENT_API_KEY); the CLI's default model.
agent_bundle("repair the SHA256 provenance for my capsule",
             backend = "anthropic", model = "claude-sonnet-5")
#> [1] "rmorie CLI not found on PATH. Install rmorie-cli to use agent_bundle()."
# }

# With no rmorie binary on PATH the call returns an install hint, not an
# error -- safe to run anywhere:
if (!nzchar(Sys.which("rmorie"))) agent_bundle("hello")
#> [1] "rmorie CLI not found on PATH. Install rmorie-cli to use agent_bundle()."
```
