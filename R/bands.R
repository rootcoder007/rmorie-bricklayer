# Banded categories.
#
# Published administrative tables report intervals, not values:
# "18 to 24", "2 to 5", "50+", "Greater than 15 days". Anything computed
# from them rests on an assumption about where inside each band the mass
# sits, and on a second assumption about where the open top band ends.
# Both assumptions are usually made silently, by taking a midpoint, and
# the open band has no midpoint to take.
#
# So: parse to BOUNDS, make the representative-value rule explicit, and
# provide the sensitivity of whatever was computed to the open band's
# assumed cap. A concentration measure that swings from 0.42 to 0.71 as
# the cap moves from 20 to 200 has not been measured.

#' Parse banded category labels into numeric bounds
#'
#' Recognises the forms that open-data publishers actually use: a bare
#' number (`"3"`), a closed range (`"18 to 24"`, `"18-24"`,
#' `"18 - 24"`), an open upper band (`"50+"`, `"Greater than 15"`,
#' `"over 15"`, `"more than 15"`, `"65 and over"`), and an open lower
#' band (`"<18"`, `"under 18"`, `"less than 18"`).
#'
#' @param x Character labels.
#' @param closed_upper For an open upper band, whether the stated number
#'   is included. `"50+"` includes 50; `"Greater than 15"` does not, so
#'   its lower bound is 16 for integer data. Controlled per-label by the
#'   wording, and this argument only settles the ambiguous `"+"` form.
#' @param integer_scale Whether the quantity is integer-valued, which
#'   decides whether `"greater than 15"` starts at 16 or just above 15.
#' @return A data frame with `label`, `lower`, `upper`, `open_lower` and
#'   `open_upper`. An unparseable label gives `NA` bounds rather than a
#'   guess.
#' @seealso [band_values()], [band_sensitivity()]
#' @references
#' The forms recognised here are taken from the categories the Ontario
#' Ministry of the Solicitor General publishes in its inmate datasets
#' (the segregation and restrictive-confinement releases), where the
#' placement-count and age categories are banded and the top band is
#' open.
#' @examples
#' parse_bands(c("1", "2 to 5", "6 to 10", "Greater than 10"))
#'
#' parse_bands(c("18 to 24", "25 to 49", "50+"))
#'
#' # An unrecognised label is reported as unparsed, not guessed at.
#' parse_bands(c("3", "unknown", "not stated"))
#' @export
parse_bands <- function(x, closed_upper = TRUE, integer_scale = TRUE) {
  lab <- as.character(x)
  s <- tolower(trimws(lab))
  # normalise the dash family, which publishers mix freely
  s <- gsub("[\u2010\u2011\u2012\u2013\u2014\u2015]", "-", s)
  s <- gsub("\\s+", " ", s)
  n <- length(s)
  lower <- rep(NA_real_, n)
  upper <- rep(NA_real_, n)
  ol <- rep(FALSE, n)
  ou <- rep(FALSE, n)
  num <- function(z) suppressWarnings(as.numeric(z))
  step <- if (isTRUE(integer_scale)) 1 else 0

  for (i in seq_len(n)) {
    z <- s[i]
    if (!nzchar(z) || is.na(z)) next
    m <- regmatches(z, regexec(
      "^(-?[0-9]*\\.?[0-9]+)\\s*(?:to|-|through)\\s*(-?[0-9]*\\.?[0-9]+)", z))[[1L]]
    if (length(m) == 3L) {
      lower[i] <- num(m[2L])
      upper[i] <- num(m[3L])
      next
    }
    # An open UPPER band. The INCLUSIVE wordings go first: "65 and
    # over" includes 65, and the bare "over" in the exclusive pattern
    # below matches it too, which moved the bound by a whole unit of
    # the quantity being measured.
    if (grepl("(\\+\\s*$|and over|and above|or more|or over|plus\\s*$)", z)) {
      v <- num(regmatches(z, regexpr("-?[0-9]*\\.?[0-9]+", z)))
      if (length(v) && !is.na(v)) {
        lower[i] <- if (isTRUE(closed_upper)) v else v + step
        ou[i] <- TRUE
      }
      next
    }
    # and the exclusive wordings, which start one unit higher
    if (grepl("(greater than|more than|over|above|\\bgt\\b)", z)) {
      v <- num(regmatches(z, regexpr("-?[0-9]*\\.?[0-9]+", z)))
      if (length(v) && !is.na(v)) {
        lower[i] <- v + step
        ou[i] <- TRUE
      }
      next
    }
    # An open LOWER band, inclusive wordings first for the same reason:
    # "17 and under" includes 17, and the bare "under" below matches it.
    if (grepl("(or less|or fewer|and under|and below|or under)", z)) {
      v <- num(regmatches(z, regexpr("-?[0-9]*\\.?[0-9]+", z)))
      if (length(v) && !is.na(v)) {
        upper[i] <- v
        ol[i] <- TRUE
      }
      next
    }
    if (grepl("(less than|fewer than|under|below|^<|\\blt\\b)", z)) {
      v <- num(regmatches(z, regexpr("-?[0-9]*\\.?[0-9]+", z)))
      if (length(v) && !is.na(v)) {
        upper[i] <- v - step
        ol[i] <- TRUE
      }
      next
    }
    # a bare number is a band of width zero
    if (grepl("^-?[0-9]*\\.?[0-9]+$", z)) {
      lower[i] <- num(z)
      upper[i] <- lower[i]
      next
    }
  }
  data.frame(label = lab, lower = lower, upper = upper,
             open_lower = ol, open_upper = ou,
             stringsAsFactors = FALSE)
}

