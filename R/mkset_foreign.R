## ----- Other packages' results, boxed for mkset() -----
## A report reads as one document only when every result in it is laid
## out the same way. These build the box of a result from base R or
## another package -- a model, a test, a table -- from its own accessors
## (coef(summary()), nobs(), AIC()), so nothing is imported; the object's
## own print() is left as its authors wrote it everywhere else.

#' Shows one result of a set: this package's results print themselves;
#' another package's are drawn as a box.
#' @param v A result from another package.
#' @return NULL, invisibly.
#' @noRd
.mkset_show <- function(v) {
  if (.mkset_own(v)) {
    print(v)
  } else {
    .rmbl_cat(.mkset_box(v), NULL)
  }
  invisible(NULL)
}

#' Whether a result is one of this package's (it has a print method here).
#' @param v A result from another package.
#' @return TRUE or FALSE.
#' @noRd
.mkset_own <- function(v) {
  ns <- asNamespace("rmoriebricklayer")
  any(vapply(
    class(v),
    function(cl) exists(paste0("print.", cl), envir = ns, inherits = FALSE),
    NA
  ))
}

#' The box of a result from another package: titled rule, lines, rule.
#' @param v A result from another package.
#' @return Lines.
#' @noRd
.mkset_box <- function(v) {
  out <- tryCatch(
    {
      if (inherits(v, "htest")) {
        .fb_htest(v)
      } else if (inherits(v, "TukeyHSD")) {
        .fb_tukey(v)
      } else if (inherits(v, c("anova", "summary.aov"))) {
        .fb_anova(v)
      } else if (inherits(v, "prcomp")) {
        .fb_prcomp(v)
      } else if (inherits(v, "kmeans")) {
        .fb_kmeans(v)
      } else if (inherits(v, "survfit")) {
        .fb_survfit(v)
      } else if (inherits(v, "multinom")) {
        .fb_multinom(v)
      } else if (inherits(v, "aov")) {
        .fb_anova(summary(v))
      } else if (is.data.frame(v) || is.matrix(v) || is.table(v)) {
        .fb_table(v)
      } else {
        .fb_model(v)
      }
    },
    error = function(e) NULL
  )
  out %||% .fb_text(v)
}

#' Any result as its own printout inside a box.
#' @param v A result from another package.
#' @return Lines.
#' @noRd
.fb_text <- function(v) {
  txt <- utils::capture.output(print(v))
  # from its first line with something on it
  txt <- txt[cumsum(nzchar(trimws(txt))) > 0L]
  more <- length(txt) - 80L
  c(
    .rmbl_rule(class(v)[1L]),
    paste0("  ", utils::head(txt, 80L)),
    if (more > 0L) sprintf("  ... %d more lines", more),
    .rmbl_rule()
  )
}

#' A p-value as text.
#' @param p A p-value.
#' @return One string.
#' @noRd
.fb_p <- function(p) {
  if (!length(p) || is.na(p)) {
    return("not available")
  }
  .rmbl_fmt_p(p)
}

#' A model's coefficients as a table: term, estimate, standard error, p.
#' @param v The model.
#' @return A data frame, or NULL when the model has no such table.
#' @noRd
.fb_coefs <- function(v) {
  # fixest keeps its table as a data frame; `$` is not for S4 (lme4)
  ctab <- if (!isS4(v) && is.list(v)) v$coeftable
  m <- if (is.data.frame(ctab) || is.matrix(ctab)) {
    as.matrix(ctab)
  } else if (inherits(v, "gam")) {
    summary(v)$p.table
  } else if (inherits(v, "survreg")) {
    summary(v)$table
  } else if (inherits(v, c("summary.lm", "summary.glm"))) {
    stats::coef(v)
  } else {
    stats::coef(summary(v))
  }
  if (!is.matrix(m) || ncol(m) < 2L || !nrow(m)) {
    return(NULL)
  }
  cn <- colnames(m)
  se <- grep("^se|std", cn, ignore.case = TRUE)[1L]
  pc <- grep("^pr|^p$|p-value", cn, ignore.case = TRUE)[1L]
  data.frame(
    term = rownames(m),
    est = unname(m[, 1L]),
    se = if (is.na(se)) NA_real_ else unname(m[, se]),
    p = if (is.na(pc)) NA_real_ else unname(m[, pc]),
    stringsAsFactors = FALSE
  )
}

