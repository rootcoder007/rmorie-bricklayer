# Design-based estimation for complex surveys: weighted means, totals,
# proportions and ratios, for the whole population or by domain, with variances
# from replicate weights (bootstrap, mean bootstrap, jackknife, BRR, Fay's BRR)
# or from Taylor linearization over strata and primary sampling units. The
# domain estimates keep the whole design: a respondent outside a domain, or with
# the analysis variable missing, contributes zero to that domain's numerator and
# denominator instead of being dropped from the design, which is what makes the
# variance of a subgroup estimate correct (dropping rows understates it).

#' Describe a complex survey design
#'
#' Collects what design-based estimation needs: the final
#' weight, and either a set of replicate weights or the strata
#' and primary sampling units (PSUs) for Taylor linearization.
#' [svyest()] and
#' [svycmp()] take the result. Use it once per
#' survey file: a
#' public-use file from Statistics Canada or Health Canada ships its final
#' weight and a set of bootstrap replicate weights, and estimates computed
#' without them understate the standard errors. The design checks the
#' replicate columns it is given and remembers the rows it was built on, so a
#' later estimate cannot silently be run on a reordered or different table.
#'
#' @details
#' Replicate variances are \eqn{v = s \sum_r (\hat\theta_r -
#' c)^2}, where \eqn{\hat\theta_r} is the estimate under
#' replicate weight \eqn{r}, \eqn{c} is the full-sample estimate
#' (`mse = TRUE`) or the mean of the replicate estimates, and
#' the scale \eqn{s} depends on how the replicates were made,
#' for \eqn{B} replicates:
#' \describe{
#'   \item{`"bootstrap"`}{\eqn{1/B}: the Rao-Wu rescaled
#'   bootstrap Statistics Canada ships with its public-use
#'   files. It is not the survey package's `type = "bootstrap"`
#'   (Canty and Davison's), whose scale is
#'   \eqn{m/((m - 1)(B - 1))} for \eqn{m} PSUs a stratum: for
#'   those replicates give that factor over \eqn{1/B} in
#'   `rscales`, \eqn{B m/((m - 1)(B - 1))} for each, with
#'   `mse = FALSE` (survey's default centring).}
#'   \item{`"meanboot"`}{\eqn{R/B}, where each replicate
#'   weight is the mean of \eqn{R} bootstrap weights
#'   (`msize`). The Canadian Substance Use Survey 2023 ships
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
#' row; under JKn, a single replicate equal to it, while two or more
#' equal to it are kept, as a stratum left out of a subset leaves all
#' of its replicates at the weight). Not a copy: a
#' jackknife replicate that scales the rows by one factor
#' \eqn{k/(k - 1)} (its deleted PSU outside a subset), and, in a set
#' whose replicates are post-stratified or calibrated (factors off
#' 0, 1, 2 and \eqn{k/(k - 1)}), a replicate equal or close to the
#' weight. Warned about, because a genuine set can produce it but
#' rarely does: under the bootstrap, more replicates equal to the
#' full-sample weight than chance draws; under the bootstrap or
#' Fay's method, a replicate within 1 percent of the weight on
#' every row, and under Fay's method one equal to it (a
#' post-stratified domain whose rows sit in one PSU per stratum);
#' under JK1 and JKn, one factor \eqn{k/(k - 1)} on every row with
#' no row left out that more or fewer replicates than \eqn{k} carry
#' (a rescaled copy beside a full set, or a lone stray; a genuine
#' set carries it on exactly \eqn{k}, on a subset too);
#' under JK1, JKn and BRR, a replicate that leaves no row out; a
#' replicate more than ten times the weight on a typical row (a
#' column on another scale, such as an outcome); and a
#' set whose replicates total, on average, under a tenth or over ten
#' times the weight (multipliers such as \pkg{survey}'s
#' `$repweights` passed in place of replicate weights). A column of
#' `data` named in `reps`, and every column of an unnamed
#' matrix, is a replicate because it was given as one; a stray that
#' is itself shaped like a replicate (another design's multipliers, a
#' constant under the bootstrap) cannot be told from one. BRR and
#' Fay replicates must come in a Hadamard order (2, or a multiple of
#' 4).
#'
#' The data passed to [svyest()] must be the rows
#' the design was built on, in the same order: rows in another order
#' are refused
#' (within strata or PSUs too), and a column changed since (a
#' permuted outcome for a permutation test) is not a reorder.
#'
#' The design's degrees of freedom (`df = "design"` in
#' [svyest()]) are PSUs less strata under
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
#' Errors: \code{data} not a data frame or with fewer than two rows; a named
#' column that \code{data} does not have, or a vector of the wrong length;
#' weights or replicate weights that are negative, missing or not finite;
#' both replicates and strata or PSUs; fewer than two replicates, or
#' replicate columns refused for the reasons above; BRR or Fay replicates not
#' in a Hadamard order; \code{type = "jkn"} without \code{rscales}, or
#' \code{rscales} not one non-negative number per replicate; \code{rho} not
#' in [0, 1) for Fay; \code{msize} or \code{degf} below 1; missing
#' strata or PSU labels; an \code{fpc} that is not positive, varies within a
#' stratum, or is smaller than the PSUs sampled.
#' Nothing is computed until [svyest()] is called,
#' so a single-PSU
#' stratum under \code{lonely = "fail"} is reported then.
#'
#' @param data A data frame, one row per respondent.
#' @param w The final (full-sample) weight: a column name
#'   or a numeric vector with one non-negative value per row.
#' @param strata,psu Optional stratum and primary sampling unit:
#'   column names or vectors. A PSU label need only be unique
#'   within its stratum.
#' @param fpc Optional finite population correction per row: a
#'   column name or vector holding either the stratum's population
#'   count of PSUs or (all values at most 1) the sampling
#'   fraction.
#' @param reps Optional replicate weights: a data frame or
#'   matrix with one column per replicate, or the names of
#'   replicate weight columns in `data`.
#' @param id With a `reps` data frame, the column (present
#'   in both) that matches its rows to `data`'s; without it the
#'   rows must already be in the same order.
#' @param type How the replicates were made: \code{"bootstrap"} (the
#'   default), \code{"meanboot"}, \code{"jk1"}, \code{"jkn"},
#'   \code{"brr"} or \code{"fay"}; see Details. Ignored without
#'   \code{reps}.
#' @param msize For \code{type = "meanboot"}, the number of
#'   bootstrap weights averaged into each replicate; default \code{1}.
#' @param rho For \code{type = "fay"}, Fay's coefficient, between 0 and 1;
#'   default \code{NULL}.
#' @param rscales Per-replicate factors: required for
#'   `type = "jkn"` (\eqn{(n_h - 1)/n_h} for each replicate's
#'   stratum), optional otherwise (multiplying the type's scale).
#' @param degf The design's degrees of freedom, when known (a
#'   public-use file's documentation gives them); by default
#'   computed as described in Details.
#' @param mse Logical scalar, default \code{TRUE}: centre replicate deviations
#'   on the full-sample estimate (\code{TRUE}) or on the mean of the replicate
#'   estimates (\code{FALSE}).
#' @param lonely What to do with a stratum that has a single
#'   PSU under linearization: \code{"fail"} (the default; an error naming it),
#'   \code{"remove"} (it contributes nothing) or \code{"adjust"} (its PSU is
#'   centred on the mean of all PSU totals).
#' @return An object of class \code{rmbl_svy_design}: a list with \code{n}
#'   (respondents), \code{weights}, \code{type} (the replicate type, or
#'   \code{"linearization"}), \code{scale} and \code{reps} (the replicate
#'   scale and weights, \code{NULL} under linearization), \code{mse},
#'   \code{strata} and \code{psu} (integer codes), \code{lonely},
#'   \code{check} (the row names and digests used to recognise the data
#'   later) and \code{degf} (the design degrees of freedom). The print method
#'   summarises it.
#' @seealso [svyest()],
#'   [svycmp()]
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' set.seed(1)
#' d <- data.frame(region = rep(c("north", "south"), each = 50),
#'                 smoker = rbinom(100, 1, rep(c(0.2, 0.35), each = 50)),
#'                 w = runif(100, 50, 150))
#' # ten bootstrap replicates, made here by resampling for the example
#' reps <- replicate(10, d$w * tabulate(sample(100, replace = TRUE), 100))
#' des <- svydes(d, w = "w", reps = reps, type = "bootstrap")
#' des
#' # the same data as a stratified design, variance by linearization
#' svydes(d, w = "w", strata = "region")
#'
#' # delete-one jackknife replicates over ten groups of respondents
#' grp <- rep(1:10, length.out = 100)
#' jk <- sapply(1:10, function(g) ifelse(grp == g, 0, d$w * 10 / 9))
#' svydes(d, w = "w", reps = jk, type = "jk1")
#'
#' # a weight column that does not exist
#' try(svydes(d, w = "wt"))
#' @export
svydes <- function(
  data,
  w,
  strata = NULL,
  psu = NULL,
  fpc = NULL,
  reps = NULL,
  id = NULL,
  type = c("bootstrap", "meanboot", "jk1", "jkn", "brr", "fay"),
  msize = 1,
  rho = NULL,
  mse = TRUE,
  lonely = c("fail", "remove", "adjust"),
  rscales = NULL,
  degf = NULL
) {
  if (!is.data.frame(data)) {
    stop("svydes: `data` must be a data frame", call. = FALSE)
  }
  # only the columns the design names must be unique: a duplicated column it
  # does not use is no reason to refuse the data (statistics stress test of
  # 5e1dce5)
  used <- unlist(Filter(
    function(v) is.character(v),
    list(w, strata, psu, fpc, id, reps)
  ))
  twice <- used[used %in% names(data)[duplicated(names(data))]]
  if (length(twice)) {
    stop(
      sprintf("`data` has two columns named %s: rename one", twice[[1L]]),
      call. = FALSE
    )
  }
  n <- nrow(data)
  if (n < 2L) {
    stop("`data` must have at least two rows", call. = FALSE)
  }
  type <- .rmbl_arg(type)
  lonely <- .rmbl_arg(lonely)
  if (!is.logical(mse) || length(mse) != 1L || is.na(mse)) {
    stop("`mse` must be TRUE or FALSE", call. = FALSE)
  }
  .w <- .svy_des_col(data, n, w, "weights")
  if (!is.numeric(.w) || anyNA(.w) || any(!is.finite(.w)) || any(.w < 0)) {
    stop("`w` must be finite, non-negative and not missing", call. = FALSE)
  }
  .w <- as.numeric(.w)
  if (
    !is.null(degf) &&
      (!is.numeric(degf) || length(degf) != 1L || is.na(degf) || degf < 1)
  ) {
    stop("`degf` must be a number of at least 1", call. = FALSE)
  }
  des <- list(
    n = n,
    weights = .w,
    type = NULL,
    scale = NULL,
    mse = mse,
    reps = NULL,
    strata = NULL,
    psu = NULL,
    fpc = NULL,
    lonely = lonely,
    check = .svy_des_check(data, w, strata, psu, reps),
    degf = degf
  )
  if (!is.null(reps)) {
    if (!is.null(strata) || !is.null(psu) || !is.null(fpc)) {
      stop(
        "give replicate weights or strata/PSUs, not both: the ",
        "replicates already carry the design",
        call. = FALSE
      )
    }
    rp <- .svy_des_reps(data, n, w, .w, reps, id)
    .reps <- .svy_reps_numeric(rp$reps)
    .svy_replicate_check(
      .reps,
      .w,
      type,
      data,
      rp$id_values,
      attr(data, "row.names"),
      rp$named,
      rscales
    )
    if (!is.matrix(.reps)) {
      .reps <- unname(.reps)
    }
    B <- if (is.matrix(.reps)) ncol(.reps) else length(.reps)
    .svy_reps_params(type, B, rscales, msize, rho)
    des$scale <- switch(
      type,
      bootstrap = 1 / B,
      meanboot = msize / B,
      jk1 = (B - 1) / B,
      jkn = 1,
      brr = 1 / B,
      fay = 1 / (B * (1 - rho)^2)
    )
    des$type <- type
    des$reps <- .reps
    des$mean_size <- if (type == "meanboot") msize
    des$rho <- if (type == "fay") rho
    des$rscales <- if (!is.null(rscales)) as.numeric(rscales)
    if (is.null(des$degf)) des$degf <- .svy_reps_degf(.reps, B, n)
  } else {
    lin <- .svy_des_linearization(data, n, strata, psu, fpc)
    des$type <- "linearization"
    des$strata <- lin$strata
    des$psu <- lin$psu
    des$fpc <- lin$fpc
    if (is.null(des$degf)) {
      des$degf <- length(unique(lin$psu)) - length(unique(lin$strata))
    }
  }
  structure(des, class = "rmbl_svy_design")
}

#' A design variable of svydes(): a column of `data` named by a string, or the
#' values themselves, one per row.
#' @param data The data frame.
#' @param n Its number of rows.
#' @param x The column name or the values; NULL for none.
#' @param what The argument's name, for the error.
#' @return The values, or NULL.
#' @noRd
.svy_des_col <- function(data, n, x, what) {
  if (is.null(x)) {
    return(NULL)
  }
  if (is.character(x) && length(x) == 1L && n != 1L) {
    if (!x %in% names(data)) {
      stop(
        sprintf("`%s` names a column `data` does not have: %s", what, x),
        call. = FALSE
      )
    }
    x <- data[[x]]
  }
  if (length(x) != n) {
    stop(
      sprintf("`%s` must have one value per row of `data` (%d)", what, n),
      call. = FALSE
    )
  }
  x
}

