# Design-based estimation for complex surveys: weighted means, totals, proportions and ratios, for
# the whole population or by domain, with variances from replicate weights (bootstrap, mean
# bootstrap, jackknife, BRR, Fay's BRR) or from Taylor linearization over strata and primary
# sampling units. The domain estimates keep the whole design: a respondent outside a domain, or
# with the analysis variable missing, contributes zero to that domain's numerator and denominator
# instead of being dropped from the design, which is what makes the variance of a subgroup
# estimate correct (dropping rows understates it).

#' Describe a complex survey design
#'
#' Collects what design-based estimation needs: the final
#' weight, and either a set of replicate weights or the strata
#' and primary sampling units (PSUs) for Taylor linearization.
#' [survey_estimate()] and
#' [survey_compare()] take the result.
#'
#' Replicate variances are \eqn{v = s \sum_r (\hat\theta_r -
#' c)^2}, where \eqn{\hat\theta_r} is the estimate under
#' replicate weight \eqn{r}, \eqn{c} is the full-sample estimate
#' (`mse = TRUE`) or the mean of the replicate estimates, and
#' the scale \eqn{s} depends on how the replicates were made,
#' for \eqn{B} replicates:
#' \describe{
#'   \item{`"bootstrap"`}{\eqn{1/B}: the Rao-Wu rescaled
#'   bootstrap Statistics Canada ships with its public-use
#'   files.}
#'   \item{`"mean_bootstrap"`}{\eqn{R/B}, where each replicate
#'   weight is the mean of \eqn{R} bootstrap weights
#'   (`mean_size`). The Canadian Substance Use Survey 2023 ships
#'   1,000 mean bootstrap weights with \eqn{R = 12}; Health
#'   Canada's technical notes give the factor of 12,
#'   equivalently Fay's BRR with \eqn{\rho = 1 - 1/\sqrt{12}}.}
#'   \item{`"jk1"`}{\eqn{(B - 1)/B}, the delete-one jackknife.}
#'   \item{`"brr"`}{\eqn{1/B}, balanced repeated replication.}
#'   \item{`"fay"`}{\eqn{1/(B (1 - \rho)^2)}, Fay's BRR with
#'   coefficient `rho`.}
#'   \item{`"jkn"`}{the stratified delete-one-PSU jackknife: each
#'   replicate has its own factor \eqn{(n_h - 1)/n_h} for the
#'   \eqn{n_h} PSUs of the stratum it deletes from, given as
#'   `rscales` (passed as `"jk1"`, JKn weights overstated the
#'   standard error by 37 percent in a test design).}
#' }
#'
#' The replicate columns are only replicates: a column holding
#' the full-sample weight, the `id`, or any other column of
#' `data` is refused by name, and BRR and Fay replicates must come
#' in a Hadamard order (2, or a multiple of 4), so a stray column
#' is caught instead of being averaged in as one more replicate.
#'
#' The design's degrees of freedom (`df = "design"` in
#' [survey_estimate()]) are PSUs less strata under
#' linearization; for replicate weights, the rank of the replicate weight matrix
#' less one, as the `survey` package computes them (twelve BRR
#' half-samples of an eight-stratum design have 8, not 11), or
#' `degf` when given.
#'
#' Without replicates, the variance is the with-replacement
#' Taylor linearization: within each stratum \eqn{h} with
#' \eqn{n_h} PSUs, \eqn{(1 - f_h) n_h / (n_h - 1)} times the sum
#' of squared deviations of the PSU totals of the weighted
#' linearized values from their stratum mean, summed over strata
#' (\eqn{f_h} from `fpc`, zero without one). No strata means one
#' stratum; no PSUs means every respondent is its own PSU.
#'
#' @param data A data frame, one row per respondent.
#' @param weights The final (full-sample) weight: a column name
#'   or a numeric vector.
#' @param strata,psu Optional stratum and primary sampling unit:
#'   column names or vectors. A PSU label need only be unique
#'   within its stratum.
#' @param fpc Optional finite population correction per row: a
#'   column name or vector holding either the stratum's population
#'   count of PSUs or (all values at most 1) the sampling
#'   fraction.
#' @param replicates Optional replicate weights: a data frame or
#'   matrix with one column per replicate, or the names of
#'   replicate weight columns in `data`.
#' @param id With a `replicates` data frame, the column (present
#'   in both) that matches its rows to `data`'s; without it the
#'   rows must already be in the same order.
#' @param type How the replicates were made; see Details.
#' @param mean_size For `type = "mean_bootstrap"`, the number of
#'   bootstrap weights averaged into each replicate.
#' @param rho For `type = "fay"`, Fay's coefficient.
#' @param rscales Per-replicate factors: required for
#'   `type = "jkn"` (\eqn{(n_h - 1)/n_h} for each replicate's
#'   stratum), optional otherwise (multiplying the type's scale).
#' @param degf The design's degrees of freedom, when known (a
#'   public-use file's documentation gives them); by default
#'   computed as described in Details.
#' @param mse Centre replicate deviations on the full-sample
#'   estimate (`TRUE`) or on the mean of the replicate estimates.
#' @param lonely_psu What to do with a stratum that has a single
#'   PSU under linearization: `"fail"` (an error naming it),
#'   `"remove"` (it contributes nothing) or `"adjust"` (its PSU is
#'   centred on the mean of all PSU totals).
#' @return An object of class `rmbl_svy_design`.
#' @seealso [survey_estimate()],
#'   [survey_compare()]
#' @examples
#' set.seed(1)
#' d <- data.frame(region = rep(c("north", "south"), each = 50),
#'                 smoker = rbinom(100, 1, rep(c(0.2, 0.35), each = 50)),
#'                 w = runif(100, 50, 150))
#' # ten bootstrap replicates, made here by resampling for the example
#' reps <- replicate(10, d$w * tabulate(sample(100, replace = TRUE), 100))
#' des <- survey_design(d, weights = "w", replicates = reps, type = "bootstrap")
#' des
#' # the same data as a stratified design, variance by linearization
#' survey_design(d, weights = "w", strata = "region")
#' @export
survey_design <- function(data, weights, strata = NULL, psu = NULL, fpc = NULL, replicates = NULL,
                          id = NULL, type = c("bootstrap", "mean_bootstrap", "jk1", "jkn", "brr", "fay"),
                          mean_size = 1, rho = NULL, mse = TRUE,
                          lonely_psu = c("fail", "remove", "adjust"), rscales = NULL, degf = NULL) {
  if (!is.data.frame(data)) stop("`data` must be a data frame", call. = FALSE)
  n <- nrow(data)
  if (n < 2L) stop("`data` must have at least two rows", call. = FALSE)
  type <- match.arg(type)
  lonely_psu <- match.arg(lonely_psu)
  if (!is.logical(mse) || length(mse) != 1L || is.na(mse)) stop("`mse` must be TRUE or FALSE", call. = FALSE)
  col <- function(x, what) {
    if (is.null(x)) return(NULL)
    if (is.character(x) && length(x) == 1L && n != 1L) {
      if (!x %in% names(data)) stop(sprintf("`%s` names a column `data` does not have: %s", what, x), call. = FALSE)
      x <- data[[x]]
    }
    if (length(x) != n) stop(sprintf("`%s` must have one value per row of `data` (%d)", what, n), call. = FALSE)
    x
  }
  w <- col(weights, "weights")
  if (!is.numeric(w) || anyNA(w) || any(!is.finite(w)) || any(w < 0)) {
    stop("`weights` must be finite, non-negative and not missing", call. = FALSE)
  }
  w <- as.numeric(w)
  if (!is.null(degf) && (!is.numeric(degf) || length(degf) != 1L || is.na(degf) || degf < 1)) {
    stop("`degf` must be a number of at least 1", call. = FALSE)
  }
  # what survey_estimate() checks the data against: the same rows in the same order (only the row
  # count was checked, and the same data reordered gave a wrong answer silently)
  named <- function(x) if (is.character(x) && length(x) == 1L) x
  check <- list(rows = attr(data, "row.names"),
                cols = Filter(Negate(is.null),
                              list(weights = named(weights), strata = named(strata), psu = named(psu))))
  check$values <- lapply(check$cols, function(cn) data[[cn]])
  # every column, in order and sorted: a reordered tibble (row names always 1..n) with a vector
  # weight gave SE 13.8 for 20.2 silently (review of 46de6a9); a column changed afterwards is not
  # a reorder and passes
  # only when nothing is named: a named weight, strata or PSU column is compared by value already,
  # and hashing every column of a million-row frame on each estimate is a cost to pay only when
  # there is no other way to notice a reorder
  if (!length(check$cols)) check$digests <- .svy_column_digests(data)
  des <- list(n = n, weights = w, type = NULL, scale = NULL, mse = mse, reps = NULL, strata = NULL,
              psu = NULL, fpc = NULL, lonely_psu = lonely_psu, check = check, degf = degf)
  if (!is.null(replicates)) {
    if (!is.null(strata) || !is.null(psu) || !is.null(fpc)) {
      stop("give replicate weights or strata/PSUs, not both: the replicates already carry the design",
           call. = FALSE)
    }
    id_values <- NULL
    if (is.character(replicates)) {
      miss <- setdiff(replicates, names(data))
      if (length(miss)) {
        stop(sprintf("replicate columns not in `data`: %s", paste(utils::head(miss, 5), collapse = ", ")),
             call. = FALSE)
      }
      own <- intersect(replicates, c(if (is.character(weights) && length(weights) == 1L) weights, id))
      if (length(own)) {
        stop(sprintf("`replicates` names %s, which is not a replicate weight (the full weight or the id)",
                     paste(own, collapse = ", ")), call. = FALSE)
      }
      reps <- unname(as.list(data[replicates]))
      names(reps) <- replicates
      named <- TRUE
    } else {
      # a matrix with an extra class (a "repweights" object) was dispatched to another as.data.frame
      # method and read wrongly
      # whether the columns came with names (as.data.frame invents V1, V2, ... for a bare matrix)
      named <- !is.null(colnames(replicates)) && all(nzchar(colnames(replicates)))
      if (is.matrix(replicates)) replicates <- as.data.frame.matrix(unclass(replicates))
      if (!is.data.frame(replicates)) {
        stop("`replicates` must be a data frame, a matrix or column names", call. = FALSE)
      }
      if (!is.null(id)) {
        if (!is.character(id) || length(id) != 1L || !id %in% names(data) || !id %in% names(replicates)) {
          stop("`id` must name a column present in both `data` and `replicates`", call. = FALSE)
        }
        if (anyDuplicated(replicates[[id]])) stop("`id` repeats in `replicates`", call. = FALSE)
        m <- match(data[[id]], replicates[[id]])
        if (anyNA(m)) stop(sprintf("%d row(s) of `data` have no replicate weights", sum(is.na(m))), call. = FALSE)
        # the one id column, by position: a replicate that happens to share the id's name stays
        # (it was dropped with it, B 24 -> 23; review of 46de6a9)
        id_values <- replicates[[id]][m]
        replicates <- replicates[m, -match(id, names(replicates)), drop = FALSE]
      }
      if (nrow(replicates) != n) {
        stop(sprintf("`replicates` must have one row per row of `data` (%d)", n), call. = FALSE)
      }
      # the full weight named in `weights`, shipped beside the replicates (CSUS's bootstrap file carries
      # WGT_PUMF), is the weight and not a replicate: set aside when it is the weight. A column that
      # only carries the weight's name is refused, not dropped (a genuine replicate called "pw" went
      # silently, B 24 -> 23; review of 29a55d8, F2)
      if (is.character(weights) && length(weights) == 1L && weights %in% names(replicates)) {
        for (i in which(names(replicates) == weights)) {
          v <- replicates[[i]]
          if (!is.numeric(v) || !identical(as.numeric(v), as.numeric(w))) {
            stop(sprintf(paste("column %s of `replicates` has the full weight's name but not its values: rename",
                               "it, or give only the replicate columns"), weights), call. = FALSE)
          }
        }
        replicates <- replicates[, names(replicates) != weights, drop = FALSE]
      }
      reps <- as.list(replicates)
      if (is.null(names(reps)) || any(!nzchar(names(reps)))) names(reps) <- sprintf("V%d", seq_along(reps))
    }
    bad <- which(!vapply(reps, is.numeric, NA))
    if (length(bad)) {
      stop(sprintf("not a replicate weight: %s (not numbers); give only the replicate columns",
                   names(reps)[[bad[[1L]]]]), call. = FALSE)
    }
    reps <- lapply(reps, function(r) {
      if (anyNA(r) || any(!is.finite(r)) || any(r < 0)) {
        stop("replicate weights must be finite, non-negative and not missing", call. = FALSE)
      }
      as.numeric(r)
    })
    .svy_replicate_check(reps, w, type, data, id_values, attr(data, "row.names"), named)
    reps <- unname(reps)
    B <- length(reps)
    if (B < 2L) stop("at least two replicate weights are needed", call. = FALSE)
    if (type == "jkn" && is.null(rscales)) {
      stop("type = \"jkn\" needs `rscales`: (n_h - 1) / n_h for the stratum each replicate deletes from",
           call. = FALSE)
    }
    if (!is.null(rscales) && (!is.numeric(rscales) || length(rscales) != B || anyNA(rscales) ||
                                any(!is.finite(rscales)) || any(rscales < 0))) {
      stop(sprintf("`rscales` must be %d finite non-negative numbers, one per replicate", B), call. = FALSE)
    }
    if (type == "mean_bootstrap" &&
        (!is.numeric(mean_size) || length(mean_size) != 1L || !is.finite(mean_size) || mean_size < 1)) {
      stop("`mean_size` must be a number of at least 1", call. = FALSE)
    }
    if (type == "fay") {
      if (!is.numeric(rho) || length(rho) != 1L || !is.finite(rho) || rho < 0 || rho >= 1) {
        stop("`rho` must be a number in [0, 1) for Fay's BRR", call. = FALSE)
      }
    }
    if (type %in% c("brr", "fay") && B > 2L && B %% 4L != 0L) {
      stop(sprintf(paste("%d replicates is not a Hadamard order (2, or a multiple of 4): BRR replicates",
                         "come in those numbers, so a column that is not a replicate may be included"), B),
           call. = FALSE)
    }
    des$scale <- switch(type,
      bootstrap = 1 / B,
      mean_bootstrap = mean_size / B,
      jk1 = (B - 1) / B,
      jkn = 1,
      brr = 1 / B,
      fay = 1 / (B * (1 - rho)^2))
    des$type <- type
    des$reps <- reps
    des$mean_size <- if (type == "mean_bootstrap") mean_size
    des$rho <- if (type == "fay") rho
    des$rscales <- if (!is.null(rscales)) as.numeric(rscales)
    # the design's degrees of freedom as the survey package computes them, the rank of the replicate
    # weight matrix less one; the rank is read from the eigenvalues of its cross-product (singular
    # values within 1e-5 of the largest count), which is the B x B problem: a QR of the n x B matrix
    # took 16 s for CSUS's 36,180 x 1,000
    if (is.null(des$degf)) {
      ev <- eigen(crossprod(do.call(cbind, reps)), symmetric = TRUE, only.values = TRUE)$values
      des$degf <- sum(ev > max(ev) * 1e-10) - 1L
    }
  } else {
    s <- col(strata, "strata")
    p <- col(psu, "psu")
    if (!is.null(s) && anyNA(s)) stop("`strata` has missing values", call. = FALSE)
    if (!is.null(p) && anyNA(p)) stop("`psu` has missing values", call. = FALSE)
    s <- if (is.null(s)) rep(1L, n) else as.integer(factor(s))
    p <- if (is.null(p)) seq_len(n) else as.integer(factor(paste(s, p, sep = "\r")))
    f <- col(fpc, "fpc")
    if (!is.null(f)) {
      if (!is.numeric(f) || anyNA(f) || any(f <= 0)) stop("`fpc` must be positive and not missing", call. = FALSE)
      # one value per stratum
      if (any(tapply(f, s, function(v) length(unique(v))) > 1L)) {
        stop("`fpc` must be constant within each stratum", call. = FALSE)
      }
      npsu <- tapply(p, s, function(v) length(unique(v)))
      fs <- tapply(f, s, `[`, 1L)
      frac <- if (all(f <= 1)) fs else npsu / fs
      if (any(frac > 1 + 1e-12)) stop("`fpc` gives a stratum more sampled PSUs than its population", call. = FALSE)
      f <- as.numeric(frac)
    }
    des$type <- "linearization"
    des$strata <- s
    des$psu <- p
    des$fpc <- f
    if (is.null(des$degf)) des$degf <- length(unique(p)) - length(unique(s))
  }
  structure(des, class = "rmbl_svy_design")
}

