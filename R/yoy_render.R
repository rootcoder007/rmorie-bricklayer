# Rendering a change table to a file. Two backends, neither needing a
# package outside base R: a self-contained HTML page, and a PDF drawn on
# R's own pdf() device.
#
# Self-contained matters for provenance work. A page that pulls a
# stylesheet or a font from a CDN stops rendering the way it rendered
# when the capsule was sealed, so everything is inlined and the file is
# the artefact.

#' Render a change table to HTML or PDF
#'
#' @param x An `rmbl_yoy` object from
#' [yoy()].
#' @param file Output path. `yoy_html()` writes a single
#' self-contained HTML file with no external requests; `yoy_pdf()`
#' writes a PDF using R's own device, so neither needs a package beyond
#' base R.
#' @param title Heading for the page.
#' @param subtitle Optional line under the heading.
#' Defaults to the table's own settings -- lag, units, interval and base
#' gate -- so the reader can see what the percentages mean.
#' @param palette One of
#' [yoy_palettes()].
#' @param digits Digits for the percent column.
#' @param bars Whether to draw an in-cell bar proportional to
#' the change, scaled to the largest absolute change in the table.
#' @param interval Whether to show the exact interval
#' column for counts.
#' @param notes Optional character vector of footnotes.
#' @param width,height PDF page size in inches.
#' @param ... Ignored.
#' @return The path, invisibly.
#' @examples
#' d <- data.frame(year = rep(2019:2023, each = 2),
#'                 region = rep(c("North", "South"), 5),
#'                 n = c(31, 402, 28, 377, 12, 190, 19, 268, 24, 331))
#' y <- yoy(d, value = "n", period = "year", by = "region",
#'          direction = "lower_is_better")
#'
#' h <- file.path(tempdir(), "change.html")
#' yoy_html(y, h, title = "Placements by region")
#' file.exists(h)
#'
#' p <- file.path(tempdir(), "change.pdf")
#' yoy_pdf(y, p, title = "Placements by region")
#' file.exists(p)
#'
#' unlink(c(h, p))
#' @name yoy_render
#' @export
yoy_html <- function(x, file, title = "Year-over-year change",
                     subtitle = NULL, palette = "diverging", digits = 1L,
                     bars = TRUE, interval = TRUE, notes = NULL, ...) {
  if (!inherits(x, "rmbl_yoy")) {
    stop("`x` must be an rmbl_yoy object from yoy()", call. = FALSE)
  }
  m <- .yoy_meta(x)
  pal <- .yoy_pal(palette)
  d <- as.data.frame(x)
  chgcol <- .yoy_change_col(x)
  pp <- identical(chgcol, "pp_change")
  if (is.null(subtitle)) subtitle <- .yoy_footer(m)
  show_ci <- isTRUE(interval) &&
    all(c("pct_lower", "pct_upper") %in% names(d))
  vd <- if (is.null(m$value_digits)) 0L else m$value_digits
  scale <- suppressWarnings(max(abs(d[[chgcol]]), na.rm = TRUE))
  if (!is.finite(scale) || scale == 0) scale <- 1

  head_cells <- c(m$by, m$period, m$value, "previous", "change",
                  if (pp) "points" else "change %")
  if (show_ci) head_cells <- c(head_cells, "interval")
  rows <- vapply(seq_len(nrow(d)), function(r) {
    v <- d$verdict[r]
    cls <- if (is.na(v)) "flat" else if (v %in% c("worse", "up")) "bad"
    else if (v %in% c("better", "down")) "good" else "flat"
    cells <- c(
      if (!is.null(m$by)) vapply(m$by, function(b) {
        .yoy_td(.yoy_esc(as.character(d[[b]][r])), "grp")
      }, "") else character(0),
      .yoy_td(.yoy_esc(.yoy_period_text(d, m)[r]), "per"),
      .yoy_td(.yoy_fmt_num(d$value[r], vd), "num"),
      .yoy_td(.yoy_fmt_num(d$previous[r], vd), "num"),
      .yoy_td(.yoy_fmt_num(d$change[r], vd), "num"),
      .yoy_pct_cell(d[[chgcol]][r], cls, digits, pp, bars, scale)
    )
    if (show_ci) {
      txt <- if (is.na(d$pct_lower[r])) "\u2014" else sprintf(
        "[%s, %s]", .yoy_fmt_pct(d$pct_lower[r], 0L),
        .yoy_fmt_pct(d$pct_upper[r], 0L))
      cells <- c(cells, .yoy_td(txt, "ci"))
    }
    note <- if (is.na(d$flag[r])) "" else sprintf(
      "<tr class=\"note\"><td colspan=\"%d\">percent withheld: %s</td></tr>",
      length(head_cells), .yoy_esc(d$flag[r]))
    paste0("<tr class=\"", cls, "\">", paste(cells, collapse = ""),
           "</tr>", note)
  }, "")

  sm <- yoy_summary(x)
  html <- c(
    "<!DOCTYPE html>", "<html lang=\"en\"><head>",
    "<meta charset=\"utf-8\">",
    "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">",
    paste0("<title>", .yoy_esc(title), "</title>"),
    paste0("<style>", .yoy_css(pal), "</style>"),
    "</head><body><main>",
    paste0("<h1>", .yoy_esc(title), "</h1>"),
    paste0("<p class=\"sub\">", .yoy_esc(subtitle), "</p>"),
    "<div class=\"scroll\"><table><thead><tr>",
    paste0(vapply(head_cells, function(h) {
      paste0("<th>", .yoy_esc(h), "</th>")
    }, ""), collapse = ""),
    "</tr></thead><tbody>", rows, "</tbody></table></div>",
    .yoy_summary_html(sm, m),
    if (length(notes)) {
      c("<ul class=\"notes\">",
        vapply(notes, function(n) paste0("<li>", .yoy_esc(n), "</li>"), ""),
        "</ul>")
    },
    paste0("<p class=\"gen\">", .yoy_esc(sprintf(
      "rmoriebricklayer %s", utils::packageVersion("rmoriebricklayer"))),
      "</p>"),
    "</main></body></html>")
  writeLines(html, file, useBytes = TRUE)
  invisible(file)
}

