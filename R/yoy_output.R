# Presentation for period-over-period change: a terminal table, a
# self-contained HTML page, and a PDF drawn on R's own device.
#
# Colour encodes the DIRECTION of an improvement, which is not the sign
# of the change. Segregation days rising is red and falling is green;
# a completion rate does the opposite. A palette that always paints "up"
# green tells the reader the wrong thing about half of all public-safety
# series.

.YOY_PALETTES <- list(
  # red/green, the default, with the hues pulled toward orange and teal
  # so that the two are still distinguishable in the common forms of
  # colour blindness
  diverging = list(
    bad = "#c2492f",
    good = "#1b7f6b",
    flat = "#6b6b6b",
    badbg = "#fbeae6",
    goodbg = "#e6f4f1"
  ),
  # blue/orange, safe for deuteranopia and protanopia alike
  safe = list(
    bad = "#b8621b",
    good = "#18567d",
    flat = "#6b6b6b",
    badbg = "#fdf0e4",
    goodbg = "#e7eff6"
  ),
  mono = list(
    bad = "#1a1a1a",
    good = "#1a1a1a",
    flat = "#6b6b6b",
    badbg = "#f0f0f0",
    goodbg = "#f7f7f7"
  )
)

#' Colour palettes for change tables
#'
#' @description
#' Lists the names of the colour palettes that the change-table renderers
#' accept. In every palette the colour says whether a change is good or bad
#' news for the series, not whether the number went up or down: the arrow in
#' the table carries the sign, and the colour carries the
#' \code{direction} chosen in \code{\link{yoy}}. Use this to see which values
#' the \code{palette} argument of \code{print()}, \code{\link{yoyhtml}} and
#' \code{\link{yoypdf}} takes.
#'
#' @details
#' Three palettes are defined:
#' \describe{
#'   \item{\code{"diverging"}}{the default; red-orange (\code{#c2492f}) for bad
#'     news and teal (\code{#1b7f6b}) for good news, hues pulled apart so the
#'     pair stays distinguishable in the common forms of colour blindness.}
#'   \item{\code{"safe"}}{orange (\code{#b8621b}) and blue (\code{#18567d}),
#'     safe for deuteranopia and protanopia alike.}
#'   \item{\code{"mono"}}{black on grey; \code{print()} emits no colour codes
#'     at all with this palette.}
#' }
#' Unchanged rows and rows without a comparison use grey (\code{#6b6b6b}).
#' The verdict-to-colour mapping is: \code{"worse"} uses the bad colour and
#' \code{"better"} the good colour. With \code{direction = "neutral"} in
#' \code{\link{yoy}} the verdicts are \code{"up"}/\code{"down"}, which say
#' nothing about good or bad news, so those rows use the grey as well; the
#' arrow still shows the sign.
#' A palette name not in this list is an error in every renderer.
#'
#' @return A character vector of palette names, currently
#' \code{c("diverging", "safe", "mono")}.
#' @seealso \code{\link{yoy}}, \code{\link{yoysmry}},
#'   \code{\link{yoyhtml}}, \code{\link{yoypdf}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # the palette names
#' yoypals()
#'
#' # use one of them when printing a change table
#' d <- data.frame(year = 2019:2023, n = c(40, 46, 38, 52, 49))
#' print(yoy(d, value = "n", prd = "year"), palette = "safe", color = FALSE)
#'
#' # a name that is not a palette is refused
#' try(print(yoy(d, value = "n", prd = "year"), palette = "rainbow"))
#' @export
yoypals <- function() names(.YOY_PALETTES)

