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

#' TRUE when the connection can be trusted with non-ASCII box characters.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_unicode_ok <- function() {
  if (!identical(Sys.getenv("RMBL_ASCII_ONLY"), "")) return(FALSE)
  l10n <- l10n_info()
  isTRUE(l10n[["UTF-8"]])
}

#' Returns the box-drawing and status glyphs for the console, Unicode or ASCII.
#' @return A named list of strings.
#' @noRd
.rmbl_glyphs <- function() {
  if (.rmbl_unicode_ok()) {
    list(h = "\u2500", tl = "\u250c", tr = "\u2510", bl = "\u2514",
         br = "\u2518", v = "\u2502", ok = "\u2713", bad = "\u2717",
         warn = "!", dash = "\u2013")
  } else {
    list(h = "-", tl = "+", tr = "+", bl = "+", br = "+", v = "|",
         ok = "OK", bad = "X", warn = "!", dash = "-")
  }
}

#' A titled rule, e.g. \dQuote{-- Drift report ----------------}.
#' @param title The title, or NULL for a plain rule.
#' @param width The rule's width in characters.
#' @return One string.
#' @noRd
.rmbl_rule <- function(title = NULL, width = 66L) {
  g <- .rmbl_glyphs()
  if (is.null(title)) return(strrep(g$h, width))
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
  paste0(strrep(" ", indent), formatC(keys, width = w, flag = "-"), "  ",
         vapply(pairs, function(v) paste(format(v), collapse = ", "),
                character(1)))
}

#' Prints a classed data frame inside the package's titled frame.
#'
#' One frame for every statistic that returns a classed data frame: a
#' titled rule, optional lines that qualify the table, the table without
#' row names, optional lines that follow it, a closing rule. The stock and
#' flow, rate, share, coverage and band printers all go through here, so
#' their caveats -- which are the argument each of them makes -- are laid
#' out the same way instead of rewritten per method.
#' @param title The title on the opening rule.
#' @param df The table to print.
#' @param notes Lines printed above the table, or NULL.
#' @param footer Lines printed below the table, or NULL.
#' @param ... Passed to `print.data.frame()`.
#' @return NULL, invisibly.
#' @noRd
.rmbl_print_table <- function(title, df, notes = NULL, footer = NULL, ...) {
  cat(.rmbl_rule(title), "\n")
  if (length(notes)) {
    cat(paste0("  ", notes), sep = "\n")
    cat("\n")
  }
  df <- as.data.frame(df, stringsAsFactors = FALSE)
  class(df) <- "data.frame"
  print.data.frame(df, row.names = FALSE, ...)
  if (length(footer)) {
    cat("\n")
    cat(paste0("  ", footer), sep = "\n")
  }
  cat(.rmbl_rule(), "\n")
  invisible(NULL)
}

#' Formats p-values for printing, \dQuote{<2e-16} for the smallest.
#' @param p A numeric vector of p-values.
#' @return A character vector.
#' @noRd
.rmbl_fmt_p <- function(p) {
  ifelse(is.na(p), "NA",
         ifelse(p < 2e-16, "<2e-16", formatC(p, format = "g", digits = 3)))
}

#' Prints a subset table as a plain data frame when the print method's columns are missing.
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
  if (all(cols %in% names(x))) return(FALSE)
  df <- x
  class(df) <- "data.frame"
  for (a in setdiff(names(attributes(df)),
                    c("names", "row.names", "class"))) {
    attr(df, a) <- NULL
  }
  print(df)
  TRUE
}

#' @export
format.bricklayer_drift <- function(x, ...) {
  g <- .rmbl_glyphs()
  verdict <- if (isTRUE(x$anydrft)) {
    paste0(g$bad, " DRIFT DETECTED")
  } else {
    paste0(g$ok, " no drift detected")
  }
  out <- c(
    .rmbl_rule("Capsule drift report"),
    paste0("  ", verdict),
    "",
    .rmbl_kv(list(
      "reference rows" = format(x$nref, big.mark = ","),
      "current rows" = format(x$ncur, big.mark = ","),
      "columns tested" = nrow(x$columns),
      "alpha" = x$alpha))
  )
  if (length(x$added)) {
    out <- c(out, paste0("  ", g$warn, " columns added:   ",
                         paste(x$added, collapse = ", ")))
  }
  if (length(x$removed)) {
    out <- c(out, paste0("  ", g$warn, " columns removed: ",
                         paste(x$removed, collapse = ", ")))
  }
  if (nrow(x$columns)) {
    cols <- x$columns
    flag <- ifelse(is.na(cols$drifted), "?",
                   ifelse(cols$drifted, g$bad, g$ok))
    tbl <- data.frame(
      ` ` = flag,
      column = cols$column,
      type = cols$type,
      stat = formatC(cols$statistic, format = "g", digits = 3),
      p = .rmbl_fmt_p(cols$p_value),
      psi = ifelse(is.na(cols$psi), g$dash,
                   formatC(cols$psi, format = "f", digits = 3)),
      check.names = FALSE, stringsAsFactors = FALSE
    )
    # Drifted columns first: the reader is looking for the problem.
    ord <- order(!isTRUE(cols$drifted) & !is.na(cols$drifted),
                 -xtfrm(ifelse(is.na(cols$drifted), FALSE, cols$drifted)),
                 cols$p_value)
    out <- c(out, "", .rmbl_rule("Per-column tests"),
             paste0("  ", utils::capture.output(
               print(tbl[ord, , drop = FALSE], row.names = FALSE))))
  }
  c(out, "", "  plot(x, what = \"columns\") draws the columns; drfthtml(x, file) writes an interactive report",
    .rmbl_rule())
}

