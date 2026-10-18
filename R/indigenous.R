# SPDX-License-Identifier: AGPL-3.0-or-later
#
# First Nations, Metis and Inuit health and wellbeing: Statistics Canada's published tables, read as
# published (quality flags kept, suppressed cells never imputed), compared distinction by
# distinction, age-standardised, and the Truth and Reconciliation Commission's Calls to Action
# tracked. Data governance is part of the method: OCAP(R) (First Nations Information Governance
# Centre) and the CARE Principles (Carroll et al. 2020) say whose data these are; the package mirrors
# only openly licensed aggregate tables and never First Nations-held survey data.

#' Read a Statistics Canada table as published
#'
#' Tidies a Statistics Canada full-table download (the "CSV for database loading" form, as the
#' data service mirrors it under \code{statcan_indigenous/tbl_<pid>}): \code{VALUE} as a number,
#' and the quality flags kept beside it in \code{quality}.
#'
#' @details
#' Statistics Canada flags every estimate: \code{E} use with caution, \code{F} too unreliable to be
#' published, \code{x} suppressed to meet the confidentiality requirements of the Statistics Act,
#' \code{..} not available, \code{...} not applicable. An \code{F}, \code{x}, \code{..} or
#' \code{...} cell has no value here (\code{NA}), whatever the file holds, and nothing in the package
#' imputes it or works it back from totals and margins: a suppressed cell is suppressed to protect
#' people, and small First Nations, Metis and Inuit communities most of all. \code{E} values are kept
#' and marked.
#'
#' The census data tables (98-10-xxxx) come in a wide layout: one column per member of a dimension
#' (\code{"Indigenous identity (9):Inuk (Inuit)[6]"}), each followed by its \code{Symbol} column,
#' and no \code{VALUE}. They are made long first: the dimension becomes a column of member labels
#' (\code{"Indigenous identity (9)"}), the values \code{VALUE} and the symbols \code{STATUS}, so
#' every Statistics Canada table reads the same way.
#'
#' A label that names two members of one dimension (the census tables repeat labels under different
#' parents, and the file drops the hierarchy) gets its member number from the coordinate:
#' \code{"Without children [3]"} and \code{"Without children [7]"}. Other labels are left as they are.
#'
#' @param x A data frame read from a Statistics Canada table, or a key of the data service
#'   (\code{"statcan_indigenous/tbl_13100924"}, or the eight-digit table id alone, which needs the
#'   data service key: see \code{\link{bricklayer_data_load}}).
#' @return The data frame with \code{VALUE} numeric and a factor column \code{quality} with levels
#'   \code{"ok"}, \code{"E"}, \code{"F"}, \code{"x"}, \code{".."}, \code{"..."}, of class
#'   \code{c("rmbl_statcan", "data.frame")}.
#' @references Statistics Canada. Symbol legend. \url{https://www.statcan.gc.ca/en/concepts/definitions/guide-symbol}
#' @seealso \code{\link{indigenous_gap}}, \code{\link{indigenous_tables}}.
#' @examples
#' # the layout of a downloaded table, with one cell suppressed
#' d <- data.frame(REF_DATE = "2019/2022", GEO = "Canada",
#'                 `Indigenous identity` = c("First Nations", "Inuk (Inuit)", "Non-Indigenous"),
#'                 VALUE = c("45.8", "", "61.5"), STATUS = c("", "x", ""),
#'                 check.names = FALSE)
#' statcan_tidy(d)
#' \dontrun{
#' # needs the data service key (bricklayer_llm_login())
#' t924 <- statcan_tidy("13100924")
#' }
#' @export
statcan_tidy <- function(x) {
  if (is.character(x) && length(x) == 1L && !is.na(x)) {
    key <- if (grepl("^[0-9]{8}$", x)) paste0("statcan_indigenous/tbl_", x) else x
    x <- bricklayer_data_load(key)
  }
  if (!is.data.frame(x)) stop("`x` must be a data frame or a table key", call. = FALSE)
  if (!"VALUE" %in% names(x)) x <- .rmbl_statcan_long(x)
  if (is.null(x)) {
    stop("`x` has no VALUE column, nor census columns: it is not a Statistics Canada table", call. = FALSE)
  }
  x <- .rmbl_statcan_members(x)
  st <- if ("STATUS" %in% names(x)) as.character(x$STATUS) else rep("", nrow(x))
  st[is.na(st)] <- ""
  st <- trimws(st)
  lv <- c("ok", "E", "F", "x", "..", "...")
  q <- ifelse(st == "", "ok", st)
  q[!q %in% lv] <- "ok"
  v <- suppressWarnings(as.numeric(as.character(x$VALUE)))
  v[q %in% c("F", "x", "..", "...")] <- NA_real_
  x$VALUE <- v
  x$quality <- factor(q, levels = lv)
  class(x) <- c("rmbl_statcan", "data.frame")
  x
}

