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

  show or change the language-model settings
  ([`bricklayer_llm_config`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_config.md)):
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
  ([`bricklayer_explain_error`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_explain_error.md)),
  without a model or the network

- `bundle REQUEST...`:

  [`agent_bundle`](https://rootcoder007.github.io/rmorie-bricklayer/reference/agent_bundle.md)
  from the shell

- `wayback FILE [--out FILE.jsonl] [--jobs N] [--within 30d] [--max N]`:

  save every URL listed in FILE (one per line; blank lines and `#`
  comments skipped) in the Internet Archive's Wayback Machine with
  [`wayback_save`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wayback_save.md),
  results in `--out` (default `FILE.wayback.jsonl`), so a stopped run
  carries on; `wayback --retry FILE.jsonl [--include-gone]` retries the
  failures of an earlier run
  ([`wayback_retry`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wayback_retry.md))

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
[`install_cli`](https://rootcoder007.github.io/rmorie-bricklayer/reference/install_cli.md)
calls this function with the shell's arguments and exits with its
status. Calling it from R is the same as typing the command, which is
how the examples below work.

## Usage

``` r
bricklayer_cli(args = commandArgs(trailingOnly = TRUE), out = cat)
```

## Arguments

- args:

  Character vector of arguments, verb first; defaults to the command
  line (`commandArgs(trailingOnly = TRUE)`). An empty vector prints the
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
sets it) and `options(rmoriebricklayer.data_cache)` is not, the
data.rmorie.com manifest and tables are kept in
`tools::R_user_dir("rmoriebricklayer", "cache")` rather than a fresh
temporary folder. The verbs `login`, `logout` and `config` write the
shared credentials and settings files; `ask`, `models`, `data`, `bundle`
and `wayback` use the network; `functions`, `describe`, `examples`,
`explain-error`, `version` and `help` only read the installed help.

## See also

[`install_cli`](https://rootcoder007.github.io/rmorie-bricklayer/reference/install_cli.md)
to put the command on your PATH.

## Examples

``` r
bricklayer_cli("version")
#> rmoriebricklayer 0.5.14
bricklayer_cli("help")
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
#>   bundle REQUEST...                         agent_bundle() from the shell
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
#> More help
#>   rmoriebricklayer help start      getting started, step by step
#>   rmoriebricklayer help llm        every way to point ask at a model (your key, Ollama, your own server)
#>   rmoriebricklayer help config     every setting, its environment variable, and examples
#>   rmoriebricklayer help r          the same from R and Rscript
#>   rmoriebricklayer VERB --help     one verb's usage
bricklayer_cli(c("functions", "json"))
#>   bricklayer_json_base64_dec     Base64 encoding
#>   bricklayer_json_base64_enc     Base64 encoding
#>   bricklayer_json_base64url_dec  Base64 encoding
#>   bricklayer_json_base64url_enc  Base64 encoding
#>   bricklayer_json_from_json      Parse JSON into R objects (jsonlite's fromJSON, natively)
#>   bricklayer_json_serialize      JSON serialisation of an R object, type and attributes included
#>   bricklayer_json_to_json        Encode an R object as JSON (jsonlite's toJSON, natively)
#>   bricklayer_json_unserialize    JSON serialisation of an R object, type and attributes included
#>   json_gzip_decode               Compressed, base64-encoded JSON
#>   json_gzip_encode               Compressed, base64-encoded JSON
#>   write_manifest_json            Write a Manifest to JSON
#>   yoy_json                       Write a change table as delimited text, JSON or Markdown
bricklayer_cli(c("describe", "analyse_table"))
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
#>      analyse_table(
#>        data,
#>        value,
#>        period,
#>        by = NULL,
#>        population = NULL,
#>        prior = NULL,
#>        units = c("count", "continuous", "percent"),
#>        rounding = NULL,
#>        rounding_kind = c("nearest", "random"),
#>        suppression_limit = NULL,
#>        direction = c("neutral", "higher_is_better", "lower_is_better"),
#>        per = 1000,
#>        conf_level = 0.95,
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
#>   period: Name of the column with the period (fiscal year, quarter,
#>           ...); numeric periods are used as the time axis of the
#>           trend tests.
#> 
#>       by: Optional character vector of grouping column names
#>           (institution, region, ...). ‘NULL’ (the default) treats the
#>           table as one series.
#> 
#> population: Optional name of an exposure column for rates (‘NULL’,
#>           the default, skips the rate step).
#> 
#>    prior: Optional data frame: the previous capsule of the same
#>           table, for the drift screen. ‘NULL’ (the default) skips it.
#> 
#>    units: ‘"count"’ (the default), ‘"continuous"’ or ‘"percent"’, as
#>           in ‘yoy()’.
#> 
#> rounding, rounding_kind, suppression_limit: How the release rounds or
#>           suppresses cells; see ‘published_bounds()’. ‘rounding’ is
#>           the rounding base (for example 5), ‘rounding_kind’
#>           ‘"nearest"’ (the default) or ‘"random"’,
#>           ‘suppression_limit’ the threshold below which cells are
#>           suppressed. ‘NULL’ when the counts are exact. Used only for
#>           counts: with other ‘units’ they are ignored, with a
#>           warning.
#> 
#> direction: Which way is an improvement, as in ‘yoy()’: ‘"neutral"’
#>           (the default), ‘"higher_is_better"’ or ‘"lower_is_better"’.
#> 
#>      per: Rate denominator, as in ‘rate()’; default 1000 (rates per
#>           1,000 of ‘population’).
#> 
#> conf_level: Confidence level for every interval, default 0.95.
#> 
#>    alpha: Level for the multiple-comparison decision and the drift
#>           screens, default 0.05.
#> 
#>   adjust: Multiple-comparison method for ‘scan_adjust()’, default
#>           ‘"BH"’ (Benjamini-Hochberg).
#> 
#> Details:
#> 
#>      The steps, in order:
#> 
#>        1. profile: ‘profile_columns()’ and ‘missingness_summary()’ on
#>           ‘data’;
#> 
#>        2. change: ‘yoy()’ between consecutive periods within each
#>           ‘by’ group. For ‘units = "count"’ the exact p-values are
#>           then adjusted across all comparisons with ‘scan_adjust()’,
#>           and, when ‘rounding’ or ‘suppression_limit’ is given,
#>           ‘yoy_bounds()’ adds the publication envelope (see
#>           ‘published_bounds()’). For ‘"continuous"’ and ‘"percent"’
#>           units neither step runs: ‘rounding’ and ‘suppression_limit’
#>           are then ignored, with a warning;
#> 
#>        3. rates (only with ‘population’): ‘rate()’ per group and
#>           period, and ‘rate_change()’ between periods, adjusted with
#>           ‘scan_adjust()’;
#> 
#>        4. trend: per group, the values summed within each period,
#>           then ‘trend_test()’ (Mann-Kendall tau, p-value and
#>           Theil-Sen slope) and, for counts, ‘count_trend()’ (Poisson
#>           rate ratio per period). A group with fewer than three
#>           periods gets ‘NA’; a test that fails gets ‘NA’ rather than
#>           an error;
#> 
#>        5. drift (only with ‘prior’): ‘capsule_drift()’ of ‘data’
#>           against ‘prior’.
#> 
#>      Nothing is written and nothing is fetched; a progress bar for
#>      the trend step is drawn on stderr unless ‘options(morie.quiet =
#>      TRUE)’. Errors: ‘data’ or ‘prior’ not a data frame; a named
#>      column not in ‘data’; an invalid ‘units’, ‘direction’ or
#>      ‘rounding_kind’; a ‘conf_level’ outside (0, 1); and any error of
#>      the functions called (for example negative counts in ‘yoy()’).
#> 
#> Value:
#> 
#>      A list of class ‘bricklayer_analysis’ (with a print method that
#>      summarises it in a few lines):
#> 
#>      ‘profile’
#>           ‘profile_columns()’ of ‘data’.
#> 
#>      ‘missingness’
#>           named numeric from ‘missingness_summary()’.
#> 
#>      ‘change’
#>           the ‘yoy()’ table; for counts with the added columns
#>           ‘p_value’, ‘p_adjusted’ and ‘significant’, and with ‘env_*’
#>           and ‘combined_pct_lower’/‘combined_pct_upper’ when
#>           publication bounds were requested.
#> 
#>      ‘rates’, ‘rate_change’
#>           the ‘rate()’ and ‘rate_change()’ tables when ‘population’
#>           is given, otherwise ‘NULL’.
#> 
#>      ‘trend’
#>           data frame with one row per group: the ‘by’ columns,
#>           ‘periods’, ‘first’, ‘last’, ‘tau’, ‘trend_p’, ‘slope’,
#>           ‘rate_ratio’, ‘rate_ratio_lower’, ‘rate_ratio_upper’.
#> 
#>      ‘drift’
#>           ‘capsule_drift()’ result against ‘prior’, or ‘NULL’.
#> 
#>      ‘meta’
#>           list of the arguments used, ‘n_rows’, the sorted ‘periods’,
#>           ‘prior’ (logical) and ‘when’ (a time stamp).
#> 
#> See Also:
#> 
#>      ‘report_analysis()’ writes the result as a Markdown or HTML
#>      report.
#> 

# one verb's usage, and the examples of a help page
bricklayer_cli(c("help", "data"))
#> usage: rmoriebricklayer data list | data pull db/table [--out FILE.csv]   curated tables at data.rmorie.com (your MORIE key)
bricklayer_cli(c("examples", "period_days"))
#> 
#>      period_days("2024-01-01", "2024-12-31") # a leap year
#>      period_days("2023-01-01", "2023-12-31")
#>      period_days("2025-04-01", "2026-03-31") # a fiscal year
#>      
#>      # a quarter as the period of an average daily population
#>      adp(4200, t = period_days(as.Date("2025-01-01"), as.Date("2025-03-31")))
#>      
#>      # numbers are not dates, and the end cannot come first
#>      try(period_days(1, 31))
#>      try(period_days("2024-12-31", "2024-01-01"))
#>      

# capture the output instead of printing it
lines <- character()
status <- bricklayer_cli(c("functions", "^drbg_"),
                         out = function(x) lines <<- c(lines, x))
status
#> [1] 0
lines
#> [1] "  drbg_generate  Draw bytes from a DRBG\n"                                                  
#> [2] "  drbg_new       A deterministic random bit generator: AES-256 CTR_DRBG (NIST SP 800-90A)\n"
#> [3] "  drbg_reseed    Reseed a DRBG\n"                                                           

# an unknown verb is a usage error: status 2, nothing run
bricklayer_cli("nonsense")
#> rmoriebricklayer: unknown verb 'nonsense'; try `rmoriebricklayer help`, or `rmoriebricklayer ask "QUESTION"` for a model
```