#' @param x An \code{rmbl_yoy} object returned by \code{yoy()}.
#' @param digits Integer, default \code{1}. Decimal places shown in the
#'   percent (or percentage-point) change column. The interval column is
#'   always shown to whole percent.
#' @param palette Character, default \code{"diverging"}. One of
#'   \code{\link{yoypals}()}; chooses the colours used when
#'   \code{color = TRUE}. An unknown name is an error.
#' @param color Logical or \code{NULL} (the default). \code{TRUE} wraps each
#'   row in 24-bit ANSI colour codes chosen from its verdict; \code{FALSE}
#'   prints plain text. \code{NULL} means colour only in an interactive
#'   session with the \code{NO_COLOR} environment variable unset, so output
#'   that is redirected or captured stays plain text. \code{format()} takes
#'   \code{TRUE} or \code{FALSE} (default \code{FALSE}).
#' @param n Integer, default \code{30}. Maximum number of rows printed; the
#'   number of rows left out is reported on a final line.
#' @param ... Further arguments from \code{print()}; the table ignores them.
#' @usage
#' \method{format}{rmbl_yoy}(x, digits = 1L, palette = "diverging",
#'   color = FALSE, n = 30, ...)
#' @rdname yoy
#' @export
format.rmbl_yoy <- function(
  x,
  digits = 1L,
  palette = "diverging",
  color = FALSE,
  n = 30,
  ...
) {
  m <- .yoy_meta(x)
  if (!nrow(x)) {
    return("<rmbl_yoy: no periods>")
  }
  # a subset of the columns keeps the class but not the period record (`[` on a
  # data frame drops attributes): print what is there as a table rather than "no
  # periods" (1.0.0 examples)
  if (is.null(m) || !all(c("value", "previous", "change") %in% names(x))) {
    return(.an_plain(x, ...))
  }
  pal <- .yoy_pal(palette)
  chgcol <- .yoy_change_col(x)
  pp <- identical(chgcol, "ppchg")
  d <- as.data.frame(x)
  shown <- utils::head(d, n)
  cols <- .yoy_print_cols(shown, m, chgcol, digits, pp)
  hdr <- names(cols)
  hdr[hdr == "pct"] <- if (pp) "points" else "change %"
  hdr[hdr == "period"] <- m$period
  hdr[hdr == "value"] <- m$value
  hdr <- .rmbl_txt(hdr)
  rows <- .yoy_print_rows(shown, cols, hdr, isTRUE(color), pal, palette)
  fn <- .yoy_first_note(shown, m)
  c(
    .rmbl_rule(sprintf("Change in %s by %s", m$value, m$period)),
    .rmbl_kv(.yoy_facts(d, m, pp)),
    "",
    paste0("  ", rows),
    if (nrow(d) > n) sprintf("  ... %d more rows", nrow(d) - n),
    if (length(fn)) c("", paste0("  ", fn)),
    "",
    paste0("  ", .yoy_footer_bits(m)),
    .rmbl_rule()
  )
}

#' @rdname yoy
#' @export
print.rmbl_yoy <- function(
  x,
  digits = 1L,
  palette = "diverging",
  color = NULL,
  n = 30,
  ...
) {
  if (is.null(color)) {
    # NO_COLOR is the cross-tool convention for "plain text please", and
    # a non-interactive session is usually being captured
    color <- isTRUE(interactive()) && Sys.getenv("NO_COLOR") == ""
  }
  .rmbl_cat(
    format(x, digits = digits, palette = palette, color = color, n = n, ...),
    x
  )
  invisible(x)
}

#' Summarise a change table
#'
#' @description
#' Collapses a period-over-period change table from \code{\link{yoy}} into
#' one row per series (or one row per group when \code{yoy()} was called with
#' \code{by}). Each row gives the first and last observed periods, the total
#' change between them, the compound annual growth rate, and how many
#' period-to-period changes went up, went down or stayed flat. Use it to
#' report the whole span of a series in one line next to the detailed table.
#'
#' @details Rows whose \code{value} is missing are dropped before the summary,
#' and the remaining rows are sorted by period, text periods in the order
#' \code{yoy()} read them (its \code{prd} and \code{prdord}). Periods with no
#' order (text \code{yoy()} could not read, an unordered factor) have no first
#' or last: \code{from}, \code{to}, \code{first}, \code{last}, \code{totalpct}
#' and \code{cagrpct} are then \code{NA}, with a warning saying why. With
#' \eqn{v_1} the first and \eqn{v_T} the last observed value, the total
#' change is \deqn{100 (v_T / v_1 - 1)} and, with
#' \eqn{s = (T - 1) / \mathrm{lag}} steps of length \code{lag},
#' \deqn{100 \left( (v_T / v_1)^{1/s} - 1 \right).} Both are \code{NA} when
#' \eqn{v_1 \le 0}, because a growth rate out of zero does not exist;
#' \code{cagrpct} is also \code{NA} for a single period. \code{"Annual"} in CAGR
#' assumes one period is a year; for monthly or quarterly data read it as the
#' compound rate per \code{lag} periods.
#'
#' The \code{up}, \code{down} and \code{flat} counts are taken from the
#' percent-change column (\code{pctchg}, or \code{ppchg} for
#' \code{units = "percent"}). A change out of a zero base has no percent
#' change and is not counted in any of the three. A group with no non-missing
#' value gives a row of \code{NA} with \code{periods = 0}.
#'
#' Anything other than a \code{yoy()} result is refused with the error
#' \dQuote{\code{object} must be a yoy() result}.
#'
#' @param object An \code{rmbl_yoy} object returned by \code{\link{yoy}}.
#' @param ... Further arguments for methods; not used.
#' @return A data frame with one row per series or group and columns: the
#' \code{by} columns (character), when \code{yoy()} had \code{by};
#' \code{from}, \code{to} (the first and last observed period, same type as
#' the period column); \code{first}, \code{last} (numeric values at those
#' periods); \code{totalpct}, \code{cagrpct} (numeric, percent);
#' \code{periods} (integer, observed periods); \code{up}, \code{down},
#' \code{flat} (integer counts of period-to-period changes).
#' @seealso \code{\link{yoy}}, \code{\link{yoypals}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # one series
#' d <- data.frame(year = 2018:2023, n = c(120, 131, 98, 140, 155, 149))
#' yoysmry(yoy(d, value = "n", prd = "year"))
#'
#' # one row per group; a zero base gives no percent change
#' g <- data.frame(year = rep(2019:2022, 2), unit = rep(c("A", "B"), each = 4),
#'                 n = c(10, 12, 0, 15, 5, 7, 6, 9))
#' yoysmry(yoy(g, value = "n", prd = "year", by = "unit"))
#'
#' # anything that is not a yoy() result is refused
#' try(yoysmry(d))
#' @export
yoysmry <- function(object, ...) UseMethod("yoysmry")

