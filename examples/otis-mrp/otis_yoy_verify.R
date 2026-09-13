## otis_yoy_verify.R -- recompute every published OTIS year-over-year
## table from the source datasets, and compare.
##
## The dashboard at
##   https://zeus.tail6f5dd7.ts.net/dashboard/otis-yoy.html
## publishes 147 tables across 29 OTIS datasets. This file recomputes
## all of them from the CSVs the province publishes and compares every
## cell against otis_yoy_published.csv.gz, so a reviewer can confirm the
## numbers rather than take them on trust.
##
## The definitions below are a PORT of the generator that produced those
## tables, not a reimplementation from the column names. Getting them
## slightly different would produce mismatches that look like data
## problems and are actually definition problems, so the arithmetic is
## kept identical: percent change rounded to one decimal and undefined
## when the earlier value is zero, shares rounded to one decimal against
## the column total, groups sorted with NA and empty dropped, count
## tables ordered by the first year descending and statistic tables by
## group name.
##
## Three grains exist in the OTIS release and they are NOT
## interchangeable:
##   1. aggregate count tables -- rows are counts, so summing across a
##      dimension is valid.
##   2. individual-level detail (a01, b01, b02, d01) -- one row per
##      person-placement, so the measures are distinct individuals and
##      summed placements/days, never a row count passed off as people.
##   3. statistic tables (b04, b08, c10, c12) -- the value column holds a
##      Maximum / Median / Mode, which cannot be summed or averaged
##      across groups, so they are reported at their own grain with no
##      share column.

.oyv_read_otis <- function(p) {
  d <- utils::read.csv(p, fileEncoding = "UTF-8-BOM", check.names = TRUE,
                       stringsAsFactors = FALSE)
  names(d) <- sub("^X\\.U\\.FEFF\\.", "", names(d))
  for (j in which(vapply(d, is.character, logical(1))))
    d[[j]] <- trimws(d[[j]])
  d
}

## Percent change, one decimal, undefined when the earlier value is zero
## or missing -- the dashboard shows those as an em dash.
.oyv_pc <- function(a, b)
  ifelse(is.na(a) | a == 0, NA_real_, round(100 * (b - a) / a, 1))

.oyv_is_measure <- function(nm)
  grepl("^(Number|Total)", nm) | grepl("Days_", nm)

## grain 1 + 2
.oyv_count_table <- function(d, ycol, dimcol, value_fun, years) {
  groups <- sort(unique(d[[dimcol]]))
  groups <- groups[!is.na(groups) & nzchar(as.character(groups))]
  if (!length(groups)) return(NULL)
  m <- vapply(years, function(y)
    vapply(groups, function(g)
      value_fun(d[d[[ycol]] == y & d[[dimcol]] == g, , drop = FALSE]),
      numeric(1)),
    numeric(length(groups)))
  if (is.null(dim(m))) m <- matrix(m, nrow = length(groups))
  res <- data.frame(group = as.character(groups), stringsAsFactors = FALSE)
  for (i in seq_along(years)) {
    res[[paste0("n_", years[i])]] <- m[, i]
    tot <- sum(m[, i])
    res[[paste0("pct_", years[i])]] <-
      if (tot > 0) round(100 * m[, i] / tot, 1) else NA_real_
  }
  for (i in seq_len(length(years) - 1L))
    res[[paste0("d_", years[i], "_", years[i + 1L])]] <-
      .oyv_pc(m[, i], m[, i + 1L])
  if (length(years) > 2L)
    res[[paste0("d_", years[1], "_", years[length(years)])]] <-
      .oyv_pc(m[, 1], m[, length(years)])
  res[order(-res[[2]]), ]
}

