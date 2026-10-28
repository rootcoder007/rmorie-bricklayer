# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Evidence that an analysis is right, not only that it re-runs. A capsule
# proves the numbers came from these bytes; these checks add that the
# statistic recovers an effect whose size is known, and that reasonable
# alternative analyses tell the same story.

#' Does the Analysis Recover a Known Effect?
#'
#' Plants effects of known size into the real data and checks that the
#' statistic gets them back. Each planted data set keeps every column as
#' it is, except the outcome: it is shuffled, which removes whatever real
#' association it had with the treatment, and then the planted effect is
#' added, `effect * treatment`. A statistic that estimates the treatment's
#' effect on the outcome should return about `effect` on every one.
#'
#' This is evidence about the statistic as it is applied to this data
#' (its missing values, its skew, its group sizes), which a simulation on
#' made-up data cannot give. A statistic that recovers 0, 0.5 and 1
#' correctly is very unlikely to be computing the wrong thing.
#'
#' @details
#' The treatment column must be numeric, logical or a factor with two
#' levels (the second is coded 1). Effects are on the outcome's own scale
#' per unit of treatment, so the statistic must estimate an additive
#' effect: a difference in means, a regression slope, an average treatment
#' effect. An effect is recovered when the average estimate is within
#' `tol` of it, after allowing three Monte Carlo standard errors, and that
#' standard error is itself no larger than `tol`: a statistic too noisy for
#' the check to mean anything is not recovered (raise `n`). Without the
#' second condition the allowance grew with the noise, and a statistic that
#' returned pure noise passed.
#'
#' @param data A data frame with at least 4 rows.
#' @param stat A function of one data frame returning one number: the
#'   estimated effect of `trt` on `y`.
#' @param y The outcome column's name. It must be numeric.
#' @param trt The treatment column's name.
#' @param effects The effects to plant. Include 0, so a statistic that
#'   finds an effect where there is none fails.
#' @param n Planted data sets per effect.
#' @param tol How far an average estimate may sit from the planted effect.
#'   The default is 10% of the largest planted effect.
#' @param seed Optional seed, for a reproducible check. The session's own
#'   random stream is left as it was.
#' @return A list of class `rmbl_plant`: `ok` (every effect recovered),
#'   `table` (one row per effect: `effect`, `recovered` (the average
#'   estimate), `bias`, `se`, `passed`), `observed` (the statistic
#'   on the real data), `n`, `tol`, `y`, `trt` and `seed`.
#'   It prints as a box and
#'   goes into a manifest with [recevid()].
#' @seealso
#' [cpsspec()] for agreement across specifications,
#' [cpsfals()]
#'   for falsification controls, [recevid()] to record them all.
#' @export
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' set.seed(1)
#' d <- data.frame(x = rbinom(200, 1, 0.5), z = rnorm(200))
#' d$y <- 2 * d$x + d$z + rnorm(200)
#'
#' # A difference in means recovers what is planted.
#' dm <- function(df) mean(df$y[df$x == 1]) - mean(df$y[df$x == 0])
#' cpsplant(d, dm, y = "y", trt = "x", n = 30, seed = 1)
#'
#' # A statistic with a bug (it doubles the effect) does not.
#' bad <- function(df) 2 * dm(df)
#' cpsplant(d, bad, y = "y", trt = "x", n = 30, seed = 1)$ok
cpsplant <- function(data, stat, y, trt, effects = c(0, 0.5, 1),
                     n = 50L, tol = NULL, seed = NULL) {
  a <- .rmbl_plant_args(data, stat, y, trt, effects, n, tol)
  if (!is.null(seed)) {
    seed <- .rmbl_r_seed(seed)
    .rmbl_local_seed(seed)
  }
  observed <- .rmbl_falsify_eval(stat, data, "the data as given")
  x <- a$x
  pg <- blprog("planted effects", length(a$effects) * a$n)
  on.exit(pg$done(), add = TRUE)
  rows <- lapply(seq_along(a$effects), function(j) {
    e <- a$effects[[j]]
    est <- vapply(seq_len(a$n), function(i) {
      pg$update((j - 1L) * a$n + i, sprintf("effect %g", e))
      d <- data
      d[[a$y]] <- sample(d[[a$y]]) + e * x
      .rmbl_falsify_eval(stat, d, sprintf("a data set planted with %g", e))
    }, numeric(1))
    se <- stats::sd(est) / sqrt(length(est))
    rec <- mean(est)
    data.frame(
      effect = e, recovered = rec, bias = rec - e, se = se,
      passed = abs(rec - e) <= a$tol + 3 * se && se <= a$tol
    )
  })
  tab <- do.call(rbind, rows)
  out <- list(
    ok = all(tab$passed), table = tab, observed = observed, n = a$n,
    tol = a$tol, y = a$y, trt = a$trt,
    seed = if (is.null(seed)) NA_integer_ else seed
  )
  class(out) <- c("rmbl_plant", "list")
  out
}