#' What svyest() checks the data against: the same rows in the same order.
#' Only the row count was checked, and the same data reordered gave a wrong
#' answer silently.
#' @param data,w,strata,psu,reps As for svydes().
#' @return A list: rows, cols, values, rowkeys and cache.
#' @noRd
.svy_des_check <- function(data, w, strata, psu, reps) {
  named <- function(x) if (is.character(x) && length(x) == 1L) x
  check <- list(
    rows = attr(data, "row.names"),
    cols = Filter(
      Negate(is.null),
      list(weights = named(w), strata = named(strata), psu = named(psu))
    )
  )
  check$values <- lapply(check$cols, function(cn) data[[cn]])
  # the rows as a set and in order: a reordered tibble (row names always 1..n)
  # with a vector weight gave SE 13.8 for 20.2 silently (review of 46de6a9), and
  # rows reordered within their strata or PSUs passed the named columns' check
  # too (statistics stress test of 5e1dce5) the replicate columns named in
  # `reps` are kept in the design itself, so they need no digest: twenty of them
  # made a design by name and every estimate on it 2 to 5 times slower than the
  # same replicates passed as a matrix (re-test of the b617a3f CRAN stress
  # fixes, 1e6 rows)
  check$rowkeys <- .svy_rowkey_digests(
    if (is.character(reps)) {
      data[, !(names(data) %in% reps), drop = FALSE]
    } else {
      data
    }
  )
  # the data frame the last check passed on, held by reference (no copy) in an
  # environment the design keeps: the next estimate on the same object skips the
  # digests, which were recomputed on every estimate (21 s each at 5e6 rows;
  # final audit of 1.0.0). An edited data frame is another object to R (copy on
  # modify), so identical() is the whole test.
  check$cache <- new.env(parent = emptyenv())
  check
}

#' The replicate weights given to svydes(), as column names, a matrix or a data
#' frame.
#' @param data,n,w,reps,id As for svydes() (`n` its number of rows).
#' @param .w The full weight's values.
#' @return A list: reps (a double matrix or a list of columns), id_values (the
#'   ids the rows were matched on, or NULL) and named (whether the replicates
#'   came with names).
#' @noRd
.svy_des_reps <- function(data, n, w, .w, reps, id) {
  if (is.character(reps)) {
    miss <- setdiff(reps, names(data))
    if (length(miss)) {
      stop(
        sprintf(
          "replicate columns not in `data`: %s",
          paste(utils::head(miss, 5), collapse = ", ")
        ),
        call. = FALSE
      )
    }
    own <- intersect(reps, c(if (is.character(w) && length(w) == 1L) w, id))
    if (length(own)) {
      stop(
        sprintf(
          paste0(
            "`reps` names %s, which is not a replicate weight (the full ",
            "weight or the id)"
          ),
          paste(own, collapse = ", ")
        ),
        call. = FALSE
      )
    }
    .reps <- unname(as.list(data[reps]))
    names(.reps) <- reps
    return(list(reps = .reps, id_values = NULL, named = TRUE))
  }
  # a matrix with an extra class (a "repweights" object) was dispatched to
  # another as.data.frame method and read wrongly whether the columns came
  # with names (as.data.frame invents V1, V2, ... for a bare matrix)
  named <- !is.null(colnames(reps)) && any(nzchar(colnames(reps)))
  # a double matrix is kept as it is and its columns read in place: a list
  # copied from it was a second 800 MB at 5e6 rows and 20 replicates, and
  # the design failed under 3 GB where the same replicates by name passed
  # (final audit of 1.0.0). One with an id, or not double, goes the data
  # frame way.
  if (is.matrix(reps) && is.double(reps) && is.null(id)) {
    return(list(
      reps = .svy_reps_matrix(unclass(reps), n, w, .w),
      id_values = NULL,
      named = named
    ))
  }
  if (is.matrix(reps)) {
    reps <- as.data.frame.matrix(unclass(reps))
  }
  if (!is.data.frame(reps)) {
    stop(
      "`reps` must be a data frame, a matrix or column names",
      call. = FALSE
    )
  }
  fr <- .svy_reps_frame(data, n, w, .w, reps, id)
  list(reps = fr$reps, id_values = fr$id_values, named = named)
}

#' The full weight's values within a rounding error (1e-12 of it, the replicate
#' check's own tolerance): identical() refused a copy 1e-13 off (statistics
#' stress test of 5e1dce5).
#' @param v A column.
#' @param .w The full weight.
#' @return TRUE or FALSE.
#' @noRd
.svy_is_full_weight <- function(v, .w) {
  is.numeric(v) &&
    !any(
      abs(as.numeric(v) - .w) > 1e-12 * pmax(abs(.w), .Machine$double.xmin)
    )
}

#' Refuses a replicate column that carries the full weight's name but not its
#' values.
#' @param w The full weight's name.
#' @noRd
.svy_stop_weight_name <- function(w) {
  stop(
    sprintf(
      paste(
        "column %s of `reps` has the full weight's name but",
        "not its values: rename",
        "it, or give only the replicate columns"
      ),
      w
    ),
    call. = FALSE
  )
}

#' Replicate weights given as a double matrix, read in place.
#' @param reps The matrix, unclassed.
#' @param n,w,.w As for .svy_des_reps().
#' @return The matrix, without a column that is the full weight.
#' @noRd
.svy_reps_matrix <- function(reps, n, w, .w) {
  if (nrow(reps) != n) {
    stop(
      sprintf(
        "svydes: `reps` must have one row per row of `data` (%d)",
        n
      ),
      call. = FALSE
    )
  }
  if (is.character(w) && length(w) == 1L && w %in% colnames(reps)) {
    for (i in which(colnames(reps) == w)) {
      if (!.svy_is_full_weight(reps[, i], .w)) .svy_stop_weight_name(w)
    }
    reps <- reps[, colnames(reps) != w, drop = FALSE]
  }
  # not named here: setting dimnames on the caller's matrix copied it
  # (762.9 MB at 5e6 x 20)
  for (j in seq_len(ncol(reps))) {
    r <- reps[, j]
    if (anyNA(r) || any(!is.finite(r)) || any(r < 0)) {
      stop(
        "svydes: replicate weights must be finite, non-negative ",
        "and not missing",
        call. = FALSE
      )
    }
  }
  reps
}

#' Replicate weights given as a data frame, matched to the rows of `data` by
#' `id` when it is given.
#' @param data,n,w,.w,id As for .svy_des_reps().
#' @param reps The data frame.
#' @return A list: reps (a named list of columns) and id_values.
#' @noRd
.svy_reps_frame <- function(data, n, w, .w, reps, id) {
  id_values <- NULL
  if (!is.null(id)) {
    m <- .svy_reps_match_id(data, reps, id)
    id_values <- reps[[id]][m]
    reps <- reps[m, names(reps) != id, drop = FALSE]
  }
  if (nrow(reps) != n) {
    stop(
      sprintf(
        "svydes: `reps` must have one row per row of `data` (%d)",
        n
      ),
      call. = FALSE
    )
  }
  # the full weight named in `w`, shipped beside the replicates (CSUS's
  # bootstrap file carries WGT_PUMF), is the weight and not a replicate:
  # set aside when it is the weight. A column that only carries the
  # weight's name is refused, not dropped (a genuine replicate called "pw"
  # went silently, B 24 -> 23; review of 29a55d8, F2)
  if (is.character(w) && length(w) == 1L && w %in% names(reps)) {
    for (i in which(names(reps) == w)) {
      if (!.svy_is_full_weight(reps[[i]], .w)) .svy_stop_weight_name(w)
    }
    reps <- reps[, names(reps) != w, drop = FALSE]
  }
  .reps <- as.list(reps)
  if (is.null(names(.reps)) || any(!nzchar(names(.reps)))) {
    names(.reps) <- sprintf("V%d", seq_along(.reps))
  }
  list(reps = .reps, id_values = id_values)
}

#' The row of `reps` for each row of `data`, matched on the column `id`.
#' @param data,reps The data and the replicate data frame.
#' @param id The id column's name.
#' @return Row indices into `reps`.
#' @noRd
.svy_reps_match_id <- function(data, reps, id) {
  if (
    !is.character(id) ||
      length(id) != 1L ||
      !id %in% names(data) ||
      !id %in% names(reps)
  ) {
    stop(
      "`id` must name a column present in both `data` and `reps`",
      call. = FALSE
    )
  }
  if (anyDuplicated(reps[[id]])) {
    stop("`id` repeats in `reps`", call. = FALSE)
  }
  m <- match(data[[id]], reps[[id]])
  if (anyNA(m)) {
    stop(
      sprintf(
        "%d row(s) of `data` have no replicate weights",
        sum(is.na(m))
      ),
      call. = FALSE
    )
  }
  # a second column with the id's name: the id itself is set aside, and
  # one that holds other values is refused, as a column with the
  # weight's name is (dropped with the id it was B 24 -> 23, kept it was
  # a replicate nobody named; reviews of 46de6a9 and 5e1dce5)
  for (i in which(names(reps) == id)[-1L]) {
    if (!identical(reps[[i]], reps[[id]])) {
      stop(
        sprintf(
          paste(
            "column %s of `reps` has the id's name but not its",
            "values: rename it,",
            "or give only the replicate columns"
          ),
          id
        ),
        call. = FALSE
      )
    }
  }
  m
}

#' Replicate columns given as a list, checked to be numbers that are finite,
#' non-negative and not missing; a matrix is returned as it is (its columns
#' were checked when it was read).
#' @param .reps The list of columns, or a double matrix.
#' @return The columns as doubles, or the matrix.
#' @noRd
.svy_reps_numeric <- function(.reps) {
  if (is.matrix(.reps)) {
    return(.reps)
  }
  bad <- which(!vapply(.reps, is.numeric, NA))
  if (length(bad)) {
    stop(
      sprintf(
        paste0(
          "not a replicate weight: %s (not numbers); give only the ",
          "replicate columns"
        ),
        names(.reps)[[bad[[1L]]]]
      ),
      call. = FALSE
    )
  }
  lapply(.reps, function(r) {
    if (anyNA(r) || any(!is.finite(r)) || any(r < 0)) {
      stop(
        "svydes: replicate weights must be finite, non-negative and ",
        "not missing",
        call. = FALSE
      )
    }
    as.numeric(r)
  })
}

#' Checks the replicate type's own arguments against the number of replicates.
#' @param type,rscales,msize,rho As for svydes().
#' @param B The number of replicates.
#' @noRd
.svy_reps_params <- function(type, B, rscales, msize, rho) {
  if (B < 2L) {
    stop("at least two replicate weights are needed", call. = FALSE)
  }
  if (type == "jkn" && is.null(rscales)) {
    stop(
      "type = \"jkn\" needs `rscales`: (n_h - 1) / n_h for the stratum ",
      "each replicate deletes from",
      call. = FALSE
    )
  }
  if (
    !is.null(rscales) &&
      (!is.numeric(rscales) ||
        length(rscales) != B ||
        anyNA(rscales) ||
        any(!is.finite(rscales)) ||
        any(rscales < 0))
  ) {
    stop(
      sprintf(
        "`rscales` must be %d finite non-negative numbers, one per replicate",
        B
      ),
      call. = FALSE
    )
  }
  .svy_reps_type_args(type, B, msize, rho)
}

#' Checks meanboot's `msize`, Fay's `rho` and the number of BRR replicates.
#' @param type,msize,rho As for svydes().
#' @param B The number of replicates.
#' @noRd
.svy_reps_type_args <- function(type, B, msize, rho) {
  if (
    type == "meanboot" &&
      (!is.numeric(msize) ||
        length(msize) != 1L ||
        !is.finite(msize) ||
        msize < 1)
  ) {
    stop("`msize` must be a number of at least 1", call. = FALSE)
  }
  if (type == "fay") {
    if (
      !is.numeric(rho) ||
        length(rho) != 1L ||
        !is.finite(rho) ||
        rho < 0 ||
        rho >= 1
    ) {
      stop("`rho` must be a number in [0, 1) for Fay's BRR", call. = FALSE)
    }
  }
  if (type %in% c("brr", "fay") && B > 2L && B %% 4L != 0L) {
    stop(
      sprintf(
        paste(
          "%d replicates is not a Hadamard order (2, or a multiple of",
          "4): BRR replicates",
          "come in those numbers, so a column that is not a replicate",
          "may be included"
        ),
        B
      ),
      call. = FALSE
    )
  }
  invisible(NULL)
}

