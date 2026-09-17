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
#' @param x Published values: a numeric vector, or a character vector in
#'   which suppressed cells appear as one of `suppressed_marks` or as
#'   `"<k"` for a limit `k`.
#' @param rounding The base the release rounds to (`5`, `10`, ...), or
#'   `NULL` when the counts are exact.
#' @param rounding_kind `"nearest"` (the printed value is the observed
#'   value rounded to the nearest multiple of `rounding`, so the
#'   observed value lies within half a base) or `"random"` (Statistics
#'   Canada's random rounding, where the observed value lies within
#'   `rounding - 1`).
#' @param suppression_limit For a cell printed as suppressed with no
#'   explicit limit, the smallest count that would have been published:
#'   the cell then lies in `[0, suppression_limit - 1]`.
#' @param suppressed_marks Strings that mark a suppressed cell.
#' @return A data frame of class `rmbl_bounds` with `value` (the
#'   published number, `NA` for a suppressed cell), `lower`, `upper` and
#'   `status` (`"exact"`, `"rounded"` or `"suppressed"`).
#' @examples
#' published_bounds(c(120, 35, 0), rounding = 5)
#' published_bounds(c("120", "x", "<5"), rounding = 5,
#'                  suppression_limit = 5)
#' # random rounding to base 5 is wider than rounding to the nearest 5
#' published_bounds(15, rounding = 5, rounding_kind = "random")
#' @seealso [change_envelope()], [yoy_bounds()]
#' @export
published_bounds <- function(x, rounding = NULL,
                             rounding_kind = c("nearest", "random"),
                             suppression_limit = NULL,
                             suppressed_marks = c("x", "X", "s", "..",
                                                  "F", "suppressed",
                                                  "n/a")) {
  rounding_kind <- match.arg(rounding_kind)
  if (!is.null(rounding)) {
    rounding <- as.numeric(rounding)[1L]
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
    value <- as.numeric(x)
  }
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
#' @param now,previous `rmbl_bounds` (or data frames with `lower` and
#'   `upper`) for the current and the earlier cell, of equal length.
#' @param population,previous_population Optional exposures for a rate
#'   envelope; the rate is `per * count / population`.
#' @param per Rate denominator when exposures are given.
#' @return A data frame with `change_lower`, `change_upper`,
#'   `pct_lower`, `pct_upper` (`NA` where the previous cell could have been
#'   zero) and, with exposures, `rate_lower`, `rate_upper`.
#' @examples
#' now <- published_bounds(c(45, 120), rounding = 5)
#' prev <- published_bounds(c(40, 100), rounding = 5)
#' change_envelope(now, prev)
#' @export
change_envelope <- function(now, previous, population = NULL,
                            previous_population = NULL, per = 1000) {
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
#' @param y An `rmbl_yoy` object with count units.
#' @inheritParams published_bounds
#' @return `y` with columns `env_change_lower`, `env_change_upper`,
#'   `env_pct_lower`, `env_pct_upper`, `combined_pct_lower`,
#'   `combined_pct_upper` and the rounding recorded in an attribute.
#' @examples
#' seg <- data.frame(year = 2021:2023, n = c(40, 45, 60))
#' y <- yoy(seg, value = "n", period = "year")
#' yoy_bounds(y, rounding = 5)
#' @export
yoy_bounds <- function(y, rounding = NULL,
                       rounding_kind = c("nearest", "random"),
                       suppression_limit = NULL) {
  if (!inherits(y, "rmbl_yoy")) {
    stop("`y` must come from yoy()", call. = FALSE)
  }
  rounding_kind <- match.arg(rounding_kind)
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
