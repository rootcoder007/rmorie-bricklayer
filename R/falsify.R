# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Falsification: the negative controls that tell you whether a finding
# is a finding.
#
# A capsule can be signed, hashed, chained and reproduced exactly and
# still report a number that means nothing -- reproducibility is a
# property of the pipeline, not of the claim. The controls here are the
# ones that can actually fail: break the association on purpose and the
# statistic should collapse; add a variable that cannot matter and it
# should not move; drop a fifth of the rows and it should stay put.

#' Run falsification controls against a statistic
#'
#' Recomputes `stat` under conditions in which its value is known
#' in advance, and reports whether it behaved. Four controls, each
#' answering a different way of being wrong:
#'
#' * **permutation** -- shuffle `trt` and the association it
#' carries is destroyed, so the statistic should fall to its null
#' distribution. Reports where the observed value sits in that
#' distribution, and the smallest p-value the number of permutations could
#' have produced.
#' * **random common cause** -- add a column of noise. It cannot
#' possibly matter, so a statistic that moves is reading something other
#' than the data.
#' * **placebo treatment** -- replace `trt` with a random draw of
#' the same shape. The effect should vanish; if it does not, the statistic
#' is picking up structure that has nothing to do with the exposure.
#' * **subset stability** -- recompute on random subsets. Wide spread
#' means the finding rests on particular rows, which is worth knowing
#' before it rests on a conclusion.
#'
#' What a pass means. Only that these controls did not catch anything. They
#' are falsification tests, so they can refute and cannot confirm: passing
#' all four is consistent with a statistic that is wrong for a reason none
#' of them probes.
#'
#' When each control passes:
#' * permutation -- the two-sided permutation p-value
#' \eqn{(1 + \#\{|s_b| \ge |s_{obs}|\}) / (1 + B)} over the \eqn{B} usable
#' permutations is below 0.05 (the observed statistic is unlike its null);
#' * placebo -- the statistic under one more permuted treatment lies within the
#' 95th percentile of the absolute permutation values;
#' * random common cause -- adding a column `.rmbl_random_common_cause` of
#' standard normal noise changes the statistic by at most
#' \eqn{10^{-8} \max(1, |s_{obs}|)};
#' * subset stability -- the observed value lies inside the middle 95% of the
#' statistic over `n` random subsets of `round(subfrac * nrow(data))`
#' rows (at least two).
#'
#' A permutation or subset on which the statistic errors or is not finite is
#' dropped from that control. The statistic is evaluated `2 n + 3` times, so
#' its cost sets the run time; a progress bar is shown when
#' `options(morie.progress)` allows it. With `seed` the random number stream
#' is set for the call and the caller's stream restored afterwards.
#'
#' Errors: `data` not a data frame or with fewer than 4 rows; `stat` not a
#' function, or failing or not returning one finite number on the data as
#' given, the placebo data or the noise-augmented data; `n` below 9;
#' `subfrac` not strictly between 0 and 1; `trt` not a column of
#' `data`.
#'
#' @param data A data frame that the statistic `stat` is computed on.
#' @param stat A function of one data frame returning
#' a single finite number.
#' @param trt Name of the column the finding is
#' about, permuted for the permutation and placebo controls. Optional:
#' without it those two controls are skipped and reported as such rather
#' than silently omitted.
#' @param n Integer scalar, the number of permutations and of subsets, at
#' least 9; default 199. The permutation p-value cannot be smaller than
#' `1 / (n + 1)`, which is reported.
#' @param subfrac Numeric scalar strictly between 0 and 1, the fraction of
#' rows kept by the subset control; default 0.8.
#' @param seed Optional integer seed. Supplied, the result is
#' reproducible; omitted (`NULL`, the default), the current random number
#' stream is used and only the generator kind is recorded.
#' @return A list of class `bricklayer_falsification`: `observed` (the
#' statistic on the data as given), `controls` (a data frame with one row per
#' control: `control`, logical `passed` (`NA` when skipped), numeric
#' `value`
#' (the p-value, the placebo or noise statistic, or the subset spread) and
#' `detail`), `permutation` (the vector of permuted statistics, `NULL`
#' without
#' `treatment`), `n`, `treatment`, `rng_kind` and `seed`
#' (`NA` when none was
#' given). `print()` shows one line per control; `plot()` draws the
#' permutation distribution.
#' @seealso
#' [cpspwr()] for the positive control
#' -- whether a real effect would have been seen at all;
#' [cpsatst()] for the different
#' question of whether the record is intact rather than whether the finding
#' survives.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' set.seed(1)
#' d <- data.frame(x = rnorm(200))
#' d$y <- 0.8 * d$x + rnorm(200)
#' # a real association survives its controls
#' real <- cpsfals(d, function(z) cor(z$x, z$y),
#'                         trt = "x", n = 199, seed = 42)
#' real$controls[, c("control", "passed")]
#'
#' # and a statistic that ignores the data fails the ones that can see it
#' fake <- cpsfals(d, function(z) 0.5, trt = "x",
#'                         n = 199, seed = 42)
#' fake$controls[fake$controls$control == "permutation", "passed"]
#'
#' # without a treatment column two controls are skipped, and say so
#' fit <- cpsfals(d, function(z) mean(z$y), n = 49, seed = 1)
#' fit$controls[, c("control", "passed")]
#'
#' # the statistic must return one finite number
#' try(cpsfals(d, function(z) c(1, 2), n = 49))
#' @export
cpsfals <- function(
  data,
  stat,
  trt = NULL,
  n = 199L,
  subfrac = 0.8,
  seed = NULL
) {
  .rmbl_no_fn(trt = trt)
  a <- .rmbl_fals_args(data, stat, n, subfrac, trt)
  n <- a$n
  subfrac <- a$subfrac
  trt <- a$trt
  if (!is.null(seed)) {
    seed <- .rmbl_r_seed(seed)
  }
  if (!is.null(seed)) {
    .rmbl_local_seed(seed)
  }

  pg <- blprog("falsification", 2 * n + 1L)
  on.exit(pg$done(), add = TRUE)
  pg$update(0, "the data as given")
  observed <- .rmbl_falsify_eval(stat, data, "the data as given")
  pm <- .rmbl_fals_perm(data, stat, trt, n, observed, pg)
  perm <- pm$perm
  rcc <- .rmbl_fals_rcc(data, stat, observed)
  subs <- .rmbl_fals_subsets(data, stat, n, subfrac, observed, pg)
  rows <- c(pm$rows, list(rcc, subs))

  df <- do.call(rbind, rows)
  rownames(df) <- NULL
  out <- list(
    observed = observed,
    controls = df,
    permutation = perm,
    n = n,
    treatment = trt,
    rng_kind = paste(RNGkind(), collapse = ","),
    # as given: as.integer() made a seed past 2^31 - 1 NA
    seed = if (is.null(seed)) NA_integer_ else seed
  )
  class(out) <- c("bricklayer_falsification", "list")
  out
}

