# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Outliers and the shape of missingness. Both answer "which rows should
# I look at before trusting this", which per-column summaries cannot.

#' Multivariate outliers by Mahalanobis distance
#'
#' @description
#' Finds the rows of a numeric table that are unusual as a combination of
#' values, not just on one variable at a time, and gives each row a
#' distance, a p-value and an outlier flag. Use it before modelling to find
#' records that are probably data-entry or linkage errors.
#'
#' @details
#' Ranks rows by how far they sit from the centre of the data ONCE THE
#' CORRELATIONS ARE ACCOUNTED FOR, which is what a per-column check cannot
#' do: a row can be unremarkable on every variable separately and still be
#' impossible jointly -- a person 1.5 m tall weighing 140 kg is inside both
#' marginal ranges and outside the cloud.
#'
#' With centre \eqn{c} and scatter matrix \eqn{S}, the squared distance of
#' row \eqn{x} is \deqn{d^2 = (x - c)^\top S^{-1} (x - c).}
#' Under multivariate normality the squared distance is chi-square on
#' `p` degrees of freedom (the number of numeric columns), which gives the
#' p-value and the cut-off.
#'
#' `robust = TRUE` centres each column on its median and scales it by its
#' MAD (\code{cmad()}, the 1.4826-scaled median absolute deviation;
#' a column whose MAD is zero falls back to its standard deviation), then
#' takes \eqn{S} as the sample covariance of the standardised data.
#' `robust = FALSE` uses the column means and the sample covariance. The
#' robust centre and scales resist outliers; the correlation shape in
#' \eqn{S} is still a classical estimate, so this is not a high-breakdown
#' estimator such as the minimum covariance determinant. The choice
#' matters more than it sounds: outliers inflate the very covariance used
#' to judge them, so with several of them the classical distance hides
#' exactly the rows it is meant to find (the masking effect).
#'
#' Exactly collinear columns are refused rather than repaired: the distance
#' is undefined there, and flooring the covariance's eigenvalues to make it
#' invertible would return numbers governed by the floor rather than by the
#' data. Drop the redundant column first --
#' [topcors()] will identify it.
#'
#' Errors: `data` neither a data frame nor a matrix; no numeric columns;
#' no more complete rows than columns; collinear columns (smallest
#' eigenvalue of \eqn{S} at most \eqn{10^{-8}} times the largest); `alpha`
#' outside (0, 1). A progress indicator is shown in an interactive session.
#'
#' @param data A data frame or numeric matrix; non-numeric
#' columns are dropped. Rows with any missing value are skipped, and
#' reported as `NA`.
#' @param alpha Significance level for the `outlier` flag
#' (default 0.001, deliberately strict: at 0.05 one row in twenty is
#' flagged by construction).
#' @param robust Use the median/MAD centre and scale (default
#' `TRUE`) .
#' @return A data frame of class `bricklayer_outliers` with
#' `row`, `distance` (the square root of the squared Mahalanobis
#' distance), `p_value`, `logpvalue` (the log of the chi-square upper
#' tail, which keeps its information where `p_value` underflows to 0) and
#' `outlier` (logical), ordered by descending distance, with skipped rows
#' (`NA` distance) last. `row` is the row number in `data`. The attributes
#' `robust` and `alpha` record the settings. The print method shows the
#' number of flagged rows and the ten most distant.
#' @references Mahalanobis PC (1936). On the generalised distance in
#' statistics. *Proceedings of the National Institute of Sciences of
#' India* 2(1), 49--55.
#' @seealso
#' [ctkyfnc()] for the per-column
#' version, [rulemad()] to turn
#' it into a validation rule.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' set.seed(1)
#' n <- 200
#' df <- data.frame(height = stats::rnorm(n, 170, 10))
#' df$weight <- df$height * 0.5 + stats::rnorm(n, 0, 5)
#'
#' # A row that is ordinary on each variable but unlikely jointly:
#' # short and heavy.
#' df[1, ] <- list(height = 155, weight = 100)
#'
#' out <- mahaoutl(df)
#' head(out, 3)
#'
#' # It is flagged, although both values lie inside the other rows' ranges.
#' out$row[1] == 1
#' range(df$height[-1])
#' range(df$weight[-1])
#'
#' # A cluster of bad rows drags the mean toward itself; the median and
#' # MAD move less, so the robust distance of such a row is the larger.
#' bad <- df
#' bad[2:21, ] <- list(height = 150, weight = 110)
#' dclassical <- mahaoutl(bad, robust = FALSE)
#' drobust <- mahaoutl(bad, robust = TRUE)
#' dclassical$distance[dclassical$row == 2] < drobust$distance[drobust$row == 2]
#'
#' # A duplicated column has no distance defined, and is refused.
#' dup <- df
#' dup$height2 <- dup$height
#' try(mahaoutl(dup))
#' @export
#' @srrstats {G2.7} Accepts a data frame or a numeric matrix (a matrix goes
#'   through as.data.frame); subclasses of data.frame are accepted by
#'   inheritance.
#' @srrstats {G3.1} robust = TRUE (median/MAD) or FALSE (means and sample
#'   covariance); mtchdid also has covm = "pooled"/"full".
#' @srrstats {G3.1a} Both options are shown in @examples and in the
#'   missingness-and-outliers.Rmd and describe.Rmd vignettes.
#' @srrstats {G5.8d} No more complete rows than columns and collinear columns
#'   are refused (test-eda.R:270, test-edge-cases.R:121).
mahaoutl <- function(data, alpha = 0.001, robust = TRUE) {
  if (is.matrix(data)) {
    data <- as.data.frame(data)
  }
  if (!is.data.frame(data)) {
    stop(
      "mahaoutl: `data` must be a data frame or a numeric matrix",
      call. = FALSE
    )
  }
  .rmbl_flag1(robust, "robust")
  inp <- .rmbl_maha_input(data, alpha)
  X <- inp$X
  p <- ncol(X)
  alpha <- inp$alpha
  ok <- inp$ok
  Xc <- X[ok, , drop = FALSE]
  pg <- blprog("Mahalanobis distances", 0)
  on.exit(pg$done(), add = TRUE)
  pg$update(
    info = sprintf("centring %s rows", format(nrow(Xc), big.mark = ","))
  )

  zs <- .rmbl_maha_std(Xc, robust)
  Z <- zs$Z
  S <- zs$S
  # Check the rank BEFORE repairing the covariance. .rmbl_make_pd floors
  # the eigenvalues, which would make an exactly singular S invertible
  # and hand back distances that are an artifact of the floor rather
  # than a property of the data. Collinear columns have no Mahalanobis
  # distance, and saying so beats inventing one.
  pg$update(info = "covariance")
  .rmbl_maha_rank(S)
  S <- .rmbl_make_pd(S, 1e-8) # positive definite by construction, so invertible
  S_inv <- solve(S)
  pg$update(info = "distances")
  d2 <- rowSums((Z %*% S_inv) * Z)
  out <- .rmbl_maha_table(d2, ok, p, alpha)
  rownames(out) <- NULL
  attr(out, "robust") <- robust
  attr(out, "alpha") <- alpha
  class(out) <- c("bricklayer_outliers", "data.frame")
  out
}

