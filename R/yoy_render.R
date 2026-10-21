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
#' Writes a change table from [yoy()] to a file for people who will not
#' run
#' R: \code{yoyhtml()} to a single self-contained web page, \code{yoypdf()}
#' to a PDF. Each row shows the period, the value, the previous value, the
#' change and the percent change, coloured by whether it is better or worse,
#' with the exact interval and any flags; the HTML page also has summary
#' cards from [yoysmry()]. Use them to hand a reviewed set
#' of
#' period-over-period changes to a manager, a journalist or a court.
#'
#' @details
#' Neither backend needs a package beyond base R. The HTML page inlines its
#' stylesheet, makes no external requests (no fonts, scripts or images from
#' the network) and escapes every value, so the file stays the artefact and
#' renders the same later. Rows are coloured by the table's \code{verdict}:
#' \code{"worse"} in the palette's bad colour, \code{"better"} in its good
#' colour, everything else (including the \code{"up"} and \code{"down"} of
#' \code{direction = "neutral"}) in its neutral grey. Labels set
#' with [yoylbl()] replace the period. For percentage units
#' the change is
#' shown in points. The page ends with the package version that wrote it.
#'
#' The PDF is drawn on R's own \code{pdf()} device with its standard fonts,
#' which cannot draw arrows or dashes, so those are written in ASCII
#' (\code{+}, \code{-}). Long tables are split over pages at 0.22 inch per row,
#' with \dQuote{page i of n} labels; notes go under the last page's rows when they
#' fit and on pages of their own otherwise. The interval column appears only
#' when the table has \code{pctlo} and \code{pctup} (counts).
#'
#' Both overwrite \code{file}. Errors: \code{x} not from [yoy()]; a
#' \code{pal} not in [yoypals()]; a file that cannot
#' be written.
#'
#' @param x An \code{rmbl_yoy} object from [yoy()].
#' @param file Output path (a string). \code{yoyhtml()} writes a single
#'   self-contained HTML file with no external requests; \code{yoypdf()}
#'   writes a PDF using R's own device, so neither needs a package beyond
#'   base R.
#' @param title Heading for the page (and the HTML page title or PDF title),
#'   a string; default \code{"Year-over-year change"}.
#' @param sub Optional line under the heading.
#'   Defaults to the table's own settings -- lag, units, interval and base
#'   gate -- so the reader can see what the percentages mean.
#' @param pal One of [yoypals()]:
#'   \code{"diverging"} (the default),
#'   \code{"safe"} or \code{"mono"}.
#' @param digits Digits for the percent column, default 1.
#' @param bars Logical (HTML only): draw an in-cell bar proportional to
#'   the change, scaled to the largest absolute change in the table
#'   (default \code{TRUE}).
#' @param intv Logical: show the exact interval column for counts
#'   (default \code{TRUE}).
#' @param notes Optional character vector of footnotes.
#' @param width,height PDF page size in inches (default 11 by 8.5,
#'   landscape US letter).
#' @param ... Ignored.
#' @return The path \code{file}, invisibly.
#' @examplesIf interactive() || identical(Sys.getenv("IN_PKGDOWN"), "true")
#' d <- data.frame(year = rep(2019:2023, each = 2),
#'                 region = rep(c("North", "South"), 5),
#'                 n = c(31, 402, 28, 377, 12, 190, 19, 268, 24, 331))
#' y <- yoy(d, value = "n", prd = "year", by = "region",
#'          dir = "lower")
#'
#' h <- file.path(tempdir(), "change.html")
#' yoyhtml(y, h, title = "Placements by region")
#' file.exists(h)
#'
#' p <- file.path(tempdir(), "change.pdf")
#' yoypdf(y, p, title = "Placements by region")
#' file.exists(p)
#'
#' # a colour-blind-safe palette, no bars or intervals, and a footnote
#' yoyhtml(y, h, pal = "safe", bars = FALSE, intv = FALSE,
#'          notes = "Counts below 10 are suppressed at source.")
#' any(grepl("suppressed", readLines(h)))
#'
#' # portrait letter pages, with fiscal-year labels
#' yoypdf(yoylbl(y, fylbl), p, width = 8.5, height = 11)
#'
#' # only yoy() tables can be rendered
#' try(yoyhtml(d, h))
#' unlink(c(h, p))
#' @name yoyren
#' @export
yoyhtml <- function(x, file, title = "Year-over-year change",
                     sub = NULL, pal = "diverging", digits = 1L,
                     bars = TRUE, intv = TRUE, notes = NULL, ...) {
  if (!inherits(x, "rmbl_yoy")) {
    stop("yoyhtml: `x` must be an rmbl_yoy object from yoy()", call. = FALSE)
  }
  # an HTML page is written to a file or a connection (writeLines(html, NULL) failed in base R's words)
  if (is.null(file)) stop("`file` must be a file path or a connection", call. = FALSE)
  file <- .rmbl_out_file(file)
  title <- .rmbl_text1(title, "title")
  if (!is.null(sub)) sub <- .rmbl_text1(sub, "sub")
  if (!is.null(notes) && (!is.character(notes) || anyNA(notes))) {
    stop("yoyhtml: `notes` must be text (a character vector), or NULL", call. = FALSE)
  }
  m <- .yoy_meta(x)
  .pal <- .yoy_pal(pal)
  d <- as.data.frame(x)
  chgcol <- .yoy_change_col(x)
  pp <- identical(chgcol, "ppchg")
  if (is.null(sub)) sub <- .yoy_footer(m)
  show_ci <- isTRUE(intv) &&
    all(c("pctlo", "pctup") %in% names(d))
  vd <- if (is.null(m$valuedig)) 0L else m$valuedig
  scale <- suppressWarnings(max(abs(d[[chgcol]]), na.rm = TRUE))
  if (!is.finite(scale) || scale == 0) scale <- 1

  head_cells <- c(m$by, m$period, m$value, "previous", "change",
                  if (pp) "points" else "change %")
  if (show_ci) head_cells <- c(head_cells, "interval")
  rows <- vapply(seq_len(nrow(d)), function(r) {
    cls <- .yoy_verdict_class(d$verdict[r])
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
      txt <- if (is.na(d$pctlo[r])) "\u2014" else sprintf(
        "[%s, %s]", .yoy_fmt_pct(d$pctlo[r], 0L),
        .yoy_fmt_pct(d$pctup[r], 0L))
      cells <- c(cells, .yoy_td(txt, "ci"))
    }
    note <- if (is.na(d$flag[r])) "" else sprintf(
      "<tr class=\"note\"><td colspan=\"%d\">note: %s</td></tr>",
      length(head_cells), .yoy_esc(d$flag[r]))
    paste0("<tr class=\"", cls, "\">", paste(cells, collapse = ""),
           "</tr>", note)
  }, "")

  sm <- yoysmry(x)
  html <- c(
    "<!DOCTYPE html>", "<html lang=\"en\"><head>",
    "<meta charset=\"utf-8\">",
    "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">",
    paste0("<title>", .yoy_esc(title), "</title>"),
    paste0("<style>", .yoy_css(.pal), "</style>"),
    "</head><body><main>",
    paste0("<h1>", .yoy_esc(title), "</h1>"),
    paste0("<p class=\"sub\">", .yoy_esc(sub), "</p>"),
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

#' Wraps text in an HTML table cell of a class.
#' @param txt The cell text, already escaped.
#' @param cls The cell's CSS class.
#' @return The `<td>` element as a string.
#' @noRd
.yoy_td <- function(txt, cls) {
  paste0("<td class=\"", cls, "\">", txt, "</td>")
}

#' Builds the HTML cell for a percentage change, with its arrow and optional bar.
#' @param v The change.
#' @param cls The verdict class of the row.
#' @param digits The number of decimal places.
#' @param pp Whether the change is in percentage points.
#' @param bars Whether a bar proportional to the change is drawn.
#' @param scale The largest absolute change in the table, the full width of a bar.
#' @return The `<td>` element as a string.
#' @noRd
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

#' Builds the HTML cards that summarise each series across the span.
#' @param sm The summary table from yoysmry().
#' @param m The yoy table's metadata.
#' @return The HTML section as a string.
#' @noRd
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
      "</div><div class=\"big\">", .yoy_fmt_pct(sm$totalpct[r], 1L),
      "</div><div class=\"cap\">",
      .yoy_esc(sprintf("%s to %s", sm$from[r], sm$to[r])),
      "</div><div class=\"cap\">",
      .yoy_esc(sprintf("compound %s per period",
                       .yoy_fmt_pct(sm$cagrpct[r], 1L))),
      "</div><div class=\"cap\">",
      .yoy_esc(sprintf("%d up, %d down, %d unchanged",
                       sm$up[r], sm$down[r], sm$flat[r])),
      "</div></div>")
  }, "")
  paste0("<h2>Across the span</h2><div class=\"cards\">",
         paste(cells, collapse = ""), "</div>")
}

