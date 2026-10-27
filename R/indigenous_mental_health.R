# SPDX-License-Identifier: AGPL-3.0-or-later
#
# First Nations, Metis and Inuit mental health and wellbeing from Statistics
# Canada's published tables: the estimates and their limits taken out of a
# table's statistics column, rated scales (perceived mental health, life
# satisfaction) compared as whole distributions, survey percentages standardised
# by age, and a plot for every result.

#' The estimates of a Statistics Canada table, with their confidence limits
#'
#' Statistics Canada's tables give each estimate on several rows: the estimate
#' itself (a percent, a rate, a count, a life expectancy), its low and high
#' confidence limits, or its coefficient of variation or standard error, all in
#' one statistics column (\code{Statistics}, \code{Characteristics},
#' \code{Statistics (3)}, ...). This puts them side by side, one row per cell of
#' the table and measure, ready for \code{\link{indgap}}, \code{\link{ordcmp}},
#' \code{\link{stdprev}} and the rest. Every table reads: one without a
#' statistics column (a census count) gives each value as its own estimate, with
#' no limits.
#'
#' @details Each label of the statistics column is read as an estimate or as one
#' of its measures of precision, in every form the tables use: \itemize{ \item
#' \code{"Low 95\% confidence interval"}; \item \code{"High 95\% confidence
#' interval, age-standardized rate"}; \item \code{"Confidence interval lower
#' bound of count"}; \item \code{"95\% confidence interval (upper limit)"};
#' \item \code{"95\% confidence interval lower bound, 2020"}; \item
#' \code{"Coefficient of variation for percent"}; \item \code{"Standard error"}.
#' } A limit that names its measure is matched to it (ignoring case and
#' spacing); one that names none, or a name that fits several measures
#' (\code{"potential years of life lost"} in a table with a number, a crude rate
#' and an age-standardised rate of them), is matched to the measure with the
#' same unit (\code{UOM}) whose estimates it contains in every cell, and left
#' unmatched (said in the attribute \code{unmatched}) if no single measure fits.
#' A coefficient of variation \eqn{c} (in percent) gives log-normal limits
#' \eqn{e \exp(\mp z \sqrt{\log(1 + (c/100)^2)})}, which stay positive however
#' large \eqn{c} is; a standard error \eqn{s} the limits \eqn{e \mp z s}; the
#' column \code{cisou} says which (\code{"published"}, \code{"cv"} or
#' \code{"se"}). Published limits that do not contain their own estimate (it
#' happens: a 100% with limits 85.5 to 98.6 in table 41-10-0012) are kept as
#' published and marked \code{"inconsistent"}; every comparison of the family
#' warns and leaves such a row out. A limit is matched to a measure when it fits
#' 95% of the cells. Labels are read in English: use the English-language
#' tables.
#'
#' Every other column but the metadata (\code{VECTOR}, \code{COORDINATE},
#' \code{UOM}, ...) identifies the cell, \code{DGUID} among them (one place name
#' can name several geographies), with the spaces some labels end in trimmed.
#' The quality flag is the estimate's: an \code{F} or \code{x} estimate is
#' \code{NA} (see \code{\link{sctidy}}), and so are its limits.
#'
#' @param x A table read by \code{\link{sctidy}}, a data frame as downloaded, or
#'   a table key.
#' @return A data frame, one row per cell and measure: the identifying columns,
#'   \code{measure}, \code{estimate}, \code{lower}, \code{upper}, \code{cisou}
#'   and \code{quality}; the attribute \code{conflvl} is the level of the
#'   limits, and \code{unmatched} names any limits that could not be matched to
#'   one measure.
#' @references Statistics Canada (2023). Self-perceived mental health of First
#'   Nations people living off reserve, Metis and Inuit by age group and gender.
#'   Table 41-10-0067-01. \doi{10.25318/4110006701-eng}
#' @seealso \code{\link{sctidy}}, \code{\link{indgap}},
#'   \code{\link{ordcmp}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # the layout of a downloaded table: percent and number of persons, with
#' # limits for the percent
#' d <- data.frame(
#'   REF_DATE = "2022",
#'   GEO = "Canada",
#'   `Indigenous identity` = rep(c("First Nations", "Metis"), each = 4),
#'   Statistics = rep(
#'     c(
#'       "Number of persons",
#'       "Percent",
#'       "Low 95% confidence interval",
#'       "High 95% confidence interval"
#'     ),
#'     2
#'   ),
#'   UOM = rep(c("Persons", "Percent", "Percent", "Percent"), 2),
#'   VALUE = c(415000, 47.1, 45.2, 49.0, 320000, 50.3, 48.1, 52.5),
#'   STATUS = "",
#'   check.names = FALSE
#' )
#' scests(d)
#' # a rate with its coefficient of variation instead of limits
#' r <- data.frame(
#'   GEO = "Canada",
#'   Characteristics = c("Rate", "Coefficient of variation for rate"),
#'   VALUE = c(12.5, 8),
#'   STATUS = ""
#' )
#' scests(r)
#' @export
scests <- function(x) {
  if (!inherits(x, "rmbl_statcan")) {
    x <- sctidy(x)
  }
  cols <- setdiff(names(x), .rmbl_statcan_meta)
  uom <- if ("UOM" %in% names(x)) {
    trimws(as.character(x$UOM))
  } else {
    rep("", nrow(x))
  }
  is_stat <- .sce_stat_cols(x, cols)
  x <- .sce_trim(x, cols)
  if (!any(is_stat)) {
    return(.sce_plain(x, cols, uom))
  }
  sc <- cols[is_stat]
  lab <- gsub("\\s+", " ", .rmbl_utf8(trimws(as.character(x[[sc]]))))
  low <- tolower(lab)
  rt <- .sce_roles(low)
  conf <- .sce_conf(low)
  dims <- setdiff(cols, sc)
  key <- do.call(paste, c(lapply(x[dims], as.character), sep = "\r"))
  e <- which(rt$role == "estimate")
  if (anyDuplicated(paste(key[e], lab[e], sep = "\r"))) {
    stop(
      .rmbl_fn(),
      "`x` has two estimates for one cell and measure of the table",
      call. = FALSE
    )
  }
  m <- list(
    lab = lab,
    role = rt$role,
    target = rt$target,
    ests = unique(lab[rt$role == "estimate"]),
    uom = uom,
    value = x$VALUE,
    key = key,
    e = e,
    ekey = paste(key[e], lab[e], sep = "\r")
  )
  bd <- .sce_bounds(lab, rt, m)
  .sce_out(x, e, dims, lab, bd, m, conf)
}

#' Compare rated scales (perceived mental health, life satisfaction) between
#' groups
#'
#' For a rated scale published as the percentage in each category with its
#' confidence limits (perceived mental health from poor to excellent, life
#' satisfaction from 0 to 10, agreement with a statement), the probability that
#' a person in each group rates higher than a person in the reference group,
#' with its confidence interval: a comparison of the whole distribution, not of
#' one category cut from it.
#'
#' @details With shares \eqn{p_i} in the group and \eqn{q_j} in the reference
#' over categories ordered from lowest to highest, the probability of a higher
#' rating, ties counted half, is \eqn{A = \sum_i p_i (Q_{i-1} + q_i / 2)} with
#' \eqn{Q_i} the reference's cumulative shares and \eqn{Q_0 = 0}: the
#' Mann-Whitney probability, equal to \eqn{\alpha / (1 + \alpha)} for Agresti's
#' (1980) generalized odds ratio \eqn{\alpha} with ties split equally, and to
#' the mean ridit of the group with the reference as the standard (Bross 1958).
#' 0.5 is no difference; \eqn{2A - 1} is Cliff's \eqn{\delta}, the share rating
#' higher less the share rating lower.
#'
#' Its variance is that of the two-sample U statistic, \eqn{\sigma_1^2 / n_1 +
#' \sigma_0^2 / n_0}, with \eqn{\sigma_1^2} the variance over the group of each
#' category's placement in the reference and \eqn{\sigma_0^2} the converse
#' (Brunner and Munzel 2000). The sample sizes are the effective ones the
#' published limits imply: for each category, \eqn{n = p(1 - p) / s^2} with
#' \eqn{s} the standard error from the limits' width, taking the median over the
#' categories. That carries the design effect of the survey's weights and
#' clusters, which the counts of persons (population totals) do not. The
#' interval is built on the logit scale, so it stays inside 0 and 1.
#'
#' The categories given in \code{lvls} are taken as the whole scale: rows for
#' totals, for combined categories (\dQuote{Excellent or very good}) and for
#' \dQuote{not specified} are left out, and the shares are rescaled to sum to
#' one over the levels. A group with a suppressed or missing category is not
#' compared, since its distribution is unknown; one with an \code{E} category
#' (in the group or the reference) is compared and marked, and one whose
#' published interval misses its own estimate is not compared.
#'
#' A higher rating means better only on a scale that runs that way. Give
#' \code{lvls} from the least to the most favourable so that \code{probbet}
#' reads as its name says.
#'
#' @param data A data frame, one row per group and category (as
#'   \code{\link{scests}} gives, filtered to one geography, age group and
#'   gender).
#' @param grp,cat,est,lower,upper Column names: the group, the category, the
#'   share in it (percent or proportion: only relative shares matter) and its
#'   published limits on the same scale.
#' @param lvls The categories, from the lowest (least favourable) to the
#'   highest.
#' @param ref The label of the reference group (required: any group of
#'   \code{data}).
#' @param qual Optional column of quality flags (see \code{\link{qltyrcd}}).
#' @param conflvl Confidence level of the published limits and of the result
#'   (default 0.95).
#' @return A data frame of class \code{rmbl_ordinal_compare}: \code{group},
#'   \code{reference}, \code{probbet}, \code{lower}, \code{upper}, \code{delta},
#'   \code{neff}, \code{neffref}, \code{usewithcau}, \code{poogrp}; the
#'   attribute \code{shares} is the matrix of shares (groups by levels), which
#'   \code{plot()} draws.
#' @references Agresti A (1980). Generalized odds ratios for ordinal data.
#' Biometrics 36(1):59-67. \doi{10.2307/2530495}
#'
#' Bross IDJ (1958). How to use ridit analysis. Biometrics 14(1):18-38.
#' \doi{10.2307/2527727}
#'
#' Brunner E, Munzel U (2000). The nonparametric Behrens-Fisher problem:
#' asymptotic theory and a small-sample approximation. Biometrical Journal
#' 42(1):17-25.
#' \doi{10.1002/(SICI)1521-4036(200001)42:1<17::AID-BIMJ17>3.0.CO;2-U}
#' @param pooled Optional labels of rows that pool other groups (see
#'   \code{\link{indgap}}).
#' @seealso \code{\link{scests}}, \code{\link{indgap}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # Self-perceived mental health, 15 years and older, Canada, 2022 (table
#' # 41-10-0067-01)
#' mh <- indiex("mentalhealth")
#' mh <- mh[mh$region == "Canada", ]
#' oc <- ordcmp(
#'   mh,
#'   "group",
#'   "rating",
#'   "estimate",
#'   "lower",
#'   "upper",
#'   lvls = c("Fair or poor", "Good", "Very good", "Excellent"),
#'   ref = "M\u00e9tis",
#'   qual = "quality"
#' )
#' oc
#' plot(oc)
#'
#' # your own table: a made-up four-level rating for two groups, with limits
#' own <- data.frame(
#'   group = rep(c("Nation A", "Everyone else"), each = 4),
#'   rating = rep(c("Poor", "Fair", "Good", "Excellent"), 2),
#'   pct = c(10, 25, 40, 25, 6, 20, 44, 30),
#'   lo = c(7, 21, 35, 21, 5, 18, 42, 28),
#'   hi = c(13, 29, 45, 29, 7, 22, 46, 32)
#' )
#' ordcmp(own, "group", "rating", "pct", "lo", "hi",
#'        lvls = c("Poor", "Fair", "Good", "Excellent"), ref = "Everyone else")
#' @export
ordcmp <- function(
  data,
  grp,
  cat,
  est,
  lower,
  upper,
  lvls,
  ref,
  qual = NULL,
  conflvl = 0.95,
  pooled = NULL
) {
  qual <- .oc_check_args(
    data,
    list(grp = grp, cat = cat, est = est, lower = lower, upper = upper),
    qual,
    lvls
  )
  ref <- .rmbl_string1(ref, "ref")
  conflvl <- .rmbl_conf_level(conflvl)
  z <- stats::qnorm(1 - (1 - conflvl) / 2)
  g <- .rmbl_utf8(trimws(as.character(data[[grp]])))
  .rmbl_pooled_check(pooled, g)
  .cat <- .rmbl_utf8(trimws(as.character(data[[cat]])))
  lvls <- .rmbl_utf8(trimws(lvls))
  .est <- .rmbl_num(data[[est]], "est")
  lo <- .rmbl_num(data[[lower]], "lower")
  hi <- .rmbl_num(data[[upper]], "upper")
  q <- .rmbl_qflags(if (is.null(qual)) rep("ok", length(g)) else data[[qual]])
  if (!ref %in% g) {
    stop(
      .rmbl_fn(),
      sprintf("\"%s\" is not a group of `data`", ref),
      call. = FALSE
    )
  }
  if (!any(.cat %in% lvls)) {
    stop(.rmbl_fn(), "no row of `data` has a category in `lvls`", call. = FALSE)
  }
  groups <- unique(g)
  k <- length(lvls)
  gs <- .oc_shares(groups, g, .cat, lvls, .est, lo, hi, q, z)
  sh <- gs$sh
  neff <- gs$neff
  if (anyNA(sh[ref, ])) {
    stop(
      .rmbl_fn(),
      "the reference group's distribution is suppressed or incomplete: ",
      "there is nothing to compare with",
      call. = FALSE
    )
  }
  q0 <- sh[ref, ]
  below0 <- c(0, cumsum(q0))[seq_len(k)]
  g0 <- below0 + q0 / 2
  rows <- lapply(setdiff(groups, ref), function(gi) {
    .oc_row(gi, sh[gi, ], q0, g0, neff[[gi]], neff[[ref]], z)
  })
  .oc_result(do.call(rbind, rows), ref, neff, gs$caution, pooled, sh, conflvl)
}