## grain 3
.oyv_stat_table <- function(d, ycol, keycols, valcol, years) {
  key <- do.call(paste, c(d[keycols], sep = " · "))
  keys <- sort(unique(key))
  if (!length(keys)) return(NULL)
  m <- vapply(years, function(y)
    vapply(keys, function(k) {
      v <- d[[valcol]][key == k & d[[ycol]] == y]
      if (length(v) == 0L) NA_real_ else if (length(v) > 1L) NA_real_ else v
    }, numeric(1)),
    numeric(length(keys)))
  if (is.null(dim(m))) m <- matrix(m, nrow = length(keys))
  res <- data.frame(group = keys, stringsAsFactors = FALSE)
  for (i in seq_along(years)) res[[paste0("n_", years[i])]] <- m[, i]
  for (i in seq_len(length(years) - 1L))
    res[[paste0("d_", years[i], "_", years[i + 1L])]] <-
      .oyv_pc(m[, i], m[, i + 1L])
  if (length(years) > 2L)
    res[[paste0("d_", years[1], "_", years[length(years)])]] <-
      .oyv_pc(m[, 1], m[, length(years)])
  res[order(res$group), ]
}

## Recompute every table for one dataset file. Returns a named list of
## data frames, named by the table title exactly as published.
otis_yoy_tables_for <- function(path) {
  d <- .oyv_read_otis(path)
  nm <- names(d)
  ycol <- if ("EndFiscalYear" %in% nm) "EndFiscalYear" else
          if ("Year" %in% nm) "Year" else NA_character_
  if (is.na(ycol)) return(list())
  years <- sort(unique(d[[ycol]]))
  idcol <- nm[grepl("UniqueIndividual_ID", nm)]
  measures <- nm[.oyv_is_measure(nm)]
  ## Some releases quote the count columns with thousands separators, so
  ## they arrive as character. Coerce, and demote anything that is not
  ## actually numeric back to a dimension rather than summing text.
  for (mc in measures) {
    if (is.character(d[[mc]])) {
      cleaned <- suppressWarnings(as.numeric(gsub("[, ]", "", d[[mc]])))
      if (all(is.na(cleaned) == is.na(d[[mc]]) | !nzchar(d[[mc]])))
        d[[mc]] <- cleaned
    }
  }
  measures <- measures[vapply(measures, function(mc) is.numeric(d[[mc]]),
                              logical(1))]
  dims <- setdiff(nm, c(ycol, idcol, measures, "Measure"))
  out <- list()

  if ("Measure" %in% nm) {
    if (!length(measures)) return(out)
    valcol <- measures[1]
    for (lev in sort(unique(d$Measure))) {
      sub <- d[d$Measure == lev, , drop = FALSE]
      tb <- .oyv_stat_table(sub, ycol, dims, valcol, years)
      if (!is.null(tb)) out[[paste0(valcol, " — ", lev)]] <- tb
    }
    return(out)
  }

  if (length(idcol) == 1L) {
    vfuns <- list("distinct individuals" =
                    function(x) length(unique(x[[idcol]])))
    for (mcol in measures)
      vfuns[[paste0("total ", mcol)]] <-
        local({ mc <- mcol; function(x) sum(x[[mc]], na.rm = TRUE) })
    for (dmc in dims) for (vn in names(vfuns)) {
      tb <- .oyv_count_table(d, ycol, dmc, vfuns[[vn]], years)
      if (!is.null(tb)) out[[paste0(vn, " by ", dmc)]] <- tb
    }
    return(out)
  }

  for (dmc in dims) for (mcol in measures) {
    tb <- .oyv_count_table(d, ycol, dmc,
                           local({ mc <- mcol
                             function(x) sum(x[[mc]], na.rm = TRUE) }),
                           years)
    if (!is.null(tb)) out[[paste0(mcol, " by ", dmc)]] <- tb
  }
  out
}

## The published file names tables by a slug; rebuild it the same way so
## a recomputed table can be matched to its published counterpart.
.oyv_slug <- function(x) tolower(gsub("[^A-Za-z0-9]+", "_", x))

