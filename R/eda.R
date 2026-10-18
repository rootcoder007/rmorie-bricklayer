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
  x <- .rmbl_num(x, "x")
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
#' Draws a one-line sketch of a column's distribution, as block characters
#' (or ASCII where the console cannot render them). The point is density of
#' information: a mean and a standard deviation cannot tell you a column is
#' bimodal, skewed or has a gap, and this can, in the width of a table cell.
#' [profcols()] shows one for every numeric column.
#'
#' @details
#' Non-finite values (\code{NA}, \code{NaN}, \code{Inf}) are dropped. The
#' range of the rest is cut into \code{bins} equal-width bins (as
#' \code{graphics::hist()} with those breaks) and each bin's count is drawn
#' as one of eight Unicode block heights, scaled to the largest bin; an
#' empty bin is a space, and a bin with any values is at least the lowest
#' block. When the session is not UTF-8, or the environment variable
#' \code{RMBL_ASCII_ONLY} is set, five ASCII levels (\code{. : - = #}) are
#' used instead. A column with no spread gives one full block in the middle;
#' no finite values give spaces.
#'
#' Errors: \code{x} that is not numeric; \code{bins} that is not one
#' positive whole number.
#'
#' @param x Numeric vector.
#' @param bins Number of bins, and so of characters, one positive whole
#'   number (default 10).
#' @return A length-1 character vector of \code{bins} characters.
#' @seealso
#' [profcols()], which includes one
#' per numeric column.
#' @examples
#' set.seed(1)
#' # A symmetric distribution peaks in the middle.
#' inlhist(stats::rnorm(1000))
#'
#' # A skewed one leans left.
#' inlhist(stats::rexp(1000))
#'
#' # Bimodality is visible here and in no single summary number.
#' inlhist(c(stats::rnorm(500, -3), stats::rnorm(500, 3)))
#'
#' # A constant column has no spread to show.
#' inlhist(rep(5, 10))
#'
#' # more bins for more detail
#' inlhist(stats::rexp(1000), bins = 30)
#'
#' # text is not a distribution
#' try(inlhist(c("a", "b")))
#' @export
inlhist <- function(x, bins = 10L) {
  x <- .rmbl_num_input(x, "x")
  bins <- .rmbl_num(bins, "bins", integer = TRUE)
  if (length(bins) != 1L || is.na(bins) || bins < 1L) {
    stop("`bins` must be a single positive integer", call. = FALSE)
  }
  .rmbl_sparkline(x, bins)
}

