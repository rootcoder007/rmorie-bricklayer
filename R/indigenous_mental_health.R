# SPDX-License-Identifier: AGPL-3.0-or-later
#
# First Nations, Metis and Inuit mental health and wellbeing from Statistics Canada's published
# tables: the estimates and their limits taken out of a table's statistics column, rated scales
# (perceived mental health, life satisfaction) compared as whole distributions, survey percentages
# standardised by age, and a plot for every result.

# DGUID is not among them: it identifies the geography, and one place name can be several geographies
# ("Division No. 1" is a census division in four provinces; table 98-10-0293 has 290 such names)
.rmbl_statcan_meta <- c("UOM", "UOM_ID", "SCALAR_FACTOR", "SCALAR_ID", "VECTOR", "COORDINATE", "Coordinate",
                        "VALUE", "STATUS", "SYMBOL", "TERMINATED", "DECIMALS", "quality")

#' The estimates of a Statistics Canada table, with their confidence limits
#'
#' Statistics Canada's tables give each estimate on several rows: the estimate itself (a
#' percent, a rate, a count, a life expectancy), its low and high confidence limits, or
#' its coefficient of variation or standard error, all in one statistics column
#' (\code{Statistics}, \code{Characteristics}, \code{Statistics (3)}, ...). This puts them
#' side by side, one row per cell of the table and measure, ready for
#' \code{\link{indgap}}, \code{\link{ordcmp}},
#' \code{\link{stdprev}} and the rest. Every table reads: one without a
#' statistics column (a census count) gives each value as its own estimate, with no
#' limits.
#'
#' @details Each label of the statistics column is read as an estimate or as one of its
#' measures of precision, in every form the tables use:
#' \itemize{
#'   \item \code{"Low 95\% confidence interval"};
#'   \item \code{"High 95\% confidence interval, age-standardized rate"};
#'   \item \code{"Confidence interval lower bound of count"};
#'   \item \code{"95\% confidence interval (upper limit)"};
#'   \item \code{"95\% confidence interval lower bound, 2020"};
#'   \item \code{"Coefficient of variation for percent"};
#'   \item \code{"Standard error"}.
#' }
#' A limit that
#' names its measure is matched to it (ignoring case and spacing); one that names none, or
#' a name that fits several measures (\code{"potential years of life lost"} in a table
#' with a number, a crude rate and an age-standardised rate of them), is matched to the
#' measure with the same unit (\code{UOM}) whose estimates it contains in every cell, and
#' left unmatched (said in the attribute \code{unmatched}) if no single measure fits. A
#' coefficient of variation \eqn{c} (in percent) gives log-normal limits
#' \eqn{e \exp(\mp z \sqrt{\log(1 + (c/100)^2)})}, which stay positive however large
#' \eqn{c} is; a standard error \eqn{s} the limits \eqn{e \mp z s}; the column
#' \code{cisou} says which (\code{"published"}, \code{"cv"} or \code{"se"}). Published
#' limits that do not contain their own estimate (it happens: a 100% with limits 85.5 to
#' 98.6 in table 41-10-0012) are kept as published and marked \code{"inconsistent"}; every
#' comparison of the family warns and leaves such a row out. A limit is matched to a
#' measure when it fits 95% of the cells. Labels are read in English: use the
#' English-language tables.
#'
#' Every other column but the metadata (\code{VECTOR}, \code{COORDINATE}, \code{UOM}, ...)
#' identifies the cell, \code{DGUID} among them (one place name can name several
#' geographies), with the spaces some labels end in trimmed. The quality flag is the
#' estimate's: an \code{F} or \code{x} estimate is \code{NA} (see
#' \code{\link{sctidy}}), and so are its limits.
#'
#' @param x A table read by \code{\link{sctidy}}, a data frame as downloaded, or a
#'   table key.
#' @return A data frame, one row per cell and measure: the identifying columns,
#'   \code{measure}, \code{estimate}, \code{lower}, \code{upper}, \code{cisou} and
#'   \code{quality}; the attribute \code{conflvl} is the level of the limits, and
#'   \code{unmatched} names any limits that could not be matched to one measure.
#' @references Statistics Canada (2023). Self-perceived mental health of First Nations
#'   people living off reserve, Metis and Inuit by age group and gender. Table
#'   41-10-0067-01.
#' \doi{10.25318/4110006701-eng}
#' @seealso \code{\link{sctidy}}, \code{\link{indgap}},
#'   \code{\link{ordcmp}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # the layout of a downloaded table: percent and number of persons, with limits for the
#' # percent
#' d <- data.frame(REF_DATE = "2022", GEO = "Canada",
#'                 `Indigenous identity` = rep(c("First Nations", "Metis"), each = 4),
#'                 Statistics = rep(c("Number of persons", "Percent",
#'                                    "Low 95% confidence interval",
#'                                    "High 95% confidence interval"), 2),
#'                 UOM = rep(c("Persons", "Percent", "Percent", "Percent"), 2),
#'                 VALUE = c(415000, 47.1, 45.2, 49.0, 320000, 50.3, 48.1, 52.5),
#'                 STATUS = "", check.names = FALSE)
#' scests(d)
#' # a rate with its coefficient of variation instead of limits
#' r <- data.frame(GEO = "Canada",
#'                 Characteristics = c("Rate", "Coefficient of variation for rate"),
#'                 VALUE = c(12.5, 8), STATUS = "")
#' scests(r)
#' @export
scests <- function(x) {
  if (!inherits(x, "rmbl_statcan")) x <- sctidy(x)
  cols <- setdiff(names(x), .rmbl_statcan_meta)
  uom <- if ("UOM" %in% names(x)) trimws(as.character(x$UOM)) else rep("", nrow(x))
  is_stat <- vapply(cols, function(n) {
    v <- x[[n]]
    grepl("^(Statistics|Characteristics)\\b", n) && (is.character(v) || is.factor(v)) ||
      ((is.character(v) || is.factor(v)) &&
         any(grepl("confidence interval|coefficient of variation|standard error", v, ignore.case = TRUE)))
  }, NA)
  if (sum(is_stat) > 1L) {
    # a "Characteristics" column of indicators beside a "Statistics" column of measures
    named <- cols[is_stat][grepl("^Statistics", cols[is_stat])]
    is_stat[] <- cols %in% (if (length(named) == 1L) named else cols[is_stat][1L])
  }
  for (d in cols) if (is.character(x[[d]]) || is.factor(x[[d]])) x[[d]] <- .rmbl_utf8(trimws(as.character(x[[d]])))
  if (!any(is_stat)) {
    out <- x[cols]
    out$measure <- uom
    out$estimate <- x$VALUE
    out$lower <- out$upper <- NA_real_
    out$cisou <- NA_character_
    out$quality <- x$quality
    rownames(out) <- NULL
    attr(out, "conflvl") <- 0.95
    attr(out, "unmatched") <- character()
    return(out)
  }
  sc <- cols[is_stat]
  lab <- gsub("\\s+", " ", .rmbl_utf8(trimws(as.character(x[[sc]]))))
  low <- tolower(lab)
  role <- rep("estimate", length(lab))
  target <- rep(NA_character_, length(lab))
  pats <- list(
    lower = c("^low [0-9.]+% confidence interval,? ?(.*)$", "^confidence interval lower bound,? ?(?:of )?(.*)$",
              "^[0-9.]+% confidence interval \\(lower limit\\),? ?(.*)$",
              "^[0-9.]+% confidence interval lower bound,? ?(.*)$"),
    upper = c("^high [0-9.]+% confidence interval,? ?(.*)$", "^confidence interval upper bound,? ?(?:of )?(.*)$",
              "^[0-9.]+% confidence interval \\(upper limit\\),? ?(.*)$",
              "^[0-9.]+% confidence interval upper bound,? ?(.*)$"),
    cv = "^coefficient of variation,? ?(?:for |of )?(.*)$",
    se = "^standard error,? ?(?:for |of )?(.*)$")
  for (r in names(pats)) {
    for (pt in pats[[r]]) {
      hit <- role == "estimate" & grepl(pt, low, perl = TRUE)
      role[hit] <- r
      target[hit] <- trimws(sub(pt, "\\1", low[hit], perl = TRUE))
    }
  }
  lv <- unique(regmatches(low, regexpr("[0-9.]+(?=% confidence)", low, perl = TRUE)))
  conf <- if (length(lv) == 1L) as.numeric(lv) / 100 else 0.95
  z <- stats::qnorm(1 - (1 - conf) / 2)
  dims <- setdiff(cols, sc)
  key <- do.call(paste, c(lapply(x[dims], as.character), sep = "\r"))
  ests <- unique(lab[role == "estimate"])
  e <- which(role == "estimate")
  if (anyDuplicated(paste(key[e], lab[e], sep = "\r"))) {
    stop("`x` has two estimates for one cell and measure of the table", call. = FALSE)
  }
  ekey <- paste(key[e], lab[e], sep = "\r")
  # the measure a precision label belongs to: by its name, then by unit, then by containing the estimates
  unmatched <- character()
  bound_of <- list()
  for (bl in unique(lab[role != "estimate"])) {
    i <- which(lab == bl)
    r <- role[i[1L]]
    t <- target[i[1L]]
    cand <- ests
    if (nzchar(t)) {
      exact <- ests[tolower(ests) == t]
      cand <- if (length(exact)) exact else ests[grepl(t, tolower(ests), fixed = TRUE)]
    }
    if (length(cand) > 1L && any(nzchar(uom))) {
      u <- unique(uom[i])
      by_u <- cand[vapply(cand, function(cn) any(uom[lab == cn] %in% u), NA)]
      if (length(by_u)) cand <- by_u
    }
    if (length(cand) > 1L && r %in% c("lower", "upper")) {
      # the other limit of the pair, if the table gives it: lower <= estimate <= upper must hold together
      other <- unique(lab[role == setdiff(c("lower", "upper"), r) & target == t])
      j <- if (length(other) == 1L) which(lab == other) else integer()
      fits <- vapply(cand, function(cn) {
        ev <- x$VALUE[e][match(paste(key[i], cn, sep = "\r"), ekey)]
        bv <- x$VALUE[i]
        ok <- is.finite(ev) & is.finite(bv)
        fit <- if (r == "lower") bv <= ev + 1e-9 else bv >= ev - 1e-9
        if (length(j)) {
          ov <- x$VALUE[j][match(key[i], key[j])]
          ok <- ok & is.finite(ov)
          fit <- fit & (if (r == "lower") ov >= ev - 1e-9 else ov <= ev + 1e-9)
        }
        # a published table can hold cells whose limits miss their own estimate (a 100% with limits
        # 85.5 to 98.6, table 41-10-0012; 5 of 396 cells of table 41-10-0015): the fit is judged on 95%
        # of the cells, not all; the wrong measure of a pair fails in nearly every cell
        if (any(ok)) mean(fit[ok]) else 0
      }, 0)
      cand <- cand[fits >= 0.95 & fits == max(fits)]
    }
    if (length(cand) == 1L) bound_of[[bl]] <- c(role = r, measure = cand) else unmatched <- c(unmatched, bl)
  }
  out <- x[e, dims, drop = FALSE]
  out$measure <- lab[e]
  out$estimate <- x$VALUE[e]
  out$lower <- NA_real_
  out$upper <- NA_real_
  out$cisou <- NA_character_
  cv <- se <- rep(NA_real_, length(e))
  for (bl in names(bound_of)) {
    i <- which(lab == bl)
    m <- match(paste(key[i], bound_of[[bl]][["measure"]], sep = "\r"), ekey)
    ok <- !is.na(m)
    v <- x$VALUE[i][ok]
    switch(bound_of[[bl]][["role"]],
           lower = out$lower[m[ok]] <- v,
           upper = out$upper[m[ok]] <- v,
           cv = cv[m[ok]] <- v,
           se = se[m[ok]] <- v)
  }
  pub <- is.finite(out$lower) & is.finite(out$upper)
  out$cisou[pub] <- "published"
  odd <- pub & is.finite(out$estimate) & (out$lower > out$estimate | out$upper < out$estimate)
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
  out$quality <- x$quality[e]
  gone <- !is.finite(out$estimate)
  out$lower[gone] <- out$upper[gone] <- NA_real_
  out$cisou[gone] <- NA_character_
  rownames(out) <- NULL
  attr(out, "conflvl") <- conf
  attr(out, "unmatched") <- unmatched
  out
}

