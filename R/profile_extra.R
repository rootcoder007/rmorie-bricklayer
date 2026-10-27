# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Description rather than validation: the summaries a person reads before
# deciding whether a capsule is worth trusting.

#' Which columns are missing together
#'
#' Counts the distinct PATTERNS of missingness across rows -- which
#' combination of columns is missing in each row -- rather than the
#' per-column rates [profcols()] reports. Use it
#' before deciding how
#' to handle gaps (drop rows, impute, model separately), because the right
#' choice depends on whether columns are missing together.
#'
#' @details
#' The distinction decides what to do about the gaps. Two columns each 30%
#' missing at random need different handling from two columns 30% missing
#' in THE SAME rows -- the second is one structural gap (a join that
#' failed, a form section nobody filled in) and often means those rows
#' should be dropped or modelled separately, while the first does not. A
#' per-column rate cannot tell the two apart; this can.
#'
#' Each row is coded as a string with one character per column, \code{X}
#' where \code{is.na()} is true and \code{.} otherwise, and the codes are
#' tabulated. Patterns are sorted by descending frequency and the first
#' \code{maxpat} kept, so \code{pctrows} may not sum to 100 when
#' patterns are cut. A frame with no rows gives an empty table. The work is
#' one pass over the rows; very wide frames give long codes.
#'
#' Errors: \code{data} not a data frame, without columns, or with missing or
#' duplicated names; \code{maxpat} not one positive whole number.
#'
#' @param data A data frame whose missingness patterns are counted.
#' @param maxpat Maximum patterns to return, most
#'   frequent first, one positive whole number (default 20).
#' @return A data frame of class \code{bricklayer_missingness}, one row per
#'   pattern: \code{pattern} (character, \code{.} for present and \code{X} for
#'   missing, in column order), \code{nrows} (integer), \code{pctrows} (numeric,
#'   percent of all rows), \code{n_missing} (integer, columns missing in that
#'   pattern) and \code{columns} (character, their names comma-separated,
#'   \code{""} for the complete pattern). Carries the column order as the
#'   \code{"columns"} attribute.
#' @seealso [profcols()] for
#' per-column rates.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # Two columns missing in the SAME rows: one structural gap.
#' structural <- data.frame(
#'   id = 1:10,
#'   a = c(rep(NA, 3), 4:10),
#'   b = c(rep(NA, 3), 4:10)
#' )
#' misspat(structural)
#'
#' # The same per-column rates, but missing independently.
#' scattered <- data.frame(
#'   id = 1:10,
#'   a = c(rep(NA, 3), 4:10),
#'   b = c(1:7, rep(NA, 3))
#' )
#' misspat(scattered)
#'
#' # A complete frame has exactly one pattern.
#' misspat(data.frame(x = 1:3, y = 4:6))
#'
#' # keep only the most common pattern
#' misspat(scattered, maxpat = 1)
#'
#' # a frame without columns has no patterns
#' try(misspat(data.frame()))
#' @export
misspat <- function(data, maxpat = 20L) {
  if (!is.data.frame(data)) {
    stop("misspat: `data` must be a data frame", call. = FALSE)
  }
  .rmbl_df_names(data)
  if (ncol(data) == 0L) {
    stop("misspat: `data` has no columns", call. = FALSE)
  }
  maxpat <- .rmbl_num(maxpat, "maxpat", integer = TRUE)
  if (length(maxpat) != 1L || is.na(maxpat) || maxpat < 1L) {
    stop("`maxpat` must be a single positive integer", call. = FALSE)
  }
  out <- if (nrow(data) == 0L) {
    data.frame(
      pattern = character(0),
      n_rows = integer(0),
      pctrows = numeric(0),
      n_missing = integer(0),
      columns = character(0),
      stringsAsFactors = FALSE
    )
  } else {
    .bl_miss_rows(data, maxpat)
  }
  attr(out, "columns") <- names(data)
  class(out) <- c("bricklayer_missingness", "data.frame")
  out
}

