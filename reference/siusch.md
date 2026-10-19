# The panel-reviewed SIU report field schema

Returns the sixteen fields that the package extracts from every Ontario
Special Investigations Unit (SIU) director's report, with a one-line
description of each. Use it to see what
[`siuprs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/siuprs.md)
returns, to build an empty coding sheet for hand review, or to check
which fields are counts before summing them across reports.

## Usage

``` r
siusch()
```

## Value

A data.frame with 16 rows and three columns: `name` (character, the
field name used by
[`siuprs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/siuprs.md)),
`count` (logical, `TRUE` for the five count fields) and `description`
(character, what the field records).

## Details

The schema is held in the native core (src/siu_schema.h) and is the same
list that
[`siuprs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/siuprs.md)
fills. Three fields are dates in ISO `YYYY-MM-DD` form, five are counts
and the rest are free text. Count-type fields (`count = TRUE`) count
distinct entities, and zero is a real answer: a witness-official-only
investigation has zero subject officials. The function takes no
arguments, reads no files and uses no network.

## Examples

``` r
s <- siusch()
s$name
#>  [1] "police_service"                "date_of_incident_iso"         
#>  [3] "date_siu_notified_iso"         "date_of_director_decision_iso"
#>  [5] "siu_investigators"             "siu_forensics_investigators"  
#>  [7] "number_of_witness_officials"   "number_of_civilian_witnesses" 
#>  [9] "number_of_subject_officials"   "age_affected"                 
#> [11] "sex_gender_affected"           "charges_recommended"          
#> [13] "directors_name"                "location_of_call"             
#> [15] "specific_injuries"             "relevant_legislation"         

# only the count fields
s[s$count, c("name", "description")]
#>                           name
#> 5            siu_investigators
#> 6  siu_forensics_investigators
#> 7  number_of_witness_officials
#> 8 number_of_civilian_witnesses
#> 9  number_of_subject_officials
#>                                                                                        description
#> 5                                                         the number of SIU investigators assigned
#> 6                                                the number of SIU forensic investigators assigned
#> 7                                            the count of distinct WITNESS officers/officials (WO)
#> 8                                                    the count of distinct civilian witnesses (CW)
#> 9 the count of distinct SUBJECT officers/officials (SO); a witness-officer-only investigation is 0

# an empty hand-coding sheet with one column per field
sheet <- as.data.frame(setNames(replicate(nrow(s), character(0), simplify = FALSE),
                                 s$name))
ncol(sheet)
#> [1] 16
```