#' Printed reports for bricklayer objects
#'
#' Human-readable renderings of the objects the package returns. Each leads
#' with the verdict, then the evidence. `format()` returns the lines
#' as a character vector so they can be logged or written to a file;
#' `print()` sends them to the console and returns its argument
#' invisibly.
#'
#' Box-drawing characters are used only when the session's encoding can
#' render them; otherwise the same layout is drawn in plain ASCII. Set the
#' environment variable `RMBL_ASCII_ONLY` to force the ASCII form,
#' which is what to do when capturing output into a fixed-width log.
#'
#' @param x The object to render.
#' @param ... Ignored, present for S3 consistency.
#' @return `format()` methods return a character vector;
#' `print()` methods return `x` invisibly.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' op <- options(rmoriebricklayer.xmssidxfile = tempfile())  # keep this example's
#' # one-time index record out of your configuration directory; leave the default in use
#' set.seed(7)
#' ref <- data.frame(v = stats::rnorm(200),
#'                   g = sample(c("a", "b"), 200, TRUE))
#' cur <- data.frame(v = stats::rnorm(200, mean = 1),
#'                   g = sample(c("a", "b"), 200, TRUE))
#'
#' # The drift report leads with its verdict.
#' cpsdrft(ref, cur)
#'
#' # format() gives the same lines for a log file.
#' head(format(cpsdrft(ref, cur)), 3)
#'
#' # A Benford screen.
#' benfordtst(10^stats::runif(500, 0, 5))
#'
#' # Keys and signatures print without ever showing the secret seed.
#' key <- pqckg(height = 2)
#' key
#' cpssign("a-manifest", key)
#' options(op)
#' @name printmeth
#' @export
#' @method print bricklayer_drift
print.bricklayer_drift <- .rmbl_print_via_format

#' @rdname printmeth
#' @export
summary.bricklayer_drift <- function(object, ...) {
  cols <- object$columns
  drifted <- if (nrow(cols)) cols$column[which(isTRUE(cols$drifted) |
                                                 cols$drifted)] else
    character(0)
  out <- list(anydrft = object$anydrft,
              ntes = nrow(cols),
              ndri = length(drifted),
              drifted = drifted,
              added = object$added,
              removed = object$removed)
  class(out) <- c("bricklayer_drift_summary", "list")
  out
}

#' @export
print.bricklayer_drift_summary <- function(x, ...) {
  g <- .rmbl_glyphs()
  cat(if (isTRUE(x$anydrft)) paste0(g$bad, " drift detected") else
        paste0(g$ok, " no drift detected"), "\n")
  cat(sprintf("  %d of %d columns drifted\n", x$ndri, x$ntes))
  if (length(x$drifted)) {
    cat("  drifted: ", paste(x$drifted, collapse = ", "), "\n", sep = "")
  }
  if (length(x$added)) {
    cat("  added:   ", paste(x$added, collapse = ", "), "\n", sep = "")
  }
  if (length(x$removed)) {
    cat("  removed: ", paste(x$removed, collapse = ", "), "\n", sep = "")
  }
  invisible(x)
}