#' Age-standardise survey percentages
#'
#' The percentage (or proportion, or rate) a group would have with the age
#' structure of a standard population, from the estimate and published limits in
#' each age group: for comparing First Nations, Metis and Inuit prevalences
#' (suicidal thoughts, mood and anxiety disorders, heavy drinking) with each
#' other and with an older population, for example, when the age pattern of the
#' outcome is steep.
#'
#' @details With estimates \eqn{p_i}, standard errors \eqn{s_i = (u_i - l_i) /
#' (2z)} and standard weights \eqn{w_i} (the standard's shares), the
#' standardised estimate is \eqn{\sum w_i p_i} with standard error
#' \eqn{\sqrt{\sum w_i^2 s_i^2}}, the age groups being disjoint domains of the
#' survey (treated as independent: see \code{\link{indgap}}). The interval is
#' normal, cut at 0 and at \code{scale}. A group with a suppressed or missing
#' age group, or one whose published interval misses its own estimate, has no
#' standardised value: the age group is not imputed. The standard should be the
#' age structure of the population compared, or a common one: for First Nations,
#' Metis and Inuit comparisons, the Indigenous population's own
#' (\code{\link{cnsstd}}; Kumar and Tjepkema 2019).
#'
#' @param est,lower,upper Numeric vectors (not column names): the estimate in
#'   each age group (and group) and its published limits.
#' @param std The standard population, one count (or share) per age group.
#' @param grp Optional labels, one per row: one result per group. Rows are
#'   matched to \code{std} by position, so order each group's rows by age in the
#'   order of \code{std} (sort by an age order, not alphabetically).
#' @param qual Optional quality flags, one per row (a vector; see
#'   \code{\link{qltyrcd}}).
#' @param conflvl Confidence level of the prevalence intervals (default 0.95).
#' @param scale The upper bound of the scale: 100 for percentages (the default),
#'   1 for proportions, \code{Inf} for rates.
#' @return A data frame of class \code{rmbl_prevalence}: \code{group},
#'   \code{estimate}, \code{lower}, \code{upper}, \code{se}, \code{usewithcau};
#'   attribute \code{conflvl}. \code{plot()} draws it.
#' @references Klein RJ, Schoenborn CA (2001). Age adjustment using the 2000
#' projected U.S. population. Healthy People 2010 Statistical Notes 20. National
#' Center for Health Statistics.
#'
#' Kumar MB, Tjepkema M (2019). Suicide among First Nations people, Metis and
#' Inuit (2011-2016): findings from the 2011 Canadian Census Health and
#' Environment Cohort (CanCHEC). National Household Survey: Aboriginal Peoples,
#' Statistics Canada catalogue no. 99-011-X2019001.
#' @seealso \code{\link{agestd}} for counts of events,
#'   \code{\link{cnsstd}}, \code{\link{indgap}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # seriously contemplated suicide in the past 12 months, 2017 (table
#' # 41-10-0021-01), standardised to the Indigenous population's age structure
#' # (2021 Census)
#' ages <- c(
#'   "15 to 24 years",
#'   "25 to 34 years",
#'   "35 to 44 years",
#'   "45 to 54 years",
#'   "55 years and over"
#' )
#' si <- indiex("suicide")
#' si <- si[
#'   si$measure == "Seriously contemplated suicide in the past 12 months" &
#'     si$age %in% ages,
#' ]
#' si <- si[order(si$group, match(si$age, ages)), ]
#' std <- cnsstd(cnsprof(indiex("censuspop")))
#' w <- c(
#'   sum(std$population[4:5]),
#'   std$population[6:8],
#'   sum(std$population[9:11])
#' )
#' sp <- stdprev(
#'   si$estimate,
#'   si$lower,
#'   si$upper,
#'   std = w,
#'   grp = si$group,
#'   qual = si$quality
#' )
#' sp
#' plot(sp)
#'
#' # your own numbers: made-up percentages in three age groups for two groups,
#' # standardised to a population of 500, 300 and 200 in those age groups
#' stdprev(
#'   est = c(12, 9, 6, 8, 6, 4),
#'   lower = c(9, 6, 3, 7, 5, 3),
#'   upper = c(15, 12, 9, 9, 7, 5),
#'   std = c(500, 300, 200),
#'   grp = rep(c("Nation A", "Everyone else"), each = 3)
#' )
#' @export
stdprev <- function(
  est,
  lower,
  upper,
  std,
  grp = NULL,
  qual = NULL,
  conflvl = 0.95,
  scale = 100
) {
  .est <- .rmbl_num(est, "est")
  lo <- .rmbl_num(lower, "lower")
  hi <- .rmbl_num(upper, "upper")
  std <- .rmbl_num(std, "std")
  conflvl <- .rmbl_conf_level(conflvl)
  if (!identical(scale, Inf)) {
    scale <- .rmbl_scalar(scale, "scale", 0)
  }
  k <- length(std)
  .sp_check_std(std)
  if (length(lo) != length(.est) || length(hi) != length(.est)) {
    stop(
      .rmbl_fn(),
      "`est`, `lower` and `upper` must be the same length",
      call. = FALSE
    )
  }
  gq <- .sp_grp_qual(grp, qual, length(.est))
  grp <- gq$grp
  q <- gq$q
  .est <- .sp_drop_bad(.est, lo, hi)
  z <- stats::qnorm(1 - (1 - conflvl) / 2)
  w <- std / sum(std)
  rows <- lapply(unique(grp), function(gi) {
    .sp_group(gi, which(grp == gi), k, q, .est, lo, hi, w, z, scale)
  })
  out <- do.call(rbind, rows)
  attr(out, "conflvl") <- conflvl
  class(out) <- c("rmbl_prevalence", "data.frame")
  out
}

# ---- plots -------------------------------------------------------------------

#' @rdname plot-methods
#' @export
plot.rmbl_indigenous_gap <- function(
  x,
  ...,
  what = c("difference", "ratio"),
  main = NULL,
  col = NULL,
  palette = NULL
) {
  .rmbl_plot_check(x, "rmbl_indigenous_gap")
  what <- .rmbl_arg(what)
  d <- as.data.frame(x)
  lab <- paste0(d$group, ifelse(d$usewithcau, " (E)", ""))
  est <- d[[what]]
  cols <- if (what == "difference") {
    c("diflo", "difup")
  } else {
    c("ratiolo", "ratioup")
  }
  lo <- d[[cols[1L]]]
  hi <- d[[cols[2L]]]
  ref <- attr(x, "reference")
  .bl_dot_interval(
    lab,
    est,
    lo,
    hi,
    .bl_main(main, sprintf("Each group against %s", ref)),
    if (what == "difference") {
      sprintf("Difference from %s", ref)
    } else {
      sprintf("Ratio to %s", ref)
    },
    .bl_cols(nrow(d), col, palette),
    ref = if (what == "difference") 0 else 1,
    note = ifelse(is.finite(est), NA_character_, "suppressed: not compared"),
    ...
  )
  invisible(d[c("group", what, cols)])
}

#' @rdname plot-methods
#' @export
plot.rmbl_dsr <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  .rmbl_plot_check(x, "rmbl_dsr")
  d <- as.data.frame(x)
  .bl_dot_interval(
    d$group,
    d$rate,
    d$lower,
    d$upper,
    .bl_main(main, "Age-standardised rates"),
    sprintf(
      "Rate per %s, with its gamma interval",
      format(attr(x, "per"), big.mark = ",", scientific = FALSE)
    ),
    .bl_cols(nrow(d), col, palette),
    ...
  )
  invisible(d[c("group", "rate", "lower", "upper")])
}

#' @rdname plot-methods
#' @export
plot.rmbl_prevalence <- function(
  x,
  ...,
  main = NULL,
  col = NULL,
  palette = NULL
) {
  .rmbl_plot_check(x, "rmbl_prevalence")
  d <- as.data.frame(x)
  .bl_dot_interval(
    paste0(d$group, ifelse(d$usewithcau, " (E)", "")),
    d$estimate,
    d$lower,
    d$upper,
    .bl_main(main, "Age-standardised estimates"),
    "Estimate, with its interval",
    .bl_cols(nrow(d), col, palette),
    note = ifelse(
      is.finite(d$estimate),
      NA_character_,
      "an age group is suppressed"
    ),
    ...
  )
  invisible(d[c("group", "estimate", "lower", "upper")])
}

#' @rdname plot-methods
#' @export
plot.rmbl_exposure_trend <- function(
  x,
  ...,
  main = NULL,
  col = NULL,
  palette = NULL
) {
  .rmbl_plot_check(x, "rmbl_exposure_trend")
  d <- as.data.frame(x)
  .bl_dot_interval(
    sprintf("Exposure %s", format(d$dose)),
    d$orratio,
    d$lower,
    d$upper,
    .bl_main(
      main,
      sprintf(
        "Odds ratio by level of exposure (trend p = %s)",
        format.pval(attr(x, "trend")$p.value, digits = 2)
      )
    ),
    "Odds ratio against the lowest level (log scale)",
    .bl_cols(nrow(d), col, palette),
    ref = 1,
    log = "x",
    ...
  )
  invisible(d[c("dose", "orratio", "lower", "upper")])
}

#' @rdname plot-methods
#' @export
plot.rmbl_trc_progress <- function(
  x,
  ...,
  main = NULL,
  col = NULL,
  palette = NULL
) {
  .rmbl_plot_check(x, "rmbl_trc_progress")
  h <- attr(x, "history")
  total <- attr(x, "total")
  cols <- .bl_cols(2L, col, palette)
  t1 <- h$year[nrow(h)]
  far <- min(max(x$cmplby[is.finite(x$cmplby)], t1 + 10), t1 + 120)
  late <- if (is.finite(x$cmplbylate)) min(x$cmplbylate, far) else far
  o <- .bl_plot_opts()
  op <- .imh_par(o, o$las, .bl_safe_mar(c(4.2, 4.5, 3, 1), o$cex))
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot(
    range(h$year[1L], far),
    c(0, total),
    type = "n",
    xlab = "",
    ylab = "",
    main = "",
    ...
  )
  .bl_title(.bl_main(main, "Calls to Action completed, and the pace projected"))
  .bl_xlab("Year")
  .bl_ylab("Calls to Action completed")
  .bl_grid(NULL, side = "y")
  graphics::abline(h = total, col = "#8C8C8C", lty = 2)
  .imh_trc_draw(x, h, total, t1, far, cols)
  invisible(h)
}

#' @rdname plot-methods
#' @export
plot.rmbl_ordinal_compare <- function(
  x,
  ...,
  main = NULL,
  col = NULL,
  palette = NULL
) {
  .rmbl_plot_check(x, "rmbl_ordinal_compare")
  sh <- attr(x, "shares")
  sh <- sh[stats::complete.cases(sh), , drop = FALSE]
  k <- ncol(sh)
  # warm for the lowest rating to cool for the highest
  cols <- if (is.null(col) && is.null(palette)) {
    rev(blpal("diverging", k))
  } else {
    .bl_cols(k, col, palette)
  }
  fit <- .bl_label_fit(rownames(sh))
  o <- .bl_plot_opts()
  op <- .imh_par(o, 1, .bl_safe_mar(c(7, fit$mar, 3, 1), o$cex))
  on.exit(graphics::par(op), add = TRUE)
  graphics::barplot(
    t(sh[rev(seq_len(nrow(sh))), , drop = FALSE]) * 100,
    horiz = TRUE,
    col = cols,
    border = "white",
    names.arg = rev(fit$labels),
    xlab = "",
    main = "",
    xlim = c(0, 100),
    ...
  )
  .bl_title(.bl_main(
    main,
    sprintf("Ratings by group (reference: %s)", x$reference[1L])
  ))
  .bl_xlab("Percent, lowest rating on the left")
  .bl_legend_below(
    legend = colnames(sh),
    fill = cols,
    border = NA,
    horiz = TRUE,
    bty = "n",
    cex = 0.75
  )
  invisible(as.data.frame(sh))
}

