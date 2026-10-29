# SPDX-License-Identifier: AGPL-3.0-or-later

#' Analyse a published administrative table in one call
#'
#' The questions asked of a published table are always the same: what
#' is in it, what changed between periods and how sure can one be, what
#' the rates are if there is an exposure, whether a short series trends,
#' and whether this release differs from the one held before. Each has a
#' function in this package; this runs them together, with the pieces a
#' reviewer needs and that are easy to forget on a deadline: exact
#' intervals on every change, multiple-comparison adjustment over the
#' groups scanned, the envelope that rounding and suppression in the
#' release imply, and a drift screen against the prior capsule.
#'
#' @details The steps, in order: \enumerate{ \item profile:
#' [profcols()] and [misssmry()] on
#' \code{data}; \item change: [yoy()] between consecutive periods within
#' each \code{by} group. For \code{units = "count"} the exact p-values are then
#' adjusted across all comparisons with [scanadj()], and, when
#' \code{rnd} or \code{suplim} is given, [yoybnd()] adds the
#' publication envelope (see [pubbnd()]). For \code{"continuous"} and
#' \code{"percent"} units neither step runs: \code{rnd} and \code{suplim} are
#' then ignored, with a warning; \item rates (only with \code{pop}):
#' [rtcalc()] per group and period, and
#' [ratechg()] between periods, adjusted with
#' [scanadj()]; \item trend: per group, the values summed within each
#' period, then [trndtst()] (Mann-Kendall tau, p-value and Theil-Sen
#' slope) and, for counts, [cnttrnd()] (Poisson rate ratio per
#' period). A group with fewer than three periods gets \code{NA}; a test that
#' fails gets \code{NA} rather than an error; \item drift (only with
#' \code{prior}): [cpsdrft()] of \code{data} against \code{prior}. }
#' Nothing is written and nothing is fetched; a progress bar for the trend step
#' is drawn on stderr unless \code{options(morie.quiet = TRUE)}. Errors:
#' \code{data} or \code{prior} not a data frame; a named column not in
#' \code{data}; an invalid \code{units}, \code{dir} or \code{rndkind}; a
#' \code{conflvl} outside (0, 1); and any error of the functions called (for
#' example negative counts in [yoy()]).
#'
#' @param data A data frame in long form: one row per period and group.
#' @param value Name of the column (a string) with the published count (or
#'   measure).
#' @param prd Name of the column with the period (fiscal year, quarter,
#'   ...); numeric periods are used as the time axis of the trend tests. Text
#'   periods (\code{"2019/20"}, \code{"2021 Q3"}, \code{"Mar 2021"}) are
#'   ordered as [yoy()] reads them (see its \code{prd}), or as
#'   \code{prdord} gives.
#' @param by Optional character vector of grouping column names
#'   (institution, region, ...). \code{NULL} (the default) treats the table as
#'   one series.
#' @param pop Optional name of an exposure column for rates
#'   (\code{NULL}, the default, skips the rate step).
#' @param prior Optional data frame: the previous capsule of the same
#'   table, for the drift screen. \code{NULL} (the default) skips it.
#' @param units \code{"count"} (the default), \code{"continuous"} or
#'   \code{"percent"}, as in [yoy()].
#' @param rnd,rndkind,suplim How the release rounds
#'   or suppresses cells; see [pubbnd()].
#'   \code{rnd} is the
#'   rounding base (for example 5), \code{rndkind} \code{"nearest"} (the
#'   default) or \code{"random"}, \code{suplim} the threshold below
#'   which cells are suppressed. \code{NULL} when the counts are exact. Used
#'   only for counts: with other \code{units} they are ignored, with a
#'   warning.
#' @param dir Which way is an improvement, as in [yoy()]:
#'   \code{"neutral"} (the default), \code{"higher"} or
#'   \code{"lower"}.
#' @param per Rate denominator, as in [rtcalc()]; default 1000 (rates
#'   per
#'   1,000 of \code{pop}).
#' @param conflvl Confidence level for every interval, default 0.95.
#' @param alpha Level for the multiple-comparison decision and the drift
#'   screens, default 0.05.
#' @param adjust Multiple-comparison method for
#'   [scanadj()]. The default is \code{"BH"} (Benjamini-Hochberg).
#' @param prdord Optional character vector: the period labels in order,
#'   for text periods the reader does not know (see [yoy()]); passed to
#'   [yoy()], [ratechg()] and the trend tests.
#' @return A list of class \code{bricklayer_analysis} (with a print method that
#'   summarises it in a few lines): \describe{
#'   \item{\code{profile}}{[profcols()] of \code{data}.}
#'   \item{\code{missingness}}{named numeric from [misssmry()].}
#'   \item{\code{change}}{the [yoy()] table; for counts with the added
#'   columns \code{p_value}, \code{padj} and \code{significant}, and with
#'   \code{env_*} and \code{compctlo}/\code{compctup} when publication bounds
#'   were requested.} \item{\code{rates}, \code{ratechg}}{the
#'   [rtcalc()] and [ratechg()] tables when
#'   \code{population} is given, otherwise \code{NULL}.}
#'   \item{\code{trend}}{data frame with one row per group: the \code{by}
#'   columns, \code{periods}, \code{first}, \code{last}, \code{tau},
#'   \code{trndp}, \code{slope}, \code{rateratio}, \code{rateratiolo},
#'   \code{rateratioup}.} \item{\code{drift}}{[cpsdrft()] result
#'   against \code{prior}, or \code{NULL}.} \item{\code{meta}}{list of the
#'   arguments used, \code{nrows}, the sorted \code{periods}, \code{prior}
#'   (logical) and \code{when} (a time stamp).} }
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' path <- system.file("extdata", "otis_a01_individuals.csv",
#'                     package = "rmoriebricklayer")
#' otis <- read.csv(path)
#' a <- anltab(otis, value = "individuals", prd = "year",
#'                    by = c("table", "group"))
#' a
#' a$change[, c("table", "group", "year", "pctchg", "padj")]
#' a$trend[, c("group", "tau", "trndp", "rateratio")]
#'
#' # counts published rounded to base 5: the intervals widen
#' b <- anltab(otis, value = "individuals", prd = "year",
#'                    by = c("table", "group"), rnd = 5)
#' b$change[1:3, c("group", "year", "pctlo", "compctlo")]
#'
#' # rates with an exposure column
#' d <- data.frame(year = rep(2019:2022, 2), site = rep(c("A", "B"), each = 4),
#'                 n = c(10, 12, 15, 9, 30, 28, 35, 40),
#'                 pop = rep(c(1000, 2000), each = 4))
#' r <- anltab(d, "n", "year", by = "site", pop = "pop", per = 1000)
#' r$ratechg[, c("site", "year", "rate", "rateratio", "padj")]
#'
#' # a column that is not in the data is an error
#' try(anltab(otis, value = "count", prd = "year"))
#' @seealso [rptanl()] writes the result as a
#'   Markdown or HTML
#'   report.
#' @export
#' @srrstats {EA1.1} @param data and the title say "a published administrative
#'   table" of counts in long form, one row per period and group;
#'   getting-started vignette says the same.
#' @srrstats {EA1.2} The description lists the questions: what changed and how
#'   sure, rates, trend, whether this release differs from the one held before.
#' @srrstats {EA3.0} One call runs profile, change, Benjamini-Hochberg
#'   adjustment over the whole scan, publication envelope, trend, rates and
#'   drift, which otherwise take separate manual steps; test-analyse_table.R.
anltab <- function(
  data,
  value,
  prd,
  by = NULL,
  pop = NULL,
  prior = NULL,
  units = c("count", "continuous", "percent"),
  rnd = NULL,
  rndkind = c("nearest", "random"),
  suplim = NULL,
  dir = c("neutral", "higher", "lower"),
  per = 1000,
  conflvl = 0.95,
  alpha = 0.05,
  adjust = "BH",
  prdord = NULL
) {
  a <- .anl_inputs(data, value, prd, by, pop, conflvl, alpha)
  adjust <- .rmbl_arg(adjust, stats::p.adjust.methods)
  b <- .anl_check_bounds(rnd, suplim)
  units <- .rmbl_arg(units)
  dir <- .rmbl_arg(dir)
  rndkind <- .rmbl_arg(rndkind)
  .anl_check_cols(data, c(a$value, a$prd, by, a$pop))
  # the settings, in the order the result's `meta` lists them
  opts <- list(
    value = a$value,
    period = a$prd,
    by = by,
    population = a$pop,
    units = units,
    rounding = b$rnd,
    rndkind = rndkind,
    suppression_limit = b$suplim,
    direction = dir,
    per = per,
    conflvl = a$conflvl,
    alpha = a$alpha,
    adjust = adjust,
    prdord = prdord
  )
  .anl_warn_bounds(opts)
  .anl_run(data, prior, opts)
}

