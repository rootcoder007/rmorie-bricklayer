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

  Optional model id (see `rmorie::agent`).

- backend:

  Optional backend override (see `rmorie::agent`).

## Value

Character scalar: the agent's output, or a message if the `rmorie`
binary is not installed.

## Examples

``` r
if (FALSE) { # \dontrun{
# Plain request -> routed to the rmorie CLI agent (auto backend).
agent_bundle("scaffold a bundle for analysis.R using the Toronto CKAN dataset")

# Pin a model, or force a backend (see rmorie::agent for the values).
agent_bundle("repair the SHA256 provenance for my capsule",
             model = "gpt-4o-mini")
agent_bundle("add a Wayback fallback to my fetch step", backend = "ollama")
} # }

# With no rmorie binary on PATH the call returns an install hint, not an
# error -- safe to run anywhere:
if (!nzchar(Sys.which("rmorie"))) agent_bundle("hello")
#> [1] "rmorie CLI not found on PATH. Install rmorie-cli to use agent_bundle()."
```
