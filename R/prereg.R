# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Pre-registration, multiple testing, and sensitivity to what was never
# measured.
#
# cpsfals() asks whether a finding survives its controls. These
# ask three questions that come before and after it: was this the
# analysis that was planned, how many other analyses were run, and how
# strong would something unobserved have to be to explain the result
# away. None of them is answerable from the data alone, which is exactly
# why they have to be recorded rather than computed.

#' Declare an analysis before running it
#'
#' @description
#' `prrgdecl()` records, before the analysis is run, the statistics
#' it intends to report and the claim each one is meant to test, with a UTC
#' timestamp. `prrgchk()` compares that declaration with what was
#' actually reported and lists the departures in both directions. Seal the
#' declaration with [cpsatst()] and it acquires a
#' date it cannot be
#' moved off. Use the pair to make a pre-analysis plan checkable.
#'
#' @details
#' The comparison [prrgchk()] makes is
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
#' Statistics are matched by exact name. The timestamp is the computer's
#' clock at the time of the call, so on its own it proves nothing; the
#' attestation is what fixes the date. Nothing is written to disk.
#'
#' Errors: `hyps` not a non-empty character vector with non-empty,
#' unique names; `prereg` not from `prrgdecl()`.
#'
#' @param hyps Named character vector: one claim
#' per statistic, named by the statistic's name as it will be recorded.
#' @param note Optional character string, default `NULL`: free text -- the
#' design, the data source, what would count as a refutation. Only the first
#' element is kept.
#' @param prereg A declaration from `prrgdecl()`.
#' @param rptd Character vector of the statistic names
#' actually reported, or a manifest (any list with a named `results`
#' element, such as a capsule manifest), whose result names are used.
#' @return `prrgdecl()` returns a list of class `bricklayer_prereg`
#' with `statistics` (the names), `hypotheses` (the claims), `note` and
#' `decutc` (ISO 8601 time).
#'
#' `prrgchk()` returns a list of class `bricklayer_prereg_check` with `ok`
#' (logical: no departures), the character vectors `decnotrep` and
#' `repnotdec`, `hypotheses` (a data frame of `statistic`,
#' `hypothesis` and
#' logical `reported`) and `decutc`. Both print a short summary.
#' @seealso
#' [cpsatst()] to seal a declaration,
#' [cpsfals()] for the controls
#' themselves, [falsfam()] for the
#' correction that additions make necessary.
#' @examplesIf interactive() || any(nzchar(Sys.getenv(c("NOT_CRAN", "MY_UNIVERSE", "IN_PKGDOWN"))))
#' plan <- prrgdecl(c(
#'   ate = "use of force is higher in the exposed division",
#'   nrows = "the extract has the row count the source publishes"),
#'   note = "OTIS 2019-2024, division-level, pre-specified")
#'
#' # afterwards, against what was reported
#' prrgchk(plan, c("ate", "nrows"))$ok
#'
#' # dropping a declared outcome is outcome switching
#' prrgchk(plan, "nrows")$decnotrep
#'
#' # and adding undeclared ones is what makes a nominal p meaningless
#' prrgchk(plan, c("ate", "nrows", "atebyyear",
#'                      "atebyprecinct"))$repnotdec
#'
#' # the full check prints the departures
#' prrgchk(plan, c("ate", "atebyyear"))
#'
#' try(prrgdecl(c("an unnamed claim")))
#' @export
prrgdecl <- function(hyps, note = NULL) {
  .rmbl_no_fn(note = note)
  if (!is.character(hyps) || !length(hyps) ||
      is.null(names(hyps)) || any(!nzchar(names(hyps)))) {
    stop("`hyps` must be a named character vector: one claim per ",
         "statistic", call. = FALSE)
  }
  if (anyDuplicated(names(hyps))) {
    stop("`hyps` has duplicate names", call. = FALSE)
  }
  out <- list(
    statistics = names(hyps),
    hypotheses = as.character(hyps),
    note = if (is.null(note)) "" else as.character(note)[1L],
    decutc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
  class(out) <- c("bricklayer_prereg", "list")
  out
}

#' @rdname prrgdecl
#' @export
prrgchk <- function(prereg, rptd) {
  .rmbl_no_fn(reported = rptd)
  if (!inherits(prereg, "bricklayer_prereg")) {
    stop("`prereg` must come from prrgdecl()", call. = FALSE)
  }
  if (is.list(rptd) && !is.null(rptd$results)) {
    rptd <- names(rptd$results)
  }
  rptd <- as.character(rptd)
  declared <- prereg$statistics
  missing <- setdiff(declared, rptd)
  added <- setdiff(rptd, declared)
  df <- data.frame(statistic = declared,
                   hypothesis = prereg$hypotheses,
                   reported = declared %in% rptd,
                   stringsAsFactors = FALSE)
  rownames(df) <- NULL
  out <- list(ok = length(missing) == 0L && length(added) == 0L,
              decnotrep = missing,
              repnotdec = added,
              hypotheses = df,
              decutc = prereg$decutc)
  class(out) <- c("bricklayer_prereg_check", "list")
  out
}

#' @export
format.bricklayer_prereg <- function(x, ...) {
  c(.rmbl_rule("Pre-registration"),
    sprintf("  declared %s", x$decutc),
    if (nzchar(x$note)) sprintf("  %s", x$note),
    .rmbl_rule(),
    sprintf("  %-22s %s", x$statistics,
            substring(x$hypotheses, 1L, 44L)),
    .rmbl_rule())
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_prereg
print.bricklayer_prereg <- .rmbl_print_via_format

#' @export
format.bricklayer_prereg_check <- function(x, ...) {
  c(.rmbl_rule(sprintf("Against the declaration of %s: %s",
                       x$decutc,
                       if (x$ok) "as declared" else "departures below")),
    if (length(x$decnotrep))
      sprintf("  declared but not reported (outcome switching): %s",
              paste(x$decnotrep, collapse = ", ")),
    if (length(x$repnotdec))
      sprintf("  reported but not declared (%d addition(s)): %s",
              length(x$repnotdec),
              paste(x$repnotdec, collapse = ", ")),
    .rmbl_rule())
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_prereg_check
print.bricklayer_prereg_check <- .rmbl_print_via_format

#' Correct a family of falsification results for multiple testing
#'
#' @description
#' Takes the p-values from several
#' [cpsfals()] runs -- or a plain
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
#' @details
#' With the \eqn{m} p-values sorted, \eqn{p_{(1)} \le \dots \le p_{(m)}}, the
#' adjusted values are: Holm, \eqn{\max_{j \le i} (m - j + 1) p_{(j)}};
#' Benjamini-Hochberg, \eqn{\min_{j \ge i} (m / j) p_{(j)}}; Bonferroni,
#' \eqn{m p_{(i)}}; all capped at 1. They agree with
#' \code{stats::p.adjust()} with methods \code{"holm"}, \code{"BH"} and
#' \code{"bonferroni"}. A member survives when its adjusted value is at
#' most `alpha`.
#'
#' For a list of [cpsfals()] results the p-value
#' used is that of
#' each result's permutation control, and the floor is \eqn{1/(n + 1)} for
#' its `n` permutations. For a numeric vector there is no floor to check and
#' unnamed values are named `p1`, `p2`, ....
#'
#' Errors: a list whose members are not all falsification results, or that
#' is unnamed; a member without a permutation p-value; a missing p-value; a
#' p-value outside \eqn{[0, 1]}.
#'
#' @param x A named list of `bricklayer_falsification`
#' objects, or a named numeric vector of p-values.
#' @param meth `"holm"` (the default), `"bh"`,
#' `"bonferroni"` or `"none"`.
#' @param alpha Number, default 0.05: the threshold applied to the adjusted
#' values.
#' @return A list of class `bricklayer_falsify_family` with `results` (a data
#' frame of `name`, `p`, `adjusted` and logical `survives`, sorted by
#' `p`),
#' `method`, `famsz` (integer), `alpha`, and `atflr` (the
#' names
#' whose p-value equals the smallest their permutation count could produce;
#' empty for a numeric vector). The print method shows the table.
#' @seealso
#' [cpsfals()],
#' [prrgdecl()].
#' @examplesIf interactive() || any(nzchar(Sys.getenv(c("NOT_CRAN", "MY_UNIVERSE", "IN_PKGDOWN"))))
#' # four statistics, one of which is real
#' set.seed(1)
#' d <- data.frame(x = rnorm(150))
#' d$y <- 0.6 * d$x + rnorm(150)
#' d$a <- rnorm(150)
#' d$b <- rnorm(150)
#' fam <- list(
#'   real = cpsfals(d, function(z) cor(z$x, z$y),
#'                          trt = "x", n = 199, seed = 1),
#'   noisea = cpsfals(d, function(z) cor(z$a, z$y),
#'                             trt = "a", n = 199, seed = 2),
#'   noiseb = cpsfals(d, function(z) cor(z$b, z$y),
#'                             trt = "b", n = 199, seed = 3))
#' falsfam(fam)
#'
#' # the correction is what stops the smallest of several from being
#' # read as the finding
#' falsfam(c(a = 0.01, b = 0.04, c = 0.2, d = 0.5))$results
#'
#' # the false-discovery rate is less strict than Holm
#' falsfam(c(a = 0.01, b = 0.04, c = 0.2, d = 0.5), meth = "bh")$results
#'
#' try(falsfam(c(a = 0.01, b = 1.2)))
#' @export
falsfam <- function(x, meth = c("holm", "bh", "bonferroni",
                                         "none"),
                           alpha = 0.05) {
  if (!length(x)) stop("`x` must hold at least one falsification result or p-value", call. = FALSE)
  meth <- .rmbl_arg(meth)
  alpha <- .rmbl_conf_level(alpha, "alpha")
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
  adj <- .rmbl_p_adjust(p, meth)
  df <- data.frame(name = names(p), p = as.numeric(p),
                   adjusted = as.numeric(adj),
                   survives = as.numeric(adj) <= alpha,
                   stringsAsFactors = FALSE)
  rownames(df) <- NULL
  out <- list(results = df[order(df$p), ], method = meth,
              famsz = length(p), alpha = alpha,
              atflr = at_floor)
  rownames(out$results) <- NULL
  class(out) <- c("bricklayer_falsify_family", "list")
  out
}

#' Adjusts p-values for multiple comparisons.
#'
#' Holm, Benjamini-Hochberg and Bonferroni, written out rather than
#' delegated so the step-up and step-down directions are visible: Holm
#' accumulates a running maximum from the smallest p upward, BH a running
#' minimum from the largest downward, and swapping them silently inverts
#' which hypotheses survive.
#' @param p The p-values.
#' @param method One of \code{"holm"}, \code{"BH"}, \code{"bonferroni"} or \code{"none"}.
#' @return The adjusted p-values, in the order of `p`.
#' @noRd
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
                       x$famsz, x$method, x$alpha)),
    sprintf("  %-22s p %-10.4g adjusted %-10.4g %s", x$results$name,
            x$results$p, x$results$adjusted,
            ifelse(x$results$survives, "survives", "")),
    if (length(x$atflr))
      c(.rmbl_rule(),
        sprintf(paste0("  at the permutation floor (more permutations ",
                       "would be needed to say more): %s"),
                paste(x$atflr, collapse = ", "))),
    .rmbl_rule())
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_falsify_family
print.bricklayer_falsify_family <- .rmbl_print_via_format

