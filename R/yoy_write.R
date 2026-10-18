# Tabular and machine-readable output for a change table.
#
# The delimited writers exist so that the number a reader sees in the
# HTML or the PDF is the number a pipeline downstream reads, from the
# same object, with each row's note
# still attached. A CSV that silently drops the `flag`
# column would hand on the one figure the table declined to stand
# behind.

#' Write a change table to a file, in whatever format the name implies
#'
#' Writes a period-over-period table from [yoy()] in the format the
#' file
#' name implies, so one call serves a web page, a PDF for a report, a CSV for
#' a spreadsheet, JSON for a program or Markdown for a README. Every format is
#' written from the same object, with each row's note attached, so the number
#' a reader sees and the number a pipeline reads are the same.
#'
#' @details
#' The extension is matched case-insensitively: \code{.html} and \code{.htm}
#' go to [yoyhtml()], \code{.pdf} to
#' [yoypdf()], \code{.csv} to
#' [yoycsv()], \code{.tsv} and \code{.tab} to
#' [yoytsv()], \code{.json} to
#' [yoyjs()], \code{.md} and \code{.markdown} to
#' [yoymd()]. An
#' existing file is overwritten. Errors when \code{x} does not come from
#' [yoy()], when the format cannot be read from the extension (pass
#' \code{format}), or when \code{format} is not one of the names below; and
#' whatever error the chosen writer raises.
#'
#' @param x An \code{rmbl_yoy} object from
#' [yoy()].
#' @param file Character scalar, the output path.
#' @param format Character scalar, the output format: \code{"auto"} (the
#' default) reads it from the file extension; otherwise one of
#' \code{"html"}, \code{"pdf"}, \code{"csv"}, \code{"tsv"}, \code{"json"}
#' or \code{"markdown"} (case-insensitive).
#' @param ... Passed to the format's own writer, so the colour,
#' digit and layout options of [yoyhtml()] and
#' [yoypdf()] are available here too.
#' @return \code{file}, invisibly (as returned by the chosen writer).
#' @seealso
#' [yoyhtml()], [yoypdf()],
#' [yoycsv()]
#' @examples
#' d <- data.frame(year = 2019:2023, n = c(402, 377, 190, 268, 331))
#' y <- yoy(d, value = "n", prd = "year")
#'
#' for (ext in c("csv", "tsv", "json", "md", "html")) {
#'   f <- file.path(tempdir(), paste0("change.", ext))
#'   yoywr(y, f)
#'   cat(ext, file.size(f), "bytes\n")
#'   unlink(f)
#' }
#'
#' # an extension that names no format: say which one
#' f <- file.path(tempdir(), "change.txt")
#' yoywr(y, f, format = "csv", digits = 1)
#' readLines(f, n = 3)
#' unlink(f)
#' try(yoywr(y, file.path(tempdir(), "change.xlsx")))
#' @export
yoywr <- function(x, file, format = "auto", ...) {
  .rmbl_no_fn(file = file, format = format)
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
    html = yoyhtml(x, file, ...),
    pdf = yoypdf(x, file, ...),
    csv = yoycsv(x, file, ...),
    tsv = yoytsv(x, file, ...),
    json = yoyjs(x, file, ...),
    markdown = yoymd(x, file, ...),
    stop(sprintf("unknown format: %s", format), call. = FALSE))
}

#' Write a change table as delimited text, JSON or Markdown
#'
#' `yoycsv()` separates fields with a comma and quotes any field that
#' contains one; `yoytsv()` separates with a tab and replaces any tab
#' inside a field, since a tab-separated field cannot contain one and
#' writing it would shift every column after it.
#' `yoyjs()` writes an object with `settings` (value, period, grouping,
#' lag, units, minimum base, confidence level, direction), `summary` (from
#' [yoysmry()]) and `rows`, using the package's own
#' JSON codec.
#' `yoymd()` writes a pipe table meant for reading: values formatted
#' (every numeric column right-aligned),
#' percentages signed and rounded, the interval as `[lower, upper]`, notes in
#' the last column, and the settings in an italic line under the table.
#'
#' @details
#' The CSV and TSV writers export every column of the object (the period and
#' grouping columns, `value`, `previous`, `change`, the percent or
#' percentage-point change, `flag`, the interval and `verdict`), so the note
#' explaining a missing or flagged figure stays with its row. Quoting in the
#' CSV follows RFC 4180 (a field with a comma, a quote or a line break is
#' quoted, quotes doubled). The metadata line names the value and period
#' columns, the grouping, the lag, the units, and for counts the interval's
#' confidence level and the base below which changes are noted. A pipe inside
#' a Markdown cell is escaped. An existing file is overwritten. Errors when
#' `x` does not come from [yoy()], or `digits` is not a whole
#' number.
#'
#' @param x An `rmbl_yoy` object from
#' [yoy()].
#' @param file Character scalar, the output path, or `NULL` to return the
#' text instead of writing it.
#' @param digits Integer scalar or `NULL`: decimal places for the percent
#' columns. For the CSV, TSV and JSON writers `NULL`, the default, writes them
#' unrounded, which is what a downstream calculation wants; give a number for
#' a figure meant to be read. For `yoymd()` the default is `1`.
#' @param na Character scalar, how to write a missing value (CSV and TSV). The
#' default empty string is what most readers expect; `"NA"` keeps R's own
#' spelling.
#' @param meta Whether to lead with comment lines
#' recording the lag, units, confidence level, base gate and direction. On
#' by default, because a percent column means different things under
#' different settings and the file is the only place a later reader can
#' look. Markdown and JSON carry the same information structurally.
#' @param comment Character scalar, the comment prefix for the metadata
#' lines; default `"#"`.
#' @param align Logical scalar, default `TRUE`: pad the Markdown columns so
#' the source table is readable unrendered.
#' @param pretty Logical scalar, default `TRUE`: indent the JSON.
#' @param ... Ignored.
#' @return `file`, invisibly; or, when `file` is `NULL`, the text as a
#' character scalar.
#' @examples
#' d <- data.frame(year = 2019:2023, n = c(402, 377, 190, 268, 331))
#' y <- yoy(d, value = "n", prd = "year")
#'
#' # Straight to text, for inspection.
#' cat(yoycsv(y, NULL))
#'
#' # Markdown, for a report.
#' cat(yoymd(y, NULL))
#'
#' # JSON keeps the settings as fields rather than as comments.
#' substr(yoyjs(y, NULL), 1, 80)
#'
#' # rounded percentages, no metadata line, and R's own NA
#' cat(yoytsv(y, NULL, digits = 1, meta = FALSE, na = "NA"))
#'
#' # written to a file
#' f <- tempfile(fileext = ".csv")
#' yoycsv(y, f)
#' read.csv(f, comment.char = "#")[, c("year", "pctchg", "flag")]
#'
#' # only yoy() results are accepted
#' try(yoycsv(d, NULL))
#' @name yoydelim
#' @export
yoycsv <- function(x, file, digits = NULL, na = "", meta = TRUE,
                    comment = "#", ...) {
  .yoy_delim(x, file, sep = ",", digits = digits, na = na,
             metadata = meta, comment = comment)
}

