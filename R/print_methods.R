# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Output surface. A provenance tool is read by a person deciding whether
# to trust a result, so what it prints matters as much as what it
# computes: the verdict comes first, the numbers that justify it come
# second, and anything demanding attention is visible without being
# looked for.
#
# Every method degrades to plain ASCII when the console cannot render
# box-drawing characters, reusing the package's own toascii()/
# asciifb() policy rather than assuming UTF-8.

#' @export
format.bricklayer_drift <- function(x, ...) {
  g <- .rmbl_glyphs()
  cols <- x$columns
  nd <- sum(cols$drifted, na.rm = TRUE)
  verdict <- if (isTRUE(x$anydrft)) {
    paste0(g$bad, " DRIFT DETECTED")
  } else {
    paste0(g$ok, " no drift detected")
  }
  .rmbl_res_block(
    "Capsule drift report",
    facts = list(
      Verdict = verdict,
      `Reference rows` = x$nref,
      `Current rows` = x$ncur,
      `Columns tested` = nrow(cols),
      `Columns drifted` = nd,
      Alpha = x$alpha
    ),
    tables = if (nrow(cols)) {
      list(`Per-column tests` = .rmbl_drift_table(cols, g))
    },
    reading = .rmbl_drift_reading(x, nd, nrow(cols)),
    notes = c(
      trimws(.rmbl_drift_moved(x, g)),
      paste(
        "plot(x, what = \"columns\") draws the columns; drfthtml(x, file)",
        "writes an interactive report."
      )
    ),
    maxrows = 30L
  )
}

#' @rdname printmeth
#' @export
summary.bricklayer_drift <- function(object, ...) {
  cols <- object$columns
  drifted <- if (nrow(cols)) {
    cols$column[which(
      isTRUE(cols$drifted) |
        cols$drifted
    )]
  } else {
    character(0)
  }
  out <- list(
    anydrft = object$anydrft,
    ntes = nrow(cols),
    ndri = length(drifted),
    drifted = drifted,
    added = object$added,
    removed = object$removed
  )
  class(out) <- c("bricklayer_drift_summary", "list")
  out
}

#' @export
format.bricklayer_drift_summary <- function(x, ...) {
  g <- .rmbl_glyphs()
  .rmbl_res_block(
    "Drift summary",
    facts = list(
      Verdict = if (isTRUE(x$anydrft)) {
        paste0(g$bad, " drift detected")
      } else {
        paste0(g$ok, " no drift detected")
      },
      Drifted = sprintf("%d of %d columns", x$ndri, x$ntes),
      `Drifted columns` = if (length(x$drifted)) toString(x$drifted),
      `Columns added` = if (length(x$added)) toString(x$added),
      `Columns removed` = if (length(x$removed)) toString(x$removed)
    )
  )
}

#' @export
format.bricklayer_benford <- function(x, ...) {
  g <- .rmbl_glyphs()
  prop <- x$proportion
  expected <- x$expected / x$n
  # A 20-cell bar makes the shape of the deviation legible at a glance,
  # which a column of numbers does not.
  bar <- vapply(
    prop,
    function(p) {
      n <- max(0L, min(20L, as.integer(round(p * 20 / max(prop)))))
      paste0(strrep("#", n), strrep(" ", 20L - n))
    },
    character(1)
  )
  verdict <- if (is.na(x$p_value)) {
    "?"
  } else if (x$p_value < 0.01) {
    paste0(g$warn, " departs from Benford's law (screen only, not a verdict)")
  } else {
    paste0(g$ok, " consistent with Benford's law")
  }
  c(
    .rmbl_rule("Benford first-digit screen"),
    paste0("  ", verdict),
    "",
    .rmbl_kv(list(
      "values used" = format(x$n, big.mark = ","),
      "chi-square" = formatC(x$statistic, format = "f", digits = 3),
      "df" = x$df,
      "p-value" = .rmbl_fmt_p(x$p_value)
    )),
    "",
    paste0("  digit  observed  expected  ", strrep(" ", 6), "shape"),
    sprintf(
      "  %5s  %8s  %8s  %s",
      names(prop),
      formatC(prop, format = "f", digits = 3),
      formatC(expected, format = "f", digits = 3),
      bar
    ),
    .rmbl_benford_reading(x, prop, expected),
    .rmbl_rule()
  )
}

#' @export
format.bricklayer_signing_key <- function(x, ...) {
  c(
    .rmbl_rule("Signing key (post-quantum)"),
    .rmbl_kv(list(
      scheme = x$scheme,
      root = x$root,
      height = x$height,
      used = sprintf("%d of %d signatures", x$next_index, x$capacity),
      remaining = x$capacity - x$next_index,
      secret = "<withheld>"
    )),
    paste0(
      "  ",
      .rmbl_glyphs()$warn,
      " one signature per index; never sign twice at one index"
    ),
    .rmbl_rule()
  )
}

#' @export
format.bricklayer_public_key <- function(x, ...) {
  c(
    .rmbl_rule("Public verification key"),
    .rmbl_kv(list(scheme = x$scheme, root = x$root, height = x$height)),
    .rmbl_rule()
  )
}

#' @export
format.bricklayer_signature <- function(x, ...) {
  pairs <- list(scheme = x$scheme)
  if (!is.null(x$key_state)) {
    pairs$WARNING <- paste0(
      "carries the signer's private key (key_state, 0.5.9 to 7703a04): ",
      "the key is compromised"
    )
  }
  if (identical(x$scheme, "hmac")) {
    pairs$tag <- x$signature
  } else if (is.null(x$auth)) {
    # a standardised scheme: no authentication path and no leaf index
    pairs$signature <- sprintf(
      "%s... (%d bytes)",
      substring(x$signature, 1L, 32L),
      nchar(x$signature) %/% 2L
    )
    pairs$state <- "stateless"
  } else {
    pairs$index <- x$index
    pairs$root <- x$root
    pairs$signature <- sprintf(
      "%s... (%d bytes)",
      substring(x$signature, 1L, 32L),
      nchar(x$signature) %/% 2L
    )
    pairs$`auth path` <- sprintf("%d nodes", nchar(x$auth) %/% 64L)
  }
  c(.rmbl_rule("Capsule signature"), .rmbl_kv(pairs), .rmbl_rule())
}

#' @param object The object to summarise.
#' @rdname printmeth
#' @export
summary.bricklayer_benford <- function(object, ...) {
  c(
    n = object$n,
    statistic = object$statistic,
    df = object$df,
    p_value = object$p_value
  )
}