#' @export
format.bricklayer_outliers <- function(x, digits = 4L, ...) {
  rob <- if (isTRUE(attr(x, "robust"))) "robust" else "classical"
  title <- paste0("Mahalanobis outliers (", rob, ")")
  need <- c("row", "distance", "p_value", "outlier")
  fb <- .rmbl_df_fallback(x, title, need, digits)
  if (!is.null(fb)) {
    return(fb)
  }
  g <- .rmbl_glyphs()
  n_out <- sum(x$outlier, na.rm = TRUE)
  d <- .rmbl_plain(x, c("row", "distance", "p_value", "logpvalue", "outlier"))
  d <- d[order(-d$distance, na.last = TRUE), , drop = FALSE]
  .rmbl_res_block(
    title,
    facts = list(
      Verdict = sprintf(
        "%s %d of %d rows beyond alpha = %s",
        if (n_out > 0L) g$warn else g$ok,
        n_out,
        nrow(x),
        format(attr(x, "alpha"))
      ),
      `Rows not scored` = if (anyNA(x$distance)) sum(is.na(x$distance))
    ),
    tables = list(`Largest distances first` = d),
    reading = .rmbl_maha_reading(d, attr(x, "alpha")),
    notes = paste(
      "The distance measures how far a row is from the centre of the data",
      "once the columns' scales and correlations are allowed for; the",
      "p-value is from the chi-square distribution it would follow without",
      "outliers, and logpvalue its natural log, for rows far in the tail."
    ),
    digits = digits,
    maxrows = 10L
  )
}

