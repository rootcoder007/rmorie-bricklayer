# SPDX-License-Identifier: AGPL-3.0-or-later

#' Bounds implied by rounding and suppression in a published table
#'
#' Administrative releases rarely publish the count that was observed.
#' Statistics Canada rounds to a base (random rounding to base 5 moves a
#' cell by up to 4); provincial tables round to the nearest 5 or 10; cells
#' below a disclosure limit are printed as `"x"`, `"<5"` or `".."`. Every
#' figure computed downstream inherits that uncertainty, and it is not
#' sampling uncertainty: no confidence interval covers it. This function
#' turns each published cell into the interval of observed counts that
#' could have produced it, so [chgenv()]
#' and [yoybnd()] can
#' carry the interval through a difference, a percent change or a rate.
#'
#' @details
#' For a published value \eqn{v} rounded to base \eqn{b}: with
#' \code{rndkind = "nearest"} the observed count lies in
#' \eqn{[\max(0, v - b/2), v + b/2]}; with \code{"random"} (unbiased random
#' rounding, where a count is moved to one of the two neighbouring multiples)
#' it lies in \eqn{[\max(0, v - (b - 1)), v + (b - 1)]}. The bounds are not
#' rounded to whole numbers. A suppressed cell lies in \eqn{[0, k - 1]}, with
#' \eqn{k} from \code{"<k"} or from \code{suplim}; rounding is
#' not applied to it. Without \code{rnd}, a published number is taken as
#' exact (lower = upper = value).
#'
#' Text cells are trimmed, and thousands separators (commas) are removed
#' before they are read as numbers. A missing value (\code{NA}) that is not a
#' suppression mark gets status \code{"missing"} and \code{NA} bounds.
#'
#' Errors: \code{rnd} not a positive number; an unknown
#' \code{rndkind}; a text cell that is neither a number nor a
#' suppression mark (the message lists the cells); a suppressed cell with no
#' limit (neither \code{"<k"} nor \code{suplim}).
#'
#' @param x Published values: a numeric vector, or a character vector (or
#'   factor) in which suppressed cells appear as one of
#'   \code{supmar} or as \code{"<k"} for a limit \code{k}.
#' @param rnd Numeric scalar, the base the release rounds to
#'   (\code{5}, \code{10}, ...), or \code{NULL} (the default) when the
#'   counts are exact.
#' @param rndkind `"nearest"` (the printed value is the observed
#'   value rounded to the nearest multiple of `rnd`, so the
#'   observed value lies within half a base) or `"random"` (Statistics
#'   Canada's random rounding, where the observed value lies within
#'   `rounding - 1`).
#' @param suplim Numeric scalar or \code{NULL} (the default). For
#'   a cell printed as suppressed with no explicit limit, the smallest count
#'   that would have been published: the cell then lies in
#'   \code{[0, suplim - 1]}.
#' @param supmar Character vector of the strings that mark a
#'   suppressed cell, matched exactly after trimming. Default
#'   \code{c("x", "X", "s", "..", "F", "suppressed", "n/a")}.
#' @return A data frame of class \code{c("rmbl_bounds", "data.frame")}, one
#'   row per cell, with \code{value} (numeric, the published number,
#'   \code{NA} for a suppressed cell), \code{lower} and \code{upper}
#'   (numeric, the interval of observed counts) and \code{status}
#'   (character: \code{"exact"}, \code{"rounded"}, \code{"suppressed"}, or
#'   \code{"missing"} for an \code{NA} that carried no suppression mark).
#'   Attribute \code{"bounds"} records \code{rounding},
#'   \code{rndkind} and \code{suplim}. \code{plot()} draws
#'   each value inside its interval.
#' @examples
#' pubbnd(c(120, 35, 0), rnd = 5)
#' pubbnd(c("120", "x", "<5"), rnd = 5,
#'                  suplim = 5)
#' # random rounding to base 5 is wider than rounding to the nearest 5
#' pubbnd(15, rnd = 5, rndkind = "random")
#'
#' # thousands separators and a custom suppression mark
#' pubbnd(c("1,200", "--", "<10"), suplim = 10,
#'                  supmar = "--")
#'
#' # a suppressed cell needs a limit
#' try(pubbnd(c("120", "x")))
#' @seealso [chgenv()],
#'   [yoybnd()]
#' @export
pubbnd <- function(x, rnd = NULL,
                             rndkind = c("nearest", "random"),
                             suplim = NULL,
                             supmar = c("x", "X", "s", "..",
                                                  "F", "suppressed",
                                                  "n/a")) {
  rndkind <- .rmbl_arg(rndkind)
  if (!is.null(suplim)) suplim <- .rmbl_scalar(suplim, "suplim", 0)
  if (!is.character(supmar) || anyNA(supmar)) {
    stop("`supmar` must be the text markers of a suppressed cell", call. = FALSE)
  }
  if (!is.null(rnd)) {
    rnd <- .rmbl_num(rnd, "rnd")[1L]
    if (is.na(rnd) || rnd <= 0) {
      stop("`rnd` must be a positive number", call. = FALSE)
    }
  }
  n <- length(x)
  value <- rep(NA_real_, n)
  status <- rep("exact", n)
  limit <- rep(NA_real_, n)
  if (is.character(x) || is.factor(x)) {
    s <- trimws(as.character(x))
    lt <- grepl("^<\\s*[0-9]+$", s)
    limit[lt] <- as.numeric(sub("^<\\s*", "", s[lt]))
    marked <- s %in% supmar
    status[lt | marked] <- "suppressed"
    num <- !(lt | marked) & !is.na(s)
    value[num] <- suppressWarnings(as.numeric(gsub(",", "", s[num])))
    bad <- num & is.na(value)
    if (any(bad)) {
      stop(sprintf(paste0("cannot read these cells as numbers or ",
                          "suppression marks: %s"),
                   paste(unique(s[bad]), collapse = ", ")), call. = FALSE)
    }
  } else {
    value <- .rmbl_num(x, "x")
  }
  status[is.na(value) & status != "suppressed"] <- "missing"
  lower <- value
  upper <- value
  if (!is.null(rnd)) {
    half <- if (rndkind == "nearest") rnd / 2 else rnd - 1
    r <- status == "exact" & !is.na(value)
    lower[r] <- pmax(0, value[r] - half)
    upper[r] <- value[r] + half
    status[r] <- "rounded"
  }
  sup <- status == "suppressed"
  if (any(sup)) {
    lim <- ifelse(is.na(limit[sup]), suplim %||% NA_real_,
                  limit[sup])
    if (anyNA(lim)) {
      stop(paste0("a suppressed cell has no limit: give `suplim` ",
                  "or write the cell as \"<k\""), call. = FALSE)
    }
    lower[sup] <- 0
    upper[sup] <- lim - 1
    value[sup] <- NA_real_
  }
  structure(data.frame(value = value, lower = lower, upper = upper,
                       status = status, stringsAsFactors = FALSE),
            class = c("rmbl_bounds", "data.frame"),
            bounds = list(rounding = rnd, rndkind = rndkind,
                          suppression_limit = suplim))
}