#' Column report for a data frame
#'
#' One row per column: type, missingness, and the summaries that suit the
#' column's type -- mean and standard deviation alongside their robust
#' counterparts (median, MAD) for a numeric column, and the number of
#' distinct levels plus the most common one for a categorical column.
#'
#' Reporting the classical and robust centres side by side is the point:
#' where they disagree, the column has outliers or a heavy tail, and the
#' mean is not describing it. That is visible in one glance here and in no
#' single number.
#'
#' How the numbers are computed. A column is numeric when `is.numeric()` is
#' `TRUE`; every other column (character, factor, logical, `Date`, ...) is
#' treated as categorical, and `top` is its most frequent non-missing value as
#' text (ties broken by the order of `sort(table())`). For a numeric column,
#' over its non-missing values: `sd` is the sample standard deviation (\eqn{n -
#' 1}), `mad` the median absolute deviation scaled by 1.4826, `skewness` the
#' population moment ratio \eqn{m_3 / m_2^{3/2}}, `n_outliers` the count outside
#' the Tukey fences (1.5 interquartile ranges beyond the quartiles), and the
#' quantiles are type 7. Infinite values are counted in `ninf` (and in `nneg`,
#' `n_distinct`) and left out of every other numeric statistic, which are taken
#' over the finite values only: a column with an infinite value keeps a finite
#' mean and range, and a column with no finite value has `NA` statistics. A
#' progress bar is shown for wide tables when `options(morie.progress)` allows
#' it. Errors when `data` is not a data frame, has no columns, or has duplicate
#' or empty column names.
#'
#' @param data A data frame whose columns are profiled.
#' @param qnts Numeric vector of quantile probabilities to include for
#' numeric columns, one column each named `q` and the percentage (`q25`,
#' `q50`, ...); default the quartiles. `NULL` or an empty vector adds none.
#' @return A data frame of class `bricklayer_profile`, one row per
#' column: the type, the missing count and share, the number of distinct
#' values, and for a numeric column the counts of zero, negative and
#' infinite values, the classical and robust centre and spread, the range,
#' the skewness, the count outside the Tukey fences, and an
#' [inlhist()] sketch of its distribution. A
#' categorical column reports its most common value in `top` instead.
#' The columns are `column`, `type` (the first class), `n`,
#' `n_missing`,
#' `pct_missing`, `n_distinct`, `nzero`, `nneg`,
#' `ninf`,
#' `mean`, `sd`, `median`, `mad`, `min`, `max`,
#' `skewness`, `n_outliers`,
#' `hist`, `top` and one per quantile; a statistic that does not apply to the
#' column's type is `NA`. The print method formats the numbers to four
#' significant digits and shows the histogram last.
#' @seealso
#' [cpsdrft()] to compare two of these,
#' [cmom()] for the underlying kernel.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' set.seed(9)
#' df <- data.frame(
#'   clean = stats::rnorm(100),
#'   skewed = c(stats::rnorm(99), 500),
#'   grade = sample(c("a", "b", "c"), 100, TRUE),
#'   gappy = c(rep(NA, 10), stats::runif(90))
#' )
#'
#' profcols(df)
#'
#' # The mean and the median agree on `clean` and disagree sharply on
#' # `skewed`, which is the outlier announcing itself.
#' p <- profcols(df)
#' p[p$column %in% c("clean", "skewed"), c("column", "mean", "median")]
#'
#' # The histogram column shows shape no summary number carries.
#' p[, c("column", "hist")]
#'
#' # Zeros, negatives and infinities are counted separately, because
#' # each breaks a different downstream computation (a log, a square
#' # root, an average).
#' p[, c("column", "nzero", "nneg", "ninf")]
#'
#' # deciles instead of quartiles
#' names(profcols(df, qnts = c(0.1, 0.9)))
#'
#' # a table with no columns has nothing to profile
#' try(profcols(df[, 0]))
#' @export
#' @srrstats {EA5.2} print.bricklayer_profile formats numbers with
#'   formatC(digits = 4); other print methods use formatC or sprintf too;
#'   test-print_methods.R.
#' @srrstats {EA5.3} The column profile has a `type` column (the first class of
#'   each column); test-print_methods.R:137.
profcols <- function(data, qnts = c(0.25, 0.5, 0.75)) {
  if (!is.data.frame(data)) {
    stop("profcols: `data` must be a data frame", call. = FALSE)
  }
  .rmbl_df_names(data)
  if (ncol(data) == 0L) {
    stop("`data` has no columns to profile", call. = FALSE)
  }
  qnts <- .rmbl_num(qnts, "qnts")
  if (anyNA(qnts) || any(qnts < 0 | qnts > 1)) {
    stop("`qnts` must be probabilities in [0, 1]", call. = FALSE)
  }
  pg <- blprog("profiling columns", ncol(data))
  on.exit(pg$done(), add = TRUE)
  rows <- lapply(names(data), function(nm) {
    pg$tick(info = nm)
    .rmbl_prof_row(data[[nm]], nm)
  })
  out <- do.call(rbind, rows)
  if (length(qnts)) {
    out <- cbind(out, .rmbl_prof_qnts(data, qnts))
  }
  rownames(out) <- NULL
  class(out) <- c("bricklayer_profile", "data.frame")
  out
}

#' @export
format.bricklayer_profile <- function(x, digits = 4L, ...) {
  fb <- .rmbl_df_fallback(x, "Column profile", c("column", "type"), digits)
  if (!is.null(fb)) {
    return(fb)
  }
  df <- .rmbl_plain(x)
  # the histogram is a drawing, not a value: keep it last
  if ("hist" %in% names(df)) {
    df <- df[c(setdiff(names(df), "hist"), "hist")]
  }
  nmiss <- if (is.null(x$n_missing)) NA else sum(x$n_missing > 0, na.rm = TRUE)
  .rmbl_res_block(
    "Column profile",
    facts = list(
      Columns = nrow(df),
      Rows = if (nrow(df) && !is.null(x$n)) max(x$n),
      Numeric = sum(x$type %in% c("numeric", "integer")),
      `With missing values` = nmiss
    ),
    tables = df,
    reading = paste(
      "Where the mean and the median (or sd and mad) disagree, the column",
      "has outliers or a heavy tail and the mean does not describe it;",
      "n_outliers counts the values beyond the Tukey fences."
    ),
    digits = digits,
    maxrows = 60L
  )
}

#' TRUE when the connection can be trusted with non-ASCII box characters.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_unicode_ok <- function() {
  if (!identical(Sys.getenv("RMBL_ASCII_ONLY"), "")) {
    return(FALSE)
  }
  l10n <- l10n_info()
  isTRUE(l10n[["UTF-8"]])
}

#' Returns the box-drawing and status glyphs for the console, Unicode or ASCII.
#' @return A named list of strings.
#' @noRd
.rmbl_glyphs <- function() {
  if (.rmbl_unicode_ok()) {
    list(
      h = "\u2500",
      tl = "\u250c",
      tr = "\u2510",
      bl = "\u2514",
      br = "\u2518",
      v = "\u2502",
      ok = "\u2713",
      bad = "\u2717",
      warn = "!",
      dash = "\u2013"
    )
  } else {
    list(
      h = "-",
      tl = "+",
      tr = "+",
      bl = "+",
      br = "+",
      v = "|",
      ok = "OK",
      bad = "X",
      warn = "!",
      dash = "-"
    )
  }
}

