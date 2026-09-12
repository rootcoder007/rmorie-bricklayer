# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Description rather than validation: the summaries a person reads before
# deciding whether a capsule is worth trusting.

#' Which columns are missing together
#'
#' Counts the distinct PATTERNS of missingness across rows, rather than
#' the per-column rates [profile_columns()] reports.
#'
#' The distinction decides what to do about the gaps. Two columns each 30%
#' missing at random need different handling from two columns 30% missing
#' in THE SAME rows -- the second is one structural gap (a join that
#' failed, a form section nobody filled in) and often means those rows
#' should be dropped or modelled separately, while the first does not.
#' A per-column rate cannot tell the two apart; this can.
#'
#' @param data A data frame.
#' @param max_patterns Maximum patterns to return, most frequent first
#'   (default 20).
#' @return A data frame of class `bricklayer_missingness`, one row per
#'   pattern: `pattern` (a string of `.` for present and `X` for
#'   missing, in column order), `n_rows`, `pct_rows`, `n_missing`
#'   (columns missing in that pattern), and `columns` (their names).
#'   Carries the column order as the `"columns"` attribute.
#' @seealso [profile_columns()] for per-column rates.
#' @examples
#' # Two columns missing in the SAME rows: one structural gap.
#' structural <- data.frame(
#'   id = 1:10,
#'   a = c(rep(NA, 3), 4:10),
#'   b = c(rep(NA, 3), 4:10)
#' )
#' missingness_pattern(structural)
#'
#' # The same per-column rates, but missing independently.
#' scattered <- data.frame(
#'   id = 1:10,
#'   a = c(rep(NA, 3), 4:10),
#'   b = c(1:7, rep(NA, 3))
#' )
#' missingness_pattern(scattered)
#'
#' # A complete frame has exactly one pattern.
#' missingness_pattern(data.frame(x = 1:3, y = 4:6))
#' @export
missingness_pattern <- function(data, max_patterns = 20L) {
  if (!is.data.frame(data)) stop("`data` must be a data frame", call. = FALSE)
  if (ncol(data) == 0L) {
    stop("`data` has no columns", call. = FALSE)
  }
  max_patterns <- as.integer(max_patterns)
  if (length(max_patterns) != 1L || is.na(max_patterns) ||
      max_patterns < 1L) {
    stop("`max_patterns` must be a single positive integer", call. = FALSE)
  }
  n <- nrow(data)
  if (n == 0L) {
    out <- data.frame(pattern = character(0), n_rows = integer(0),
                      pct_rows = numeric(0), n_missing = integer(0),
                      columns = character(0), stringsAsFactors = FALSE)
    attr(out, "columns") <- names(data)
    class(out) <- c("bricklayer_missingness", "data.frame")
    return(out)
  }

  m <- vapply(data, is.na, logical(n))
  if (is.null(dim(m))) m <- matrix(m, nrow = n)
  codes <- apply(m, 1L, function(r) paste0(ifelse(r, "X", "."),
                                           collapse = ""))
  tab <- sort(table(codes), decreasing = TRUE)
  keep <- utils::head(names(tab), max_patterns)

  rows <- lapply(keep, function(code) {
    flags <- strsplit(code, "", fixed = TRUE)[[1L]] == "X"
    data.frame(
      pattern = code,
      n_rows = as.integer(tab[[code]]),
      pct_rows = 100 * as.integer(tab[[code]]) / n,
      n_missing = sum(flags),
      columns = if (any(flags)) {
        paste(names(data)[flags], collapse = ", ")
      } else {
        ""
      },
      stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  attr(out, "columns") <- names(data)
  class(out) <- c("bricklayer_missingness", "data.frame")
  out
}

#' @export
print.bricklayer_missingness <- function(x, ...) {
  cat(.rmbl_rule("Missingness patterns"), "\n")
  cols <- attr(x, "columns")
  cat("  columns, in pattern order: ", paste(cols, collapse = ", "),
      "\n\n", sep = "")
  df <- as.data.frame(unclass(x), stringsAsFactors = FALSE)
  attr(df, "columns") <- NULL
  df$pct_rows <- formatC(df$pct_rows, format = "f", digits = 1)
  print(df, row.names = FALSE)
  cat(.rmbl_rule(), "\n")
  invisible(x)
}

#' Strongest pairwise correlations in a data frame
#'
#' Ranks the numeric column pairs by the strength of their association,
#' so a wide table's structure can be read without squinting at a
#' correlation matrix.
#'
#' Spearman is the default deliberately. Pearson measures LINEAR
#' association only, so it understates a relationship that is perfectly
#' monotone but curved, and a single outlier can manufacture or destroy
#' it. On data you have not yet inspected -- which is the situation this
#' function is for -- the rank correlation is the safer question to ask.
#'
#' @param data A data frame; non-numeric columns are ignored.
#' @param n Number of pairs to return (default 10).
#' @param method `"spearman"` (default) or `"pearson"`.
#' @param min_abs Report only pairs whose absolute correlation reaches
#'   this (default 0).
#' @return A data frame of class `bricklayer_correlations` with `x`, `y`,
#'   `correlation` and `abs_correlation`, strongest first.
#' @seealso [core_cor_spearman()], [core_cov()]
#' @examples
#' set.seed(1)
#' n <- 200
#' df <- data.frame(
#'   a = stats::rnorm(n),
#'   b = stats::rnorm(n),
#'   grade = sample(letters[1:3], n, TRUE)
#' )
#' df$c <- df$a * 2 + stats::rnorm(n, sd = 0.1)   # strongly related to a
#' df$d <- exp(df$a)                              # monotone but curved
#'
#' top_correlations(df)
#'
#' # The curved pair is ranked correctly by Spearman and understated by
#' # Pearson, which is why Spearman is the default.
#' tc <- top_correlations(df, method = "spearman")
#' tc[tc$x == "a" & tc$y == "d", "correlation"]
#' tp <- top_correlations(df, method = "pearson")
#' tp[tp$x == "a" & tp$y == "d", "correlation"]
#'
#' # Filter to the pairs worth looking at.
#' top_correlations(df, min_abs = 0.5)
#' @export
top_correlations <- function(data, n = 10L, method = c("spearman",
                                                       "pearson"),
                             min_abs = 0) {
  method <- match.arg(method)
  if (!is.data.frame(data)) stop("`data` must be a data frame", call. = FALSE)
  num <- names(data)[vapply(data, is.numeric, logical(1))]
  if (length(num) < 2L) {
    stop("need at least two numeric columns to correlate", call. = FALSE)
  }
  n <- as.integer(n)
  if (length(n) != 1L || is.na(n) || n < 1L) {
    stop("`n` must be a single positive integer", call. = FALSE)
  }
  min_abs <- as.numeric(min_abs)
  if (length(min_abs) != 1L || is.na(min_abs) || min_abs < 0 ||
      min_abs > 1) {
    stop("`min_abs` must be a single value in [0, 1]", call. = FALSE)
  }

  pairs <- utils::combn(num, 2L)
  vals <- vapply(seq_len(ncol(pairs)), function(j) {
    a <- data[[pairs[1L, j]]]
    b <- data[[pairs[2L, j]]]
    ok <- !is.na(a) & !is.na(b)
    if (sum(ok) < 3L) return(NA_real_)
    if (identical(method, "spearman")) {
      core_cor_spearman(a[ok], b[ok])
    } else {
      core_cor(a[ok], b[ok])
    }
  }, 0)

  out <- data.frame(x = pairs[1L, ], y = pairs[2L, ], correlation = vals,
                    abs_correlation = abs(vals), stringsAsFactors = FALSE)
  out <- out[!is.na(out$correlation) & out$abs_correlation >= min_abs, ,
             drop = FALSE]
  out <- out[order(-out$abs_correlation), , drop = FALSE]
  out <- utils::head(out, n)
  rownames(out) <- NULL
  attr(out, "method") <- method
  class(out) <- c("bricklayer_correlations", "data.frame")
  out
}

#' @export
print.bricklayer_correlations <- function(x, ...) {
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
  df$abs_correlation <- NULL
  print(df, row.names = FALSE)
  cat(.rmbl_rule(), "\n")
  invisible(x)
}

#' Compare two captured environments
#'
#' Reports what changed between the environment captured by one run and
#' another: the R version, the platform, and every package whose version
#' differs, was added, or disappeared.
#'
#' This is the question a failed reproduction actually raises. A manifest
#' records the environment; comparing two manifests by eye across a few
#' hundred packages does not scale, and the one line that matters -- a
#' dependency that moved a minor version -- is exactly what gets missed.
#'
#' @param a,b Environment records from [capture_environment()], or whole
#'   manifests containing an `environment` element.
#' @return A list of class `bricklayer_env_diff`: `identical` (logical),
#'   `r_version` (a length-2 character vector when they differ, else
#'   `NULL`), `platform` (likewise), and `packages` (a data frame of
#'   `package`, `a`, `b`, `change`, where `change` is `"added"`,
#'   `"removed"` or `"changed"`).
#' @seealso [capture_environment()], [make_manifest()]
#' @examples
#' a <- capture_environment()
#' b <- a
#'
#' # An environment matches itself.
#' environment_diff(a, b)$identical
#'
#' # Stage a moved dependency and a removed one.
#' if (length(b$packages)) {
#'   nm <- names(b$packages)[1]
#'   b$packages[[nm]] <- "0.0.0"
#'   environment_diff(a, b)$packages
#' }
#'
#' # Whole manifests are accepted, not just the environment block.
#' m <- make_manifest(list(run = "demo"))
#' environment_diff(m, m)$identical
#' @export
environment_diff <- function(a, b) {
  pull <- function(x, what) {
    if (is.list(x) && !is.null(x$environment)) x <- x$environment
    if (!is.list(x)) {
      stop("`a` and `b` must be environment records or manifests",
           call. = FALSE)
    }
    x[[what]]
  }
  pkgs <- function(x) {
    p <- pull(x, "packages")
    if (is.null(p)) return(character(0))
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
    if (identical(va, vb)) return(NULL)
    change <- if (is.na(va)) "added" else if (is.na(vb)) "removed" else
      "changed"
    data.frame(package = nm, a = va, b = vb, change = change,
               stringsAsFactors = FALSE)
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  pkg_df <- if (length(rows)) do.call(rbind, rows) else
    data.frame(package = character(0), a = character(0), b = character(0),
               change = character(0), stringsAsFactors = FALSE)
  rownames(pkg_df) <- NULL

  r_diff <- if (!identical(ra, rb)) c(a = ra, b = rb) else NULL
  p_diff <- if (!identical(pa, pb)) c(a = pa, b = pb) else NULL

  out <- list(identical = is.null(r_diff) && is.null(p_diff) &&
                nrow(pkg_df) == 0L,
              r_version = r_diff, platform = p_diff, packages = pkg_df)
  class(out) <- c("bricklayer_env_diff", "list")
  out
}

#' @export
format.bricklayer_env_diff <- function(x, ...) {
  g <- .rmbl_glyphs()
  lines <- c(.rmbl_rule("Environment diff"),
             paste0("  ", if (isTRUE(x$identical))
               paste0(g$ok, " environments match") else
               paste0(g$bad, " environments differ")),
             "")
  if (!is.null(x$r_version)) {
    lines <- c(lines, .rmbl_kv(list("R version" = sprintf("%s -> %s",
      x$r_version[["a"]], x$r_version[["b"]]))))
  }
  if (!is.null(x$platform)) {
    lines <- c(lines, .rmbl_kv(list(platform = sprintf("%s -> %s",
      x$platform[["a"]], x$platform[["b"]]))))
  }
  if (nrow(x$packages) == 0L) {
    return(c(lines, "  no package differences", .rmbl_rule()))
  }
  lines <- c(lines, sprintf("  %d package difference(s):",
                            nrow(x$packages)), "")
  rows <- sprintf("  %-24s %-12s %-12s %s", x$packages$package,
                  ifelse(is.na(x$packages$a), g$dash, x$packages$a),
                  ifelse(is.na(x$packages$b), g$dash, x$packages$b),
                  x$packages$change)
  c(lines, rows, .rmbl_rule())
}

#' @rdname rmbl_print_methods
#' @export
print.bricklayer_env_diff <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}
