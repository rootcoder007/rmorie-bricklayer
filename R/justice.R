# SPDX-License-Identifier: AGPL-3.0-or-later Courts and police-reported crime:
# the flow of cases through a court, the time cases take, the mix of ways they
# end, where incidents cluster and whether they repeat close in space and time.
# Each function takes the published counts (or the incident points) as they
# come, returns a classed result with print() and plot() methods, and states the
# assumption it rests on in its documentation.

# ---- shared ------------------------------------------------------------------

# ---- case flow ---------------------------------------------------------------

#' Case flow through a court: clearance, backlog and time to clear
#'
#' Turns the counts a court publishes each period -- cases received, cases
#' disposed and, when it is published, cases pending -- into the measures
#' used to judge whether a court is keeping up: the clearance rate (cases
#' disposed per case received), its rolling value over a window, the net
#' flow into the inventory and, with the pending count, the number of
#' periods the current inventory would take to clear at the recent pace of
#' disposition.
#'
#' @param recv Cases received (new cases), one per period, in time
#'   order.
#' @param disp Cases disposed, one per period.
#' @param pend Optional cases pending at the end of each period.
#' @param prd Optional period labels: numbers, dates, or
#'   \code{"YYYY-MM"} strings (which the plot draws on a date axis).
#' @param win Periods in the rolling clearance rate and in the pace
#'   behind \code{pertoclear}. Default 12, a year of months.
#' @param conflvl Confidence level for the intervals. Default 0.95.
#'
#' @return A data frame of class \code{rmbl_case_flow}, one row per period, with
#'   \code{period}, \code{received}, \code{disposed}, \code{clearance} with
#'   \code{lower} and \code{upper}, \code{net} (received less disposed:
#'   positive grows the inventory), \code{rolclr} with
#'   \code{rollo} and \code{rolup} (\code{NA} until a full
#'   window is available), and either \code{pending},
#'   \code{penchg} and \code{pertoclear}, or, without
#'   \code{pending}, \code{cumnet} (the inventory change since the
#'   first period).
#'
#' @details
#' A clearance rate above 1 means the court disposed of more cases than it
#' received, so its inventory fell. The interval treats received and
#' disposed as Poisson counts over the same period: given their sum, the
#' disposed count is binomial, and the exact (Clopper-Pearson) limits for
#' that proportion give exact limits for the ratio. The interval measures
#' the period-to-period noise of counts this size; it does not make
#' received and disposed the same cases, which they are not (a case
#' disposed this month was usually received months before).
#'
#' \code{pertoclear} divides the pending inventory by the mean
#' number disposed over the last \code{win} periods (fewer at the start
#' of the series). The published pending count need not equal the previous
#' count plus the net flow -- courts reactivate cases on bench warrants and
#' transfer them -- so \code{penchg} is reported next to
#' \code{net} rather than derived from it.
#'
#' The result carries attribute \code{"caseflow"}: \code{win},
#' \code{conflvl} and the totals received and disposed. Errors:
#' \code{recv} empty; a count vector that is not numeric, has a missing,
#' negative or infinite value, or a length other than \code{recv}'s;
#' \code{prd} of another length, with missing or repeated values;
#' \code{win} not a whole number of at least 1; \code{conflvl}
#' outside (0, 1).
#'
#' @references
#' Ostrom, B. J. and Hanson, R. A. (1999). \emph{Efficiency, Timeliness,
#' and Quality: A New Perspective from Nine State Criminal Trial Courts}.
#' National Center for State Courts, Williamsburg, VA. (Clearance rate and
#' time-to-disposition measures.)
#'
#' Ulm, K. (1990). A simple method to calculate the confidence interval of
#' a standardized mortality ratio. \emph{American Journal of Epidemiology},
#' 131(2), 373-375. (Exact limits for a ratio of Poisson counts through the
#' beta distribution.)
#'
#' @seealso \code{\link{lifetbl}}, \code{\link{dispmix}},
#'   \code{\link{stkflow}} for custody populations.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' f <- read.csv(system.file(
#'   "extdata",
#'   "ocj_flow_ontario.csv",
#'   package = "rmoriebricklayer"
#' ))
#' cf <- caseflow(f$received, f$disposed, pend = f$pending, prd = f$month)
#' cf
#' plot(cf)
#'
#' # without the pending count, a quarterly rolling window and 90% intervals
#' cq <- caseflow(
#'   f$received,
#'   f$disposed,
#'   prd = f$month,
#'   win = 3,
#'   conflvl = 0.90
#' )
#' head(as.data.frame(cq)[, c("period", "clearance", "rolclr", "cumnet")])
#'
#' # one value per period in every count
#' try(caseflow(c(100, 120, 90), c(95, 130)))
#' @export
caseflow <- function(
  recv,
  disp,
  pend = NULL,
  prd = NULL,
  win = 12L,
  conflvl = 0.95
) {
  recv <- .jx_counts(recv, "recv")
  n <- length(recv)
  if (!n) {
    stop("`recv` is empty", call. = FALSE)
  }
  disp <- .jx_counts(disp, "disp", n)
  if (!is.null(pend)) {
    pend <- .jx_counts(pend, "pend", n)
  }
  prd <- .jx_period(prd, n)
  win <- .rmbl_num(win, "win", integer = TRUE)
  if (length(win) != 1L || is.na(win) || win < 1L) {
    stop("`win` must be a single whole number of at least 1", call. = FALSE)
  }
  conflvl <- .rmbl_conf_level(conflvl)
  ci <- .jx_ratio_ci(disp, recv, conflvl)
  clearance <- ifelse(recv > 0, disp / recv, NA_real_)
  rr <- .jx_roll(recv, n, win)
  rd <- .jx_roll(disp, n, win)
  rci <- .jx_ratio_ci(rd, rr, conflvl)
  out <- data.frame(
    period = prd,
    received = recv,
    disposed = disp,
    clearance = clearance,
    lower = ci$lower,
    upper = ci$upper,
    net = recv - disp,
    rolclr = ifelse(!is.na(rr) & rr > 0, rd / rr, NA_real_),
    rollo = rci$lower,
    rolup = rci$upper,
    stringsAsFactors = FALSE
  )
  out <- .jx_cf_pending(out, pend, disp, win)
  attr(out, "caseflow") <- list(
    window = win,
    conflvl = conflvl,
    totalrec = sum(recv),
    totaldis = sum(disp)
  )
  class(out) <- c("rmbl_case_flow", "data.frame")
  out
}

#' @export
format.rmbl_case_flow <- function(x, ...) {
  m <- attr(x, "caseflow")
  need <- c("period", "received", "disposed", "clearance", "lower", "upper")
  # a subset (x[1:3, ]) keeps the class but not the summary it was printed with
  if (is.null(m) || !all(need %in% names(x)) || !nrow(x)) {
    return(.an_plain(x, ...))
  }
  d <- as.data.frame(x)
  show <- d[c("period", "received", "disposed", "clearance")]
  show[[paste(.an_lvl(m$conflvl), "CI")]] <- .an_ci(d$lower, d$upper, 3L)
  more <- intersect(
    c("net", "rolclr", "pending", "pertoclear", "cumnet"),
    names(d)
  )
  show <- cbind(show, d[more])
  .an_block(
    "Case flow",
    facts = list(
      Periods = sprintf(
        "%s to %s (%d)",
        format(d$period[1L]),
        format(d$period[nrow(d)]),
        nrow(d)
      ),
      Intervals = sprintf(
        "%s exact (clearance is a ratio of counts)",
        .an_lvl(m$conflvl)
      ),
      `Rolling window` = sprintf("%d periods (rolclr)", m$window)
    ),
    tables = list(show),
    reading = c(.jx_cf_notes(x, m), .jx_cf_reading(x, m)),
    notes = c(
      "Clearance above 1: more cases disposed than received, so the",
      "caseload shrank; below 1, it grew."
    ),
    digits = 4L
  )
}

#' @rdname plot-methods
#' @export
plot.rmbl_case_flow <- function(
  x,
  ...,
  what = c("flow", "clearance"),
  main = NULL,
  col = NULL,
  palette = NULL
) {
  .rmbl_plot_check(x, "rmbl_case_flow")
  what <- .rmbl_arg(what, c("flow", "clearance"), several = TRUE)
  px <- .jx_period_x(x$period)
  cols <- .bl_cols(2, col, palette)
  if (length(what) > 1L) {
    op0 <- graphics::par(no.readonly = TRUE)
    on.exit(graphics::par(op0), add = TRUE)
    .bl_panels_begin(length(what))
    on.exit(.bl_panels_abort(), add = TRUE)
  }
  for (w in what) {
    if (w == "flow") {
      .jx_cf_flow(x, px, cols, if (length(what) == 1L) main else NULL, ...)
    } else {
      .jx_cf_clearance(x, px, cols, if (length(what) == 1L) main else NULL, ...)
    }
  }
  if (length(what) > 1L) {
    .bl_panels_end()
    if (!is.null(main)) {
      graphics::mtext(
        main,
        side = 3,
        outer = TRUE,
        line = -1.2,
        font = 2,
        col = "#1F2430"
      )
    }
  }
  invisible(as.data.frame(x))
}

# ---- grouped time to an event: the actuarial life table ----------------------

#' Life table for grouped times: how long cases take
#'
#' The actuarial (Cutler-Ederer) life table for times published only in
#' bands -- for example the share of court cases disposed within 10
#' months, between 10 and 15 months, and so on. It gives, at the end of
#' each band, the proportion still open (the survival function) with a
#' Greenwood confidence interval, the hazard within the band, and the
#' median time.
#'
#' @param breaks Band edges, increasing, starting at the time origin:
#'   \code{c(0, 10, 15, 18, Inf)} for the four bands above. The last edge
#'   may be \code{Inf} (an open band). Or band labels such as
#'   \code{c("Under 10", "10-15", "15-18", "Over 18")}, read with
#'   \code{\link{prsbands}}.
#' @param events Cases that ended in each band (counts, or expected
#'   counts such as a published share times the number of cases).
#' @param cens Cases withdrawn from observation in each band without
#'   the event (still open when the data were drawn); one value or one per
#'   band. Default 0.
#' @param conflvl Confidence level. Default 0.95.
#' @param conftype Scale of the interval: \code{"log-log"} (the default,
#'   which keeps the limits inside 0 to 1), \code{"log"} or \code{"plain"}.
#'
#' @return A data frame of class \code{rmbl_life_table}, one row per band:
#'   \code{lower}, \code{upper} (the band edges), \code{entering},
#'   \code{events}, \code{censored}, \code{atrisk} (entering less half the
#'   censored), \code{q} (conditional probability of the event in the
#'   band), \code{survival} at the end of the band with \code{se},
#'   \code{conflo} and \code{confup}, \code{hazard} (events per
#'   unit time within the band; \code{NA} for an open band), and the
#'   attribute \code{median}.
#'
#' @details Within a band the censored cases are assumed to have been at risk
#' for half of it, so the number at risk is \eqn{n'_j = n_j - c_j/2}; the
#' conditional probability of the event is \eqn{q_j = d_j / n'_j} and the
#' survival at the end of band \eqn{j} is \eqn{\prod_{i \le j} (1 - q_i)}.
#' Greenwood's formula gives \eqn{\mathrm{Var}(\hat S_j) = \hat S_j^2 \sum_{i
#' \le j} q_i / (n'_i (1 - q_i))}. With no censoring the table equals the
#' Kaplan-Meier estimate at the band edges, and the Greenwood variance equals
#' the one \code{survival::survfit()} reports. The hazard in a closed band is
#' \eqn{d_j / (w_j (n'_j - d_j / 2))} for band width \eqn{w_j}. The median is
#' interpolated linearly inside the band where survival crosses one half, which
#' assumes events are spread evenly across that band; when the crossing falls in
#' an open band, the median is reported as greater than its lower edge.
#'
#' Court statistics that count only disposed cases describe time to
#' disposition among cases that were disposed, with no censoring; cases
#' still pending are not in them, so the survival function describes the
#' disposed cohort, not every case received.
#'
#' The median is attribute \code{"median"} (\code{Inf}, with a \code{note},
#' when survival never falls to one half or crosses it in the open band), and
#' attribute \code{"lifetbl"} records \code{conflvl} and
#' \code{conftype}. Errors: band labels that cannot be read, or that are
#' not contiguous, or with an open band other than the last; fewer than two
#' increasing edges, or an infinite edge other than the last; \code{events}
#' or \code{cens} that are not non-negative counts, one per band; no
#' cases at all; \code{conflvl} outside (0, 1); an unknown
#' \code{conftype}.
#'
#' @references
#' Cutler, S. J. and Ederer, F. (1958). Maximum utilization of the life
#' table method in analyzing survival. \emph{Journal of Chronic
#' Diseases}, 8(6), 699-712.
#'
#' Greenwood, M. (1926). \emph{The Natural Duration of Cancer}. Reports on
#' Public Health and Medical Subjects 33. HMSO, London.
#'
#' Lee, E. T. and Wang, J. W. (2003). \emph{Statistical Methods for
#' Survival Data Analysis}, 3rd ed. Wiley, Hoboken, NJ. Chapter 4.
#'
#' @seealso \code{\link{caseflow}}, \code{\link{prsbands}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' d <- read.csv(system.file("extdata", "ocj_time_to_disposition.csv",
#'                           package = "rmoriebricklayer"))
#' f <- read.csv(system.file("extdata", "ocj_flow_ontario.csv",
#'                           package = "rmoriebricklayer"))
#' last <- nrow(d)
#' shares <- unlist(d[last, c("under_10", "m10_15", "m15_18", "over_18")])
#' lt <- lifetbl(c(0, 10, 15, 18, Inf), events = shares * f$disposed[last])
#' lt
#' plot(lt)
#'
#' # bands given by their labels, with some cases still open, on the log scale
#' lt2 <- lifetbl(c("Under 10", "10-15", "15-18", "Over 18"),
#'                   events = c(600, 150, 60, 90), cens = c(40, 20, 10, 0),
#'                   conftype = "log")
#' as.data.frame(lt2)[, c("lower", "upper", "atrisk", "survival",
#'                        "conflo", "confup")]
#' attr(lt2, "median")
#'
#' # an open band can only come last
#' try(lifetbl(c(0, Inf, 20), events = c(5, 5)))
#' @export
lifetbl <- function(
  breaks,
  events,
  cens = 0,
  conflvl = 0.95,
  conftype = c("log-log", "log", "plain")
) {
  .rmbl_no_fn(cens = cens)
  conftype <- .rmbl_arg(conftype)
  conflvl <- .rmbl_conf_level(conflvl)
  bh <- .jx_lt_bands(breaks)
  lo <- bh$lo
  hi <- bh$hi
  k <- length(lo)
  d <- .jx_counts(events, "events", k)
  w <- .jx_counts(if (length(cens) == 1L) rep(cens, k) else cens, "cens", k)
  total <- sum(d) + sum(w)
  if (total <= 0) {
    stop("there are no cases (`events` and `cens` are all zero)", call. = FALSE)
  }
  sv <- .jx_lt_survival(d, w, total)
  entering <- sv$entering
  at_risk <- sv$at_risk
  q <- sv$q
  surv <- sv$surv
  gw <- sv$gw
  se <- surv * sqrt(gw)
  lims <- .jx_lt_limits(surv, gw, conflvl, conftype)
  width <- hi - lo
  hazard <- ifelse(
    is.finite(width) & at_risk - d / 2 > 0,
    d / (width * (at_risk - d / 2)),
    NA_real_
  )
  s0 <- c(1, utils::head(surv, -1L))
  med <- .jx_lt_median(surv, s0, lo, hi, width)
  out <- data.frame(
    lower = lo,
    upper = hi,
    entering = entering,
    events = d,
    censored = w,
    atrisk = at_risk,
    q = q,
    survival = surv,
    se = se,
    conflo = lims[[1L]],
    confup = lims[[2L]],
    hazard = hazard
  )
  attr(out, "median") <- med
  attr(out, "lifetab") <- list(conflvl = conflvl, conftype = conftype)
  class(out) <- c("rmbl_life_table", "data.frame")
  out
}

#' @export
format.rmbl_life_table <- function(x, ...) {
  m <- attr(x, "lifetab")
  need <- c("lower", "upper", "events", "censored", "survival", "conflo")
  if (is.null(m) || !all(need %in% names(x)) || !nrow(x)) {
    return(.an_plain(x, ...))
  }
  med <- attr(x, "median")
  d <- as.data.frame(x)
  show <- d[intersect(
    c("lower", "upper", "entering", "events", "censored", "atrisk", "q"),
    names(d)
  )]
  show$survival <- d$survival
  show[[paste(.an_lvl(m$conflvl), "CI")]] <- .an_ci(d$conflo, d$confup)
  show$hazard <- d$hazard
  medtxt <- if (is.finite(med)) {
    sprintf("Median time: %.3g (linear within its band)", med)
  } else {
    paste("Median time:", attr(med, "note"))
  }
  .an_block(
    "Life table (actuarial)",
    facts = list(
      Bands = nrow(d),
      Cases = sum(d$events) + sum(d$censored),
      Events = sum(d$events),
      Censored = sum(d$censored),
      Interval = sprintf("%s %s Greenwood", .an_lvl(m$conflvl), m$conftype)
    ),
    tables = list(show),
    reading = c(
      medtxt,
      "survival is the share still without the event at the end of each band."
    ),
    notes = "A censored case counts as half a case at risk in its band."
  )
}

#' @rdname plot-methods
#' @export
plot.rmbl_life_table <- function(
  x,
  ...,
  main = NULL,
  col = NULL,
  palette = NULL
) {
  .rmbl_plot_check(x, "rmbl_life_table")
  cols <- .bl_cols(2, col, palette)
  hi <- x$upper
  open <- !is.finite(hi)
  # an open last band is drawn a band-width past its lower edge, marked with an
  # arrow
  span <- if (nrow(x) > 1L) {
    stats::median(diff(c(x$lower[1L], hi[!open])))
  } else {
    1
  }
  hi[open] <- x$lower[open] + span
  tx <- c(x$lower[1L], hi)
  sv <- c(1, x$survival)
  lo <- c(1, x$conflo)
  up <- c(1, x$confup)
  op <- .bl_par(c(0, 1))
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot(
    tx,
    sv,
    type = "n",
    ylim = c(0, 1),
    xlab = "Time",
    ylab = "",
    main = "",
    ...
  )
  .bl_ylab("Proportion still open")
  med <- attr(x, "median")
  .bl_title(.bl_main(
    main,
    if (is.finite(med)) {
      sprintf("Life table: median %.3g", med)
    } else {
      "Life table"
    }
  ))
  .bl_grid(NULL)
  .jx_lt_band(tx, lo, up, cols)
  .jx_lt_curve(tx, sv, open, cols)
  .jx_lt_marks(tx, open, med, cols)
  invisible(data.frame(time = tx, survival = sv, conflo = lo, confup = up))
}

