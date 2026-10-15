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
#' The replicate columns are taken as given: which columns are
#' replicates is not guessed from their values (rules that tried
#' refused genuine designs, a dominant PSU or a jackknife on a
#' subset). Refused, because no genuine replicate can be it: the
#' `id`'s values, the row numbers, a column of `data` passed under
#' another name, a second column named like the weight or the `id`
#' that holds other values, and under JK1, JKn and BRR a copy of the
#' full-sample weight (equal to it, or within 1 percent of it on every
#' row). Warned about, because a genuine set can produce it but
#' rarely does: under the bootstrap, more replicates equal to the
#' full-sample weight than chance draws; under the bootstrap or
#' Fay's method, a replicate within 1 percent of the weight on
#' every row;
#' under JK1, JKn and BRR, a replicate that leaves no row out; a
#' replicate more than ten times the weight on a typical row (a
#' column on another scale, such as an outcome); and a
#' set whose replicates total, on average, under a tenth or over ten
#' times the weight (multipliers such as \pkg{survey}'s
#' `$repweights` passed in place of replicate weights). A column of
#' `data` named in `replicates`, and every column of an unnamed
#' matrix, is a replicate because it was given as one; a stray that
#' is itself shaped like a replicate (another design's multipliers, a
#' constant under the bootstrap) cannot be told from one. BRR and
#' Fay replicates must come in a Hadamard order (2, or a multiple of
#' 4).
#'
#' The data passed to [survey_estimate()] must be the rows
#' the design was built on, in the same order: rows in another order
#' are refused
#' (within strata or PSUs too), and a column changed since (a
#' permuted outcome for a permutation test) is not a reorder.
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
  # only the columns the design names must be unique: a duplicated column it does not use is no
  # reason to refuse the data (statistics stress test of 5e1dce5)
  used <- unlist(Filter(function(v) is.character(v), list(weights, strata, psu, fpc, id, replicates)))
  twice <- used[used %in% names(data)[duplicated(names(data))]]
  if (length(twice)) stop(sprintf("`data` has two columns named %s: rename one", twice[[1L]]), call. = FALSE)
  n <- nrow(data)
  if (n < 2L) stop("`data` must have at least two rows", call. = FALSE)
  type <- .rmbl_arg(type)
  lonely_psu <- .rmbl_arg(lonely_psu)
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
  # the rows as a set and in order: a reordered tibble (row names always 1..n) with a vector weight
  # gave SE 13.8 for 20.2 silently (review of 46de6a9), and rows reordered within their strata or
  # PSUs passed the named columns' check too (statistics stress test of 5e1dce5)
  check$rowkeys <- .svy_rowkey_digests(data)
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
        # a second column with the id's name: the id itself is set aside, and one that holds other
        # values is refused, as a column with the weight's name is (dropped with the id it was B 24 ->
        # 23, kept it was a replicate nobody named; reviews of 46de6a9 and 5e1dce5)
        for (i in which(names(replicates) == id)[-1L]) {
          if (!identical(replicates[[i]], replicates[[id]])) {
            stop(sprintf(paste("column %s of `replicates` has the id's name but not its values: rename it,",
                               "or give only the replicate columns"), id), call. = FALSE)
          }
        }
        id_values <- replicates[[id]][m]
        replicates <- replicates[m, names(replicates) != id, drop = FALSE]
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
          # the weight within a rounding error (1e-12 of it, the replicate check's own tolerance):
          # identical() refused a copy 1e-13 off (statistics stress test of 5e1dce5)
          if (!is.numeric(v) || any(abs(as.numeric(v) - w) > 1e-12 * pmax(abs(w), .Machine$double.xmin))) {
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
  if (same_rows && same_cols && !is.null(ck$rowkeys) && all(ck$rowkeys$cols %in% names(data))) {
    now <- .svy_rowkey_digests(data[ck$rowkeys$cols])
    # the same rows in another order: a reorder, whatever the row names say. A column changed since
    # (a permuted y for a permutation test, a recode) changes the rows themselves and passes; it was
    # refused as a reorder when each column was compared on its own (statistics stress test of 5e1dce5)
    if (identical(now$sorted, ck$rowkeys$sorted) && !identical(now$ordered, ck$rowkeys$ordered)) same_rows <- FALSE
  }
  if (!same_rows || !same_cols) {
    stop(paste("`data` is not the data frame the design was built on (its rows are in another order, or",
               "its weight, strata or PSU columns differ): build the design on this data"), call. = FALSE)
  }
}

