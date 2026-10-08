# Language-model routes and the signed services document

[`bricklayer_llm_ask()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_ask.md)
sends a question to a language model and returns the answer. Which model
answers is decided by a fixed order of routes, and every address the
package would connect to is either yours or comes from a signed
document. This vignette explains the order, the document, and what the
package will and will not do on the network.

## The route order

1.  **An endpoint of your own**: `MORIE_LLM_BASE_URL` (with
    `MORIE_LLM_API_KEY` and `MORIE_LLM_MODEL`), any OpenAI-compatible
    server. Taken when configured, not probed.
2.  **A local Ollama** at `OLLAMA_HOST` (default `localhost:11434`);
    `OLLAMA_HOST=off` disables the probe.
3.  **The hosted MORIE tier**, last, and only with a personal key issued
    on request at <https://www.rmorie.com/access/>. A cloud provider’s
    own API (Gemini, OpenAI) is reached through route 1 when its
    endpoint speaks the OpenAI protocol; there is no separate route.

[`bricklayer_llm_status()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_status.md)
reports what is available from this machine. With the local route off
the call reaches no network:

``` r

old <- Sys.getenv("OLLAMA_HOST", unset = NA)
Sys.setenv(OLLAMA_HOST = "off")
bricklayer_llm_status()
#>               route        status
#> 1      own endpoint       not set
#> 2      local Ollama      disabled
#> 3 hosted MORIE tier not logged in
#>                                                                                                                                                                                                                  detail
#> 1                                                                                                                               MORIE_LLM_BASE_URL (+ MORIE_LLM_API_KEY, MORIE_LLM_MODEL): any OpenAI-compatible server
#> 2                                                                                                                                                                                                       OLLAMA_HOST=off
#> 3 https://llm.rmorie.com  (request a key at https://rmorie.com/access, then `rmoriebricklayer login --token KEY` (R: bricklayer_llm_login(token = )); `rmoriebricklayer login` signs in with GitHub or an emailed code)
if (is.na(old)) Sys.unsetenv("OLLAMA_HOST") else Sys.setenv(OLLAMA_HOST = old)
```

## Asking

``` r

bricklayer_llm_ask("In one sentence, what does a Merkle root pin?")
bricklayer_llm_ask(paste(c("Summarise this table:", capture.output(print(head(mtcars)))),
                         collapse = "\n"),
                   system_prompt = "Answer in two sentences.")
```

[`agent_bundle()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/agent_bundle.md)
uses the same route to explain a reproducibility bundle’s verification
output in plain language, when a key is stored and only then.

## The signed services document

The hosted tier’s addresses, its model list and its sign-in service are
**not** hard-coded in the package. They come from a document at
`https://rmorie.com/.well-known/morie-services.json`, signed with
ML-DSA-44 under a key pinned in the package, so the endpoints can change
without a release while no one but the project can change them. A copy
ships with the package as the fallback and the floor:

``` r

s <- bricklayer_services(offline = TRUE)
s$llm$mode
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
- A transfer under 64 bytes/s for 30 s is ended; an in-memory reply past
  16 MiB is dropped; the services document and JSON fetches cap at 1 MiB
  and 16 MiB.
- The sign-in service’s `verification_uri` is opened in a browser only
  when it is a public https address.

## Signing in to the hosted tier

``` r

bricklayer_llm_login(token = "<key issued at https://www.rmorie.com/access/>")
bricklayer_llm_login()          # or: GitHub device flow / emailed code
bricklayer_llm_models()         # what the tier offers
bricklayer_llm_logout()         # forget the key
```

The key is stored with mode 0600 in the user’s configuration directory
and never written anywhere else. Prompts and responses are not stored by
the tier; the published terms are at `https://llm.rmorie.com/`.

## From the command line

The same routes serve the CLI installed by
[`install_cli()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/install_cli.md):

``` sh
rmoriebricklayer status
rmoriebricklayer ask "what does capsule_bundle() cover?"
rmoriebricklayer login --token KEY
```
