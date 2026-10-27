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
#' Errors: \code{rnd} not one positive finite number; a negative or
#' infinite count in \code{x}; an unknown
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
#' @examplesIf isTRUE(getOption("rmbl.examples"))
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
pubbnd <- function(
  x,
  rnd = NULL,
  rndkind = c("nearest", "random"),
  suplim = NULL,
  supmar = c("x", "X", "s", "..", "F", "suppressed", "n/a")
) {
  rndkind <- .rmbl_arg(rndkind)
  ck <- .pb_check_args(rnd, suplim, supmar)
  rnd <- ck$rnd
  suplim <- ck$suplim
  n <- length(x)
  if (is.character(x) || is.factor(x)) {
    rd <- .pb_read_text(x, supmar)
    value <- rd$value
    status <- rd$status
    limit <- rd$limit
  } else {
    value <- .rmbl_num(x, "x")
    status <- rep("exact", n)
    limit <- rep(NA_real_, n)
  }
  .pb_check_counts(value)
  status[is.na(value) & status != "suppressed"] <- "missing"
  rb <- .pb_round(value, status, rnd, rndkind)
  lower <- rb$lower
  upper <- rb$upper
  status <- rb$status
  sup <- status == "suppressed"
  if (any(sup)) {
    lim <- ifelse(is.na(limit[sup]), suplim %||% NA_real_, limit[sup])
    if (anyNA(lim)) {
      stop(
        "a suppressed cell has no limit: give `suplim` ",
        "or write the cell as \"<k\"",
        call. = FALSE
      )
    }
    lower[sup] <- 0
    upper[sup] <- lim - 1
    value[sup] <- NA_real_
  }
  structure(
    data.frame(
      value = value,
      lower = lower,
      upper = upper,
      status = status,
      stringsAsFactors = FALSE
    ),
    class = c("rmbl_bounds", "data.frame"),
    bounds = list(rounding = rnd, rndkind = rndkind, suppression_limit = suplim)
  )
}

