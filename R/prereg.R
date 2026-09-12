# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Pre-registration, multiple testing, and sensitivity to what was never
# measured.
#
# capsule_falsify() asks whether a finding survives its controls. These
# ask three questions that come before and after it: was this the
# analysis that was planned, how many other analyses were run, and how
# strong would something unobserved have to be to explain the result
# away. None of them is answerable from the data alone, which is exactly
# why they have to be recorded rather than computed.

#' Declare an analysis before running it
#'
#' Records the statistics an analysis intends to report and what each is
#' meant to show, so that what was actually reported can be compared
#' against it afterwards. Seal it with
#' [capsule_attest()] and the declaration
#' acquires a date it cannot be moved off.
#'
#' The comparison [prereg_check()] makes is
#' asymmetric on purpose, because the two ways of departing from a plan are
#' different failures:
#'
#' * a declared statistic that was NOT reported is outcome switching --
#' the analysis was run and its result dropped;
#' * a reported statistic that was NOT declared is an addition, and
#' twenty of them is why a nominal p of 0.05 means nothing.
#'
#' Neither is misconduct on its own and both are invisible without a
#' declaration made in advance.
#'
#' @param hypotheses Named character vector: one claim
#' per statistic, named by the statistic's name as it will be recorded.
#' @param note Optional free text -- the design, the data
#' source, what would count as a refutation.
#' @param prereg A declaration from `prereg_declare()`.
#' @param reported Character vector of the statistic names
#' actually reported, or a manifest from which they are taken.
#' @return `prereg_declare()` a list of class
#' `bricklayer_prereg`; `prereg_check()` a list with `ok`,
#' `declared_not_reported`, `reported_not_declared` and a
#' `hypotheses` data frame.
#' @seealso
#' [capsule_attest()] to seal a declaration,
#' [capsule_falsify()] for the controls
#' themselves, [falsify_family()] for the
#' correction that additions make necessary.
#' @examples
#' plan <- prereg_declare(c(
#'   ate = "use of force is higher in the exposed division",
#'   n_rows = "the extract has the row count the source publishes"),
#'   note = "OTIS 2019-2024, division-level, pre-specified")
#'
#' # afterwards, against what was reported
#' prereg_check(plan, c("ate", "n_rows"))$ok
#'
#' # dropping a declared outcome is outcome switching
#' prereg_check(plan, "n_rows")$declared_not_reported
#'
#' # and adding undeclared ones is what makes a nominal p meaningless
#' prereg_check(plan, c("ate", "n_rows", "ate_by_year",
#'                      "ate_by_precinct"))$reported_not_declared
#' @export
prereg_declare <- function(hypotheses, note = NULL) {
  if (!is.character(hypotheses) || !length(hypotheses) ||
      is.null(names(hypotheses)) || any(!nzchar(names(hypotheses)))) {
    stop("`hypotheses` must be a named character vector: one claim per ",
         "statistic", call. = FALSE)
  }
  if (anyDuplicated(names(hypotheses))) {
    stop("`hypotheses` has duplicate names", call. = FALSE)
  }
  out <- list(
    statistics = names(hypotheses),
    hypotheses = as.character(hypotheses),
    note = if (is.null(note)) "" else as.character(note)[1L],
    declared_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
  class(out) <- c("bricklayer_prereg", "list")
  out
}

#' @rdname prereg_declare
#' @export
prereg_check <- function(prereg, reported) {
  if (!inherits(prereg, "bricklayer_prereg")) {
    stop("`prereg` must come from prereg_declare()", call. = FALSE)
  }
  if (is.list(reported) && !is.null(reported$results)) {
    reported <- names(reported$results)
  }
  reported <- as.character(reported)
  declared <- prereg$statistics
  missing <- setdiff(declared, reported)
  added <- setdiff(reported, declared)
  df <- data.frame(statistic = declared,
                   hypothesis = prereg$hypotheses,
                   reported = declared %in% reported,
                   stringsAsFactors = FALSE)
  rownames(df) <- NULL
  out <- list(ok = length(missing) == 0L && length(added) == 0L,
              declared_not_reported = missing,
              reported_not_declared = added,
              hypotheses = df,
              declared_utc = prereg$declared_utc)
  class(out) <- c("bricklayer_prereg_check", "list")
  out
}

#' @export
format.bricklayer_prereg <- function(x, ...) {
  c(.rmbl_rule("Pre-registration"),
    sprintf("  declared %s", x$declared_utc),
    if (nzchar(x$note)) sprintf("  %s", x$note),
    .rmbl_rule(),
    sprintf("  %-22s %s", x$statistics,
            substring(x$hypotheses, 1L, 44L)),
    .rmbl_rule())
}

#' @rdname rmbl_print_methods
#' @export
print.bricklayer_prereg <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

#' @export
format.bricklayer_prereg_check <- function(x, ...) {
  c(.rmbl_rule(sprintf("Against the declaration of %s: %s",
                       x$declared_utc,
                       if (x$ok) "as declared" else "departures below")),
    if (length(x$declared_not_reported))
      sprintf("  declared but not reported (outcome switching): %s",
              paste(x$declared_not_reported, collapse = ", ")),
    if (length(x$reported_not_declared))
      sprintf("  reported but not declared (%d addition(s)): %s",
              length(x$reported_not_declared),
              paste(x$reported_not_declared, collapse = ", ")),
    .rmbl_rule())
}

#' @rdname rmbl_print_methods
#' @export
print.bricklayer_prereg_check <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

#' Correct a family of falsification results for multiple testing
#'
#' Takes the p-values from several
#' [capsule_falsify()] runs -- or a plain
#' numeric vector -- and reports which survive once the size of the family
#' is accounted for.
#'
#' Running the permutation control over twenty statistics and reporting the
#' one that came in under 0.05 is not a finding: at that family size
#' roughly one spurious result is what chance produces. Which correction to
#' use depends on the claim. Holm controls the probability of ANY false
#' positive, which is what a claim about a specific statistic needs.
#' Benjamini-Hochberg controls the expected PROPORTION of false positives
#' among those declared, which is what a screening exercise needs; it is
#' less conservative and says something weaker.
#'
#' A permutation p-value cannot fall below `1 / (n + 1)`, so with a
#' small number of permutations a whole family can be uncorrectable --
#' every p sits at the floor. That is reported rather than hidden, because
#' the alternative is a table of adjusted values that look like evidence of
#' nothing in particular.
#'
#' @param x A named list of `bricklayer_falsification`
#' objects, or a named numeric vector of p-values.
#' @param method `"holm"` (the default), `"bh"`,
#' `"bonferroni"` or `"none"`.
#' @param alpha Threshold applied to the adjusted values.
#' @return A list of class `bricklayer_falsify_family`: a
#' `results` data frame ( `name`, `p`, `adjusted`,
#' `survives`) , the `method`, the family size, and
#' `at_floor`, the names whose p-value equals the smallest their
#' permutation count could produce.
#' @seealso
#' [capsule_falsify()],
#' [prereg_declare()].
#' @examples
#' # four statistics, one of which is real
#' set.seed(1)
#' d <- data.frame(x = rnorm(150))
#' d$y <- 0.6 * d$x + rnorm(150)
#' d$a <- rnorm(150)
#' d$b <- rnorm(150)
#' fam <- list(
#'   real = capsule_falsify(d, function(z) cor(z$x, z$y),
#'                          treatment = "x", n = 199, seed = 1),
#'   noise_a = capsule_falsify(d, function(z) cor(z$a, z$y),
#'                             treatment = "a", n = 199, seed = 2),
#'   noise_b = capsule_falsify(d, function(z) cor(z$b, z$y),
#'                             treatment = "b", n = 199, seed = 3))
#' falsify_family(fam)
#'
#' # the correction is what stops the smallest of several from being
#' # read as the finding
#' falsify_family(c(a = 0.01, b = 0.04, c = 0.2, d = 0.5))$results
#' @export
falsify_family <- function(x, method = c("holm", "bh", "bonferroni",
                                         "none"),
                           alpha = 0.05) {
  method <- match.arg(method)
  at_floor <- character(0)
  if (is.list(x) && length(x) &&
      all(vapply(x, inherits, logical(1), "bricklayer_falsification"))) {
    nms <- names(x)
    if (is.null(nms) || any(!nzchar(nms))) {
      stop("`x` must be a NAMED list of falsification results",
           call. = FALSE)
    }
    p <- vapply(x, function(f) {
      v <- f$controls$value[f$controls$control == "permutation"]
      if (!length(v)) NA_real_ else as.numeric(v)[1L]
    }, numeric(1))
    floors <- vapply(x, function(f) 1 / (1 + f$n), numeric(1))
    at_floor <- nms[is.finite(p) & abs(p - floors) < 1e-12]
    names(p) <- nms
  } else if (is.numeric(x)) {
    p <- x
    if (is.null(names(p))) names(p) <- paste0("p", seq_along(p))
  } else {
    stop("`x` must be a named list of falsification results or a ",
         "numeric vector of p-values", call. = FALSE)
  }
  if (any(is.na(p))) {
    stop("every member of the family needs a p-value; ",
         "a permutation control that was skipped has none", call. = FALSE)
  }
  if (any(p < 0 | p > 1)) {
    stop("p-values must lie in [0, 1]", call. = FALSE)
  }
  adj <- .rmbl_p_adjust(p, method)
  df <- data.frame(name = names(p), p = as.numeric(p),
                   adjusted = as.numeric(adj),
                   survives = as.numeric(adj) <= alpha,
                   stringsAsFactors = FALSE)
  rownames(df) <- NULL
  out <- list(results = df[order(df$p), ], method = method,
              family_size = length(p), alpha = alpha,
              at_floor = at_floor)
  rownames(out$results) <- NULL
  class(out) <- c("bricklayer_falsify_family", "list")
  out
}

# Holm, Benjamini-Hochberg and Bonferroni, written out rather than
# delegated so the step-up and step-down directions are visible: Holm
# accumulates a running maximum from the smallest p upward, BH a running
# minimum from the largest downward, and swapping them silently inverts
# which hypotheses survive.
.rmbl_p_adjust <- function(p, method) {
  n <- length(p)
  if (identical(method, "none") || n == 0L) return(pmin(1, p))
  if (identical(method, "bonferroni")) return(pmin(1, n * p))
  o <- order(p)
  ro <- order(o)
  ps <- p[o]
  if (identical(method, "holm")) {
    adj <- cummax((n - seq_len(n) + 1L) * ps)
  } else {
    adj <- rev(cummin(rev(n / seq_len(n) * ps)))
  }
  pmin(1, adj)[ro]
}

#' @export
format.bricklayer_falsify_family <- function(x, ...) {
  c(.rmbl_rule(sprintf("Family of %d, corrected by %s at alpha %.3g",
                       x$family_size, x$method, x$alpha)),
    sprintf("  %-22s p %-10.4g adjusted %-10.4g %s", x$results$name,
            x$results$p, x$results$adjusted,
            ifelse(x$results$survives, "survives", "")),
    if (length(x$at_floor))
      c(.rmbl_rule(),
        sprintf(paste0("  at the permutation floor (more permutations ",
                       "would be needed to say more): %s"),
                paste(x$at_floor, collapse = ", "))),
    .rmbl_rule())
}

#' @rdname rmbl_print_methods
#' @export
print.bricklayer_falsify_family <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

#' How strong would an unmeasured confounder have to be
#'
#' The E-value of VanderWeele and Ding (2017): the minimum strength of
#' association, on the risk-ratio scale, that an unmeasured confounder
#' would need with BOTH the exposure and the outcome to explain away an
#' observed risk ratio.
#'
#' It answers the question a covariate list cannot: not whether the
#' analysis adjusted for the right things, but how much unmeasured
#' confounding it would take to move the result to nothing. An E-value of
#' 1.2 says very little would be needed; an E-value of 5 says a confounder
#' five times more common in the exposed group AND five times more
#' associated with the outcome would have to have gone unnoticed.
#'
#' The E-value for the confidence limit is the one to report alongside it:
#' a large point-estimate E-value with a limit E-value of 1 means the
#' interval already includes no effect, and no confounding is needed at
#' all.
#'
#' @param rr Observed risk ratio, greater than 0. Protective
#' effects (below 1) are inverted first, as the measure is symmetric.
#' @param lo,hi Optional confidence limits on the same scale.
#' The limit nearer the null is the one used.
#' @param true The value to move the estimate to. Defaults to
#' 1, the null.
#' @return A named numeric vector: `evalue_point` and, when limits are
#' given, `evalue_limit`.
#' @references VanderWeele, T. J., and Ding, P. (2017). Sensitivity
#' Analysis in Observational Research: Introducing the E-Value.
#' *Annals of Internal Medicine* 167(4), 268-274.
#'   \doi{10.7326/M16-2607}
#' @seealso
#' [capsule_falsify()] for controls that use
#' the data, where this uses none.
#' @examples
#' # a risk ratio of 2 needs a confounder associated by 3.41 with both
#' evalue_rr(2)
#'
#' # a protective effect is inverted, so 0.5 gives the same answer
#' evalue_rr(0.5)
#'
#' # an interval that already includes the null needs nothing
#' evalue_rr(2, lo = 0.9, hi = 4.4)
#'
#' # and a strong result with a limit well above the null is harder to
#' # explain away
#' evalue_rr(3, lo = 2.1, hi = 4.3)
#' @export
evalue_rr <- function(rr, lo = NULL, hi = NULL, true = 1) {
  one <- function(v) {
    v <- as.numeric(v)[1L]
    if (!is.finite(v) || v <= 0) {
      stop("risk ratios must be finite and positive", call. = FALSE)
    }
    v
  }
  true <- one(true)
  rr <- one(rr) / true
  # The measure is symmetric about the null: a halving is as hard to
  # explain away as a doubling, so a protective effect is inverted.
  if (rr < 1) rr <- 1 / rr
  point <- rr + sqrt(rr * (rr - 1))
  out <- c(evalue_point = point)
  if (!is.null(lo) || !is.null(hi)) {
    l <- if (is.null(lo)) NA_real_ else one(lo) / true
    h <- if (is.null(hi)) NA_real_ else one(hi) / true
    # the limit NEARER the null is what has to be moved
    lim <- if (!is.na(l) && l > 1) l else if (!is.na(h) && h < 1) 1 / h else
      NA_real_
    out <- c(out, evalue_limit =
               if (is.na(lim)) 1 else lim + sqrt(lim * (lim - 1)))
  }
  out
}
