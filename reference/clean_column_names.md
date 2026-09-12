# Tidy the column names of an ingested table

Converts names to a consistent, syntactically valid form: transliterated
to ASCII, non-alphanumerics collapsed to a single separator, and
duplicates disambiguated with a numeric suffix. The counterpart of
`janitor::clean_names()`.

## Usage

``` r
clean_column_names(
  data,
  case = c("snake", "lower_camel", "upper_camel", "screaming_snake", "none"),
  sep = "_"
)
```

## Arguments

- data:

  A data frame, or a character vector of names.

- case:

  `"snake"` (default), `"lower_camel"`, `"upper_camel"`,
  `"screaming_snake"`, or `"none"` to normalise separators only.

- sep:

  Separator for `"snake"` and `"screaming_snake"` (default `"_"`) .

## Value

The data frame with new names (and an `"original_names"` attribute), or
the cleaned character vector.

## Details

Open-data extracts arrive with names like `"Total Population (2021)"`
and `"% change"`, which need backticks everywhere and break silently
when a re-release renames `"% change"` to `"% change"`. Normalising once
at ingestion makes the schema stable against that.

Record the mapping in the capsule manifest. Cleaning names changes what
a downstream script must refer to, so an unrecorded cleaning is itself a
reproducibility hazard – the returned object carries the original names
in its `"original_names"` attribute for exactly that.

## Examples

``` r
clean_column_names(c("Total  Population (2021)", "% change",
                     "Ville / City", "dup", "dup"))
#> [1] "total_population_2021" "pct_change"            "ville_city"           
#> [4] "dup"                   "dup_2"                

# Applied to a data frame, with the original names retained.
df <- data.frame(`Total Pop` = 1:2, `% change` = 3:4,
                 check.names = FALSE)
cleaned <- clean_column_names(df)
names(cleaned)
#> [1] "total_pop"  "pct_change"
attr(cleaned, "original_names")
#> [1] "Total Pop" "% change" 

# Other cases.
clean_column_names(c("Total Pop"), case = "lower_camel")
#> [1] "totalPop"
clean_column_names(c("Total Pop"), case = "upper_camel")
#> [1] "TotalPop"
clean_column_names(c("Total Pop"), case = "screaming_snake")
#> [1] "TOTAL_POP"
```