#' @export
format.bricklayer_analysis <- function(x, ...) {
  m <- x$meta
  .rmbl_res_block(
    "Analysis of a published table",
    facts = c(.anl_fmt_head(x), .anl_fmt_change(x), .anl_fmt_tail(x)),
    reading = paste(
      "Changes are between consecutive periods with exact or interval",
      "tests, adjusted for the number of comparisons; rptanl() writes the",
      "full tables as a report, and x$change, x$rates and x$trend hold them."
    ),
    notes = if (length(m$when)) paste("Run", m$when)
  )
}

#' Write an analysis as a Markdown or HTML report
#'
#' Renders an [anltab()] result as a report: the
#' change table with
#' its intervals and adjusted p-values, the rates, the trends, the drift
#' screen and the column profile, each with one sentence saying how to read
#' it. The Markdown is plain enough to paste into a notebook or a pull
#' request; the HTML is a single self-contained file with no external
#' resources, suitable for e-mailing to a reviewer.
#'
#' @details Sections appear in this order: a header line (value, period, groups,
#' rows, period range and the time of the analysis), \dQuote{Change between
#' periods}, \dQuote{Rates per ...} (when there were rates), \dQuote{Trend over
#' the series}, \dQuote{Drift against the prior capsule} (when a prior was
#' given) and \dQuote{What is in the table} (with \dQuote{Missing values} when
#' any are missing). Tables use pipe syntax; numbers are rounded to
#' \code{digits} decimals, whole numbers of 10,000 and above get thousands
#' separators, logicals are written yes/no and \code{NA} is blank. When the
#' values are percentages the change is reported in percentage points. The HTML
#' is produced by a small built-in converter (headings, paragraphs, tables and
#' inline code, with the text escaped). The file is written as UTF-8 and
#' overwritten if it exists.
#'
#' Errors: \code{x} not from [anltab()]; an invalid
#' \code{format}.
#'
#' @param x A \code{bricklayer_analysis} from
#'   [anltab()].
#' @param path Where to write, a file path. With \code{NULL} (the default)
#'   the text is returned invisibly and nothing is written.
#' @param format \code{"markdown"} or \code{"html"}. With \code{NULL} (the
#'   default), a \code{path} ending in \code{.html} or \code{.htm} gives
#'   HTML and anything else, or no \code{path}, gives Markdown.
#' @param title Report title, a string; the top heading and, for HTML, the
#'   page title.
#' @param digits Number of decimals for percentages and rates, default 1.
#' @return The report text (a length-1 character string, Markdown or a full
#'   HTML document), invisibly.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' path <- system.file("extdata", "otis_a01_individuals.csv",
#'                     package = "rmoriebricklayer")
#' a <- anltab(read.csv(path), value = "individuals",
#'                    prd = "year", by = c("table", "group"))
#' md <- rptanl(a)
#' cat(substr(md, 1, 400))
#'
#' # HTML, chosen from the file extension
#' out <- tempfile(fileext = ".html")
#' rptanl(a, out, title = "OTIS A01: individuals in custody", digits = 2)
#' readLines(out, n = 3)
#'
#' # only an anltab() result can be reported
#' try(rptanl(read.csv(path)))
#' unlink(out)
#' @export
rptanl <- function(
  x,
  path = NULL,
  format = NULL,
  title = "Analysis of a published table",
  digits = 1L
) {
  if (!inherits(x, "bricklayer_analysis")) {
    stop("`x` must come from anltab()", call. = FALSE)
  }
  if (!is.null(path)) {
    path <- .rmbl_out_file(path, "path")
  }
  if (!is.null(path) && is.null(format)) {
    format <- if (
      is.character(path) && grepl("\\.html?$", path, ignore.case = TRUE)
    ) {
      "html"
    } else {
      "markdown"
    }
  }
  format <- .rmbl_arg(format, c("markdown", "html"))
  title <- .rmbl_text1(title, "title")
  digits <- .rmbl_scalar(digits, "digits", -1, 15, integer = TRUE)
  text <- paste(
    c(
      .anl_md_intro(x, title),
      .anl_md_change(x, digits),
      .anl_md_rates(x, digits),
      .anl_md_trend(x),
      .anl_md_drift(x),
      .anl_md_profile(x)
    ),
    collapse = "\n"
  )
  if (format == "html") {
    text <- .md_to_html(text, title)
  }
  if (!is.null(path)) {
    writeLines(enc2utf8(text), path, useBytes = TRUE)
  }
  invisible(text)
}