#' The design's degrees of freedom as the survey package computes them, the
#' rank of the replicate weight matrix less one; the rank is read from the
#' eigenvalues of its cross-product (singular values within 1e-5 of the
#' largest count), which is the B x B problem: a QR of the n x B matrix took
#' 16 s for CSUS's 36,180 x 1,000.
#' @param .reps The replicates, a double matrix or a list of columns.
#' @param B Their number.
#' @param n The number of rows.
#' @return An integer.
#' @noRd
.svy_reps_degf <- function(.reps, B, n) {
  # the replicates scaled by their largest value: a replicate of 1e308
  # overflowed the cross-product to Inf and eigen() failed in its own words
  # (final audit of 1.0.0, #8)
  sc <- if (is.matrix(.reps)) {
    max(0, vapply(seq_len(B), function(j) max(abs(.reps[, j])), 0))
  } else {
    max(vapply(.reps, function(r) if (length(r)) max(abs(r)) else 0, 0))
  }
  if (!is.finite(sc) || sc == 0) {
    sc <- 1
  }
  # the rank is at most min(n, B): the smaller Gram matrix is the one read.
  # B replicates on n rows with B > n (n = 20, B = 1e5) built a B x B
  # product that asked for 74.5 GB and B = 5,000 took 113 s where a 200 x
  # 200 one is instant (final audit of 1.0.0, #8)
  if (B <= n) {
    # the cross-product a block of rows at a time: do.call(cbind, reps) was
    # a second copy of every replicate (800 MB at 5e6 rows and 20
    # replicates; CRAN stress test of 0.5.14, #8)
    cp <- matrix(0, B, B)
    for (st in if (n > 0L) seq(1L, n, by = 262144L)) {
      idx <- st:min(n, st + 262143L)
      blk <- if (is.matrix(.reps)) {
        .reps[idx, , drop = FALSE] / sc
      } else {
        vapply(.reps, function(r) r[idx] / sc, numeric(length(idx)))
      }
      cp <- cp + crossprod(blk)
    }
  } else {
    cp <- matrix(0, n, n)
    for (st in seq(1L, B, by = 4096L)) {
      idx <- st:min(B, st + 4095L)
      m <- if (is.matrix(.reps)) {
        .reps[, idx, drop = FALSE] / sc
      } else {
        vapply(.reps[idx], function(r) r / sc, numeric(n))
      }
      cp <- cp + tcrossprod(m)
    }
  }
  ev <- eigen(cp, symmetric = TRUE, only.values = TRUE)$values
  sum(ev > max(ev) * 1e-10) - 1L
}

#' Strata, PSUs and finite population corrections for a design estimated by
#' linearization.
#' @param data,n,strata,psu,fpc As for svydes() (`n` its number of rows).
#' @return A list: strata and psu (integer codes) and fpc (the sampling
#'   fraction of each row's stratum, or NULL).
#' @noRd
.svy_des_linearization <- function(data, n, strata, psu, fpc) {
  s <- .svy_des_col(data, n, strata, "strata")
  p <- .svy_des_col(data, n, psu, "psu")
  if (!is.null(s) && anyNA(s)) {
    stop("`strata` has missing values", call. = FALSE)
  }
  if (!is.null(p) && anyNA(p)) {
    stop("`psu` has missing values", call. = FALSE)
  }
  s <- if (is.null(s)) rep(1L, n) else as.integer(factor(s))
  p <- if (is.null(p)) {
    seq_len(n)
  } else {
    as.integer(factor(paste(s, p, sep = "\r")))
  }
  f <- .svy_des_col(data, n, fpc, "fpc")
  if (!is.null(f)) {
    if (!is.numeric(f) || anyNA(f) || any(f <= 0)) {
      stop("`fpc` must be positive and not missing", call. = FALSE)
    }
    # one value per stratum
    if (any(tapply(f, s, function(v) length(unique(v))) > 1L)) {
      stop("`fpc` must be constant within each stratum", call. = FALSE)
    }
    npsu <- tapply(p, s, function(v) length(unique(v)))
    fs <- tapply(f, s, `[`, 1L)
    frac <- if (all(f <= 1)) fs else npsu / fs
    if (any(frac > 1 + 1e-12)) {
      stop(
        "`fpc` gives a stratum more sampled PSUs than its population",
        call. = FALSE
      )
    }
    f <- as.numeric(frac)
  }
  list(strata = s, psu = p, fpc = f)
}

#' The design's degrees of freedom (svydes(): PSUs less strata, the replicate
#' matrix's rank less one, or as given)
#' @param des A design from `svydes()`.
#' @return The degrees of freedom.
#' @noRd
.svy_df <- function(des) {
  if (!is.null(des$degf)) {
    return(des$degf)
  }
  if (identical(des$type, "linearization")) {
    length(unique(des$psu)) - length(unique(des$strata))
  } else {
    .svy_nrep(des) - 1L
  }
}

#' The number of replicates a design holds (a list of columns, or a matrix kept
#' as given)
#' @param des A design from `svydes()`.
#' @return The number of replicates; 0 for a linearisation design.
#' @noRd
.svy_nrep <- function(des) {
  if (is.matrix(des$reps)) ncol(des$reps) else length(des$reps)
}

#' The data must be the rows the design was built on, in the same order
#' @param design A design from `svydes()`.
#' @param data The data frame passed to the estimator.
#' @return NULL, invisibly; an error when `data` is not the design's data.
#' @noRd
.svy_check_data <- function(design, data) {
  if (!is.data.frame(data) || nrow(data) != design$n) {
    stop("`data` must be the data frame the design was built on", call. = FALSE)
  }
  ck <- design$check
  if (is.null(ck)) {
    return(invisible())
  }
  cache <- ck$cache
  if (
    is.environment(cache) && !is.null(cache$last) && identical(data, cache$last)
  ) {
    return(invisible())
  }
  same_cols <- all(vapply(
    names(ck$cols),
    function(k) {
      cn <- ck$cols[[k]]
      cn %in% names(data) && identical(data[[cn]], ck$values[[k]])
    },
    logical(1)
  ))
  # whether the rows are in the order the design was built on, read from the
  # rows themselves; NA when they cannot tell, and then the row names decide
  in_order <- NA
  rk <- ck$rowkeys
  if (same_cols && !is.null(rk)) {
    present <- intersect(rk$cols, names(data))
    if (length(present) && length(present) == length(rk$cols)) {
      now <- .svy_rowkey_digests(data[rk$cols])
      # the same rows in another order: a reorder, whatever the row names say. A
      # column changed since (a permuted y for a permutation test, a recode)
      # changes the rows themselves and passes; it was refused as a reorder when
      # each column was compared on its own (statistics stress test of 5e1dce5)
      if (identical(now$sorted, rk$sorted)) {
        in_order <- identical(now$ordered, rk$ordered)
      } else if (!is.null(rk$keys) && length(rk$keys) == length(now$keys)) {
        # cells edited since: each row's key is looked for among the built keys.
        # A row whose key is at its own position is in place; one whose key is
        # at another position has moved; one found nowhere was edited. Rows that
        # moved beside fewer edited ones are a reorder, whatever the columns the
        # reorder left unchanged say (a swap of two rows and one edited cell was
        # read as in order because the columns equal on the two rows counted as
        # "not moved": SE 9.60 for 9.92 silently; final audit of 1.0.0, #3). A
        # permuted or recoded column changes rows and moves none, and passes as
        # before
        inplace <- now$keys == rk$keys
        found <- now$keys %in% rk$keys
        moved <- sum(found & !inplace)
        edited <- sum(!found)
        in_order <- !(moved >= 2L && moved > edited)
      }
    }
    if (is.na(in_order) && length(present) && !is.null(rk$colsor)) {
      # a column dropped or one cell edited since: the rows as a whole differ,
      # so each column that still holds the same values is read on its own. One
      # of them in another order is a permuted column; two or more are the rows
      # reordered (reorder then drop or edit a column gave a wrong SE silently;
      # CRAN stress test of b617a3f, #3)
      now <- .svy_rowkey_digests(data[present])
      cs <- intersect(present, intersect(now$cols, names(rk$colsor)))
      cs <- cs[rk$colinf[cs] & now$colsor[cs] == rk$colsor[cs]]
      moved <- sum(now$colord[cs] != rk$colord[cs])
      # a reorder moves every column that still holds its values; two permuted
      # outcomes beside columns still in place are columns changed since, not a
      # reorder (they were refused as one; re-test of the b617a3f CRAN stress
      # fixes)
      if (moved >= 2L && moved == length(cs)) {
        in_order <- FALSE
      } else if (length(cs) > moved) {
        in_order <- TRUE
      }
    }
  }
  # a row-name reset (rownames(d) <- NULL) on rows still in order is the same
  # data (refused as a reorder; CRAN stress test of b617a3f)
  same_rows <- if (is.na(in_order)) {
    identical(attr(data, "row.names"), ck$rows)
  } else {
    in_order
  }
  if (!same_rows || !same_cols) {
    stop(
      paste(
        "`data` is not the data frame the design was built on (its rows",
        "are in another order, or",
        "its weight, strata or PSU columns differ): build the design on",
        "this data"
      ),
      call. = FALSE
    )
  }
  if (is.environment(cache)) {
    cache$last <- data
  }
  invisible()
}

#' Digests the rows of a data frame in an order-free and an ordered form.
#'
#' One number per row that does not depend on the row order: each column's
#' values coded by their rank among its distinct values (a radix sort, so no
#' locale), folded into the row's key modulo 2^31 - 1 (exact in a double).
#' Digested in row order and sorted: the same rows in another order have the
#' same sorted digest and a different ordered one. A million rows of ten columns
#' take about a second; the per-column text digests this replaces took 88 s per
#' estimate (statistics stress test of 5e1dce5).
#' @param data The data frame.
#' @return A list with the columns used, the ordered and sorted digests, each
#'   row's key and per-column digests.
#' @noRd
.svy_rowkey_digests <- function(data) {
  nm <- names(data) %||% character(length(data))
  # the columns that can be found again by name: atomic, named, the name used
  # once
  keep <- vapply(data, function(v) is.atomic(v) && !is.null(v), NA) &
    !is.na(nm) &
    nzchar(nm) &
    !(nm %in% nm[duplicated(nm)])
  cols <- nm[keep]
  n <- nrow(data)
  k <- numeric(n)
  # x mod 2^31 - 1 by floor(): R's %% on doubles took most of the time.
  # Deterministic, which is all a key needs, and under 2^53 after the next
  # multiply
  fold <- function(x) x - 2147483647 * floor(x / 2147483647)
  co <- cs <- ci <- list()
  for (i in which(keep)) {
    # a one-dimensional array (apiclus2 has one) is its values
    v <- as.vector(data[[i]])
    code <- if (is.double(v)) {
      # the bits of the number: the same value gives the same code wherever its
      # row is, with no sort or match (in C: the R arithmetic's own result,
      # without its column-long copies)
      .Call(C_rmbl_svy_dblcode, v)
    } else if (is.integer(v) || is.logical(v)) {
      # the same codes as a double column's: an edit that turned an integer
      # column into a double one (x$meals[5] <- x$meals[5] + 1) changed every
      # row's code with it, and the rows as a whole read as all changed rather
      # than two moved and one edited (final audit of 1.0.0, #3)
      .Call(C_rmbl_svy_dblcode, as.numeric(v))
    } else {
      if (is.complex(v)) {
        v <- paste(Re(v), Im(v))
      }
      match(v, sort(unique(v), method = "radix", na.last = TRUE))
    }
    k <- fold(k * 1000003 + code)
    code <- as.numeric(code)
    co[[nm[[i]]]] <- .Call(C_rmbl_sha256_real, code)
    # the column as a set of values: an order-independent digest, not the sorted
    # column's (the sort copied the column and asked for working memory as long
    # again; final audit of 1.0.0, #3)
    cs[[nm[[i]]]] <- .Call(C_rmbl_svy_msethash, code)
    ci[[nm[[i]]]] <- n > 0L && any(code != code[[1L]])
  }
  # each column on its own as well, in order and as a set, and whether it holds
  # more than one value: what .svy_check_data() reads when a column was dropped
  # or edited since the keys themselves as well (one double a row): what
  # .svy_check_data() reads when a cell was edited since, to tell rows that
  # moved from rows that changed
  list(
    cols = cols,
    ordered = .Call(C_rmbl_sha256_real, k),
    sorted = .Call(C_rmbl_svy_msethash, k),
    keys = k,
    colord = unlist(co),
    colsor = unlist(cs),
    colinf = unlist(ci)
  )
}

