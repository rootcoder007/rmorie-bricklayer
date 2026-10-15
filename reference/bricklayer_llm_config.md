# Show or save the language-model settings

Every setting that decides how
[`bricklayer_llm_ask`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_ask.md)
reaches a model, in one place: which route to use; your key and model
for each provider (bring your own key: see
[`bricklayer_llm_providers`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_providers.md));
the address, key and model of your own OpenAI-compatible server; and of
a local or LAN Ollama server. Settings are saved in
`$XDG_CONFIG_HOME/morie/llm.json` (default `~/.config/morie/`), a
private file (owner-only) this function writes only when you pass a
setting; keys are never printed. An environment variable that is set
(the `env` column, e.g. `ANTHROPIC_API_KEY`) wins over a saved value.

## Usage

``` r
bricklayer_llm_config(...)
```

## Arguments

- ...:

  Settings to save, as `key = value`: `route` (`"auto"`, `"own"`,
  `"ollama"` or a provider id), `<provider>.key` and `<provider>.model`
  (e.g. `anthropic.key`, `openai.model`), `own.url`, `own.key`,
  `own.model`, `ollama.url`, `ollama.model`, `ollama.key`. `NULL` or
  `""` removes a saved setting. With no arguments nothing is written.

## Value

A data frame with one row per setting: `key`, `value` (a key only as
`"set"`), `source` (`"environment"`, `"saved"` or `"default"`), `env`
(the variable that overrides it) and `help`; visibly when called with no
settings.

## Details

The same is available from the shell: `rmbl config` lists the settings,
`rmbl config set KEY VALUE` and `rmbl config unset KEY` change one (a
key is asked for without echo when no value is given), and
`rmbl config setup` walks through them.

## Examples

``` r
# reading the settings writes nothing
head(bricklayer_llm_config())
#>            key                  value  source                env
#> 1        route                   auto default    MORIE_LLM_ROUTE
#> 2      own.url              (not set) default MORIE_LLM_BASE_URL
#> 3      own.key              (not set) default  MORIE_LLM_API_KEY
#> 4    own.model              (not set) default    MORIE_LLM_MODEL
#> 5   ollama.url http://localhost:11434 default        OLLAMA_HOST
#> 6 ollama.model (the first one pulled) default       OLLAMA_MODEL
#>                                                                                                                                                                      help
#> 1                                                      which route `ask` uses: auto (own endpoint, then each provider with a key, then Ollama), own, ollama or a provider
#> 2 your own OpenAI-compatible server, e.g. http://localhost:1234/v1 (LM Studio), http://localhost:8080/v1 (llama-server -m /path/model.gguf) or https://api.example.org/v1
#> 3                                                                                                                    API key for your own server (sent as a Bearer token)
#> 4                                                                                                                                           model name on your own server
#> 5                                                                               your Ollama server, e.g. http://localhost:11434 or 192.168.1.20:11434; off to skip Ollama
#> 6                                                                                                                     Ollama model to use (default: the first one pulled)
if (FALSE) { # \dontrun{
# your Anthropic key and model, and always use them
bricklayer_llm_config(anthropic.key = "sk-ant-...", route = "anthropic")
# an Ollama server on another machine
bricklayer_llm_config(ollama.url = "http://192.168.1.20:11434", ollama.model = "qwen3:8b")
# your own OpenAI-compatible server
bricklayer_llm_config(own.url = "http://localhost:1234/v1", own.model = "my-model")
# back to the automatic order
bricklayer_llm_config(route = NULL)
} # }
```