#' Compare rated scales (perceived mental health, life satisfaction) between groups
#'
#' For a rated scale published as the percentage in each category with its confidence
#' limits (perceived mental health from poor to excellent, life satisfaction from 0 to 10,
#' agreement with a statement), the probability that a person in each group rates higher
#' than a person in the reference group, with its confidence interval: a comparison of the
#' whole distribution, not of one category cut from it.
#'
#' @details With shares \eqn{p_i} in the group and \eqn{q_j} in the reference over
#' categories ordered from lowest to highest, the probability of a higher rating, ties
#' counted half, is \eqn{A = \sum_i p_i (Q_{i-1} + q_i / 2)} with \eqn{Q_i} the
#' reference's cumulative shares and \eqn{Q_0 = 0}: the Mann-Whitney probability, equal to
#' \eqn{\alpha / (1 + \alpha)} for Agresti's (1980) generalized odds ratio \eqn{\alpha}
#' with ties split equally, and to the mean ridit of the group with the reference as the
#' standard (Bross 1958). 0.5 is no difference; \eqn{2A - 1} is Cliff's \eqn{\delta}, the
#' share rating higher less the share rating lower.
#'
#' Its variance is that of the two-sample U statistic,
#' \eqn{\sigma_1^2 / n_1 + \sigma_0^2 / n_0}, with \eqn{\sigma_1^2} the variance over the
#' group of each category's placement in the reference and \eqn{\sigma_0^2} the converse
#' (Brunner and Munzel 2000). The sample sizes are the effective ones the published limits
#' imply: for each category, \eqn{n = p(1 - p) / s^2} with \eqn{s} the standard error from
#' the limits' width, taking the median over the categories. That carries the design
#' effect of the survey's weights and clusters, which the counts of persons (population
#' totals) do not. The interval is built on the logit scale, so it stays inside 0 and 1.
#'
#' The categories given in \code{lvls} are taken as the whole scale: rows for totals,
#' for combined categories (\dQuote{Excellent or very good}) and for \dQuote{not
#' specified} are left
#' out, and the shares are rescaled to sum to one over the levels. A group with a
#' suppressed or missing category is not compared, since its distribution is unknown; one
#' with an \code{E} category (in the group or the reference) is compared and marked, and
#' one whose published interval misses its own estimate is not compared.
#'
#' A higher rating means better only on a scale that runs that way. Give \code{lvls}
#' from the least to the most favourable so that \code{probbet} reads as its name
#' says.
#'
#' @param data A data frame, one row per group and category (as
#'   \code{\link{scests}} gives, filtered to one geography, age group and
#'   gender).
#' @param grp,cat,est,lower,upper Column names: the group, the category, the
#'   share in it (percent or proportion: only relative shares matter) and its published
#'   limits on the same scale.
#' @param lvls The categories, from the lowest (least favourable) to the highest.
#' @param ref The label of the reference group (required: any group of \code{data}).
#' @param qual Optional column of quality flags (see \code{\link{qltyrcd}}).
#' @param conflvl Confidence level of the published limits and of the result (default
#'   0.95).
#' @return A data frame of class \code{rmbl_ordinal_compare}: \code{group},
#'   \code{reference}, \code{probbet}, \code{lower}, \code{upper}, \code{delta},
#'   \code{neff}, \code{neffref}, \code{usewithcau}, \code{poogrp};
#'   the attribute \code{shares} is the matrix of shares (groups by levels), which
#'   \code{plot()} draws.
#' @references Agresti A (1980). Generalized odds ratios for ordinal data. Biometrics
#' 36(1):59-67. \doi{10.2307/2530495}
#'
#' Bross IDJ (1958). How to use ridit analysis. Biometrics 14(1):18-38.
#' \doi{10.2307/2527727}
#'
#' Brunner E, Munzel U (2000). The nonparametric Behrens-Fisher problem: asymptotic theory
#' and a small-sample approximation. Biometrical Journal 42(1):17-25.
#' \doi{10.1002/(SICI)1521-4036(200001)42:1<17::AID-BIMJ17>3.0.CO;2-U}
#' @param pooled Optional labels of rows that pool other groups (see
#'   \code{\link{indgap}}).
#' @seealso \code{\link{scests}}, \code{\link{indgap}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # Self-perceived mental health, 15 years and older, Canada, 2022 (table 41-10-0067-01)
#' mh <- indiex("mentalhealth")
#' mh <- mh[mh$region == "Canada", ]
#' oc <- ordcmp(mh, "group", "rating", "estimate", "lower", "upper",
#'                       lvls = c("Fair or poor", "Good", "Very good", "Excellent"),
#'                       ref = "M\u00e9tis", qual = "quality")
#' oc
#' plot(oc)
#' @export
ordcmp <- function(data, grp, cat, est, lower, upper, lvls, ref,
                            qual = NULL, conflvl = 0.95, pooled = NULL) {
  if (!is.data.frame(data)) stop("ordcmp: `data` must be a data frame", call. = FALSE)
  for (nm in c("grp", "cat", "est", "lower", "upper")) {
    v <- .rmbl_string1(get(nm), nm)
    if (!v %in% names(data)) stop(sprintf("ordcmp: column `%s` not found in `data`", v), call. = FALSE)
  }
  if (!is.null(qual)) {
    qual <- .rmbl_string1(qual, "qual")
    if (!qual %in% names(data)) stop(sprintf("ordcmp: column `%s` not found in `data`", qual), call. = FALSE)
  }
  .rmbl_no_fn(levels = lvls)
  if (!is.character(lvls) || length(lvls) < 2L || anyNA(lvls) || anyDuplicated(lvls)) {
    stop("`lvls` must be two or more distinct categories, from the lowest to the highest", call. = FALSE)
  }
  ref <- .rmbl_string1(ref, "ref")
  conflvl <- .rmbl_conf_level(conflvl)
  z <- stats::qnorm(1 - (1 - conflvl) / 2)
  g <- .rmbl_utf8(trimws(as.character(data[[grp]])))
  .cat <- .rmbl_utf8(trimws(as.character(data[[cat]])))
  lvls <- .rmbl_utf8(trimws(lvls))
  .est <- .rmbl_num(data[[est]], "est")
  lo <- .rmbl_num(data[[lower]], "lower")
  hi <- .rmbl_num(data[[upper]], "upper")
  q <- .rmbl_qflags(if (is.null(qual)) rep("ok", length(g)) else data[[qual]])
  if (!ref %in% g) stop(sprintf("\"%s\" is not a group of `data`", ref), call. = FALSE)
  if (!any(.cat %in% lvls)) stop("no row of `data` has a category in `lvls`", call. = FALSE)
  groups <- unique(g)
  k <- length(lvls)
  sh <- matrix(NA_real_, length(groups), k, dimnames = list(groups, lvls))
  neff <- stats::setNames(rep(NA_real_, length(groups)), groups)
  caution <- stats::setNames(rep(FALSE, length(groups)), groups)
  for (gi in groups) {
    i <- which(g == gi & .cat %in% lvls)
    if (anyDuplicated(.cat[i])) stop(sprintf("group \"%s\" has a category twice", gi), call. = FALSE)
    i <- i[match(lvls, .cat[i])]
    if (anyNA(i) || any(q[i] %in% c("F", "x", "..", "...")) || !all(is.finite(.est[i]))) next
    if (any(lo[i] > .est[i] | hi[i] < .est[i], na.rm = TRUE)) {
      warning(sprintf("an interval of \"%s\" does not contain its estimate; not compared", gi), call. = FALSE)
      next
    }
    p <- .est[i] / sum(.est[i])
    s <- (hi[i] - lo[i]) / (2 * z) / sum(.est[i])
    ok <- is.finite(s) & s > 0 & p > 0 & p < 1
    sh[gi, ] <- p
    neff[[gi]] <- if (any(ok)) stats::median(p[ok] * (1 - p[ok]) / s[ok]^2) else NA_real_
    caution[[gi]] <- any(q[i] == "E")
  }
  if (anyNA(sh[ref, ])) {
    stop("the reference group's distribution is suppressed or incomplete: there is nothing to compare with",
         call. = FALSE)
  }
  q0 <- sh[ref, ]
  below0 <- c(0, cumsum(q0))[seq_len(k)]
  g0 <- below0 + q0 / 2
  rows <- lapply(setdiff(groups, ref), function(gi) {
    p1 <- sh[gi, ]
    if (anyNA(p1)) {
      return(data.frame(group = gi, probbet = NA_real_, lower = NA_real_, upper = NA_real_))
    }
    a <- sum(p1 * g0)
    above1 <- rev(c(0, cumsum(rev(p1)))[seq_len(k)])
    g1 <- above1 + p1 / 2
    v <- (sum(p1 * g0^2) - a^2) / neff[[gi]] + (sum(q0 * g1^2) - a^2) / neff[[ref]]
    if (!is.finite(v) || a <= 0 || a >= 1) {
      return(data.frame(group = gi, probbet = a, lower = NA_real_, upper = NA_real_))
    }
    sl <- sqrt(v) / (a * (1 - a))
    data.frame(group = gi, probbet = a, lower = stats::plogis(stats::qlogis(a) - z * sl),
               upper = stats::plogis(stats::qlogis(a) + z * sl))
  })
  out <- do.call(rbind, rows)
  out <- data.frame(group = out$group, reference = ref, probbet = out$probbet,
                    lower = out$lower, upper = out$upper, delta = 2 * out$probbet - 1,
                    neff = unname(neff[out$group]), neffref = unname(neff[[ref]]),
                    usewithcau = unname(caution[out$group]) | caution[[ref]],
                    poogrp = .rmbl_pan_indigenous(out$group, pooled), stringsAsFactors = FALSE)
  attr(out, "shares") <- sh
  attr(out, "conflvl") <- conflvl
  class(out) <- c("rmbl_ordinal_compare", "data.frame")
  out
}