#' Checks that the replicate weights given are replicate weights.
#'
#' The replicates are exactly the columns given, by name or as the object
#' passed: nothing is guessed from values (the totals, constancy and
#' multiplier-shape rules of 46de6a9 and after refused genuine sets, a dominant
#' PSU or a jackknife on a subset, and still passed strays; reviews of 46de6a9).
#' What is refused is exact: the full-sample weight itself (a jackknife, BRR or
#' Fay replicate always changes some rows; a bootstrap replicate that draws
#' every PSU once is the weight, legitimately, and survey's rescaled multipliers
#' put it a rounding error off), the id's values, the row numbers, and a column
#' of `data` passed under another name. A column of `data` passed under its own
#' name is a replicate because it was asked for; so is every column of an
#' unnamed matrix, which has no names to compare (reviews of 46de6a9).
#' @param reps The replicates: a list of numeric columns or a matrix.
#' @param w The full-sample weights.
#' @param type The replicate type (\code{"bootstrap"}, \code{"meanboot"},
#' \code{"jk1"}, \code{"jkn"}, \code{"brr"} or \code{"fay"}).
#' @param data The data frame the design is built on.
#' @param id_values The PSU id values, when numeric.
#' @param row_names The row names of `data`.
#' @param named Whether the replicates were given by name, so their names can be
#'   compared with the columns of `data`.
#' @param rscales The per-replicate scales given, or NULL.
#' @return `TRUE`, invisibly; warnings for replicates kept as given.
#' @noRd
.svy_replicate_check <- function(
  reps,
  w,
  type,
  data,
  id_values = NULL,
  row_names = NULL,
  named = TRUE,
  rscales = NULL
) {
  n <- length(w)
  # the replicates as a list of columns or as the matrix given: each column read
  # in place, ONCE. Every rule below reads a summary of the column made on that
  # one pass (the earlier five passes over 20 columns of 5e6 rows were 4 GB of
  # transient copies and 17 s; final audit of 1.0.0)
  B <- if (is.matrix(reps)) ncol(reps) else length(reps)
  rnm <- if (is.matrix(reps)) colnames(reps) else names(reps)
  if (is.null(rnm)) {
    rnm <- sprintf("V%d", seq_len(B))
  }
  rnm[!nzchar(rnm)] <- sprintf("V%d", seq_len(B))[!nzchar(rnm)]
  rn <- if (is.numeric(row_names)) as.numeric(row_names) else NULL
  idv <- if (is.numeric(id_values)) as.numeric(id_values) else NULL
  numcols <- Filter(is.numeric, as.list(data))
  summ <- .svy_rc_summaries(reps, w, idv, rn, B)
  inf_idx <- which(!.svy_rc_get(summ, "same"))
  adjusted <- .svy_rc_adjusted(summ, type, B, inf_idx)
  # JKn with its rscales: the replicate deleting a PSU of a stratum of m PSUs
  # scales the stratum's other rows by m / (m - 1), which is 1 / rscale, and
  # leaves the other strata at 1. From 101 PSUs on that is within 1% of the
  # weight, and on a domain without the deleted PSU's rows it was refused as a
  # copy (stratum of 150 PSUs; pre-CRAN audit of 30bed8e)
  rsc <- if (
    identical(type, "jkn") &&
      is.numeric(rscales) &&
      length(rscales) == B &&
      all(is.finite(rscales))
  ) {
    rscales
  }
  ctx <- list(
    reps = reps,
    summ = summ,
    type = type,
    B = B,
    rnm = rnm,
    rsc = rsc,
    adjusted = adjusted,
    wvaries = n > 0L && max(w) != min(w),
    named = named,
    numcols = numcols,
    keys = lapply(numcols, function(v) .svy_rc_key(as.numeric(v), n)),
    # the factor each unadjusted jackknife replicate applies to the rows it
    # keeps, and how many carry it (see .svy_rc_stray())
    fac_of = if (!adjusted && type %in% c("jk1", "jkn")) {
      .svy_rc_get(summ, "fac")
    } else {
      rep(NA_real_, B)
    }
  )
  warned <- character()
  equal <- integer()
  for (b in seq_len(B)) {
    res <- .svy_rc_one(b, ctx)
    warned <- c(warned, res$warn)
    if (res$equal) equal <- c(equal, b)
  }
  if (identical(type, "jkn") && length(equal) == B) {
    stop(
      "every replicate is the full-sample weight: give the replicate weights",
      call. = FALSE
    )
  }
  # one JKn replicate equal to the weight: a stratum left out of a subset leaves
  # all its (two or more) replicates at the weight, so a single one is the
  # weight passed beside them (accepted; re-test of the b617a3f CRAN stress
  # fixes)
  if (identical(type, "jkn") && !adjusted && length(equal) == 1L) {
    .svy_rc_refuse(rnm, equal[[1L]], "the full-sample weight")
  }
  # two or more JKn replicates equal to the weight are kept: a stratum left out
  # of a subset leaves all of its replicates at the weight, and two copies of it
  # look the same (documented)
  if (length(equal) && identical(type, "bootstrap") && !adjusted) {
    warned <- c(warned, .svy_rc_boot_equal(reps, w, B, rnm, equal))
  }
  .svy_rc_warn(warned, mean(.svy_rc_get(summ, "total")) / sum(w))
  invisible(TRUE)
}

#' One replicate column, read in place.
#' @param reps The replicates: a list of columns or a matrix.
#' @param b The column's index.
#' @return The column.
#' @noRd
.svy_rc_col <- function(reps, b) if (is.matrix(reps)) reps[, b] else reps[[b]]

#' A cheap key of a numeric column: its first and last values and its sum.
#' @param v The column, as doubles.
#' @param n Its length.
#' @return Three numbers.
#' @noRd
.svy_rc_key <- function(v, n) c(v[1L], v[n], sum(v))

#' Refuses a replicate that is not a replicate weight.
#' @param rnm The replicates' names.
#' @param b The replicate's index.
#' @param what What it is instead.
#' @noRd
.svy_rc_refuse <- function(rnm, b, what) {
  stop(
    sprintf(
      paste0(
        "replicate %s is %s, not a replicate weight; give only the ",
        "replicate columns"
      ),
      rnm[[b]] %||% b,
      what
    ),
    call. = FALSE
  )
}

#' One field of every replicate's summary, as a vector.
#' @param summ The summaries (.svy_rc_summaries()).
#' @param what The field.
#' @return A logical vector for the flags, numbers otherwise.
#' @noRd
.svy_rc_get <- function(summ, what) {
  flags <- c("same", "anyzero", "const", "isid", "isrow", "counts")
  vapply(summ, function(x) x[[what]], if (what %in% flags) NA else 0)
}

#' One summary per replicate, made on a single pass over its column.
#'
#' The factors r / w a replicate applies on the rows it keeps. Unadjusted, a
#' jackknife or BRR replicate has at most three (0 aside: 1, n / (n - 1), 2) and
#' a bootstrap a handful of counts; post-stratified or calibrated, each row has
#' its own. Read on the set, by majority, so one stray column does not make a
#' whole set look adjusted. Adjusted, a replicate equal to the weight or within
#' 1% of it is genuine on a subset, where the PSU it deletes is outside the rows
#' (post- stratification brings it back to the weight): 18 post-stratified and
#' 4 JKn calibrated designs were refused, and 16 bootstrap and BRR subsets
#' warned about (re-test of the b617a3f CRAN stress fixes) read on the first
#' 4,096 rows each keeps: an adjustment shows there as well as anywhere, and the
#' whole column took a second a million rows. The pass over the column is in C,
#' with nothing allocated as long as it (the R pass held 340 MB per column at
#' 5e6 rows; final audit of 1.0.0, #3)
#' @param reps The replicates.
#' @param w The full-sample weights.
#' @param idv,rn The numeric id values and row names, or NULL.
#' @param B The number of replicates.
#' @return A list of B summaries.
#' @noRd
.svy_rc_summaries <- function(reps, w, idv, rn, B) {
  n <- length(w)
  pg <- blprog("checking replicate weights", B)
  on.exit(pg$done(), add = TRUE)
  summ <- vector("list", B)
  i8 <- seq_len(min(n, 8192L))
  w8 <- pmax(w[i8], .Machine$double.xmin)
  for (b in seq_len(B)) {
    pg$update(b - 1L, sprintf("replicate %d/%d", b, B))
    r <- .svy_rc_col(reps, b)
    s <- .Call(C_rmbl_svy_colsumm, r, w, idv, rn)
    hk <- s$hk
    fh <- unique(signif(r[hk] / w[hk], 9))
    # one factor on every row kept (no hashing of the column)
    fullfac <- if (!is.na(s$fullfac) && signif(s$fullfac, 9) != 1) {
      signif(s$fullfac, 9)
    } else {
      NA_real_
    }
    fnz <- fh[fh != 1]
    summ[[b]] <- list(
      same = s$same,
      maxrel = s$maxrel,
      anyzero = s$anyzero,
      const = s$const,
      total = sum(r),
      key = .svy_rc_key(r, n),
      isid = s$isid,
      isrow = s$isrow,
      nfac = length(fh),
      fh = fh,
      f1 = if (length(fh) == 1L) fh else NA_real_,
      fac = if (length(fnz) == 1L) fnz else NA_real_,
      fullfac = fullfac,
      counts = length(hk) > 0L && all(abs(fh - round(fh)) < 1e-9),
      # the factors on the first rows, zeros included (a BRR replicate keeps one
      # PSU of each pair)
      nfac_all = length(unique(signif(r[i8] / w8, 9))),
      typical = if (length(hk)) stats::median(r[hk] / w[hk]) else NA_real_
    )
  }
  summ
}

#' Jackknife and BRR: a factor off the lattice 1, 2, k / (k - 1) is an
#' adjustment's (three post-strata give few factors, but not these); a
#' bootstrap's counts are many, so there it is their number.
#' @param x One replicate's summary.
#' @param B The number of replicates.
#' @return TRUE or FALSE.
#' @noRd
.svy_rc_off_lattice <- function(x, B) {
  f <- x$fh
  if (!length(f)) {
    return(FALSE)
  }
  # whole numbers are counts (a bootstrap set called a jackknife), never an
  # adjustment's factors
  f <- f[abs(f - round(f)) > 1e-9]
  if (!length(f)) {
    return(FALSE)
  }
  m <- f / (f - 1)
  any(f <= 1 | abs(m - round(m)) > 1e-6 * abs(m) | round(m) > B)
}

#' Whether a JK1 set is unadjusted.
#'
#' The vote is among the replicates that differ from the weight: one equal to
#' it says nothing of an adjustment, and on a post-stratum subset most are (each
#' deletes a PSU with no row there, and post-stratification brings the rest
#' back to the weight): the set read as unadjusted and was refused (apiclus1 JK1
#' post-stratified on stype, rows of H; CRAN stress test of 0.5.14, #5) JK1
#' unadjusted scales every row a replicate keeps by one factor, n / (n - 1), the
#' same in all n of them (n PSUs): the factor that most replicates share, held
#' by exactly n of them. A stray column beside them (the weight, a jittered
#' copy) leaves that intact. Post-stratified, the factor of each replicate is
#' its own: 14/13, 7/6, 7/5 ... on a post-stratum (some look like a k / (k - 1),
#' but not shared by k replicates), and the set is adjusted (CRAN stress test of
#' 0.5.14, #5)
#' @param summ The summaries.
#' @param inf_idx The replicates that differ from the weight.
#' @param B The number of replicates.
#' @return TRUE or FALSE.
#' @noRd
.svy_rc_jk1_unadjusted <- function(summ, inf_idx, B) {
  f1 <- .svy_rc_get(summ, "f1")[inf_idx]
  u <- unique(f1[!is.na(f1)])
  if (!length(u)) {
    return(FALSE)
  }
  cnt <- tabulate(match(f1, u), length(u))
  c1 <- u[[which.max(cnt)]]
  nm <- max(cnt)
  # the k of k / (k - 1) is the number of replicates sharing the factor, or
  # the number of those that leave a row out: the full data plus a column w *
  # 15/14 made 16 of a factor whose k is 15, and the set read as adjusted, so
  # the copy passed silently (final audit of 1.0.0, #9)
  out <- .svy_rc_get(summ, "anyzero")[inf_idx]
  nout <- sum(out & !is.na(f1) & f1 == c1)
  k <- c1 / (c1 - 1)
  nm > B / 2 &&
    c1 > 1 &&
    (abs(k - nm) < 1e-6 * nm || abs(k - nout) < 1e-6 * max(nout, 1))
}

#' Whether the replicate set is adjusted (post-stratified or calibrated), read
#' by majority among the replicates that differ from the weight.
#' @param summ The summaries.
#' @param type The replicate type.
#' @param B The number of replicates.
#' @param inf_idx The replicates that differ from the weight.
#' @return TRUE or FALSE.
#' @noRd
.svy_rc_adjusted <- function(summ, type, B, inf_idx) {
  length(inf_idx) > 0L &&
    if (identical(type, "jk1")) {
      # whole-number factors are a bootstrap's counts (a bootstrap set called a
      # jackknife), never an adjustment's
      !.svy_rc_jk1_unadjusted(summ, inf_idx, B) &&
        !(sum(.svy_rc_get(summ, "counts")[inf_idx]) > length(inf_idx) / 2)
    } else if (type %in% c("jkn", "brr")) {
      sum(vapply(summ[inf_idx], .svy_rc_off_lattice, NA, B = B)) >
        length(inf_idx) / 2
    } else {
      sum(.svy_rc_get(summ, "nfac")[inf_idx] > 8L) > length(inf_idx) / 2
    }
}

#' A jackknife replicate whose deleted PSU is outside the rows scales every row
#' by one factor k / (k - 1), and 1 elsewhere: JK1 with k the number of
#' replicates (n PSUs), JKn with k the PSUs of its stratum, post-stratified JK1
#' with k those of the post-stratum. With 101 PSUs or more that is within 1% of
#' the weight, and it was refused as a copy on 15 JK1 domain subsets (re-test of
#' the b617a3f CRAN stress fixes).
#' @param x One replicate's summary.
#' @param B The number of replicates.
#' @return TRUE or FALSE.
#' @noRd
.svy_rc_jk_scale <- function(x, B) {
  f <- x$fullfac
  if (is.na(f) || f <= 1) {
    return(FALSE)
  }
  m <- f / (f - 1)
  # post-stratified JK1 has its post-stratum's k, not the number of replicates
  abs(m - round(m)) < 1e-6 * m && round(m) <= B
}

