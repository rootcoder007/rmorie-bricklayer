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
#' could have produced it, so [change_envelope()]
#' and [yoy_bounds()] can
#' carry the interval through a difference, a percent change or a rate.
#'
#' @details
#' For a published value \eqn{v} rounded to base \eqn{b}: with
#' \code{rounding_kind = "nearest"} the observed count lies in
#' \eqn{[\max(0, v - b/2), v + b/2]}; with \code{"random"} (unbiased random
#' rounding, where a count is moved to one of the two neighbouring multiples)
#' it lies in \eqn{[\max(0, v - (b - 1)), v + (b - 1)]}. The bounds are not
#' rounded to whole numbers. A suppressed cell lies in \eqn{[0, k - 1]}, with
#' \eqn{k} from \code{"<k"} or from \code{suppression_limit}; rounding is
#' not applied to it. Without \code{rounding}, a published number is taken as
#' exact (lower = upper = value).
#'
#' Text cells are trimmed, and thousands separators (commas) are removed
#' before they are read as numbers. A missing value (\code{NA}) that is not a
#' suppression mark gets status \code{"missing"} and \code{NA} bounds.
#'
#' Errors: \code{rounding} not a positive number; an unknown
#' \code{rounding_kind}; a text cell that is neither a number nor a
#' suppression mark (the message lists the cells); a suppressed cell with no
#' limit (neither \code{"<k"} nor \code{suppression_limit}).
#'
#' @param x Published values: a numeric vector, or a character vector (or
#'   factor) in which suppressed cells appear as one of
#'   \code{suppressed_marks} or as \code{"<k"} for a limit \code{k}.
#' @param rounding Numeric scalar, the base the release rounds to
#'   (\code{5}, \code{10}, ...), or \code{NULL} (the default) when the
#'   counts are exact.
#' @param rounding_kind `"nearest"` (the printed value is the observed
#'   value rounded to the nearest multiple of `rounding`, so the
#'   observed value lies within half a base) or `"random"` (Statistics
#'   Canada's random rounding, where the observed value lies within
#'   `rounding - 1`).
#' @param suppression_limit Numeric scalar or \code{NULL} (the default). For
#'   a cell printed as suppressed with no explicit limit, the smallest count
#'   that would have been published: the cell then lies in
#'   \code{[0, suppression_limit - 1]}.
#' @param suppressed_marks Character vector of the strings that mark a
#'   suppressed cell, matched exactly after trimming. Default
#'   \code{c("x", "X", "s", "..", "F", "suppressed", "n/a")}.
#' @return A data frame of class \code{c("rmbl_bounds", "data.frame")}, one
#'   row per cell, with \code{value} (numeric, the published number,
#'   \code{NA} for a suppressed cell), \code{lower} and \code{upper}
#'   (numeric, the interval of observed counts) and \code{status}
#'   (character: \code{"exact"}, \code{"rounded"}, \code{"suppressed"}, or
#'   \code{"missing"} for an \code{NA} that carried no suppression mark).
#'   Attribute \code{"bounds"} records \code{rounding},
#'   \code{rounding_kind} and \code{suppression_limit}. \code{plot()} draws
#'   each value inside its interval.
#' @examples
#' published_bounds(c(120, 35, 0), rounding = 5)
#' published_bounds(c("120", "x", "<5"), rounding = 5,
#'                  suppression_limit = 5)
#' # random rounding to base 5 is wider than rounding to the nearest 5
#' published_bounds(15, rounding = 5, rounding_kind = "random")
#'
#' # thousands separators and a custom suppression mark
#' published_bounds(c("1,200", "--", "<10"), suppression_limit = 10,
#'                  suppressed_marks = "--")
#'
#' # a suppressed cell needs a limit
#' try(published_bounds(c("120", "x")))
#' @seealso [change_envelope()],
#'   [yoy_bounds()]
#' @export
published_bounds <- function(x, rounding = NULL,
                             rounding_kind = c("nearest", "random"),
                             suppression_limit = NULL,
                             suppressed_marks = c("x", "X", "s", "..",
                                                  "F", "suppressed",
                                                  "n/a")) {
  rounding_kind <- .rmbl_arg(rounding_kind)
  if (!is.null(rounding)) {
    rounding <- .rmbl_num(rounding, "rounding")[1L]
    if (is.na(rounding) || rounding <= 0) {
      stop("`rounding` must be a positive number", call. = FALSE)
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
    marked <- s %in% suppressed_marks
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
  if (!is.null(rounding)) {
    half <- if (rounding_kind == "nearest") rounding / 2 else rounding - 1
    r <- status == "exact" & !is.na(value)
    lower[r] <- pmax(0, value[r] - half)
    upper[r] <- value[r] + half
    status[r] <- "rounded"
  }
  sup <- status == "suppressed"
  if (any(sup)) {
    lim <- ifelse(is.na(limit[sup]), suppression_limit %||% NA_real_,
                  limit[sup])
    if (anyNA(lim)) {
      stop(paste0("a suppressed cell has no limit: give `suppression_limit` ",
                  "or write the cell as \"<k\""), call. = FALSE)
    }
    lower[sup] <- 0
    upper[sup] <- lim - 1
    value[sup] <- NA_real_
  }
  structure(data.frame(value = value, lower = lower, upper = upper,
                       status = status, stringsAsFactors = FALSE),
            class = c("rmbl_bounds", "data.frame"),
            bounds = list(rounding = rounding, rounding_kind = rounding_kind,
                          suppression_limit = suppression_limit))
}

#' Envelope of a difference, a percent change or a rate under
#' publication bounds
#'
#' Given the intervals from [published_bounds()]
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
#' Errors when \code{now} and \code{previous} have different numbers of
#' rows. The populations are not checked; give one per row (or one value).
#'
#' @param now,previous \code{rmbl_bounds} objects from
#'   [published_bounds()] (or data frames with numeric
#'   \code{lower} and
#'   \code{upper}) for the current and the earlier cell, with the same number
#'   of rows.
#' @param population,previous_population Optional numeric exposures (for
#'   example residents) for a rate envelope of the current and the previous
#'   cell; the rate is \code{per * count / population}. Default \code{NULL}.
#'   \code{previous_population} is used only with \code{population}.
#' @param per Numeric scalar, the rate base when exposures are given; default
#'   \code{1000} (per 1,000).
#' @return A data frame, one row per cell, with numeric columns
#'   \code{change_lower}, \code{change_upper}, \code{pct_lower},
#'   \code{pct_upper} (\code{NA} where the previous cell could have been
#'   zero); with \code{population} also \code{rate_lower} and
#'   \code{rate_upper}; with \code{previous_population} as well
#'   \code{previous_rate_lower} and \code{previous_rate_upper}.
#' @seealso [published_bounds()],
#'   [yoy_bounds()].
#' @examples
#' now <- published_bounds(c(45, 120), rounding = 5)
#' prev <- published_bounds(c(40, 100), rounding = 5)
#' change_envelope(now, prev)
#'
#' # with rates per 1,000 residents in both years
#' change_envelope(now, prev, population = c(10000, 20000),
#'                 previous_population = c(10000, 19000))
#'
#' # a suppressed previous cell could have been zero: no upper percentage
#' change_envelope(published_bounds(12), published_bounds("<5"))
#'
#' # the two sides must line up
#' try(change_envelope(now, prev[1, ]))
#' @export
change_envelope <- function(now, previous, population = NULL,
                            previous_population = NULL, per = 1000) {
  for (nm in c("now", "previous")) {
    v <- get(nm)
    if (!is.data.frame(v) || !all(c("lower", "upper") %in% names(v))) {
      stop(sprintf("`%s` must be a data frame from published_bounds() (columns lower and upper)", nm),
           call. = FALSE)
    }
  }
  if (nrow(now) != nrow(previous)) {
    stop("`now` and `previous` must have the same number of rows",
         call. = FALSE)
  }
  out <- data.frame(change_lower = now$lower - previous$upper,
                    change_upper = now$upper - previous$lower)
  pl <- ifelse(previous$upper > 0,
               100 * (now$lower / previous$upper - 1), NA_real_)
  pu <- ifelse(previous$lower > 0,
               100 * (now$upper / previous$lower - 1), NA_real_)
  out$pct_lower <- pl
  out$pct_upper <- pu
  if (!is.null(population)) {
    out$rate_lower <- per * now$lower / population
    out$rate_upper <- per * now$upper / population
    if (!is.null(previous_population)) {
      out$previous_rate_lower <- per * previous$lower / previous_population
      out$previous_rate_upper <- per * previous$upper / previous_population
    }
  }
  out
}

#' Add publication bounds to a year-over-year table
#'
#' [yoy()] gives an exact conditional-binomial interval for the percent
#' change of a count, which covers sampling variation. This adds the
#' interval that rounding and suppression in the published cells imply
#' ([published_bounds()] carried through
#' [change_envelope()]), and a
#' combined interval that is the union of the two, which is the honest
#' range for a figure read off a rounded table.
#'
#' @details
#' The \code{value} and \code{previous} columns of \code{y} are passed to
#' [published_bounds()] with the same rounding and
#' suppression settings, and
#' the two intervals to [change_envelope()]. The combined
#' interval is the
#' smallest interval that contains both the sampling interval
#' (\code{pct_lower}, \code{pct_upper}) and the publication envelope: its
#' lower end is the smaller of the two lower ends, its upper end the larger of
#' the two upper ends. Where either is \code{NA} (the first period, or a
#' previous cell that could be zero) the combined end is \code{NA}. The
#' function does not check that \code{y} holds counts; publication bounds
#' make sense only for counts.
#'
#' Errors when \code{y} does not come from [yoy()], and for the reasons
#' [published_bounds()] gives.
#'
#' @param y An \code{rmbl_yoy} object from [yoy()], with counts as
#'   values.
#' @inheritParams published_bounds
#' @return \code{y} (still an \code{rmbl_yoy}) with added numeric columns
#'   \code{env_change_lower}, \code{env_change_upper},
#'   \code{env_pct_lower}, \code{env_pct_upper} and, when \code{y} has
#'   percent-change intervals, \code{combined_pct_lower} and
#'   \code{combined_pct_upper}. The rounding settings are recorded as
#'   \code{bounds} in the \code{"yoy"} attribute.
#' @seealso [published_bounds()],
#'   [change_envelope()], [yoy()].
#' @examples
#' seg <- data.frame(year = 2021:2023, n = c(40, 45, 60))
#' y <- yoy(seg, value = "n", period = "year")
#' yoy_bounds(y, rounding = 5)
#'
#' # random rounding to base 5 widens the envelope
#' yb <- yoy_bounds(y, rounding = 5, rounding_kind = "random")
#' as.data.frame(yb)[, c("year", "env_pct_lower", "env_pct_upper",
#'                       "combined_pct_lower", "combined_pct_upper")]
#'
#' # only yoy() results are accepted
#' try(yoy_bounds(seg, rounding = 5))
#' @export
yoy_bounds <- function(y, rounding = NULL,
                       rounding_kind = c("nearest", "random"),
                       suppression_limit = NULL) {
  if (!inherits(y, "rmbl_yoy")) {
    stop("`y` must come from yoy()", call. = FALSE)
  }
  rounding_kind <- .rmbl_arg(rounding_kind)
  m <- attr(y, "yoy")
  now <- published_bounds(y$value, rounding, rounding_kind,
                          suppression_limit)
  prev <- published_bounds(y$previous, rounding, rounding_kind,
                           suppression_limit)
  env <- change_envelope(now, prev)
  y$env_change_lower <- env$change_lower
  y$env_change_upper <- env$change_upper
  y$env_pct_lower <- env$pct_lower
  y$env_pct_upper <- env$pct_upper
  if (!is.null(y$pct_lower)) {
    y$combined_pct_lower <- pmin(y$pct_lower, env$pct_lower, na.rm = FALSE)
    y$combined_pct_upper <- pmax(y$pct_upper, env$pct_upper, na.rm = FALSE)
  }
  m$bounds <- attr(now, "bounds")
  attr(y, "yoy") <- m
  y
}
