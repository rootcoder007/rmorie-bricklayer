# Language models (your own key) and the signed services document

[`bricklayer_llm_ask()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_ask.md)
sends a question to a language model and returns the answer. You bring
the model: a key for a provider you already use, a model on your own
machine, or a server of your own. Nothing is sent anywhere you did not
set up, and the package runs no model service of its own. This vignette
explains the routes, how the model is given the packages’ help, and what
the package will and will not do on the network.

## The route order

1.  **An endpoint of your own**: `MORIE_LLM_BASE_URL` (with
    `MORIE_LLM_API_KEY` and `MORIE_LLM_MODEL`), any OpenAI-compatible
    server (LM Studio, vLLM, llama.cpp’s `llama-server`, a company
    gateway). Taken when configured, not probed.
2.  **A provider whose key is set**, in the order
    [`bricklayer_llm_providers()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_providers.md)
    lists them: OpenAI, Anthropic, Google Gemini, OpenRouter, Groq,
    Together AI, Fireworks AI, DeepSeek, Mistral, xAI, Cerebras,
    Perplexity, Hugging Face, OpenCode Zen, Cohere and NVIDIA. Each
    reads its usual variable (`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`,
    `GEMINI_API_KEY`, …) or a key saved with
    `bricklayer_llm_config(anthropic.key = ...)`; the model is
    `MORIE_<PROVIDER>_MODEL` or `<provider>.model`. Anthropic’s Messages
    API and Gemini’s `generateContent` are spoken natively; the others
    are OpenAI-compatible.
3.  **Ollama** at `OLLAMA_HOST` (default `localhost:11434`), on this
    machine or another, once its server is running (`ollama serve`, the
    Ollama app, or the system service its Linux installer sets up) and
    has a model (`ollama pull NAME`), or Ollama’s own cloud API
    (`ollama.url = https://ollama.com` with your `ollama.key`);
    `OLLAMA_HOST=off` disables the probe. Its first listed model is the
    default.

`route = "anthropic"` (or `rmbl config set route anthropic`) takes one
route only.

``` r

bricklayer_llm_providers()[, c("id", "label", "key_env")]
#>             id         label            key_env
#> 1       openai        OpenAI     OPENAI_API_KEY
#> 2    anthropic     Anthropic  ANTHROPIC_API_KEY
#> 3       gemini Google Gemini     GEMINI_API_KEY
#> 4   openrouter    OpenRouter OPENROUTER_API_KEY
#> 5         groq          Groq       GROQ_API_KEY
#> 6     together   Together AI   TOGETHER_API_KEY
#> 7    fireworks  Fireworks AI  FIREWORKS_API_KEY
#> 8     deepseek      DeepSeek   DEEPSEEK_API_KEY
#> 9      mistral       Mistral    MISTRAL_API_KEY
#> 10         xai           xAI        XAI_API_KEY
#> 11    cerebras      Cerebras   CEREBRAS_API_KEY
#> 12  perplexity    Perplexity PERPLEXITY_API_KEY
#> 13 huggingface  Hugging Face           HF_TOKEN
#> 14    opencode  OpenCode Zen   OPENCODE_API_KEY
#> 15      cohere        Cohere     COHERE_API_KEY
#> 16      nvidia    NVIDIA NIM     NVIDIA_API_KEY
```