# the design's degrees of freedom (survey_design(): PSUs less strata, the replicate matrix's rank less
# one, or as given)
.svy_df <- function(des) {
  if (!is.null(des$degf)) return(des$degf)
  if (identical(des$type, "linearization")) length(unique(des$psu)) - length(unique(des$strata)) else
    length(des$reps) - 1L
}

# The data must be the rows the design was built on, in the same order
.svy_check_data <- function(design, data) {
  if (!is.data.frame(data) || nrow(data) != design$n) {
    stop("`data` must be the data frame the design was built on", call. = FALSE)
  }
  ck <- design$check
  if (is.null(ck)) return(invisible())
  same_rows <- identical(attr(data, "row.names"), ck$rows)
  same_cols <- all(vapply(names(ck$cols), function(k) {
    cn <- ck$cols[[k]]
    cn %in% names(data) && identical(data[[cn]], ck$values[[k]])
  }, logical(1)))
  if (same_rows && same_cols && !is.null(ck$digests)) {
    now <- .svy_column_digests(data[intersect(names(data), rownames(ck$digests))])
    was <- ck$digests[rownames(now), , drop = FALSE]
    # the same values in another order: a reorder, whatever the row names say
    if (any(now[, "ordered"] != was[, "ordered"] & now[, "sorted"] == was[, "sorted"])) same_rows <- FALSE
  }
  if (!same_rows || !same_cols) {
    stop(paste("`data` is not the data frame the design was built on (its rows are in another order, or",
               "its weight, strata or PSU columns differ): build the design on this data"), call. = FALSE)
  }
}

