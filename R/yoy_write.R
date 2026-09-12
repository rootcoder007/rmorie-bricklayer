# Tabular and machine-readable output for a change table.
#
# The delimited writers exist so that the number a reader sees in the
# HTML or the PDF is the number a pipeline downstream reads, from the
# same object, with the withheld percentages still marked as withheld
# and the reason still attached. A CSV that silently drops the `flag`
# column would hand on the one figure the table declined to stand
# behind.

#' Write a change table to a file, in whatever format the name implies
#'
#' @param x An `rmbl_yoy` object from [yoy()].
#' @param file Output path.
#' @param format Output format. `"auto"` reads it from the file
#'   extension: `.html`/`.htm`, `.pdf`, `.csv`, `.tsv`/`.tab`, `.json`,
#'   `.md`/`.markdown`.
#' @param ... Passed to the format's own writer, so the colour, digit and
#'   layout options of [yoy_html()] and [yoy_pdf()] are available here
#'   too.
#' @return The path, invisibly.
#' @seealso [yoy_html()], [yoy_pdf()], [yoy_csv()]
#' @examples
#' d <- data.frame(year = 2019:2023, n = c(402, 377, 190, 268, 331))
#' y <- yoy(d, value = "n", period = "year")
#'
#' for (ext in c("csv", "tsv", "json", "md", "html")) {
#'   f <- file.path(tempdir(), paste0("change.", ext))
#'   yoy_write(y, f)
#'   cat(ext, file.size(f), "bytes\n")
#'   unlink(f)
#' }
#' @export
yoy_write <- function(x, file, format = "auto", ...) {
  if (!inherits(x, "rmbl_yoy")) {
    stop("`x` must be an rmbl_yoy object from yoy()", call. = FALSE)
  }
  file <- as.character(file)[1L]
  format <- tolower(as.character(format)[1L])
  if (identical(format, "auto")) {
    ext <- tolower(sub(".*\\.", "", basename(file)))
    format <- switch(ext,
      html = , htm = "html",
      pdf = "pdf",
      csv = "csv",
      tsv = , tab = "tsv",
      json = "json",
      md = , markdown = "markdown",
      stop(sprintf(
        "cannot tell the format from \"%s\"; pass format = explicitly",
        basename(file)), call. = FALSE))
  }
  switch(format,
    html = yoy_html(x, file, ...),
    pdf = yoy_pdf(x, file, ...),
    csv = yoy_csv(x, file, ...),
    tsv = yoy_tsv(x, file, ...),
    json = yoy_json(x, file, ...),
    markdown = yoy_markdown(x, file, ...),
    stop(sprintf("unknown format: %s", format), call. = FALSE))
}

#' Write a change table as delimited text, JSON or Markdown
#'
#' `yoy_csv()` separates fields with a comma and quotes any field that
#' contains one; `yoy_tsv()` separates with a tab and replaces any tab
#' inside a field, since a tab-separated field cannot contain one and
#' writing it would shift every column after it.
#'
#' @param x An `rmbl_yoy` object from [yoy()].
#' @param file Output path, or `NULL` to return the text instead of
#'   writing it.
#' @param digits Digits for the percent columns. `NULL`, the default,
#'   writes them unrounded, which is what a downstream calculation
#'   wants; give a number for a figure meant to be read.
#' @param na How to write a missing value. The default empty string is
#'   what most readers expect; `"NA"` keeps R's own spelling.
#' @param metadata Whether to lead with comment lines recording the lag,
#'   units, confidence level, base gate and direction. On by default,
#'   because a percent column means different things under different
#'   settings and the file is the only place a later reader can look.
#'   Markdown and JSON carry the same information structurally.
#' @param comment Comment prefix for the metadata lines.
#' @param align Whether to pad the Markdown columns so the source table
#'   is readable unrendered.
#' @param pretty Whether to indent the JSON.
#' @param ... Ignored.
#' @return The path, invisibly; or the text, when `file` is `NULL`.
#' @examples
#' d <- data.frame(year = 2019:2023, n = c(402, 377, 190, 268, 331))
#' y <- yoy(d, value = "n", period = "year")
#'
#' # Straight to text, for inspection.
#' cat(yoy_csv(y, NULL))
#'
#' # Markdown, for a report.
#' cat(yoy_markdown(y, NULL))
#'
#' # JSON keeps the settings as fields rather than as comments.
#' substr(yoy_json(y, NULL), 1, 80)
#' @name yoy_delim
#' @export
yoy_csv <- function(x, file, digits = NULL, na = "", metadata = TRUE,
                    comment = "#", ...) {
  .yoy_delim(x, file, sep = ",", digits = digits, na = na,
             metadata = metadata, comment = comment)
}