#' Runs of consecutive missing values
#'
#' @description
#' Finds the maximal stretches of consecutive `NA` in each column,
#' with where each begins and how long it is.
#'
#' Row order carries meaning in a capsule far more often than people allow
#' for -- a time series, an ordered export, a paginated download -- and a
#' long unbroken run of missingness means something different from the same
#' count scattered about. A run says an instrument was down, a page failed
#' to fetch, or a period was never collected; scattered gaps say individual
#' records failed. The rate cannot distinguish them.
#'
#' @details
#' Each column's missingness indicator \code{is.na(x)} is run-length
#' encoded with \code{rle()}; every run of `TRUE` with length at least
#' `minrun` is reported. Rows are taken in their current order, so sort
#' the data by time (or by download order) first. A list column counts an
#' element as missing only when \code{is.na()} says so. Errors: `data` not a
#' data frame or without columns, or with duplicated or empty names;
#' `minrun` not a positive whole number.
#'
#' @param data A data frame, in the row order that carries meaning.
#' @param minrun Whole number, default 2: report only runs at least this
#' long (a run of 1 is an isolated gap).
#' @return A data frame of class `bricklayer_runs` with `column`
#' (character), `start` and `end` (integer row numbers, inclusive) and
#' `length` (integer), longest first and then by column name. Zero rows
#' when there are no qualifying runs.
#' @seealso
#' [misspat()] for which
#' columns are missing together,
#' [misssmry()] for the rates.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # One long outage and two isolated gaps, with the same total count.
#' df <- data.frame(
#'   outage = c(1, 2, NA, NA, NA, NA, 7, 8),
#'   scattered = c(1, NA, 3, 4, NA, 6, NA, NA)
#' )
#' sum(is.na(df$outage)) == sum(is.na(df$scattered))
#'
#' missruns(df)
#'
#' # Isolated gaps too, by lowering the threshold.
#' missruns(df, minrun = 1)
#'
#' # A complete column has no runs.
#' missruns(data.frame(x = 1:5))
#'
#' try(missruns(df, minrun = 0))
#' @export
missruns <- function(data, minrun = 2L) {
  if (!is.data.frame(data)) {
    stop("missruns: `data` must be a data frame", call. = FALSE)
  }
  .rmbl_df_names(data)
  if (ncol(data) == 0L) {
    stop("missruns: `data` has no columns", call. = FALSE)
  }
  minrun <- .rmbl_num(minrun, "minrun", integer = TRUE)
  if (length(minrun) != 1L || is.na(minrun) || minrun < 1L) {
    stop("`minrun` must be a single positive integer", call. = FALSE)
  }
  rows <- list()
  for (nm in names(data)) {
    rows[[length(rows) + 1L]] <- .rmbl_miss_runs_col(data[[nm]], nm, minrun)
  }
  out <- if (length(rows)) {
    do.call(rbind, rows)
  } else {
    data.frame(
      column = character(0),
      start = integer(0),
      end = integer(0),
      length = integer(0),
      stringsAsFactors = FALSE
    )
  }
  if (nrow(out) > 0L) {
    out <- out[order(-out$length, out$column), , drop = FALSE]
  }
  rownames(out) <- NULL
  class(out) <- c("bricklayer_runs", "data.frame")
  out
}