#' anltab()'s rounding base and suppression limit, checked.
#' @param rnd,suplim As for anltab().
#' @return A list: rnd and suplim.
#' @noRd
.anl_check_bounds <- function(rnd, suplim) {
  for (nm in c("rnd", "suplim")) {
    v <- if (nm == "rnd") rnd else suplim
    if (is.null(v)) {
      next
    }
    v <- .rmbl_num(v, nm)
    # a rounding base of 0 or Inf, or an infinite suppression limit, has no
    # publication envelope: pubbnd() refused rnd = 0 only later, Inf never
    if (length(v) != 1L || !is.finite(v) || v < 0 || (nm == "rnd" && v == 0)) {
      stop(
        sprintf(
          "`%s` must be one %s number, finite, or NULL",
          nm,
          if (nm == "rnd") "positive" else "non-negative"
        ),
        call. = FALSE
      )
    }
    if (nm == "rnd") rnd <- v else suplim <- v
  }
  list(rnd = rnd, suplim = suplim)
}

#' anltab()'s columns, each in the data.
#' @param data The table given to anltab(), whose names must include `cols`.
#' @param cols The columns.
#' @noRd
.anl_check_cols <- function(data, cols) {
  for (col in cols) {
    if (!col %in% names(data)) {
      stop(
        sprintf("anltab: column `%s` not found in `data`", col),
        call. = FALSE
      )
    }
  }
  invisible(NULL)
}

#' anltab()'s rates and their changes, when there is an exposure.
#' @param data,value,prd,by,pop,per,conflvl,adjust,alpha,prdord As for
#'   anltab().
#' @return A list: rates and rc (NULL without `pop`).
#' @noRd
.anl_rates <- function(data, value, prd, by, pop, per, conflvl, adjust, alpha,
                       prdord = NULL) {
  rates <- NULL
  rc <- NULL
  if (!is.null(pop)) {
    rates <- rtcalc(
      data,
      count = value,
      pop = pop,
      by = c(by, prd),
      per = per,
      conflvl = conflvl
    )
    rc <- ratechg(
      data,
      count = value,
      pop = pop,
      prd = prd,
      by = by,
      per = per,
      conflvl = conflvl,
      prdord = prdord
    )
    rc <- scanadj(rc, meth = adjust, alpha = alpha)
  }
  list(rates = rates, rc = rc)
}