# ---- composition: how cases end ----------------------------------------------

#' The mix of outcomes over time, with simultaneous intervals and trend tests
#'
#' For a table of counts -- periods in rows, outcomes in columns, such as
#' cases withdrawn, pleaded guilty, or tried -- gives each outcome's share
#' of its period with Goodman's simultaneous confidence intervals, tests
#' whether the mix is the same in every period, and tests each outcome for
#' a linear trend in its share.
#'
#' @param cnts A matrix or data frame of non-negative counts, one row per
#'   period and one column per outcome. Columns that are not numeric are
#'   refused; pass only the outcome columns.
#' @param prd Optional period labels (default: the row names, or
#'   \code{1:nrow(counts)}).
#' @param scores Numeric scores for the periods in the trend tests.
#'   Default: \code{1:nrow(counts)}, i.e. equally spaced.
#' @param conflvl Confidence level. Default 0.95.
#'
#' @return A list of class \code{rmbl_disposition_mix}: \code{shares}, a long
#'   data frame (\code{period}, \code{outcome}, \code{count}, \code{total},
#'   \code{share}, \code{lower}, \code{upper}); \code{homogeneity}, the
#'   Pearson chi-square test that every period has the same mix (with
#'   Cramer's V); \code{trend}, one row per outcome with the
#'   Cochran-Armitage trend statistic, its p-value, the Holm-adjusted
#'   p-value, and the change in share from the first to the last period.
#'
#' @details
#' Goodman's intervals hold for all \eqn{k} shares of a period at once: with
#' \eqn{A} the upper \eqn{\alpha/k} point of the chi-square distribution
#' on one degree of freedom, the limits for a share \eqn{n_i / N} are
#' \deqn{\frac{A + 2 n_i \pm \sqrt{A (A + 4 n_i (N - n_i) / N)}}{2 (N + A)}.}
#'
#' The trend test for each outcome is the Cochran-Armitage test of its
#' count against the period totals (\code{stats::prop.trend.test()}); the
#' Holm adjustment covers the \eqn{k} tests. Counts of court cases are
#' large, so these tests detect small changes; the shares and their
#' intervals show whether a change is large enough to matter.
#'
#' Errors: \code{cnts} not a numeric matrix or data frame, with a
#' non-numeric column, fewer than one period or two outcomes, or a negative,
#' missing or infinite count; a period with no cases; \code{scores} not one
#' finite number per period, or all equal; \code{prd} of the wrong length
#' or with repeats; \code{conflvl} outside (0, 1).
#'
#' @references
#' Goodman, L. A. (1965). On simultaneous confidence intervals for
#' multinomial proportions. \emph{Technometrics}, 7(2), 247-254.
#'
#' Armitage, P. (1955). Tests for linear trends in proportions and
#' frequencies. \emph{Biometrics}, 11(3), 375-386.
#'
#' Holm, S. (1979). A simple sequentially rejective multiple test
#' procedure. \emph{Scandinavian Journal of Statistics}, 6(2), 65-70.
#'
#' @seealso \code{\link{shrs}} for one period's shares with Wilson
#'   intervals.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' d <- read.csv(system.file("extdata", "ocj_dispositions.csv",
#'                           package = "rmoriebricklayer"))
#' mix <- dispmix(d[, -(1:2)], prd = d$year)
#' mix
#' plot(mix)
#'
#' # the parts of the result
#' head(mix$shares)
#' mix$trend
#'
#' # years as trend scores, so the gap where no row exists is respected
#' dispmix(d[, -(1:2)], prd = d$year, scores = d$year)$trend[, 1:3]
#'
#' # outcome columns only: a text column is refused
#' try(dispmix(data.frame(year = c("a", "b"), x = 1:2, y = 3:4)))
#' @export
dispmix <- function(cnts, prd = NULL, scores = NULL, conflvl = 0.95) {
  cnts <- .jx_dm_matrix(cnts)
  .jx_counts(as.vector(cnts), "cnts")
  conflvl <- .rmbl_conf_level(conflvl)
  nt <- nrow(cnts)
  k <- ncol(cnts)
  outcome <- colnames(cnts) %||% paste0("outcome_", seq_len(k))
  if (is.null(prd)) {
    prd <- rownames(cnts) %||% seq_len(nt)
  }
  prd <- .jx_period(prd, nt)
  tot <- rowSums(cnts)
  if (any(tot <= 0)) {
    stop(
      sprintf("period %s has no cases", format(prd[tot <= 0][1L])),
      call. = FALSE
    )
  }
  shares <- .jx_dm_shares(cnts, prd, outcome, tot, conflvl)
  homog <- NULL
  trend <- NULL
  if (nt >= 2L) {
    homog <- .jx_dm_homog(cnts)
  }
  if (nt >= 3L) {
    trend <- .jx_dm_trend(cnts, tot, scores, outcome)
  }
  structure(
    list(
      shares = shares,
      homogeneity = homog,
      trend = trend,
      period = prd,
      outcome = outcome,
      conflvl = conflvl
    ),
    class = "rmbl_disposition_mix"
  )
}

#' @export
format.rmbl_disposition_mix <- function(x, ...) {
  s <- x$shares
  wide <- stats::reshape(
    s[, c("period", "outcome", "share")],
    idvar = "outcome",
    timevar = "period",
    direction = "wide"
  )
  names(wide) <- sub("^share[.]", "", names(wide))
  tabs <- list(`Share of each period's cases` = wide)
  if (!is.null(x$trend)) {
    tr <- x$trend
    st <- formatC(tr$statistic, format = "f", digits = 2L, big.mark = ",")
    tr$statistic <- formatC(st, width = max(nchar(st)))
    tabs[["Cochran-Armitage trend in each share (Holm-adjusted)"]] <- tr
  }
  h <- x$homogeneity
  .an_block(
    "Outcome shares by period",
    facts = list(
      Periods = length(x$period),
      Outcomes = length(x$outcome),
      Cases = sum(s$count),
      Intervals = sprintf(
        "%s Goodman simultaneous (in $shares)",
        .an_lvl(x$conflvl)
      ),
      `Same mix in every period` = if (!is.null(h)) {
        sprintf(
          "chi-square %.1f on %d df, p %s, Cramer's V %.3f",
          h$statistic,
          h$df,
          .rmbl_fmt_p(h$p_value),
          h$cramerv
        )
      }
    ),
    tables = tabs,
    reading = c(.jx_dm_reading(x), .jx_dm_trends(x)),
    notes = if (is.null(x$trend)) "A trend test needs three periods or more."
  )
}

#' @rdname plot-methods
#' @export
plot.rmbl_disposition_mix <- function(
  x,
  ...,
  main = NULL,
  col = NULL,
  palette = NULL
) {
  .rmbl_plot_check(x, "rmbl_disposition_mix")
  s <- x$shares
  nt <- length(x$period)
  k <- length(x$outcome)
  sh <- matrix(s$share, nrow = nt, ncol = k)
  cum <- cbind(0, t(apply(sh, 1L, cumsum)))
  if (nt == 1L) {
    cum <- matrix(c(0, cumsum(sh)), nrow = 1L)
  }
  px <- .jx_period_x(x$period)
  pxn <- as.numeric(px)
  cols <- .bl_cols(k, col, palette)
  labs <- gsub("_", " ", x$outcome, fixed = TRUE)
  o <- .bl_plot_opts()
  op <- .jx_cd_par(o)
  on.exit(graphics::par(op), add = TRUE)
  # the outcome labels are drawn at 0.75 of the text size (text() scales by
  # par("cex") as strwidth() does), so the right margin is their measured width
  # in lines plus a gap
  fit <- .bl_label_fit(labs, cex = 0.75)
  right <- max(.bl_strwidth(fit$labels, cex = 0.75), 0) /
    graphics::par("csi") +
    1.2
  graphics::par(mar = .bl_safe_mar(c(4.2, 4.5, 3, right), o$cex))
  xr <- if (nt == 1L) pxn + c(-0.5, 0.5) else range(pxn)
  graphics::plot(
    xr,
    c(0, 1),
    type = "n",
    xaxt = "n",
    xlab = "Period",
    ylab = "",
    main = "",
    ...
  )
  .bl_ylab("Share of cases")
  if (inherits(px, "Date")) {
    graphics::axis.Date(1, px)
  } else {
    graphics::axis(1, at = pxn, labels = x$period)
  }
  .bl_title(.bl_main(main, "How cases ended"))
  xs <- if (nt == 1L) xr else pxn
  .jx_dm_bands(xs, cum, cols)
  .jx_dm_labels(cum, fit$labels, cols)
  invisible(s)
}

#' Where incidents cluster: a kernel density surface
#'
#' Estimates the density of incident locations -- police-reported
#' occurrences, calls for service, addresses of people in a program -- as
#' a smooth surface in incidents per square kilometre, and the smallest
#' areas holding a given share of them (the highest-density regions). The
#' plot draws the surface as a heat map with those regions outlined.
#'
#' @param lon,lat Coordinates of the incidents: longitude and latitude in
#'   degrees (WGS84) by default, or planar coordinates in metres with
#'   \code{coords = "planar"}. Points with a missing coordinate are
#'   dropped with a message; in degrees, points at exactly (0, 0), which
#'   is how several open-data portals publish an incident with no
#'   location, are dropped too.
#' @param w Optional non-negative weight per incident. Default 1.
#' @param bw Kernel standard deviation in kilometres: one value for
#'   both directions or two (east-west, north-south). Default: Scott's
#'   normal-reference rule, \eqn{\sigma n^{-1/6}} for each direction.
#' @param ngrid Grid nodes per direction. Default 200.
#' @param cover Shares of the incidents whose highest-density regions
#'   are reported and outlined. Default \code{c(0.5, 0.9)}.
#' @param xy \code{"lonlat"} (the default) or \code{"planar"}.
#'
#' @return A list of class \code{rmbl_density}: \code{field} (incidents per
#'   square kilometre on the grid), \code{x} and \code{y} (grid coordinates
#'   in kilometres from the centre), \code{lon} and \code{lat} (the same
#'   grid in degrees, for \code{"lonlat"}), \code{bandwidth}, \code{n},
#'   \code{dropped}, \code{points} (the projected incidents), and
#'   \code{regions}: one row per coverage share with the density
#'   \code{level} that bounds it, its \code{areakm2}, and its share of the
#'   mapped area.
#'
#' @details
#' The estimate is the Gaussian product-kernel density, computed on the
#' grid by linear binning followed by an exact discrete convolution, which
#' agrees with the direct sum to within the binning error (of order the
#' squared grid spacing over the squared bandwidth). The grid extends three
#' bandwidths past the outermost incident so the surface integrates to the
#' total weight.
#'
#' A highest-density region for share \eqn{p} is the set of grid cells
#' with the largest densities whose estimated incidents add up to \eqn{p}
#' of the total. Its area is the spatial counterpart of a concentration
#' index: when half the incidents fall in a few per cent of the mapped
#' area, they are concentrated. The bandwidth decides how sharp the
#' surface is, so it should be reported with any map; the default suits a
#' first look, not a definitive one.
#'
#' Errors: \code{lon} and \code{lat} of different lengths, or (with
#' \code{coords = "lonlat"}) a coordinate that is not a longitude and
#' latitude in degrees; fewer than two located incidents with positive weight;
#' \code{ngrid} not a whole number from 10 to 2000; \code{cover} not
#' shares strictly between 0 and 1; incidents all on one line with no
#' \code{bw} given; a \code{bw} that is not one or two positive
#' numbers, or longer than half the earth's circumference. Incidents with a
#' missing coordinate are dropped.
#'
#' @references
#' Scott, D. W. (2015). \emph{Multivariate Density Estimation: Theory,
#' Practice, and Visualization}, 2nd ed. Wiley, Hoboken, NJ.
#'
#' Wand, M. P. (1994). Fast computation of multivariate kernel estimators.
#' \emph{Journal of Computational and Graphical Statistics}, 3(4),
#' 433-445.
#'
#' Hyndman, R. J. (1996). Computing and graphing highest density regions.
#' \emph{The American Statistician}, 50(2), 120-126.
#'
#' Chainey, S., Tompson, L. and Uhlig, S. (2008). The utility of hotspot
#' mapping for predicting spatial patterns of crime. \emph{Security
#' Journal}, 21(1-2), 4-28.
#'
#' @seealso \code{\link{knoxtst}}, \code{\link{plmfld}} (the same
#'   kind of surface, for an air pollutant).
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' b <- read.csv(system.file("extdata", "tps_break_enter_d14_2024.csv",
#'                           package = "rmoriebricklayer"))
#' kd <- crmdens(b$lon, b$lat, ngrid = 120)
#' kd
#' plot(kd)
#'
#' # a fixed 300 m bandwidth on a coarser grid: a sharper surface
#' kd3 <- crmdens(b$lon, b$lat, bw = 0.3, ngrid = 60)
#' kd3$regions
#'
#' # planar coordinates in metres
#' set.seed(2)
#' xy <- cbind(rnorm(200, sd = 500), rnorm(200, sd = 500))
#' crmdens(xy[, 1], xy[, 2], xy = "planar", ngrid = 40)$bandwidth
#'
#' # longitudes and latitudes are checked
#' try(crmdens(c(-79.4, 200), c(43.7, 43.8)))
#' @export
crmdens <- function(
  lon,
  lat,
  w = NULL,
  bw = NULL,
  ngrid = 200L,
  cover = c(0.5, 0.9),
  xy = c("lonlat", "planar")
) {
  xy <- .rmbl_arg(xy)
  lon <- .rmbl_num_input(lon, "lon", allow_null = FALSE)
  lat <- .rmbl_num_input(lat, "lat", allow_null = FALSE)
  if (length(lon) != length(lat)) {
    stop("`lon` and `lat` must have the same length", call. = FALSE)
  }
  pw <- .cd_points(lon, lat, w, xy)
  lon <- pw$lon
  lat <- pw$lat
  .w <- pw$w
  dropped <- pw$dropped
  ngrid <- .cd_check_grid(ngrid, cover)
  cover <- .rmbl_num_input(cover, "cover", allow_null = FALSE)
  pp <- .cd_plane(lon, lat, xy)
  p <- pp$p
  lon0 <- pp$lon0
  lat0 <- pp$lat0
  n <- length(p$x)
  h <- .cd_bandwidth(bw, p, .w, xy)
  gx <- seq(min(p$x) - 3 * h[1L], max(p$x) + 3 * h[1L], length.out = ngrid)
  gy <- seq(min(p$y) - 3 * h[2L], max(p$y) + 3 * h[2L], length.out = ngrid)
  dx <- gx[2L] - gx[1L]
  dy <- gy[2L] - gy[1L]
  .cd_spacing_warn(dx, dy, h)
  field <- .cd_field(p, .w, gx, gy, h)
  cell <- dx * dy
  mass <- field * cell
  regions <- .cd_regions(field, mass, cell, cover)
  out <- list(
    field = field,
    x = gx,
    y = gy,
    bandwidth = h,
    n = n,
    total = sum(.w),
    dropped = dropped,
    points = data.frame(x = p$x, y = p$y),
    regions = regions,
    coords = xy,
    centre = c(lon = lon0, lat = lat0)
  )
  if (xy == "lonlat") {
    out <- .cd_lonlat_grid(out, p, lat0, lat)
  }
  class(out) <- "rmbl_density"
  out
}

#' @export
format.rmbl_density <- function(x, ...) {
  r <- x$regions
  show <- data.frame(
    incidents = sprintf("%g%%", 100 * r$coverage),
    areakm2 = r$areakm2,
    shrofmaparea = sprintf("%.1f%%", 100 * r$areashr),
    densatedge = r$level,
    stringsAsFactors = FALSE
  )
  .an_block(
    "Kernel density of incidents",
    facts = list(
      Incidents = x$n,
      Dropped = if (x$dropped) sprintf("%d without a location", x$dropped),
      Coordinates = if (identical(x$coords, "lonlat")) {
        sprintf(
          "longitude and latitude, centred on %.4f, %.4f",
          x$centre[[1L]],
          x$centre[[2L]]
        )
      } else {
        "planar, in kilometres"
      },
      Grid = sprintf("%d x %d cells", length(x$x), length(x$y)),
      Bandwidth = sprintf(
        "%.3g km east-west, %.3g km north-south",
        x$bandwidth[1L],
        x$bandwidth[2L]
      ),
      `Peak density` = sprintf("%.4g incidents per km2", max(x$field))
    ),
    tables = list(`The smallest areas holding each share of incidents` = show),
    reading = .jx_de_reading(x)
  )
}

#' @rdname plot-methods
#' @param points For \code{rmbl_density}, whether to draw the incidents
#'   over the surface.
#' @usage \method{plot}{rmbl_density}(x, ..., points = TRUE, main = NULL,
#'   col = NULL, palette = NULL)
#' @export
plot.rmbl_density <- function(
  x,
  ...,
  points = TRUE,
  main = NULL,
  col = NULL,
  palette = NULL
) {
  .rmbl_plot_check(x, "rmbl_density")
  ll <- x$coords == "lonlat"
  xs <- if (ll) x$lon else x$x
  ys <- if (ll) x$lat else x$y
  f <- x$field
  # the faintest tail is left blank so the map reads as hot spots on a plain
  # ground
  f[f < 0.02 * max(f)] <- NA
  # col = "notacolor" failed in image.default() in its own words (final audit of
  # 1.0.0, #11)
  cols <- .cd_cols(col, palette)
  op <- .bl_par(ys)
  on.exit(graphics::par(op), add = TRUE)
  asp <- if (ll) 1 / cos(x$centre[["lat"]] * pi / 180) else 1
  graphics::image(
    xs,
    ys,
    f,
    col = cols,
    asp = asp,
    useRaster = TRUE,
    xlab = if (ll) "Longitude" else "x (km)",
    ylab = "",
    main = "",
    ...
  )
  .bl_ylab(if (ll) "Latitude" else "y (km)")
  .bl_title(.bl_main(
    main,
    sprintf("Incident density, %s incidents", format(x$n, big.mark = ","))
  ))
  .cd_overlay(x, xs, ys, ll, points)
  invisible(data.frame(
    x = rep(xs, times = length(ys)),
    y = rep(ys, each = length(xs)),
    density = as.vector(x$field)
  ))
}