#' Compare every recomputed table against the published values
#'
#' @param dsdir Directory holding the OTIS dataset CSVs.
#' @param published Data frame read from otis_yoy_published.csv.gz:
#'   dataset, table, group, column, value.
#' @return A data frame with one row per published table: dataset,
#'   table, cells compared, cells mismatching, and the first mismatch
#'   as text.
otis_yoy_compare <- function(dsdir, published) {
  files <- sort(list.files(dsdir, pattern = "\\.csv$", full.names = TRUE))
  ## index the published values by slug for lookup
  published$ds_slug <- .oyv_slug(published$dataset)
  published$tb_slug <- .oyv_slug(published$table)
  rows <- list()
  for (p in files) {
    ds <- sub("\\.csv$", "", basename(p))
    pub_ds <- published[published$ds_slug == .oyv_slug(ds), , drop = FALSE]
    if (!nrow(pub_ds)) next
    got <- tryCatch(otis_yoy_tables_for(p),
                    error = function(e) structure(list(), err = conditionMessage(e)))
    for (tb_slug in unique(pub_ds$tb_slug)) {
      want <- pub_ds[pub_ds$tb_slug == tb_slug, , drop = FALSE]
      hit <- names(got)[.oyv_slug(names(got)) == tb_slug]
      if (!length(hit)) {
        rows[[length(rows) + 1L]] <- data.frame(
          dataset = ds, table = tb_slug, cells = nrow(want),
          mismatched = nrow(want), first = "table not produced",
          stringsAsFactors = FALSE)
        next
      }
      tb <- got[[hit[1]]]
      bad <- 0L; first <- NA_character_
      for (k in seq_len(nrow(want))) {
        g <- want$group[k]; col <- want$column[k]
        exp_v <- suppressWarnings(as.numeric(want$value[k]))
        obs_v <- if (!col %in% names(tb)) NA_real_ else {
          i <- which(as.character(tb$group) == g)
          if (!length(i)) NA_real_ else suppressWarnings(as.numeric(tb[[col]][i[1]]))
        }
        ok <- if (is.na(exp_v) && is.na(obs_v)) TRUE else
              if (is.na(exp_v) || is.na(obs_v)) FALSE else
              abs(exp_v - obs_v) <= 0.05   # published values carry one decimal
        if (!ok) {
          bad <- bad + 1L
          if (is.na(first))
            first <- sprintf("%s / %s: published %s, recomputed %s",
                             g, col, format(exp_v), format(obs_v))
        }
      }
      rows[[length(rows) + 1L]] <- data.frame(
        dataset = ds, table = tb_slug, cells = nrow(want),
        mismatched = bad,
        first = if (is.na(first)) "" else first,
        stringsAsFactors = FALSE)
    }
  }
  if (!length(rows))
    return(data.frame(dataset = character(0), table = character(0),
                      cells = integer(0), mismatched = integer(0),
                      first = character(0), stringsAsFactors = FALSE))
  do.call(rbind, rows)
}

## The three routes to the same restrictive-confinement population: c01
## states it directly, c04 breaks it out by race and region, and a01 is
## one row per person-placement. If they stop agreeing, a grain rule is
## wrong and every table built on it is suspect -- which is exactly the
## kind of error a cell-by-cell comparison against the same generator
## would NOT catch, so it is checked separately.
otis_yoy_grain_agreement <- function(dsdir) {
  f <- function(n) file.path(dsdir, n)
  need <- c("a01_restrictive_confinement_detailed_dataset.csv",
            "c01_individuals_in_segregation_and_restrictive_confinement_total_individuals.csv",
            "c04_individuals_in_segregation_and_restrictive_confinement_race_by_region.csv")
  if (!all(file.exists(f(need)))) return(NULL)
  a01 <- .oyv_read_otis(f(need[1]))
  c01 <- .oyv_read_otis(f(need[2]))
  c04 <- .oyv_read_otis(f(need[3]))
  out <- lapply(sort(unique(a01$EndFiscalYear)), function(y) data.frame(
    year = y,
    a01_distinct = length(unique(a01$UniqueIndividual_ID[a01$EndFiscalYear == y])),
    c01_total = sum(c01$NumberIndividuals_RestrictiveConfinement[c01$EndFiscalYear == y]),
    c04_total = sum(c04$NumberIndividuals_RestrictiveConfinement[c04$EndFiscalYear == y]),
    stringsAsFactors = FALSE))
  do.call(rbind, out)
}