.yoy_td <- function(txt, cls) {
  paste0("<td class=\"", cls, "\">", txt, "</td>")
}

.yoy_pct_cell <- function(v, cls, digits, pp, bars, scale) {
  txt <- .yoy_fmt_pct(v, digits, pp)
  arrow <- if (is.na(v)) "" else if (v > 0) "\u25b2" else if (v < 0)
    "\u25bc" else "\u2013"
  bar <- ""
  if (isTRUE(bars) && !is.na(v) && is.finite(v)) {
    w <- min(100, 100 * abs(v) / scale)
    bar <- sprintf("<span class=\"bar %s\" style=\"width:%.1f%%\"></span>",
                   cls, w)
  }
  paste0("<td class=\"pct ", cls, "\"><span class=\"arw\">", arrow,
         "</span><span class=\"val\">", txt, "</span>", bar, "</td>")
}

.yoy_summary_html <- function(sm, m) {
  keys <- intersect(m$by, names(sm))
  cells <- vapply(seq_len(nrow(sm)), function(r) {
    lab <- if (length(keys)) {
      paste(vapply(keys, function(k) as.character(sm[[k]][r]), ""),
            collapse = " \u00b7 ")
    } else {
      "overall"
    }
    paste0(
      "<div class=\"card\"><div class=\"lab\">", .yoy_esc(lab),
      "</div><div class=\"big\">", .yoy_fmt_pct(sm$total_pct[r], 1L),
      "</div><div class=\"cap\">",
      .yoy_esc(sprintf("%s to %s", sm$from[r], sm$to[r])),
      "</div><div class=\"cap\">",
      .yoy_esc(sprintf("compound %s per period",
                       .yoy_fmt_pct(sm$cagr_pct[r], 1L))),
      "</div><div class=\"cap\">",
      .yoy_esc(sprintf("%d up, %d down, %d unchanged",
                       sm$up[r], sm$down[r], sm$flat[r])),
      "</div></div>")
  }, "")
  paste0("<h2>Across the span</h2><div class=\"cards\">",
         paste(cells, collapse = ""), "</div>")
}

