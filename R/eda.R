# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Exploratory description. A capsule is only worth pinning if somebody
# looked at what is in it first, and the look is the step that gets
# skipped. These are the summaries that make skipping it harder: the
# shape of every column, where the gaps are, which values dominate, and
# which rows do not belong.

# A one-line histogram from block-drawing characters, or ASCII where the
# console cannot render them. Eight levels is what the Unicode blocks
# give; the ASCII fallback has five and says less, but says it legibly.
.rmbl_sparkline <- function(x, bins = 10L) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  if (length(x) == 0L) return(strrep(" ", bins))
  rng <- range(x)
  if (!is.finite(rng[1L]) || rng[1L] == rng[2L]) {
    # no spread to show: one full bar says "all the same value"
    ticks <- if (.rmbl_unicode_ok()) "\u2588" else "#"
    return(paste0(strrep(" ", bins %/% 2L), ticks,
                  strrep(" ", bins - bins %/% 2L - 1L)))
  }
  breaks <- seq(rng[1L], rng[2L], length.out = bins + 1L)
  counts <- graphics::hist(x, breaks = breaks, plot = FALSE)$counts
  levels <- if (.rmbl_unicode_ok()) {
    c("\u2581", "\u2582", "\u2583", "\u2584", "\u2585", "\u2586",
      "\u2587", "\u2588")
  } else {
    c(".", ":", "-", "=", "#")
  }
  mx <- max(counts)
  idx <- ifelse(counts == 0L, 0L,
                pmax(1L, ceiling(counts / mx * length(levels))))
  paste(ifelse(idx == 0L, " ", levels[pmax(1L, idx)]), collapse = "")
}

#' Inline histogram for a numeric vector
#'
#' A one-line sketch of a column's distribution, as block characters (or
#' ASCII where the console cannot render them). The point is density of
#' information: a mean and a standard deviation cannot tell you a column
#' is bimodal, and this can, in the width of a table cell.
#'
#' @param x Numeric vector.
#' @param bins Number of bins (default 10).
#' @return A length-1 character vector of `bins` characters.
#' @seealso [profile_columns()], which includes one per numeric column.
#' @examples
#' set.seed(1)
#' # A symmetric distribution peaks in the middle.
#' inline_hist(stats::rnorm(1000))
#'
#' # A skewed one leans left.
#' inline_hist(stats::rexp(1000))
#'
#' # Bimodality is visible here and in no single summary number.
#' inline_hist(c(stats::rnorm(500, -3), stats::rnorm(500, 3)))
#'
#' # A constant column has no spread to show.
#' inline_hist(rep(5, 10))
#' @export
inline_hist <- function(x, bins = 10L) {
  bins <- as.integer(bins)
  if (length(bins) != 1L || is.na(bins) || bins < 1L) {
    stop("`bins` must be a single positive integer", call. = FALSE)
  }
  .rmbl_sparkline(x, bins)
}

