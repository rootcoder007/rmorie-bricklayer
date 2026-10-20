# SPDX-License-Identifier: AGPL-3.0-or-later
#
# First Nations, Inuit and Metis frameworks for wellness, put to work on published tables: the First
# Nations Mental Wellness Continuum's four directions, Indigenous Services Canada's Community
# Well-Being index, connection to land and community as association across places, healing as change
# over time, a community-weighted index of protective and risk factors, and an audit of how
# deficit-framed a set of results is. Each says what it computes and what it cannot.

#' Checks that `data` is a data frame and that each column argument names one of its columns.
#' @param data The data frame passed by the user.
#' @param ... The column arguments, each named; the optional ones may be NULL.
#' @return `TRUE`, invisibly.
#' @noRd
.rmbl_ind_cols <- function(data, ...) {
  if (!is.data.frame(data)) stop(.rmbl_fn(), "`data` must be a data frame", call. = FALSE)
  a <- list(...)
  # the limit and quality columns are optional; every other NULL reached data[[NULL]] and failed
  # in R's words ("attempt to select less than one element"; final audit of 1.0.0)
  optional <- c("quality", "x_lower", "x_upper", "y_lower", "y_upper")
  for (nm in names(a)) {
    if (is.null(a[[nm]])) {
      if (!nm %in% optional) stop(sprintf("`%s` must name a column of `data`", nm), call. = FALSE)
      next
    }
    .rmbl_col(data, a[[nm]], nm)
  }
  invisible(TRUE)
}

#' Reads the quality flags of the rows, "ok" for every row when there is no quality column.
#' @param data The data frame.
#' @param quality The name of the quality column, or NULL.
#' @return A character vector of flags, one per row.
#' @noRd
.rmbl_quality <- function(data, quality) {
  q <- if (is.null(quality)) rep("ok", nrow(data)) else as.character(data[[quality]])
  .rmbl_qflags(q)
}