#' What kind of model it is, in words.
#' @param v The model.
#' @return One string.
#' @noRd
.fb_kind <- function(v) {
  fam <- tryCatch(stats::family(v), error = function(e) NULL)
  if (inherits(v, "gam")) {
    return("Generalised additive model (mgcv::gam)")
  }
  if (inherits(v, "svyglm")) {
    return("Survey-weighted generalised linear model (survey::svyglm)")
  }
  if (inherits(v, "negbin")) {
    return("Negative binomial model (MASS::glm.nb)")
  }
  if (inherits(v, "glm") && !is.null(fam)) {
    return(sprintf(
      "Generalised linear model: %s, %s link (glm)",
      fam$family,
      fam$link
    ))
  }
  kinds <- c(
    coxph = "Cox proportional hazards model (survival::coxph)",
    survreg = "Parametric survival model (survival::survreg)",
    merMod = "Mixed model (lme4)",
    lme = "Mixed model (nlme::lme)",
    fixest = "Fixed-effects model (fixest)",
    polr = "Ordinal logistic model (MASS::polr)",
    nls = "Nonlinear least squares (nls)",
    summary.lm = "Linear model (lm), summary",
    summary.glm = "Generalised linear model (glm), summary",
    lm = "Linear model (lm)"
  )
  # inherits() also follows S4 classes (lme4's lmerMod is a merMod)
  hit <- names(kinds)[vapply(names(kinds), function(k) inherits(v, k), NA)]
  if (length(hit)) kinds[[hit[1L]]] else sprintf("Model (%s)", class(v)[1L])
}

#' The scale on which exp(estimate) reads, or NULL.
#' @param v The model.
#' @return A column name ("HR", "OR", "RR") or NULL.
#' @noRd
.fb_ratio <- function(v) {
  if (inherits(v, "coxph")) {
    return("HR")
  }
  fam <- tryCatch(stats::family(v), error = function(e) NULL)
  link <- if (is.list(fam)) fam$link else ""
  switch(link, logit = "OR", log = "RR", NULL)
}