#' @export
print.bricklayer_missingness <- function(x, ...) {
  if (
    .rmbl_needs_cols(
      x,
      c(
        "pattern",
        "n_rows",
        "pctrows",
        "n_missing",
        "columns"
      )
    )
  ) {
    return(invisible(x))
  }
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
format.bricklayer_missingness <- function(x, ...) {
  df <- as.data.frame(unclass(x), stringsAsFactors = FALSE)
  attr(df, "columns") <- NULL
  if (!all(c("pattern", "n_rows", "pctrows") %in% names(df))) {
    return(utils::capture.output(print(df)))
  }
  df$pctrows <- formatC(df$pctrows, format = "f", digits = 1)
  .rmbl_stat_block(
    "Missingness patterns",
    facts = list(
      Columns = paste0("in pattern order: ", toString(attr(x, "columns"))),
      Patterns = nrow(df),
      Rows = sum(df$n_rows)
    ),
    table = df,
    reading = paste(
      "Each pattern marks the columns missing together; a few large",
      "patterns point to a cause worth naming before rows are dropped."
    )
  )
}

#' Strongest pairwise correlations in a data frame
#'
#' Ranks the numeric column pairs by the strength of their association and
#' returns the strongest, so a wide table's structure can be read without
#' squinting at a correlation matrix. Use it on a new data set to find
#' near-duplicate columns, derived columns and the relationships worth a
#' closer look.
#'
#' @details
#' Spearman is the default deliberately. Pearson measures LINEAR
#' association only, so it understates a relationship that is perfectly
#' monotone but curved, and a single outlier can manufacture or destroy it.
#' On data you have not yet inspected -- which is the situation this
#' function is for -- the rank correlation is the safer question to ask.
#'
#' Non-numeric columns are ignored. Each pair uses the rows where both
#' values are present; a pair with fewer than three such rows, or with a
#' constant column, has no correlation and is left out. Pairs are ranked by
#' absolute correlation, those below \code{minabs} dropped, and the first
#' \code{n} returned. [cortbl()] gives every
#' pair, with the
#' number of rows behind each. A progress bar is drawn on stderr for many
#' pairs unless \code{options(morie.quiet = TRUE)}.
#'
#' Errors: \code{data} not a data frame; fewer than two numeric columns;
#' \code{n} not one positive whole number; \code{minabs} not one number in
#' \eqn{[0, 1]}; an invalid \code{meth}.
#'
#' @param data A data frame; its numeric pairs are ranked by correlation.
#' @param n Number of pairs to return, one positive whole number (default
#'   10).
#' @param meth \code{"spearman"} (default) or \code{"pearson"}.
#' @param minabs Report only pairs whose absolute correlation reaches this,
#'   a number in \eqn{[0, 1]} (default 0).
#' @return A data frame of class \code{c("bricklayer_correlations",
#'   "data.frame")} with \code{x} and \code{y} (character, column names),
#'   \code{correlation} (numeric) and \code{abscor} (numeric),
#'   strongest first, at most \code{n} rows; the method is in
#'   \code{attr(, "method")}. The print method draws a signed bar per pair.
#' @seealso
#' [cspr()],
#' [ccovm()],
#' [cortbl()]
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' set.seed(1)
#' n <- 200
#' df <- data.frame(
#'   a = stats::rnorm(n),
#'   b = stats::rnorm(n),
#'   grade = sample(letters[1:3], n, TRUE)
#' )
#' df$c <- df$a * 2 + stats::rnorm(n, sd = 0.1) # strongly related to a
#' df$d <- exp(df$a) # monotone but curved
#'
#' topcors(df)
#'
#' # The curved pair is ranked correctly by Spearman and understated by
#' # Pearson, which is why Spearman is the default.
#' tc <- topcors(df, meth = "spearman")
#' tc[tc$x == "a" & tc$y == "d", "correlation"]
#' tp <- topcors(df, meth = "pearson")
#' tp[tp$x == "a" & tp$y == "d", "correlation"]
#'
#' # Filter to the pairs worth looking at, and keep the top two.
#' topcors(df, n = 2, minabs = 0.5)
#'
#' # a threshold above 1 is an error
#' try(topcors(df, minabs = 2))
#' @export
topcors <- function(
  data,
  n = 10L,
  meth = c(
    "spearman",
    "pearson"
  ),
  minabs = 0
) {
  meth <- .rmbl_arg(meth)
  if (!is.data.frame(data)) {
    stop("topcors: `data` must be a data frame", call. = FALSE)
  }
  .rmbl_df_names(data)
  num <- names(data)[vapply(data, is.numeric, logical(1))]
  if (length(num) < 2L) {
    stop(
      "topcors: need at least two numeric columns to correlate",
      call. = FALSE
    )
  }
  n <- .rmbl_num(n, "n", integer = TRUE)
  if (length(n) != 1L || is.na(n) || n < 1L) {
    stop("`n` must be a single positive integer", call. = FALSE)
  }
  minabs <- .bl_minabs(minabs)

  pairs <- utils::combn(num, 2L)
  vals <- .bl_pair_cors(data, pairs, meth)
  out <- data.frame(
    x = pairs[1L, ],
    y = pairs[2L, ],
    correlation = vals,
    abscor = abs(vals),
    stringsAsFactors = FALSE
  )
  out <- out[!is.na(out$correlation) & out$abscor >= minabs, , drop = FALSE]
  out <- out[order(-out$abscor), , drop = FALSE]
  out <- utils::head(out, n)
  rownames(out) <- NULL
  attr(out, "method") <- meth
  class(out) <- c("bricklayer_correlations", "data.frame")
  out
}

#' @export
print.bricklayer_correlations <- function(x, ...) {
  if (.rmbl_needs_cols(x, c("x", "y", "correlation", "abscor"))) {
    return(invisible(x))
  }
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
format.bricklayer_correlations <- function(x, ...) {
  title <- paste0("Top correlations (", attr(x, "method"), ")")
  if (nrow(x) == 0L) {
    return(.rmbl_stat_block(title, notes = "(none above the threshold)"))
  }
  df <- as.data.frame(unclass(x), stringsAsFactors = FALSE)
  attr(df, "method") <- NULL
  # a signed bar makes the direction and strength readable at a glance
  df$plot <- vapply(x$correlation, .bl_cor_bar, character(1))
  df$correlation <- formatC(df$correlation, format = "f", digits = 3)
  df$abscor <- NULL
  .rmbl_stat_block(
    title,
    facts = list(Method = attr(x, "method"), Pairs = nrow(df)),
    table = df,
    reading = paste(
      "The pairs most strongly associated, strongest first; a correlation",
      "near 1 or -1 often means one column is derived from the other."
    )
  )
}

#' Compare two captured environments
#'
#' Reports what changed between the environment captured by one run and
#' another: the R version, the platform, and every package whose version
#' differs, was added, or disappeared. Use it when a result does not
#' reproduce, to see first whether the software around it changed.
#'
#' @details
#' This is the question a failed reproduction actually raises. A manifest
#' records the environment; comparing two manifests by eye across a few
#' hundred packages does not scale, and the one line that matters -- a
#' dependency that moved a minor version -- is exactly what gets missed.
#'
#' Versions are compared as strings. A package recorded in \code{b} but not
#' in \code{a} (or recorded with an \code{NA} version in \code{a}) is
#' \code{"added"}; the reverse is \code{"removed"}. The operating-system
#' string, the capture time and the random number generator settings are
#' not compared. Any other field present in only one record, or different
#' in the two, is named in \code{fields} and makes them differ. Rows follow
#' the order of \code{a}'s packages, then \code{b}'s new ones.
#'
#' Error: \code{a} or \code{b} that is not a list.
#'
#' @param a,b Environment records from [capenv()], or whole
#'   manifests (such
#'   as [mkmnf()] returns) that hold an \code{environment} element.
#' @return A list of class \code{c("bricklayer_env_diff", "list")}:
#'   \code{identical} (logical, \code{TRUE} when R version, platform and all
#'   package versions agree), \code{r_version} (a named length-2 character
#'   vector \code{c(a = , b = )} when they differ, else \code{NULL}),
#'   \code{platform} (likewise), and \code{packages} (a data frame with
#'   character columns \code{package}, \code{a}, \code{b} and \code{change},
#'   where \code{change} is \code{"added"}, \code{"removed"} or
#'   \code{"changed"}; no rows when nothing differs), and \code{fields}
#'   (the names of any other fields that differ, \code{character(0)} when
#'   none).
#' @seealso
#' [capenv()],
#' [mkmnf()]
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' a <- capenv(c("stats", "utils"))
#' b <- a
#'
#' # An environment matches itself.
#' envdiff(a, b)$identical
#'
#' # Stage a moved dependency, an added one and a newer R.
#' b$packages[["stats"]] <- "0.0.0"
#' b$packages[["tools"]] <- "4.9.0"
#' b$r_version <- "9.9.9"
#' d <- envdiff(a, b)
#' d$packages
#' d$r_version
#' d
#'
#' # Whole manifests are accepted, not just the environment block.
#' m <- mkmnf(list(run = "demo"))
#' envdiff(m, m)$identical
#'
#' # anything other than a record is refused
#' try(envdiff("4.5.1", a))
#' @export
envdiff <- function(a, b) {
  ra <- as.character(.bl_env_pull(a, "r_version"))
  rb <- as.character(.bl_env_pull(b, "r_version"))
  pa <- as.character(.bl_env_pull(a, "platform"))
  pb <- as.character(.bl_env_pull(b, "platform"))
  ka <- .bl_env_pkgs(a)
  kb <- .bl_env_pkgs(b)

  pkg_df <- .bl_env_pkg_diff(ka, kb)

  r_diff <- if (identical(ra, rb)) NULL else c(a = ra, b = rb)
  p_diff <- if (identical(pa, pb)) NULL else c(a = pa, b = pb)
  # a field in only one record was ignored and the two called identical
  fld <- .bl_env_fields(a, b)

  out <- list(
    identical = is.null(r_diff) &&
      is.null(p_diff) &&
      nrow(pkg_df) == 0L &&
      !length(fld),
    r_version = r_diff,
    platform = p_diff,
    packages = pkg_df,
    fields = fld
  )
  class(out) <- c("bricklayer_env_diff", "list")
  out
}

#' @export
format.bricklayer_env_diff <- function(x, ...) {
  g <- .rmbl_glyphs()
  pk <- x$packages
  .rmbl_stat_block(
    "Environment diff",
    facts = .bl_env_diff_facts(x, g),
    table = if (nrow(pk)) {
      data.frame(
        package = pk$package,
        a = ifelse(is.na(pk$a), g$dash, pk$a),
        b = ifelse(is.na(pk$b), g$dash, pk$b),
        change = pk$change,
        stringsAsFactors = FALSE
      )
    },
    reading = if (isTRUE(x$identical)) {
      "The two records describe the same R, platform and package versions."
    } else {
      "The records differ: a result may not reproduce until these agree."
    },
    notes = if (nrow(pk)) {
      sprintf("%d package difference(s)", nrow(pk))
    } else {
      "no package differences"
    }
  )
}

#' Counts the rows of each missingness pattern, the commonest first.
#' @param data A data frame with at least one row.
#' @param maxpat The most patterns kept.
#' @return A data frame, one row per pattern.
#' @noRd
.bl_miss_rows <- function(data, maxpat) {
  n <- nrow(data)
  m <- vapply(data, is.na, logical(n))
  if (is.null(dim(m))) {
    m <- matrix(m, nrow = n)
  }
  codes <- apply(m, 1L, function(r) {
    paste(ifelse(r, "X", "."), collapse = "")
  })
  tab <- sort(table(codes), decreasing = TRUE)
  keep <- utils::head(names(tab), maxpat)

  rows <- lapply(keep, function(code) {
    flags <- strsplit(code, "", fixed = TRUE)[[1L]] == "X"
    data.frame(
      pattern = code,
      n_rows = as.integer(tab[[code]]),
      pctrows = 100 * as.integer(tab[[code]]) / n,
      n_missing = sum(flags),
      columns = if (any(flags)) {
        toString(names(data)[flags])
      } else {
        ""
      },
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

#' Checks the smallest absolute correlation topcors() keeps.
#' @param minabs The value given.
#' @return It, as a number.
#' @noRd
.bl_minabs <- function(minabs) {
  minabs <- .rmbl_num(minabs, "minabs")
  if (length(minabs) != 1L || is.na(minabs) || minabs < 0 || minabs > 1) {
    stop("`minabs` must be a single value in [0, 1]", call. = FALSE)
  }
  minabs
}

#' Correlates each pair of columns on their complete rows, for topcors().
#' @param data The data frame holding the columns in `pairs`.
#' @param pairs The pairs, one per column of a two-row matrix.
#' @param meth "spearman" or "pearson".
#' @return One correlation per pair, NA for fewer than three complete rows.
#' @noRd
.bl_pair_cors <- function(data, pairs, meth) {
  pg <- blprog("correlations", ncol(pairs))
  on.exit(pg$done(), add = TRUE)
  vals <- vapply(
    seq_len(ncol(pairs)),
    function(j) {
      pg$update(j - 1L, sprintf("pair %d/%d", j, ncol(pairs)))
      a <- data[[pairs[1L, j]]]
      b <- data[[pairs[2L, j]]]
      ok <- !is.na(a) & !is.na(b)
      if (sum(ok) < 3L) {
        return(NA_real_)
      }
      if (identical(meth, "spearman")) {
        cspr(a[ok], b[ok])
      } else {
        ccorr(a[ok], b[ok])
      }
    },
    0
  )
  vals
}

#' The facts of an environment diff: the verdict, then the R version, the
#' platform and the other fields when they differ.
#' @param x An environment diff from envdiff().
#' @param g The glyphs from .rmbl_glyphs().
#' @return A named list.
#' @noRd
.bl_env_diff_facts <- function(x, g) {
  arrow <- function(v) {
    if (!is.null(v)) sprintf("%s -> %s", v[["a"]], v[["b"]])
  }
  list(
    Status = if (isTRUE(x$identical)) {
      paste0(g$ok, " environments match")
    } else {
      paste0(g$bad, " environments differ")
    },
    `R version` = arrow(x$r_version),
    Platform = arrow(x$platform),
    `other fields` = if (length(x$fields)) toString(x$fields)
  )
}

#' A signed text bar for one correlation: left of the bar for negative,
#' right for positive, one mark per 0.1.
#' @param r The correlation.
#' @return One string of 21 characters.
#' @noRd
.bl_cor_bar <- function(r) {
  k <- as.integer(round(abs(r) * 10))
  bar <- strrep("#", k)
  if (r < 0) {
    paste0(formatC(bar, width = 10), "|", strrep(" ", 10))
  } else {
    paste0(strrep(" ", 10), "|", formatC(bar, width = -10))
  }
}

#' Reads one field of an environment record or a manifest's.
#' @param x An environment record, or a manifest carrying one.
#' @param what The field to take from `x`.
#' @return The field's value.
#' @noRd
.bl_env_pull <- function(x, what) {
  .bl_env_rec(x)[[what]]
}

#' The environment record itself: `x`, or a manifest's environment element.
#' @param x An environment record, or a manifest carrying one.
#' @return The record, a named list.
#' @noRd
.bl_env_rec <- function(x) {
  if (is.list(x) && !is.null(x$environment)) {
    x <- x$environment
  }
  if (!is.list(x) || is.data.frame(x) || is.null(names(x))) {
    stop(
      "`a` and `b` must be environment records or manifests",
      call. = FALSE
    )
  }
  x
}

#' The fields other than R version, platform and packages that differ.
#'
#' The operating system, capture time and RNG settings are left out, as
#' documented; any other field in only one record, or different, is named.
#' @param a,b Environment records, or manifests carrying one.
#' @return A character vector of field names.
#' @noRd
.bl_env_fields <- function(a, b) {
  skip <- c(
    "r_version",
    "platform",
    "packages",
    "os",
    "captured_utc",
    "rng_kind",
    "rng_seeded"
  )
  ra <- .bl_env_rec(a)
  rb <- .bl_env_rec(b)
  nm <- setdiff(union(names(ra), names(rb)), skip)
  nm[!vapply(nm, function(n) identical(ra[[n]], rb[[n]]), NA)]
}

#' The package versions of an environment record, named by package.
#' @param x An environment record, or a manifest carrying one.
#' @return A named character vector.
#' @noRd
.bl_env_pkgs <- function(x) {
  p <- .bl_env_pull(x, "packages")
  if (is.null(p)) {
    return(character(0))
  }
  v <- vapply(p, function(z) as.character(z)[1L], character(1))
  stats::setNames(v, names(p))
}

#' The packages added, removed or changed between two environments.
#' @param ka,kb The package versions of each, named by package.
#' @return A data frame: package, a, b and change.
#' @noRd
.bl_env_pkg_diff <- function(ka, kb) {
  all_names <- union(names(ka), names(kb))
  rows <- lapply(all_names, function(nm) {
    va <- if (nm %in% names(ka)) ka[[nm]] else NA_character_
    vb <- if (nm %in% names(kb)) kb[[nm]] else NA_character_
    if (identical(va, vb)) {
      return(NULL)
    }
    change <- if (is.na(va)) {
      "added"
    } else if (is.na(vb)) {
      "removed"
    } else {
      "changed"
    }
    data.frame(
      package = nm,
      a = va,
      b = vb,
      change = change,
      stringsAsFactors = FALSE
    )
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  pkg_df <- if (length(rows)) {
    do.call(rbind, rows)
  } else {
    data.frame(
      package = character(0),
      a = character(0),
      b = character(0),
      change = character(0),
      stringsAsFactors = FALSE
    )
  }
  rownames(pkg_df) <- NULL
  pkg_df
}