#' Near-repeat analysis: the Knox test for space-time clustering
#'
#' Asks whether incidents close together in space also happen close
#' together in time more often than chance would give -- the near-repeat
#' pattern of burglary and shootings. Pairs of incidents are classified by
#' distance band and time band; each cell's count is compared with the
#' count expected if the times were shuffled among the locations, and a
#' Monte Carlo permutation test gives its p-value.
#'
#' @param x,y Locations: longitude and latitude in degrees by default
#'   (\code{coords = "lonlat"}), or planar coordinates in metres.
#' @param time Times of the incidents: \code{Date}, \code{POSIXct}, or
#'   numbers in days.
#' @param spcbands Upper edges of the distance bands in metres,
#'   increasing: \code{c(100, 200, 400)} is 0-100, 100-200 and 200-400 m.
#' @param tmbands Upper edges of the time bands in days, increasing.
#' @param nsim Monte Carlo permutations. Default 999.
#' @param seed Optional seed for the permutations, a whole number from
#'   -2147483647 to 2^53 - 1; the caller's random stream is left as it was.
#' @param xy \code{"lonlat"} or \code{"planar"}.
#' @param maxprs Limit on candidate pairs held in memory. Default 5e7.
#'
#' @return A list of class \code{rmbl_knox}: \code{table}, a long data frame
#'   with one row per distance-by-time cell (\code{spclo},
#'   \code{spcup}, \code{tmlo}, \code{tmup},
#'   \code{observed}, \code{expected}, \code{ratio}, \code{p_value}); the
#'   \code{n} incidents used; \code{nsim}.
#'
#' @details
#' Under the null hypothesis that the times are exchangeable among the
#' locations, every unordered pair of locations receives a uniformly random
#' pair of times, so the expected count in a cell is exact:
#' \eqn{E_{st} = S_s T_t / P}, where \eqn{S_s} is the number of pairs in
#' distance band \eqn{s}, \eqn{T_t} the number in time band \eqn{t}, and
#' \eqn{P = n(n-1)/2}. The ratio is \eqn{O_{st} / E_{st}}: above 1, pairs
#' that close in space are that close in time more often than chance. The
#' p-value of each cell is one-sided, \eqn{(1 + \#\{O^* \ge O\}) / (1 +
#' nsim)} over the permutations. Cells are tested separately; a table of
#' many cells will show some small p-values by chance alone.
#'
#' Only pairs within the largest distance band are needed, and they are
#' found by hashing the locations to a grid, so the work grows with the
#' number of close pairs rather than with \eqn{n^2}.
#'
#' Ties in time -- incidents recorded to the day -- put same-day pairs in
#' the first time band (0 to its edge). The test speaks to the timing of
#' incidents relative to each other, not to what caused them; near-repeat
#' patterns also arise when one offender commits a series.
#'
#' Errors: \code{x}, \code{y} and \code{time} of different lengths;
#' \code{spcbands} or \code{tmbands} not positive, finite and
#' increasing; \code{nsim} below 19; \code{maxprs} below 1; longitude and
#' latitude out of range under \code{coords = "lonlat"}; fewer than three
#' incidents. With \code{seed} the random number stream is set for the call
#' and restored afterwards.
#'
#' @references
#' Knox, E. G. (1964). The detection of space-time interactions.
#' \emph{Journal of the Royal Statistical Society, Series C (Applied
#' Statistics)}, 13(1), 25-30.
#'
#' Mantel, N. (1967). The detection of disease clustering and a
#' generalized regression approach. \emph{Cancer Research}, 27(2),
#' 209-220.
#'
#' Johnson, S. D., Bernasco, W., Bowers, K. J., Elffers, H., Ratcliffe,
#' J., Rengert, G. and Townsley, M. (2007). Space-time patterns of risk: a
#' cross national assessment of residential burglary victimization.
#' \emph{Journal of Quantitative Criminology}, 23(3), 201-219.
#'
#' @seealso \code{\link{crmdens}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' b <- read.csv(system.file("extdata", "tps_break_enter_d14_2024.csv",
#'                           package = "rmoriebricklayer"))
#' b <- b[!is.na(b$lon), ]
#' kn <- knoxtst(b$lon, b$lat, as.Date(b$occ_date), spcbands = c(100, 200, 400),
#'                 tmbands = c(7, 14, 28), nsim = 199, seed = 1)
#' kn
#' plot(kn)
#'
#' # planar coordinates in metres and times in days, on simulated points
#' set.seed(5)
#' n <- 150
#' kp <- knoxtst(runif(n, 0, 2000), runif(n, 0, 2000), runif(n, 0, 365),
#'                 spcbands = c(200, 400), tmbands = c(14, 28),
#'                 nsim = 99, seed = 2, xy = "planar")
#' kp
#'
#' # bands must increase
#' try(knoxtst(b$lon, b$lat, as.Date(b$occ_date), c(400, 100), c(7, 14)))
#' @export
knoxtst <- function(
  x,
  y,
  time,
  spcbands,
  tmbands,
  nsim = 999L,
  seed = NULL,
  xy = c("lonlat", "planar"),
  maxprs = 5e7
) {
  xy <- .rmbl_arg(xy)
  maxprs <- .knox_maxprs(maxprs)
  x <- .rmbl_num_input(x, "x", allow_null = FALSE)
  y <- .rmbl_num_input(y, "y", allow_null = FALSE)
  pts <- .knox_points(x, y, time)
  x <- pts$x
  y <- pts$y
  tt <- pts$tt
  sb <- .knox_bands(spcbands, "spcbands")
  tb <- .knox_bands(tmbands, "tmbands")
  nsim <- .knox_nsim(nsim)
  if (xy == "lonlat") {
    pts <- .knox_lonlat(x, y, tt)
    x <- pts$x
    y <- pts$y
    tt <- pts$tt
  }
  n <- length(x)
  if (n < 3L) {
    stop("need at least three incidents", call. = FALSE)
  }
  pm <- .knox_metres(x, y, xy)
  cp <- .jx_close_pairs(pm$x, pm$y, max(sb), maxprs)
  ks <- length(sb)
  kt <- length(tb)
  ex <- .knox_expected(cp, sb, tb, tt, n)
  s_idx <- ex$s_idx
  expected <- ex$expected
  cell_of <- function(tv) .knox_cell_counts(tv, cp, s_idx, tb, ks)
  obs <- cell_of(tt)
  sims <- .knox_sims(seed, nsim, cell_of, tt, ks * kt)
  pv <- (1 + rowSums(sims >= obs)) / (nsim + 1)
  tab <- .knox_table(sb, tb, obs, expected, pv)
  structure(
    list(
      table = tab,
      n = n,
      nsim = nsim,
      spcbands = sb,
      tmbands = tb,
      closeprs = length(cp$d)
    ),
    class = "rmbl_knox"
  )
}

#' @export
format.rmbl_knox <- function(x, ...) {
  t <- x$table
  cell <- .knox_labels(t)
  m <- matrix(cell, nrow = length(x$spcbands))
  df <- data.frame(
    distance = sprintf(
      "%g-%g m",
      c(0, utils::head(x$spcbands, -1L)),
      x$spcbands
    ),
    m,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  names(df)[-1L] <- sprintf(
    "%g-%g d",
    c(0, utils::head(x$tmbands, -1L)),
    x$tmbands
  )
  .an_block(
    "Knox test of near-repeat incidents",
    facts = list(
      Incidents = x$n,
      Permutations = x$nsim,
      `Close pairs` = x$closeprs,
      `Space bands` = toString(x$spcbands),
      `Time bands` = toString(x$tmbands)
    ),
    tables = list(`Knox ratios, observed / expected pairs` = df),
    reading = c(
      "A ratio above 1: more pairs this close in space and in time than",
      "chance alone gives, the near-repeat pattern."
    ),
    notes = paste0(
      "* p < 0.05, ** p < 0.01, one-sided per cell (not adjusted for the ",
      "number of cells); - nothing expected"
    )
  )
}

#' @rdname plot-methods
#' @export
plot.rmbl_knox <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  .rmbl_plot_check(x, "rmbl_knox")
  t <- x$table
  ks <- length(x$spcbands)
  kt <- length(x$tmbands)
  r <- matrix(t$ratio, nrow = ks)
  lr <- log2(r)
  lim <- max(1, abs(lr[is.finite(lr)]))
  # white at a ratio of 1, blue below, red above (the diverging palette's grey
  # midpoint muddied every cell near 1)
  cols <- .knox_cols(col, palette)
  ylabs <- sprintf("%g-%g", c(0, utils::head(x$spcbands, -1L)), x$spcbands)
  op <- .bl_par(labels = ylabs)
  on.exit(graphics::par(op), add = TRUE)
  # room for the axis title outside the band labels
  mar <- graphics::par("mar")
  graphics::par(mar = .bl_safe_mar(c(mar[1L], mar[2L] + 1.6, mar[3L], mar[4L])))
  lr[!is.finite(lr)] <- NA
  graphics::image(
    seq_len(kt),
    seq_len(ks),
    t(lr),
    col = cols,
    zlim = c(-lim, lim),
    axes = FALSE,
    xlab = "Days apart",
    ylab = "",
    main = "",
    ...
  )
  graphics::axis(
    1,
    at = seq_len(kt),
    labels = sprintf("%g-%g", c(0, utils::head(x$tmbands, -1L)), x$tmbands)
  )
  graphics::axis(2, at = seq_len(ks), labels = ylabs)
  .bl_knox_ylab(ylabs)
  graphics::box()
  .bl_title(.bl_main(main, "Near repeats: Knox ratio (observed / expected)"))
  lab <- .knox_labels(t)
  graphics::text(
    rep(seq_len(kt), each = ks),
    rep(seq_len(ks), times = kt),
    lab,
    cex = 0.85
  )
  invisible(t)
}

#' Decompose a change in a clearance rate into rate and case-mix effects
#'
#' An aggregate clearance rate -- cases disposed per case received by a
#' court, or offences cleared per offence reported to a police service --
#' is a weighted mean of the rates of its parts (offence groups, courts,
#' case types), weighted by each part's share of the denominator. It can
#' therefore fall while the rate of every part rises, if the work shifts
#' toward the parts that clear more slowly: Simpson's paradox. This
#' function compares two periods (or two jurisdictions), splits the change
#' in the aggregate exactly into the change in the parts' rates and the
#' change in the mix, reports the rate standardised to a common mix, tests
#' the within-part change, and says whether the comparison is a reversal.
#'
#' @param num Cases disposed (or cleared), one per part and
#'   comparison.
#' @param den Cases received (or reported), one per part and
#'   comparison.
#' @param grp The part each row belongs to: offence group, court, case
#'   type.
#' @param cmp The comparison each row belongs to: exactly two values,
#'   such as two years or two jurisdictions.
#' @param base Which value of \code{cmp} is the baseline. Default: the
#'   first in sorted order.
#' @param conflvl Confidence level. Default 0.95.
#'
#' @return A list of class \code{rmbl_clearance_decomposition}:
#'   \describe{
#'   \item{\code{groups}}{one row per part: the counts, rates and
#'     denominator shares (\code{weight}) in both comparisons, the rate
#'     ratio with its exact interval, and the part's \code{rateeff} and
#'     \code{mixeff}.}
#'   \item{\code{overall}}{the aggregate rates, their \code{change}, its
#'     \code{rateeff} and \code{mixeff} (which add to it exactly),
#'     the comparison rate standardised to the baseline mix
#'     (\code{staonbase}) and to the average mix
#'     (\code{staonave}).}
#'   \item{\code{rateratio}}{the crude rate ratio and the Mantel-Haenszel
#'     rate ratio over the parts, each with its interval, and the p-value
#'     for the stratified ratio.}
#'   \item{\code{simpson}}{\code{"full"} when every part moved one way and
#'     the aggregate the other; \code{"mix"} when the aggregate moved
#'     against the mix-standardised change (the mix outweighed the rates);
#'     \code{"none"} otherwise; with the number of parts that rose and
#'     fell.}
#'   }
#'
#' @details With part rates \eqn{r_g} and denominator shares \eqn{w_g}, the
#' aggregate is \eqn{R = \sum_g w_g r_g}. Kitagawa's symmetric decomposition
#' writes the change between comparisons A and B as \deqn{R_B - R_A = \sum_g
#' \bar w_g (r_{gB} - r_{gA}) + \sum_g \bar r_g (w_{gB} - w_{gA}),} with
#' \eqn{\bar w_g} and \eqn{\bar r_g} the averages over A and B: the first sum is
#' the rate effect (the change the aggregate would show with the mix held at its
#' average), the second the mix effect. The two add to the observed change with
#' no residual. Because the shares' changes add to zero, each part's mix term is
#' reported as \eqn{(\bar r_g - \bar R)(w_{gB} - w_{gA})}, centred on the
#' average aggregate rate \eqn{\bar R}: the total is the same, and a part's term
#' is negative when work moved toward a part that clears below average.
#'
#' The within-part change is estimated by the Mantel-Haenszel rate ratio,
#' treating each part's numerator as a Poisson count over its denominator,
#' with the Greenland-Robins variance; the p-value is for the hypothesis
#' that the ratio is 1. Each part's own rate ratio has the exact
#' conditional (binomial) interval. A court's clearance rate can exceed 1,
#' so it is treated as a rate rather than a proportion; for police
#' clearance, where it is a proportion, the Poisson treatment is
#' conservative.
#'
#' The decomposition is only as good as the parts: a different grouping
#' (courts instead of offence groups) can tell a different story, and both
#' can be right. Demers and Rossmo found 210 reversals in fifteen years of
#' clearance rates for Canada's fifty largest police services, four of
#' them reversed in every crime category, and advise comparing clearance
#' rates only within comparable mixes.
#'
#' @references
#' Simpson, E. H. (1951). The interpretation of interaction in contingency
#' tables. \emph{Journal of the Royal Statistical Society, Series B},
#' 13(2), 238-241.
#'
#' Kitagawa, E. M. (1955). Components of a difference between two rates.
#' \emph{Journal of the American Statistical Association}, 50(272),
#' 1168-1194. \doi{10.2307/2281213}
#'
#' Das Gupta, P. (1993). \emph{Standardization and Decomposition of Rates:
#' A User's Manual}. U.S. Bureau of the Census, Current Population Reports
#' P23-186. Washington, DC.
#'
#' Greenland, S. and Robins, J. M. (1985). Estimation of a common effect
#' parameter from sparse follow-up data. \emph{Biometrics}, 41(1), 55-68.
#'
#' Demers, S. and Rossmo, D. K. (2015). Simpson's paradox in Canadian
#' police clearance rates. \emph{Canadian Journal of Criminology and
#' Criminal Justice}, 57(3), 424-434.
#' \doi{10.3138/cjccj.2014-E29}
#'
#' @seealso \code{\link{caseflow}} for the clearance rate over time.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' g <- read.csv(system.file(
#'   "extdata",
#'   "ocj_offence_groups.csv",
#'   package = "rmoriebricklayer"
#' ))
#' g <- g[g$year %in% c(2014, 2022), ]
#' cd <- clrdcmp(g$disposed, g$received, g$offence_group, g$year)
#' cd
#' plot(cd)
#'
#' # Simpson's paradox in four numbers: each part clears better in B, yet the
#' # aggregate falls, because B's workload moved to the part that clears less
#' toy <- clrdcmp(
#'   num = c(90, 20, 19, 60),
#'   den = c(100, 50, 20, 140),
#'   grp = c("minor", "serious", "minor", "serious"),
#'   cmp = c("A", "A", "B", "B")
#' )
#' toy
#'
#' # every part must appear in both comparisons
#' try(clrdcmp(c(5, 6, 7), c(10, 10, 10), c("x", "y", "x"), c(1, 1, 2)))
#' @export
clrdcmp <- function(num, den, grp, cmp, base = NULL, conflvl = 0.95) {
  ck <- .clr_check_inputs(num, den, grp, cmp)
  .num <- ck$num
  .den <- ck$den
  conflvl <- .rmbl_conf_level(conflvl)
  levs <- .clr_levels(cmp, base)
  key <- paste(grp, cmp, sep = "\r")
  .clr_check_parts(grp, cmp, key, levs)
  g <- sort(unique(grp))
  pick <- function(v, l) v[match(paste(g, l, sep = "\r"), key)]
  na <- pick(.num, levs[1L])
  da <- pick(.den, levs[1L])
  nb <- pick(.num, levs[2L])
  db <- pick(.den, levs[2L])
  .clr_check_zero(g, da, db)
  k <- .clr_kitagawa(na, da, nb, db)
  ra <- k$ra
  rb <- k$rb
  wa <- k$wa
  wb <- k$wb
  rate_eff <- k$rate_eff
  mix_eff <- k$mix_eff
  groups <- .clr_group_table(g, na, da, nb, db, k, conflvl)
  agg_a <- sum(na) / sum(da)
  agg_b <- sum(nb) / sum(db)
  overall <- data.frame(
    ratea = agg_a,
    rateb = agg_b,
    change = agg_b - agg_a,
    rateeff = sum(rate_eff),
    mixeff = sum(mix_eff),
    staonbase = sum(wa * rb),
    staonave = sum((wa + wb) / 2 * rb)
  )
  rr <- .clr_rate_ratio(na, da, nb, db, conflvl)
  up <- sum(rb > ra)
  down <- sum(rb < ra)
  type <- .clr_simpson(overall, up, down, length(g))
  structure(
    list(
      groups = groups,
      overall = overall,
      rateratio = rr,
      simpson = list(type = type, up = up, down = down, parts = length(g)),
      compare = levs,
      conflvl = conflvl
    ),
    class = "rmbl_clearance_decomposition"
  )
}

