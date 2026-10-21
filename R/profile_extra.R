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
#' @param data A data frame.
#' @param maxpat Maximum patterns to return, most
#'   frequent first, one positive whole number (default 20).
#' @return A data frame of class \code{bricklayer_missingness}, one row per pattern:
#'   \code{pattern} (character, \code{.}
#'   for present and \code{X} for missing, in column order), \code{nrows}
#'   (integer), \code{pctrows} (numeric, percent of all rows),
#'   \code{n_missing} (integer, columns missing in that pattern) and
#'   \code{columns} (character, their names comma-separated, \code{""} for the
#'   complete pattern). Carries the column order as the \code{"columns"}
#'   attribute.
#' @seealso [profcols()] for
#' per-column rates.
#' @examples
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
  if (!is.data.frame(data)) stop("misspat: `data` must be a data frame", call. = FALSE)
  .rmbl_df_names(data)
  if (ncol(data) == 0L) {
    stop("misspat: `data` has no columns", call. = FALSE)
  }
  maxpat <- .rmbl_num(maxpat, "maxpat", integer = TRUE)
  if (length(maxpat) != 1L || is.na(maxpat) ||
    maxpat < 1L) {
    stop("`maxpat` must be a single positive integer", call. = FALSE)
  }
  n <- nrow(data)
  if (n == 0L) {
    out <- data.frame(
      pattern = character(0), n_rows = integer(0),
      pctrows = numeric(0), n_missing = integer(0),
      columns = character(0), stringsAsFactors = FALSE
    )
    attr(out, "columns") <- names(data)
    class(out) <- c("bricklayer_missingness", "data.frame")
    return(out)
  }

  m <- vapply(data, is.na, logical(n))
  if (is.null(dim(m))) m <- matrix(m, nrow = n)
  codes <- apply(m, 1L, function(r) {
    paste0(ifelse(r, "X", "."),
      collapse = ""
    )
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
        paste(names(data)[flags], collapse = ", ")
      } else {
        ""
      },
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  attr(out, "columns") <- names(data)
  class(out) <- c("bricklayer_missingness", "data.frame")
  out
}