#' Tests the trend of each group's per-period totals with trndtst() and, for
#' counts, cnttrnd().
#' @param data The table to test, split by `by` into one series per group.
#' @param value The name of the value column.
#' @param period The name of the period column.
#' @param by The names of the grouping columns, or NULL for one group.
#' @param units The kind of value; `"count"` adds the rate ratio from cnttrnd().
#' @param conf_level The confidence level for the intervals.
#' @param prdord The period labels in order, or NULL.
#' @return A data frame with one row per group: periods, first and last totals,
#'   Kendall tau, its p-value, the slope, and the rate ratio with its interval.
#' @noRd
.analysis_trends <- function(data, value, period, by, units, conf_level,
                             prdord = NULL) {
  conf_level <- .rmbl_conf_level(conf_level)
  # text periods in the order yoy() reads them ("Mar 2021" after "Feb 2021"),
  # not alphabetically; yoy() has already warned about any it cannot order
  data[[period]] <- .yoy_prd_read(data[[period]], prdord, quiet = TRUE)$p
  groups <- if (is.null(by)) {
    list(data)
  } else {
    split(data, data[by], drop = TRUE)
  }
  pg <- blprog("trends", length(groups))
  on.exit(pg$done(), add = TRUE)
  rows <- lapply(groups, function(g) {
    pg$tick(info = "groups")
    g <- g[order(g[[period]]), , drop = FALSE]
    agg <- stats::aggregate(
      g[[value]],
      by = list(p = g[[period]]),
      FUN = sum,
      na.rm = TRUE
    )
    y <- agg$x
    x <- agg$p
    out <- if (!is.null(by)) {
      as.data.frame(g[1L, by, drop = FALSE])
    } else {
      data.frame(row.names = 1L)
    }
    out$periods <- length(y)
    out$first <- y[1L]
    out$last <- y[length(y)]
    out$tau <- NA_real_
    out$trndp <- NA_real_
    out$slope <- NA_real_
    out$rateratio <- NA_real_
    out$rateratiolo <- NA_real_
    out$rateratioup <- NA_real_
    if (length(y) >= 3L && !all(is.na(y))) {
      out <- .analysis_trend_tests(out, y, x, units, conf_level)
    }
    out
  })
  # unnamed: group labels as row names warned in a C locale (as yoy())
  out <- do.call(rbind, unname(rows))
  rownames(out) <- NULL
  out
}

#' Numbers written one by one: format() on a whole column pads every
#' number to the longest one's decimals ("20.00000").
#' @param v A numeric vector.
#' @param big Whether numbers from 10,000 up get a thousands separator.
#' @return A character vector.
#' @noRd
.md_num1 <- function(v, big) {
  vapply(v, function(z) {
    if (is.na(z)) {
      return("")
    }
    format(z, big.mark = if (big && abs(z) >= 1e4) "," else "",
           trim = TRUE, scientific = FALSE, digits = 15L)
  }, character(1L))
}

#' Minimal Markdown table (pipe syntax) from a data frame; numeric
#' columns rounded to `digits`, logicals as yes/no, NA as blank.
#' @param d A data frame.
#' @param digits The number of decimals for numbers that are not whole.
#' @param plain The names of columns written without a thousands separator.
#' @return One string holding the table.
#' @noRd
.md_table <- function(d, digits = 1L, plain = character()) {
  d <- as.data.frame(d, stringsAsFactors = FALSE)
  if (!nrow(d)) {
    return("(no rows)")
  }
  cells <- lapply(names(d), function(nm) {
    v <- d[[nm]]
    if (nm %in% plain) {
      # a period (2023) is a label, not a quantity: no thousands separator
      lab <- if (is.numeric(v)) {
        .md_num1(v, big = FALSE)
      } else {
        .rmbl_ctl_escape(as.character(v))
      }
      ifelse(is.na(v), "", lab)
    } else if (is.logical(v)) {
      yn <- ifelse(v, "yes", "no")
      ifelse(is.na(v), "", yn)
    } else if (is.numeric(v)) {
      whole <- v == round(v) & abs(v) < 1e9
      # a separator from 10,000 up only: a four-digit whole number (a year in
      # the profile's min / max) read as "2,023"
      num <- ifelse(whole, .md_num1(v, big = TRUE),
                    formatC(v, digits = digits, format = "f"))
      ifelse(is.na(v), "", num)
    } else {
      ifelse(is.na(v), "", .rmbl_ctl_escape(as.character(v)))
    }
  })
  rows <- do.call(paste, c(cells, sep = " | "))
  paste(
    c(
      paste("|", paste(.rmbl_ctl_escape(names(d)), collapse = " | "), "|"),
      paste("|", paste(rep("---", ncol(d)), collapse = " | "), "|"),
      paste("|", rows, "|")
    ),
    collapse = "\n"
  )
}