#' Age-standardise survey percentages
#'
#' The percentage (or proportion, or rate) a group would have with the age structure of a
#' standard population, from the estimate and published limits in each age group: for
#' comparing First Nations, Metis and Inuit prevalences (suicidal thoughts, mood and
#' anxiety disorders, heavy drinking) with each other and with an older population, for
#' example, when the age pattern of the outcome is steep.
#'
#' @details With estimates \eqn{p_i}, standard errors \eqn{s_i = (u_i - l_i) / (2z)} and
#' standard weights \eqn{w_i} (the standard's shares), the standardised estimate is
#' \eqn{\sum w_i p_i} with standard error \eqn{\sqrt{\sum w_i^2 s_i^2}}, the age groups
#' being disjoint domains of the survey (treated as independent: see
#' \code{\link{indgap}}). The interval is normal, cut at 0 and at \code{scale}. A
#' group with a suppressed or missing age group, or one whose published interval misses
#' its own estimate, has no standardised value: the age group is not imputed. The standard
#' should be the age structure of the population compared, or a common one: for First
#' Nations, Metis and Inuit comparisons, the Indigenous population's own
#' (\code{\link{cnsstd}}; Kumar and Tjepkema 2019).
#'
#' @param est,lower,upper Numeric vectors (not column names): the estimate in each
#'   age group (and group) and its published limits.
#' @param std The standard population, one count (or share) per age group.
#' @param grp Optional labels, one per row: one result per group. Rows are matched to
#'   \code{std} by position, so order each group's rows by age in the order of
#'   \code{std} (sort by an age order, not alphabetically).
#' @param qual Optional quality flags, one per row (a vector; see
#'   \code{\link{qltyrcd}}).
#' @param conflvl Confidence level (default 0.95).
#' @param scale The upper bound of the scale: 100 for percentages (the default), 1 for
#'   proportions, \code{Inf} for rates.
#' @return A data frame of class \code{rmbl_prevalence}: \code{group}, \code{estimate},
#'   \code{lower}, \code{upper}, \code{se}, \code{usewithcau}; attribute
#'   \code{conflvl}. \code{plot()} draws it.
#' @references Klein RJ, Schoenborn CA (2001). Age adjustment using the 2000 projected
#' U.S. population. Healthy People 2010 Statistical Notes 20. National Center for Health
#' Statistics.
#'
#' Kumar MB, Tjepkema M (2019). Suicide among First Nations people, Metis and Inuit
#' (2011-2016): findings from the 2011 Canadian Census Health and Environment Cohort
#' (CanCHEC). National Household Survey: Aboriginal Peoples, Statistics Canada catalogue
#' no. 99-011-X2019001.
#' @seealso \code{\link{agestd}} for counts of events,
#'   \code{\link{cnsstd}}, \code{\link{indgap}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # seriously contemplated suicide in the past 12 months, 2017 (table 41-10-0021-01),
#' # standardised to the Indigenous population's age structure (2021 Census)
#' ages <- c("15 to 24 years", "25 to 34 years", "35 to 44 years", "45 to 54 years",
#'           "55 years and over")
#' si <- indiex("suicide")
#' si <- si[si$measure == "Seriously contemplated suicide in the past 12 months" &
#'            si$age %in% ages, ]
#' si <- si[order(si$group, match(si$age, ages)), ]
#' std <- cnsstd(cnsprof(indiex("censuspop")))
#' w <- c(sum(std$population[4:5]), std$population[6:8], sum(std$population[9:11]))
#' sp <- stdprev(si$estimate, si$lower, si$upper, std = w,
#'                              grp = si$group, qual = si$quality)
#' sp
#' plot(sp)
#' @export
stdprev <- function(est, lower, upper, std, grp = NULL, qual = NULL,
                                   conflvl = 0.95, scale = 100) {
  .est <- .rmbl_num(est, "est")
  lo <- .rmbl_num(lower, "lower")
  hi <- .rmbl_num(upper, "upper")
  std <- .rmbl_num(std, "std")
  conflvl <- .rmbl_conf_level(conflvl)
  if (!identical(scale, Inf)) scale <- .rmbl_scalar(scale, "scale", 0)
  k <- length(std)
  if (!k || anyNA(std) || any(std < 0) || sum(std) <= 0) {
    stop("stdprev: `std` must be non-negative counts, one per age group, not all zero", call. = FALSE)
  }
  if (length(lo) != length(.est) || length(hi) != length(.est)) {
    stop("`est`, `lower` and `upper` must be the same length", call. = FALSE)
  }
  if (is.null(grp)) grp <- rep("all", length(.est))
  .rmbl_no_fn(group = grp, quality = qual)
  grp <- as.character(grp)
  if (length(grp) != length(.est)) stop("stdprev: `grp` must have one label per row", call. = FALSE)
  q <- if (is.null(qual)) rep("ok", length(.est)) else as.character(qual)
  if (length(q) != length(.est)) stop("`qual` must have one flag per row", call. = FALSE)
  q <- .rmbl_qflags(q)
  bad <- is.finite(lo) & is.finite(hi) & is.finite(.est) & (lo > .est | hi < .est)
  if (any(bad)) {
    warning(sprintf("%d interval(s) do not contain their estimate; their groups are not standardised", sum(bad)),
            call. = FALSE)
    .est[bad] <- NA_real_
  }
  z <- stats::qnorm(1 - (1 - conflvl) / 2)
  w <- std / sum(std)
  rows <- lapply(unique(grp), function(gi) {
    i <- which(grp == gi)
    if (length(i) != k) {
      stop(sprintf("stdprev: group \"%s\" has %d age groups; `std` has %d", gi, length(i), k), call. = FALSE)
    }
    gone <- q[i] %in% c("F", "x", "..", "...") | !is.finite(.est[i]) | !is.finite(lo[i]) | !is.finite(hi[i])
    if (any(gone)) {
      return(data.frame(group = gi, estimate = NA_real_, lower = NA_real_, upper = NA_real_, se = NA_real_,
                        usewithcau = FALSE))
    }
    y <- sum(w * .est[i])
    se <- sqrt(sum(w^2 * ((hi[i] - lo[i]) / (2 * z))^2))
    data.frame(group = gi, estimate = y, lower = max(0, y - z * se), upper = min(scale, y + z * se), se = se,
               usewithcau = any(q[i] == "E"))
  })
  out <- do.call(rbind, rows)
  attr(out, "conflvl") <- conflvl
  class(out) <- c("rmbl_prevalence", "data.frame")
  out
}

# ---- plots ----------------------------------------------------------------------------------------

#' @rdname plot-methods
#' @export
plot.rmbl_indigenous_gap <- function(x, ..., what = c("difference", "ratio"), main = NULL, col = NULL,
                                     palette = NULL) {
  .rmbl_plot_check(x, "rmbl_indigenous_gap")
  what <- .rmbl_arg(what)
  d <- as.data.frame(x)
  lab <- paste0(d$group, ifelse(d$usewithcau, " (E)", ""))
  est <- d[[what]]
  cols <- if (what == "difference") c("diflo", "difup") else c("ratiolo", "ratioup")
  lo <- d[[cols[1L]]]
  hi <- d[[cols[2L]]]
  ref <- attr(x, "reference")
  .bl_dot_interval(lab, est, lo, hi,
                   .bl_main(main, sprintf("Each group against %s", ref)),
                   if (what == "difference") sprintf("Difference from %s", ref) else sprintf("Ratio to %s", ref),
                   .bl_cols(nrow(d), col, palette), ref = if (what == "difference") 0 else 1,
                   note = ifelse(is.finite(est), NA_character_, "suppressed: not compared"), ...)
  invisible(d[c("group", what, cols)])
}

