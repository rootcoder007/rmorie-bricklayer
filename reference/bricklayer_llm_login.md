# Sign in for the curated tables at data.rmorie.com

Stores your personal MORIE data key in
`$XDG_CONFIG_HOME/morie/credentials.json` (owner-only; the file the
`morie`, `rmorie` and `rmoriedata` packages read too, so one sign-in
serves all of them). The key opens the curated tables
([`bricklayer_data_load`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_data_manifest.md));
it is not used for language models, which run on your own key or a local
model
([`bricklayer_llm_ask`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_ask.md)).
Keys are personal: the GitHub or emailed-code sign-in issues one, or ask
at <https://www.rmorie.com/access/>. The sign-in addresses come from
[`bricklayer_services`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_services.md).
Three ways in:

- `token`: a key you already have, from the website or an email. It is
  checked with the service first and stored only when it is accepted; a
  refused key, or no answer, stores nothing.

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

  Character scalar or `NULL` (the default): a key you already have,
  issued at <https://www.rmorie.com/access/>. Surrounding spaces are
  removed. Takes precedence over `email`.

- email:

  Character scalar or `NULL` (the default): sign in with a 6-digit code
  sent to this address. Lower-cased before use.

- code:

  Character scalar or `NULL` (the default): the emailed code when you
  already have it; `NULL` sends a new code and asks for it at the
  console. Used only with `email`.

- open_browser:

  Logical scalar, default
  [`interactive()`](https://rdrr.io/r/base/interactive.html): open the
  GitHub page for the device flow in the system browser (only a public
  `https` address is opened).

- poll_max_seconds:

  Numeric scalar, default `600`: how many seconds the device flow waits
  for you to approve the sign-in.

## Value

The key (character scalar), invisibly. A message names the file it was
stored in.

## Details

The credentials file is edited as text: only the three members this
package owns (`hosted_key`, `hosted_user` and `hosted_base_url`, the
address the key was issued for) are set, and every other byte stays, so
entries written by the other packages survive. The file is written
through a fresh temporary name, created owner-only (mode 0600, folder
0700 on Unix) before the key is written. A file that is not a JSON
object, is not valid JSON or names a member twice is refused rather than
overwritten. `XDG_CONFIG_HOME` moves the file; when unset it is
`~/.config/morie/credentials.json`.

The sign-in service address is the signed services document's
`data.auth_url` (see
[`bricklayer_services`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_services.md)),
or `MORIE_HOSTED_AUTH_URL` when set (it must be a public `https`
address). The device flow polls every `interval` seconds the service
names (5 by default), prints a progress line about every 30 seconds, and
stops with an error after `poll_max_seconds`.

Errors: an empty `token`; a `token` the data service does not accept, or
no answer from it (nothing is stored); an `email` that is empty or not
of the form `name@domain.tld`; no code typed at the prompt; a refused
code; a sign-in service that answers with an error or returns no key; a
credentials file that cannot be edited safely.

## See also

[`bricklayer_llm_logout`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_logout.md)
to remove the key.

## Examples

``` r
old <- Sys.getenv("XDG_CONFIG_HOME", unset = NA)
Sys.setenv(XDG_CONFIG_HOME = tempfile())   # never touch your real credentials

# input checks that need no network
try(bricklayer_llm_login(token = "   "))
#> Error : an empty token cannot be stored
try(bricklayer_llm_login(email = "not-an-email"))
#> Error : 'not-an-email' is not an email address

if (is.na(old)) Sys.unsetenv("XDG_CONFIG_HOME") else Sys.setenv(XDG_CONFIG_HOME = old)
if (FALSE) { # \dontrun{
# these contact the sign-in service
bricklayer_llm_login(token = "<key issued at https://www.rmorie.com/access/>")
bricklayer_llm_login(email = "you@example.com")
bricklayer_llm_login(email = "you@example.com", code = "123456")
bricklayer_llm_login() # GitHub device flow
} # }
```