# A census data table (98-10-xxxx) in its wide layout: one column per member of a dimension
# ("Indigenous identity (9):Metis[5]"), each followed by its "Symbol" column, and no VALUE. Made long:
# the dimension becomes a column of member labels, the values VALUE and the symbols STATUS. NULL when
# the table has no such columns.
.rmbl_statcan_long <- function(x) {
  nm <- names(x)
  vc <- grep(":.*\\[[0-9]+\\]\\s*$", nm)
  if (!length(vc)) return(NULL)
  dim <- unique(trimws(sub(":.*$", "", nm[vc])))
  if (length(dim) != 1L) stop("`x` spreads more than one dimension across its columns", call. = FALSE)
  sym <- vc + 1L
  has_sym <- sym <= length(nm) & grepl("^Symbol", nm[pmin(sym, length(nm))])
  ids <- setdiff(seq_along(nm), c(vc, sym[has_sym]))
  members <- trimws(sub("\\s*\\[[0-9]+\\]\\s*$", "", sub("^[^:]*:", "", nm[vc])))
  n <- nrow(x)
  out <- x[rep(seq_len(n), length(vc)), ids, drop = FALSE]
  out[[dim]] <- rep(members, each = n)
  out$VALUE <- unlist(lapply(vc, function(j) as.character(x[[j]])), use.names = FALSE)
  out$STATUS <- unlist(lapply(seq_along(vc), function(i) {
    if (has_sym[i]) as.character(x[[sym[i]]]) else rep("", n)
  }), use.names = FALSE)
  rownames(out) <- NULL
  out
}

# One label can name two members of a dimension ("Without children" under couple families and under
# another parent, table 98-10-0254): the CSV drops the hierarchy, and only the member number in the
# coordinate tells them apart. Such labels get their member number ("Without children [3]"); labels that
# name one member are left as they are. The coordinate holds one number per dimension, the geography
# first, in the order of the columns; the geography is told apart by DGUID and is left alone.
.rmbl_statcan_members <- function(x) {
  cc <- intersect(c("COORDINATE", "Coordinate"), names(x))[1L]
  if (is.na(cc) || !"GEO" %in% names(x)) return(x)
  nm <- names(x)
  between <- nm[seq(match("GEO", nm), match(cc, nm) - 1L)]
  dims <- between[!between %in% c("DGUID", "UOM", "UOM_ID", "SCALAR_FACTOR", "SCALAR_ID", "VECTOR")]
  k <- length(dims)
  if (k < 2L) return(x)
  parts <- strsplit(as.character(x[[cc]]), ".", fixed = TRUE)
  if (any(lengths(parts) < k)) return(x)
  ids <- matrix(unlist(lapply(parts, `[`, seq_len(k)), use.names = FALSE), ncol = k, byrow = TRUE)
  for (j in 2:k) {
    lab <- as.character(x[[dims[j]]])
    n_id <- tapply(ids[, j], lab, function(v) length(unique(v)))
    amb <- lab %in% names(n_id)[n_id > 1L]
    if (any(amb)) x[[dims[j]]][amb] <- paste0(lab[amb], " [", ids[amb, j], "]")
  }
  x
}

# a pan-Indigenous total (every identity together), as against First Nations, Metis or Inuit
.rmbl_pan_indigenous <- function(g) {
  grepl("^total|^indigenous identity|^aboriginal identity|^total indigenous|^indigenous population",
        trimws(tolower(g)))
}

