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
  diverging = list(bad = "#c2492f", good = "#1b7f6b", flat = "#6b6b6b",
                   bad_bg = "#fbeae6", good_bg = "#e6f4f1"),
  # blue/orange, safe for deuteranopia and protanopia alike
  safe      = list(bad = "#b8621b", good = "#18567d", flat = "#6b6b6b",
                   bad_bg = "#fdf0e4", good_bg = "#e7eff6"),
  mono      = list(bad = "#1a1a1a", good = "#1a1a1a", flat = "#6b6b6b",
                   bad_bg = "#f0f0f0", good_bg = "#f7f7f7")
)

#' Colour palettes for change tables
#'
#' @return A character vector of palette names accepted by
#'   [yoy_html()], [yoy_pdf()] and `print()`.
#' @examples
#' yoy_palettes()
#' @export
yoy_palettes <- function() names(.YOY_PALETTES)

.yoy_pal <- function(palette) {
  palette <- match.arg(palette, names(.YOY_PALETTES))
  .YOY_PALETTES[[palette]]
}

.yoy_meta <- function(x) attr(x, "yoy", exact = TRUE)

.yoy_change_col <- function(x) {
  if ("pp_change" %in% names(x)) "pp_change" else "pct_change"
}

# The arrow carries the sign; the colour carries whether the sign is
# good news. Keeping them separate means a monochrome or piped-to-file
# rendering still says which way the number moved.
.yoy_arrow <- function(chg) {
  out <- rep(" ", length(chg))
  ok <- !is.na(chg)
  out[ok & chg > 0] <- "\u25b2"
  out[ok & chg < 0] <- "\u25bc"
  out[ok & chg == 0] <- "\u2013"
  out
}

.yoy_fmt_pct <- function(v, digits = 1L, pp = FALSE) {
  out <- rep("\u2014", length(v))
  ok <- !is.na(v) & is.finite(v)
  out[ok] <- sprintf(paste0("%+.", digits, "f%s"), v[ok],
                     if (pp) "pp" else "%")
  out[!is.na(v) & is.infinite(v)] <- "+Inf"
  out
}

.yoy_fmt_num <- function(v, digits = 0L) {
  out <- rep("\u2014", length(v))
  ok <- !is.na(v)
  out[ok] <- formatC(v[ok], format = "f", digits = digits, big.mark = ",")
  out
}

#' @param x An `rmbl_yoy` object.
#' @param digits Digits for the percent column.
#' @param palette One of [yoy_palettes()].
#' @param color Whether to emit ANSI colour. Defaults to colour only when
#'   writing to a terminal that has it, so a redirected or captured
#'   output stays plain text.
#' @param n Maximum rows to print.
#' @param ... Ignored.
#' @rdname yoy
#' @export
print.rmbl_yoy <- function(x, digits = 1L, palette = "diverging",
                           color = NULL, n = 30L, ...) {
  m <- .yoy_meta(x)
  if (is.null(m) || !nrow(x)) {
    cat("<rmbl_yoy: no periods>\n")
    return(invisible(x))
  }
  if (is.null(color)) {
    # NO_COLOR is the cross-tool convention for "plain text please", and
    # a non-interactive session is usually being captured
    color <- isTRUE(interactive()) && Sys.getenv("NO_COLOR") == ""
  }
  pal <- .yoy_pal(palette)
  chgcol <- .yoy_change_col(x)
  pp <- identical(chgcol, "pp_change")
  d <- as.data.frame(x)
  d <- utils::head(d, n)
  vd <- if (is.null(m$value_digits)) 0L else m$value_digits
  cols <- list(
    period = .yoy_period_text(d, m),
    value = .yoy_fmt_num(d$value, vd),
    previous = .yoy_fmt_num(d$previous, vd),
    change = .yoy_fmt_num(d$change, vd),
    pct = paste0(.yoy_arrow(d[[chgcol]]), " ",
                 .yoy_fmt_pct(d[[chgcol]], digits, pp))
  )
  if (all(c("pct_lower", "pct_upper") %in% names(d))) {
    cols$interval <- ifelse(
      is.na(d$pct_lower), "\u2014",
      sprintf("[%s, %s]",
              .yoy_fmt_pct(d$pct_lower, 0L), .yoy_fmt_pct(d$pct_upper, 0L)))
  }
  if (!is.null(m$by)) {
    for (b in rev(m$by)) {
      cols <- c(stats::setNames(list(as.character(d[[b]])), b), cols)
    }
  }
  hdr <- names(cols)
  hdr[hdr == "pct"] <- if (pp) "points" else "change %"
  hdr[hdr == "period"] <- m$period
  hdr[hdr == "value"] <- m$value
  widths <- vapply(seq_along(cols), function(i) {
    max(nchar(c(hdr[i], cols[[i]])), na.rm = TRUE)
  }, 0L)
  pad <- function(s, w) formatC(s, width = w, flag = "-")
  cat(paste(vapply(seq_along(cols), function(i) pad(hdr[i], widths[i]), ""),
            collapse = "  "), "\n", sep = "")
  cat(paste(vapply(widths, function(w) strrep("\u2500", w), ""),
            collapse = "  "), "\n", sep = "")
  for (r in seq_len(nrow(d))) {
    line <- paste(vapply(seq_along(cols),
                         function(i) pad(cols[[i]][r], widths[i]), ""),
                  collapse = "  ")
    if (isTRUE(color)) {
      v <- d$verdict[r]
      hex <- if (is.na(v)) NULL else if (v %in% c("worse", "up")) pal$bad
      else if (v %in% c("better", "down")) pal$good else pal$flat
      if (!is.null(hex) && !identical(palette, "mono")) {
        line <- paste0(.yoy_ansi(hex), line, "\033[0m")
      }
    }
    cat(line, "\n", sep = "")
    if (!is.na(d$flag[r])) {
      cat("    \u21b3 percent withheld: ", d$flag[r], "\n", sep = "")
    }
  }
  if (nrow(as.data.frame(x)) > n) {
    cat("... ", nrow(as.data.frame(x)) - n, " more rows\n", sep = "")
  }
  cat("\n", .yoy_footer(m), "\n", sep = "")
  invisible(x)
}