#' @export
format.rmbl_clearance_decomposition <- function(x, ...) {
  o <- x$overall
  s <- x$simpson
  a <- format(x$compare[1L])
  b <- format(x$compare[2L])
  verdict <- .clr_verdict(s, o)
  g <- x$groups
  show <- data.frame(
    part = g$group,
    ratea = g$ratea,
    rateb = g$rateb,
    weia = g$weia,
    weib = g$weib,
    ratio = g$rateratio,
    ci = .an_ci(g$lower, g$upper),
    rateeff = g$rateeff,
    mixeff = g$mixeff,
    stringsAsFactors = FALSE
  )
  names(show)[c(2:5, 7L)] <- c(
    paste("rate", a),
    paste("rate", b),
    paste("share", a),
    paste("share", b),
    paste(.an_lvl(x$conflvl), "CI")
  )
  .an_block(
    sprintf("Clearance rate, %s against %s (Kitagawa)", b, a),
    facts = .clr_facts(o, s, a, b),
    tables = list(show),
    reading = c(
      sprintf("%d of %d parts rose, %d fell.", s$up, s$parts, s$down),
      verdict,
      "Rate effect: the change at a fixed case mix; mix effect: the change",
      "from the mix of cases alone."
    ),
    notes = .clr_footer(x$rateratio, a, b)
  )
}

#' @rdname plot-methods
#' @param maxparts For \code{rmbl_clearance_decomposition}, the most parts
#'   drawn: past it, the parts that moved the aggregate most, and the rest
#'   summed into one row. The 0.5.x name \code{max_parts} is still accepted.
#' @usage \method{plot}{rmbl_clearance_decomposition}(x, ..., what = NULL,
#'   maxparts = 20L, main = NULL, col = NULL, palette = NULL)
#' @export
plot.rmbl_clearance_decomposition <- function(
  x,
  ...,
  what = NULL,
  maxparts = 20L,
  main = NULL,
  col = NULL,
  palette = NULL
) {
  old <- .rmbl_old_names(c(max_parts = "maxparts"))
  if (!is.null(old)) {
    return(eval(old$call, old$env))
  }
  .rmbl_plot_check(x, "rmbl_clearance_decomposition")
  cols <- .bl_cols(2, col, palette)
  maxparts <- .jx_cd_maxparts(maxparts)
  v <- .jx_cd_view(x, maxparts)
  x$groups <- v$groups
  x$other <- v$other
  # the paradox needs two pictures side by side: the parts' rates (most went one
  # way) and where the work moved (toward the parts that clear less); the
  # waterfall adds the sum. Ten inches hold all three, six hold the first two,
  # and a smaller device the rates alone, with the decomposition written under
  # them.
  if (is.null(what)) {
    what <- .jx_cd_what()
  }
  what <- .rmbl_arg(what, c("rates", "mix", "effects"), several = TRUE)
  o <- x$overall
  line <- sprintf(
    "Change %+.4f = rates %+.4f + mix %+.4f",
    o$change,
    o$rateeff,
    o$mixeff
  )
  op0 <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(op0), add = TRUE)
  draw <- list(rates = .jx_cd_rates, mix = .jx_cd_mix, effects = .jx_cd_effects)
  if (length(what) > 1L) {
    .bl_panels_begin(length(what))
    on.exit(.bl_panels_abort(), add = TRUE)
    for (w in what) {
      draw[[w]](x, cols, NULL, ...)
    }
    keys <- .bl_panels_end()
    .jx_cd_outer_text(line, keys, what, main)
  } else {
    .jx_cd_single(x, what, cols, main, line, draw, ...)
  }
  invisible(x$groups)
}

#' Counts as numbers: finite, non-negative, one per period
#' @param x The counts passed by the user.
#' @param what The argument's name, quoted when the counts are not one a period.
#' @param n The number of periods, or NULL for any length.
#' @param allow_na Whether missing values are accepted.
#' @return A double vector.
#' @noRd
.jx_counts <- function(x, what, n = NULL, allow_na = FALSE) {
  x <- .rmbl_num_input(x, what, allow_null = FALSE)
  if (!is.null(n) && length(x) != n) {
    stop(
      sprintf(
        "`%s` must have %d value%s (one per period), got %d",
        what,
        n,
        if (n == 1L) "" else "s",
        length(x)
      ),
      call. = FALSE
    )
  }
  if (!allow_na && anyNA(x)) {
    stop(sprintf("`%s` has missing values", what), call. = FALSE)
  }
  ok <- x[!is.na(x)]
  if (!all(is.finite(ok)) || any(ok < 0)) {
    stop(
      .rmbl_fn(),
      sprintf("`%s` must be finite, non-negative counts", what),
      call. = FALSE
    )
  }
  x
}

#' Computes the exact conditional confidence interval for the ratio of two
#' Poisson counts.
#'
#' The exact conditional interval for the ratio a / b of two Poisson counts over
#' the same exposure: given a + b, a is binomial with p = r / (1 + r), and the
#' Clopper-Pearson limits for p map to r = p / (1 - p).
#' @param a The numerator counts.
#' @param b The denominator counts.
#' @param conf_level The confidence level of the exact interval.
#' @return A list with `lower` and `upper`; NA where both counts are 0 or
#'   missing.
#' @noRd
.jx_ratio_ci <- function(a, b, conf_level) {
  conf_level <- .rmbl_conf_level(conf_level)
  alpha <- 1 - conf_level
  lo <- ifelse(a == 0, 0, stats::qbeta(alpha / 2, a, b + 1))
  hi <- ifelse(b == 0, 1, stats::qbeta(1 - alpha / 2, a + 1, b))
  bad <- is.na(a) | is.na(b) | (a + b) == 0
  lo[bad] <- NA_real_
  hi[bad] <- NA_real_
  list(lower = lo / (1 - lo), upper = ifelse(hi >= 1, Inf, hi / (1 - hi)))
}

#' Checks the period labels, or numbers the periods 1 to `n` when there are
#' none.
#' @param period The labels passed by the user, or NULL.
#' @param n The number of periods `period` must label, or numbered 1 to `n`.
#' @return The period labels.
#' @noRd
.jx_period <- function(period, n) {
  if (is.null(period)) {
    return(seq_len(n))
  }
  if (length(period) != n) {
    stop(
      sprintf("`period` must have %d values, got %d", n, length(period)),
      call. = FALSE
    )
  }
  if (anyNA(period)) {
    stop("`period` has missing values", call. = FALSE)
  }
  if (anyDuplicated(period)) {
    stop("`period` has repeated values; give one row per period", call. = FALSE)
  }
  period
}