#' Wellness beside distress: a strengths-first profile of published indicators
#'
#' Puts a group's wellness indicators (life satisfaction, perceived mental
#' health, a hopeful outlook, a sense of belonging, a strong cultural identity)
#' first and its distress indicators (suicidal thoughts, mood and anxiety
#' disorders, fair or poor mental health) after them, each with its published
#' interval, for each First Nations, Metis and Inuit group: so that a table of
#' mental health is never read, or plotted, as a list of deficits alone.
#'
#' @details Indigenous scholars of mental health define it as wellness and as a
#' process of healing, grounded in community, cultural identity, a holistic view
#' and interdependence (Stewart 2008), and ask that strengths be reported
#' together with disparities (Stewart 2020). This function puts that into how
#' published estimates are reported; it adds no estimate of its own. The
#' optional \code{domain} groups indicators by the holistic domains of the
#' Medicine Wheel teachings that Gabriel, Mirza and Stewart (2022) describe
#' (physical, emotional, mental, spiritual). That grouping is a way to lay out
#' the table, not a validated scale, and published tables have few indicators of
#' the spiritual domain: the profile says what is there and does not stand one
#' indicator in for another.
#'
#' Aggregate tables show how indicators vary together across groups; they cannot
#' show that culture, land or belonging protects mental health within a group,
#' which would be an ecological inference. The differences these tables show
#' between groups are the effects of colonial policy and of structural
#' conditions, not of the people in the groups (Gabriel et al. 2022); their
#' interpretation belongs with First Nations, Metis and Inuit communities.
#'
#' @param data A data frame, one row per group and indicator (as
#'   \code{\link{scests}} gives).
#' @param grp,ind,est,lower,upper Column names: the group, the indicator,
#'   the percentage and its published limits.
#' @param well,distress The indicators that measure wellness or strength, and
#'   those that measure distress; rows for any other indicator (totals,
#'   \dQuote{not specified}) are left out.
#' @param domain Optional named character vector giving each indicator's
#'   holistic domain, for example \code{c("Life satisfaction 8 to 10" =
#'   "mental", ...)}.
#' @param qual Optional column of quality flags, one per row of `data`.
#' @return A data frame of class \code{rmbl_wellness_profile}, wellness rows
#'   first, with the columns \code{group}, \code{indicator}, \code{side}
#'   (\code{"wellness"} or \code{"distress"}), \code{domain}, \code{estimate},
#'   \code{lower}, \code{upper} and \code{usewithcau}; \code{plot()} draws it.
#' @section Acknowledgement: This estimator puts to quantitative use the
#' framework of Professor Suzanne Stewart (Yellowknives Dene First Nation,
#' University of Toronto).
#'
#' See the acknowledgements of the \code{first-nations-metis-inuit-health}
#' vignette.
#' @references Stewart SL (2008). Promoting Indigenous mental health: cultural
#' perspectives on healing from Native counsellors in Canada. International
#' Journal of Health Promotion and Education 46(2):49-56.
#' \doi{10.1080/14635240.2008.10708129}
#'
#' Stewart S (2020). Addressing strengths and disparities in Indigenous health.
#' International Journal of Indigenous Health 15(1):4.
#' \doi{10.32799/ijih.v15i1.34976}
#'
#' Gabriel MD, Mirza S, Stewart SL (2022). Exploring mental health and holistic
#' healing through the life stories of Indigenous youth who have experienced
#' homelessness. International Journal of Environmental Research and Public
#' Health 19(20):13402. \doi{10.3390/ijerph192013402}
#' @seealso \code{\link{scests}}, \code{\link{indgap}},
#'   \code{\link{ordcmp}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # well-being, 2024 (table 41-10-0082-01)
#' wb <- indiex("wellbeing")
#' w <- welprof(
#'   wb,
#'   "group",
#'   "indicator",
#'   "estimate",
#'   "lower",
#'   "upper",
#'   well = c(
#'     "Life satisfaction rating of 8, 9 or 10",
#'     "Sense of meaning and purpose rating of 8, 9 or 10",
#'     "Always or often has a hopeful outlook"
#'   ),
#'   distress = c(
#'     "Life satisfaction rating between 0 and 5",
#'     "Rarely or never has a hopeful outlook"
#'   ),
#'   qual = "quality"
#' )
#' w
#' plot(w)
#'
#' # your own table: made-up percentages for two communities, with limits
#' own <- data.frame(
#'   community = rep(c("Lakeside", "Riverbend"), each = 4),
#'   item = rep(c("Hopeful", "Satisfied", "Rarely hopeful", "Low satisfaction"),
#'              2),
#'   pct = c(64, 71, 12, 18, 58, 66, 16, 22),
#'   lo = c(59, 66, 9, 14, 52, 60, 12, 17),
#'   hi = c(69, 76, 15, 22, 64, 72, 20, 27)
#' )
#' welprof(own, "community", "item", "pct", "lo", "hi",
#'         well = c("Hopeful", "Satisfied"),
#'         distress = c("Rarely hopeful", "Low satisfaction"))
#' @export
welprof <- function(
  data,
  grp,
  ind,
  est,
  lower,
  upper,
  well,
  distress,
  domain = NULL,
  qual = NULL
) {
  if (!is.data.frame(data)) {
    stop("welprof: `data` must be a data frame", call. = FALSE)
  }
  qual <- .wp_check_cols(
    data,
    list(grp = grp, ind = ind, est = est, lower = lower, upper = upper),
    qual
  )
  .rmbl_no_fn(well = well, distress = distress, domain = domain)
  .ind <- .rmbl_utf8(trimws(as.character(data[[ind]])))
  sides <- .wp_check_inds(well, distress, .ind, domain)
  well <- sides$well
  distress <- sides$distress
  .est <- .rmbl_num(data[[est]], "est")
  q <- rep("ok", length(.ind))
  if (!is.null(qual)) {
    q <- as.character(data[[qual]])
  }
  q <- .rmbl_qflags(q)
  gone <- q %in% c("F", "x", "..", "...")
  .est[gone] <- NA_real_
  dom <- rep(NA_character_, length(.ind))
  if (!is.null(domain)) {
    dom <- unname(domain[.ind])
  }
  keep <- .ind %in% c(well, distress)
  lo <- ifelse(gone, NA_real_, .rmbl_num(data[[lower]], "lower"))
  hi <- ifelse(gone, NA_real_, .rmbl_num(data[[upper]], "upper"))
  .grp <- .rmbl_utf8(trimws(as.character(data[[grp]])))
  .est[keep] <- .rmbl_contains(
    .est[keep],
    lo[keep],
    hi[keep],
    paste0(.grp[keep], ": ", .ind[keep])
  )
  out <- data.frame(
    group = .grp,
    indicator = .ind,
    side = ifelse(.ind %in% well, "wellness", "distress"),
    domain = dom,
    estimate = .est,
    lower = lo,
    upper = hi,
    usewithcau = q == "E",
    stringsAsFactors = FALSE
  )[keep, , drop = FALSE]
  .wp_order(out, c(well, distress))
}

#' @rdname plot-methods
#' @export
plot.rmbl_wellness_profile <- function(
  x,
  ...,
  main = NULL,
  col = NULL,
  palette = NULL
) {
  .rmbl_plot_check(x, "rmbl_wellness_profile")
  d <- as.data.frame(x)
  inds <- unique(d$indicator)
  grp <- unique(d$group)
  ng <- length(grp)
  cols <- .bl_cols(ng, col, palette)
  side <- d$side[match(inds, d$indicator)]
  # one band per indicator, wellness on top; each group a row inside the band
  step <- 1 / (ng + 1)
  yb <- rev(seq_along(inds))
  y <- yb[match(d$indicator, inds)] +
    (match(d$group, grp) - (ng + 1) / 2) * step
  # a band per indicator leaves room for two-line labels, so long names are
  # broken, not cut
  labs <- .bl_label_wrap(inds)
  o <- .bl_plot_opts()
  op <- .imh_par(o, 1, .bl_safe_mar(c(7, labs$mar, 3, 1), o$cex))
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot(
    .imh_wp_range(d),
    c(0.5, length(inds) + 0.5),
    type = "n",
    yaxt = "n",
    xlab = "",
    ylab = "",
    main = "",
    ...
  )
  .bl_title(.bl_main(main, "Wellness and distress, each group"))
  .bl_xlab("Estimate, with its published interval")
  .bl_grid(NULL, side = "x")
  .imh_wp_sections(side)
  .imh_wp_marks(d, y, cols[match(d$group, grp)])
  .bl_row_labels(yb, labs$labels)
  .bl_legend_below(
    legend = grp,
    col = cols,
    pch = 19,
    horiz = TRUE,
    bty = "n",
    cex = 0.75
  )
  invisible(d)
}

#' Holistic balance: how evenly wellness is held across the domains of a whole
#' person
#'
#' For each group, from published percentages of wellness in each holistic
#' domain (physical, emotional, mental, spiritual, or the domains a community
#' names), the overall level of wellness and how balanced it is across the
#' domains, with Monte Carlo intervals from the published ones.
#'
#' @details Indigenous understandings of mental health are holistic: wellness is
#' a balance among the domains of a person, and illness a loss of that balance
#' (Stewart 2008; Gabriel, Mirza and Stewart 2022). A single indicator, or an
#' average of indicators, cannot show balance: a group with 80% in two domains
#' and 20% in two others has the same average as one with 50% in all four. This
#' method, which is ours and inspired by that work rather than taken from it,
#' measures balance as the ratio of the weighted geometric to the weighted
#' arithmetic mean of the domain levels \eqn{p_k}: \deqn{B = \exp\left(\sum_k
#' w_k \log p_k\right) / \sum_k w_k p_k,} one less Atkinson's (1970) index with
#' inequality aversion 1. \eqn{B = 1} exactly when every domain with a positive
#' weight is at the same level, and it falls toward 0 as one domain falls behind
#' the others; it does not depend on the overall level, which is reported beside
#' it (\code{level}, \eqn{\sum_k w_k p_k}) with the weakest domain.
#'
#' The weights \code{w} say how much each domain counts. They are equal by
#' default; a community that holds its own view of the domains sets its own (the
#' CARE principle of authority to control, Carroll et al. 2020), and the result
#' says which weights it used.
#'
#' Several indicators in one domain are averaged, their standard errors combined
#' as independent (they come from the same respondents, so that standard error
#' is too small). The interval for \eqn{B} comes from \code{reps} draws of every
#' domain level from a normal distribution on the logit scale with the standard
#' error of its published interval, the domains independent. \eqn{B} is at most
#' 1 and reaches 1 only at equal levels, so noise in the levels tends to pull
#' the draws below \eqn{\hat B} (\eqn{B} is not concave; the direction of the
#' bias is seen in the draws, not guaranteed): the percentile interval is
#' shifted back by the draws' mean bias (\eqn{\bar B^* - \hat B}), kept inside
#' \eqn{(0, 1]} and widened if need be to contain \eqn{\hat B}. The level's
#' interval is normal. A group with a suppressed or missing domain, or one whose
#' published interval misses its own estimate, has no balance: the domain is not
#' imputed.
#'
#' What the domains mean, and which indicators stand for each, is for the
#' communities to say; the published tables have few measures of spiritual
#' wellness, and a domain with no fitting indicator should be left out rather
#' than filled with another.
#'
#' @param grp,domain,est,lower,upper Column names: the group, the domain of the
#'   indicator (any set of domains: Medicine Wheel, Te Whare Tapa Wha, a
#'   Nation's own), the percentage of wellness (0 to 100, strictly inside;
#'   multiply proportions by 100) and its published limits.
#' @param w Optional named weights, one per domain (they are rescaled to sum to
#'   one).
#' @param qual Optional column of quality flags for the estimates.
#' @param reps Monte Carlo draws for the intervals (default 10,000).
#' @param seed Seed for the draws, so the intervals are reproducible (default
#'   1).
#' @param conflvl Confidence level of the balance intervals (default 0.95).
#' @return A data frame of class \code{rmbl_holistic_balance}: \code{group},
#'   \code{level}, \code{lvllo}, \code{lvlup}, \code{balance}, \code{ballo},
#'   \code{balup}, \code{weadom}, \code{usewithcau}; the attributes
#'   \code{domains} (the matrix of domain levels, groups by domains) and
#'   \code{weights}.
#' @section Acknowledgement: This estimator puts to quantitative use the
#' framework of Professor Suzanne Stewart (Yellowknives Dene First Nation,
#' University of Toronto).
#'
#' See the acknowledgements of the \code{first-nations-metis-inuit-health}
#' vignette.
#' @references Atkinson AB (1970). On the measurement of inequality. Journal of
#' Economic Theory 2(3):244-263. \doi{10.1016/0022-0531(70)90039-6}
#'
#' Carroll SR, Garba I, Figueroa-Rodriguez OL, et al. (2020). The CARE
#' Principles for Indigenous Data Governance. Data Science Journal 19:43.
#' \doi{10.5334/dsj-2020-043}
#'
#' Gabriel MD, Mirza S, Stewart SL (2022). Exploring mental health and holistic
#' healing through the life stories of Indigenous youth who have experienced
#' homelessness. International Journal of Environmental Research and Public
#' Health 19(20):13402. \doi{10.3390/ijerph192013402}
#'
#' Stewart SL (2008). Promoting Indigenous mental health: cultural perspectives
#' on healing from Native counsellors in Canada. International Journal of Health
#' Promotion and Education 46(2):49-56. \doi{10.1080/14635240.2008.10708129}
#' @seealso \code{\link{welprof}}, \code{\link{dualcont}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # four domains from table 13-10-0924-01, 2019/2022, adults: which indicator
#' # stands for each is a choice for the people whose data these are; this is
#' # one reading of it
#' h <- indiex("health")
#' belong <- paste(
#'   "Sense of belonging to local community,",
#'   "somewhat strong or very strong"
#' )
#' dom <- c(
#'   "Perceived health, very good or excellent" = "physical",
#'   "Perceived mental health, very good or excellent" = "mental",
#'   "Life satisfaction, satisfied or very satisfied" = "emotional",
#'   stats::setNames("community", belong)
#' )
#' d <- h[
#'   h$period == "2019/2022" &
#'     h$age == "Total, 18 years and over" &
#'     h$indicator %in% names(dom),
#' ]
#' d$domain <- dom[d$indicator]
#' hb <- holbal(
#'   d,
#'   "group",
#'   "domain",
#'   "estimate",
#'   "lower",
#'   "upper",
#'   qual = "quality"
#' )
#' hb
#' plot(hb)
#' # a community that counts belonging twice
#' holbal(
#'   d,
#'   "group",
#'   "domain",
#'   "estimate",
#'   "lower",
#'   "upper",
#'   qual = "quality",
#'   w = c(physical = 1, mental = 1, emotional = 1, community = 2)
#' )
#'
#' # your own table: made-up percentages of wellness in four domains a Nation
#' # set for itself, for two communities
#' own <- data.frame(
#'   community = rep(c("Lakeside", "Riverbend"), each = 4),
#'   domain = rep(c("body", "mind", "spirit", "family"), 2),
#'   pct = c(62, 58, 70, 75, 55, 61, 66, 80),
#'   lo = c(57, 53, 65, 70, 49, 55, 60, 75),
#'   hi = c(67, 63, 75, 80, 61, 67, 72, 85)
#' )
#' holbal(own, "community", "domain", "pct", "lo", "hi", reps = 2000)
#' @export
#' @inheritParams welprof
holbal <- function(
  data,
  grp,
  domain,
  est,
  lower,
  upper,
  w = NULL,
  qual = NULL,
  reps = 10000,
  seed = 1,
  conflvl = 0.95
) {
  if (!is.data.frame(data)) {
    stop("holbal: `data` must be a data frame", call. = FALSE)
  }
  grp <- .rmbl_col(data, grp, "grp")
  domain <- .rmbl_col(data, domain, "domain")
  est <- .rmbl_col(data, est, "est")
  lower <- .rmbl_col(data, lower, "lower")
  upper <- .rmbl_col(data, upper, "upper")
  if (!is.null(qual)) {
    qual <- .rmbl_col(data, qual, "qual")
  }
  reps <- .rmbl_scalar(reps, "reps", 100, 1e6, integer = TRUE)
  conflvl <- .rmbl_conf_level(conflvl)
  z <- stats::qnorm(1 - (1 - conflvl) / 2)
  g <- .rmbl_utf8(trimws(as.character(data[[grp]])))
  dm <- .rmbl_utf8(trimws(as.character(data[[domain]])))
  raw <- .rmbl_num(data[[est]], "est")
  lo_raw <- .rmbl_num(data[[lower]], "lower")
  hi_raw <- .rmbl_num(data[[upper]], "upper")
  .hb_check_pct(raw)
  q <- if (is.null(qual)) rep("ok", length(g)) else as.character(data[[qual]])
  q <- .rmbl_qflags(q)
  raw[q %in% c("F", "x", "..", "...")] <- NA_real_
  in_dom <- !is.na(dm) & nzchar(dm)
  raw[in_dom] <- .rmbl_contains(
    raw[in_dom],
    lo_raw[in_dom],
    hi_raw[in_dom],
    paste0(g[in_dom], ": ", dm[in_dom])
  )
  .est <- raw / 100
  se <- (hi_raw - lo_raw) / (2 * z) / 100
  doms <- unique(dm[!is.na(dm) & nzchar(dm)])
  if (length(doms) < 2L) {
    stop(.rmbl_fn(), "balance needs two domains at least", call. = FALSE)
  }
  .w <- .hb_weights(w, doms)
  groups <- unique(g)
  lv <- .hb_levels(groups, doms, g, dm, .est, se, q)
  lev <- lv$lev
  sem <- lv$sem
  .rmbl_local_seed(seed)
  a <- (1 - conflvl) / 2
  rows <- lapply(groups, function(gi) {
    .hb_row(gi, lev[gi, ], sem[gi, ], .w, reps, a, z, doms)
  })
  .hb_result(do.call(rbind, rows), lv, .w, conflvl)
}