#' The box of a fitted model.
#' @param v The model.
#' @return Lines, or NULL when it has no coefficient table.
#' @noRd
.fb_model <- function(v) {
  ct <- .fb_coefs(v)
  if (is.null(ct)) {
    return(NULL)
  }
  dfr <- tryCatch(stats::df.residual(v), error = function(e) NULL)
  q <- if (is.numeric(dfr) && length(dfr) == 1L && is.finite(dfr) &&
             dfr > 0) {
    stats::qt(0.975, dfr)
  } else {
    stats::qnorm(0.975)
  }
  lo <- ct$est - q * ct$se
  hi <- ct$est + q * ct$se
  tab <- data.frame(
    term = ct$term,
    estimate = signif(ct$est, 4),
    `95% CI` = .fb_ci(lo, hi),
    p = vapply(ct$p, .fb_p, ""),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  rt <- .fb_ratio(v)
  if (!is.null(rt)) {
    tab[[rt]] <- signif(exp(ct$est), 4)
    tab[[paste(rt, "95% CI")]] <- .fb_ci(exp(lo), exp(hi))
  }
  .an_block(
    .fb_kind(v),
    facts = .fb_model_facts(v),
    tables = list(tab),
    reading = .fb_model_reading(ct, lo, hi, rt)
  )
}

#' Intervals as text.
#' @param lo,hi The interval's lower and upper bounds.
#' @return A character vector.
#' @noRd
.fb_ci <- function(lo, hi) {
  ifelse(
    is.finite(lo) & is.finite(hi),
    sprintf("[%s, %s]", signif(lo, 3), signif(hi, 3)),
    ""
  )
}

#' The facts above a model's table: formula, observations, fit.
#' @param v The model.
#' @return A named list.
#' @noRd
.fb_model_facts <- function(v) {
  f <- tryCatch(
    deparse1(stats::formula(v), collapse = " ", width.cutoff = 500L),
    error = function(e) NULL
  )
  n <- tryCatch(stats::nobs(v), error = function(e) NULL)
  aic <- tryCatch(stats::AIC(v), error = function(e) NULL)
  s <- if (inherits(v, c("lm", "summary.lm")) && !inherits(v, "glm")) {
    tryCatch(if (inherits(v, "summary.lm")) v else summary(v),
             error = function(e) NULL)
  }
  out <- list(Formula = f, Observations = n)
  if (inherits(v, "coxph")) out$Events <- v[["nevent"]]
  if (is.list(s) && is.numeric(s$r.squared)) {
    out$`R squared` <- sprintf(
      "%.3f (adjusted %.3f)",
      s$r.squared,
      s$adj.r.squared
    )
  }
  if (is.numeric(aic) && length(aic) == 1L && is.finite(aic)) {
    out$AIC <- format(round(aic, 1), nsmall = 1)
  }
  out[!vapply(out, is.null, NA)]
}

#' The reading under a model's table: which terms differ from zero.
#' @param ct The coefficient table.
#' @param lo,hi The interval bounds.
#' @param rt The ratio scale, or NULL.
#' @return Sentences.
#' @noRd
.fb_model_reading <- function(ct, lo, hi, rt) {
  keep <- ct$term != "(Intercept)"
  havep <- any(is.finite(ct$p[keep]))
  sig <- if (havep) {
    keep & is.finite(ct$p) & ct$p < 0.05
  } else {
    keep & is.finite(lo) & (lo > 0 | hi < 0)
  }
  how <- if (havep) "at the 5% level" else "by its 95% interval"
  if (!any(sig)) {
    return(sprintf(
      "No term differs from zero %s (of %d).",
      how,
      sum(keep)
    ))
  }
  terms <- sprintf(
    "%s (%s)",
    ct$term[sig],
    ifelse(ct$est[sig] > 0, "up", "down")
  )
  c(
    sprintf(
      "%d of %d terms differ from zero %s: %s.",
      sum(sig),
      sum(keep),
      how,
      toString(utils::head(terms, 6L))
    ),
    if (!havep) "The model reports no p-values; the intervals are Wald.",
    if (!is.null(rt)) {
      sprintf("%s is exp(estimate): a ratio, 1 for no effect.", rt)
    }
  )
}

#' The box of a statistical test (stats::t.test(), chisq.test(), ...).
#' @param v The test.
#' @return Lines.
#' @noRd
.fb_htest <- function(v) {
  facts <- list(Data = v$data.name)
  if (length(v$statistic)) {
    facts[[names(v$statistic) %||% "Statistic"]] <- signif(v$statistic, 4)
  }
  if (length(v$parameter)) {
    facts[[toString(names(v$parameter))]] <-
      toString(signif(v$parameter, 4))
  }
  facts$p <- .fb_p(v$p.value)
  if (length(v$estimate)) {
    facts$Estimate <- paste(
      paste(names(v$estimate) %||% "", signif(v$estimate, 4)),
      collapse = "; "
    )
  }
  if (length(v$conf.int)) {
    facts[[sprintf("%g%% CI", 100 * attr(v$conf.int, "conf.level"))]] <-
      .fb_ci(v$conf.int[1L], v$conf.int[2L])
  }
  rej <- is.finite(v$p.value) && v$p.value < 0.05
  .an_block(
    trimws(v$method),
    facts = facts,
    reading = sprintf(
      "%s at the 5%% level (alternative: %s).",
      if (rej) {
        "The data are not consistent with the null hypothesis"
      } else {
        "The data do not reject the null hypothesis"
      },
      v$alternative %||% "not stated"
    )
  )
}

#' The box of an analysis-of-variance table.
#' @param v An anova table or summary(aov).
#' @return Lines.
#' @noRd
.fb_anova <- function(v) {
  a <- if (inherits(v, "summary.aov")) v[[1L]] else v
  d <- as.data.frame(a)
  pc <- grep("^Pr", names(d))[1L]
  tab <- cbind(term = trimws(rownames(d)), signif(d, 4))
  rownames(tab) <- NULL
  sig <- if (is.na(pc)) logical() else which(d[[pc]] < 0.05)
  .an_block(
    "Analysis of variance",
    facts = list(Terms = sum(trimws(rownames(d)) != "Residuals")),
    tables = list(tab),
    reading = if (length(sig)) {
      sprintf(
        "Terms that matter at the 5%% level: %s.",
        toString(trimws(rownames(d))[sig])
      )
    } else {
      "No term matters at the 5% level."
    }
  )
}

#' The box of Tukey's honest significant differences.
#' @param v From stats::TukeyHSD().
#' @return Lines.
#' @noRd
.fb_tukey <- function(v) {
  tabs <- lapply(names(v), function(nm) {
    m <- v[[nm]]
    data.frame(
      comparison = rownames(m),
      difference = signif(m[, "diff"], 4),
      `95% CI` = .fb_ci(m[, "lwr"], m[, "upr"]),
      p = vapply(m[, "p adj"], .fb_p, ""),
      check.names = FALSE,
      stringsAsFactors = FALSE
    )
  })
  all <- do.call(rbind, tabs)
  nsig <- sum(vapply(names(v), function(nm) {
    sum(v[[nm]][, "p adj"] < 0.05)
  }, 0))
  .an_block(
    "Tukey honest significant differences",
    facts = list(Comparisons = nrow(all)),
    tables = list(all),
    reading = sprintf(
      "%d of %d comparisons differ at the 5%% level, adjusted for all of them.",
      nsig,
      nrow(all)
    )
  )
}

#' The box of a principal component analysis.
#' @param v From stats::prcomp().
#' @return Lines.
#' @noRd
.fb_prcomp <- function(v) {
  imp <- summary(v)$importance
  k <- min(ncol(imp), 6L)
  tab <- data.frame(
    component = colnames(imp)[seq_len(k)],
    sd = signif(imp[1L, seq_len(k)], 4),
    `share %` = round(100 * imp[2L, seq_len(k)], 1),
    `cumulative %` = round(100 * imp[3L, seq_len(k)], 1),
    check.names = FALSE
  )
  .an_block(
    "Principal components",
    facts = list(Variables = nrow(v$rotation), Components = ncol(imp)),
    tables = list(tab),
    reading = sprintf(
      "The first two components hold %.1f%% of the variance.",
      100 * imp[3L, min(2L, ncol(imp))]
    )
  )
}

#' The box of a k-means clustering.
#' @param v From stats::kmeans().
#' @return Lines.
#' @noRd
.fb_kmeans <- function(v) {
  ctr <- as.data.frame(signif(v$centers, 4))
  tab <- cbind(cluster = seq_len(nrow(ctr)), size = v$size, ctr)
  .an_block(
    "k-means clustering",
    facts = list(
      Clusters = length(v$size),
      Points = sum(v$size),
      `Between / total` = sprintf("%.1f%%", 100 * v$betweenss / v$totss)
    ),
    tables = list(tab),
    reading = sprintf(
      "The clusters account for %.1f%% of the total sum of squares.",
      100 * v$betweenss / v$totss
    )
  )
}

#' The box of survival curves.
#' @param v From survival::survfit().
#' @return Lines.
#' @noRd
.fb_survfit <- function(v) {
  t <- summary(v)$table
  if (!is.matrix(t)) {
    t <- matrix(t, nrow = 1L, dimnames = list("all", names(t)))
  }
  pick <- function(nm) if (nm %in% colnames(t)) t[, nm] else NA
  tab <- data.frame(
    group = rownames(t),
    n = pick("records"),
    events = pick("events"),
    median = signif(pick("median"), 4),
    `95% CI` = .fb_ci(pick("0.95LCL"), pick("0.95UCL")),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  .an_block(
    "Survival curves (survival::survfit)",
    facts = list(Groups = nrow(t), Events = sum(tab$events, na.rm = TRUE)),
    tables = list(tab),
    reading = if (anyNA(tab$median)) {
      "A median is missing where fewer than half had the event."
    } else {
      "The median is the time by which half had the event."
    }
  )
}

#' The box of a multinomial logit (nnet::multinom()).
#' @param v The model.
#' @return Lines.
#' @noRd
.fb_multinom <- function(v) {
  s <- summary(v)
  b <- as.matrix(s$coefficients)
  se <- as.matrix(s$standard.errors)
  z <- b / se
  ct <- data.frame(
    term = as.vector(outer(rownames(b), colnames(b), paste, sep = ": ")),
    est = as.vector(b),
    se = as.vector(se),
    p = as.vector(2 * stats::pnorm(-abs(z))),
    stringsAsFactors = FALSE
  )
  lo <- ct$est - stats::qnorm(0.975) * ct$se
  hi <- ct$est + stats::qnorm(0.975) * ct$se
  keep <- !grepl("(Intercept)", ct$term, fixed = TRUE)
  tab <- data.frame(
    term = ct$term,
    estimate = signif(ct$est, 4),
    `95% CI` = .fb_ci(lo, hi),
    p = vapply(ct$p, .fb_p, ""),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  .an_block(
    "Multinomial logit (nnet::multinom)",
    facts = list(Outcomes = nrow(b) + 1L, AIC = round(v$AIC, 1)),
    tables = list(tab),
    reading = c(
      .fb_model_reading(ct[keep, ], lo[keep], hi[keep], NULL),
      "Each estimate compares an outcome with the first."
    )
  )
}

#' The box of a table, matrix or data frame.
#' @param v The table.
#' @return Lines.
#' @noRd
.fb_table <- function(v) {
  d <- if (is.data.frame(v)) {
    v
  } else if (length(dim(v)) == 2L) {
    m <- as.data.frame.matrix(v)
    cbind(` ` = rownames(m), m, stringsAsFactors = FALSE)
  } else {
    as.data.frame(v)
  }
  rownames(d) <- NULL
  more <- nrow(d) - 30L
  .an_block(
    if (is.data.frame(v)) "Data frame" else "Table",
    facts = list(Rows = nrow(d), Columns = ncol(d)),
    tables = list(utils::head(d, 30L)),
    notes = if (more > 0L) sprintf("... and %d more rows.", more)
  )
}
