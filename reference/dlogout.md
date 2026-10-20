# Forget the MORIE data key

Removes the MORIE data key that
[`dlogin`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dlogin.md)
stored, so this machine can no longer load the curated tables at
data.rmorie.com until you sign in again. Use it on a shared machine, or
to switch to another key. Nothing is contacted.

## Usage

``` r
dlogout()
```

## Value

Logical scalar, invisibly: `TRUE` when a key was removed, `FALSE` when
none was stored.

## Details

The shared credentials file is `credentials.json` in the folder
`$XDG_CONFIG_HOME/morie`, else in `~/.config/morie`. It is edited as
text. Three members are removed: `hosted_key`, `hosted_user` and
`hosted_base_url`. Every other entry (written by `morie`, `rmorie` or
`rmoriedata`) is kept byte for byte. When nothing else is left the file
is deleted. A key set in the environment variable `MORIE_HOSTED_KEY` is
not touched. A message says whether a key was removed.

Errors when the file is not a JSON object (or not valid JSON, or names a
member twice), and when the key cannot be removed without damaging the
file; in both cases the file is left as it was.

## See also

[`dlogin`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dlogin.md).

## Examples

``` r
old <- Sys.getenv("XDG_CONFIG_HOME", unset = NA)
Sys.setenv(XDG_CONFIG_HOME = tempfile())   # a scratch credentials folder

# nothing stored yet
dlogout()
#> No MORIE data key was stored.

# a file holding a key and another tool's entry: only the key goes
d <- file.path(Sys.getenv("XDG_CONFIG_HOME"), "morie")
dir.create(d, recursive = TRUE)
writeLines('{"hosted_key": "k-123", "other_tool": 1}', file.path(d, "credentials.json"))
dlogout()
#> Logged out: the MORIE data key was removed.
readLines(file.path(d, "credentials.json"))
#> [1] "{\"other_tool\": 1}"

# a damaged file is refused, not overwritten
writeLines("not json", file.path(d, "credentials.json"))
try(dlogout())
#> Error : /tmp/RtmpgLYJrZ/file1ed04fe66bc9/morie/credentials.json is not a JSON object (or not valid JSON, or lists a key twice); fix or remove it (it is shared with morie and rmorie)

if (is.na(old)) Sys.unsetenv("XDG_CONFIG_HOME") else Sys.setenv(XDG_CONFIG_HOME = old)
```
