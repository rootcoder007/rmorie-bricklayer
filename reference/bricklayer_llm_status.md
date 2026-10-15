# Report the language-model routes available from this machine

Report the language-model routes available from this machine

## Usage

``` r
bricklayer_llm_status()
```

## Value

A data frame with one row per route, in the order
[`bricklayer_llm_ask`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_ask.md)
tries them (own endpoint, each provider whose key is set, local Ollama;
the providers without a key share one row): `route`, `status` and
`detail`. Nothing is sent to a provider; a local Ollama server is asked
for its model list. Printed by `rmoriebricklayer doctor`.

## Examples

``` r
# with the local route off the call reaches no network
old <- Sys.getenv("OLLAMA_HOST", unset = NA)
Sys.setenv(OLLAMA_HOST = "off")
bricklayer_llm_status()
#>             route   status
#> 1    own endpoint  not set
#> 2 other providers   no key
#> 3    local Ollama disabled
#>                                                                                                                                                                                                                                                                                                                                                                                                                                              detail
#> 1                                                                                                                                                                                                                                                                                                                                                           MORIE_LLM_BASE_URL (+ MORIE_LLM_API_KEY, MORIE_LLM_MODEL): any OpenAI-compatible server
#> 2 openai (OPENAI_API_KEY), anthropic (ANTHROPIC_API_KEY), gemini (GEMINI_API_KEY), openrouter (OPENROUTER_API_KEY), groq (GROQ_API_KEY), together (TOGETHER_API_KEY), fireworks (FIREWORKS_API_KEY), deepseek (DEEPSEEK_API_KEY), mistral (MISTRAL_API_KEY), xai (XAI_API_KEY), cerebras (CEREBRAS_API_KEY), perplexity (PERPLEXITY_API_KEY), huggingface (HF_TOKEN), opencode (OPENCODE_API_KEY), cohere (COHERE_API_KEY), nvidia (NVIDIA_API_KEY)
#> 3                                                                                                                                                                                                                                                                                                                                                                                                                                   OLLAMA_HOST=off
if (is.na(old)) Sys.unsetenv("OLLAMA_HOST") else Sys.setenv(OLLAMA_HOST = old)
```