#' Converts the report Markdown to a self-contained HTML page.
#'
#' Enough Markdown for the report: headings, paragraphs, pipe tables,
#' inline code. No dependency, no external resources.
#' @param md The Markdown text.
#' @param title The page title, escaped into the `<title>` element.
#' @return One string holding the HTML document.
#' @noRd
.md_to_html <- function(md, title) {
  lines <- strsplit(md, "\n", fixed = TRUE)[[1L]]
  out <- character()
  i <- 1L
  while (i <= length(lines)) {
    l <- lines[i]
    if (grepl("^#{1,3} ", l)) {
      lvl <- nchar(sub(" .*$", "", l))
      out <- c(
        out,
        sprintf("<h%d>%s</h%d>", lvl, .md_inline(sub("^#+ ", "", l)), lvl)
      )
    } else if (grepl("^\\|", l)) {
      j <- i
      while (j <= length(lines) && grepl("^\\|", lines[j])) {
        j <- j + 1L
      }
      out <- c(out, .md_html_table(lines[i:(j - 1L)]))
      i <- j
      next
    } else if (nzchar(trimws(l))) {
      out <- c(out, paste0("<p>", .md_inline(l), "</p>"))
    }
    i <- i + 1L
  }
  .md_html_page(out, title)
}

#' anltab()'s data, column names, confidence level and alpha, checked.
#' @param data,value,prd,by,pop,conflvl,alpha As for anltab().
#' @return A list: value, prd, pop, conflvl and alpha.
#' @noRd
.anl_inputs <- function(data, value, prd, by, pop, conflvl, alpha) {
  if (!is.data.frame(data)) {
    stop("anltab: `data` must be a data frame", call. = FALSE)
  }
  .rmbl_df_names(data)
  value <- .rmbl_string1(value, "value")
  prd <- .rmbl_string1(prd, "prd")
  if (!is.null(by) && (!is.character(by) || !length(by) || anyNA(by))) {
    stop(
      "anltab: `by` must be one or more column names, or NULL",
      call. = FALSE
    )
  }
  conflvl <- .rmbl_conf_level(conflvl)
  # each a single value, checked here: the inner calls met them as base R did
  # ("the condition has length > 1", "invalid format '%g'"; CRAN stress test of
  # 0.5.14)
  if (!is.null(pop)) {
    pop <- .rmbl_string1(pop, "pop")
  }
  alpha <- .rmbl_conf_level(alpha, "alpha")
  list(value = value, prd = prd, pop = pop, conflvl = conflvl, alpha = alpha)
}

#' Warns that rounding and suppression are ignored for a non-count.
#' @param o anltab()'s settings.
#' @return NULL, invisibly.
#' @noRd
.anl_warn_bounds <- function(o) {
  bounded <- !is.null(o$rounding) || !is.null(o$suppression_limit)
  if (bounded && o$units != "count") {
    warning(
      sprintf(
        paste0(
          "`rnd` and `suplim` apply only to counts: they are ignored ",
          "with units = \"%s\""
        ),
        o$units
      ),
      call. = FALSE
    )
  }
  invisible(NULL)
}

#' anltab()'s analysis, once its arguments are checked.
#' @param data The table analysed: profiled, checked for gaps and change.
#' @param prior The prior capsule, or NULL.
#' @param o anltab()'s settings.
#' @return A bricklayer_analysis.
#' @noRd
.anl_run <- function(data, prior, o) {
  ## ---- what is in it ----
  profile <- profcols(data)
  miss <- misssmry(data)

  ## ---- what changed, and how sure ----
  change <- .anl_change(data, o)

  ## ---- rates, if there is an exposure ----
  r <- .anl_rates(
    data,
    o$value,
    o$period,
    o$by,
    o$population,
    o$per,
    o$conflvl,
    o$adjust,
    o$alpha,
    o$prdord
  )

  ## ---- trend over the periods, per group ----
  trend <- .analysis_trends(
    data,
    o$value,
    o$period,
    o$by,
    o$units,
    o$conflvl,
    o$prdord
  )

  ## ---- drift against the prior capsule ----
  drift <- .anl_drift(prior, data, o$alpha)

  structure(
    list(
      profile = profile,
      missingness = miss,
      change = change,
      rates = r$rates,
      ratechg = r$rc,
      trend = trend,
      drift = drift,
      meta = .anl_meta(o, data, prior)
    ),
    class = "bricklayer_analysis"
  )
}

#' anltab()'s year-on-year change, multiplicity-adjusted and bounded for a
#' count.
#' @param data The table whose change between periods is measured.
#' @param o anltab()'s settings.
#' @return A yoy() result.
#' @noRd
.anl_change <- function(data, o) {
  # bare `value` and `prd`, as anltab() passed them to yoy()
  value <- o$value
  prd <- o$period
  change <- yoy(
    data,
    value = value,
    prd = prd,
    by = o$by,
    units = o$units,
    conflvl = o$conflvl,
    dir = o$direction,
    prdord = o$prdord
  )
  if (o$units == "count") {
    change <- scanadj(change, meth = o$adjust, alpha = o$alpha)
    if (!is.null(o$rounding) || !is.null(o$suppression_limit)) {
      change <- yoybnd(
        change,
        rnd = o$rounding,
        rndkind = o$rndkind,
        suplim = o$suppression_limit
      )
    }
  }
  change
}