# A digest of each column as given and sorted (rows: columns; "ordered", "sorted").
.svy_column_digests <- function(data) {
  if (!length(data)) return(matrix(character(), 0L, 2L, dimnames = list(NULL, c("ordered", "sorted"))))
  one <- function(v) {
    v <- as.character(v)
    v[is.na(v)] <- "\x1fNA"
    c(core_sha256(paste(v, collapse = "\x1f")), core_sha256(paste(sort(v), collapse = "\x1f")))
  }
  d <- t(vapply(data, one, character(2), USE.NAMES = TRUE))
  colnames(d) <- c("ordered", "sorted")
  d
}

# The replicates are exactly the columns given, by name or as the object passed: nothing is
# guessed from values (the totals, constancy and multiplier-shape rules of 46de6a9 and after refused
# genuine sets, a dominant PSU or a jackknife on a subset, and still passed strays; reviews of
# 46de6a9). What is refused is exact: the full-sample weight itself (a jackknife, BRR or Fay
# replicate always changes some rows; a bootstrap replicate that draws every PSU once is the
# weight, legitimately, and survey's rescaled multipliers put it a rounding error off), the id's
# values, the row numbers, and a column of `data` passed under another name. A column of `data`
# passed under its own name is a replicate because it was asked for; so is every column of an
# unnamed matrix, which has no names to compare (reviews of 46de6a9).
.svy_replicate_check <- function(reps, w, type, data, id_values = NULL, row_names = NULL, named = TRUE) {
  n <- length(w)
  rown <- as.numeric(seq_len(n))
  rn <- if (is.numeric(row_names)) as.numeric(row_names) else NULL
  idv <- if (is.numeric(id_values)) as.numeric(id_values) else NULL
  refuse <- function(b, what) {
    stop(sprintf("replicate %s is %s, not a replicate weight; give only the replicate columns",
                 names(reps)[[b]] %||% b, what), call. = FALSE)
  }
  numcols <- Filter(is.numeric, as.list(data))
  key <- function(v) c(v[1L], v[n], sum(v))
  keys <- lapply(numcols, function(v) key(as.numeric(v)))
  for (b in seq_along(reps)) {
    r <- reps[[b]]
    rel <- abs(r - w) / pmax(w, .Machine$double.xmin)
    if (identical(r, w) || all(rel < 1e-12)) {
      if (!type %in% c("bootstrap", "mean_bootstrap")) refuse(b, "the full-sample weight")
      next
    }
    if (!is.null(idv) && identical(r, idv)) refuse(b, "the id")
    if (identical(r, rown) || (!is.null(rn) && identical(r, rn))) refuse(b, "the row number")
    if (!named) next
    kr <- key(r)
    for (cn in setdiff(names(numcols), names(reps)[[b]])) {
      if (identical(kr, keys[[cn]]) && identical(r, as.numeric(numcols[[cn]]))) {
        refuse(b, sprintf("column %s of `data`", cn))
      }
    }
  }
  invisible(TRUE)
}

