# SPDX-License-Identifier: AGPL-3.0-or-later
# Drift for people who will not read a console: the verdicts under PSI bands a reader can move,
# an interactive page that is one file with nothing fetched, and a Shiny app over the same data.
# Both draw from the binned summaries cpsdrft() keeps (`summ`), never from the rows.

#' The colours of the four verdicts: ok, warn, fail and untested.
#' @noRd
.BL_VERDICT_COLS <- c(ok = "#2166AC", warn = "#E69F00", fail = "#D6604D", untested = "#8C8C8C")

#' The PSI bands of a drift result, the caller's when given, checked.
#' @param x A cpsdrft() result.
#' @param warn,fail The caller's bands, or NULL for the object's.
#' @return A list with `warn` and `fail`.
#' @noRd
.bl_drift_bands <- function(x, warn = NULL, fail = NULL) {
  fail <- .rmbl_scalar(fail %||% x$bands[["fail"]] %||% x$psithr %||% 0.25, "fail", 0)
  warn <- .rmbl_scalar(warn %||% x$bands[["warn"]] %||% min(0.1, fail), "warn", 0)
  if (warn > fail) stop(.rmbl_fn(), "`warn` must not be above `fail`", call. = FALSE)
  list(warn = warn, fail = fail)
}

#' The verdict of each column under PSI bands.
#'
#' fail: the test rejects at `alpha`, or the PSI is above `fail` with both samples at least
#' `psiminn` (cpsdrft()'s `drifted` at `fail = psithr`); warn: the PSI is above `warn`; untested: no
#' p-value; ok otherwise. drfthtml()'s page scores the same way in its script.
#' @param x A cpsdrft() result.
#' @param warn,fail The PSI bands.
#' @param alpha The level of the tests.
#' @return A character vector, one verdict per row of `x$columns`.
#' @noRd
.bl_drift_verdict <- function(x, warn, fail, alpha = x$alpha) {
  d <- x$columns
  n <- function(f) vapply(d$column, function(cl) as.numeric(x$summ[[cl]][[f]] %||% NA), 0, USE.NAMES = FALSE)
  large <- if (is.null(x$summ)) rep(TRUE, nrow(d)) else
    (n("nref") >= (x$psiminn %||% 0)) %in% TRUE & (n("ncur") >= (x$psiminn %||% 0)) %in% TRUE
  v <- ifelse(is.na(d$p_value), "untested", "ok")
  v[!is.na(d$psi) & d$psi > warn] <- "warn"
  v[(!is.na(d$p_value) & d$p_value < alpha) | (!is.na(d$psi) & large & d$psi > fail)] <- "fail"
  v
}

#' The test each column type runs.
#' @param type The column types.
#' @return The test names.
#' @noRd
.bl_drift_test <- function(type) {
  unname(c(numeric = "KS", date = "KS", categorical = "chi-square homogeneity",
           identifier = "none")[type])
}

#' The column table of a drift result under PSI bands, worst first.
#' @param x A cpsdrft() result.
#' @param warn,fail The PSI bands.
#' @return A data frame: verdict, column, type, test, statistic, p_value, psi, missing_change
#'   (current less reference missing share), nref and ncur.
#' @noRd
.bl_drift_table <- function(x, warn, fail) {
  d <- x$columns
  s <- function(f) vapply(d$column, function(cl) as.numeric(x$summ[[cl]][[f]] %||% NA), 0, USE.NAMES = FALSE)
  out <- data.frame(verdict = .bl_drift_verdict(x, warn, fail), column = d$column, type = d$type,
                    test = .bl_drift_test(d$type), statistic = d$statistic, p_value = d$p_value, psi = d$psi,
                    missing_change = s("misscur") - s("missref"), nref = s("nref"), ncur = s("ncur"),
                    stringsAsFactors = FALSE)
  out[order(match(out$verdict, c("fail", "warn", "ok", "untested")), -xtfrm(ifelse(is.na(out$psi), -1, out$psi))), ,
      drop = FALSE]
}

