# Run the rmoriebricklayer command line

Dispatches the verbs of the `rmoriebricklayer` launcher:

- `login [--token] [--email ADDRESS [--code CODE]] [--no-browser]`:

  sign in for the curated tables at data.rmorie.com (a free MORIE data
  key, issued at <https://www.rmorie.com/access/>): a key you paste with
  `--token` (read from the terminal or a pipe when KEY is omitted), a
  code sent to `--email`, or the GitHub device flow

- `logout`:

  forget the data key

- `doctor`:

  report the language-model routes available here (own endpoint, each
  provider with your key, local Ollama), in the order `ask` tries them

- `models [--route ROUTE]`:

  list the models your provider (or server) offers, the one in use
  marked

- `data list`:

  the curated tables at data.rmorie.com

- `data pull db/table`:

  download one table as CSV

- `app [PATH] [--port N] [--no-browser]`:

  open the analysis dashboard
  ([`rmblapp`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmblapp.md))
  on this machine, with PATH, a CSV file or a capsule directory, loaded;
  needs the shiny package

- `config [setup | set KEY VALUE | unset KEY | get KEY | help]`:

  show or change the settings of the language model
  ([`llmcfg`](https://rootcoder007.github.io/rmorie-bricklayer/reference/llmcfg.md)):
  the route `ask` uses and the address, key and model of each route;
  `setup` walks through them

- `ask [--route ROUTE] [--model NAME] [--fresh] PROMPT...`:

  send a prompt to the model (or the named one, on the named route) and
  print the reply; the same question again is answered from this machine
  (`--fresh` asks anew). `aye` and `tellme` are the same verb, and a
  quoted question with no verb (`rmbl "how do I weight a survey?"`) is
  asked too

- `explain-error MESSAGE...`:

  where an error of these packages comes from
  ([`explerr`](https://rootcoder007.github.io/rmorie-bricklayer/reference/explerr.md)),
  without a model or the network

- `bundle REQUEST...`:

  [`agentbndl`](https://rootcoder007.github.io/rmorie-bricklayer/reference/agentbndl.md)
  from the shell

- `wayback FILE [--out FILE.jsonl] [--jobs N] [--within 30d] [--max N]`:

  save every URL listed in FILE (one per line; blank lines and `#`
  comments skipped) in the Internet Archive's Wayback Machine with
  [`wbsave`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wbsave.md),
  results in `--out` (default `FILE.wayback.jsonl`), so a stopped run
  carries on; `wayback --retry FILE.jsonl [--include-gone]` retries the
  failures of an earlier run
  ([`wbrtry`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wbrtry.md))

- `verify PATH [--json] [--fail-on LEVEL] [--public-key HEX]`:

  check every capsule under PATH as the rmbl GitHub Action does
  ([`cpschk`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpschk.md)):
  each file against its JSON Schema
  ([`schemapath`](https://rootcoder007.github.io/rmorie-bricklayer/reference/schemapath.md)),
  [`vrfcps`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfcps.md)
  and
  [`cpsbndlvrf`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsbndl.md).
  The secret of an hmac bundle is read from `RMBL_KEY`, which is then
  removed from the environment. Prints the Markdown report, or JSON with
  `--json`; exits 1 when a failed row is at or above `--fail-on`
  (`error`, the default, `drift` or `warn`). `--base MANIFEST|DIR`
  compares each manifest with its base copy, `--manifests GLOB` checks
  only the capsule files matching GLOB, `--snapshot` looks up each
  source's latest Wayback snapshot and `--no-footprint` leaves the
  footprint
  ([`co2fp`](https://rootcoder007.github.io/rmorie-bricklayer/reference/co2fp.md))
  out of the report

- `drift PATH [--json] [--fail-on LEVEL] [--html FILE] [--app]`:

  verify, then fetch each source again and compare it column by column
  ([`cpsdrft`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md),
  Benford): a column past `--psi-warn X` (0.1) is a warning, a flagged
  one past `--psi-fail X` (0.25) drift. `--allow-file` accepts `file://`
  sources, `--cache DIR` keeps each source and reads it when a fetch
  fails; the options of verify apply. `--html FILE` writes the
  interactive report
  ([`drfthtml`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drfthtml.md))
  and `--app` opens it as a Shiny app
  ([`drftapp`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drftapp.md))

- `refresh PATH`:

  pin each source's new bytes
  ([`cpsrfrsh`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsrfrsh.md))
  and print what changed
  ([`mnfdiff`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mnfdiff.md))

- `report PATH [--format md|json]`:

  the verify report, exit 0; the options of verify apply

- `sign PATH [--scheme S] [--key-file F] [--overwrite]`:

  pin each provenance on its first run and sign each capsule into
  `capsule_bundle.json`
  ([`cpsseal`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsseal.md)),
  then verify as `verify` does. The key is `RMBL_KEY`, removed from the
  environment at once, or the contents of `--key-file`, and is never
  printed: the shared secret for `hmac` (the default), else the JSON of
  a
  [`fipskg`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md)
  key, or its secret hex with `--public-key`. An existing bundle is
  refused without `--overwrite`; an `xmss-sha256` key is refused

- `functions [PATTERN]`:

  list the exported functions with their one-line titles, optionally
  filtered by a regular expression

- `describe NAME`:

  title, usage, arguments and description of one function, from its help
  page

- `examples NAME`:

  print the examples of one function

- `version`:

  print the package version (also `--version`, `-v`)

- `help [VERB]`:

  this list, or one verb's usage (also `--help`, `-h`; `VERB --help`
  shows a verb's usage without running it)

The launcher installed by
[`instcli`](https://rootcoder007.github.io/rmorie-bricklayer/reference/instcli.md)
calls this function with the shell's arguments and exits with its
status. Calling it from R is the same as typing the command, which is
how the examples below work.

## Usage

``` r
blcli(args = commandArgs(trailingOnly = TRUE), out = cat)
```

## Arguments

- args:

  Character vector of arguments, verb first. The default is the command
  line, `commandArgs(trailingOnly = TRUE)`. An empty vector prints the
  help.

- out:

  Function that receives the output text, one string at a time (default
  `cat`, the console). Pass a function that collects the strings to
  capture the output.

## Value

The exit status (integer scalar), invisibly: 0 on success, 1 on failure,
2 for a usage error, 130 when interrupted.

## Details

An option a verb does not take is refused with exit status 2 rather than
ignored or sent as part of a prompt; everything after a bare `--` is
positional (for a prompt that itself starts with `--`) and only `ask`,
`bundle` and `explain-error` accept it. A first argument that is plainly
a question (two or more words, or ending in `?`, with no path, line
break or key-shaped word) and no verb is asked as `ask` would ask it.

Errors are not raised: every error is written to `out` as
`"PROG: message"` and turned into the exit status. The status is 0 on
success, 1 when the verb failed (an error, nothing found, no route), 2
for a usage error (an unknown verb or option, a missing value) and 130
when interrupted (Ctrl-C). The command name in messages is the
environment variable `RMBL_PROG`, else `rmoriebricklayer`.

Side effects: during the call `options(morie.progress = TRUE)` is set,
so downloads draw a progress bar; when `RMBL_PROG` is set (the launcher
sets it) and `options(rmoriebricklayer.dcache)` is not, the
data.rmorie.com manifest and tables are kept in
`tools::R_user_dir("rmoriebricklayer", "cache")` rather than a fresh
temporary folder. The verbs `login`, `logout` and `config` write the
shared credentials and settings files; `ask`, `models`, `data`, `bundle`
and `wayback` use the network, and `drift` and `refresh` fetch each
capsule's source (`refresh` writes the capsule), `sign` writes each
capsule's provenance and bundle; `verify` and `report` only read the
capsule files; `functions`, `describe`, `examples`, `explain-error`,
`version` and `help` only read the installed help.

## See also

[`instcli`](https://rootcoder007.github.io/rmorie-bricklayer/reference/instcli.md)
to put the command on your PATH.

## Examples

``` r
blcli("version")
#> rmoriebricklayer 1.0.0
blcli("help")
#> usage: rmoriebricklayer <verb> [options]   (rmbl is the same command as rmoriebricklayer)
#> 
#> Language models (your own key, or a model on your machine)
#>   ask [--route R] [--model NAME] PROMPT...  ask a model and print the reply (--fresh: ask anew)
#>   aye, tellme, or just "QUESTION?"          the same as ask
#>   explain-error "MESSAGE"                   where an error comes from and what to do, no model needed
#>   doctor                                    what is set up, and which route ask will use
#>   config                                    show every language-model setting
#>   config setup                              answer a few questions to set them all
#>   config set KEY VALUE | unset KEY          change one (keys: config help)
#>   config reset [--force]                    move an unreadable settings file aside
#>   models [--route R]                        models your provider or server offers
#>   bundle REQUEST...                         agentbndl() from the shell
#> 
#> Data and functions
#>   login [--token] [--email ADDRESS]         sign in for the curated tables at data.rmorie.com
#>         [--code CODE] [--no-browser]
#>   logout                                    forget the data key
#>   data list                                 curated tables at data.rmorie.com
#>   data pull db/table [--out FILE.csv]       download one of them (your MORIE data key)
#>   app [PATH] [--port N] [--no-browser]      the analysis dashboard on this machine (needs shiny)
#>   wayback FILE [--out F.jsonl] [--jobs N]   archive every URL in FILE (archive.org keys)
#>   wayback --retry F.jsonl                   retry the failed URLs of an earlier wayback run
#>   functions [PATTERN]                       exported functions and their titles
#>   describe NAME                             help page of one function
#>   examples NAME                             its examples
#>   version                                   package version
#> 
#> Capsules (the checks of the rmbl GitHub Action)
#>   verify PATH [--json] [--fail-on LEVEL]    schemas, digests, bundle signature (hmac secret: RMBL_KEY)
#>         [--base MANIFEST|DIR] [--snapshot]  manifests against their base copies; Wayback snapshots
#>   drift PATH [--json] [--fail-on LEVEL]     verify, then fetch each source and compare it with the pin
#>         [--psi-warn X] [--psi-fail X]       the PSI bands of the column table (0.1 and 0.25)
#>         [--html FILE] [--app]               and write the drift report, or open it as an app
#>   refresh PATH                              pin each source's new bytes in its provenance
#>   sign PATH [--scheme S] [--key-file F]     pin and sign each capsule (key: RMBL_KEY or the file), verify
#>   report PATH [--format md|json]            the verify report; never fails
#> 
#> More help
#>   rmoriebricklayer help start      getting started, step by step
#>   rmoriebricklayer help llm        every way to point ask at a model (your key, Ollama, your own server)
#>   rmoriebricklayer help config     every setting, its environment variable, and examples
#>   rmoriebricklayer help r          the same from R and Rscript
#>   rmoriebricklayer VERB --help     one verb's usage

# one verb's usage
blcli(c("help", "data"))
#> usage: rmoriebricklayer data list | data pull db/table [--out FILE.csv]   curated tables at data.rmorie.com (your MORIE key)

# capture the output instead of printing it
con <- textConnection("lines", "w")
status <- blcli(c("functions", "^drbg_"), out = function(x) cat(x, file = con))
close(con)
status
#> [1] 0
lines
#> [1] "  drbg_generate  The 0.5.x names, kept as aliases"
#> [2] "  drbg_new       The 0.5.x names, kept as aliases"
#> [3] "  drbg_reseed    The 0.5.x names, kept as aliases"

# an unknown verb is a usage error: status 2, nothing run
blcli("nonsense")
#> rmoriebricklayer: unknown verb 'nonsense'; try `rmoriebricklayer help`, or `rmoriebricklayer ask "QUESTION"` for a model

# check a capsule as the rmbl GitHub Action does
d <- usecpstmpl(tempfile("capsule-"), ex = TRUE)
invisible(cpsrfrsh(d))
blcli(c("verify", d))
#> ## rmbl capsule verify with [rmoriebricklayer 1.0.0](https://github.com/rootcoder007/rmorie-bricklayer)
#> 
#> **✔ ok**: 1 capsule under `/tmp/Rtmp147Jzo/capsule-1f46734aff02`: 1 ok, 0 warn, 0 drift, 0 error
#> 
#> | Capsule | Source | SHA-256 | Size | Rows | Bounds | Result |
#> |---|---|---|---|---|---|---|
#> | `/tmp/Rtmp147Jzo/capsule-1f46734aff02` | /tmp/Rtmp147Jzo/temp_libpath1f461d33de48/rmoriebricklayer/extdata/otis_a01_individuals.csv | `6b1a0d2d11f6` | 0.5 KB | - | - | ✔ ok |
#> 
#> <details>
#> <summary>✔ <code>/tmp/Rtmp147Jzo/capsule-1f46734aff02</code>: ok, 7 of 7 checks passed (click to open)</summary>
#> 
#> - Source: /tmp/Rtmp147Jzo/temp_libpath1f461d33de48/rmoriebricklayer/extdata/otis_a01_individuals.csv
#> - Pinned SHA-256: `6b1a0d2d11f62eaffe4a95111286753aca9afc015fc4d0ea07c9953ff3030248`
#> 
#> | Status | Check | Detail |
#> |---|---|---|
#> | ✔ pass | schema: data_provenance.json | valid against capsule.schema.json |
#> | ✔ pass | provenance_readable | /tmp/Rtmp147Jzo/capsule-1f46734aff02/data_provenance.json |
#> | ✔ pass | data_present | /tmp/Rtmp147Jzo/capsule-1f46734aff02/otis_a01_individuals.csv |
#> | ✔ pass | data_sha256 | 6b1a0d2d11f62eaffe4a95111286753aca9afc015fc4d0ea07c9953ff3030248 |
#> | ✔ pass | data_size_bytes | 462 bytes on disk |
#> | ✔ pass | data_readable | /tmp/Rtmp147Jzo/capsule-1f46734aff02/otis_a01_individuals.csv |
#> | ✔ pass | data_not_synthetic | no synthetic marker: sidecar, manifest and provenance all say real data |
#> 
#> </details>
#> 
#> ---
#> 
#> Footprint of these checks (co2fp(), modelled, Green Algorithms): 0.0 s wall, 0.0 s CPU, 0.000107 Wh, 4.92e-05 gCO2e at 458.3 gCO2e/kWh (World, 2025).
#> 
#> ---
#> 
#> mode `verify` · fail-on `error` · rmoriebricklayer 1.0.0 · R version 4.6.1 (2026-06-24)

if (FALSE) { # interactive()
# these read every help page, which takes a few seconds
blcli(c("functions", "json"))
blcli(c("describe", "anltab"))
blcli(c("examples", "perdays"))
}
```