#' Escapes text for HTML, with NA as the empty string.
#' @param s The text.
#' @return A character vector with `&`, `<`, `>` and both quotes escaped.
#' @noRd
.yoy_esc <- function(s) {
  s <- as.character(s)
  s[is.na(s)] <- ""
  s <- gsub("&", "&amp;", s, fixed = TRUE)
  s <- gsub("<", "&lt;", s, fixed = TRUE)
  s <- gsub(">", "&gt;", s, fixed = TRUE)
  s <- gsub("\"", "&quot;", s, fixed = TRUE)
  gsub("'", "&#39;", s, fixed = TRUE)
}

#' One stylesheet, inlined, defining the palette as custom properties so
#' that the dark theme redefines only the tokens.
#' @param pal The palette, from .yoy_pal().
#' @return The stylesheet as a string.
#' @noRd
.yoy_css <- function(pal) {
  paste0(
    ":root{--bad:", pal$bad, ";--good:", pal$good, ";--flat:", pal$flat,
    ";--badbg:", pal$badbg, ";--goodbg:", pal$goodbg,
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

#' @rdname yoyren
#' @export
yoypdf <- function(x, file, title = "Year-over-year change",
                    sub = NULL, pal = "diverging", digits = 1L,
                    intv = TRUE, notes = NULL,
                    width = 11, height = 8.5, ...) {
  if (!inherits(x, "rmbl_yoy")) {
    stop("yoypdf: `x` must be an rmbl_yoy object from yoy()", call. = FALSE)
  }
  file <- .rmbl_out_file(file, connection = FALSE)
  width <- .rmbl_scalar(width, "width", 2, 200)
  height <- .rmbl_scalar(height, "height", 2, 200)
  title <- .rmbl_text1(title, "title")
  if (!is.null(sub)) sub <- .rmbl_text1(sub, "sub")
  if (!is.null(notes) && (!is.character(notes) || anyNA(notes))) {
    stop("yoypdf: `notes` must be text (a character vector), or NULL", call. = FALSE)
  }
  m <- .yoy_meta(x)
  .pal <- .yoy_pal(pal)
  d <- as.data.frame(x)
  chgcol <- .yoy_change_col(x)
  pp <- identical(chgcol, "ppchg")
  if (is.null(sub)) sub <- .yoy_footer(m)
  show_ci <- isTRUE(intv) &&
    all(c("pctlo", "pctup") %in% names(d))

  hdr <- c(m$by, m$period, m$value, "previous", "change",
           if (pp) "points" else "change %")
  vd <- if (is.null(m$valuedig)) 0L else m$valuedig
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
      is.na(d$pctlo), "\u2014",
      sprintf("[%s, %s]", .yoy_fmt_pct(d$pctlo, 0L),
              .yoy_fmt_pct(d$pctup, 0L))))
  }
  cols <- vapply(.yoy_verdict_class(d$verdict), function(k) .pal[[k]], "", USE.NAMES = FALSE)

  # Paginate on the rows that fit, so a long table becomes several pages
  # rather than one page with the tail cut off.
  # the rows a page holds: the title block takes the top 12 percent and the page label
  # the bottom 6, each row 0.22 inch, and the notes on the last page 0.018 of the height per
  # line; the old flat allowance (height - 2.4) overflowed on tall pages (24 inch: 98 rows
  # planned, 88 fit)
  # notes that would take more than half the last page go on pages of their own after the table
  line_in <- .yoy_note_line(height)
  notes_in <- line_in * (length(notes) + 1L)
  # the rows a page holds never shrink for the notes: they share the last page only when they fit
  # under its rows, and otherwise take pages of their own after the table
  per_page <- .yoy_rows_per_page(height, 0L)
  pages <- split(seq_len(nrow(body)),
                 ceiling(seq_len(nrow(body)) / per_page))
  n_last <- if (length(pages)) length(pages[[length(pages)]]) else 0L
  room_in <- (per_page - n_last) * 0.22
  notes_own_pages <- length(notes) > 0L && notes_in > room_in
  # The PDF device's default Type 1 fonts have no em dash or arrows, and
  # substitute them with a warning per cell. The table says the same
  # thing in the encoding the font can actually draw.
  body[] <- .yoy_ascii(body)
  hdr <- .yoy_ascii(hdr)
  sub <- .yoy_ascii(sub)
  if (length(notes)) notes <- .yoy_ascii(notes)
  grDevices::pdf(file, width = width, height = height,
                 title = title, onefile = TRUE)
  on.exit(grDevices::dev.off(), add = TRUE)
  note_pages <- if (notes_own_pages) {
    per_note_page <- max(1L, as.integer(floor(0.76 * height / line_in)))
    split(notes, ceiling(seq_along(notes) / per_note_page))
  } else {
    list()
  }
  npg <- length(pages) + length(note_pages)
  for (pg in seq_along(pages)) {
    .yoy_pdf_page(hdr, body[pages[[pg]], , drop = FALSE],
                  cols[pages[[pg]]], title, sub, .pal,
                  if (npg > 1L) sprintf("page %d of %d", pg, npg) else "",
                  if (pg == length(pages) && !notes_own_pages) notes else NULL, height = height)
  }
  for (k in seq_along(note_pages)) {
    .yoy_pdf_page(hdr, body[integer(0), , drop = FALSE], character(0), title, sub, .pal,
                  sprintf("page %d of %d", length(pages) + k, npg), note_pages[[k]], height = height,
                  notes_only = TRUE)
  }
  invisible(file)
}