#' A titled rule, e.g. \dQuote{-- Drift report ----------------}.
#' @param title The title, or NULL for a plain rule.
#' @param width The rule's width in characters.
#' @return One string.
#' @noRd
.rmbl_rule <- function(title = NULL, width = 66L) {
  g <- .rmbl_glyphs()
  if (is.null(title)) {
    return(strrep(g$h, width))
  }
  left <- paste0(strrep(g$h, 2L), " ", title, " ")
  pad <- max(0L, width - nchar(left))
  paste0(left, strrep(g$h, pad))
}

#' Fixed-width label/value lines, labels right-padded to a common width.
#' @param pairs A named list or vector of values.
#' @param indent The number of spaces before each line.
#' @return A character vector of lines.
#' @noRd
.rmbl_kv <- function(pairs, indent = 2L) {
  keys <- names(pairs)
  w <- if (length(keys)) max(nchar(keys)) else 0L
  paste0(
    strrep(" ", indent),
    formatC(keys, width = w, flag = "-"),
    "  ",
    vapply(pairs, function(v) toString(format(v)), character(1))
  )
}

#' Prints a subset table as a plain data frame when the print method's columns
#' are missing.
#'
#' A classed data frame keeps its class when columns are subset away, so
#' `result[, c("a", "b")]` still dispatches to the custom print method
#' with the columns that method needs now missing. Fall back to a plain
#' data-frame print rather than erroring on the user's subset.
#' @param x The classed data frame.
#' @param cols The columns the print method needs.
#' @return TRUE when the plain print was done, else FALSE.
#' @noRd
.rmbl_needs_cols <- function(x, cols) {
  if (all(cols %in% names(x))) {
    return(FALSE)
  }
  df <- x
  class(df) <- "data.frame"
  for (a in setdiff(names(attributes(df)), c("names", "row.names", "class"))) {
    attr(df, a) <- NULL
  }
  print(df)
  TRUE
}

#' Computes the column statistics of the describe table.
#'
#' Column statistics for the describe table. Inside the package these are
#' the compiled kernels; sourced standalone in a capsule bundle (no family
#' package installed) the same definitions come from base R: population
#' skewness m3 / m2^1.5, type-7 quartiles, Tukey fences at 1.5 IQR, MAD
#' with the 1.4826 constant.
#' @param ok The column's non-missing values.
#' @param native Whether the compiled kernels are there to use.
#' @return A named list of statistics.
#' @noRd
.rmbl_column_stats <- function(ok, native = exists("cmom", mode = "function")) {
  # bundle-scan-guarded: ctkyfnc cmed cmad
  if (native) {
    m <- cmom(ok)
    f <- ctkyfnc(ok)
    return(list(
      mean = m[["mean"]],
      sd = sqrt(m[["variance"]]),
      skewness = m[["skewness"]],
      median = cmed(ok),
      mad = cmad(ok),
      lower = f[["lower"]],
      upper = f[["upper"]],
      hist = if (exists(".rmbl_sparkline", mode = "function")) {
        .rmbl_sparkline(ok)
      } else {
        NA_character_
      }
    ))
  }
  n <- length(ok)
  mu <- mean(ok)
  d <- ok - mu
  m2 <- mean(d^2)
  sk <- if (n > 2 && m2 > 0) mean(d^3) / m2^1.5 else NaN
  q <- stats::quantile(ok, c(0.25, 0.75), names = FALSE, type = 7)
  iqr <- q[2L] - q[1L]
  list(
    mean = mu,
    sd = if (n > 1) stats::sd(ok) else NaN,
    skewness = sk,
    median = stats::median(ok),
    mad = stats::mad(ok),
    lower = q[1L] - 1.5 * iqr,
    upper = q[2L] + 1.5 * iqr,
    hist = NA_character_
  )
}

#' The added- and removed-column lines of a printed drift report.
#' @param x A cpsdrft() result, whose added and removed columns are listed.
#' @param g The glyphs from .rmbl_glyphs(), marking moved columns.
#' @return A character vector, empty when no column came or went.
#' @noRd
.rmbl_drift_moved <- function(x, g) {
  out <- character(0)
  if (length(x$added)) {
    out <- c(
      out,
      paste0(
        "  ",
        g$warn,
        " columns added:   ",
        toString(x$added)
      )
    )
  }
  if (length(x$removed)) {
    out <- c(
      out,
      paste0(
        "  ",
        g$warn,
        " columns removed: ",
        toString(x$removed)
      )
    )
  }
  out
}