#' @rdname plot-methods
#' @export
plot.rmbl_prevalence <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  .rmbl_plot_check(x, "rmbl_prevalence")
  d <- as.data.frame(x)
  lab <- paste0(d$group, ifelse(d$usewithcau, " (E)", ""))
  .bl_dot_interval(lab, d$estimate, d$lower, d$upper, .bl_main(main, "Age-standardised prevalence"),
                   "Per cent, standardised", .bl_cols(nrow(d), col, palette),
                   note = ifelse(is.finite(d$estimate), NA_character_, "suppressed"), ...)
  invisible(d[c("group", "estimate", "lower", "upper")])
}

#' @rdname plot-methods
#' @export
plot.rmbl_dsr <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  .rmbl_plot_check(x, "rmbl_dsr")
  d <- as.data.frame(x)
  .bl_dot_interval(d$group, d$rate, d$lower, d$upper, .bl_main(main, "Age-standardised rates"),
                   sprintf("Rate per %s, with its gamma interval", format(attr(x, "per"), big.mark = ",",
                                                                            scientific = FALSE)),
                   .bl_cols(nrow(d), col, palette), ...)
  invisible(d[c("group", "rate", "lower", "upper")])
}

#' @rdname plot-methods
#' @export
plot.rmbl_prevalence <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  .rmbl_plot_check(x, "rmbl_prevalence")
  d <- as.data.frame(x)
  .bl_dot_interval(paste0(d$group, ifelse(d$usewithcau, " (E)", "")), d$estimate, d$lower, d$upper,
                   .bl_main(main, "Age-standardised estimates"), "Estimate, with its interval",
                   .bl_cols(nrow(d), col, palette),
                   note = ifelse(is.finite(d$estimate), NA_character_, "an age group is suppressed"), ...)
  invisible(d[c("group", "estimate", "lower", "upper")])
}

#' @rdname plot-methods
#' @export
plot.rmbl_exposure_trend <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  .rmbl_plot_check(x, "rmbl_exposure_trend")
  d <- as.data.frame(x)
  .bl_dot_interval(sprintf("Exposure %s", format(d$dose)), d$orratio, d$lower, d$upper,
                   .bl_main(main, sprintf("Odds ratio by level of exposure (trend p = %s)",
                                          format.pval(attr(x, "trend")$p.value, digits = 2))),
                   "Odds ratio against the lowest level (log scale)", .bl_cols(nrow(d), col, palette), ref = 1,
                   log = "x", ...)
  invisible(d[c("dose", "orratio", "lower", "upper")])
}

#' @rdname plot-methods
#' @export
plot.rmbl_trc_progress <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  .rmbl_plot_check(x, "rmbl_trc_progress")
  h <- attr(x, "history")
  total <- attr(x, "total")
  cols <- .bl_cols(2L, col, palette)
  t1 <- h$year[nrow(h)]
  far <- min(max(x$cmplby[is.finite(x$cmplby)], t1 + 10), t1 + 120)
  late <- if (is.finite(x$cmplbylate)) min(x$cmplbylate, far) else far
  o <- .bl_plot_opts()
  op <- graphics::par(las = o$las, cex = o$cex, bg = o$bg, bty = "n", tcl = -0.2, mgp = c(3, 0.55, 0),
                      col.axis = "#3D4350", fg = "#8A909A", col = "#1F2430",
                      mar = .bl_safe_mar(c(4.2, 4.5, 3, 1), o$cex))
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot(range(h$year[1L], far), c(0, total), type = "n", xlab = "", ylab = "", main = "", ...)
  .bl_title(.bl_main(main, "Calls to Action completed, and the pace projected"))
  .bl_xlab("Year")
  .bl_ylab("Calls to Action completed")
  .bl_grid(NULL, side = "y")
  graphics::abline(h = total, col = "#8C8C8C", lty = 2)
  # the band between the projections at the interval's two ends of the rate
  yr <- function(r, t) pmin(total, x$completed + r * (t - t1))
  ts <- seq(t1, far, length.out = 200)
  graphics::polygon(c(ts, rev(ts)), c(yr(x$rateup, ts), rev(yr(x$ratelo, ts))),
                    col = grDevices::adjustcolor(cols[2L], 0.18), border = NA)
  graphics::lines(ts, yr(x$rate, ts), col = cols[2L], lwd = 1.6, lty = 2)
  graphics::lines(h$year, h$completed, type = "s", col = cols[1L], lwd = 2.2)
  graphics::points(h$year, h$completed, pch = 21, bg = cols[1L], col = "white", cex = 1.4)
  if (is.finite(x$cmplby) && x$cmplby <= far) {
    graphics::text(x$cmplby, total, sprintf("all %d by %.0f at this pace", round(total), x$cmplby),
                   adj = c(1.05, 1.6), cex = 0.8, col = cols[2L])
  }
  invisible(h)
}

#' @rdname plot-methods
#' @export
plot.rmbl_ordinal_compare <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  .rmbl_plot_check(x, "rmbl_ordinal_compare")
  sh <- attr(x, "shares")
  sh <- sh[stats::complete.cases(sh), , drop = FALSE]
  k <- ncol(sh)
  # warm for the lowest rating to cool for the highest
  cols <- if (is.null(col) && is.null(palette)) rev(blpal("diverging", k)) else .bl_cols(k, col, palette)
  fit <- .bl_label_fit(rownames(sh))
  o <- .bl_plot_opts()
  op <- graphics::par(las = 1, cex = o$cex, bg = o$bg, bty = "n", tcl = -0.2, mgp = c(3, 0.55, 0),
                      col.axis = "#3D4350", fg = "#8A909A", col = "#1F2430",
                      mar = .bl_safe_mar(c(7, fit$mar, 3, 1), o$cex))
  on.exit(graphics::par(op), add = TRUE)
  graphics::barplot(t(sh[rev(seq_len(nrow(sh))), , drop = FALSE]) * 100, horiz = TRUE, col = cols,
                    border = "white", names.arg = rev(fit$labels), xlab = "", main = "", xlim = c(0, 100), ...)
  .bl_title(.bl_main(main, sprintf("Ratings by group (reference: %s)", x$reference[1L])))
  .bl_xlab("Percent, lowest rating on the left")
  .bl_legend_below(legend = colnames(sh), fill = cols, border = NA, horiz = TRUE, bty = "n", cex = 0.75)
  invisible(as.data.frame(sh))
}

#' Wellness beside distress: a strengths-first profile of published indicators
#'
#' Puts a group's wellness indicators (life satisfaction, perceived mental health, a
#' hopeful outlook, a sense of belonging, a strong cultural identity) first and its
#' distress indicators (suicidal thoughts, mood and anxiety disorders, fair or poor mental
#' health) after them, each with its published interval, for each First Nations, Metis and
#' Inuit group: so that a table of mental health is never read, or plotted, as a list of
#' deficits alone.
#'
#' @details Indigenous scholars of mental health define it as wellness and as a process of
#' healing, grounded in community, cultural identity, a holistic view and interdependence
#' (Stewart 2008), and ask that strengths be reported together with disparities (Stewart
#' 2020). This function puts that into how published estimates are reported; it adds no
#' estimate of its own. The optional \code{domain} groups indicators by the holistic
#' domains of the Medicine Wheel teachings that Gabriel, Mirza and Stewart (2022) describe
#' (physical, emotional, mental, spiritual). That grouping is a way to lay out the table,
#' not a validated scale, and published tables have few indicators of the spiritual
#' domain: the profile says what is there and does not stand one indicator in for another.
#'
#' Aggregate tables show how indicators vary together across groups; they cannot show that
#' culture, land or belonging protects mental health within a group, which would be an
#' ecological inference. The differences these tables show between groups are the effects
#' of colonial policy and of structural conditions, not of the people in the groups
#' (Gabriel et al. 2022); their interpretation belongs with First Nations, Metis and Inuit
#' communities.
#'
#' @param data A data frame, one row per group and indicator (as
#'   \code{\link{scests}} gives).
#' @param grp,ind,est,lower,upper Column names: the group, the indicator,
#'   the percentage and its published limits.
#' @param well,distress The indicators that measure wellness or strength, and those
#'   that measure distress; rows for any other indicator (totals, \dQuote{not specified})
#'   are
#'   left out.
#' @param domain Optional named character vector giving each indicator's holistic domain,
#'   for example \code{c("Life satisfaction 8 to 10" = "mental", ...)}.
#' @param qual Optional column of quality flags.
#' @return A data frame of class \code{rmbl_wellness_profile}, wellness rows first,
#'   with the columns \code{group}, \code{indicator}, \code{side} (\code{"wellness"}
#'   or \code{"distress"}), \code{domain}, \code{estimate}, \code{lower},
#'   \code{upper} and \code{usewithcau}; \code{plot()} draws it.
#' @section Acknowledgement:
#' This estimator puts to quantitative use the framework of Professor Suzanne Stewart
#' (Yellowknives Dene First Nation, University of Toronto).
#'
#' See the acknowledgements of the \code{first-nations-metis-inuit-health} vignette.
#' @references Stewart SL (2008). Promoting Indigenous mental health: cultural
#' perspectives on healing from Native counsellors in Canada. International Journal of
#' Health Promotion and Education 46(2):49-56. \doi{10.1080/14635240.2008.10708129}
#'
#' Stewart S (2020). Addressing strengths and disparities in Indigenous health.
#' International Journal of Indigenous Health 15(1):4. \doi{10.32799/ijih.v15i1.34976}
#'
#' Gabriel MD, Mirza S, Stewart SL (2022). Exploring mental health and holistic healing
#' through the life stories of Indigenous youth who have experienced homelessness.
#' International Journal of Environmental Research and Public Health 19(20):13402.
#' \doi{10.3390/ijerph192013402}
#' @seealso \code{\link{scests}}, \code{\link{indgap}},
#'   \code{\link{ordcmp}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # well-being, 2024 (table 41-10-0082-01)
#' wb <- indiex("wellbeing")
#' w <- welprof(wb, "group", "indicator", "estimate", "lower", "upper",
#'                       well = c("Life satisfaction rating of 8, 9 or 10",
#'                                    "Sense of meaning and purpose rating of 8, 9 or 10",
#'                                    "Always or often has a hopeful outlook"),
#'                       distress = c("Life satisfaction rating between 0 and 5",
#'                                    "Rarely or never has a hopeful outlook"),
#'                       qual = "quality")
#' w
#' plot(w)
#' @export
welprof <- function(data, grp, ind, est, lower, upper, well, distress, domain = NULL,
                             qual = NULL) {
  if (!is.data.frame(data)) stop("welprof: `data` must be a data frame", call. = FALSE)
  for (nm in c("grp", "ind", "est", "lower", "upper")) {
    v <- .rmbl_string1(get(nm), nm)
    if (!v %in% names(data)) stop(sprintf("welprof: column `%s` not found in `data`", v), call. = FALSE)
  }
  if (!is.null(qual)) {
    qual <- .rmbl_string1(qual, "qual")
    if (!qual %in% names(data)) stop(sprintf("welprof: column `%s` not found in `data`", qual), call. = FALSE)
  }
  .rmbl_no_fn(wellness = well, distress = distress, domain = domain)
  .ind <- .rmbl_utf8(trimws(as.character(data[[ind]])))
  for (nm in c("well", "distress")) {
    v <- get(nm)
    if (!is.character(v) || !length(v) || anyNA(v)) stop(sprintf("`%s` must name indicators of `data`", nm),
                                                         call. = FALSE)
  }
  well <- .rmbl_utf8(trimws(well))
  distress <- .rmbl_utf8(trimws(distress))
  if (length(intersect(well, distress))) {
    stop("an indicator cannot be both one of wellness and one of distress", call. = FALSE)
  }
  miss <- setdiff(c(well, distress), .ind)
  if (length(miss)) stop(sprintf("welprof: not an indicator of `data`: %s", paste(miss, collapse = ", ")),
                         call. = FALSE)
  if (!is.null(domain) && (!is.character(domain) || is.null(names(domain)))) {
    stop("`domain` must be a named character vector: indicator = domain", call. = FALSE)
  }
  .est <- .rmbl_num(data[[est]], "est")
  q <- if (is.null(qual)) rep("ok", length(.ind)) else as.character(data[[qual]])
  q <- .rmbl_qflags(q)
  gone <- q %in% c("F", "x", "..", "...")
  .est[gone] <- NA_real_
  dom <- if (is.null(domain)) rep(NA_character_, length(.ind)) else unname(domain[.ind])
  keep <- .ind %in% c(well, distress)
  lo <- ifelse(gone, NA_real_, .rmbl_num(data[[lower]], "lower"))
  hi <- ifelse(gone, NA_real_, .rmbl_num(data[[upper]], "upper"))
  .grp <- .rmbl_utf8(trimws(as.character(data[[grp]])))
  .est[keep] <- .rmbl_contains(.est[keep], lo[keep], hi[keep], paste0(.grp[keep], ": ", .ind[keep]))
  out <- data.frame(group = .grp, indicator = .ind,
                    side = ifelse(.ind %in% well, "wellness", "distress"), domain = dom, estimate = .est,
                    lower = lo,
                    upper = hi,
                    usewithcau = q == "E", stringsAsFactors = FALSE)[keep, , drop = FALSE]
  ilev <- c(well, distress)
  o <- order(out$side != "wellness", match(out$indicator, ilev), match(out$group, unique(out$group)))
  out <- out[o, , drop = FALSE]
  rownames(out) <- NULL
  class(out) <- c("rmbl_wellness_profile", "data.frame")
  out
}