.yoy_esc <- function(s) {
  s <- as.character(s)
  s[is.na(s)] <- ""
  s <- gsub("&", "&amp;", s, fixed = TRUE)
  s <- gsub("<", "&lt;", s, fixed = TRUE)
  s <- gsub(">", "&gt;", s, fixed = TRUE)
  s <- gsub("\"", "&quot;", s, fixed = TRUE)
  gsub("'", "&#39;", s, fixed = TRUE)
}

# One stylesheet, inlined, defining the palette as custom properties so
# that the dark theme redefines only the tokens.
.yoy_css <- function(pal) {
  paste0(
    ":root{--bad:", pal$bad, ";--good:", pal$good, ";--flat:", pal$flat,
    ";--badbg:", pal$bad_bg, ";--goodbg:", pal$good_bg,
    ";--ink:#1a1a1a;--dim:#5c5c5c;--rule:#e0ddd8;--ground:#faf9f7;",
    "--panel:#ffffff}",
    "@media (prefers-color-scheme:dark){:root:not([data-theme=light]){",
    "--ink:#eceae6;--dim:#a6a29b;--rule:#332f2b;--ground:#171513;",
    "--panel:#201d1a;--badbg:#331f1a;--goodbg:#142a26}}",
    "*{box-sizing:border-box}",
    "body{margin:0;background:var(--ground);color:var(--ink);",
    "font:14px/1.5 ui-sans-serif,-apple-system,'Segoe UI',Roboto,",
    "'Helvetica Neue',Arial,sans-serif}",
    "main{max-width:1000px;margin:0 auto;padding:2.5rem 1.25rem 4rem}",
    "h1{font-size:1.6rem;margin:0 0 .25rem;letter-spacing:-.01em}",
    "h2{font-size:1rem;text-transform:uppercase;letter-spacing:.08em;",
    "color:var(--dim);margin:2.5rem 0 .75rem;font-weight:600}",
    "p.sub{color:var(--dim);margin:0 0 1.75rem}",
    ".scroll{overflow-x:auto;border:1px solid var(--rule);border-radius:6px;",
    "background:var(--panel)}",
    "table{border-collapse:collapse;width:100%;min-width:520px}",
    "th{text-align:left;font-size:.72rem;text-transform:uppercase;",
    "letter-spacing:.06em;color:var(--dim);font-weight:600;",
    "padding:.65rem .75rem;border-bottom:1px solid var(--rule);",
    "white-space:nowrap}",
    "td{padding:.55rem .75rem;border-bottom:1px solid var(--rule);",
    "vertical-align:middle}",
    "tbody tr:last-child td{border-bottom:0}",
    "td.num,td.ci{text-align:right;font-variant-numeric:tabular-nums}",
    "td.per{font-variant-numeric:tabular-nums;white-space:nowrap}",
    "td.grp{font-weight:600}",
    "td.ci{color:var(--dim);font-size:.85rem;white-space:nowrap}",
    "td.pct{position:relative;text-align:right;white-space:nowrap;",
    "font-variant-numeric:tabular-nums}",
    "td.pct .arw{margin-right:.3rem;font-size:.8rem}",
    "td.pct.bad{color:var(--bad)}td.pct.good{color:var(--good)}",
    "td.pct.flat{color:var(--flat)}",
    ".bar{position:absolute;left:0;bottom:0;height:2px;opacity:.55}",
    ".bar.bad{background:var(--bad)}.bar.good{background:var(--good)}",
    ".bar.flat{background:var(--flat)}",
    "tr.bad td.pct{background:var(--badbg)}",
    "tr.good td.pct{background:var(--goodbg)}",
    "tr.note td{border-bottom:1px solid var(--rule);color:var(--dim);",
    "font-size:.8rem;padding:.2rem .75rem .5rem}",
    ".cards{display:grid;gap:.75rem;",
    "grid-template-columns:repeat(auto-fit,minmax(180px,1fr))}",
    ".card{border:1px solid var(--rule);border-radius:6px;padding:.9rem;",
    "background:var(--panel)}",
    ".card .lab{font-size:.72rem;text-transform:uppercase;",
    "letter-spacing:.06em;color:var(--dim);font-weight:600}",
    ".card .big{font-size:1.5rem;margin:.2rem 0 .3rem;",
    "font-variant-numeric:tabular-nums}",
    ".card .cap{color:var(--dim);font-size:.8rem}",
    "ul.notes{color:var(--dim);font-size:.85rem;padding-left:1.1rem}",
    "p.gen{color:var(--dim);font-size:.75rem;margin-top:2.5rem}")
}