#' The per-column test table of a printed drift report, drifted columns
#' first.
#' @param cols The report's `columns` table, at least one row.
#' @param g The glyphs from .rmbl_glyphs(), marking each column.
#' @return A data frame.
#' @noRd
.rmbl_drift_table <- function(cols, g) {
  mark <- ifelse(cols$drifted, g$bad, g$ok)
  flag <- ifelse(is.na(cols$drifted), "?", mark)
  tbl <- data.frame(
    ` ` = flag,
    column = cols$column,
    type = cols$type,
    stat = cols$statistic,
    p = cols$p_value,
    psi = cols$psi,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  # Drifted columns first: the reader is looking for the problem.
  ord <- order(
    !isTRUE(cols$drifted) & !is.na(cols$drifted),
    -xtfrm(ifelse(is.na(cols$drifted), FALSE, cols$drifted)),
    cols$p_value
  )
  tbl <- tbl[ord, , drop = FALSE]
  rownames(tbl) <- NULL
  tbl
}

#' The reading of a drift report.
#' @param x The report.
#' @param nd The number of columns that drifted.
#' @param nt The number of columns tested.
#' @return One string.
#' @noRd
.rmbl_drift_reading <- function(x, nd, nt) {
  if (!nt) {
    return("No column was in both tables, so nothing could be compared.")
  }
  if (nd) {
    return(sprintf(
      paste(
        "%d of %d columns changed between the reference and the current",
        "table by more than chance at alpha %s; check those columns before",
        "trusting results built on the reference."
      ),
      nd,
      nt,
      format(x$alpha)
    ))
  }
  sprintf(
    paste(
      "None of the %d columns changed by more than chance at alpha %s;",
      "psi above 0.25 is the usual sign of a material shift."
    ),
    nt,
    format(x$alpha)
  )
}

#' One profcols() row: the column's name, type and missingness, then its
#' statistics.
#' @param v The column profiled into one row.
#' @param nm The column's name, for the row.
#' @return A one-row data frame.
#' @noRd
.rmbl_prof_row <- function(v, nm) {
  n_missing <- sum(is.na(v))
  base <- data.frame(
    column = nm,
    type = class(v)[1L],
    n = length(v),
    n_missing = n_missing,
    pct_missing = 100 * n_missing / max(1L, length(v)),
    stringsAsFactors = FALSE
  )
  if (is.numeric(v)) {
    return(.rmbl_prof_numeric(base, v))
  }
  .rmbl_prof_other(base, v)
}

#' The statistics of a numeric column, for profcols().
#' @param base The row's name, type and missingness.
#' @param v The numeric column summarised.
#' @return A one-row data frame.
#' @noRd
.rmbl_prof_numeric <- function(base, v) {
  ok <- v[!is.na(v)]
  if (length(ok) == 0L) {
    return(.rmbl_prof_empty(base))
  }
  # the statistics are over the finite values: an Inf counted in
  # ninf made the mean and the range infinite as well
  fin <- ok[is.finite(ok)]
  st <- if (length(fin)) .rmbl_column_stats(fin) else .rmbl_prof_nastats()
  cbind(
    base,
    n_distinct = length(unique(ok)),
    nzero = sum(ok == 0),
    nneg = sum(ok < 0),
    ninf = sum(is.infinite(v)),
    mean = st$mean,
    sd = st$sd,
    median = st$median,
    mad = st$mad,
    min = if (length(fin)) min(fin) else NA_real_,
    max = if (length(fin)) max(fin) else NA_real_,
    skewness = st$skewness,
    n_outliers = if (length(fin)) {
      sum(fin < st$lower | fin > st$upper)
    } else {
      NA_integer_
    },
    hist = st$hist,
    top = NA_character_,
    stringsAsFactors = FALSE
  )
}

#' The profcols() row of a numeric column with no values.
#' @param base The row's name, type and missingness.
#' @return A one-row data frame.
#' @noRd
.rmbl_prof_empty <- function(base) {
  cbind(
    base,
    n_distinct = 0L,
    nzero = NA_integer_,
    nneg = NA_integer_,
    ninf = NA_integer_,
    mean = NA_real_,
    sd = NA_real_,
    median = NA_real_,
    mad = NA_real_,
    min = NA_real_,
    max = NA_real_,
    skewness = NA_real_,
    n_outliers = NA_integer_,
    hist = NA_character_,
    top = NA_character_,
    stringsAsFactors = FALSE
  )
}

#' The column statistics of a numeric column with no finite value.
#' @return A list shaped like .rmbl_column_stats()'s, every entry missing.
#' @noRd
.rmbl_prof_nastats <- function() {
  list(
    mean = NA_real_,
    sd = NA_real_,
    median = NA_real_,
    mad = NA_real_,
    skewness = NA_real_,
    lower = NA_real_,
    upper = NA_real_,
    hist = NA_character_
  )
}

#' The statistics of a non-numeric column, for profcols().
#' @param base The row's name, type and missingness.
#' @param v The non-numeric column summarised.
#' @return A one-row data frame.
#' @noRd
.rmbl_prof_other <- function(base, v) {
  ok <- as.character(v[!is.na(v)])
  top <- if (length(ok)) {
    names(sort(table(ok), decreasing = TRUE))[1L]
  } else {
    NA_character_
  }
  cbind(
    base,
    n_distinct = length(unique(ok)),
    nzero = NA_integer_,
    nneg = NA_integer_,
    ninf = NA_integer_,
    mean = NA_real_,
    sd = NA_real_,
    median = NA_real_,
    mad = NA_real_,
    min = NA_real_,
    max = NA_real_,
    skewness = NA_real_,
    n_outliers = NA_integer_,
    hist = NA_character_,
    top = top,
    stringsAsFactors = FALSE
  )
}

#' The quantile columns of profcols().
#' @param data The data frame profiled.
#' @param qnts The probabilities.
#' @return A matrix, one row per column of `data`.
#' @noRd
.rmbl_prof_qnts <- function(data, qnts) {
  qs <- lapply(names(data), function(nm) {
    v <- data[[nm]]
    if (is.numeric(v) && any(is.finite(v))) {
      as.numeric(.Call(
        C_rmbl_quantile,
        as.numeric(v[is.finite(v)]),
        as.numeric(qnts)
      ))
    } else {
      rep(NA_real_, length(qnts))
    }
  })
  qm <- do.call(rbind, qs)
  colnames(qm) <- paste0("q", format(100 * qnts, trim = TRUE))
  qm
}

# ---- boxed console output ----------------------------------------------------
# Every print() method prints its format() lines through .rmbl_cat(). A block
# that format() writes as a titled rule, lines, and a closing rule is drawn as
# a box: the title in the top edge, the lines inside it, wrapped to the console
# width with a hanging indent, never running past the right edge. A result
# with a verdict (a logical `ok` and a `checks` table) gets a status line
# first, and a check row's leading mark becomes a tick or a cross. Colour only
# where the console takes it (the package's console probe, .bl_console(): it
# honours NO_COLOR, knitr, sinks and the RStudio and Positron consoles);
# Unicode only where the locale takes it, else ASCII. format() itself is
# unchanged: code and tests that read the lines get the plain ones.

#' Prints format() lines, as a box when they are one titled block.
#' @param lines The lines format() returned.
#' @param x The object printed, for its verdict (`ok` and `checks`), or NULL.
#' @return NULL, invisibly.
#' @noRd
.rmbl_cat <- function(lines, x = NULL) {
  lines <- as.character(lines)
  cap <- .rmbl_print_caps()
  if (.rmbl_is_block(lines, cap)) {
    lines <- .rmbl_box(lines, .rmbl_verdict(x), cap)
  }
  cat(lines, sep = "\n")
  invisible(NULL)
}

#' What the console takes: colours, Unicode and width.
#' @return A list: `colors` (number), `unicode` (logical), `width` (integer).
#' @noRd
.rmbl_print_caps <- function() {
  # sourced on its own (a capsule bundle) the console probe is absent: plain
  cap <- if (exists(".bl_console", mode = "function")) {
    tryCatch(.bl_console(tty = FALSE), error = function(e) NULL)
  }
  width <- suppressWarnings(as.integer(cap$width %||% getOption("width", 80L)))
  list(
    colors = as.integer(cap$colors %||% 1L),
    unicode = .rmbl_unicode_ok(),
    width = if (length(width) == 1L && !is.na(width)) width else 80L
  )
}

#' Whether format() lines are one titled block: a titled rule first and a
#' plain rule last.
#' @param lines The lines.
#' @param cap The console's capabilities.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_is_block <- function(lines, cap) {
  h <- c("\u2500", "-")
  n <- length(lines)
  if (n < 2L) {
    return(FALSE)
  }
  top <- any(startsWith(lines[1L], paste0(strrep(h, 2L), " ")))
  rule <- nchar(lines[n]) > 0L &&
    any(vapply(
      h,
      function(s) identical(gsub(s, "", lines[n], fixed = TRUE), ""),
      NA
    ))
  top && rule
}

#' The verdict of a result with checks, for its status line.
#' @param x The object printed.
#' @return NULL, or a list: `ok` and `text`.
#' @noRd
.rmbl_verdict <- function(x) {
  ok <- if (is.list(x)) x[["ok"]]
  ch <- if (is.list(x)) x[["checks"]]
  if (!is.logical(ok) || length(ok) != 1L || is.na(ok)) {
    return(NULL)
  }
  n <- if (is.data.frame(ch) && is.logical(ch$ok)) nrow(ch) else NA_integer_
  bad <- if (is.na(n)) NA_integer_ else sum(!ch$ok)
  text <- if (is.na(n)) {
    ""
  } else if (ok) {
    sprintf("%d of %d checks passed", n - bad, n)
  } else {
    sprintf("%d of %d checks failed", bad, n)
  }
  list(ok = ok, text = text)
}