#' @export
format.bricklayer_runs <- function(x, digits = 4L, ...) {
  title <- "Runs of consecutive missing values"
  need <- c("column", "start", "end", "length")
  fb <- .rmbl_df_fallback(x, title, need, digits)
  if (!is.null(fb)) {
    return(fb)
  }
  .rmbl_res_block(
    title,
    facts = list(
      Runs = nrow(x),
      `Columns with runs` = length(unique(x$column)),
      `Longest run` = if (nrow(x)) max(x$length)
    ),
    tables = if (nrow(x)) .rmbl_plain(x, need),
    reading = if (nrow(x)) {
      paste(
        "Long runs of missing rows usually mean a source stopped reporting",
        "for a while, not values missing at random."
      )
    } else {
      "(none)"
    },
    digits = digits,
    maxrows = 30L
  )
}

#' Text map of where the missing values are
#'
#' @description
#' Draws the missingness of a whole table as a grid, one character per cell
#' block -- a console counterpart of `visdat::vis_miss()` that needs
#' no graphics device, so it works over SSH, in a log, and inside a
#' capsule's plain-text summary.
#'
#' Rows are binned so the map fits `height` lines; a block is drawn at
#' the shade its missing proportion falls in. Seeing the table at once is
#' the point: a diagonal band, a block of rows, or a single ragged column
#' are all instantly recognisable shapes that a column of percentages is
#' not.
#'
#' @details
#' The rows are split into at most `height` consecutive blocks of nearly
#' equal size; each map line is one block, labelled with its first row
#' number, and each map column is one column of `data`. A cell's shade is
#' its block's proportion missing rounded to the nearest quarter: blank (0),
#' light, medium, dark, full (1). Where the console cannot show Unicode the
#' shades are \code{" .-+#"}. Column names are written vertically above the
#' map, cut to `width` characters. A table with no rows prints
#' \code{"(no rows)"}. Errors: `data` not a data frame or without columns;
#' `height` not a positive whole number.
#'
#' @param data A data frame whose missing cells are drawn as a grid.
#' @param height Whole number, default 20: the maximum number of lines
#' (row blocks) in the map.
#' @param width Whole number, default 12: column names are cut to this many
#' characters in the vertical legend.
#' @return A character vector of the map's lines, invisibly; the map is
#' printed with \code{cat()} as a side effect.
#' @seealso
#' [misspat()],
#' [missruns()]
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' set.seed(1)
#' df <- data.frame(
#'   complete = 1:100,
#'   block = c(rep(NA, 30), 31:100),
#'   scattered = ifelse(stats::runif(100) < 0.3, NA, 1),
#'   mostlygone = c(1:10, rep(NA, 90))
#' )
#' missgrid(df)
#'
#' # a coarser map with short labels
#' missgrid(df, height = 5, width = 4)
#'
#' try(missgrid(df, height = 0))
#' @export
missgrid <- function(data, height = 20L, width = 12L) {
  if (!is.data.frame(data)) {
    stop("missgrid: `data` must be a data frame", call. = FALSE)
  }
  .rmbl_df_names(data)
  if (ncol(data) == 0L) {
    stop("missgrid: `data` has no columns", call. = FALSE)
  }
  height <- .rmbl_num(height, "height", integer = TRUE)
  if (length(height) != 1L || is.na(height) || height < 1L) {
    stop("`height` must be a single positive integer", call. = FALSE)
  }
  width <- .rmbl_scalar(width, "width", 1, 10000, integer = TRUE)
  n <- nrow(data)
  shades <- if (.rmbl_unicode_ok()) {
    c(" ", "\u2591", "\u2592", "\u2593", "\u2588")
  } else {
    c(" ", ".", "-", "+", "#")
  }
  nm <- substring(names(data), 1L, width)

  if (n == 0L) {
    lines <- c(.rmbl_rule("Missingness map"), "  (no rows)", .rmbl_rule())
    cat(lines, sep = "\n")
    return(invisible(lines))
  }
  rows <- .rmbl_miss_grid_rows(data, min(height, n), shades)
  lines <- c(
    .rmbl_rule("Missingness map"),
    .rmbl_miss_grid_header(nm),
    rows,
    "",
    paste0(
      "  legend: '",
      shades[1L],
      "' none  '",
      shades[length(shades)],
      "' all missing"
    ),
    .rmbl_rule()
  )
  cat(lines, sep = "\n")
  cat("\n")
  invisible(lines)
}

