# Show or save the language-model settings

Every setting that decides how
[`bricklayer_llm_ask`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_ask.md)
reaches a model, in one place: which route to use, and the address, key
and model of your own OpenAI-compatible server, of a local or LAN Ollama
server, and of the hosted MORIE tier. Settings are saved in
`$XDG_CONFIG_HOME/morie/llm.json` (default `~/.config/morie/`), a
private file this function writes only when you pass a setting; the
hosted key goes to the shared credentials file through
[`bricklayer_llm_login`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_login.md),
which checks it with the gateway first. An environment variable that is
set (the `env` column) wins over a saved value.

## Usage

``` r
bricklayer_llm_config(...)
```

## Arguments

- ...:

  Settings to save, as `key = value`: `route` (`"auto"`, `"own"`,
  `"ollama"` or `"hosted"`), `own.url`, `own.key`, `own.model`,
  `ollama.url`, `ollama.model`, `ollama.key`, `hosted.url`,
  `hosted.model`, `hosted.key`. `NULL` or `""` removes a saved setting.
  With no arguments nothing is written.

## Value

A data frame with one row per setting: `key`, `value` (a key only as
`"set"`), `source` (`"environment"`, `"saved"` or `"default"`), `env`
(the variable that overrides it) and `help`; visibly when called with no
settings.

## Details

The same is available from the shell: `rmbl config` lists the settings,
`rmbl config set KEY VALUE` and `rmbl config unset KEY` change one, and
`rmbl config setup` walks through all of them.

## Examples

``` r
# reading the settings writes nothing
bricklayer_llm_config()
#>             key                  value  source                   env
#> 1         route                   auto default       MORIE_LLM_ROUTE
#> 2       own.url              (not set) default    MORIE_LLM_BASE_URL
#> 3       own.key              (not set) default     MORIE_LLM_API_KEY
#> 4     own.model   (the server's first) default       MORIE_LLM_MODEL
#> 5    ollama.url http://localhost:11434 default           OLLAMA_HOST
#> 6  ollama.model (the first one pulled) default          OLLAMA_MODEL
#> 7    ollama.key              (not set) default        OLLAMA_API_KEY
#> 8    hosted.url https://llm.rmorie.com default MORIE_HOSTED_BASE_URL
#> 9  hosted.model       minimax-m3:cloud default    MORIE_HOSTED_MODEL
#> 10   hosted.key              (not set) default      MORIE_HOSTED_KEY
#>                                                                                                                                                                       help
#> 1                                                                             which route `ask` uses: auto (own endpoint, then Ollama, then hosted), own, ollama or hosted
#> 2  your own OpenAI-compatible server, e.g. http://localhost:1234/v1 (LM Studio), http://localhost:8080/v1 (llama-server -m /path/model.gguf) or https://api.example.org/v1
#> 3                                                                                                                     API key for your own server (sent as a Bearer token)
#> 4                                                                                                                                            model name on your own server
#> 5                                                                                your Ollama server, e.g. http://localhost:11434 or 192.168.1.20:11434; off to skip Ollama
#> 6                                                                                                                      Ollama model to use (default: the first one pulled)
#> 7                                                                                                                              API key for an Ollama server that wants one
#> 8                                                                                   hosted MORIE tier address (default: from the signed services document); off to skip it
#> 9                                                                                                     hosted model (default: the tier's default; `rmbl models` lists them)
#> 10                                                                                    your MORIE key (stored by `rmbl login`; checked with the gateway before it is saved)
if (FALSE) { # \dontrun{
# always use the hosted tier with one model
bricklayer_llm_config(route = "hosted", hosted.model = "gpt-oss-120b:cf")
# an Ollama server on another machine
bricklayer_llm_config(ollama.url = "http://192.168.1.20:11434", ollama.model = "qwen3:8b")
# your own OpenAI-compatible server
bricklayer_llm_config(own.url = "http://localhost:1234/v1", own.model = "my-model")
# back to the automatic order
bricklayer_llm_config(route = NULL)
} # }
```