#' X positions for periods: numbers as they are, dates as dates,
#' \code{"YYYY-MM"} as month starts, anything else in the order given
#' @param p The period labels.
#' @return The x positions: numbers or dates.
#' @noRd
.jx_period_x <- function(p) {
  if (is.numeric(p) || inherits(p, "Date")) {
    return(p)
  }
  p <- as.character(p)
  if (all(grepl("^[0-9]{4}-[0-9]{2}$", p))) {
    return(as.Date(paste0(p, "-01")))
  }
  if (all(grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", p))) {
    return(as.Date(p))
  }
  seq_along(p)
}

#' Court and police data shipped with the package
#'
#' Small excerpts of published court and police statistics, in
#' \code{inst/extdata}, used by the examples, tests and the
#' \code{courts-and-crime} vignette. Each is a faithful copy of published
#' numbers (no value altered, no row invented); the full tables, every
#' edition and location, are on the package's data hub
#' (\code{\link{dload}}, collections \code{ocj_statistics}
#' and \code{tps_open_data}).
#'
#' \describe{
#' \item{\code{ocj_flow_ontario.csv}}{Ontario Court of Justice, criminal
#'   clearance-rate statistics, province-wide, monthly from April 2024 to
#'   March 2026 (the 2026 edition): \code{month}, cases \code{received},
#'   cases \code{disposed}, cases \code{pending} (net of bench warrants).}
#' \item{\code{ocj_time_to_disposition.csv}}{The same months from the
#'   disposition-rate statistics: the shares of cases disposed in under 10
#'   months, 10-15, 15-18 and over 18 months (cases without bench
#'   warrants), and the average days to disposition.}
#' \item{\code{ocj_dispositions.csv}}{Province-wide criminal cases
#'   disposed by how they ended, one row per calendar year 2012-2019,
#'   2021, 2022, 2024 and 2025; each row adds to the year's published
#'   total. The 2020 edition covers October to September and the 2026
#'   edition April to March; the 2023 edition publishes no Toronto figures,
#'   so it has no province-wide row.}
#' \item{\code{ocj_offence_groups.csv}}{The same years by offence group:
#'   cases received and disposed. The groups add to each year's
#'   province-wide total.}
#' \item{\code{ocj_courts.csv}}{The same years by court, with
#'   \code{court_series}, which names Toronto's courthouses \code{"Toronto"}
#'   throughout: from 2023 the Court publishes Toronto as one location (the
#'   new Toronto courthouse consolidated its criminal courts that year).
#'   Each year's courts add to the province-wide total.}
#' \item{\code{tps_break_enter_d14_2024.csv}}{Toronto Police Service
#'   Break and Enter open data, every break and enter that occurred in
#'   2024 in division D14, one row per occurrence (508): \code{event_id},
#'   occurrence date, premises type, the published longitude and
#'   latitude (which the Service offsets to the nearest intersection),
#'   and \code{offence_records}, the number of offence records the
#'   Service publishes for the occurrence (five have two). The source package
#'   builds it with the script \code{tps_break_enter_d14_2024.R} in its
#'   \code{data-raw} folder.}
#' }
#'
#' @source Ontario Court of Justice, court statistics,
#'   ontariocourts.ca/ocj/statistics (retrieved
#'   2026-10-13), editions 2012 to 2026, published by the Court for
#'   public use. Toronto Police Service, Public Safety Data Portal,
#'   dataset \dQuote{Break and Enter Open Data}, data.tps.ca
#'   (retrieved 2026-10-13); contains information licensed under the
#'   Open Government Licence - Toronto Police Service. See
#'   \code{inst/COPYRIGHTS}.
#' @return No R object: each file is a CSV in \code{inst/extdata}. Read one
#'   into a data frame with \code{read.csv()} on the path that
#'   \code{system.file("extdata", <file>, package = "rmoriebricklayer")} gives.
#' @name justice-data
#' @seealso \code{\link{caseflow}}, \code{\link{lifetbl}},
#'   \code{\link{dispmix}}, \code{\link{clrdcmp}},
#'   \code{\link{crmdens}}, \code{\link{knoxtst}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' f <- read.csv(system.file("extdata", "ocj_flow_ontario.csv",
#'                           package = "rmoriebricklayer"))
#' head(f)
#' c <- read.csv(system.file("extdata", "ocj_courts.csv",
#'                           package = "rmoriebricklayer"))
#' tapply(c$disposed, c$year, sum)
NULL

#' Fill between two series in two colours by sign, splitting segments where they
#' cross
#' @param x The x positions.
#' @param a The first series.
#' @param b The second series.
#' @param col_pos The colour where `a` is above `b`.
#' @param col_neg The colour where `a` is below `b`.
#' @return NULL, invisibly.
#' @noRd
.jx_fill_between <- function(x, a, b, col_pos, col_neg) {
  x <- as.numeric(x)
  for (i in seq_len(length(x) - 1L)) {
    d1 <- a[i] - b[i]
    d2 <- a[i + 1L] - b[i + 1L]
    if (d1 * d2 < 0) {
      f <- d1 / (d1 - d2)
      xc <- x[i] + f * (x[i + 1L] - x[i])
      yc <- a[i] + f * (a[i + 1L] - a[i])
      graphics::polygon(
        c(x[i], xc, x[i]),
        c(a[i], yc, b[i]),
        border = NA,
        col = if (d1 > 0) col_pos else col_neg
      )
      graphics::polygon(
        c(xc, x[i + 1L], x[i + 1L]),
        c(yc, a[i + 1L], b[i + 1L]),
        border = NA,
        col = if (d2 > 0) col_pos else col_neg
      )
    } else {
      graphics::polygon(
        c(x[i], x[i + 1L], x[i + 1L], x[i]),
        c(a[i], a[i + 1L], b[i + 1L], b[i]),
        border = NA,
        col = if (d1 + d2 >= 0) col_pos else col_neg
      )
    }
  }
  invisible(NULL)
}

#' Draws the x axis, as dates when the periods are dates.
#' @param px The x positions.
#' @return What the axis function returns.
#' @noRd
.jx_xaxis <- function(px) {
  if (inherits(px, "Date")) graphics::axis.Date(1, px) else graphics::axis(1)
}

# ---- where incidents cluster: kernel density ---------------------------------

.jx_earth_km <- 6371.0088

#' lon/lat to kilometres on a plane through their centre (equirectangular):
#' within a city the distortion is far below the bandwidth
#' @param lon The longitudes.
#' @param lat The latitudes.
#' @param lon0 The centre's longitude.
#' @param lat0 The centre's latitude.
#' @return A list with the coordinates `x` and `y` in kilometres.
#' @noRd
.jx_project <- function(lon, lat, lon0, lat0) {
  list(
    x = .jx_earth_km * (lon - lon0) * pi / 180 * cos(lat0 * pi / 180),
    y = .jx_earth_km * (lat - lat0) * pi / 180
  )
}

#' Puts longitudes and latitudes on a plane in kilometres.
#'
#' The one way crmdens(), knoxtst() and hotpers() put longitudes and latitudes
#' on the plane: points across the antimeridian are taken on one side of it (179
#' and -179 degrees were 358 degrees apart, a 19,240 km bandwidth; review of
#' e57fed5), the centre is the median, and an extent past 2,000 km, where the
#' flat approximation stops being one, is said. Returns the projection
#' (kilometres), the centre and the longitudes as used.
#' @param lon The longitudes.
#' @param lat The latitudes.
#' @param caller The calling function's name, used in the warning.
#' @return A list with `x`, `y`, the centre `lon0` and `lat0`, and the
#'   longitudes `lon` as used.
#' @noRd
.jx_lonlat_plane <- function(lon, lat, caller) {
  if (length(lon) && diff(range(lon)) > 180) {
    alt <- ifelse(lon < 0, lon + 360, lon)
    if (diff(range(alt)) < diff(range(lon))) lon <- alt
  }
  lon0 <- stats::median(lon)
  lat0 <- stats::median(lat)
  p <- .jx_project(lon, lat, lon0, lat0)
  span <- max(diff(range(p$x)), diff(range(p$y)))
  if (span > 2000) {
    warning(
      sprintf(
        paste(
          "%s(): the incidents span %.0f km; distances are taken on a",
          "flat map through their",
          "centre, which is accurate for a city or a region, not across",
          "a continent"
        ),
        caller,
        span
      ),
      call. = FALSE
    )
  }
  list(
    x = p$x,
    y = p$y,
    lon0 = ((lon0 + 180) %% 360) - 180,
    lat0 = lat0,
    lon = lon
  )
}

#' Marks the points at (0, 0).
#'
#' (0, 0) is how raw police exports write \dQuote{no location}: no incident is
#' placed in the Gulf of Guinea
#' @param lon The longitudes.
#' @param lat The latitudes.
#' @return A logical vector.
#' @noRd
.jx_null_island <- function(lon, lat) {
  is.finite(lon) & is.finite(lat) & lon == 0 & lat == 0
}

#' Linear binning (each point shares its weight among the four nearest grid
#' nodes)
#' @param x The x coordinates.
#' @param y The y coordinates.
#' @param w The points' weights, shared among the four nearest grid nodes.
#' @param gx The grid's x nodes, equally spaced.
#' @param gy The grid's y nodes, equally spaced.
#' @return A matrix of binned weights, one row per x node.
#' @noRd
.jx_linbin <- function(x, y, w, gx, gy) {
  nx <- length(gx)
  ny <- length(gy)
  dx <- gx[2L] - gx[1L]
  dy <- gy[2L] - gy[1L]
  fx <- (x - gx[1L]) / dx
  fy <- (y - gy[1L]) / dy
  ix <- pmin(pmax(floor(fx), 0), nx - 2)
  iy <- pmin(pmax(floor(fy), 0), ny - 2)
  ax <- fx - ix
  ay <- fy - iy
  acc <- new.env(parent = emptyenv())
  acc$m <- numeric(nx * ny)
  add <- function(i, j, v) {
    s <- tapply(v, i + 1 + j * nx, sum)
    k <- as.integer(names(s))
    acc$m[k] <- acc$m[k] + s
  }
  add(ix, iy, w * (1 - ax) * (1 - ay))
  add(ix + 1, iy, w * ax * (1 - ay))
  add(ix, iy + 1, w * (1 - ax) * ay)
  add(ix + 1, iy + 1, w * ax * ay)
  matrix(acc$m, nx, ny)
}

#' crmdens()'s located incidents in degrees: a coordinate outside the
#' degree ranges refused, (0, 0) dropped.
#' @param lon,lat The coordinates.
#' @param keep The incidents kept so far.
#' @return The incidents kept.
#' @noRd
.cd_keep_lonlat <- function(lon, lat, keep) {
  bad <- keep & (abs(lat) > 90 | abs(lon) > 180)
  if (any(bad)) {
    stop(
      sprintf(
        paste(
          "coordinate %d is not a longitude and latitude in degrees",
          "(%g, %g);",
          "planar data take coords = \"planar\""
        ),
        which(bad)[1L],
        lon[bad][1L],
        lat[bad][1L]
      ),
      call. = FALSE
    )
  }
  keep & !.jx_null_island(lon, lat)
}

#' crmdens()'s grid size and coverage shares, checked.
#' @param ngrid,cover As for crmdens().
#' @return The grid size, a whole number.
#' @noRd
.cd_check_grid <- function(ngrid, cover) {
  ngrid <- .rmbl_num(ngrid, "ngrid", integer = TRUE)
  if (length(ngrid) != 1L || is.na(ngrid) || ngrid < 10L || ngrid > 2000L) {
    stop("`ngrid` must be a whole number from 10 to 2000", call. = FALSE)
  }
  cover <- .rmbl_num_input(cover, "cover", allow_null = FALSE)
  if (!length(cover) || anyNA(cover) || any(cover <= 0 | cover >= 1)) {
    stop("`cover` must be shares strictly between 0 and 1", call. = FALSE)
  }
  ngrid
}

#' crmdens()'s bandwidth: the one given, checked, or Scott's rule from the
#' incidents' weighted spread.
#' @param bw As for crmdens().
#' @param p The incidents on the plane (km).
#' @param .w Their weights.
#' @param xy The coordinates' kind.
#' @return The two bandwidths.
#' @noRd
.cd_bandwidth <- function(bw, p, .w, xy) {
  n <- length(p$x)
  if (is.null(bw)) {
    sx <- sqrt(stats::cov.wt(cbind(p$x, p$y), wt = .w / sum(.w))$cov[c(1L, 4L)])
    h <- sx * n^(-1 / 6)
    if (any(!is.finite(h) | h <= 0)) {
      stop(
        "the incidents do not spread in both directions; give `bw` in ",
        "kilometres",
        call. = FALSE
      )
    }
    return(h)
  }
  h <- .rmbl_num_input(bw, "bw", allow_null = FALSE)
  if (!length(h) %in% 1:2 || any(!is.finite(h) | h <= 0)) {
    stop(
      "`bw` must be one or two positive numbers (kilometres)",
      call. = FALSE
    )
  }
  h <- rep_len(h, 2L)
  # a bandwidth past half the earth's circumference is not a distance on a
  # map; one far wider than the incidents' spread smooths them into a single
  # blur (1e6 km was taken silently)
  if (xy == "lonlat" && any(h > 20037.5)) {
    stop(
      "`bw` is longer than half the earth's circumference (20,037 km)",
      call. = FALSE
    )
  }
  spread <- max(diff(range(p$x)), diff(range(p$y)))
  if (spread > 0 && any(h > 10 * spread)) {
    warning(
      sprintf(
        paste0(
          "`bw` (%.3g km) is over ten times the incidents' spread (%.3g ",
          "km): the map is one blur"
        ),
        max(h),
        spread
      ),
      call. = FALSE
    )
  }
  h
}

#' crmdens()'s grid and incidents in longitude and latitude.
#' @param out The density.
#' @param p The plane's projection.
#' @param lat0 Its centre's latitude.
#' @param lat The incidents' latitudes.
#' @return The density with lon and lat.
#' @noRd
.cd_lonlat_grid <- function(out, p, lat0, lat) {
  out$lon <- p$lon0 + out$x / (.jx_earth_km * cos(lat0 * pi / 180)) * 180 / pi
  # the grid is drawn with image(), which needs increasing longitudes: a grid
  # that runs past 180 degrees (incidents near the antimeridian, 179.5 to
  # 179.99) is wrapped only when every node ends up on one side; otherwise the
  # nodes past 180 keep their continued values (180.3 is -179.7) and the map
  # stays one piece (review of 29a55d8, F4)
  wrapped <- ((out$lon + 180) %% 360) - 180
  wrap <- !is.unsorted(wrapped, strictly = TRUE)
  if (wrap) {
    out$lon <- wrapped
  }
  out$lat <- lat0 + out$y / .jx_earth_km * 180 / pi
  # the incidents in the grid's own frame (the same transform as the grid's
  # nodes), so a map that runs past 180 degrees keeps its points on it (30 of
  # 60 fell off; review of 46de6a9, F4)
  plon <- p$lon0 + p$x / (.jx_earth_km * cos(lat0 * pi / 180)) * 180 / pi
  out$points$lon <- if (wrap) ((plon + 180) %% 360) - 180 else plon
  out$points$lat <- lat
  out
}

#' The y title of the Knox table sits outside its band labels, which are text,
#' not axTicks()
#' @param labels The band labels drawn on the y axis.
#' @return What `graphics::title()` returns.
#' @noRd
.bl_knox_ylab <- function(labels) {
  o <- graphics::par(c("cex.axis", "csi", "mar", "mgp"))
  w <- max(.bl_strwidth(labels, cex = o$cex.axis), 0)
  graphics::title(
    ylab = "Metres apart",
    line = max(min(o$mgp[2L] + w / o$csi + 0.7, o$mar[2L] - 1), 0.2)
  )
}

# ---- near repeats: the Knox test ---------------------------------------------

#' Chooses a grid origin that a far outlier cannot shift.
#'
#' The grid's origin: the smallest coordinate of the points within 2^52 cells of
#' the median. The smallest of all let one point at -1e300 shift every other one
#' to 1e300, where they all fell into one cell (the counts were wiped out; the
#' mirror of the +1e300 point, CRAN stress test of b617a3f). With no such
#' outlier it is min(v), as before; an outlier is then a far point, compared
#' directly.
#' @param v The coordinates.
#' @param unit The cell side.
#' @return The origin.
#' @noRd
.jx_origin <- function(v, unit) {
  med <- stats::median(v)
  inl <- abs(v - med) / unit <= 2^52
  if (any(inl)) min(v[inl]) else med
}

#' Pairs closer than `r`: points hashed to cells of side r, each cell compared
#' with itself and four of its neighbours, so every close pair is found once
#' @param x The x coordinates.
#' @param y The y coordinates.
#' @param r The distance.
#' @param max_pairs The largest number of direct comparisons allowed for points
#'   too far out to index.
#' @return A list with the indices `i` and `j` of each pair and their distance
#'   `d`.
#' @noRd
.jx_close_pairs <- function(x, y, r, max_pairs) {
  # distances do not move when the coordinates are shifted, and the cell indices
  # shrink
  x <- x - .jx_origin(x, r)
  y <- y - .jx_origin(y, r)
  cx <- floor(x / r)
  cy <- floor(y / r)
  # past 2^52 a cell index is not a whole number with room beside it, so
  # neighbouring cells merge or skip (x = 1e12 with a band of 1e-6 overcounted;
  # review of 46de6a9). Those points are compared with every other one directly;
  # one far outlier, or a band so small that every index overflows, refused the
  # whole test before (statistics stress test of 5e1dce5)
  far <- !is.finite(cx) | !is.finite(cy) | abs(cx) >= 2^52 | abs(cy) >= 2^52
  near <- which(!far)
  # within the band, in units of the band: r * r underflows for a band of 1e-300
  within <- function(i, j) ((x[i] - x[j]) / r)^2 + ((y[i] - y[j]) / r)^2 <= 1
  fp <- if (any(far)) {
    .jx_far_pairs(far, length(x), within, max_pairs)
  } else {
    list(out_i = list(), out_j = list(), total = 0)
  }
  total <- fp$total
  out_i <- fp$out_i
  out_j <- fp$out_j
  # whole numbers written out in full: paste() writes 1e15 and 1e15 + 1 both as
  # "1e+15", one cell
  key <- function(a, b) sprintf("%.0f %.0f", a, b)
  pts <- data.frame(i = near, k = key(cx[near], cy[near]))
  for (off in list(c(0, 0), c(1, -1), c(1, 0), c(1, 1), c(0, 1))) {
    nb <- data.frame(j = near, k = key(cx[near] - off[1L], cy[near] - off[2L]))
    # sizes first, so a dense cell is refused before memory is spent on it
    a <- table(pts$k)
    b <- table(nb$k)
    common <- intersect(names(a), names(b))
    total <- total + sum(as.numeric(a[common]) * as.numeric(b[common]))
    if (total > max_pairs) {
      .jx_too_many_pairs(max_pairs)
    }
    m <- merge(pts, nb, by = "k")
    if (all(off == 0)) {
      m <- m[m$i < m$j, ]
    }
    sel <- within(m$i, m$j)
    out_i[[length(out_i) + 1L]] <- m$i[sel]
    out_j[[length(out_j) + 1L]] <- m$j[sel]
  }
  i <- unlist(out_i)
  j <- unlist(out_j)
  list(i = i, j = j, d = sqrt((x[i] - x[j])^2 + (y[i] - y[j])^2))
}

#' Pairs (over all n(n-1)/2) whose absolute difference is within each cut, from
#' sorted values
#' @param t The values.
#' @param cuts The cuts.
#' @return A count for each cut.
#' @noRd
.jx_pairs_within <- function(t, cuts) {
  t <- sort(t)
  vapply(
    cuts,
    function(b) sum(findInterval(t + b, t) - seq_along(t)),
    numeric(1)
  )
}

#' knoxtst()'s incidents: times in days, lengths checked, those without a
#' location or a time dropped.
#' @param x,y,time As for knoxtst().
#' @return A list: x, y and tt.
#' @noRd
.knox_points <- function(x, y, time) {
  tt <- if (inherits(time, "Date")) {
    as.numeric(time)
  } else if (inherits(time, "POSIXt")) {
    as.numeric(time) / 86400
  } else {
    .rmbl_num_input(time, "time", allow_null = FALSE)
  }
  if (length(y) != length(x) || length(tt) != length(x)) {
    stop("`x`, `y` and `time` must have the same length", call. = FALSE)
  }
  # an incident without a location or a time is dropped and said, as crmdens()
  # and hotpers() do (knoxtst() alone refused the whole call; review of 29a55d8)
  keep <- is.finite(x) & is.finite(y) & is.finite(tt)
  if (!all(keep)) {
    message(sprintf(
      "knoxtst(): %d incident%s without a usable location or time dropped",
      sum(!keep),
      if (sum(!keep) == 1L) "" else "s"
    ))
    x <- x[keep]
    y <- y[keep]
    tt <- tt[keep]
  }
  list(x = x, y = y, tt = tt)
}

#' A Knox test's distance or time bands, checked.
#' @param b The bands.
#' @param what Their argument's name.
#' @return The bands.
#' @noRd
.knox_bands <- function(b, what) {
  b <- .rmbl_num_input(b, what, allow_null = FALSE)
  if (
    !length(b) ||
      anyNA(b) ||
      !all(is.finite(b)) ||
      any(b <= 0) ||
      is.unsorted(b, strictly = TRUE)
  ) {
    stop(
      sprintf("`%s` must be positive, finite and increasing", what),
      call. = FALSE
    )
  }
  b
}

#' knoxtst()'s incidents in degrees: ranges checked, (0, 0) dropped.
#' @param x,y,tt The incidents.
#' @return A list: x, y and tt.
#' @noRd
.knox_lonlat <- function(x, y, tt) {
  if (any(abs(y) > 90 | abs(x) > 180)) {
    stop(
      "`x` and `y` are not longitudes and latitudes in degrees; ",
      "planar data take coords = \"planar\"",
      call. = FALSE
    )
  }
  # (0, 0) is "no location", as crmdens() and hotpers() read it: twenty such
  # rows had made the closest space-time cell 163 observed against 33 expected
  # (review of e57fed5, E3)
  nowhere <- .jx_null_island(x, y)
  if (any(nowhere)) {
    message(sprintf(
      paste0(
        "knoxtst(): %d incident%s at (0, 0), the raw exports' \"no ",
        "location\", dropped"
      ),
      sum(nowhere),
      if (sum(nowhere) == 1L) "" else "s"
    ))
    x <- x[!nowhere]
    y <- y[!nowhere]
    tt <- tt[!nowhere]
  }
  list(x = x, y = y, tt = tt)
}

#' Evaluates an expression under a seed when one is given.
#'
#' The seed is optional here, unlike .rmbl_with_seed()
#' @param seed The seed for `expr`, or NULL to run it on the session's stream.
#' @param expr The expression to evaluate, under `seed` when one is given.
#' @return The value of `expr`.
#' @noRd
.rmbl_with_seed_maybe <- function(seed, expr) {
  if (is.null(seed)) {
    return(expr)
  }
  # every seed the package takes, up to 2^53 - 1 (2^40 was refused here, and
  # -2^31 called too large; CRAN stress test of 0.5.14)
  .rmbl_with_seed(.rmbl_r_seed(seed), expr)
}

# ---- case mix: Simpson's paradox in an aggregate clearance rate --------------

#' clrdcmp()'s two comparison values, the base first when one is given.
#' @param cmp,base As for clrdcmp().
#' @return The two values.
#' @noRd
.clr_levels <- function(cmp, base) {
  levs <- sort(unique(cmp))
  if (length(levs) != 2L) {
    stop(
      sprintf(
        paste0(
          "`cmp` must have exactly two values (two periods or two ",
          "jurisdictions), got %d"
        ),
        length(levs)
      ),
      call. = FALSE
    )
  }
  if (!is.null(base)) {
    if (
      !is.atomic(base) ||
        is.complex(base) ||
        length(base) != 1L ||
        is.na(base) ||
        !as.character(base) %in% as.character(levs)
    ) {
      stop("`base` must be one of the two values of `cmp`", call. = FALSE)
    }
    # the level itself, in its own type
    base <- levs[match(as.character(base), as.character(levs))]
    levs <- c(base, setdiff(levs, base))
  }
  levs
}

#' clrdcmp()'s parts: each once per comparison, and in both.
#' @param grp,cmp As for clrdcmp().
#' @param key The part-comparison keys.
#' @param levs The two comparison values.
#' @noRd
.clr_check_parts <- function(grp, cmp, key, levs) {
  if (anyDuplicated(key)) {
    d <- which(duplicated(key))[1L]
    stop(
      sprintf(
        "part \"%s\" appears more than once in %s",
        grp[d],
        format(cmp[d])
      ),
      call. = FALSE
    )
  }
  ga <- grp[cmp == levs[1L]]
  gb <- grp[cmp == levs[2L]]
  miss <- c(setdiff(ga, gb), setdiff(gb, ga))
  if (length(miss)) {
    stop(
      sprintf(
        paste0(
          "part \"%s\" is in only one comparison; a rate change needs it in ",
          "both (merge or drop it first)"
        ),
        miss[1L]
      ),
      call. = FALSE
    )
  }
  invisible(NULL)
}

#' The crude and Mantel-Haenszel rate ratios, with intervals.
#' @param na,da,nb,db Each part's numerators and denominators in the two
#'   comparisons.
#' @param conflvl The confidence level of the crude and Mantel-Haenszel CIs.
#' @return A data frame.
#' @noRd
.clr_rate_ratio <- function(na, da, nb, db, conflvl) {
  # Mantel-Haenszel rate ratio for person-time data, Greenland-Robins variance
  # of its log
  tt <- da + db
  sa <- sum(nb * da / tt)
  sb <- sum(na * db / tt)
  z <- stats::qnorm(1 - (1 - conflvl) / 2)
  mh <- sa / sb
  v <- sum((na + nb) * da * db / tt^2) / (sa * sb)
  cci <- .jx_ratio_ci(sum(nb), sum(na), conflvl)
  data.frame(
    estimate = c("crude", "mantel_haenszel"),
    ratio = c((sum(nb) / sum(db)) / (sum(na) / sum(da)), mh),
    lower = c(cci$lower * sum(da) / sum(db), mh * exp(-z * sqrt(v))),
    upper = c(cci$upper * sum(da) / sum(db), mh * exp(z * sqrt(v))),
    p_value = c(NA_real_, 2 * stats::pnorm(-abs(log(mh)) / sqrt(v))),
    stringsAsFactors = FALSE
  )
}

#' The kind of Simpson's paradox in a decomposition: full (every part moved
#' against the total), mix (the rate effect against the total) or none.
#' @param overall The overall row.
#' @param up,down The parts whose rate rose and fell.
#' @param k The number of parts.
#' @return The kind.
#' @noRd
.clr_simpson <- function(overall, up, down, k) {
  ch <- overall$change
  if (ch != 0 && ((up == k && ch < 0) || (down == k && ch > 0))) {
    "full"
  } else if (
    ch != 0 && overall$rateeff != 0 && sign(ch) != sign(overall$rateeff)
  ) {
    "mix"
  } else {
    "none"
  }
}

#' Prepares the parts of a clearance decomposition for drawing.
#'
#' The parts as drawn: ordered by their average rate (lowest at the bottom), so
#' the colours of the mix panel separate; past `maxparts`, the parts that moved
#' the aggregate most, and the rest summed into one row (its rate from the
#' summed counts, not an average of rates).
#' @param x A `rmbl_clearance_decomposition` object.
#' @param max_parts The most parts drawn; the rest are summed into one row.
#' @return A list with the parts to draw, `groups`, and the number summed into
#'   the last row, `other`.
#' @noRd
.jx_cd_view <- function(x, max_parts) {
  g <- x$groups
  other <- 0L
  if (nrow(g) > max_parts) {
    keep <- order(-(abs(g$rateeff) + abs(g$mixeff)))[seq_len(max_parts - 1L)]
    rest <- g[-keep, , drop = FALSE]
    agg <- g[keep[1L], , drop = FALSE]
    agg$group <- sprintf("Other parts (%d)", nrow(rest))
    for (v in c(
      "numa",
      "dena",
      "numb",
      "denb",
      "weia",
      "weib",
      "rateeff",
      "mixeff"
    )) {
      agg[[v]] <- sum(rest[[v]])
    }
    agg$ratea <- agg$numa / agg$dena
    agg$rateb <- agg$numb / agg$denb
    agg$rateratio <- agg$rateb / agg$ratea
    agg$lower <- NA_real_
    agg$upper <- NA_real_
    g <- rbind(g[keep, , drop = FALSE], agg)
    other <- nrow(rest)
  }
  g <- g[order((g$ratea + g$rateb) / 2), , drop = FALSE]
  rownames(g) <- NULL
  list(groups = g, other = other)
}

#' Fits the row labels of a panel to its margin and row height.
#'
#' Row labels for a panel of `units` rows, chosen before the plot so the margin
#' fits them: two lines when the rows are tall enough, else one (cut with an
#' ellipsis only past the room), and a text size the row height allows.
#' @param labs The panel's row labels, wrapped or shrunk to fit the row height.
#' @param units The number of rows the panel holds.
#' @return A list with `labels`, the margin `mar` in lines and the text size
#'   `cex`.
#' @noRd
.jx_row_labels <- function(labs, units) {
  fin <- tryCatch(graphics::par("fin"), error = function(e) c(7, 7))
  csi <- tryCatch(graphics::par("cin")[2L], error = function(e) 0.2) *
    .bl_plot_opts()$cex
  # the plot's height is the figure less its margins (7.2 lines) and the panel
  # key's outer margin
  oma <- tryCatch(sum(graphics::par("oma")[c(1L, 3L)]), error = function(e) 0)
  rowh <- max(fin[2L] - (7.2 + oma) * csi, csi) / units
  fit <- .bl_label_wrap(labs)
  two <- any(grepl("\n", fit$labels, fixed = TRUE))
  if (two && 2 * csi * 0.9 > rowh) {
    # rows too short for two lines: the whole name a size smaller reads better
    # than a cut one; cut (with an ellipsis) only when even 0.7 of the size does
    # not fit the room
    room <- 0.5 *
      tryCatch(graphics::par("fin")[1L], error = function(e) 7) -
      csi
    w <- max(.bl_strwidth(labs, cex = 1), 0)
    sizes <- c(0.85, 0.75, 0.65, 0.6)
    shrink <- sizes[w * sizes <= room]
    if (length(shrink)) {
      fit <- list(
        labels = labs,
        mar = max(1, w * shrink[1L] / csi + 1) / shrink[1L]
      )
      fit$cex <- min(shrink[1L], max(0.45, rowh / (csi * 0.9)))
      return(fit)
    }
    fit <- .bl_label_fit(labs)
    two <- FALSE
  }
  fit$cex <- max(0.45, min(1, rowh / ((if (two) 2 else 1) * csi * 0.9)))
  fit
}

#' Arrows only where they are long enough to have a direction (a part that
#' barely moved gets its two points and no arrow: R warns about a zero-length
#' arrow and draws nothing)
#' @param x0 The start positions.
#' @param y The rows.
#' @param x1 The end positions.
#' @param col The colours.
#' @param lwd The line widths.
#' @return NULL, invisibly when no arrow is drawn.
#' @noRd
.jx_arrows <- function(x0, y, x1, col, lwd) {
  usr <- graphics::par("usr")
  len <- abs(x1 - x0) / diff(usr[1:2]) * graphics::par("pin")[1L]
  ok <- is.finite(len) & len > 0.02
  if (any(ok)) {
    graphics::arrows(
      x0[ok],
      y[ok],
      x1[ok],
      y[ok],
      length = 0.06,
      col = col[ok],
      lwd = lwd[ok]
    )
  }
}

#' Draws the rates panel of a clearance decomposition.
#'
#' Each part's rate in both comparisons, the aggregate on top; an arrow per
#' part, coloured by direction, so a reversal reads as every arrow pointing one
#' way and the top one the other
#' @param x A `rmbl_clearance_decomposition` object, as prepared by
#'   `.jx_cd_view()`.
#' @param cols The two colours: rate up, rate down.
#' @param main The rates panel's title, or NULL for the default.
#' @param ... Passed to `graphics::plot()` for the rates panel.
#' @return NULL, invisibly.
#' @noRd
.jx_cd_rates <- function(x, cols, main, ...) {
  g <- x$groups
  o <- x$overall
  a <- format(x$compare[1L])
  b <- format(x$compare[2L])
  labs <- c(as.character(g$group), "All parts")
  k <- nrow(g)
  y <- c(seq_len(k), k + 1.6)
  ra <- c(g$ratea, o$ratea)
  rb <- c(g$rateb, o$rateb)
  # the panel's text size first: a panel grid lowers par("cex"), and labels
  # measured at the lowered size and drawn at this one ran off the device
  o0 <- .bl_plot_opts()
  op <- .jx_cd_par(o0)
  on.exit(graphics::par(op), add = TRUE)
  fit <- .jx_row_labels(labs, k + 2.6)
  graphics::par(
    mar = .bl_safe_mar(c(4.2, fit$mar * fit$cex + 0.8, 3, 1), o0$cex)
  )
  graphics::plot(
    range(c(ra, rb)),
    range(y) + c(-0.5, 0.5),
    type = "n",
    yaxt = "n",
    xlab = "",
    ylab = "",
    main = "",
    ...
  )
  graphics::axis(2, at = y, labels = FALSE)
  # every row labelled (axis() drops labels that would touch)
  .jx_cd_row_text(y, fit)
  .bl_xlab("Clearance rate")
  title <- sprintf("Rates, %s to %s", a, b)
  if (isTRUE(x$other > 0L)) {
    title <- sprintf("%s, top %d", title, k - 1L)
  }
  .bl_title(.bl_main(main, title))
  .bl_grid(NULL, side = "x")
  graphics::abline(h = k + 0.8, col = "#9AA0AA", lwd = 1.5)
  graphics::abline(v = 1, lty = 3, col = "#888888")
  dir <- ifelse(rb >= ra, cols[1L], cols[2L])
  .jx_arrows(ra, y, rb, dir, c(rep(2, k), 3.5))
  .jx_cd_points(ra, rb, y, dir)
  invisible(NULL)
}

#' Draws the case-mix panel of a clearance decomposition.
#'
#' Each part's share of the workload in both comparisons, coloured by whether it
#' clears above or below the average: the mix that can turn the aggregate
#' against its parts
#' @param x A `rmbl_clearance_decomposition` object, as prepared by
#'   `.jx_cd_view()`.
#' @param cols The two colours: above and below the average rate.
#' @param main The case-mix panel's title, or NULL for the default.
#' @param ... Passed to `graphics::plot()` for the case-mix panel.
#' @return NULL, invisibly.
#' @noRd
.jx_cd_mix <- function(x, cols, main, ...) {
  g <- x$groups
  o <- x$overall
  a <- format(x$compare[1L])
  b <- format(x$compare[2L])
  k <- nrow(g)
  y <- seq_len(k)
  wa <- g$weia
  wb <- g$weib
  centre <- (o$ratea + o$rateb) / 2
  colr <- ifelse((g$ratea + g$rateb) / 2 >= centre, cols[1L], cols[2L])
  o0 <- .bl_plot_opts()
  op <- .jx_cd_par(o0)
  on.exit(graphics::par(op), add = TRUE)
  fit <- .jx_row_labels(as.character(g$group), k + 1)
  graphics::par(
    mar = .bl_safe_mar(c(4.2, fit$mar * fit$cex + 0.8, 3, 1), o0$cex)
  )
  graphics::plot(
    range(c(0, wa, wb)),
    c(0.5, k + 0.5),
    type = "n",
    yaxt = "n",
    xlab = "",
    ylab = "",
    main = "",
    ...
  )
  graphics::axis(2, at = y, labels = FALSE)
  .jx_cd_row_text(y, fit)
  .bl_xlab("Share of workload")
  .bl_title(.bl_main(main, "Where the work moved"))
  .bl_grid(NULL, side = "x")
  .jx_arrows(wa, y, wb, colr, rep(2, k))
  .jx_cd_points(wa, wb, y, colr)
  .jx_cd_mix_key()
  invisible(NULL)
}

#' The change in the aggregate as a waterfall: rate effect, then mix effect,
#' then the total
#' @param x A `rmbl_clearance_decomposition` object.
#' @param cols The two colours: a gain and a loss.
#' @param main The waterfall's title, or NULL for the default.
#' @param ... Passed to `graphics::plot()` for the waterfall.
#' @return NULL, invisibly.
#' @noRd
.jx_cd_effects <- function(x, cols, main, ...) {
  o <- x$overall
  vals <- c(o$rateeff, o$mixeff)
  ends <- cumsum(c(0, vals))
  op <- .bl_par(c(ends, o$change))
  graphics::plot(
    c(0.4, 3.6),
    range(c(0, ends, o$change)) +
      c(-1, 1) * 0.05 * max(abs(c(ends, o$change)), 1e-12),
    type = "n",
    xaxt = "n",
    xlab = "",
    ylab = "",
    main = "",
    ...
  )
  .bl_ylab("Change in the clearance rate")
  # mtext, not axis(): axis() drops labels that would touch, and on a small
  # panel kept only one
  graphics::axis(1, at = 1:3, labels = FALSE)
  bar_cex <- .jx_cd_bar_labels()
  .bl_title(.bl_main(
    main,
    switch(
      x$simpson$type,
      full = "Reversal in every part",
      mix = "Reversed by the case mix",
      none = "Rate and mix effects"
    )
  ))
  .bl_grid(NULL)
  graphics::abline(h = 0, col = "#666666")
  .jx_cd_bars(ends, vals, o$change, cols)
  # each value at the far end of its own bar: above a gain, below a loss, so
  # neighbours never meet
  v3 <- c(vals, o$change)
  tip <- c(ends[2:3], o$change)
  graphics::text(
    1:3,
    tip,
    sprintf("%+.4f", v3),
    pos = ifelse(v3 >= 0, 3, 1),
    xpd = NA,
    cex = min(0.75, bar_cex)
  )
  graphics::par(op)
  invisible(NULL)
}

#' Rolling sums over a window of periods.
#' @param v The counts.
#' @param n The number of counts in `v`, the length of the result.
#' @param win The window.
#' @return The sums, NA before the first full window.
#' @noRd
.jx_roll <- function(v, n, win) {
  cs <- cumsum(v)
  out <- rep(NA_real_, n)
  if (n >= win) {
    out[win:n] <- cs[win:n] - c(0, cs)[seq_len(n - win + 1L)]
  }
  out
}

#' caseflow()'s pending columns, or the running net inflow without them.
#' @param out The case flow table.
#' @param pend,disp,win As for caseflow(), checked.
#' @return `out` with pending, penchg and pertoclear, or with cumnet.
#' @noRd
.jx_cf_pending <- function(out, pend, disp, win) {
  if (!is.null(pend)) {
    pace <- vapply(
      seq_along(disp),
      function(i) mean(disp[max(1L, i - win + 1L):i]),
      numeric(1)
    )
    out$pending <- pend
    out$penchg <- c(NA_real_, diff(pend))
    out$pertoclear <- ifelse(pace > 0, pend / pace, NA_real_)
  } else {
    out$cumnet <- cumsum(out$net)
  }
  out
}

#' print.rmbl_case_flow()'s notes: the overall clearance, and the backlog.
#' @param x The case flow table.
#' @param m Its summary attribute.
#' @return The notes.
#' @noRd
.jx_cf_notes <- function(x, m) {
  overall <- m$totaldis / m$totalrec
  ci <- .jx_ratio_ci(m$totaldis, m$totalrec, m$conflvl)
  notes <- sprintf(
    paste0(
      "Over all %d periods: %s received, %s disposed, clearance %.3f ",
      "(%.3f to %.3f)"
    ),
    nrow(x),
    format(m$totalrec, big.mark = ","),
    format(m$totaldis, big.mark = ","),
    overall,
    ci$lower,
    ci$upper
  )
  if (!is.null(x$pending)) {
    notes <- c(
      notes,
      sprintf(
        paste0(
          "Pending at the end: %s, about %.1f periods of disposition at ",
          "the last %d-period pace"
        ),
        format(utils::tail(x$pending, 1L), big.mark = ","),
        utils::tail(x$pertoclear, 1L),
        m$window
      )
    )
  }
  notes
}

#' plot.rmbl_case_flow()'s panel of cases received and disposed.
#' @param x The case flow table.
#' @param px The periods' positions.
#' @param cols The two colours.
#' @param main The received-and-disposed panel's title, or NULL.
#' @param ... Passed to plot() for the received-and-disposed panel.
#' @return NULL, invisibly.
#' @noRd
.jx_cf_flow <- function(x, px, cols, main, ...) {
  ys <- c(x$received, x$disposed)
  op <- .bl_par(ys)
  graphics::plot(
    px,
    x$received,
    type = "n",
    ylim = range(ys, finite = TRUE),
    xaxt = "n",
    xlab = "Period",
    ylab = "",
    main = "",
    ...
  )
  .bl_ylab("Cases")
  .jx_xaxis(px)
  .bl_title(.bl_main(
    main,
    if (all(graphics::par("pin") >= c(2.6, 1.8))) {
      "Cases received and disposed"
    } else {
      "Received (dashed) and disposed"
    }
  ))
  .bl_grid(NULL)
  # disposed above received (inventory falling) in the first colour, below
  # in the second
  .jx_fill_between(
    px,
    x$disposed,
    x$received,
    grDevices::adjustcolor(cols[1L], 0.25),
    grDevices::adjustcolor(cols[2L], 0.25)
  )
  graphics::lines(px, x$received, col = "#333333", lwd = 2, lty = 2)
  graphics::lines(
    px,
    x$disposed,
    col = grDevices::adjustcolor(cols[1L], 0.25),
    lwd = 6
  )
  graphics::lines(px, x$disposed, col = cols[1L], lwd = 2.2)
  .jx_cf_flow_key(cols)
  graphics::par(op)
  invisible(NULL)
}

#' The key of the received-and-disposed panel, on a panel large enough.
#' @param cols The two colours.
#' @return NULL, invisibly.
#' @noRd
.jx_cf_flow_key <- function(cols) {
  # a key over a panel smaller than about 2.6 by 1.8 inches hides the lines
  # it explains; the title says which line is which instead
  if (all(graphics::par("pin") >= c(2.6, 1.8))) {
    graphics::legend(
      "bottomleft",
      c("received", "disposed", "inventory fell", "inventory grew"),
      col = c("#333333", cols[1L], NA, NA),
      lty = c(2, 1, NA, NA),
      lwd = 2,
      fill = c(
        NA,
        NA,
        grDevices::adjustcolor(cols[1L], 0.25),
        grDevices::adjustcolor(cols[2L], 0.25)
      ),
      border = NA,
      bty = "n",
      cex = 0.75
    )
  }
  invisible(NULL)
}

#' plot.rmbl_case_flow()'s panel of the clearance rate.
#' @param x The case flow table.
#' @param px The periods' positions.
#' @param cols The two colours.
#' @param main The clearance-rate panel's title, or NULL.
#' @param ... Passed to plot() for the clearance-rate panel.
#' @return NULL, invisibly.
#' @noRd
.jx_cf_clearance <- function(x, px, cols, main, ...) {
  ys <- c(x$lower, x$upper, x$clearance, 1)
  op <- .bl_par(ys)
  graphics::plot(
    px,
    x$clearance,
    type = "n",
    ylim = range(ys, finite = TRUE),
    xaxt = "n",
    xlab = "Period",
    ylab = "",
    main = "",
    ...
  )
  .bl_ylab("Disposed per case received")
  .jx_xaxis(px)
  .bl_title(.bl_main(
    main,
    "Clearance rate"
  ))
  .bl_grid(NULL)
  ok <- is.finite(x$lower) & is.finite(x$upper)
  if (any(ok)) {
    graphics::polygon(
      c(px[ok], rev(px[ok])),
      c(x$lower[ok], rev(x$upper[ok])),
      border = NA,
      col = grDevices::adjustcolor(cols[1L], 0.2)
    )
  }
  graphics::abline(h = 1, lty = 2, col = "#666666")
  graphics::lines(px, x$clearance, col = cols[1L], lwd = 1.5)
  graphics::points(
    px,
    x$clearance,
    pch = 21,
    bg = cols[1L],
    col = "white",
    lwd = 0.8,
    cex = 0.9
  )
  if (any(is.finite(x$rolclr))) {
    graphics::lines(px, x$rolclr, col = cols[2L], lwd = 2.5)
  }
  graphics::par(op)
  invisible(NULL)
}

#' lifetbl()'s band edges, from band labels or from numeric breaks.
#' @param breaks As for lifetbl().
#' @return A list: lo and hi, the bands' lower and upper edges.
#' @noRd
.jx_lt_bands <- function(breaks) {
  if (is.character(breaks) || is.factor(breaks)) {
    # times, not head counts: "Under 10" ends at 10, and "Over 18" starts there
    b <- prsbands(as.character(breaks), intsca = FALSE)
    lo <- b$lower
    # an open first band ("Under 10") starts at the time origin
    if (isTRUE(b$openlo[1L]) && is.na(lo[1L])) {
      lo[1L] <- 0
    }
    bad <- is.na(lo) | (is.na(b$upper) & !b$openup)
    if (any(bad)) {
      stop(
        sprintf("could not read the band \"%s\"", b$label[bad][1L]),
        call. = FALSE
      )
    }
    if (any(utils::head(b$openup, -1L))) {
      stop("only the last band may be open (\"Over ...\")", call. = FALSE)
    }
    hi <- ifelse(is.na(b$upper), Inf, b$upper)
    if (any(utils::head(hi, -1L) != lo[-1L])) {
      stop(
        "the bands must be contiguous (each band starts where the one ",
        "before ends)",
        call. = FALSE
      )
    }
  } else {
    breaks <- .rmbl_num_input(breaks, "breaks", allow_null = FALSE)
    if (
      length(breaks) < 2L ||
        anyNA(breaks) ||
        is.unsorted(breaks, strictly = TRUE)
    ) {
      stop("`breaks` must be at least two increasing band edges", call. = FALSE)
    }
    if (!is.finite(breaks[1L]) || !all(is.finite(utils::head(breaks, -1L)))) {
      stop("only the last of `breaks` may be infinite", call. = FALSE)
    }
    lo <- utils::head(breaks, -1L)
    hi <- breaks[-1L]
  }
  list(lo = lo, hi = hi)
}

#' lifetbl()'s confidence limits of the survival function.
#' @param surv The survival function at the bands' ends.
#' @param gw Greenwood's sums.
#' @param conflvl,conftype As for lifetbl(), checked.
#' @return A list: the lower and the upper limits.
#' @noRd
.jx_lt_limits <- function(surv, gw, conflvl, conftype) {
  z <- stats::qnorm(1 - (1 - conflvl) / 2)
  se <- surv * sqrt(gw)
  lims <- switch(
    conftype,
    plain = list(pmax(surv - z * se, 0), pmin(surv + z * se, 1)),
    log = list(surv * exp(-z * sqrt(gw)), pmin(surv * exp(z * sqrt(gw)), 1)),
    `log-log` = {
      s <- sqrt(gw) / log(surv)
      list(surv^exp(-z * s), surv^exp(z * s))
    }
  )
  lapply(lims, function(v) {
    ifelse(surv > 0 & surv < 1 & is.finite(gw), v, NA_real_)
  })
}

#' lifetbl()'s median time, by linear interpolation within its band.
#' @param surv The survival function at the bands' ends.
#' @param s0 The survival function at the bands' starts.
#' @param lo,hi,width The bands' edges and widths.
#' @return The median, or Inf with a note when it is not reached.
#' @noRd
.jx_lt_median <- function(surv, s0, lo, hi, width) {
  j <- which(surv <= 0.5)[1L]
  if (is.na(j)) {
    structure(
      Inf,
      note = sprintf(
        "over %s: survival never falls to one half",
        format(utils::tail(hi, 1L))
      )
    )
  } else if (is.finite(hi[j])) {
    lo[j] + width[j] * (s0[j] - 0.5) / (s0[j] - surv[j])
  } else {
    structure(
      Inf,
      note = sprintf("over %s (inside the open band)", format(lo[j]))
    )
  }
}

#' plot.rmbl_life_table()'s confidence band.
#' @param tx The times.
#' @param lo,up The limits at those times.
#' @param cols The two colours.
#' @return NULL, invisibly.
#' @noRd
.jx_lt_band <- function(tx, lo, up, cols) {
  ok <- is.finite(lo) & is.finite(up)
  if (sum(ok) > 1L) {
    graphics::polygon(
      c(tx[ok], rev(tx[ok])),
      c(lo[ok], rev(up[ok])),
      border = NA,
      col = grDevices::adjustcolor(cols[1L], 0.2)
    )
  }
  invisible(NULL)
}

#' plot.rmbl_life_table()'s survival curve, dashed into an open last band.
#' @param tx,sv The times and the survival function there.
#' @param open Which bands are open.
#' @param cols The two colours.
#' @return NULL, invisibly.
#' @noRd
.jx_lt_curve <- function(tx, sv, open, cols) {
  kk <- length(tx)
  closed <- if (any(open)) seq_len(kk - 1L) else seq_len(kk)
  graphics::polygon(
    c(tx[closed][1L], tx[closed], tx[closed][sum(closed)]),
    c(0, sv[closed], 0),
    col = grDevices::adjustcolor(cols[1L], 0.16),
    border = NA
  )
  graphics::lines(
    tx[closed],
    sv[closed],
    col = grDevices::adjustcolor(cols[1L], 0.25),
    lwd = 7
  )
  graphics::lines(tx[closed], sv[closed], col = cols[1L], lwd = 2.5)
  graphics::points(
    tx[closed],
    sv[closed],
    pch = 21,
    bg = cols[1L],
    col = "white",
    lwd = 1.5,
    cex = 1.5
  )
  # an open band has no end: its fall to zero is drawn dashed, over a nominal
  # width
  if (any(open)) {
    graphics::lines(
      tx[(kk - 1L):kk],
      sv[(kk - 1L):kk],
      col = cols[1L],
      lwd = 2,
      lty = 2
    )
  }
  invisible(NULL)
}

#' plot.rmbl_life_table()'s line at one half, its median and open-band arrow.
#' @param tx The times.
#' @param open Which bands are open.
#' @param med The median time.
#' @param cols The two colours.
#' @return NULL, invisibly.
#' @noRd
.jx_lt_marks <- function(tx, open, med, cols) {
  graphics::abline(h = 0.5, lty = 3, col = "#666666")
  if (is.finite(med)) {
    graphics::abline(v = med, lty = 2, col = cols[2L])
  }
  if (any(open)) {
    graphics::arrows(
      utils::tail(tx, 2L)[1L],
      0.02,
      utils::tail(tx, 1L),
      0.02,
      length = 0.08,
      col = "#666666"
    )
  }
  invisible(NULL)
}

#' dispmix()'s counts as a numeric matrix, checked.
#' @param cnts As for dispmix().
#' @return The counts: one row per period, one column per outcome.
#' @noRd
.jx_dm_matrix <- function(cnts) {
  if (is.data.frame(cnts)) {
    bad <- names(cnts)[!vapply(cnts, is.numeric, logical(1))]
    if (length(bad)) {
      stop(
        sprintf(
          paste0(
            "`cnts` has a column that is not numeric (%s); pass only the ",
            "outcome columns"
          ),
          bad[1L]
        ),
        call. = FALSE
      )
    }
    cnts <- as.matrix(cnts)
  }
  if (!is.matrix(cnts) || !is.numeric(cnts)) {
    stop("`cnts` must be a numeric matrix or data frame", call. = FALSE)
  }
  if (nrow(cnts) < 1L || ncol(cnts) < 2L) {
    stop("`cnts` needs at least one period and two outcomes", call. = FALSE)
  }
  cnts
}

#' dispmix()'s share of each outcome in each period, with simultaneous
#' Goodman intervals.
#' @param cnts The counts matrix.
#' @param prd,outcome The periods and outcomes.
#' @param tot The periods' totals.
#' @param conflvl As for dispmix(), checked.
#' @return A data frame, one row per period and outcome.
#' @noRd
.jx_dm_shares <- function(cnts, prd, outcome, tot, conflvl) {
  nt <- nrow(cnts)
  k <- ncol(cnts)
  a <- stats::qchisq(1 - (1 - conflvl) / k, 1)
  ni <- as.vector(cnts)
  nn <- rep(tot, times = k)
  half <- sqrt(a * (a + 4 * ni * (nn - ni) / nn))
  data.frame(
    period = rep(prd, times = k),
    outcome = rep(outcome, each = nt),
    count = ni,
    total = nn,
    share = ni / nn,
    lower = (a + 2 * ni - half) / (2 * (nn + a)),
    upper = (a + 2 * ni + half) / (2 * (nn + a)),
    stringsAsFactors = FALSE
  )
}

#' dispmix()'s chi-square test that the mix is the same in every period.
#' @param cnts The counts matrix, at least two periods.
#' @return A one-row data frame: statistic, df, p_value and cramerv.
#' @noRd
.jx_dm_homog <- function(cnts) {
  keep <- colSums(cnts) > 0
  m <- cnts[, keep, drop = FALSE]
  e <- outer(rowSums(m), colSums(m)) / sum(m)
  x2 <- sum((m - e)^2 / e)
  df <- (nrow(m) - 1L) * (ncol(m) - 1L)
  data.frame(
    statistic = x2,
    df = df,
    p_value = stats::pchisq(x2, df, lower.tail = FALSE),
    cramerv = sqrt(x2 / (sum(m) * min(nrow(m) - 1L, ncol(m) - 1L)))
  )
}

#' dispmix()'s test of a trend in each outcome's share over the periods.
#' @param cnts The counts matrix, at least three periods.
#' @param tot The periods' totals.
#' @param scores,outcome As for dispmix(); the outcomes' names.
#' @return A data frame, one row per outcome.
#' @noRd
.jx_dm_trend <- function(cnts, tot, scores, outcome) {
  nt <- nrow(cnts)
  k <- ncol(cnts)
  if (is.null(scores)) {
    scores <- seq_len(nt)
  }
  scores <- .rmbl_num_input(scores, "scores", allow_null = FALSE)
  if (
    length(scores) != nt ||
      !all(is.finite(scores)) ||
      length(unique(scores)) < 2L
  ) {
    stop(
      sprintf("`scores` must be %d finite numbers, not all equal", nt),
      call. = FALSE
    )
  }
  tr <- lapply(seq_len(k), function(j) {
    if (sum(cnts[, j]) == 0 || all(cnts[, j] == tot)) {
      return(c(NA_real_, NA_real_))
    }
    t <- suppressWarnings(stats::prop.trend.test(
      cnts[, j],
      tot,
      score = scores
    ))
    c(unname(t$statistic), t$p.value)
  })
  tr <- do.call(rbind, tr)
  trend <- data.frame(
    outcome = outcome,
    statistic = tr[, 1L],
    p_value = tr[, 2L],
    pholm = stats::p.adjust(tr[, 2L], "holm"),
    change = cnts[nt, ] / tot[nt] - cnts[1L, ] / tot[1L],
    stringsAsFactors = FALSE
  )
  rownames(trend) <- NULL
  trend
}

#' plot.rmbl_disposition_mix()'s stacked bands of the shares.
#' @param xs The periods' x positions, the bands' left and right edges.
#' @param cum The cumulative shares, one row per period.
#' @param cols The outcomes' colours.
#' @return NULL, invisibly.
#' @noRd
.jx_dm_bands <- function(xs, cum, cols) {
  nt <- nrow(cum)
  k <- ncol(cum) - 1L
  for (j in seq_len(k)) {
    lo <- if (nt == 1L) rep(cum[1L, j], 2L) else cum[, j]
    hi <- if (nt == 1L) rep(cum[1L, j + 1L], 2L) else cum[, j + 1L]
    graphics::polygon(
      c(xs, rev(xs)),
      c(lo, rev(hi)),
      col = cols[j],
      border = "white",
      lwd = 0.5
    )
  }
  invisible(NULL)
}

#' plot.rmbl_disposition_mix()'s outcome labels, right of the last period.
#' @param cum The cumulative shares, one row per period.
#' @param labels The outcomes' labels, fitted.
#' @param cols The outcomes' colours.
#' @return NULL, invisibly.
#' @noRd
.jx_dm_labels <- function(cum, labels, cols) {
  nt <- nrow(cum)
  k <- ncol(cum) - 1L
  mid <- (cum[nt, -1L] + cum[nt, -(k + 1L)]) / 2
  # labels for bands too thin to hold text are pushed apart so they do not
  # overprint
  gap <- 0.75 * graphics::par("cxy")[2L]
  ord <- order(mid)
  ym <- mid[ord]
  for (i in seq_along(ym)[-1L]) {
    ym[i] <- max(ym[i], ym[i - 1L] + gap)
  }
  # pushed past the top: the whole stack moves down, then is spread upward again
  # from the floor
  if (max(ym) > 1) {
    ym[length(ym)] <- 1
    for (i in rev(seq_along(ym))[-1L]) {
      ym[i] <- min(ym[i], ym[i + 1L] - gap)
    }
  }
  # from the frame's edge, not the last period's: drawn from inside the frame,
  # the box ran through the first letter
  graphics::text(
    graphics::par("usr")[2L],
    ym,
    labels[ord],
    pos = 4,
    xpd = NA,
    cex = 0.75,
    col = cols[ord]
  )
  invisible(NULL)
}

#' crmdens()'s located incidents and their weights; the rest are dropped
#' with a message.
#' @param lon,lat,w,xy As for crmdens(), `lon` and `lat` checked.
#' @return A list: lon, lat, w and dropped (the count dropped).
#' @noRd
.cd_points <- function(lon, lat, w, xy) {
  .w <- if (is.null(w)) {
    rep(1, length(lon))
  } else {
    .jx_counts(w, "w", length(lon), allow_na = TRUE)
  }
  keep <- is.finite(lon) & is.finite(lat) & !is.na(.w)
  if (xy == "lonlat") {
    keep <- .cd_keep_lonlat(lon, lat, keep)
  }
  dropped <- sum(!keep)
  if (dropped) {
    message(sprintf(
      "crmdens(): %d incident%s without a usable location dropped",
      dropped,
      if (dropped == 1L) "" else "s"
    ))
  }
  lon <- lon[keep]
  lat <- lat[keep]
  .w <- .w[keep]
  if (length(lon) < 2L || sum(.w) <= 0) {
    stop(
      "need at least two located incidents with positive weight",
      call. = FALSE
    )
  }
  list(lon = lon, lat = lat, w = .w, dropped = dropped)
}

#' crmdens()'s incidents on a plane in kilometres.
#' @param lon,lat,xy As for crmdens(), checked.
#' @return A list: p (x and y), and the projection's centre lon0 and lat0 (NA
#'   for planar coordinates).
#' @noRd
.cd_plane <- function(lon, lat, xy) {
  if (xy == "lonlat") {
    p <- .jx_lonlat_plane(lon, lat, "crmdens")
    lon0 <- p$lon0
    lat0 <- p$lat0
  } else {
    lon0 <- lat0 <- NA_real_
    p <- list(
      x = (lon - stats::median(lon)) / 1000,
      y = (lat - stats::median(lat)) / 1000
    )
  }
  list(p = p, lon0 = lon0, lat0 = lat0)
}

#' Warns when crmdens()'s grid is coarser than its bandwidth.
#' @param dx,dy The grid's spacing.
#' @param h The bandwidths.
#' @return NULL, invisibly.
#' @noRd
.cd_spacing_warn <- function(dx, dy, h) {
  if (dx > h[1L] || dy > h[2L]) {
    warning(
      sprintf(
        paste0(
          "the grid spacing (%.3g km) is wider than the bandwidth (%.3g ",
          "km); raise `ngrid`"
        ),
        max(dx, dy),
        min(h)
      ),
      call. = FALSE
    )
  }
  invisible(NULL)
}

#' crmdens()'s smallest regions holding each share of the incidents.
#' @param field The density on the grid.
#' @param mass The density times the cell area.
#' @param cell The cell area.
#' @param cover As for crmdens(), checked.
#' @return A data frame, one row per share.
#' @noRd
.cd_regions <- function(field, mass, cell, cover) {
  o <- order(mass, decreasing = TRUE)
  cm <- cumsum(mass[o]) / sum(mass)
  do.call(
    rbind,
    lapply(sort(cover), function(cv) {
      m <- which(cm >= cv)[1L]
      data.frame(
        coverage = cv,
        level = field[o][m],
        areakm2 = m * cell,
        areashr = m / length(field)
      )
    })
  )
}

#' plot.rmbl_density()'s colours.
#' @param col,palette As for plot.rmbl_density().
#' @return The colours.
#' @noRd
.cd_cols <- function(col, palette) {
  if (!is.null(col)) {
    .bl_cols(length(col), col)
  } else if (!is.null(palette)) {
    blpal(palette, 64)
  } else {
    grDevices::hcl.colors(64, "YlOrRd", rev = TRUE)
  }
}

#' plot.rmbl_density()'s incidents and the contours of its regions.
#' @param x The rmbl_density.
#' @param xs,ys The grid.
#' @param ll Whether the coordinates are longitude and latitude.
#' @param points As for plot.rmbl_density().
#' @return NULL, invisibly.
#' @noRd
.cd_overlay <- function(x, xs, ys, ll, points) {
  if (isTRUE(points)) {
    graphics::points(
      if (ll) x$points$lon else x$points$x,
      if (ll) x$points$lat else x$points$y,
      pch = 16,
      cex = 0.3,
      col = grDevices::adjustcolor("#222222", 0.35)
    )
  }
  r <- x$regions
  graphics::contour(
    xs,
    ys,
    x$field,
    levels = r$level,
    labels = sprintf("%g%%", 100 * r$coverage),
    add = TRUE,
    col = "#222222",
    lwd = c(2, 1.2)[seq_len(nrow(r)) %% 2 + 1L],
    labcex = 0.7
  )
  invisible(NULL)
}

#' knoxtst()'s cap on the close pairs, checked.
#' @param maxprs As for knoxtst().
#' @return The cap.
#' @noRd
.knox_maxprs <- function(maxprs) {
  maxprs <- .rmbl_num(maxprs, "maxprs")
  if (length(maxprs) != 1L || is.na(maxprs) || maxprs < 1) {
    stop("`maxprs` must be a single number of at least 1", call. = FALSE)
  }
  maxprs
}

#' knoxtst()'s number of permutations, checked.
#' @param nsim As for knoxtst().
#' @return The number.
#' @noRd
.knox_nsim <- function(nsim) {
  nsim <- .rmbl_num(nsim, "nsim", integer = TRUE)
  if (length(nsim) != 1L || is.na(nsim) || nsim < 19L) {
    stop("`nsim` must be a whole number of at least 19", call. = FALSE)
  }
  nsim
}

#' knoxtst()'s incidents on a plane in metres.
#' @param x,y,xy As for knoxtst(), checked.
#' @return A list: x and y.
#' @noRd
.knox_metres <- function(x, y, xy) {
  if (xy == "lonlat") {
    p <- .jx_lonlat_plane(x, y, "knoxtst")
    list(x = p$x * 1000, y = p$y * 1000)
  } else {
    list(x = x, y = y)
  }
}

#' The close pairs counted in each cell of distance and time bands.
#' @param tv The incidents' times.
#' @param cp The close pairs (.jx_close_pairs()).
#' @param s_idx Each pair's distance band.
#' @param tb The time bands.
#' @param ks The number of distance bands.
#' @return The counts, distance bands varying fastest.
#' @noRd
.knox_cell_counts <- function(tv, cp, s_idx, tb, ks) {
  kt <- length(tb)
  dt <- abs(tv[cp$i] - tv[cp$j])
  t_idx <- findInterval(
    dt,
    c(0, tb),
    left.open = TRUE,
    rightmost.closed = TRUE
  )
  t_idx[dt == 0] <- 1L
  ok <- t_idx >= 1L & t_idx <= kt & dt <= max(tb)
  tabulate(s_idx[ok] + (t_idx[ok] - 1L) * ks, ks * kt)
}

#' knoxtst()'s table: one row per cell of distance and time bands.
#' @param sb,tb The distance and time bands.
#' @param obs,expected The observed and expected pairs.
#' @param pv The permutation p-values.
#' @return A data frame.
#' @noRd
.knox_table <- function(sb, tb, obs, expected, pv) {
  ks <- length(sb)
  kt <- length(tb)
  data.frame(
    spclo = rep(c(0, utils::head(sb, -1L)), times = kt),
    spcup = rep(sb, times = kt),
    tmlo = rep(c(0, utils::head(tb, -1L)), each = ks),
    tmup = rep(tb, each = ks),
    observed = obs,
    expected = as.vector(expected),
    ratio = ifelse(
      as.vector(expected) > 0,
      obs / as.vector(expected),
      NA_real_
    ),
    p_value = pv
  )
}

#' The Knox ratios as cell labels, starred by their p-values.
#' @param t The Knox table.
#' @return One label per cell; "-" where there is no ratio.
#' @noRd
.knox_labels <- function(t) {
  stars <- ifelse(t$p_value < 0.05, "*", "")
  stars[!is.na(t$p_value) & t$p_value < 0.01] <- "**"
  lab <- sprintf("%.2f%s", t$ratio, stars)
  lab[is.na(t$ratio)] <- "-"
  lab
}

#' plot.rmbl_knox()'s colours: white at a ratio of 1, blue below, red above.
#' @param col,palette As for plot.rmbl_knox().
#' @return The colours.
#' @noRd
.knox_cols <- function(col, palette) {
  if (!is.null(col)) {
    .bl_cols(length(col), col)
  } else if (!is.null(palette)) {
    blpal(palette, 63)
  } else {
    grDevices::colorRampPalette(c("#2166AC", "#F7F7F7", "#B2182B"))(63)
  }
}

#' clrdcmp()'s counts and labels, checked.
#' @param num,den,grp,cmp As for clrdcmp().
#' @return A list: num and den, as counts.
#' @noRd
.clr_check_inputs <- function(num, den, grp, cmp) {
  .num <- .jx_counts(num, "num")
  n <- length(.num)
  if (!n) {
    stop("`num` is empty", call. = FALSE)
  }
  .den <- .jx_counts(den, "den", n)
  if (length(grp) != n || length(cmp) != n) {
    stop(
      "`num`, `den`, `grp` and `cmp` must have the same length",
      call. = FALSE
    )
  }
  if (anyNA(grp) || anyNA(cmp)) {
    stop("`grp` and `cmp` must not have missing values", call. = FALSE)
  }
  list(num = .num, den = .den)
}

#' Stops when a part of clrdcmp() has a zero denominator.
#' @param g The parts.
#' @param da,db Their denominators in the two compared levels.
#' @return NULL, invisibly.
#' @noRd
.clr_check_zero <- function(g, da, db) {
  if (any(da == 0 | db == 0)) {
    stop(
      sprintf(
        "part \"%s\" has a zero denominator, so it has no rate",
        g[da == 0 | db == 0][1L]
      ),
      call. = FALSE
    )
  }
  invisible(NULL)
}

#' clrdcmp()'s Kitagawa terms: each part's rates, shares and effects.
#' @param na,da,nb,db The parts' numerators and denominators in the two
#'   compared levels.
#' @return A list: ra, rb, wa, wb, rate_eff and mix_eff.
#' @noRd
.clr_kitagawa <- function(na, da, nb, db) {
  ra <- na / da
  rb <- nb / db
  wa <- da / sum(da)
  wb <- db / sum(db)
  rate_eff <- (wa + wb) / 2 * (rb - ra)
  # each part's mix term is centred on the average aggregate rate: the shares'
  # changes add to zero, so the total is unchanged, and a part's term is
  # negative when work moved toward a part that clears below the average
  # (uncentred, a growing part always looked like a gain)
  centre <- (sum(na) / sum(da) + sum(nb) / sum(db)) / 2
  mix_eff <- ((ra + rb) / 2 - centre) * (wb - wa)
  list(
    ra = ra,
    rb = rb,
    wa = wa,
    wb = wb,
    rate_eff = rate_eff,
    mix_eff = mix_eff
  )
}

#' clrdcmp()'s table of the parts.
#' @param g The parts.
#' @param na,da,nb,db Their numerators and denominators.
#' @param k The Kitagawa terms (.clr_kitagawa()).
#' @param conflvl As for clrdcmp(), checked.
#' @return A data frame, one row per part.
#' @noRd
.clr_group_table <- function(g, na, da, nb, db, k, conflvl) {
  ci <- .jx_ratio_ci(nb, na, conflvl)
  data.frame(
    group = g,
    numa = na,
    dena = da,
    ratea = k$ra,
    weia = k$wa,
    numb = nb,
    denb = db,
    rateb = k$rb,
    weib = k$wb,
    rateratio = k$rb / k$ra,
    lower = ci$lower * da / db,
    upper = ci$upper * da / db,
    rateeff = k$rate_eff,
    mixeff = k$mix_eff,
    stringsAsFactors = FALSE
  )
}

#' print.rmbl_clearance_decomposition()'s verdict on Simpson's paradox.
#' @param s The paradox's summary.
#' @param o The overall row.
#' @return One string.
#' @noRd
.clr_verdict <- function(s, o) {
  switch(
    s$type,
    full = sprintf(
      paste0(
        "Simpson's paradox: every part moved the other way to the ",
        "aggregate (%d of %d)"
      ),
      if (o$change < 0) s$up else s$down,
      s$parts
    ),
    mix = sprintf(
      paste0(
        "Simpson's paradox through the mix: the aggregate %s, but at a ",
        "fixed mix it %s"
      ),
      if (o$change < 0) "fell" else "rose",
      if (o$rateeff < 0) "fell" else "rose"
    ),
    none = paste0(
      "No reversal: the aggregate moved the way the mix-standardised rate ",
      "did"
    )
  )
}

#' print.rmbl_clearance_decomposition()'s footer: the rate ratios.
#' @param rr The crude and Mantel-Haenszel rate ratios.
#' @param a,b The compared levels.
#' @return One string.
#' @noRd
.clr_footer <- function(rr, a, b) {
  sprintf(
    paste(
      "Rate ratio %s/%s: crude %.4f (%.4f to %.4f);",
      "within parts (Mantel-Haenszel) %.4f (%.4f to %.4f), p %s"
    ),
    b,
    a,
    rr$ratio[1L],
    rr$lower[1L],
    rr$upper[1L],
    rr$ratio[2L],
    rr$lower[2L],
    rr$upper[2L],
    .rmbl_fmt_p(rr$p_value[2L])
  )
}

#' plot.rmbl_clearance_decomposition()'s number of rows, checked and fitted
#' to the device.
#' @param maxparts As for plot.rmbl_clearance_decomposition().
#' @return The number of rows.
#' @noRd
.jx_cd_maxparts <- function(maxparts) {
  maxparts <- .rmbl_num(maxparts, "maxparts", integer = TRUE)
  if (length(maxparts) != 1L || is.na(maxparts) || maxparts < 2L) {
    stop("`maxparts` must be a whole number of at least 2", call. = FALSE)
  }
  # no more rows than the device has room for (about 0.12 inch each): a 3-inch
  # device shows the parts that moved the aggregate most, the rest summed,
  # instead of 20 rows on top of each other
  din <- tryCatch(graphics::par("din"), error = function(e) c(7, 7))
  maxparts <- max(2L, min(maxparts, as.integer(floor((din[2L] - 2) / 0.12))))
  maxparts
}

#' plot.rmbl_clearance_decomposition()'s default panels for the device.
#' @return The panels' names.
#' @noRd
.jx_cd_what <- function() {
  din <- tryCatch(graphics::par("din"), error = function(e) c(7, 7))
  if (din[1L] >= 10 && din[2L] >= 3.5) {
    c("rates", "mix", "effects")
  } else if (din[1L] >= 6 && din[2L] >= 3.5) {
    c("rates", "mix")
  } else {
    "rates"
  }
}

#' The outer text of the decomposition's panels: the sum, and the title.
#' @param line The decomposition, as one line.
#' @param keys The panels' keys (.bl_panels_end()).
#' @param what The panels drawn.
#' @param main The decomposition's outer title, or NULL for none.
#' @return NULL, invisibly.
#' @noRd
.jx_cd_outer_text <- function(line, keys, what, main) {
  if (!"effects" %in% what) {
    graphics::mtext(
      line,
      side = 1,
      outer = TRUE,
      line = if (length(keys)) 1.2 else 0.2,
      cex = 0.8,
      adj = 0,
      col = "#3D4350"
    )
  }
  if (!is.null(main)) {
    graphics::mtext(
      main,
      side = 3,
      outer = TRUE,
      line = -1.2,
      font = 2,
      col = "#1F2430"
    )
  }
  invisible(NULL)
}

#' One panel of the decomposition, with the sum written under it.
#' @param x The decomposition.
#' @param what The panel.
#' @param cols The two colours.
#' @param main The single panel's title, or NULL for the default.
#' @param line The decomposition, as one line.
#' @param draw The panels' drawing functions.
#' @param ... Passed to the drawing function.
#' @return NULL, invisibly.
#' @noRd
.jx_cd_single <- function(x, what, cols, main, line, draw, ...) {
  if (what != "effects") {
    graphics::par(oma = c(1.4, 0, 0, 0))
  }
  draw[[what]](x, cols, main, ...)
  if (what != "effects") {
    graphics::mtext(
      line,
      side = 1,
      outer = TRUE,
      line = 0.2,
      cex = 0.8,
      adj = 0,
      col = "#3D4350"
    )
  }
  invisible(NULL)
}

#' The close pairs of the points too far out to index: each compared with
#' every other point directly.
#' @param far Which points are too far out.
#' @param nx The number of points.
#' @param within The test of two points being within the band.
#' @param max_pairs The cap on the pairs compared.
#' @return A list: out_i and out_j (lists of the pairs' indices) and total
#'   (the pairs compared).
#' @noRd
.jx_far_pairs <- function(far, nx, within, max_pairs) {
  out_i <- list()
  out_j <- list()
  fi <- which(far)
  total <- length(fi) * nx
  if (total > max_pairs) {
    stop(
      sprintf(
        paste(
          "%d incidents lie too far out for the largest distance band",
          "to index (past 2^52",
          "bands); comparing them with every other one is more than",
          "%s pairs: use a wider",
          "band, rescale, or raise `maxprs`"
        ),
        length(fi),
        format(max_pairs, big.mark = ",")
      ),
      call. = FALSE
    )
  }
  for (i in fi) {
    j <- setdiff(seq_len(nx), i)
    j <- j[!(far[j] & j < i)] # each pair of two far points once
    sel <- within(rep(i, length(j)), j)
    out_i[[length(out_i) + 1L]] <- pmin(i, j[sel])
    out_j[[length(out_j) + 1L]] <- pmax(i, j[sel])
  }
  list(out_i = out_i, out_j = out_j, total = total)
}

#' Stops: more candidate pairs within the largest band than the cap.
#' @param max_pairs The cap.
#' @return Does not return.
#' @noRd
.jx_too_many_pairs <- function(max_pairs) {
  stop(
    sprintf(
      paste(
        "more than %s candidate pairs within the largest distance",
        "band: use a smaller",
        "largest band, fewer incidents, or raise `maxprs`"
      ),
      format(max_pairs, big.mark = ",")
    ),
    call. = FALSE
  )
}

#' The graphical parameters of a decomposition panel, set at the panel's
#' own text size.
#' @param o0 The plot options (.bl_plot_opts()).
#' @return The previous parameters.
#' @noRd
.jx_cd_par <- function(o0) {
  # every value saved before any is set: setting fg sets col too, so col read
  # after fg was already the frame's grey; mar too, which the panels set next
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
    las = o0$las,
    cex = o0$cex,
    bg = o0$bg,
    bty = "n",
    tcl = -0.2,
    mgp = c(3, 0.55, 0),
    col.axis = "#3D4350",
    fg = "#8A909A",
    col = "#1F2430"
  )
  op
}