#' Draws a titled block as a box.
#' @param lines The block: titled rule, body lines, closing rule.
#' @param verdict NULL, or the verdict from .rmbl_verdict().
#' @param cap The console's capabilities.
#' @return The box's lines.
#' @noRd
.rmbl_box <- function(lines, verdict, cap) {
  g <- .rmbl_box_glyphs(cap$unicode)
  st <- .rmbl_box_styles(cap$colors)
  top <- "^(\u2500\u2500|--) (.*?) (\u2500|-)*$"
  title <- sub(top, "\\2", lines[1L], perl = TRUE)
  body <- lines[-c(1L, length(lines))]
  need <- max(c(.rmbl_vis_w(body), .rmbl_vis_w(title) + 4L, 30L)) + 4L
  width <- max(40L, min(need, cap$width - 1L, 100L))
  inner <- width - 4L
  # wrap the plain lines first, then mark the first line of each check row
  rows <- unlist(lapply(body, function(s) {
    w <- .rmbl_box_wrap(s, inner)
    c(.rmbl_box_mark(w[1L], g, st), w[-1L])
  }))
  if (!is.null(verdict)) {
    rows <- c(.rmbl_box_status(verdict, g, st), "", rows)
  }
  pad <- function(s) {
    paste0(g$v, " ", s, strrep(" ", max(0L, inner - .rmbl_vis_w(s))), " ", g$v)
  }
  fill <- max(1L, width - .rmbl_vis_w(title) - 6L)
  c(
    paste0(g$tl, g$h, g$h, " ", st$title(title), " ", strrep(g$h, fill), g$tr),
    vapply(rows, pad, "", USE.NAMES = FALSE),
    paste0(g$bl, strrep(g$h, width - 2L), g$br)
  )
}

#' The box's characters: rounded Unicode, or ASCII.
#' @param unicode Whether the console takes Unicode.
#' @return A named list of strings.
#' @noRd
.rmbl_box_glyphs <- function(unicode) {
  if (isTRUE(unicode)) {
    list(
      h = "\u2500",
      v = "\u2502",
      tl = "\u256d",
      tr = "\u256e",
      bl = "\u2570",
      br = "\u256f",
      ok = "\u2714",
      bad = "\u2716",
      dot = "\u00b7"
    )
  } else {
    list(
      h = "-",
      v = "|",
      tl = "+",
      tr = "+",
      bl = "+",
      br = "+",
      ok = "OK",
      bad = "X",
      dot = "-"
    )
  }
}

#' The styles for the box: bold, dim, green and red, or none.
#' @param colors The number of colours the console takes.
#' @return A named list of functions of a string.
#' @noRd
.rmbl_box_styles <- function(colors) {
  sgr <- function(on, off) {
    if (isTRUE(colors > 1L)) {
      function(s) paste0("\033[", on, "m", s, "\033[", off, "m")
    } else {
      function(s) s
    }
  }
  list(
    title = sgr("1", "22"),
    dim = sgr("2", "22"),
    good = sgr("32", "39"),
    bad = sgr("31", "39")
  )
}

#' The status line of a result with a verdict.
#' @param verdict The verdict from .rmbl_verdict().
#' @param g The box's characters.
#' @param st The styles.
#' @return One string.
#' @noRd
.rmbl_box_status <- function(verdict, g, st) {
  head <- if (verdict$ok) {
    st$good(paste(g$ok, "VERIFIED"))
  } else {
    st$bad(paste(g$bad, "NOT VERIFIED"))
  }
  if (nzchar(verdict$text)) {
    paste0(head, "  ", st$dim(paste(g$dot, verdict$text)))
  } else {
    head
  }
}

#' A body line with its leading pass/fail mark drawn as a tick or a cross.
#' @param s The line.
#' @param g The box's characters.
#' @param st The styles.
#' @return The line.
#' @noRd
.rmbl_box_mark <- function(s, g, st) {
  re <- "^( *)(ok|OK|PASS|\u2713|FAIL|X|\u2717)( +)(.*)$"
  m <- regmatches(s, regexec(re, s))[[1L]]
  if (!length(m)) {
    return(s)
  }
  good <- m[3L] %in% c("ok", "OK", "PASS", "\u2713")
  mark <- if (good) st$good(g$ok) else st$bad(g$bad)
  # keep the column the text started in, so the rows stay aligned
  gap <- max(
    1L,
    nchar(m[3L]) + nchar(m[4L]) - .rmbl_vis_w(if (good) g$ok else g$bad)
  )
  paste0(m[2L], mark, strrep(" ", gap), m[5L])
}

#' Wraps one body line to the box's inner width, with a hanging indent at the
#' column its value starts in (after a label and two spaces), or at its own
#' indent.
#' @param s The line.
#' @param inner The inner width.
#' @return One or more strings.
#' @noRd
.rmbl_box_wrap <- function(s, inner) {
  if (.rmbl_vis_w(s) <= inner) {
    return(s)
  }
  plain <- gsub("\033\\[[0-9;]*m", "", s)
  # the value column: after the last run of two or more spaces that ends in
  # the first half of the line (a label, or a mark and a check name)
  gaps <- gregexpr(" {2,}(?=[^ ])", plain, perl = TRUE)[[1L]]
  ends <- gaps + attr(gaps, "match.length")
  ends <- ends[gaps > 0L & ends - 1L < inner %/% 2L]
  ind <- if (length(ends)) {
    max(ends) - 1L
  } else {
    nchar(sub("^( *).*$", "\\1", plain))
  }
  w <- max(10L, inner - ind)
  rest <- .rmbl_hard_break(strwrap(substring(plain, ind + 1L), width = w), w)
  rest <- rest[nzchar(rest)]
  c(
    paste0(substr(plain, 1L, ind), rest[1L]),
    paste0(strrep(" ", ind), rest[-1L])
  )
}

#' Cuts any piece longer than the width (a digest, a URL: strwrap() never
#' breaks a word) into pieces of that width, so no line runs past the box.
#' @param s Wrapped pieces.
#' @param w The width.
#' @return Strings, none wider than `w`.
#' @noRd
.rmbl_hard_break <- function(s, w) {
  unlist(lapply(s, function(x) {
    n <- nchar(x)
    if (n <= w) {
      return(x)
    }
    at <- seq(1L, n, by = w)
    substring(x, at, pmin(at + w - 1L, n))
  }))
}

#' The width a string takes on screen, its colour codes left out.
#' @param s Strings.
#' @return Integers.
#' @noRd
.rmbl_vis_w <- function(s) {
  nchar(gsub("\033\\[[0-9;]*m", "", s), type = "width")
}

