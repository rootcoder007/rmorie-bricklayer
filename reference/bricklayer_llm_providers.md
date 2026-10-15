# The language-model providers a key can be brought for

Every provider
[`bricklayer_llm_ask`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_ask.md)
can reach with your own key, with the environment variable that holds
it, the address it is sent to and the wire format used. Nothing is
contacted.

## Usage

``` r
bricklayer_llm_providers()
```

## Value

A data frame: `id` (the route name), `label`, `key_env` (and `alt_env`),
`base`, `api` (`"openai"`, `"anthropic"` or `"gemini"`), `default_model`
and `key_set` (whether a key is set here).

## Examples

``` r
bricklayer_llm_providers()[, c("id", "key_env", "key_set")]
#>             id            key_env key_set
#> 1       openai     OPENAI_API_KEY   FALSE
#> 2    anthropic  ANTHROPIC_API_KEY   FALSE
#> 3       gemini     GEMINI_API_KEY   FALSE
#> 4   openrouter OPENROUTER_API_KEY   FALSE
#> 5         groq       GROQ_API_KEY   FALSE
#> 6     together   TOGETHER_API_KEY   FALSE
#> 7    fireworks  FIREWORKS_API_KEY   FALSE
#> 8     deepseek   DEEPSEEK_API_KEY   FALSE
#> 9      mistral    MISTRAL_API_KEY   FALSE
#> 10         xai        XAI_API_KEY   FALSE
#> 11    cerebras   CEREBRAS_API_KEY   FALSE
#> 12  perplexity PERPLEXITY_API_KEY   FALSE
#> 13 huggingface           HF_TOKEN   FALSE
#> 14    opencode   OPENCODE_API_KEY   FALSE
#> 15      cohere     COHERE_API_KEY   FALSE
#> 16      nvidia     NVIDIA_API_KEY   FALSE
```