#' Labels every row of a decomposition panel, left of the frame.
#' @param y The rows' positions.
#' @param fit The fitted labels (.jx_row_labels()).
#' @return NULL, invisibly.
#' @noRd
.jx_cd_row_text <- function(y, fit) {
  graphics::text(
    graphics::par("usr")[1L] - 0.03 * diff(graphics::par("usr")[1:2]),
    y,
    fit$labels,
    adj = 1,
    xpd = NA,
    cex = fit$cex
  )
  invisible(NULL)
}

#' The two ends of each row of a decomposition panel: open, then filled.
#' @param a,b The values in the two compared levels.
#' @param y The rows' positions.
#' @param fill The rows' colours.
#' @return NULL, invisibly.
#' @noRd
.jx_cd_points <- function(a, b, y, fill) {
  graphics::points(a, y, pch = 21, bg = "white", col = "#555555", cex = 1.1)
  graphics::points(
    b,
    y,
    pch = 21,
    bg = fill,
    col = "white",
    lwd = 1.2,
    cex = 1.5
  )
  invisible(NULL)
}

#' The colour key of the mix panel.
#' @return NULL, invisibly.
#' @noRd
.jx_cd_mix_key <- function() {
  # the colour key under the title, where it covers no point, sized to the panel
  key <- "colour: blue clears above average, orange below"
  kc <- min(
    0.75,
    0.75 * graphics::par("pin")[1L] / max(.bl_strwidth(key, cex = 0.75), 1e-6)
  )
  graphics::mtext(
    key,
    side = 3,
    line = 0.15,
    cex = kc * graphics::par("cex"),
    col = "#555555"
  )
  invisible(NULL)
}

