# Run the rmoriebricklayer command line

Dispatches the verbs of the `rmoriebricklayer` launcher:

- `login [--token [KEY]] [--email ADDRESS [--code CODE]] [--no-browser]`:

  sign in to the hosted MORIE tier (a last resort behind a local model
  or your own endpoint; keys are issued on request at
  <https://www.rmorie.com/access/>): a key you paste with `--token`
  (read from the terminal or a pipe when KEY is omitted), a code sent to
  `--email`, or the GitHub device flow

- `logout`:

  forget the hosted key

- `doctor`:

  report the language-model routes available here (own endpoint, local
  Ollama, hosted tier), in the order `ask` tries them

- `models`:

  list the models the hosted tier offers your key (default marked)

- `data list`:

  the curated tables at data.rmorie.com

- `data pull db/table`:

  download one table as CSV

- `config [setup | set KEY VALUE | unset KEY | get KEY | help]`:

  show or change the language-model settings
  ([`bricklayer_llm_config`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_config.md)):
  the route `ask` uses and the address, key and model of each route;
  `setup` walks through them

- `ask [--route ROUTE] [--model NAME] PROMPT...`:

  send a prompt to the model (or the named one, on the named route) and
  print the reply

- `bundle REQUEST...`:

  [`agent_bundle`](https://rootcoder007.github.io/rmorie-bricklayer/reference/agent_bundle.md)
  from the shell

- `functions [PATTERN]`:

  list the exported functions with their one-line titles, optionally
  filtered by a regular expression

- `describe NAME`:

  title, usage, arguments and description of one function, from its help
  page

- `examples NAME`:

  print the examples of one function

- `version`:

  print the package version

- `help`:

  this list

## Usage

``` r
bricklayer_cli(args = commandArgs(trailingOnly = TRUE), out = cat)
```

## Arguments

- args:

  Character vector of arguments; defaults to the command line.

- out:

  Function that receives the output text (default: the console).

## Value

The exit status, invisibly (0 on success).

## Examples

``` r
bricklayer_cli("version")
#> rmoriebricklayer 0.5.11
bricklayer_cli("help")
#> usage: rmoriebricklayer <verb> [options]   (rmbl is the same command as rmoriebricklayer)
#> 
#> Language models
#>   ask [--route R] [--model NAME] PROMPT...  ask a model and print the reply
#>   doctor                                    what is set up, and which route ask will use
#>   config                                    show every language-model setting
#>   config setup                              answer a few questions to set them all
#>   config set KEY VALUE | unset KEY          change one (keys: config help)
#>   login [--token [KEY]] [--email ADDRESS]   sign in to the hosted MORIE tier
#>         [--code CODE] [--no-browser]
#>   logout                                    forget the hosted key
#>   models                                    models the hosted tier offers your key
#>   bundle REQUEST...                         agent_bundle() from the shell
#> 
#> Data and functions
#>   data list                                 curated tables at data.rmorie.com
#>   data pull db/table [--out FILE.csv]       download one of them (your MORIE key)
#>   functions [PATTERN]                       exported functions and their titles
#>   describe NAME                             help page of one function
#>   examples NAME                             its examples
#>   version                                   package version
#> 
#> More help
#>   rmoriebricklayer help start      getting started, step by step
#>   rmoriebricklayer help llm        every way to point ask at a model (hosted, Ollama, your own server)
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
#>    value: Column with the published count (or measure).
#> 
#>   period: Column with the period (fiscal year, quarter, ...).
#> 
#>       by: Optional grouping columns (institution, region, ...).
#> 
#> population: Optional exposure column for rates.
#> 
#>    prior: Optional data frame: the previous capsule of the same
#>           table, for the drift screen.
#> 
#>    units: ‘"count"’, ‘"continuous"’ or ‘"percent"’, as in ‘yoy()’.
#> 
#> rounding, rounding_kind, suppression_limit: How the release rounds or
#>           suppresses cells; see ‘published_bounds()’. ‘NULL’ when the
#>           counts are exact.
#> 
#> direction: Which way is an improvement, as in ‘yoy()’.
#> 
#>      per: Rate denominator, as in ‘rate()’.
#> 
#> conf_level: Confidence level for every interval.
#> 
#>    alpha: Level for the multiple-comparison decision and the drift
#>           screens.
#> 
#>   adjust: Multiple-comparison method for ‘scan_adjust()’.
#> 
#> Value:
#> 
#>      A list of class ‘bricklayer_analysis’ with ‘profile’
#>      (‘profile_columns()’), ‘missingness’ (‘missingness_summary()’),
#>      ‘change’ (‘yoy()’ with p-values, adjustment and, if ‘rounding’
#>      or ‘suppression_limit’ was given, publication bounds), ‘rates’
#>      and ‘rate_change’ (when ‘population’ is given), ‘trend’ (one row
#>      per group with ‘trend_test()’ and, for counts, ‘count_trend()’),
#>      ‘drift’ (‘capsule_drift()’ against ‘prior’), and ‘meta’.
#> 
#> See Also:
#> 
#>      ‘report_analysis()’ writes the result as a Markdown or HTML
#>      report.
#> 
```