#' Wellness and distress as two continua
#'
#' For each group, one wellness indicator against one distress indicator, each
#' with its published interval, and the ratio of the two: the dual-continua view
#' of mental health, in which wellness is not the absence of distress and is
#' measured in its own right.
#'
#' @details Keyes (2002, 2005) showed that flourishing and mental illness are
#' correlated but distinct axes: a person, or a population, can carry distress
#' and also wellness. That is how Indigenous scholars of mental health describe
#' it too, as wellness and as a process of healing rather than as illness alone
#' (Stewart 2008). Plotting the groups on both axes keeps a strength visible
#' beside the burden it sits next to. The \code{strratio} is \eqn{R = W / D},
#' wellness over distress, with the log-normal interval \eqn{\exp\{\log R \pm
#' z\sqrt{\sigma_W^2 + \sigma_D^2}\}} from the two published intervals: above 1,
#' more people report the wellness than the distress. The two estimates come
#' from the same respondents; their covariance is not published, so the interval
#' treats them as independent and is too narrow when they are negatively
#' correlated, as answers about wellness and distress usually are. Any two
#' indicators on one scale can be set against each other.
#'
#' @param x A wellness profile from \code{\link{welprof}}.
#' @param well,distress One wellness and one distress indicator of \code{x}.
#' @param conflvl Confidence level of the published intervals and of the ratio
#'   (default 0.95).
#' @return A data frame of class \code{rmbl_dual_continuum} with \code{group},
#'   \code{wellness}, \code{wello}, \code{welup}, \code{distress},
#'   \code{distrlo}, \code{distrup}, \code{strratio},
#'   \code{ratiolo}, \code{ratioup} and \code{usewithcau}.
#' @section Acknowledgement: This estimator puts to quantitative use the
#' framework of Professor Suzanne Stewart (Yellowknives Dene First Nation,
#' University of Toronto).
#'
#' See the acknowledgements of the \code{first-nations-metis-inuit-health}
#' vignette.
#' @references Keyes CLM (2002). The mental health continuum: from languishing
#' to flourishing in life. Journal of Health and Social Behavior 43(2):207-222.
#' \doi{10.2307/3090197}
#'
#' Keyes CLM (2005). Mental illness and/or mental health? Investigating axioms
#' of the complete state model of health. Journal of Consulting and Clinical
#' Psychology 73(3):539-548. \doi{10.1037/0022-006X.73.3.539}
#'
#' Stewart SL (2008), see \code{\link{holbal}}.
#' @seealso \code{\link{welprof}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' wb <- indiex("wellbeing")
#' w <- welprof(wb, "group", "indicator", "estimate", "lower", "upper",
#'                       well = "Always or often has a hopeful outlook",
#'                       distress = "Life satisfaction rating between 0 and 5",
#'                       qual = "quality")
#' dc <- dualcont(w, "Always or often has a hopeful outlook",
#'                      "Life satisfaction rating between 0 and 5")
#' dc
#' plot(dc)
#'
#' # your own table: made-up percentages for two communities, with limits
#' own <- data.frame(
#'   community = rep(c("Lakeside", "Riverbend"), each = 4),
#'   item = rep(c("Hopeful", "Satisfied", "Rarely hopeful", "Low satisfaction"),
#'              2),
#'   pct = c(64, 71, 12, 18, 58, 66, 16, 22),
#'   lo = c(59, 66, 9, 14, 52, 60, 12, 17),
#'   hi = c(69, 76, 15, 22, 64, 72, 20, 27)
#' )
#' w <- welprof(own, "community", "item", "pct", "lo", "hi",
#'              well = "Hopeful", distress = "Rarely hopeful")
#' dualcont(w, "Hopeful", "Rarely hopeful")
#' @export
dualcont <- function(x, well, distress, conflvl = 0.95) {
  if (!inherits(x, "rmbl_wellness_profile")) {
    stop("dualcont: `x` must come from welprof()", call. = FALSE)
  }
  well <- .rmbl_string1(well, "well")
  distress <- .rmbl_string1(distress, "distress")
  .dc_check(x, well, distress)
  conflvl <- .rmbl_conf_level(conflvl)
  .dc_result(x, well, distress, conflvl)
}

#' Do distinct groups differ? A heterogeneity test before pooling
#'
#' Tests whether the estimates of one indicator for distinct groups (First
#' Nations, Metis and Inuit; Aboriginal and Torres Strait Islander people; any
#' groups with published intervals) differ more than their intervals allow, and
#' says how much of their spread is real: the evidence for reporting each group
#' distinctly rather than as one pooled figure.
#'
#' @details With estimates \eqn{y_g}, standard errors \eqn{s_g} from the
#' published intervals and weights \eqn{w_g = 1/s_g^2}, Cochran's \eqn{Q = \sum
#' w_g (y_g - \bar y_w)^2} has a chi-squared distribution on \eqn{G - 1} degrees
#' of freedom when the groups share one value, and \eqn{I^2 = \max(0, (Q -
#' (G-1))/Q)} is the share of the spread that is real rather than sampling error
#' (Higgins and Thompson 2002). A pooled figure is a weighted mean of different
#' populations whenever \eqn{I^2} is large; the population-weighted total
#' Statistics Canada publishes also depends on how many people are in each
#' group, so it is mostly a First Nations figure where First Nations people are
#' most of the Indigenous population. Rows that pool groups are left out
#' (\code{pooled}; see \code{\link{indgap}}); every other row is included, so
#' drop the reference group (non-Indigenous people) yourself, and never test
#' overlapping groups (\code{"alone"} beside \dQuote{alone or in combination})
#' together: they are not independent. With two or three groups the test has
#' little power and \eqn{I^2} is imprecise; a large \eqn{p} is not evidence that
#' the groups are the same.
#'
#' @param data A data frame, one row per group.
#' @param grp,est,lower,upper Column names.
#' @param qual Optional column of quality flags; suppressed rows are left out
#'   (see \code{\link{qltyrcd}}).
#' @param conflvl Confidence level of the published intervals, and the level of
#'   the verdict printed (default 0.95).
#' @param pooled Optional labels of rows that pool other groups.
#' @return A list of class \code{rmbl_distinctions}: \code{groups} (the
#'   estimates used, with their standard errors), \code{pooled} (the
#'   inverse-variance mean) and \code{poose}, \code{q}, \code{df},
#'   \code{p_value}, \code{i2}, \code{leftout} (the rows not used) and
#'   \code{conflvl}. \code{print()} and \code{plot()} show it.
#' @references Higgins JPT, Thompson SG (2002). Quantifying heterogeneity in a
#'   meta-analysis. Statistics in Medicine 21(11):1539-1558.
#'   \doi{10.1002/sim.1186}
#' @seealso \code{\link{indgap}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # perceived mental health very good or excellent, 2019/2022, adults (table
#' # 13-10-0924-01)
#' h <- indiex("health")
#' mh <- h[
#'   h$period == "2019/2022" &
#'     h$age == "Total, 18 years and over" &
#'     h$group != "Non-Indigenous" &
#'     h$indicator == "Perceived mental health, very good or excellent",
#' ]
#' dt <- dstntst(mh, "group", "estimate", "lower", "upper", qual = "quality")
#' dt
#' plot(dt)
#' # your own table: made-up numbers, with the pooled row named
#' own <- data.frame(
#'   group = c("Aboriginal", "Torres Strait Islander", "Both"),
#'   est = c(24.0, 31.0, 24.6),
#'   lo = c(22.1, 26.2, 22.8),
#'   hi = c(25.9, 35.8, 26.4)
#' )
#' dstntst(own, "group", "est", "lo", "hi", pooled = "Both")
#' @export
dstntst <- function(
  data,
  grp,
  est,
  lower,
  upper,
  qual = NULL,
  conflvl = 0.95,
  pooled = NULL
) {
  if (!is.data.frame(data)) {
    stop("dstntst: `data` must be a data frame", call. = FALSE)
  }
  grp <- .rmbl_col(data, grp, "grp")
  est <- .rmbl_col(data, est, "est")
  lower <- .rmbl_col(data, lower, "lower")
  upper <- .rmbl_col(data, upper, "upper")
  if (!is.null(qual)) {
    qual <- .rmbl_col(data, qual, "qual")
  }
  conflvl <- .rmbl_conf_level(conflvl)
  z <- stats::qnorm(1 - (1 - conflvl) / 2)
  g <- .rmbl_utf8(trimws(as.character(data[[grp]])))
  .rmbl_pooled_check(pooled, g)
  y <- .rmbl_num(data[[est]], "est")
  lo <- .rmbl_num(data[[lower]], "lower")
  hi <- .rmbl_num(data[[upper]], "upper")
  y <- .rmbl_contains(y, lo, hi, g)
  s <- (hi - lo) / (2 * z)
  q <- .rmbl_qflags(if (is.null(qual)) rep("ok", length(g)) else data[[qual]])
  use <- !.rmbl_pan_indigenous(g, pooled) &
    !q %in% c("F", "x", "..", "...") &
    is.finite(y) &
    is.finite(s) &
    s > 0
  if (sum(use) < 2L) {
    stop(
      .rmbl_fn(),
      "the test needs two groups at least with an estimate and an interval",
      call. = FALSE
    )
  }
  if (anyDuplicated(g[use])) {
    stop(.rmbl_fn(), "a group appears twice", call. = FALSE)
  }
  .dt_result(g, y, s, use, conflvl)
}

#' @export
format.rmbl_distinctions <- function(x, ...) {
  lvl <- if (is.null(x$conflvl)) 0.95 else x$conflvl
  a <- 1 - lvl
  z <- stats::qnorm(1 - a / 2)
  g <- x$groups
  g[[.an_ci_name(lvl)]] <- .an_ci(
    g$estimate - z * g$se,
    g$estimate + z * g$se
  )
  differ <- x$p_value < a
  .an_block(
    "Distinctions test",
    facts = list(
      Groups = nrow(x$groups),
      `Cochran's Q` = sprintf("%.2f on %d df", x$q, x$df),
      `p-value` = .rmbl_fmt_p(x$p_value),
      `I-squared` = sprintf(
        "%.0f%% of the variation is beyond chance",
        100 * x$i2
      ),
      Pooled = sprintf(
        "%.2f (se %.3g, inverse-variance mean)",
        x$pooled,
        x$poose
      ),
      `Left out` = if (length(x$leftout)) paste(x$leftout, collapse = "; ")
    ),
    tables = list(g),
    reading = if (differ) {
      c(
        "Q says the groups differ: report each one, not the pooled figure.",
        sprintf("Q = %.2f, p = %s.", x$q, format.pval(x$p_value, digits = 3))
      )
    } else {
      c(
        sprintf("No difference shown at the %g%% level, which is", 100 * a),
        "not evidence that they are the same."
      )
    },
    notes = c(
      "Distinctions-based: each group is reported on its own; a",
      "pan-Indigenous total is left out of the test, never used as a group.",
      "Higgins and Thompson (2002) for Q and I-squared."
    )
  )
}

#' @export
format.rmbl_wellness_profile <- function(x, ...) {
  need <- c("group", "indicator", "side", "estimate", "lower", "upper")
  if (!all(need %in% names(x)) || !nrow(x)) {
    return(.an_plain(x, ...))
  }
  d <- as.data.frame(x)
  ci <- .an_ci_name(attr(x, "conflvl"))
  tabs <- .an_by(d, "indicator", function(g) {
    out <- data.frame(
      group = .an_star(g$group, g$usewithcau),
      estimate = g$estimate,
      stringsAsFactors = FALSE
    )
    out[[ci]] <- .an_ci(g$lower, g$upper)
    if (!all(is.na(g$domain))) {
      out$domain <- ifelse(is.na(g$domain), "", as.character(g$domain))
    }
    out
  })
  names(tabs) <- .an_side_caption(names(tabs), d)
  .an_block(
    "Wellness profile",
    facts = list(
      Groups = paste(unique(d$group), collapse = "; "),
      `Wellness indicators` = length(unique(d$indicator[d$side == "wellness"])),
      `Distress indicators` = length(unique(d$indicator[d$side == "distress"]))
    ),
    tables = tabs,
    reading = .an_wp_reading(d),
    notes = c(
      "Wellness indicators come first, so each group's strengths are read",
      "before its distress (Stewart 2008).",
      .an_caution(d$usewithcau)
    )
  )
}

#' @export
format.rmbl_holistic_balance <- function(x, ...) {
  need <- c("group", "level", "lvllo", "lvlup", "balance", "ballo", "balup")
  if (!all(need %in% names(x)) || !nrow(x)) {
    return(.an_plain(x, ...))
  }
  d <- as.data.frame(x)
  lvl <- .an_lvl(attr(x, "conflvl")) %||% ""
  show <- data.frame(
    group = .an_star(d$group, d$usewithcau),
    level = d$level,
    lvlci = .an_ci(d$lvllo, d$lvlup),
    balance = d$balance,
    balci = .an_ci(d$ballo, d$balup, 3L),
    weakest = d$weadom,
    stringsAsFactors = FALSE
  )
  names(show)[c(3L, 5L)] <- trimws(paste(lvl, c("level CI", "balance CI")))
  tabs <- list(show)
  tabs[["Domain levels (percent)"]] <- .an_hb_domains(x, d$group)
  .an_block(
    "Holistic balance across the domains",
    facts = list(
      Groups = nrow(d),
      Weights = .an_hb_weights(attr(x, "weights")),
      Balance = "weighted geometric over arithmetic mean of the domain levels"
    ),
    tables = tabs,
    reading = .an_hb_reading(d),
    notes = c(
      "balance is 1 when every domain is at the same level and falls toward",
      "0 as one falls behind; level is the weighted mean, reported beside it.",
      "Our method, inspired by Stewart (2008), not taken from it.",
      "The weights say how much each domain counts; a community may set",
      "its own (CARE: authority to control, Carroll et al. 2020).",
      .an_caution(d$usewithcau)
    )
  )
}