#' The standardised data and their correlation, for mahaoutl().
#' @param Xc The complete rows.
#' @param robust As for mahaoutl().
#' @return A list: `Z` (the standardised rows) and `S` (their covariance).
#' @noRd
.rmbl_maha_std <- function(Xc, robust) {
  if (isTRUE(robust)) {
    centre <- apply(Xc, 2L, cmed)
    scales <- apply(Xc, 2L, cmad)
    # A zero MAD means no robust spread to divide by; fall back to the
    # classical scale for that column rather than dividing by zero.
    cls <- apply(Xc, 2L, stats::sd)
    alt <- ifelse(cls > 0, cls, 1)
    scales <- ifelse(scales > 0, scales, alt)
    Z <- sweep(sweep(Xc, 2L, centre, "-"), 2L, scales, "/")
    # correlation of the robustly standardised data, so the shape comes
    # from the bulk rather than from the tails
    S <- ccovm(Z)
  } else {
    centre <- colMeans(Xc)
    # the distance is affine invariant, so standardising by the classical
    # scale changes nothing except the conditioning: columns of wildly
    # different scale (1e160 against 1) are no longer read as collinear
    # the range, not the standard deviation: squaring 1e160 overflows
    scales <- apply(Xc, 2L, function(v) diff(range(v)))
    scales <- ifelse(is.finite(scales) & scales > 0, scales, 1)
    Z <- sweep(sweep(Xc, 2L, centre, "-"), 2L, scales, "/")
    S <- ccovm(Z)
  }
  list(Z = Z, S = S)
}

#' Stops when a covariance is singular: collinear columns have no
#' Mahalanobis distance.
#' @param S The covariance.
#' @return Nothing useful.
#' @noRd
.rmbl_maha_rank <- function(S) {
  ev <- tryCatch(
    eigen(S, symmetric = TRUE, only.values = TRUE)$values,
    error = function(e) NULL
  )
  if (
    is.null(ev) ||
      min(ev) <= 1e-8 * max(abs(ev), .Machine$double.eps)
  ) {
    stop(
      "the columns are collinear, so no Mahalanobis distance is ",
      "defined. Drop the redundant column(s) -- drpconst() and ",
      "topcors() will find them.",
      call. = FALSE
    )
  }
  invisible(NULL)
}

#' The table of mahaoutl(): one row per row of the data, the largest
#' distances first.
#' @param d2 The squared distances of the complete rows.
#' @param ok Which rows are complete.
#' @param p The number of columns.
#' @param alpha As for mahaoutl().
#' @return A data frame.
#' @noRd
.rmbl_maha_table <- function(d2, ok, p, alpha) {
  out <- data.frame(
    row = which(ok),
    distance = sqrt(d2),
    p_value = stats::pchisq(d2, p, lower.tail = FALSE),
    logpvalue = stats::pchisq(d2, p, lower.tail = FALSE, log.p = TRUE),
    stringsAsFactors = FALSE
  )
  out$outlier <- out$p_value < alpha
  skipped <- which(!ok)
  if (length(skipped) > 0L) {
    out <- rbind(
      out,
      data.frame(
        row = skipped,
        distance = NA_real_,
        p_value = NA_real_,
        logpvalue = NA_real_,
        outlier = NA,
        stringsAsFactors = FALSE
      )
    )
  }
  out[order(-out$distance, na.last = TRUE), , drop = FALSE]
}