#' @export
print.rmbl_svy_design <- function(x, ...) {
  cat(sprintf("Survey design: %s respondents, weights summing to %s\n", format(x$n, big.mark = ","),
              format(round(sum(x$weights)), big.mark = ",")))
  if (identical(x$type, "linearization")) {
    cat(sprintf("Variance: Taylor linearization, %d strata, %d PSUs%s\n", length(unique(x$strata)),
                length(unique(x$psu)), if (!is.null(x$fpc)) ", finite population correction" else ""))
  } else {
    lab <- switch(x$type,
      bootstrap = "bootstrap",
      mean_bootstrap = sprintf("mean bootstrap (each the mean of %g)", x$mean_size),
      jk1 = "jackknife (JK1)",
      jkn = "stratified jackknife (JKn)",
      brr = "balanced repeated replication",
      fay = sprintf("Fay's BRR (rho = %g)", x$rho))
    cat(sprintf("Variance: %d replicate weights, %s; scale %.6g, %s\n", length(x$reps), lab, x$scale,
                if (x$mse) "centred on the full-sample estimate" else "centred on the replicate mean"))
  }
  invisible(x)
}

# The estimates and their covariance. Every estimate is a total A (stat "total") or a ratio A / D of
# weighted totals; `num` and `den` are n x k matrices of the per-row values entering each.
.svy_core <- function(des, num, den) {
  w <- des$weights
  A <- colSums(w * num)
  D <- if (is.null(den)) NULL else colSums(w * den)
  est <- if (is.null(den)) A else A / D
  k <- ncol(num)
  if (!is.null(des$reps)) {
    tot <- .Call(C_rmbl_svy_reptotals, cbind(num, den), des$reps)
    th <- if (is.null(den)) tot[, seq_len(k), drop = FALSE] else
      tot[, seq_len(k), drop = FALSE] / tot[, k + seq_len(k), drop = FALSE]
    centre <- if (des$mse) est else colMeans(th)
    dev <- sweep(th, 2L, centre)
    dev[!is.finite(dev)] <- NA_real_
    dz <- ifelse(is.na(dev), 0, dev)
    if (!is.null(des$rscales)) dz <- dz * sqrt(des$rscales)
    V <- des$scale * crossprod(dz)
    # a replicate whose domain total was zero has no estimate: its variance is not computable
    bad <- colSums(is.na(dev)) > 0
    if (any(bad)) {
      V[bad, ] <- NA_real_
      V[, bad] <- NA_real_
    }
  } else {
    # linearized values: a total's own values, a ratio's (y - theta x) / X
    u <- if (is.null(den)) num else sweep(num - sweep(den, 2L, est, `*`), 2L, D, `/`)
    z <- w * u
    pt <- rowsum(z, des$psu, reorder = TRUE)
    ps <- as.integer(tapply(des$strata, des$psu, `[`, 1L))
    V <- matrix(0, k, k)
    informative <- 0L     # strata that carry variance information
    for (h in sort(unique(ps))) {
      zh <- pt[ps == h, , drop = FALSE]
      nh <- nrow(zh)
      fh <- if (is.null(des$fpc)) 0 else des$fpc[h]
      # a certainty stratum (every PSU sampled) adds no sampling variance, one PSU or many
      if (fh >= 1 - 1e-12) next
      if (nh == 1L) {
        if (des$lonely_psu == "fail") {
          stop(sprintf("stratum %d has a single PSU: set lonely_psu to \"remove\" or \"adjust\"", h), call. = FALSE)
        }
        if (des$lonely_psu == "remove" || nrow(pt) < 2L) next
        dz <- sweep(zh, 2L, colSums(pt) / nrow(pt))
        V <- V + (1 - fh) * crossprod(dz)
        informative <- informative + 1L
        next
      }
      dz <- sweep(zh, 2L, colMeans(zh))
      V <- V + (1 - fh) * nh / (nh - 1) * crossprod(dz)
      informative <- informative + 1L
    }
    # no stratum with two PSUs (one PSU in all, or every lonely PSU removed): a standard error of
    # zero would read as an exact estimate, so the variance is not computable
    census <- !is.null(des$fpc) && all(des$fpc >= 1 - 1e-12)
    if (informative == 0L && !census) V[] <- NA_real_
  }
  list(est = unname(est), V = unname(V), A = A, D = D)
}

