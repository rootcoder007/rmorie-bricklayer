# Changelog

## rmoriebricklayer 0.5.1

### trend_test() no longer stalls beyond a few hundred periods

The Sen confidence interval enumerated every pairwise slope in an R
double loop that grew a vector one element at a time, so a series of
2,000 periods took minutes and a long one never returned. The slopes are
now enumerated and sorted in C (`n` of 3,000 runs in seconds, identical
interval), and
[`trend_test()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/trend_test.md)
refuses more than 20,000 periods with a message giving the memory the
pairwise slopes would need.

### Functions that seed the RNG leave the caller’s stream alone

[`drift_calibrate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drift_calibrate.md),
[`capsule_power()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_power.md),
[`capsule_falsify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_falsify.md),
[`falsify_family()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/falsify_family.md),
the synthetic-data generator and the trend bootstrap seeded the session
and left it seeded, so a user who had set a seed for reproducibility got
identical downstream draws whatever seed they chose. Each now seeds for
its own call and restores the caller’s stream on exit; the seeded
results are unchanged.

### core_moments() and json_gzip_decode() at the extremes

[`core_moments()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_moments.md)
squared its first value on the first step of the single-pass update, so
any input above the square root of the largest double gave NaN for every
statistic, and raised raw deviations to the fourth power, which
overflowed beyond about 1e77. It now takes two passes on deviations
scaled by their largest magnitude; the definitions and the results on
ordinary data are unchanged, and the shape statistics are NaN only when
the variance is zero. The streaming accumulator behind
`rmbl_moments_acc_add()` no longer squares its first value either.