#' @export
format.bricklayer_falsification <- function(x, ...) {
  ct <- x$controls
  mark <- c("FAIL", "ok  ")[ct$passed + 1L]
  mark[is.na(ct$passed)] <- "--  "
  nm <- formatC(ct$control, width = max(nchar(ct$control)), flag = "-")
  .rmbl_stat_block(
    "Falsification controls",
    facts = list(
      `Observed statistic` = sprintf("%.8g", x$observed),
      Permutations = x$n,
      Treatment = x$treatment,
      Seed = if (!is.na(x$seed)) format(x$seed, scientific = FALSE),
      Generator = x$rng_kind
    ),
    reading = if (any(!is.na(ct$passed) & !ct$passed)) {
      paste(
        "At least one control failed: the result may come from the design",
        "or from chance rather than from the data."
      )
    } else {
      paste(
        "The controls that ran passed: a shuffled treatment, a placebo, an",
        "added random cause and subsets of the data did not explain it away."
      )
    },
    notes = sub(" +$", "", paste(mark, nm, substring(ct$detail, 1L, 60L)))
  )
}

#' Calls the user statistic on one data set and checks it returns one finite
#' number.
#'
#' A statistic has to return one finite number. Anything else is an error
#' here rather than an NA that quietly passes every control below.
#' @param statistic The user function.
#' @param data The data set it is called on.
#' @param what Which data set this is, used in the error message.
#' @return The statistic as one double.
#' @noRd
.rmbl_falsify_eval <- function(statistic, data, what) {
  v <- tryCatch(statistic(data), error = function(e) {
    stop(
      sprintf("the statistic failed on %s: %s", what, conditionMessage(e)),
      call. = FALSE
    )
  })
  # a data frame or a list returned by the statistic failed in R's words in
  # as.numeric() (final audit of 1.0.0): refused here, as any other non-number
  # is
  if (!is.atomic(v)) {
    stop(
      .rmbl_fn(),
      sprintf("the statistic must return one finite number; on %s it ", what),
      "returned something else",
      call. = FALSE
    )
  }
  v <- suppressWarnings(as.numeric(v))
  if (length(v) != 1L || !is.finite(v)) {
    stop(
      .rmbl_fn(),
      sprintf("the statistic must return one finite number; on %s it ", what),
      "returned something else",
      call. = FALSE
    )
  }
  v
}