#' @rdname yoy_render
#' @export
yoy_pdf <- function(x, file, title = "Year-over-year change",
                    subtitle = NULL, palette = "diverging", digits = 1L,
                    interval = TRUE, notes = NULL,
                    width = 11, height = 8.5, ...) {
  if (!inherits(x, "rmbl_yoy")) {
    stop("`x` must be an rmbl_yoy object from yoy()", call. = FALSE)
  }
  m <- .yoy_meta(x)
  pal <- .yoy_pal(palette)
  d <- as.data.frame(x)
  chgcol <- .yoy_change_col(x)
  pp <- identical(chgcol, "pp_change")
  if (is.null(subtitle)) subtitle <- .yoy_footer(m)
  show_ci <- isTRUE(interval) &&
    all(c("pct_lower", "pct_upper") %in% names(d))

  hdr <- c(m$by, m$period, m$value, "previous", "change",
           if (pp) "points" else "change %")
  vd <- if (is.null(m$value_digits)) 0L else m$value_digits
  body <- cbind(
    if (!is.null(m$by)) {
      do.call(cbind, lapply(m$by, function(b) as.character(d[[b]])))
    } else {
      NULL
    },
    .yoy_period_text(d, m),
    .yoy_fmt_num(d$value, vd), .yoy_fmt_num(d$previous, vd),
    .yoy_fmt_num(d$change, vd), .yoy_fmt_pct(d[[chgcol]], digits, pp))
  if (show_ci) {
    hdr <- c(hdr, "interval")
    body <- cbind(body, ifelse(
      is.na(d$pct_lower), "\u2014",
      sprintf("[%s, %s]", .yoy_fmt_pct(d$pct_lower, 0L),
              .yoy_fmt_pct(d$pct_upper, 0L))))
  }
  cols <- vapply(seq_len(nrow(d)), function(r) {
    v <- d$verdict[r]
    if (is.na(v)) pal$flat else if (v %in% c("worse", "up")) pal$bad
    else if (v %in% c("better", "down")) pal$good else pal$flat
  }, "")

  # Paginate on the rows that fit, so a long table becomes several pages
  # rather than one page with the tail cut off.
  per_page <- max(5L, floor((height - 2.4) / 0.22))
  pages <- split(seq_len(nrow(body)),
                 ceiling(seq_len(nrow(body)) / per_page))
  # The PDF device's default Type 1 fonts have no em dash or arrows, and
  # substitute them with a warning per cell. The table says the same
  # thing in the encoding the font can actually draw.
  body[] <- .yoy_ascii(body)
  hdr <- .yoy_ascii(hdr)
  subtitle <- .yoy_ascii(subtitle)
  if (length(notes)) notes <- .yoy_ascii(notes)
  grDevices::pdf(file, width = width, height = height,
                 title = title, onefile = TRUE)
  on.exit(grDevices::dev.off(), add = TRUE)
  npg <- length(pages)
  for (pg in seq_along(pages)) {
    .yoy_pdf_page(hdr, body[pages[[pg]], , drop = FALSE],
                  cols[pages[[pg]]], title, subtitle, pal,
                  if (npg > 1L) sprintf("page %d of %d", pg, npg) else "",
                  if (pg == npg) notes else NULL)
  }
  invisible(file)
}

