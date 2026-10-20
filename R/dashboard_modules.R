# SPDX-License-Identifier: AGPL-3.0-or-later
# The dashboard's own panels: settings, report, capsule, proof ledger and drift.

# ---- settings -----------------------------------------------------------------------------------

#' The settings panel.
#' @param id The module id.
#' @return A tag list.
#' @noRd
.bl_set_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::selectInput(ns("theme"), "Theme", c("As the system is set" = "auto", "Light" = "light", "Dark" = "dark")),
    shiny::numericInput(ns("digits"), "Significant digits in printed results", 4, min = 1, max = 15),
    shiny::numericInput(ns("seed"), "Seed of the seeded analyses", 1, min = 0, step = 1),
    shiny::tags$p(class = "bl-about",
                  "The seed is written into each R call that uses one, so a rerun gives the same draws.")
  )
}

#' The settings server.
#' @param id The module id.
#' @return A reactive list: digits and seed.
#' @noRd
.bl_set_server <- function(id) {
  shiny::moduleServer(id, function(input, output, session) {
    shiny::observeEvent(input$theme, session$sendCustomMessage("bltheme", input$theme))
    shiny::reactive({
      dg <- suppressWarnings(as.integer(input$digits %||% 4L))
      sd <- suppressWarnings(as.integer(input$seed %||% 1L))
      list(digits = if (length(dg) && !is.na(dg)) min(max(dg, 1L), 15L) else 4L,
           seed = if (length(sd) && !is.na(sd)) sd else 1L)
    })
  })
}

# ---- report -------------------------------------------------------------------------------------

#' Whether the SVG device is available (cairo).
#' @return TRUE or FALSE.
#' @noRd
.bl_have_cairo <- function() isTRUE(capabilities("cairo"))

#' Draws a plot call as inline SVG (a PNG data URI where there is no SVG device).
#' @param expr The plot call.
#' @param env Where to evaluate it.
#' @return One string of markup.
#' @noRd
.bl_svg <- function(expr, env) {
  svg <- .bl_have_cairo()
  f <- tempfile(fileext = if (svg) ".svg" else ".png")
  on.exit(unlink(f), add = TRUE)
  if (svg) grDevices::svg(f, width = 7.5, height = 4.6) else grDevices::png(f, 750, 460)
  tryCatch(eval(expr, env), finally = grDevices::dev.off())
  if (!svg) {
    return(sprintf('<img alt="plot" src="data:image/png;base64,%s">', jsb64enc(readBin(f, "raw", file.size(f)))))
  }
  s <- readLines(f, warn = FALSE)
  paste(s[!startsWith(s, "<?xml")], collapse = "\n")
}

#' A report entry from a run.
#' @param r The run, from .bl_tab_run() or a panel.
#' @return A list: title, code, text, svg, yoy.
#' @noRd
.bl_rpt_entry <- function(r) {
  list(title = r$title, code = r$code, text = utils::capture.output(print(r$value)),
       svg = if (!is.null(r$plot)) .bl_svg(r$plot, r$env), yoy = if (inherits(r$value, "rmbl_yoy")) r$value)
}

