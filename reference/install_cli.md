# Install the rmoriebricklayer command-line launcher

Links the launcher shipped in the package (`inst/bin/rmoriebricklayer`)
into a directory on your PATH so that `rmoriebricklayer login`,
`rmoriebricklayer ask ...` and the other verbs of
[`bricklayer_cli`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_cli.md)
work from any shell. On Windows a `rmoriebricklayer.cmd` wrapper is
written instead of a symlink. Nothing outside `dir` is touched, and only
when you call this.

## Usage

``` r
install_cli(
  dir = file.path(path.expand("~"), ".local", "bin"),
  name = "rmoriebricklayer"
)
```

## Arguments

- dir:

  Target directory (default `~/.local/bin`; created if absent).

- name:

  Command name (default `rmoriebricklayer`).

## Value

The path of the installed launcher, invisibly.

## Examples

``` r
if (FALSE) { # \dontrun{
install_cli()
} # }
```