# ---- statistical results -----------------------------------------------------
# One layout for every estimate, test and model the package returns: a title,
# the facts a reader needs to judge it (method, n, groups, confidence level),
# an estimate table with aligned columns, intervals as [lower, upper] and
# p-values as 0.017 or < 0.001, then a plain-language reading. format()
# methods build it with .rmbl_stat_block() and print() methods show it with
# .rmbl_cat(), which draws it as a box.

#' The lines of a statistical result, as one titled block.
#' @param title The result's name, e.g. "Count trend".
#' @param facts Named list of the facts shown under the title (method, n,
#'   confidence level, ...); NULL entries are left out.
#' @param table Optional data frame of estimates, already in the units to show;
#'   numeric columns are formatted with .rmbl_fmt_num(), columns named
#'   `p`, `p_value` or ending in `_p` with .rmbl_fmt_p().
#' @param reading Optional plain-language sentences about the result.
#' @param notes Optional further lines (cautions, what was dropped).
#' @param digits Significant digits for the table's numbers.
#' @return A character vector of lines.
#' @noRd
.rmbl_stat_block <- function(
  title,
  facts = list(),
  table = NULL,
  reading = NULL,
  notes = NULL,
  digits = 4L
) {
  facts <- Filter(function(v) !is.null(v) && length(v), facts)
  out <- .rmbl_rule(title)
  if (length(facts)) {
    out <- c(out, .rmbl_kv(lapply(facts, .rmbl_fact)))
  }
  if (is.data.frame(table) && nrow(table)) {
    out <- c(out, "", .rmbl_stat_table(table, digits))
  }
  if (length(reading)) {
    out <- c(out, "", paste0("  ", reading))
  }
  if (length(notes)) {
    out <- c(out, "", paste0("  ", notes))
  }
  c(out, .rmbl_rule())
}

#' One fact for the block's key-value list, as text.
#' @param v The value.
#' @return One string.
#' @noRd
.rmbl_fact <- function(v) {
  if (is.numeric(v)) {
    return(toString(.rmbl_fmt_num(v)))
  }
  toString(as.character(v))
}

#' An estimate table as aligned text lines with a rule under the header.
#' @param df The table.
#' @param digits Significant digits.
#' @return A character vector of lines, indented two spaces.
#' @noRd
.rmbl_stat_table <- function(df, digits = 4L) {
  cols <- lapply(names(df), function(nm) {
    v <- df[[nm]]
    if (.rmbl_is_p_col(nm) && is.numeric(v)) {
      .rmbl_fmt_p(v)
    } else if (.rmbl_is_period_col(nm) && is.numeric(v)) {
      ifelse(is.na(v), "", format(v, scientific = FALSE, trim = TRUE))
    } else if (is.numeric(v)) {
      .rmbl_fmt_col(v, digits)
    } else {
      ifelse(is.na(v), "", as.character(v))
    }
  })
  names(cols) <- names(df)
  num <- vapply(df, is.numeric, NA)
  w <- pmax(
    nchar(names(cols), type = "width"),
    vapply(
      cols,
      function(v) {
        max(c(0L, nchar(v, type = "width")))
      },
      1L
    )
  )
  cell <- function(s, i) {
    formatC(s, width = w[[i]], flag = if (num[[i]]) " " else "-")
  }
  head <- paste(
    vapply(seq_along(cols), function(i) cell(names(cols)[i], i), ""),
    collapse = "  "
  )
  rule <- paste(vapply(w, function(k) strrep("-", k), ""), collapse = "  ")
  rows <- vapply(
    seq_len(nrow(df)),
    function(r) {
      paste(
        vapply(seq_along(cols), function(i) cell(cols[[i]][r], i), ""),
        collapse = "  "
      )
    },
    ""
  )
  paste0("  ", c(head, rule, rows))
}

#' Whether a column name holds p-values.
#' @param nm The name.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_is_p_col <- function(nm) {
  # p, p_value, p.value, pholm, padj, p_adj, pbh, pfdr, q, qvalue, adj_p, ...
  grepl(
    "^(p|q)([._]?(value|holm|adj|bh|by|bonf|fdr|perm|exact))?$|_p$",
    tolower(nm)
  )
}

#' Whether a column name holds periods (years, fiscal years, months, waves):
#' printed as they are, never as 2,021.
#' @param nm The name.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_is_period_col <- function(nm) {
  grepl(
    "(^|_)(year|yr|fy|period|prd|month|quarter|wave|cycle|edition)(s)?($|_)",
    tolower(nm)
  )
}

#' p-values as read in a paper: 0.017, 0.0004 shown as < 0.001, NA as blank.
#' @param p Numbers in [0, 1].
#' @return Strings.
#' @noRd
.rmbl_fmt_p <- function(p) {
  out <- ifelse(
    p < 0.001,
    "< 0.001",
    formatC(p, format = "f", digits = 3L)
  )
  out[is.na(p)] <- ""
  out
}

#' Numbers with a fixed count of significant digits (whole numbers in full,
#' with thousands separators), no scientific notation unless very large or
#' very small, NA as blank.
#' @param x Numbers.
#' @param digits Significant digits.
#' @return Strings.
#' @noRd
.rmbl_fmt_num <- function(x, digits = 4L) {
  out <- vapply(
    x,
    function(v) {
      if (is.na(v)) {
        return("")
      }
      if (is.infinite(v)) {
        return(if (v > 0) "Inf" else "-Inf")
      }
      if (v != 0 && (abs(v) >= 1e7 || abs(v) < 1e-4)) {
        return(formatC(v, format = "e", digits = digits - 1L))
      }
      if (v == round(v)) {
        return(formatC(v, format = "d", big.mark = ","))
      }
      formatC(signif(v, digits), format = "fg", digits = digits)
    },
    ""
  )
  trimws(out)
}

#' A table column of numbers with one count of decimals, so the column reads
#' 0.979 above 1.038, not 0.9788 above 1.038: as many decimals as give its
#' typical (median) value `digits` significant digits (at most 6). Whole
#' numbers, and columns that are very large or very small, keep
#' .rmbl_fmt_num()'s form.
#' @param v The column's numbers.
#' @param digits Significant digits of the typical value.
#' @return Strings, NA blank.
#' @noRd
.rmbl_fmt_col <- function(v, digits = 4L) {
  ok <- is.finite(v)
  a <- abs(v[ok])
  if (!any(a > 0) || all(v[ok] == round(v[ok])) || max(a) >= 1e7 ||
    max(a) < 1e-4) {
    return(.rmbl_fmt_num(v, digits))
  }
  typ <- stats::median(a[a > 0])
  dp <- as.integer(min(6, max(0, digits - 1 - floor(log10(typ)))))
  out <- formatC(v, format = "f", digits = dp, big.mark = ",")
  out[is.na(v)] <- ""
  out[is.infinite(v)] <- ifelse(v[is.infinite(v)] > 0, "Inf", "-Inf")
  out
}