#' One row of cpsfals()'s control table.
#' @param control The control's name.
#' @param passed Whether it passed, `NA` when skipped.
#' @param value The control's number.
#' @param detail The sentence that explains it.
#' @return A one-row data frame.
#' @noRd
.rmbl_fals_row <- function(control, passed, value, detail) {
  data.frame(
    control = control,
    passed = passed,
    value = value,
    detail = as.character(detail),
    stringsAsFactors = FALSE
  )
}

#' cpsfals()'s data, statistic, counts and treatment column, checked.
#' @param data,stat,n,subfrac,trt As for cpsfals().
#' @return A list with the checked `n`, `subfrac` and `trt`.
#' @noRd
.rmbl_fals_args <- function(data, stat, n, subfrac, trt) {
  if (!is.data.frame(data) || nrow(data) < 4L) {
    stop(
      "cpsfals: `data` must be a data frame with at least 4 rows",
      call. = FALSE
    )
  }
  if (!is.function(stat)) {
    stop("`stat` must be a function of one data frame", call. = FALSE)
  }
  n <- .rmbl_num(n, "n", integer = TRUE)[1L]
  if (is.na(n) || n < 9L) {
    stop(
      "`n` must be at least 9: fewer permutations cannot produce a ",
      "p-value below 0.1",
      call. = FALSE
    )
  }
  subfrac <- .rmbl_num(subfrac, "subfrac")[1L]
  if (is.na(subfrac) || subfrac <= 0 || subfrac >= 1) {
    stop("`subfrac` must be between 0 and 1", call. = FALSE)
  }
  if (!is.null(trt)) {
    trt <- as.character(trt)[1L]
    if (!trt %in% names(data)) {
      stop("cpsfals: `trt` is not a column of `data`", call. = FALSE)
    }
  }
  list(n = n, subfrac = subfrac, trt = trt)
}

#' cpsfals()'s permutation and placebo controls.
#' @param data,stat,trt,n As for cpsfals() (checked).
#' @param observed The statistic on the data as given.
#' @param pg The progress bar, updated after each permutation.
#' @return A list with `perm` (the permuted statistics, `NULL` without a
#'   treatment column) and `rows` (two control rows).
#' @noRd
.rmbl_fals_perm <- function(data, stat, trt, n, observed, pg) {
  if (is.null(trt)) {
    why <- "skipped: no `trt` column was named"
    return(list(
      perm = NULL,
      rows = list(
        .rmbl_fals_row("permutation", NA, NA_real_, why),
        .rmbl_fals_row("placebo", NA, NA_real_, why)
      )
    ))
  }
  perm <- vapply(
    seq_len(n),
    function(i) {
      pg$update(i, sprintf("permutation %d/%d", i, n))
      d <- data
      d[[trt]] <- sample(d[[trt]])
      tryCatch(as.numeric(stat(d))[1L], error = .rmbl_or(NA_real_))
    },
    numeric(1)
  )
  ok <- is.finite(perm)
  # The two-sided permutation p-value, with the +1 that keeps it from
  # ever being zero: the observed value is one of the arrangements.
  extreme <- sum(abs(perm[ok]) >= abs(observed))
  p <- (1 + extreme) / (1 + sum(ok))
  floor_p <- 1 / (1 + sum(ok))
  r1 <- .rmbl_fals_row(
    "permutation",
    p < 0.05,
    p,
    sprintf(
      paste0(
        "p = %.4g with %d usable permutations; the ",
        "smallest this design can report is %.4g"
      ),
      p,
      sum(ok),
      floor_p
    )
  )

  r2 <- .rmbl_fals_placebo(data, stat, trt, perm[ok], observed)
  list(perm = perm, rows = list(r1, r2))
}

