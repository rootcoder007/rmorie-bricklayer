# Open the analysis dashboard

A local web app over the package's analyses: load a CSV file, the pinned
data of a capsule, or a table from data.rmorie.com (after `rmbl login`),
then run the analysis families through forms, with the package's own
plots and reports. Everything runs on this machine in this R session;
nothing is sent anywhere except the data.rmorie.com requests you make.

## Usage

``` r
rmblapp(data = NULL, capsule = NULL, ...)
```

## Arguments

- data:

  A data frame, or the path of a CSV file, to start with; `NULL` for
  none.

- capsule:

  The directory of a capsule whose pinned data to start with; `NULL` for
  none.

- ...:

  Options passed to
  [`shiny::shinyApp()`](https://rdrr.io/pkg/shiny/man/shinyApp.html),
  such as `port` and `launch.browser`.

## Value

A shiny app object; printing it (or
[`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html)) starts
it.

## Details

Every analysis shows the R call it ran, and runs exactly that call, so a
result can be reproduced in a script by copying the code. A refusal is
shown as the package words it, with
[`explerr()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/explerr.md)'s
explanation of where it comes from beside it. The tabs:

- Describe:

  [`profcols()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/profcols.md),
  [`freqtbl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/freqtbl.md),
  [`cortbl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cortbl.md),
  [`mahaoutl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mahaoutl.md),
  [`missgrid()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/missgrid.md)
  and the distribution plots
  ([`plotrdg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plotmore.md),
  [`plotecdf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plotmore.md),
  [`plotvln()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plotmore.md),
  [`plothex()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plotmore.md),
  [`plotgain()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plotmore.md));
  the column types are listed under the data source.

- Year over year:

  [`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
  with period, value, group, minimum base and direction, its plot, and
  the
  [`yoyhtml()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoyren.md)
  page to download.

- Rates:

  [`rtcalc()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rtcalc.md),
  [`ratechg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ratechg.md)
  and
  [`shrs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/shrs.md),
  with intervals and plots.

- Trends:

  [`trndtst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/trndtst.md)
  (Mann-Kendall with the Theil-Sen slope),
  [`stepchg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stepchg.md),
  [`cnttrnd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cnttrnd.md),
  and
  [`plotcal()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plotseries.md),
  [`plothrz()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plotseries.md),
  [`plotsm()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plotseries.md)
  and
  [`plotbump()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plotseries.md).

- Survey:

  [`svydes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/svydes.md)
  with weights, strata, clusters or replicate weights, then
  [`svyest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/svyest.md)
  or
  [`svycmp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/svycmp.md).

- Distributions:

  [`dstfit()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dstfit.md)
  with its density, QQ, PP and tail plots, and a synthetic sample from a
  fit through
  [`mksyncol()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mksyncol.md).

- Drift:

  the drift app of
  [`drftapp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drftapp.md)
  on two uploaded CSV files.

- Capsule:

  the provenance of a capsule (source, pinned digest, manifest,
  attestation, bundle files) and its verification rows, with buttons
  that run
  [`vrfcps()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfcps.md)
  and
  [`cpschk()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpschk.md),
  or
  [`cpsrfrsh()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsrfrsh.md).

- Policy:

  the panel and policy-evaluation functions on panel data:
  [`plndid()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plndid.md),
  [`evstudy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/evstudy.md),
  [`stgatt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stgatt.md),
  [`bacondcmp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bacondcmp.md),
  [`swtdid()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/swtdid.md),
  [`perminf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/perminf.md),
  [`syndid()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/syndid.md),
  [`mtchdid()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mtchdid.md),
  [`wcb()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wcb.md),
  [`loounit()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/loounit.md),
  [`cohtrnd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cohtrnd.md),
  [`plnpwr()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plnpwr.md),
  [`baltab()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/baltab.md)
  and
  [`tse()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/tse.md).

- First Nations, Metis and Inuit:

  the bundled Statistics Canada tables
  ([`indiex()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/indiex.md))
  or a table of your own in the same layout:
  [`indgap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/indgap.md),
  [`dstntst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dstntst.md),
  [`ordcmp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ordcmp.md),
  [`welprof()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/welprof.md)
  with
  [`dualcont()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dualcont.md),
  [`healchg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/healchg.md),
  [`mhcont()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mhcont.md),
  [`stdprev()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stdprev.md)
  and
  [`trcprog()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/trcprog.md).
  Each distinction is reported on its own, suppressed cells stay
  suppressed with their quality flags, and the panel states the OCAP and
  CARE principles and the source tables.

- Courts and corrections:

  [`stkflow()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stkflow.md),
  [`caseflow()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/caseflow.md),
  [`clrdcmp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/clrdcmp.md),
  [`dispmix()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dispmix.md),
  [`lifetbl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/lifetbl.md),
  [`crmdens()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crmdens.md),
  [`knoxtst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/knoxtst.md),
  [`rgnmapintg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rgnmapintg.md),
  and the SIU report readers
  [`siuprs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/siuprs.md)
  and
  [`siuso()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/siuso.md)
  on pasted text.

- Air pollution:

  [`plmfld()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plmfld.md)
  and
  [`gplume()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pgsig.md)
  for a Gaussian plume,
  [`crfpm25()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crfpm25.md),
  [`crfno2()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crfpm25.md),
  [`polbrdn()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/polbrdn.md)
  and
  [`vrfpol()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfpol.md).

- Hawkes:

  [`chwkfit()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chwkfit.md)
  with
  [`plothwk()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plothwk.md)
  (intensity, time-rescaling QQ, branching tree) and
  [`chwksim()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chwksim.md).

- Proof ledger:

  a ledger
  ([`ldgrread()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ldgrread.md))
  from a file, a capsule or an installed package, its theorems with
  their status and covered functions, and
  [`ldgrchk()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ldgrread.md).

- Report:

  the results added from the tabs, as one self-contained HTML page
  (plots as inline SVG, year-over-year tables as
  [`yoyhtml()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoyren.md)
  draws them), as Markdown, or as a GitHub comment to copy.

- Settings:

  light, dark or the system's theme, digits, and the seed of the seeded
  analyses.

The data key of data.rmorie.com is never held by the app:
[`dload()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dmnf.md)
reads it from where `rmbl login` stored it.

The dashboard needs the shiny package (Suggests); without it `rmblapp()`
refuses.

## See also

`rmbl app` on the command line
([`blcli()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/blcli.md)).

## Examples

``` r
if (FALSE) { # interactive()
rmblapp(indiex("health"))
}
```