#' @export
format.rmbl_bounds <- function(x, ...) {
  if (!all(c("value", "lower", "upper", "status") %in% names(x))) {
    return(utils::capture.output(print(as.data.frame(unclass(x)))))
  }
  b <- attr(x, "bounds")
  st <- table(factor(
    x$status,
    levels = c("exact", "rounded", "suppressed", "missing")
  ))
  d <- as.data.frame(unclass(x), stringsAsFactors = FALSE)
  attr(d, "bounds") <- NULL
  .rmbl_stat_block(
    "Publication bounds",
    facts = list(
      Cells = sprintf(
        "%d: %d exact, %d rounded, %d suppressed, %d missing",
        nrow(x),
        st[["exact"]],
        st[["rounded"]],
        st[["suppressed"]],
        st[["missing"]]
      ),
      Rounding = if (length(b$rounding)) {
        sprintf("to %s (%s)", toString(b$rounding), toString(b$rndkind))
      },
      `Suppression limit` = b$suppression_limit
    ),
    table = utils::head(d, 20L),
    reading = paste(
      "Each published number stands for the range of true counts that",
      "could have produced it; a later comparison has to hold across it."
    ),
    notes = if (nrow(x) > 20L) sprintf("... and %d more cells", nrow(x) - 20L)
  )
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
#' @examplesIf isTRUE(getOption("rmbl.examples"))
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
chgenv <- function(now, prev, pop = NULL, prepop = NULL, per = 1000) {
  .pb_check_bounds(now, "now")
  .pb_check_bounds(prev, "prev")
  if (nrow(now) != nrow(prev)) {
    stop("`now` and `prev` must have the same number of rows", call. = FALSE)
  }
  per <- .rmbl_scalar(per, "per", 1e-12)
  out <- data.frame(
    chglo = now$lower - prev$upper,
    chgup = now$upper - prev$lower
  )
  pl <- ifelse(prev$upper > 0, 100 * (now$lower / prev$upper - 1), NA_real_)
  pu <- ifelse(prev$lower > 0, 100 * (now$upper / prev$lower - 1), NA_real_)
  out$pctlo <- pl
  out$pctup <- pu
  per <- .rmbl_num(per, "per")
  pop <- .pb_exposure(pop, "pop", nrow(now))
  prepop <- .pb_exposure(prepop, "prepop", nrow(now))
  if (!is.null(pop)) {
    out$ratelo <- per * now$lower / pop
    out$rateup <- per * now$upper / pop
    if (!is.null(prepop)) {
      out$preratelo <- per * prev$lower / prepop
      out$prerateup <- per * prev$upper / prepop
    }
  }
  .rmbl_cls(out, "rmbl_change_bounds")
}

#' @export
format.rmbl_change_bounds <- function(x, digits = 4L, ...) {
  title <- "Change between published values"
  need <- c("chglo", "chgup", "pctlo", "pctup")
  fb <- .rmbl_df_fallback(x, title, need, digits)
  if (!is.null(fb)) {
    return(fb)
  }
  d <- .rmbl_plain(x)
  tb <- data.frame(cell = seq_len(nrow(d)))
  tb$change <- .rmbl_fmt_ci(d$chglo, d$chgup, digits)
  tb$`change %` <- .rmbl_fmt_ci(d$pctlo, d$pctup, digits)
  if (all(c("ratelo", "rateup") %in% names(d))) {
    tb$rate <- .rmbl_fmt_ci(d$ratelo, d$rateup, digits)
  }
  if (all(c("preratelo", "prerateup") %in% names(d))) {
    tb$`previous rate` <- .rmbl_fmt_ci(d$preratelo, d$prerateup, digits)
  }
  .rmbl_res_block(
    title,
    facts = list(
      Cells = nrow(d),
      `Certain rises` = sum(d$chglo > 0, na.rm = TRUE),
      `Certain falls` = sum(d$chgup < 0, na.rm = TRUE)
    ),
    tables = list(tb),
    reading = paste(
      "Each interval holds every change consistent with the two published",
      "(rounded or suppressed) values. An interval that spans 0 cannot tell",
      "a rise from a fall."
    ),
    digits = digits,
    maxrows = 40L
  )
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
#' @examplesIf isTRUE(getOption("rmbl.examples"))
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
yoybnd <- function(
  y,
  rnd = NULL,
  rndkind = c("nearest", "random"),
  suplim = NULL
) {
  if (!inherits(y, "rmbl_yoy")) {
    stop("yoybnd: `y` must come from yoy()", call. = FALSE)
  }
  rndkind <- .rmbl_arg(rndkind)
  m <- attr(y, "yoy")
  now <- pubbnd(y$value, rnd, rndkind, suplim)
  prev <- pubbnd(y$previous, rnd, rndkind, suplim)
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

#' pubbnd()'s rounding base, suppression limit and markers, checked.
#' @param rnd,suplim,supmar As for pubbnd().
#' @return A list: rnd and suplim.
#' @noRd
.pb_check_args <- function(rnd, suplim, supmar) {
  if (!is.null(suplim)) {
    suplim <- .rmbl_scalar(suplim, "suplim", 0)
  }
  if (!is.character(supmar) || anyNA(supmar)) {
    stop(
      "`supmar` must be the text markers of a suppressed cell",
      call. = FALSE
    )
  }
  if (!is.null(rnd)) {
    rnd <- .rmbl_num(rnd, "rnd")
    # one finite base: Inf gave infinite bounds, c(5, 10) was cut to 5
    if (length(rnd) != 1L || !is.finite(rnd) || rnd <= 0) {
      stop("`rnd` must be a positive number, one and finite", call. = FALSE)
    }
  }
  list(rnd = rnd, suplim = suplim)
}

#' pubbnd()'s published values must be counts.
#'
#' -10 gave the interval \[0, -7.5\], Inf an infinite one.
#' @param value The values read from `x`; NA is a missing cell.
#' @return NULL, invisibly.
#' @noRd
.pb_check_counts <- function(value) {
  if (any(!is.na(value) & (value < 0 | !is.finite(value)))) {
    stop("`x` must hold counts, finite and not negative", call. = FALSE)
  }
  invisible(NULL)
}

#' pubbnd()'s text cells read as numbers, suppression marks and limits.
#' @param x,supmar As for pubbnd(), `x` a character vector or factor.
#' @return A list: value, status and limit, one element per cell.
#' @noRd
.pb_read_text <- function(x, supmar) {
  n <- length(x)
  value <- rep(NA_real_, n)
  status <- rep("exact", n)
  limit <- rep(NA_real_, n)
  s <- trimws(as.character(x))
  lt <- grepl("^<\\s*[0-9]+$", s)
  limit[lt] <- as.numeric(sub("^<\\s*", "", s[lt]))
  marked <- s %in% supmar
  status[lt | marked] <- "suppressed"
  num <- !(lt | marked) & !is.na(s)
  value[num] <- suppressWarnings(as.numeric(gsub(
    ",",
    "",
    s[num],
    fixed = TRUE
  )))
  bad <- num & is.na(value)
  if (any(bad)) {
    stop(
      sprintf(
        paste0(
          "cannot read these cells as numbers or ",
          "suppression marks: %s"
        ),
        toString(unique(s[bad]))
      ),
      call. = FALSE
    )
  }
  list(value = value, status = status, limit = limit)
}

#' chgenv()'s current or previous bounds, checked.
#' @param v The bounds.
#' @param nm Their argument's name.
#' @return NULL, invisibly.
#' @noRd
.pb_check_bounds <- function(v, nm) {
  if (!is.data.frame(v) || !all(c("lower", "upper") %in% names(v))) {
    stop(
      sprintf(
        "`%s` must be a data frame from pubbnd() (columns lower and upper)",
        nm
      ),
      call. = FALSE
    )
  }
  invisible(NULL)
}

#' chgenv()'s exposure for a rate, checked: one number or one per row.
#' @param v The exposure, or NULL.
#' @param nm Its argument's name.
#' @param nr The number of rows.
#' @return The exposure as numbers, or NULL.
#' @noRd
.pb_exposure <- function(v, nm, nr) {
  if (is.null(v)) {
    return(NULL)
  }
  v <- .rmbl_num(v, nm)
  if (!(length(v) %in% c(1L, nr))) {
    stop(
      sprintf("`%s` must be one number or one per row (%d)", nm, nr),
      call. = FALSE
    )
  }
  v
}

#' pubbnd()'s bounds of the cells published as rounded numbers.
#' @param value,status The cells' values and status.
#' @param rnd,rndkind As for pubbnd(), checked.
#' @return A list: lower, upper and status.
#' @noRd
.pb_round <- function(value, status, rnd, rndkind) {
  lower <- value
  upper <- value
  if (!is.null(rnd)) {
    half <- if (rndkind == "nearest") rnd / 2 else rnd - 1
    r <- status == "exact" & !is.na(value)
    lower[r] <- pmax(0, value[r] - half)
    upper[r] <- value[r] + half
    status[r] <- "rounded"
  }
  list(lower = lower, upper = upper, status = status)
}