#' cpsfals()'s placebo control: a permuted exposure should sit inside the
#' permutation null.
#' @param data,stat,trt As for cpsfals() (checked).
#' @param perm The usable permuted statistics.
#' @param observed The statistic on the data as given.
#' @return A control row.
#' @noRd
.rmbl_fals_placebo <- function(data, stat, trt, perm, observed) {
  d <- data
  d[[trt]] <- sample(d[[trt]])
  placebo <- .rmbl_falsify_eval(stat, d, "the placebo exposure")
  # A placebo effect should sit inside the permutation null, since
  # that is exactly what it is a draw from.
  inside <- abs(placebo) <= stats::quantile(abs(perm), 0.95, names = FALSE)
  .rmbl_fals_row(
    "placebo",
    inside,
    placebo,
    sprintf(
      paste0("a permuted exposure gives %.6g, against an ", "observed %.6g"),
      placebo,
      observed
    )
  )
}

#' cpsfals()'s random-common-cause control: an added noise column must not
#' move the statistic.
#' @param data,stat As for cpsfals().
#' @param observed The statistic on the data as given.
#' @return A control row.
#' @noRd
.rmbl_fals_rcc <- function(data, stat, observed) {
  d <- data
  d[[".rmbl_random_common_cause"]] <- stats::rnorm(nrow(data))
  rcc <- .rmbl_falsify_eval(stat, d, "an added noise column")
  moved <- abs(rcc - observed)
  tol <- 1e-8 * max(1, abs(observed))
  .rmbl_fals_row(
    "random_common_cause",
    moved <= tol,
    rcc,
    sprintf(
      paste0(
        "adding a column of noise moved the statistic by ",
        "%.3g; it cannot matter, so anything above %.3g is ",
        "the statistic reading its own inputs wrongly"
      ),
      moved,
      tol
    )
  )
}

#' cpsfals()'s subset-stability control.
#' @param data,stat,n,subfrac As for cpsfals() (checked).
#' @param observed The statistic on the data as given.
#' @param pg The progress bar, updated after each subset.
#' @return A control row.
#' @noRd
.rmbl_fals_subsets <- function(data, stat, n, subfrac, observed, pg) {
  k <- max(2L, as.integer(round(subfrac * nrow(data))))
  subs <- vapply(
    seq_len(n),
    function(i) {
      pg$update(n + i, sprintf("subset %d/%d", i, n))
      idx <- sample.int(nrow(data), k)
      tryCatch(
        as.numeric(stat(data[idx, , drop = FALSE]))[1L],
        error = .rmbl_or(NA_real_)
      )
    },
    numeric(1)
  )
  sok <- is.finite(subs)
  if (any(sok)) {
    q <- stats::quantile(subs[sok], c(0.025, 0.975), names = FALSE)
    spread <- diff(q)
    scale <- max(abs(observed), stats::sd(subs[sok]), .Machine$double.eps)
    .rmbl_fals_row(
      "subset_stability",
      observed >= q[1] && observed <= q[2],
      spread,
      sprintf(
        paste0(
          "the middle 95%% of %d subsets spans [%.6g, ",
          "%.6g], a width of %.3g relative to %.3g"
        ),
        sum(sok),
        q[1],
        q[2],
        spread,
        scale
      )
    )
  } else {
    .rmbl_fals_row(
      "subset_stability",
      FALSE,
      NA_real_,
      "the statistic could not be computed on any subset"
    )
  }
}