#' The report as one self-contained HTML page, in yoyhtml()'s style.
#' @param entries The entries.
#' @param title The page title.
#' @return One string.
#' @noRd
.bl_rpt_html <- function(entries, title = "Analysis report") {
  f <- tempfile(fileext = ".html")
  on.exit(unlink(f), add = TRUE)
  yoyhtml(yoy(c(1, 2)), f)
  page <- paste(readLines(f, warn = FALSE), collapse = "\n")
  style <- regmatches(page, regexpr("(?s)<style>.*?</style>", page, perl = TRUE))
  sect <- vapply(seq_along(entries), function(k) {
    e <- entries[[k]]
    tab <- if (!is.null(e$yoy)) {
      yoyhtml(e$yoy, f, title = e$title)
      h <- paste(readLines(f, warn = FALSE), collapse = "\n")
      regmatches(h, regexpr("(?s)<div class=\"scroll\">.*?</table></div>", h, perl = TRUE))
    }
    # each SVG's ids made unique on the page: the glyphs of one plot must not resolve to another's
    svg <- if (!is.null(e$svg)) gsub("(id=\"|href=\"#|url\\(#)", sprintf("\\1p%d-", k), e$svg) else ""
    paste0("<section><h2>", .yoy_esc(e$title), "</h2>",
           "<pre><code>", .yoy_esc(paste(e$code, collapse = "\n")), "</code></pre>",
           if (length(tab)) tab else paste0("<pre>", .yoy_esc(paste(e$text, collapse = "\n")), "</pre>"),
           "<figure>", svg, "</figure></section>")
  }, "")
  paste0("<!DOCTYPE html>\n<html lang=\"en\"><head><meta charset=\"utf-8\">",
         "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>", .yoy_esc(title),
         "</title>", style,
         "<style>pre{background:var(--panel);border:1px solid var(--rule);border-radius:6px;padding:.7rem;",
         "overflow-x:auto;font-size:.82rem}figure{margin:1rem 0}figure svg,figure img{max-width:100%;height:auto}",
         "</style></head><body><main><h1>", .yoy_esc(title), "</h1><p class=\"sub\">", length(entries),
         " results from the rmoriebricklayer dashboard, each with the R call that computed it.</p>",
         paste(sect, collapse = "\n"), "</main></body></html>\n")
}

#' The report as Markdown (also the GitHub comment).
#' @param entries The entries.
#' @param title The title.
#' @return One string.
#' @noRd
.bl_rpt_md <- function(entries, title = "Analysis report") {
  f <- tempfile(fileext = ".md")
  on.exit(unlink(f), add = TRUE)
  parts <- vapply(entries, function(e) {
    body <- if (!is.null(e$yoy)) {
      yoymd(e$yoy, f)
      readLines(f, warn = FALSE)
    } else {
      c("```", e$text, "```")
    }
    paste(c(paste("##", e$title), "", "```r", e$code, "```", "", body), collapse = "\n")
  }, "")
  paste(c(paste("#", title), "", paste(parts, collapse = "\n\n")), collapse = "\n")
}

#' The report panel.
#' @param id The module id.
#' @return A tag list.
#' @noRd
.bl_rpt_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::tags$p(class = "bl-about", "Results added with \"Add to report\" in the other tabs. Pick the ones to keep."),
    shiny::textInput(ns("title"), "Title", "Analysis report"),
    shiny::checkboxGroupInput(ns("pick"), "Results", NULL),
    shiny::downloadButton(ns("html"), "HTML page"),
    shiny::downloadButton(ns("md"), "Markdown"),
    shiny::actionButton(ns("clear"), "Clear the report"),
    shiny::tags$h3("As a GitHub comment"),
    shiny::tags$button(type = "button", class = "btn btn-default bl-copy", `data-target` = ns("gh"),
                       "Copy as GitHub comment"),
    shiny::verbatimTextOutput(ns("gh"))
  )
}

#' The report server.
#' @param id The module id.
#' @param rpt The report's entries.
#' @return NULL, invisibly.
#' @noRd
.bl_rpt_server <- function(id, rpt) {
  shiny::moduleServer(id, function(input, output, session) {
    shiny::observe({
      e <- rpt()
      ch <- stats::setNames(as.character(seq_along(e)), vapply(e, `[[`, "", "title"))
      shiny::updateCheckboxGroupInput(session, "pick", choices = ch, selected = ch)
    })
    chosen <- shiny::reactive(rpt()[intersect(as.integer(input$pick), seq_along(rpt()))])
    shiny::observeEvent(input$clear, rpt(list()))
    output$gh <- shiny::renderText(if (length(chosen())) .bl_rpt_md(chosen(), input$title) else "")
    output$html <- shiny::downloadHandler("rmbl-report.html",
                                          function(file) writeLines(.bl_rpt_html(chosen(), input$title), file))
    output$md <- shiny::downloadHandler("rmbl-report.md",
                                        function(file) writeLines(.bl_rpt_md(chosen(), input$title), file))
    invisible(NULL)
  })
}