#' @rdname yoysmry
#' @export
yoysmry.default <- function(object, ...) {
  stop(
    sprintf("`object` must be a yoy() result, not %s", class(object)[1L]),
    call. = FALSE
  )
}

#' @rdname yoysmry
#' @export
yoysmry.rmbl_yoy <- function(object, ...) {
  m <- .yoy_meta(object)
  d <- as.data.frame(object)
  chgcol <- .yoy_change_col(object)
  # the span runs first to last period, so it needs their order: text periods
  # sorted alphabetically put "Apr 2021" before "Jan 2021" (C18)
  rk <- .yoy_prd_rank(d[[m$period]], m$prdord)
  if (is.null(rk)) {
    warning(
      "yoysmry: the periods have no order, so `from`, `to`, `first`, ",
      "`last`, `totalpct` and `cagrpct` are NA; give yoy() their order ",
      "with `prdord`",
      call. = FALSE
    )
  }
  d$.yoyrk <- if (is.null(rk)) NA_real_ else rk
  ord <- !is.null(rk)
  if (is.null(m$by)) {
    out <- .yoy_smry1(d, m, chgcol, ord)
  } else {
    sp <- split(d, d[m$by], drop = TRUE, sep = "\r")
    rows <- lapply(names(sp), function(k) {
      r <- .yoy_smry1(sp[[k]], m, chgcol, ord)
      lab <- strsplit(k, "\r", fixed = TRUE)[[1L]]
      for (i in seq_along(m$by)) {
        r[[m$by[i]]] <- lab[i]
      }
      r[, c(m$by, setdiff(names(r), m$by)), drop = FALSE]
    })
    out <- do.call(rbind, rows)
  }
  rownames(out) <- NULL
  .rmbl_cls(out, "rmbl_yoy_summary")
}

#' @export
format.rmbl_yoy_summary <- function(x, digits = 4L, ...) {
  title <- "Year-over-year summary"
  need <- c(
    "from", "to", "first", "last", "totalpct", "cagrpct",
    "periods", "up", "down", "flat"
  )
  fb <- .rmbl_df_fallback(x, title, need, digits)
  if (!is.null(fb)) {
    return(fb)
  }
  d <- .rmbl_plain(x)
  # a period printed as text, so 2021 never reads 2,021
  d$from <- as.character(d$from)
  d$to <- as.character(d$to)
  .rmbl_res_block(
    title,
    facts = list(Series = nrow(d)),
    tables = list(d),
    reading = paste(
      "totalpct is the change from the first period to the last and",
      "cagrpct the compound rate per step; up, down and flat count the",
      "changes from one period to the next."
    ),
    notes = if (nrow(d) && all(is.na(d$from))) {
      "The periods have no order, so the span is not given."
    },
    digits = digits,
    maxrows = 40L
  )
}

#' Looks up a printing palette by name.
#' @param palette The palette name, one of yoypals().
#' @return The palette's named colours.
#' @noRd
.yoy_pal <- function(palette) {
  palette <- .rmbl_arg(palette, names(.YOY_PALETTES))
  .YOY_PALETTES[[palette]]
}

