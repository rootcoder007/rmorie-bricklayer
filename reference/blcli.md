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

  check every capsule under PATH as the rmbl GitHub Action does: each
  file against its JSON Schema
  ([`schemapath`](https://rootcoder007.github.io/rmorie-bricklayer/reference/schemapath.md)),
  [`vrfcps`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfcps.md)
  and
  [`cpsbndlvrf`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsbndl.md).
  The secret of an hmac bundle is read from `RMBL_KEY`, which is then
  removed from the environment. Prints the Markdown report, or JSON with
  `--json`; exits 1 when a failed row is at or above `--fail-on`
  (`error`, the default, `drift` or `warn`)

- `drift PATH [--json] [--fail-on LEVEL]`:

  verify, then fetch each source again: new bytes are a warning,
  drifting columns
  ([`cpsdrft`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md))
  are drift

- `refresh PATH`:

  pin each source's new bytes
  ([`cpsrfrsh`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsrfrsh.md))
  and print what changed
  ([`mnfdiff`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mnfdiff.md))

- `report PATH [--format md|json]`:

  the verify report, exit 0

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
capsule's source (`refresh` writes the capsule); `verify` and `report`
only read the capsule files; `functions`, `describe`, `examples`,
`explain-error`, `version` and `help` only read the installed help.

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
#>   wayback FILE [--out F.jsonl] [--jobs N]   archive every URL in FILE (archive.org keys)
#>   wayback --retry F.jsonl                   retry the failed URLs of an earlier wayback run
#>   functions [PATTERN]                       exported functions and their titles
#>   describe NAME                             help page of one function
#>   examples NAME                             its examples
#>   version                                   package version
#> 
#> Capsules (the checks of the rmbl GitHub Action)
#>   verify PATH [--json] [--fail-on LEVEL]    schemas, digests, bundle signature (hmac secret: RMBL_KEY)
#>   drift PATH [--json] [--fail-on LEVEL]     verify, then fetch each source and compare it with the pin
#>   refresh PATH                              pin each source's new bytes in its provenance
#>   report PATH [--format md|json]            the verify report; never fails
#> 
#> More help
#>   rmoriebricklayer help start      getting started, step by step
#>   rmoriebricklayer help llm        every way to point ask at a model (your key, Ollama, your own server)
#>   rmoriebricklayer help config     every setting, its environment variable, and examples
#>   rmoriebricklayer help r          the same from R and Rscript
#>   rmoriebricklayer VERB --help     one verb's usage
blcli(c("functions", "json"))
#>   bricklayer_json_base64_dec     The 0.5.x names, kept as aliases
#>   bricklayer_json_base64_enc     The 0.5.x names, kept as aliases
#>   bricklayer_json_base64url_dec  The 0.5.x names, kept as aliases
#>   bricklayer_json_base64url_enc  The 0.5.x names, kept as aliases
#>   bricklayer_json_from_json      Old names kept for rmoriedata 0.3.x
#>   bricklayer_json_serialize      The 0.5.x names, kept as aliases
#>   bricklayer_json_to_json        Old names kept for rmoriedata 0.3.x
#>   bricklayer_json_unserialize    The 0.5.x names, kept as aliases
#>   json_gzip_decode               The 0.5.x names, kept as aliases
#>   json_gzip_encode               The 0.5.x names, kept as aliases
#>   write_manifest_json            The 0.5.x names, kept as aliases
#>   yoy_json                       The 0.5.x names, kept as aliases
blcli(c("describe", "anltab"))
#> Analyse a published administrative table in one call
#> 
#> Description:
#> 
#>      The questions asked of a published table are always the same:
#>      what is in it, what changed between periods and how sure can one
#>      be, what the rates are if there is an exposure, whether a short
#>      series trends, and whether this release differs from the one
#>      held before. Each has a function in this package; this runs them
#>      together, with the pieces a reviewer needs and that are easy to
#>      forget on a deadline: exact intervals on every change,
#>      multiple-comparison adjustment over the groups scanned, the
#>      envelope that rounding and suppression in the release imply, and
#>      a drift screen against the prior capsule.
#> 
#> Usage:
#> 
#>      anltab(
#>        data,
#>        value,
#>        prd,
#>        by = NULL,
#>        pop = NULL,
#>        prior = NULL,
#>        units = c("count", "continuous", "percent"),
#>        rnd = NULL,
#>        rndkind = c("nearest", "random"),
#>        suplim = NULL,
#>        dir = c("neutral", "higher", "lower"),
#>        per = 1000,
#>        conflvl = 0.95,
#>        alpha = 0.05,
#>        adjust = "BH"
#>      )
#>      
#> Arguments:
#> 
#>     data: A data frame in long form: one row per period and group.
#> 
#>    value: Name of the column (a string) with the published count (or
#>           measure).
#> 
#>      prd: Name of the column with the period (fiscal year, quarter,
#>           ...); numeric periods are used as the time axis of the
#>           trend tests.
#> 
#>       by: Optional character vector of grouping column names
#>           (institution, region, ...). ‘NULL’ (the default) treats the
#>           table as one series.
#> 
#>      pop: Optional name of an exposure column for rates (‘NULL’, the
#>           default, skips the rate step).
#> 
#>    prior: Optional data frame: the previous capsule of the same
#>           table, for the drift screen. ‘NULL’ (the default) skips it.
#> 
#>    units: ‘"count"’ (the default), ‘"continuous"’ or ‘"percent"’, as
#>           in ‘yoy()’.
#> 
#> rnd, rndkind, suplim: How the release rounds or suppresses cells; see
#>           ‘pubbnd()’. ‘rnd’ is the rounding base (for example 5),
#>           ‘rndkind’ ‘"nearest"’ (the default) or ‘"random"’, ‘suplim’
#>           the threshold below which cells are suppressed. ‘NULL’ when
#>           the counts are exact. Used only for counts: with other
#>           ‘units’ they are ignored, with a warning.
#> 
#>      dir: Which way is an improvement, as in ‘yoy()’: ‘"neutral"’
#>           (the default), ‘"higher"’ or ‘"lower"’.
#> 
#>      per: Rate denominator, as in ‘rtcalc()’; default 1000 (rates per
#>           1,000 of ‘pop’).
#> 
#>  conflvl: Confidence level for every interval, default 0.95.
#> 
#>    alpha: Level for the multiple-comparison decision and the drift
#>           screens, default 0.05.
#> 
#>   adjust: Multiple-comparison method for ‘scanadj()’. The default is
#>           ‘"BH"’ (Benjamini-Hochberg).
#> 
#> Details:
#> 
#>      The steps, in order:
#> 
#>        1. profile: ‘profcols()’ and ‘misssmry()’ on ‘data’;
#> 
#>        2. change: ‘yoy()’ between consecutive periods within each
#>           ‘by’ group. For ‘units = "count"’ the exact p-values are
#>           then adjusted across all comparisons with ‘scanadj()’, and,
#>           when ‘rnd’ or ‘suplim’ is given, ‘yoybnd()’ adds the
#>           publication envelope (see ‘pubbnd()’). For ‘"continuous"’
#>           and ‘"percent"’ units neither step runs: ‘rnd’ and ‘suplim’
#>           are then ignored, with a warning;
#> 
#>        3. rates (only with ‘pop’): ‘rtcalc()’ per group and period,
#>           and ‘ratechg()’ between periods, adjusted with ‘scanadj()’;
#> 
#>        4. trend: per group, the values summed within each period,
#>           then ‘trndtst()’ (Mann-Kendall tau, p-value and Theil-Sen
#>           slope) and, for counts, ‘cnttrnd()’ (Poisson rate ratio per
#>           period). A group with fewer than three periods gets ‘NA’; a
#>           test that fails gets ‘NA’ rather than an error;
#> 
#>        5. drift (only with ‘prior’): ‘cpsdrft()’ of ‘data’ against
#>           ‘prior’.
#> 
#>      Nothing is written and nothing is fetched; a progress bar for
#>      the trend step is drawn on stderr unless ‘options(morie.quiet =
#>      TRUE)’. Errors: ‘data’ or ‘prior’ not a data frame; a named
#>      column not in ‘data’; an invalid ‘units’, ‘dir’ or ‘rndkind’; a
#>      ‘conflvl’ outside (0, 1); and any error of the functions called
#>      (for example negative counts in ‘yoy()’).
#> 
#> Value:
#> 
#>      A list of class ‘bricklayer_analysis’ (with a print method that
#>      summarises it in a few lines):
#> 
#>      ‘profile’
#>           ‘profcols()’ of ‘data’.
#> 
#>      ‘missingness’
#>           named numeric from ‘misssmry()’.
#> 
#>      ‘change’
#>           the ‘yoy()’ table; for counts with the added columns
#>           ‘p_value’, ‘padj’ and ‘significant’, and with ‘env_*’ and
#>           ‘compctlo’/‘compctup’ when publication bounds were
#>           requested.
#> 
#>      ‘rates’, ‘ratechg’
#>           the ‘rtcalc()’ and ‘ratechg()’ tables when ‘population’ is
#>           given, otherwise ‘NULL’.
#> 
#>      ‘trend’
#>           data frame with one row per group: the ‘by’ columns,
#>           ‘periods’, ‘first’, ‘last’, ‘tau’, ‘trndp’, ‘slope’,
#>           ‘rateratio’, ‘rateratiolo’, ‘rateratioup’.
#> 
#>      ‘drift’
#>           ‘cpsdrft()’ result against ‘prior’, or ‘NULL’.
#> 
#>      ‘meta’
#>           list of the arguments used, ‘nrows’, the sorted ‘periods’,
#>           ‘prior’ (logical) and ‘when’ (a time stamp).
#> 
#> See Also:
#> 
#>      ‘rptanl()’ writes the result as a Markdown or HTML report.
#> 

# one verb's usage, and the examples of a help page
blcli(c("help", "data"))
#> usage: rmoriebricklayer data list | data pull db/table [--out FILE.csv]   curated tables at data.rmorie.com (your MORIE key)
blcli(c("examples", "perdays"))
#> 
#>      perdays("2024-01-01", "2024-12-31") # a leap year
#>      perdays("2023-01-01", "2023-12-31")
#>      perdays("2025-04-01", "2026-03-31") # a fiscal year
#>      
#>      # a quarter as the period of an average daily population
#>      adp(4200, t = perdays(as.Date("2025-01-01"), as.Date("2025-03-31")))
#>      
#>      # numbers are not dates, and the end cannot come first
#>      try(perdays(1, 31))
#>      try(perdays("2024-12-31", "2024-01-01"))
#>      

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
#> **✔ ok**: 1 capsule under `/tmp/RtmpsKAgL4/capsule-1e076c4ee035`: 1 ok, 0 warn, 0 drift, 0 error
#> 
#> | Capsule | Source | SHA-256 | Size | Rows | Bounds | Result |
#> |---|---|---|---|---|---|---|
#> | `/tmp/RtmpsKAgL4/capsule-1e076c4ee035` | /tmp/RtmpsKAgL4/temp_libpath1e0721705800/rmoriebricklayer/extdata/otis_a01_individuals.csv | `6b1a0d2d11f6` | 0.5 KB | - | - | ✔ ok |
#> 
#> <details>
#> <summary>✔ <code>/tmp/RtmpsKAgL4/capsule-1e076c4ee035</code>: ok, 7 of 7 checks passed (click to open)</summary>
#> 
#> | | Check | Detail |
#> |---|---|---|
#> | ✔ | schema: data_provenance.json | valid against capsule.schema.json |
#> | ✔ | provenance_readable | /tmp/RtmpsKAgL4/capsule-1e076c4ee035/data_provenance.json |
#> | ✔ | data_present | /tmp/RtmpsKAgL4/capsule-1e076c4ee035/otis_a01_individuals.csv |
#> | ✔ | data_sha256 | 6b1a0d2d11f62eaffe4a95111286753aca9afc015fc4d0ea07c9953ff3030248 |
#> | ✔ | data_size_bytes | 462 bytes on disk |
#> | ✔ | data_readable | /tmp/RtmpsKAgL4/capsule-1e076c4ee035/otis_a01_individuals.csv |
#> | ✔ | data_not_synthetic | no synthetic marker: sidecar, manifest and provenance all say real data |
#> 
#> </details>
#> 
#> ---
#> 
#> mode `verify` · rmoriebricklayer 1.0.0 · R version 4.6.1 (2026-06-24)
```
