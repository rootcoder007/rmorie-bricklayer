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
agent_bundle("scaffold a bundle for analysis.R using the Toronto CKAN dataset")
} # }
```
