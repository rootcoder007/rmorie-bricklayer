# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Outliers and the shape of missingness. Both answer "which rows should
# I look at before trusting this", which per-column summaries cannot.

#' Multivariate outliers by Mahalanobis distance
#'
#' Ranks rows by how far they sit from the centre of the data ONCE THE
#' CORRELATIONS ARE ACCOUNTED FOR, which is what a per-column check
#' cannot do: a row can be unremarkable on every variable separately and
#' still be impossible jointly -- a person 1.5 m tall weighing 140 kg is
#' inside both marginal ranges and outside the cloud.
#'
#' Under multivariate normality the squared distance is chi-square on `p`
#' degrees of freedom, which gives the p-value and the cut-off.
#'
#' `robust = TRUE` centres on the coordinate-wise median and scales by a
#' MAD-based covariance instead of the mean and sample covariance. This
#' matters more than it sounds: outliers inflate the very covariance used
#' to judge them, so with several of them the classical distance hides
#' exactly the rows it is meant to find (the masking effect).
#'
#' @param data A data frame or numeric matrix; non-numeric columns are
#'   dropped. Rows with any missing value are skipped, and reported as
#'   `NA`.
#' @param alpha Significance level for the `outlier` flag (default
#'   0.001, deliberately strict: at 0.05 one row in twenty is flagged by
#'   construction).
#' @param robust Use the median/MAD centre and scale (default `TRUE`).
#' @return A data frame of class `bricklayer_outliers` with `row`,
#'   `distance` (the square root of the squared Mahalanobis distance),
#'   `p_value` and `outlier`, ordered by descending distance.
#' @references Mahalanobis PC (1936). On the generalised distance in
#'   statistics. *Proceedings of the National Institute of Sciences of
#'   India* 2(1), 49--55.
#' @seealso [core_tukey_fences()] for the per-column version,
#'   [rule_within_n_mads()] to turn it into a validation rule.
#' @examples
#' set.seed(1)
#' n <- 200
#' df <- data.frame(height = stats::rnorm(n, 170, 10))
#' df$weight <- df$height * 0.5 + stats::rnorm(n, 0, 5)
#'
#' # A row that is ordinary on each variable but impossible jointly.
#' df[1, ] <- list(height = 150, weight = 140)
#'
#' out <- mahalanobis_outliers(df)
#' head(out, 3)
#'
#' # It is flagged, even though neither value is a marginal outlier.
#' out$row[1] == 1
#' range(df$height)
#' range(df$weight)
#'
#' # The classical version can be fooled by the outliers it should find.
#' mahalanobis_outliers(df, robust = FALSE)$distance[1] <
#'   mahalanobis_outliers(df, robust = TRUE)$distance[1]
#' @export
mahalanobis_outliers <- function(data, alpha = 0.001, robust = TRUE) {
  if (is.matrix(data)) data <- as.data.frame(data)
  if (!is.data.frame(data)) {
    stop("`data` must be a data frame or a numeric matrix", call. = FALSE)
  }
  num <- vapply(data, is.numeric, logical(1))
  if (!any(num)) stop("`data` has no numeric columns", call. = FALSE)
  X <- as.matrix(data[, num, drop = FALSE])
  storage.mode(X) <- "double"
  p <- ncol(X)
  if (p < 1L) stop("`data` has no numeric columns", call. = FALSE)
  alpha <- as.numeric(alpha)
  if (length(alpha) != 1L || is.na(alpha) || alpha <= 0 || alpha >= 1) {
    stop("`alpha` must be a single value strictly inside (0, 1)",
         call. = FALSE)
  }
  ok <- stats::complete.cases(X)
  if (sum(ok) < p + 1L) {
    stop("need more complete rows than columns to estimate a covariance",
         call. = FALSE)
  }
  Xc <- X[ok, , drop = FALSE]

  if (isTRUE(robust)) {
    centre <- apply(Xc, 2L, core_median)
    scales <- apply(Xc, 2L, core_mad)
    # A zero MAD means no robust spread to divide by; fall back to the
    # classical scale for that column rather than dividing by zero.
    cls <- apply(Xc, 2L, stats::sd)
    scales <- ifelse(scales > 0, scales, ifelse(cls > 0, cls, 1))
    Z <- sweep(sweep(Xc, 2L, centre, "-"), 2L, scales, "/")
    # correlation of the robustly standardised data, so the shape comes
    # from the bulk rather than from the tails
    S <- core_cov(Z)
  } else {
    centre <- colMeans(Xc)
    scales <- rep(1, p)
    Z <- sweep(Xc, 2L, centre, "-")
    S <- core_cov(Z)
  }
  S <- .rmbl_make_pd(S, 1e-8)
  S_inv <- tryCatch(solve(S), error = function(e) NULL)
  if (is.null(S_inv)) {
    stop("the columns are collinear, so no Mahalanobis distance is defined",
         call. = FALSE)
  }
  d2 <- rowSums((Z %*% S_inv) * Z)

  out <- data.frame(row = which(ok), distance = sqrt(d2),
                    p_value = 1 - core_gamma_cdf(p / 2, d2 / 2),
                    stringsAsFactors = FALSE)
  out$outlier <- out$p_value < alpha
  skipped <- which(!ok)
  if (length(skipped) > 0L) {
    out <- rbind(out, data.frame(row = skipped, distance = NA_real_,
                                 p_value = NA_real_, outlier = NA,
                                 stringsAsFactors = FALSE))
  }
  out <- out[order(-out$distance, na.last = TRUE), , drop = FALSE]
  rownames(out) <- NULL
  attr(out, "robust") <- robust
  attr(out, "alpha") <- alpha
  class(out) <- c("bricklayer_outliers", "data.frame")
  out
}