#' One paragraph on what a column's verdict means.
#' @param r One row of .bl_drift_table().
#' @param b The PSI bands.
#' @param alpha The level of the tests.
#' @param note The column's note from cpsdrft().
#' @return One string.
#' @noRd
.bl_drift_note <- function(r, b, alpha, note = "") {
  f <- function(v) if (is.na(v)) "none" else trimws(formatC(v, digits = 3, format = "g"))
  switch(r$verdict,
    fail = paste0(r$column, " moved: ",
                  if (!is.na(r$p_value) && r$p_value < alpha) {
                    sprintf("the %s test gives p = %s, below alpha %s", r$test, f(r$p_value), f(alpha))
                  } else {
                    sprintf("its PSI of %s is above the fail band %s", f(r$psi), f(b$fail))
                  }, "; ", .bl_check_meaning("source_columns"), "."),
    warn = sprintf("%s is worth a look: its PSI of %s is above the warn band %s, though the test gives p = %s.",
                   r$column, f(r$psi), f(b$warn), f(r$p_value)),
    ok = sprintf("%s looks the same in both: PSI %s, below the warn band %s, and p = %s.",
                 r$column, f(r$psi), f(b$warn), f(r$p_value)),
    sprintf("%s was not tested: %s.", r$column, if (nzchar(note)) note else "no test applies"))
}

#' The record of a provenance that a report heads with.
#' @param p A provenance record (a list), or NULL.
#' @return A list (name, url, sha256, date), or NULL.
#' @noRd
.bl_drift_prov <- function(p) {
  if (!is.list(p)) return(NULL)
  s1 <- function(...) {
    for (v in list(...)) {
      v <- unlist(v)
      if (length(v) && !is.na(v[[1L]])) return(as.character(v[[1L]]))
    }
    NULL
  }
  src <- if (is.list(p$source)) p$source else list()
  list(name = s1(p$name), url = s1(p$resource$direct_url, src$url),
       sha256 = s1(src$sha256, p$resource$sha256),
       date = s1(src$retrieved, src$date, p$retrieved, p$date, p$resource$retrieved))
}

#' Everything a drift report shows, as one list: the data of drfthtml()'s page and drftapp().
#' @param x A cpsdrft() result, perhaps with `provenance` and `manifest` attached.
#' @param warn,fail The PSI bands, or NULL for the object's.
#' @param title The report's title.
#' @return A list, written to the page as JSON.
#' @noRd
.bl_drift_payload <- function(x, warn = NULL, fail = NULL, title = "Drift report") {
  b <- .bl_drift_bands(x, warn, fail)
  d <- x$columns
  v <- .bl_drift_verdict(x, b$warn, b$fail)
  cols <- lapply(seq_len(nrow(d)), function(i) {
    s <- x$summ[[d$column[i]]] %||% list()
    c(as.list(d[i, c("column", "type", "statistic", "p_value", "psi", "jsdiv", "unseen_share", "drifted", "note")]),
      list(test = .bl_drift_test(d$type[i]), verdict = v[i], nref = s$nref, ncur = s$ncur,
           missref = s$missref, misscur = s$misscur, stats = s$stats, top = s$top, bins = s$bins,
           hist = s$hist, benford = s$benford))
  })
  list(title = title, version = as.character(utils::packageVersion("rmoriebricklayer")),
       written = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), nref = x$nref, ncur = x$ncur, alpha = x$alpha,
       psiminn = x$psiminn %||% 0, bands = b, anydrft = isTRUE(x$anydrft), added = as.list(x$added),
       removed = as.list(x$removed), meaning = .bl_check_meaning("source_columns"), columns = cols,
       provenance = .bl_drift_prov(x$provenance),
       manifest = if (is.data.frame(x$manifest)) as.data.frame(unclass(x$manifest), stringsAsFactors = FALSE))
}

#' The payload as JSON that can sit inside a script element.
#' @param p From .bl_drift_payload().
#' @return One string, data frames by column; every "<" is written \\u003c, so no value can close the element.
#' @noRd
.bl_drift_json <- function(p) {
  j <- tojs(p, dataframe = "columns", auto_unbox = TRUE, null = "null", na = "null", digits = I(6))
  gsub("<", "\\u003c", as.character(j), fixed = TRUE)
}