#' Glyphs the PDF device's base fonts cannot draw, rendered as the ASCII
#' that means the same thing.
#' @param x A character vector or matrix.
#' @return `x` with those glyphs replaced, keeping a matrix's shape.
#' @noRd
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

#' Counts the table rows that fit on one PDF page.
#'
#' Rows that fit one page of `height` inches: the title block takes the top 12 percent of the
#' page and the page label the bottom 6, every row 0.22 inch, and the notes (last page)
#' 0.018 of the height per line. .yoy_pdf_page() draws with the same figures.
#' @param height The page height in inches.
#' @param n_notes The number of note lines on the page.
#' @return The number of rows, at least 5.
#' @noRd
.yoy_rows_per_page <- function(height, n_notes = 0L) {
  notes_in <- if (n_notes > 0L) .yoy_note_line(height) * (n_notes + 1L) else 0
  max(5L, as.integer(floor((0.82 * height - 0.22 * 1.1 - notes_in) / 0.22)))
}

#' Gives the height of one note line on a PDF page.
#'
#' The height of one note line: 0.018 of the page, but never under a tenth of an inch (about
#' seven points), so a short page does not print its notes at a size nobody can read.
#' @param height The page height in inches.
#' @return The line height in inches.
#' @noRd
.yoy_note_line <- function(height) max(0.018 * height, 0.1)