#' An interval as [lower, upper].
#' @param lo,hi The bounds.
#' @param digits Significant digits.
#' @return Strings.
#' @noRd
.rmbl_fmt_ci <- function(lo, hi, digits = 4L) {
  n <- length(lo)
  if (n > 1L && length(hi) == n) {
    # a column of intervals: every bound with the same decimals
    both <- .rmbl_fmt_col(c(lo, hi), digits)
    return(sprintf("[%s, %s]", both[seq_len(n)], both[n + seq_len(n)]))
  }
  a <- .rmbl_fmt_num(lo, digits)
  b <- .rmbl_fmt_num(hi, digits)
  sprintf("[%s, %s]", .rmbl_same_dp(a, b), .rmbl_same_dp(b, a))
}

#' Pads a plain decimal with zeros to the decimals of its partner, so an
#' interval reads [47.0, 56.2], not [47, 56.2]; numbers in e-notation, blank
#' and Inf are left as they are.
#' @param s,other Formatted numbers, element by element.
#' @return Strings.
#' @noRd
.rmbl_same_dp <- function(s, other) {
  dp <- function(v) {
    ifelse(grepl(".", v, fixed = TRUE), nchar(sub("^[^.]*[.]", "", v)), 0L)
  }
  plain <- grepl("^-?[0-9,]+([.][0-9]+)?$", s) &
    grepl("^-?[0-9,]+([.][0-9]+)?$", other)
  add <- ifelse(plain, pmax(0L, dp(other) - dp(s)), 0L)
  pad <- add > 0L
  s[pad] <- paste0(
    s[pad],
    ifelse(dp(s[pad]) == 0L, ".", ""),
    strrep("0", add[pad])
  )
  s
}

# ---- result blocks -----------------------------------------------------------
# The format() methods of the analysis results build their block with
# .rmbl_res_block(): .rmbl_stat_block()'s facts, reading and notes, with any
# number of tables, each split into column chunks that fit an 80-column box
# (the first column repeated) and cut to its first rows.

#' The lines of a result: one titled block with facts, tables that fit the
#' box, a reading and notes.
#' @param title The result's name.
#' @param facts Named list of facts; NULL entries are left out.
#' @param tables A data frame, or a list of them (a name is shown above its
#'   table).
#' @param reading Optional plain-language sentences, wrapped.
#' @param notes Optional further lines, each wrapped.
#' @param digits Significant digits for the tables' numbers.
#' @param maxrows The most rows shown of each table.
#' @return A character vector of lines.
#' @noRd
.rmbl_res_block <- function(
  title,
  facts = list(),
  tables = list(),
  reading = NULL,
  notes = NULL,
  digits = 4L,
  maxrows = 20L
) {
  if (is.data.frame(tables)) {
    tables <- list(tables)
  }
  tables <- Filter(Negate(is.null), tables)
  b <- .rmbl_stat_block(
    title,
    facts,
    NULL,
    .rmbl_wrap(reading),
    unlist(lapply(notes, .rmbl_wrap)),
    digits
  )
  nf <- sum(vapply(facts, function(v) !is.null(v) && length(v) > 0L, NA))
  tl <- unlist(lapply(seq_along(tables), function(i) {
    .rmbl_res_table(tables[[i]], names(tables)[i], digits, maxrows)
  }))
  k <- seq_len(1L + nf)
  c(b[k], tl, b[-k])
}

#' One table of a result block: a caption, the table in column chunks that fit
#' the box, and how many rows were left out.
#' @param df The table (a plain data frame).
#' @param caption The line above it, or NULL.
#' @param digits Significant digits.
#' @param maxrows The most rows shown.
#' @return A character vector of lines, the first one blank.
#' @noRd
.rmbl_res_table <- function(df, caption = NULL, digits = 4L, maxrows = 20L) {
  out <- ""
  if (length(caption) && !is.na(caption) && nzchar(caption)) {
    out <- c(out, paste0("  ", caption))
  }
  if (!is.data.frame(df) || !nrow(df) || !ncol(df)) {
    return(c(out, "  (no rows)"))
  }
  more <- nrow(df) - maxrows
  if (more > 0L) {
    df <- df[seq_len(maxrows), , drop = FALSE]
  }
  chunks <- .rmbl_res_chunks(df, digits)
  body <- unlist(lapply(seq_along(chunks), function(i) {
    c(if (i > 1L) "", .rmbl_stat_table(df[chunks[[i]]], digits))
  }))
  c(
    out,
    body,
    if (more > 0L) sprintf("  ... %s more rows", format(more, big.mark = ","))
  )
}

#' Splits a table's columns into chunks no wider than the box, the first
#' column at the head of each.
#' @param df The table.
#' @param digits Significant digits.
#' @param width The widest a chunk may be, in characters.
#' @return A list of column indices.
#' @noRd
.rmbl_res_chunks <- function(df, digits, width = 72L) {
  w <- vapply(
    seq_along(df),
    function(j) {
      max(nchar(.rmbl_stat_table(df[j], digits), type = "width")) - 2
    },
    1
  )
  if (length(w) < 2L || sum(w) + 2L * (length(w) - 1L) <= width) {
    return(list(seq_along(df)))
  }
  chunks <- list()
  cur <- 1L
  used <- w[1L]
  for (j in seq_along(w)[-1L]) {
    if (used + 2L + w[j] > width && length(cur) > 1L) {
      chunks[[length(chunks) + 1L]] <- cur
      cur <- 1L
      used <- w[1L]
    }
    cur <- c(cur, j)
    used <- used + 2L + w[j]
  }
  c(chunks, list(cur))
}

#' Text wrapped for a block: the sentences joined and wrapped to 70 columns.
#' @param txt Character vector, or NULL.
#' @return A character vector, or NULL.
#' @noRd
.rmbl_wrap <- function(txt) {
  txt <- txt[!is.na(txt) & nzchar(txt)]
  if (!length(txt)) {
    return(NULL)
  }
  strwrap(paste(txt, collapse = " "), width = 70L)
}

#' A classed data frame as a plain one: its columns, no other attributes.
#' @param x The data frame.
#' @param cols Optional columns to keep (those present, in this order).
#' @return A data frame.
#' @noRd
.rmbl_plain <- function(x, cols = NULL) {
  nm <- names(x)
  if (length(cols)) {
    nm <- intersect(cols, nm)
  }
  d <- lapply(nm, function(k) .subset2(x, k))
  n <- if (length(d)) length(d[[1L]]) else 0L
  structure(
    stats::setNames(d, nm),
    row.names = seq_len(n),
    class = "data.frame"
  )
}

#' The block of a classed data frame whose columns were subset away: the
#' table as it is, under the result's title.
#' @param x The data frame.
#' @param title The result's title.
#' @param cols The columns the result's own layout needs.
#' @param digits Significant digits.
#' @return NULL when every column is there, else the block's lines.
#' @noRd
.rmbl_df_fallback <- function(x, title, cols, digits = 4L) {
  if (all(cols %in% names(x))) {
    return(NULL)
  }
  .rmbl_res_block(
    title,
    facts = list(Rows = nrow(x), Columns = ncol(x)),
    tables = .rmbl_plain(x),
    notes = paste(
      "Some of this result's columns are not here (a subset of it?), so",
      "it is shown as a plain table."
    ),
    digits = digits
  )
}