#' Representative values for banded categories
#'
#' Turns bounds into the single number per band that a calculation needs,
#' under a stated rule. The open band is the whole difficulty: it has no
#' midpoint, so a cap has to be supplied or assumed, and the assumption
#' is recorded in the result rather than absorbed into it.
#'
#' @param bands A data frame from [parse_bands()], or labels to parse.
#' @param rule How to place a value inside a closed band. `"midpoint"`
#'   is the arithmetic mean of the bounds. `"lower"` and `"upper"` give
#'   the conservative and generous readings, which together bracket
#'   whatever the truth is. `"geometric"` suits a quantity whose
#'   distribution inside the band is closer to log-uniform than uniform,
#'   which is usual for counts and durations.
#' @param open_upper_cap Upper bound to assume for an open top band. The
#'   default multiplies the band's lower bound by `open_upper_factor`,
#'   which is an assumption and is flagged as one.
#' @param open_upper_factor Multiplier used when no cap is given.
#' @param open_lower_floor Lower bound to assume for an open bottom
#'   band. Defaults to zero.
#' @return The band table with a `value` column and an `assumed` column
#'   marking the rows whose value rests on the open-band assumption.
#' @seealso [band_sensitivity()]
#' @examples
#' b <- parse_bands(c("1", "2 to 5", "6 to 10", "Greater than 10"))
#'
#' band_values(b)
#'
#' # The lower and upper rules bracket the truth.
#' band_values(b, rule = "lower")$value
#' band_values(b, rule = "upper", open_upper_cap = 40)$value
#' @export
band_values <- function(bands, rule = c("midpoint", "lower", "upper",
                                        "geometric"),
                        open_upper_cap = NULL, open_upper_factor = 2,
                        open_lower_floor = 0) {
  rule <- match.arg(rule)
  if (!is.data.frame(bands)) bands <- parse_bands(bands)
  need <- c("lower", "upper", "open_lower", "open_upper")
  if (!all(need %in% names(bands))) {
    stop("`bands` must come from parse_bands()", call. = FALSE)
  }
  lo <- bands$lower
  hi <- bands$upper
  assumed <- bands$open_upper | bands$open_lower
  # an open band's missing side is filled from the assumption, which is
  # then reported
  if (any(bands$open_upper)) {
    cap <- if (is.null(open_upper_cap)) {
      lo[bands$open_upper] * open_upper_factor
    } else {
      rep(as.numeric(open_upper_cap)[1L], sum(bands$open_upper))
    }
    hi[bands$open_upper] <- cap
  }
  if (any(bands$open_lower)) {
    lo[bands$open_lower] <- as.numeric(open_lower_floor)[1L]
  }
  value <- switch(rule,
    lower = lo,
    upper = hi,
    midpoint = (lo + hi) / 2,
    geometric = {
      # the geometric mean is undefined at or below zero, so a band
      # touching zero falls back to the arithmetic midpoint rather than
      # returning NaN
      g <- sqrt(lo * hi)
      bad <- !is.finite(g) | lo <= 0
      g[bad] <- ((lo + hi) / 2)[bad]
      g
    })
  out <- bands
  out$value <- value
  out$assumed <- assumed
  out
}