#' Returns the settings that yoy() stored on its result.
#' @param x A yoy() result.
#' @return The list held in the \code{"yoy"} attribute, or NULL.
#' @noRd
.yoy_meta <- function(x) attr(x, "yoy", exact = TRUE)

#' Names the change column of a yoy() result.
#' @param x A yoy() result.
#' @return \code{"ppchg"} for a percentage-point change, else \code{"pctchg"}.
#' @noRd
.yoy_change_col <- function(x) {
  if ("ppchg" %in% names(x)) "ppchg" else "pctchg"
}

#' Classes each verdict as good, bad or flat news.
#'
#' The colour class of each verdict: good or bad news only when a direction says
#' which is which. \code{"up"} and \code{"down"} (direction = \code{"neutral"})
#' are neither, so they are flat; they had been painted bad and good, which
#' called every neutral rise bad news.
#' @param v The verdicts.
#' @return A character vector of \code{"good"}, \code{"bad"} or \code{"flat"}.
#' @noRd
.yoy_verdict_class <- function(v) {
  out <- rep("flat", length(v))
  out[!is.na(v) & v == "worse"] <- "bad"
  out[!is.na(v) & v == "better"] <- "good"
  out
}

#' Draws the arrow that shows the sign of each change.
#'
#' The arrow carries the sign; the colour carries whether the sign is
#' good news. Keeping them separate means a monochrome or piped-to-file
#' rendering still says which way the number moved.
#' @param chg The changes, shown as up, down or flat arrows.
#' @return A character vector of arrows, a dash for no change and a blank for
#'   NA.
#' @noRd
.yoy_arrow <- function(chg) {
  out <- rep(" ", length(chg))
  ok <- !is.na(chg)
  out[ok & chg > 0] <- .yg("\u25b2")
  out[ok & chg < 0] <- .yg("\u25bc")
  out[ok & chg == 0] <- "\u2013"
  out
}

#' Formats changes as signed percentages or percentage points.
#' @param v The changes.
#' @param digits The decimal places of the percentage.
#' @param pp Whether the unit is percentage points.
#' @return A character vector, a dash for a missing value.
#' @noRd
.yoy_fmt_pct <- function(v, digits = 1L, pp = FALSE) {
  # every writer's digits come through here: NA, a vector or text became the
  # format "%+.NAf"
  digits <- .rmbl_scalar(digits, "digits", 0, 15, integer = TRUE)
  out <- rep(.yg("\u2014"), length(v))
  ok <- !is.na(v) & is.finite(v)
  out[ok] <- sprintf(paste0("%+.", digits, "f%s"), v[ok], if (pp) "pp" else "%")
  out[!is.na(v) & is.infinite(v)] <- "+Inf"
  out
}

#' Formats numbers with thousands separators.
#' @param v The numbers.
#' @param digits The decimal places of the number.
#' @return A character vector, a dash for a missing value.
#' @noRd
.yoy_fmt_num <- function(v, digits = 0L) {
  out <- rep(.yg("\u2014"), length(v))
  ok <- !is.na(v)
  out[ok] <- formatC(v[ok], format = "f", digits = digits, big.mark = ",")
  out
}

#' 24-bit ANSI, which every terminal that reports colour support handles.
#' @param hex The colour as \dQuote{#RRGGBB}.
#' @return The escape sequence that sets that foreground colour.
#' @noRd
.yoy_ansi <- function(hex) {
  r <- strtoi(substr(hex, 2L, 3L), 16L)
  g <- strtoi(substr(hex, 4L, 5L), 16L)
  b <- strtoi(substr(hex, 6L, 7L), 16L)
  sprintf("\033[38;2;%d;%d;%dm", r, g, b)
}

#' Writes the footer line that states a yoy() table's settings.
#' @param m The settings of the yoy() result (see `.yoy_meta()`).
#' @return One string.
#' @noRd
.yoy_footer <- function(m) {
  paste(.yoy_footer_bits(m), collapse = .yg(" \u00b7 "))
}