#' @rdname plot-methods
#' @export
plot.rmbl_wellness_profile <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
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
  y <- yb[match(d$indicator, inds)] + (match(d$group, grp) - (ng + 1) / 2) * step
  # a band per indicator leaves room for two-line labels, so long names are broken, not cut
  labs <- .bl_label_wrap(inds)
  o <- .bl_plot_opts()
  op <- graphics::par(las = 1, cex = o$cex, bg = o$bg, bty = "n", tcl = -0.2, mgp = c(3, 0.55, 0),
                      col.axis = "#3D4350", fg = "#8A909A", col = "#1F2430",
                      mar = .bl_safe_mar(c(7, labs$mar, 3, 1), o$cex))
  on.exit(graphics::par(op), add = TRUE)
  vals <- c(d$lower, d$upper, d$estimate)
  vals <- vals[is.finite(vals)]
  # the range of the estimates and their intervals, padded: anchored at 0 the points sat in a
  # corner of an empty panel
  xr <- if (length(vals)) range(vals) + c(-1, 1) * 0.06 * max(diff(range(vals)), 1) else c(0, 100)
  graphics::plot(xr, c(0.5, length(inds) + 0.5), type = "n", yaxt = "n", xlab = "", ylab = "", main = "", ...)
  .bl_title(.bl_main(main, "Wellness and distress, each group"))
  .bl_xlab("Estimate, with its published interval")
  .bl_grid(NULL, side = "x")
  nw <- sum(side == "wellness")
  if (nw && nw < length(inds)) graphics::abline(h = length(inds) - nw + 0.5, col = "#8C8C8C", lty = 3)
  # the two sections named at the right edge: wellness above the line, distress below
  usr <- graphics::par("usr")
  if (nw) graphics::text(usr[2L], length(inds) + 0.45, "wellness", adj = c(1, 1), cex = 0.75, font = 3, col = "#6E6E6E")
  if (nw < length(inds)) {
    graphics::text(usr[2L], length(inds) - nw + 0.45, "distress", adj = c(1, 1), cex = 0.75, font = 3, col = "#6E6E6E")
  }
  gc <- cols[match(d$group, grp)]
  ok <- is.finite(d$lower) & is.finite(d$upper)
  if (any(ok)) graphics::segments(d$lower[ok], y[ok], d$upper[ok], y[ok], col = gc[ok], lwd = 2, lend = 1)
  graphics::points(d$estimate, y, pch = ifelse(d$usewithcau, 1, 19), col = gc, cex = 1.2)
  .bl_row_labels(yb, labs$labels)
  .bl_legend_below(legend = grp, col = cols, pch = 19, horiz = TRUE, bty = "n", cex = 0.75)
  invisible(d)
}

#' A column of `data` named by a string argument, checked
#' @param data The data frame.
#' @param x The column name passed by the user.
#' @param what The argument's name, used in the error message.
#' @return The column name.
#' @noRd
.rmbl_col <- function(data, x, what) {
  x <- .rmbl_string1(x, what)
  if (!x %in% names(data)) stop(.rmbl_fn(), sprintf("column `%s` not found in `data`", x), call. = FALSE)
  x
}