[`bricklayer_llm_status()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_status.md)
reports what is available from this machine. With the local route off
the call reaches no network:

``` r

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

## Asking, with the packages’ help at hand

``` r

bricklayer_llm_ask("How do I estimate a weighted proportion with bootstrap replicate weights?")
bricklayer_llm_ask(paste(c("Summarise this table:", capture.output(print(head(mtcars)))),
                         collapse = "\n"),
                   system_prompt = "Answer in two sentences.", docs = FALSE)
```

With `docs = TRUE` (the default) the model is told every function of the
MORIE packages installed here (rmoriebricklayer, and rmoriedata and
rmorie when present), read from their installed help, and gets five
tools it can call: `search_docs` (a search over every help page),
`get_help`, `get_examples`, `list_datasets` and `get_vignette`. It reads
the pages it needs before it writes code. A model that does not take
tools gets the pages nearest the question in its prompt instead. The
tools only read help; nothing the model says is run.

How much of the help goes into the prompt follows what the model can
take in:

- a provider’s model, a model Ollama serves from its cloud
  (`minimax-m3:cloud` reports a 512,000-token context) and a remote
  server of your own get the whole index of functions, full help pages
  and up to six rounds of lookups;
- a model Ollama runs on this machine works in Ollama’s context window
  (4,096 tokens unless the server was started with
  `OLLAMA_CONTEXT_LENGTH`), so it gets the functions nearest the
  question, shorter pages and fewer rounds; a server of your own on this
  machine gets a middle size;
- `MORIE_LLM_CONTEXT` (tokens) says what your model takes, whatever the
  route.

Every size can still reach every function: `search_docs` and `get_help`
look up any page.

[`agent_bundle()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/agent_bundle.md)
asks over the same routes, with the bundle task added, and with no route
it returns the setup hint (`rmbl bundle` exits 1).

## The signed services document

The data service’s addresses and its sign-in service are **not**
hard-coded in the package. They come from a document at
`https://rmorie.com/.well-known/morie-services.json`, signed with
ML-DSA-44 under a key pinned in the package, so the endpoints can change
without a release while no one but the project can change them. A copy
ships with the package as the fallback and the floor:

``` r

s <- bricklayer_services(offline = TRUE)
s$data$mode
#> [1] "key"
attr(s, "source")
#> [1] "bundled"
```

What the verifier enforces, each with a test:

- the signature must verify under the pinned key, or the document is
  ignored;
- a validly signed but **older** document than the bundled copy is
  refused: a retired document in a cache (or served live) can never pin
  the endpoint a key would be sent to;
- the cache serves only when it is newer than the bundled document, and
  an older cache is deleted;
- a mirror without a `.json` suffix finds its `.sig`;
  `MORIE_SERVICES_URL` names a mirror.

## What the package will not do on the network

The 0.5.8 to 0.5.10 reviews closed every bypass of the transport and
these rules now hold for every byte the package sends or receives:

- An endpoint of your own is either the loopback host, a literal private
  LAN address (`10/8`, `172.16/12`, `192.168/16`, `fc00::/7`, for an LM
  Studio or vLLM box on your own network) over plain http, or a public
  https address. Link-local addresses and host names over plain http are
  refused, and a redirect from a remote origin into the loopback
  interface is refused.
- Request headers do not follow a redirect to another origin (scheme,
  host or effective port) unless they are content negotiation;
  `Authorization`, `X-Api-Key` and the rest stay with the first origin.
- **Keys are redacted by value**: a gateway’s error text has the key
  that was sent, any `Bearer` token and any `sk-` key removed before it
  becomes an R condition.
- Bytes a server sent are parsed as text, never as a second address.
- A download under 64 bytes/s for 30 s is ended. A model call is not: a
  model may think for a minute before its first byte, so a call has one
  deadline, the `timeout` (120 s), a conversation with help-page lookups
  three times that, and Ctrl-C ends the wait at once without sending the
  prompt again. An in-memory reply past 16 MiB is dropped; the services
  document and JSON fetches cap at 1 MiB and 16 MiB.
- The sign-in service’s `verification_uri` is opened in a browser only
  when it is a public https address.

## The data key

Signing in is for the curated tables at `data.rmorie.com` only; it is
never a language model.

``` r

bricklayer_llm_login(token = "<key issued at https://www.rmorie.com/access/>")
bricklayer_llm_login()          # or: GitHub device flow / emailed code
bricklayer_llm_logout()         # forget the key
```

The key is stored with mode 0600 in the user’s configuration directory
and never written anywhere else. `rmbl doctor` says whether one is
stored.

## From the command line

The same routes serve the CLI installed by
[`install_cli()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/install_cli.md):

``` sh
rmoriebricklayer config setup       # pick a provider, paste its key (saved privately), pick a model
rmoriebricklayer doctor             # the routes, and the one ask takes
rmoriebricklayer models --route anthropic
rmoriebricklayer ask "what does capsule_bundle() cover?"
rmoriebricklayer ask --route ollama --model gemma3:4b "how do I verify a capsule?"
rmoriebricklayer login --token      # the data key: paste it when asked; it never sits in the shell history
```