#' The Mann-Kendall test and the count trend of one series, for
#' .analysis_trends().
#' @param out The series' row, its test columns missing.
#' @param y The values, at least three.
#' @param x The periods of `y`, used as the time axis only when numeric.
#' @param units The value's units; `"count"` also runs the count trend test.
#' @param conf_level The confidence level of the trend tests' intervals.
#' @return `out`, the test columns filled where a test ran.
#' @noRd
.analysis_trend_tests <- function(out, y, x, units, conf_level) {
  tt <- tryCatch(
    trndtst(y, x = if (is.numeric(x)) x else NULL, conflvl = conf_level),
    error = function(e) NULL
  )
  if (!is.null(tt)) {
    out$tau <- tt$tau
    out$trndp <- tt$p_value
    out$slope <- tt$slope
  }
  if (units == "count") {
    ct <- tryCatch(
      cnttrnd(y, x = if (is.numeric(x)) x else NULL, conflvl = conf_level),
      error = function(e) NULL
    )
    if (!is.null(ct)) {
      out$rateratio <- ct$rateratio
      out$rateratiolo <- ct$lower %||% NA_real_
      out$rateratioup <- ct$upper %||% NA_real_
    }
  }
  out
}

#' The facts that open a printed analysis: what was analysed, and its size.
#' @param x A bricklayer_analysis.
#' @return A named list.
#' @noRd
.anl_fmt_head <- function(x) {
  m <- x$meta
  np <- length(m$periods)
  list(
    Value = paste0("`", m$value, "`"),
    Period = m$period,
    Periods = if (np) {
      sprintf("%d (%s to %s)", np, m$periods[1L], m$periods[np])
    },
    `Grouped by` = if (length(m$by)) paste(m$by, collapse = " x "),
    Rows = m$n_rows,
    Columns = nrow(x$profile),
    Missing = if (isTRUE(x$missingness[["n_missing"]] > 0)) {
      sprintf(
        "%d column(s) with missing values",
        x$missingness[["n_cols_any_missing"]]
      )
    } else {
      "no missing values"
    }
  )
}

#' The change, bounds and rate facts of a printed analysis.
#' @param x A bricklayer_analysis.
#' @return A named list.
#' @noRd
.anl_fmt_change <- function(x) {
  m <- x$meta
  ch <- x$change
  cmp <- ch[!is.na(ch$previous), , drop = FALSE]
  r <- x$ratechg
  if (!is.null(r)) {
    r <- r[!is.na(r$prerate), , drop = FALSE]
  }
  list(
    Changes = paste0(
      sprintf("%d comparison(s)", nrow(cmp)),
      if (!is.null(cmp$significant)) {
        sprintf(
          ", %d significant after %s at %g",
          sum(cmp$significant),
          m$adjust,
          m$alpha
        )
      }
    ),
    `Publication bounds` = if (!is.null(cmp$compctlo)) .anl_fmt_bounds(m),
    Rates = if (!is.null(r)) {
      sprintf(
        "per %s: %d comparison(s), %d significant after adjustment",
        format(m$per),
        nrow(r),
        sum(r$significant, na.rm = TRUE)
      )
    }
  )
}

#' The publication-bounds fact of a printed analysis.
#' @param m The analysis's `meta`.
#' @return One string.
#' @noRd
.anl_fmt_bounds <- function(m) {
  sprintf(
    "rounding %s (%s)%s; combined intervals reported",
    if (is.null(m$rounding)) "none" else format(m$rounding),
    m$rndkind,
    if (is.null(m$suppression_limit)) {
      ""
    } else {
      sprintf(", suppression below %g", m$suppression_limit)
    }
  )
}

#' The trend and drift facts of a printed analysis.
#' @param x A bricklayer_analysis.
#' @return A named list.
#' @noRd
.anl_fmt_tail <- function(x) {
  m <- x$meta
  tr <- x$trend
  d <- x$drift$columns
  list(
    Trend = if (nrow(tr) && !all(is.na(tr$trndp))) {
      sprintf(
        "%d of %d series with Mann-Kendall p < %g",
        sum(tr$trndp < m$alpha, na.rm = TRUE),
        nrow(tr),
        m$alpha
      )
    } else {
      "fewer than three periods, not tested"
    },
    `Drift vs prior capsule` = if (!is.null(d)) {
      sprintf(
        "%d of %d column(s) flagged at alpha %g",
        sum(d$drifted, na.rm = TRUE),
        nrow(d),
        m$alpha
      )
    }
  )
}

