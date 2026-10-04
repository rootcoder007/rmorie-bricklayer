# Report the language-model routes available from this machine

Report the language-model routes available from this machine

## Usage

``` r
bricklayer_llm_status()
```

## Value

A data frame with one row per route (the hosted MORIE tier): `route`,
`status` and `detail`. Printed by `rmoriebricklayer doctor`.

## Examples

``` r
bricklayer_llm_status()
#>               route        status                 detail
#> 1 hosted MORIE tier not logged in https://llm.rmorie.com
```