#' Holistic balance: how evenly wellness is held across the domains of a whole person
#'
#' For each group, from published percentages of wellness in each holistic domain
#' (physical, emotional, mental, spiritual, or the domains a community names), the overall
#' level of wellness and how balanced it is across the domains, with Monte Carlo intervals
#' from the published ones.
#'
#' @details Indigenous understandings of mental health are holistic: wellness is a balance
#' among the domains of a person, and illness a loss of that balance (Stewart 2008;
#' Gabriel, Mirza and Stewart 2022). A single indicator, or an average of indicators,
#' cannot show balance: a group with 80% in two domains and 20% in two others has the
#' same average as one with 50% in all four. This method, which is ours and inspired by
#' that work rather than taken from it, measures balance as the ratio of the weighted
#' geometric to the weighted arithmetic mean of the domain levels \eqn{p_k}:
#' \deqn{B = \exp\left(\sum_k w_k \log p_k\right) / \sum_k w_k p_k,}
#' one less Atkinson's (1970) index with inequality aversion 1. \eqn{B = 1} exactly when
#' every domain with a positive weight is at the same level, and it falls toward 0 as one
#' domain falls behind the others; it does not depend on the overall level, which is
#' reported beside it (\code{level}, \eqn{\sum_k w_k p_k}) with the weakest domain.
#'
#' The weights \code{w} say how much each domain counts. They are equal by default;
#' a community that holds its own view of the domains sets its own (the CARE principle of
#' authority to control, Carroll et al. 2020), and the result says which weights it used.
#'
#' Several indicators in one domain are averaged, their standard errors combined as
#' independent (they come from the same respondents, so that standard error is too
#' small). The interval for \eqn{B} comes from \code{reps} draws of every domain level
#' from a normal distribution on the logit scale with the standard error of its published
#' interval, the domains independent. \eqn{B} is at most 1 and reaches 1 only at equal
#' levels, so noise in the levels tends to pull the draws below \eqn{\hat B} (\eqn{B} is
#' not concave; the direction of the bias is seen in the draws, not guaranteed): the
#' percentile interval is shifted back by the draws' mean bias (\eqn{\bar B^* - \hat B}),
#' kept inside \eqn{(0, 1]} and widened if need be to contain \eqn{\hat B}. The level's
#' interval is normal. A group with a suppressed or missing domain, or one whose
#' published interval misses its own estimate, has no balance: the domain is not imputed.
#'
#' What the domains mean, and which indicators stand for each, is for the communities to
#' say; the published tables have few measures of spiritual wellness, and a domain with no
#' fitting indicator should be left out rather than filled with another.
#'
#' @param data A data frame, one row per group and indicator (as
#'   \code{\link{scests}} gives).
#' @param grp,domain,est,lower,upper Column names: the group, the domain of the
#'   indicator (any set of domains: Medicine Wheel, Te Whare Tapa Wha, a Nation's own),
#'   the percentage of wellness (0 to 100, strictly inside; multiply proportions by 100)
#'   and its published limits.
#' @param w Optional named weights, one per domain (they are rescaled to sum to
#'   one).
#' @param qual Optional column of quality flags.
#' @param reps Monte Carlo draws for the intervals (default 10,000).
#' @param seed Seed for the draws, so the intervals are reproducible (default 1).
#' @param conflvl Confidence level (default 0.95).
#' @return A data frame of class \code{rmbl_holistic_balance}: \code{group}, \code{level},
#'   \code{lvllo}, \code{lvlup}, \code{balance}, \code{ballo},
#'   \code{balup}, \code{weadom}, \code{usewithcau}; the attributes
#'   \code{domains} (the matrix of domain levels, groups by domains) and \code{weights}.
#' @section Acknowledgement:
#' This estimator puts to quantitative use the framework of Professor Suzanne Stewart
#' (Yellowknives Dene First Nation, University of Toronto).
#'
#' See the acknowledgements of the \code{first-nations-metis-inuit-health} vignette.
#' @references Atkinson AB (1970). On the measurement of inequality. Journal of Economic
#' Theory 2(3):244-263.
#' \doi{10.1016/0022-0531(70)90039-6}
#'
#' Carroll SR, Garba I, Figueroa-Rodriguez OL, et al. (2020). The CARE Principles for
#' Indigenous Data Governance. Data Science Journal 19:43.
#' \doi{10.5334/dsj-2020-043}
#'
#' Gabriel MD, Mirza S, Stewart SL (2022). Exploring mental health and holistic healing
#' through the life stories of Indigenous youth who have experienced homelessness.
#' International Journal of Environmental Research and Public Health 19(20):13402.
#' \doi{10.3390/ijerph192013402}
#'
#' Stewart SL (2008). Promoting Indigenous mental health: cultural perspectives on healing
#' from Native counsellors in Canada. International Journal of Health Promotion and
#' Education 46(2):49-56. \doi{10.1080/14635240.2008.10708129}
#' @seealso \code{\link{welprof}}, \code{\link{dualcont}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # four domains from table 13-10-0924-01, 2019/2022, adults: which indicator stands for
#' # each is a choice for the people whose data these are; this is one reading of it
#' h <- indiex("health")
#' dom <- c("Perceived health, very good or excellent" = "physical",
#'          "Perceived mental health, very good or excellent" = "mental",
#'          "Life satisfaction, satisfied or very satisfied" = "emotional",
#'          "Sense of belonging to local community, somewhat strong or very strong" =
#'            "community")
#' d <- h[h$period == "2019/2022" & h$age == "Total, 18 years and over" &
#'          h$indicator %in% names(dom), ]
#' d$domain <- dom[d$indicator]
#' hb <- holbal(d, "group", "domain", "estimate", "lower", "upper",
#'                        qual = "quality")
#' hb
#' plot(hb)
#' # a community that counts belonging twice
#' holbal(d, "group", "domain", "estimate", "lower", "upper",
#'                  qual = "quality",
#'                  w = c(physical = 1, mental = 1, emotional = 1, community = 2))
#' @export
holbal <- function(data, grp, domain, est, lower, upper, w = NULL, qual = NULL,
                             reps = 10000, seed = 1, conflvl = 0.95) {
  if (!is.data.frame(data)) stop("holbal: `data` must be a data frame", call. = FALSE)
  grp <- .rmbl_col(data, grp, "grp")
  domain <- .rmbl_col(data, domain, "domain")
  est <- .rmbl_col(data, est, "est")
  lower <- .rmbl_col(data, lower, "lower")
  upper <- .rmbl_col(data, upper, "upper")
  if (!is.null(qual)) qual <- .rmbl_col(data, qual, "qual")
  reps <- .rmbl_scalar(reps, "reps", 100, 1e6, integer = TRUE)
  conflvl <- .rmbl_conf_level(conflvl)
  z <- stats::qnorm(1 - (1 - conflvl) / 2)
  g <- .rmbl_utf8(trimws(as.character(data[[grp]])))
  dm <- .rmbl_utf8(trimws(as.character(data[[domain]])))
  raw <- .rmbl_num(data[[est]], "est")
  lo_raw <- .rmbl_num(data[[lower]], "lower")
  hi_raw <- .rmbl_num(data[[upper]], "upper")
  if (any(is.finite(raw)) && all(raw[is.finite(raw)] <= 1)) {
    stop("the estimates are all at or below 1: are they proportions? give percentages (0 to 100)", call. = FALSE)
  }
  q <- if (is.null(qual)) rep("ok", length(g)) else as.character(data[[qual]])
  q <- .rmbl_qflags(q)
  raw[q %in% c("F", "x", "..", "...")] <- NA_real_
  in_dom <- !is.na(dm) & nzchar(dm)
  raw[in_dom] <- .rmbl_contains(raw[in_dom], lo_raw[in_dom], hi_raw[in_dom], paste0(g[in_dom], ": ", dm[in_dom]))
  .est <- raw / 100
  se <- (hi_raw - lo_raw) / (2 * z) / 100
  doms <- unique(dm[!is.na(dm) & nzchar(dm)])
  if (length(doms) < 2L) stop("balance needs two domains at least", call. = FALSE)
  if (is.null(w)) {
    w <- stats::setNames(rep(1, length(doms)), doms)
  } else {
    .rmbl_no_fn(weights = w)
    if (!is.numeric(w) || is.null(names(w)) || !setequal(names(w), doms) ||
          anyNA(w) || any(w < 0) || sum(w) <= 0) {
      stop(sprintf("`w` must be non-negative numbers named by the domains (%s), not all zero",
                   paste(doms, collapse = ", ")), call. = FALSE)
    }
  }
  .w <- w[doms] / sum(w[doms])
  groups <- unique(g)
  lev <- sem <- matrix(NA_real_, length(groups), length(doms), dimnames = list(groups, doms))
  caution <- stats::setNames(rep(FALSE, length(groups)), groups)
  for (gi in groups) {
    for (dk in doms) {
      i <- which(g == gi & dm == dk)
      if (!length(i) || anyNA(.est[i])) next
      lev[gi, dk] <- mean(.est[i])
      sem[gi, dk] <- sqrt(sum(se[i]^2)) / length(i)
    }
    caution[[gi]] <- any(q[g == gi & dm %in% doms] == "E")
  }
  if (any(lev <= 0 | lev >= 1, na.rm = TRUE)) {
    stop("domain levels must be percentages strictly between 0 and 100", call. = FALSE)
  }
  bal <- function(p) exp(sum(.w * log(p))) / sum(.w * p)
  .rmbl_local_seed(seed)
  a <- (1 - conflvl) / 2
  rows <- lapply(groups, function(gi) {
    p <- lev[gi, ]
    s <- sem[gi, ]
    if (anyNA(p) || anyNA(s)) {
      return(data.frame(group = gi, level = NA_real_, lvllo = NA_real_, lvlup = NA_real_,
                        balance = NA_real_, ballo = NA_real_, balup = NA_real_,
                        weadom = NA_character_))
    }
    sl <- s / (p * (1 - p))
    dr <- stats::plogis(matrix(stats::qlogis(p), reps, length(p), byrow = TRUE) +
                          matrix(stats::rnorm(reps * length(p)), reps) * rep(sl, each = reps))
    bb <- exp(drop(log(dr) %*% .w)) / drop(dr %*% .w)
    lv <- sum(.w * p)
    lse <- sqrt(sum(.w^2 * s^2))
    # B is at most 1 and reaches 1 only at equal levels, so noise tends to pull the draws below
    # B-hat (B is not concave): the percentile interval is shifted
    # back by the draws' mean bias, kept inside (0, 1], and made to contain B-hat
    b0 <- bal(p)
    bias <- mean(bb) - b0
    b_lo <- min(b0, max(0, unname(stats::quantile(bb, a)) - bias))
    b_hi <- max(b0, min(1, unname(stats::quantile(bb, 1 - a)) - bias))
    data.frame(group = gi, level = 100 * lv, lvllo = 100 * max(0, lv - z * lse),
               lvlup = 100 * min(1, lv + z * lse), balance = b0,
               ballo = b_lo, balup = b_hi,
               weadom = doms[which.min(p)])
  })
  out <- do.call(rbind, rows)
  out$usewithcau <- unname(caution[out$group])
  attr(out, "domains") <- 100 * lev
  attr(out, "weights") <- .w
  attr(out, "conflvl") <- conflvl
  class(out) <- c("rmbl_holistic_balance", "data.frame")
  out
}

