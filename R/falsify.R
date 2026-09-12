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
#' Recomputes `statistic` under conditions in which its value is known
#' in advance, and reports whether it behaved. Four controls, each
#' answering a different way of being wrong:
#'
#' * **permutation** -- shuffle `treatment` and the association it
#' carries is destroyed, so the statistic should fall to its null
#' distribution. Reports where the observed value sits in that
#' distribution, and the smallest p-value the number of permutations could
#' have produced.
#' * **random common cause** -- add a column of noise. It cannot
#' possibly matter, so a statistic that moves is reading something other
#' than the data.
#' * **placebo treatment** -- replace `treatment` with a random draw of
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
#' @param data A data frame.
#' @param statistic A function of one data frame returning
#' a single finite number.
#' @param treatment Name of the column the finding is
#' about, permuted for the permutation and placebo controls. Optional:
#' without it those two controls are skipped and reported as such rather
#' than silently omitted.
#' @param n Number of permutations and subsets. The permutation
#' p-value cannot be smaller than `1 / (n + 1)`, which is reported.
#' @param subset_frac Fraction of rows kept by the
#' subset control.
#' @param seed Optional integer seed. Supplied, the result is
#' reproducible; omitted, the current RNG state is used and recorded.
#' @return A list of class `bricklayer_falsification`:
#' `observed`, a `controls` data frame (one row per control, with
#' `passed`) , and `permutation` holding the null distribution.
#' @seealso
#' [capsule_attest()] for the other question
#' -- whether the record is intact, rather than whether the finding
#' survives.
#' @examples
#' set.seed(1)
#' d <- data.frame(x = rnorm(200))
#' d$y <- 0.8 * d$x + rnorm(200)
#' # a real association survives its controls
#' real <- capsule_falsify(d, function(z) cor(z$x, z$y),
#'                         treatment = "x", n = 199, seed = 42)
#' real$controls[, c("control", "passed")]
#'
#' # and a statistic that ignores the data fails the ones that can see it
#' fake <- capsule_falsify(d, function(z) 0.5, treatment = "x",
#'                         n = 199, seed = 42)
#' fake$controls[fake$controls$control == "permutation", "passed"]
#' @export
capsule_falsify <- function(data, statistic, treatment = NULL, n = 199L,
                            subset_frac = 0.8, seed = NULL) {
  if (!is.data.frame(data) || nrow(data) < 4L) {
    stop("`data` must be a data frame with at least 4 rows", call. = FALSE)
  }
  if (!is.function(statistic)) {
    stop("`statistic` must be a function of one data frame", call. = FALSE)
  }
  n <- as.integer(n)[1L]
  if (is.na(n) || n < 9L) {
    stop("`n` must be at least 9: fewer permutations cannot produce a ",
         "p-value below 0.1", call. = FALSE)
  }
  subset_frac <- as.numeric(subset_frac)[1L]
  if (is.na(subset_frac) || subset_frac <= 0 || subset_frac >= 1) {
    stop("`subset_frac` must be between 0 and 1", call. = FALSE)
  }
  if (!is.null(treatment)) {
    treatment <- as.character(treatment)[1L]
    if (!treatment %in% names(data)) {
      stop("`treatment` is not a column of `data`", call. = FALSE)
    }
  }
  if (!is.null(seed)) set.seed(as.integer(seed)[1L])

  observed <- .rmbl_falsify_eval(statistic, data, "the data as given")
  rows <- list()
  add <- function(control, passed, value, detail) {
    rows[[length(rows) + 1L]] <<- data.frame(
      control = control, passed = passed, value = value,
      detail = as.character(detail), stringsAsFactors = FALSE)
  }

  perm <- NULL
  if (is.null(treatment)) {
    add("permutation", NA, NA_real_,
        "skipped: no `treatment` column was named")
    add("placebo", NA, NA_real_,
        "skipped: no `treatment` column was named")
  } else {
    perm <- vapply(seq_len(n), function(i) {
      d <- data
      d[[treatment]] <- sample(d[[treatment]])
      tryCatch(as.numeric(statistic(d))[1L], error = function(e) NA_real_)
    }, numeric(1))
    ok <- is.finite(perm)
    # The two-sided permutation p-value, with the +1 that keeps it from
    # ever being zero: the observed value is one of the arrangements.
    extreme <- sum(abs(perm[ok]) >= abs(observed))
    p <- (1 + extreme) / (1 + sum(ok))
    floor_p <- 1 / (1 + sum(ok))
    add("permutation", p < 0.05, p,
        sprintf(paste0("p = %.4g with %d usable permutations; the ",
                       "smallest this design can report is %.4g"),
                p, sum(ok), floor_p))

    d <- data
    d[[treatment]] <- sample(d[[treatment]])
    placebo <- .rmbl_falsify_eval(statistic, d, "the placebo exposure")
    # A placebo effect should sit inside the permutation null, since
    # that is exactly what it is a draw from.
    inside <- abs(placebo) <= stats::quantile(abs(perm[ok]), 0.95,
                                              names = FALSE)
    add("placebo", inside, placebo,
        sprintf(paste0("a permuted exposure gives %.6g, against an ",
                       "observed %.6g"), placebo, observed))
  }

  d <- data
  d[[".rmbl_random_common_cause"]] <- stats::rnorm(nrow(data))
  rcc <- .rmbl_falsify_eval(statistic, d, "an added noise column")
  moved <- abs(rcc - observed)
  tol <- 1e-8 * max(1, abs(observed))
  add("random_common_cause", moved <= tol, rcc,
      sprintf(paste0("adding a column of noise moved the statistic by ",
                     "%.3g; it cannot matter, so anything above %.3g is ",
                     "the statistic reading its own inputs wrongly"),
              moved, tol))

  k <- max(2L, as.integer(round(subset_frac * nrow(data))))
  subs <- vapply(seq_len(n), function(i) {
    idx <- sample.int(nrow(data), k)
    tryCatch(as.numeric(statistic(data[idx, , drop = FALSE]))[1L],
             error = function(e) NA_real_)
  }, numeric(1))
  sok <- is.finite(subs)
  if (!any(sok)) {
    add("subset_stability", FALSE, NA_real_,
        "the statistic could not be computed on any subset")
  } else {
    q <- stats::quantile(subs[sok], c(0.025, 0.975), names = FALSE)
    spread <- diff(q)
    scale <- max(abs(observed), stats::sd(subs[sok]), .Machine$double.eps)
    add("subset_stability", observed >= q[1] && observed <= q[2], spread,
        sprintf(paste0("the middle 95%% of %d subsets spans [%.6g, ",
                       "%.6g], a width of %.3g relative to %.3g"),
                sum(sok), q[1], q[2], spread, scale))
  }

  df <- do.call(rbind, rows)
  rownames(df) <- NULL
  out <- list(observed = observed, controls = df,
              permutation = perm,
              n = n, treatment = treatment,
              rng_kind = paste(RNGkind(), collapse = ","),
              seed = if (is.null(seed)) NA_integer_ else
                as.integer(seed)[1L])
  class(out) <- c("bricklayer_falsification", "list")
  out
}