#' Whether a JKn replicate's factors are 1 and 1 / rscale only.
#' @param x One replicate's summary.
#' @param rsc The rscales given for JKn, or NULL.
#' @param b The replicate's index.
#' @return TRUE or FALSE.
#' @noRd
.svy_rc_jkn_known <- function(x, rsc, b) {
  f <- x$fh
  !is.null(rsc) &&
    rsc[b] > 0 &&
    rsc[b] < 1 &&
    length(f) > 0L &&
    all(abs(f - 1) < 1e-8 | abs(f * rsc[b] - 1) < 1e-8)
}

#' How many replicates carry the factor `f`.
#' @param fac_of Each replicate's factor, NA when it has none.
#' @param f The factor.
#' @return A count.
#' @noRd
.svy_rc_fac_cnt <- function(fac_of, f) sum(!is.na(fac_of) & fac_of == f)

#' A genuine unadjusted jackknife set carries a factor k/(k - 1) on exactly k
#' replicates (those whose PSU lies in a subset have a row out, the others not),
#' so a no-row-out replicate whose factor is carried by more or fewer than k is
#' a stray: the full data plus w * 15/14 (16 of a factor whose k is 15) and w *
#' 1.005 beside 200 JKn replicates (1 of a factor whose k is 200) passed
#' silently (final audit of 1.0.0, #9).
#' @param x One replicate's summary; its fullfac is above 1 (only asked after
#'   .svy_rc_jk_scale()).
#' @param fac_of Each replicate's factor.
#' @return TRUE or FALSE.
#' @noRd
.svy_rc_stray <- function(x, fac_of) {
  f <- x$fullfac
  cnt <- .svy_rc_fac_cnt(fac_of, f)
  abs(f / (f - 1) - cnt) > 1e-6 * max(1, cnt)
}

#' The warning for a rescaled copy of the full-sample weight.
#' @param nm The replicate's name.
#' @param cnt How many replicates carry its factor.
#' @return The text.
#' @noRd
.svy_rc_stray_msg <- function(nm, cnt) {
  sprintf(
    paste(
      "replicate %s scales every row by one factor k/(k - 1) that %d",
      "replicates carry and leaves no row out: a rescaled",
      "copy of the",
      "full-sample weight, not a replicate of this set"
    ),
    nm,
    cnt
  )
}

#' The warning for a replicate that leaves no row out and is no rescaled weight.
#' @param nm The replicate's name.
#' @param type The replicate type.
#' @return The text.
#' @noRd
.svy_rc_no_row_out_msg <- function(nm, type) {
  sprintf(
    paste0(
      "replicate %s leaves no row out and is no rescaled weight, as ",
      "a %s replicate is"
    ),
    nm,
    toupper(type)
  )
}

#' The checks of one replicate.
#' @param b The replicate's index.
#' @param ctx What the checks share (built in .svy_replicate_check()).
#' @return A list: warn (texts) and equal (whether it is the full weight).
#' @noRd
.svy_rc_one <- function(b, ctx) {
  x <- ctx$summ[[b]]
  nm <- ctx$rnm[[b]] %||% as.character(b)
  if (x$same) {
    return(list(warn = .svy_rc_same(b, nm, ctx), equal = TRUE))
  }
  warn <- .svy_rc_shape(b, x, nm, ctx)
  # a replicate weight is the weight times a multiplier of a few at most on a
  # typical row (a bootstrap PSU drawn k times, 0 or n / (n - 1) for a
  # jackknife, 0 or 2 for BRR); a column ten times the weight there is on
  # another scale: api99 among the replicates raised the SE 21% silently
  # (statistics stress test of 5e1dce5). A genuine bootstrap reaches it only
  # if a PSU holding most rows is drawn ten times (about 1e-7 a replicate) A
  # tenth of the weight is another scale too: a normalised weight pw /
  # mean(pw) or one of survey's multiplier columns passed silently and
  # multiplied the SE of a total by 3.5 (CRAN stress test of b617a3f, #9).
  # Read on the first 4,096 rows the replicate keeps (BRR zeroes half of
  # them); Fay's 1 - rho can be small, so the lower bound is not applied there
  typical <- x$typical
  if (
    is.finite(typical) &&
      (typical > 10 || (typical < 0.1 && !identical(ctx$type, "fay")))
  ) {
    warn <- c(
      warn,
      sprintf(
        "replicate %s is %.3g times the full-sample weight on a typical row",
        nm,
        typical
      )
    )
  }
  if (x$isid) {
    .svy_rc_refuse(ctx$rnm, b, "the id")
  }
  if (x$isrow) {
    .svy_rc_refuse(ctx$rnm, b, "the row number")
  }
  if (ctx$named) {
    .svy_rc_data_cols(b, x, ctx)
  }
  list(warn = warn, equal = FALSE)
}

#' A replicate equal to the full-sample weight.
#'
#' A JKn replicate deletes a PSU of one stratum and leaves every other stratum's
#' rows at the weight: on a subset of other strata it is the weight,
#' legitimately (refused on 72% of JKn stratum subsets that survey estimates;
#' CRAN stress test of b617a3f, #7). A stratum has two PSUs at the least, so
#' those replicates come two or more at a time; one alone is a copy (below) a
#' Fay replicate too: post-stratified on a domain whose rows sit in one PSU per
#' stratum, every row of the domain keeps the weight (refused as a copy, 1 of
#' 2,576 designs; final audit of 1.0.0, #9): said, not refused
#' @param b,nm The replicate's index and name.
#' @param ctx What the checks share.
#' @return Warning texts.
#' @noRd
.svy_rc_same <- function(b, nm, ctx) {
  type <- ctx$type
  if (!ctx$adjusted && !type %in% c("bootstrap", "meanboot", "jkn", "fay")) {
    .svy_rc_refuse(ctx$rnm, b, "the full-sample weight")
  }
  if (!ctx$adjusted && identical(type, "fay")) {
    return(sprintf(
      paste(
        "replicate %s is the full-sample weight: genuine on a",
        "domain whose",
        "rows sit in one PSU per stratum, a copy otherwise"
      ),
      nm
    ))
  }
  character()
}

#' The shape checks of a replicate that differs from the full weight: a copy
#' within 1%, a BRR replicate that leaves no row out, a constant, a jackknife
#' replicate that leaves no row out.
#' @param b,x,nm The replicate's index, summary and name.
#' @param ctx What the checks share.
#' @return Warning texts.
#' @noRd
.svy_rc_shape <- function(b, x, nm, ctx) {
  type <- ctx$type
  adjusted <- ctx$adjusted
  # every row within 1% of the weight, not equal to it: a rounded, jittered or
  # single-precision copy. A jackknife or BRR replicate zeroes the PSUs it
  # leaves out, so there it cannot be one; under a bootstrap or Fay's method
  # it is said
  if (x$maxrel < 0.01) {
    return(.svy_rc_near_copy(b, x, nm, ctx))
  }
  if (!adjusted && identical(type, "brr") && !x$anyzero && x$nfac_all > 2L) {
    # a BRR replicate keeps one PSU of every stratum pair (the other's rows
    # are 0) and doubles it. A jackknife replicate on a subset may leave out a
    # PSU outside it, and post-stratified or calibrated it scales each row by
    # its own factor: no row out and many factors is genuine there, and was
    # said falsely (CRAN stress test of b617a3f, #8)
    return(.svy_rc_no_row_out_msg(nm, type))
  }
  if (x$const && ctx$wvaries) {
    # one value on every row while the weight varies: no multiplier of the
    # weight makes it
    return(sprintf(
      paste0(
        "replicate %s is one value on every row, which the ",
        "full-sample weight is not"
      ),
      nm
    ))
  }
  if (!adjusted && type %in% c("jk1", "jkn") && !x$anyzero) {
    # a jackknife replicate deletes a PSU: on rows that keep every PSU it is
    # one factor k / (k - 1) (and 1 on other strata under JKn), as documented,
    # and that is genuine only on a subset whose deleted PSU lies outside it
    # (the full data plus w * 15/14 passed silently; final audit of 1.0.0,
    # #9); anything else that leaves no row out is said (the warning the Rd
    # promises was not given; re-test of the b617a3f CRAN stress fixes)
    if (.svy_rc_jk_scale(x, ctx$B)) {
      if (.svy_rc_stray(x, ctx$fac_of)) {
        return(.svy_rc_stray_msg(
          nm,
          .svy_rc_fac_cnt(ctx$fac_of, ctx$fac_of[[b]])
        ))
      }
    } else if (!.svy_rc_jkn_known(x, ctx$rsc, b)) {
      # JKn's factor 1 / rscale on its stratum and 1 elsewhere is a rescaled
      # weight
      return(sprintf(
        paste0(
          "replicate %s leaves no row out and is no rescaled weight, ",
          "as a %s replicate is"
        ),
        nm,
        toupper(type)
      ))
    }
  }
  character()
}

#' A replicate within 1% of the full weight on every row.
#' @param b,x,nm The replicate's index, summary and name.
#' @param ctx What the checks share.
#' @return Warning texts.
#' @noRd
.svy_rc_near_copy <- function(b, x, nm, ctx) {
  type <- ctx$type
  adjusted <- ctx$adjusted
  jkn_known <- .svy_rc_jkn_known(x, ctx$rsc, b)
  if (
    adjusted ||
      (type %in% c("jk1", "jkn") && .svy_rc_jk_scale(x, ctx$B)) ||
      jkn_known
  ) {
    # genuine: see `adjusted` and .svy_rc_jk_scale(). One factor k / (k - 1)
    # on every row with no row left out is genuine only on a subset whose
    # deleted PSU lies outside it; carried by more or fewer replicates than
    # its k it is a rescaled copy (w * 1.005 under JKn and w * 15/14 under
    # JK1 passed silently; final audit of 1.0.0, #9): said
    if (
      !adjusted && !x$anyzero && !jkn_known && .svy_rc_stray(x, ctx$fac_of)
    ) {
      return(.svy_rc_stray_msg(
        nm,
        .svy_rc_fac_cnt(ctx$fac_of, ctx$fac_of[[b]])
      ))
    }
    return(character())
  }
  if (type %in% c("jk1", "jkn", "brr")) {
    .svy_rc_refuse(
      ctx$rnm,
      b,
      "a copy of the full-sample weight (within 1% on every row)"
    )
  }
  sprintf(
    "replicate %s is within 1%% of the full-sample weight on every row",
    nm
  )
}

#' The other replicates passed are not strays: two genuine replicates can be
#' identical (common in JK1 and BRR subsets and small bootstraps; 216 of 2,400
#' designs refused, CRAN stress test of b617a3f, #1) a column of `data` under
#' its own name was asked for (a genuine replicate kept in `data` is one;
#' reviews of 46de6a9, b617a3f #1, e57fed5 E9); the same values under another
#' name are a stray.
#' @param b,x The replicate's index and summary.
#' @param ctx What the checks share.
#' @noRd
.svy_rc_data_cols <- function(b, x, ctx) {
  for (cn in setdiff(names(ctx$numcols), ctx$rnm)) {
    if (
      identical(x$key, ctx$keys[[cn]]) &&
        identical(.svy_rc_col(ctx$reps, b), as.numeric(ctx$numcols[[cn]]))
    ) {
      .svy_rc_refuse(ctx$rnm, b, sprintf("column %s of `data`", cn))
    }
  }
  invisible(NULL)
}

#' Bootstrap replicates equal to the full weight: more than a bootstrap draws.
#'
#' A bootstrap draw of every PSU once is the full weight, legitimately: with m
#' PSUs in one stratum it happens with chance m!/m^m per replicate (22% at
#' three), and stratified with the product of each stratum's s!/s^s. The strata
#' are not given, but a PSU drawn k times sits in a stratum of at least k PSUs
#' (and two at the least), so each PSU's largest multiplier bounds its stratum's
#' size from below and the chance from above: (s!/s^s)^(1/s) a PSU (m!/m^m for
#' the whole design warned on 4 strata of 2 PSUs, 9 equal of 12.5 expected; CRAN
#' stress test of b617a3f, #8). More such replicates than that makes (a Poisson
#' tail under 1e-4) means the weight itself was passed beside them: said, not
#' refused (kept silently, SE 0.270 for 0.284; statistics stress test of
#' 5e1dce5). The PSUs are read from the replicates: the rows of one PSU share
#' their multiplier in every one
#' @param reps,w,B,rnm As in .svy_replicate_check().
#' @param equal The replicates equal to the full weight.
#' @return Warning texts.
#' @noRd
.svy_rc_boot_equal <- function(reps, w, B, rnm, equal) {
  n <- length(w)
  z <- cos(seq_len(B))
  sig <- numeric(n)
  top <- numeric(n)
  pos <- w > 0
  wpos <- pmax(w, .Machine$double.xmin)
  for (b in seq_len(B)) {
    r <- .svy_rc_col(reps, b)
    sig <- sig + z[[b]] * r / wpos
    top[pos] <- pmax(top[pos], r[pos] / w[pos])
  }
  key <- signif(sig, 10)
  m <- length(unique(key))
  size <- pmax(2, round(tapply(top, key, max)))
  expect <- B * exp(sum((lfactorial(size) - size * log(size)) / size))
  if (stats::ppois(length(equal) - 1L, expect, lower.tail = FALSE) >= 1e-4) {
    return(character())
  }
  sprintf(
    paste(
      "%d replicate(s) equal the full-sample weight (%s), more than a",
      "bootstrap of %d PSUs draws"
    ),
    length(equal),
    paste(utils::head(rnm[equal], 3L), collapse = ", "),
    m
  )
}