# The analysis columns for one variable over the domains: numerators, denominators and labels.
.svy_columns <- function(data, des, y, by, stat, denominator, levels) {
  n <- des$n
  if (!is.character(y) || length(y) != 1L || !y %in% names(data)) {
    stop("`y` must name a column of `data`", call. = FALSE)
  }
  v <- data[[y]]
  ok <- !is.na(v)
  if (!is.null(denominator)) {
    if (!is.character(denominator) || length(denominator) != 1L || !denominator %in% names(data)) {
      stop("`denominator` must name a column of `data`", call. = FALSE)
    }
    x <- data[[denominator]]
    if (!is.numeric(x)) stop("`denominator` must be numeric", call. = FALSE)
    ok <- ok & !is.na(x)
  }
  if (is.null(by)) {
    dom <- factor(rep("all", n))
    dlab <- data.frame(row.names = 1L)
  } else {
    miss <- setdiff(by, names(data))
    if (length(miss)) stop(sprintf("`by` names columns `data` does not have: %s", paste(miss, collapse = ", ")),
                           call. = FALSE)
    key <- interaction(data[by], drop = TRUE, sep = "\r", lex.order = TRUE)
    dom <- key
    parts <- do.call(rbind, strsplit(levels(key), "\r", fixed = TRUE))
    dlab <- as.data.frame(matrix(parts, ncol = length(by)), stringsAsFactors = FALSE)
    names(dlab) <- by
  }
  ok <- ok & !is.na(dom)
  if (stat == "proportion") {
    lv <- if (is.factor(v)) levels(droplevels(v[ok])) else sort(unique(as.character(v[ok])))
    if (!is.null(levels)) {
      bad <- setdiff(as.character(levels), lv)
      if (length(bad)) stop(sprintf("levels not observed in `%s`: %s", y, paste(bad, collapse = ", ")), call. = FALSE)
      lv <- as.character(levels)
    }
    if (!length(lv)) stop(sprintf("`%s` has no non-missing values", y), call. = FALSE)
  } else {
    if (!is.numeric(v) && !is.logical(v)) stop(sprintf("`%s` must be numeric for a %s", y, stat), call. = FALSE)
    if (any(!is.finite(v[ok]))) stop(sprintf("`%s` has infinite values", y), call. = FALSE)
    lv <- NA_character_
  }
  nd <- nlevels(dom)
  k <- nd * length(lv)
  num <- matrix(0, n, k)
  den <- if (stat == "total") NULL else matrix(0, n, k)
  cnt <- integer(k)
  di <- integer(k)
  li <- character(k)
  j <- 0L
  for (d in seq_len(nd)) {
    ind <- ok & as.integer(dom) == d
    ind[is.na(ind)] <- FALSE
    for (l in lv) {
      j <- j + 1L
      num[, j] <- if (stat == "proportion") as.numeric(ind & as.character(v) == l) else ifelse(ind, as.numeric(v), 0)
      num[is.na(num[, j]), j] <- 0
      if (!is.null(den)) den[, j] <- if (stat == "ratio") ifelse(ind, as.numeric(x), 0) else as.numeric(ind)
      cnt[j] <- sum(ind)
      di[j] <- d
      li[j] <- l
    }
  }
  lab <- if (ncol(dlab)) dlab[di, , drop = FALSE] else data.frame(row.names = seq_len(k))
  if (stat == "proportion") lab$level <- li
  rownames(lab) <- NULL
  list(num = num, den = den, n = cnt, labels = lab)
}