#' @export
format.bricklayer_benford <- function(x, ...) {
  g <- .rmbl_glyphs()
  prop <- x$proportion
  expected <- x$expected / x$n
  # A 20-cell bar makes the shape of the deviation legible at a glance,
  # which a column of numbers does not.
  bar <- vapply(prop, function(p) {
    n <- max(0L, min(20L, as.integer(round(p * 20 / max(prop)))))
    paste0(strrep("#", n), strrep(" ", 20L - n))
  }, character(1))
  verdict <- if (is.na(x$p_value)) "?" else if (x$p_value < 0.01) {
    paste0(g$warn, " departs from Benford's law (screen only, not a verdict)")
  } else {
    paste0(g$ok, " consistent with Benford's law")
  }
  c(.rmbl_rule("Benford first-digit screen"),
    paste0("  ", verdict),
    "",
    .rmbl_kv(list("values used" = format(x$n, big.mark = ","),
                  "chi-square" = formatC(x$statistic, format = "f",
                                         digits = 3),
                  "df" = x$df,
                  "p-value" = .rmbl_fmt_p(x$p_value))),
    "",
    paste0("  digit  observed  expected  ", strrep(" ", 6), "shape"),
    sprintf("  %5s  %8s  %8s  %s", names(prop),
            formatC(prop, format = "f", digits = 3),
            formatC(expected, format = "f", digits = 3), bar),
    .rmbl_rule())
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_benford
print.bricklayer_benford <- .rmbl_print_via_format

#' @export
format.bricklayer_signing_key <- function(x, ...) {
  c(.rmbl_rule("Signing key (post-quantum)"),
    .rmbl_kv(list(
      scheme = x$scheme,
      root = x$root,
      height = x$height,
      used = sprintf("%d of %d signatures", x$next_index, x$capacity),
      remaining = x$capacity - x$next_index,
      secret = "<withheld>")),
    paste0("  ", .rmbl_glyphs()$warn,
           " one signature per index; never sign twice at one index"),
    .rmbl_rule())
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_signing_key
print.bricklayer_signing_key <- .rmbl_print_via_format

#' @export
format.bricklayer_public_key <- function(x, ...) {
  c(.rmbl_rule("Public verification key"),
    .rmbl_kv(list(scheme = x$scheme, root = x$root, height = x$height)),
    .rmbl_rule())
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_public_key
print.bricklayer_public_key <- .rmbl_print_via_format

#' @export
format.bricklayer_signature <- function(x, ...) {
  pairs <- list(scheme = x$scheme)
  if (!is.null(x$key_state)) {
    pairs$WARNING <- "carries the signer's private key (key_state, 0.5.9 to 7703a04): the key is compromised"
  }
  if (identical(x$scheme, "hmac")) {
    pairs$tag <- x$signature
  } else if (is.null(x$auth)) {
    # a standardised scheme: no authentication path and no leaf index
    pairs$signature <- sprintf("%s... (%d bytes)",
                               substring(x$signature, 1L, 32L),
                               nchar(x$signature) %/% 2L)
    pairs$state <- "stateless"
  } else {
    pairs$index <- x$index
    pairs$root <- x$root
    pairs$signature <- sprintf("%s... (%d bytes)",
                               substring(x$signature, 1L, 32L),
                               nchar(x$signature) %/% 2L)
    pairs$`auth path` <- sprintf("%d nodes", nchar(x$auth) %/% 64L)
  }
  c(.rmbl_rule("Capsule signature"), .rmbl_kv(pairs), .rmbl_rule())
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_signature
print.bricklayer_signature <- .rmbl_print_via_format

#' @param object The object to summarise.
#' @rdname printmeth
#' @export
summary.bricklayer_benford <- function(object, ...) {
  c(n = object$n, statistic = object$statistic, df = object$df,
    p_value = object$p_value)
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
#' over its non-missing values: `sd` is the sample standard deviation
#' (\eqn{n - 1}), `mad` the median absolute deviation scaled by 1.4826,
#' `skewness` the population moment ratio \eqn{m_3 / m_2^{3/2}},
#' `n_outliers` the count outside the Tukey fences (1.5 interquartile ranges
#' beyond the quartiles), and the quantiles are type 7. Infinite values are
#' counted in `ninf` (and in `nneg`, `n_distinct`) and left
#' out
#' of every other numeric statistic, which are taken over the finite values
#' only: a column with an infinite value keeps a finite mean and range, and
#' a column with no finite value has `NA` statistics. A progress bar is shown for
#' wide tables when
#' `options(morie.progress)` allows it. Errors when `data` is not a data
#' frame, has no columns, or has duplicate or empty column names.
#'
#' @param data A data frame.
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
#' @srrstats {EA5.2} print.bricklayer_profile formats numbers with formatC(digits = 4); other print methods use
#'   formatC or sprintf too; test-print-methods.R.
#' @srrstats {EA5.3} The column profile has a `type` column (the first class of each column); test-print-methods.R:137.
profcols <- function(data, qnts = c(0.25, 0.5, 0.75)) {
  if (!is.data.frame(data)) stop("profcols: `data` must be a data frame", call. = FALSE)
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
    v <- data[[nm]]
    n_missing <- sum(is.na(v))
    base <- data.frame(column = nm, type = class(v)[1L], n = length(v),
                       n_missing = n_missing,
                       pct_missing = 100 * n_missing / max(1L, length(v)),
                       stringsAsFactors = FALSE)
    if (is.numeric(v)) {
      ok <- v[!is.na(v)]
      if (length(ok) == 0L) {
        return(cbind(base, n_distinct = 0L, nzero = NA_integer_,
                     nneg = NA_integer_, ninf = NA_integer_,
                     mean = NA_real_, sd = NA_real_,
                     median = NA_real_, mad = NA_real_, min = NA_real_,
                     max = NA_real_, skewness = NA_real_,
                     n_outliers = NA_integer_, hist = NA_character_,
                     top = NA_character_, stringsAsFactors = FALSE))
      }
      # the statistics are over the finite values: an Inf counted in
      # ninf made the mean and the range infinite as well
      fin <- ok[is.finite(ok)]
      st <- if (length(fin)) .rmbl_column_stats(fin) else
        list(mean = NA_real_, sd = NA_real_, median = NA_real_, mad = NA_real_,
             skewness = NA_real_, lower = NA_real_, upper = NA_real_, hist = NA_character_)
      cbind(base, n_distinct = length(unique(ok)),
            nzero = sum(ok == 0), nneg = sum(ok < 0),
            ninf = sum(is.infinite(v)),
            mean = st$mean, sd = st$sd,
            median = st$median, mad = st$mad,
            min = if (length(fin)) min(fin) else NA_real_,
            max = if (length(fin)) max(fin) else NA_real_, skewness = st$skewness,
            n_outliers = if (length(fin)) sum(fin < st$lower | fin > st$upper) else NA_integer_,
            hist = st$hist, top = NA_character_,
            stringsAsFactors = FALSE)
    } else {
      ok <- as.character(v[!is.na(v)])
      top <- if (length(ok)) names(sort(table(ok), decreasing = TRUE))[1L] else
        NA_character_
      cbind(base, n_distinct = length(unique(ok)), nzero = NA_integer_,
            nneg = NA_integer_, ninf = NA_integer_,
            mean = NA_real_, sd = NA_real_, median = NA_real_,
            mad = NA_real_, min = NA_real_, max = NA_real_,
            skewness = NA_real_, n_outliers = NA_integer_,
            hist = NA_character_, top = top, stringsAsFactors = FALSE)
    }
  })
  out <- do.call(rbind, rows)
  if (length(qnts)) {
    qs <- lapply(names(data), function(nm) {
      v <- data[[nm]]
      if (is.numeric(v) && any(is.finite(v))) {
        as.numeric(.Call(C_rmbl_quantile, as.numeric(v[is.finite(v)]),
                         as.numeric(qnts)))
      } else {
        rep(NA_real_, length(qnts))
      }
    })
    qm <- do.call(rbind, qs)
    colnames(qm) <- paste0("q", format(100 * qnts, trim = TRUE))
    out <- cbind(out, qm)
  }
  rownames(out) <- NULL
  class(out) <- c("bricklayer_profile", "data.frame")
  out
}

#' @export
print.bricklayer_profile <- function(x, ...) {
  if (.rmbl_needs_cols(x, c("column", "type"))) return(invisible(x))
  cat(.rmbl_rule("Column profile"), "\n")
  df <- as.data.frame(unclass(x), stringsAsFactors = FALSE)
  num <- vapply(df, is.numeric, logical(1))
  df[num] <- lapply(df[num], function(v) {
    ifelse(is.na(v), NA_character_, formatC(v, format = "g", digits = 4))
  })
  df[is.na(df)] <- .rmbl_glyphs()$dash
  # the histogram is a drawing, not a value: keep it last and unpadded
  if ("hist" %in% names(df)) {
    df <- df[, c(setdiff(names(df), "hist"), "hist"), drop = FALSE]
  }
  print(df, row.names = FALSE)
  cat(.rmbl_rule(), "\n")
  invisible(x)
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
.rmbl_column_stats <- function(ok,
                               native = exists("cmom",
                                               mode = "function")) {
  # bundle-scan-guarded: ctkyfnc cmed cmad
  if (native) {
    m <- cmom(ok)
    f <- ctkyfnc(ok)
    return(list(mean = m[["mean"]], sd = sqrt(m[["variance"]]),
                skewness = m[["skewness"]], median = cmed(ok),
                mad = cmad(ok), lower = f[["lower"]],
                upper = f[["upper"]],
                hist = if (exists(".rmbl_sparkline", mode = "function"))
                  .rmbl_sparkline(ok) else NA_character_))
  }
  n <- length(ok)
  mu <- mean(ok)
  d <- ok - mu
  m2 <- mean(d^2)
  sk <- if (n > 2 && m2 > 0) mean(d^3) / m2^1.5 else NaN
  q <- stats::quantile(ok, c(0.25, 0.75), names = FALSE, type = 7)
  iqr <- q[2L] - q[1L]
  list(mean = mu, sd = if (n > 1) stats::sd(ok) else NaN, skewness = sk,
       median = stats::median(ok), mad = stats::mad(ok),
       lower = q[1L] - 1.5 * iqr, upper = q[2L] + 1.5 * iqr,
       hist = NA_character_)
}