#' The four directions of the First Nations Mental Wellness Continuum, from published
#' indicators
#'
#' Lays out a group's published indicators under the four outcomes of the First Nations
#' Mental Wellness Continuum Framework (hope, belonging, meaning, purpose), each with its
#' interval, and says which directions the tables have no measure of.
#'
#' @details The Framework (Health Canada and Assembly of First Nations 2015) describes
#' mental wellness as hope for the future, a sense of belonging and connectedness to
#' family, community and culture, a sense of meaning and of how one's life fits into
#' creation, and purpose in daily life. It has no numeric scoring, and no survey table
#' measures the four directions as the Framework defines them. This function takes the
#' indicators a user names as proxies for each
#' (\code{hope = "Always or often has a hopeful outlook"}, ...), reports each direction's
#' level (the mean of its proxies, their standard errors combined as independent; the
#' proxies share respondents, so if they are positively correlated that standard error is
#' too small), marks
#' every row as a proxy, and reports a direction given no proxy as missing rather than
#' filling it from another. One indicator named for two directions (Statistics Canada asks
#' about "meaning and purpose" together) is used for both and marked \code{shared}.
#'
#' The result plots as a \code{\link{welprof}}. For the balance across the
#' directions, call \code{\link{holbal}} on the rows with a proxy
#' (\code{x[x$domain != "no published proxy", ]}, with \code{"domain"} as its domain
#' column):
#' a missing direction otherwise leaves the balance \code{NA}, and a shared proxy counts
#' once per direction it serves, so give such directions half weight. Other frameworks of
#' wellness (Te Whare Tapa Wha, the Social and Emotional Wellbeing domains, a Nation's
#' own) take the same route through \code{\link{welprof}} and
#' \code{\link{holbal}}, which accept any set of domains.
#'
#' @param data A data frame, one row per group and indicator.
#' @param grp,ind,est,lower,upper Column names: the group, the indicator,
#'   the estimate (percent) and its published limits.
#' @param hope,belong,meaning,purp The indicators taken as proxies for each
#'   direction, or \code{NULL} where the tables have none.
#' @param qual Optional column of quality flags.
#' @param conflvl Confidence level of the published intervals (default 0.95).
#' @return A data frame with the classes \code{rmbl_wellness_continuum} and
#'   \code{rmbl_wellness_profile}. Its columns are \code{group},
#'   \code{indicator} (the direction),
#'   \code{side} (\code{"wellness"}), \code{domain} (the proxies), \code{estimate},
#'   \code{lower}, \code{upper}, \code{usewithcau}, \code{shared}, \code{proxy}
#'   (always \code{TRUE}).
#' @references Health Canada, Assembly of First Nations (2015). First Nations Mental
#' Wellness Continuum Framework. Ottawa: Health Canada. Summary report:\cr
#' \url{https://www.sac-isc.gc.ca/eng/1576093687903/1576093725971}
#' @seealso \code{\link{welprof}}, \code{\link{holbal}}.
#' @examples
#' # well-being, 2024 (table 41-10-0082-01): hope, and meaning and purpose (asked
#' # together);
#' # this table has no measure of belonging, so that direction is reported as missing
#' wb <- indiex("wellbeing")
#' mw <- mhcont(wb, "group", "indicator", "estimate", "lower", "upper",
#'         hope = "Always or often has a hopeful outlook",
#'         meaning = "Sense of meaning and purpose rating of 8, 9 or 10",
#'         purp = "Sense of meaning and purpose rating of 8, 9 or 10",
#'         qual = "quality")
#' mw
#' plot(mw)
#' @export
mhcont <- function(data, grp, ind, est, lower, upper, hope = NULL,
                                      belong = NULL, meaning = NULL, purp = NULL, qual = NULL,
                                      conflvl = 0.95) {
  .rmbl_ind_cols(data, group = grp, indicator = ind, estimate = est, lower = lower,
                 upper = upper, quality = qual)
  conflvl <- .rmbl_conf_level(conflvl)
  z <- stats::qnorm(1 - (1 - conflvl) / 2)
  dirs <- list(hope = hope, belonging = belong, meaning = meaning, purpose = purp)
  .rmbl_no_fn(hope = hope, belonging = belong, meaning = meaning, purpose = purp)
  for (nm in names(dirs)) {
    v <- dirs[[nm]]
    if (!is.null(v) && (!is.character(v) || !length(v) || anyNA(v))) {
      stop(sprintf("`%s` must name indicators of `data`, or be NULL", nm), call. = FALSE)
    }
  }
  if (all(vapply(dirs, is.null, NA))) stop("name a proxy for one direction at least", call. = FALSE)
  .ind <- .rmbl_utf8(trimws(as.character(data[[ind]])))
  miss <- setdiff(trimws(unlist(dirs)), .ind)
  if (length(miss)) stop(sprintf("mhcont: not an indicator of `data`: %s", paste(miss, collapse = ", ")), call. = FALSE)
  g <- .rmbl_utf8(trimws(as.character(data[[grp]])))
  .est <- .rmbl_num(data[[est]], "est")
  lo <- .rmbl_num(data[[lower]], "lower")
  hi <- .rmbl_num(data[[upper]], "upper")
  named <- .ind %in% trimws(unlist(dirs))
  .est[named] <- .rmbl_contains(.est[named], lo[named], hi[named], paste0(g[named], ": ", .ind[named]))
  se <- (hi - lo) / (2 * z)
  q <- .rmbl_quality(data, qual)
  .est[q %in% c("F", "x", "..", "...")] <- NA_real_
  used <- table(unlist(lapply(dirs, unique)))
  rows <- list()
  for (gi in unique(g)) {
    for (nm in names(dirs)) {
      p <- trimws(dirs[[nm]])
      if (is.null(dirs[[nm]])) {
        rows[[length(rows) + 1L]] <- data.frame(group = gi, indicator = nm, domain = "no published proxy",
                                                estimate = NA_real_, lower = NA_real_, upper = NA_real_,
                                                usewithcau = FALSE, shared = FALSE)
        next
      }
      i <- which(g == gi & .ind %in% p)
      ok <- length(i) == length(p) && !anyNA(.est[i])
      m <- if (ok) mean(.est[i]) else NA_real_
      s <- if (ok) sqrt(sum(se[i]^2)) / length(i) else NA_real_
      rows[[length(rows) + 1L]] <- data.frame(group = gi, indicator = nm, domain = paste(p, collapse = "; "),
                                              estimate = m, lower = m - z * s, upper = m + z * s,
                                              usewithcau = any(q[i] == "E"), shared = any(used[p] > 1))
    }
  }
  out <- do.call(rbind, rows)
  out <- data.frame(out[c("group", "indicator")], side = "wellness", out[c("domain", "estimate", "lower", "upper",
                                                                            "usewithcau", "shared")],
                    proxy = TRUE, stringsAsFactors = FALSE)
  attr(out, "conflvl") <- conflvl
  class(out) <- c("rmbl_wellness_continuum", "rmbl_wellness_profile", "data.frame")
  out
}

