# The language-model providers a key can be brought for

Lists every provider
[`llmask`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmask.md)
can reach with your own key: the environment variable that holds the
key, the address the key and prompts are sent to, the wire format used,
and whether a key is set on this machine. Use it to find the variable
name to set for a provider, or the `id` to pass as `route`. Nothing is
contacted.

## Usage

``` r
llmprvd()
```

## Value

A data frame with one row per provider (16 rows) and eight columns: `id`
(character, the value `route =` takes), `label` (character, readable
name), `base` (character, the API base address), `api` (character, the
wire format: `"openai"`, `"anthropic"` or `"gemini"`), `key_env`
(character, the environment variable for the key), `alt_env` (character,
an alternative variable, `""` when none), `default_model` (character,
the model used when none is chosen, `NA` when the provider has no
default) and `key_set` (logical, whether a key is set here).

## Details

The table is fixed in the package (the providers' documented addresses
and key variables). A key counts as set when the provider's variable
(`key_env`), its alternative spelling (`alt_env`), or a key saved with
`rmoriebricklayer config set ID.key` is non-empty; key values are never
returned. A key with a line break or control character in it is an
error. A server that speaks the OpenAI format but is not in the table is
used as your own endpoint (`MORIE_LLM_BASE_URL`).

## See also

[`llmstat`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmstat.md),
[`llmrte`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmrte.md).

## Examples

``` r
p <- llmprvd()
p[, c("id", "key_env", "key_set")]
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

# the providers that use the Anthropic or Gemini wire format
p[p$api != "openai", c("id", "api", "base")]
#>          id       api                                      base
#> 2 anthropic anthropic                 https://api.anthropic.com
#> 3    gemini    gemini https://generativelanguage.googleapis.com

# providers with a default model
p[!is.na(p$default_model), c("id", "default_model")]
#>            id   default_model
#> 2   anthropic claude-opus-5-5
#> 12 perplexity       sonar-pro
```