## ---------------------------------------------------------------------
## Opt-in download of the source datasets
##
## The province publishes all 29 OTIS files as resources of one CKAN
## package, and each resource URL ends in the canonical filename --
## .../download/a01_restrictive_confinement_detailed_dataset.csv --
## which was checked to hold for all 29. So the name comes from the URL,
## and nothing is inferred from the resource TITLE, which would be
## hopeless: "Segregation Placements - Maximum, Median and Mode
## Consecutive Durations by Region" is the file known here as
## b04_segregation_placements_consecutive_durations_by_region, and 15 of
## the 29 diverge that way.
##
## The column signature is then used for what it is actually good for:
## confirming that a downloaded file CONTAINS what its name claims. If
## the province reshuffles which data sits behind a URL, the recomputed
## tables would be wrong in a way that comparing against published
## output could not catch, because both sides would move together.

.oyv_signature <- function(path) {
  hdr <- utils::read.csv(path, nrows = 1L, check.names = FALSE,
                         fileEncoding = "UTF-8-BOM",
                         stringsAsFactors = FALSE)
  cols <- sub("^﻿", "", trimws(names(hdr)))
  ## method = "radix" sorts by byte value, which is the same in every
  ## locale. The default sort() uses the locale's collation and that
  ## reorders punctuation: a UTF-8 locale puts Number_Of_Placements
  ## before NumberConsecutiveDays_Segregation, while byte order puts the
  ## "C" (0x43) ahead of the "_" (0x5F). One dataset of the 29 differs
  ## only in that pair, so under the default sort its signature failed
  ## to match itself and the file went unidentified.
  paste(sort(cols, method = "radix"), collapse = "|")
}

#' Download the OTIS datasets, verifying each against its signature
#'
#' @param destdir Directory to write the CSVs into.
#' @param signatures Data frame with columns dataset, n_cols, signature.
#' @param package_uuid CKAN package UUID for the OTIS release.
#' @param quiet Passed to the downloader.
#' @return A data frame: resource, dataset, path, and signature_ok --
#'   NA when the dataset is not one of the published set.
otis_yoy_download <- function(destdir, signatures,
                              package_uuid = "09f7fc65-d3bb-4ca8-8b84-1cdc3ef73c36",
                              quiet = TRUE) {
  dir.create(destdir, recursive = TRUE, showWarnings = FALSE)
  api <- paste0("https://data.ontario.ca/api/3/action/package_show?id=",
                package_uuid)
  raw <- tempfile(fileext = ".json")
  ok <- tryCatch({
    utils::download.file(api, raw, quiet = quiet)
    TRUE
  }, error = function(e) FALSE, warning = function(w) FALSE)
  if (!ok) return(NULL)
  pkg <- if (exists("bricklayer_json_from_json", mode = "function")) {
    bricklayer_json_from_json(raw, simplifyVector = FALSE)
  } else if (requireNamespace("jsonlite", quietly = TRUE)) {
    jsonlite::fromJSON(raw, simplifyVector = FALSE)
  } else {
    return(NULL)
  }
  resources <- pkg$result$resources
  out <- list()
  for (r in resources) {
    fmt <- tolower(if (is.null(r$format)) "" else r$format)
    if (!identical(fmt, "csv")) next
    url <- r$url
    base <- basename(sub("[?].*$", "", url))
    ds <- sub("[.]csv$", "", base)
    dest <- file.path(destdir, paste0(ds, ".csv"))
    got <- tryCatch({
      utils::download.file(url, dest, mode = "wb", quiet = quiet)
      TRUE
    }, error = function(e) FALSE, warning = function(w) FALSE)
    if (!got || !file.exists(dest)) {
      out[[length(out) + 1L]] <- data.frame(
        resource = base, dataset = ds, path = NA_character_,
        signature_ok = NA, stringsAsFactors = FALSE)
      next
    }
    expect <- signatures$signature[signatures$dataset == ds]
    sig_ok <- if (!length(expect)) NA else
      identical(tryCatch(.oyv_signature(dest), error = function(e) ""),
                expect[1])
    out[[length(out) + 1L]] <- data.frame(
      resource = base, dataset = ds, path = dest,
      signature_ok = sig_ok, stringsAsFactors = FALSE)
  }
  if (!length(out)) return(NULL)
  do.call(rbind, out)
}