#' A drift result as Markdown: the verdict and the column table.
#' @param x A cpsdrft() result.
#' @param b The PSI bands.
#' @return One string.
#' @noRd
.bl_drift_md <- function(x, b) {
  t <- .bl_drift_table(x, b$warn, b$fail)
  mark <- c(ok = "\u2714 ok", warn = "\u26a0 warn", fail = "\u2716 fail", untested = "\u2013 untested")
  f <- function(v) ifelse(is.na(v), "", trimws(formatC(v, digits = 3, format = "g")))
  esc <- function(s) gsub("|", "\\|", s, fixed = TRUE)
  paste0(c(sprintf("## Drift: %d fail, %d warn, %d ok, %d untested", sum(t$verdict == "fail"),
                   sum(t$verdict == "warn"), sum(t$verdict == "ok"), sum(t$verdict == "untested")), "",
           sprintf("Rows %d -> %d; PSI bands warn %s, fail %s; alpha %s.", x$nref, x$ncur, f(b$warn), f(b$fail),
                   f(x$alpha)), "",
           "| verdict | column | type | test | PSI | p-value |", "|---|---|---|---|---|---|",
           sprintf("| %s | %s | %s | %s | %s | %s |", mark[t$verdict], esc(t$column), t$type, t$test, f(t$psi),
                   f(t$p_value))), collapse = "\n")
}

#' The PSI of a column without its k largest bins, the shares of the rest renormalised.
#' @param bins The column's PSI bins (bin, ref, cur, contrib).
#' @param k The number of bins left out.
#' @return A list: `psi` (NA when nothing is left) and `dropped` (the bins left out).
#' @noRd
.bl_psi_without <- function(bins, k) {
  o <- order(-bins$contrib)
  drop <- utils::head(o, k)
  rest <- bins[setdiff(seq_len(nrow(bins)), drop), , drop = FALSE]
  if (!nrow(rest) || sum(rest$ref) <= 0 || sum(rest$cur) <= 0) {
    return(list(psi = NA_real_, dropped = bins$bin[drop]))
  }
  list(psi = sum(.rmbl_psi_terms(rest$ref / sum(rest$ref), rest$cur / sum(rest$cur))), dropped = bins$bin[drop])
}

