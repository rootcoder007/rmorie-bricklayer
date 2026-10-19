# JSON serialisation of an R object, type and attributes included

Writes an R object to JSON with its type and attributes alongside the
value, so the round trip returns THE SAME OBJECT rather than something
that merely prints the same. The counterpart of jsonlite's
`serializeJSON()` / `unserializeJSON()`, computed by this package's own
codec with no jsonlite dependency.

## Usage

``` r
jsser(x, digits = 8, pretty = FALSE)

jsunser(txt, trusted = FALSE)
```

## Arguments

- x:

  Object to serialise.

- digits:

  Decimal digits retained for doubles (default 8, the jsonlite default,
  so `1/3` is written as `0.33333333`). `digits = I(17)` writes every
  double exactly (17 significant digits), which makes the round trip
  [`identical()`](https://rdrr.io/r/base/identical.html) for doubles
  too; `NA` means 15 significant digits, as in jsonlite, and is not
  exact. A complex value with only one `NA` part comes back as `NA`, as
  it does in jsonlite.

- pretty:

  Logical scalar, default `FALSE`: indent the output.

- txt:

  Character scalar: JSON produced by `jsser()`.

- trusted:

  `FALSE` (default) rebuilds data types only (vectors, lists, factors,
  matrices, data frames, environments, symbols) and refuses functions,
  calls, expressions, namespaces and S4 objects: rebuilding those runs
  code the JSON's author chose, through
  [`unserialize()`](https://rdrr.io/r/base/serialize.html),
  [`parse()`](https://rdrr.io/r/base/parse.html),
  [`getNamespace()`](https://rdrr.io/r/base/ns-reflect.html) or an
  `initialize` method. Set `TRUE` only for JSON your own session
  produced.

## Value

`jsser()` returns a length-1 character vector of class `json`;
`jsunser()` returns the original object.

## Details

Use this, not
[`tojs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/tojs.md),
whenever the JSON has to reconstruct the object faithfully.
[`tojs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/tojs.md)
writes the DATA – which is what an API or a human wants, and which loses
factor levels, matrix dimensions, classes and every other attribute.
These two keep them, at the cost of JSON no other tool will understand.

## See also

[`tojs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/tojs.md)
for plain data JSON,
[`csha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/csha256.md)
for fingerprinting the result.

## Examples

``` r
# A factor survives the round trip with its levels intact.
f <- factor(c("b", "a", "b"), levels = c("a", "b", "c"))
back <- jsunser(jsser(f))
identical(back, f)
#> [1] TRUE

# So does a matrix, with its dimensions.
m <- matrix(1:6, nrow = 2)
identical(jsunser(jsser(m)), m)
#> [1] TRUE

# Plain data JSON does not keep either, which is the trade-off.
tojs(f)
#> ["b","a","b"] 

# Nested lists, names and NULLs round trip too.
x <- list(a = 1:3, b = list(c = "x", d = NULL), e = TRUE)
identical(jsunser(jsser(x)), x)
#> [1] TRUE

# Doubles are rounded to `digits`; I(17) keeps them exact.
jsser(1/3)
#> {"type":"double","attributes":{},"value":[0.33333333]} 
exact <- jsser(1/3, digits = I(17))
identical(jsunser(exact), 1/3)
#> [1] TRUE

# The serialised form is JSON, so it can be pinned like any other text.
nchar(csha256(jsser(m)))
#> [1] 64

# A function is refused unless the JSON is trusted.
try(jsunser(jsser(function(x) x + 1)))
#> Error : jsunser() refuses to rebuild a 'closure' from JSON it did not write: that would run code chosen by the file's author. Pass trusted = TRUE only for JSON produced by jsser() in your own session.
```