#' @rdname yoy_delim
#' @export
yoy_tsv <- function(x, file, digits = NULL, na = "", metadata = TRUE,
                    comment = "#", ...) {
  .yoy_delim(x, file, sep = "\t", digits = digits, na = na,
             metadata = metadata, comment = comment)
}

.yoy_delim <- function(x, file, sep, digits, na, metadata, comment) {
  if (!inherits(x, "rmbl_yoy")) {
    stop("`x` must be an rmbl_yoy object from yoy()", call. = FALSE)
  }
  m <- .yoy_meta(x)
  d <- .yoy_export_frame(x, digits)
  quoting <- identical(sep, ",")
  lines <- character(0)
  if (isTRUE(metadata)) {
    lines <- c(lines, paste0(comment, " ", .yoy_meta_lines(m)))
  }
  cell <- function(v) {
    out <- ifelse(is.na(v), na, as.character(v))
    if (!quoting) {
      # a tab-separated field cannot contain a tab, and silently writing
      # one would shift every column after it
      return(gsub("[\t\r\n]", " ", out))
    }
    needs <- grepl("[,\"\r\n]", out)
    out[needs] <- paste0("\"", gsub("\"", "\"\"", out[needs]), "\"")
    out
  }
  hdr <- paste(cell(names(d)), collapse = sep)
  body <- if (nrow(d)) {
    apply(vapply(d, cell, character(nrow(d))), 1L,
          function(r) paste(r, collapse = sep))
  } else {
    character(0)
  }
  txt <- paste0(paste(c(lines, hdr, body), collapse = "\n"), "\n")
  if (is.null(file)) return(txt)
  writeLines(txt, file, sep = "", useBytes = TRUE)
  invisible(file)
}

#' @rdname yoy_delim
#' @export
yoy_json <- function(x, file, digits = NULL, pretty = TRUE, ...) {
  if (!inherits(x, "rmbl_yoy")) {
    stop("`x` must be an rmbl_yoy object from yoy()", call. = FALSE)
  }
  m <- .yoy_meta(x)
  d <- .yoy_export_frame(x, digits)
  # Written with this package's own JSON codec, so the file is produced
  # by the same writer whose output the manifest digests.
  settings <- list(value = m$value, period = m$period)
  # An absent grouping is an absent key, not an empty object: a NULL
  # inside a list serialises as {}, which reads as "grouped by nothing
  # in particular" rather than "not grouped".
  if (!is.null(m$by)) settings$by <- as.list(m$by)
  settings <- c(settings,
                list(lag = m$lag, units = m$units, min_base = m$min_base,
                     conf_level = m$conf_level, direction = m$direction))
  obj <- list(
    settings = settings,
    summary = yoy_summary(x),
    rows = d)
  txt <- as.character(bricklayer_json_to_json(obj, pretty = pretty,
                                              auto_unbox = TRUE,
                                              na = "null"))
  if (is.null(file)) return(txt)
  writeLines(txt, file, useBytes = TRUE)
  invisible(file)
}