#' A confidence level as text, "95%"; NULL when there is none.
#' @param v The level, in (0, 1).
#' @return A string or NULL.
#' @noRd
.rmbl_lvl <- function(v) {
  if (!is.numeric(v) || length(v) != 1L || is.na(v)) {
    return(NULL)
  }
  paste0(format(100 * v), "%")
}

#' The name of an interval column: "95% CI", or "Interval" with no level.
#' @param v The level, or NULL.
#' @return A string.
#' @noRd
.rmbl_ci_name <- function(v) {
  l <- .rmbl_lvl(v)
  if (is.null(l)) "interval" else paste(l, "CI")
}

#' A plain-language sentence about an estimate and its interval.
#' @param lead The start of the sentence, naming the estimate.
#' @param est,lo,hi The estimate and its interval.
#' @param lvl The confidence level, or NULL.
#' @param null The value of no effect (0, or 1 for a ratio).
#' @return One string, or NULL when the estimate is missing.
#' @noRd
.rmbl_est_reading <- function(lead, est, lo, hi, lvl = NULL, null = 0) {
  if (!length(est) || !is.finite(est[1L])) {
    return(NULL)
  }
  lo <- lo[1L]
  hi <- hi[1L]
  known <- length(lo) && length(hi) && !is.na(lo) && !is.na(hi)
  l <- .rmbl_lvl(lvl)
  iv <- if (known) {
    sprintf(" (%s interval %s)", l %||% "its", .rmbl_fmt_ci(lo, hi))
  } else {
    ""
  }
  verdict <- if (!known) {
    "it has no interval to judge it by."
  } else if (lo <= null && hi >= null) {
    sprintf(
      "the interval includes %s, so the data cannot rule out no effect.",
      format(null)
    )
  } else {
    sprintf(
      "the interval excludes %s, so the data distinguish it from no effect.",
      format(null)
    )
  }
  paste0(lead, " ", .rmbl_fmt_num(est[1L]), iv, ": ", verdict)
}

#' A table's flag column as short codes, with the flags spelled out as notes.
#' @param df The table.
#' @param col The flag column's name.
#' @return A list: `df` (the codes in place of the flags) and `notes`.
#' @noRd
.rmbl_flag_codes <- function(df, col = "flag") {
  if (!col %in% names(df)) {
    return(list(df = df, notes = NULL))
  }
  f <- as.character(df[[col]])
  u <- unique(f[!is.na(f) & nzchar(f)])
  if (!length(u)) {
    df[[col]] <- NULL
    return(list(df = df, notes = NULL))
  }
  code <- paste0("[", seq_along(u), "]")
  df[[col]] <- ifelse(is.na(f) | !nzchar(f), "", code[match(f, u)])
  list(df = df, notes = paste(code, u))
}

#' A table's lower and upper columns as one interval column, "[a, b]".
#' @param df The table.
#' @param lvl The confidence level, or NULL, for the column's name.
#' @param lo,hi The names of the bound columns.
#' @return The table, the interval where the lower bound was.
#' @noRd
.rmbl_ci_cols <- function(df, lvl = NULL, lo = "lower", hi = "upper") {
  if (!all(c(lo, hi) %in% names(df))) {
    return(df)
  }
  i <- match(lo, names(df))
  a <- df[[lo]]
  b <- df[[hi]]
  df[[lo]] <- ifelse(is.na(a) & is.na(b), "", .rmbl_fmt_ci(a, b))
  names(df)[i] <- .rmbl_ci_name(lvl)
  df[[hi]] <- NULL
  df
}

#' A p-value in a sentence: "= 0.017" or "< 0.001".
#' @param p The p-value.
#' @return One string.
#' @noRd
.rmbl_p_txt <- function(p) {
  if (!length(p) || is.na(p[1L])) {
    return("not available")
  }
  if (p[1L] < 0.001) "< 0.001" else paste("=", .rmbl_fmt_p(p[1L]))
}

#' A plain-language sentence about a rate ratio and its interval.
#' @param lead The start of the sentence, naming the ratio.
#' @param rr,lo,hi The ratio and its interval.
#' @param lvl The confidence level, or NULL.
#' @return One or two sentences, or NULL when the ratio is missing.
#' @noRd
.rmbl_rr_reading <- function(lead, rr, lo, hi, lvl = NULL) {
  if (!length(rr) || !is.finite(rr[1L])) {
    return(NULL)
  }
  pct <- 100 * (rr[1L] - 1)
  paste(
    .rmbl_est_reading(lead, rr, lo, hi, lvl, null = 1),
    sprintf(
      "A ratio of %s is a %s%% %s.",
      .rmbl_fmt_num(rr[1L]),
      .rmbl_fmt_num(abs(pct), 3L),
      if (pct >= 0) "rise" else "fall"
    )
  )
}

#' Counts of a column's values as "a 3, b 2".
#' @param v The values.
#' @return One string.
#' @noRd
.rmbl_tally <- function(v) {
  t <- table(v, useNA = "no")
  toString(paste(names(t), as.integer(t)))
}

#' The reading of a Benford screen, a blank line first: whether the digits
#' depart from the law at the screen's 0.01, and where the largest gap is.
#' @param x The benfordtst() result.
#' @param prop,expected The observed and expected share of each digit.
#' @return A character vector of lines.
#' @noRd
.rmbl_benford_reading <- function(x, prop, expected) {
  gap <- prop - expected
  k <- which.max(abs(gap))
  at <- sprintf(
    "at %s, %.1f%% seen against %.1f%% expected",
    names(prop)[k],
    100 * prop[k],
    100 * expected[k]
  )
  first <- if (!length(k) || is.na(x$p_value)) {
    "Too few values for the chi-square to say anything."
  } else {
    sprintf(
      "The leading digits %s Benford's law (p %s); the largest gap is %s.",
      if (x$p_value < 0.01) "depart from" else "are consistent with",
      .rmbl_p_txt(x$p_value),
      at
    )
  }
  c(
    "",
    paste0(
      "  ",
      .rmbl_wrap(c(
        first,
        "Benford's law expects a leading 1 about 30% of the time and a 9",
        "under 5%. A departure is a reason to look closer (rounding,",
        "thresholds, made-up figures), never proof by itself."
      ))
    )
  )
}

#' A result with a class put in front of the classes it has.
#' @param x The value returned to the user.
#' @param cls The class to prepend.
#' @return `x`, its values unchanged.
#' @noRd
.rmbl_cls <- function(x, cls) {
  class(x) <- c(cls, class(x))
  x
}

#' A p-value as one fact of a block: 0.017, < 0.001, or "not available".
#' @param p A p-value, or NULL.
#' @return One string.
#' @noRd
.rmbl_p_fact <- function(p) {
  if (!length(p) || is.na(p[1L])) {
    return("not available")
  }
  .rmbl_fmt_p(p[1L])
}