[`json_gzip_decode()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_json_gzip.md)
refuses input that is not a gzip member (fewer than 18 bytes or not
starting 1f 8b) with a clear error. It used to pass the bytes straight
to [`memDecompress()`](https://rdrr.io/r/base/memCompress.html), which
in R 4.6 dumps core on an empty vector, so `json_gzip_decode("")`
crashed the session.

### core_mean() no longer overflows where base R does not

The shared numeric core summed naively, so `core_mean(rep(1e308, 3))`
was `Inf` and `core_mean(rep(1e120, 3))` was off by 1.4e104;
[`core_var()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_core_stats.md),
[`core_sd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_core_spread.md)
and
[`core_moments()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_moments.md)
inherited it, returning 3e208 for the variance of three identical
values. The core now uses base R’s algorithm (extended precision sum
plus one corrective pass) with a running mean as the fallback when the
sum overflows although every input is finite, and the same fix ships in
rmorie, which carries a copy of the header. Results on ordinary data are
bit-identical to [`mean()`](https://rdrr.io/r/base/mean.html).

### One call for a published table

[`analyse_table()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/analyse_table.md)
runs the questions asked of every published table of counts (what is in
it, what changed and how sure, rates if there is an exposure, trend,
drift against the prior capsule) and returns one object;
[`report_analysis()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/report_analysis.md)
writes it as Markdown or a single HTML file;
[`use_capsule_template()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/use_capsule_template.md)
writes a capsule folder whose `analysis.R` runs as written. A
getting-started vignette walks the shipped OTIS table through it in
twenty lines.

### Uncertainty the release itself introduces

[`published_bounds()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/published_bounds.md)
turns rounded (`rounding = 5`, nearest or Statistics Canada random
rounding) and suppressed (`"x"`, `"<5"`) cells into the interval of
observed counts that could have produced them;
[`change_envelope()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/change_envelope.md)
carries that interval through a difference, a percent change or a rate
exactly;
[`yoy_bounds()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_bounds.md)
adds it to a
[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
table with a combined interval that is the union of the sampling
interval and the envelope. No confidence interval covers this
uncertainty, so it was previously invisible.

### Many comparisons, and screens that fire on nothing

[`yoy_pvalues()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_pvalues.md)
gives the exact conditional-binomial test that matches the
[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
interval;
[`scan_adjust()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/scan_adjust.md)
adjusts a
[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
or
[`rate_change()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rate_change.md)
scan for multiple comparisons (Benjamini-Hochberg by default) and marks
what survives;
[`rate_change()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rate_change.md)
now returns `previous_count` and `previous_population` so the test is
exact given the exposures.
[`drift_calibrate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drift_calibrate.md)
estimates how often
[`capsule_drift()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_drift.md)’s
screens fire on identical data by splitting one release into random
halves, per column and family-wise, with the per-screen alpha that would
hold the family-wise rate.

### Encoding handling no longer depends on the session locale

[`ascii_fallback()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ascii_fallback.md)
and
[`to_ascii()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/to_ascii.md)
test the bytes with
[`validUTF8()`](https://rdrr.io/r/base/validUTF8.html) and drop invalid
ones with an explicit UTF-8-to-UTF-8
[`iconv()`](https://rdrr.io/r/base/iconv.html). The previous guard went
through [`enc2utf8()`](https://rdrr.io/r/base/Encoding.html), which
under a C locale re-encodes invalid bytes as Latin-1 instead of flagging
them, so the fallback returned them untouched.
`bricklayer_json_minify()` and `bricklayer_json_prettify()` declare
their result as UTF-8 ([`paste()`](https://rdrr.io/r/base/paste.html)
had dropped the mark, so `nchar(x, "chars")` over-counted in a C
locale). Found by an independent C-locale check of 0.5.0; the check
matrix now includes a C-locale cell. The JSON byte-order-mark test and
strip work on the bytes, so a C locale no longer warns “unable to
translate ‘\<U+FEFF\>…’” or “invalid char string in output conversion”
while validating or minifying JSON.

## rmoriebricklayer 0.5.0

CRAN release: 2026-09-16

### Point locations and the regions that contain them

A region map from facilities to statistical regions is built once and
read many times, so an error in it is the one error recomputing the
downstream tables cannot find: everything downstream reads the region
map, and both sides of any comparison move together. `R/region_map.R`
adds the checks that can find it.

- [`region_coverage()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/region_coverage.md)
  reports how many regions hold at least one unit and what share of the
  population lives in them, and its print method says each time that the
  share is not a rate denominator. A region holding no unit is not an
  unserved population: units serve catchments, which a point location
  does not state. Summing the populations of unit-holding regions pairs
  a partial denominator with a numerator drawn from the whole territory,
  and every rate built that way is inflated unevenly.

- [`region_map_integrity()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/region_map_integrity.md)
  finds what a comparison against published output cannot, because it
  would be present on both sides: a unit assigned two regions, a unit
  assigned none, a region code belonging to another province. No
  geometry, so it runs with nothing installed.

- [`region_map_compare()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/region_map_compare.md)
  matches two region maps on the unit identifier and compares them cell
  by cell, numerics through
  [`all.equal()`](https://rdrr.io/r/base/all.equal.html) so a coordinate
  that survived a round trip through text is not reported as a change.

- [`region_map_second_route()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/region_map_second_route.md)
  compares the assignment against one derived a DIFFERENT way, and takes
  the known-bad cases by name rather than by a loosened tolerance. This
  is the only one of the four that can catch an error in the original
  method, because it does not use that method.

- [`region_map_from_points()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/region_map_from_points.md)
  recomputes the assignment by point in polygon, projecting the points
  onto the boundary file’s own coordinate system rather than the
  reverse. It returns `NULL` without `sf` or without the boundary file,
  so a verification script records the check as unavailable instead of
  failing over an optional dependency. `sf` joins Suggests.

### The otis-mrp example

- New section 3g re-derives the institution to census division region
  map and the division populations under it, rather than reading them.
  The 49 Ontario census-division populations re-derive exactly from
  Statistics Canada 17-10-0139-01, summing to 15,109,416; the 21
  divisions holding an open institution hold 10,110,752 of those. Twelve
  checks run with nothing granted, and injected errors were confirmed to
  fail them: a moved institution, a foreign region code, an altered
  population, a dropped division and a duplicated row each break at
  least one.

- The city-name second route covers eleven of the twenty-five open
  institutions and disagrees on one, which is recorded as documented
  rather than tolerated. Sudbury Jail stands inside the City of Greater
  Sudbury, census division 3553 and 171,568 people; the bare name
  “Sudbury” belongs to census division 3552, Sudbury District, 22,746
  people. Two places, one name. The geometry is right and the name route
  is wrong, and a SECOND disagreement is still a failure.

- `institution_cd_region_map.csv` and `cd_population_2022.csv` now
  travel with the example, so the checks run from the bundle.

### Verification that runs

- The push CI now fetches the public OTIS A01 input (4.7 MB, cached on
  its pinned provenance) and passes it to the smoke test, so every
  section of `analysis.R` is exercised on each push instead of recording
  as INFO. The bundle’s R packages are read from `config.json` rather
  than listed a second time in the workflow.

- `verify_bundle.sh` compares the manifest against `config.json`’s
  `total_checks` and `pass_csv` whenever real data was supplied, and
  fails on a mismatch. The expected counts are now an assertion, not a
  note.

- A weekly workflow, `otis-full-verify.yml`, runs `analysis.R` with
  every opt-in verification on: the 147 published year-over-year tables,
  the 108 rate tables, the census-division populations re-derived from
  Statistics Canada, and the point-in-polygon recompute of the region
  map against the 2021 boundary file. It fails on any DIFFER and keeps
  the manifest for ninety days, so “verified” carries a date.

- CI refuses a copy of any vendored R file tracked under `examples/`,
  the shape of the `custody.R` shadowing below.

- `check_pkgdown()` runs in the test suite when pkgdown is installed, so
  a topic missing from the reference index fails locally rather than on
  the site build.

### Printing

- The statistics that return a classed data frame –
  [`rate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rate.md),
  [`share()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/share.md),
  [`rate_change()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rate_change.md),
  [`stock_flow()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stock_flow.md),
  [`region_coverage()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/region_coverage.md)
  and
  [`band_sensitivity()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/band_sensitivity.md)
  – print through one frame: a titled rule, the table, the lines that
  qualify it. The caveats each of them carries are laid out the same way
  instead of rewritten per method.

### Bug fixes

- `examples/otis-mrp/custody.R` is removed. It duplicated `R/custody.R`
  and took precedence over it: `analysis.R` searches beside the script
  before `../../R`, so a run from a checkout without the package
  installed resolved to a
  [`stock_flow()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stock_flow.md)
  without the `baseline` argument and without
  [`period_days()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/period_days.md)
  or
  [`stay_summary()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stay_summary.md).
  It was the only one of the nine vendored R files tracked under
  `examples/`, and `make_bundle.sh` copies the package file over it at
  build time, so built bundles were unaffected.

## rmoriebricklayer 0.4.9

### Bug fixes

- The JSON writer no longer asks the platform for its digits. Seventeen
  significant digits are this package’s round-trip guarantee, but
  `sprintf("%.17g")` delegates to the C library, and Windows aarch64’s
  gets it wrong: it renders the largest double as
  `1.7976931348623156e+308`, one ulp low, so the text reads back as a
  different number. Eight assertions in `test-attest.R` and
  `test-json-edges.R` failed there while passing on every other
  platform, and jsonlite, which brings its own converter, disagreed with
  both. The digits are now generated by exact integer arithmetic in
  `src/rmbl_strtod.cpp`, the same way the reader already worked:
  mantissa times a power of two, scaled by an exact multiply and an
  exact division, with the remainder deciding the rounding, ties to
  even. Verified byte-for-byte identical to the platform across 199,934
  doubles wherever the platform is correct, so nothing changes on a
  sound library.

## rmoriebricklayer 0.4.8

### Why the version moved

Five exported functions –
[`adp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adp.md),
[`alos()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/alos.md),
[`admissions()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/admissions.md),
[`adp_from_counts()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adp_from_counts.md),
[`stock_flow()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stock_flow.md),
and then
[`period_days()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/period_days.md)
and
[`stay_summary()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stay_summary.md)
– were added across three commits that all carried `Version: 0.4.7`.
r-universe had already built and served 0.4.7 from an earlier snapshot,
so a package depending on `rmoriebricklayer (>= 0.4.7)` could be handed
a build without any of them, and rmorie’s minimal-dependency job duly
failed on exactly that. A version number that does not move when the
interface grows cannot be depended on, which is the whole reason it
exists. Everything below was previously listed under 0.4.7.

### The stock and flow measures reach the example, and so does the MNAR pair

Both were computed and published for reading before they were shipped
anywhere a check could see them. They are in `analysis.R` now.

**Section 3e** computes Lakner’s measures for segregation through the
package’s own
[`adp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adp.md),
[`alos()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/alos.md)
and
[`stock_flow()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stock_flow.md),
so the example exercises the functions rather than reimplementing them.
It is NOT gated, unlike the rate tables: there is no denominator to
argue about, since days divided by 365 and days divided by the people
who served them are both unambiguous.

It records checks that can fail, not just values:

- `lakner_b02_one_row_per_person` asserts the structure that makes
  `TotalAggregatedDays_Segregation` Lakner’s X-sub-i.
- `lakner_people_b01_vs_b02_*` requires the two tables to agree on how
  many people there were.
- `lakner_decomposition_exact` requires `(1 + p) * (1 + l) - 1` to
  recover the change in days, to 1e-9.
- `lakner_b01_consecutive_is_not_total_*` records the ratio, about 0.67,
  so the trap cannot be rediscovered the hard way: `b01` holds roughly
  2.7 rows per person and its `NumberConsecutiveDays_Segregation` is a
  spell length, not an additive share of the year.
- `lakner_day_share_*` puts the day share beside the headcount share,
  which is how Lakner p.15 says a subgroup share of the average daily
  population must be taken.

**Section 3f** is the capacity analysis, as a pair rather than an
imputation. `Operational_Capacity` is missing for three of the 25 open
institutions and they are the large ones – Central East CC, Central
North CC and Toronto South DC – while the largest observed capacity is
944. Missingness that depends on the value is MNAR, not MAR, so imputing
would pull all three toward the observed mean and understate three
denominators in a knowable direction.

So Central and Northern, whose capacity is fully observed, get a
complete-case estimate, and the other three get a range across the
plausible span of their one missing capacity. Three checks carry the
argument: that every `Alert_Type` gives the same yearly total, since
summing across types would count each placement six times; that exactly
two regions are fully observed; and that all three unobserved capacities
exceed the largest observed one, which is what makes this MNAR.

New outputs: `12_stock_flow.csv` and `13_capacity_mnar.csv`. The
capacity analyses need Ontario’s institutional-locations CSV, a separate
CKAN dataset, shipped with the example and overridable with
`OTIS_LOCATIONS`.

### Stock and flow: person-days have two denominators

[`adp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adp.md),
[`alos()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/alos.md),
[`admissions()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/admissions.md),
[`adp_from_counts()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adp_from_counts.md)
and
[`stock_flow()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stock_flow.md)
implement the measures from Lakner, *A Manual of Statistical Sampling
Methods for Corrections Planners* (University of Illinois at
Urbana-Champaign, 1976). One quantity, person-days, carries two
denominators:

- divided by TIME it gives the average daily population, a **stock**:
  how many people are held at once. Lakner p.15.
- divided by PEOPLE it gives the average length of stay. Lakner p.16.

[`stock_flow()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stock_flow.md)
puts both in one table with the decomposition, because when length of
stay moves the two can carry **opposite signs** and a report quoting
either alone states the wrong direction for the other. The print method
says so explicitly when the signs disagree.

This is not a hypothetical. On Ontario’s segregation data the number of
people held fell 24.0% between FY2023 and FY2025 while their stays grew
43.5% longer, so total detention days rose 9.0% and the average daily
population rose with them. A flow rate falls 27.6% over exactly the
window in which a stock rate rises 3.9%. The decomposition is exact:
days are people times length of stay, so `(1 + p) * (1 + l) - 1`
recovers the change in days.

[`admissions()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/admissions.md)
inverts the identity when two of the three quantities are published and
the third is not.
[`adp_from_counts()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adp_from_counts.md)
covers the case where only periodic headcounts exist rather than a
record per person (Lakner eq 2.7, p.21), with the assumption stated: the
days counted must not differ systematically from the days missed.

[`alos()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/alos.md)’s
documentation carries Lakner’s own caveat (p.16-17), which is easy to
lose: the period must exceed the longest stay people actually serve, or
the average is biased DOWNWARD, because the longest stays are the ones
that fail to finish inside the window.

Nothing about the arithmetic is specific to custody – the same
relationship governs hospital beds, shelter occupancy and open
caseloads. It is Little’s law under the names corrections planning uses.

The tests anchor on Lakner’s own worked examples rather than on each
other: 13,500 days over a year giving 36.986; 12,150 days across 2,700
people giving 4.5; 25 held daily against 1,750 admissions giving 5.2;
and counts on 255 days summing to 34,935 giving 50,005 person-days.
Those are numbers computed by someone else, so they can disagree with
this code, which is the property a test needs.

### Rates, shares and rate change

A count is not comparable across places of different size or years of
different population, so
[`rate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rate.md)
divides counts by exposure and scales to a denominator – `per = 1000`,
`"10k"`, `"100k"`, `"1m"`, or any positive number. The interval is the
exact Poisson one, matching
[`stats::poisson.test`](https://rdrr.io/r/stats/poisson.test.html) to
the last digit, so a count of zero gives a lower limit of exactly zero
instead of a negative rate.

[`share()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/share.md)
is the other quantity people mean by “percentage”: what fraction of a
total each count is. Its denominator is the total of the same events,
not a population, so shares over a complete grouping sum to 100. The
interval is Wilson’s rather than the normal approximation, which runs
past the ends of the scale and reports negative percentages at exactly
the small counts people reach for it.

Labelling one of these as the other is the most common error in a
published table, which is why they are separate functions with separate
intervals rather than one function with a flag.

[`rate_change()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rate_change.md)
is the change in a rate between periods. This is not the percent change
of two rates treated as measured numbers: both denominators move, and an
interval that ignores them understates the uncertainty. It conditions on
the total of the two counts and corrects for the exposure ratio –
[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)’s
exact conditional-binomial interval generalised to unequal denominators,
and it reduces to exactly that interval when the two populations are
equal, which is a test.

Like
[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md),
the comparison period is matched on the period value and not on row
position, so a missing year reports no comparison instead of silently
comparing 2023 against 2020.

### Verifying the published year-over-year tables

The `otis-mrp` example now recomputes every published OTIS
year-over-year table from the province’s own CSVs and compares all of
them: 147 tables across 29 datasets, 8,214 cells. Previously the example
verified the models and the descriptives but said nothing about those
tables, so a reader checking them had nothing to check against.

The table definitions are a port of the generator that produced the
published page, not a reimplementation from column names – percent
change rounded to one decimal and undefined when the earlier value is
zero, shares against the column total, groups sorted with NA and empty
dropped. Getting those subtly different would produce mismatches that
look like data errors and are actually definition errors.

It also checks something a cell-by-cell comparison cannot: three OTIS
datasets reach the same restrictive-confinement population by different
routes, and `a01` distinct individuals, `c01` totals and `c04` totals
must agree per fiscal year (20,781 / 19,641 / 25,045). A wrong grain
rule would move both sides of a cell comparison together and pass; this
fails.

The datasets are ~14 MB and are not shipped. They come from
`OTIS_DATASETS_DIR` if you already have them, or `OTIS_YOY_DOWNLOAD=1`
to fetch them from the province. rmoriedata is deliberately not a
source: its OTIS files are five-row samples for examples, so comparing
published totals against them would fail by construction rather than
tell anyone anything.

Files are named from the CKAN resource URL, which ends in the canonical
filename for all 29. Nothing is inferred from the resource title, which
would be guesswork – “Segregation Placements - Maximum, Median and Mode
Consecutive Durations by Region” is the file called
`b04_segregation_placements_consecutive_durations_by_region`, and 15 of
the 29 diverge that way. A column signature then confirms a downloaded
file contains what its name claims, which catches the province
reshuffling data behind a URL – an error no comparison against published
output could catch, because both sides would move together.

### Rate tables, verified against both exposures – opt-in

The example can verify the 108 published rate tables across 24 OTIS
datasets, 15,831 cells, and does so on request:

``` R
OTIS_RATES_VERIFY=1 Rscript analysis.R <input> <outdir>
```

It is off by default, and not because it fails – it passes all 108. It
is held back because a group row in those tables divides that group’s
count by the WHOLE yearly population, so it states how much the group
contributes to the overall rate rather than the rate among its own
members: men’s placements over the whole restrictive-confinement
population is not a rate for men. c01 carries the population by gender,
so a matched denominator exists for some tables and not others, and
choosing per table is its own piece of work. The example already has the
rates it needs, and the year-over-year tables already give counts,
shares and percentage change for every published table.

Each count is expressed against two exposures:

- the yearly total of the prison population the dataset covers, per
  1,000, taken from `c01`, which states all three regime totals
  directly. Those totals were checked against the detailed datasets
  rather than trusted: `a01` distinct individuals equal `c01`’s
  restrictive-confinement total, and `b01` and `b02` distinct
  individuals equal its segregation total, in every year.
- Ontario residents at April 1, per 100,000, from Statistics Canada
  table 17-10-0009-01. Geography position 7 was confirmed as Ontario
  from the cube metadata rather than assumed.

This is the construction criminology uses for a rate – a count over an
exposure, which in a count model enters as an offset of log(exposure).
Intervals are the exact Poisson interval, and change between years is
the exact conditional interval for a rate ratio corrected for both
exposures, cross-checked against the two-sample
[`stats::poisson.test`](https://rdrr.io/r/stats/poisson.test.html).

`otis_headline_rates()` reports the named rates. Over FY2023 to FY2025
the incarceration rate rose from 216.7 to 267.5 per 100,000 residents
while the solitary-confinement rate fell from 81.6 to 59.1, and within
custody solitary use fell from 376.7 to 221.0 per 1,000. The two move in
opposite directions, which a count alone hides.

The recomputation deliberately does not port the generator’s arithmetic,
as the year-over-year check does; it goes through
[`rate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rate.md)
and
[`rate_change()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rate_change.md),
whose intervals are anchored to base R. That independence found two
defects in the generator that a like-for-like port would have reproduced
silently: the rate-ratio arguments were reversed, giving a +34.4% change
an interval of -25.9 to -25.3 that did not contain its own estimate, and
a group with no exposure in a year got an upper limit of `Inf` on a
change that was simply undefined. Both are now guarded by assertions
that every rate and every change must lie inside its own interval.

A group row in these tables is a CONTRIBUTION, not a per-capita rate:
the numerator is that group’s count and the denominator is the whole
yearly population, so men’s placements over the whole
restrictive-confinement population is not a rate for men. Where the
measure counts recurring events rather than people the per-1,000 figure
can exceed 1,000, for the same reason one person can hold several
placements. Both facts are stated on every table rather than left for a
reader to infer.

### The count model no longer reports a missing AIC

The canonical `glmmTMB` fit returned a non-positive-definite Hessian and
no AIC, which the example flagged as a warning for several releases. The
cause is identifiable: the negative-binomial dispersion runs to
4.35e+08. A negative binomial whose theta goes to infinity IS a Poisson,
so the likelihood is flat in that direction and the Hessian is singular
in it. The `rc` random intercept, with a standard deviation of 4.5, has
already absorbed the overdispersion theta would explain – the outcome is
93% zeros with mean 0.173 and variance 0.473 – so the two compete to
describe the same variation and one is left unidentified.

The fit now names the model it is actually fitting. The Poisson gives
the same coefficient and the same standard error to four decimals, with
a positive-definite Hessian and an AIC of 3045.3 against the published
3041.7. Which family produced the numbers is recorded in the manifest,
because a coefficient is not interpretable without it.

A different optimiser was the wrong answer and was tried first:
Nelder-Mead converges, but to a worse optimum (AIC 3054), trading a
missing AIC for a wrong one.

### The otis-mrp example

The example analysis had an absolute path to the author’s own volume as
its default input. It could not exist on a reviewer’s machine and it
published a local directory layout, so the input is now searched for –
command line, then `OTIS_INPUT`, then known filenames in the working
directory and beside the script – and the script stops with the exact
command to run when it finds nothing.

`lme4` and `DHARMa` were attached and recorded as dependencies but never
called; both are gone. The header now also says which arm is canonical
for what: `rmorie::morie_otis_irm_dml` is the preferred DML path and
makes `DoubleML`, `mlr3`, `mlr3learners` and `lgr` unnecessary, while
`MatchIt` and `glmmTMB` stay because the published numbers came from
them and the script exists to let a reviewer check those numbers.

The analysis now also writes `08_rates_and_yoy.csv`: movement rates per
1,000 placements and per 1,000 person-years, each year’s share of the
total, and the year-over-year change in the rate. Capsule bundles carry
`yoy.R` and `rate.R` so this works with nothing installed.

### Fixes

- A capsule bundle sources `json_native.R` with no compiled library
  present, so calling the registered native decimal converter failed
  with `object 'C_rmbl_strtod' not found` and every bundle run died. The
  converter is used when it is there and R’s own reader when it is not.

- `test-attest.R` compared the decimal converter against decimal
  literals, which are converted by whatever C library R was built
  against – the thing under test. On macOS both sides moved together and
  the test failed against the correct answer. Expected values are now
  transported as the bytes of the double.

- The version-drift test read `DESCRIPTION` from a source tree that
  `R CMD check` does not provide, erroring on all five platforms.

- [`rate_change()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rate_change.md)
  on non-numeric periods indexed with positions that could be zero,
  which returns a shorter vector and recycles wrong answers rather than
  reporting anything.

- `analysis.R` called `say()`, which is defined only in the bundle’s
  `lib_interactive.R`. Run from a bundle it resolved; run directly from
  a checkout – which is how a reviewer runs it – it died with
  `Error in say(...)`. Both call sites use
  [`cat()`](https://rdrr.io/r/base/cat.html) now.

- The example’s default input was an absolute path inside the author’s
  own volume. It could not exist on a reviewer’s machine and it
  published a local directory layout. The input is searched for now.

- Column signatures are compared after sorting with `method = "radix"`.
  The default [`sort()`](https://rdrr.io/r/base/sort.html) uses the
  locale’s collation, which orders `Number_Of_Placements` before
  `NumberConsecutiveDays_Segregation` while byte order does the reverse;
  one dataset of the 29 differs only in that pair, so under the default
  sort its signature failed to match itself and the file went
  unidentified.

## rmoriebricklayer 0.4.6

Certificate path validation is now complete: the three things 0.4.5
listed as still missing are done.

### Name constraints

A CA can be limited to part of the name space, and a verifier that
ignores the limit treats a CA constrained to one organisation’s domains
as able to issue for any name at all.
[`cert_chain_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cert_chain_verify.md)
now enforces `nameConstraints` for every CA in the path against every
certificate below it – not only the leaf, so a constrained CA cannot
escape by issuing an intermediate.

The matching rules are per type and deliberately not shared: a DNS
constraint of `example.org` covers `host.example.org` and `example.org`;
an email constraint of `example.org` covers mailboxes whose host is
exactly that and NOT its subdomains; a directory name constraint matches
whole relative distinguished names, so `O=Acme` is not satisfied by
`O=AcmeCorp`. `pathLenConstraint` is enforced too.

### Certificate policies

`certificatePolicies`, `policyMappings`, `policyConstraints` and
`inhibitAnyPolicy` are processed as RFC 5280 section 6.1 describes, with
its three counters. Pass `policies` to
[`cert_chain_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cert_chain_verify.md)
and the path must yield one of them after mapping; omit it and policies
are still processed, but only reported as a failure where a certificate
in the path requires an explicit policy. Mapping to or from `anyPolicy`
is rejected, as the standard requires.

Not done: policy qualifier processing. A user notice attached to a
policy is parsed past rather than surfaced.

### Revocation can now be fetched

`revocation = "fetch"` retrieves CRLs from the distribution points in
the certificates and queries any OCSP responder they name. OCSP is
POSTed as RFC 6960 requires a responder to accept, falling back to the
optional GET form.

It is opt-in, and that is the design rather than caution. A verifier
that reaches out during a check stops working offline – which is where
an archival capsule is most likely to be verified – becomes
non-deterministic, and tells whoever runs the responder which
certificates are being checked and when. `"supplied"` (the default) uses
only CRLs handed in; `"none"` skips revocation entirely.

A responder’s answer is believed only when its signature verifies under
a certificate in the path, or one it carries that the path issued. An
unverifiable “good” is reported as a failure: treating it as a pass
would be worse than skipping the check, because it would look like the
check had happened.

### Along the way

- SHA-1, for OCSP CertID only – RFC 6960 keys a request on the SHA-1 of
  the issuer’s name and public key, and a responder given anything else
  answers “unauthorized”. It verifies no signatures here and must not:
  SHA-1 collisions are practical.
- `C_rmbl_http_post()`, so OCSP can POST. It is the only thing in the
  package that sends a body.
- Every verdict here was cross-checked against `openssl verify` on the
  same certificates – it rejects the three name-constrained leaves and
  the wrong-policy leaf that these tests reject – and the OCSP request
  this package builds is byte-identical to `openssl ocsp -reqout`, which
  checks the DER encoder, the CertID and the SHA-1 at once.
- Fixed a `logical(0)` trap in policy processing: `is.na(NULL)` is
  `logical(0)` and `if` on it is an error, so a counter read from a
  structure that did not carry the field failed instead of defaulting.

## rmoriebricklayer 0.4.5

The four things the previous release documented as deliberately
incomplete are now complete.

### Certificates are validated, not just used

[`timestamp_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/timestamp_verify.md)
gained `trust`, `crls` and `at_time`, and there is a new
[`cert_parse()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cert_parse.md)
and
[`cert_chain_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cert_chain_verify.md)
behind them. The chain is built to an anchor you name, every signature
in it is verified, every validity window is checked, an issuer must be a
CA, and the leaf must carry the timeStamping extended key usage. A CRL
can be handed in.

Validity is judged at the time the TOKEN asserts, not at the time the
check runs. A token signed in 2020 under a certificate that expired in
2021 was validly signed, and judging it by today’s date would reject it
for a reason unconnected to its validity.

Omitting `trust` no longer passes quietly: `certificate_trust` is
reported as failed, because a signature that verifies under an
unvouched-for certificate says only that some key signed the token.

Still not done, and now the only gaps here: name constraints, policy
mapping, and fetching revocation data over the network.

### ECDSA, not only RSA

`rmbl_ecdsa.cpp` implements ECDSA verification over P-256, P-384 and
P-521 – field and group arithmetic, Jacobian point operations, and the
FIPS 186-4 verification equation with the range and on-curve checks that
a lax verifier skips. Certificates and timestamp tokens signed with
`ecdsa-with-SHA256/384/512` now verify; the test fixtures carry one
token of each kind over the same payload under the same CA, so the two
paths are exercised against real tokens rather than against each other.

SHA-384 was added for `ecdsa-with-SHA384`, checked against its FIPS
180-4 vectors.

One bug is worth recording because of how it presented. The P-521 group
order was written four hex digits short. Every published base-point
multiple still matched – the curve arithmetic uses only the field prime
and b – while every operation mod n was wrong and no signature verified.
The fix added a width check on every curve constant and a test that
`n * G` is the point at infinity, which is the property that fails the
moment the order is wrong.

### Falsification can now confirm as well as refute

[`capsule_power()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_power.md)
injects an effect of known size, reruns the whole detection procedure,
and reports the rate at which it is found. The smallest size detected
reliably is the smallest effect the analysis could have seen.

This is the case the negative controls cannot reach. A procedure with no
power against the effect at issue passes every control in
[`capsule_falsify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_falsify.md)
by failing to see anything at all, and a null result from it is not
evidence of absence. A design whose permutation floor sits above alpha –
where no size could ever be detected – is refused rather than run.

### Signing an SLH-DSA `s` parameter set is five to seven times faster

Worst case went from 7.20 seconds to 2.67, and the SHA-2 sets from 7.20
to 1.09. Nothing is gated behind an environment variable any more; every
parameter set signs in the test suite.

Three changes, in order of what they were worth:

- the Keccak round no longer evaluates `% 5` on every lane – the
  permutation is straight-line code with literal indices, generated from
  the formulas rather than transcribed;
- the tweakable hash no longer heap-allocates, which it was doing a few
  million times per signature;
- the SHA-2 parameter sets resume from a cached midstate instead of
  recompressing the padded public seed on every call, which is what the
  reference implementation means by a seeded state.

`sha256_update()` and `sha512_update()` also now copy in bulk rather
than a byte at a time, which speeds up every other user of them.

All 15 signature parameter sets remain byte-identical to OpenSSL 3.5,
re-checked after the optimisation: 300 comparisons, no differences.

## rmoriebricklayer 0.4.4

### From “the record is intact” to “the record is right”

[`verify_capsule()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_capsule.md)
checks a manifest against itself, which catches an edited manifest and
cannot catch one that was wrong when it was written.

- [`manifest_recompute()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/manifest_recompute.md)
  re-runs named statistics against the data and compares each to what
  was recorded. Results that were recorded but NOT recomputed are
  reported as `unchecked`: an analysis that recorded twenty statistics
  and re-derives three has seventeen it has not, and a report that
  quietly omitted them would read as a clean bill of health.
- [`manifest_record_seed()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/manifest_record_seed.md)
  and
  [`manifest_restore_seed()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/manifest_record_seed.md)
  record and replay the generator’s full state.
  [`set.seed()`](https://rdrr.io/r/base/Random.html) is reproducible
  only if everything before it is too – one extra draw upstream shifts
  every later value – so the state is what gets recorded, and the kind
  beside it, because a seed replayed under a different kind gives
  different numbers silently.
- [`capture_dependencies()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capture_dependencies.md)
  records where each package came from: the library, the repository, and
  for a remote install its URL and commit. Two installations can report
  the same version and differ.

### Falsification, and what comes before and after it

- [`prereg_declare()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/prereg_declare.md)
  and
  [`prereg_check()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/prereg_declare.md)
  – declare the statistics an analysis intends to report, and compare
  that against what it did. The two departures are reported separately
  because they are different failures: a declared statistic that was not
  reported is outcome switching, and a reported statistic that was not
  declared is an addition. Both are invisible without a declaration made
  in advance.
- [`falsify_family()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/falsify_family.md)
  – corrects a family of permutation p-values by Holm,
  Benjamini-Hochberg or Bonferroni, and names those sitting at the
  permutation floor, where more permutations would be needed to say
  anything more. Running the control over twenty statistics and
  reporting the one under 0.05 is not a finding.
- [`evalue_rr()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/evalue_rr.md)
  – the E-value of VanderWeele and Ding: how strong an unmeasured
  confounder would have to be, with both the exposure and the outcome,
  to explain the result away.

### Distribution and time

- [`capsule_bundle()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_bundle.md),
  [`capsule_bundle_read()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_bundle.md)
  and
  [`capsule_bundle_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_bundle.md)
  – one signed artifact holding a digest of every file, the manifest
  digest and an attestation over both. The file digests are inside the
  signature: a list of hashes that is not itself signed can be rewritten
  to match whatever the files now say. Files present but unlisted are
  reported too.

- [`timestamp_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/timestamp_verify.md)
  and
  [`timestamp_info()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/timestamp_verify.md)
  – RFC 3161 timestamp tokens, verified natively. The message imprint is
  checked against the data, the genTime is reported, and the authority’s
  RSA signature over the signed attributes is verified, which meant
  implementing DER parsing and a bignum modular exponentiation
  (`C_rmbl_der_parse`, `C_rmbl_rsa_recover`). A hash chain proves the
  order of a sequence of manifests and not that any of them existed at a
  given time; this supplies the date.

  What it does NOT do, stated plainly because it is the difference
  between this and a browser’s padlock: validate the certificate. No
  chain building, no validity dates, no revocation, no check of the
  timeStamping key usage. Pass the certificate you have decided to
  trust, and read a pass as “this key said so”.

## rmoriebricklayer 0.4.3

### A manifest can now reproduce its own numbers

[`write_manifest_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/write_manifest_json.md)
wrote doubles at four significant digits, so a manifest recording `1/3`
said `0.3333` and no later recomputation could match what was written.
Every number is now written at full double precision – seventeen
significant digits, which is enough to recover any double exactly – and
round-trips exactly, the smallest denormal included.

That holds on every platform, because the package no longer asks the
platform. Seventeen digits recover any double only through a reader that
rounds correctly, and not every C library does: macOS arm64 (R 4.6.0)
reads the correct decimal for `.Machine$double.xmax` as `Inf`, and loses
low bits above about 1e100 on text written elsewhere. So the decimal
conversion is done here instead, in integer arithmetic with a remainder
that decides the rounding – round to nearest, ties to even, with no
floating point involved in the decision. A manifest written on one
machine now reads back bit-identically on another, and a caller does
nothing to get that. A provenance record that cannot reproduce its own
numbers is the one failure mode the whole capsule apparatus exists to
prevent, and this was it.

- [`manifest_canonical()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/manifest_canonical.md)
  and
  [`manifest_digest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/manifest_canonical.md)
  – one line of JSON with every object’s keys sorted, and its SHA-256. R
  lists keep insertion order, so the same manifest assembled in a
  different order used to serialise to different bytes, which made a
  signature over the JSON depend on the order a script happened to build
  a list in. Sign the digest.
- [`capture_environment()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capture_environment.md)
  now records `rng_kind` and whether a seed was in force. Without the
  generator’s identity a stochastic result cannot be reproduced even on
  the same machine: R has changed its default
  [`sample()`](https://rdrr.io/r/base/sample.html) algorithm before, and
  a recorded seed means nothing without the kind it was fed to.

### Attestation: a signature a third party can actually check

[`capsule_attest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_attest.md)
and
[`capsule_check_attestation()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_attest.md).
A bare signature leaves three things implicit – which key, which scheme,
which bytes – and a verifier who has to be told them out of band cannot
check anything they were not already given. An attestation records the
scheme, the public key, the context, the pre-hash, the manifest digest
and a note from the signer, all inside the signed payload, so the check
is `capsule_check_attestation(attestation, manifest)` and nothing else.
Editing any field afterwards is detected, including the note.

### Falsification: controls that can fail

[`capsule_falsify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_falsify.md)
runs four negative controls against a statistic and reports whether it
behaved: a permutation test that destroys the association on purpose, a
random common cause that cannot matter, a placebo exposure, and subset
stability. Reproducibility is a property of a pipeline, not of a claim –
a capsule can be signed, hashed, chained and reproduced byte for byte
while reporting a number that means nothing.

The permutation control reports the smallest p-value its design could
have produced, because a reader who does not know that 19 permutations
floor at 0.05 will over-read a p of 0.05. The controls are demonstrated
failing as well as passing: a constant statistic fails the permutation
test, noise fails it, and a statistic that reads the injected noise
column fails the random-common-cause control.

## rmoriebricklayer 0.4.2

### The rest of the NIST post-quantum standards

- **ML-KEM (FIPS 203)** at all three levels –
  [`kem_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kem_keygen.md),
  [`kem_encapsulate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kem_encapsulate.md),
  [`kem_decapsulate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kem_decapsulate.md),
  [`kem_sizes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kem_sizes.md).
  A key encapsulation mechanism answers a different question from a
  signature: not who produced a capsule but what key two parties now
  share. Decapsulation has no failure path, deliberately: a bad
  ciphertext yields a shared secret derived from a value held only
  inside the decapsulation key, so the sender learns nothing from
  whether it worked. That is the Fujisaki-Okamoto transform’s implicit
  rejection.
- **HashML-DSA (FIPS 204 section 5.4) and HashSLH-DSA (FIPS 205 section
  10.2.2)** – `capsule_sign(prehash = )`, for signing a digest of the
  message rather than the message. The identifier of the pre-hash is
  bound into the signature, not merely its output, so a signature over a
  SHA-256 digest is never interchangeable with one over a SHAKE128
  digest of the same length.
- **ExternalMu-ML-DSA** –
  [`fips_mu()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_mu.md),
  [`fips_sign_mu()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_mu.md),
  [`fips_verify_mu()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_mu.md).
  A message can be reduced to the 64-byte value that is all ML-DSA
  signing consumes, and only that handed to whatever holds the key, so a
  large file never has to cross the boundary the key sits behind. mu
  binds the public key and the context, so it is not a bare digest.

Every one of these is checked against OpenSSL 3.5, which shares no code
with this package. ML-KEM keys generated from the same seed agree byte
for byte at all three levels, its ciphertexts decapsulate here to the
secret it reports and ours to the secret we report, and a corrupted
ciphertext produces the same rejection secret in both. The pre-hash and
external-mu signatures are byte-identical for every parameter set and
every pre-hash.

## rmoriebricklayer 0.4.1

### The standardised post-quantum schemes are now implemented here

ML-DSA (FIPS 204) and SLH-DSA (FIPS 205) were previously reached through
liboqs, so which schemes a build offered depended on what happened to be
installed on the machine that built it – a poor property for a signature
format meant to outlive that machine. Both are now implemented in the
package, on its own Keccak sponge, and the optional system dependency is
gone along with the `./configure` step that probed for it.

- [`fips_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md),
  [`fips_public_key()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md),
  [`fips_key()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_key.md)
  and
  [`fips_sizes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_sizes.md)
  are the new entry points.
  [`pqc_backends()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_backends.md)
  now reports a fixed list – ML-DSA at all three parameter sets and
  SLH-DSA at all twelve, six over SHAKE and six over SHA-2 – available
  in every build.
  [`fips_key()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_key.md)
  wraps key material from elsewhere, so a key written by another
  implementation can be used directly.
- SHA-512, HMAC and MGF1 gained the pieces the SHA-2 instantiation of
  FIPS 205 needs. Its address is compressed from 32 bytes to 22 with
  every field moved, its message randomiser is an HMAC and its digest an
  MGF1, and its multi-block tweakable hash switches to SHA-512 at
  192-bit security and above but its single-block one does not – none of
  which a test that only signs and verifies would notice.
- [`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md)
  and
  [`capsule_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_verify.md)
  gained `context`, the context string both standards bind into the
  message encoding, so one key can be used for two purposes without a
  signature crossing between them.
  [`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md)
  also gained `deterministic`, selecting the variant whose output
  depends only on key, message and context.
- [`oqs_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/oqs_keygen.md)
  and
  [`oqs_public_key()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/oqs_keygen.md)
  are deprecated in favour of the `fips_*` names and now warn. They
  still work, and still return the same classes.

Every parameter set is checked against OpenSSL 3.5, which shares no code
with this package: in deterministic mode the two produce the SAME BYTES,
over several message and context lengths, and each verifies the other’s
signatures. That cross-check is the conformance claim. Reference parity
is not: this implementation matched the pq-crystals and sphincsplus
reference code byte for byte while disagreeing with the standards twice
over – FIPS 204 and FIPS 205 both prepend a context domain separator the
reference code omits, and FIPS 205 reads the FORS indices most
significant bit first where SPHINCS+ read them least significant bit
first. Neither is detectable from the inside: a signature scheme that
verifies only its own output still rejects every tampering.

## rmoriebricklayer 0.4.0

The release that makes a capsule answer three questions a checksum
cannot: is this still the same *data*, who *says* so, and what is
actually *in* it.

### Is this still the same data?

A SHA-256 tells you the bytes changed. It cannot tell you whether the
distribution changed – and those are different questions. A re-released
open-data extract legitimately has a different digest while being the
same data statistically; conversely a column can keep its name, its type
and its row count while having been silently rescaled, and no digest
notices.

- [`capsule_drift()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_drift.md)
  tests every shared column between a pinned extract and a fresh fetch,
  and reports which moved.
- [`drift_ks()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drift_ks.md)
  (two-sample Kolmogorov-Smirnov),
  [`drift_psi()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drift_psi.md)
  (population stability index and Jensen-Shannon divergence),
  [`drift_homogeneity()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drift_homogeneity.md)
  (two-sample chi-square) and
  [`drift_chisq()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drift_chisq.md)
  (goodness-of-fit against a known distribution) are available
  individually.
- [`benford_test()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/benford_test.md)
  screens a numeric column’s leading digits against Benford’s law – a
  cheap check on figures that were rounded, capped or invented. It is a
  screen, not a verdict, and says so.

[`capsule_drift()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_drift.md)
uses the two-sample homogeneity test for categorical columns, not
goodness-of-fit: the reference is itself a finite sample, and treating
it as a known distribution ignores its sampling error and reports drift
too readily. For the same reason the population stability index is
reported as an effect size but only allowed to raise the drift flag once
both samples pass `psi_min_n` – its 0.25 “material shift” band is a
large-sample heuristic with no calibrated null, and on a few hundred
rows binning noise alone clears it.

### Who says so?

A digest in a manifest proves the data was not corrupted. It proves
nothing about who produced it, because anyone who edits the data can
recompute the digest.

- [`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md)
  /
  [`capsule_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_verify.md)
  authenticate a manifest, either with a shared secret (`HMAC-SHA-256`,
  RFC 2104) or with a post-quantum, asymmetric, hash-based signature.
- [`pqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_keygen.md)
  builds that signature’s key: a Merkle tree over Winternitz one-time
  keys, following the RFC 8391 construction over the SHA-256 this
  package already ships. Its security rests on the hash alone – no
  lattice assumption, no elliptic curve, nothing Shor’s algorithm
  breaks, and no new system dependency.
- [`merkle_root()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_merkle.md)
  and friends pin a capsule chunk by chunk, so a mismatch names *which*
  chunk moved rather than only that the file did.
- [`chain_new()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_chain.md)
  /
  [`chain_append()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_chain.md)
  link each manifest to the digest of the one before, making the run
  history tamper-evident.
  [`chain_seal()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_chain.md)
  is the value to sign: the head alone misses a deletion from the middle
  and the links alone miss a truncation from the end.

On post-quantum choices: SHA-2 and HMAC are already adequate against a
quantum adversary, since Grover only halves the exponent. Signatures are
the part Shor breaks, so that is the part replaced.

A lattice scheme is deliberately **not** hand-rolled here – an
uncertified hand-written NTT and rejection sampler would be a worse
outcome than no lattice signature. Instead, `./configure` looks for
liboqs, and where it is found
[`oqs_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/oqs_keygen.md)
exposes the standardised schemes – ML-DSA (FIPS 204) and SLH-DSA (FIPS
205) – computed entirely by that library.
[`pqc_backends()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_backends.md)
reports what the build actually enabled, checked per scheme, since
liboqs is configurable. Absence is not an error: the package builds
without it, and the bundled hash-based scheme needs nothing.

Unlike the hash-based key, the standardised keys are STATELESS – one key
signs any number of messages, with no leaf index to track. A signature
is never verified against a key of a different scheme.

A height-`h` signing key signs exactly `2^h` messages. Signing twice at
one index breaks the scheme outright, so
[`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md)
tracks the index, returns the advanced key state, and refuses an
exhausted key rather than wrapping around.

### What is actually in it?

A capsule is only worth pinning if somebody looked at the data first,
and the look is the step that gets skipped.

- [`profile_columns()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/profile_columns.md)
  describes every column: type, missingness, distinct values, the counts
  of zero, negative and infinite values, the classical *and* robust
  centre and spread side by side (where they disagree, the mean is not
  describing the column), and an
  [`inline_hist()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/inline_hist.md)
  sketch that shows bimodality no summary number carries.
- [`frequency_table()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/frequency_table.md),
  [`correlation_table()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/correlation_table.md),
  [`top_correlations()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/top_correlations.md),
  [`duplicate_rows()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/duplicate_rows.md),
  [`drop_empty()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_drop.md),
  [`drop_constant()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_drop.md)
  and
  [`clean_column_names()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/clean_column_names.md)
  cover the rest of a first pass.
- [`mahalanobis_outliers()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mahalanobis_outliers.md)
  finds rows that are unremarkable on every variable separately and
  impossible jointly. It defaults to a robust centre and scale, because
  outliers inflate the very covariance used to judge them.
- [`missingness_summary()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/missingness_summary.md),
  [`missingness_pattern()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/missingness_pattern.md),
  [`missing_runs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/missing_runs.md)
  and
  [`missingness_map()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/missingness_map.md)
  describe the *shape* of the gaps, not just the rate: whether columns
  are missing together, and whether a gap is one outage or scattered
  failures.
- [`mcar_test()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mcar_test.md)
  is Little’s test for missing-completely-at-random – the assumption
  that licenses dropping incomplete rows. It carries an
  expectation-maximisation estimator, because the maximum-likelihood
  mean and covariance under missingness have no closed form; on complete
  data that estimator reproduces the ML estimates exactly.
- [`environment_diff()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/environment_diff.md)
  reports what moved between two runs’ captured environments, which is
  the question a failed reproduction actually raises.

### One command for the whole assessment

[`capsule_report()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_report.md)
runs the checks above over one data frame and collects the findings into
a single report, ordered by severity: a missing required column is
`fatal`, a drifted column or an unverified signature is a `warn`, an
outlier or a Benford departure is a `note`. It exists because the
failure mode this package is built against is a person running one
check, seeing it pass, and concluding the data is fine.

Each problem is reported ONCE. An entirely missing column is missing, is
trivially constant, and makes any covariance singular; reporting all
three would bury the findings that matter under a single cause. The
collinearity note therefore fires only for a genuinely duplicated or
derived column, which is the case that tells the reader something new.

[`report_markdown()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/report_markdown.md)
writes the assessment beside the capsule it describes. Both renderings
carry the caveat that no finding is proof of correctness.

### Schemas and rules

- [`infer_schema()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/infer_schema.md)
  derives the schema
  [`validate_schema()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/validate_schema.md)
  consumes from data you already trust, so a capsule need not be pinned
  on nothing. It describes one extract and should be read and edited,
  not trusted blindly.
- [`validate_schema()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/validate_schema.md)
  gains the checks to match: column types (with integer and double
  treated as interchangeable), numeric ranges, and per-column
  missingness ceilings. Every field stays optional, so schemas written
  for earlier versions are unaffected.
- [`rule()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rule.md)
  and
  [`validate_rules()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/validate_rules.md)
  express the project-specific checks a generic schema cannot – an age
  that must be non-negative, two dates that must be ordered – and
  [`rule_in_set()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_rule_library.md),
  [`rule_between()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_rule_library.md),
  [`rule_not_null()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_rule_library.md),
  [`rule_unique()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_rule_library.md),
  [`rule_regex()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_rule_library.md),
  [`rule_increasing()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_rule_library.md),
  [`rule_within_n_mads()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_rule_library.md),
  [`rule_complete_rows()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_rule_library.md),
  [`rule_distinct_rows()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_rule_library.md)
  and
  [`rule_col_count()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_rule_library.md)
  supply the common ones ready-made.

### Capsules larger than memory

- [`online_summary()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_online.md)
  accumulates mean, variance, skewness and kurtosis block by block. The
  merge is **exact** – Chan, Golub and LeVeque’s parallel combination
  with Terriberry’s higher moments – so a chunked pass agrees with a
  single batch pass rather than approximating it.
- [`reservoir_indices()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_reservoir.md)
  /
  [`reservoir_sample()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_reservoir.md)
  take a uniform sample of a stream in one pass (Vitter’s Algorithm R).
- [`distinct_sketch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_distinct.md)
  /
  [`distinct_count()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_distinct.md)
  estimate cardinality in fixed memory (HyperLogLog), with the published
  relative error.

### Newly reachable

Several things existed in the package with no way to call them. The
compiled core carried kernels that had no binding, and the JSON codec
had three internal helpers:

- [`core_sd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_core_spread.md),
  [`core_dist()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_core_spread.md),
  [`core_normal_logpdf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_normal_logpdf.md),
  [`core_bootstrap_mean()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_bootstrap_mean.md),
  [`core_ipw_weights()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_ipw_weights.md),
  [`core_gamma_cdf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_gamma_cdf.md)
  and
  [`core_hawkes_nll()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_hawkes_nll.md)
  now reach kernels that were already compiled in.
- [`bricklayer_json_serialize()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_json_serialize.md)
  /
  [`bricklayer_json_unserialize()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_json_serialize.md)
  – lossless JSON that round trips an object rather than only its data –
  were internal, and left a dangling documentation link.
- The base64 codec
  ([`bricklayer_json_base64_enc()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_base64.md)
  and the URL-safe variant) was internal too.
- [`json_gzip_encode()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_json_gzip.md)
  /
  [`json_gzip_decode()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_json_gzip.md)
  are new: gzip plus base64, for a payload that travels.

All of these are published through `LinkingTo: rmoriebricklayer`, so
`rmorie` and `rmoriedata` call one compiled copy rather than carrying
their own.

### Keys

[`pqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_keygen.md)’s
seeds previously came from a function that mixed the clock, the process
id and R’s Mersenne Twister.
[`set.seed()`](https://rdrr.io/r/base/Random.html) makes R’s generator
reproducible by design and its state is recoverable from its output, so
a key drawn from it is guessable.

- [`random_bytes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/random_bytes.md)
  reads the operating system’s CSPRNG and **fails** rather than falling
  back to a weaker source.
- [`derive_key()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/derive_key.md)
  is PBKDF2-HMAC-SHA256, so a passphrase can stand in for raw key bytes.
- [`core_blake2b()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_blake2b.md)
  is a natively keyed digest of any width from 1 to 64 bytes – a MAC
  without the HMAC construction.
- [`digest_object()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/digest_object.md)
  fingerprints an arbitrary R object.

### Behaviour changes worth knowing about

Three functions now REFUSE input they previously computed through. In
each case the old answer was a number produced by an internal guard
rather than by the data, which is worse than an error because it looks
like a result.

- [`mahalanobis_outliers()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mahalanobis_outliers.md)
  and
  [`mcar_test()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mcar_test.md)
  reject exactly collinear or constant columns. Both repair a singular
  covariance by flooring its eigenvalues so the algorithm can proceed;
  with a duplicated column that floor, not the data, determined the
  answer.
  [`mcar_test()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mcar_test.md)
  checks the complete-case covariance where it can, because two
  identical columns with different missingness leave the pairwise
  covariance only nearly singular.
- [`capsule_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_verify.md)
  rejects a signature presented with a key of a different scheme
  explicitly. It already failed, but incidentally, on a length mismatch.

### SIU parser fixes

Four defects in the report parser, each of which produced a wrong field
rather than an error:

- statute sections with a decimal were dropped, so
  `Section 320.13, Criminal Code` – the ordinary dangerous-driving
  citation – never reached `relevant_legislation`;
- the director’s name and the police service both reached back across a
  line break, so the real signature block
  `Dated at Toronto.\n\nAlex Morrow\nDirector` yielded
  `"Toronto. Alex Morrow"`, and a force named once just under a heading
  picked the heading up with it;
- only `&amp;`, `&nbsp;` and one smart quote were decoded, so `&lt;`,
  `&gt;`, `&quot;`, `&apos;`, the remaining quotes and the dashes
  survived into the extracted text.

### Statistics for the tables these capsules hold

An open-data extract from a criminal-justice system has a shape the
general-purpose toolkits do not assume: a handful of fiscal years,
counts rather than measurements, categories reported as bands rather
than values, and a region code with no geometry attached.

[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
computes period-over-period change and declines it in the three cases
where the figure would describe something other than the data. Periods
are matched on their own **value**, not on row position, so a missing
year is a gap rather than a quietly multi-year comparison. A percent off
a base below the gate is withheld with its reason recorded – two
placements becoming twenty is a 900% rise and also nothing at all –
while the count change and the direction are still reported, those being
facts. A column already in percent is handled in percentage **points**,
a percent of a percent being a different quantity. For counts the
interval is exact: conditional on the two periods’ total the current
count is binomial, so the ratio has a Clopper-Pearson interval, verified
identical to
[`stats::poisson.test`](https://rdrr.io/r/stats/poisson.test.html) on
every case including both zero boundaries.

- [`yoy_write()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_write.md)
  renders to HTML, PDF, CSV, TSV, JSON or Markdown, with the format
  taken from the file name;
  [`yoy_html()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_render.md),
  [`yoy_pdf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_render.md),
  [`yoy_csv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_delim.md),
  [`yoy_tsv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_delim.md),
  [`yoy_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_delim.md)
  and
  [`yoy_markdown()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_delim.md)
  are available individually. Nothing here needs a package beyond base
  R: the HTML is self-contained and makes no network request, so it
  renders later as it rendered when the capsule was sealed, and the PDF
  is drawn on R’s own device and paginates rather than truncating.
- [`yoy_summary()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_summary.md)
  gives the change across the whole span and the compound rate per
  period.
  [`yoy_label()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_label.md)
  and
  [`fiscal_year_label()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fiscal_year_label.md)
  render a fiscal year by the years it spans, so an `EndFiscalYear` of
  2023 prints as `2022/23` rather than naming a calendar year the row is
  not about.
- Colour encodes whether a change is an **improvement**, which is not
  the sign of the change: segregation days rising is bad news and a
  completion rate rising is not.
  [`yoy_palettes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_palettes.md)
  offers a colour-blind-safe pair and a monochrome option for print.

### Categories published as intervals

[`parse_bands()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/parse_bands.md)
reads the interval labels publishers actually use – `"2 to 5"`, `"50+"`,
`"Greater than 10"`, `"under 18"`, and the whole dash family – and
returns **bounds**, distinguishing the inclusive wordings from the
exclusive ones: `"65 and over"` starts at 65 and `"over 65"` at 66,
which is a whole unit of the quantity being measured.

- [`band_values()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/band_values.md)
  makes the representative-value rule explicit, and marks the rows whose
  value rests on an assumption about the open top band, that band having
  no midpoint to take.
- [`band_sensitivity()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/band_sensitivity.md)
  reports how far a derived statistic moves as the assumed cap varies.
  Everything computed from banded data carries that dependence; the only
  question is whether it was measured.

### Concentration, association and heavy tails

- [`gini()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/concentration.md),
  [`lorenz()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/concentration.md)
  and
  [`top_share()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/concentration.md)
  answer whether a few units account for most of a total. Gini is
  verified both against the mean-absolute-difference definition and
  against twice the area under its own Lorenz curve. Its maximum for `n`
  units is `1 - 1/n`, not 1, so the value means different things across
  ten units and ten thousand.
- [`hill_tail_index()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hill_tail_index.md)
  maximises the **exact** discrete likelihood. The closed-form
  continuity correction usually quoted is an asymptotic approximation in
  the threshold, and at a threshold of one – where administrative counts
  start – it returns about 2.0 from data generated with an exponent of
  2.5. It also reports a goodness-of-fit distance, because an exponent
  fitted to a tail that is not a power law is a number with no referent.
- [`hurwitz_zeta()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hurwitz_zeta.md)
  is the normalising constant that needs, computed by Euler-Maclaurin
  and verified against `pi^2/6`, `pi^4/90`, Apery’s constant and the
  shift identity.
- [`cramers_v()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cramers_v.md)
  carries Bergsma’s bias correction, without which a sparse table
  reports association that is an artefact of its size, and permutes its
  p-value rather than trusting the chi-square approximation when an
  expected count is small.

### Trend in a series of a few periods

- [`trend_test()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/trend_test.md)
  is Mann-Kendall with a Theil-Sen slope: no distributional assumption,
  resistant to one aberrant period, exact by enumeration up to eight
  periods, and agreeing with
  [`stats::cor.test`](https://rdrr.io/r/stats/cor.test.html)’s tau and
  exact p-values.
- [`step_change()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/step_change.md)
  scans every admissible split and takes its p-value from the
  permutation distribution of the **maximum** over splits, not from the
  best split’s own test – which is how a break is found in any series.
  It records that six points cannot produce a p-value below
  `(1 + 72) / (1 + 720)` however clean the step.
- [`count_trend()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/count_trend.md)
  is a Poisson rate ratio per period, matching
  [`stats::glm`](https://rdrr.io/r/stats/glm.html) to 1e-8, with an
  offset for a varying denominator and a widening to quasi-Poisson when
  the dispersion says the Poisson interval is too narrow.

### Region-coded counts

A region is an areal unit with a population, not a coordinate.

- [`expected_counts()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/expected_counts.md)
  does indirect standardisation, removing the part of a difference
  explained by who the area holds. The expected counts total the
  observed ones, which is the identity that makes them a standardisation
  rather than a prediction.
- [`sir()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/sir.md)
  reports the ratio with the exact Poisson interval, identical to
  [`stats::poisson.test`](https://rdrr.io/r/stats/poisson.test.html)’s,
  including a lower limit of exactly zero at an observed count of zero.
- [`eb_rates()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/eb_rates.md)
  is the Clayton-Kaldor empirical Bayes shrinkage, which stops a small
  area’s noise from ranking it to the top or bottom of a league table.
  Where the between-area variance estimate is not positive there is no
  evidence of real variation and every estimate collapses to the overall
  rate, reported through total shrinkage rather than hidden.
- [`funnel_limits()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/funnel_limits.md)
  gives exact Poisson control limits, which stay correct at the small
  expected counts where a normal funnel’s lower limit goes below zero.
- [`morans_i()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/morans_i.md)
  requires a neighbour list and does not invent one, an extract keyed on
  a region shipping no geometry. Its null expectation is `-1/(n - 1)`,
  not zero.

Two vignettes cover the lot: *Year-over-year change, and the three ways
it goes wrong* and *Statistics for a published administrative table*.

### Byte compatibility

Every hash, keyed hash, checksum, key derivation, base64 and JSON output
is now compared against an **independent** implementation – `digest`,
`openssl`, `jsonlite` and base R’s own inflater – over a length sweep
crossing each construction’s block boundaries. Published vectors prove a
primitive reproduces a handful of documented inputs; they do not prove
it agrees with the libraries already in a user’s pipeline. SHA-256,
SHA-512, HMAC-SHA-256, BLAKE2b, PBKDF2 and the JSON writer were already
exact. Five things were not.

- **Merkle chunks could not hold binary data at all.** Chunks were taken
  as strings and measured with `strlen`, and
  [`chunk_file()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chunk_file.md)
  called [`rawToChar()`](https://rdrr.io/r/base/rawConversion.html),
  which errors on any file containing a zero byte. A raw vector handed
  in was coerced, so `merkle_root(list(charToRaw("a")))` hashed deparsed
  text and returned a confident digest of the wrong thing. Chunks are
  now bytes end to end, and
  [`chunk_file()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chunk_file.md)
  returns a list of raw vectors. **Roots for character input are
  unchanged**, so manifests already recorded still verify.
- **[`json_gzip_encode()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_json_gzip.md)
  did not produce gzip.** `memCompress(type = "gzip")` emits a zlib
  stream (RFC 1950, header `0x78 0x9c`), not a gzip member (RFC 1952,
  `0x1f 0x8b`), and `memDecompress` reads both – so the round trip
  looked correct while no external tool could read bytes the
  documentation calls “raw gzip bytes, for writing to a file”. Now a
  real member, with the CRC-32 and length trailer, and MTIME pinned to
  zero so a capsule digest does not move with the clock.
- **base64 line-wrapping was off by one byte** at every multiple of 54
  input bytes. The wrap terminates the 54-byte input block, not the
  72-character output, and 52, 53 and 54 bytes all encode to 72
  characters while only 54 fills a block. A field encoded by `jsonlite`
  and re-encoded here differed, and a digest comparison read that as
  drift. Now exact over every length from 0 to 400.
- **[`digest_object()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/digest_object.md)
  accepted `key` but wired it only to blake2b**, so a keyed `sha256`,
  `sha512` or `crc32` silently returned the *unkeyed* digest – an
  authentication request answered with a checksum. `sha256` now routes
  to HMAC-SHA-256 and the two algorithms with no keyed form refuse the
  key.
- **[`json_gzip_decode()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_json_gzip.md)
  trusted its flag over its input’s type**, so handing back what
  `json_gzip_encode(raw = TRUE)` returned, without repeating the flag,
  ran the bytes through a base64 decode and failed inside the inflater.

### Newly reachable through LinkingTo

`gini`, `top_share`, `lorenz`, `mann_kendall`, `theil_sen` and
`hurwitz_zeta` are published with `R_RegisterCCallable` and shimmed in
`inst/include/rmoriebricklayer.h`, so a sibling package reaches them
without going back through R.

A consumer package is now built **and run** against the header as part
of the suite. The two halves fail independently: a signature mismatch is
a compile error, while a wrong name in `R_RegisterCCallable` compiles
perfectly and raises only on first call, `R_GetCCallable` resolving
lazily. That test immediately earned its place by recording a real
requirement – **`LinkingTo` alone is not enough**. It puts the header on
the include path at compile time but does not load the providing
package, so a consumer needs `Imports: rmoriebricklayer` as well or the
first kernel call raises “function ‘rmbl_gini’ not provided by package
‘rmoriebricklayer’”.

### Verification

Everything with a published test vector is checked against it: SHA-512
against FIPS 180-4, HMAC-SHA-256 against RFC 4231, PBKDF2-HMAC-SHA256
against the published vectors including the multi-block case, BLAKE2b
against RFC 7693, and CRC-32 against the ITU V.42 check value. The
statistics are anchored on base R, the Merkle construction on digests
recomputed by hand, and the exceedance and reservoir distributions on
exhaustive enumeration and simulation respectively.

The XMSS signature scheme is **byte-compatible with the RFC 8391
reference implementation**. Getting there required fixing three
divergences from the specification, none of which the previous
security-property tests could detect, because a sound-but-wrong
pseudorandom function passes every one of them:

- the WOTS+ chain seeds came from `PRF(SK_SEED, toByte(i, 32))` rather
  than `PRF_keygen(SK_SEED, PUB_SEED || ADRS)` (NIST SP 800-208’s domain
  4);
- the message digest was keyed with `PUB_SEED`, with the index and root
  pushed into the message, rather than keyed with
  `R || root || toByte(idx, n)` as section 4.1.9 requires;
- there was no `SK_PRF`, so the per-signature randomiser `R` that the
  RFC binds the digest to did not exist at all.

The whole 2500-byte signature for XMSS-SHA2_10_256 – index, randomiser,
WOTS+ signature and authentication path – now matches the reference byte
for byte, and the vectors are embedded in the test suite so the check
needs neither a network nor a C toolchain.

**This changes the key and signature formats.**
[`pqc_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_keygen.md)
now generates a third secret (`sk_prf`) and
[`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md)
returns `randomizer` and `wire` alongside the existing fields. A key
made by an earlier build cannot sign, and a signature made by one cannot
be verified; both raise an explicit error rather than failing quietly.
Nothing is lost in practice, because signing is new in this release and
was never in a version on CRAN.

It is verified against its security properties as well – a valid
signature verifies, and every tampering of the message, signature,
authentication path, index or key fails – and it must still not be
treated as *certified*, which is a statement about process rather than
about the bytes. The standardised schemes carry no such caveat, because
they are liboqs’s implementation rather than one of ours; what is tested
here is the binding, including that ML-DSA-65 produces the key and
signature sizes FIPS 204 specifies.

Everything added in this release is anchored outside itself. The exact
count interval is checked against
[`stats::poisson.test`](https://rdrr.io/r/stats/poisson.test.html), the
Poisson trend against [`stats::glm`](https://rdrr.io/r/stats/glm.html),
Kendall’s tau and its exact p-values against
[`stats::cor.test`](https://rdrr.io/r/stats/cor.test.html), the funnel
limits against [`stats::qpois`](https://rdrr.io/r/stats/Poisson.html),
Gini against its own definition and its own Lorenz curve, the Hurwitz
zeta against three published constants and a functional identity, and
the tail-index estimator against samples whose exponent is known by
construction – the only anchor that can fail, since comparing against
the closed form would compare against the thing being replaced. The
statistical methods are grounded in the local corpus where it has them
(Lawson on standardised incidence ratios and Clayton-Kaldor shrinkage;
Hedderich and Sachs on the Lorenz construction and the indirect/direct
distinction); Bergsma and Clauset-Shalizi-Newman are not in it and are
cited from the published papers, marked as such.

Three source-level invariants are now checked too, because they break
only on platforms the development host is not: that no R header precedes
a standard header reaching libc++’s `<locale>` (R’s `length` macro
otherwise rewrites it, which fails on macOS and is silent on Linux),
that every C entry point is registered with a matching arity and every
registration resolves, and that no source file carries a non-ASCII byte.

The suite is 5,300 assertions at 97.6% coverage, and
`R CMD check --as-cran` is clean.

## rmoriebricklayer 0.3.11

Test fix; no code changes.

`test-json-branches.R` asserted one platform’s spelling of a
full-precision double. With `digits = NULL` the encoder calls
`sprintf("%.17g", ...)`, which asks the C library for 17 significant
digits and lets it choose how to print them: x86 gives
`9.9999999999999995e-21` for `1e-20`, Windows arm64 gives `1e-20`. Both
are the same double and both round trip, but the hard-coded expectation
failed the arm64 builds on r-universe.

The test now asserts the contract the option actually promises – full
precision that survives a round trip – and carries an anchor that fails
if the round trip stops being exact.

## rmoriebricklayer 0.3.10

Documentation only; no code changes.

The manual still credited ‘jsonlite’ and ‘digest’ for work the package
now does itself, which had been true before 0.3.8 moved both to Suggests
behind a native JSON codec and a compiled SHA-256 core:

- [`load_provenance()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/load_provenance.md)
  said it parsed via
  [`jsonlite::fromJSON()`](https://jeroen.r-universe.dev/jsonlite/reference/fromJSON.html),
  and linked to it; it reads with
  [`bricklayer_json_from_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_json_from_json.md).
- [`verify_capsule()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_capsule.md)’s
  example called
  [`jsonlite::write_json()`](https://jeroen.r-universe.dev/jsonlite/reference/read_json.html)
  – a Suggests package used unconditionally in an example. It now writes
  with
  [`bricklayer_json_to_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_json_to_json.md).
- [`sha256_file()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/sha256_file.md)
  and
  [`verify_sha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_sha256.md)
  said they hashed “via the digest package”; they use the compiled core,
  or the bundled pure-R FIPS 180-4 implementation when a capsule is
  sourced standalone.
- [`wayback_snapshot_url_native()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wayback_snapshot_url_native.md)
  described the R-level resolver it supersedes as “jsonlite-based”; that
  resolver parses natively too.
- [`write_manifest_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/write_manifest_json.md)‘s
  example said it round-tripped through ’jsonlite’.

## rmoriebricklayer 0.3.9

CRAN release: 2026-09-08

- The native JSON codec is now jsonlite’s complete mapping: every
  `toJSON()` option
  (dataframe/matrix/Date/POSIXt/factor/complex/raw/null/na/digits/
  pretty/force plus rownames, keep_vec_names, json_verbatim,
  always_decimal, time_format, UTC, no_dots), the same number formatting
  (`num_to_char` / `modp_dtoa2` rules), `fromJSON()` simplification
  (record lists, matrices, arrays, `$date`, `_row`, `"NA"` strings),
  prettify/minify (yajl layout), validate,
  serializeJSON/unserializeJSON, base64, ndjson streaming and
  rbind_pages. A parity test pins all of it to jsonlite byte-for-byte
  when jsonlite is installed (1,742 cases, 0 differences).
- Standalone capsule bundles: `make_bundle.sh` now ships `json_native.R`
  and a pure-R SHA-256 (`sha256_native.R`), `setup_and_run.R` no longer
  requires jsonlite, and
  [`sha256_file()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/sha256_file.md)
  falls back to the pure-R digest when the compiled core is not loaded.
  This fixes the 0.3.8 CI failure of the otis-mrp bundle
  (`bricklayer_json_from_json` not found).
- pkgdown index and examples for the two exported codec functions.

## rmoriebricklayer 0.3.8

- No more runtime dependence on ‘digest’ or ‘jsonlite’: Imports is now
  base R only (`stats`, `utils`).
  [`sha256_file()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/sha256_file.md)
  hashes through the compiled SHA-256 core that already backed
  [`core_sha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_sha256.md);
  every JSON read (CKAN, Socrata, ArcGIS, Wayback metadata, local
  manifests) and the manifest writer go through a new pure-R,
  jsonlite-compatible codec exported as
  [`bricklayer_json_from_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_json_from_json.md)
  /
  [`bricklayer_json_to_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_json_to_json.md)
  (same simplification rules and encoder options as jsonlite). Both old
  packages move to Suggests and are only used by the cross-check tests,
  which pin the native codec and hash to their output when installed.
- Remote JSON endpoints are fetched with
  [`bricklayer_fetch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_fetch.md)
  (the compiled fetch core with its Wayback fallback) instead of
  jsonlite’s URL reader.

## rmoriebricklayer 0.3.7

CRAN release: 2026-08-05

- Test-only change: local_mocked_bindings() tests are guarded so they
  skip cleanly under a bare testthat::test_dir() (they need the package
  namespace, which devtools::test() and R CMD check provide). No
  user-facing change.

## rmoriebricklayer 0.3.6

- CRAN incoming-pretest NOTE cleanup: quote ‘Wayback Machine’ in
  DESCRIPTION; README Code-of-Conduct link is now an absolute URL (the
  file is .Rbuildignore’d, so the relative URI flagged as invalid).

## rmoriebricklayer 0.3.5

- SIU features now live natively in bricklayer: the deterministic
  parse/resolve core is part of `src/` (zero new dependencies,
  hand-rolled `.Call` glue like the rest of the backend). New:
  [`bricklayer_parse_siu()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_parse_siu.md)
  (16 schema fields + language from report HTML or a saved file),
  [`bricklayer_fetch_parse_siu()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_fetch_parse_siu.md)
  (fetch + parse in one call),
  [`bricklayer_siu_schema()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_siu_schema.md),
  [`bricklayer_siu_text()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_siu_text.md),
  [`bricklayer_siu_iso_date()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_siu_iso_date.md),
  [`bricklayer_siu_resolve_so()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_siu_resolve_so.md)
  (rule-ordered subject-official count; 0 is a real answer).
  Synthetic-report fixture + offline tests included.

## rmoriebricklayer 0.3.4

- CRAN reviewer round (K. Lauseker, 0.3.0): spell out CKAN + SHA-256 and
  link the CKAN/Wayback web services in DESCRIPTION; agent_bundle
  example `\dontrun` -\> `\donttest`; setup_and_run.R no longer calls
  [`setwd()`](https://rdrr.io/r/base/getwd.html),
  [`install.packages()`](https://rdrr.io/r/utils/install.packages.html),
  or
  [`installed.packages()`](https://rdrr.io/r/utils/installed.packages.html)
  (checks via
  [`requireNamespace()`](https://rdrr.io/r/base/ns-load.html) and prints
  the install command instead).

## rmoriebricklayer 0.3.3

- Add `bricklayer_fetch_siu(drid, dest)`: fetch an Ontario SIU
  director’s report by drid through the live+Wayback engine – the fetch
  step of the open SIU corpus pipeline.

## rmoriebricklayer 0.3.2

### Documentation

- Every exported function now carries exhaustive, multiple-example
  documentation covering each argument, edge cases, and a realistic
  workflow (previously most had a single one-liner).
- Version bump ensures the
  [`bricklayer_fetch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_fetch.md)
  help topic (added in an earlier 0.3.1 build without a version bump)
  propagates to the r-universe binary and downstream reverse-dependency
  checks.

## rmoriebricklayer 0.3.1

### rOpenSci submission preparation

- License wording corrected: the optional `rmorie` CLI that
  [`agent_bundle()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/agent_bundle.md)
  forwards to is AGPL-3.0-or-later (the entire MORIE family is AGPL; an
  earlier internal comment mislabelled it proprietary).

- Package moved from the `bricklayer/` subdirectory to the repository
  root (required by rOpenSci’s review tooling); repo-level extras stay
  as `.Rbuildignore`d siblings.

- New vignette `capsules.Rmd` walking the essential flow offline:
  provenance pin -\> schema validation -\> SHA256 integrity -\>
  synthetic fallback -\> manifest + summary.

- Every exported function now has runnable `@examples` (network calls in
  `\donttest`; offline NULL-contracts shown runnable).

- README gained development-version install instructions.

- New CI: test coverage (covr + Codecov) and rOpenSci `pkgcheck`.

- Test coverage raised from 84 percent to 96 percent: offline tests for
  the CKAN/Socrata/ArcGIS resolver success paths, `friendly_download`
  diagnostics and Wayback retry, summary contact/licence blocks, pinned
  script hashes, and the multi-block SHA-256 path. Dead
  `requireNamespace` guards for Imports (`digest`, `jsonlite`) removed.

- Repo-level `LICENSE` text excluded from the build (`License: AGPL-3`
  is the canonical spec; the stray file triggered a check NOTE).

## rmoriebricklayer 0.3.0

### Capsule-level integrity

- New
  [`verify_capsule()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_capsule.md):
  one call re-verifies an entire reproducible data capsule offline:
  provenance readability, pinned sha256/size/row count, schema validity,
  script hash, and re-derivation of every stored manifest cross-check
  from its own numbers.
- New
  [`capture_environment()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capture_environment.md)
  records R version, platform, OS, UTC timestamp, and loaded package
  versions;
  [`make_manifest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/make_manifest.md)
  now attaches it by default (`environment = FALSE` to opt out).
- New
  [`cite_capsule()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cite_capsule.md)
  generates a ready-to-paste data citation (text + BibTeX `@misc`,
  DOI-aware) from a provenance object.

### Portal coverage

- New
  [`resolve_via_socrata()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/resolve_via_socrata.md)
  and
  [`resolve_via_arcgis()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/resolve_via_arcgis.md)
  extend URL-rot recovery beyond CKAN to the Socrata
  (Calgary/Chicago/NYC) and ArcGIS FeatureServer (Toronto Police
  Service) portals the MORIE family fetches from.

## rmoriebricklayer 0.2.5

- `make_synthetic_column("id_pattern")` without a `year_col` now returns
  all `n` ids (a vectorised-`gsub` misuse returned a single id).
- `bernoulli` columns unlist JSON-derived `labels`, fixing mangled
  column names from provenance-parsed schemas.
- Single-value `row_replication` no longer trips base R’s scalar
  [`sample()`](https://rdrr.io/r/base/sample.html) expansion.
- Test suite grown from 9 to 43 behavioural tests covering the full
  export surface (provenance, CKAN guards, Wayback handling, offline
  <file://> downloads, sha256, schema validation, manifests, synthetic
  generation, RNG hygiene).

## rmoriebricklayer 0.2.4

- [`make_synthetic_csv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/make_synthetic_csv.md)
  now restores the caller’s `.Random.seed` on exit (CRAN policy: no
  lasting RNG-state change).
- First CRAN submission prep: `cran-comments.md`, build exclusions.

## rmoriebricklayer 0.2.3

- Capsule terminology adopted across the documentation; CITATION added;
  37/37 reproduction checks in `examples/otis-mrp/`.