#' How strong would an unmeasured confounder have to be
#'
#' @description
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
#' @details
#' For a risk ratio \eqn{RR \ge 1} (after dividing by `true`, and
#' inverting a ratio below 1),
#' \deqn{E = RR + \sqrt{RR (RR - 1)}.}
#' For the interval, the limit nearer the null is used: the lower limit when
#' it is above 1, else the reciprocal of the upper limit when it is below 1;
#' when the interval contains 1 the limit E-value is 1. The formula is for
#' risk ratios; VanderWeele and Ding (2017) give approximate conversions for
#' odds ratios with a common outcome and for hazard ratios, which this
#' function does not apply. Only the first element of each argument is
#' used. Errors: a ratio or limit that is not finite and positive.
#'
#' @param rr Observed risk ratio, greater than 0. Protective
#' effects (below 1) are inverted first, as the measure is symmetric.
#' @param lo,hi Optional confidence limits on the same scale.
#' The limit nearer the null is the one used.
#' @param true Number, default 1 (the null): the value to move the estimate
#' to. A value other than 1 asks how much confounding would move the
#' estimate to `true` instead of to no effect.
#' @return A named numeric vector: `evlpoint` and, when limits are
#' given, `evllimit`.
#' @references VanderWeele, T. J., and Ding, P. (2017). Sensitivity
#' Analysis in Observational Research: Introducing the E-Value.
#' *Annals of Internal Medicine* 167(4), 268-274.
#'   \doi{10.7326/M16-2607}
#' @seealso
#' [cpsfals()] for controls that use
#' the data, where this uses none.
#' @examplesIf interactive() || any(nzchar(Sys.getenv(c("NOT_CRAN", "MY_UNIVERSE", "IN_PKGDOWN"))))
#' # a risk ratio of 2 needs a confounder associated by 3.41 with both
#' evlrr(2)
#'
#' # a protective effect is inverted, so 0.5 gives the same answer
#' evlrr(0.5)
#'
#' # an interval that already includes the null needs nothing
#' evlrr(2, lo = 0.9, hi = 4.4)
#'
#' # and a strong result with a limit well above the null is harder to
#' # explain away
#' evlrr(3, lo = 2.1, hi = 4.3)
#'
#' # how much confounding would bring a risk ratio of 3 down to 1.5
#' evlrr(3, true = 1.5)
#'
#' try(evlrr(-2))
#' @export
evlrr <- function(rr, lo = NULL, hi = NULL, true = 1) {
  one <- function(v) {
    v <- .rmbl_num(v, "v")[1L]
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
  out <- c(evlpoint = point)
  if (!is.null(lo) || !is.null(hi)) {
    l <- if (is.null(lo)) NA_real_ else one(lo) / true
    h <- if (is.null(hi)) NA_real_ else one(hi) / true
    # the limit NEARER the null is what has to be moved
    lim <- if (!is.na(l) && l > 1) l else if (!is.na(h) && h < 1) 1 / h else
      NA_real_
    out <- c(out, evllimit =
               if (is.na(lim)) 1 else lim + sqrt(lim * (lim - 1)))
  }
  out
}