#' The warning for the replicates kept as given.
#'
#' The set as a whole: replicate weights total, on average, what the weight
#' totals (jackknife and bootstrap replicate totals average to the full total,
#' whatever one dominant PSU does to a single replicate). An average a tenth of
#' that or ten times it is survey's multipliers ($repweights) or another scale
#' passed in place of the weights (accepted silently: SE 20.16 for 28.28 on
#' apiclus2; statistics stress test of 5e1dce5)
#' @param warned The per-replicate texts.
#' @param ratio The replicates' mean total over the weight's total.
#' @noRd
.svy_rc_warn <- function(warned, ratio) {
  if (is.finite(ratio) && (ratio < 0.1 || ratio > 10)) {
    # first: it explains the per-replicate lines that follow, which the five
    # shown would cut off
    warned <- c(
      sprintf(
        paste(
          "the replicates total %.3g times the full-sample weight: multipliers",
          "(as survey's $repweights) rather than replicate weights?"
        ),
        ratio
      ),
      warned
    )
  }
  if (length(warned)) {
    warning(
      paste0(
        paste(utils::head(warned, 5L), collapse = "; "),
        if (length(warned) > 5L) {
          sprintf("; and %d more", length(warned) - 5L)
        } else {
          ""
        },
        ". Kept as given: give only the replicate weights if these are not"
      ),
      call. = FALSE
    )
  }
  invisible(NULL)
}

#' @export
print.rmbl_svy_design <- function(x, ...) {
  cat(sprintf(
    "Survey design: %s respondents, weights summing to %s\n",
    format(x$n, big.mark = ","),
    format(round(sum(x$weights)), big.mark = ",")
  ))
  if (identical(x$type, "linearization")) {
    cat(sprintf(
      "Variance: Taylor linearization, %d strata, %d PSUs%s\n",
      length(unique(x$strata)),
      length(unique(x$psu)),
      if (!is.null(x$fpc)) ", finite population correction" else ""
    ))
  } else {
    lab <- switch(
      x$type,
      bootstrap = "bootstrap",
      meanboot = sprintf("mean bootstrap (each the mean of %g)", x$mean_size),
      jk1 = "jackknife (JK1)",
      jkn = "stratified jackknife (JKn)",
      brr = "balanced repeated replication",
      fay = sprintf("Fay's BRR (rho = %g)", x$rho)
    )
    cat(sprintf(
      "Variance: %d replicate weights, %s; scale %.6g, %s\n",
      .svy_nrep(x),
      lab,
      x$scale,
      if (x$mse) {
        "centred on the full-sample estimate"
      } else {
        "centred on the replicate mean"
      }
    ))
  }
  invisible(x)
}

#' Computes the design-based estimates and their covariance matrix.
#'
#' The estimates and their covariance. Every estimate is a total A (stat
#' \code{"total"}) or a ratio A / D of weighted totals; `num` and `den` are n x
#' k matrices of the per-row values entering each, or `num` is the column spec
#' of .svy_columns(), whose k columns are read as the rows of their domain only:
#' n x k matrices for the numerators, the denominators and their products with
#' the weights were 1.9 GB of heap for a mean over 50 domains at a million rows
#' (final audit of 1.0.0).
#' @param des A design from `svydes()`.
#' @param num The n x k matrix of numerators, or a column spec from
#'   `.svy_columns()`.
#' @param den The n x k matrix of denominators, or NULL for totals.
#' @return A list with the estimates `est`, their covariance `V` and the
#'   weighted totals `A` and `D`.
#' @noRd
.svy_core <- function(des, num, den) {
  w <- des$weights
  n <- length(w)
  spec <- inherits(num, "rmbl_svy_colspec")
  k <- if (spec) num$k else ncol(num)
  has_den <- if (spec) num$stat != "total" else !is.null(den)
  # one column as the rows it has: the row indices, the numerator and the
  # denominator there
  column <- if (spec) {
    function(j) .svy_colpair(num, j)
  } else {
    function(j) {
      list(idx = seq_len(n), num = num[, j], den = if (has_den) den[, j])
    }
  }
  if (!is.null(des$reps)) {
    return(.svy_core_rep(des, column, k, has_den))
  }
  # Linearization. The PSU totals of the linearized values are n_psu x k; with
  # one row per PSU and fifty domains at a million rows that alone is 400 MB, so
  # the columns go in blocks: each block's linearized PSU totals are centred
  # within strata and scaled by the stratum's factor, and the covariance is the
  # cross-product of those blocks, two at a time.
  psu <- des$psu
  # the stratum of each PSU, in the order rowsum() returns them (sorted);
  # tapply() over a million one-row PSUs built a list of a million elements
  # (final audit of 1.0.0)
  upsu <- sort(unique(psu))
  ps <- as.integer(des$strata[match(upsu, psu)])
  npsu <- length(ps)
  A <- numeric(k)
  D <- if (has_den) numeric(k) else NULL
  for (j in seq_len(k)) {
    cj <- column(j)
    wj <- w[cj$idx]
    A[j] <- sum(wj * cj$num)
    if (has_den) D[j] <- sum(wj * cj$den)
  }
  est <- if (has_den) A / D else A
  st <- .svy_core_strata(des, ps, npsu)
  lin <- list(
    column = column,
    w = w,
    n = n,
    has_den = has_den,
    est = est,
    D = D,
    psu = psu,
    ps = ps,
    npsu = npsu,
    st = st,
    # each PSU one row (no PSU given): the PSU totals are the rows themselves,
    # and rowsum() over a million groups (a sort and a million row names a
    # call, 300 calls) is skipped
    one_row = npsu == n && identical(as.integer(psu), seq_len(n))
  )
  V <- matrix(0, k, k)
  bk <- max(1L, as.integer(floor(2^24 / max(n, 1L))))
  starts <- seq(1L, k, by = bk)
  for (a in starts) {
    ca <- a:min(k, a + bk - 1L)
    za <- .svy_core_block(ca, lin)
    V[ca, ca] <- crossprod(za)
    for (b in starts[starts > a]) {
      cb <- b:min(k, b + bk - 1L)
      zb <- .svy_core_block(cb, lin)
      V[ca, cb] <- crossprod(za, zb)
      V[cb, ca] <- t(V[ca, cb])
    }
  }
  # no stratum with two PSUs (one PSU in all, or every lonely PSU removed): a
  # standard error of zero would read as an exact estimate, so the variance is
  # not computable
  census <- !is.null(des$fpc) && all(des$fpc >= 1 - 1e-12)
  if (st$informative == 0L && !census) {
    V[] <- NA_real_
  }
  list(est = unname(est), V = unname(V), A = A, D = D)
}

#' The estimates and their covariance under a replicate design.
#' @param des The design.
#' @param column A function of a column index giving its rows (idx), numerator
#'   and denominator there.
#' @param k The number of columns.
#' @param has_den Whether the estimates are ratios.
#' @return A list: est, V, A and D.
#' @noRd
.svy_core_rep <- function(des, column, k, has_den) {
  w <- des$weights
  n <- length(w)
  A <- numeric(k)
  D <- if (has_den) numeric(k) else NULL
  B <- .svy_nrep(des)
  tn <- matrix(0, B, k)
  td <- if (has_den) matrix(0, B, k) else NULL
  for (j in seq_len(k)) {
    cj <- column(j)
    wj <- w[cj$idx]
    A[j] <- sum(wj * cj$num)
    if (has_den) {
      D[j] <- sum(wj * cj$den)
    }
    t <- .Call(
      C_rmbl_svy_reptotals,
      if (has_den) cbind(cj$num, cj$den) else cbind(cj$num),
      des$reps,
      if (length(cj$idx) == n) NULL else cj$idx
    )
    tn[, j] <- t[, 1L]
    if (has_den) td[, j] <- t[, 2L]
  }
  est <- if (has_den) A / D else A
  th <- if (has_den) tn / td else tn
  centre <- if (des$mse) est else colMeans(th)
  dev <- sweep(th, 2L, centre)
  dev[!is.finite(dev)] <- NA_real_
  dz <- ifelse(is.na(dev), 0, dev)
  if (!is.null(des$rscales)) {
    dz <- dz * sqrt(des$rscales)
  }
  V <- des$scale * crossprod(dz)
  # a replicate whose domain total was zero has no estimate: its variance is
  # not computable
  bad <- colSums(is.na(dev)) > 0
  if (any(bad)) {
    V[bad, ] <- NA_real_
    V[, bad] <- NA_real_
  }
  list(est = unname(est), V = unname(V), A = A, D = D)
}

#' The strata that carry variance information, and each one's centring and
#' factor, under linearization.
#' @param des The design.
#' @param ps The stratum of each PSU, PSUs sorted.
#' @param npsu The number of PSUs.
#' @return A list: use (PSUs that enter the cross-product), fac (sqrt of the
#'   stratum's factor, per PSU), grand (PSUs centred on the grand mean: a
#'   lonely PSU, adjusted) and informative (the number of strata that count).
#' @noRd
.svy_core_strata <- function(des, ps, npsu) {
  informative <- 0L
  use <- logical(npsu)
  fac <- numeric(npsu)
  grand <- logical(npsu)
  for (h in sort(unique(ps))) {
    rows <- which(ps == h)
    nh <- length(rows)
    fh <- if (is.null(des$fpc)) 0 else des$fpc[h]
    # a certainty stratum (every PSU sampled) adds no sampling variance, one PSU
    # or many
    if (fh >= 1 - 1e-12) {
      next
    }
    if (nh == 1L) {
      if (des$lonely == "fail") {
        stop(
          sprintf(
            paste0(
              "stratum %d has a single PSU: set lonely to \"remove\" or ",
              "\"adjust\""
            ),
            h
          ),
          call. = FALSE
        )
      }
      if (des$lonely == "remove" || npsu < 2L) {
        next
      }
      use[rows] <- TRUE
      grand[rows] <- TRUE
      fac[rows] <- sqrt(1 - fh)
      informative <- informative + 1L
      next
    }
    use[rows] <- TRUE
    fac[rows] <- sqrt((1 - fh) * nh / (nh - 1))
    informative <- informative + 1L
  }
  list(use = use, fac = fac, grand = grand, informative = informative)
}

#' One block of columns' linearized values per row, (y - theta x) / X, written
#' on the rows of each column's domain only, then summed by PSU, centred and
#' scaled.
#' @param cols The column indices.
#' @param lin What the blocks share (built in .svy_core()).
#' @return A PSUs x columns matrix.
#' @noRd
.svy_core_block <- function(cols, lin) {
  z <- matrix(0, lin$n, length(cols))
  for (i in seq_along(cols)) {
    cj <- lin$column(cols[[i]])
    wj <- lin$w[cj$idx]
    z[cj$idx, i] <- if (lin$has_den) {
      wj * (cj$num - lin$est[cols[[i]]] * cj$den) / lin$D[cols[[i]]]
    } else {
      wj * cj$num
    }
  }
  if (!lin$one_row) {
    z <- rowsum(z, lin$psu, reorder = TRUE)
    dimnames(z) <- NULL
  }
  # centred within the stratum (a lonely PSU kept: on the grand mean) and
  # scaled, one column at a time: sweep() over row subsets copied the whole
  # block four times (final audit of 1.0.0)
  # stratum means, strata sorted
  ps <- lin$ps
  st <- lin$st
  hm <- rowsum(z, ps, reorder = TRUE) / as.vector(table(ps))
  hi <- match(ps, sort(unique(ps)))
  gm <- colSums(z) / lin$npsu
  for (i in seq_len(ncol(z))) {
    ci <- hm[hi, i]
    if (any(st$grand)) {
      ci[st$grand] <- gm[i]
    }
    zi <- (z[, i] - ci) * st$fac
    zi[!st$use] <- 0
    z[, i] <- zi
  }
  z
}

#' One analysis column of a column spec, on the rows of its domain: the row
#' indices, the numerator and the denominator (NULL for a total)
#' @param s A column spec from `.svy_columns()`.
#' @param j The column's index.
#' @return A list with `idx`, `num` and `den`.
#' @noRd
.svy_colpair <- function(s, j) {
  idx <- s$rows[[s$di[j]]]
  if (s$stat == "proportion") {
    num <- as.numeric(s$vc[idx] == s$li[j])
    num[is.na(num)] <- 0
  } else {
    num <- s$vn[idx]
    num[is.na(num)] <- 0
  }
  den <- if (s$stat == "total") {
    NULL
  } else if (s$stat == "ratio") {
    s$xn[idx]
  } else {
    rep(1, length(idx))
  }
  list(idx = idx, num = num, den = den)
}

