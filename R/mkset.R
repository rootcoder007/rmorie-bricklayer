## ----- Several results as one report -----

#' Combine Results into One Report
#'
#' Puts several results together: printed, a box of contents and then every
#' result's own box, all at the console's width; written to a file, one
#' self-contained HTML page (each result's box and, when it has one, its
#' plot), Markdown ready for a GitHub comment or a paper, or plain text.
#'
#' @details
#' Any object this package returns can go in, and any other R object that
#' prints (a model, a data frame): each is shown as it prints. A
#' year-over-year table from [yoy()] becomes a real table in HTML and
#' Markdown.
#'
#' In a file the boxes are drawn 80 characters wide and without colour, so
#' the report looks the same whatever console made it. HTML draws each
#' result's `plot()` under its box (`plots = FALSE` leaves them out); a plot
#' that fails is left out and the box is kept. The page needs no network and
#' nothing installed to open.
#'
#' Errors: no results; a `file` that does not end in `.html`, `.htm`,
#' `.md` or `.txt`; a `title` that is not one string; `plots` that is not
#' `TRUE` or `FALSE`.
#'
#' @param ... The results. A name gives a result its heading
#'   (`"Change by year" = anltab(...)`); an unnamed one is headed by its
#'   box's own title. One unnamed plain list is read as the list of results.
#' @param title The report's heading, default `"Analysis results"`.
#' @param file `NULL` (default) to print, or a file to write: the extension
#'   picks the format (`.html` or `.htm`,
#'   `.md`, `.txt`). An existing file is replaced.
#' @param plots In HTML, draw each result's plot, default `TRUE`.
#' @return An object of class `rmbl_set`: a list with `title` and `items`
#'   (the results, named by their headings). It prints as the report. With
#'   `file`, it is returned invisibly with the written file's path in
#'   attribute `"path"`.
#' @seealso [rptanl()] for the report of one
#' [anltab()] analysis;
#'   [rmblapp()], whose dashboard gathers results the same way.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' x <- c(3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5)
#' d <- data.frame(year = rep(2020:2023, 2), grp = rep(c("a", "b"), each = 4),
#'                 n = c(5, 7, 9, 11, 4, 6, 8, 7), pop = 1000)
#' s <- mkset(
#'   "How unequal" = ginicoef(x),
#'   "Rates by group" = rtcalc(d, "n", "pop", by = "grp"),
#'   title = "My study"
#' )
#' s
#'
#' # one page, one Markdown file, one text file
#' mkset(s$items, title = "My study", file = file.path(tempdir(), "r.html"))
#' mkset(s$items, title = "My study", file = file.path(tempdir(), "r.md"))
#' mkset(s$items, title = "My study", file = file.path(tempdir(), "r.txt"))
#'
#' # the extension picks the format
#' try(mkset(ginicoef(x), file = file.path(tempdir(), "r.pdf")))
#' @export
mkset <- function(..., title = "Analysis results", file = NULL,
                  plots = TRUE) {
  items <- list(...)
  if (
    length(items) == 1L &&
      is.null(names(items)) &&
      is.list(items[[1L]]) &&
      !is.object(items[[1L]])
  ) {
    items <- items[[1L]]
  }
  if (!length(items)) {
    stop("mkset: give at least one result", call. = FALSE)
  }
  title <- .rmbl_string1(title, "title")
  plots <- .rmbl_flag1(plots, "plots")
  nm <- names(items) %||% rep("", length(items))
  nm[is.na(nm)] <- ""
  names(items) <- vapply(
    seq_along(items),
    function(k) if (nzchar(nm[k])) nm[k] else .mkset_head(items[[k]], k),
    ""
  )
  out <- .rmbl_cls(list(title = title, items = items), "rmbl_set")
  if (is.null(file)) {
    return(out)
  }
  file <- .rmbl_string1(file, "file")
  ext <- tolower(tools::file_ext(file))
  if (!ext %in% c("html", "htm", "md", "txt")) {
    stop(
      sprintf(
        "mkset: `file` must end in .html, .md or .txt, not .%s",
        ext
      ),
      call. = FALSE
    )
  }
  txt <- switch(
    ext,
    html = ,
    htm = .mkset_html(out, plots),
    md = .mkset_md(out),
    txt = paste(.mkset_lines(out), collapse = "\n")
  )
  .bndl_write_text(sub("\n$", "", txt), file)
  attr(out, "path") <- normalizePath(file, winslash = "/")
  invisible(out)
}

