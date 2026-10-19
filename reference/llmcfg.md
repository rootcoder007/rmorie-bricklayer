# Show or save the language-model settings

Every setting that decides how
[`llmask`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmask.md)
reaches a model, in one place: which route to use; your key and model
for each provider (bring your own key: see
[`llmprvd`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmprvd.md));
the address, key and model of your own OpenAI-compatible server; and of
a local or LAN Ollama server. Called with no arguments it only reads: it
returns a table of every setting, its current value, and where that
value comes from. Called with `key = value` pairs it saves those
settings first. Keys are never printed, only whether one is set.

## Usage

``` r
llmcfg(...)
```

## Arguments

- ...:

  Settings to save, as `key = value`: `route` (`"auto"`, `"own"`,
  `"ollama"` or a provider id such as `"anthropic"`; case is ignored),
  `<provider>.key` and `<provider>.model` (e.g. `anthropic.key`,
  `openai.model`), `own.url`, `own.key`, `own.model`, `ollama.url`,
  `ollama.model`, `ollama.key`. Each value is a single string (leading
  and trailing spaces are removed). `NULL`, `NA` or `""` removes a saved
  setting. With no arguments nothing is written.

## Value

A data frame with one row per setting (seven general settings followed
by a key and a model row for each provider) and five character columns:
`key` (the setting's name), `value` (its current value, the default
spelled out; a key only as `"set"` or `"(not set)"`), `source`
(`"environment"`, `"saved"` or `"default"`), `env` (the environment
variable that overrides it) and `help` (what it is for). Returned
visibly when called with no settings, invisibly after saving.

## Details

**Where settings live.** Saved settings are kept in
`$XDG_CONFIG_HOME/morie/llm.json` (`~/.config/morie/llm.json` when
`XDG_CONFIG_HOME` is unset), a private file (mode 0600, in a private
directory) next to the shared `credentials.json`. The file is written
only when you pass a setting; only the settings that change are
rewritten in place, so the rest of the file stays exactly as it was. An
empty set of settings removes the file.

**Precedence.** An environment variable that is set (the `env` column,
for example `ANTHROPIC_API_KEY` or `OLLAMA_HOST`) wins over a saved
value, which wins over the built-in default. Saving a setting whose
variable is set warns that the variable still wins. A provider key is
also read from the provider's alternative variable where it has one
(`GOOGLE_API_KEY` for Gemini, `HUGGINGFACE_HUB_TOKEN` for Hugging Face,
`CO_API_KEY` for Cohere).

**Checks when saving.** Names must be among the settings listed in the
`key` column (`"unknown setting"` otherwise) and every value passed as
`key = value` with one value each. `route` must be `"auto"`, `"own"`,
`"ollama"` or a provider id; the retired `"hosted"` route is refused.
`own.url` must be an `http(s)://` address and `ollama.url` an address or
`host:port`; both are refused if they contain spaces, a fragment or user
information, and, unless they point at this machine or a private LAN
address, they get the package's public-address check (a metadata or
link-local address is refused). `"off"`, `"none"` or `"disabled"` turns
a server off. A key with a line break or control character in it is
refused. A new `own.url` or `ollama.url` drops the key saved for the old
server (with a message), so a key is never sent to a server it was not
saved for. A settings file that is not a JSON object, or holds a setting
that is not a non-empty string, stops every call until it is fixed or
moved aside with `rmbl config reset`.

Reading the settings takes a few milliseconds: the table of settings is
built once per session and the file is read once per call. Nothing is
sent over the network by this function.

The same is available from the shell: `rmbl config` lists the settings,
`rmbl config set KEY VALUE` and `rmbl config unset KEY` change one (a
key is asked for without echo when no value is given), and
`rmbl config setup` walks through them.

## See also

[`llmprvd`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmprvd.md)
for the providers and their variables,
[`llmstat`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmstat.md)
for which routes are reachable,
[`llmask`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmask.md)
which uses these settings.

## Examples

``` r
# Work in a temporary settings directory so your own settings are
# untouched.
old <- Sys.getenv("XDG_CONFIG_HOME", unset = NA)
Sys.setenv(XDG_CONFIG_HOME = tempfile("cfg"))

# Reading the settings writes nothing.
cfg <- llmcfg()
head(cfg[, c("key", "value", "source")])
#>            key                  value  source
#> 1        route                   auto default
#> 2      own.url              (not set) default
#> 3      own.key              (not set) default
#> 4    own.model              (not set) default
#> 5   ollama.url http://localhost:11434 default
#> 6 ollama.model (the first one pulled) default
nrow(cfg)
#> [1] 39

# Save a local Ollama model and use it for every request; the key column
# shows where each value now comes from.
llmcfg(ollama.model = "qwen3:8b", route = "ollama")
cfg <- llmcfg()
cfg[cfg$key %in% c("route", "ollama.model"), c("key", "value", "source")]
#>            key    value source
#> 1        route   ollama  saved
#> 6 ollama.model qwen3:8b  saved

# A key is shown only as set or not set.
llmcfg(own.url = "http://localhost:1234/v1", own.key = "k-123")
cfg <- llmcfg()
cfg$value[cfg$key == "own.key"]
#> [1] "set"

# Back to the defaults: NULL removes a saved setting.
llmcfg(route = NULL, ollama.model = NULL, own.url = NULL,
                      own.key = NULL)

# Unknown settings and retired routes are refused.
try(llmcfg(colour = "blue"))
#> Error : unknown setting 'colour' (one of: route, own.url, own.key, own.model, ollama.url, ollama.model, ollama.key, openai.key, openai.model, anthropic.key, anthropic.model, gemini.key, gemini.model, openrouter.key, openrouter.model, groq.key, groq.model, together.key, together.model, fireworks.key, fireworks.model, deepseek.key, deepseek.model, mistral.key, mistral.model, xai.key, xai.model, cerebras.key, cerebras.model, perplexity.key, perplexity.model, huggingface.key, huggingface.model, opencode.key, opencode.model, cohere.key, cohere.model, nvidia.key, nvidia.model)
try(llmcfg(route = "hosted"))
#> Error : the hosted MORIE language-model tier is retired: bring your own key (a provider's variable such as ANTHROPIC_API_KEY or OPENAI_API_KEY, or `rmoriebricklayer config set <provider>.key`) or run a model locally (Ollama); `rmoriebricklayer config setup` walks through it

if (is.na(old)) Sys.unsetenv("XDG_CONFIG_HOME") else Sys.setenv(XDG_CONFIG_HOME = old)
if (FALSE) { # \dontrun{
# your Anthropic key and model, and always use them
llmcfg(anthropic.key = "sk-ant-...", route = "anthropic")
# an Ollama server on another machine
llmcfg(ollama.url = "http://192.168.1.20:11434", ollama.model = "qwen3:8b")
} # }
```