#' The Community Well-Being index of a community
#'
#' Indigenous Services Canada's Community Well-Being (CWB) index: income, education,
#' housing and labour force activity, each scored from 0 to 100, and their mean, from
#' census profile figures.
#'
#' @details The components, as the index's methodology sets them out (Penney, O'Sullivan
#' and Senecal 2012; O'Sullivan and McHardy 2013; Indigenous Services Canada's reports on
#' trends, 1981 to 2016 and 2021):
#' \describe{
#'   \item{income}{\eqn{100 (\log y - \log a) / (\log b - \log a)} for income per capita
#'     \eqn{y} (total income over total population) between the bounds \eqn{a} and \eqn{b}
#'     (2,650 and 75,000 dollars in the 2016 and 2021 series; 2,000 and 40,000 in the
#'     earlier ones), kept between 0 and 100 here.}
#'   \item{education}{two thirds of the percentage aged 20 and over with at least a high
#'     school certificate, plus one third of the percentage aged 25 and over with a
#'     university degree at the bachelor's level or above.}
#'   \item{housing}{half the percentage of people in dwellings with no more than one
#'     person per room, plus half the percentage in dwellings that need no major repairs.}
#'   \item{labour}{half the participation rate, plus half the employment rate of those
#'     participating (ages 20 to 64).}
#' }
#' The index is the mean of the four. Indigenous Services Canada computes it from
#' unrounded census microdata, scores only communities of 65 people or more and suppresses
#' the components of communities under 250 people or 40 households: scores from published,
#' rounded profile figures come close to the published index but need not equal it, and a
#' small community's should be treated as the Department would. The full current
#' methodology is available from the Department on request. The index measures
#' socio-economic conditions as the census counts them; it says nothing of culture,
#' language or relationship to land, and is not a measure of wellness as First Nations and
#' Inuit define it. The CWB is Indigenous Services Canada's index, with bounds in the
#' Canadian dollars of its series: for another country, set \code{bounds} in its currency
#' and read the result as a CWB-style score, not comparable with Canada's.
#'
#' @param incpercap Income per capita, in the dollars of the series' bounds.
#' @param highsch20p,uni25p Percentages for education.
#' @param notcro,nomajrep Percentages for housing.
#' @param partic,empl Percentages for labour force activity.
#' @param bounds The income bounds (default the 2016 and 2021 series: 2650 and 75000).
#' @return A data frame, one row per community: \code{income}, \code{education},
#'   \code{housing}, \code{labour}, \code{cwb}.
#' @references Penney C, O'Sullivan E, Senecal S (2012). The Community Well-Being Index
#' (CWB): Examining Well-Being in Inuit Communities, 1981-2006. Aboriginal Affairs and
#' Northern Development Canada.
#'
#' O'Sullivan E, McHardy M (2013). The Community Well-Being (CWB) Index: Disparity in
#' Well-Being Between First Nations and Other Canadian Communities Over Time. In White JP,
#' Peters J, Beavon D, Spence N (eds), Aboriginal Well-Being: Canada's Continuing
#' Challenge. Thompson Educational.
#'
#' Indigenous Services Canada (2019). Report on trends in First Nations communities, 1981
#' to 2016 (Community Well-Being index).\cr
#' \url{https://www.sac-isc.gc.ca/eng/1345816651029/1557323327644}
#' @examples
#' # made-up profile figures for two communities, to show the computation
#' cwbscr(incpercap = c(18000, 31000), highsch20p = c(58, 81),
#'           uni25p = c(6, 19), notcro = c(71, 95),
#'           nomajrep = c(62, 90),
#'           partic = c(55, 68), empl = c(78, 92))
#' @export
cwbscr <- function(incpercap, highsch20p, uni25p, notcro, nomajrep,
                      partic, empl, bounds = c(2650, 75000)) {
  a <- list(incpercap = incpercap, highsch20p = highsch20p,
            uni25p = uni25p, notcro = notcro,
            nomajrep = nomajrep, participation = partic, employment = empl)
  a <- Map(.rmbl_num, a, names(a))
  n <- max(lengths(a))
  if (!n || any(lengths(a) != n & lengths(a) != 1L)) {
    stop("every argument must have one value per community (or one value for all)", call. = FALSE)
  }
  pct <- a[-1L]
  for (nm in names(pct)) {
    if (any(pct[[nm]] < 0 | pct[[nm]] > 100, na.rm = TRUE)) {
      stop(sprintf("`%s` must be percentages from 0 to 100", nm), call. = FALSE)
    }
  }
  if (any(a$incpercap <= 0, na.rm = TRUE)) stop("`incpercap` must be positive", call. = FALSE)
  bounds <- .rmbl_num(bounds, "bounds")
  if (length(bounds) != 2L || anyNA(bounds) || bounds[1L] <= 0 || bounds[2L] <= bounds[1L]) {
    stop("`bounds` must be two increasing positive incomes", call. = FALSE)
  }
  inc <- 100 * (log(a$incpercap) - log(bounds[1L])) / (log(bounds[2L]) - log(bounds[1L]))
  inc <- pmin(100, pmax(0, inc))
  edu <- 2 / 3 * a$highsch20p + 1 / 3 * a$uni25p
  hou <- (a$notcro + a$nomajrep) / 2
  lab <- (a$participation + a$employment) / 2
  out <- data.frame(income = rep_len(inc, n), education = rep_len(edu, n), housing = rep_len(hou, n),
                    labour = rep_len(lab, n))
  out$cwb <- rowMeans(out)
  out
}