# Glyphs the PDF device's base fonts cannot draw, rendered as the ASCII
# that means the same thing.
.yoy_ascii <- function(x) {
  out <- as.character(x)
  for (pair in list(c("\u2014", "-"), c("\u2013", "-"),
                    c("\u25b2", "+"), c("\u25bc", "-"),
                    c("\u00b7", "|"), c("\u2500", "-"),
                    c("\u21b3", ">"))) {
    out <- gsub(pair[1L], pair[2L], out, fixed = TRUE)
  }
  if (is.matrix(x)) {
    out <- matrix(out, nrow = nrow(x), dimnames = dimnames(x))
  }
  out
}

.yoy_pdf_page <- function(hdr, body, cols, title, subtitle, pal,
                          pagelab, notes) {
  ncol <- length(hdr)
  op <- graphics::par(mar = c(0.6, 0.6, 0.6, 0.6))
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot.new()
  graphics::plot.window(c(0, 1), c(0, 1), xaxs = "i", yaxs = "i")
  graphics::text(0, 0.965, title, adj = c(0, 1), cex = 1.5, font = 2)
  graphics::text(0, 0.925, subtitle, adj = c(0, 1), cex = 0.8,
                 col = pal$flat)
  # Right-align the numeric columns and left-align the labels, which is
  # the only way a column of figures reads as a column.
  numeric_from <- ncol - (if (hdr[ncol] == "interval") 3L else 2L)
  w <- rep(1, ncol)
  w[seq_len(max(1L, numeric_from - 1L))] <- 1.3
  xs <- cumsum(c(0, w / sum(w)))
  top <- 0.88
  rowh <- 0.22 / 8.5
  graphics::segments(0, top + rowh * 0.6, 1, top + rowh * 0.6,
                     col = pal$flat, lwd = 0.7)
  for (j in seq_len(ncol)) {
    right <- j >= numeric_from
    graphics::text(if (right) xs[j + 1L] - 0.004 else xs[j] + 0.004,
                   top, hdr[j], adj = c(if (right) 1 else 0, 1),
                   cex = 0.68, font = 2, col = pal$flat)
  }
  graphics::segments(0, top - rowh * 0.35, 1, top - rowh * 0.35,
                     col = pal$flat, lwd = 0.7)
  y <- top - rowh * 1.1
  for (i in seq_len(nrow(body))) {
    for (j in seq_len(ncol)) {
      right <- j >= numeric_from
      last <- j == ncol - (if (hdr[ncol] == "interval") 1L else 0L)
      graphics::text(if (right) xs[j + 1L] - 0.004 else xs[j] + 0.004,
                     y, body[i, j], adj = c(if (right) 1 else 0, 1),
                     cex = 0.72,
                     col = if (last) cols[i] else graphics::par("fg"))
    }
    y <- y - rowh
    if (y < 0.06) break
  }
  if (nzchar(pagelab)) {
    graphics::text(1, 0.02, pagelab, adj = c(1, 0), cex = 0.6,
                   col = pal$flat)
  }
  if (length(notes)) {
    graphics::text(0, 0.04 + 0.018 * length(notes),
                   paste(notes, collapse = "\n"), adj = c(0, 1),
                   cex = 0.62, col = pal$flat)
  }
  invisible(NULL)
}