#' @export
format.rmbl_dual_continuum <- function(x, ...) {
  need <- c("group", "wellness", "wello", "distress", "strratio", "ratiolo")
  if (!all(need %in% names(x)) || !nrow(x)) {
    return(.an_plain(x, ...))
  }
  d <- as.data.frame(x)
  lab <- attr(x, "labels")
  show <- data.frame(
    group = .an_star(d$group, d$usewithcau),
    wellness = d$wellness,
    wellci = .an_ci(d$wello, d$welup),
    distress = d$distress,
    distci = .an_ci(d$distrlo, d$distrup),
    ratio = d$strratio,
    ratioci = .an_ci(d$ratiolo, d$ratioup, 3L),
    stringsAsFactors = FALSE
  )
  names(show)[c(3L, 5L, 7L)] <- c("interval", "interval ", "ratio interval")
  above <- sum(d$ratiolo > 1, na.rm = TRUE)
  .an_block(
    "Dual continuum: wellness beside distress",
    facts = list(
      Wellness = if (!is.null(lab)) lab[["wellness"]],
      Distress = if (!is.null(lab)) lab[["distress"]],
      Groups = nrow(d),
      Ratio = "wellness over distress, log-normal interval"
    ),
    tables = list(show),
    reading = c(
      "A ratio above 1: more people report the wellness than the distress.",
      sprintf(
        "%d of %d groups have the whole interval above 1.",
        above,
        nrow(d)
      )
    ),
    notes = c(
      "Both estimates come from the same respondents and their covariance",
      "is not published: the interval treats them as independent.",
      .an_caution(d$usewithcau)
    )
  )
}

#' @export
format.rmbl_ordinal_compare <- function(x, ...) {
  need <- c("group", "reference", "probbet", "lower", "upper", "delta")
  if (!all(need %in% names(x)) || !nrow(x)) {
    return(.an_plain(x, ...))
  }
  d <- as.data.frame(x)
  lab <- .an_pooled(.an_star(d$group, d$usewithcau), d$poogrp)
  show <- data.frame(
    group = lab,
    probbet = d$probbet,
    ci = .an_ci(d$lower, d$upper, 3L),
    delta = d$delta,
    neff = round(d$neff),
    stringsAsFactors = FALSE
  )
  names(show)[3L] <- .an_ci_name(attr(x, "conflvl"))
  .an_block(
    "Ordinal comparison against a reference group",
    facts = list(
      Reference = d$reference[1L],
      `Reference neff` = round(d$neffref[1L]),
      Levels = if (is.matrix(attr(x, "shares"))) ncol(attr(x, "shares")),
      Measure = "chance a person in the group rates higher, ties half"
    ),
    tables = list(show),
    reading = .rd_null(
      lab,
      d$lower,
      d$upper,
      0.5,
      sprintf("Rate higher than %s", d$reference[1L]),
      sprintf("Rate lower than %s", d$reference[1L])
    ),
    notes = c(
      "probbet 0.5 is no difference; above 0.5 the group rates higher.",
      "delta (Cliff's) = share rating higher less share rating lower.",
      "neff: the effective sample size the published limits imply (it",
      "carries the survey's design effect).",
      if (any(.an_true(d$poogrp))) {
        paste(
          "(pooled): a pan-Indigenous total, shown beside, not a distinct",
          "group (poogrp)."
        )
      },
      .an_caution(d$usewithcau)
    )
  )
}

#' @export
format.rmbl_prevalence <- function(x, ...) {
  need <- c("group", "estimate", "lower", "upper")
  if (!all(need %in% names(x)) || !nrow(x)) {
    return(.an_plain(x, ...))
  }
  d <- as.data.frame(x)
  show <- data.frame(
    group = .an_star(d$group, d$usewithcau),
    estimate = d$estimate,
    stringsAsFactors = FALSE
  )
  show[[.an_ci_name(attr(x, "conflvl"))]] <- .an_ci(d$lower, d$upper)
  show$se <- d$se
  .an_block(
    "Age-standardised prevalence",
    facts = list(
      Groups = nrow(d),
      Method = "direct standardisation to the standard population given"
    ),
    tables = list(show),
    reading = .rd_groups(
      .an_star(d$group, d$usewithcau),
      d$estimate,
      d$lower,
      d$upper,
      "prevalence"
    ),
    notes = c(
      "Each group's prevalence as if it had the standard population's ages,",
      "so the groups compare without their age structures.",
      "Compare only rates standardised to the same population.",
      .an_caution(d$usewithcau)
    )
  )
}

#' @rdname plot-methods
#' @export
plot.rmbl_holistic_balance <- function(
  x,
  ...,
  main = NULL,
  col = NULL,
  palette = NULL
) {
  .rmbl_plot_check(x, "rmbl_holistic_balance")
  lev <- attr(x, "domains")
  lev <- lev[stats::complete.cases(lev), , drop = FALSE]
  k <- ncol(lev)
  ng <- nrow(lev)
  cols <- .bl_cols(ng, col, palette)
  o <- .bl_plot_opts()
  op <- graphics::par(
    cex = o$cex,
    bg = o$bg,
    mar = c(1 + 1.3 * ceiling(nrow(lev) / 2), 1, 3, 1),
    xpd = NA
  )
  on.exit(graphics::par(op), add = TRUE)
  # one spoke per domain, from the top clockwise, the circle at 100%
  ang <- pi / 2 - 2 * pi * (seq_len(k) - 1) / k
  graphics::plot(
    c(-1.35, 1.35),
    c(-1.25, 1.25),
    type = "n",
    asp = 1,
    axes = FALSE,
    xlab = "",
    ylab = "",
    main = "",
    ...
  )
  .bl_title(.bl_main(main, "Wellness in each domain, and its balance"))
  .imh_hb_web(colnames(lev), ang)
  for (i in seq_len(ng)) {
    r <- lev[i, ] / 100
    graphics::polygon(
      r * cos(ang),
      r * sin(ang),
      border = cols[i],
      lwd = 2,
      col = grDevices::adjustcolor(cols[i], 0.12)
    )
  }
  .imh_hb_legend(x, lev, cols)
  invisible(as.data.frame(lev))
}

#' @rdname plot-methods
#' @export
plot.rmbl_dual_continuum <- function(
  x,
  ...,
  main = NULL,
  col = NULL,
  palette = NULL
) {
  .rmbl_plot_check(x, "rmbl_dual_continuum")
  d <- as.data.frame(x)
  lab <- attr(x, "labels")
  cols <- .bl_cols(nrow(d), col, palette)
  o <- .bl_plot_opts()
  op <- .imh_par(o, 1, .bl_safe_mar(c(4.2, 4.5, 3, 1)))
  on.exit(graphics::par(op), add = TRUE)
  # the data's own range, padded (anchored at 0, the groups crowded one corner
  # of an empty panel)
  xr <- range(d$distrlo, d$distrup, d$distress, na.rm = TRUE)
  yr <- range(d$wello, d$welup, d$wellness, na.rm = TRUE)
  xr <- xr + c(-1, 1) * 0.08 * max(diff(xr), 1)
  yr <- yr + c(-1, 1) * 0.08 * max(diff(yr), 1)
  graphics::plot(xr, yr, type = "n", xlab = "", ylab = "", main = "", ...)
  .bl_title(.bl_main(main, "Wellness and distress, two continua"))
  .bl_xlab(sprintf("%s (%%)", lab[["distress"]]))
  .bl_ylab(sprintf("%s (%%)", lab[["wellness"]]))
  .bl_grid(NULL, side = "y")
  .imh_dc_marks(d, cols)
  invisible(d)
}

#' @rdname plot-methods
#' @export
plot.rmbl_distinctions <- function(
  x,
  ...,
  main = NULL,
  col = NULL,
  palette = NULL
) {
  .rmbl_plot_check(x, "rmbl_distinctions")
  d <- x$groups
  z <- stats::qnorm(1 - (1 - x$conflvl) / 2)
  .bl_dot_interval(
    d$group,
    d$estimate,
    d$estimate - z * d$se,
    d$estimate + z * d$se,
    .bl_main(
      main,
      sprintf("Each group, and the pooled figure (I^2 = %.0f%%)", 100 * x$i2)
    ),
    "Estimate, with its published interval; dashed: pooled",
    .bl_cols(nrow(d), col, palette),
    ref = x$pooled,
    ...
  )
  invisible(d)
}

#' First Nations, Metis and Inuit health and mental health: bundled Statistics
#' Canada excerpts
#'
#' Small excerpts of Statistics Canada tables, bundled so that the examples and
#' vignettes run on published values without a network connection or a data
#' service key. Values are as published, with their 95% limits and quality
#' flags; nothing is imputed (suppressed cells are \code{NA}).
#'
#' \describe{ \item{\code{"health"}}{Table 13-10-0924-01, Health indicators for
#'   First Nations people living off reserve, Metis and Inuit, by age group and
#'   sex, four-year period estimates (Canadian Community Health Survey),
#'   2015/2018 and 2019/2022; Canada, both sexes, the 27 indicators by age
#'   group, with non-Indigenous people for comparison: the table behind The
#'   Daily of 2025-02-13. Columns \code{period}, \code{group}, \code{age},
#'   \code{indicator}, \code{estimate}, \code{lower}, \code{upper},
#'   \code{quality}.} \item{\code{"mentalhealth"}}{Table 41-10-0067-01,
#'   Self-perceived mental health of First Nations people living off reserve,
#'   Metis and Inuit by age group and gender, 2022 (Indigenous Peoples Survey);
#'   15 years and older, every region. Columns \code{region}, \code{group},
#'   \code{rating}, \code{estimate}, \code{lower}, \code{upper},
#'   \code{quality}.} \item{\code{"wellbeing"}}{Table 41-10-0082-01, Selected
#'   characteristics of well-being and impacts of rising prices by First Nations
#'   people living off reserve, Metis and Inuit, and gender, 2024; total of
#'   genders. Columns \code{group}, \code{indicator}, \code{estimate},
#'   \code{lower}, \code{upper}, \code{quality}.} \item{\code{"suiide"}}{Table
#'   41-10-0021-01, Self-perceived mental health and suicidal thoughts by
#'   Aboriginal identity, age group and sex, 2017 (Aboriginal Peoples Survey);
#'   Canada, both sexes, by age. Columns \code{group}, \code{age},
#'   \code{measure}, \code{estimate}, \code{lower}, \code{upper},
#'   \code{quality}.} \item{\code{"censuspop"}}{The Indigenous Population
#'   Profile, 2021 Census of Population (98-510-X2021001), Canada, the provinces
#'   and the territories, total of genders, on and off reserve: the population
#'   by age group, children and foster children, knowledge of Indigenous
#'   languages, highest certificate (25 and over), labour force status, income
#'   and low income, as published (read it with \code{\link{cnsprof}}).}
#'   \item{\code{"lifeexp"}}{Table 17-10-0160-01, Life expectancy at birth of
#'   Indigenous populations in Canada, 2006/2011 to 2016/2021, both sexes,
#'   Canada: First Nations (Registered or Treaty Indians, on and off reserve,
#'   and without registered status), Metis, Inuit and non-Indigenous people.
#'   Columns \code{period}, \code{group}, \code{measure}, \code{estimate},
#'   \code{lower}, \code{upper}, \code{quality}.} \item{\code{"infmort"}}{Table
#'   17-10-0161-01, Infant mortality rates of Indigenous populations in Canada
#'   (per 1,000 live births), 1994/1996 to 2014/2016, the same groups and
#'   columns.} \item{\code{"censushh"}}{The same profile's households and
#'   dwellings (98-510-X2021016), Indigenous and non-Indigenous households:
#'   persons per room, housing suitability, dwelling condition and core housing
#'   need.} }
#'
#' The First Nations figures of the survey excerpts are for First Nations people
#' living off reserve: the surveys do not cover reserves, whose data are
#' governed by First Nations (see the First Nations Information Governance
#' Centre). Groups are as the tables name them, with \dQuote{Inuk (Inuit)}
#' written \code{"Inuit"}.
#'
#' @param name Which excerpt.
#' @return A data frame.
#' @source Statistics Canada tables, each with its DOI: \itemize{ \item
#' 13-10-0924-01, \doi{10.25318/1310092401-eng}; \item 41-10-0067-01,
#' \doi{10.25318/4110006701-eng}; \item 41-10-0082-01,
#' \doi{10.25318/4110008201-eng}; \item 41-10-0021-01,
#' \doi{10.25318/4110002101-eng}; \item 17-10-0160-01,
#' \doi{10.25318/1710016001-eng}; \item 17-10-0161-01,
#' \doi{10.25318/1710016101-eng}. } Indigenous Population Profile, 2021 Census
#' of Population, catalogue 98-510-X2021001 and 98-510-X2021016. Reproduced and
#' distributed on an \dQuote{as is} basis with the permission of Statistics
#' Canada, under the Statistics Canada Open Licence:
#'
#' statcan.gc.ca/en/terms-conditions/open-licence
#'
#' Built by the scripts \code{indigenous_mental_health.R} and
#' \code{indigenous_census.R} in the \code{data-raw} folder of the source
#' package.
#' @seealso \code{\link{indtabs}} for the full tables at the data service.
#' @usage
#' indiex(
#'   name = c("health", "mentalhealth", "wellbeing", "suicide",
#'            "censuspop", "censushh", "lifeexp", "infantmort")
#' )
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' h <- indiex("health")
#' mh <- h[h$period == "2019/2022" & h$age == "Total, 18 years and over" &
#'           h$indicator == "Perceived mental health, very good or excellent", ]
#' plot(indgap(mh, "group", "estimate", "lower", "upper", qual = "quality"))
#' @export
indiex <- function(
  name = c(
    "health",
    "mentalhealth",
    "wellbeing",
    "suicide",
    "censuspop",
    "censushh",
    "lifeexp",
    "infantmort"
  )
) {
  name <- .rmbl_arg(name)
  files <- c(
    health = "health_indicators",
    mentalhealth = "mental_health",
    wellbeing = "wellbeing",
    suicide = "suicidal_ideation",
    censuspop = "census_population",
    censushh = "census_households",
    lifeexp = "life_expectancy",
    infantmort = "infant_mortality"
  )
  f <- system.file(
    "extdata",
    sprintf("indigenous_%s.csv", files[[name]]),
    package = "rmoriebricklayer",
    mustWork = TRUE
  )
  # the bytes are UTF-8 and are marked so; re-encoding to the native locale
  # (fileEncoding) cut the file at "Metis" with an accent in a C locale (the
  # C-locale CI cell)
  utils::read.csv(
    f,
    stringsAsFactors = FALSE,
    encoding = "UTF-8",
    check.names = FALSE
  )
}