#' Connection across places: does one indicator rise where another does?
#'
#' For two indicators published for the same places (regions, provinces, Inuit regions),
#' their rank correlation across places, an exact permutation p-value, and an interval
#' that carries the sampling error of the published estimates: for connection to land and
#' wellness, community belonging and mental health, education and health.
#'
#' @details Mashford-Pringle and Stewart (2019) describe the land as "an instrumental part
#' of all aspects of Indigenous life including health and well-being"; Mashford-Pringle
#' (2016) describes Indigenous health and education as interconnected. Across places, that
#' connection has a testable shadow: where more people are on the land (or belong, or
#' finish school), do more report wellness? This function measures it by Spearman's
#' \eqn{\rho}. Its p-value is exact when there are at most 8 places (over all \eqn{n!}
#' orderings) and a Monte Carlo estimate otherwise (\eqn{(b + 1)/(R + 1)} for \eqn{b} of
#' \eqn{R} = \code{reps} random orderings at least as extreme). Each estimate carries
#' sampling error, so \code{rholo} and \code{rhoup} are the quantiles of
#' \eqn{\rho} over \code{reps} draws of both indicators from normal distributions with
#' their published standard errors. That is a sensitivity band, not a confidence interval
#' for a correlation across places: it shows how much the published sampling error alone
#' moves \eqn{\rho} for these places, it is pulled toward 0 (noise is added to estimates
#' that are already noisy), and it ignores the sampling of the places themselves. Quality
#' flags are not carried: filter suppressed rows out first.
#'
#' This is an association across places (an ecological one). It cannot say that connection
#' to land makes a person well, which needs data on persons; a handful of places gives
#' little power; and a correlation is not a measure of the relationship the authors
#' describe. It is a description of how the published indicators move together.
#'
#' @param data A data frame, one row per place.
#' @param place Column of place names.
#' @param x,y Columns of the two indicators.
#' @param xlo,xup,ylo,yup Optional columns of their published limits (for
#'   the interval).
#' @param reps Draws for the interval and, past 8 places, for the p-value (default
#'   10,000).
#' @param seed Seed for the draws (default 1).
#' @param conflvl Confidence level (default 0.95).
#' @return A list of class \code{rmbl_connection}: \code{data} (the places used),
#'   \code{rho}, \code{p_value}, \code{exact}, \code{rholo}, \code{rhoup},
#'   \code{n}.
#' @section Acknowledgement:
#' This estimator puts to quantitative use the work of Professor Angela Mashford-Pringle
#' (Timiskaming First Nation) and Professor Suzanne Stewart (Yellowknives Dene First
#' Nation), both of the University of Toronto.
#'
#' See the acknowledgements of the \code{first-nations-metis-inuit-health} vignette.
#' @references Mashford-Pringle A, Stewart SL (2019). Akiikaa (it is the land): exploring
#' land-based experiences with university students in Ontario. Global Health Promotion
#' 26(3_suppl):64-72. \doi{10.1177/1757975919828722}
#'
#' Mashford-Pringle A (2016). Aboriginal health and Aboriginal education are
#' interconnected. Research in the Sociology of Health Care 34:85-96.
#' \doi{10.1108/s0275-495920160000034005}
#' @seealso \code{\link{dualcont}}.
#' @examples
#' # across regions, 2022 (table 41-10-0067-01): where First Nations people report
#' # excellent or
#' # very good mental health, do Metis people living in the same region too?
#' mh <- indiex("mentalhealth")
#' mh <- mh[mh$rating == "Excellent or very good" & mh$region != "Canada", ]
#' fn <- mh[mh$group == "First Nations", ]
#' me <- mh[mh$group == "M\u00e9tis", ]
#' d <- merge(fn, me, by = "region", suffixes = c("fn", "me"))
#' ca <- connassoc(d, "region", "estimatefn", "estimateme", "lowerfn",
#'                              "upperfn",
#'                              "lowerme", "upperme")
#' ca
#' plot(ca)
#' @export
connassoc <- function(data, place, x, y, xlo = NULL, xup = NULL, ylo = NULL,
                                   yup = NULL, reps = 10000, seed = 1, conflvl = 0.95) {
  .rmbl_ind_cols(data, place = place, x = x, y = y, x_lower = xlo, x_upper = xup,
                 y_lower = ylo, y_upper = yup)
  if (sum(vapply(list(xlo, xup, ylo, yup), is.null, NA)) %% 4L) {
    stop("give all four limit columns, or none", call. = FALSE)
  }
  reps <- .rmbl_scalar(reps, "reps", 100, 1e6, integer = TRUE)
  conflvl <- .rmbl_conf_level(conflvl)
  z <- stats::qnorm(1 - (1 - conflvl) / 2)
  xv <- .rmbl_num(data[[x]], "x")
  yv <- .rmbl_num(data[[y]], "y")
  ok <- is.finite(xv) & is.finite(yv)
  if (sum(ok) < 3L) stop("the association needs three places at least with both indicators", call. = FALSE)
  d <- data.frame(place = as.character(data[[place]]), x = xv, y = yv)
  if (!is.null(xlo)) {
    d$xse <- (.rmbl_num(data[[xup]], "xup") - .rmbl_num(data[[xlo]], "xlo")) / (2 * z)
    d$yse <- (.rmbl_num(data[[yup]], "yup") - .rmbl_num(data[[ylo]], "ylo")) / (2 * z)
    ok <- ok & is.finite(d$xse) & is.finite(d$yse)
  }
  d <- d[ok, , drop = FALSE]
  n <- nrow(d)
  rho <- function(a, b) stats::cor(rank(a), rank(b))
  r0 <- rho(d$x, d$y)
  .rmbl_local_seed(seed)
  ry <- rank(d$y)
  rx <- rank(d$x)
  exact <- n <= 8L
  perm <- if (exact) {
    ps <- .rmbl_permutations(n)
    apply(ps, 1L, function(p) stats::cor(rx, ry[p]))
  } else {
    replicate(reps, stats::cor(rx, sample(ry)))
  }
  hits <- sum(abs(perm) >= abs(r0) - 1e-12)
  p <- if (exact) hits / length(perm) else (hits + 1) / (reps + 1)
  lo <- hi <- NA_real_
  if (!is.null(xlo)) {
    draws <- replicate(reps, rho(stats::rnorm(n, d$x, d$xse), stats::rnorm(n, d$y, d$yse)))
    a <- (1 - conflvl) / 2
    lo <- unname(stats::quantile(draws, a, na.rm = TRUE))
    hi <- unname(stats::quantile(draws, 1 - a, na.rm = TRUE))
  }
  out <- list(data = d, rho = r0, p_value = p, exact = exact, rholo = lo, rhoup = hi, n = n,
              labels = c(x = x, y = y), conflvl = conflvl)
  class(out) <- "rmbl_connection"
  out
}