#' Frequency table for one column
#'
#' Counts, percentages, and percentages of the non-missing values, with
#' missing counted as its own row. The counterpart of
#' `janitor::tabyl()`.
#'
#' Two percentage columns, because both questions get asked and
#' conflating them is how missingness gets hidden: `pct` is the share of
#' ALL rows, `pct_valid` the share of rows where the value is present.
#' When a column is 40% missing those two differ enormously, and only the
#' second describes the values that are actually there.
#'
#' @param data A data frame, or a vector.
#' @param column Column name, when `data` is a data frame.
#' @param max_levels Maximum rows to return, most frequent first
#'   (default 25). The remainder are folded into one `"(other)"` row so
#'   the percentages still sum to 100.
#' @param sort Sort by descending count (default `TRUE`); `FALSE` keeps
#'   the natural order of the values.
#' @return A data frame of class `bricklayer_freq`: `value`, `n`, `pct`,
#'   `pct_valid`.
#' @seealso [profile_columns()] for every column at once.
#' @examples
#' df <- data.frame(grade = c("a", "b", "b", "c", NA, "b"),
#'                  stringsAsFactors = FALSE)
#' frequency_table(df, "grade")
#'
#' # The two percentage columns differ exactly by the missingness.
#' frequency_table(df, "grade")[, c("pct", "pct_valid")]
#'
#' # A vector works directly.
#' frequency_table(c(1, 1, 2, 3, 3, 3))
#'
#' # Natural order rather than frequency order.
#' frequency_table(c("c", "a", "b", "a"), sort = FALSE)
#'
#' # Long tails are folded so the percentages still total 100.
#' set.seed(1)
#' ft <- frequency_table(sample(letters, 500, TRUE), max_levels = 5)
#' ft
#' sum(ft$pct)
#' @export
frequency_table <- function(data, column = NULL, max_levels = 25L,
                            sort = TRUE) {
  v <- if (is.data.frame(data)) {
    if (is.null(column)) {
      stop("`column` is required when `data` is a data frame", call. = FALSE)
    }
    column <- as.character(column)[1L]
    if (!column %in% names(data)) {
      stop(sprintf("no such column: %s", column), call. = FALSE)
    }
    data[[column]]
  } else {
    data
  }
  max_levels <- as.integer(max_levels)
  if (length(max_levels) != 1L || is.na(max_levels) || max_levels < 1L) {
    stop("`max_levels` must be a single positive integer", call. = FALSE)
  }
  n_all <- length(v)
  if (n_all == 0L) {
    out <- data.frame(value = character(0), n = integer(0),
                      pct = numeric(0), pct_valid = numeric(0),
                      stringsAsFactors = FALSE)
    class(out) <- c("bricklayer_freq", "data.frame")
    return(out)
  }
  n_na <- sum(is.na(v))
  n_valid <- n_all - n_na
  tab <- table(as.character(v[!is.na(v)]))
  if (isTRUE(sort)) tab <- base::sort(tab, decreasing = TRUE)

  vals <- names(tab)
  counts <- as.integer(tab)
  if (length(vals) > max_levels) {
    keep <- seq_len(max_levels)
    other <- sum(counts[-keep])
    vals <- c(vals[keep], "(other)")
    counts <- c(counts[keep], other)
  }
  if (n_na > 0L) {
    vals <- c(vals, NA_character_)
    counts <- c(counts, n_na)
  }
  out <- data.frame(
    value = vals, n = as.integer(counts),
    pct = 100 * counts / n_all,
    # the missing row has no share of the valid values, by definition
    pct_valid = ifelse(is.na(vals), NA_real_,
                       if (n_valid > 0L) 100 * counts / n_valid else NA_real_),
    stringsAsFactors = FALSE)
  rownames(out) <- NULL
  class(out) <- c("bricklayer_freq", "data.frame")
  out
}

#' @export
print.bricklayer_freq <- function(x, ...) {
  if (.rmbl_needs_cols(x, c("value", "n", "pct", "pct_valid"))) {
    return(invisible(x))
  }
  cat(.rmbl_rule("Frequency table"), "\n")
  df <- as.data.frame(unclass(x), stringsAsFactors = FALSE)
  if (nrow(df) == 0L) {
    cat("  (no values)\n")
    cat(.rmbl_rule(), "\n")
    return(invisible(x))
  }
  g <- .rmbl_glyphs()
  df$value <- ifelse(is.na(df$value), paste0(g$dash, " (missing)"), df$value)
  df$pct <- formatC(df$pct, format = "f", digits = 1)
  df$pct_valid <- ifelse(is.na(df$pct_valid), g$dash,
                         formatC(df$pct_valid, format = "f", digits = 1))
  df$bar <- vapply(x$n, function(k) {
    strrep("#", as.integer(round(20 * k / max(x$n))))
  }, character(1))
  print(df, row.names = FALSE)
  cat(.rmbl_rule(), "\n")
  invisible(x)
}

