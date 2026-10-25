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
#' @description Published administrative tables often report intervals instead
#' of values: \dQuote{18 to 24}, \dQuote{2 to 5}, \code{"50+"}, \dQuote{Greater
#' than 15 days}. This function reads such labels into a lower and an upper
#' bound per band, and flags the bands that are open at the top or the bottom.
#' It recognises the wordings open-data publishers actually use, and leaves a
#' label it cannot read as \code{NA} rather than guessing. Use it as the first
#' step before \code{\link{bandvals}}, \code{\link{expbands}} or
#' \code{\link{bandsens}}.
#'
#' @details
#' Labels are lower-cased and trimmed; the Unicode dash family (U+2010 to
#' U+2015 and the minus sign U+2212) is read as a hyphen, and correctly
#' grouped thousands separators are removed (\code{"1,000 to 2,499"}). Then,
#' in order:
#' \itemize{
#'   \item \strong{Closed range}: two numbers joined by \code{to}, \code{-} or
#'     \code{through}, optionally preceded by one word and followed by a unit
#'     (\code{"ages 18-24"}, \code{"0 to 5 overnight stays"}). The two
#'     numbers must be the only numbers in the label, the lower must not
#'     exceed the upper, and no open-band cue word (over, under, more, less,
#'     plus, ...) or \code{+} may appear; otherwise the label is \code{NA}.
#'   \item \strong{Open upper band, inclusive}: \code{"50+"},
#'     \code{"65 and over"}, \code{"and above"}, \code{"or more"},
#'     \code{"or over"}, \code{"plus"}. The lower bound is the number when
#'     \code{clsup = TRUE}, and the number plus one step otherwise.
#'   \item \strong{Open upper band, exclusive}: \code{"greater than"},
#'     \code{"more than"}, \code{"over"}, \code{"above"}, \code{"gt"}. The
#'     lower bound is the number plus one step.
#'   \item \strong{Open lower band, inclusive}: \code{"17 and under"},
#'     \code{"or less"}, \code{"or fewer"}, \code{"and below"},
#'     \code{"or under"}. The upper bound is the number.
#'   \item \strong{Open lower band, exclusive}: \code{"less than"},
#'     \code{"fewer than"}, \code{"under"}, \code{"below"}, \code{"<"},
#'     \code{"lt"}. The upper bound is the number minus one step.
#'   \item \strong{Bare number}: a band of width zero. A bare negative
#'     number (\code{"-5"}) is read as a suppressed cell and stays \code{NA}.
#' }
#' The step is 1 when \code{intsca = TRUE} and the label has no
#' decimal point, and 0 otherwise. A label with more than one number that is
#' not a range, an empty label and \code{NA} all give \code{NA} bounds.
#' Anything other than a character or factor vector is an error.
#'
#' @param x Character vector (or factor) of band labels.
#' @param clsup Logical, default \code{TRUE}. For the inclusive
#'   open-upper wordings (\code{"+"}, \code{"and over"}, \code{"or more"} and
#'   the like), whether the stated number belongs to the band:
#'   \code{TRUE} reads \code{"50+"} as 50 and above, \code{FALSE} as above 50
#'   (lower bound 51 on an integer scale). The exclusive wordings
#'   (\code{"greater than 15"}) always exclude the number.
#' @param intsca Logical, default \code{TRUE}. Whether the quantity is
#'   integer-valued (counts, days, whole years). It decides whether
#'   \code{"greater than 15"} starts at 16 (\code{TRUE}) or at 15 as an
#'   infimum (\code{FALSE}). A label written with decimals is always treated
#'   as continuous.
#' @return A data frame with one row per label and columns \code{label}
#'   (character, as given), \code{lower} and \code{upper} (numeric bounds,
#'   \code{NA} for the open side of an open band or for an unparsed label),
#'   and \code{openlo}, \code{openup} (logical).
#' @seealso
#' \code{\link{bandvals}}, \code{\link{bandsens}},
#' \code{\link{expbands}}
#' @references
#' The forms recognised here are taken from the categories the Ontario
#' Ministry of the Solicitor General publishes in its inmate datasets (the
#' segregation and restrictive-confinement releases), where the
#' placement-count and age categories are banded and the top band is open.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' prsbands(c("1", "2 to 5", "6 to 10", "Greater than 10"))
#'
#' prsbands(c("18 to 24", "25 to 49", "50+", "under 18"))
#'
#' # "50+" excluding 50, and a continuous scale
#' prsbands(c("50+", "over 15"), clsup = FALSE)
#' prsbands(c("over 15", "under 0.5"), intsca = FALSE)
#'
#' # An unrecognised or self-contradictory label is NA, not guessed at.
#' prsbands(c("3", "unknown", "24 to 18", "15 to 19 and over"))
#'
#' try(prsbands(1:3))
#' @export
prsbands <- function(x, clsup = TRUE, intsca = TRUE) {
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
  s <- vapply(
    s,
    function(z) {
      if (is.na(z)) {
        return(z)
      }
      m <- gregexpr(
        "(?<![0-9,])[0-9]{1,3}(?:,[0-9]{3})+(?![0-9,])",
        z,
        perl = TRUE
      )[[1L]]
      if (m[1L] > 0) {
        toks <- regmatches(z, list(m))[[1L]]
        regmatches(z, list(m)) <- list(gsub(",", "", toks, fixed = TRUE))
      }
      z
    },
    character(1),
    USE.NAMES = FALSE
  )
  n <- length(s)
  lower <- rep(NA_real_, n)
  upper <- rep(NA_real_, n)
  ol <- rep(FALSE, n)
  ou <- rep(FALSE, n)
  num <- function(z) suppressWarnings(as.numeric(z))
  cue_re <- paste0(
    "\\b(over|above|more|plus|under|less|below|",
    "fewer|greater|than|gt|lt)\\b"
  )

  for (i in seq_len(n)) {
    z <- s[i]
    if (!nzchar(z) || is.na(z)) {
      next
    }
    # a label written with decimals is on a decimal scale whatever
    # `intsca` says: "under 0.5" is not "at most -0.5"
    step <- if (isTRUE(intsca) && !grepl("[0-9]\\.[0-9]", z)) 1 else 0
    # "18 to 24", "ages 18-24", "18 to 24 (years)", "0 to 5 overnight
    # stays". The two numbers must be the only digits in the label:
    # "100-200-300" has no reading, and "15 to 19 and over" contradicts
    # itself, so both stay NA rather than parsing as the first two
    # numbers. A cue word (over, under, more ...) anywhere -- in the
    # leading word slot or the trailing unit -- is a contradiction too,
    # matched as a WORD: "overnight" is not "over". Inverted bounds
    # ("24 to 18") stay NA.
    m <- regmatches(
      z,
      regexec(
        paste0(
          "^([a-z]+ )?(-?[0-9]*\\.?[0-9]+) ?(?:to|-|through) ?",
          "(-?[0-9]*\\.?[0-9]+)([^0-9]*)$"
        ),
        z
      )
    )[[1L]]
    if (length(m) == 5L) {
      lo <- num(m[3L])
      up <- num(m[4L])
      cue <- grepl(cue_re, m[2L], perl = TRUE) ||
        grepl(cue_re, m[5L], perl = TRUE) ||
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
    if (length(nums) != 1L) {
      next
    }
    # An open UPPER band. The INCLUSIVE wordings go first: "65 and
    # over" includes 65, and the bare "over" in the exclusive pattern
    # below matches it too, which moved the bound by a whole unit of
    # the quantity being measured.
    if (grepl("(\\+\\s*$|and over|and above|or more|or over|plus\\s*$)", z)) {
      v <- num(regmatches(z, regexpr("-?[0-9]*\\.?[0-9]+", z)))
      if (length(v) && !is.na(v)) {
        lower[i] <- if (isTRUE(clsup)) v else v + step
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
  data.frame(
    label = lab,
    lower = lower,
    upper = upper,
    openlo = ol,
    openup = ou,
    stringsAsFactors = FALSE
  )
}

#' Representative values for banded categories
#'
#' @description
#' Gives each band a single number that a calculation can use (a mean, a
#' concentration index, a regression), under a rule you choose. For closed
#' bands the rule places the value at the midpoint, the lower or upper
#' bound, or the geometric mean of the bounds. An open band (\code{"50+"},
#' \dQuote{under 18}) has no midpoint, so its missing bound is filled from an
#' explicit assumption, and the rows that rest on that assumption are
#' flagged in the result instead of being absorbed into it.
#'
#' @details
#' For a band with bounds \eqn{[l, u]} the value is \eqn{(l + u)/2}
#' (\code{"midpoint"}), \eqn{l} (\code{"lower"}), \eqn{u} (\code{"upper"}) or
#' \eqn{\sqrt{l u}} (\code{"geometric"}; when \eqn{l \le 0} the arithmetic
#' midpoint is used instead, because the geometric mean is undefined there).
#' The \code{"lower"} and \code{"upper"} rules bracket any value that could
#' come from the bands.
#'
#' An open upper band gets \eqn{u =} \code{openupcap} if given, else
#' \eqn{u = l \times} \code{openupfac}. An open lower band gets
#' \eqn{l =} \code{openloflr} if given, else \eqn{\min(0, u)}. A cap
#' below the band's lower bound, or a floor above its upper bound, is an
#' error, because the value would lie outside the band. Unparsed bands give
#' \code{NA}.
#'
#' Use \code{\link{bandsens}} to see how much a result moves with the
#' cap, and \code{\link{expbands}} to turn the values into one value per
#' unit.
#'
#' @param bands A data frame from \code{\link{prsbands}}, or a character
#'   vector of labels to parse with its defaults.
#' @param rule Character, one of \code{"midpoint"} (the default),
#'   \code{"lower"}, \code{"upper"} or \code{"geometric"}. The geometric
#'   mean suits quantities whose distribution inside a band is closer to
#'   log-uniform than uniform, which is usual for counts and durations.
#' @param openupcap Number or \code{NULL} (the default). The upper bound
#'   assumed for every open top band, in the units of the labels.
#' @param openupfac Number, default \code{2}. When no cap is given,
#'   the open top band's upper bound is its lower bound times this factor
#'   (so \dQuote{Greater than 10} becomes 11 to 22).
#' @param openloflr Number or \code{NULL} (the default). The lower bound assumed
#'   for an open bottom band (\dQuote{under 18}). \code{NULL} uses 0, or the
#'   band's own upper bound when that is below 0. A floor above a band's upper
#'   bound is refused.
#' @return The band table with two added columns: \code{value} (numeric, the
#'   representative value) and \code{assumed} (logical, \code{TRUE} for the
#'   open bands whose value rests on the cap or floor).
#' @seealso \code{\link{prsbands}}, \code{\link{bandsens}},
#'   \code{\link{expbands}}
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' b <- prsbands(c("1", "2 to 5", "6 to 10", "Greater than 10"))
#' bandvals(b)
#'
#' # The lower and upper rules bracket the truth.
#' bandvals(b, rule = "lower")$value
#' bandvals(b, rule = "upper", openupcap = 40)$value
#'
#' # geometric placement, and an explicit floor for an open bottom band
#' bandvals(b, rule = "geometric", openupcap = 40)$value
#' bandvals(c("under 5", "5 to 9", "10+"), openloflr = 1)
#'
#' # a cap inside the open band is refused
#' try(bandvals(b, openupcap = 5))
#' @export
bandvals <- function(
  bands,
  rule = c("midpoint", "lower", "upper", "geometric"),
  openupcap = NULL,
  openupfac = 2,
  openloflr = NULL
) {
  rule <- .rmbl_arg(rule)
  openupfac <- .rmbl_num(openupfac, "openupfac")
  if (length(openupfac) != 1L || !is.finite(openupfac) || openupfac <= 0) {
    stop("`openupfac` must be one positive number", call. = FALSE)
  }
  if (!is.data.frame(bands)) {
    bands <- prsbands(bands)
  }
  need <- c("lower", "upper", "openlo", "openup")
  if (!all(need %in% names(bands))) {
    stop("`bands` must come from prsbands()", call. = FALSE)
  }
  lo <- bands$lower
  hi <- bands$upper
  assumed <- bands$openup | bands$openlo
  # an open band's missing side is filled from the assumption, which is
  # then reported
  if (any(bands$openup)) {
    cap <- if (is.null(openupcap)) {
      lo[bands$openup] * openupfac
    } else {
      rep(.rmbl_num(openupcap, "openupcap")[1L], sum(bands$openup))
    }
    hi[bands$openup] <- cap
    if (any(hi[bands$openup] < lo[bands$openup], na.rm = TRUE)) {
      stop(
        sprintf(
          paste0(
            "the open-band cap (%s) lies below the band's own ",
            "lower bound (%s); a midpoint there would be below ",
            "every value in the band"
          ),
          format(min(hi[bands$openup], na.rm = TRUE)),
          format(max(lo[bands$openup], na.rm = TRUE))
        ),
        call. = FALSE
      )
    }
  }
  if (any(bands$openlo)) {
    # the mirror of the cap above: a floor above the band's own upper bound
    # would put the midpoint outside the band. The default floor is 0, or
    # the band's upper bound when that is lower ("under 0").
    floor_v <- if (is.null(openloflr)) {
      pmin(0, hi[bands$openlo])
    } else {
      rep(as.numeric(openloflr)[1L], sum(bands$openlo))
    }
    if (any(floor_v > hi[bands$openlo], na.rm = TRUE)) {
      stop(
        sprintf(
          paste0(
            "the open-band floor (%s) lies above the band's own ",
            "upper bound (%s); a midpoint there would be above ",
            "every value in the band"
          ),
          format(max(floor_v, na.rm = TRUE)),
          format(min(hi[bands$openlo], na.rm = TRUE))
        ),
        call. = FALSE
      )
    }
    lo[bands$openlo] <- floor_v
  }
  value <- switch(
    rule,
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
    }
  )
  out <- bands
  out$value <- value
  out$assumed <- assumed
  out
}

#' How much a result depends on the open band's assumed cap
#'
#' @description
#' Recomputes a statistic of banded data (by default the Gini coefficient)
#' for a range of assumed caps on the open top band, and reports how far the
#' answer moves. Every statistic computed from banded data depends on where
#' the open band is assumed to end; this function measures that dependence,
#' so you can report a range instead of a single figure when the dependence
#' is large.
#'
#' @details
#' Let \eqn{b} be the smallest lower bound among the open top bands. The
#' default caps are 12 points spaced evenly on the log scale from
#' \eqn{1.05 b} to \eqn{20 b}. For each cap \eqn{c},
#' \code{\link{bandvals}(bands, rule, openupcap = c)} gives one value
#' per band, each value is repeated \code{cnts} times, and
#' \code{stat} is applied to the result. A statistic that errors or
#' does not return a single number gives \code{NA}; warnings are suppressed.
#'
#' The span is \eqn{\max - \min} over the finite values and the relative span
#' is the span divided by the median absolute value (\code{NA} when any value
#' is zero). The print method adds a note when the relative span exceeds
#' 0.1.
#'
#' Errors: \code{cnts} not numeric or of a different length from the
#' bands; no open top band.
#'
#' @param bands A data frame from \code{\link{prsbands}}, or labels to
#'   parse.
#' @param cnts Numeric vector, one per band: how many units fall in each
#'   band. Non-integer counts are truncated by \code{rep()}.
#' @param stat A function that takes a numeric vector of per-unit
#'   values and returns one number. Default \code{\link{ginicoef}}.
#' @param caps Numeric vector of caps to try, in the units of the labels.
#'   Default \code{NULL}: the geometric sweep described in Details. Values are
#'   sorted and de-duplicated.
#' @param rule Character, default \code{"midpoint"}: the placement rule passed
#'   to \code{\link{bandvals}}.
#' @return A data frame of class \code{c("rmbl_band_sensitivity",
#'   "data.frame")} with numeric columns \code{cap} and \code{value}, and
#'   attributes \code{span}, \code{relspan} and \code{base} (the lower
#'   bound \eqn{b} of the open band).
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' b <- prsbands(c("1", "2 to 5", "6 to 10", "Greater than 10"))
#' counts <- c(1200, 430, 110, 38)
#'
#' s <- bandsens(b, counts)
#' s
#' attr(s, "relspan")
#'
#' # A statistic that barely moves has been measured; one that swings
#' # has not.
#' bandsens(b, counts, stat = mean, caps = c(12, 20, 50))
#'
#' # nothing to vary without an open band
#' try(bandsens(c("1", "2 to 5"), c(10, 4)))
#' @export
bandsens <- function(
  bands,
  cnts,
  stat = ginicoef,
  caps = NULL,
  rule = "midpoint"
) {
  if (!is.data.frame(bands)) {
    bands <- prsbands(bands)
  }
  cnts <- .rmbl_num(cnts, "cnts")
  if (length(cnts) != nrow(bands)) {
    stop(
      sprintf(
        "bandsens: `cnts` has %d entries for %d bands",
        length(cnts),
        nrow(bands)
      ),
      call. = FALSE
    )
  }
  if (!any(bands$openup)) {
    stop(
      paste0("no open upper band, so there is nothing to be ", "sensitive to"),
      call. = FALSE
    )
  }
  if (!is.function(stat)) {
    stop("`stat` must be a function of the band values", call. = FALSE)
  }
  base <- min(bands$lower[bands$openup], na.rm = TRUE)
  if (is.null(caps)) {
    caps <- unique(round(
      base * exp(seq(log(1.05), log(20), length.out = 12L)),
      6L
    ))
  }
  caps <- sort(unique(.rmbl_num(caps, "caps")))
  vals <- vapply(
    caps,
    function(cp) {
      bv <- bandvals(bands, rule = rule, openupcap = cp)
      x <- rep(bv$value, times = cnts)
      out <- suppressWarnings(stat(x))
      if (length(out) != 1L) NA_real_ else as.numeric(out)
    },
    0
  )
  fin <- vals[is.finite(vals)]
  span <- if (length(fin)) max(fin) - min(fin) else NA_real_
  rel <- if (length(fin) && min(abs(fin)) > 0) {
    span / stats::median(abs(fin))
  } else {
    NA_real_
  }
  structure(
    data.frame(cap = caps, value = vals),
    class = c("rmbl_band_sensitivity", "data.frame"),
    span = span,
    relspan = rel,
    base = base
  )
}

#' @param x An `rmbl_band_sensitivity` object.
#' @param ... Ignored.
#' @rdname bandsens
#' @export
print.rmbl_band_sensitivity <- function(x, ...) {
  sp <- attr(x, "span", exact = TRUE)
  rel <- attr(x, "relspan", exact = TRUE)
  footer <- paste0(
    "span over the caps tried: ",
    format(sp, digits = 4L),
    if (!is.na(rel)) {
      paste0(" (", format(100 * rel, digits = 3L), "% of the typical value)")
    } else {
      ""
    }
  )
  if (!is.na(rel) && rel > 0.1) {
    footer <- c(
      footer,
      "The statistic moves by more than a tenth of itself across the",
      "caps tried, so it is a property of the assumption as much as",
      "of the data. Report the range, not a single figure."
    )
  }
  .rmbl_print_table(
    "Sensitivity to the open top band's assumed cap",
    as.data.frame(x),
    footer = footer,
    ...
  )
  invisible(x)
}

#' Expand a banded frequency table into per-unit values
#'
#' @description
#' Turns a banded frequency table (labels and a count per band) into a
#' numeric vector with one value per unit, using the representative value of
#' each band from \code{\link{bandvals}}. The result can be passed to any
#' function that expects individual values, such as \code{\link{ginicoef}},
#' \code{mean()} or \code{quantile()}. Bands that cannot be parsed but have
#' units in them are an error by default, so a statistic never describes
#' only part of the data without saying so.
#'
#' @details
#' Each band's value is repeated \code{round(counts)} times, in band order.
#' Bands with an \code{NA} count are skipped. A band with an \code{NA} value
#' (unparsed label) and a positive count is an error unless
#' \code{drpunp = TRUE}, in which case its units are left out with a
#' warning that gives their number and labels.
#'
#' Errors: \code{cnts} of the wrong length, non-numeric or negative; an
#' unplaceable band with units (by default); any error from
#' \code{\link{bandvals}}.
#'
#' @param bands A data frame from \code{\link{prsbands}}, or labels to
#'   parse.
#' @param cnts Numeric vector, one non-negative count per band.
#' @param ... Further arguments to \code{\link{bandvals}}: \code{rule},
#'   \code{openupcap}, \code{openupfac} and
#'   \code{openloflr}.
#' @param drpunp Logical, default \code{FALSE}. \code{FALSE} makes a
#'   band whose label could not be parsed, yet which has a count, an error;
#'   \code{TRUE} leaves those units out with a warning instead.
#' @return A numeric vector with one entry per unit (length
#'   \code{sum(round(counts))} over the placed bands).
#' @seealso \code{\link{bandvals}}, \code{\link{bandsens}}
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' x <- expbands(c("1", "2 to 5", "Greater than 5"),
#'                   cnts = c(10, 4, 2), openupcap = 12)
#' table(x)
#' ginicoef(x)
#'
#' # the lower-bound reading of the same table
#' expbands(c("1", "2 to 5", "Greater than 5"), cnts = c(10, 4, 2),
#'              rule = "lower")
#'
#' # an unparseable band with units in it stops the call
#' try(expbands(c("1", "not stated"), cnts = c(3, 2)))
#' @export
expbands <- function(bands, cnts, ..., drpunp = FALSE) {
  if (!is.data.frame(bands)) {
    bands <- prsbands(bands)
  }
  cnts <- .rmbl_num(cnts, "cnts")
  if (length(cnts) != nrow(bands)) {
    stop(
      sprintf(
        "expbands: `cnts` has %d entries for %d bands",
        length(cnts),
        nrow(bands)
      ),
      call. = FALSE
    )
  }
  if (any(cnts < 0, na.rm = TRUE)) {
    stop("`cnts` must be non-negative", call. = FALSE)
  }
  bv <- bandvals(bands, ...)
  lost <- is.na(bv$value) & !is.na(cnts) & cnts > 0
  if (any(lost)) {
    msg <- sprintf(
      "%s unit(s) in %d band(s) could not be placed: %s",
      format(sum(cnts[lost])),
      sum(lost),
      paste(sprintf("'%s'", bands$label[lost]), collapse = ", ")
    )
    if (!isTRUE(drpunp)) {
      stop(msg, " (set drpunp = TRUE to leave them out)", call. = FALSE)
    }
    warning(msg, call. = FALSE)
  }
  keep <- !is.na(bv$value) & !is.na(cnts)
  rep(bv$value[keep], times = round(cnts[keep]))
}


#' Returns a regular expression that matches the Unicode dashes and the minus
#' sign.
#'
#' U+2010..U+2015 and U+2212 as a byte-wise alternation, built from raw bytes
#' and marked \code{"bytes"}: a string literal with those bytes is translated to
#' the native encoding when it is pasted, and in a C locale that translation is
#' a warning per call.
#' @return One string marked \code{"bytes"}.
#' @noRd
.rmbl_dash_pattern <- function() {
  one <- function(...) rawToChar(as.raw(c(...)))
  parts <- c(
    one(0xe2, 0x80, 0x90),
    one(0xe2, 0x80, 0x91),
    one(0xe2, 0x80, 0x92),
    one(0xe2, 0x80, 0x93),
    one(0xe2, 0x80, 0x94),
    one(0xe2, 0x80, 0x95),
    one(0xe2, 0x88, 0x92)
  )
  out <- rawToChar(do.call(
    c,
    c(
      lapply(parts[-length(parts)], function(p) {
        c(charToRaw(p), charToRaw("|"))
      }),
      list(charToRaw(parts[length(parts)]))
    )
  ))
  Encoding(out) <- "bytes"
  out
}