#' Every ordering of 1..n, one per row (n <= 8: 40,320 rows at most)
#' @param n The number of items, a whole number from 1 to 8.
#' @return An integer matrix with one permutation per row.
#' @noRd
.rmbl_permutations <- function(n) {
  if (n == 1L) return(matrix(1L, 1L, 1L))
  sub <- .rmbl_permutations(n - 1L)
  do.call(rbind, lapply(seq_len(n), function(i) cbind(i, matrix(setdiff(seq_len(n), i)[sub], nrow(sub)))))
}

#' @export
print.rmbl_connection <- function(x, ...) {
  cat(sprintf("Rank correlation across %d places: rho = %.2f, %s p = %s", x$n, x$rho,
              if (x$exact) "exact" else "permutation", format.pval(x$p_value, digits = 3)))
  if (is.finite(x$rholo)) {
    cat(sprintf("; with the published sampling error, %.0f%% interval %.2f to %.2f", 100 * x$conflvl,
                x$rholo, x$rhoup))
  }
  cat("\nAn association across places: it does not show that one causes the other for any person.\n")
  invisible(x)
}

#' Healing as a process: change in published indicators between two periods
#'
#' For each group and indicator, the change between two survey periods with its confidence
#' interval, wellness indicators first: change over time read as Indigenous scholars
#' describe mental health, as a process of healing, not as a fixed deficit.
#'
#' @details Stewart (2008) describes Indigenous mental health as wellness and as a process
#' of healing; a process is seen in change. The change \eqn{p_2 - p_1} has the interval
#' \eqn{p_2 - p_1 \pm z\sqrt{s_1^2 + s_2^2}}, with the standard errors from the published
#' intervals and the two periods' samples independent (separate cycles of a survey are). A
#' change is only as comparable as the two periods' questions and designs: Statistics
#' Canada flags breaks in a series, and a change across one is not a change in the people.
#'
#' @param data A data frame, one row per group, indicator and period.
#' @param grp,ind,prd,est,lower,upper Column names: the change is in the
#'   estimate's own units (percentage points for percentages).
#' @param from,to The two periods.
#' @param well,distress Optional indicators of wellness (listed first) and of
#'   distress; with \code{distress} given, any other indicator is marked \code{"other"}.
#' @param qual Optional column of quality flags.
#' @param conflvl Confidence level (default 0.95).
#' @return A data frame of class \code{rmbl_healing_change}: \code{group},
#'   \code{indicator}, \code{side}, \code{from}, \code{to}, \code{change}, \code{lower},
#'   \code{upper}, \code{usewithcau}.
#' @section Acknowledgement:
#' This estimator puts to quantitative use the framework of Professor Suzanne Stewart
#' (Yellowknives Dene First Nation, University of Toronto).
#'
#' See the acknowledgements of the \code{first-nations-metis-inuit-health} vignette.
#' @references Stewart SL (2008), see \code{\link{holbal}}.
#' @seealso \code{\link{welprof}}.
#' @examples
#' # 2015/2018 to 2019/2022, adults (table 13-10-0924-01)
#' h <- indiex("health")
#' belong <- "Sense of belonging to local community, somewhat strong or very strong"
#' h <- h[h$age == "Total, 18 years and over" & h$indicator %in%
#'          c("Perceived mental health, very good or excellent", belong,
#'            "Mood disorder", "Anxiety disorder"), ]
#' hc <- healchg(h, "group", "indicator", "period", "estimate", "lower", "upper",
#'                      from = "2015/2018", to = "2019/2022", qual = "quality",
#'                      well = c("Perceived mental health, very good or excellent",
#'                                   belong))
#' hc
#' plot(hc)
#' @export
healchg <- function(data, grp, ind, prd, est, lower, upper, from, to, well = NULL,
                           qual = NULL, conflvl = 0.95, distress = NULL) {
  .rmbl_ind_cols(data, group = grp, indicator = ind, period = prd, estimate = est,
                 lower = lower, upper = upper, quality = qual)
  from <- .rmbl_string1(from, "from")
  to <- .rmbl_string1(to, "to")
  .rmbl_no_fn(wellness = well, distress = distress)
  conflvl <- .rmbl_conf_level(conflvl)
  z <- stats::qnorm(1 - (1 - conflvl) / 2)
  pr <- as.character(data[[prd]])
  for (v in c(from, to)) if (!v %in% pr) stop(sprintf("\"%s\" is not a period of `data`", v), call. = FALSE)
  g <- .rmbl_utf8(trimws(as.character(data[[grp]])))
  .ind <- .rmbl_utf8(trimws(as.character(data[[ind]])))
  .est <- .rmbl_num(data[[est]], "est")
  lo <- .rmbl_num(data[[lower]], "lower")
  hi <- .rmbl_num(data[[upper]], "upper")
  .est <- .rmbl_contains(.est, lo, hi, paste0(g, ": ", .ind, " (", pr, ")"))
  se <- (hi - lo) / (2 * z)
  q <- .rmbl_quality(data, qual)
  .est[q %in% c("F", "x", "..", "...")] <- NA_real_
  key <- paste(g, .ind, sep = "\r")
  k1 <- which(pr == from)
  k2 <- which(pr == to)
  if (anyDuplicated(key[k1]) || anyDuplicated(key[k2])) {
    stop("a group and indicator appear twice in one period: filter `data` to one age group, sex and place",
         call. = FALSE)
  }
  both <- intersect(key[k1], key[k2])
  if (!length(both)) stop("no group and indicator is in both periods", call. = FALSE)
  i1 <- k1[match(both, key[k1])]
  i2 <- k2[match(both, key[k2])]
  ch <- .est[i2] - .est[i1]
  s <- sqrt(se[i1]^2 + se[i2]^2)
  side <- if (is.null(well) && is.null(distress)) rep(NA_character_, length(both)) else
    ifelse(.ind[i1] %in% trimws(well), "wellness",
           if (is.null(distress)) "distress" else ifelse(.ind[i1] %in% trimws(distress), "distress", "other"))
  out <- data.frame(group = g[i1], indicator = .ind[i1], side = side, from = .est[i1], to = .est[i2], change = ch,
                    lower = ch - z * s, upper = ch + z * s, usewithcau = q[i1] == "E" | q[i2] == "E",
                    stringsAsFactors = FALSE)
  o <- order(!(out$side %in% "wellness"), match(out$indicator, unique(out$indicator)))
  out <- out[o, , drop = FALSE]
  rownames(out) <- NULL
  attr(out, "periods") <- c(from = from, to = to)
  class(out) <- c("rmbl_healing_change", "data.frame")
  out
}

