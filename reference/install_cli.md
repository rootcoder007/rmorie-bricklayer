# Install the rmoriebricklayer command-line launcher

Links the launcher shipped in the package (`inst/bin/rmoriebricklayer`)
into a directory on your PATH so that `rmoriebricklayer login`,
`rmbl ask ...` and the other verbs of
[`bricklayer_cli`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_cli.md)
work from any shell. On Windows a `rmoriebricklayer.cmd` wrapper is
written instead of a symlink. Nothing outside `dir` is touched, and only
when you call this.

## Usage

``` r
install_cli(
  dir = file.path(path.expand("~"), ".local", "bin"),
  name = c("rmoriebricklayer", "rmbl")
)
```

## Arguments

- dir:

  Target directory (default `~/.local/bin`; created if absent).

- name:

  Command names to install (default both `rmoriebricklayer` and its
  short form `rmbl`; every verb works under either).

## Value

The path of the installed `rmoriebricklayer` launcher, invisibly (`rmbl`
is written beside it).

## Examples

``` r
if (FALSE) { # \dontrun{
install_cli()
} # }
```
