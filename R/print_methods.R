# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Output surface. A provenance tool is read by a person deciding whether
# to trust a result, so what it prints matters as much as what it
# computes: the verdict comes first, the numbers that justify it come
# second, and anything demanding attention is visible without being
# looked for.
#
# Every method degrades to plain ASCII when the console cannot render
# box-drawing characters, reusing the package's own to_ascii()/
# ascii_fallback() policy rather than assuming UTF-8.

# TRUE when the connection can be trusted with non-ASCII box characters.
.rmbl_unicode_ok <- function() {
  if (!identical(Sys.getenv("RMBL_ASCII_ONLY"), "")) return(FALSE)
  l10n <- l10n_info()
  isTRUE(l10n[["UTF-8"]])
}

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

# A titled rule, e.g. "-- Drift report ----------------".
.rmbl_rule <- function(title = NULL, width = 66L) {
  g <- .rmbl_glyphs()
  if (is.null(title)) return(strrep(g$h, width))
  left <- paste0(strrep(g$h, 2L), " ", title, " ")
  pad <- max(0L, width - nchar(left))
  paste0(left, strrep(g$h, pad))
}

# Fixed-width label/value lines, labels right-padded to a common width.
.rmbl_kv <- function(pairs, indent = 2L) {
  keys <- names(pairs)
  w <- if (length(keys)) max(nchar(keys)) else 0L
  paste0(strrep(" ", indent), formatC(keys, width = w, flag = "-"), "  ",
         vapply(pairs, function(v) paste(format(v), collapse = ", "),
                character(1)))
}

.rmbl_fmt_p <- function(p) {
  ifelse(is.na(p), "NA",
         ifelse(p < 2e-16, "<2e-16", formatC(p, format = "g", digits = 3)))
}