#' The PSI of every column over earlier drift runs.
#'
#' Reads every .json file in a directory: the output of `rmbl drift --json` (each capsule's `drift`)
#' or a report's own JSON export (its `columns`), in file-name order.
#' @param dir The directory.
#' @return A data frame: run, file, column, psi and p_value.
#' @noRd
.bl_drift_history <- function(dir) {
  dir <- .rmbl_string1(dir, "hist")
  if (!dir.exists(dir)) stop(.rmbl_fn(), sprintf("`hist` is not a directory: %s", .rmbl_printable(dir)), call. = FALSE)
  files <- sort(list.files(dir, pattern = "\\.json$", full.names = TRUE))
  num <- function(v) if (is.null(v)) NA_real_ else as.numeric(v)
  rows <- lapply(seq_along(files), function(i) {
    j <- tryCatch(.rmbl_json_text(readLines(files[i], warn = FALSE), simplifyVector = FALSE),
                  error = function(e) NULL)
    cl <- if (!is.null(j$columns)) j$columns else
      unlist(lapply(j$capsules, function(cp) cp$drift$columns), recursive = FALSE)
    if (!length(cl)) return(NULL)
    data.frame(run = i, file = basename(files[i]), column = vapply(cl, function(e) as.character(e$column), ""),
               psi = vapply(cl, function(e) num(e$psi), 0), p_value = vapply(cl, function(e) num(e$p_value), 0),
               stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  if (is.null(out)) stop(.rmbl_fn(), sprintf("no drift JSON in %s", .rmbl_printable(dir)), call. = FALSE)
  out
}

#' Draws the PSI of each column over runs, one small panel per column.
#' @param h From .bl_drift_history().
#' @param b The PSI bands.
#' @return `h`, invisibly.
#' @noRd
.bl_drift_history_plot <- function(h, b) {
  cl <- utils::head(unique(h$column), 12L)
  op <- .bl_panels_begin(length(cl))
  on.exit(graphics::par(op), add = TRUE)
  on.exit(.bl_panels_abort(), add = TRUE)
  for (c1 in cl) {
    s <- h[h$column == c1, , drop = FALSE]
    graphics::par(mar = .bl_safe_mar(c(3.2, 3.6, 2.4, 0.6)))
    graphics::plot(s$run, s$psi, type = "n", ylim = range(c(0, s$psi, b$fail * 1.1), na.rm = TRUE),
                   xlab = "Run", ylab = "")
    .bl_title(c1)
    .bl_grid(NULL)
    graphics::abline(h = c(b$warn, b$fail), lty = 2, col = .BL_VERDICT_COLS[c("warn", "fail")])
    .bl_line(s$run, s$psi, .BL_VERDICT_COLS[["ok"]], fill = FALSE, label = FALSE)
    over <- !is.na(s$psi) & s$psi > b$fail
    graphics::points(s$run[over], s$psi[over], pch = 21, cex = 1.6, bg = .BL_VERDICT_COLS[["fail"]], col = "white")
  }
  .bl_panels_end()
  invisible(h)
}

#' Puts a value in for a placeholder of a template, literally (no regular expression).
#' @param t The template.
#' @param key The placeholder.
#' @param v The value, already escaped.
#' @return The template filled.
#' @noRd
.bl_fill <- function(t, key, v) paste(strsplit(paste0(t, "\n"), key, fixed = TRUE)[[1L]], collapse = v)

#' Opens a file in the browser.
#' @param f The path.
#' @return NULL, invisibly.
#' @noRd
.bl_open_file <- function(f) {
  utils::browseURL(f)
  invisible(NULL)
}

#' Interactive drift report as one HTML file
#'
#' @description
#' Writes a [cpsdrft()] result to a single web page for a reader
#' who will
#' not run R. Everything is inside the file: the stylesheet, a short script,
#' and the binned summaries of each column as JSON. Nothing is fetched, so
#' the page opens from disk (`file://`) and looks the same later.
#'
#' @details
#' The page shows:
#' \itemize{
#'   \item a header with the overall verdict, the count of columns per
#'     verdict, the row counts, when the page was written, the package
#'     version, and the capsule's provenance (name, source, pinned
#'     SHA-256, data date) when `x$provenance` holds one;
#'   \item the column table: verdict, column, type, test (KS for numbers
#'     and dates, chi-square homogeneity for categories), statistic,
#'     p-value, PSI, the change in the missing share and both sample
#'     sizes. It has a search box, filters by verdict and type, and sorts
#'     on any header;
#'   \item for the column chosen (click a row, or the up and down keys; `/`
#'     goes to the search box): both samples' summary statistics, or the
#'     ten largest categories; their distributions overlaid; each bin's
#'     term of the PSI, drawn up where the current sample has more mass
#'     and down where it has less; for a numeric column the first digits
#'     against Benford's law; and a sentence on what the verdict means;
#'   \item sliders for the warn and fail PSI bands and for alpha, which
#'     score the verdicts again as they move, and a button back to the
#'     object's bands;
#'   \item a manifest tab with the resources added, removed or changed,
#'     their digests and sizes, when `x$manifest` holds an
#'     [mnfdiff()];
#'   \item a history tab: pick earlier `rmbl drift --json` outputs or this
#'     page's JSON exports, and the PSI of each column is drawn over the
#'     runs, points above the fail band marked;
#'   \item exports: Markdown, JSON, each chart as SVG, and the column table
#'     copied as a GitHub comment.
#' }
#' The verdicts: `fail` when the test rejects at alpha, or the PSI is above
#' the fail band with both samples at least `psiminn`; `warn` when the PSI
#' is above the warn band; `untested` when no test applies; `ok` otherwise.
#' At the object's bands `fail` is [cpsdrft()]'s
#' `drifted`. Each verdict is
#' written in words beside its symbol, the tables have header cells, and
#' each chart has a text label. A light or dark theme follows the system
#' and a button switches it. Every value is escaped. The page holds no rows
#' of the data, only the summaries in `x$summ`, so its size grows with the
#' number of columns and categories, not of rows.
#'
#' Errors: `x` not from [cpsdrft()]; `file` not one
#' path; `title` not one
#' string; `warn` above `fail`.
#'
#' @param x A [cpsdrft()] result. Attach a provenance record as
#'   `x$provenance` (for example from [loadprov()]) and an
#'   [mnfdiff()] as
#'   `x$manifest` to show them; `rmbl drift --html` does both.
#' @param file The path to write.
#' @param title The page title, a string.
#' @param warn,fail The PSI bands the page opens with; `NULL` (the default)
#'   takes the object's `bands`.
#' @param open Logical: open the page in the browser when written (default
#'   `FALSE`).
#' @return The path `file`, invisibly.
#' @seealso [drftapp()] for the same report as a Shiny app,
#'   [plot()][plot-methods] for the same charts in base graphics.
#' @examples
#' set.seed(5)
#' ref <- data.frame(value = stats::rnorm(400),
#'                   grade = sample(c("a", "b", "c"), 400, TRUE))
#' cur <- data.frame(value = stats::rnorm(400, 0.4),
#'                   grade = sample(c("a", "b", "c"), 400, TRUE))
#' d <- cpsdrft(ref, cur)
#' f <- file.path(tempdir(), "drift.html")
#' drfthtml(d, f, title = "Pinned against fetched")
#' file.exists(f)
#'
#' # narrower bands open the page with more columns to look at
#' drfthtml(d, f, warn = 0.02, fail = 0.05)
#' unlink(f)
#' try(drfthtml(list(), f))
#' @srrstats {EA5.0} The page's charts use the plot methods' palette and the change tables'
#'   typography (the stylesheet of yoyhtml()); test-drift-plots.R checks the page.
#' @export
drfthtml <- function(x, file, title = "Drift report", warn = NULL, fail = NULL, open = FALSE) {
  if (!inherits(x, "bricklayer_drift")) {
    stop(.rmbl_fn(), "`x` must be a bricklayer_drift object from cpsdrft()", call. = FALSE)
  }
  file <- .rmbl_out_file(file, connection = FALSE)
  title <- .rmbl_text1(title, "title")
  .rmbl_flag1(open, "open")
  js <- function(f) {
    paste(readLines(system.file("drift", f, package = "rmoriebricklayer"), warn = FALSE), collapse = "\n")
  }
  p <- .bl_drift_payload(x, warn, fail, title)
  html <- c(
    "<!DOCTYPE html>", "<html lang=\"en\"><head>", "<meta charset=\"utf-8\">",
    "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">",
    paste0("<title>", .yoy_esc(title), "</title>"),
    paste0("<style>", .yoy_css(.yoy_pal("diverging")), js("drift.css"), "</style>"),
    "</head><body><main>",
    .bl_fill(.bl_fill(js("body.html"), "{{VERSION}}", .yoy_esc(p$version)), "{{TITLE}}", .yoy_esc(title)),
    "</main>",
    paste0("<script type=\"application/json\" id=\"drift-data\">", .bl_drift_json(p), "</script>"),
    paste0("<script>", js("drift.js"), "</script>"),
    "</body></html>")
  writeLines(html, file, useBytes = TRUE)
  if (open) .bl_open_file(file)
  invisible(file)
}

#' Drift report as a Shiny app
#'
#' @description
#' The report of [drfthtml()] as a Shiny app, for working through
#' a drift
#' result rather than handing it on. `drftapp(x)` opens on a
#' [cpsdrft()]
#' result; `drftapp()` with no result opens on two file inputs, the
#' reference and the current CSV, and compares them when both are
#' uploaded. It needs the shiny package, which is suggested, not required.
#'
#' @details
#' The app has the column table (verdicts under the bands), the PSI per
#' column, and for the chosen column its summary, the distributions, the PSI
#' by bin, the first digits and a sentence on the verdict, as
#' [drfthtml()]
#' has; the warn and fail bands and alpha are sliders, with a reset to the
#' object's bands. Beyond the page it has: "what would clear this", the
#' PSI of the column with its `k` largest bins left out and the rest
#' renormalised; with `ref` and `cur` (or uploaded CSV files), a rerun of
#' [cpsdrft()] on chosen columns with another number of bins; with
#' `hist`,
#' the PSI of each column over the runs in that directory
#' (`rmbl drift --json` outputs or JSON exports of the page); a manifest
#' tab when
#' `x$manifest` holds an [mnfdiff()]; and downloads of the
#' HTML report,
#' Markdown and JSON. Uploaded files are read with the package's own CSV
#' reader (the one [dload()] uses). `rmbl drift PATH --app`
#' opens the app on
#' the first capsule whose source moved.
#'
#' The function builds the app and returns it; printing it, or
#' [shiny::runApp()], runs it.
#'
#' Errors: `x` neither `NULL` nor from [cpsdrft()];
#' shiny not installed;
#' only one of `ref` and `cur`, or either not a data frame; `hist` not a
#' directory or holding no drift JSON; `warn` above `fail`.
#'
#' @inheritParams drfthtml
#' @param x A [cpsdrft()] result, or `NULL` (the default) to
#'   upload two CSV
#'   files in the app.
#' @param ref,cur Optional: the two data frames `x` was computed from, for
#'   the rerun panel.
#' @param hist Optional: a directory of earlier drift JSON files, for the
#'   history tab.
#' @return A Shiny app object (class `shiny.appobj`).
#' @seealso [drfthtml()] for a file to hand on.
#' @examples
#' set.seed(5)
#' ref <- data.frame(value = stats::rnorm(400),
#'                   grade = sample(c("a", "b", "c"), 400, TRUE))
#' cur <- data.frame(value = stats::rnorm(400, 0.4),
#'                   grade = sample(c("a", "b", "c"), 400, TRUE))
#' d <- cpsdrft(ref, cur)
#' @examplesIf interactive()
#' if (requireNamespace("shiny", quietly = TRUE)) {
#'   # drftapp() alone opens on two CSV files to upload
#'   print(drftapp(d, ref = ref, cur = cur))
#' }
#' @export
drftapp <- function(x = NULL, ref = NULL, cur = NULL, hist = NULL, warn = NULL, fail = NULL) {
  if (!is.null(x) && !inherits(x, "bricklayer_drift")) {
    stop(.rmbl_fn(), "`x` must be a bricklayer_drift object from cpsdrft(), or NULL", call. = FALSE)
  }
  if (!requireNamespace("shiny", quietly = TRUE)) {
    stop(.rmbl_fn(), "the app needs the shiny package: install.packages(\"shiny\")", call. = FALSE)
  }
  if (xor(is.null(ref), is.null(cur)) || (!is.null(ref) && !(is.data.frame(ref) && is.data.frame(cur)))) {
    stop(.rmbl_fn(), "`ref` and `cur` must both be data frames, or both NULL", call. = FALSE)
  }
  b0 <- if (is.null(x)) .bl_drift_bands(list(), warn, fail) else .bl_drift_bands(x, warn, fail)
  a0 <- if (is.null(x)) 0.01 else x$alpha
  h <- if (!is.null(hist)) .bl_drift_history(hist)
  num <- function(id, lab, v, mx, st) shiny::sliderInput(id, lab, min = 0, max = mx, value = v, step = st)
  shared <- if (!is.null(ref)) intersect(names(ref), names(cur)) else character()
  side <- shiny::sidebarPanel(
    if (is.null(x)) {
      shiny::tagList(shiny::fileInput("refcsv", "Reference CSV", accept = ".csv"),
                 shiny::fileInput("curcsv", "Current CSV", accept = ".csv"))
    },
    num("warn", "warn PSI", b0$warn, max(1, 2 * b0$fail), 0.01),
    num("fail", "fail PSI", b0$fail, max(1, 2 * b0$fail), 0.01),
    num("alpha", "alpha", a0, 0.2, 0.001),
    shiny::actionButton("reset", "Reset to the object's bands"),
    shiny::selectInput("col", "Column", if (is.null(x)) character() else x$columns$column),
    shiny::numericInput("k", "Bins to leave out (what would clear this)", 1, min = 1, step = 1),
    shiny::selectInput("sub", "Rerun on columns", shared, multiple = TRUE),
    shiny::numericInput("bins", "Bins", 10, min = 2, step = 1), shiny::actionButton("rerun", "Rerun cpsdrft()"),
    shiny::downloadButton("html", "HTML report"), shiny::downloadButton("md", "Markdown"),
    shiny::downloadButton("json", "JSON"))
  tabs <- list(shiny::tabPanel("Columns", shiny::tableOutput("tab"), shiny::plotOutput("psi")),
               shiny::tabPanel("Column", shiny::textOutput("note"), shiny::tableOutput("summ"),
                               shiny::plotOutput("cmp"), shiny::plotOutput("benford"), shiny::textOutput("clear")))
  if (is.data.frame(x$manifest)) tabs <- c(tabs, list(shiny::tabPanel("Manifest", shiny::tableOutput("manifest"))))
  if (!is.null(h)) tabs <- c(tabs, list(shiny::tabPanel("History", shiny::plotOutput("history"))))
  ui <- shiny::fluidPage(shiny::titlePanel("Drift report"),
                         shiny::sidebarLayout(side, shiny::mainPanel(do.call(shiny::tabsetPanel, tabs))))
  server <- function(input, output, session) {
    cx <- shiny::reactiveVal(x)
    data <- shiny::reactiveVal(if (!is.null(ref)) list(ref = ref, cur = cur))
    now <- shiny::reactive({
      y <- cx()
      shiny::req(y)
      y$alpha <- input$alpha
      y
    })
    bands <- shiny::reactive(.bl_drift_bands(now(), input$warn, max(input$warn, input$fail)))
    run <- function(r, c1, cols) {
      y <- cpsdrft(r[cols], c1[cols], alpha = input$alpha, bins = input$bins)
      y$manifest <- x$manifest
      y$provenance <- x$provenance
      cx(y)
      shiny::updateSelectInput(session, "col", choices = y$columns$column)
    }
    shiny::observeEvent(input$reset, {
      shiny::updateSliderInput(session, "warn", value = b0$warn)
      shiny::updateSliderInput(session, "fail", value = b0$fail)
      shiny::updateSliderInput(session, "alpha", value = a0)
    })
    shiny::observeEvent(list(input$refcsv, input$curcsv), {
      shiny::req(input$refcsv, input$curcsv)
      d <- list(ref = .bl_read_csv_gz(input$refcsv$datapath), cur = .bl_read_csv_gz(input$curcsv$datapath))
      data(d)
      shiny::updateSelectInput(session, "sub", choices = intersect(names(d$ref), names(d$cur)))
      run(d$ref, d$cur, intersect(names(d$ref), names(d$cur)))
    })
    shiny::observeEvent(input$rerun, {
      d <- data()
      shiny::req(d)
      run(d$ref, d$cur, if (length(input$sub)) input$sub else intersect(names(d$ref), names(d$cur)))
    })
    row <- shiny::reactive({
      t <- .bl_drift_table(now(), bands()$warn, bands()$fail)
      t[t$column == input$col, , drop = FALSE]
    })
    output$tab <- shiny::renderTable(.bl_drift_table(now(), bands()$warn, bands()$fail), digits = 4)
    output$psi <- shiny::renderPlot(plot(now(), warn = bands()$warn, fail = bands()$fail))
    output$cmp <- shiny::renderPlot(plot(now(), what = "columns", cols = shiny::req(input$col)))
    output$benford <- shiny::renderPlot({
      if (!is.null(now()$summ[[shiny::req(input$col)]]$benford)) plot(now(), what = "benford", cols = input$col)
    })
    output$note <- shiny::renderText({
      r <- row()
      if (nrow(r)) .bl_drift_note(r, bands(), input$alpha, now()$columns$note[now()$columns$column == input$col])
    })
    output$summ <- shiny::renderTable({
      s <- now()$summ[[shiny::req(input$col)]]
      s$stats %||% s$top
    }, digits = 4)
    output$clear <- shiny::renderText({
      bn <- now()$summ[[shiny::req(input$col)]]$bins
      if (!is.null(bn)) {
        w <- .bl_psi_without(bn, max(1L, as.integer(input$k)))
        sprintf("Without %s, the PSI would be %s (now %s).", paste(w$dropped, collapse = ", "),
                trimws(formatC(w$psi, digits = 3, format = "g")), trimws(formatC(sum(bn$contrib), digits = 3,
                                                                                    format = "g")))
      }
    })
    output$manifest <- shiny::renderTable(as.data.frame(unclass(x$manifest)))
    output$history <- shiny::renderPlot(.bl_drift_history_plot(h, bands()))
    output$html <- shiny::downloadHandler("drift.html", function(f) {
      drfthtml(now(), f, warn = bands()$warn, fail = bands()$fail)
    })
    output$md <- shiny::downloadHandler("drift.md", function(f) writeLines(.bl_drift_md(now(), bands()), f))
    output$json <- shiny::downloadHandler("drift.json", function(f) {
      writeLines(.bl_drift_json(.bl_drift_payload(now(), bands()$warn, bands()$fail)), f)
    })
  }
  shiny::shinyApp(ui, server)
}

#' Runs a Shiny app (rmbl drift --app); a test replaces it so no server starts.
#' @param app The app object.
#' @return What shiny::runApp() returns.
#' @noRd
.bl_run_app <- function(app) shiny::runApp(app)