#' Wellness and distress as two continua
#'
#' For each group, one wellness indicator against one distress indicator, each with its
#' published interval, and the ratio of the two: the dual-continua view of mental health,
#' in which wellness is not the absence of distress and is measured in its own right.
#'
#' @details Keyes (2002, 2005) showed that flourishing and mental illness are correlated
#' but distinct axes: a person, or a population, can carry distress and also wellness.
#' That is how Indigenous scholars of mental health describe it too, as wellness and as a
#' process of healing rather than as illness alone (Stewart 2008). Plotting the groups on
#' both axes keeps a strength visible beside the burden it sits next to. The
#' \code{strratio} is \eqn{R = W / D}, wellness over distress, with the log-normal
#' interval \eqn{\exp\{\log R \pm z\sqrt{\sigma_W^2 + \sigma_D^2}\}} from the two
#' published intervals: above 1, more people report the wellness than the distress. The
#' two estimates come from the same respondents; their covariance is not published, so the
#' interval treats them as independent and is too narrow when they are negatively
#' correlated, as answers about wellness and distress usually are. Any two indicators on
#' one scale can be set against each other.
#'
#' @param x A \code{\link{welprof}}.
#' @param well,distress One wellness and one distress indicator of \code{x}.
#' @param conflvl Confidence level of the published intervals and of the ratio (default
#'   0.95).
#' @return A data frame of class \code{rmbl_dual_continuum} with \code{group},
#'   \code{wellness}, \code{wello}, \code{welup}, \code{distress},
#'   \code{distrlo}, \code{distrup}, \code{strratio},
#'   \code{ratiolo}, \code{ratioup} and \code{usewithcau}.
#' @section Acknowledgement:
#' This estimator puts to quantitative use the framework of Professor Suzanne Stewart
#' (Yellowknives Dene First Nation, University of Toronto).
#'
#' See the acknowledgements of the \code{first-nations-metis-inuit-health} vignette.
#' @references Keyes CLM (2002). The mental health continuum: from languishing to
#' flourishing in life. Journal of Health and Social Behavior 43(2):207-222.
#' \doi{10.2307/3090197}
#'
#' Keyes CLM (2005). Mental illness and/or mental health? Investigating axioms of the
#' complete state model of health. Journal of Consulting and Clinical Psychology
#' 73(3):539-548.
#' \doi{10.1037/0022-006X.73.3.539}
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
#' @export
dualcont <- function(x, well, distress, conflvl = 0.95) {
  if (!inherits(x, "rmbl_wellness_profile")) stop("dualcont: `x` must come from welprof()", call. = FALSE)
  well <- .rmbl_string1(well, "well")
  distress <- .rmbl_string1(distress, "distress")
  if (!well %in% x$indicator[x$side == "wellness"]) {
    stop(sprintf("\"%s\" is not a wellness indicator of `x`", well), call. = FALSE)
  }
  if (!distress %in% x$indicator[x$side == "distress"]) {
    stop(sprintf("\"%s\" is not a distress indicator of `x`", distress), call. = FALSE)
  }
  conflvl <- .rmbl_conf_level(conflvl)
  z <- stats::qnorm(1 - (1 - conflvl) / 2)
  groups <- unique(x$group)
  pick <- function(ind, col) x[[col]][x$indicator == ind][match(groups, x$group[x$indicator == ind])]
  w <- pick(well, "estimate")
  d <- pick(distress, "estimate")
  slog <- function(ind) {
    lo <- pick(ind, "lower")
    hi <- pick(ind, "upper")
    ifelse(lo > 0 & hi > 0, (log(hi) - log(lo)) / (2 * z), NA_real_)
  }
  r <- w / d
  sr <- sqrt(slog(well)^2 + slog(distress)^2)
  ok <- is.finite(r) & r > 0
  out <- data.frame(group = groups, wellness = w, wello = pick(well, "lower"),
                    welup = pick(well, "upper"), distress = d,
                    distrlo = pick(distress, "lower"), distrup = pick(distress, "upper"),
                    strratio = ifelse(ok, r, NA_real_),
                    ratiolo = ifelse(ok, exp(log(r) - z * sr), NA_real_),
                    ratioup = ifelse(ok, exp(log(r) + z * sr), NA_real_),
                    usewithcau = pick(well, "usewithcau") %in% TRUE |
                      pick(distress, "usewithcau") %in% TRUE, stringsAsFactors = FALSE)
  attr(out, "labels") <- c(wellness = well, distress = distress)
  class(out) <- c("rmbl_dual_continuum", "data.frame")
  out
}

#' Do distinct groups differ? A heterogeneity test before pooling
#'
#' Tests whether the estimates of one indicator for distinct groups (First Nations, Metis
#' and Inuit; Aboriginal and Torres Strait Islander people; any groups with published
#' intervals) differ more than their intervals allow, and says how much of their spread is
#' real: the evidence for reporting each group distinctly rather than as one pooled
#' figure.
#'
#' @details With estimates \eqn{y_g}, standard errors \eqn{s_g} from the published
#' intervals and weights \eqn{w_g = 1/s_g^2}, Cochran's
#' \eqn{Q = \sum w_g (y_g - \bar y_w)^2} has a chi-squared distribution on \eqn{G - 1}
#' degrees of freedom when the groups share one value, and
#' \eqn{I^2 = \max(0, (Q - (G-1))/Q)} is the share of the spread that is real rather than
#' sampling error (Higgins and Thompson 2002). A pooled figure is a weighted mean of
#' different populations whenever \eqn{I^2} is large; the population-weighted total
#' Statistics Canada publishes also depends on how many people are in each group, so it is
#' mostly a First Nations figure where First Nations people are most of the Indigenous
#' population. Rows that pool groups are left out (\code{pooled}; see
#' \code{\link{indgap}}); every other row is included, so drop the reference group
#' (non-Indigenous people) yourself, and never test overlapping groups (\code{"alone"}
#' beside
#' \dQuote{alone or in combination}) together: they are not independent. With two or
#' three groups
#' the test has little power and \eqn{I^2} is imprecise; a large \eqn{p} is not evidence
#' that the groups are the same.
#'
#' @param data A data frame, one row per group.
#' @param grp,est,lower,upper Column names.
#' @param qual Optional column of quality flags; suppressed rows are left out (see
#'   \code{\link{qltyrcd}}).
#' @param conflvl Confidence level of the published intervals, and the level of the
#'   verdict printed (default 0.95).
#' @param pooled Optional labels of rows that pool other groups.
#' @return A list of class \code{rmbl_distinctions}: \code{groups} (the estimates used,
#'   with their standard errors), \code{pooled} (the inverse-variance mean) and
#'   \code{poose}, \code{q}, \code{df}, \code{p_value}, \code{i2}, \code{leftout}
#'   (the rows not used) and \code{conflvl}. \code{print()} and \code{plot()} show it.
#' @references Higgins JPT, Thompson SG (2002). Quantifying heterogeneity in a
#'   meta-analysis. Statistics in Medicine 21(11):1539-1558. \doi{10.1002/sim.1186}
#' @seealso \code{\link{indgap}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # perceived mental health very good or excellent, 2019/2022, adults (table
#' # 13-10-0924-01)
#' h <- indiex("health")
#' mh <- h[h$period == "2019/2022" & h$age == "Total, 18 years and over" &
#'           h$group != "Non-Indigenous" &
#'           h$indicator == "Perceived mental health, very good or excellent", ]
#' dt <- dstntst(mh, "group", "estimate", "lower", "upper", qual = "quality")
#' dt
#' plot(dt)
#' # your own table: made-up numbers, with the pooled row named
#' own <- data.frame(group = c("Aboriginal", "Torres Strait Islander", "Both"),
#'                   est = c(24.0, 31.0, 24.6), lo = c(22.1, 26.2, 22.8), hi = c(25.9,
#'                                                                               35.8, 26.4))
#' dstntst(own, "group", "est", "lo", "hi", pooled = "Both")
#' @export
dstntst <- function(data, grp, est, lower, upper, qual = NULL, conflvl = 0.95,
                              pooled = NULL) {
  if (!is.data.frame(data)) stop("dstntst: `data` must be a data frame", call. = FALSE)
  grp <- .rmbl_col(data, grp, "grp")
  est <- .rmbl_col(data, est, "est")
  lower <- .rmbl_col(data, lower, "lower")
  upper <- .rmbl_col(data, upper, "upper")
  if (!is.null(qual)) qual <- .rmbl_col(data, qual, "qual")
  conflvl <- .rmbl_conf_level(conflvl)
  z <- stats::qnorm(1 - (1 - conflvl) / 2)
  g <- .rmbl_utf8(trimws(as.character(data[[grp]])))
  y <- .rmbl_num(data[[est]], "est")
  lo <- .rmbl_num(data[[lower]], "lower")
  hi <- .rmbl_num(data[[upper]], "upper")
  y <- .rmbl_contains(y, lo, hi, g)
  s <- (hi - lo) / (2 * z)
  q <- .rmbl_qflags(if (is.null(qual)) rep("ok", length(g)) else data[[qual]])
  use <- !.rmbl_pan_indigenous(g, pooled) & !q %in% c("F", "x", "..", "...") & is.finite(y) & is.finite(s) &
    s > 0
  if (sum(use) < 2L) stop("the test needs two groups at least with an estimate and an interval", call. = FALSE)
  if (anyDuplicated(g[use])) stop("a group appears twice", call. = FALSE)
  w <- 1 / s[use]^2
  pooled_est <- sum(w * y[use]) / sum(w)
  qs <- sum(w * (y[use] - pooled_est)^2)
  df <- sum(use) - 1L
  out <- list(groups = data.frame(group = g[use], estimate = y[use], se = s[use], stringsAsFactors = FALSE),
              pooled = pooled_est, poose = sqrt(1 / sum(w)), q = qs, df = df,
              p_value = stats::pchisq(qs, df, lower.tail = FALSE), i2 = if (qs > 0) max(0, (qs - df) / qs) else 0,
              leftout = g[!use], conflvl = conflvl)
  class(out) <- "rmbl_distinctions"
  out
}

#' @export
print.rmbl_distinctions <- function(x, ...) {
  cat(sprintf("Distinctions test across %d groups: Q = %.2f on %d df, p = %s, I^2 = %.0f%%\n",
              nrow(x$groups), x$q, x$df, format.pval(x$p_value, digits = 3), 100 * x$i2))
  a <- 1 - (if (is.null(x$conflvl)) 0.95 else x$conflvl)
  cat(sprintf("Pooled (inverse-variance) %.2f; %s\n", x$pooled,
              if (x$p_value < a) "the groups differ: report each one, not the pooled figure" else
                sprintf("no difference shown at the %g%% level (which is not evidence that they are the same)",
                        100 * a)))
  if (length(x$leftout)) cat("Left out:", paste(x$leftout, collapse = "; "), "\n")
  invisible(x)
}

