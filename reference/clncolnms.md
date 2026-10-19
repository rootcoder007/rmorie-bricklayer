# Tidy the column names of an ingested table

Converts column names to a consistent, syntactically valid form:
transliterated to ASCII, non-alphanumerics collapsed to a single
separator, and duplicates disambiguated with a numeric suffix. The
counterpart of `janitor::clean_names()`. Use it right after reading an
open-data file, so the rest of the script can refer to columns without
backticks.

## Usage

``` r
clncolnms(
  data,
  case = c("snake", "lower_camel", "upper_camel", "screaming_snake", "none"),
  sep = "_"
)
```

## Arguments

- data:

  A data frame, or a character vector of names.

- case:

  `"snake"` (default, `total_pop`), `"lower_camel"` (`totalPop`),
  `"upper_camel"` (`TotalPop`), `"screaming_snake"` (`TOTAL_POP`), or
  `"none"` to normalise separators only and keep the letters' case.

- sep:

  Separator, a string, used between words for `"snake"`,
  `"screaming_snake"` and `"none"`, and before the number that
  disambiguates a duplicate in every case (default `"_"`).

## Value

For a data frame, the data frame with new names and an `"orignms"`
attribute (character, the names before cleaning); for a character
vector, the cleaned character vector.

## Details

Open-data extracts arrive with names like `"Total Population (2021)"`
and `"% change"`, which need backticks everywhere and break silently
when a re-release renames `"% change"` to `"% Change"` or adds a
trailing space. Normalising once at ingestion makes the schema stable
against that.

The steps, in order: transliterate to ASCII
(`iconv(..., "ASCII//TRANSLIT")`, keeping the original where that
fails); replace `%` by `pct`, `&` by `and` and `#` by `n` as words;
split camelCase at a lower-to-upper boundary; turn every run of other
characters into one word break; an empty name becomes `x`; join the
words in the chosen case; prefix `x` to a name starting with a digit;
and give repeated names the suffixes `<sep>2`, `<sep>3`, ... in order of
appearance (the first keeps its name). The transliteration depends on
the platform's iconv, so an accented letter may come out slightly
differently on different systems.

Record the mapping in the capsule manifest. Cleaning names changes what
a downstream script must refer to, so an unrecorded cleaning is itself a
reproducibility hazard – the returned object carries the original names
in its `"orignms"` attribute for exactly that.

## Examples

``` r
clncolnms(c("Total  Population (2021)", "% change",
                     "Ville / City", "dup", "dup"))
#> [1] "total_population_2021" "pct_change"            "ville_city"           
#> [4] "dup"                   "dup_2"                

# Applied to a data frame, with the original names retained.
df <- data.frame(`Total Pop` = 1:2, `% change` = 3:4,
                 check.names = FALSE)
cleaned <- clncolnms(df)
names(cleaned)
#> [1] "total_pop"  "pct_change"
attr(cleaned, "orignms")
#> [1] "Total Pop" "% change" 

# Other cases.
clncolnms(c("Total Pop"), case = "lower_camel")
#> [1] "totalPop"
clncolnms(c("Total Pop"), case = "upper_camel")
#> [1] "TotalPop"
clncolnms(c("Total Pop"), case = "screaming_snake")
#> [1] "TOTAL_POP"

# a different separator, and a name that starts with a digit
clncolnms(c("2021 count", "Rate per 1000"), sep = ".")
#> [1] "x2021.count"   "rate.per.1000"

# an unknown case is an error
try(clncolnms("a b", case = "kebab"))
#> Error : `case` must be one of "snake", "lower_camel", "upper_camel", "screaming_snake", "none", not "kebab"
```