#' Full pairwise correlation table
#'
#' Every numeric pair's correlation in long form -- one row per pair,
#' which is easier to sort, filter and join than a matrix. The
#' counterpart of `corrr::correlate()`.
#'
#' @param data A data frame; non-numeric columns are ignored.
#' @param method `"spearman"` (default) or `"pearson"`. See
#'   [top_correlations()] for why the rank correlation is the default.
#' @param min_pairs Minimum complete pairs required before a correlation
#'   is computed (default 3). Below it the pair is `NA` rather than a
#'   number computed from almost nothing.
#' @return A data frame of class `bricklayer_cortable` with `x`, `y`,
#'   `correlation` and `n_pairs`.
#' @seealso [top_correlations()] for just the strongest,
#'   [core_cov()] for the matrix form.
#' @examples
#' set.seed(1)
#' df <- data.frame(a = stats::rnorm(100), b = stats::rnorm(100))
#' df$c <- df$a + stats::rnorm(100, sd = 0.2)
#'
#' correlation_table(df)
#'
#' # n_pairs shows how much data each figure rests on.
#' gappy <- df
#' gappy$a[1:80] <- NA
#' correlation_table(gappy)
#'
#' # A pair with too little overlap is NA, not a number from nothing.
#' thin <- df
#' thin$a[1:99] <- NA
#' correlation_table(thin)$correlation
#' @export
correlation_table <- function(data, method = c("spearman", "pearson"),
                              min_pairs = 3L) {
  method <- match.arg(method)
  if (!is.data.frame(data)) stop("`data` must be a data frame", call. = FALSE)
  num <- names(data)[vapply(data, is.numeric, logical(1))]
  if (length(num) < 2L) {
    stop("need at least two numeric columns to correlate", call. = FALSE)
  }
  min_pairs <- as.integer(min_pairs)
  if (length(min_pairs) != 1L || is.na(min_pairs) || min_pairs < 2L) {
    stop("`min_pairs` must be a single integer of at least 2", call. = FALSE)
  }
  pairs <- utils::combn(num, 2L)
  rows <- lapply(seq_len(ncol(pairs)), function(j) {
    a <- data[[pairs[1L, j]]]
    b <- data[[pairs[2L, j]]]
    ok <- !is.na(a) & !is.na(b)
    np <- sum(ok)
    val <- if (np < min_pairs) NA_real_ else if (identical(method, "spearman")) {
      core_cor_spearman(a[ok], b[ok])
    } else {
      core_cor(a[ok], b[ok])
    }
    data.frame(x = pairs[1L, j], y = pairs[2L, j], correlation = val,
               n_pairs = np, stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  attr(out, "method") <- method
  class(out) <- c("bricklayer_cortable", "data.frame")
  out
}

#' @export
print.bricklayer_cortable <- function(x, ...) {
  if (.rmbl_needs_cols(x, c("x", "y", "correlation", "n_pairs"))) {
    return(invisible(x))
  }
  cat(.rmbl_rule(paste0("Correlations (", attr(x, "method"), ")")), "\n")
  df <- as.data.frame(unclass(x), stringsAsFactors = FALSE)
  attr(df, "method") <- NULL
  df$correlation <- ifelse(is.na(df$correlation), .rmbl_glyphs()$dash,
                           formatC(df$correlation, format = "f", digits = 3))
  print(df, row.names = FALSE)
  cat(.rmbl_rule(), "\n")
  invisible(x)
}

#' Drop empty or constant columns and rows
#'
#' `drop_empty()` removes rows or columns that are entirely missing.
#' `drop_constant()` removes columns that hold a single distinct value.
#' The counterparts of `janitor::remove_empty()` and
#' `janitor::remove_constant()`.
#'
#' A constant column carries no information and breaks anything that
#' scales by variance, so it is worth removing -- but it is also a
#' FINDING. A column that was informative in the pinned capsule and is
#' constant in a fresh fetch means the source changed, so check
#' [capsule_drift()] before deleting it and moving on.
#'
#' @param data A data frame.
#' @param which `"rows"`, `"cols"`, or both (the default).
#' @param na_as_value Treat `NA` as a distinct value, so a column of
#'   `NA`s plus one real value counts as two (default `FALSE`).
#' @return The data frame, with the offending rows or columns removed.
#'   The names of what was dropped are attached as the `"dropped"`
#'   attribute.
#' @seealso [profile_columns()], which reports `n_distinct` without
#'   removing anything.
#' @examples
#' df <- data.frame(
#'   keep = c(1, 2, NA),
#'   all_na = c(NA, NA, NA),
#'   constant = c(7, 7, 7),
#'   stringsAsFactors = FALSE
#' )
#'
#' drop_empty(df)
#' attr(drop_empty(df), "dropped")
#'
#' drop_constant(df)
#'
#' # Rows only.
#' drop_empty(data.frame(a = c(1, NA), b = c(2, NA)), which = "rows")
#'
#' # A column of NAs plus one value is constant by default, and not when
#' # NA is treated as a value of its own.
#' x <- data.frame(v = c(NA, NA, 5))
#' ncol(drop_constant(x))
#' ncol(drop_constant(x, na_as_value = TRUE))
#' @name rmbl_drop
#' @export
drop_empty <- function(data, which = c("rows", "cols")) {
  if (!is.data.frame(data)) stop("`data` must be a data frame", call. = FALSE)
  which <- match.arg(which, c("rows", "cols"), several.ok = TRUE)
  dropped <- character(0)
  if ("cols" %in% which && ncol(data) > 0L) {
    empty <- vapply(data, function(v) all(is.na(v)), logical(1))
    dropped <- c(dropped, names(data)[empty])
    data <- data[, !empty, drop = FALSE]
  }
  if ("rows" %in% which && nrow(data) > 0L && ncol(data) > 0L) {
    empty_rows <- apply(data, 1L, function(r) all(is.na(r)))
    data <- data[!empty_rows, , drop = FALSE]
    rownames(data) <- NULL
  }
  attr(data, "dropped") <- dropped
  data
}

#' @rdname rmbl_drop
#' @export
drop_constant <- function(data, na_as_value = FALSE) {
  if (!is.data.frame(data)) stop("`data` must be a data frame", call. = FALSE)
  if (ncol(data) == 0L) {
    attr(data, "dropped") <- character(0)
    return(data)
  }
  const <- vapply(data, function(v) {
    u <- if (isTRUE(na_as_value)) unique(v) else unique(v[!is.na(v)])
    length(u) <= 1L
  }, logical(1))
  dropped <- names(data)[const]
  out <- data[, !const, drop = FALSE]
  attr(out, "dropped") <- dropped
  out
}

#' Tidy the column names of an ingested table
#'
#' Converts names to a consistent, syntactically valid form: transliterated
#' to ASCII, non-alphanumerics collapsed to a single separator, and
#' duplicates disambiguated with a numeric suffix. The counterpart of
#' `janitor::clean_names()`.
#'
#' Open-data extracts arrive with names like `"Total  Population (2021)"`
#' and `"% change"`, which need backticks everywhere and break silently
#' when a re-release renames `"% change"` to `"%  change"`. Normalising
#' once at ingestion makes the schema stable against that.
#'
#' Record the mapping in the capsule manifest. Cleaning names changes
#' what a downstream script must refer to, so an unrecorded cleaning is
#' itself a reproducibility hazard -- the returned object carries the
#' original names in its `"original_names"` attribute for exactly that.
#'
#' @param data A data frame, or a character vector of names.
#' @param case `"snake"` (default), `"lower_camel"`, `"upper_camel"`,
#'   `"screaming_snake"`, or `"none"` to normalise separators only.
#' @param sep Separator for `"snake"` and `"screaming_snake"`
#'   (default `"_"`).
#' @return The data frame with new names (and an `"original_names"`
#'   attribute), or the cleaned character vector.
#' @examples
#' clean_column_names(c("Total  Population (2021)", "% change",
#'                      "Ville / City", "dup", "dup"))
#'
#' # Applied to a data frame, with the original names retained.
#' df <- data.frame(`Total Pop` = 1:2, `% change` = 3:4,
#'                  check.names = FALSE)
#' cleaned <- clean_column_names(df)
#' names(cleaned)
#' attr(cleaned, "original_names")
#'
#' # Other cases.
#' clean_column_names(c("Total Pop"), case = "lower_camel")
#' clean_column_names(c("Total Pop"), case = "upper_camel")
#' clean_column_names(c("Total Pop"), case = "screaming_snake")
#' @export
clean_column_names <- function(data, case = c("snake", "lower_camel",
                                              "upper_camel",
                                              "screaming_snake", "none"),
                               sep = "_") {
  case <- match.arg(case)
  nms <- if (is.data.frame(data)) names(data) else as.character(data)
  if (length(nms) == 0L) {
    if (is.data.frame(data)) return(data)
    return(character(0))
  }
  original <- nms

  # Transliterate first: an accented name must not become empty.
  out <- iconv(nms, to = "ASCII//TRANSLIT")
  out[is.na(out)] <- nms[is.na(out)]
  # Percentages and ampersands carry meaning a bare strip would lose.
  out <- gsub("%", " pct ", out, fixed = TRUE)
  out <- gsub("&", " and ", out, fixed = TRUE)
  out <- gsub("#", " n ", out, fixed = TRUE)
  # Split camelCase before folding case, or the word boundary is lost.
  out <- gsub("([a-z0-9])([A-Z])", "\\1 \\2", out)
  out <- gsub("[^A-Za-z0-9]+", " ", out)
  out <- trimws(out)
  out[!nzchar(out)] <- "x"

  words <- strsplit(out, " ", fixed = TRUE)
  out <- vapply(words, function(w) {
    w <- w[nzchar(w)]
    if (length(w) == 0L) return("x")
    switch(case,
      snake = paste(tolower(w), collapse = sep),
      screaming_snake = paste(toupper(w), collapse = sep),
      lower_camel = paste0(tolower(w[1L]),
                           paste(.rmbl_capitalise(w[-1L]), collapse = "")),
      upper_camel = paste(.rmbl_capitalise(w), collapse = ""),
      none = paste(w, collapse = sep))
  }, character(1))

  # A name starting with a digit is not syntactically valid.
  out <- ifelse(grepl("^[0-9]", out), paste0("x", out), out)
  # Disambiguate duplicates rather than letting one silently win.
  dup <- duplicated(out)
  if (any(dup)) {
    for (nm in unique(out[dup])) {
      idx <- which(out == nm)
      out[idx] <- paste0(nm, c("", paste0(sep, seq_len(length(idx) - 1L) + 1L)))
    }
  }
  if (is.data.frame(data)) {
    names(data) <- out
    attr(data, "original_names") <- original
    return(data)
  }
  out
}

.rmbl_capitalise <- function(w) {
  if (length(w) == 0L) return(character(0))
  paste0(toupper(substring(w, 1L, 1L)), tolower(substring(w, 2L)))
}