#' The analysis columns for one variable over the domains: numerators,
#' denominators and labels.
#' @param data The data frame.
#' @param des A design from `svydes()`.
#' @param y The analysis variable's column name.
#' @param by The domain columns, or NULL.
#' @param stat The statistic: \code{"mean"}, \code{"total"}, \code{"proportion"}
#' or \code{"ratio"}.
#' @param denominator The ratio's denominator column, or NULL.
#' @param levels The levels of a proportion to report, or NULL for all observed.
#' @return A list with the column spec `num`, `den` (NULL), the respondent
#'   counts `n` and the row `labels`.
#' @noRd
.svy_columns <- function(data, des, y, by, stat, denominator, levels) {
  n <- des$n
  if (!is.character(y) || length(y) != 1L || !y %in% names(data)) {
    stop("`y` must name a column of `data`", call. = FALSE)
  }
  v <- data[[y]]
  ok <- !is.na(v)
  if (!is.null(denominator)) {
    if (
      !is.character(denominator) ||
        length(denominator) != 1L ||
        !denominator %in% names(data)
    ) {
      stop("`denominator` must name a column of `data`", call. = FALSE)
    }
    x <- data[[denominator]]
    if (!is.numeric(x)) {
      stop("`denominator` must be numeric", call. = FALSE)
    }
    ok <- ok & !is.na(x)
  }
  if (is.null(by)) {
    dom <- factor(rep("all", n))
    dlab <- data.frame(row.names = 1L)
  } else {
    miss <- setdiff(by, names(data))
    if (length(miss)) {
      stop(
        sprintf(
          "`by` names columns `data` does not have: %s",
          paste(miss, collapse = ", ")
        ),
        call. = FALSE
      )
    }
    key <- interaction(data[by], drop = TRUE, sep = "\r", lex.order = TRUE)
    dom <- key
    parts <- do.call(rbind, strsplit(levels(key), "\r", fixed = TRUE))
    dlab <- as.data.frame(
      matrix(parts, ncol = length(by)),
      stringsAsFactors = FALSE
    )
    names(dlab) <- by
  }
  ok <- ok & !is.na(dom)
  if (stat == "proportion") {
    lv <- if (is.factor(v)) {
      levels(droplevels(v[ok]))
    } else {
      sort(unique(as.character(v[ok])))
    }
    if (!is.null(levels)) {
      bad <- setdiff(as.character(levels), lv)
      if (length(bad)) {
        stop(
          sprintf(
            "levels not observed in `%s`: %s",
            y,
            paste(bad, collapse = ", ")
          ),
          call. = FALSE
        )
      }
      lv <- as.character(levels)
    }
    if (!length(lv)) {
      stop(sprintf("`%s` has no non-missing values", y), call. = FALSE)
    }
  } else {
    if (!is.numeric(v) && !is.logical(v)) {
      stop(sprintf("`%s` must be numeric for a %s", y, stat), call. = FALSE)
    }
    if (any(!is.finite(v[ok]))) {
      stop(sprintf("`%s` has infinite values", y), call. = FALSE)
    }
    lv <- NA_character_
  }
  nd <- nlevels(dom)
  k <- nd * length(lv)
  domi <- as.integer(dom)
  di <- rep(seq_len(nd), each = length(lv))
  li <- rep(lv, times = nd)
  okd <- ok & !is.na(domi)
  # the rows of each domain, once (a which() over every row per column was a
  # copy per column)
  rows <- split(which(okd), factor(domi[okd], levels = seq_len(nd)))
  cnt <- lengths(rows)[di]
  lab <- if (ncol(dlab)) {
    dlab[di, , drop = FALSE]
  } else {
    data.frame(row.names = seq_len(k))
  }
  if (stat == "proportion") {
    lab$level <- li
  }
  rownames(lab) <- NULL
  # the columns are made one at a time by .svy_colpair(): see .svy_core()
  spec <- structure(
    list(
      k = k,
      stat = stat,
      rows = rows,
      di = di,
      li = li,
      vn = if (stat != "proportion") as.numeric(v),
      vc = if (stat == "proportion") as.character(v),
      xn = if (stat == "ratio") as.numeric(x)
    ),
    class = "rmbl_svy_colspec"
  )
  list(num = spec, den = NULL, n = cnt, labels = lab)
}