#' @export
format.rmbl_plant <- function(x, ...) {
  t <- x$table
  .rmbl_stat_block(
    paste("Planted-effect recovery:", if (x$ok) "passed" else "FAILED"),
    facts = list(
      Outcome = x$y,
      Treatment = x$trt,
      `Data sets per effect` = x$n,
      Tolerance = x$tol,
      `Estimate on the real data` = x$observed,
      Seed = if (!is.na(x$seed)) format(x$seed, scientific = FALSE)
    ),
    table = data.frame(
      planted = t$effect, recovered = t$recovered, bias = t$bias,
      se = t$se,
      result = ifelse(t$passed, "ok", ifelse(
        t$se > x$tol, "too noisy", "FAIL"
      ))
    ),
    reading = if (x$ok) {
      paste(
        "The statistic recovered every planted effect on this data, so it",
        "measures the treatment's effect on the outcome as intended."
      )
    } else {
      paste(
        "The statistic missed at least one planted effect: it does not",
        "measure what it is meant to on this data. Check it before",
        "reporting its estimate."
      )
    },
    notes = c(
      paste(
        "Each planted data set shuffles the outcome, removing its real",
        "association, then adds effect x treatment."
      ),
      if (any(t$se > x$tol)) {
        paste(
          "Too noisy: the standard error exceeds the tolerance, so the",
          "check cannot tell the effect from noise. Raise n."
        )
      }
    )
  )
}

#' Do Reasonable Alternative Analyses Agree?
#'
#' Runs several specifications of the same estimate (other covariates,
#' another model, another handling of outliers or missing values) and
#' reports how far they spread and whether they agree in sign. A finding
#' that holds under one specification only is fragile; one that survives
#' the reasonable alternatives is robust.
#'
#' @param data A data frame.
#' @param specs A named list of functions, each taking the data frame and
#'   returning one number: the estimate under that specification. The
#'   first is the one the paper reports.
#' @return A list of class `rmbl_spec`: `ok` (every estimate has the sign
#'   of the reported one), `table` (`spec`, `estimate`, `same_sign`),
#'   `reported`, `range` and `share` (the share agreeing in sign). It
#'   prints as a box and goes into a manifest with [recevid()].
#' @seealso
#' [cpsplant()],
#' [recevid()].
#' @export
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' set.seed(2)
#' d <- data.frame(x = rnorm(300), z = rnorm(300))
#' d$y <- 0.5 * d$x + 0.3 * d$z + rnorm(300)
#' cpsspec(d, list(
#'   adjusted = function(df) coef(lm(y ~ x + z, df))[["x"]],
#'   simple = function(df) coef(lm(y ~ x, df))[["x"]],
#'   trimmed = function(df) {
#'     keep <- abs(df$y - mean(df$y)) < 3 * sd(df$y)
#'     coef(lm(y ~ x + z, df[keep, ]))[["x"]]
#'   }
#' ))
cpsspec <- function(data, specs) {
  nm <- .rmbl_spec_args(data, specs)
  est <- vapply(nm, function(k) {
    .rmbl_falsify_eval(specs[[k]], data, sprintf("specification '%s'", k))
  }, numeric(1), USE.NAMES = FALSE)
  same <- sign(est) == sign(est[1L]) & est != 0
  out <- list(
    ok = all(same), reported = est[1L], range = range(est),
    share = mean(same),
    table = data.frame(spec = nm, estimate = est, same_sign = same,
                       stringsAsFactors = FALSE)
  )
  class(out) <- c("rmbl_spec", "list")
  out
}

#' @export
format.rmbl_spec <- function(x, ...) {
  t <- x$table
  .rmbl_stat_block(
    paste("Specification check:", if (x$ok) "robust" else "FRAGILE"),
    facts = list(
      Specifications = nrow(t),
      Reported = sprintf("%.6g (%s)", x$reported, t$spec[1L]),
      Range = sprintf("%.6g to %.6g", x$range[1L], x$range[2L]),
      `Same sign as reported` = sprintf("%d of %d", sum(t$same_sign),
                                        nrow(t))
    ),
    table = data.frame(
      specification = t$spec, estimate = t$estimate,
      sign = ifelse(t$same_sign, "same", "DIFFERENT")
    ),
    reading = if (x$ok) {
      paste(
        "Every specification agrees in sign with the reported one, so the",
        "finding does not hang on one analytic choice."
      )
    } else {
      paste(
        "At least one reasonable specification points the other way: the",
        "finding depends on the analytic choices and should be reported",
        "with them."
      )
    }
  )
}