#' The title and the one-line summary of rptanl()'s report.
#' @param x A bricklayer_analysis.
#' @param title The checked title, written as the level-one Markdown heading.
#' @return A character vector of Markdown lines.
#' @noRd
.anl_md_intro <- function(x, title) {
  m <- x$meta
  out <- character()
  out <- c(
    out,
    paste0("# ", .rmbl_ctl_escape(title)),
    "",
    sprintf(
      paste0(
        "`%s` by `%s`%s; %d rows; %d period(s) from %s to %s; ",
        "generated %s."
      ),
      m$value,
      m$period,
      if (length(m$by)) {
        paste0(
          ", grouped by ",
          paste(sprintf("`%s`", m$by), collapse = " and ")
        )
      } else {
        ""
      },
      m$n_rows,
      length(m$periods),
      m$periods[1L],
      m$periods[length(m$periods)],
      m$when
    ),
    ""
  )
  out
}

#' The change-between-periods section of rptanl()'s report.
#' @param x A bricklayer_analysis.
#' @param digits Decimal places, as for rptanl().
#' @return A character vector of Markdown lines.
#' @noRd
.anl_md_change <- function(x, digits) {
  m <- x$meta
  out <- character()
  ch <- x$change
  # percent units change in points
  chg <- if ("pctchg" %in% names(ch)) "pctchg" else "ppchg"
  out <- c(
    out,
    "## Change between periods",
    "",
    .anl_md_change_note(x, chg),
    ""
  )
  cols <- c(m$by, m$period, "value", "previous", chg)
  if (!is.null(ch$pctlo)) {
    cols <- c(cols, "pctlo", "pctup")
  }
  if (!is.null(ch$compctlo)) {
    cols <- c(cols, "compctlo", "compctup")
    out <- c(
      out,
      sprintf(
        paste0(
          "`combined_*` widens the sampling interval by the ",
          "envelope that rounding%s in the release implies; ",
          "it is the honest range for a figure read off the ",
          "published table."
        ),
        if (is.null(m$suppression_limit)) "" else " and suppression"
      ),
      ""
    )
  }
  if (!is.null(ch$padj)) {
    cols <- c(cols, "padj", "significant")
  }
  cols <- c(cols, "flag")
  out <- c(out, .md_table(ch[cols], digits, plain = m$period), "")
  out
}

#' The rates section of rptanl()'s report, empty without an exposure.
#' @param x A bricklayer_analysis.
#' @param digits Decimal places, as for rptanl().
#' @return A character vector of Markdown lines.
#' @noRd
.anl_md_rates <- function(x, digits) {
  m <- x$meta
  out <- character()
  if (!is.null(x$ratechg)) {
    out <- c(
      out,
      sprintf("## Rates per %s", format(m$per)),
      "",
      sprintf(
        paste0(
          "Rate ratios between consecutive periods with %g%% ",
          "intervals; p-values exact given the exposures, ",
          "adjusted by %s."
        ),
        100 * m$conflvl,
        m$adjust
      ),
      ""
    )
    rc <- x$ratechg
    out <- c(
      out,
      .md_table(
        rc[c(
          m$by,
          m$period,
          "count",
          "population",
          "rate",
          "prerate",
          "pctchg",
          "pctlo",
          "pctup",
          "padj",
          "significant",
          "flag"
        )],
        digits,
        plain = m$period
      ),
      ""
    )
  }
  out
}

#' The trend section of rptanl()'s report.
#' @param x A bricklayer_analysis.
#' @return A character vector of Markdown lines.
#' @noRd
.anl_md_trend <- function(x) {
  out <- character()
  out <- c(
    out,
    "## Trend over the series",
    "",
    paste0(
      "Mann-Kendall tau and its p-value (exact for short series), ",
      "the Theil-Sen slope per period, and for counts the Poisson ",
      "rate ratio per period with its interval. Three periods is ",
      "the minimum; a p-value from three points can never fall ",
      "below 0.33, which is reported rather than hidden."
    ),
    ""
  )
  out <- c(out, .md_table(x$trend, 3L), "")
  out
}

#' The drift section of rptanl()'s report, empty without a prior capsule.
#' @param x A bricklayer_analysis.
#' @return A character vector of Markdown lines.
#' @noRd
.anl_md_drift <- function(x) {
  m <- x$meta
  out <- character()
  if (!is.null(x$drift)) {
    out <- c(
      out,
      "## Drift against the prior capsule",
      "",
      sprintf(
        paste0(
          "Per column: Kolmogorov-Smirnov or chi-square against ",
          "the prior release at alpha %g, and the population ",
          "stability index. `drifted` is the screen's verdict; ",
          "run `drftcal()` on the prior capsule to learn ",
          "how often these screens fire on identical data."
        ),
        m$alpha
      ),
      ""
    )
    out <- c(out, .md_table(x$drift$columns, 3L), "")
    if (length(x$drift$added)) {
      out <- c(out, sprintf("Columns added: %s.", toString(x$drift$added)), "")
    }
    if (length(x$drift$removed)) {
      out <- c(
        out,
        sprintf(
          "Columns removed: %s.",
          toString(x$drift$removed)
        ),
        ""
      )
    }
  }
  out
}