#' @rdname yoy_delim
#' @export
yoy_markdown <- function(x, file, digits = 1L, align = TRUE, ...) {
  if (!inherits(x, "rmbl_yoy")) {
    stop("`x` must be an rmbl_yoy object from yoy()", call. = FALSE)
  }
  m <- .yoy_meta(x)
  d <- as.data.frame(x)
  chgcol <- .yoy_change_col(x)
  pp <- identical(chgcol, "pp_change")
  vd <- if (is.null(m$value_digits)) 0L else m$value_digits
  cols <- list()
  if (!is.null(m$by)) {
    for (b in m$by) cols[[b]] <- as.character(d[[b]])
  }
  cols[[m$period]] <- .yoy_period_text(d, m)
  cols[[m$value]] <- .yoy_fmt_num(d$value, vd)
  cols[["previous"]] <- .yoy_fmt_num(d$previous, vd)
  cols[["change"]] <- .yoy_fmt_num(d$change, vd)
  cols[[if (pp) "points" else "change %"]] <-
    .yoy_fmt_pct(d[[chgcol]], digits, pp)
  if (all(c("pct_lower", "pct_upper") %in% names(d))) {
    cols[["interval"]] <- ifelse(
      is.na(d$pct_lower), "",
      sprintf("[%s, %s]", .yoy_fmt_pct(d$pct_lower, 0L),
              .yoy_fmt_pct(d$pct_upper, 0L)))
  }
  cols[["note"]] <- ifelse(is.na(d$flag), "", d$flag)
  # a pipe inside a cell would end the cell
  cols <- lapply(cols, function(v) gsub("|", "\\|", v, fixed = TRUE))
  nms <- names(cols)
  numeric_from <- length(nms) -
    (if ("interval" %in% nms) 3L else 2L)
  # Display WIDTH, not character count: the em dash standing in for a
  # missing value is one character and one column, but a byte count
  # would misjudge it and the rule under the header would not line up
  # with the header.
  w <- if (isTRUE(align)) {
    vapply(seq_along(cols), function(i) {
      max(3L, nchar(c(nms[i], cols[[i]]), type = "width"), na.rm = TRUE)
    }, 0L)
  } else {
    rep(0L, length(cols))
  }
  padr <- function(s, k, right) {
    gap <- max(0L, w[k] - nchar(s, type = "width"))
    if (right) paste0(strrep(" ", gap), s) else paste0(s, strrep(" ", gap))
  }
  right <- seq_along(cols) >= numeric_from & nms != "note"
  row <- function(vals) {
    paste0("| ", paste(vapply(seq_along(vals), function(k) {
      padr(vals[k], k, right[k])
    }, ""), collapse = " | "), " |")
  }
  # the rule is exactly as wide as its column, with a trailing colon
  # marking a right-aligned one
  rule <- paste0("| ", paste(vapply(seq_along(cols), function(k) {
    # three dashes is the shortest rule Markdown accepts, and with
    # align = FALSE the widths are zero
    width <- max(3L, w[k])
    if (right[k]) paste0(strrep("-", width - 1L), ":") else strrep("-", width)
  }, ""), collapse = " | "), " |")
  lines <- c(row(nms), rule,
             vapply(seq_len(nrow(d)), function(r) {
               row(vapply(cols, function(v) v[r], ""))
             }, ""))
  meta <- paste0("_", .yoy_meta_lines(m), "_")
  txt <- paste0(paste(c(lines, "", meta), collapse = "\n"), "\n")
  if (is.null(file)) return(txt)
  writeLines(txt, file, useBytes = TRUE)
  invisible(file)
}

# One line describing what the percentages mean, shared by every writer
# so the caveat cannot drift between formats.
.yoy_meta_lines <- function(m) {
  bits <- c(sprintf("value: %s", m$value),
            sprintf("period: %s", m$period),
            if (!is.null(m$by)) sprintf("by: %s",
                                        paste(m$by, collapse = ", ")),
            sprintf("lag: %d", m$lag),
            sprintf("units: %s", m$units))
  if (identical(m$units, "count")) {
    bits <- c(bits,
              sprintf("interval: %.0f%% exact rate ratio",
                      100 * m$conf_level),
              sprintf("percent withheld below a base of %g", m$min_base))
  }
  if (identical(m$units, "percent")) {
    bits <- c(bits, "change is in percentage points")
  }
  if (!identical(m$direction, "neutral")) {
    bits <- c(bits, sprintf("direction: %s", gsub("_", " ", m$direction)))
  }
  paste(bits, collapse = "; ")
}

# The data frame the machine-readable writers export: every column the
# object carries, with the percent columns optionally rounded. The `flag`
# column travels with them, so a withheld percentage stays marked as
# withheld wherever it lands.
.yoy_export_frame <- function(x, digits) {
  d <- as.data.frame(x)
  if (!is.null(digits)) {
    digits <- as.integer(digits)[1L]
    for (nm in intersect(c("pct_change", "pp_change", "pct_lower",
                           "pct_upper"), names(d))) {
      d[[nm]] <- round(d[[nm]], digits)
    }
  }
  d
}
