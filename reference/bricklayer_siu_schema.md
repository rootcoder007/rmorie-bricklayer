# The panel-reviewed SIU report field schema

The sixteen fields extracted from every Special Investigations Unit
director's report. Count-type fields (`is_count = TRUE`) count distinct
entities and zero is a real answer – a witness-official-only
investigation has zero subject officials.

## Usage

``` r
bricklayer_siu_schema()
```

## Value

A data.frame with columns `name`, `is_count`, and `description`.

## Examples

``` r
bricklayer_siu_schema()
#>                             name is_count
#> 1                 police_service    FALSE
#> 2           date_of_incident_iso    FALSE
#> 3          date_siu_notified_iso    FALSE
#> 4  date_of_director_decision_iso    FALSE
#> 5              siu_investigators     TRUE
#> 6    siu_forensics_investigators     TRUE
#> 7    number_of_witness_officials     TRUE
#> 8   number_of_civilian_witnesses     TRUE
#> 9     number_of_subject_officers     TRUE
#> 10                  age_affected    FALSE
#> 11           sex_gender_affected    FALSE
#> 12           charges_recommended    FALSE
#> 13                directors_name    FALSE
#> 14              location_of_call    FALSE
#> 15             specific_injuries    FALSE
#> 16          relevant_legislation    FALSE
#>                                                                                         description
#> 1                                        the police service(s) whose officials the SIU investigated
#> 2                                                   the date the incident occurred (ISO YYYY-MM-DD)
#> 3                                            the date the SIU was notified/invoked (ISO YYYY-MM-DD)
#> 4                                              the date of the Director's decision (ISO YYYY-MM-DD)
#> 5                                                          the number of SIU investigators assigned
#> 6                                                 the number of SIU forensic investigators assigned
#> 7                                             the count of distinct WITNESS officers/officials (WO)
#> 8                                                     the count of distinct civilian witnesses (CW)
#> 9  the count of distinct SUBJECT officers/officials (SO); a witness-officer-only investigation is 0
#> 10                                        the age (or age range) of the affected person/complainant
#> 11                                                the sex/gender of the affected person/complainant
#> 12                                          whether charges were recommended/laid, and against whom
#> 13                                                         the name of the SIU Director who decided
#> 14                                                 the location/address where the incident occurred
#> 15                                              the specific injuries the affected person sustained
#> 16                                     the legislation/Criminal Code sections the Director analysed
```