## ---------------------------------------------------------------------
## The published RATE tables
##
## https://zeus.tail6f5dd7.ts.net/dashboard/otis-rates.html publishes 108
## rate tables across 24 datasets, each count expressed against two
## exposures:
##
##   1. the yearly total of the prison population the dataset covers,
##      per 1,000, taken from c01;
##   2. Ontario residents at April 1, per 100,000, from Statistics
##      Canada 17-10-0009-01.
##
## This is the textbook construction: a count divided by an exposure,
## which in a count model enters as an offset of log(exposure). The
## interval is the exact Poisson one, and for change between years the
## exact conditional interval for a rate ratio corrected for both
## exposures.
##
## The recomputation here deliberately does NOT port the generator's
## arithmetic the way the year-over-year check does. It goes through
## rate() and rate_change(), whose intervals are anchored to
## stats::poisson.test. The two sides are therefore independent, and
## that has already earned itself twice: the generator first shipped
## with the rate-ratio arguments reversed, giving a +34.4% change an
## interval of -25.9 to -25.3, and then with an upper limit of Inf on a
## change that was simply undefined because the group had no exposure.

OTIS_PER_PRISON <- 1000
OTIS_PER_ONT <- 100000

## Ontario residents at April 1 (fiscal year end), Statistics Canada
## table 17-10-0009-01, geography position 7 confirmed as Ontario from
## the cube metadata rather than assumed.
OTIS_ONT_POP <- c("2022" = 15051975, "2023" = 15495050, "2024" = 16046534,
                  "2025" = 16256538, "2026" = 16103890)

## The prison populations, from c01, which states them directly.
otis_prison_pop <- function(dsdir) {
  p <- file.path(dsdir,
    "c01_individuals_in_segregation_and_restrictive_confinement_total_individuals.csv")
  if (!file.exists(p)) return(NULL)
  c01 <- .oyv_read_otis(p)
  list(incustody = tapply(c01$NumberIndividuals_InCustody, c01$EndFiscalYear, sum),
       rc = tapply(c01$NumberIndividuals_RestrictiveConfinement, c01$EndFiscalYear, sum),
       seg = tapply(c01$NumberIndividuals_Segregation, c01$EndFiscalYear, sum))
}

.oyv_pop_for <- function(measure, dataset) {
  m <- tolower(measure)
  if (grepl("restrictiveconfinement", m)) return("rc")
  if (grepl("segregation", m)) return("seg")
  if (grepl("incustody|custodialdeath", m)) return("incustody")
  code <- substr(dataset, 1, 1)
  if (identical(code, "a")) "rc" else if (identical(code, "b")) "seg" else
    "incustody"
}

.oyv_rate_inputs <- function(path) {
  d <- .oyv_read_otis(path)
  nm <- names(d)
  ycol <- if ("EndFiscalYear" %in% nm) "EndFiscalYear" else
          if ("Year" %in% nm) "Year" else NA_character_
  if (is.na(ycol) || "Measure" %in% nm) return(NULL)
  idcol <- nm[grepl("UniqueIndividual_ID", nm)]
  measures <- nm[.oyv_is_measure(nm)]
  for (mc in measures) if (is.character(d[[mc]])) {
    cl <- suppressWarnings(as.numeric(gsub("[, ]", "", d[[mc]])))
    if (all(is.na(cl) == is.na(d[[mc]]) | !nzchar(d[[mc]]))) d[[mc]] <- cl
  }
  measures <- measures[vapply(measures, function(mc) is.numeric(d[[mc]]),
                              logical(1))]
  if (!length(measures)) return(NULL)
  list(d = d, ycol = ycol, measures = measures,
       dims = setdiff(nm, c(ycol, idcol, measures, "Measure")),
       years = sort(unique(d[[ycol]])))
}

