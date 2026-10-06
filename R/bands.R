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
#' number ( `"3"`) , a closed range ( `"18 to 24"`,
#' `"18-24"`, `"18 - 24"`) , an open upper band ( `"50+"`,
#' `"Greater than 15"`, `"over 15"`, `"more than 15"`,
#' `"65 and over"`) , and an open lower band ( `"<18"`,
#' `"under 18"`, `"less than 18"`) .
#'
#' @param x Character labels.
#' @param closed_upper For an open upper band, whether
#' the stated number is included. `"50+"` includes 50;
#' `"Greater than 15"` does not, so its lower bound is 16 for integer
#' data. Controlled per-label by the wording, and this argument only
#' settles the ambiguous `"+"` form.
#' @param integer_scale Whether the quantity is
#' integer-valued, which decides whether `"greater than 15"` starts at
#' 16 or just above 15.
#' @return A data frame with `label`, `lower`, `upper`,
#' `open_lower` and `open_upper`. An unparseable label gives
#' `NA` bounds rather than a guess.
#' @seealso
#' [band_values()],
#' [band_sensitivity()]
#' @references
#' The forms recognised here are taken from the categories the Ontario
#' Ministry of the Solicitor General publishes in its inmate datasets (the
#' segregation and restrictive-confinement releases), where the
#' placement-count and age categories are banded and the top band is open.
#' @examples
#' parse_bands(c("1", "2 to 5", "6 to 10", "Greater than 10"))
#'
#' parse_bands(c("18 to 24", "25 to 49", "50+"))
#'
#' # An unrecognised label is reported as unparsed, not guessed at.
#' parse_bands(c("3", "unknown", "not stated"))
#' @export
parse_bands <- function(x, closed_upper = TRUE, integer_scale = TRUE) {
  if (!is.null(x) && !is.character(x) && !is.factor(x)) {
    stop("`x` must be character band labels", call. = FALSE)
  }
  lab <- as.character(x)
  s <- tolower(trimws(lab))
  # normalise the dash family, which publishers mix freely. Byte-wise, so
  # the en dash -- the commonest published separator -- parses in a C
  # locale too, where a UTF-8 pattern aborted the call.
  dashes <- .rmbl_dash_pattern()
  s <- gsub(dashes, "-", s, useBytes = TRUE, perl = TRUE)
  s <- gsub("\\s+", " ", s)
  # thousands separators ("1,000 to 2,499", the commonest published form):
  # only a correctly grouped number loses its commas; "12,34,567" is not
  # a number and stays as it is, so the label stays NA
  s <- vapply(s, function(z) {
    if (is.na(z)) return(z)
    m <- gregexpr("(?<![0-9,])[0-9]{1,3}(?:,[0-9]{3})+(?![0-9,])", z, perl = TRUE)[[1L]]
    if (m[1L] > 0) {
      toks <- regmatches(z, list(m))[[1L]]
      regmatches(z, list(m)) <- list(gsub(",", "", toks, fixed = TRUE))
    }
    z
  }, character(1), USE.NAMES = FALSE)
  n <- length(s)
  lower <- rep(NA_real_, n)
  upper <- rep(NA_real_, n)
  ol <- rep(FALSE, n)
  ou <- rep(FALSE, n)
  num <- function(z) suppressWarnings(as.numeric(z))
  cue_re <- "\\b(over|above|more|plus|under|less|below|fewer|greater|than|gt|lt)\\b"

  for (i in seq_len(n)) {
    z <- s[i]
    if (!nzchar(z) || is.na(z)) next
    # a label written with decimals is on a decimal scale whatever
    # `integer_scale` says: "under 0.5" is not "at most -0.5"
    step <- if (isTRUE(integer_scale) && !grepl("[0-9]\\.[0-9]", z)) 1 else 0
    # "18 to 24", "ages 18-24", "18 to 24 (years)", "0 to 5 overnight
    # stays". The two numbers must be the only digits in the label:
    # "100-200-300" has no reading, and "15 to 19 and over" contradicts
    # itself, so both stay NA rather than parsing as the first two
    # numbers. A cue word (over, under, more ...) anywhere -- in the
    # leading word slot or the trailing unit -- is a contradiction too,
    # matched as a WORD: "overnight" is not "over". Inverted bounds
    # ("24 to 18") stay NA.
    m <- regmatches(z, regexec(paste0(
      "^([a-z]+ )?(-?[0-9]*\\.?[0-9]+) ?(?:to|-|through) ?",
      "(-?[0-9]*\\.?[0-9]+)([^0-9]*)$"), z))[[1L]]
    if (length(m) == 5L) {
      lo <- num(m[3L])
      up <- num(m[4L])
      cue <- grepl(cue_re, m[2L], perl = TRUE) || grepl(cue_re, m[5L], perl = TRUE) ||
        grepl("\\+", m[5L])
      if (!cue && !is.na(lo) && !is.na(up) && lo <= up) {
        lower[i] <- lo
        upper[i] <- up
      }
      next
    }
    # From here on a label names ONE bound. Two numbers that did not read
    # as a range above ("more than 10 - 20", "under 18 to 24") contradict
    # themselves and stay NA rather than yielding the first number.
    nums <- regmatches(z, gregexpr("-?[0-9]*\\.?[0-9]+", z))[[1L]]
    if (length(nums) != 1L) next
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
    # a bare number is a band of width zero; a bare "-5" is not (a
    # suppressed cell, or a range missing its first bound) and stays NA
    if (grepl("^[0-9]*\\.?[0-9]+$", z)) {
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
#' midpoint, so a cap has to be supplied or assumed, and the assumption is
#' recorded in the result rather than absorbed into it.
#'
#' @param bands A data frame from
#' [parse_bands()], or labels to parse.
#' @param rule How to place a value inside a closed band.
#' `"midpoint"` is the arithmetic mean of the bounds. `"lower"`
#' and `"upper"` give the conservative and generous readings, which
#' together bracket whatever the truth is. `"geometric"` suits a
#' quantity whose distribution inside the band is closer to log-uniform
#' than uniform, which is usual for counts and durations.
#' @param open_upper_cap Upper bound to assume for an
#' open top band. The default multiplies the band's lower bound by
#' `open_upper_factor`, which is an assumption and is flagged as one.
#' @param open_upper_factor Multiplier used when no
#' cap is given.
#' @param open_lower_floor Lower bound assumed for an open lower band
#'   ("under 18"). `NULL`, the default, uses 0, or the band's own upper
#'   bound when that is below 0; an explicit floor above a band's upper
#'   bound is refused.
#' for an open bottom band. Defaults to zero.
#' @return The band table with a `value` column and an `assumed`
#' column marking the rows whose value rests on the open-band assumption.
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
                        open_lower_floor = NULL) {
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
    if (any(hi[bands$open_upper] < lo[bands$open_upper], na.rm = TRUE)) {
      stop(sprintf(paste0("the open-band cap (%s) lies below the band's own ",
                          "lower bound (%s); a midpoint there would be below ",
                          "every value in the band"),
                   format(min(hi[bands$open_upper], na.rm = TRUE)),
                   format(max(lo[bands$open_upper], na.rm = TRUE))),
           call. = FALSE)
    }
  }
  if (any(bands$open_lower)) {
    # the mirror of the cap above: a floor above the band's own upper bound
    # would put the midpoint outside the band. The default floor is 0, or
    # the band's upper bound when that is lower ("under 0").
    floor_v <- if (is.null(open_lower_floor)) {
      pmin(0, hi[bands$open_lower])
    } else {
      rep(as.numeric(open_lower_floor)[1L], sum(bands$open_lower))
    }
    if (any(floor_v > hi[bands$open_lower], na.rm = TRUE)) {
      stop(sprintf(paste0("the open-band floor (%s) lies above the band's own ",
                          "upper bound (%s); a midpoint there would be above ",
                          "every value in the band"),
                   format(max(floor_v, na.rm = TRUE)),
                   format(min(hi[bands$open_lower], na.rm = TRUE))),
           call. = FALSE)
    }
    lo[bands$open_lower] <- floor_v
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
#' banded data carries this dependence; the only question is whether it was
#' measured.
#'
#' @param bands A data frame from
#' [parse_bands()], or labels to parse.
#' @param counts How many units fall in each band.
#' @param statistic A function of a numeric vector of
#' per-unit values. Defaults to [gini()].
#' @param caps Caps to try for the open top band. Defaults to a
#' geometric sweep from the band's lower bound to twenty times it.
#' @param rule Passed to
#' [band_values()].
#' @return A data frame of `cap` and `value`, with the span and
#' the relative span attached as attributes and printed by `print()`.
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
  counts <- .rmbl_num(counts, "counts")
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
  sp <- attr(x, "span", exact = TRUE)
  rel <- attr(x, "relative_span", exact = TRUE)
  footer <- paste0("span over the caps tried: ", format(sp, digits = 4L),
                   if (!is.na(rel)) paste0(" (", format(100 * rel, digits = 3L),
                                           "% of the typical value)") else "")
  if (!is.na(rel) && rel > 0.1) {
    footer <- c(footer,
      "The statistic moves by more than a tenth of itself across the",
      "caps tried, so it is a property of the assumption as much as",
      "of the data. Report the range, not a single figure.")
  }
  .rmbl_print_table("Sensitivity to the open top band's assumed cap",
                    as.data.frame(x), footer = footer, ...)
  invisible(x)
}

#' Expand a banded frequency table into per-unit values
#'
#' @param bands A data frame from
#' [parse_bands()], or labels to parse.
#' @param counts How many units fall in each band.
#' @param ... Passed to
#' [band_values()].
#' @param drop_unparsed A band whose label could not be parsed, yet which
#' has a count, is an error by default: every statistic computed from the
#' result would otherwise describe a fraction of the data in silence.
#' `TRUE` leaves those units out with a warning instead.
#' @return A numeric vector with one entry per unit.
#' @examples
#' x <- expand_bands(c("1", "2 to 5", "Greater than 5"),
#'                   counts = c(10, 4, 2), open_upper_cap = 12)
#' table(x)
#'
#' gini(x)
#' @export
expand_bands <- function(bands, counts, ..., drop_unparsed = FALSE) {
  if (!is.data.frame(bands)) bands <- parse_bands(bands)
  counts <- .rmbl_num(counts, "counts")
  if (length(counts) != nrow(bands)) {
    stop(sprintf("`counts` has %d entries for %d bands",
                 length(counts), nrow(bands)), call. = FALSE)
  }
  if (any(counts < 0, na.rm = TRUE)) {
    stop("`counts` must be non-negative", call. = FALSE)
  }
  bv <- band_values(bands, ...)
  lost <- is.na(bv$value) & !is.na(counts) & counts > 0
  if (any(lost)) {
    msg <- sprintf("%s unit(s) in %d band(s) could not be placed: %s",
                   format(sum(counts[lost])), sum(lost),
                   paste(sprintf("'%s'", bands$label[lost]), collapse = ", "))
    if (!isTRUE(drop_unparsed)) {
      stop(msg, " (set drop_unparsed = TRUE to leave them out)",
           call. = FALSE)
    }
    warning(msg, call. = FALSE)
  }
  keep <- !is.na(bv$value) & !is.na(counts)
  rep(bv$value[keep], times = round(counts[keep]))
}


# U+2010..U+2015 and U+2212 as a byte-wise alternation, built from raw bytes
# and marked "bytes": a string literal with those bytes is translated to the
# native encoding when it is pasted, and in a C locale that translation is
# a warning per call.
#' @noRd
.rmbl_dash_pattern <- function() {
  one <- function(...) rawToChar(as.raw(c(...)))
  parts <- c(one(0xe2, 0x80, 0x90), one(0xe2, 0x80, 0x91), one(0xe2, 0x80, 0x92),
             one(0xe2, 0x80, 0x93), one(0xe2, 0x80, 0x94), one(0xe2, 0x80, 0x95),
             one(0xe2, 0x88, 0x92))
  out <- rawToChar(do.call(c, c(lapply(parts[-length(parts)], function(p) c(charToRaw(p), charToRaw("|"))),
                                 list(charToRaw(parts[length(parts)])))))
  Encoding(out) <- "bytes"
  out
}