.svy_ci <- function(est, se, n_used, stat, ci, conf_level, df = Inf, design_df = Inf) {
  z <- if (is.finite(df)) stats::qt(1 - (1 - conf_level) / 2, df) else stats::qnorm(1 - (1 - conf_level) / 2)
  lower <- est - z * se
  upper <- est + z * se
  if (stat == "proportion" && ci != "wald") {
    inside <- is.finite(se) & est > 0 & est < 1
    # at 0 or 1 the design effect is 0/0: Wilson at the plain n (the logit interval does not exist
    # there either, and takes the same). Wald with se = 0 had collapsed to [1, 1] for 40 of 40.
    edge <- !is.na(est) & (est <= 0 | est >= 1) & n_used > 0
    if (any(edge)) {
      zz <- stats::qnorm(1 - (1 - conf_level) / 2)
      tt <- if (is.finite(design_df)) stats::qt(1 - (1 - conf_level) / 2, design_df) else zz
      tn <- stats::qt(1 - (1 - conf_level) / 2, pmax(n_used[edge] - 1, 1))
      ne <- pmin(n_used[edge] * (tn / tt)^2, n_used[edge])
      p <- pmin(pmax(est[edge], 0), 1)
      mid <- (p + zz^2 / (2 * ne)) / (1 + zz^2 / ne)
      half <- zz / (1 + zz^2 / ne) * sqrt(p * (1 - p) / ne + zz^2 / (4 * ne^2))
      lower[edge] <- ifelse(p <= 0, 0, mid - half)   # the bound at the observed end is that end, exactly
      upper[edge] <- ifelse(p >= 1, 1, mid + half)
    }
    if (ci == "logit") {
      l <- stats::qlogis(est[inside]) - z * se[inside] / (est[inside] * (1 - est[inside]))
      u <- stats::qlogis(est[inside]) + z * se[inside] / (est[inside] * (1 - est[inside]))
      lower[inside] <- stats::plogis(l)
      upper[inside] <- stats::plogis(u)
    } else {
      # Wilson's score interval at the modified effective sample size of SAS PROC SURVEYFREQ
      # (CL(TYPE = WILSON)), which produced Health Canada's CSUS intervals: n / Deff with the SRS
      # variance on n - 1, times (t_{n-1} / t_df)^2 for the design's degrees of freedom (Korn and
      # Graubard 1998; SAS documents the n - 1 quantile, where z stood before 0.5.12), and never
      # more than the n respondents behind the estimate
      p <- est[inside]
      n <- n_used[inside]
      zz <- stats::qnorm(1 - (1 - conf_level) / 2)
      tt <- if (is.finite(design_df)) stats::qt(1 - (1 - conf_level) / 2, design_df) else zz
      tn <- stats::qt(1 - (1 - conf_level) / 2, pmax(n - 1, 1))
      deff <- se[inside]^2 / (p * (1 - p) / (n - 1))
      ne <- pmin(n / deff * (tn / tt)^2, n)
      z <- zz
      mid <- (p + z^2 / (2 * ne)) / (1 + z^2 / ne)
      half <- z / (1 + z^2 / ne) * sqrt(p * (1 - p) / ne + z^2 / (4 * ne^2))
      lower[inside] <- mid - half
      upper[inside] <- mid + half
    }
    lower <- pmax(lower, 0)
    upper <- pmin(upper, 1)
  }
  list(lower = lower, upper = upper)
}

