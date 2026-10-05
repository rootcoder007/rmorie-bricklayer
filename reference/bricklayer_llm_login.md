# Sign in to the hosted MORIE language model

Mints a personal key for <https://llm.rmorie.com> and stores it in
`$XDG_CONFIG_HOME/morie/credentials.json` (owner-only; the file the
`morie` and `rmorie` packages read too, so one sign-in serves all
three). Three ways in:

- `token`: a key you already have, from the website or an email. It is
  checked with the gateway first and stored only when the gateway
  accepts it; a refused key, or no answer, stores nothing.

- `email`: a 6-digit code is sent to the address (valid ten minutes,
  single use); you type it, or pass `code`.

- neither: the GitHub device flow; a code is shown to enter at
  github.com, and the key arrives once you approve.

Nothing is written except by this explicit call.

## Usage

``` r
bricklayer_llm_login(
  token = NULL,
  email = NULL,
  code = NULL,
  open_browser = interactive(),
  poll_max_seconds = 600
)
```

## Arguments

- token:

  A key from <https://llm.rmorie.com>.

- email:

  Sign in with a code sent to this address.

- code:

  The emailed code, when you already have it.

- open_browser:

  Open the GitHub page for the device flow.

- poll_max_seconds:

  How long the device flow waits for approval.

## Value

The key, invisibly.

## Examples

``` r
if (FALSE) { # \dontrun{
bricklayer_llm_login(email = "you@example.com")
bricklayer_llm_login() # GitHub device flow
bricklayer_llm_login(token = "<key from https://llm.rmorie.com>")
} # }
```