## One rate table, recomputed through rate() and rate_change().
otis_rates_table <- function(inp, dimcol, mcol, popkey, ppop) {
  d <- inp$d
  groups <- sort(unique(d[[dimcol]]))
  groups <- groups[!is.na(groups) & nzchar(as.character(groups))]
  if (!length(groups)) return(NULL)
  pv <- ppop[[popkey]]
  agg <- do.call(rbind, lapply(groups, function(g) do.call(rbind,
    lapply(inp$years, function(y) {
      s <- d[d[[inp$ycol]] == y & d[[dimcol]] == g, , drop = FALSE]
      ys <- as.character(y)
      data.frame(group = as.character(g), year = ys,
                 n = sum(s[[mcol]], na.rm = TRUE),
                 pop = if (ys %in% names(pv)) as.numeric(pv[[ys]]) else NA_real_,
                 ont = if (ys %in% names(OTIS_ONT_POP)) OTIS_ONT_POP[[ys]] else NA_real_,
                 stringsAsFactors = FALSE)
    }))))
  pr <- agg[!is.na(agg$pop) & agg$pop > 0, , drop = FALSE]
  po <- agg[!is.na(agg$ont) & agg$ont > 0, , drop = FALSE]
  list(all = agg,
       prison = if (nrow(pr)) rate(pr, n, pop, by = c("group", "year"),
                                   per = OTIS_PER_PRISON) else NULL,
       ont = if (nrow(po)) rate(po, n, ont, by = c("group", "year"),
                                per = OTIS_PER_ONT) else NULL,
       change = if (nrow(pr)) rate_change(pr, n, pop, year, by = "group",
                                          per = OTIS_PER_PRISON) else NULL)
}

.oyv_rate_cell <- function(got, group, col) {
  pick <- function(df, y, vc) {
    if (is.null(df)) return(NA_real_)
    i <- which(as.character(df$group) == group & as.character(df$year) == y)
    if (!length(i)) return(NA_real_)
    suppressWarnings(as.numeric(df[[vc]][i[1]]))
  }
  m <- regmatches(col,
    regexec("^(n|pop|rate|lo|hi|orate|olo|ohi)_([0-9]{4})$", col))[[1]]
  if (length(m) == 3L) {
    y <- m[3]
    return(switch(m[2],
      n = pick(got$all, y, "n"),
      pop = pick(got$all, y, "pop"),
      rate = pick(got$prison, y, "rate"),
      lo = pick(got$prison, y, "lower"),
      hi = pick(got$prison, y, "upper"),
      orate = pick(got$ont, y, "rate"),
      olo = pick(got$ont, y, "lower"),
      ohi = pick(got$ont, y, "upper"),
      NA_real_))
  }
  m <- regmatches(col, regexec("^(d|lo|hi)_([0-9]{4})_([0-9]{4})$", col))[[1]]
  if (length(m) == 4L) {
    later <- m[4]
    return(switch(m[2],
      d = pick(got$change, later, "pct_change"),
      lo = pick(got$change, later, "pct_lower"),
      hi = pick(got$change, later, "pct_upper"),
      NA_real_))
  }
  NA_real_
}