#' Record Correctness Evidence in a Manifest
#'
#' Adds the outcome of a correctness check to a manifest, so the capsule
#' carries not only the reported numbers but the checks they passed. Each
#' planted effect from
#' [cpsplant()]
#' becomes a record (recovered against planted, within the tolerance); a
#' [cpsspec()]
#' check records the share of specifications agreeing in sign (which
#' should be 1); a
#' [cpsfals()]
#' result records each control that ran (1 for passed).
#'
#' @param man A manifest from [mkmnf()].
#' @param x A result of
#'   [cpsplant()],
#'   [cpsspec()] or
#'   [cpsfals()].
#' @param grp The records' group.
#' @return The manifest, with the new records.
#' @seealso
#' [recrd()],
#' [cpsbndl()].
#' @export
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' set.seed(1)
#' d <- data.frame(x = rbinom(100, 1, 0.5))
#' d$y <- d$x + rnorm(100)
#' dm <- function(df) mean(df$y[df$x == 1]) - mean(df$y[df$x == 0])
#' man <- mkmnf(list(project = "demo"), env = FALSE)
#' man <- recevid(man, cpsplant(d, dm, "y", "x", n = 20, seed = 1))
#' man
recevid <- function(man, x, grp = "evidence") {
  grp <- .rmbl_string1(grp, "grp")
  if (inherits(x, "rmbl_plant")) {
    t <- x$table
    for (i in seq_len(nrow(t))) {
      man <- recrd(man, sprintf("planted effect %g recovered", t$effect[i]),
                   t$recovered[i], t$effect[i],
                   tol = x$tol + 3 * min(t$se[i], x$tol),
                   grp = grp)
    }
    return(man)
  }
  if (inherits(x, "rmbl_spec")) {
    return(recrd(man, "specifications agreeing in sign (share)", x$share,
                 1, tol = 0, grp = grp))
  }
  if (inherits(x, "bricklayer_falsification")) {
    ct <- x$controls[!is.na(x$controls$passed), , drop = FALSE]
    for (i in seq_len(nrow(ct))) {
      man <- recrd(man, sprintf("falsification control %s passed",
                                ct$control[i]),
                   as.numeric(ct$passed[i]), 1, tol = 0, grp = grp)
    }
    return(man)
  }
  stop("`x` must come from cpsplant(), cpsspec() or cpsfals()",
       call. = FALSE)
}

#' Checks cpsplant()'s arguments and codes the treatment as numbers.
#' @param data,stat,y,trt,effects,n,tol As for cpsplant().
#' @return A list: `y`, `trt`, `x` (the coded treatment), `effects`, `n`,
#'   `tol`.
#' @noRd
.rmbl_plant_args <- function(data, stat, y, trt, effects, n, tol) {
  if (!is.data.frame(data) || nrow(data) < 4L) {
    stop("`data` must be a data frame with at least 4 rows", call. = FALSE)
  }
  if (!is.function(stat)) {
    stop("`stat` must be a function of one data frame", call. = FALSE)
  }
  y <- .rmbl_string1(y, "y")
  trt <- .rmbl_string1(trt, "trt")
  for (v in c(y, trt)) {
    if (!v %in% names(data)) {
      stop("`", v, "` is not a column of `data`", call. = FALSE)
    }
  }
  if (!is.numeric(data[[y]])) {
    stop("the outcome `", y, "` must be numeric", call. = FALSE)
  }
  effects <- .rmbl_num(effects, "effects")
  if (!length(effects) || anyNA(effects) || !all(is.finite(effects))) {
    stop("`effects` must be finite numbers", call. = FALSE)
  }
  n <- .rmbl_num(n, "n", integer = TRUE)[1L]
  if (is.na(n) || n < 5L) {
    stop("`n` must be at least 5", call. = FALSE)
  }
  if (is.null(tol)) {
    tol <- 0.1 * max(abs(effects))
  }
  tol <- .rmbl_num(tol, "tol")[1L]
  if (is.na(tol) || tol < 0) {
    stop("`tol` must be a number of at least 0", call. = FALSE)
  }
  list(y = y, trt = trt, x = .rmbl_plant_code(data[[trt]], trt),
       effects = effects, n = n, tol = tol)
}

#' A treatment column as 0/1 or numbers.
#' @param v The column.
#' @param nm Its name, for the message.
#' @return A numeric vector.
#' @noRd
.rmbl_plant_code <- function(v, nm) {
  if (is.logical(v)) {
    return(as.numeric(v))
  }
  if (is.factor(v) || is.character(v)) {
    lv <- if (is.factor(v)) levels(droplevels(v)) else sort(unique(v))
    if (length(lv) != 2L) {
      stop("the treatment `", nm, "` must have two levels to code it 0/1",
           call. = FALSE)
    }
    return(as.numeric(as.character(v) == lv[2L]))
  }
  if (!is.numeric(v)) {
    stop("the treatment `", nm, "` must be numeric, logical or two levels",
         call. = FALSE)
  }
  as.numeric(v)
}

#' Checks cpsspec()'s arguments.
#' @param data,specs As for cpsspec().
#' @return The specifications' names.
#' @noRd
.rmbl_spec_args <- function(data, specs) {
  if (!is.data.frame(data) || !nrow(data)) {
    stop("`data` must be a data frame with rows", call. = FALSE)
  }
  bad <- paste("`specs` must be a list of two or more named functions,",
               "each with its own name")
  if (!is.list(specs) || length(specs) < 2L) {
    stop(bad, call. = FALSE)
  }
  nm <- names(specs)
  if (is.null(nm) || anyNA(nm) || !all(nzchar(nm)) || anyDuplicated(nm)) {
    stop(bad, call. = FALSE)
  }
  if (!all(vapply(specs, is.function, NA))) {
    stop(bad, call. = FALSE)
  }
  nm
}
