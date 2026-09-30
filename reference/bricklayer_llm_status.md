# Report the language-model routes available from this machine

Report the language-model routes available from this machine

## Usage

``` r
bricklayer_llm_status()
```

## Value

A data frame with one row per route: `route`, `status` and `detail`.
Printed by `rmoriebricklayer doctor`.

## Examples

``` r
bricklayer_llm_status()
#>               route        status
#> 1 hosted MORIE tier not logged in
#> 2  rmorie-cli agent        absent
#>                                                detail
#> 1                              https://llm.rmorie.com
#> 2 backend = "ollama" or "anthropic" in agent_bundle()
```