#' @export
format.bricklayer_falsification <- function(x, ...) {
  verdict <- function(p) if (is.na(p)) "skip" else if (p) "ok" else "FAIL"
  c(.rmbl_rule("Falsification controls"),
    sprintf("  observed statistic  %.8g", x$observed),
    sprintf("  permutations        %d%s", x$n,
            if (is.na(x$seed)) "" else sprintf(" (seed %d)", x$seed)),
    .rmbl_rule(),
    sprintf("  %-22s %-5s %s", x$controls$control,
            vapply(x$controls$passed, verdict, character(1)),
            substring(x$controls$detail, 1L, 40L)),
    .rmbl_rule())
}

#' @rdname rmbl_print_methods
#' @export
print.bricklayer_falsification <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

# A statistic has to return one finite number. Anything else is an error
# here rather than an NA that quietly passes every control below.
.rmbl_falsify_eval <- function(statistic, data, what) {
  v <- tryCatch(statistic(data), error = function(e) {
    stop(sprintf("the statistic failed on %s: %s", what,
                 conditionMessage(e)), call. = FALSE)
  })
  v <- suppressWarnings(as.numeric(v))
  if (length(v) != 1L || !is.finite(v)) {
    stop(sprintf("the statistic must return one finite number; on %s it ",
                 what), "returned something else", call. = FALSE)
  }
  v
}