# One number per row that does not depend on the row order: each column's values coded by their
# rank among its distinct values (a radix sort, so no locale), folded into the row's key modulo
# 2^31 - 1 (exact in a double). Digested in row order and sorted: the same rows in another order
# have the same sorted digest and a different ordered one. A million rows of ten columns take about
# a second; the per-column text digests this replaces took 88 s per estimate (statistics stress test
# of 5e1dce5).
.svy_rowkey_digests <- function(data) {
  nm <- names(data) %||% character(length(data))
  # the columns that can be found again by name: atomic, named, the name used once
  keep <- vapply(data, function(v) is.atomic(v) && !is.null(v), NA) & !is.na(nm) & nzchar(nm) &
    !(nm %in% nm[duplicated(nm)])
  cols <- nm[keep]
  n <- nrow(data)
  k <- numeric(n)
  # x mod 2^31 - 1 by floor(): R's %% on doubles took most of the time. Deterministic, which is all a
  # key needs, and under 2^53 after the next multiply
  fold <- function(x) x - 2147483647 * floor(x / 2147483647)
  for (i in which(keep)) {
    v <- as.vector(data[[i]])   # a one-dimensional array (apiclus2 has one) is its values
    code <- if (is.double(v)) {
      # the bits of the number: the same value gives the same code wherever its row is, with no
      # sort or match
      b <- readBin(writeBin(v, raw()), "integer", n = 2L * n)
      fold(fold(b[c(TRUE, FALSE)]) * 65599 + b[c(FALSE, TRUE)])
    } else if (is.integer(v) || is.logical(v)) {
      x <- as.numeric(v)
      x[is.na(x)] <- -1
      x
    } else {
      if (is.complex(v)) v <- paste(Re(v), Im(v))
      match(v, sort(unique(v), method = "radix", na.last = TRUE))
    }
    k <- fold(k * 1000003 + code)
  }
  list(cols = cols, ordered = core_sha256(writeBin(k, raw())),
       sorted = core_sha256(writeBin(sort(k, method = "radix"), raw())))
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
  warned <- character()
  equal <- integer()
  for (b in seq_along(reps)) {
    r <- reps[[b]]
    rel <- abs(r - w) / pmax(w, .Machine$double.xmin)
    nm <- names(reps)[[b]] %||% as.character(b)
    if (identical(r, w) || all(rel < 1e-12)) {
      if (!type %in% c("bootstrap", "mean_bootstrap")) refuse(b, "the full-sample weight")
      equal <- c(equal, b)
      next
    }
    # every row within 1% of the weight, not equal to it: a rounded, jittered or single-precision
    # copy. A jackknife or BRR replicate zeroes the PSUs it leaves out, so there it cannot be one;
    # under a bootstrap or Fay's method it is said
    if (all(rel < 0.01)) {
      if (type %in% c("jk1", "jkn", "brr")) refuse(b, "a copy of the full-sample weight (within 1% on every row)")
      warned <- c(warned, sprintf("replicate %s is within 1%% of the full-sample weight on every row", nm))
    } else if (type %in% c("jk1", "jkn", "brr") && !any(r == 0 & w > 0) &&
                 length(unique(signif(r / pmax(w, .Machine$double.xmin), 9))) > 2L) {
      # a jackknife or BRR replicate leaves PSUs out (their rows are 0) and scales the rest by one
      # factor (two for JKn: its stratum's and 1 elsewhere). On a subset the PSU it leaves out may
      # be outside it, so a genuine one can leave no row out, but its rows still share one or two
      # factors; a rounded weight or a constant does not (rounded weights were kept silently)
      warned <- c(warned, sprintf("replicate %s leaves no row out and is no rescaled weight, as a %s replicate is",
                                  nm, toupper(type)))
    }
    # a replicate weight is the weight times a multiplier of a few at most on a typical row (a bootstrap
    # PSU drawn k times, 0 or n / (n - 1) for a jackknife, 0 or 2 for BRR); a column ten times the
    # weight there is on another scale: api99 among the replicates raised the SE 21% silently
    # (statistics stress test of 5e1dce5). A genuine bootstrap reaches it only if a PSU holding most
    # rows is drawn ten times (about 1e-7 a replicate)
    typical <- stats::median(r / pmax(w, .Machine$double.xmin))
    if (is.finite(typical) && typical > 10) {
      warned <- c(warned, sprintf("replicate %s is %.3g times the full-sample weight on a typical row", nm, typical))
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
  # a bootstrap draw of every PSU once is the full weight, legitimately: with m PSUs it happens with
  # chance m!/m^m per replicate (22% at three). More such replicates than chance makes (a Poisson
  # tail under 1e-4) means the weight itself was passed beside them: said, not refused (kept
  # silently, SE 0.270 for 0.284; statistics stress test of 5e1dce5). m is read from the replicates:
  # the rows of one PSU share their multiplier in every replicate
  if (length(equal) && identical(type, "bootstrap")) {
    z <- cos(seq_along(reps))
    sig <- numeric(n)
    for (b in seq_along(reps)) sig <- sig + z[[b]] * reps[[b]] / pmax(w, .Machine$double.xmin)
    m <- length(unique(signif(sig, 10)))
    expect <- length(reps) * exp(lfactorial(m) - m * log(m))
    if (stats::ppois(length(equal) - 1L, expect, lower.tail = FALSE) < 1e-4) {
      warned <- c(warned, sprintf(paste("%d replicate(s) equal the full-sample weight (%s), more than a",
                                        "bootstrap of %d PSUs draws"),
                                  length(equal), paste(utils::head(names(reps)[equal], 3L), collapse = ", "), m))
    }
  }
  # the set as a whole: replicate weights total, on average, what the weight totals (jackknife and
  # bootstrap replicate totals average to the full total, whatever one dominant PSU does to a single
  # replicate). An average a tenth of that or ten times it is survey's multipliers ($repweights) or
  # another scale passed in place of the weights (accepted silently: SE 20.16 for 28.28 on apiclus2;
  # statistics stress test of 5e1dce5)
  ratio <- mean(vapply(reps, sum, 0)) / sum(w)
  if (is.finite(ratio) && (ratio < 0.1 || ratio > 10)) {
    warned <- c(warned, sprintf(paste("the replicates total %.3g times the full-sample weight: multipliers",
                                      "(as survey's $repweights) rather than replicate weights?"), ratio))
  }
  if (length(warned)) {
    warning(paste0(paste(utils::head(warned, 5L), collapse = "; "),
                   if (length(warned) > 5L) sprintf("; and %d more", length(warned) - 5L) else "",
                   ". Kept as given: give only the replicate weights if these are not"), call. = FALSE)
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
  stat <- .rmbl_arg(stat)
  ci <- .rmbl_arg(ci)
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
  stat <- .rmbl_arg(stat)
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