#' @export
print.bricklayer_outliers <- function(x, ...) {
  g <- .rmbl_glyphs()
  n_out <- sum(x$outlier, na.rm = TRUE)
  cat(.rmbl_rule(paste0("Mahalanobis outliers (",
                        if (isTRUE(attr(x, "robust"))) "robust" else
                          "classical", ")")), "\n")
  cat(sprintf("  %s %d of %d rows beyond alpha = %s\n",
              if (n_out > 0L) g$warn else g$ok, n_out, nrow(x),
              format(attr(x, "alpha"))))
  cat("\n")
  df <- as.data.frame(unclass(x), stringsAsFactors = FALSE)
  attr(df, "robust") <- NULL
  attr(df, "alpha") <- NULL
  df <- utils::head(df, 10L)
  df$distance <- formatC(df$distance, format = "f", digits = 2)
  df$p_value <- .rmbl_fmt_p(x$p_value[seq_len(nrow(df))])
  print(df, row.names = FALSE)
  if (nrow(x) > 10L) {
    cat(sprintf("  ... %d more rows\n", nrow(x) - 10L))
  }
  cat(.rmbl_rule(), "\n")
  invisible(x)
}

#' Runs of consecutive missing values
#'
#' Finds the maximal stretches of consecutive `NA` in each column, with
#' where each begins and how long it is.
#'
#' Row order carries meaning in a capsule far more often than people
#' allow for -- a time series, an ordered export, a paginated download --
#' and a long unbroken run of missingness means something different from
#' the same count scattered about. A run says an instrument was down, a
#' page failed to fetch, or a period was never collected; scattered gaps
#' say individual records failed. The rate cannot distinguish them.
#'
#' @param data A data frame.
#' @param min_run Report only runs at least this long (default 2, since
#'   a run of 1 is an isolated gap).
#' @return A data frame of class `bricklayer_runs` with `column`,
#'   `start`, `end` and `length`, longest first. Zero rows when there
#'   are no qualifying runs.
#' @seealso [missingness_pattern()] for which columns are missing
#'   together, [missingness_summary()] for the rates.
#' @examples
#' # One long outage and two isolated gaps, with the same total count.
#' df <- data.frame(
#'   outage = c(1, 2, NA, NA, NA, NA, 7, 8),
#'   scattered = c(1, NA, 3, 4, NA, 6, NA, NA)
#' )
#' sum(is.na(df$outage)) == sum(is.na(df$scattered))
#'
#' missing_runs(df)
#'
#' # Isolated gaps too, by lowering the threshold.
#' missing_runs(df, min_run = 1)
#'
#' # A complete column has no runs.
#' missing_runs(data.frame(x = 1:5))
#' @export
missing_runs <- function(data, min_run = 2L) {
  if (!is.data.frame(data)) stop("`data` must be a data frame", call. = FALSE)
  if (ncol(data) == 0L) stop("`data` has no columns", call. = FALSE)
  min_run <- as.integer(min_run)
  if (length(min_run) != 1L || is.na(min_run) || min_run < 1L) {
    stop("`min_run` must be a single positive integer", call. = FALSE)
  }
  rows <- list()
  for (nm in names(data)) {
    na <- is.na(data[[nm]])
    if (!any(na)) next
    r <- rle(na)
    ends <- cumsum(r$lengths)
    starts <- ends - r$lengths + 1L
    sel <- r$values & r$lengths >= min_run
    if (!any(sel)) next
    rows[[length(rows) + 1L]] <- data.frame(
      column = nm, start = starts[sel], end = ends[sel],
      length = r$lengths[sel], stringsAsFactors = FALSE)
  }
  out <- if (length(rows)) do.call(rbind, rows) else
    data.frame(column = character(0), start = integer(0), end = integer(0),
               length = integer(0), stringsAsFactors = FALSE)
  if (nrow(out) > 0L) out <- out[order(-out$length, out$column), ,
                                 drop = FALSE]
  rownames(out) <- NULL
  class(out) <- c("bricklayer_runs", "data.frame")
  out
}