# ---- capsule ------------------------------------------------------------------------------------

#' A two-column table of the scalar fields of a list.
#' @param x The list.
#' @param prefix The prefix of nested names.
#' @return A data frame: field, value.
#' @noRd
.bl_fields <- function(x, prefix = "") {
  out <- data.frame(field = character(), value = character(), stringsAsFactors = FALSE)
  for (nm in names(x)) {
    v <- x[[nm]]
    key <- paste0(prefix, nm)
    if (is.list(v) && !is.null(names(v))) {
      out <- rbind(out, .bl_fields(v, paste0(key, ".")))
    } else if (is.atomic(v) && length(v)) {
      out <- rbind(out, data.frame(field = key, value = paste(as.character(v), collapse = ", "),
                                   stringsAsFactors = FALSE))
    }
  }
  out
}

#' What the capsule viewer shows: provenance, manifest, attestation and bundle files.
#' @param dir The capsule directory.
#' @return A list of data frames (NULL where the capsule has no such file) and the code.
#' @noRd
.bl_cps_view <- function(dir) {
  dir <- .rmbl_string1(dir, "dir")
  if (!dir.exists(dir)) stop("rmblapp: the capsule is not an existing directory: ", dir, call. = FALSE)
  p <- loadprov(file.path(dir, "data_provenance.json"))
  m <- file.path(dir, "manifest.json")
  b <- file.path(dir, "capsule_bundle.json")
  bnd <- if (file.exists(b)) cpsbndlrd(b)
  list(prov = .bl_fields(p), manifest = if (file.exists(m)) .bl_fields(.bl_read_json_list(m)),
       atst = if (!is.null(bnd)) .bl_fields(bnd$attestation[setdiff(names(bnd$attestation), "signature")]),
       files = if (!is.null(bnd)) data.frame(path = vapply(bnd$files, function(f) f$path, ""),
                                             sha256 = vapply(bnd$files, function(f) f$sha256, ""),
                                             size_bytes = vapply(bnd$files, function(f) as.numeric(f$size_bytes), 1),
                                             stringsAsFactors = FALSE),
       code = c(sprintf("dir <- %s", deparse(dir)), "prov <- loadprov(file.path(dir, \"data_provenance.json\"))",
                if (!is.null(bnd)) "bnd <- cpsbndlrd(file.path(dir, \"capsule_bundle.json\"))"))
}

#' Check rows with a status word, for an accessible table.
#' @param rows The rows (with ok, and optionally severity).
#' @return The rows with status first.
#' @noRd
.bl_status_rows <- function(rows) {
  sev <- rows$severity %||% rep("error", nrow(rows))
  st <- ifelse(rows$ok, "pass", ifelse(sev == "note", "note", ifelse(sev == "warn", "warn", "FAIL")))
  data.frame(status = st, part = rows$part %||% rep("", nrow(rows)), check = rows$check, severity = sev,
             detail = rows$detail %||% rep("", nrow(rows)), stringsAsFactors = FALSE)
}

#' The capsule panel.
#' @param id The module id.
#' @return A tag list.
#' @noRd
.bl_cps_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::tags$p(class = "bl-about", paste(
      "The provenance of a capsule as the package reads it, and its checks. Verify reads the files only;",
      "refresh fetches the source again and pins its new bytes.")),
    shiny::textInput(ns("dir"), "Capsule directory"),
    shiny::actionButton(ns("show"), "Show the provenance"),
    shiny::actionButton(ns("verify"), "Verify"),
    shiny::actionButton(ns("refresh"), "Refresh the pin"),
    shiny::actionButton(ns("add"), "Add to report"),
    shiny::uiOutput(ns("err")),
    shiny::tags$h3("R call"), shiny::verbatimTextOutput(ns("code")),
    shiny::tags$h3("Provenance"), shiny::tableOutput(ns("prov")),
    shiny::tags$h3("Manifest"), shiny::tableOutput(ns("manifest")),
    shiny::tags$h3("Attestation"), shiny::tableOutput(ns("atst")),
    shiny::tags$h3("Bundle files"), shiny::tableOutput(ns("files")),
    shiny::tags$h3("Verification"), shiny::tableOutput(ns("rows"))
  )
}