# 24-bit ANSI, which every terminal that reports colour support handles.
.yoy_ansi <- function(hex) {
  r <- strtoi(substr(hex, 2L, 3L), 16L)
  g <- strtoi(substr(hex, 4L, 5L), 16L)
  b <- strtoi(substr(hex, 6L, 7L), 16L)
  sprintf("\033[38;2;%d;%d;%dm", r, g, b)
}

.yoy_footer <- function(m) {
  bits <- c(sprintf("lag %d period%s", m$lag, if (m$lag == 1L) "" else "s"),
            sprintf("units: %s", m$units))
  if (m$units == "count") {
    bits <- c(bits, sprintf("%.0f%% exact rate-ratio interval",
                            100 * m$conf_level),
              sprintf("percent withheld below a base of %g", m$min_base))
  }
  if (m$units == "percent") {
    bits <- c(bits, "percentage-point change, not percent of a percent")
  }
  if (!identical(m$direction, "neutral")) {
    bits <- c(bits, sub("_", " ", gsub("_", " ", m$direction)))
  }
  paste(bits, collapse = " \u00b7 ")
}

#' Summarise a change table
#'
#' @param object An `rmbl_yoy` object.
#' @param ... Ignored.
#' @return A data frame with one row per group giving the first and last
#'   period, the total change across the span, the compound annual growth
#'   rate, and how many periods moved each way.
#' @examples
#' d <- data.frame(year = 2018:2023, n = c(120, 131, 98, 140, 155, 149))
#' yoy_summary(yoy(d, value = "n", period = "year"))
#' @export
yoy_summary <- function(object, ...) UseMethod("yoy_summary")

#' @rdname yoy_summary
#' @export
yoy_summary.rmbl_yoy <- function(object, ...) {
  m <- .yoy_meta(object)
  d <- as.data.frame(object)
  chgcol <- .yoy_change_col(object)
  one <- function(g) {
    g <- g[order(g[[m$period]]), , drop = FALSE]
    fin <- g[!is.na(g$value), , drop = FALSE]
    if (!nrow(fin)) {
      return(data.frame(from = NA, to = NA, first = NA_real_,
                        last = NA_real_, total_pct = NA_real_,
                        cagr_pct = NA_real_, periods = 0L,
                        up = 0L, down = 0L, flat = 0L,
                        stringsAsFactors = FALSE))
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
    data.frame(from = fin[[m$period]][1L],
               to = fin[[m$period]][nrow(fin)],
               first = first, last = last,
               total_pct = total, cagr_pct = cagr,
               periods = nrow(fin),
               up = sum(ch > 0, na.rm = TRUE),
               down = sum(ch < 0, na.rm = TRUE),
               flat = sum(ch == 0, na.rm = TRUE),
               stringsAsFactors = FALSE)
  }
  if (is.null(m$by)) {
    out <- one(d)
  } else {
    sp <- split(d, d[m$by], drop = TRUE, sep = "\r")
    rows <- lapply(names(sp), function(k) {
      r <- one(sp[[k]])
      lab <- strsplit(k, "\r", fixed = TRUE)[[1L]]
      for (i in seq_along(m$by)) r[[m$by[i]]] <- lab[i]
      r[, c(m$by, setdiff(names(r), m$by)), drop = FALSE]
    })
    out <- do.call(rbind, rows)
  }
  rownames(out) <- NULL
  out
}