#' How much a result depends on the open band's assumed cap
#'
#' Recomputes a statistic across a range of assumed caps for the open top
#' band and reports how far the answer moves. Everything derived from
#' banded data carries this dependence; the only question is whether it
#' was measured.
#'
#' @param bands A data frame from [parse_bands()], or labels to parse.
#' @param counts How many units fall in each band.
#' @param statistic A function of a numeric vector of per-unit values.
#'   Defaults to [gini()].
#' @param caps Caps to try for the open top band. Defaults to a
#'   geometric sweep from the band's lower bound to twenty times it.
#' @param rule Passed to [band_values()].
#' @return A data frame of `cap` and `value`, with the span and the
#'   relative span attached as attributes and printed by
#'   `print()`.
#' @examples
#' b <- parse_bands(c("1", "2 to 5", "6 to 10", "Greater than 10"))
#' counts <- c(1200, 430, 110, 38)
#'
#' s <- band_sensitivity(b, counts)
#' s
#'
#' # A statistic that barely moves has been measured; one that swings
#' # has not.
#' band_sensitivity(b, counts, statistic = mean)
#' @export
band_sensitivity <- function(bands, counts, statistic = gini, caps = NULL,
                             rule = "midpoint") {
  if (!is.data.frame(bands)) bands <- parse_bands(bands)
  counts <- as.numeric(counts)
  if (length(counts) != nrow(bands)) {
    stop(sprintf("`counts` has %d entries for %d bands",
                 length(counts), nrow(bands)), call. = FALSE)
  }
  if (!any(bands$open_upper)) {
    stop(paste0("no open upper band, so there is nothing to be ",
                "sensitive to"), call. = FALSE)
  }
  base <- min(bands$lower[bands$open_upper], na.rm = TRUE)
  if (is.null(caps)) {
    caps <- unique(round(base * exp(seq(log(1.05), log(20),
                                        length.out = 12L)), 6L))
  }
  caps <- sort(unique(as.numeric(caps)))
  vals <- vapply(caps, function(cp) {
    bv <- band_values(bands, rule = rule, open_upper_cap = cp)
    x <- rep(bv$value, times = counts)
    out <- suppressWarnings(statistic(x))
    if (length(out) != 1L) NA_real_ else as.numeric(out)
  }, 0)
  fin <- vals[is.finite(vals)]
  span <- if (length(fin)) max(fin) - min(fin) else NA_real_
  rel <- if (length(fin) && min(abs(fin)) > 0) {
    span / stats::median(abs(fin))
  } else {
    NA_real_
  }
  structure(data.frame(cap = caps, value = vals),
            class = c("rmbl_band_sensitivity", "data.frame"),
            span = span, relative_span = rel, base = base)
}

#' @param x An `rmbl_band_sensitivity` object.
#' @param ... Ignored.
#' @rdname band_sensitivity
#' @export
print.rmbl_band_sensitivity <- function(x, ...) {
  cat("Sensitivity to the open top band's assumed cap\n\n")
  print(as.data.frame(x), row.names = FALSE)
  sp <- attr(x, "span", exact = TRUE)
  rel <- attr(x, "relative_span", exact = TRUE)
  cat("\nspan over the caps tried: ", format(sp, digits = 4L), sep = "")
  if (!is.na(rel)) {
    cat(" (", format(100 * rel, digits = 3L),
        "% of the typical value)", sep = "")
  }
  cat("\n")
  if (!is.na(rel) && rel > 0.1) {
    cat("The statistic moves by more than a tenth of itself across the\n",
        "caps tried, so it is a property of the assumption as much as\n",
        "of the data. Report the range, not a single figure.\n", sep = "")
  }
  invisible(x)
}

#' Expand a banded frequency table into per-unit values
#'
#' @param bands A data frame from [parse_bands()], or labels to parse.
#' @param counts How many units fall in each band.
#' @param ... Passed to [band_values()].
#' @return A numeric vector with one entry per unit.
#' @examples
#' x <- expand_bands(c("1", "2 to 5", "Greater than 5"),
#'                   counts = c(10, 4, 2), open_upper_cap = 12)
#' table(x)
#'
#' gini(x)
#' @export
expand_bands <- function(bands, counts, ...) {
  if (!is.data.frame(bands)) bands <- parse_bands(bands)
  counts <- as.numeric(counts)
  if (length(counts) != nrow(bands)) {
    stop(sprintf("`counts` has %d entries for %d bands",
                 length(counts), nrow(bands)), call. = FALSE)
  }
  if (any(counts < 0, na.rm = TRUE)) {
    stop("`counts` must be non-negative", call. = FALSE)
  }
  bv <- band_values(bands, ...)
  keep <- !is.na(bv$value) & !is.na(counts)
  rep(bv$value[keep], times = round(counts[keep]))
}