#' @export
format.rmbl_set <- function(x, ...) {
  it <- x$items
  cls <- vapply(it, function(v) class(v)[1L], "")
  .an_block(
    x$title,
    facts = list(Results = length(it)),
    tables = list(data.frame(
      No = seq_along(it),
      Result = names(it),
      Class = unname(cls),
      stringsAsFactors = FALSE
    )),
    reading = paste(
      "Each result follows under its number. mkset(..., file = ) writes",
      "them as one HTML page (.html), Markdown (.md) or text (.txt)."
    )
  )
}

#' @export
print.rmbl_set <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  it <- x$items
  for (k in seq_along(it)) {
    cat("\n", k, ". ", names(it)[k], "\n\n", sep = "")
    .mkset_show(it[[k]])
  }
  invisible(x)
}

#' A result's heading when it was given no name: its box's title.
#' @param v The result.
#' @param k Its position.
#' @return One string.
#' @noRd
.mkset_head <- function(v, k) {
  l1 <- tryCatch(
    as.character(if (.mkset_own(v)) format(v) else .mkset_box(v))[1L],
    error = function(e) NA
  )
  pat <- "^(\u2500\u2500|--) (.*?) (\u2500|-)*$"
  head <- if (length(l1) && !is.na(l1) && grepl(pat, l1, perl = TRUE)) {
    trimws(sub(pat, "\\2", l1, perl = TRUE))
  }
  # a box titled only by its class says less than its place in the set
  if (length(head) && !identical(head, class(v)[1L])) {
    return(head)
  }
  sprintf("Result %d (%s)", k, class(v)[1L])
}

#' What a result prints, 80 characters wide and without colour.
#' @param v The result.
#' @return Lines.
#' @noRd
.mkset_lines <- function(v) {
  op <- options(rmoriebricklayer.width = 80L, rmoriebricklayer.numcol = 1L)
  on.exit(options(op), add = TRUE)
  shown <- if (inherits(v, "rmbl_set")) {
    utils::capture.output(print(v))
  } else {
    utils::capture.output(.mkset_show(v))
  }
  gsub("\033\\[[0-9;]*m", "", shown)
}

#' The results as report entries (heading, text, plot, yoy table).
#' @param x A set.
#' @param plots Whether to draw the plots.
#' @return A list of entries for .bl_rpt_html() and .bl_rpt_md().
#' @noRd
.mkset_entries <- function(x, plots = FALSE) {
  lapply(seq_along(x$items), function(k) {
    v <- x$items[[k]]
    list(
      title = names(x$items)[k],
      code = NULL,
      text = .mkset_lines(v),
      svg = if (plots) .mkset_plot(v),
      yoy = if (inherits(v, "rmbl_yoy")) v
    )
  })
}

#' A result's plot as markup, or NULL when it has none or it fails.
#' @param v The result.
#' @param big The largest SVG kept as vectors, in bytes.
#' @return One string or NULL.
#' @noRd
.mkset_plot <- function(v, big = 300000) {
  has <- any(vapply(
    class(v),
    function(cl) !is.null(utils::getS3method("plot", cl, optional = TRUE)),
    NA
  ))
  if (!has) {
    return(NULL)
  }
  env <- new.env()
  env$v <- v
  svg <- tryCatch(.bl_svg(quote(plot(v)), env), error = function(e) NULL)
  # a plot of many marks (a hexbin, a particle cloud) is megabytes as
  # vectors: past `big` characters it is drawn as a picture instead
  if (!is.null(svg) && nchar(svg, type = "bytes") > big) {
    svg <- .mkset_png(quote(plot(v)), env)
  }
  svg
}

#' A plot call as a PNG data URI image.
#' @param expr The plot call.
#' @param env Where to evaluate it.
#' @return One string of markup.
#' @noRd
.mkset_png <- function(expr, env) {
  f <- tempfile(fileext = ".png")
  on.exit(unlink(f), add = TRUE)
  grDevices::png(f, 1500, 920, res = 192)
  tryCatch(eval(expr, env), finally = grDevices::dev.off())
  sprintf(
    "<img alt=\"plot\" src=\"data:image/png;base64,%s\">",
    jsb64enc(readBin(f, "raw", file.size(f)))
  )
}

#' The set as one HTML page.
#' @param x A set.
#' @param plots Whether to draw the plots.
#' @return One string.
#' @noRd
.mkset_html <- function(x, plots) {
  .bl_rpt_html(
    .mkset_entries(x, plots),
    x$title,
    sub = sprintf(
      "%d result%s, each as it prints%s.",
      length(x$items),
      if (length(x$items) == 1L) "" else "s",
      if (plots) ", with its plot where it has one" else ""
    )
  )
}

#' The set as Markdown.
#' @param x A set.
#' @return One string.
#' @noRd
.mkset_md <- function(x) {
  .bl_rpt_md(.mkset_entries(x), x$title)
}