#' A community-weighted index of protective and risk factors
#'
#' Combines published indicators into one index for each group or place, with weights the
#' community sets: protective factors count for, risk factors against. The weights are
#' never estimated.
#'
#' @details Inuit Tapiriit Kanatami's National Inuit Suicide Prevention Strategy (2016)
#' names risk factors (among them crowded housing, food insecurity, childhood adversity,
#' mental distress) and protective factors (among them cultural continuity, social equity,
#' family strength, healthy child development). How much each matters is a judgement for
#' the people the index describes, so the function takes the weights as given: positive
#' for protective, negative for risk. The index is \eqn{\sum_i w_i p_i / \sum_i |w_i|},
#' with standard error \eqn{\sqrt{\sum_i w_i^2 s_i^2} / \sum_i |w_i|} from the published
#' intervals (independent estimates). It is a summary of the indicators under the weights
#' given; with other weights it ranks places otherwise, and it is never a ranking of
#' Nations or communities on their culture. For Inuit regions, use Inuit data only.
#'
#' @param data A data frame, one row per group (or place) and indicator.
#' @param grp,ind,est,lower,upper Column names; every indicator must be on
#'   one scale (percent, for example: a rate per 1,000 beside a percentage makes the
#'   weights meaningless).
#' @param w Named weights, one per indicator used: positive for a protective factor,
#'   negative for a risk factor.
#' @param qual Optional column of quality flags.
#' @param conflvl Confidence level (default 0.95).
#' @return A data frame of class \code{rmbl_community_index}: \code{group}, \code{index},
#'   \code{lower}, \code{upper}, \code{usewithcau}; attributes \code{weights} and
#'   \code{conflvl}. \code{plot()} draws it.
#' @references Inuit Tapiriit Kanatami (2016). National Inuit Suicide Prevention Strategy.
#' Ottawa. \url{https://itk.ca/national-inuit-suicide-prevention-strategy/}
#'
#' Carroll SR, et al. (2020), see \code{\link{holbal}}.
#' @examples
#' # weights a community might set for adults, 2019/2022 (table 13-10-0924-01); others
#' # would differ
#' h <- indiex("health")
#' h <- h[h$period == "2019/2022" & h$age == "Total, 18 years and over", ]
#' w <- c(2, 1, -2, -1)
#' names(w) <- c("Sense of belonging to local community, somewhat strong or very strong",
#'               "Has a regular healthcare provider",
#'               "Perceived life stress, most days quite a bit or extremely stressful",
#'               "Heavy drinking")
#' ci <- commidx(h, "group", "indicator", "estimate", "lower", "upper",
#'                       qual = "quality", w = w)
#' ci
#' # an indicator the table does not publish for the period leaves the index NA, never
#' # filled: food insecurity is ".." for 2019/2022
#' w2 <- c(w, "Household food insecure" = -2)
#' commidx(h, "group", "indicator", "estimate", "lower", "upper",
#'                 qual = "quality",
#'                 w = w2)$index
#' plot(ci)
#' @export
commidx <- function(data, grp, ind, est, lower, upper, w, qual = NULL,
                            conflvl = 0.95) {
  .rmbl_ind_cols(data, group = grp, indicator = ind, estimate = est, lower = lower,
                 upper = upper, quality = qual)
  if (missing(w)) w <- NULL
  .rmbl_no_fn(weights = w)
  if (!is.numeric(w) || is.null(names(w)) || anyNA(w) ||
        all(w == 0) || anyDuplicated(names(w))) {
    stop("`w` must be numbers named by indicator (positive protective, negative risk), set by the ",
         "community: the function does not choose them", call. = FALSE)
  }
  conflvl <- .rmbl_conf_level(conflvl)
  z <- stats::qnorm(1 - (1 - conflvl) / 2)
  .ind <- .rmbl_utf8(trimws(as.character(data[[ind]])))
  miss <- setdiff(names(w), .ind)
  if (length(miss)) stop(sprintf("commidx: not an indicator of `data`: %s", paste(miss, collapse = ", ")),
                         call. = FALSE)
  g <- .rmbl_utf8(trimws(as.character(data[[grp]])))
  .est <- .rmbl_num(data[[est]], "est")
  lo <- .rmbl_num(data[[lower]], "lower")
  hi <- .rmbl_num(data[[upper]], "upper")
  used <- .ind %in% names(w)
  .est[used] <- .rmbl_contains(.est[used], lo[used], hi[used], paste0(g[used], ": ", .ind[used]))
  se <- (hi - lo) / (2 * z)
  q <- .rmbl_quality(data, qual)
  .est[q %in% c("F", "x", "..", "...")] <- NA_real_
  tot <- sum(abs(w))
  rows <- lapply(unique(g), function(gi) {
    i <- which(g == gi & .ind %in% names(w))
    if (anyDuplicated(.ind[i])) stop(sprintf("group \"%s\" has an indicator twice", gi), call. = FALSE)
    i <- i[match(names(w), .ind[i])]
    if (anyNA(i) || anyNA(.est[i])) {
      return(data.frame(group = gi, index = NA_real_, lower = NA_real_, upper = NA_real_, usewithcau = FALSE))
    }
    v <- sum(w * .est[i]) / tot
    s <- sqrt(sum(w^2 * se[i]^2)) / tot
    data.frame(group = gi, index = v, lower = v - z * s, upper = v + z * s, usewithcau = any(q[i] == "E"))
  })
  out <- do.call(rbind, rows)
  attr(out, "weights") <- w
  attr(out, "conflvl") <- conflvl
  class(out) <- c("rmbl_community_index", "data.frame")
  out
}