#' Estimate a mean, total, proportion or ratio from a survey
#' design
#'
#' Design-based point estimates with standard errors, confidence
#' intervals and coefficients of variation, for the whole
#' population or for each domain of `by`. A respondent outside a
#' domain, or missing the analysis variable, counts zero in that
#' domain and stays in the design, so the variance of a subgroup
#' estimate reflects the whole sample design.
#'
#' Proportions are reported for every category of `y` (or those
#' in `levels`), each with its own interval. The default
#' interval for a proportion is Wilson's score interval at the
#' modified effective sample size of SAS PROC SURVEYFREQ, the
#' software behind Health Canada's published Canadian Substance
#' Use Survey intervals: \eqn{n / \mathrm{Deff}}, with the
#' design effect taken against the simple-random-sampling
#' variance \eqn{p(1 - p)/(n - 1)}, scaled by \eqn{(z /
#' t_{df})^2} for the design's degrees of freedom (Korn and
#' Graubard 1998) and capped at the \eqn{n} respondents behind
#' the estimate. `ci = "logit"` builds the interval on the logit
#' scale and `"wald"` symmetrically. Means, totals and ratios
#' get the symmetric normal interval.
#'
#' A domain with fewer than `min_n` respondents is flagged, not
#' withheld: Health Canada suppresses such CSUS estimates in its
#' data tool (denominator under 30), and the flag lets the
#' reader do the same.
#'
#' @param design A [survey_design()] built on `data`.
#' @param data The data frame the design was built on.
#' @param y The analysis column.
#' @param by Optional domain columns.
#' @param stat `"mean"`, `"total"`, `"proportion"` or `"ratio"`
#'   (of `y` to `denominator`).
#' @param denominator For a ratio, the denominator column.
#' @param levels For a proportion, the categories to report
#'   (default all observed).
#' @param conf_level Confidence level.
#' @param ci Interval method: `"auto"` (Wilson for proportions,
#'   Wald otherwise), `"wilson"`, `"logit"` or `"wald"`.
#' @param min_n Domains with fewer respondents are flagged.
#' @param df Degrees of freedom for the interval: `Inf` (the
#'   default) for the normal quantile, a number for Student's t,
#'   or `"design"` for the design's own (PSUs less strata under
#'   linearization, replicates less one otherwise).
#' @return A data frame of class `rmbl_svy_estimate`: the domain
#'   (and `level`) columns, then `estimate`, `se`, `lower`,
#'   `upper`, `cv` (percent), `n` (respondents counted) and
#'   `flag`. The covariance of the estimates is the `vcov`
#'   attribute.
#' @seealso [survey_design()],
#'   [survey_compare()]
#' @examples
#' set.seed(1)
#' d <- data.frame(region = rep(c("north", "south"), each = 50),
#'                 smoker = rbinom(100, 1, rep(c(0.2, 0.35), each = 50)),
#'                 drinks = rpois(100, 3), w = runif(100, 50, 150))
#' des <- survey_design(d, weights = "w", strata = "region")
#' survey_estimate(des, d, "smoker", by = "region", stat = "proportion", levels = "1")
#' survey_estimate(des, d, "drinks", stat = "mean")
#' survey_estimate(des, d, "drinks", by = "region", stat = "total")
#' @export
survey_estimate <- function(design, data, y, by = NULL, stat = c("mean", "total", "proportion", "ratio"),
                            denominator = NULL, levels = NULL, conf_level = 0.95,
                            ci = c("auto", "wilson", "logit", "wald"), min_n = 30, df = Inf) {
  stat <- match.arg(stat)
  ci <- match.arg(ci)
  if (!inherits(design, "rmbl_svy_design")) stop("`design` must come from survey_design()", call. = FALSE)
  .svy_check_data(design, data)
  if (!length(by)) by <- NULL
  if (!is.character(by) && !is.null(by)) stop("`by` must name columns of `data`", call. = FALSE)
  if (!is.numeric(conf_level) || length(conf_level) != 1L || is.na(conf_level) ||
        !(conf_level > 0 && conf_level < 1)) {
    stop("`conf_level` must be a number between 0 and 1", call. = FALSE)
  }
  if (stat == "ratio" && is.null(denominator)) stop("a ratio needs a `denominator` column", call. = FALSE)
  if (ci == "auto") ci <- if (stat == "proportion") "wilson" else "wald"
  if (identical(df, "design")) {
    df <- .svy_df(design)
    # replicates that are all multiples of one weight vector have rank 1: no degrees of freedom
    if (df < 1) {
      stop(sprintf("the design has %g degrees of freedom (its replicate weights do not vary independently)", df),
           call. = FALSE)
    }
  }
  if (!is.numeric(df) || length(df) != 1L || is.na(df) || df <= 0) {
    stop("`df` must be a positive number, Inf or \"design\"", call. = FALSE)
  }
  cols <- .svy_columns(data, design, y, by, stat, if (stat == "ratio") denominator, levels)
  core <- .svy_core(design, cols$num, cols$den)
  se <- sqrt(pmax(diag(core$V), 0))
  int <- .svy_ci(core$est, se, cols$n, stat, ci, conf_level, df, .svy_df(design))
  flag <- rep(NA_character_, length(se))
  flag[cols$n < min_n] <- sprintf("fewer than %g respondents", min_n)
  # the reason a variance is missing, said as it is
  flag[is.na(se)] <- if (is.null(design$reps)) "variance not computable (no stratum has two PSUs)" else
    "variance not computable (a replicate left the domain empty)"
  flag[is.na(se) & !is.null(core$D) & is.finite(core$D) & core$D == 0] <- "the domain's weights are all zero"
  flag[cols$n == 0L] <- "no respondents"
  out <- cbind(cols$labels, data.frame(estimate = core$est, se = se, lower = int$lower, upper = int$upper,
                                       cv = 100 * se / abs(core$est), n = cols$n, flag = flag,
                                       stringsAsFactors = FALSE))
  rownames(out) <- NULL
  structure(out, class = c("rmbl_svy_estimate", "data.frame"), vcov = core$V, stat = stat, y = y, by = by,
            ci = ci, conf_level = conf_level, df = df, method = design$type, denominator = denominator)
}