#' Envelope of a difference, a percent change or a rate under
#' publication bounds
#'
#' Given the intervals from [pubbnd()]
#' for the current and the
#' previous cell, the set of differences and percent changes that the
#' observed counts could have produced is an interval too: its ends are
#' reached at the ends of the input intervals, because the difference and
#' the ratio are monotone in each argument. This is interval arithmetic,
#' not a confidence interval; it says nothing about sampling and everything
#' about what the release withheld.
#'
#' @details
#' With current interval \eqn{[a_l, a_u]} and previous interval
#' \eqn{[b_l, b_u]}: the change lies in \eqn{[a_l - b_u, a_u - b_l]} and the
#' percent change in \eqn{[100(a_l / b_u - 1), 100(a_u / b_l - 1)]}. An end of
#' the percent interval is \code{NA} when its denominator could be zero (an
#' upper bound needs \eqn{b_l > 0}, a lower bound \eqn{b_u > 0}), since a
#' change from zero has no percentage. A rate interval is
#' \eqn{[per \cdot a_l / pop, per \cdot a_u / pop]}; the population is taken
#' as exact.
#'
#' Errors when \code{now} and \code{prev} have different numbers of
#' rows. The populations are not checked; give one per row (or one value).
#'
#' @param now,prev \code{rmbl_bounds} objects from
#'   [pubbnd()] (or data frames with numeric
#'   \code{lower} and
#'   \code{upper}) for the current and the earlier cell, with the same number
#'   of rows.
#' @param pop,prepop Optional numeric exposures (for
#'   example residents) for a rate envelope of the current and the previous
#'   cell; the rate is \code{per * count / population}. Default \code{NULL}.
#'   \code{prepop} is used only with \code{pop}.
#' @param per Numeric scalar, the rate base when exposures are given; default
#'   \code{1000} (per 1,000).
#' @return A data frame, one row per cell, with numeric columns
#'   \code{chglo}, \code{chgup}, \code{pctlo},
#'   \code{pctup} (\code{NA} where the previous cell could have been
#'   zero); with \code{population} also \code{ratelo} and
#'   \code{rateup}; with \code{prepop} as well
#'   \code{preratelo} and \code{prerateup}.
#' @seealso [pubbnd()],
#'   [yoybnd()].
#' @examples
#' now <- pubbnd(c(45, 120), rnd = 5)
#' prev <- pubbnd(c(40, 100), rnd = 5)
#' chgenv(now, prev)
#'
#' # with rates per 1,000 residents in both years
#' chgenv(now, prev, pop = c(10000, 20000),
#'                 prepop = c(10000, 19000))
#'
#' # a suppressed previous cell could have been zero: no upper percentage
#' chgenv(pubbnd(12), pubbnd("<5"))
#'
#' # the two sides must line up
#' try(chgenv(now, prev[1, ]))
#' @export
chgenv <- function(now, prev, pop = NULL,
                            prepop = NULL, per = 1000) {
  for (nm in c("now", "prev")) {
    v <- get(nm)
    if (!is.data.frame(v) || !all(c("lower", "upper") %in% names(v))) {
      stop(sprintf("`%s` must be a data frame from pubbnd() (columns lower and upper)", nm),
           call. = FALSE)
    }
  }
  if (nrow(now) != nrow(prev)) {
    stop("`now` and `prev` must have the same number of rows",
         call. = FALSE)
  }
  per <- .rmbl_scalar(per, "per", 1e-12)
  out <- data.frame(chglo = now$lower - prev$upper,
                    chgup = now$upper - prev$lower)
  pl <- ifelse(prev$upper > 0,
               100 * (now$lower / prev$upper - 1), NA_real_)
  pu <- ifelse(prev$lower > 0,
               100 * (now$upper / prev$lower - 1), NA_real_)
  out$pctlo <- pl
  out$pctup <- pu
  per <- .rmbl_num(per, "per")
  for (nm in c("pop", "prepop")) {
    v <- get(nm)
    if (is.null(v)) next
    v <- .rmbl_num(v, nm)
    if (!(length(v) %in% c(1L, nrow(now)))) {
      stop(sprintf("`%s` must be one number or one per row (%d)", nm, nrow(now)), call. = FALSE)
    }
    assign(nm, v)
  }
  if (!is.null(pop)) {
    out$ratelo <- per * now$lower / pop
    out$rateup <- per * now$upper / pop
    if (!is.null(prepop)) {
      out$preratelo <- per * prev$lower / prepop
      out$prerateup <- per * prev$upper / prepop
    }
  }
  out
}