#' The capsule server.
#' @param id The module id.
#' @param dat The data loaded at the left (its capsule fills the directory).
#' @param rpt The report's entries.
#' @return NULL, invisibly.
#' @noRd
.bl_cps_server <- function(id, dat, rpt) {
  shiny::moduleServer(id, function(input, output, session) {
    view <- shiny::reactiveVal(NULL)
    rows <- shiny::reactiveVal(NULL)
    err <- shiny::reactiveVal(NULL)
    code <- shiny::reactiveVal(character())
    shiny::observe({
      d <- dat()$capsule
      if (!is.null(d)) shiny::updateTextInput(session, "dir", value = d)
    })
    take <- function(r, then) {
      if (inherits(r, "bl_app_error")) {
        err(r)
      } else {
        err(NULL)
        then(r)
      }
    }
    shiny::observeEvent(input$show, take(.bl_app_try(.bl_cps_view(input$dir)), function(r) {
      view(r)
      code(r$code)
    }))
    shiny::observeEvent(input$verify, take(.bl_app_try({
      v <- vrfcps(input$dir)
      k <- cpschk(input$dir, fp = FALSE)
      rbind(.bl_status_rows(cbind(part = "provenance", v$checks, stringsAsFactors = FALSE)),
            .bl_status_rows(k$rows))
    }), function(r) {
      rows(r)
      code(c(sprintf("dir <- %s", deparse(input$dir)), "vrfcps(dir)", "cpschk(dir, fp = FALSE)$rows"))
    }))
    shiny::observeEvent(input$refresh, take(.bl_app_try(cpsrfrsh(input$dir)), function(r) {
      rows(as.data.frame(r))
      code(c(sprintf("dir <- %s", deparse(input$dir)), "cpsrfrsh(dir)"))
    }))
    shiny::observeEvent(input$add, if (!is.null(rows())) {
      rpt(c(rpt(), list(.bl_rpt_entry(list(title = paste("Capsule", basename(input$dir)), code = code(),
                                            value = rows(), plot = NULL)))))
    })
    output$err <- shiny::renderUI(if (!is.null(err())) .bl_app_err_ui(err()))
    output$code <- shiny::renderText(paste(code(), collapse = "\n"))
    output$prov <- shiny::renderTable(view()$prov)
    output$manifest <- shiny::renderTable(view()$manifest)
    output$atst <- shiny::renderTable(view()$atst)
    output$files <- shiny::renderTable(view()$files)
    output$rows <- shiny::renderTable(rows())
    invisible(NULL)
  })
}

# ---- proof ledger -------------------------------------------------------------------------------

#' The ledgers installed packages ship in inst/ledger.
#' @param pkgs The packages to look in; default every installed package.
#' @param find The ledger directory of a package, "" when it has none.
#' @return A named character vector of paths ("pkg: file").
#' @noRd
.bl_ldgr_installed <- function(pkgs = rownames(utils::installed.packages(fields = character())),
                               find = function(p) system.file("ledger", package = p)) {
  out <- character()
  for (p in pkgs) {
    d <- find(p)
    if (!nzchar(d)) next
    f <- list.files(d, pattern = "[.]json$", full.names = TRUE)
    out <- c(out, stats::setNames(f, paste0(p, ": ", basename(f))))
  }
  out
}

#' The link to a theorem's line on the repository at the ledger's commit, or NULL.
#' @param src The ledger's source.
#' @param t The theorem.
#' @return One URL or NULL.
#' @noRd
.bl_ldgr_link <- function(src, t) {
  r <- sub("[.]git$", "", sub("/+$", "", src$repo))
  base <- if (grepl("^https?://", r)) r else if (grepl("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", r)) {
    paste0("https://github.com/", r)
  }
  if (is.null(base)) return(NULL)
  sprintf("%s/blob/%s/%s#L%d", base, src$commit, t$file, as.integer(t$line))
}