#' How deficit-framed is a set of results?
#'
#' Counts how many of the indicators in a report measure distress, deficit or disparity
#' and how many measure wellness or strength, and names any group reported on deficits
#' alone.
#'
#' @details Walter (2016) shows that statistics about Indigenous peoples cluster around
#' five Ds: disparity, deprivation, disadvantage, dysfunction and difference. Results
#' built only of those describe Indigenous peoples as their problems. This audit does not
#' measure anything about people; it measures the report: the share of its indicators that
#' are deficit-framed, overall and per group, so a report can be balanced before it is
#' published. Pair each gap with a strength-framed level (\code{\link{welprof}},
#' \code{\link{dualcont}}).
#'
#' @param x A \code{\link{welprof}}.
#' @return A list of class \code{rmbl_framing}: \code{bygrp} (a data frame of
#'   \code{group}, \code{wellness}, \code{distress}, \code{shrdef}),
#'   \code{shrdef} overall and \code{defonly} (the groups with no wellness
#'   indicator).
#' @references Walter M (2016). Data politics and Indigenous representation in Australian
#' statistics. In Kukutai T, Taylor J (eds), Indigenous Data Sovereignty: Toward an
#' Agenda, 79-97. ANU Press. \doi{10.22459/caepr38.11.2016.05}
#'
#' Walter M, Andersen C (2013). Indigenous Statistics: A Quantitative Research
#' Methodology. Left Coast Press. \doi{10.4324/9781315426570}
#' @examples
#' wb <- indiex("wellbeing")
#' w <- welprof(wb, "group", "indicator", "estimate", "lower", "upper",
#'                       well = "Always or often has a hopeful outlook",
#'                       distress = c("Rarely or never has a hopeful outlook",
#'                                    "Life satisfaction rating between 0 and 5",
#'                                    "Fair or poor perceived health"))
#' frmaud(w)
#' @export
frmaud <- function(x) {
  if (!inherits(x, "rmbl_wellness_profile")) stop("frmaud: `x` must come from welprof()", call. = FALSE)
  groups <- unique(x$group)
  bg <- data.frame(group = groups,
                   wellness = vapply(groups, function(gi) sum(x$group == gi & x$side == "wellness"), 0L),
                   distress = vapply(groups, function(gi) sum(x$group == gi & x$side == "distress"), 0L),
                   stringsAsFactors = FALSE)
  bg$shrdef <- bg$distress / (bg$wellness + bg$distress)
  rownames(bg) <- NULL
  out <- list(bygrp = bg, shrdef = sum(bg$distress) / sum(bg$wellness + bg$distress),
              defonly = bg$group[bg$wellness == 0L])
  class(out) <- "rmbl_framing"
  out
}