# DGUID is not among them: it identifies the geography, and one place name can
# be several geographies ("Division No. 1" is a census division in four
# provinces; table 98-10-0293 has 290 such names)
.rmbl_statcan_meta <- c(
  "UOM",
  "UOM_ID",
  "SCALAR_FACTOR",
  "SCALAR_ID",
  "VECTOR",
  "COORDINATE",
  "Coordinate",
  "VALUE",
  "STATUS",
  "SYMBOL",
  "TERMINATED",
  "DECIMALS",
  "quality"
)

#' The domain levels of a holistic balance, one row per group.
#' @param x The holbal() result.
#' @param groups The groups, in the result's order.
#' @return A data frame, or NULL when the levels are not recorded.
#' @noRd
.an_hb_domains <- function(x, groups) {
  m <- attr(x, "domains")
  if (!is.matrix(m) || nrow(m) != length(groups)) {
    return(NULL)
  }
  out <- data.frame(group = groups, stringsAsFactors = FALSE)
  cbind(out, as.data.frame(unclass(m), row.names = NULL, optional = TRUE))
}

#' The weights of a holistic balance, as text.
#' @param w The named weights, or NULL.
#' @return One string, or NULL.
#' @noRd
.an_hb_weights <- function(w) {
  if (!length(w)) {
    return(NULL)
  }
  if (length(unique(w)) == 1L) {
    return(sprintf("equal, over %d domains", length(w)))
  }
  toString(sprintf("%s %s", names(w), format(signif(w, 3))))
}

#' Trims the text dimension columns of a tidy Statistics Canada table.
#' @param x The tidy table.
#' @param cols Its dimension columns.
#' @return `x`, its character and factor columns among `cols` trimmed text.
#' @noRd
.sce_trim <- function(x, cols) {
  for (d in cols) {
    if (is.character(x[[d]]) || is.factor(x[[d]])) {
      x[[d]] <- .rmbl_utf8(trimws(as.character(x[[d]])))
    }
  }
  x
}

#' The confidence level a table's statistic labels name, or 0.95.
#' @param low The statistic labels, in lower case.
#' @return The level, a proportion.
#' @noRd
.sce_conf <- function(low) {
  lv <- unique(regmatches(
    low,
    regexpr("[0-9.]+(?=% confidence)", low, perl = TRUE)
  ))
  if (length(lv) == 1L) as.numeric(lv) / 100 else 0.95
}

#' The measure each precision label belongs to.
#' @param lab The statistic labels.
#' @param rt Their roles and targets (.sce_roles()).
#' @param m What the matching shares.
#' @return A list: `bound_of` (each matched label's role and measure) and
#'   `unmatched` (the labels matched to no measure).
#' @noRd
.sce_bounds <- function(lab, rt, m) {
  # the measure a precision label belongs to: by its name, then by unit, then by
  # containing the estimates
  unmatched <- character()
  bound_of <- list()
  for (bl in unique(lab[rt$role != "estimate"])) {
    cand <- .sce_measure_of(bl, m)
    if (length(cand) == 1L) {
      bound_of[[bl]] <- c(role = rt$role[which(lab == bl)[1L]], measure = cand)
    } else {
      unmatched <- c(unmatched, bl)
    }
  }
  list(bound_of = bound_of, unmatched = unmatched)
}

#' scests()'s result: one row per estimate, with its interval.
#' @param x The tidy table.
#' @param e The rows of the estimates.
#' @param dims The dimension columns other than the statistic.
#' @param lab The statistic labels.
#' @param bd From .sce_bounds().
#' @param m What the matching shares.
#' @param conf The confidence level.
#' @return The estimates (a data frame).
#' @noRd
.sce_out <- function(x, e, dims, lab, bd, m, conf) {
  bound_of <- bd$bound_of
  out <- x[e, dims, drop = FALSE]
  out$measure <- lab[e]
  out$estimate <- x$VALUE[e]
  out$lower <- NA_real_
  out$upper <- NA_real_
  out$cisou <- NA_character_
  out <- .sce_intervals(out, bound_of, m, stats::qnorm(1 - (1 - conf) / 2))
  out$quality <- x$quality[e]
  gone <- !is.finite(out$estimate)
  out$lower[gone] <- out$upper[gone] <- NA_real_
  out$cisou[gone] <- NA_character_
  rownames(out) <- NULL
  attr(out, "conflvl") <- conf
  attr(out, "unmatched") <- bd$unmatched
  out
}

#' The column of a Statistics Canada table that names the statistic of each
#' row: a "Statistics" or "Characteristics" column, or one that names
#' intervals, coefficients of variation or standard errors.
#'
#' A "Characteristics" column of indicators beside a "Statistics" column of
#' measures: the "Statistics" one.
#' @param x The tidy table.
#' @param cols Its dimension columns.
#' @return A logical vector over `cols`, TRUE at most once.
#' @noRd
.sce_stat_cols <- function(x, cols) {
  is_stat <- vapply(
    cols,
    function(n) {
      v <- x[[n]]
      text <- is.character(v) || is.factor(v)
      (grepl("^(Statistics|Characteristics)\\b", n) && text) ||
        (text &&
          any(grepl(
            "confidence interval|coefficient of variation|standard error",
            v,
            ignore.case = TRUE
          )))
    },
    NA
  )
  if (sum(is_stat) > 1L) {
    named <- cols[is_stat][grepl("^Statistics", cols[is_stat])]
    is_stat[] <- cols %in%
      (if (length(named) == 1L) named else cols[is_stat][1L])
  }
  is_stat
}

#' A table with no statistic column: every row an estimate, without an
#' interval.
#' @param x The tidy table.
#' @param cols Its dimension columns.
#' @param uom The unit of each row.
#' @return The estimates.
#' @noRd
.sce_plain <- function(x, cols, uom) {
  out <- x[cols]
  out$measure <- uom
  out$estimate <- x$VALUE
  out$lower <- out$upper <- NA_real_
  out$cisou <- NA_character_
  out$quality <- x$quality
  rownames(out) <- NULL
  attr(out, "conflvl") <- 0.95
  attr(out, "unmatched") <- character()
  out
}

#' Each statistic label's role (estimate, lower, upper, cv or se) and the
#' measure it names.
#' @param low The labels, lower case.
#' @return A list: role and target.
#' @noRd
.sce_roles <- function(low) {
  role <- rep("estimate", length(low))
  target <- rep(NA_character_, length(low))
  pats <- list(
    lower = c(
      "^low [0-9.]+% confidence interval,? ?(.*)$",
      "^confidence interval lower bound,? ?(?:of )?(.*)$",
      "^[0-9.]+% confidence interval \\(lower limit\\),? ?(.*)$",
      "^[0-9.]+% confidence interval lower bound,? ?(.*)$"
    ),
    upper = c(
      "^high [0-9.]+% confidence interval,? ?(.*)$",
      "^confidence interval upper bound,? ?(?:of )?(.*)$",
      "^[0-9.]+% confidence interval \\(upper limit\\),? ?(.*)$",
      "^[0-9.]+% confidence interval upper bound,? ?(.*)$"
    ),
    cv = "^coefficient of variation,? ?(?:for |of )?(.*)$",
    se = "^standard error,? ?(?:for |of )?(.*)$"
  )
  for (r in names(pats)) {
    for (pt in pats[[r]]) {
      hit <- role == "estimate" & grepl(pt, low, perl = TRUE)
      role[hit] <- r
      target[hit] <- trimws(sub(pt, "\\1", low[hit], perl = TRUE))
    }
  }
  list(role = role, target = target)
}

#' The estimates a precision label may belong to: by its name, then by unit,
#' then (a limit) by the estimates it contains.
#' @param bl The label.
#' @param m What the matching shares (built in scests()).
#' @return The candidate measures (one when it is matched).
#' @noRd
.sce_measure_of <- function(bl, m) {
  i <- which(m$lab == bl)
  r <- m$role[i[1L]]
  t <- m$target[i[1L]]
  cand <- m$ests
  if (nzchar(t)) {
    exact <- m$ests[tolower(m$ests) == t]
    cand <- if (length(exact)) {
      exact
    } else {
      m$ests[grepl(t, tolower(m$ests), fixed = TRUE)]
    }
  }
  if (length(cand) > 1L && any(nzchar(m$uom))) {
    u <- unique(m$uom[i])
    by_u <- cand[vapply(cand, function(cn) any(m$uom[m$lab == cn] %in% u), NA)]
    if (length(by_u)) cand <- by_u
  }
  if (length(cand) > 1L && r %in% c("lower", "upper")) {
    # the other limit of the pair, if the table gives it: lower <= estimate <=
    # upper must hold together
    other <- unique(m$lab[
      m$role == setdiff(c("lower", "upper"), r) & m$target == t
    ])
    j <- if (length(other) == 1L) which(m$lab == other) else integer()
    fits <- vapply(cand, .sce_limit_fit, 0, i = i, j = j, r = r, m = m)
    cand <- cand[fits >= 0.95 & fits == max(fits)]
  }
  cand
}

#' The share of cells where a limit lies on its side of a candidate estimate
#' (and the other limit, when there is one, on its own side).
#'
#' A published table can hold cells whose limits miss their own estimate (a
#' 100% with limits 85.5 to 98.6, table 41-10-0012; 5 of 396 cells of table
#' 41-10-0015): the fit is judged on 95% of the cells, not all; the wrong
#' measure of a pair fails in nearly every cell.
#' @param cn The candidate measure.
#' @param i,j The rows of the limit and of the other limit.
#' @param r The limit's role.
#' @param m What the matching shares.
#' @return The share.
#' @noRd
.sce_limit_fit <- function(cn, i, j, r, m) {
  ev <- m$value[m$e][match(paste(m$key[i], cn, sep = "\r"), m$ekey)]
  bv <- m$value[i]
  ok <- is.finite(ev) & is.finite(bv)
  fit <- if (r == "lower") bv <= ev + 1e-9 else bv >= ev - 1e-9
  if (length(j)) {
    ov <- m$value[j][match(m$key[i], m$key[j])]
    ok <- ok & is.finite(ov)
    fit <- fit & (if (r == "lower") ov >= ev - 1e-9 else ov <= ev + 1e-9)
  }
  if (any(ok)) mean(fit[ok]) else 0
}

#' The estimates' intervals: published, or from a coefficient of variation
#' (log-normal), or from a standard error.
#' @param out The estimates.
#' @param bound_of Each precision label's role and measure.
#' @param m What the matching shares.
#' @param z The normal quantile of the confidence level, for the bounds.
#' @return The estimates with lower, upper and cisou.
#' @noRd
.sce_intervals <- function(out, bound_of, m, z) {
  cv <- se <- rep(NA_real_, length(m$e))
  for (bl in names(bound_of)) {
    i <- which(m$lab == bl)
    hit <- match(
      paste(m$key[i], bound_of[[bl]][["measure"]], sep = "\r"),
      m$ekey
    )
    ok <- !is.na(hit)
    v <- m$value[i][ok]
    role <- bound_of[[bl]][["role"]]
    if (identical(role, "lower")) {
      out$lower[hit[ok]] <- v
    } else if (identical(role, "upper")) {
      out$upper[hit[ok]] <- v
    } else if (identical(role, "cv")) {
      cv[hit[ok]] <- v
    } else if (identical(role, "se")) {
      se[hit[ok]] <- v
    }
  }
  pub <- is.finite(out$lower) & is.finite(out$upper)
  out$cisou[pub] <- "published"
  odd <- pub &
    is.finite(out$estimate) &
    (out$lower > out$estimate | out$upper < out$estimate)
  out$cisou[odd] <- "inconsistent"
  from_cv <- !pub & is.finite(cv) & is.finite(out$estimate)
  sl <- sqrt(log(1 + (cv[from_cv] / 100)^2))
  out$lower[from_cv] <- out$estimate[from_cv] * exp(-z * sl)
  out$upper[from_cv] <- out$estimate[from_cv] * exp(z * sl)
  out$cisou[from_cv] <- "cv"
  from_se <- !pub & !from_cv & is.finite(se) & is.finite(out$estimate)
  out$lower[from_se] <- out$estimate[from_se] - z * se[from_se]
  out$upper[from_se] <- out$estimate[from_se] + z * se[from_se]
  out$cisou[from_se] <- "se"
  out
}

#' ordcmp()'s columns and categories, checked.
#' @param data As for ordcmp().
#' @param cols The column arguments, by name.
#' @param qual,lvls As for ordcmp().
#' @return The quality column's name, or NULL.
#' @noRd
.oc_check_args <- function(data, cols, qual, lvls) {
  if (!is.data.frame(data)) {
    stop("ordcmp: `data` must be a data frame", call. = FALSE)
  }
  for (nm in names(cols)) {
    v <- .rmbl_string1(cols[[nm]], nm)
    if (!v %in% names(data)) {
      stop(sprintf("ordcmp: column `%s` not found in `data`", v), call. = FALSE)
    }
  }
  if (!is.null(qual)) {
    qual <- .rmbl_string1(qual, "qual")
    if (!qual %in% names(data)) {
      stop(
        sprintf("ordcmp: column `%s` not found in `data`", qual),
        call. = FALSE
      )
    }
  }
  .rmbl_no_fn(lvls = lvls)
  if (
    !is.character(lvls) ||
      length(lvls) < 2L ||
      anyNA(lvls) ||
      anyDuplicated(lvls)
  ) {
    stop(
      .rmbl_fn(),
      "`lvls` must be two or more distinct categories, from the lowest ",
      "to the highest",
      call. = FALSE
    )
  }
  qual
}