#' The profile and missing-value sections of rptanl()'s report.
#' @param x A bricklayer_analysis.
#' @return A character vector of Markdown lines.
#' @noRd
.anl_md_profile <- function(x) {
  out <- character()
  out <- c(out, "## What is in the table", "", .md_table(x$profile, 2L), "")
  if (x$missingness[["n_missing"]] > 0) {
    out <- c(
      out,
      "### Missing values",
      "",
      .md_table(as.data.frame(as.list(x$missingness)), 2L),
      ""
    )
  }
  out
}

#' Escapes &, < and > for HTML.
#' @param s A character vector.
#' @return `s`, escaped.
#' @noRd
.md_esc <- function(s) {
  s <- .rmbl_ctl_escape(s, ws = TRUE)
  s <- gsub("&", "&amp;", s, fixed = TRUE)
  s <- gsub("<", "&lt;", s, fixed = TRUE)
  gsub(">", "&gt;", s, fixed = TRUE)
}

#' Escapes a line of Markdown for HTML and renders its `code` spans.
#' @param s A character vector.
#' @return `s` as HTML.
#' @noRd
.md_inline <- function(s) gsub("`([^`]+)`", "<code>\\1</code>", .md_esc(s))

#' Renders a Markdown table (its lines, separator second) as HTML.
#' @param tbl The table's lines.
#' @return The HTML lines, `<table>` to `</table>`.
#' @noRd
.md_html_table <- function(tbl) {
  cells <- lapply(tbl[-2L], function(r) {
    v <- strsplit(
      sub("\\|\\s*$", "", sub("^\\|\\s*", "", r)),
      " | ",
      fixed = TRUE
    )[[1L]]
    trimws(v)
  })
  hdr <- paste0(
    "<tr>",
    paste0("<th>", .md_inline(cells[[1L]]), "</th>", collapse = ""),
    "</tr>"
  )
  body <- vapply(
    cells[-1L],
    function(v) {
      paste0(
        "<tr>",
        paste0("<td>", .md_inline(v), "</td>", collapse = ""),
        "</tr>"
      )
    },
    ""
  )
  c("<table>", hdr, body, "</table>")
}

#' Wraps HTML body lines in a standalone page.
#' @param out The body lines.
#' @param title The page title, escaped into the `<title>` element.
#' @return The page, one string.
#' @noRd
.md_html_page <- function(out, title) {
  paste(
    c(
      "<!DOCTYPE html>",
      "<html lang=\"en\"><head><meta charset=\"utf-8\">",
      sprintf("<title>%s</title>", .md_esc(title)),
      paste0(
        "<style>body{font:15px/1.5 system-ui,sans-serif;",
        "max-width:60em;margin:2em auto;padding:0 1em;color:#222}"
      ),
      "table{border-collapse:collapse;margin:1em 0;font-size:13px}",
      "th,td{border:1px solid #ccc;padding:3px 7px;text-align:right}",
      paste0(
        "th{background:#f3f3f3}",
        "td:first-child,th:first-child{text-align:left}"
      ),
      "code{background:#f3f3f3;padding:0 3px}</style></head><body>",
      out,
      "</body></html>"
    ),
    collapse = "\n"
  )
}

#' anltab()'s drift against the prior capsule.
#' @param prior The prior capsule, or NULL.
#' @param data The current table, compared with `prior` by cpsdrft().
#' @param alpha The significance level.
#' @return A cpsdrft() result, or NULL without a prior capsule.
#' @noRd
.anl_drift <- function(prior, data, alpha) {
  if (is.null(prior)) {
    return(NULL)
  }
  if (!is.data.frame(prior)) {
    stop("`prior` must be a data frame", call. = FALSE)
  }
  cpsdrft(prior, data, alpha = alpha)
}

#' The `meta` of an anltab() result: its settings, then the data's size,
#' periods and when it ran.
#' @param o anltab()'s settings.
#' @param data The table analysed, giving the row count and the periods.
#' @param prior The prior capsule, or NULL.
#' @return A list.
#' @noRd
.anl_meta <- function(o, data, prior) {
  c(
    o,
    list(
      n_rows = nrow(data),
      periods = .yoy_prd_sort(data[[o$period]], o$prdord),
      prior = !is.null(prior),
      when = format(Sys.time(), "%Y-%m-%d %H:%M")
    )
  )
}

#' The sentence that opens rptanl()'s change section.
#' @param x A bricklayer_analysis.
#' @param chg The change column, "pctchg" or "ppchg".
#' @return One string.
#' @noRd
.anl_md_change_note <- function(x, chg) {
  m <- x$meta
  if (identical(chg, "ppchg")) {
    # the values are percentages: they change in points, and a count interval
    # does not apply
    paste(
      "Change in percentage points between consecutive periods (the",
      "values are percentages,",
      "so no count-based interval applies)."
    )
  } else {
    sprintf(
      paste0(
        "Percent change with a %g%% exact conditional-binomial ",
        "interval; p-values are exact and adjusted over the %d ",
        "comparisons by %s. A row is significant when the ",
        "adjusted p-value is below %g."
      ),
      100 * m$conflvl,
      sum(!is.na(x$change$previous)),
      m$adjust,
      m$alpha
    )
  }
}