#' Compare the published rate tables against a recomputation
#'
#' @param dsdir Directory holding the OTIS dataset CSVs.
#' @param published Data frame from otis_rates_published.csv.gz.
#' @return One row per published table: dataset, table, cells,
#'   mismatched, and the first mismatch as text.
otis_rates_compare <- function(dsdir, published) {
  ppop <- otis_prison_pop(dsdir)
  if (is.null(ppop)) return(NULL)
  published$ds_slug <- .oyv_slug(published$dataset)
  published$tb_slug <- .oyv_slug(published$table)
  files <- sort(list.files(dsdir, pattern = "\\.csv$", full.names = TRUE))
  out <- list()
  for (p in files) {
    ds <- sub("\\.csv$", "", basename(p))
    pub_ds <- published[published$ds_slug == .oyv_slug(ds), , drop = FALSE]
    if (!nrow(pub_ds)) next
    inp <- .oyv_rate_inputs(p)
    if (is.null(inp)) next
    for (dmc in inp$dims) for (mcol in inp$measures) {
      tb_slug <- .oyv_slug(paste0(mcol, " by ", dmc))
      want <- pub_ds[pub_ds$tb_slug == tb_slug, , drop = FALSE]
      if (!nrow(want)) next
      got <- tryCatch(otis_rates_table(inp, dmc, mcol,
                                       .oyv_pop_for(mcol, ds), ppop),
                      error = function(e) NULL)
      if (is.null(got)) {
        out[[length(out) + 1L]] <- data.frame(dataset = ds, table = tb_slug,
          cells = nrow(want), mismatched = nrow(want),
          first = "table not produced", stringsAsFactors = FALSE)
        next
      }
      bad <- 0L; first <- NA_character_
      for (k in seq_len(nrow(want))) {
        g <- want$group[k]; col <- want$column[k]
        exp_v <- suppressWarnings(as.numeric(want$value[k]))
        obs_v <- .oyv_rate_cell(got, g, col)
        ok <- if (is.na(exp_v) && is.na(obs_v)) TRUE else
              if (is.na(exp_v) || is.na(obs_v)) FALSE else
              if (is.infinite(exp_v) || is.infinite(obs_v))
                identical(exp_v, obs_v) else
              abs(exp_v - obs_v) <= 0.06
        if (!ok) {
          bad <- bad + 1L
          if (is.na(first))
            first <- sprintf("%s / %s: published %s, recomputed %s",
                             g, col, format(exp_v), format(obs_v))
        }
      }
      out[[length(out) + 1L]] <- data.frame(dataset = ds, table = tb_slug,
        cells = nrow(want), mismatched = bad,
        first = if (is.na(first)) "" else first, stringsAsFactors = FALSE)
    }
  }
  if (!length(out))
    return(data.frame(dataset = character(0), table = character(0),
                      cells = integer(0), mismatched = integer(0),
                      first = character(0), stringsAsFactors = FALSE))
  do.call(rbind, out)
}

#' The named criminological rates, with exact Poisson intervals
#'
#' Incarceration, restrictive-confinement and solitary-confinement
#' rates per 100,000 Ontario residents, and the two confinement rates
#' per 1,000 people in custody.
#'
#' @param dsdir Directory holding the OTIS dataset CSVs.
#' @return A data frame: rate, year, count, exposure, per, rate, lower,
#'   upper.
otis_headline_rates <- function(dsdir) {
  ppop <- otis_prison_pop(dsdir)
  if (is.null(ppop)) return(NULL)
  years <- intersect(names(ppop$incustody), names(OTIS_ONT_POP))
  mk <- function(label, count, exposure, per) {
    r <- rate(count, exposure, per = per)
    data.frame(rate = label, count = count, exposure = exposure, per = per,
               value = r$rate, lower = r$lower, upper = r$upper,
               stringsAsFactors = FALSE)
  }
  out <- list()
  for (y in years) {
    cu <- as.numeric(ppop$incustody[[y]])
    rc <- as.numeric(ppop$rc[[y]])
    sg <- as.numeric(ppop$seg[[y]])
    on <- OTIS_ONT_POP[[y]]
    for (row in list(
      mk("incarceration rate per 100,000 residents", cu, on, OTIS_PER_ONT),
      mk("restrictive confinement rate per 100,000 residents", rc, on, OTIS_PER_ONT),
      mk("solitary confinement rate per 100,000 residents", sg, on, OTIS_PER_ONT),
      mk("restrictive confinement per 1,000 in custody", rc, cu, OTIS_PER_PRISON),
      mk("solitary confinement per 1,000 in custody", sg, cu, OTIS_PER_PRISON))) {
      row$year <- y
      out[[length(out) + 1L]] <- row
    }
  }
  res <- do.call(rbind, out)
  res[, c("rate", "year", "count", "exposure", "per", "value", "lower", "upper")]
}