#' @export
print.bricklayer_missingness <- function(x, ...) {
  if (.rmbl_needs_cols(x, c(
    "pattern", "n_rows", "pctrows", "n_missing",
    "columns"
  ))) {
    return(invisible(x))
  }
  cat(.rmbl_rule("Missingness patterns"), "\n")
  cols <- attr(x, "columns")
  cat("  columns, in pattern order: ", paste(cols, collapse = ", "),
    "\n\n",
    sep = ""
  )
  df <- as.data.frame(unclass(x), stringsAsFactors = FALSE)
  attr(df, "columns") <- NULL
  df$pctrows <- formatC(df$pctrows, format = "f", digits = 1)
  print(df, row.names = FALSE)
  cat(.rmbl_rule(), "\n")
  invisible(x)
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
#' @param data A data frame; non-numeric columns are ignored.
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
#' @examples
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
topcors <- function(data, n = 10L, meth = c(
                               "spearman",
                               "pearson"
                             ),
                             minabs = 0) {
  meth <- .rmbl_arg(meth)
  if (!is.data.frame(data)) stop("topcors: `data` must be a data frame", call. = FALSE)
  .rmbl_df_names(data)
  num <- names(data)[vapply(data, is.numeric, logical(1))]
  if (length(num) < 2L) {
    stop("topcors: need at least two numeric columns to correlate", call. = FALSE)
  }
  n <- .rmbl_num(n, "n", integer = TRUE)
  if (length(n) != 1L || is.na(n) || n < 1L) {
    stop("`n` must be a single positive integer", call. = FALSE)
  }
  minabs <- .rmbl_num(minabs, "minabs")
  if (length(minabs) != 1L || is.na(minabs) || minabs < 0 ||
    minabs > 1) {
    stop("`minabs` must be a single value in [0, 1]", call. = FALSE)
  }

  pairs <- utils::combn(num, 2L)
  pg <- blprog("correlations", ncol(pairs))
  on.exit(pg$done(), add = TRUE)
  vals <- vapply(seq_len(ncol(pairs)), function(j) {
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
  }, 0)

  out <- data.frame(
    x = pairs[1L, ], y = pairs[2L, ], correlation = vals,
    abscor = abs(vals), stringsAsFactors = FALSE
  )
  out <- out[!is.na(out$correlation) & out$abscor >= minabs, ,
    drop = FALSE
  ]
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
  cat(.rmbl_rule(paste0("Top correlations (", attr(x, "method"), ")")), "\n")
  if (nrow(x) == 0L) {
    cat("  (none above the threshold)\n")
    cat(.rmbl_rule(), "\n")
    return(invisible(x))
  }
  df <- as.data.frame(unclass(x), stringsAsFactors = FALSE)
  attr(df, "method") <- NULL
  # a signed bar makes the direction and strength readable at a glance
  df$plot <- vapply(x$correlation, function(r) {
    k <- as.integer(round(abs(r) * 10))
    bar <- strrep("#", k)
    if (r < 0) {
      paste0(formatC(bar, width = 10), "|", strrep(" ", 10))
    } else {
      paste0(strrep(" ", 10), "|", formatC(bar, width = -10))
    }
  }, character(1))
  df$correlation <- formatC(df$correlation, format = "f", digits = 3)
  df$abscor <- NULL
  print(df, row.names = FALSE)
  cat(.rmbl_rule(), "\n")
  invisible(x)
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
#' not compared. Rows follow the order of \code{a}'s packages, then
#' \code{b}'s new ones.
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
#'   \code{"changed"}; no rows when nothing differs).
#' @seealso
#' [capenv()],
#' [mkmnf()]
#' @examples
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
  pull <- function(x, what) {
    if (is.list(x) && !is.null(x$environment)) x <- x$environment
    if (!is.list(x) || is.data.frame(x) || is.null(names(x))) {
      stop("`a` and `b` must be environment records or manifests",
        call. = FALSE
      )
    }
    x[[what]]
  }
  pkgs <- function(x) {
    p <- pull(x, "packages")
    if (is.null(p)) {
      return(character(0))
    }
    v <- vapply(p, function(z) as.character(z)[1L], character(1))
    stats::setNames(v, names(p))
  }

  ra <- as.character(pull(a, "r_version"))
  rb <- as.character(pull(b, "r_version"))
  pa <- as.character(pull(a, "platform"))
  pb <- as.character(pull(b, "platform"))
  ka <- pkgs(a)
  kb <- pkgs(b)

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
      package = nm, a = va, b = vb, change = change,
      stringsAsFactors = FALSE
    )
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  pkg_df <- if (length(rows)) {
    do.call(rbind, rows)
  } else {
    data.frame(
      package = character(0), a = character(0), b = character(0),
      change = character(0), stringsAsFactors = FALSE
    )
  }
  rownames(pkg_df) <- NULL

  r_diff <- if (!identical(ra, rb)) c(a = ra, b = rb) else NULL
  p_diff <- if (!identical(pa, pb)) c(a = pa, b = pb) else NULL

  out <- list(
    identical = is.null(r_diff) && is.null(p_diff) &&
      nrow(pkg_df) == 0L,
    r_version = r_diff, platform = p_diff, packages = pkg_df
  )
  class(out) <- c("bricklayer_env_diff", "list")
  out
}

#' @export
format.bricklayer_env_diff <- function(x, ...) {
  g <- .rmbl_glyphs()
  lines <- c(
    .rmbl_rule("Environment diff"),
    paste0("  ", if (isTRUE(x$identical)) {
      paste0(g$ok, " environments match")
    } else {
      paste0(g$bad, " environments differ")
    }),
    ""
  )
  if (!is.null(x$r_version)) {
    lines <- c(lines, .rmbl_kv(list("R version" = sprintf(
      "%s -> %s",
      x$r_version[["a"]], x$r_version[["b"]]
    ))))
  }
  if (!is.null(x$platform)) {
    lines <- c(lines, .rmbl_kv(list(platform = sprintf(
      "%s -> %s",
      x$platform[["a"]], x$platform[["b"]]
    ))))
  }
  if (nrow(x$packages) == 0L) {
    return(c(lines, "  no package differences", .rmbl_rule()))
  }
  lines <- c(lines, sprintf(
    "  %d package difference(s):",
    nrow(x$packages)
  ), "")
  rows <- sprintf(
    "  %-24s %-12s %-12s %s", x$packages$package,
    ifelse(is.na(x$packages$a), g$dash, x$packages$a),
    ifelse(is.na(x$packages$b), g$dash, x$packages$b),
    x$packages$change
  )
  c(lines, rows, .rmbl_rule())
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_env_diff
print.bricklayer_env_diff <- .rmbl_print_via_format