#' The waterfall's bar labels, sized to fit the bars.
#' @return The labels' size.
#' @noRd
.jx_cd_bar_labels <- function() {
  unit_in <- graphics::par("pin")[1L] / diff(graphics::par("usr")[1:2])
  bar_cex <- min(
    0.85,
    0.85 *
      0.9 *
      unit_in /
      max(.bl_strwidth(c("rates", "mix", "total"), cex = 0.85))
  )
  graphics::mtext(
    c("rates", "mix", "total"),
    side = 1,
    at = 1:3,
    line = 0.8,
    cex = bar_cex * graphics::par("cex")
  )
  bar_cex
}

#' The waterfall's bars: the rate and mix effects, and their sum.
#' @param ends The steps' ends.
#' @param vals The two effects.
#' @param change The total change.
#' @param cols The two colours.
#' @return NULL, invisibly.
#' @noRd
.jx_cd_bars <- function(ends, vals, change, cols) {
  for (i in 1:2) {
    graphics::rect(
      i - 0.35,
      ends[i],
      i + 0.35,
      ends[i + 1L],
      border = NA,
      col = if (vals[i] >= 0) cols[1L] else cols[2L]
    )
  }
  graphics::rect(
    3 - 0.35,
    0,
    3 + 0.35,
    change,
    border = "#333333",
    col = "#999999"
  )
  # the bars' values, and the steps joined, so the waterfall reads as a sum
  graphics::segments(
    c(1.35, 2.35),
    ends[2:3],
    c(1.65, 2.65),
    ends[2:3],
    lty = 3,
    col = "#666666"
  )
  invisible(NULL)
}

