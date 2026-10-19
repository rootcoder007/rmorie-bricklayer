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
#' Tidies a Statistics Canada full-table download (the "CSV for database loading" form, as
#' the data service mirrors it under \code{statcan_indigenous/tbl_<pid>}): \code{VALUE} as
#' a number, and the quality flags kept beside it in \code{quality}.
#'
#' @details Statistics Canada flags every estimate: \code{E} use with caution, \code{F}
#' too unreliable to be published, \code{x} suppressed to meet the confidentiality
#' requirements of the Statistics Act, \code{..} not available, \code{...} not applicable.
#' An \code{F}, \code{x}, \code{..} or \code{...} cell has no value here (\code{NA}),
#' whatever the file holds, and nothing in the package imputes it or works it back from
#' totals and margins: a suppressed cell is suppressed to protect people, and small First
#' Nations, Metis and Inuit communities most of all. \code{E} values are kept and marked.
#'
#' The census data tables (98-10-xxxx) come in a wide layout: one column per member of a
#' dimension (\code{"Indigenous identity (9):Inuk (Inuit)[6]"}), each followed by its
#' \code{Symbol} column, and no \code{VALUE}. They are made long first: the dimension
#' becomes a column of member labels (\code{"Indigenous identity (9)"}), the values
#' \code{VALUE} and the symbols \code{STATUS}, so every Statistics Canada table reads the
#' same way.
#'
#' A label that names two members of one dimension (the census tables repeat labels under
#' different parents, and the file drops the hierarchy) gets its member number from the
#' coordinate: \code{"Without children [3]"} and \code{"Without children [7]"}. Other
#' labels are left as they are.
#'
#' @param x A data frame read from a Statistics Canada table (English-language full-table
#'   CSV), or a key of the data service (\code{"statcan_indigenous/tbl_13100924"}, or the
#'   eight-digit table id alone). A key needs a data service key: sign in once with
#'   \code{\link{dlogin}} (see \code{\link{dload}}); a data
#'   frame you read yourself needs none.
#' @return The data frame with \code{VALUE} numeric and a factor column \code{quality}
#'   with levels \code{"ok"}, \code{"E"}, \code{"F"}, \code{"x"}, \code{".."},
#'   \code{"..."}, of class \code{c("rmbl_statcan", "data.frame")}.
#' @references Statistics Canada. Symbol legend.
#'   \url{https://www.statcan.gc.ca/en/concepts/definitions/guide-symbol}
#' @seealso \code{\link{indgap}}, \code{\link{indtabs}}.
#' @examples
#' # the layout of a downloaded table, with one cell suppressed
#' d <- data.frame(REF_DATE = "2019/2022", GEO = "Canada",
#'                 `Indigenous identity` = c("First Nations", "Inuk (Inuit)",
#'                                           "Non-Indigenous"),
#'                 VALUE = c("45.8", "", "61.5"), STATUS = c("", "x", ""),
#'                 check.names = FALSE)
#' sctidy(d)
#' \dontrun{
#' # needs a data service key: sign in once with dlogin()
#' t924 <- sctidy("13100924")
#' }
#' @export
sctidy <- function(x) {
  if (is.character(x) && length(x) == 1L && !is.na(x)) {
    key <- if (grepl("^[0-9]{8}$", x)) paste0("statcan_indigenous/tbl_", x) else x
    x <- dload(key)
  }
  if (!is.data.frame(x)) stop("`x` must be a data frame or a table key", call. = FALSE)
  if (!"VALUE" %in% names(x)) x <- .rmbl_statcan_long(x)
  if (is.null(x)) {
    stop("`x` has no VALUE column, nor census columns: it is not a Statistics Canada table", call. = FALSE)
  }
  x <- .rmbl_statcan_members(x)
  st <- if ("STATUS" %in% names(x)) as.character(x$STATUS) else rep("", nrow(x))
  st[is.na(st)] <- ""
  st <- .rmbl_utf8(trimws(st))
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

# Rows that pool groups (a pan-Indigenous total, as against First Nations, Metis or Inuit): those
# named in `pooled`, or by default labels that begin "Total", "Indigenous identity",
# "Aboriginal identity" or "Indigenous population".
.rmbl_pan_indigenous <- function(g, pooled_groups = NULL) {
  if (!is.null(pooled_groups)) {
    .rmbl_no_fn(pooled_groups = pooled_groups)
    if (!is.character(pooled_groups) || anyNA(pooled_groups)) {
      stop("`pooled` must be the labels of the rows that pool other groups", call. = FALSE)
    }
    return(trimws(g) %in% trimws(pooled_groups))
  }
  grepl("^total|^indigenous identity|^aboriginal identity|^total indigenous|^indigenous population",
        trimws(tolower(g)))
}

# The package's quality vocabulary: "ok", "E" (use with caution), "F", "x", "..", "..." (no value).
# A flag outside it is said once and treated as "ok": recode another agency's flags with
# qltyrcd() first.
.rmbl_qflags <- function(q) {
  q <- trimws(as.character(q))
  q[is.na(q) | q == ""] <- "ok"
  odd <- setdiff(unique(q), c("ok", "E", "F", "x", "..", "..."))
  if (length(odd)) {
    warning(sprintf("quality flag(s) %s not recognised: treated as ok; recode them with qltyrcd()",
                    paste0("\"", odd, "\"", collapse = ", ")), call. = FALSE)
    q[q %in% odd] <- "ok"
  }
  q
}

# Published limits that miss their own estimate (it happens: a 100% with limits 85.5 to 98.6): the
# estimate is set to NA, so the row is not compared, and the rows are named in one warning.
.rmbl_contains <- function(est, lo, hi, labels) {
  bad <- is.finite(lo) & is.finite(hi) & is.finite(est) & (lo > est | hi < est)
  if (any(bad)) {
    warning(sprintf("the interval does not contain the estimate for: %s; not compared",
                    paste(unique(labels[bad]), collapse = ", ")), call. = FALSE)
    est[bad] <- NA_real_
  }
  est
}

#' Recode another agency's quality flags to the package's
#'
#' The comparisons of this family read Statistics Canada's quality flags: \code{E} (use
#' with caution), and \code{F}, \code{x}, \code{..}, \code{...} (no value: too unreliable,
#' suppressed, not available, not applicable). Other agencies flag otherwise: the
#' Australian Bureau of Statistics \code{np} (not published) and \code{*} or \code{**}
#' (relative standard error over 25\% or 50\%), Stats NZ \code{S} (suppressed), the US
#' Census Bureau \code{(X)}. This maps them to the package's vocabulary, so suppressed
#' cells are never compared and uncertain ones are marked.
#'
#' @param x The flags, one per row.
#' @param suppr Flags meaning the value must not be used (it becomes \code{"x"}).
#' @param caution Flags meaning the value may be used with caution (it becomes
#'   \code{"E"}).
#' @return A character vector of \code{"ok"}, \code{"E"} and \code{"x"}; empty and missing
#'   flags are \code{"ok"}.
#' @seealso \code{\link{limfrom}}, \code{\link{indgap}}.
#' @examples
#' # flags as an Australian table might give them
#' qltyrcd(c("", "np", "*", "**", NA), suppr = c("np", "**"), caution = "*")
#' @export
qltyrcd <- function(x, suppr = c("F", "x", "..", "..."), caution = "E") {
  .rmbl_no_fn(x = x, suppressed = suppr, caution = caution)
  if (!is.atomic(x)) stop("`x` must be a vector of flags", call. = FALSE)
  for (nm in c("suppr", "caution")) {
    v <- get(nm)
    if (!is.character(v) || anyNA(v)) stop(sprintf("`%s` must be flags (character)", nm), call. = FALSE)
  }
  if (length(intersect(suppr, caution))) stop("a flag cannot be both suppressed and caution", call. = FALSE)
  f <- trimws(as.character(x))
  out <- rep("ok", length(f))
  out[f %in% trimws(caution)] <- "E"
  out[f %in% trimws(suppr)] <- "x"
  out
}

#' Confidence limits from a standard error, a coefficient of variation or a margin of
#' error
#'
#' The comparisons of this family take an estimate and its published confidence limits.
#' Agencies that publish a standard error, a relative standard error (coefficient of
#' variation) or a margin of error instead give the same information; this turns it into
#' limits at the level wanted.
#'
#' @details With an estimate \eqn{e} and \eqn{z = \Phi^{-1}(1 - \alpha/2)} for the level
#' wanted, a standard error \eqn{s} gives \eqn{e \pm z s}; a coefficient of variation
#' \eqn{c} (in percent) gives \eqn{s = e c / 100}; a margin of error \eqn{m} at level
#' \code{moelev} (the American Community Survey publishes 90\% margins) gives
#' \eqn{s = m / z_{moe}}. The limits are symmetric on the estimate's scale.
#'
#' @param est The estimates.
#' @param se,cv,moe Give one: standard errors, coefficients of variation (relative
#'   standard errors, in percent), or margins of error.
#' @param moelev The confidence level of the margins of error (default 0.90).
#' @param conflvl The level of the limits returned (default 0.95).
#' @return A data frame: \code{estimate}, \code{lower}, \code{upper}, \code{se}.
#' @seealso \code{\link{qltyrcd}}, \code{\link{indgap}}.
#' @examples
#' limfrom(c(24.1, 31.5), cv = c(8, 12))
#' limfrom(1520, moe = 210)                 # a 90% margin of error
#' @export
limfrom <- function(est, se = NULL, cv = NULL, moe = NULL, moelev = 0.90, conflvl = 0.95) {
  est <- .rmbl_num(est, "est")
  given <- !vapply(list(se, cv, moe), is.null, NA)
  if (sum(given) != 1L) stop("give one of `se`, `cv` or `moe`", call. = FALSE)
  conflvl <- .rmbl_conf_level(conflvl)
  moelev <- .rmbl_conf_level(moelev, "moelev")
  s <- if (given[1L]) .rmbl_num(se, "se") else if (given[2L]) est * .rmbl_num(cv, "cv") / 100 else
    .rmbl_num(moe, "moe") / stats::qnorm(1 - (1 - moelev) / 2)
  if (length(s) != length(est) && length(s) != 1L) {
    stop("the standard errors must be one per estimate", call. = FALSE)
  }
  if (any(s < 0, na.rm = TRUE)) stop("standard errors, CVs and margins must not be negative", call. = FALSE)
  z <- stats::qnorm(1 - (1 - conflvl) / 2)
  data.frame(estimate = est, lower = est - z * s, upper = est + z * s, se = rep_len(s, length(est)))
}

#' Compare published group estimates with a reference group
#'
#' For published estimates with their confidence limits (percentages, rates, years of life
#' expectancy: any scale, with the limits on the same scale), the ratio and the difference
#' of each group to a reference group, with confidence intervals worked from the published
#' ones: First Nations, Metis and Inuit against non-Indigenous people, Aboriginal and
#' Torres Strait Islander people against non-Indigenous Australians, Maori against
#' non-Maori, or any groups with published intervals.
#'
#' @details Each published interval gives a standard error, \eqn{s = (u - l) / (2 z)}, on
#' the scale of the estimate for the difference and on the log scale,
#' \eqn{\sigma = (\log u - \log l) / (2 z)}, for the ratio, with
#' \eqn{z = \Phi^{-1}(1 - \alpha/2)}. This takes the interval as symmetric on that scale;
#' for asymmetric (gamma, logit, Wilson) limits it averages the two sides. With a standard
#' error, a coefficient of variation or a margin of error instead of limits, make limits
#' with \code{\link{limfrom}} first. The groups are treated as independent samples, so
#' the standard error of a difference is \eqn{\sqrt{s_g^2 + s_r^2}} and of a log ratio
#' \eqn{\sqrt{\sigma_g^2 + \sigma_r^2}}. Disjoint domains of one survey are nearly
#' independent but not exactly (they share the design's strata and clusters): the
#' intervals are approximations, and the exact ones need the survey's replicate weights
#' (for Statistics Canada's surveys, in its Research Data Centres). The reference must not
#' contain the groups: compare with non-Indigenous people, not with a total, whose
#' covariance with each group is large and positive (the function warns when the reference
#' looks like a total). A lower limit of 0 (a limit cut at zero) leaves the ratio's
#' interval \code{NA}.
#'
#' Distinctions-based: each group is compared on its own. A row that pools groups is kept
#' but marked \code{poogrp = TRUE}, since a pooled figure can hide what differs
#' between the groups it pools: name such rows in \code{pooled} (by default labels
#' beginning "Total", "Indigenous identity", "Aboriginal identity" or "Indigenous
#' population" are taken as pooled). A row flagged \code{E} (in the group or the
#' reference) is compared and marked; one flagged \code{F}, \code{x}, \code{..} or
#' \code{...}, with no estimate, or whose published interval does not contain its own
#' estimate, is not compared. Other agencies' flags: \code{\link{qltyrcd}}.
#'
#' @param data A data frame, one row per group (filtered to one period, age group, sex and
#'   place: a group appearing twice is refused).
#' @param grp,est,lower,upper Column names: the group label, the estimate, and its
#'   published confidence limits, on one scale.
#' @param ref The label of the reference group (default \code{"Non-Indigenous"}).
#' @param qual Optional column of quality flags in the package's vocabulary
#'   (\code{"E"}, \code{"F"}, \code{"x"}, \code{".."}, \code{"..."}; see
#'   \code{\link{qltyrcd}} for other agencies' flags).
#' @param conflvl The confidence level of the published intervals and of the ones
#'   returned (default 0.95).
#' @param pooled Optional labels of the rows that pool other groups (for example
#'   \code{"Aboriginal and Torres Strait Islander"} beside its parts, or a "Total
#'   Indigenous" row); by default the labels described in Details.
#' @return A data frame of class \code{rmbl_indigenous_gap}, one row per group but the
#'   reference. The columns are \code{group}, \code{estimate}, \code{refest}, \code{ratio},
#'   \code{ratiolo}, \code{ratioup}, \code{difference}, \code{diflo},
#'   \code{difup}, \code{usewithcau} and \code{poogrp}; attributes
#'   \code{reference} and \code{conflvl}. \code{plot()} draws each group's difference
#'   or ratio.
#' @references Statistics Canada (2025). Health indicators for First Nations adults living
#' off reserve, Metis and Inuit adults, 2015 to 2022. The Daily, 2025-02-13.\cr
#' \url{https://www150.statcan.gc.ca/n1/daily-quotidien/250213/dq250213f-eng.htm}
#'
#' Carroll SR, Garba I, Figueroa-Rodriguez OL, et al. (2020). The CARE Principles for
#' Indigenous Data Governance. Data Science Journal 19:43.
#' \doi{10.5334/dsj-2020-043}
#' @seealso \code{\link{dstntst}} before pooling, \code{\link{limfrom}},
#'   \code{\link{qltyrcd}}, \code{\link{agestd}}.
#' @examples
#' # Perceived mental health very good or excellent, adults, 2019/2022 (Statistics Canada,
#' # table 13-10-0924-01; The Daily, 2025-02-13)
#' h <- indiex("health")
#' mh <- h[h$period == "2019/2022" & h$age == "Total, 18 years and over" &
#'           h$indicator == "Perceived mental health, very good or excellent", ]
#' g <- indgap(mh, "group", "estimate", "lower", "upper", qual = "quality")
#' g
#' plot(g)
#' plot(g, what = "ratio")
#' # your own table: made-up numbers in another country's layout, with relative standard
#' # errors instead of limits and that agency's flags
#' own <- data.frame(group = c("Aboriginal", "Torres Strait Islander",
#'                             "Aboriginal and Torres Strait Islander",
#'                             "Non-Indigenous Australians"),
#'                   pct = c(31.2, 27.5, 30.8, 18.9), rse = c(4.1, 22.0, 3.9, 1.2),
#'                   flag = c("", "*", "", ""))
#' own <- cbind(own, limfrom(own$pct, cv = own$rse)[c("lower", "upper")])
#' own$q <- qltyrcd(own$flag, suppr = c("np", "**"), caution = "*")
#' indgap(own, "group", "pct", "lower", "upper",
#'                ref = "Non-Indigenous Australians",
#'                qual = "q", pooled = "Aboriginal and Torres Strait Islander")
#' @export
indgap <- function(data, grp, est, lower, upper, ref = "Non-Indigenous",
                           qual = NULL, conflvl = 0.95, pooled = NULL) {
  if (!is.data.frame(data)) stop("`data` must be a data frame", call. = FALSE)
  for (nm in c("grp", "est", "lower", "upper")) {
    v <- .rmbl_string1(get(nm), nm)
    if (!v %in% names(data)) stop(sprintf("column `%s` not found in `data`", v), call. = FALSE)
  }
  if (!is.null(qual)) {
    qual <- .rmbl_string1(qual, "qual")
    if (!qual %in% names(data)) stop(sprintf("column `%s` not found in `data`", qual), call. = FALSE)
  }
  ref <- .rmbl_string1(ref, "ref")
  if (grepl("^total", trimws(ref), ignore.case = TRUE) || .rmbl_pan_indigenous(ref, pooled)) {
    warning("the reference looks like a total that contains the groups: the intervals assume independent samples ",
            "and are not right for it; compare with the groups' complement (for example non-Indigenous people)",
            call. = FALSE)
  }
  conflvl <- .rmbl_conf_level(conflvl)
  g <- .rmbl_utf8(trimws(as.character(data[[grp]])))
  .est <- .rmbl_num(data[[est]], "est")
  lo <- .rmbl_num(data[[lower]], "lower")
  hi <- .rmbl_num(data[[upper]], "upper")
  q <- .rmbl_qflags(if (is.null(qual)) rep("ok", length(g)) else data[[qual]])
  if (anyDuplicated(g)) {
    stop("a group appears twice: filter `data` to one period, age group, sex and place", call. = FALSE)
  }
  r <- which(g == trimws(ref))
  if (length(r) != 1L) {
    stop(sprintf("`ref` must name exactly one row of `%s` (\"%s\" names %d)", grp, ref, length(r)),
         call. = FALSE)
  }
  if (q[r] %in% c("F", "x", "..", "...") || !is.finite(.est[r])) {
    stop("the reference estimate is suppressed or missing: there is nothing to compare with", call. = FALSE)
  }
  bad <- is.finite(lo) & is.finite(hi) & is.finite(.est) & (lo > .est | hi < .est)
  if (bad[r]) {
    stop("the reference group's published interval does not contain its estimate", call. = FALSE)
  }
  if (any(bad)) {
    # a published table can hold such a cell (a 100% with limits 85.5 to 98.6): said, and not compared
    warning(sprintf("the interval does not contain the estimate for: %s; not compared",
                    paste(g[bad], collapse = ", ")), call. = FALSE)
    .est[bad] <- NA_real_
  }
  z <- stats::qnorm(1 - (1 - conflvl) / 2)
  se <- (hi - lo) / (2 * z)
  sel <- ifelse(lo > 0 & hi > 0, (log(hi) - log(lo)) / (2 * z), NA_real_)
  use <- seq_along(g)[-r]
  ok <- !(q[use] %in% c("F", "x", "..", "...")) & is.finite(.est[use])
  diff <- .est[use] - .est[r]
  sd <- sqrt(se[use]^2 + se[r]^2)
  ratio <- .est[use] / .est[r]
  sr <- sqrt(sel[use]^2 + sel[r]^2)
  out <- data.frame(
    group = g[use], estimate = .est[use], refest = .est[r],
    ratio = ifelse(ok, ratio, NA_real_),
    ratiolo = ifelse(ok & ratio > 0, exp(log(ratio) - z * sr), NA_real_),
    ratioup = ifelse(ok & ratio > 0, exp(log(ratio) + z * sr), NA_real_),
    difference = ifelse(ok, diff, NA_real_),
    diflo = ifelse(ok, diff - z * sd, NA_real_),
    difup = ifelse(ok, diff + z * sd, NA_real_),
    usewithcau = q[use] == "E" | q[r] == "E",
    poogrp = .rmbl_pan_indigenous(g[use], pooled),
    stringsAsFactors = FALSE)
  attr(out, "reference") <- ref
  attr(out, "conflvl") <- conflvl
  class(out) <- c("rmbl_indigenous_gap", "data.frame")
  out
}

#' Directly age-standardised rates, with Fay-Feuer gamma intervals
#'
#' The rate a population would have with the age structure of a standard population, for
#' one or more groups, with Fay and Feuer's gamma confidence interval.
#'
#' @details With \eqn{d_i} events and \eqn{n_i} people in age group \eqn{i} and standard
#' weights \eqn{w_i} (the standard population's shares), the rate is
#' \eqn{y = \sum w_i d_i / n_i}, its variance \eqn{v = \sum (w_i / n_i)^2 d_i}, and with
#' \eqn{w_M = \max_i w_i / n_i} the limits are
#' \eqn{\frac{v}{2y} \chi^2_{2y^2/v}(\alpha/2)} and
#' \eqn{\frac{v + w_M^2}{2(y + w_M)} \chi^2_{2(y + w_M)^2/(v + w_M^2)}(1 - \alpha/2)} (Fay
#' and Feuer 1997). The interval is conservative (coverage at least nominal in Fay and
#' Feuer's simulations) and reduces to the exact Garwood interval for a single age group:
#' suited to the few events of small communities. With no events the lower limit is 0.
#' Rates are per \code{per} people. Age groups are matched to \code{std} by position:
#' order the rows of each group by age, in the order of \code{std}.
#'
#' The choice of standard matters: Statistics Canada's comparisons of First Nations, Metis
#' and Inuit mortality standardise to the Indigenous population's own age structure (Kumar
#' and Tjepkema 2019), which is younger than Canada's.
#'
#' @param events,pop Numbers of events and of people, one per age group (and
#'   group).
#' @param std The standard population, one count per age group (its shares are the
#'   weights).
#' @param grp Optional labels: one rate per group, each over the same age groups in the
#'   same order.
#' @param per Rate per this many people (default 100,000).
#' @param conflvl Confidence level (default 0.95).
#' @return A data frame with \code{group}, \code{events}, \code{rate}, \code{lower},
#'   \code{upper}, and the attributes \code{var} (the variances, on the per-person scale)
#'   for \code{\link{rategap}}.
#' @references Fay MP, Feuer EJ (1997). Confidence intervals for directly standardized
#' rates: a method based on the gamma distribution. Statistics in Medicine 16(7):791-801.\cr
#' \doi{10.1002/(sici)1097-0258(19970415)16:7<791::aid-sim500>3.0.co;2-#}
#'
#' Kumar MB, Tjepkema M (2019). Suicide among First Nations people, Metis and Inuit
#' (2011-2016): Findings from the 2011 Canadian Census Health and Environment Cohort
#' (CanCHEC). Statistics Canada 99-011-X2019001.
#' @seealso \code{\link{rategap}}.
#' @examples
#' # made-up counts for one small community, by five age groups, to show the computation
#' std <- c(30000, 25000, 20000, 15000, 10000)   # a younger standard population
#' agestd(events = c(4, 9, 11, 6, 3), pop = c(9000, 8000, 6000, 4000,
#'                                                            2000),
#'                 std = std)
#' @export
agestd <- function(events, pop, std, grp = NULL, per = 1e5, conflvl = 0.95) {
  events <- .rmbl_num(events, "events")
  pop <- .rmbl_num(pop, "pop")
  std <- .rmbl_num(std, "std")
  per <- .rmbl_scalar(per, "per", 1)
  conflvl <- .rmbl_conf_level(conflvl)
  k <- length(std)
  if (!k || anyNA(std) || any(std < 0) || sum(std) <= 0) {
    stop("`std` must be non-negative counts, one per age group, not all zero", call. = FALSE)
  }
  if (length(events) != length(pop)) stop("`events` and `pop` must be the same length", call. = FALSE)
  if (anyNA(events) || any(events < 0) || any(abs(events - round(events)) > 1e-8)) {
    stop("`events` must be non-negative whole numbers", call. = FALSE)
  }
  if (anyNA(pop) || any(pop <= 0)) stop("`pop` must be positive", call. = FALSE)
  if (is.null(grp)) grp <- rep("all", length(events))
  .rmbl_no_fn(group = grp)
  grp <- as.character(grp)
  if (length(grp) != length(events)) stop("`grp` must have one label per row", call. = FALSE)
  w <- std / sum(std)
  a <- 1 - conflvl
  rows <- lapply(unique(grp), function(gi) {
    i <- which(grp == gi)
    if (length(i) != k) {
      stop(sprintf("group \"%s\" has %d age groups; `std` has %d", gi, length(i), k), call. = FALSE)
    }
    d <- events[i]
    n <- pop[i]
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
  attr(out, "conflvl") <- conflvl
  class(out) <- c("rmbl_dsr", "data.frame")
  out
}

#' The gap between two standardised rates
#'
#' The ratio and the difference of two directly standardised rates from
#' \code{\link{agestd}}, with confidence intervals: log-normal for the ratio
#' (variance \eqn{v_1/y_1^2 + v_2/y_2^2}) and normal for the difference, the two rates
#' independent. Both measures are reported, as the relative gap alone hides how large the
#' absolute one is (Anderson et al. 2016).
#'
#' @param x Output of \code{\link{agestd}} (two or more groups).
#' @param grp,ref The labels of the group and of the reference group.
#' @return A one-row data frame: \code{group}, \code{reference}, \code{ratio} with
#'   \code{ratiolo}/\code{ratioup}, and \code{difference} (per \code{per} people)
#'   with \code{diflo}/\code{difup}.
#' @references Anderson I, Robson B, Connolly M, et al. (2016). Indigenous and tribal
#' peoples' health (The Lancet-Lowitja Institute Global Collaboration): a population
#' study. The Lancet 388(10040):131-157.
#' \doi{10.1016/S0140-6736(16)00345-7}
#' @examples
#' # made-up counts, to show the computation
#' std <- c(30000, 25000, 20000, 15000, 10000)
#' r <- agestd(events = c(4, 9, 11, 6, 3, 2, 4, 6, 5, 4),
#'                      pop = c(9000, 8000, 6000, 4000, 2000,
#'                                     20000, 19000, 18000, 15000, 12000),
#'                      std = std, grp = rep(c("Inuit", "Non-Indigenous"),
#'                                                  each = 5))
#' plot(r)
#' rategap(r, "Inuit", "Non-Indigenous")
#' @export
rategap <- function(x, grp, ref) {
  if (!inherits(x, "rmbl_dsr")) stop("`x` must come from agestd()", call. = FALSE)
  grp <- .rmbl_string1(grp, "grp")
  ref <- .rmbl_string1(ref, "ref")
  for (g in c(grp, ref)) {
    if (!g %in% x$group) stop(sprintf("\"%s\" is not a group of `x`", g), call. = FALSE)
  }
  if (grp == ref) stop("`grp` and `ref` must be two different groups", call. = FALSE)
  per <- attr(x, "per")
  z <- stats::qnorm(1 - (1 - attr(x, "conflvl")) / 2)
  v <- attr(x, "var")
  y1 <- x$rate[x$group == grp] / per
  y0 <- x$rate[x$group == ref] / per
  if (y1 <= 0 || y0 <= 0) stop("a ratio needs both rates above zero", call. = FALSE)
  slr <- sqrt(v[[grp]] / y1^2 + v[[ref]] / y0^2)
  sd <- sqrt(v[[grp]] + v[[ref]])
  data.frame(group = grp, reference = ref, ratio = y1 / y0,
             ratiolo = exp(log(y1 / y0) - z * slr), ratioup = exp(log(y1 / y0) + z * slr),
             difference = (y1 - y0) * per, diflo = (y1 - y0 - z * sd) * per,
             difup = (y1 - y0 + z * sd) * per, stringsAsFactors = FALSE)
}

#' Generations of residential school attendance in a family
#'
#' Codes the intergenerational exposure used in the epidemiology of Indian Residential
#' Schools: how many generations before the respondent attended, 0 (neither parents nor
#' grandparents), 1 (parents or grandparents) or 2 (both a parent and a grandparent), as
#' in McQuaid et al. (2017).
#'
#' @details Each answer is \code{TRUE} (attended), \code{FALSE} (did not) or \code{NA}
#' (not known). An unknown answer may hide an attendance, so the count is unknown
#' (\code{NA}) whenever an unknown answer could change it: always when the known answer is
#' \code{FALSE}, and, with \code{partial = "na"} (the default), also when the known answer
#' is \code{TRUE} (the count is 1 or 2). \code{partial = "lowerbnd"} codes that case 1,
#' a lower bound: it keeps the person but can classify them a level too low, which biases
#' a trend toward no effect.
#'
#' @param parent,gparent Logical vectors: did a parent, did a grandparent attend.
#' @param partial What a known attendance with the other generation unknown counts as:
#'   \code{"na"} (not known, the default) or \code{"lowerbnd"} (1).
#' @return An integer vector of 0, 1, 2 or \code{NA}.
#' @references McQuaid RJ, Bombay A, McInnis OA, Humeny C, Matheson K, Anisman H (2017).
#' Suicide ideation and attempts among First Nations peoples living on-reserve in Canada:
#' the intergenerational and cumulative effects of Indian Residential Schools. Canadian
#' Journal of Psychiatry 62(6):422-430. \doi{10.1177/0706743717702075}
#'
#' Bombay A, Matheson K, Anisman H (2014). The intergenerational effects of Indian
#' Residential Schools: implications for the concept of historical trauma. Transcultural
#' Psychiatry 51(3):320-338. \doi{10.1177/1363461513503380}
#' @seealso \code{\link{exptrnd}}.
#' @examples
#' genexpo(c(TRUE, FALSE, TRUE, NA, FALSE), c(TRUE, FALSE, FALSE, TRUE, NA))
#' genexpo(c(TRUE, FALSE, TRUE, NA, FALSE), c(TRUE, FALSE, FALSE, TRUE, NA),
#'                     partial = "lowerbnd")
#' @export
genexpo <- function(parent, gparent, partial = c("na", "lowerbnd")) {
  partial <- .rmbl_arg(partial)
  for (nm in c("parent", "gparent")) {
    v <- get(nm)
    if (!is.logical(v)) stop(sprintf("`%s` must be TRUE, FALSE or NA for each person", nm), call. = FALSE)
  }
  if (length(parent) != length(gparent)) {
    stop("`parent` and `gparent` must be the same length", call. = FALSE)
  }
  out <- as.integer(parent %in% TRUE) + as.integer(gparent %in% TRUE)
  either_na <- is.na(parent) | is.na(gparent)
  out[either_na & out == 0L] <- NA_integer_
  if (partial == "na") out[either_na & out == 1L] <- NA_integer_
  out
}

#' A dose-response across generations of exposure
#'
#' For counts of an outcome (suicidal thoughts, distress) among people with 0, 1 or 2
#' generations of residential school attendance in their family (or any ordered exposure),
#' the odds ratio of each level against the lowest level, with Woolf intervals, and the
#' Cochran-Armitage test for a trend across the levels.
#'
#' @param cases Number with the outcome at each exposure level.
#' @param n Number of people at each level.
#' @param dose The exposure levels, in order (default \code{0, 1, 2, ...}); the trend test
#'   scores them.
#' @param conflvl Confidence level (default 0.95).
#' @return A data frame with \code{dose}, \code{cases}, \code{n}, \code{proportion},
#'   \code{orratio}, \code{lower}, \code{upper}; the trend test is the attribute
#'   \code{trend} (an \code{htest}).
#' @details With \eqn{a_k} cases and \eqn{b_k = n_k - a_k} non-cases at level \eqn{k}, the
#' odds ratio against the lowest level is \eqn{(a_k/b_k)/(a_1/b_1)}, with Woolf's interval
#' \eqn{\exp\{\log OR \pm z\sqrt{1/a_k + 1/b_k + 1/a_1 + 1/b_1}\}}. When any cell is
#' empty, one half is added to every cell of every level (Haldane-Anscombe), so every odds
#' ratio is finite. The trend test is the Cochran-Armitage test (\code{prop.trend.test})
#' with the levels as scores. Counts must be unweighted. For a complex survey, take the
#' weighted analysis from the survey itself (\code{\link{svydes}}): this function
#' is for published or aggregated counts.
#' @references McQuaid RJ, et al. (2017), see \code{\link{genexpo}}.
#' @examples
#' # made-up counts by 0, 1 and 2 generations of attendance, to show the computation
#' et <- exptrnd(cases = c(60, 95, 70), n = c(500, 520, 300))
#' et
#' plot(et)
#' @export
exptrnd <- function(cases, n, dose = seq_along(cases) - 1L, conflvl = 0.95) {
  cases <- .rmbl_num(cases, "cases")
  n <- .rmbl_num(n, "n")
  dose <- .rmbl_num(dose, "dose")
  conflvl <- .rmbl_conf_level(conflvl)
  k <- length(cases)
  if (k < 2L || length(n) != k || length(dose) != k) {
    stop("`cases`, `n` and `dose` must have one entry per level, two levels at least", call. = FALSE)
  }
  if (anyNA(c(cases, n, dose)) || any(cases < 0) || any(n <= 0) || any(cases > n) ||
      any(abs(c(cases, n) - round(c(cases, n))) > 1e-8)) {
    stop("`cases` and `n` must be whole numbers with 0 <= cases <= n and n > 0", call. = FALSE)
  }
  if (is.unsorted(dose, strictly = TRUE)) stop("`dose` must be strictly increasing", call. = FALSE)
  if (all(cases == 0) || all(cases == n)) {
    stop("no level has a case (or every person at every level is one): there is no trend to test", call. = FALSE)
  }
  z <- stats::qnorm(1 - (1 - conflvl) / 2)
  a <- cases
  b <- n - cases
  # the Haldane-Anscombe half added to every cell when one is empty, so the odds ratio is finite
  adj <- if (any(c(a, b) == 0)) 0.5 else 0
  or <- ((a + adj) / (b + adj)) / ((a[1] + adj) / (b[1] + adj))
  se <- sqrt(1 / (a + adj) + 1 / (b + adj) + 1 / (a[1] + adj) + 1 / (b[1] + adj))
  se[1] <- 0
  out <- data.frame(dose = dose, cases = a, n = n, proportion = a / n, orratio = or,
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
#' The number of the Truth and Reconciliation Commission's 94 Calls to Action that the
#' Yellowhead Institute's annual accountability reports judged complete, by the year they
#' were completed, to the end of 2022: the only counts here are those the reports state.
#'
#' @return A data frame with \code{period}, \code{yearend}, \code{completed},
#'   \code{cumulative} and \code{source}.
#' @details 2015-2019: 8 (13 in all by December 2022, less those of 2020-2022); 2020:
#' none; 2021: 3, all in June; 2022: 2 (Jewell and Mosby 2021, 2022). Other trackers count
#' otherwise: the federal government reports by theme rather than call by call; CBC's
#' Beyond 94 and Indigenous Watchdog grade each call on their own scales and are
#' copyrighted, so their tables are not reproduced. The reports are licensed CC BY-NC 2.5
#' Canada; the counts are facts taken from them, with the reports cited.
#' @references Jewell E, Mosby I (2021). Calls to Action Accountability: A 2021 Status
#' Update on Reconciliation. Yellowhead Institute, Toronto Metropolitan University.
#'
#' Jewell E, Mosby I (2022). Calls to Action Accountability: A 2022 Status Update on
#' Reconciliation. Yellowhead Institute, Toronto Metropolitan University.
#'
#' Truth and Reconciliation Commission of Canada (2015). Truth and Reconciliation
#' Commission of Canada: Calls to Action. Winnipeg.
#' @seealso \code{\link{trcprog}}.
#' @examples
#' trccmpl()
#' @export
trccmpl <- function() {
  d <- data.frame(period = c("2015-2019", "2020", "2021", "2022"), yearend = c(2019L, 2020L, 2021L, 2022L),
                  completed = c(8L, 0L, 3L, 2L), stringsAsFactors = FALSE)
  d$cumulative <- cumsum(d$completed)
  d$source <- c("Jewell and Mosby (2022): 13 complete in all", "Jewell and Mosby (2021)",
                "Jewell and Mosby (2021)", "Jewell and Mosby (2022)")
  d
}

#' How fast the Calls to Action are being completed
#'
#' From cumulative counts of completed Calls to Action over time, the completion rate
#' (calls a year), its exact Poisson interval, and the year all 94 would be complete at
#' that rate.
#'
#' @details Completions are taken as a Poisson process with a constant rate over the span
#' from the start (\code{start}, the Commission's final report in December 2015) to the
#' last count: the rate is \eqn{c / T} with the exact (Garwood) interval for \eqn{c}
#' completed calls, and the projection is the year \eqn{94 - c} more would take at that
#' rate (at the interval's ends, its range). A constant rate is the simplest model, and
#' the one behind the Yellowhead Institute's projection ("42 years, or until 2065", 2022);
#' with the counts to the end of 2022 and December 2015 as the start it gives 2067. The
#' pace has not been constant, so the projection is a description of the pace so far, not
#' a forecast. Any count of commitments completed over time can be modelled the same way:
#' set \code{total} and \code{start}.
#'
#' @param done Cumulative number completed at each date (default:
#'   \code{\link{trccmpl}}).
#' @param yearend The year each count was made to (end of year).
#' @param total Number of Calls to Action (94).
#' @param start When counting began, as a year with a fraction (2015.96: December 15,
#'   2015).
#' @param conflvl Confidence level (default 0.95).
#' @return A one-row data frame of class \code{rmbl_trc_progress} with the columns
#'   \code{completed}, \code{remaining}, \code{years}, \code{rate}, \code{ratelo},
#'   \code{rateup}, \code{cmplby}, \code{cmplbyearly} and \code{cmplbylate};
#'   \code{plot()} draws the completions and the projection, with the band the rate's
#'   interval gives.
#' @seealso \code{\link{trccmpl}}.
#' @examples
#' p <- trcprog()
#' p
#' plot(p)
#' @export
trcprog <- function(done = trccmpl()$cumulative, yearend = trccmpl()$yearend,
                         total = 94, start = 2015.96, conflvl = 0.95) {
  done <- .rmbl_num(done, "done", integer = TRUE)
  yearend <- .rmbl_num(yearend, "yearend")
  total <- .rmbl_scalar(total, "total", 1)
  start <- .rmbl_scalar(start, "start")
  conflvl <- .rmbl_conf_level(conflvl)
  if (!length(done) || length(done) != length(yearend) || anyNA(c(done, yearend))) {
    stop("`done` and `yearend` must be one count per year, with no NA", call. = FALSE)
  }
  if (is.unsorted(yearend, strictly = TRUE)) stop("`yearend` must be increasing", call. = FALSE)
  if (is.unsorted(done) || any(done < 0) || any(done > total)) {
    stop("`done` must be cumulative counts between 0 and `total`", call. = FALSE)
  }
  c1 <- done[length(done)]
  t1 <- yearend[length(yearend)] + 1
  span <- t1 - start
  if (span <= 0) stop("the last count must come after `start`", call. = FALSE)
  a <- 1 - conflvl
  lo <- if (c1 > 0) stats::qgamma(a / 2, c1) / span else 0
  hi <- stats::qgamma(1 - a / 2, c1 + 1) / span
  rem <- total - c1
  by <- function(r) if (rem == 0) t1 else if (r > 0) t1 + rem / r else Inf
  out <- data.frame(completed = c1, remaining = rem, years = span, rate = c1 / span, ratelo = lo,
                    rateup = hi, cmplby = by(c1 / span), cmplbyearly = by(hi),
                    cmplbylate = by(lo))
  # the counts behind it, from `start`, for plot()
  attr(out, "history") <- data.frame(year = c(start, yearend + 1), completed = c(0, done))
  attr(out, "total") <- total
  class(out) <- c("rmbl_trc_progress", "data.frame")
  out
}

#' The Indigenous health and wellbeing tables the data service holds
#'
#' Lists the First Nations, Metis and Inuit tables mirrored at the data service:
#' Statistics Canada's Indigenous-titled tables (\code{statcan_indigenous}) and the 2021
#' Census Indigenous Population Profile (\code{census2021_ipp}), with their descriptions,
#' row counts and licences, searchable.
#'
#' @param pat Optional regular expression matched against the descriptions (case
#'   ignored).
#' @param refresh Fetch the manifest again (default \code{FALSE}).
#' @return A data frame: \code{key}, \code{rows}, \code{description}, \code{license},
#'   \code{source}.
#' @details Needs a data service key: sign in once with
#' \code{\link{dlogin}}. Only openly licensed aggregate tables are mirrored.
#' First Nations Information Governance Centre data (the First Nations Regional Health
#' Survey and its companions) are governed by the OCAP(R) principles and are not; ask the
#' Centre (\url{https://fnigc.ca}).
#' @examples
#' \dontrun{
#' indtabs("mental health")
#' }
#' @export
indtabs <- function(pat = NULL, refresh = FALSE) {
  if (!is.null(pat)) pat <- .rmbl_string1(pat, "pat")
  m <- dmnf(refresh = refresh)
  ds <- Filter(function(d) is.character(d$key) && grepl("^(statcan_indigenous|census2021_ipp)/", d$key), m$datasets)
  out <- data.frame(
    key = vapply(ds, function(d) d$key, ""),
    rows = vapply(ds, function(d) as.numeric(d$rows %||% NA), 0),
    description = vapply(ds, function(d) as.character(d$meta$description %||% "")[1L], ""),
    license = vapply(ds, function(d) as.character(d$meta$license %||% "")[1L], ""),
    source = vapply(ds, function(d) as.character(d$meta$source %||% "")[1L], ""),
    stringsAsFactors = FALSE)
  if (!is.null(pat)) out <- out[grepl(pat, out$description, ignore.case = TRUE), , drop = FALSE]
  rownames(out) <- NULL
  out
}