#' The runs of missing values of one column, for missruns().
#' @param v The column scanned for runs of missing values.
#' @param nm The column's name, for the result.
#' @param minrun As for missruns().
#' @return A data frame of its runs, or NULL when it has none.
#' @noRd
.rmbl_miss_runs_col <- function(v, nm, minrun) {
  na <- is.na(v)
  if (!any(na)) {
    return(NULL)
  }
  r <- rle(na)
  ends <- cumsum(r$lengths)
  starts <- ends - r$lengths + 1L
  sel <- r$values & r$lengths >= minrun
  if (!any(sel)) {
    return(NULL)
  }
  data.frame(
    column = nm,
    start = starts[sel],
    end = ends[sel],
    length = r$lengths[sel],
    stringsAsFactors = FALSE
  )
}

#' The rows of a missingness map: one per bin of rows, a shade per column.
#' @param data The data frame, binned into rows of the grid.
#' @param bins The number of bins.
#' @param shades The shades, from none to all missing.
#' @return A character vector of lines.
#' @noRd
.rmbl_miss_grid_rows <- function(data, bins, shades) {
  n <- nrow(data)
  edges <- unique(as.integer(round(seq(0, n, length.out = bins + 1L))))
  rows <- character(0)
  for (i in seq_len(length(edges) - 1L)) {
    idx <- (edges[i] + 1L):edges[i + 1L]
    cells <- vapply(
      data,
      function(v) {
        frac <- mean(is.na(v[idx]))
        shades[1L + as.integer(round(frac * (length(shades) - 1L)))]
      },
      character(1)
    )
    rows <- c(
      rows,
      sprintf(
        "  %6s %s",
        paste0(edges[i] + 1L, ""),
        paste(cells, collapse = "")
      )
    )
  }
  rows
}

#' The numeric columns of mahaoutl()'s data, its `alpha` and its complete
#' rows, checked.
#' @param data,alpha As for mahaoutl().
#' @return A list: `X` (the numeric matrix), `alpha` and `ok` (the complete
#'   rows).
#' @noRd
.rmbl_maha_input <- function(data, alpha) {
  num <- vapply(data, is.numeric, logical(1))
  if (!any(num)) {
    stop("`data` has no numeric columns", call. = FALSE)
  }
  X <- as.matrix(data[, num, drop = FALSE])
  storage.mode(X) <- "double"
  p <- ncol(X)
  alpha <- .rmbl_num(alpha, "alpha")
  if (length(alpha) != 1L || is.na(alpha) || alpha <= 0 || alpha >= 1) {
    stop(
      "mahaoutl: `alpha` must be a single value strictly inside (0, 1)",
      call. = FALSE
    )
  }
  ok <- stats::complete.cases(X)
  if (sum(ok) < p + 1L) {
    stop(
      "need more complete rows than columns to estimate a covariance",
      call. = FALSE
    )
  }
  list(X = X, alpha = alpha, ok = ok)
}

#' A vertical legend of the column names, so a wide table still reads.
#' @param nm The column names, cut to their width.
#' @return A character vector, one line per character of the longest name.
#' @noRd
.rmbl_miss_grid_header <- function(nm) {
  vapply(
    seq_len(max(nchar(nm))),
    function(k) {
      paste0(
        "  ",
        strrep(" ", 6L),
        " ",
        paste(substring(nm, k, k), collapse = "")
      )
    },
    character(1)
  )
}