#' lifetbl()'s actuarial survival: those at risk, the hazard per band, the
#' survival function and Greenwood's sums.
#' @param d,w The events and the censored cases in each band.
#' @param total All the cases.
#' @return A list: entering, at_risk, q, surv and gw.
#' @noRd
.jx_lt_survival <- function(d, w, total) {
  k <- length(d)
  entering <- total - c(0, cumsum(d + w))[seq_len(k)]
  at_risk <- entering - w / 2
  q <- ifelse(at_risk > 0, pmin(d / at_risk, 1), NA_real_)
  # entering is built by subtraction, so a band holding every remaining case can
  # come out a rounding error short of q = 1; that is q = 1
  q[!is.na(q) & q > 1 - 1e-9] <- 1
  surv <- cumprod(1 - ifelse(is.na(q), 0, q))
  gw <- cumsum(ifelse(
    at_risk > 0 & q < 1,
    d / (at_risk * (at_risk - d)),
    NA_real_
  ))
  list(entering = entering, at_risk = at_risk, q = q, surv = surv, gw = gw)
}

#' knoxtst()'s distance band of each close pair, and the pairs expected in
#' each cell when space and time are independent.
#' @param cp The close pairs (.jx_close_pairs()).
#' @param sb,tb The distance and time bands.
#' @param tt The incidents' times.
#' @param n The number of incidents.
#' @return A list: s_idx and expected (distance bands x time bands).
#' @noRd
.knox_expected <- function(cp, sb, tb, tt, n) {
  ks <- length(sb)
  s_idx <- findInterval(
    cp$d,
    c(0, sb),
    left.open = TRUE,
    rightmost.closed = TRUE
  )
  s_idx[cp$d == 0] <- 1L
  big_p <- n * (n - 1) / 2
  s_cnt <- tabulate(s_idx, ks)
  t_cum <- .jx_pairs_within(tt, tb)
  t_cnt <- diff(c(0, t_cum))
  expected <- outer(s_cnt, t_cnt) / big_p
  list(s_idx = s_idx, expected = expected)
}

#' knoxtst()'s permutations: the cell counts with the times shuffled.
#' @param seed,nsim As for knoxtst(), checked.
#' @param cell_of The cell counter.
#' @param tt The incidents' times.
#' @param m The number of cells.
#' @return An m x nsim matrix.
#' @noRd
.knox_sims <- function(seed, nsim, cell_of, tt, m) {
  n <- length(tt)
  pg <- blprog("Knox test", nsim)
  on.exit(pg$done(), add = TRUE)
  sims <- .rmbl_with_seed_maybe(
    seed,
    vapply(
      seq_len(nsim),
      function(k) {
        pg$update(k - 1L, sprintf("permutation %d/%d", k, nsim))
        cell_of(tt[sample.int(n)])
      },
      numeric(m)
    )
  )
  matrix(sims, nrow = m)
}

#' crmdens()'s density on the grid: binned counts smoothed by the kernel.
#' @param p The incidents on the plane.
#' @param .w Their weights.
#' @param gx,gy The grid.
#' @param h The bandwidths.
#' @return The density, one row per x.
#' @noRd
.cd_field <- function(p, .w, gx, gy, h) {
  cnt <- .jx_linbin(p$x, p$y, .w, gx, gy)
  kx <- stats::dnorm(outer(gx, gx, "-"), sd = h[1L])
  ky <- stats::dnorm(outer(gy, gy, "-"), sd = h[2L])
  kx %*% cnt %*% t(ky)
}

#' The reading of an outcome mix: the share that rose most and the one that
#' fell most from the first period to the last.
#' @param x The dispmix() result.
#' @return Sentences, or NULL for one period.
#' @noRd
.jx_dm_reading <- function(x) {
  s <- x$shares
  p <- x$period
  if (length(p) < 2L) {
    return("One period: the shares of its cases, with no change to compare.")
  }
  first <- s$share[s$period == p[1L]]
  last <- s$share[s$period == p[length(p)]]
  ch <- last - first
  up <- which.max(ch)
  dn <- which.min(ch)
  c(
    sprintf("From %s to %s:", format(p[1L]), format(p[length(p)])),
    sprintf(
      "%s rose most, %+.1f points of the share;",
      x$outcome[up],
      100 * ch[up]
    ),
    sprintf("%s fell most, %+.1f points.", x$outcome[dn], 100 * ch[dn])
  )
}

#' The reading of a kernel density: how concentrated the incidents are.
#' @param x The crmdens() result.
#' @return Sentences.
#' @noRd
.jx_de_reading <- function(x) {
  r <- x$regions
  c(
    sprintf(
      "%s incidents%s; bandwidth %.3g km east-west, %.3g km north-south",
      format(x$n, big.mark = ","),
      if (x$dropped) {
        sprintf(" (%d without a location dropped)", x$dropped)
      } else {
        ""
      },
      x$bandwidth[1L],
      x$bandwidth[2L]
    ),
    sprintf(
      "%g%% of the incidents lie in %.1f%% of the mapped area.",
      100 * r$coverage[1L],
      100 * r$areashr[1L]
    )
  )
}

#' The facts of a clearance decomposition: the two rates, the change and its
#' parts, the standardised rates.
#' @param o The overall row.
#' @param s The paradox's summary.
#' @param a,b The compared levels.
#' @return A named list.
#' @noRd
.clr_facts <- function(o, s, a, b) {
  stats::setNames(
    list(
      o$ratea,
      o$rateb,
      sprintf(
        "%+.4f = rate effect %+.4f + mix effect %+.4f",
        o$change,
        o$rateeff,
        o$mixeff
      ),
      sprintf("%.4f", o$staonbase),
      sprintf("%.4f", o$staonave),
      s$parts
    ),
    c(
      paste("Rate", a),
      paste("Rate", b),
      "Change",
      sprintf("%s at the %s mix", b, a),
      sprintf("%s at the average mix", b),
      "Parts"
    )
  )
}