#' Frequency table for one column
#'
#' Counts how often each value of a column occurs, with percentages of all
#' rows and of the non-missing rows, and missing values counted as their
#' own row. It is the first look at a categorical variable (a charge type,
#' a region, a response category), and the counterpart of
#' \code{janitor::tabyl()}.
#'
#' @details
#' Two percentage columns, because both questions get asked and conflating
#' them is how missingness gets hidden: \code{pct} is the share of ALL
#' rows, \code{pctvalid} the share of rows where the value is present.
#' When a column is 40% missing those two differ enormously, and only the
#' second describes the values that are actually there.
#'
#' Values are tabulated as text (\code{as.character()}), so numbers and
#' factors are counted by their printed value, and factor levels that do not
#' occur get no row. Rows are sorted by descending count (ties in the order
#' \code{table()} gives) or kept in sorted value order with
#' \code{sort = FALSE}. Beyond \code{maxlvl} distinct values, the rest are
#' folded into one \code{"(other)"} row so the percentages still sum to 100.
#' The missing row, when there is one, comes last, with \code{value} \code{NA}
#' and \code{pctvalid} \code{NA}. An empty input gives a table with no rows.
#' The print method adds a bar column.
#'
#' Errors: a data frame without \code{col}; a \code{col} that is not
#' in \code{data}; \code{maxlvl} not one positive whole number.
#'
#' @param data A data frame, or a vector.
#' @param col Column name (a string), when \code{data} is a data
#'   frame; ignored for a vector.
#' @param maxlvl Maximum value rows to return, most
#'   frequent first (default 25). The remainder are folded into one
#'   \code{"(other)"} row so the percentages still sum to 100.
#' @param sort Logical: sort by descending count (default \code{TRUE});
#'   \code{FALSE} keeps the sorted order of the values.
#' @return A data frame of class \code{c("bricklayer_freq", "data.frame")}
#'   with columns \code{value} (character), \code{n} (integer count),
#'   \code{pct} (numeric, percent of all rows) and \code{pctvalid} (numeric,
#'   percent of non-missing rows; \code{NA} on the missing row).
#' @seealso [profcols()] for every
#' column at once.
#' @examples
#' df <- data.frame(grade = c("a", "b", "b", "c", NA, "b"),
#'                  stringsAsFactors = FALSE)
#' freqtbl(df, "grade")
#'
#' # The two percentage columns differ exactly by the missingness.
#' freqtbl(df, "grade")[, c("pct", "pctvalid")]
#'
#' # A vector works directly.
#' freqtbl(c(1, 1, 2, 3, 3, 3))
#'
#' # Sorted value order rather than frequency order.
#' freqtbl(c("c", "a", "b", "a"), sort = FALSE)
#'
#' # Long tails are folded so the percentages still total 100.
#' set.seed(1)
#' ft <- freqtbl(sample(letters, 500, TRUE), maxlvl = 5)
#' ft
#' sum(ft$pct)
#'
#' # a data frame needs a column name
#' try(freqtbl(df))
#' @export
freqtbl <- function(data, col = NULL, maxlvl = 25L,
                            sort = TRUE) {
  .rmbl_no_fn(data = data, column = col)
  v <- if (is.data.frame(data)) {
    if (is.null(col)) {
      stop("`col` is required when `data` is a data frame", call. = FALSE)
    }
    col <- as.character(col)[1L]
    if (!col %in% names(data)) {
      stop(sprintf("no such column: %s", col), call. = FALSE)
    }
    data[[col]]
  } else {
    data
  }
  maxlvl <- .rmbl_num(maxlvl, "maxlvl", integer = TRUE)
  if (length(maxlvl) != 1L || is.na(maxlvl) || maxlvl < 1L) {
    stop("`maxlvl` must be a single positive integer", call. = FALSE)
  }
  n_all <- length(v)
  if (n_all == 0L) {
    out <- data.frame(value = character(0), n = integer(0),
                      pct = numeric(0), pctvalid = numeric(0),
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
  if (length(vals) > maxlvl) {
    keep <- seq_len(maxlvl)
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
    pctvalid = ifelse(is.na(vals), NA_real_,
                       if (n_valid > 0L) 100 * counts / n_valid else NA_real_),
    stringsAsFactors = FALSE)
  rownames(out) <- NULL
  class(out) <- c("bricklayer_freq", "data.frame")
  out
}

#' @export
print.bricklayer_freq <- function(x, ...) {
  if (.rmbl_needs_cols(x, c("value", "n", "pct", "pctvalid"))) {
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
  df$pctvalid <- ifelse(is.na(df$pctvalid), g$dash,
                         formatC(df$pctvalid, format = "f", digits = 1))
  df$bar <- vapply(x$n, function(k) {
    strrep("#", as.integer(round(20 * k / max(x$n))))
  }, character(1))
  print(df, row.names = FALSE)
  cat(.rmbl_rule(), "\n")
  invisible(x)
}

#' Full pairwise correlation table
#'
#' Computes the correlation of every pair of numeric columns and returns it
#' in long form -- one row per pair, which is easier to sort, filter and join
#' than a matrix -- with the number of complete pairs each figure rests on.
#' The counterpart of \code{corrr::correlate()}.
#'
#' @details
#' Non-numeric columns are ignored. For each pair, rows where either value is
#' missing are dropped (pairwise deletion), so different pairs can rest on
#' different rows; \code{nprs} says how many. Spearman's rank correlation
#' (the default) is the Pearson correlation of the ranks, robust to outliers
#' and to monotone transformations; see
#' [topcors()] for why it is
#' the default. A pair with fewer than \code{minprs} complete rows, or
#' with a constant column (no variance), gets \code{NA}. The pairs are listed
#' in column order (\code{utils::combn()}). A progress bar is drawn on stderr
#' for many pairs unless \code{options(morie.quiet = TRUE)}.
#'
#' Errors: \code{data} not a data frame; fewer than two numeric columns;
#' \code{minprs} not a whole number of at least 2; an invalid
#' \code{meth}.
#'
#' @param data A data frame; non-numeric columns are ignored.
#' @param meth \code{"spearman"} (default) or \code{"pearson"}. See
#'   [topcors()] for why the rank correlation is
#'   the default.
#' @param minprs Minimum complete pairs required before
#'   a correlation is computed, a whole number of at least 2 (default 3).
#'   Below it the pair is \code{NA} rather than a number computed from almost
#'   nothing.
#' @return A data frame of class \code{c("bricklayer_cortable", "data.frame")}
#'   with one row per pair of numeric columns and the columns \code{x} and
#'   \code{y} (character, the column names), \code{correlation} (numeric, in
#'   \eqn{[-1, 1]} or \code{NA}) and \code{nprs} (integer); the method is
#'   in \code{attr(, "method")}.
#' @seealso
#' [topcors()] for just the
#' strongest, [ccovm()] for the matrix form.
#' @examples
#' set.seed(1)
#' df <- data.frame(a = stats::rnorm(100), b = stats::rnorm(100))
#' df$c <- df$a + stats::rnorm(100, sd = 0.2)
#'
#' cortbl(df)
#'
#' # Pearson instead of Spearman
#' cortbl(df, meth = "pearson")
#'
#' # nprs shows how much data each figure rests on.
#' gappy <- df
#' gappy$a[1:80] <- NA
#' cortbl(gappy)
#'
#' # A pair with too little overlap is NA, not a number from nothing.
#' thin <- df
#' thin$a[1:99] <- NA
#' cortbl(thin)$correlation
#'
#' # one numeric column cannot be correlated
#' try(cortbl(data.frame(a = 1:5, b = letters[1:5])))
#' @export
cortbl <- function(data, meth = c("spearman", "pearson"),
                              minprs = 3L) {
  meth <- .rmbl_arg(meth)
  if (!is.data.frame(data)) stop("`data` must be a data frame", call. = FALSE)
  .rmbl_df_names(data)
  num <- names(data)[vapply(data, is.numeric, logical(1))]
  if (length(num) < 2L) {
    stop("need at least two numeric columns to correlate", call. = FALSE)
  }
  minprs <- .rmbl_num(minprs, "minprs", integer = TRUE)
  if (length(minprs) != 1L || is.na(minprs) || minprs < 2L) {
    stop("`minprs` must be a single integer of at least 2", call. = FALSE)
  }
  pairs <- utils::combn(num, 2L)
  pg <- blprog("correlations", ncol(pairs))
  on.exit(pg$done(), add = TRUE)
  rows <- lapply(seq_len(ncol(pairs)), function(j) {
    pg$update(j - 1L, sprintf("pair %d/%d", j, ncol(pairs)))
    a <- data[[pairs[1L, j]]]
    b <- data[[pairs[2L, j]]]
    ok <- !is.na(a) & !is.na(b)
    np <- sum(ok)
    val <- if (np < minprs) NA_real_ else if (identical(meth, "spearman")) {
      cspr(a[ok], b[ok])
    } else {
      ccorr(a[ok], b[ok])
    }
    data.frame(x = pairs[1L, j], y = pairs[2L, j], correlation = val,
               nprs = np, stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  attr(out, "method") <- meth
  class(out) <- c("bricklayer_cortable", "data.frame")
  out
}

#' @export
print.bricklayer_cortable <- function(x, ...) {
  if (.rmbl_needs_cols(x, c("x", "y", "correlation", "nprs"))) {
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
#' \code{drpempty()} removes rows or columns that are entirely missing.
#' \code{drpconst()} removes columns that hold a single distinct
#' value. The counterparts of \code{janitor::remove_empty()} and
#' \code{janitor::remove_constant()}. Use them after reading a spreadsheet
#' export, which often carries blank padding rows, empty columns and
#' columns that repeat one value (a year, a jurisdiction) on every row.
#'
#' @details
#' A constant column carries no information and breaks anything that scales
#' by variance, so it is worth removing -- but it is also a FINDING. A
#' column that was informative in the pinned capsule and is constant in a
#' fresh fetch means the source changed, so check
#' [cpsdrft()] before deleting it and
#' moving on.
#'
#' \code{drpempty()} removes all-\code{NA} columns first, then all-\code{NA}
#' rows among the remaining columns, and resets the row names. An empty
#' string is a value, not missing. \code{drpconst()} counts the distinct
#' non-missing values of each column (with \code{naasval = TRUE},
#' \code{NA} counts as a value), so an all-\code{NA} column is also dropped
#' by default. Neither function modifies anything in place.
#'
#' Errors: \code{data} not a data frame (or with missing or duplicated names);
#' \code{which} other than \code{"rows"} and/or \code{"cols"}.
#'
#' @param data A data frame.
#' @param which \code{"rows"}, \code{"cols"}, or both (the
#'   default, \code{c("rows", "cols")}).
#' @param naasval Logical: treat \code{NA} as a distinct
#'   value, so a column of \code{NA}s plus one real value counts as two
#'   (default \code{FALSE}).
#' @return The data frame, with the offending rows or columns removed. The
#'   names of the columns that were dropped are attached as the
#'   \code{"dropped"} attribute (a character vector, empty when none); dropped
#'   rows are not listed.
#' @seealso
#' [profcols()], which reports
#' \code{n_distinct} without removing anything.
#' @examples
#' df <- data.frame(
#'   keep = c(1, 2, NA),
#'   allna = c(NA, NA, NA),
#'   constant = c(7, 7, 7),
#'   stringsAsFactors = FALSE
#' )
#'
#' drpempty(df)
#' attr(drpempty(df), "dropped")
#'
#' drpconst(df)
#' attr(drpconst(df), "dropped")
#'
#' # Rows only.
#' drpempty(data.frame(a = c(1, NA), b = c(2, NA)), which = "rows")
#'
#' # A column of NAs plus one value is constant by default, and not when
#' # NA is treated as a value of its own.
#' x <- data.frame(v = c(NA, NA, 5))
#' ncol(drpconst(x))
#' ncol(drpconst(x, naasval = TRUE))
#'
#' # only data frames
#' try(drpempty(c(1, NA)))
#' @name drp
#' @export
drpempty <- function(data, which = c("rows", "cols")) {
  if (!is.data.frame(data)) stop("`data` must be a data frame", call. = FALSE)
  .rmbl_df_names(data)
  which <- .rmbl_arg(which, c("rows", "cols"), several = TRUE)
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

#' @rdname drp
#' @export
drpconst <- function(data, naasval = FALSE) {
  if (!is.data.frame(data)) stop("`data` must be a data frame", call. = FALSE)
  .rmbl_df_names(data)
  if (ncol(data) == 0L) {
    attr(data, "dropped") <- character(0)
    return(data)
  }
  const <- vapply(data, function(v) {
    u <- if (isTRUE(naasval)) unique(v) else unique(v[!is.na(v)])
    length(u) <= 1L
  }, logical(1))
  dropped <- names(data)[const]
  out <- data[, !const, drop = FALSE]
  attr(out, "dropped") <- dropped
  out
}

#' Tidy the column names of an ingested table
#'
#' Converts column names to a consistent, syntactically valid form:
#' transliterated to ASCII, non-alphanumerics collapsed to a single
#' separator, and duplicates disambiguated with a numeric suffix. The
#' counterpart of \code{janitor::clean_names()}. Use it right after reading
#' an open-data file, so the rest of the script can refer to columns without
#' backticks.
#'
#' @details
#' Open-data extracts arrive with names like
#' \code{"Total Population (2021)"} and \code{"\% change"}, which need
#' backticks everywhere and break silently when a re-release renames
#' \code{"\% change"} to \code{"\% Change"} or adds a trailing space.
#' Normalising once at ingestion makes the schema stable against that.
#'
#' The steps, in order: transliterate to ASCII (\code{iconv(...,
#' "ASCII//TRANSLIT")}, keeping the original where that fails); replace
#' \code{\%} by \code{pct}, \code{&} by \code{and} and \code{#} by \code{n}
#' as words; split camelCase at a lower-to-upper boundary; turn every run of
#' other characters into one word break; an empty name becomes \code{x};
#' join the words in the chosen case; prefix \code{x} to a name starting
#' with a digit; and give repeated names the suffixes \code{<sep>2},
#' \code{<sep>3}, ... in order of appearance (the first keeps its name).
#' The transliteration depends on the platform's iconv, so an accented
#' letter may come out slightly differently on different systems.
#'
#' Record the mapping in the capsule manifest. Cleaning names changes what
#' a downstream script must refer to, so an unrecorded cleaning is itself a
#' reproducibility hazard -- the returned object carries the original names
#' in its \code{"orignms"} attribute for exactly that.
#'
#' @param data A data frame, or a character vector of names.
#' @param case \code{"snake"} (default, \code{total_pop}), \code{"lower_camel"}
#'   (\code{totalPop}), \code{"upper_camel"} (\code{TotalPop}),
#'   \code{"screaming_snake"} (\code{TOTAL_POP}), or \code{"none"} to normalise
#'   separators only and keep the letters' case.
#' @param sep Separator, a string, used between words for \code{"snake"},
#'   \code{"screaming_snake"} and \code{"none"}, and before the number that
#'   disambiguates a duplicate in every case (default \code{"_"}).
#' @return For a data frame, the data frame with new names and an
#'   \code{"orignms"} attribute (character, the names before cleaning);
#'   for a character vector, the cleaned character vector.
#' @examples
#' clncolnms(c("Total  Population (2021)", "% change",
#'                      "Ville / City", "dup", "dup"))
#'
#' # Applied to a data frame, with the original names retained.
#' df <- data.frame(`Total Pop` = 1:2, `% change` = 3:4,
#'                  check.names = FALSE)
#' cleaned <- clncolnms(df)
#' names(cleaned)
#' attr(cleaned, "orignms")
#'
#' # Other cases.
#' clncolnms(c("Total Pop"), case = "lower_camel")
#' clncolnms(c("Total Pop"), case = "upper_camel")
#' clncolnms(c("Total Pop"), case = "screaming_snake")
#'
#' # a different separator, and a name that starts with a digit
#' clncolnms(c("2021 count", "Rate per 1000"), sep = ".")
#'
#' # an unknown case is an error
#' try(clncolnms("a b", case = "kebab"))
#' @export
clncolnms <- function(data, case = c("snake", "lower_camel",
                                              "upper_camel",
                                              "screaming_snake", "none"),
                               sep = "_") {
  .rmbl_no_fn(data = data)
  case <- .rmbl_arg(case)
  sep <- .rmbl_text1(sep, "sep")
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
    attr(data, "orignms") <- original
    return(data)
  }
  out
}

.rmbl_capitalise <- function(w) {
  if (length(w) == 0L) return(character(0))
  paste0(toupper(substring(w, 1L, 1L)), tolower(substring(w, 2L)))
}