#' Compare First Nations, Metis and Inuit estimates with a reference group
#'
#' For published percentages or rates with their confidence intervals (a Statistics Canada table,
#' a report), the ratio and the difference of each group to a reference group, with confidence
#' intervals worked from the published ones.
#'
#' @details
#' Each published interval gives a standard error, \eqn{(u - l) / (2 z)}, on the scale of the
#' estimate for the difference and on the log scale, \eqn{(\log u - \log l) / (2 z)}, for the ratio.
#' The groups are treated as independent samples, so the standard error of a difference is the root
#' of the sum of the squares. Disjoint domains of one survey are nearly so, but not exactly (they
#' share the design's strata and clusters): the intervals are approximations, and the exact ones need
#' the survey's bootstrap weights, which Statistics Canada holds in its Research Data Centres.
#'
#' Distinctions-based: each group is compared on its own. A row that pools every identity (\code{"Total
#' Indigenous"}, \code{"Indigenous identity"}) is kept but marked \code{pan_indigenous = TRUE}, since
#' a pooled figure can hide what differs between First Nations, Metis and Inuit. A row whose estimate
#' is flagged \code{E} is compared and marked; one flagged \code{F} or \code{x}, or with no estimate,
#' is not compared.
#'
#' @param data A data frame, one row per group.
#' @param group,estimate,lower,upper Column names: the group label, the estimate, and the published
#'   confidence limits.
#' @param reference The label of the reference group (default \code{"Non-Indigenous"}).
#' @param quality Optional column of quality flags (\code{E}, \code{F}, \code{x}, ...), as
#'   \code{\link{statcan_tidy}} gives them.
#' @param conf_level The confidence level of the published intervals and of the ones returned
#'   (default 0.95).
#' @return A data frame with \code{group}, \code{estimate}, \code{reference_estimate}, \code{ratio},
#'   \code{ratio_lower}, \code{ratio_upper}, \code{difference}, \code{difference_lower},
#'   \code{difference_upper}, \code{use_with_caution} and \code{pan_indigenous}, of class
#'   \code{rmbl_indigenous_gap} (\code{plot()} draws each group's difference or ratio).
#' @references
#' Statistics Canada (2025). Health indicators for First Nations adults living off reserve, Metis and
#' Inuit adults, 2015 to 2022. The Daily, 2025-02-13.
#' \url{https://www150.statcan.gc.ca/n1/daily-quotidien/250213/dq250213f-eng.htm}
#'
#' Carroll SR, Garba I, Figueroa-Rodriguez OL, et al. (2020). The CARE Principles for Indigenous Data
#' Governance. Data Science Journal 19:43. \doi{10.5334/dsj-2020-043}
#' @seealso \code{\link{statcan_tidy}}, \code{\link{age_standardise}}.
#' @examples
#' # Perceived mental health very good or excellent, adults, 2019/2022: The Daily, 2025-02-13
#' # (table 13-10-0924-01)
#' h <- indigenous_example("health_indicators")
#' mh <- h[h$period == "2019/2022" & h$age == "Total, 18 years and over" &
#'           h$indicator == "Perceived mental health, very good or excellent", ]
#' g <- indigenous_gap(mh, "group", "estimate", "lower", "upper", quality = "quality")
#' g
#' plot(g)
#' plot(g, what = "ratio")
#' @export
indigenous_gap <- function(data, group, estimate, lower, upper, reference = "Non-Indigenous",
                           quality = NULL, conf_level = 0.95) {
  if (!is.data.frame(data)) stop("`data` must be a data frame", call. = FALSE)
  for (nm in c("group", "estimate", "lower", "upper")) {
    v <- .rmbl_string1(get(nm), nm)
    if (!v %in% names(data)) stop(sprintf("column `%s` not found in `data`", v), call. = FALSE)
  }
  if (!is.null(quality)) {
    quality <- .rmbl_string1(quality, "quality")
    if (!quality %in% names(data)) stop(sprintf("column `%s` not found in `data`", quality), call. = FALSE)
  }
  reference <- .rmbl_string1(reference, "reference")
  conf_level <- .rmbl_conf_level(conf_level)
  g <- as.character(data[[group]])
  est <- .rmbl_num(data[[estimate]], "estimate")
  lo <- .rmbl_num(data[[lower]], "lower")
  hi <- .rmbl_num(data[[upper]], "upper")
  q <- if (is.null(quality)) rep("ok", length(g)) else as.character(data[[quality]])
  q[is.na(q) | q == ""] <- "ok"
  r <- which(g == reference)
  if (length(r) != 1L) {
    stop(sprintf("`reference` must name exactly one row of `%s` (\"%s\" names %d)", group, reference, length(r)),
         call. = FALSE)
  }
  if (q[r] %in% c("F", "x", "..", "...") || !is.finite(est[r])) {
    stop("the reference estimate is suppressed or missing: there is nothing to compare with", call. = FALSE)
  }
  bad <- is.finite(lo) & is.finite(hi) & is.finite(est) & (lo > est | hi < est)
  if (bad[r]) {
    stop("the reference group's published interval does not contain its estimate", call. = FALSE)
  }
  if (any(bad)) {
    # a published table can hold such a cell (a 100% with limits 85.5 to 98.6): said, and not compared
    warning(sprintf("the interval does not contain the estimate for: %s; not compared",
                    paste(g[bad], collapse = ", ")), call. = FALSE)
    est[bad] <- NA_real_
  }
  z <- stats::qnorm(1 - (1 - conf_level) / 2)
  se <- (hi - lo) / (2 * z)
  sel <- ifelse(lo > 0 & hi > 0, (log(hi) - log(lo)) / (2 * z), NA_real_)
  use <- seq_along(g)[-r]
  ok <- !(q[use] %in% c("F", "x", "..", "...")) & is.finite(est[use])
  diff <- est[use] - est[r]
  sd <- sqrt(se[use]^2 + se[r]^2)
  ratio <- est[use] / est[r]
  sr <- sqrt(sel[use]^2 + sel[r]^2)
  out <- data.frame(
    group = g[use], estimate = est[use], reference_estimate = est[r],
    ratio = ifelse(ok, ratio, NA_real_),
    ratio_lower = ifelse(ok & ratio > 0, exp(log(ratio) - z * sr), NA_real_),
    ratio_upper = ifelse(ok & ratio > 0, exp(log(ratio) + z * sr), NA_real_),
    difference = ifelse(ok, diff, NA_real_),
    difference_lower = ifelse(ok, diff - z * sd, NA_real_),
    difference_upper = ifelse(ok, diff + z * sd, NA_real_),
    use_with_caution = q[use] == "E" | q[r] == "E",
    pan_indigenous = .rmbl_pan_indigenous(g[use]),
    stringsAsFactors = FALSE)
  attr(out, "reference") <- reference
  attr(out, "conf_level") <- conf_level
  class(out) <- c("rmbl_indigenous_gap", "data.frame")
  out
}