#' Compare survey estimates between domains
#'
#' Each domain's estimate against a reference domain: the
#' difference, its standard error from the design (the
#' covariance between the two estimates included, which is what
#' a pair of separate intervals leaves out), a confidence
#' interval and a two-sided p-value from the normal
#' approximation.
#'
#' @inheritParams survey_estimate
#' @param by The domain columns to compare across.
#' @param ref The reference domain, as its label (for several
#'   `by` columns, the labels joined with `" / "`); default the
#'   first.
#' @return A data frame of class `rmbl_svy_compare`: `domain`,
#'   `level` (for a proportion), `estimate`, `reference`,
#'   `difference`, `se`, `lower`, `upper`, `p_value`.
#' @examples
#' set.seed(1)
#' d <- data.frame(region = rep(c("north", "south", "east"), length.out = 150),
#'                 smoker = rbinom(150, 1, 0.3), w = runif(150, 50, 150))
#' des <- survey_design(d, weights = "w")
#' survey_compare(des, d, "smoker", by = "region", stat = "proportion",
#'                levels = "1", ref = "north")
#' @export
survey_compare <- function(design, data, y, by, stat = c("mean", "total", "proportion", "ratio"),
                           denominator = NULL, levels = NULL, ref = NULL, conf_level = 0.95) {
  stat <- match.arg(stat)
  if (missing(by) || !length(by)) stop("`by` must name the domains to compare", call. = FALSE)
  e <- survey_estimate(design, data, y, by = by, stat = stat, denominator = denominator, levels = levels,
                       conf_level = conf_level, ci = "wald")
  V <- attr(e, "vcov")
  dom <- do.call(paste, c(as.list(as.data.frame(e)[by]), sep = " / "))
  lev <- if (stat == "proportion") e$level else rep(NA_character_, nrow(e))
  doms <- unique(dom)
  if (length(doms) < 2L) stop("comparisons need at least two domains", call. = FALSE)
  if (is.null(ref)) ref <- doms[1L]
  # a domain label may be a number (ref = 2023 for a year): matched as the label it prints as
  if (is.numeric(ref) && length(ref) == 1L && !is.na(ref)) ref <- as.character(ref)
  if (!is.character(ref) || length(ref) != 1L || is.na(ref)) {
    stop("`ref` must be one domain label", call. = FALSE)
  }
  if (!ref %in% doms) stop(sprintf("`ref` is not one of the domains: %s", paste(doms, collapse = ", ")), call. = FALSE)
  z <- stats::qnorm(1 - (1 - conf_level) / 2)
  rows <- list()
  for (l in unique(lev)) {
    i0 <- which(dom == ref & (lev %in% l))
    for (i in which(dom != ref & (lev %in% l))) {
      d <- e$estimate[i] - e$estimate[i0]
      s <- sqrt(max(V[i, i] + V[i0, i0] - 2 * V[i, i0], 0))
      rows[[length(rows) + 1L]] <- data.frame(domain = dom[i], level = l, estimate = e$estimate[i],
                                              reference = e$estimate[i0], difference = d, se = s,
                                              lower = d - z * s, upper = d + z * s,
                                              p_value = 2 * stats::pnorm(-abs(d / s)), stringsAsFactors = FALSE)
    }
  }
  out <- do.call(rbind, rows)
  if (stat != "proportion") out$level <- NULL
  rownames(out) <- NULL
  structure(out, class = c("rmbl_svy_compare", "data.frame"), ref = ref, stat = stat, y = y,
            conf_level = conf_level)
}

#' @export
print.rmbl_svy_estimate <- function(x, digits = 4, ...) {
  m <- attributes(x)
  cat(sprintf("Survey %s of %s%s (%s variance, %g%% %s interval)\n", m$stat, m$y,
              if (length(m$by)) paste(" by", paste(m$by, collapse = ", ")) else "",
              m$method, 100 * m$conf_level, m$ci))
  d <- as.data.frame(unclass(x), stringsAsFactors = FALSE)
  attr(d, "vcov") <- NULL
  print(format(d, digits = digits), row.names = FALSE)
  invisible(x)
}

#' @export
print.rmbl_svy_compare <- function(x, digits = 4, ...) {
  cat(sprintf("Survey %s of %s against %s (%g%% interval)\n", attr(x, "stat"), attr(x, "y"), attr(x, "ref"),
              100 * attr(x, "conf_level")))
  print(format(as.data.frame(unclass(x), stringsAsFactors = FALSE), digits = digits), row.names = FALSE)
  invisible(x)
}

#' @rdname plot-methods
#' @export
plot.rmbl_svy_estimate <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  m <- attributes(x)
  d <- as.data.frame(unclass(x), stringsAsFactors = FALSE)
  pct <- identical(m$stat, "proportion")
  k <- if (pct) 100 else 1
  lab <- if (length(m$by)) do.call(paste, c(d[m$by], sep = " / ")) else rep("all", nrow(d))
  if (pct && length(unique(d$level)) > 1L) lab <- paste(lab, d$level, sep = ": ")
  if (all(lab == "all")) lab <- if (pct) d$level else m$y
  pal <- .bl_cols(3, col, palette)
  cols <- if (!is.null(col)) rep_len(col, nrow(d)) else ifelse(is.na(d$flag), pal[1L], pal[2L])
  note <- ifelse(is.na(d$flag), NA_character_, d$flag)
  .bl_dot_interval(lab, k * d$estimate, k * d$lower, k * d$upper,
                   .bl_main(main, sprintf("%s of %s", tools::toTitleCase(m$stat), m$y)),
                   sprintf("%s%s, with %g%% interval (orange: flagged)", if (pct) "Percent" else
                             tools::toTitleCase(m$stat), if (pct) "" else "", 100 * m$conf_level),
                   cols, note = note, ...)
  invisible(data.frame(label = lab, estimate = k * d$estimate, lower = k * d$lower, upper = k * d$upper,
                       stringsAsFactors = FALSE))
}

#' @rdname plot-methods
#' @export
plot.rmbl_svy_compare <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  d <- as.data.frame(unclass(x), stringsAsFactors = FALSE)
  pct <- identical(attr(x, "stat"), "proportion")
  k <- if (pct) 100 else 1
  lab <- if (!is.null(d$level) && length(unique(d$level)) > 1L) paste(d$domain, d$level, sep = ": ") else d$domain
  pal <- .bl_cols(3, col, if (is.null(palette) && is.null(col)) "diverging" else palette)
  sig <- d$p_value < 1 - attr(x, "conf_level")
  cols <- if (!is.null(col)) rep_len(col, nrow(d)) else
    ifelse(!sig, pal[2L], ifelse(d$difference > 0, pal[3L], pal[1L]))
  .bl_dot_interval(lab, k * d$difference, k * d$lower, k * d$upper,
                   .bl_main(main, sprintf("Difference from %s", attr(x, "ref"))),
                   sprintf("Difference%s, with interval (grey: not significant)",
                           if (pct) " in percentage points" else ""),
                   cols, ref = 0, ...)
  invisible(data.frame(label = lab, difference = k * d$difference, lower = k * d$lower, upper = k * d$upper,
                       stringsAsFactors = FALSE))
}
