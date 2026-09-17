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
#' @param data A data frame in long form: one row per period and group.
#' @param value Column with the published count (or measure).
#' @param period Column with the period (fiscal year, quarter, ...).
#' @param by Optional grouping columns (institution, region, ...).
#' @param population Optional exposure column for rates.
#' @param prior Optional data frame: the previous capsule of the same
#'   table, for the drift screen.
#' @param units `"count"`, `"continuous"` or `"percent"`, as in
#'   [yoy()].
#' @param rounding,rounding_kind,suppression_limit How the release rounds
#'   or suppresses cells; see
#'   [published_bounds()]. `NULL` when the
#'   counts are exact.
#' @param direction Which way is an improvement, as in [yoy()].
#' @param per Rate denominator, as in [rate()].
#' @param conf_level Confidence level for every interval.
#' @param alpha Level for the multiple-comparison decision and the drift
#'   screens.
#' @param adjust Multiple-comparison method for [scan_adjust()].
#' @return A list of class `bricklayer_analysis` with `profile`
#'   ([profile_columns()]), `missingness`
#'   ([missingness_summary()]),
#'   `change` ([yoy()] with p-values, adjustment and,
#'   if `rounding` or
#'   `suppression_limit` was given, publication bounds), `rates` and
#'   `rate_change` (when `population` is given), `trend` (one row per
#'   group with [trend_test()] and, for counts,
#'   [count_trend()]),
#'   `drift` ([capsule_drift()] against `prior`),
#'   and `meta`.
#' @examples
#' path <- system.file("extdata", "otis_a01_individuals.csv",
#'                     package = "rmoriebricklayer")
#' otis <- read.csv(path)
#' a <- analyse_table(otis, value = "individuals", period = "year",
#'                    by = c("table", "group"))
#' a
#' a$change[, c("table", "group", "year", "pct_change", "p_adjusted")]
#' @seealso [report_analysis()] writes the result as a Markdown or HTML
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
  units <- match.arg(units)
  direction <- match.arg(direction)
  rounding_kind <- match.arg(rounding_kind)
  for (col in c(value, period, by, population)) {
    if (!col %in% names(data)) {
      stop(sprintf("column `%s` not found in `data`", col), call. = FALSE)
    }
  }
  bounded <- !is.null(rounding) || !is.null(suppression_limit)

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
  groups <- if (is.null(by)) list(data) else
    split(data, data[by], drop = TRUE)
  rows <- lapply(groups, function(g) {
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
#' Renders a [analyse_table()] result: the profile,
#' the change table
#' with its intervals and adjusted p-values, the rates, the trends and
#' the drift screen, each with one sentence saying how to read it. The
#' Markdown is plain enough to paste into a notebook; the HTML is a
#' single self-contained file.
#'
#' @param x A `bricklayer_analysis`.
#' @param path Where to write. With `NULL` the text is returned invisibly
#'   and nothing is written.
#' @param format `"markdown"` or `"html"`; guessed from `path` when it
#'   ends in `.html` or `.md`.
#' @param title Report title.
#' @param digits Digits for percentages and rates.
#' @return The report text, invisibly.
#' @examples
#' path <- system.file("extdata", "otis_a01_individuals.csv",
#'                     package = "rmoriebricklayer")
#' a <- analyse_table(read.csv(path), value = "individuals",
#'                    period = "year", by = c("table", "group"))
#' md <- report_analysis(a)
#' cat(substr(md, 1, 400))
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
  format <- match.arg(format)
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

  add("## Change between periods", "",
      sprintf(paste0("Percent change with a %g%% exact conditional-binomial ",
                     "interval; p-values are exact and adjusted over the %d ",
                     "comparisons by %s. A row is significant when the ",
                     "adjusted p-value is below %g."),
              100 * m$conf_level, sum(!is.na(x$change$previous)),
              m$adjust, m$alpha), "")
  ch <- x$change
  cols <- c(m$by, m$period, "value", "previous", "pct_change")
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
  add(.md_table(ch[cols], digits), "")

  if (!is.null(x$rate_change)) {
    add(sprintf("## Rates per %s", format(m$per)), "",
        sprintf(paste0("Rate ratios between consecutive periods with %g%% ",
                       "intervals; p-values exact given the exposures, ",
                       "adjusted by %s."), 100 * m$conf_level, m$adjust), "")
    rc <- x$rate_change
    add(.md_table(rc[c(m$by, m$period, "count", "population", "rate",
                       "previous_rate", "pct_change", "pct_lower",
                       "pct_upper", "p_adjusted", "significant", "flag")],
                  digits), "")
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
.md_table <- function(d, digits = 1L) {
  d <- as.data.frame(d, stringsAsFactors = FALSE)
  if (!nrow(d)) return("(no rows)")
  cells <- lapply(d, function(v) {
    if (is.logical(v)) {
      ifelse(is.na(v), "", ifelse(v, "yes", "no"))
    } else if (is.numeric(v)) {
      whole <- v == round(v) & abs(v) < 1e9
      ifelse(is.na(v), "",
             ifelse(whole,
                    format(v, big.mark = ",", trim = TRUE,
                           scientific = FALSE),
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
