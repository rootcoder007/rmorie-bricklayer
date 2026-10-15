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
#' @details
#' The steps, in order:
#' \enumerate{
#'   \item profile: [profile_columns()] and
#'     [missingness_summary()] on \code{data};
#'   \item change: [yoy()] between consecutive periods within each
#'     \code{by} group.
#'     For \code{units = "count"} the exact p-values are then adjusted across all
#'     comparisons with [scan_adjust()], and, when
#'     \code{rounding} or
#'     \code{suppression_limit} is given, [yoy_bounds()] adds
#'     the publication
#'     envelope (see [published_bounds()]). For
#'     \code{"continuous"} and
#'     \code{"percent"} units neither step runs: \code{rounding} and
#'     \code{suppression_limit} are then ignored, with a warning;
#'   \item rates (only with \code{population}): [rate()] per group and
#'     period, and
#'     [rate_change()] between periods, adjusted with
#'     [scan_adjust()];
#'   \item trend: per group, the values summed within each period, then
#'     [trend_test()] (Mann-Kendall tau, p-value and Theil-Sen
#'     slope) and, for
#'     counts, [count_trend()] (Poisson rate ratio per period).
#'     A group with fewer
#'     than three periods gets \code{NA}; a test that fails gets \code{NA} rather
#'     than an error;
#'   \item drift (only with \code{prior}): [capsule_drift()]
#'     of \code{data} against
#'     \code{prior}.
#' }
#' Nothing is written and nothing is fetched; a progress bar for the trend
#' step is drawn on stderr unless \code{options(morie.quiet = TRUE)}.
#' Errors: \code{data} or \code{prior} not a data frame; a named column not
#' in \code{data}; an invalid \code{units}, \code{direction} or
#' \code{rounding_kind}; a \code{conf_level} outside (0, 1); and any error of the
#' functions called (for example
#' negative counts in [yoy()]).
#'
#' @param data A data frame in long form: one row per period and group.
#' @param value Name of the column (a string) with the published count (or
#'   measure).
#' @param period Name of the column with the period (fiscal year, quarter,
#'   ...); numeric periods are used as the time axis of the trend tests.
#' @param by Optional character vector of grouping column names
#'   (institution, region, ...). \code{NULL} (the default) treats the table as
#'   one series.
#' @param population Optional name of an exposure column for rates
#'   (\code{NULL}, the default, skips the rate step).
#' @param prior Optional data frame: the previous capsule of the same
#'   table, for the drift screen. \code{NULL} (the default) skips it.
#' @param units \code{"count"} (the default), \code{"continuous"} or
#'   \code{"percent"}, as in [yoy()].
#' @param rounding,rounding_kind,suppression_limit How the release rounds
#'   or suppresses cells; see [published_bounds()].
#'   \code{rounding} is the
#'   rounding base (for example 5), \code{rounding_kind} \code{"nearest"} (the
#'   default) or \code{"random"}, \code{suppression_limit} the threshold below
#'   which cells are suppressed. \code{NULL} when the counts are exact. Used
#'   only for counts: with other \code{units} they are ignored, with a
#'   warning.
#' @param direction Which way is an improvement, as in [yoy()]:
#'   \code{"neutral"} (the default), \code{"higher_is_better"} or
#'   \code{"lower_is_better"}.
#' @param per Rate denominator, as in [rate()]; default 1000 (rates
#'   per
#'   1,000 of \code{population}).
#' @param conf_level Confidence level for every interval, default 0.95.
#' @param alpha Level for the multiple-comparison decision and the drift
#'   screens, default 0.05.
#' @param adjust Multiple-comparison method for
#'   [scan_adjust()], default
#'   \code{"BH"} (Benjamini-Hochberg).
#' @return A list of class \code{bricklayer_analysis} (with a print method that
#'   summarises it in a few lines):
#'   \describe{
#'     \item{\code{profile}}{[profile_columns()] of
#'       \code{data}.}
#'     \item{\code{missingness}}{named numeric from
#'       [missingness_summary()].}
#'     \item{\code{change}}{the [yoy()] table; for counts with the
#'       added columns
#'       \code{p_value}, \code{p_adjusted} and \code{significant}, and with
#'       \code{env_*} and \code{combined_pct_lower}/\code{combined_pct_upper} when
#'       publication bounds were requested.}
#'     \item{\code{rates}, \code{rate_change}}{the [rate()] and
#'       [rate_change()]
#'       tables when \code{population} is given, otherwise \code{NULL}.}
#'     \item{\code{trend}}{data frame with one row per group: the \code{by} columns,
#'       \code{periods}, \code{first}, \code{last}, \code{tau}, \code{trend_p},
#'       \code{slope}, \code{rate_ratio}, \code{rate_ratio_lower},
#'       \code{rate_ratio_upper}.}
#'     \item{\code{drift}}{[capsule_drift()] result against
#'       \code{prior}, or
#'       \code{NULL}.}
#'     \item{\code{meta}}{list of the arguments used, \code{n_rows}, the sorted
#'       \code{periods}, \code{prior} (logical) and \code{when} (a time stamp).}
#'   }
#' @examples
#' path <- system.file("extdata", "otis_a01_individuals.csv",
#'                     package = "rmoriebricklayer")
#' otis <- read.csv(path)
#' a <- analyse_table(otis, value = "individuals", period = "year",
#'                    by = c("table", "group"))
#' a
#' a$change[, c("table", "group", "year", "pct_change", "p_adjusted")]
#' a$trend[, c("group", "tau", "trend_p", "rate_ratio")]
#'
#' # counts published rounded to base 5: the intervals widen
#' b <- analyse_table(otis, value = "individuals", period = "year",
#'                    by = c("table", "group"), rounding = 5)
#' b$change[1:3, c("group", "year", "pct_lower", "combined_pct_lower")]
#'
#' # rates with an exposure column
#' d <- data.frame(year = rep(2019:2022, 2), site = rep(c("A", "B"), each = 4),
#'                 n = c(10, 12, 15, 9, 30, 28, 35, 40),
#'                 pop = rep(c(1000, 2000), each = 4))
#' r <- analyse_table(d, "n", "year", by = "site", population = "pop", per = 1000)
#' r$rate_change[, c("site", "year", "rate", "rate_ratio", "p_adjusted")]
#'
#' # a column that is not in the data is an error
#' try(analyse_table(otis, value = "count", period = "year"))
#' @seealso [report_analysis()] writes the result as a
#'   Markdown or HTML
#'   report.
#' @export
analyse_table <- function(data, value, period, by = NULL, population = NULL,
                          prior = NULL,
                          units = c("count", "continuous", "percent"),
                          rounding = NULL,
                          rounding_kind = c("nearest", "random"),
                          suppression_limit = NULL,
                          direction = c("neutral", "higher_is_better",
                                        "lower_is_better"),
                          per = 1000, conf_level = 0.95, alpha = 0.05,
                          adjust = "BH") {
  if (!is.data.frame(data)) stop("`data` must be a data frame", call. = FALSE)
  .rmbl_df_names(data)
  conf_level <- .rmbl_conf_level(conf_level)
  units <- .rmbl_arg(units)
  direction <- .rmbl_arg(direction)
  rounding_kind <- .rmbl_arg(rounding_kind)
  for (col in c(value, period, by, population)) {
    if (!col %in% names(data)) {
      stop(sprintf("column `%s` not found in `data`", col), call. = FALSE)
    }
  }
  bounded <- !is.null(rounding) || !is.null(suppression_limit)
  if (bounded && units != "count") {
    warning(sprintf(paste0("`rounding` and `suppression_limit` apply only to counts: they are ignored ",
                           "with units = \"%s\""), units), call. = FALSE)
  }

  ## ---- what is in it ----
  profile <- profile_columns(data)
  missing <- missingness_summary(data)

  ## ---- what changed, and how sure ----
  change <- yoy(data, value = value, period = period, by = by,
                units = units, conf_level = conf_level,
                direction = direction)
  if (units == "count") {
    change <- scan_adjust(change, method = adjust, alpha = alpha)
    if (bounded) {
      change <- yoy_bounds(change, rounding = rounding,
                           rounding_kind = rounding_kind,
                           suppression_limit = suppression_limit)
    }
  }

  ## ---- rates, if there is an exposure ----
  rates <- NULL
  rc <- NULL
  if (!is.null(population)) {
    rates <- rate(data, count = value, population = population,
                  by = c(by, period), per = per, conf_level = conf_level)
    rc <- rate_change(data, count = value, population = population,
                      period = period, by = by, per = per,
                      conf_level = conf_level)
    rc <- scan_adjust(rc, method = adjust, alpha = alpha)
  }

  ## ---- trend over the periods, per group ----
  trend <- .analysis_trends(data, value, period, by, units, conf_level)

  ## ---- drift against the prior capsule ----
  drift <- NULL
  if (!is.null(prior)) {
    if (!is.data.frame(prior)) {
      stop("`prior` must be a data frame", call. = FALSE)
    }
    drift <- capsule_drift(prior, data, alpha = alpha)
  }

  structure(list(profile = profile, missingness = missing, change = change,
                 rates = rates, rate_change = rc, trend = trend,
                 drift = drift,
                 meta = list(value = value, period = period, by = by,
                             population = population, units = units,
                             rounding = rounding,
                             rounding_kind = rounding_kind,
                             suppression_limit = suppression_limit,
                             direction = direction, per = per,
                             conf_level = conf_level, alpha = alpha,
                             adjust = adjust, n_rows = nrow(data),
                             periods = sort(unique(data[[period]])),
                             prior = !is.null(prior),
                             when = format(Sys.time(), "%Y-%m-%d %H:%M"))),
            class = "bricklayer_analysis")
}