#' @rdname plot-methods
#' @export
plot.rmbl_holistic_balance <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  .rmbl_plot_check(x, "rmbl_holistic_balance")
  lev <- attr(x, "domains")
  lev <- lev[stats::complete.cases(lev), , drop = FALSE]
  k <- ncol(lev)
  ng <- nrow(lev)
  cols <- .bl_cols(ng, col, palette)
  o <- .bl_plot_opts()
  op <- graphics::par(cex = o$cex, bg = o$bg, mar = c(1 + 1.3 * ceiling(nrow(lev) / 2), 1, 3, 1), xpd = NA)
  on.exit(graphics::par(op), add = TRUE)
  # one spoke per domain, from the top clockwise, the circle at 100%
  ang <- pi / 2 - 2 * pi * (seq_len(k) - 1) / k
  graphics::plot(c(-1.35, 1.35), c(-1.25, 1.25), type = "n", asp = 1, axes = FALSE, xlab = "", ylab = "",
                 main = "", ...)
  .bl_title(.bl_main(main, "Wellness in each domain, and its balance"))
  for (r in c(0.25, 0.5, 0.75, 1)) {
    graphics::polygon(r * cos(seq(0, 2 * pi, length.out = 100)), r * sin(seq(0, 2 * pi, length.out = 100)),
                      border = "#D5D8DD", lty = if (r == 1) 1 else 3)
  }
  graphics::segments(0, 0, cos(ang), sin(ang), col = "#D5D8DD")
  wrapped <- vapply(colnames(lev), function(s) paste(strwrap(s, 22), collapse = "\n"), "")
  # each label leans away from the circle: left of a spoke on the left, above one at the top
  for (j in seq_len(k)) {
    graphics::text(1.06 * cos(ang[j]), 1.06 * sin(ang[j]), wrapped[[j]], cex = 0.75, col = "#3D4350",
                   adj = c(0.5 - 0.5 * sign(round(cos(ang[j]), 6)), 0.5 - 0.5 * sign(round(sin(ang[j]), 6))))
  }
  for (i in seq_len(ng)) {
    r <- lev[i, ] / 100
    graphics::polygon(r * cos(ang), r * sin(ang), border = cols[i], lwd = 2,
                      col = grDevices::adjustcolor(cols[i], 0.12))
  }
  b <- x$balance[match(rownames(lev), x$group)]
  .bl_legend_below(ncol = min(2L, ng), bty = "n", cex = 0.75, col = cols, lwd = 2, text.col = "#3D4350",
                   legend = sprintf("%s (balance %.2f)", rownames(lev), b), line = 0.2)
  invisible(as.data.frame(lev))
}

#' @rdname plot-methods
#' @export
plot.rmbl_dual_continuum <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  .rmbl_plot_check(x, "rmbl_dual_continuum")
  d <- as.data.frame(x)
  lab <- attr(x, "labels")
  cols <- .bl_cols(nrow(d), col, palette)
  o <- .bl_plot_opts()
  op <- graphics::par(las = 1, cex = o$cex, bg = o$bg, bty = "n", tcl = -0.2, mgp = c(3, 0.55, 0),
                      col.axis = "#3D4350", fg = "#8A909A", col = "#1F2430", mar = .bl_safe_mar(c(4.2, 4.5, 3, 1)))
  on.exit(graphics::par(op), add = TRUE)
  # the data's own range, padded (anchored at 0, the groups crowded one corner of an empty panel)
  xr <- range(d$distrlo, d$distrup, d$distress, na.rm = TRUE)
  yr <- range(d$wello, d$welup, d$wellness, na.rm = TRUE)
  xr <- xr + c(-1, 1) * 0.08 * max(diff(xr), 1)
  yr <- yr + c(-1, 1) * 0.08 * max(diff(yr), 1)
  graphics::plot(xr, yr, type = "n", xlab = "", ylab = "", main = "", ...)
  .bl_title(.bl_main(main, "Wellness and distress, two continua"))
  .bl_xlab(sprintf("%s (%%)", lab[["distress"]]))
  .bl_ylab(sprintf("%s (%%)", lab[["wellness"]]))
  .bl_grid(NULL, side = "y")
  graphics::segments(d$distrlo, d$wellness, d$distrup, d$wellness, col = cols, lwd = 1.6)
  graphics::segments(d$distress, d$wello, d$distress, d$welup, col = cols, lwd = 1.6)
  graphics::points(d$distress, d$wellness, pch = 21, bg = cols, col = "white", cex = 1.8)
  graphics::text(d$distress, d$wellness, d$group, pos = 3, offset = 0.9, cex = 0.8, col = cols)
  invisible(d)
}

#' @rdname plot-methods
#' @export
plot.rmbl_distinctions <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  .rmbl_plot_check(x, "rmbl_distinctions")
  d <- x$groups
  z <- stats::qnorm(1 - (1 - x$conflvl) / 2)
  .bl_dot_interval(d$group, d$estimate, d$estimate - z * d$se, d$estimate + z * d$se,
                   .bl_main(main, sprintf("Each group, and the pooled figure (I^2 = %.0f%%)", 100 * x$i2)),
                   "Estimate, with its published interval; dashed: pooled", .bl_cols(nrow(d), col, palette),
                   ref = x$pooled, ...)
  invisible(d)
}

#' First Nations, Metis and Inuit health and mental health: bundled Statistics Canada
#' excerpts
#'
#' Small excerpts of Statistics Canada tables, bundled so that the examples and vignettes
#' run on published values without a network connection or a data service key. Values are
#' as published, with their 95% limits and quality flags; nothing is imputed (suppressed
#' cells are \code{NA}).
#'
#' \describe{
#'   \item{\code{"health"}}{Table 13-10-0924-01, Health indicators for First
#'     Nations people living off reserve, Metis and Inuit, by age group and sex, four-year
#'     period estimates (Canadian Community Health Survey), 2015/2018 and 2019/2022;
#'     Canada, both sexes, the 27 indicators by age group, with non-Indigenous people for
#'     comparison: the table behind The Daily of 2025-02-13. Columns \code{period},
#'     \code{group}, \code{age}, \code{indicator}, \code{estimate}, \code{lower},
#'     \code{upper}, \code{quality}.}
#'   \item{\code{"mentalhealth"}}{Table 41-10-0067-01, Self-perceived mental health of
#'     First Nations people living off reserve, Metis and Inuit by age group and gender,
#'     2022 (Indigenous Peoples Survey); 15 years and older, every region. Columns
#'     \code{region}, \code{group}, \code{rating}, \code{estimate}, \code{lower},
#'     \code{upper}, \code{quality}.}
#'   \item{\code{"wellbeing"}}{Table 41-10-0082-01, Selected characteristics of well-being
#'     and impacts of rising prices by First Nations people living off reserve, Metis and
#'     Inuit, and gender, 2024; total of genders. Columns \code{group}, \code{indicator},
#'     \code{estimate}, \code{lower}, \code{upper}, \code{quality}.}
#'   \item{\code{"suiide"}}{Table 41-10-0021-01, Self-perceived mental health
#'     and suicidal thoughts by Aboriginal identity, age group and sex, 2017 (Aboriginal
#'     Peoples Survey); Canada, both sexes, by age. Columns \code{group}, \code{age},
#'     \code{measure}, \code{estimate}, \code{lower}, \code{upper}, \code{quality}.}
#'   \item{\code{"censuspop"}}{The Indigenous Population Profile, 2021 Census of
#'     Population (98-510-X2021001), Canada, the provinces and the territories, total of
#'     genders, on and off reserve: the population by age group, children and foster
#'     children, knowledge of Indigenous languages, highest certificate (25 and over),
#'     labour force status, income and low income, as published (read it with
#'     \code{\link{cnsprof}}).}
#'   \item{\code{"lifeexp"}}{Table 17-10-0160-01, Life expectancy at birth of
#'     Indigenous populations in Canada, 2006/2011 to 2016/2021, both sexes, Canada: First
#'     Nations (Registered or Treaty Indians, on and off reserve, and without registered
#'     status), Metis, Inuit and non-Indigenous people. Columns \code{period},
#'     \code{group}, \code{measure}, \code{estimate}, \code{lower}, \code{upper},
#'     \code{quality}.}
#'   \item{\code{"infmort"}}{Table 17-10-0161-01, Infant mortality rates of
#'     Indigenous populations in Canada (per 1,000 live births), 1994/1996 to 2014/2016,
#'     the same groups and columns.}
#'   \item{\code{"censushh"}}{The same profile's households and dwellings
#'     (98-510-X2021016), Indigenous and non-Indigenous households: persons per room,
#'     housing suitability, dwelling condition and core housing need.}
#' }
#'
#' The First Nations figures of the survey excerpts are for First Nations people living
#' off reserve: the surveys do not cover reserves, whose data are governed by First
#' Nations (see the First Nations Information Governance Centre). Groups are as the tables
#' name them, with \dQuote{Inuk (Inuit)} written \code{"Inuit"}.
#'
#' @param name Which excerpt.
#' @return A data frame.
#' @source Statistics Canada tables, each with its DOI:
#' \itemize{
#'   \item 13-10-0924-01, \doi{10.25318/1310092401-eng};
#'   \item 41-10-0067-01, \doi{10.25318/4110006701-eng};
#'   \item 41-10-0082-01, \doi{10.25318/4110008201-eng};
#'   \item 41-10-0021-01, \doi{10.25318/4110002101-eng};
#'   \item 17-10-0160-01, \doi{10.25318/1710016001-eng};
#'   \item 17-10-0161-01, \doi{10.25318/1710016101-eng}.
#' }
#' Indigenous Population Profile, 2021 Census of Population, catalogue 98-510-X2021001
#' and 98-510-X2021016. Reproduced and distributed on an \dQuote{as is} basis with the
#' permission of Statistics Canada, under the Statistics Canada Open Licence:
#'
#' \url{https://www.statcan.gc.ca/en/terms-conditions/open-licence}
#'
#' Built by the scripts \code{indigenous_mental_health.R} and \code{indigenous_census.R}
#' in the \code{data-raw} folder of the source package.
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
indiex <- function(name = c("health", "mentalhealth", "wellbeing", "suicide",
                                        "censuspop", "censushh", "lifeexp",
                                        "infantmort")) {
  name <- .rmbl_arg(name)
  files <- c(health = "health_indicators", mentalhealth = "mental_health", wellbeing = "wellbeing",
             suicide = "suicidal_ideation", censuspop = "census_population", censushh = "census_households",
             lifeexp = "life_expectancy", infantmort = "infant_mortality")
  f <- system.file("extdata", sprintf("indigenous_%s.csv", files[[name]]), package = "rmoriebricklayer",
                   mustWork = TRUE)
  # the bytes are UTF-8 and are marked so; re-encoding to the native locale (fileEncoding) cut the
  # file at "Metis" with an accent in a C locale (the C-locale CI cell)
  utils::read.csv(f, stringsAsFactors = FALSE, encoding = "UTF-8", check.names = FALSE)
}