#' Computes confidence limits for survey estimates.
#' @param est The estimates.
#' @param se Their standard errors.
#' @param n_used The number of respondents behind each estimate.
#' @param stat The statistic; proportions get bounded intervals.
#' @param ci The interval for proportions: \code{"wald"}, \code{"wilson"} or
#'   \code{"logit"}.
#' @param conf_level The confidence level.
#' @param df The degrees of freedom for the quantile; Inf uses the normal.
#' @param design_df The design's degrees of freedom, for the effective sample
#'   size of the Wilson interval.
#' @return A list with `lower` and `upper`.
#' @noRd
.svy_ci <- function(
  est,
  se,
  n_used,
  stat,
  ci,
  conf_level,
  df = Inf,
  design_df = Inf
) {
  conf_level <- .rmbl_conf_level(conf_level)
  z <- if (is.finite(df)) {
    stats::qt(1 - (1 - conf_level) / 2, df)
  } else {
    stats::qnorm(1 - (1 - conf_level) / 2)
  }
  lower <- est - z * se
  upper <- est + z * se
  if (stat == "proportion" && ci != "wald") {
    inside <- is.finite(se) & est > 0 & est < 1
    # at 0 or 1 the design effect is 0/0: Wilson at the plain n (the logit
    # interval does not exist there either, and takes the same). Wald with se =
    # 0 had collapsed to [1, 1] for 40 of 40.
    edge <- !is.na(est) & (est <= 0 | est >= 1) & n_used > 0
    if (any(edge)) {
      zz <- stats::qnorm(1 - (1 - conf_level) / 2)
      tt <- if (is.finite(design_df)) {
        stats::qt(1 - (1 - conf_level) / 2, design_df)
      } else {
        zz
      }
      tn <- stats::qt(1 - (1 - conf_level) / 2, pmax(n_used[edge] - 1, 1))
      ne <- pmin(n_used[edge] * (tn / tt)^2, n_used[edge])
      p <- pmin(pmax(est[edge], 0), 1)
      mid <- (p + zz^2 / (2 * ne)) / (1 + zz^2 / ne)
      half <- zz / (1 + zz^2 / ne) * sqrt(p * (1 - p) / ne + zz^2 / (4 * ne^2))
      # the bound at the observed end is that end, exactly
      lower[edge] <- ifelse(p <= 0, 0, mid - half)
      upper[edge] <- ifelse(p >= 1, 1, mid + half)
    }
    if (ci == "logit") {
      l <- stats::qlogis(est[inside]) -
        z * se[inside] / (est[inside] * (1 - est[inside]))
      u <- stats::qlogis(est[inside]) +
        z * se[inside] / (est[inside] * (1 - est[inside]))
      lower[inside] <- stats::plogis(l)
      upper[inside] <- stats::plogis(u)
    } else {
      # Wilson's score interval at the modified effective sample size of SAS
      # PROC SURVEYFREQ (CL(TYPE = WILSON)), which produced Health Canada's CSUS
      # intervals: n / Deff with the SRS variance on n - 1, times (t_{n-1} /
      # t_df)^2 for the design's degrees of freedom (Korn and Graubard 1998; SAS
      # documents the n - 1 quantile, where z stood before 0.5.12), and never
      # more than the n respondents behind the estimate
      p <- est[inside]
      n <- n_used[inside]
      zz <- stats::qnorm(1 - (1 - conf_level) / 2)
      tt <- if (is.finite(design_df)) {
        stats::qt(1 - (1 - conf_level) / 2, design_df)
      } else {
        zz
      }
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
#' estimate reflects the whole sample design. Use it for the figures a
#' survey report publishes (the prevalence of a behaviour by region, the mean
#' number of drinks, a population total) with the standard errors the survey's
#' design implies rather than those of a simple random sample.
#'
#' @details
#' The estimates are ratios of weighted totals: a mean is
#' \eqn{\sum w_i y_i / \sum w_i} over the domain, a total
#' \eqn{\sum w_i y_i}, a proportion the mean of the 0/1 indicator of each
#' category, and a ratio \eqn{\sum w_i y_i / \sum w_i x_i} with \eqn{x} the
#' \code{den}. Their variances come from the design: the replicate
#' formula, or Taylor linearization of the ratio (see
#' [svydes()]).
#'
#' Proportions are reported for every category of `y` (or those
#' in `lvls`), each with its own interval. The default
#' interval for a proportion is Wilson's score interval at the
#' modified effective sample size of SAS PROC SURVEYFREQ, the
#' software behind Health Canada's published Canadian Substance
#' Use Survey intervals: \eqn{n / \mathrm{Deff}}, with the
#' design effect taken against the simple-random-sampling
#' variance \eqn{p(1 - p)/(n - 1)}, scaled by \eqn{(t_{n-1} /
#' t_{df})^2} for the design's degrees of freedom (Korn and
#' Graubard 1998; \eqn{t_{df}} is the normal quantile when the design's
#' degrees of freedom are infinite) and capped at the \eqn{n} respondents
#' behind the estimate. `ci = "logit"` builds the interval on the logit
#' scale and `"wald"` symmetrically. Means, totals and ratios
#' get the symmetric normal interval.
#'
#' A domain with fewer than `minn` respondents is flagged, not
#' withheld: Health Canada suppresses such CSUS estimates in its
#' data tool (denominator under 30), and the flag lets the
#' reader do the same. Other flags say why a standard error is missing (no
#' stratum with two PSUs, a replicate that left the domain empty, weights all
#' zero) or that a domain has no respondents.
#'
#' Errors: \code{des} not from [svydes()];
#' \code{data} not the rows
#' the design was built on, in the same order; \code{y}, \code{by} or
#' \code{den} naming a column \code{data} does not have; a ratio
#' without \code{den}; \code{conflvl} outside (0, 1); \code{df}
#' not positive, \code{Inf} or \code{"design"}, or a design with no degrees
#' of freedom under \code{df = "design"}; a single-PSU stratum under
#' \code{lonely = "fail"}.
#'
#' @param des A [svydes()] built on `data`.
#' @param data The data frame the design was built on.
#' @param y Character scalar, the analysis column: numeric for a mean, total
#'   or ratio; any type for a proportion (each distinct value is a category).
#' @param by Optional character vector of domain columns; \code{NULL} (the
#'   default) estimates for the whole population.
#' @param stat `"mean"`, `"total"`, `"proportion"` or `"ratio"`
#'   (of `y` to `den`).
#' @param den For a ratio, the denominator column.
#' @param lvls For a proportion, the categories to report
#'   (default all observed).
#' @param conflvl Numeric scalar in (0, 1), the confidence level; default
#'   \code{0.95}.
#' @param ci Interval method: \code{"auto"} (the default; Wilson for
#'   proportions, Wald otherwise), \code{"wilson"}, \code{"logit"} or
#'   \code{"wald"}. Wilson and logit apply to proportions only.
#' @param minn Numeric scalar, default \code{30}: domains with fewer
#'   respondents are flagged.
#' @param df Degrees of freedom for the interval: `Inf` (the
#'   default) for the normal quantile, a number for Student's t,
#'   or `"design"` for the design's own (PSUs less strata under
#'   linearization, replicates less one otherwise).
#' @return A data frame of class \code{c("rmbl_svy_estimate", "data.frame")},
#'   one row per domain (and category, for a proportion): the domain columns
#'   (and \code{level}), then numeric \code{estimate}, \code{se},
#'   \code{lower}, \code{upper}, \code{cv} (coefficient of variation,
#'   percent), integer \code{n} (respondents counted) and character
#'   \code{flag} (\code{NA} when there is nothing to say). Attributes:
#'   \code{vcov} (the covariance matrix of the estimates, used by
#'   [svycmp()]), \code{stat}, \code{y}, \code{by},
#'   \code{ci},
#'   \code{conflvl}, \code{df}, \code{method} (the variance method) and
#'   \code{denominator}.
#' @seealso [svydes()],
#'   [svycmp()]
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' set.seed(1)
#' d <- data.frame(region = rep(c("north", "south"), each = 50),
#'                 smoker = rbinom(100, 1, rep(c(0.2, 0.35), each = 50)),
#'                 drinks = rpois(100, 3), w = runif(100, 50, 150))
#' des <- svydes(d, w = "w", strata = "region")
#' svyest(des, d, "smoker", by = "region", stat = "proportion", lvls = "1")
#' svyest(des, d, "drinks", stat = "mean")
#' svyest(des, d, "drinks", by = "region", stat = "total")
#'
#' # a ratio of two totals, with Student's t on the design's degrees of freedom
#' d$visits <- rpois(100, 6)
#' svyest(des, d, "drinks", stat = "ratio", den = "visits", df = "design")
#'
#' # a logit interval at 90 percent
#' svyest(des, d, "smoker", stat = "proportion", lvls = "1", ci = "logit",
#'                 conflvl = 0.90)
#'
#' # the design remembers its rows: a subset is refused
#' try(svyest(des, d[-1, ], "drinks"))
#' @export
#' @srrstats {G2.0a} @param docs state lengths explicitly ("y Character scalar",
#'   "conflvl Numeric scalar in (0, 1)", "by Optional character vector").
#' @srrstats {G2.3} Univariate character options are handled by .rmbl_arg
#'   (G2.3a); case handling is covered under G2.3b.
#' @srrstats {G2.3a} stat and ci are checked by .rmbl_arg() (match.arg
#'   equivalent, pmatch, names the value given); there are 106 .rmbl_arg calls
#'   package-wide.
#' @srrstats {G2.13} A missing y counts zero in its domain but stays in the
#'   design; test-survey.R checks estimate and n = 11 with `y[1] = NA`.
#' @srrstats {G5.0} Tested on the survey package's standard api datasets
#'   (apistrat, apiclus1) in test-survey.R.
#' @srrstats {G5.4b} test-survey.R matches
#'   survey::svymean/svytotal/svyratio/svyby/svyciprop and JK1 replicates to the
#'   estimate and SE.
svyest <- function(
  des,
  data,
  y,
  by = NULL,
  stat = c("mean", "total", "proportion", "ratio"),
  den = NULL,
  lvls = NULL,
  conflvl = 0.95,
  ci = c("auto", "wilson", "logit", "wald"),
  minn = 30,
  df = Inf
) {
  .rmbl_no_fn(levels = lvls)
  stat <- .rmbl_arg(stat)
  ci <- .rmbl_arg(ci)
  if (!inherits(des, "rmbl_svy_design")) {
    stop("svyest: `des` must come from svydes()", call. = FALSE)
  }
  .svy_check_data(des, data)
  if (!length(by)) {
    by <- NULL
  }
  if (!is.character(by) && !is.null(by)) {
    stop("`by` must name columns of `data`", call. = FALSE)
  }
  conflvl <- .rmbl_conf_level(conflvl)
  minn <- .rmbl_scalar(minn, "minn", 0)
  if (stat == "ratio" && is.null(den)) {
    stop("a ratio needs a `den` column", call. = FALSE)
  }
  if (ci == "auto") {
    ci <- if (stat == "proportion") "wilson" else "wald"
  }
  if (identical(df, "design")) {
    df <- .svy_df(des)
    # replicates that are all multiples of one weight vector have rank 1: no
    # degrees of freedom
    if (df < 1) {
      stop(
        sprintf(
          paste0(
            "the design has %g degrees of freedom (its replicate weights ",
            "do not vary independently)"
          ),
          df
        ),
        call. = FALSE
      )
    }
  }
  if (!is.numeric(df) || length(df) != 1L || is.na(df) || df <= 0) {
    stop("`df` must be a positive number, Inf or \"design\"", call. = FALSE)
  }
  cols <- .svy_columns(data, des, y, by, stat, if (stat == "ratio") den, lvls)
  core <- .svy_core(des, cols$num, cols$den)
  se <- sqrt(pmax(diag(core$V), 0))
  int <- .svy_ci(core$est, se, cols$n, stat, ci, conflvl, df, .svy_df(des))
  flag <- rep(NA_character_, length(se))
  flag[cols$n < minn] <- sprintf("fewer than %g respondents", minn)
  # the reason a variance is missing, said as it is
  flag[is.na(se)] <- if (is.null(des$reps)) {
    "variance not computable (no stratum has two PSUs)"
  } else {
    "variance not computable (a replicate left the domain empty)"
  }
  flag[
    is.na(se) & !is.null(core$D) & is.finite(core$D) & core$D == 0
  ] <- "the domain's weights are all zero"
  flag[cols$n == 0L] <- "no respondents"
  out <- cbind(
    cols$labels,
    data.frame(
      estimate = core$est,
      se = se,
      lower = int$lower,
      upper = int$upper,
      cv = 100 * se / abs(core$est),
      n = cols$n,
      flag = flag,
      stringsAsFactors = FALSE
    )
  )
  rownames(out) <- NULL
  structure(
    out,
    class = c("rmbl_svy_estimate", "data.frame"),
    vcov = core$V,
    stat = stat,
    y = y,
    by = by,
    ci = ci,
    conflvl = conflvl,
    df = df,
    method = des$type,
    denominator = den
  )
}

#' Compare survey estimates between domains
#'
#' Each domain's estimate against a reference domain: the
#' difference, its standard error from the design (the
#' covariance between the two estimates included, which is what
#' a pair of separate intervals leaves out), a confidence
#' interval and a two-sided p-value from the normal
#' approximation. Use it to test whether two regions or groups differ, rather
#' than checking whether their separate intervals overlap: overlapping
#' intervals do not mean no difference, and domains of one survey are not
#' independent.
#'
#' @details
#' The estimates come from [svyest()] with Wald
#' intervals. For domain
#' \eqn{i} and reference \eqn{0} the difference is \eqn{d = \hat\theta_i -
#' \hat\theta_0} with \eqn{SE(d) = \sqrt{V_{ii} + V_{00} - 2V_{i0}}} from the
#' design covariance; the interval is \eqn{d \pm z\,SE(d)} and the p-value
#' \eqn{2\Phi(-|d|/SE(d))}, both on the normal distribution (there is no
#' \code{df} argument). For a proportion every category is compared
#' separately. No adjustment for multiple comparisons is made.
#'
#' Errors: \code{by} missing or empty; fewer than two domains; a \code{ref}
#' that is not a single domain label present in the data; and every error of
#' [svyest()].
#'
#' @inheritParams svyest
#' @param by The domain columns to compare across.
#' @param ref The reference domain, as its label (for several
#'   \code{by} columns, the labels joined with \code{" / "}); a number is
#'   matched as the label it prints as. Default \code{NULL}: the first domain.
#' @return A data frame of class \code{c("rmbl_svy_compare", "data.frame")},
#'   one row per non-reference domain (and category): \code{domain},
#'   \code{level} (for a proportion only), numeric \code{estimate} (the
#'   domain's), \code{reference} (the reference domain's), \code{difference},
#'   \code{se}, \code{lower}, \code{upper} and \code{p_value}. Attributes
#'   \code{ref}, \code{stat}, \code{y} and \code{conflvl}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' set.seed(1)
#' d <- data.frame(region = rep(c("north", "south", "east"), length.out = 150),
#'                 smoker = rbinom(150, 1, 0.3), w = runif(150, 50, 150))
#' des <- svydes(d, w = "w")
#' svycmp(des, d, "smoker", by = "region", stat = "proportion",
#'                lvls = "1", ref = "north")
#'
#' # means, against the default (first) domain, at 90 percent
#' d$drinks <- rpois(150, 3)
#' svycmp(des, d, "drinks", by = "region", conflvl = 0.90)
#'
#' # the reference must be one of the domains
#' try(svycmp(des, d, "drinks", by = "region", ref = "west"))
#' @export
svycmp <- function(
  des,
  data,
  y,
  by,
  stat = c("mean", "total", "proportion", "ratio"),
  den = NULL,
  lvls = NULL,
  ref = NULL,
  conflvl = 0.95
) {
  .rmbl_no_fn(levels = lvls)
  stat <- .rmbl_arg(stat)
  conflvl <- .rmbl_conf_level(conflvl)
  if (missing(by) || !length(by)) {
    stop("`by` must name the domains to compare", call. = FALSE)
  }
  e <- svyest(
    des,
    data,
    y,
    by = by,
    stat = stat,
    den = den,
    lvls = lvls,
    conflvl = conflvl,
    ci = "wald"
  )
  V <- attr(e, "vcov")
  dom <- do.call(paste, c(as.list(as.data.frame(e)[by]), sep = " / "))
  lev <- if (stat == "proportion") e$level else rep(NA_character_, nrow(e))
  doms <- unique(dom)
  if (length(doms) < 2L) {
    stop("comparisons need at least two domains", call. = FALSE)
  }
  if (is.null(ref)) {
    ref <- doms[1L]
  }
  # a domain label may be a number (ref = 2023 for a year): matched as the label
  # it prints as
  if (is.numeric(ref) && length(ref) == 1L && !is.na(ref)) {
    ref <- as.character(ref)
  }
  if (!is.character(ref) || length(ref) != 1L || is.na(ref)) {
    stop("`ref` must be one domain label", call. = FALSE)
  }
  if (!ref %in% doms) {
    stop(
      sprintf(
        "`ref` is not one of the domains: %s",
        paste(doms, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  z <- stats::qnorm(1 - (1 - conflvl) / 2)
  rows <- list()
  for (l in unique(lev)) {
    i0 <- which(dom == ref & (lev %in% l))
    for (i in which(dom != ref & (lev %in% l))) {
      d <- e$estimate[i] - e$estimate[i0]
      s <- sqrt(max(V[i, i] + V[i0, i0] - 2 * V[i, i0], 0))
      rows[[length(rows) + 1L]] <- data.frame(
        domain = dom[i],
        level = l,
        estimate = e$estimate[i],
        reference = e$estimate[i0],
        difference = d,
        se = s,
        lower = d - z * s,
        upper = d + z * s,
        p_value = 2 * stats::pnorm(-abs(d / s)),
        stringsAsFactors = FALSE
      )
    }
  }
  out <- do.call(rbind, rows)
  if (stat != "proportion") {
    out$level <- NULL
  }
  rownames(out) <- NULL
  structure(
    out,
    class = c("rmbl_svy_compare", "data.frame"),
    ref = ref,
    stat = stat,
    y = y,
    conflvl = conflvl
  )
}

#' @export
print.rmbl_svy_estimate <- function(x, digits = 4, ...) {
  m <- attributes(x)
  cat(sprintf(
    "Survey %s of %s%s (%s variance, %g%% %s interval)\n",
    m$stat,
    m$y,
    if (length(m$by)) paste(" by", paste(m$by, collapse = ", ")) else "",
    m$method,
    100 * m$conflvl,
    m$ci
  ))
  d <- as.data.frame(unclass(x), stringsAsFactors = FALSE)
  attr(d, "vcov") <- NULL
  print(format(d, digits = digits), row.names = FALSE)
  invisible(x)
}

#' @export
print.rmbl_svy_compare <- function(x, digits = 4, ...) {
  cat(sprintf(
    "Survey %s of %s against %s (%g%% interval)\n",
    attr(x, "stat"),
    attr(x, "y"),
    attr(x, "ref"),
    100 * attr(x, "conflvl")
  ))
  print(
    format(
      as.data.frame(unclass(x), stringsAsFactors = FALSE),
      digits = digits
    ),
    row.names = FALSE
  )
  invisible(x)
}

#' @rdname plot-methods
#' @export
plot.rmbl_svy_estimate <- function(
  x,
  ...,
  main = NULL,
  col = NULL,
  palette = NULL
) {
  .rmbl_plot_check(x, "rmbl_svy_estimate")
  m <- attributes(x)
  d <- as.data.frame(unclass(x), stringsAsFactors = FALSE)
  pct <- identical(m$stat, "proportion")
  k <- if (pct) 100 else 1
  lab <- if (length(m$by)) {
    do.call(paste, c(d[m$by], sep = " / "))
  } else {
    rep("all", nrow(d))
  }
  if (pct && length(unique(d$level)) > 1L) {
    lab <- paste(lab, d$level, sep = ": ")
  }
  if (all(lab == "all")) {
    lab <- if (pct) d$level else m$y
  }
  pal <- .bl_cols(3, col, palette)
  cols <- if (!is.null(col)) {
    rep_len(col, nrow(d))
  } else {
    ifelse(is.na(d$flag), pal[1L], pal[2L])
  }
  note <- ifelse(is.na(d$flag), NA_character_, d$flag)
  .bl_dot_interval(
    lab,
    k * d$estimate,
    k * d$lower,
    k * d$upper,
    .bl_main(main, sprintf("%s of %s", tools::toTitleCase(m$stat), m$y)),
    sprintf(
      "%s%s, with %g%% interval (orange: flagged)",
      if (pct) {
        "Percent"
      } else {
        tools::toTitleCase(m$stat)
      },
      if (pct) "" else "",
      100 * m$conflvl
    ),
    cols,
    note = note,
    ...
  )
  invisible(data.frame(
    label = lab,
    estimate = k * d$estimate,
    lower = k * d$lower,
    upper = k * d$upper,
    stringsAsFactors = FALSE
  ))
}

#' @rdname plot-methods
#' @export
plot.rmbl_svy_compare <- function(
  x,
  ...,
  main = NULL,
  col = NULL,
  palette = NULL
) {
  .rmbl_plot_check(x, "rmbl_svy_compare")
  d <- as.data.frame(unclass(x), stringsAsFactors = FALSE)
  pct <- identical(attr(x, "stat"), "proportion")
  k <- if (pct) 100 else 1
  lab <- if (!is.null(d$level) && length(unique(d$level)) > 1L) {
    paste(d$domain, d$level, sep = ": ")
  } else {
    d$domain
  }
  pal <- .bl_cols(
    3,
    col,
    if (is.null(palette) && is.null(col)) "diverging" else palette
  )
  sig <- d$p_value < 1 - attr(x, "conflvl")
  cols <- if (!is.null(col)) {
    rep_len(col, nrow(d))
  } else {
    ifelse(!sig, pal[2L], ifelse(d$difference > 0, pal[3L], pal[1L]))
  }
  .bl_dot_interval(
    lab,
    k * d$difference,
    k * d$lower,
    k * d$upper,
    .bl_main(main, sprintf("Difference from %s", attr(x, "ref"))),
    sprintf(
      "Difference%s, with interval (grey: not significant)",
      if (pct) " in percentage points" else ""
    ),
    cols,
    ref = 0,
    ...
  )
  invisible(data.frame(
    label = lab,
    difference = k * d$difference,
    lower = k * d$lower,
    upper = k * d$upper,
    stringsAsFactors = FALSE
  ))
}