#' Draws one page of a yoy table on the open PDF device.
#' @param hdr The column headers.
#' @param body The character matrix of rows for this page.
#' @param cols The colour of each row's change.
#' @param title The page title.
#' @param subtitle The line under the title.
#' @param pal The palette, from .yoy_pal().
#' @param pagelab The page label, or \code{""} for none.
#' @param notes The note lines for this page.
#' @param height The page height in inches.
#' @param notes_only Whether the page holds notes alone.
#' @return NULL, invisibly.
#' @noRd
.yoy_pdf_page <- function(hdr, body, cols, title, subtitle, pal,
                          pagelab, notes, height = 8.5, notes_only = FALSE) {
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
  # 0.22 inch per row in page units, the same figure the pagination used, so
  # every row handed to this page lands on it whatever the page height
  rowh <- 0.22 / height
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
    y <- y - rowh   # the caller hands this page only the rows that fit at this height
  }
  if (nzchar(pagelab)) {
    graphics::text(1, 0.02, pagelab, adj = c(1, 0), cex = 0.6,
                   col = pal$flat)
  }
  if (length(notes)) {
    # one line per 0.018 of the page height, the allowance the pagination made: the text size
    # follows the page, so 30 notes on a 5-inch page fit instead of running off the bottom
    line_in <- .yoy_note_line(height)
    cex_n <- min(0.62, line_in / graphics::par("csi") * 0.95)
    top_n <- if (notes_only) 0.88 else 0.04 + line_in * length(notes) / height
    graphics::text(0, top_n, paste(notes, collapse = "\n"), adj = c(0, 1),
                   cex = cex_n, col = pal$flat)
  }
  invisible(NULL)
}