# A classed data frame keeps its class when columns are subset away, so
# `result[, c("a", "b")]` still dispatches to the custom print method
# with the columns that method needs now missing. Fall back to a plain
# data-frame print rather than erroring on the user's subset.
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
  verdict <- if (isTRUE(x$any_drift)) {
    paste0(g$bad, " DRIFT DETECTED")
  } else {
    paste0(g$ok, " no drift detected")
  }
  out <- c(
    .rmbl_rule("Capsule drift report"),
    paste0("  ", verdict),
    "",
    .rmbl_kv(list(
      "reference rows" = format(x$n_reference, big.mark = ","),
      "current rows" = format(x$n_current, big.mark = ","),
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
  c(out, .rmbl_rule())
}

#' Printed reports for bricklayer objects
#'
#' Human-readable renderings of the objects the package returns. Each
#' leads with the verdict, then the evidence. `format()` returns the
#' lines as a character vector so they can be logged or written to a
#' file; `print()` sends them to the console and returns its argument
#' invisibly.
#'
#' Box-drawing characters are used only when the session's encoding can
#' render them; otherwise the same layout is drawn in plain ASCII. Set
#' the environment variable `RMBL_ASCII_ONLY` to force the ASCII form,
#' which is what to do when capturing output into a fixed-width log.
#'
#' @param x The object to render.
#' @param ... Ignored, present for S3 consistency.
#' @return `format()` methods return a character vector; `print()`
#'   methods return `x` invisibly.
#' @examples
#' set.seed(7)
#' ref <- data.frame(v = stats::rnorm(200),
#'                   g = sample(c("a", "b"), 200, TRUE))
#' cur <- data.frame(v = stats::rnorm(200, mean = 1),
#'                   g = sample(c("a", "b"), 200, TRUE))
#'
#' # The drift report leads with its verdict.
#' capsule_drift(ref, cur)
#'
#' # format() gives the same lines for a log file.
#' head(format(capsule_drift(ref, cur)), 3)
#'
#' # A Benford screen.
#' benford_test(10^stats::runif(500, 0, 5))
#'
#' # Keys and signatures print without ever showing the secret seed.
#' key <- pqc_keygen(height = 2)
#' key
#' capsule_sign("a-manifest", key)
#' @name rmbl_print_methods
#' @export
print.bricklayer_drift <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

#' @rdname rmbl_print_methods
#' @export
summary.bricklayer_drift <- function(object, ...) {
  cols <- object$columns
  drifted <- if (nrow(cols)) cols$column[which(isTRUE(cols$drifted) |
                                                 cols$drifted)] else
    character(0)
  out <- list(any_drift = object$any_drift,
              n_tested = nrow(cols),
              n_drifted = length(drifted),
              drifted = drifted,
              added = object$added,
              removed = object$removed)
  class(out) <- c("bricklayer_drift_summary", "list")
  out
}

#' @export
print.bricklayer_drift_summary <- function(x, ...) {
  g <- .rmbl_glyphs()
  cat(if (isTRUE(x$any_drift)) paste0(g$bad, " drift detected") else
        paste0(g$ok, " no drift detected"), "\n")
  cat(sprintf("  %d of %d columns drifted\n", x$n_drifted, x$n_tested))
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

#' @rdname rmbl_print_methods
#' @export
print.bricklayer_benford <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

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

#' @rdname rmbl_print_methods
#' @export
print.bricklayer_signing_key <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

#' @export
format.bricklayer_public_key <- function(x, ...) {
  c(.rmbl_rule("Public verification key"),
    .rmbl_kv(list(scheme = x$scheme, root = x$root, height = x$height)),
    .rmbl_rule())
}

#' @rdname rmbl_print_methods
#' @export
print.bricklayer_public_key <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

#' @export
format.bricklayer_signature <- function(x, ...) {
  pairs <- list(scheme = x$scheme)
  if (identical(x$scheme, "hmac")) {
    pairs$tag <- x$signature
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

#' @rdname rmbl_print_methods
#' @export
print.bricklayer_signature <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

#' @param object The object to summarise.
#' @rdname rmbl_print_methods
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
#' mean is not describing it. That is visible in one glance here and in
#' no single number.
#'
#' @param data A data frame.
#' @param quantiles Quantile probabilities to include for numeric
#'   columns (default the quartiles).
#' @return A data frame of class `bricklayer_profile`, one row per
#'   column: the type, the missing count and share, the number of
#'   distinct values, and for a numeric column the counts of zero,
#'   negative and infinite values, the classical and robust centre and
#'   spread, the range, the skewness, the count outside the Tukey
#'   fences, and an [inline_hist()] sketch of its distribution. A
#'   categorical column reports its most common value in `top`
#'   instead.
#' @seealso [capsule_drift()] to compare two of these, [core_moments()]
#'   for the underlying kernel.
#' @examples
#' set.seed(9)
#' df <- data.frame(
#'   clean = stats::rnorm(100),
#'   skewed = c(stats::rnorm(99), 500),
#'   grade = sample(c("a", "b", "c"), 100, TRUE),
#'   gappy = c(rep(NA, 10), stats::runif(90))
#' )
#'
#' profile_columns(df)
#'
#' # The mean and the median agree on `clean` and disagree sharply on
#' # `skewed`, which is the outlier announcing itself.
#' p <- profile_columns(df)
#' p[p$column %in% c("clean", "skewed"), c("column", "mean", "median")]
#'
#' # The histogram column shows shape no summary number carries.
#' p[, c("column", "hist")]
#'
#' # Zeros, negatives and infinities are counted separately, because
#' # each breaks a different downstream computation (a log, a square
#' # root, an average).
#' p[, c("column", "n_zero", "n_negative", "n_infinite")]
#' @export
profile_columns <- function(data, quantiles = c(0.25, 0.5, 0.75)) {
  if (!is.data.frame(data)) stop("`data` must be a data frame", call. = FALSE)
  if (ncol(data) == 0L) {
    stop("`data` has no columns to profile", call. = FALSE)
  }
  rows <- lapply(names(data), function(nm) {
    v <- data[[nm]]
    n_missing <- sum(is.na(v))
    base <- data.frame(column = nm, type = class(v)[1L], n = length(v),
                       n_missing = n_missing,
                       pct_missing = 100 * n_missing / max(1L, length(v)),
                       stringsAsFactors = FALSE)
    if (is.numeric(v)) {
      ok <- v[!is.na(v)]
      if (length(ok) == 0L) {
        return(cbind(base, n_distinct = 0L, n_zero = NA_integer_,
                     n_negative = NA_integer_, n_infinite = NA_integer_,
                     mean = NA_real_, sd = NA_real_,
                     median = NA_real_, mad = NA_real_, min = NA_real_,
                     max = NA_real_, skewness = NA_real_,
                     n_outliers = NA_integer_, hist = NA_character_,
                     top = NA_character_, stringsAsFactors = FALSE))
      }
      m <- core_moments(ok)
      f <- core_tukey_fences(ok)
      cbind(base, n_distinct = length(unique(ok)),
            n_zero = sum(ok == 0), n_negative = sum(ok < 0),
            n_infinite = sum(is.infinite(v)),
            mean = m[["mean"]], sd = sqrt(m[["variance"]]),
            median = core_median(ok), mad = core_mad(ok),
            min = min(ok), max = max(ok), skewness = m[["skewness"]],
            n_outliers = sum(ok < f[["lower"]] | ok > f[["upper"]]),
            hist = .rmbl_sparkline(ok), top = NA_character_,
            stringsAsFactors = FALSE)
    } else {
      ok <- as.character(v[!is.na(v)])
      top <- if (length(ok)) names(sort(table(ok), decreasing = TRUE))[1L] else
        NA_character_
      cbind(base, n_distinct = length(unique(ok)), n_zero = NA_integer_,
            n_negative = NA_integer_, n_infinite = NA_integer_,
            mean = NA_real_, sd = NA_real_, median = NA_real_,
            mad = NA_real_, min = NA_real_, max = NA_real_,
            skewness = NA_real_, n_outliers = NA_integer_,
            hist = NA_character_, top = top, stringsAsFactors = FALSE)
    }
  })
  out <- do.call(rbind, rows)
  if (length(quantiles)) {
    qs <- lapply(names(data), function(nm) {
      v <- data[[nm]]
      if (is.numeric(v) && any(!is.na(v))) {
        as.numeric(.Call(C_rmbl_quantile, as.numeric(v[!is.na(v)]),
                         as.numeric(quantiles)))
      } else {
        rep(NA_real_, length(quantiles))
      }
    })
    qm <- do.call(rbind, qs)
    colnames(qm) <- paste0("q", format(100 * quantiles, trim = TRUE))
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