#' Add publication bounds to a year-over-year table
#'
#' [yoy()] gives an exact conditional-binomial interval for the percent
#' change of a count, which covers sampling variation. This adds the
#' interval that rounding and suppression in the published cells imply
#' ([pubbnd()] carried through
#' [chgenv()]), and a
#' combined interval that is the union of the two, which is the honest
#' range for a figure read off a rounded table.
#'
#' @details
#' The \code{value} and \code{previous} columns of \code{y} are passed to
#' [pubbnd()] with the same rounding and
#' suppression settings, and
#' the two intervals to [chgenv()]. The combined
#' interval is the
#' smallest interval that contains both the sampling interval
#' (\code{pctlo}, \code{pctup}) and the publication envelope: its
#' lower end is the smaller of the two lower ends, its upper end the larger of
#' the two upper ends. Where either is \code{NA} (the first period, or a
#' previous cell that could be zero) the combined end is \code{NA}. The
#' function does not check that \code{y} holds counts; publication bounds
#' make sense only for counts.
#'
#' Errors when \code{y} does not come from [yoy()], and for the reasons
#' [pubbnd()] gives.
#'
#' @param y An \code{rmbl_yoy} object from [yoy()], with counts as
#'   values.
#' @inheritParams pubbnd
#' @return \code{y} (still an \code{rmbl_yoy}) with added numeric columns
#'   \code{envchglo}, \code{envchgup},
#'   \code{envpctlo}, \code{envpctup} and, when \code{y} has
#'   percent-change intervals, \code{compctlo} and
#'   \code{compctup}. The rounding settings are recorded as
#'   \code{bounds} in the \code{"yoy"} attribute.
#' @seealso [pubbnd()],
#'   [chgenv()], [yoy()].
#' @examples
#' seg <- data.frame(year = 2021:2023, n = c(40, 45, 60))
#' y <- yoy(seg, value = "n", prd = "year")
#' yoybnd(y, rnd = 5)
#'
#' # random rounding to base 5 widens the envelope
#' yb <- yoybnd(y, rnd = 5, rndkind = "random")
#' as.data.frame(yb)[, c("year", "envpctlo", "envpctup",
#'                       "compctlo", "compctup")]
#'
#' # only yoy() results are accepted
#' try(yoybnd(seg, rnd = 5))
#' @export
yoybnd <- function(y, rnd = NULL,
                       rndkind = c("nearest", "random"),
                       suplim = NULL) {
  if (!inherits(y, "rmbl_yoy")) {
    stop("yoybnd: `y` must come from yoy()", call. = FALSE)
  }
  rndkind <- .rmbl_arg(rndkind)
  m <- attr(y, "yoy")
  now <- pubbnd(y$value, rnd, rndkind,
                          suplim)
  prev <- pubbnd(y$previous, rnd, rndkind,
                           suplim)
  env <- chgenv(now, prev)
  y$envchglo <- env$chglo
  y$envchgup <- env$chgup
  y$envpctlo <- env$pctlo
  y$envpctup <- env$pctup
  if (!is.null(y$pctlo)) {
    y$compctlo <- pmin(y$pctlo, env$pctlo, na.rm = FALSE)
    y$compctup <- pmax(y$pctup, env$pctup, na.rm = FALSE)
  }
  m$bounds <- attr(now, "bounds")
  attr(y, "yoy") <- m
  y
}