#' The theorem table of a ledger, as HTML.
#' @param led A ldgrread() result.
#' @return A tag.
#' @noRd
.bl_ldgr_table <- function(led) {
  t <- shiny::tags
  chip <- function(s) t$span(class = paste("bl-chip", switch(s, proved = "bl-ok", sorry = "bl-bad", "bl-warn")), s)
  rows <- lapply(led$theorems, function(th) {
    url <- .bl_ldgr_link(led$source, th)
    where <- sprintf("%s:%d", th$file, as.integer(th$line))
    cov <- lapply(th$covers, function(cv) {
      inst <- cv$language == "R" && requireNamespace(cv$package, quietly = TRUE)
      t$li(t$code(sprintf("%s::%s", cv$package, cv$`function`)), if (inst) " installed" else " not installed")
    })
    t$tr(t$td(th$id), t$td(chip(th$status)), t$td(th$sorry_count),
         t$td(t$pre(t$code(th$statement))),
         t$td(if (is.null(url)) where else t$a(href = url, target = "_blank", rel = "noopener", where)),
         t$td(if (length(cov)) t$ul(cov) else "none"))
  })
  t$table(t$caption(sprintf("%s, %s at %s", led$name, led$source$repo, substr(led$source$commit, 1L, 12L))),
          t$thead(t$tr(t$th(scope = "col", "id"), t$th(scope = "col", "status"), t$th(scope = "col", "sorry"),
                       t$th(scope = "col", "statement"), t$th(scope = "col", "Lean file"),
                       t$th(scope = "col", "covers"))),
          t$tbody(rows))
}

#' The proof ledger panel.
#' @param id The module id.
#' @return A tag list.
#' @noRd
.bl_ldgr_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::tags$p(class = "bl-about", paste(
      "The theorems of a formal-proof build and the package functions they cover (ldgrread(), ldgrchk()).",
      "A theorem counts as proved only with no sorry; an axiom is assumed, not proved.")),
    shiny::radioButtons(ns("src"), "Ledger", c("The sample ledger" = "sample", "A file" = "file",
                                               "A capsule directory" = "capsule", "An installed package" = "inst")),
    shiny::conditionalPanel("input.src == 'file'", ns = ns, shiny::fileInput(ns("file"), "Ledger JSON",
                                                                             accept = ".json")),
    shiny::conditionalPanel("input.src == 'capsule'", ns = ns, shiny::textInput(ns("dir"), "Capsule directory")),
    shiny::conditionalPanel("input.src == 'inst'", ns = ns,
                            shiny::actionButton(ns("find"), "Find the ledgers installed packages ship"),
                            shiny::selectInput(ns("inst"), "Ledger", NULL)),
    shiny::actionButton(ns("load"), "Load", class = "btn-primary"),
    shiny::actionButton(ns("check"), "Run the checks"),
    shiny::actionButton(ns("add"), "Add to report"),
    shiny::uiOutput(ns("err")),
    shiny::tags$h3("R call"), shiny::verbatimTextOutput(ns("code")),
    shiny::tags$h3("Theorems"), shiny::uiOutput(ns("thm")),
    shiny::tags$h3("Checks"), shiny::tableOutput(ns("rows")),
    shiny::tags$h3("Provenance and attestation"), shiny::tableOutput(ns("prov")), shiny::tableOutput(ns("atst"))
  )
}

#' The path of the ledger the panel's source names.
#' @param input The inputs.
#' @return A list: path and the code that names it.
#' @noRd
.bl_ldgr_path <- function(input) {
  switch(input$src,
    sample = list(path = system.file("extdata", "ledger_sample.json", package = "rmoriebricklayer"),
                  code = "path <- system.file(\"extdata\", \"ledger_sample.json\", package = \"rmoriebricklayer\")"),
    file = {
      if (is.null(input$file)) stop("choose a ledger file first", call. = FALSE)
      list(path = input$file$datapath, code = sprintf("path <- %s", deparse(input$file$name)))
    },
    capsule = {
      p <- loadprov(file.path(input$dir, "data_provenance.json"))
      list(path = file.path(input$dir, p$resource$filename),
           code = sprintf("path <- file.path(%s, %s)", deparse(input$dir), deparse(p$resource$filename)))
    },
    inst = {
      if (!length(input$inst) || !nzchar(input$inst)) stop("find and choose an installed ledger first", call. = FALSE)
      list(path = input$inst, code = sprintf("path <- %s", deparse(input$inst)))
    }
  )
}