#' One group's distribution over the categories, and its effective sample
#' size from the intervals.
#' @param i The group's rows in a category of `lvls`.
#' @param gi The group's label, named in the error.
#' @param .cat,.est,lo,hi,q The categories, estimates, limits and quality
#'   flags.
#' @param lvls The categories, lowest first.
#' @param z The normal quantile.
#' @return A list (p, neff, caution), or NULL when the group is not compared.
#' @noRd
.oc_group <- function(i, gi, .cat, lvls, .est, lo, hi, q, z) {
  if (anyDuplicated(.cat[i])) {
    stop(
      .rmbl_fn(),
      sprintf("group \"%s\" has a category twice", gi),
      call. = FALSE
    )
  }
  i <- i[match(lvls, .cat[i])]
  if (
    anyNA(i) ||
      any(q[i] %in% c("F", "x", "..", "...")) ||
      !all(is.finite(.est[i]))
  ) {
    return(NULL)
  }
  if (any(lo[i] > .est[i] | hi[i] < .est[i], na.rm = TRUE)) {
    warning(
      sprintf(
        "an interval of \"%s\" does not contain its estimate; not compared",
        gi
      ),
      call. = FALSE
    )
    return(NULL)
  }
  p <- .est[i] / sum(.est[i])
  s <- (hi[i] - lo[i]) / (2 * z) / sum(.est[i])
  ok <- is.finite(s) & s > 0 & p > 0 & p < 1
  list(
    p = p,
    neff = if (any(ok)) {
      stats::median(p[ok] * (1 - p[ok]) / s[ok]^2)
    } else {
      NA_real_
    },
    caution = any(q[i] == "E")
  )
}

#' One group's probability of a higher category than the reference group, with
#' its interval on the logit scale.
#' @param gi The group's label for the row.
#' @param p1 Its distribution.
#' @param q0 The reference group's distribution.
#' @param g0 The reference's mid-ranks.
#' @param n1,n0 The two effective sample sizes.
#' @param z The normal quantile.
#' @return A one-row data frame.
#' @noRd
.oc_row <- function(gi, p1, q0, g0, n1, n0, z) {
  if (anyNA(p1)) {
    return(data.frame(
      group = gi,
      probbet = NA_real_,
      lower = NA_real_,
      upper = NA_real_
    ))
  }
  k <- length(p1)
  a <- sum(p1 * g0)
  above1 <- rev(c(0, cumsum(rev(p1)))[seq_len(k)])
  g1 <- above1 + p1 / 2
  v <- (sum(p1 * g0^2) - a^2) / n1 + (sum(q0 * g1^2) - a^2) / n0
  if (!is.finite(v) || a <= 0 || a >= 1) {
    return(data.frame(
      group = gi,
      probbet = a,
      lower = NA_real_,
      upper = NA_real_
    ))
  }
  sl <- sqrt(v) / (a * (1 - a))
  data.frame(
    group = gi,
    probbet = a,
    lower = stats::plogis(stats::qlogis(a) - z * sl),
    upper = stats::plogis(stats::qlogis(a) + z * sl)
  )
}

#' The shares of each group's categories, its effective sample size and
#' whether any of its estimates is to be used with caution.
#' @param groups The groups.
#' @param g,.cat,.est,lo,hi,q The rows' group, category, estimate, limits and
#'   quality flag.
#' @param lvls The categories, in order.
#' @param z The normal quantile of the confidence level, for the bounds.
#' @return A list: `sh` (a groups-by-categories matrix), `neff` and `caution`.
#' @noRd
.oc_shares <- function(groups, g, .cat, lvls, .est, lo, hi, q, z) {
  sh <- matrix(
    NA_real_,
    length(groups),
    length(lvls),
    dimnames = list(groups, lvls)
  )
  neff <- stats::setNames(rep(NA_real_, length(groups)), groups)
  caution <- stats::setNames(rep(FALSE, length(groups)), groups)
  for (gi in groups) {
    r <- .oc_group(
      which(g == gi & .cat %in% lvls),
      gi,
      .cat,
      lvls,
      .est,
      lo,
      hi,
      q,
      z
    )
    if (is.null(r)) {
      next
    }
    sh[gi, ] <- r$p
    neff[[gi]] <- r$neff
    caution[[gi]] <- r$caution
  }
  list(sh = sh, neff = neff, caution = caution)
}

#' ordcmp()'s result from the rows of each group against the reference.
#' @param out The rows (.oc_row()), bound.
#' @param ref The reference group's label.
#' @param neff,caution Each group's effective sample size and caution flag.
#' @param pooled As for ordcmp().
#' @param sh The shares (.oc_shares()).
#' @param conflvl The confidence level, stored as an attribute.
#' @return A data frame of class `rmbl_ordinal_compare`.
#' @noRd
.oc_result <- function(out, ref, neff, caution, pooled, sh, conflvl) {
  out <- data.frame(
    group = out$group,
    reference = ref,
    probbet = out$probbet,
    lower = out$lower,
    upper = out$upper,
    delta = 2 * out$probbet - 1,
    neff = unname(neff[out$group]),
    neffref = unname(neff[[ref]]),
    usewithcau = unname(caution[out$group]) | caution[[ref]],
    poogrp = .rmbl_pan_indigenous(out$group, pooled),
    stringsAsFactors = FALSE
  )
  attr(out, "shares") <- sh
  attr(out, "conflvl") <- conflvl
  class(out) <- c("rmbl_ordinal_compare", "data.frame")
  out
}

#' Refuses a standard population that is not non-negative counts, not all zero.
#' @param std The standard population's counts.
#' @return `std`, invisibly.
#' @noRd
.sp_check_std <- function(std) {
  if (!length(std) || anyNA(std) || any(std < 0) || sum(std) <= 0) {
    stop(
      "stdprev: `std` must be non-negative counts, one per age group, ",
      "not all zero",
      call. = FALSE
    )
  }
  invisible(std)
}

#' stdprev()'s group labels and quality flags, one per row.
#' @param grp,qual As for stdprev().
#' @param n The number of rows, the length `grp` and `qual` must have.
#' @return A list: `grp` and `q` (the flags, through .rmbl_qflags()).
#' @noRd
.sp_grp_qual <- function(grp, qual, n) {
  if (is.null(grp)) {
    grp <- rep("all", n)
  }
  .rmbl_no_fn(grp = grp, qual = qual)
  grp <- as.character(grp)
  if (length(grp) != n) {
    stop("stdprev: `grp` must have one label per row", call. = FALSE)
  }
  q <- if (is.null(qual)) rep("ok", n) else as.character(qual)
  if (length(q) != n) {
    stop(.rmbl_fn(), "`qual` must have one flag per row", call. = FALSE)
  }
  list(grp = grp, q = .rmbl_qflags(q))
}

#' The estimates with those outside their own interval dropped, and a warning
#' that says how many.
#' @param .est,lo,hi The estimates and their limits.
#' @return The estimates, NA where an interval does not contain its estimate.
#' @noRd
.sp_drop_bad <- function(.est, lo, hi) {
  bad <- is.finite(lo) &
    is.finite(hi) &
    is.finite(.est) &
    (lo > .est | hi < .est)
  if (any(bad)) {
    warning(
      sprintf(
        paste0(
          "%d interval(s) do not contain their estimate; their groups are ",
          "not standardised"
        ),
        sum(bad)
      ),
      call. = FALSE
    )
    .est[bad] <- NA_real_
  }
  .est
}

#' One group's age-standardised estimate.
#' @param gi The group's label for the row.
#' @param i Its rows.
#' @param k The number of age groups.
#' @param q,.est,lo,hi The rows' quality flags, estimates and limits.
#' @param w The standard population's weights.
#' @param z The normal quantile of the confidence level, for the bounds.
#' @param scale The upper bound of the scale.
#' @return A one-row data frame.
#' @noRd
.sp_group <- function(gi, i, k, q, .est, lo, hi, w, z, scale) {
  if (length(i) != k) {
    stop(
      sprintf(
        "stdprev: group \"%s\" has %d age groups; `std` has %d",
        gi,
        length(i),
        k
      ),
      call. = FALSE
    )
  }
  gone <- q[i] %in%
    c("F", "x", "..", "...") |
    !is.finite(.est[i]) |
    !is.finite(lo[i]) |
    !is.finite(hi[i])
  if (any(gone)) {
    return(data.frame(
      group = gi,
      estimate = NA_real_,
      lower = NA_real_,
      upper = NA_real_,
      se = NA_real_,
      usewithcau = FALSE
    ))
  }
  y <- sum(w * .est[i])
  se <- sqrt(sum(w^2 * ((hi[i] - lo[i]) / (2 * z))^2))
  data.frame(
    group = gi,
    estimate = y,
    lower = max(0, y - z * se),
    upper = min(scale, y + z * se),
    se = se,
    usewithcau = any(q[i] == "E")
  )
}

#' Draws the Calls to Action completed and the paces projected from them.
#' @param x An `rmbl_trc_progress`.
#' @param h Its history.
#' @param total The number of Calls to Action.
#' @param t1,far The last year of the history and the plot's last year.
#' @param cols The colours: the history's, then the projection's.
#' @return NULL, invisibly.
#' @noRd
.imh_trc_draw <- function(x, h, total, t1, far, cols) {
  # the band between the projections at the interval's two ends of the rate
  yr <- function(r, t) pmin(total, x$completed + r * (t - t1))
  ts <- seq(t1, far, length.out = 200)
  graphics::polygon(
    c(ts, rev(ts)),
    c(yr(x$rateup, ts), rev(yr(x$ratelo, ts))),
    col = grDevices::adjustcolor(cols[2L], 0.18),
    border = NA
  )
  graphics::lines(ts, yr(x$rate, ts), col = cols[2L], lwd = 1.6, lty = 2)
  graphics::lines(h$year, h$completed, type = "s", col = cols[1L], lwd = 2.2)
  graphics::points(
    h$year,
    h$completed,
    pch = 21,
    bg = cols[1L],
    col = "white",
    cex = 1.4
  )
  if (is.finite(x$cmplby) && x$cmplby <= far) {
    graphics::text(
      x$cmplby,
      total,
      sprintf("all %d by %.0f at this pace", round(total), x$cmplby),
      adj = c(1.05, 1.6),
      cex = 0.8,
      col = cols[2L]
    )
  }
  invisible(NULL)
}

#' welprof()'s column arguments, checked.
#' @param data The data frame given to welprof().
#' @param cols The column arguments, by name.
#' @param qual The quality column's name, or NULL.
#' @return `qual`, checked.
#' @noRd
.wp_check_cols <- function(data, cols, qual) {
  for (nm in names(cols)) {
    v <- .rmbl_string1(cols[[nm]], nm)
    if (!v %in% names(data)) {
      stop(
        sprintf("welprof: column `%s` not found in `data`", v),
        call. = FALSE
      )
    }
  }
  if (!is.null(qual)) {
    qual <- .rmbl_string1(qual, "qual")
    if (!qual %in% names(data)) {
      stop(
        sprintf("welprof: column `%s` not found in `data`", qual),
        call. = FALSE
      )
    }
  }
  qual
}

#' welprof()'s wellness and distress indicators and domains, checked.
#' @param well,distress,domain As for welprof().
#' @param .ind The indicators of `data`.
#' @return A list: `well` and `distress`, trimmed.
#' @noRd
.wp_check_inds <- function(well, distress, .ind, domain) {
  for (nm in c("well", "distress")) {
    v <- if (nm == "well") well else distress
    if (!is.character(v) || !length(v) || anyNA(v)) {
      stop(
        .rmbl_fn(),
        sprintf("`%s` must name indicators of `data`", nm),
        call. = FALSE
      )
    }
  }
  well <- .rmbl_utf8(trimws(well))
  distress <- .rmbl_utf8(trimws(distress))
  if (length(intersect(well, distress))) {
    stop(
      .rmbl_fn(),
      "an indicator cannot be both one of wellness and one of distress",
      call. = FALSE
    )
  }
  miss <- setdiff(c(well, distress), .ind)
  if (length(miss)) {
    stop(
      sprintf(
        "welprof: not an indicator of `data`: %s",
        toString(miss)
      ),
      call. = FALSE
    )
  }
  if (!is.null(domain) && (!is.character(domain) || is.null(names(domain)))) {
    stop(
      .rmbl_fn(),
      "`domain` must be a named character vector: indicator = domain",
      call. = FALSE
    )
  }
  list(well = well, distress = distress)
}

#' A wellness profile in its order: wellness first, each indicator in the
#' order given, the groups in their order of appearance.
#' @param out The profile's rows.
#' @param ilev The indicators, wellness then distress.
#' @return A data frame of class `rmbl_wellness_profile`.
#' @noRd
.wp_order <- function(out, ilev) {
  o <- order(
    out$side != "wellness",
    match(out$indicator, ilev),
    match(out$group, unique(out$group))
  )
  out <- out[o, , drop = FALSE]
  rownames(out) <- NULL
  class(out) <- c("rmbl_wellness_profile", "data.frame")
  out
}

#' The x range of the wellness profile plot: the estimates and their intervals,
#' padded.
#' @param d The profile, as a data frame.
#' @return Two numbers.
#' @noRd
.imh_wp_range <- function(d) {
  vals <- c(d$lower, d$upper, d$estimate)
  vals <- vals[is.finite(vals)]
  # the range of the estimates and their intervals, padded: anchored at 0 the
  # points sat in a corner of an empty panel
  if (length(vals)) {
    range(vals) + c(-1, 1) * 0.06 * max(diff(range(vals)), 1)
  } else {
    c(0, 100)
  }
}

#' Draws the line between the wellness and the distress indicators of the
#' wellness profile plot, and names the two sections.
#' @param side Each indicator's side, top to bottom.
#' @return NULL, invisibly.
#' @noRd
.imh_wp_sections <- function(side) {
  inds <- side
  nw <- sum(side == "wellness")
  if (nw && nw < length(inds)) {
    graphics::abline(h = length(inds) - nw + 0.5, col = "#8C8C8C", lty = 3)
  }
  # the two sections named at the right edge: wellness above the line, distress
  # below
  usr <- graphics::par("usr")
  if (nw) {
    graphics::text(
      usr[2L],
      length(inds) + 0.45,
      "wellness",
      adj = c(1, 1),
      cex = 0.75,
      font = 3,
      col = "#6E6E6E"
    )
  }
  if (nw < length(inds)) {
    graphics::text(
      usr[2L],
      length(inds) - nw + 0.45,
      "distress",
      adj = c(1, 1),
      cex = 0.75,
      font = 3,
      col = "#6E6E6E"
    )
  }
  invisible(NULL)
}

