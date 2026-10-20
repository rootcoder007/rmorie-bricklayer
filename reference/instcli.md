# Install the rmoriebricklayer command-line launcher

Writes small launcher scripts into a directory on your PATH so that
`rmoriebricklayer login`, `rmbl ask ...` and the other verbs of
[`blcli`](https://rootcoder007.github.io/rmorie-bricklayer/reference/blcli.md)
work from any shell. Run it once after installing or upgrading the
package. Nothing outside `dir` is touched, and only when you call this.

## Usage

``` r
instcli(
  dir = file.path(path.expand("~"), ".local", "bin"),
  name = c("rmoriebricklayer", "rmbl")
)
```

## Arguments

- dir:

  Character scalar, the target directory; default `~/.local/bin`.
  Created (with its parents) if absent.

- name:

  Character vector of command names to install; default both
  `rmoriebricklayer` and its short form `rmbl` (every verb works under
  either).

## Value

The path of the first launcher written (normally `rmoriebricklayer`),
invisibly; the others are written beside it.

## Details

On Unix-alikes each launcher is a `/bin/sh` script (mode 0755) that sets
`RMBL_PROG` to its own name and runs
`Rscript -e "rmoriebricklayer::blcli()"` with the shell's arguments,
exiting with the function's status (130 on Ctrl-C). The library this
copy of the package is installed in is pinned inside R with
[`.libPaths()`](https://rdrr.io/r/base/libPaths.html), so an `R_LIBS`
set in the shell or in `~/.Renviron` cannot make the command run another
copy. An existing file or link of the same name in `dir` is replaced. On
Windows a `NAME.cmd` batch wrapper doing the same is written instead. A
message names the files written and, when `dir` is not on the `PATH`,
says to add it. Re-run it after moving the package to another library.

Errors when the package installation has no launcher in `inst/bin` (a
damaged installation); when `dir` cannot be created or written, or is
not one string; and when `name` is not a character vector of one or more
command names (empty, `NA`, an empty string or a name with a directory
part is refused).

## See also

[`blcli`](https://rootcoder007.github.io/rmorie-bricklayer/reference/blcli.md)
for the verbs.

## Examples

``` r
# into a scratch folder, so nothing on your PATH changes
d <- file.path(tempdir(), "bin")
p <- instcli(dir = d)
#> Installed /tmp/RtmpxAJGDE/bin/rmoriebricklayer and /tmp/RtmpxAJGDE/bin/rmbl; add /tmp/RtmpxAJGDE/bin to your PATH
list.files(d)
#> [1] "rmbl"             "rmoriebricklayer"
readLines(p)[1:4]
#> [1] "#!/bin/sh"                                                                                        
#> [2] "# rmoriebricklayer: the rmoriebricklayer command line (written by rmoriebricklayer::instcli())"   
#> [3] "# runs the package in /tmp/RtmpxAJGDE/temp_libpath1e17383cacc8 (pinned with .libPaths() inside R)"
#> [4] "export RMBL_PROG=rmoriebricklayer"                                                                

# one name only
instcli(dir = d, name = "rmbl")
#> Installed /tmp/RtmpxAJGDE/bin/rmbl; add /tmp/RtmpxAJGDE/bin to your PATH

if (FALSE) { # interactive()
instcli()   # ~/.local/bin/rmoriebricklayer and ~/.local/bin/rmbl
}
```