#' The proof ledger server.
#' @param id The module id.
#' @param dat The data loaded at the left (its capsule fills the directory).
#' @param rpt The report's entries.
#' @return NULL, invisibly.
#' @noRd
.bl_ldgr_server <- function(id, dat, rpt) {
  shiny::moduleServer(id, function(input, output, session) {
    led <- shiny::reactiveVal(NULL)
    rows <- shiny::reactiveVal(NULL)
    err <- shiny::reactiveVal(NULL)
    code <- shiny::reactiveVal(character())
    shiny::observe({
      d <- dat()$capsule
      if (!is.null(d)) shiny::updateTextInput(session, "dir", value = d)
    })
    shiny::observeEvent(input$find, {
      shiny::updateSelectInput(session, "inst", choices = .bl_ldgr_installed())
    })
    shiny::observeEvent(input$load, {
      r <- .bl_app_try({
        p <- .bl_ldgr_path(input)
        list(led = ldgrread(p$path), code = c(p$code, "led <- ldgrread(path)"))
      })
      if (inherits(r, "bl_app_error")) {
        err(r)
      } else {
        err(NULL)
        led(r$led)
        rows(NULL)
        code(r$code)
      }
    })
    shiny::observeEvent(input$check, if (!is.null(led())) {
      r <- .bl_app_try(.bl_status_rows(ldgrchk(led())))
      if (inherits(r, "bl_app_error")) {
        err(r)
      } else {
        rows(r)
        code(unique(c(code(), "ldgrchk(led)")))
      }
    })
    shiny::observeEvent(input$add, if (!is.null(rows())) {
      rpt(c(rpt(), list(.bl_rpt_entry(list(title = paste("Proof ledger:", led()$name), code = code(),
                                            value = rows(), plot = NULL)))))
    })
    capdir <- shiny::reactive({
      l <- led()
      d <- if (!is.null(l)) dirname(attr(l, "path"))
      if (!is.null(d) && file.exists(file.path(d, "data_provenance.json"))) d
    })
    output$err <- shiny::renderUI(if (!is.null(err())) .bl_app_err_ui(err()))
    output$code <- shiny::renderText(paste(code(), collapse = "\n"))
    output$thm <- shiny::renderUI(if (!is.null(led())) .bl_ldgr_table(led()))
    output$rows <- shiny::renderTable(rows())
    output$prov <- shiny::renderTable(if (!is.null(capdir())) .bl_cps_view(capdir())$prov)
    output$atst <- shiny::renderTable(if (!is.null(capdir())) .bl_cps_view(capdir())$atst)
    invisible(NULL)
  })
}

# ---- drift ----------------------------------------------------------------------------------------

#' The drift panel: the drift app of drftapp() on two uploaded CSV files.
#' @param id The tab's id (the drift app's controls keep their own names).
#' @return A tag list.
#' @noRd
.bl_drift_ui <- function(id) {
  shiny::tagList(
    shiny::tags$p(class = "bl-about", paste(
      "Upload the pinned data and a fresh copy as two CSV files to compare them column by column (cpsdrft()),",
      "as drftapp() does; `rmbl drift PATH` runs the same from the shell.")),
    .bl_drift_parts()$ui
  )
}

#' The drift app's server, on the dashboard's session.
#' @param input,output,session The dashboard's.
#' @return NULL, invisibly.
#' @noRd
.bl_drift_server <- function(input, output, session) {
  .bl_drift_parts()$server(input, output, session)
  invisible(NULL)
}