#' @rdname yoydelim
#' @export
yoytsv <- function(x, file, digits = NULL, na = "", meta = TRUE,
                    comment = "#", ...) {
  .yoy_delim(x, file, sep = "\t", digits = digits, na = na,
             metadata = meta, comment = comment)
}

.yoy_delim <- function(x, file, sep, digits, na, metadata, comment) {
  if (!inherits(x, "rmbl_yoy")) {
    stop("`x` must be an rmbl_yoy object from yoy()", call. = FALSE)
  }
  file <- .rmbl_out_file(file)
  na <- .rmbl_text1(na, "na")
  comment <- .rmbl_text1(comment, "comment")
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

#' @rdname yoydelim
#' @export
yoyjs <- function(x, file, digits = NULL, pretty = TRUE, ...) {
  if (!inherits(x, "rmbl_yoy")) {
    stop("`x` must be an rmbl_yoy object from yoy()", call. = FALSE)
  }
  file <- .rmbl_out_file(file)
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
                list(lag = m$lag, units = m$units, minbase = m$minbase,
                     conflvl = m$conflvl, direction = m$direction))
  obj <- list(
    settings = settings,
    summary = yoysmry(x),
    rows = d)
  txt <- as.character(tojs(obj, pretty = pretty,
                                              auto_unbox = TRUE,
                                              na = "null"))
  if (is.null(file)) return(txt)
  writeLines(txt, file, useBytes = TRUE)
  invisible(file)
}

#' @rdname yoydelim
#' @export
yoymd <- function(x, file, digits = 1L, align = TRUE, ...) {
  if (!inherits(x, "rmbl_yoy")) {
    stop("`x` must be an rmbl_yoy object from yoy()", call. = FALSE)
  }
  file <- .rmbl_out_file(file)
  m <- .yoy_meta(x)
  d <- as.data.frame(x)
  chgcol <- .yoy_change_col(x)
  pp <- identical(chgcol, "ppchg")
  vd <- if (is.null(m$valuedig)) 0L else m$valuedig
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
  if (all(c("pctlo", "pctup") %in% names(d))) {
    cols[["interval"]] <- ifelse(
      is.na(d$pctlo), "",
      sprintf("[%s, %s]", .yoy_fmt_pct(d$pctlo, 0L),
              .yoy_fmt_pct(d$pctup, 0L)))
  }
  cols[["note"]] <- ifelse(is.na(d$flag), "", d$flag)
  # a pipe inside a cell would end the cell
  cols <- lapply(cols, function(v) gsub("|", "\\|", v, fixed = TRUE))
  nms <- names(cols)
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
  # every numeric column right-aligned: counting back from the end had left the value and the
  # previous value aligned left while the change beside them was aligned right
  right <- seq_along(cols) > length(m$by) + 1L & nms != "note"
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
                      100 * m$conflvl))
    if (isTRUE(m$minbase > 0)) bits <- c(bits, sprintf("bases below %g noted", m$minbase))
  }
  if (identical(m$units, "percent")) {
    bits <- c(bits, "change is in percentage points")
  }
  if (!identical(m$direction, "neutral")) {
    bits <- c(bits, sprintf("direction: %s is better", m$direction))
  }
  paste(bits, collapse = "; ")
}

# The data frame the machine-readable writers export: every column the
# object carries, with the percent columns optionally rounded. The `flag`
# column travels with them, so a row's note (zero base, missing period)
# stays with it wherever it lands.
.yoy_export_frame <- function(x, digits) {
  d <- as.data.frame(x)
  if (!is.null(digits)) {
    digits <- .rmbl_num(digits, "digits", integer = TRUE)[1L]
    for (nm in intersect(c("pctchg", "ppchg", "pctlo",
                           "pctup"), names(d))) {
      d[[nm]] <- round(d[[nm]], digits)
    }
  }
  d
}