#' Directly age-standardised rates, with exact gamma intervals
#'
#' The rate a population would have with the age structure of a standard population, for one or
#' more groups, with Fay and Feuer's gamma confidence interval.
#'
#' @details
#' With \eqn{d_i} events and \eqn{n_i} people in age group \eqn{i} and standard weights
#' \eqn{w_i} (the standard population's shares), the rate is \eqn{y = \sum w_i d_i / n_i}, its
#' variance \eqn{v = \sum (w_i / n_i)^2 d_i}, and with \eqn{w_M = \max_i w_i / n_i} the limits are
#' \eqn{\frac{v}{2y} \chi^2_{2y^2/v}(\alpha/2)} and
#' \eqn{\frac{v + w_M^2}{2(y + w_M)} \chi^2_{2(y + w_M)^2/(v + w_M^2)}(1 - \alpha/2)}
#' (Fay and Feuer 1997), exact when there are few events, as there are for small communities. With
#' no events the lower limit is 0. Rates are per \code{per} people.
#'
#' The choice of standard matters: Statistics Canada's comparisons of First Nations, Metis and Inuit
#' mortality standardise to the Indigenous population's own age structure (Kumar and Tjepkema 2019),
#' which is younger than Canada's.
#'
#' @param events,population Numbers of events and of people, one per age group (and group).
#' @param standard The standard population, one count per age group (its shares are the weights).
#' @param group Optional labels: one rate per group, each over the same age groups in the same order.
#' @param per Rate per this many people (default 100,000).
#' @param conf_level Confidence level (default 0.95).
#' @return A data frame with \code{group}, \code{events}, \code{rate}, \code{lower}, \code{upper},
#'   and the attributes \code{var} (the variances, on the per-person scale) for
#'   \code{\link{rate_gap}}.
#' @references Fay MP, Feuer EJ (1997). Confidence intervals for directly standardized rates: a method
#' based on the gamma distribution. Statistics in Medicine 16(7):791-801.
#' \doi{10.1002/(sici)1097-0258(19970415)16:7<791::aid-sim500>3.0.co;2-#}
#'
#' Kumar MB, Tjepkema M (2019). Suicide among First Nations people, Metis and Inuit (2011-2016):
#' Findings from the 2011 Canadian Census Health and Environment Cohort (CanCHEC). Statistics Canada
#' 99-011-X2019001.
#' @seealso \code{\link{rate_gap}}.
#' @examples
#' # made-up counts for one small community, by five age groups, to show the computation
#' std <- c(30000, 25000, 20000, 15000, 10000)   # a younger standard population
#' age_standardise(events = c(4, 9, 11, 6, 3), population = c(9000, 8000, 6000, 4000, 2000),
#'                 standard = std)
#' @export
age_standardise <- function(events, population, standard, group = NULL, per = 1e5, conf_level = 0.95) {
  events <- .rmbl_num(events, "events")
  population <- .rmbl_num(population, "population")
  standard <- .rmbl_num(standard, "standard")
  per <- .rmbl_scalar(per, "per", 1)
  conf_level <- .rmbl_conf_level(conf_level)
  k <- length(standard)
  if (!k || anyNA(standard) || any(standard < 0) || sum(standard) <= 0) {
    stop("`standard` must be non-negative counts, one per age group, not all zero", call. = FALSE)
  }
  if (length(events) != length(population)) stop("`events` and `population` must be the same length", call. = FALSE)
  if (anyNA(events) || any(events < 0) || any(abs(events - round(events)) > 1e-8)) {
    stop("`events` must be non-negative whole numbers", call. = FALSE)
  }
  if (anyNA(population) || any(population <= 0)) stop("`population` must be positive", call. = FALSE)
  if (is.null(group)) group <- rep("all", length(events))
  .rmbl_no_fn(group = group)
  group <- as.character(group)
  if (length(group) != length(events)) stop("`group` must have one label per row", call. = FALSE)
  w <- standard / sum(standard)
  a <- 1 - conf_level
  rows <- lapply(unique(group), function(gi) {
    i <- which(group == gi)
    if (length(i) != k) {
      stop(sprintf("group \"%s\" has %d age groups; `standard` has %d", gi, length(i), k), call. = FALSE)
    }
    d <- events[i]
    n <- population[i]
    wi <- w / n
    y <- sum(wi * d)
    v <- sum(wi^2 * d)
    wm <- max(wi)
    lower <- if (y > 0) v / (2 * y) * stats::qchisq(a / 2, 2 * y^2 / v) else 0
    upper <- (v + wm^2) / (2 * (y + wm)) * stats::qchisq(1 - a / 2, 2 * (y + wm)^2 / (v + wm^2))
    data.frame(group = gi, events = sum(d), rate = y * per, lower = lower * per, upper = upper * per,
               var = v, stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  attr(out, "var") <- stats::setNames(out$var, out$group)
  out$var <- NULL
  attr(out, "per") <- per
  attr(out, "conf_level") <- conf_level
  class(out) <- c("rmbl_dsr", "data.frame")
  out
}

#' The gap between two standardised rates
#'
#' The ratio and the difference of two directly standardised rates from \code{\link{age_standardise}},
#' with confidence intervals: log-normal for the ratio (variance \eqn{v_1/y_1^2 + v_2/y_2^2}) and
#' normal for the difference, the two rates independent. Both measures are reported, as the relative
#' gap alone hides how large the absolute one is (Anderson et al. 2016).
#'
#' @param x Output of \code{\link{age_standardise}} (two or more groups).
#' @param group,reference The labels of the group and of the reference group.
#' @return A one-row data frame: \code{group}, \code{reference}, \code{ratio} with
#'   \code{ratio_lower}/\code{ratio_upper}, and \code{difference} (per \code{per} people) with
#'   \code{difference_lower}/\code{difference_upper}.
#' @references Anderson I, Robson B, Connolly M, et al. (2016). Indigenous and tribal peoples' health
#' (The Lancet-Lowitja Institute Global Collaboration): a population study. The Lancet
#' 388(10040):131-157. \doi{10.1016/S0140-6736(16)00345-7}
#' @examples
#' # made-up counts, to show the computation
#' std <- c(30000, 25000, 20000, 15000, 10000)
#' r <- age_standardise(events = c(4, 9, 11, 6, 3, 2, 4, 6, 5, 4),
#'                      population = c(9000, 8000, 6000, 4000, 2000,
#'                                     20000, 19000, 18000, 15000, 12000),
#'                      standard = std, group = rep(c("Inuit", "Non-Indigenous"), each = 5))
#' plot(r)
#' rate_gap(r, "Inuit", "Non-Indigenous")
#' @export
rate_gap <- function(x, group, reference) {
  if (!inherits(x, "rmbl_dsr")) stop("`x` must come from age_standardise()", call. = FALSE)
  group <- .rmbl_string1(group, "group")
  reference <- .rmbl_string1(reference, "reference")
  for (g in c(group, reference)) {
    if (!g %in% x$group) stop(sprintf("\"%s\" is not a group of `x`", g), call. = FALSE)
  }
  per <- attr(x, "per")
  z <- stats::qnorm(1 - (1 - attr(x, "conf_level")) / 2)
  v <- attr(x, "var")
  y1 <- x$rate[x$group == group] / per
  y0 <- x$rate[x$group == reference] / per
  if (y1 <= 0 || y0 <= 0) stop("a ratio needs both rates above zero", call. = FALSE)
  slr <- sqrt(v[[group]] / y1^2 + v[[reference]] / y0^2)
  sd <- sqrt(v[[group]] + v[[reference]])
  data.frame(group = group, reference = reference, ratio = y1 / y0,
             ratio_lower = exp(log(y1 / y0) - z * slr), ratio_upper = exp(log(y1 / y0) + z * slr),
             difference = (y1 - y0) * per, difference_lower = (y1 - y0 - z * sd) * per,
             difference_upper = (y1 - y0 + z * sd) * per, stringsAsFactors = FALSE)
}

#' Generations of residential school attendance in a family
#'
#' Codes the intergenerational exposure used in the epidemiology of Indian Residential Schools: how
#' many generations before the respondent attended, 0 (neither parents nor grandparents), 1 (parents
#' or grandparents) or 2 (both a parent and a grandparent), as in McQuaid et al. (2017).
#'
#' @details
#' Each answer is \code{TRUE} (attended), \code{FALSE} (did not) or \code{NA} (not known). A known
#' attendance in one generation is at least one generation whatever the other is; otherwise an
#' unknown answer leaves the count unknown (\code{NA}), since it may hide an attendance.
#'
#' @param parent,grandparent Logical vectors: did a parent, did a grandparent attend.
#' @return An integer vector of 0, 1, 2 or \code{NA}.
#' @references McQuaid RJ, Bombay A, McInnis OA, Humeny C, Matheson K, Anisman H (2017). Suicide
#' ideation and attempts among First Nations peoples living on-reserve in Canada: the intergenerational
#' and cumulative effects of Indian Residential Schools. Canadian Journal of Psychiatry 62(6):422-430.
#' \doi{10.1177/0706743717702075}
#'
#' Bombay A, Matheson K, Anisman H (2014). The intergenerational effects of Indian Residential Schools:
#' implications for the concept of historical trauma. Transcultural Psychiatry 51(3):320-338.
#' \doi{10.1177/1363461513503380}
#' @seealso \code{\link{exposure_trend}}.
#' @examples
#' generations_exposed(c(TRUE, FALSE, TRUE, NA, FALSE), c(TRUE, FALSE, FALSE, TRUE, NA))
#' @export
generations_exposed <- function(parent, grandparent) {
  for (nm in c("parent", "grandparent")) {
    v <- get(nm)
    if (!is.logical(v)) stop(sprintf("`%s` must be TRUE, FALSE or NA for each person", nm), call. = FALSE)
  }
  if (length(parent) != length(grandparent)) {
    stop("`parent` and `grandparent` must be the same length", call. = FALSE)
  }
  out <- as.integer(parent %in% TRUE) + as.integer(grandparent %in% TRUE)
  unknown <- (is.na(parent) & !grandparent %in% TRUE) | (is.na(grandparent) & !parent %in% TRUE)
  out[unknown & out == 0L] <- NA_integer_
  out
}

#' A dose-response across generations of exposure
#'
#' For counts of an outcome (suicidal thoughts, distress) among people with 0, 1 or 2 generations of
#' residential school attendance in their family (or any ordered exposure), the odds ratio of each
#' level against the lowest, with Woolf intervals, and the Cochran-Armitage test for a trend across
#' the levels.
#'
#' @param cases Number with the outcome at each exposure level.
#' @param n Number of people at each level.
#' @param dose The exposure levels, in order (default \code{0, 1, 2, ...}); the trend test scores them.
#' @param conf_level Confidence level (default 0.95).
#' @return A data frame with \code{dose}, \code{cases}, \code{n}, \code{proportion},
#'   \code{odds_ratio}, \code{lower}, \code{upper}; the trend test is the attribute \code{trend}
#'   (an \code{htest}).
#' @details Counts must be unweighted. For a complex survey, take the weighted analysis from the survey
#' itself (\code{\link{survey_design}}): this function is for published or aggregated counts.
#' @references McQuaid RJ, et al. (2017), see \code{\link{generations_exposed}}.
#' @examples
#' # made-up counts by 0, 1 and 2 generations of attendance, to show the computation
#' et <- exposure_trend(cases = c(60, 95, 70), n = c(500, 520, 300))
#' et
#' plot(et)
#' @export
exposure_trend <- function(cases, n, dose = seq_along(cases) - 1L, conf_level = 0.95) {
  cases <- .rmbl_num(cases, "cases")
  n <- .rmbl_num(n, "n")
  dose <- .rmbl_num(dose, "dose")
  conf_level <- .rmbl_conf_level(conf_level)
  k <- length(cases)
  if (k < 2L || length(n) != k || length(dose) != k) {
    stop("`cases`, `n` and `dose` must have one entry per level, two levels at least", call. = FALSE)
  }
  if (anyNA(c(cases, n, dose)) || any(cases < 0) || any(n <= 0) || any(cases > n) ||
      any(abs(c(cases, n) - round(c(cases, n))) > 1e-8)) {
    stop("`cases` and `n` must be whole numbers with 0 <= cases <= n and n > 0", call. = FALSE)
  }
  if (is.unsorted(dose, strictly = TRUE)) stop("`dose` must be strictly increasing", call. = FALSE)
  z <- stats::qnorm(1 - (1 - conf_level) / 2)
  a <- cases
  b <- n - cases
  # the Haldane-Anscombe half added to every cell when one is empty, so the odds ratio is finite
  adj <- if (any(c(a, b) == 0)) 0.5 else 0
  or <- ((a + adj) / (b + adj)) / ((a[1] + adj) / (b[1] + adj))
  se <- sqrt(1 / (a + adj) + 1 / (b + adj) + 1 / (a[1] + adj) + 1 / (b[1] + adj))
  se[1] <- 0
  out <- data.frame(dose = dose, cases = a, n = n, proportion = a / n, odds_ratio = or,
                    lower = exp(log(or) - z * se), upper = exp(log(or) + z * se))
  out$lower[1] <- out$upper[1] <- 1
  # ponytail: with two levels the weighted fit inside prop.trend.test is exact and stats warns
  # "essentially perfect fit"; the chi-squared trend statistic is still the right one, so only that
  # warning is muffled.
  attr(out, "trend") <- withCallingHandlers(stats::prop.trend.test(a, n, score = dose), warning = function(w) {
    if (grepl("perfect fit", conditionMessage(w), fixed = TRUE)) invokeRestart("muffleWarning")
  })
  class(out) <- c("rmbl_exposure_trend", "data.frame")
  out
}

#' Calls to Action completed, year by year
#'
#' The number of the Truth and Reconciliation Commission's 94 Calls to Action that the Yellowhead
#' Institute's annual accountability reports judged complete, by the year they were completed, to
#' the end of 2022: the only counts here are those the reports state.
#'
#' @return A data frame with \code{period}, \code{year_end}, \code{completed}, \code{cumulative}
#'   and \code{source}.
#' @details
#' 2015-2019: 8 (13 in all by December 2022, less those of 2020-2022); 2020: none; 2021: 3, all in
#' June; 2022: 2 (Jewell and Mosby 2021, 2022). Other trackers count otherwise: the federal government
#' reports by theme rather than call by call; CBC's Beyond 94 and Indigenous Watchdog grade each call
#' on their own scales and are copyrighted, so their tables are not reproduced. The reports are
#' licensed CC BY-NC 2.5 Canada; the counts are facts taken from them, with the reports cited.
#' @references
#' Jewell E, Mosby I (2021). Calls to Action Accountability: A 2021 Status Update on Reconciliation.
#' Yellowhead Institute, Toronto Metropolitan University.
#'
#' Jewell E, Mosby I (2022). Calls to Action Accountability: A 2022 Status Update on Reconciliation.
#' Yellowhead Institute, Toronto Metropolitan University.
#'
#' Truth and Reconciliation Commission of Canada (2015). Truth and Reconciliation Commission of
#' Canada: Calls to Action. Winnipeg.
#' @seealso \code{\link{trc_progress}}.
#' @examples
#' trc_completions()
#' @export
trc_completions <- function() {
  d <- data.frame(period = c("2015-2019", "2020", "2021", "2022"), year_end = c(2019L, 2020L, 2021L, 2022L),
                  completed = c(8L, 0L, 3L, 2L), stringsAsFactors = FALSE)
  d$cumulative <- cumsum(d$completed)
  d$source <- c("Jewell and Mosby (2022): 13 complete in all", "Jewell and Mosby (2021)",
                "Jewell and Mosby (2021)", "Jewell and Mosby (2022)")
  d
}

#' How fast the Calls to Action are being completed
#'
#' From cumulative counts of completed Calls to Action over time, the completion rate (calls a year),
#' its exact Poisson interval, and the year all 94 would be complete at that rate.
#'
#' @details
#' Completions are taken as a Poisson process with a constant rate over the span from the start
#' (\code{start}, the Commission's final report in December 2015) to the last count: the rate is
#' \eqn{c / T} with the exact (Garwood) interval for \eqn{c} completed calls, and the projection is
#' the year \eqn{94 - c} more would take at that rate (at the interval's ends, its range). A constant
#' rate is the simplest model and the one the Yellowhead Institute's projection uses ("42 years, or
#' until 2065", 2022); the pace has not been constant, so the projection is a description of the pace
#' so far, not a forecast.
#'
#' @param completed Cumulative number completed at each date (default: \code{\link{trc_completions}}).
#' @param year_end The year each count was made to (end of year).
#' @param total Number of Calls to Action (94).
#' @param start When counting began, as a year with a fraction (2015.96: December 15, 2015).
#' @param conf_level Confidence level (default 0.95).
#' @return A one-row data frame: \code{completed}, \code{remaining}, \code{years}, \code{rate},
#'   \code{rate_lower}, \code{rate_upper}, \code{complete_by}, \code{complete_by_early},
#'   \code{complete_by_late}, of class \code{rmbl_trc_progress}; \code{plot()} draws the
#'   completions and the projection, with the band the rate's interval gives.
#' @seealso \code{\link{trc_completions}}.
#' @examples
#' p <- trc_progress()
#' p
#' plot(p)
#' @export
trc_progress <- function(completed = trc_completions()$cumulative, year_end = trc_completions()$year_end,
                         total = 94, start = 2015.96, conf_level = 0.95) {
  completed <- .rmbl_num(completed, "completed")
  year_end <- .rmbl_num(year_end, "year_end")
  total <- .rmbl_scalar(total, "total", 1)
  start <- .rmbl_scalar(start, "start")
  conf_level <- .rmbl_conf_level(conf_level)
  if (!length(completed) || length(completed) != length(year_end) || anyNA(c(completed, year_end))) {
    stop("`completed` and `year_end` must be one count per year, with no NA", call. = FALSE)
  }
  if (is.unsorted(completed) || any(completed < 0) || any(completed > total)) {
    stop("`completed` must be cumulative counts between 0 and `total`", call. = FALSE)
  }
  c1 <- completed[length(completed)]
  t1 <- year_end[length(year_end)] + 1
  span <- t1 - start
  if (span <= 0) stop("the last count must come after `start`", call. = FALSE)
  a <- 1 - conf_level
  lo <- if (c1 > 0) stats::qgamma(a / 2, c1) / span else 0
  hi <- stats::qgamma(1 - a / 2, c1 + 1) / span
  rem <- total - c1
  by <- function(r) if (rem == 0) t1 else if (r > 0) t1 + rem / r else Inf
  out <- data.frame(completed = c1, remaining = rem, years = span, rate = c1 / span, rate_lower = lo,
                    rate_upper = hi, complete_by = by(c1 / span), complete_by_early = by(hi),
                    complete_by_late = by(lo))
  # the counts behind it, from `start`, for plot()
  attr(out, "history") <- data.frame(year = c(start, year_end + 1), completed = c(0, completed))
  attr(out, "total") <- total
  class(out) <- c("rmbl_trc_progress", "data.frame")
  out
}

#' The Indigenous health and wellbeing tables the data service holds
#'
#' Lists the First Nations, Metis and Inuit tables mirrored at the data service: Statistics Canada's
#' Indigenous-titled tables (\code{statcan_indigenous}) and the 2021 Census Indigenous Population
#' Profile (\code{census2021_ipp}), with their descriptions, row counts and licences, searchable.
#'
#' @param pattern Optional regular expression matched against the descriptions (case ignored).
#' @param refresh Fetch the manifest again (default \code{FALSE}).
#' @return A data frame: \code{key}, \code{rows}, \code{description}, \code{license}, \code{source}.
#' @details Needs the data service key (\code{\link{bricklayer_llm_login}}). Only openly licensed
#' aggregate tables are mirrored. First Nations Information Governance Centre data (the First Nations
#' Regional Health Survey and its companions) are governed by the OCAP(R) principles and are not; ask
#' the Centre (\url{https://fnigc.ca}).
#' @examples
#' \dontrun{
#' indigenous_tables("mental health")
#' }
#' @export
indigenous_tables <- function(pattern = NULL, refresh = FALSE) {
  if (!is.null(pattern)) pattern <- .rmbl_string1(pattern, "pattern")
  m <- bricklayer_data_manifest(refresh = refresh)
  ds <- Filter(function(d) is.character(d$key) && grepl("^(statcan_indigenous|census2021_ipp)/", d$key), m$datasets)
  out <- data.frame(
    key = vapply(ds, function(d) d$key, ""),
    rows = vapply(ds, function(d) as.numeric(d$rows %||% NA), 0),
    description = vapply(ds, function(d) as.character(d$meta$description %||% "")[1L], ""),
    license = vapply(ds, function(d) as.character(d$meta$license %||% "")[1L], ""),
    source = vapply(ds, function(d) as.character(d$meta$source %||% "")[1L], ""),
    stringsAsFactors = FALSE)
  if (!is.null(pattern)) out <- out[grepl(pattern, out$description, ignore.case = TRUE), , drop = FALSE]
  rownames(out) <- NULL
  out
}