.analysis_trends <- function(data, value, period, by, units, conf_level) {
  conf_level <- .rmbl_conf_level(conf_level)
  groups <- if (is.null(by)) list(data) else
    split(data, data[by], drop = TRUE)
  pg <- bricklayer_progress("trends", length(groups))
  on.exit(pg$done(), add = TRUE)
  rows <- lapply(groups, function(g) {
    pg$tick(info = "groups")
    g <- g[order(g[[period]]), , drop = FALSE]
    agg <- stats::aggregate(g[[value]], by = list(p = g[[period]]),
                            FUN = sum, na.rm = TRUE)
    y <- agg$x
    x <- agg$p
    out <- if (!is.null(by)) as.data.frame(g[1L, by, drop = FALSE]) else
      data.frame(row.names = 1L)
    out$periods <- length(y)
    out$first <- y[1L]
    out$last <- y[length(y)]
    out$tau <- NA_real_
    out$trend_p <- NA_real_
    out$slope <- NA_real_
    out$rate_ratio <- NA_real_
    out$rate_ratio_lower <- NA_real_
    out$rate_ratio_upper <- NA_real_
    if (length(y) >= 3L && !all(is.na(y))) {
      tt <- tryCatch(trend_test(y, x = if (is.numeric(x)) x else NULL,
                                conf_level = conf_level),
                     error = function(e) NULL)
      if (!is.null(tt)) {
        out$tau <- tt$tau
        out$trend_p <- tt$p_value
        out$slope <- tt$slope
      }
      if (units == "count") {
        ct <- tryCatch(count_trend(y, x = if (is.numeric(x)) x else NULL,
                                   conf_level = conf_level),
                       error = function(e) NULL)
        if (!is.null(ct)) {
          out$rate_ratio <- ct$rate_ratio
          out$rate_ratio_lower <- ct$lower %||% NA_real_
          out$rate_ratio_upper <- ct$upper %||% NA_real_
        }
      }
    }
    out
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

#' @export
print.bricklayer_analysis <- function(x, ...) {
  m <- x$meta
  cat(sprintf("Analysis of `%s` by %s over %d period(s) (%s to %s)%s\n",
              m$value, m$period, length(m$periods), m$periods[1L],
              m$periods[length(m$periods)],
              if (length(m$by)) paste0(", grouped by ",
                                       paste(m$by, collapse = " x ")) else ""))
  cat(sprintf("  rows %d, columns %d; %s\n", m$n_rows, nrow(x$profile),
              if (x$missingness[["n_missing"]] > 0)
                sprintf("%d column(s) with missing values",
                        x$missingness[["n_cols_any_missing"]]) else
                "no missing values"))
  ch <- x$change
  cmp <- ch[!is.na(ch$previous), , drop = FALSE]
  cat(sprintf("  change: %d comparison(s)", nrow(cmp)))
  if (!is.null(cmp$significant)) {
    cat(sprintf(", %d significant after %s at %g", sum(cmp$significant),
                m$adjust, m$alpha))
  }
  cat("\n")
  if (!is.null(cmp$combined_pct_lower)) {
    cat(sprintf(paste0("  publication bounds: rounding %s (%s)%s; ",
                       "combined intervals reported\n"),
                if (is.null(m$rounding)) "none" else format(m$rounding),
                m$rounding_kind,
                if (is.null(m$suppression_limit)) "" else
                  sprintf(", suppression below %g", m$suppression_limit)))
  }
  if (!is.null(x$rate_change)) {
    r <- x$rate_change[!is.na(x$rate_change$previous_rate), , drop = FALSE]
    cat(sprintf(paste0("  rates per %s: %d comparison(s), ",
                       "%d significant after adjustment\n"),
                format(m$per), nrow(r), sum(r$significant, na.rm = TRUE)))
  }
  tr <- x$trend
  if (nrow(tr) && any(!is.na(tr$trend_p))) {
    cat(sprintf("  trend: %d of %d series with Mann-Kendall p < %g\n",
                sum(tr$trend_p < m$alpha, na.rm = TRUE), nrow(tr), m$alpha))
  } else {
    cat("  trend: fewer than three periods, not tested\n")
  }
  if (!is.null(x$drift)) {
    d <- x$drift$columns
    cat(sprintf(paste0("  drift vs prior capsule: %d of %d column(s) ",
                       "flagged at alpha %g\n"),
                sum(d$drifted, na.rm = TRUE), nrow(d), m$alpha))
  }
  invisible(x)
}

#' Write an analysis as a Markdown or HTML report
#'
#' Renders an [analyse_table()] result as a report: the
#' change table with
#' its intervals and adjusted p-values, the rates, the trends, the drift
#' screen and the column profile, each with one sentence saying how to read
#' it. The Markdown is plain enough to paste into a notebook or a pull
#' request; the HTML is a single self-contained file with no external
#' resources, suitable for e-mailing to a reviewer.
#'
#' @details
#' Sections appear in this order: a header line (value, period, groups,
#' rows, period range and the time of the analysis), "Change between
#' periods", "Rates per ..." (when there were rates), "Trend over the
#' series", "Drift against the prior capsule" (when a prior was given) and
#' "What is in the table" (with "Missing values" when any are missing).
#' Tables use pipe syntax; numbers are rounded to \code{digits} decimals,
#' whole numbers of 10,000 and above get thousands separators, logicals are
#' written yes/no and \code{NA} is blank. When the values are percentages
#' the change is reported in percentage points. The HTML is produced by a
#' small built-in converter (headings, paragraphs, tables and inline code,
#' with the text escaped). The file is written as UTF-8 and overwritten if
#' it exists.
#'
#' Errors: \code{x} not from [analyse_table()]; an invalid
#' \code{format}.
#'
#' @param x A \code{bricklayer_analysis} from
#'   [analyse_table()].
#' @param path Where to write, a file path. With \code{NULL} (the default)
#'   the text is returned invisibly and nothing is written.
#' @param format \code{"markdown"} (the default) or \code{"html"}. When
#'   \code{format} is not given and \code{path} ends in \code{.html} or
#'   \code{.htm}, HTML is written; any other path gives Markdown.
#' @param title Report title, a string; the top heading and, for HTML, the
#'   page title.
#' @param digits Number of decimals for percentages and rates, default 1.
#' @return The report text (a length-1 character string, Markdown or a full
#'   HTML document), invisibly.
#' @examples
#' path <- system.file("extdata", "otis_a01_individuals.csv",
#'                     package = "rmoriebricklayer")
#' a <- analyse_table(read.csv(path), value = "individuals",
#'                    period = "year", by = c("table", "group"))
#' md <- report_analysis(a)
#' cat(substr(md, 1, 400))
#'
#' # HTML, chosen from the file extension
#' out <- tempfile(fileext = ".html")
#' report_analysis(a, out, title = "OTIS A01: individuals in custody", digits = 2)
#' readLines(out, n = 3)
#'
#' # only an analyse_table() result can be reported
#' try(report_analysis(read.csv(path)))
#' unlink(out)
#' @export
report_analysis <- function(x, path = NULL, format = c("markdown", "html"),
                            title = "Analysis of a published table",
                            digits = 1L) {
  if (!inherits(x, "bricklayer_analysis")) {
    stop("`x` must come from analyse_table()", call. = FALSE)
  }
  if (!is.null(path) && missing(format)) {
    format <- if (grepl("\\.html?$", path, ignore.case = TRUE)) "html" else
      "markdown"
  }
  format <- .rmbl_arg(format)
  m <- x$meta
  lines <- character()
  add <- function(...) lines <<- c(lines, ...)
  add(paste0("# ", title), "",
      sprintf(paste0("`%s` by `%s`%s; %d rows; %d period(s) from %s to %s; ",
                     "generated %s."),
              m$value, m$period,
              if (length(m$by)) paste0(", grouped by ",
                                       paste(sprintf("`%s`", m$by),
                                             collapse = " and ")) else "",
              m$n_rows, length(m$periods), m$periods[1L],
              m$periods[length(m$periods)], m$when), "")

  ch <- x$change
  chg <- if ("pct_change" %in% names(ch)) "pct_change" else "pp_change"  # percent units change in points
  add("## Change between periods", "",
      if (identical(chg, "pp_change")) {
        # the values are percentages: they change in points, and a count interval does not apply
        paste("Change in percentage points between consecutive periods (the values are percentages,",
              "so no count-based interval applies).")
      } else {
        sprintf(paste0("Percent change with a %g%% exact conditional-binomial ",
                       "interval; p-values are exact and adjusted over the %d ",
                       "comparisons by %s. A row is significant when the ",
                       "adjusted p-value is below %g."),
                100 * m$conf_level, sum(!is.na(x$change$previous)),
                m$adjust, m$alpha)
      }, "")
  cols <- c(m$by, m$period, "value", "previous", chg)
  if (!is.null(ch$pct_lower)) cols <- c(cols, "pct_lower", "pct_upper")
  if (!is.null(ch$combined_pct_lower)) {
    cols <- c(cols, "combined_pct_lower", "combined_pct_upper")
    add(sprintf(paste0("`combined_*` widens the sampling interval by the ",
                       "envelope that rounding%s in the release implies; ",
                       "it is the honest range for a figure read off the ",
                       "published table."),
                if (is.null(m$suppression_limit)) "" else " and suppression"),
        "")
  }
  if (!is.null(ch$p_adjusted)) cols <- c(cols, "p_adjusted", "significant")
  cols <- c(cols, "flag")
  add(.md_table(ch[cols], digits, plain = m$period), "")

  if (!is.null(x$rate_change)) {
    add(sprintf("## Rates per %s", format(m$per)), "",
        sprintf(paste0("Rate ratios between consecutive periods with %g%% ",
                       "intervals; p-values exact given the exposures, ",
                       "adjusted by %s."), 100 * m$conf_level, m$adjust), "")
    rc <- x$rate_change
    add(.md_table(rc[c(m$by, m$period, "count", "population", "rate",
                       "previous_rate", "pct_change", "pct_lower",
                       "pct_upper", "p_adjusted", "significant", "flag")],
                  digits, plain = m$period), "")
  }

  add("## Trend over the series", "",
      paste0("Mann-Kendall tau and its p-value (exact for short series), ",
             "the Theil-Sen slope per period, and for counts the Poisson ",
             "rate ratio per period with its interval. Three periods is ",
             "the minimum; a p-value from three points can never fall ",
             "below 0.33, which is reported rather than hidden."), "")
  add(.md_table(x$trend, 3L), "")

  if (!is.null(x$drift)) {
    add("## Drift against the prior capsule", "",
        sprintf(paste0("Per column: Kolmogorov-Smirnov or chi-square against ",
                       "the prior release at alpha %g, and the population ",
                       "stability index. `drifted` is the screen's verdict; ",
                       "run `drift_calibrate()` on the prior capsule to learn ",
                       "how often these screens fire on identical data."),
                m$alpha), "")
    add(.md_table(x$drift$columns, 3L), "")
    if (length(x$drift$added)) {
      add(sprintf("Columns added: %s.",
                  paste(x$drift$added, collapse = ", ")), "")
    }
    if (length(x$drift$removed)) {
      add(sprintf("Columns removed: %s.",
                  paste(x$drift$removed, collapse = ", ")), "")
    }
  }

  add("## What is in the table", "", .md_table(x$profile, 2L), "")
  if (x$missingness[["n_missing"]] > 0) {
    add("### Missing values", "",
        .md_table(as.data.frame(as.list(x$missingness)), 2L), "")
  }
  text <- paste(lines, collapse = "\n")
  if (format == "html") text <- .md_to_html(text, title)
  if (!is.null(path)) {
    writeLines(enc2utf8(text), path, useBytes = TRUE)
  }
  invisible(text)
}

# Minimal Markdown table (pipe syntax) from a data frame; numeric
# columns rounded to `digits`, logicals as yes/no, NA as blank.
.md_table <- function(d, digits = 1L, plain = character()) {
  d <- as.data.frame(d, stringsAsFactors = FALSE)
  if (!nrow(d)) return("(no rows)")
  cells <- lapply(names(d), function(nm) {
    v <- d[[nm]]
    if (nm %in% plain) {
      # a period (2023) is a label, not a quantity: no thousands separator
      ifelse(is.na(v), "", format(v, trim = TRUE, scientific = FALSE))
    } else if (is.logical(v)) {
      ifelse(is.na(v), "", ifelse(v, "yes", "no"))
    } else if (is.numeric(v)) {
      whole <- v == round(v) & abs(v) < 1e9
      # a separator from 10,000 up only: a four-digit whole number (a year in the profile's
      # min / max) read as "2,023"
      ifelse(is.na(v), "",
             ifelse(whole,
                    ifelse(abs(v) >= 1e4, format(v, big.mark = ",", trim = TRUE, scientific = FALSE),
                           format(v, trim = TRUE, scientific = FALSE)),
                    formatC(v, digits = digits, format = "f")))
    } else {
      ifelse(is.na(v), "", as.character(v))
    }
  })
  rows <- do.call(paste, c(cells, sep = " | "))
  paste(c(paste("|", paste(names(d), collapse = " | "), "|"),
          paste("|", paste(rep("---", ncol(d)), collapse = " | "), "|"),
          paste("|", rows, "|")), collapse = "\n")
}

# Enough Markdown for the report: headings, paragraphs, pipe tables,
# inline code. No dependency, no external resources.
.md_to_html <- function(md, title) {
  esc <- function(s) {
    s <- gsub("&", "&amp;", s, fixed = TRUE)
    s <- gsub("<", "&lt;", s, fixed = TRUE)
    gsub(">", "&gt;", s, fixed = TRUE)
  }
  inline <- function(s) gsub("`([^`]+)`", "<code>\\1</code>", esc(s))
  lines <- strsplit(md, "\n", fixed = TRUE)[[1L]]
  out <- character()
  i <- 1L
  while (i <= length(lines)) {
    l <- lines[i]
    if (grepl("^#{1,3} ", l)) {
      lvl <- nchar(sub(" .*$", "", l))
      out <- c(out, sprintf("<h%d>%s</h%d>", lvl,
                            inline(sub("^#+ ", "", l)), lvl))
    } else if (grepl("^\\|", l)) {
      j <- i
      while (j <= length(lines) && grepl("^\\|", lines[j])) j <- j + 1L
      tbl <- lines[i:(j - 1L)]
      cells <- lapply(tbl[-2L], function(r) {
        v <- strsplit(sub("\\|\\s*$", "", sub("^\\|\\s*", "", r)), " | ",
                      fixed = TRUE)[[1L]]
        trimws(v)
      })
      hdr <- paste0("<tr>", paste0("<th>", inline(cells[[1L]]), "</th>",
                                   collapse = ""), "</tr>")
      body <- vapply(cells[-1L], function(v) {
        paste0("<tr>", paste0("<td>", inline(v), "</td>", collapse = ""),
               "</tr>")
      }, "")
      out <- c(out, "<table>", hdr, body, "</table>")
      i <- j
      next
    } else if (nzchar(trimws(l))) {
      out <- c(out, paste0("<p>", inline(l), "</p>"))
    }
    i <- i + 1L
  }
  paste(c("<!DOCTYPE html>", "<html lang=\"en\"><head><meta charset=\"utf-8\">",
          sprintf("<title>%s</title>", esc(title)),
          paste0("<style>body{font:15px/1.5 system-ui,sans-serif;",
                 "max-width:60em;margin:2em auto;padding:0 1em;color:#222}"),
          "table{border-collapse:collapse;margin:1em 0;font-size:13px}",
          "th,td{border:1px solid #ccc;padding:3px 7px;text-align:right}",
          paste0("th{background:#f3f3f3}",
                 "td:first-child,th:first-child{text-align:left}"),
          "code{background:#f3f3f3;padding:0 3px}</style></head><body>",
          out, "</body></html>"), collapse = "\n")
}