#' @export
print.rmbl_framing <- function(x, ...) {
  cat(sprintf("%.0f%% of the indicators reported are deficit-framed.\n", 100 * x$shrdef))
  if (length(x$defonly)) {
    cat("Reported on deficits alone:", paste(x$defonly, collapse = "; "), "\n")
  }
  if (x$shrdef > 0.5) {
    cat("Most of this report measures disparity or deficit; pair each with a strength-framed level.\n")
  }
  invisible(x)
}

#' @rdname plot-methods
#' @export
plot.rmbl_connection <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  .rmbl_plot_check(x, "rmbl_connection")
  # axis titles given in ... name the axes; the rest of ... goes to plot()
  dots <- list(...)
  xlab <- dots$xlab
  ylab <- dots$ylab
  dots$xlab <- dots$ylab <- NULL
  d <- x$data
  cols <- .bl_cols(1L, col, palette)
  o <- .bl_plot_opts()
  op <- graphics::par(las = 1, cex = o$cex, bg = o$bg, bty = "n", tcl = -0.2, mgp = c(3, 0.55, 0),
                      col.axis = "#3D4350", fg = "#8A909A", col = "#1F2430", mar = .bl_safe_mar(c(4.2, 4.5, 3, 1)))
  on.exit(graphics::par(op), add = TRUE)
  z <- stats::qnorm(1 - (1 - x$conflvl) / 2)
  has <- !is.null(d$xse)
  xr <- range(d$x, if (has) d$x + c(-1, 1) * z * rep(d$xse, each = 2))
  yr <- range(d$y, if (has) d$y + c(-1, 1) * z * rep(d$yse, each = 2))
  # room on both sides for the place names printed beside the points
  xr <- xr + c(-1, 1) * 0.12 * diff(xr)
  do.call(graphics::plot, c(list(xr, yr, type = "n", xlab = "", ylab = "", main = ""), dots))
  .bl_title(.bl_main(main, sprintf("Across places: rho = %.2f (p = %s)", x$rho, format.pval(x$p_value, digits = 2))))
  .bl_xlab(if (is.null(xlab)) x$labels[["x"]] else .rmbl_string1(xlab, "xlab"))
  .bl_ylab(if (is.null(ylab)) x$labels[["y"]] else .rmbl_string1(ylab, "ylab"))
  .bl_grid(NULL, side = "y")
  if (has) {
    graphics::segments(d$x - z * d$xse, d$y, d$x + z * d$xse, d$y, col = grDevices::adjustcolor(cols, 0.5))
    graphics::segments(d$x, d$y - z * d$yse, d$x, d$y + z * d$yse, col = grDevices::adjustcolor(cols, 0.5))
  }
  graphics::points(d$x, d$y, pch = 21, bg = cols, col = "white", cex = 1.6)
  # neighbouring places labelled on alternating sides, so close points do not print over each other
  side <- c(3L, 1L, 4L, 2L)[(rank(d$x, ties.method = "first") - 1L) %% 4L + 1L]
  graphics::text(d$x, d$y, d$place, pos = side, offset = 0.6, cex = 0.65, col = "#3D4350", xpd = NA)
  invisible(d)
}

#' @rdname plot-methods
#' @export
plot.rmbl_healing_change <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  .rmbl_plot_check(x, "rmbl_healing_change")
  d <- as.data.frame(x)
  p <- attr(x, "periods")
  lab <- paste0(.bl_short_label(d$indicator), ": ", d$group, ifelse(d$usewithcau, " (E)", ""))
  side <- ifelse(is.na(d$side), 1L, ifelse(d$side == "wellness", 2L, 3L))
  cols <- .bl_cols(3L, col, palette)[side]
  .bl_dot_interval(lab, d$change, d$lower, d$upper,
                   .bl_main(main, sprintf("Change from %s to %s", p[["from"]], p[["to"]])),
                   "Change, in the estimate's units, with its interval", cols, ref = 0,
                   note = ifelse(is.finite(d$change), NA_character_, "suppressed in one period"), ...)
  invisible(d[c("group", "indicator", "change", "lower", "upper")])
}

#' @rdname plot-methods
#' @export
plot.rmbl_community_index <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  .rmbl_plot_check(x, "rmbl_community_index")
  d <- as.data.frame(x)
  .bl_dot_interval(paste0(d$group, ifelse(d$usewithcau, " (E)", "")), d$index, d$lower, d$upper,
                   .bl_main(main, "Community-weighted index of protective and risk factors"),
                   "Index under the weights given, with its interval", .bl_cols(nrow(d), col, palette),
                   note = ifelse(is.finite(d$index), NA_character_, "an indicator is suppressed"), ...)
  invisible(d[c("group", "index", "lower", "upper")])
}