#' Draws each group's estimates and intervals on the wellness profile plot.
#' @param d The profile, as a data frame.
#' @param y Each row's position.
#' @param gc Each row's colour.
#' @return NULL, invisibly.
#' @noRd
.imh_wp_marks <- function(d, y, gc) {
  ok <- is.finite(d$lower) & is.finite(d$upper)
  if (any(ok)) {
    graphics::segments(
      d$lower[ok],
      y[ok],
      d$upper[ok],
      y[ok],
      col = gc[ok],
      lwd = 2,
      lend = 1
    )
  }
  graphics::points(
    d$estimate,
    y,
    pch = ifelse(d$usewithcau, 1, 19),
    col = gc,
    cex = 1.2
  )
  invisible(NULL)
}

#' A column of `data` named by a string argument, checked
#' @param data The data frame that must have column `x`.
#' @param x The column name passed by the user.
#' @param what The argument's name, quoted if column `x` is invalid.
#' @return The column name.
#' @noRd
.rmbl_col <- function(data, x, what) {
  x <- .rmbl_string1(x, what)
  if (!x %in% names(data)) {
    stop(
      .rmbl_fn(),
      sprintf("column `%s` not found in `data`", x),
      call. = FALSE
    )
  }
  x
}

#' holbal()'s domain weights, checked: non-negative, named by the domains, not
#' all zero; equal by default.
#' @param w As for holbal().
#' @param doms The domains.
#' @return The weights, summing to one.
#' @noRd
.hb_weights <- function(w, doms) {
  if (is.null(w)) {
    w <- stats::setNames(rep(1, length(doms)), doms)
  } else {
    .rmbl_no_fn(w = w)
    if (
      !is.numeric(w) ||
        is.null(names(w)) ||
        !setequal(names(w), doms) ||
        anyNA(w) ||
        any(w < 0) ||
        sum(w) <= 0
    ) {
      stop(
        sprintf(
          paste0(
            "`w` must be non-negative numbers named by the domains (%s), ",
            "not all zero"
          ),
          toString(doms)
        ),
        call. = FALSE
      )
    }
  }
  w[doms] / sum(w[doms])
}

#' One group's weighted level and balance, with simulated intervals.
#' @param gi The group's label for the row.
#' @param p,s Its domain levels and their standard errors.
#' @param .w The domain weights.
#' @param reps The number of simulation draws.
#' @param a The tail probability.
#' @param z The normal quantile.
#' @param doms The domains.
#' @return A one-row data frame.
#' @noRd
.hb_row <- function(gi, p, s, .w, reps, a, z, doms) {
  bal <- function(p) exp(sum(.w * log(p))) / sum(.w * p)
  if (anyNA(p) || anyNA(s)) {
    return(data.frame(
      group = gi,
      level = NA_real_,
      lvllo = NA_real_,
      lvlup = NA_real_,
      balance = NA_real_,
      ballo = NA_real_,
      balup = NA_real_,
      weadom = NA_character_
    ))
  }
  sl <- s / (p * (1 - p))
  dr <- stats::plogis(
    matrix(stats::qlogis(p), reps, length(p), byrow = TRUE) +
      matrix(stats::rnorm(reps * length(p)), reps) * rep(sl, each = reps)
  )
  bb <- exp(drop(log(dr) %*% .w)) / drop(dr %*% .w)
  lv <- sum(.w * p)
  lse <- sqrt(sum(.w^2 * s^2))
  # B is at most 1 and reaches 1 only at equal levels, so noise tends to pull
  # the draws below B-hat (B is not concave): the percentile interval is
  # shifted back by the draws' mean bias, kept inside (0, 1], and made to
  # contain B-hat
  b0 <- bal(p)
  bias <- mean(bb) - b0
  b_lo <- min(b0, max(0, unname(stats::quantile(bb, a)) - bias))
  b_hi <- max(b0, min(1, unname(stats::quantile(bb, 1 - a)) - bias))
  data.frame(
    group = gi,
    level = 100 * lv,
    lvllo = 100 * max(0, lv - z * lse),
    lvlup = 100 * min(1, lv + z * lse),
    balance = b0,
    ballo = b_lo,
    balup = b_hi,
    weadom = doms[which.min(p)]
  )
}

#' holbal()'s result from each group's row.
#' @param out The groups' rows, bound.
#' @param lv From .hb_levels().
#' @param .w The domains' weights.
#' @param conflvl The confidence level, stored as an attribute.
#' @return A data frame of class `rmbl_holistic_balance`.
#' @noRd
.hb_result <- function(out, lv, .w, conflvl) {
  out$usewithcau <- unname(lv$caution[out$group])
  attr(out, "domains") <- 100 * lv$lev
  attr(out, "weights") <- .w
  attr(out, "conflvl") <- conflvl
  class(out) <- c("rmbl_holistic_balance", "data.frame")
  out
}

#' Refuses estimates that look like proportions rather than percentages.
#' @param raw The estimates.
#' @return `raw`, invisibly.
#' @noRd
.hb_check_pct <- function(raw) {
  if (any(is.finite(raw)) && all(raw[is.finite(raw)] <= 1)) {
    stop(
      .rmbl_fn(),
      "the estimates are all at or below 1: are they proportions? give ",
      "percentages (0 to 100)",
      call. = FALSE
    )
  }
  invisible(raw)
}

#' Each group's level in each domain, its standard error, and whether any of
#' the group's estimates is to be used with caution.
#' @param groups,doms The groups and the domains.
#' @param g,dm,.est,se,q The rows' group, domain, estimate (a proportion), its
#'   standard error and quality flag.
#' @return A list: `lev` and `sem` (groups-by-domains matrices) and `caution`.
#' @noRd
.hb_levels <- function(groups, doms, g, dm, .est, se, q) {
  lev <- sem <- matrix(
    NA_real_,
    length(groups),
    length(doms),
    dimnames = list(groups, doms)
  )
  caution <- stats::setNames(rep(FALSE, length(groups)), groups)
  for (gi in groups) {
    for (dk in doms) {
      i <- which(g == gi & dm == dk)
      if (!length(i) || anyNA(.est[i])) {
        next
      }
      lev[gi, dk] <- mean(.est[i])
      sem[gi, dk] <- sqrt(sum(se[i]^2)) / length(i)
    }
    caution[[gi]] <- any(q[g == gi & dm %in% doms] == "E")
  }
  if (any(lev <= 0 | lev >= 1, na.rm = TRUE)) {
    stop(
      .rmbl_fn(),
      "domain levels must be percentages strictly between 0 and 100",
      call. = FALSE
    )
  }
  list(lev = lev, sem = sem, caution = caution)
}

#' Refuses indicators that are not one wellness and one distress indicator of
#' a wellness profile.
#' @param x A welprof().
#' @param well,distress The two indicators.
#' @return NULL, invisibly.
#' @noRd
.dc_check <- function(x, well, distress) {
  if (!well %in% x$indicator[x$side == "wellness"]) {
    stop(
      .rmbl_fn(),
      sprintf("\"%s\" is not a wellness indicator of `x`", well),
      call. = FALSE
    )
  }
  if (!distress %in% x$indicator[x$side == "distress"]) {
    stop(
      .rmbl_fn(),
      sprintf("\"%s\" is not a distress indicator of `x`", distress),
      call. = FALSE
    )
  }
  invisible(NULL)
}

#' dualcont()'s result from the two indicators.
#' @param x A welprof().
#' @param well,distress The two indicators.
#' @param conflvl The confidence level of the contrasts.
#' @return A data frame of class `rmbl_dual_continuum`.
#' @noRd
.dc_result <- function(x, well, distress, conflvl) {
  z <- stats::qnorm(1 - (1 - conflvl) / 2)
  groups <- unique(x$group)
  pick <- function(ind, col) {
    x[[col]][x$indicator == ind][match(groups, x$group[x$indicator == ind])]
  }
  w <- pick(well, "estimate")
  d <- pick(distress, "estimate")
  slog <- function(ind) {
    lo <- pick(ind, "lower")
    hi <- pick(ind, "upper")
    ifelse(lo > 0 & hi > 0, (log(hi) - log(lo)) / (2 * z), NA_real_)
  }
  r <- w / d
  sr <- sqrt(slog(well)^2 + slog(distress)^2)
  cw <- pick(well, "usewithcau")
  cd <- pick(distress, "usewithcau")
  ok <- is.finite(r) & r > 0
  out <- data.frame(
    group = groups,
    wellness = w,
    wello = pick(well, "lower"),
    welup = pick(well, "upper"),
    distress = d,
    distrlo = pick(distress, "lower"),
    distrup = pick(distress, "upper"),
    strratio = ifelse(ok, r, NA_real_),
    ratiolo = ifelse(ok, exp(log(r) - z * sr), NA_real_),
    ratioup = ifelse(ok, exp(log(r) + z * sr), NA_real_),
    usewithcau = (cw & !is.na(cw)) | (cd & !is.na(cd)),
    stringsAsFactors = FALSE
  )
  attr(out, "labels") <- c(wellness = well, distress = distress)
  class(out) <- c("rmbl_dual_continuum", "data.frame")
  out
}

#' dstntst()'s result: Cochran's Q and I^2 over the groups used.
#' @param g,y,s The rows' groups, estimates and standard errors.
#' @param use The rows used.
#' @param conflvl The confidence level of the group intervals, kept with them.
#' @return A list of class `rmbl_distinctions`.
#' @noRd
.dt_result <- function(g, y, s, use, conflvl) {
  w <- 1 / s[use]^2
  pooled_est <- sum(w * y[use]) / sum(w)
  qs <- sum(w * (y[use] - pooled_est)^2)
  df <- sum(use) - 1L
  out <- list(
    groups = data.frame(
      group = g[use],
      estimate = y[use],
      se = s[use],
      stringsAsFactors = FALSE
    ),
    pooled = pooled_est,
    poose = sqrt(1 / sum(w)),
    q = qs,
    df = df,
    p_value = stats::pchisq(qs, df, lower.tail = FALSE),
    i2 = if (qs > 0) max(0, (qs - df) / qs) else 0,
    leftout = g[!use],
    conflvl = conflvl
  )
  class(out) <- "rmbl_distinctions"
  out
}

#' The legend of the holistic balance plot: each group and its balance.
#' @param x An `rmbl_holistic_balance`.
#' @param lev The domain levels drawn.
#' @param cols The groups' colours.
#' @return NULL, invisibly.
#' @noRd
.imh_hb_legend <- function(x, lev, cols) {
  b <- x$balance[match(rownames(lev), x$group)]
  .bl_legend_below(
    ncol = min(2L, nrow(lev)),
    bty = "n",
    cex = 0.75,
    col = cols,
    lwd = 2,
    text.col = "#3D4350",
    legend = sprintf("%s (balance %.2f)", rownames(lev), b),
    line = 0.2
  )
  invisible(NULL)
}

#' Draws the web of the holistic balance plot: the rings, a spoke per domain
#' and the domains' names.
#' @param doms The domains.
#' @param ang Each spoke's angle.
#' @return NULL, invisibly.
#' @noRd
.imh_hb_web <- function(doms, ang) {
  k <- length(doms)
  for (r in c(0.25, 0.5, 0.75, 1)) {
    graphics::polygon(
      r * cos(seq(0, 2 * pi, length.out = 100)),
      r * sin(seq(0, 2 * pi, length.out = 100)),
      border = "#D5D8DD",
      lty = if (r == 1) 1 else 3
    )
  }
  graphics::segments(0, 0, cos(ang), sin(ang), col = "#D5D8DD")
  wrapped <- vapply(
    doms,
    function(s) paste(strwrap(s, 22), collapse = "\n"),
    ""
  )
  # each label leans away from the circle: left of a spoke on the left, above
  # one at the top
  for (j in seq_len(k)) {
    graphics::text(
      1.06 * cos(ang[j]),
      1.06 * sin(ang[j]),
      wrapped[[j]],
      cex = 0.75,
      col = "#3D4350",
      adj = c(
        0.5 - 0.5 * sign(round(cos(ang[j]), 6)),
        0.5 - 0.5 * sign(round(sin(ang[j]), 6))
      )
    )
  }
  invisible(NULL)
}

#' Draws each group's point and its two intervals on the dual continuum plot.
#' @param d The dual continuum, as a data frame.
#' @param cols Each group's colour.
#' @return NULL, invisibly.
#' @noRd
.imh_dc_marks <- function(d, cols) {
  graphics::segments(
    d$distrlo,
    d$wellness,
    d$distrup,
    d$wellness,
    col = cols,
    lwd = 1.6
  )
  graphics::segments(
    d$distress,
    d$wello,
    d$distress,
    d$welup,
    col = cols,
    lwd = 1.6
  )
  graphics::points(
    d$distress,
    d$wellness,
    pch = 21,
    bg = cols,
    col = "white",
    cex = 1.8
  )
  graphics::text(
    d$distress,
    d$wellness,
    d$group,
    pos = 3,
    offset = 0.9,
    cex = 0.8,
    col = cols
  )
  invisible(NULL)
}

#' Sets the graphics parameters of the plots in this file.
#' @param o The plot options from .bl_plot_opts(), such as `cex` and `bg`.
#' @param las The axis label style.
#' @param mar The margins.
#' @return The parameters as they were, for graphics::par().
#' @noRd
.imh_par <- function(o, las, mar) {
  # every value saved before any is set: setting fg sets col too, so col read
  # after fg was already the frame's grey
  op <- graphics::par(c(
    "las",
    "cex",
    "bg",
    "bty",
    "tcl",
    "mgp",
    "col.axis",
    "fg",
    "col",
    "mar"
  ))
  graphics::par(
    las = las,
    cex = o$cex,
    bg = o$bg,
    bty = "n",
    tcl = -0.2,
    mgp = c(3, 0.55, 0),
    col.axis = "#3D4350",
    fg = "#8A909A",
    col = "#1F2430",
    mar = mar
  )
  op
}