#' The settings of a yoy() table, one phrase each: lag, units, interval,
#' direction.
#' @param m The settings of the yoy() result (see `.yoy_meta()`).
#' @return A character vector.
#' @noRd
.yoy_footer_bits <- function(m) {
  bits <- c(
    sprintf("lag %d period%s", m$lag, if (m$lag == 1L) "" else "s"),
    sprintf("units: %s", m$units)
  )
  if (m$units == "count") {
    bits <- c(
      bits,
      sprintf("%.0f%% exact rate-ratio interval", 100 * m$conflvl)
    )
    if (isTRUE(m$minbase > 0)) {
      bits <- c(bits, sprintf("bases below %g noted", m$minbase))
    }
  }
  if (m$units == "percent") {
    bits <- c(bits, "percentage-point change, not percent of a percent")
  }
  if (!identical(m$direction, "neutral")) {
    bits <- c(bits, paste(m$direction, "is better"))
  }
  bits
}

#' A glyph, or its ASCII meaning where the console cannot render UTF-8
#' (LC_ALL=C, some CI logs)
#' @param x The glyph.
#' @return `x`, or its ASCII replacement.
#' @noRd
.yg <- function(x) if (.rmbl_unicode_ok()) x else .yoy_ascii(x)

#' Summarises one series of a year-over-year table.
#' @param g The series' rows.
#' @param m The table's period record.
#' @param chgcol The change column: pctchg or ppchg.
#' @param ord Whether the periods have an order (column `.yoyrk`, the sort
#'   key); without one the span, its ends and its changes are NA.
#' @return A one-row data frame.
#' @noRd
.yoy_smry1 <- function(g, m, chgcol, ord = TRUE) {
  g <- g[order(g$.yoyrk), , drop = FALSE]
  fin <- g[!is.na(g$value), , drop = FALSE]
  if (!nrow(fin)) {
    return(data.frame(
      from = NA,
      to = NA,
      first = NA_real_,
      last = NA_real_,
      totalpct = NA_real_,
      cagrpct = NA_real_,
      periods = 0L,
      up = 0L,
      down = 0L,
      flat = 0L,
      stringsAsFactors = FALSE
    ))
  }
  first <- fin$value[1L]
  last <- fin$value[nrow(fin)]
  # the span is in periods, and CAGR is only defined when the starting
  # value is positive -- a compound rate out of zero does not exist
  steps <- (nrow(fin) - 1L) / m$lag
  total <- if (first > 0) 100 * (last / first - 1) else NA_real_
  cagr <- if (first > 0 && steps > 0) {
    100 * ((last / first)^(1 / steps) - 1)
  } else {
    NA_real_
  }
  ch <- g[[chgcol]]
  out <- data.frame(
    from = fin[[m$period]][1L],
    to = fin[[m$period]][nrow(fin)],
    first = first,
    last = last,
    totalpct = total,
    cagrpct = cagr,
    periods = nrow(fin),
    up = sum(ch > 0, na.rm = TRUE),
    down = sum(ch < 0, na.rm = TRUE),
    flat = sum(ch == 0, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
  if (!ord) {
    out$from <- out$from[NA_integer_]
    out$to <- out$to[NA_integer_]
    out[c("first", "last", "totalpct", "cagrpct")] <- NA_real_
  }
  out
}

#' The printed columns of a year-over-year table, as text.
#' @param d The rows printed.
#' @param m The table's period record.
#' @param chgcol The change column: pctchg or ppchg.
#' @param digits The digits of a percentage.
#' @param pp Whether the change column is in percentage points.
#' @return A named list of character vectors, one per column.
#' @noRd
.yoy_print_cols <- function(d, m, chgcol, digits, pp) {
  vd <- if (is.null(m$valuedig)) 0L else m$valuedig
  cols <- list(
    period = .yoy_period_text(d, m),
    value = .yoy_fmt_num(d$value, vd),
    previous = .yoy_fmt_num(d$previous, vd),
    change = .yoy_fmt_num(d$change, vd),
    pct = paste0(
      .yoy_arrow(d[[chgcol]]),
      " ",
      .yoy_fmt_pct(d[[chgcol]], digits, pp)
    )
  )
  if (all(c("pctlo", "pctup") %in% names(d))) {
    cols$interval <- ifelse(
      is.na(d$pctlo),
      .yg("\u2014"),
      sprintf("[%s, %s]", .yoy_fmt_pct(d$pctlo, 0L), .yoy_fmt_pct(d$pctup, 0L))
    )
  }
  if (!is.null(m$by)) {
    for (b in rev(m$by)) {
      cols <- c(stats::setNames(list(as.character(d[[b]])), b), cols)
    }
  }
  # labels as the console shows them, as rtcalc() prints them: folded to
  # ASCII in a C locale ("Metis"), control characters escaped; unfolded, the
  # columns misaligned with "unable to translate" warnings (recheck of a8cdaf9)
  lapply(cols, .rmbl_txt)
}

#' The yoy table's columns and headers cut to fit the console (a
#' 300-character label collapsed the table).
#' @param cols The yoy columns, as strings.
#' @param hdr Their headers.
#' @return list(cols, hdr).
#' @noRd
.yoy_fit <- function(cols, hdr) {
  num <- vapply(cols, function(v) {
    all(is.na(v) | grepl("^[ +-]?[0-9.,%]*$|^NA$", v))
  }, NA)
  fit <- .rmbl_fit(lapply(seq_along(cols), function(i) c(hdr[i], cols[[i]])),
                   num, .rmbl_avail())
  out <- lapply(fit, `[`, -1L)
  names(out) <- names(cols)
  list(cols = out, hdr = vapply(fit, `[`, "", 1L))
}

#' The header, the rule and the rows of a year-over-year table, as lines.
#' @param d The rows printed.
#' @param cols The columns as text.
#' @param hdr The column headers, padded to the column widths.
#' @param color Whether rows are coloured by verdict.
#' @param pal The verdict colours.
#' @param palette The palette's name.
#' @return A character vector of lines.
#' @noRd
.yoy_print_rows <- function(d, cols, hdr, color, pal, palette) {
  f <- .yoy_fit(cols, hdr)
  cols <- f$cols
  hdr <- f$hdr
  # display widths: a CJK label takes two columns
  wd <- function(s) nchar(ifelse(is.na(s), "NA", s), type = "width")
  widths <- vapply(
    seq_along(cols),
    function(i) max(wd(c(hdr[i], cols[[i]]))),
    0L
  )
  pad <- function(s, w) {
    paste0(ifelse(is.na(s), "NA", s), strrep(" ", max(0L, w - wd(s))))
  }
  if (sum(widths) + 2L * (length(widths) - 1L) > .rmbl_avail()) {
    return(.rmbl_stack(hdr, cols, nrow(d)))
  }
  out <- c(
    paste(
      vapply(seq_along(cols), function(i) pad(hdr[i], widths[i]), ""),
      collapse = "  "
    ),
    paste(
      vapply(widths, function(w) strrep(.yg("\u2500"), w), ""),
      collapse = "  "
    )
  )
  for (r in seq_len(nrow(d))) {
    line <- paste(
      vapply(seq_along(cols), function(i) pad(cols[[i]][r], widths[i]), ""),
      collapse = "  "
    )
    if (isTRUE(color)) {
      v <- d$verdict[r]
      hex <- if (is.na(v)) NULL else pal[[.yoy_verdict_class(v)]]
      if (!is.null(hex) && !identical(palette, "mono")) {
        line <- paste0(.yoy_ansi(hex), line, "\033[0m")
      }
    }
    out <- c(out, line)
    # the first period has nothing to compare with in every table: said once
    # under the table (.yoy_first_note()), not under each group's first row
    if (!is.na(d$flag[r]) && d$flag[r] != "no comparison period") {
      out <- c(out, paste0(.yg("  \u21b3 note: "), d$flag[r]))
    }
  }
  out
}

#' The one line that says the first periods have nothing to compare with.
#' @param d The rows shown.
#' @param m The table's period record.
#' @return One string, or NULL when no row is a first period.
#' @noRd
.yoy_first_note <- function(d, m) {
  if (!any(!is.na(d$flag) & d$flag == "no comparison period")) {
    return(NULL)
  }
  lag <- m$lag %||% 1L
  sprintf(
    "Note: the first %s%s %s nothing to compare with, so %s no change.",
    if (lag == 1L) "period" else sprintf("%d periods", lag),
    if (length(m$by)) " of each group" else "",
    if (lag == 1L) "has" else "have",
    if (lag == 1L) "it shows" else "they show"
  )
}

#' The facts shown above a year-over-year table.
#' @param d The table, as a data frame.
#' @param m The table's period record.
#' @param pp Whether the change column is in percentage points.
#' @return A named list of strings.
#' @noRd
.yoy_facts <- function(d, m, pp) {
  out <- list(
    Rows = format(nrow(d)),
    Change = if (pp) "in percentage points" else "in percent",
    Better = if (identical(m$direction, "neutral")) {
      "not set (direction neutral): the colour shows no verdict"
    } else {
      paste(m$direction, "values")
    }
  )
  if (!is.null(m$by)) {
    out$Groups <- sprintf(
      "%d (by %s)",
      nrow(unique(d[m$by])),
      toString(m$by)
    )
  }
  out
}
