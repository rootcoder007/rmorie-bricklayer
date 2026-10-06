# Report the language-model routes available from this machine

Report the language-model routes available from this machine

## Usage

``` r
bricklayer_llm_status()
```

## Value

A data frame with one row per route, in the order
[`bricklayer_llm_ask`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_ask.md)
tries them (own endpoint, local Ollama, hosted MORIE tier): `route`,
`status` and `detail`. Printed by `rmoriebricklayer doctor`.

## Examples

``` r
bricklayer_llm_status()
#>               route        status
#> 1      own endpoint       not set
#> 2      local Ollama   not running
#> 3 hosted MORIE tier not logged in
#>                                                                                                                                                                                                                  detail
#> 1                                                                                                                               MORIE_LLM_BASE_URL (+ MORIE_LLM_API_KEY, MORIE_LLM_MODEL): any OpenAI-compatible server
#> 2                                                                                                                            http://localhost:11434 (install Ollama and pull a model, or point OLLAMA_HOST at a server)
#> 3 https://llm.rmorie.com  (request a key at https://rmorie.com/access, then `rmoriebricklayer login --token KEY` (R: bricklayer_llm_login(token = )); `rmoriebricklayer login` signs in with GitHub or an emailed code)
```