#' @export
print.bricklayer_runs <- function(x, ...) {
  cat(.rmbl_rule("Runs of consecutive missing values"), "\n")
  if (nrow(x) == 0L) {
    cat("  (none)\n")
    cat(.rmbl_rule(), "\n")
    return(invisible(x))
  }
  print(as.data.frame(unclass(x), stringsAsFactors = FALSE), row.names = FALSE)
  cat(.rmbl_rule(), "\n")
  invisible(x)
}

#' Text map of where the missing values are
#'
#' Draws the missingness of a whole table as a grid, one character per
#' cell block -- a console counterpart of `visdat::vis_miss()` that needs
#' no graphics device, so it works over SSH, in a log, and inside a
#' capsule's plain-text summary.
#'
#' Rows are binned so the map fits `height` lines; a block is drawn at
#' the shade its missing proportion falls in. Seeing the table at once is
#' the point: a diagonal band, a block of rows, or a single ragged column
#' are all instantly recognisable shapes that a column of percentages
#' is not.
#'
#' @param data A data frame.
#' @param height Maximum rows in the map (default 20).
#' @param width Maximum characters per column label (default 12).
#' @return A character vector of the map's lines, invisibly; printed as a
#'   side effect.
#' @seealso [missingness_pattern()], [missing_runs()]
#' @examples
#' set.seed(1)
#' df <- data.frame(
#'   complete = 1:100,
#'   block = c(rep(NA, 30), 31:100),
#'   scattered = ifelse(stats::runif(100) < 0.3, NA, 1),
#'   mostly_gone = c(1:10, rep(NA, 90))
#' )
#' missingness_map(df)
#' @export
missingness_map <- function(data, height = 20L, width = 12L) {
  if (!is.data.frame(data)) stop("`data` must be a data frame", call. = FALSE)
  if (ncol(data) == 0L) stop("`data` has no columns", call. = FALSE)
  height <- as.integer(height)
  if (length(height) != 1L || is.na(height) || height < 1L) {
    stop("`height` must be a single positive integer", call. = FALSE)
  }
  n <- nrow(data)
  shades <- if (.rmbl_unicode_ok()) {
    c(" ", "░", "▒", "▓", "█")
  } else {
    c(" ", ".", "-", "+", "#")
  }
  nm <- substring(names(data), 1L, width)

  if (n == 0L) {
    lines <- c(.rmbl_rule("Missingness map"), "  (no rows)", .rmbl_rule())
    cat(lines, sep = "\n")
    return(invisible(lines))
  }
  bins <- min(height, n)
  edges <- unique(as.integer(round(seq(0, n, length.out = bins + 1L))))
  rows <- character(0)
  for (i in seq_len(length(edges) - 1L)) {
    idx <- (edges[i] + 1L):edges[i + 1L]
    cells <- vapply(data, function(v) {
      frac <- mean(is.na(v[idx]))
      shades[1L + as.integer(round(frac * (length(shades) - 1L)))]
    }, character(1))
    rows <- c(rows, sprintf("  %6s %s", paste0(edges[i] + 1L, ""),
                            paste(cells, collapse = "")))
  }
  # a vertical legend of the column names, so a wide table still reads
  header <- vapply(seq_len(max(nchar(nm))), function(k) {
    paste0("  ", strrep(" ", 6L), " ",
           paste(substring(nm, k, k), collapse = ""))
  }, character(1))
  lines <- c(.rmbl_rule("Missingness map"), header, rows,
             "",
             paste0("  legend: '", shades[1L], "' none  '",
                    shades[length(shades)], "' all missing"),
             .rmbl_rule())
  cat(lines, sep = "\n")
  cat("\n")
  invisible(lines)
}
