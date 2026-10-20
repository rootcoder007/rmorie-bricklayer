# SPDX-License-Identifier: AGPL-3.0-or-later
# The analysis dashboard: a shiny app over the package's own functions. Each tab is a form over
# exported functions (dashboard_specs.R); a run evaluates exactly the call it shows, so what the
# page computed can be pasted into a script and computed again. The page is built with bslib
# (cards, value boxes, sidebars, the navbar menus); dashboard_cards.R draws the cards' contents.

#' Open the analysis dashboard
#'
#' A local web app over the package's analyses: every tab opens on a demonstration
#' dataset ([rmbldemo()]) with its first analysis already run, and
#'   you can load a CSV
#' file, the pinned data of a capsule, or a table from data.rmorie.com (after
#' `rmbl login`) instead. Everything runs on this machine in this R session; nothing
#'   is
#' sent anywhere except the data.rmorie.com requests you make.
#'
#' @details Each analysis page shows the headline numbers (estimate, interval, n and a
#'   verdict) in value boxes, the package's plot in a card that opens full screen and
#'   downloads as PNG, SVG or CSV, a diagnostics card (the checks and secondary tables
#'   the function returns, residual and goodness-of-fit plots where the method has
#'   them, effect sizes with a line on how to read them), the table, and the R call it
#'   ran, which runs exactly that call, so a result can be reproduced in a script by
#'   copying the code. The method card states the method in the words of its help page,
#'   its assumptions and what the numbers mean. A refusal is shown as the package words
#'   it, with [explerr()]'s explanation of where it comes from beside
#'   it, and as a toast.
#'   The resampling analyses (bootstraps, permutations, simulations and the Hawkes
#'   fits) run in a forked background process on Unix-alikes, so the page stays live
#'   while they work. "Share this view" in the navbar gives a link that reopens the
#'   page with the same tab, data and form.
#'
#'   The menus and their tabs:
#' \describe{
#'   \item{Data}{Describe: [profcols()],
#'   [freqtbl()], [cortbl()],
#'   [mahaoutl()],
#'     [missgrid()] and the distribution plots
#'     ([plotrdg()], [plotecdf()],
#'     [plotvln()],
#'     [plothex()], [plotgain()]); click a
#'     column of the profile to see its
#'     distribution. Distributions: [dstfit()] with its density, QQ, PP
#'     and tail plots,
#'     and a synthetic sample from a fit through [mksyncol()].}
#'   \item{Over time}{Year over year: [yoy()] (hover a period of its plot
#'   for the
#'     period's rows) and the [yoyhtml()] page to download. Rates:
#'     [rtcalc()],
#'     [ratechg()] and [shrs()]. Trends:
#'     [trndtst()] (Mann-Kendall with the Theil-Sen
#'     slope), [stepchg()], [cnttrnd()], and
#'     [plotcal()], [plothrz()],
#'     [plotsm()] and
#'     [plotbump()].}
#'   \item{Causal and survey}{Survey: [svydes()] with weights, strata,
#'   clusters or
#'     replicate weights, then [svyest()] or
#'     [svycmp()]. Policy: [plndid()],
#'     [evstudy()], [stgatt()],
#'     [bacondcmp()], [swtdid()],
#'     [perminf()], [syndid()],
#'     [mtchdid()], [wcb()],
#'     [loounit()], [cohtrnd()],
#'     [plnpwr()], [baltab()] and
#'     [tse()].}
#'   \item{Capsules}{Drift: [cpsdrft()] on two snapshots, with a
#'   density whose brushed
#'     range gives each snapshot's share of rows, and the app of
#'     [drftapp()] for two
#'     CSV files. Capsule: the provenance of a capsule (source, pinned digest,
#'     manifest, attestation, bundle files) and its verification rows, with buttons
#'     that run [vrfcps()] and [cpschk()], or
#'     [cpsrfrsh()]. Proof ledger: a ledger
#'     ([ldgrread()]) from the demo, a file, a capsule or an installed
#'     package, its
#'     theorems with their status and covered functions, and
#'     [ldgrchk()].}
#'   \item{Domains}{First Nations, Metis and Inuit: the bundled Statistics Canada
#'     tables ([indiex()]) or a table in the same layout:
#'     [indgap()], [dstntst()],
#'     [ordcmp()], [welprof()] with
#'     [dualcont()], [healchg()],
#'     [mhcont()], [stdprev()]
#'     and [trcprog()]. Each distinction is reported on its own,
#'     suppressed cells stay
#'     suppressed with their quality flags, and the page states the OCAP and CARE
#'     principles and the source tables. Courts and corrections:
#'     [caseflow()],
#'     [stkflow()], [clrdcmp()],
#'     [dispmix()], [lifetbl()],
#'     [crmdens()], [knoxtst()],
#'     [rgnmapintg()], and the SIU report readers
#'     [siuprs()] and [siuso()] on pasted
#'     text. Air pollution: [plmfld()] and
#'     [gplume()] for a Gaussian plume, the
#'     monitors of the demo series ([plotsm()]),
#'     [crfpm25()], [crfno2()],
#'     [polbrdn()]
#'     and [vrfpol()]. Hawkes: [chwkfit()] with
#'     [plothwk()] (intensity, time-rescaling
#'     QQ, branching tree), [chwksim()] and
#'     [chwkjit()]. Search and rescue: the search theory
#'     functions behind one form, [ltrlrng()],
#'     [srchpod()], [pswppod()],
#'     [datumpmap()], [opteffort()] and
#'     [optcrcsrch()], with the POD and POS numbers and four
#'     plots, and any figure of Frost's The Theory of Search
#'     through [srchfig()].}
#'   \item{Report}{the results added from the tabs, as one self-contained HTML page
#'     (plots as inline SVG, year-over-year tables as [yoyhtml()] draws
#'     them), as
#'     Markdown, or as a GitHub comment to copy.}
#'   \item{Settings}{light, dark or the system's theme (also the switch in the navbar),
#'     digits, and the seed of the seeded analyses.}
#' }
#' The data key of data.rmorie.com is never held by the app:
#' [dload()] reads it from where `rmbl login` stored it.
#'
#' The dashboard needs the shiny package (Suggests), and with it bslib, which shiny
#' installs; without shiny `rmblapp()` refuses.
#' @param data A data frame, or the path of a CSV file, to start with; `NULL`
#'   for none.
#' @param capsule The directory of a capsule whose pinned data to start with;
#'   `NULL` for none.
#' @param ... Options passed to [shiny::shinyApp()], such
#'   as `port` and `launch.browser`.
#' @return A shiny app object; printing it (or
#'   [shiny::runApp()]) starts it.
#' @seealso `rmbl app` on the command line ([blcli()]);
#'   [rmbldemo()] for the datasets
#'   the tabs open on.
#' @examplesIf interactive()
#' rmblapp()
#' rmblapp(indiex("health"))
#' @export
rmblapp <- function(data = NULL, capsule = NULL, ...) {
  .bl_app_need()
  init <- .bl_app_init(data, capsule, deparse(substitute(data))[1L])
  shiny::shinyApp(ui = function(request) .bl_app_ui(), server = .bl_app_server(init), options = list(...),
                  enableBookmarking = "url")
}

#' Refuses when shiny or bslib is not installed.
#' @return TRUE, invisibly.
#' @noRd
.bl_app_need <- function() {
  if (!requireNamespace("shiny", quietly = TRUE) || !requireNamespace("bslib", quietly = TRUE)) {
    stop("rmblapp: the dashboard needs the shiny package: install.packages(\"shiny\")", call. = FALSE)
  }
  invisible(TRUE)
}

#' The data the app starts with.
#' @param data A data frame, a CSV path or NULL.
#' @param capsule A capsule directory or NULL.
#' @param name How `data` was written in the call.
#' @return A list: data, code, label, capsule.
#' @noRd
.bl_app_init <- function(data, capsule, name = "data") {
  if (!is.null(capsule)) return(.bl_app_capsule(capsule))
  if (is.null(data)) return(list(data = NULL, code = character(), label = "no data loaded", capsule = NULL))
  if (is.data.frame(data)) {
    return(list(data = data, code = if (identical(name, "data")) character() else paste("data <-", name),
                label = sprintf("%s (given to rmblapp())", name), capsule = NULL))
  }
  if (is.character(data) && length(data) == 1L && file.exists(data) && !dir.exists(data)) {
    return(.bl_app_read(data, data))
  }
  stop("rmblapp: `data` must be a data frame or the path of a CSV file", call. = FALSE)
}

#' Reads a CSV file with the package's reader (the columns read.csv() gives, typed the
#' same way).
#' @param path The file.
#' @param name The name to show and to write in the R call.
#' @return A list: data, code, label, capsule.
#' @noRd
.bl_app_read <- function(path, name) {
  d <- .bl_read_csv_gz(path)
  list(data = d, code = sprintf("data <- utils::read.csv(%s, stringsAsFactors = FALSE)", deparse(name)),
       label = basename(name), capsule = NULL)
}

#' Loads a demonstration dataset.
#' @param name Its name.
#' @return A list: data, code, label, capsule.
#' @noRd
.bl_app_demo <- function(name) {
  list(data = rmbldemo(name), code = sprintf("data <- rmbldemo(%s)", deparse(name)),
       label = sprintf("%s (demo)", name), capsule = NULL)
}

#' Loads the pinned data of a capsule.
#' @param dir The capsule directory.
#' @return A list: data, code, label, capsule.
#' @noRd
.bl_app_capsule <- function(dir) {
  dir <- .rmbl_string1(dir, "capsule")
  if (!dir.exists(dir)) stop("rmblapp: `capsule` is not an existing directory: ", dir, call. = FALSE)
  p <- loadprov(file.path(dir, "data_provenance.json"))
  f <- file.path(dir, p$resource$filename %||% "")
  if (!nzchar(p$resource$filename %||% "") || !file.exists(f)) {
    stop("rmblapp: the capsule's pinned data file is missing (run `rmbl refresh` to pin it)", call. = FALSE)
  }
  r <- .bl_app_read(f, f)
  r$label <- sprintf("%s (capsule %s)", basename(f), basename(normalizePath(dir)))
  r$capsule <- normalizePath(dir)
  r
}

#' Runs an expression, turning an error into the refusal and its explanation.
#' @param expr The expression.
#' @return Its value, or a list of class bl_app_error with msg, why and nodata.
#' @noRd
.bl_app_try <- function(expr) {
  tryCatch(expr, error = function(e) {
    structure(list(msg = conditionMessage(e), why = .bl_app_why(e), nodata = inherits(e, "bl_nodata")),
              class = "bl_app_error")
  })
}

#' Where an error comes from, in explerr()'s words, or "" when it is not one of the
#' package's.
#' @param e The condition.
#' @return One string.
#' @noRd
.bl_app_why <- function(e) {
  x <- tryCatch(explerr(e, n = 1L), error = function(err) NULL)
  if (is.null(x) || !nrow(x)) return("")
  sprintf("Raised by %s::%s() (%s match in the table of the package's messages).", x$package[[1L]],
          x$raised_by[[1L]], x$match[[1L]])
}

#' The refusal panel of a failed run; a run without data is a note, not a refusal.
#' @param r A bl_app_error.
#' @return A tag.
#' @noRd
.bl_app_err_ui <- function(r) {
  if (isTRUE(r$nodata)) return(shiny::tags$p(class = "bl-about", role = "status", r$msg))
  shiny::tags$div(class = "bl-err", role = "alert",
                  shiny::tags$p(shiny::tags$strong("Refused: "), r$msg),
                  if (nzchar(r$why)) shiny::tags$p(class = "bl-why", r$why))
}

#' A refusal as a toast, besides the panel; a run without data is not one.
#' @param r A run result.
#' @return NULL, invisibly.
#' @noRd
.bl_app_toast <- function(r) {
  if (inherits(r, "bl_app_error") && !isTRUE(r$nodata)) {
    shiny::showNotification(paste("Refused:", r$msg), type = "error", duration = 8)
  }
  invisible(NULL)
}

#' The type table of a data frame: column, type, missing, distinct.
#' @param d The data frame or NULL.
#' @return A data frame or NULL.
#' @noRd
.bl_app_types <- function(d) {
  if (!is.data.frame(d) || !ncol(d)) return(NULL)
  data.frame(column = names(d), type = vapply(d, function(v) class(v)[1L], ""),
             missing = vapply(d, function(v) sum(is.na(v)), 1L),
             distinct = vapply(d, function(v) length(unique(v)), 1L), stringsAsFactors = FALSE)
}

#' The page's theme: Bootstrap 5 with the house accent and the typography of yoyhtml()
#' (system fonts only, so nothing is fetched).
#' @return A bs_theme.
#' @noRd
.bl_app_theme <- function() {
  cols <- .bl_cols(3L)
  bslib::bs_theme(version = 5, primary = cols[[1L]], secondary = "#5c5c5c", success = "#1b7f6b",
                  danger = "#c2492f", info = cols[[3L]],
                  base_font = bslib::font_collection("ui-sans-serif", "-apple-system", "Segoe UI", "Roboto",
                                                     "Helvetica Neue", "Arial", "sans-serif"),
                  code_font = bslib::font_collection("ui-monospace", "SFMono-Regular", "Menlo", "Consolas",
                                                     "monospace"),
                  "font-size-base" = "0.9rem", "border-radius" = "0.5rem", "card-cap-bg" = "transparent")
}

#' The page's style: the yoyhtml() look on Bootstrap's own variables, light and dark.
#' @return CSS text.
#' @noRd
.bl_app_css <- function() {
  paste0(
    "[data-bs-theme=light] body{background:#faf9f7}",
    ".card-header{font-size:.78rem;text-transform:uppercase;letter-spacing:.07em;font-weight:600;",
    "color:var(--bs-secondary-color);display:flex;align-items:center;gap:.5rem;flex-wrap:wrap}",
    ".card-header .bl-tools{margin-left:auto;display:flex;gap:.35rem}",
    ".bl-lead{color:var(--bs-secondary-color);max-width:80ch;margin:0 0 .75rem}.bl-lead p{margin:0 0 .4rem}",
    ".bl-about{color:var(--bs-secondary-color);margin:0 0 .6rem}",
    ".bl-err{border-left:4px solid var(--bs-danger);padding:.5rem .9rem;margin:0 0 .75rem;",
    "background:var(--bs-body-bg)}.bl-why{color:var(--bs-secondary-color);margin:0}",
    ".bl-scroll{overflow:auto;max-height:28rem;max-width:100%}.bl-scroll table{font-size:.82rem}",
    ".bl-scroll th{position:sticky;top:0;background:var(--bs-body-bg);font-size:.7rem;text-transform:uppercase;",
    "letter-spacing:.05em;color:var(--bs-secondary-color)}",
    "pre{white-space:pre;overflow:auto;max-height:30rem;font-size:.8rem}",
    ".shiny-plot-output,img,svg{max-width:100%}",
    ".bl-method dt{font-size:.72rem;text-transform:uppercase;letter-spacing:.06em;color:var(--bs-secondary-color);",
    "margin-top:.5rem}.bl-method dd{margin:0 0 .25rem}",
    ".bl-chip{display:inline-block;padding:0 .45rem;border-radius:.6rem;font-size:.75rem;font-weight:600}",
    ".bl-ok{background:#e6f4f1;color:#1b7f6b}.bl-bad{background:#fbeae6;color:#c2492f}",
    ".bl-warn{background:#fdf3d8;color:#8a6100}",
    ".value-box-title{font-size:.78rem}.value-box-value{font-size:1.35rem !important;overflow-wrap:anywhere}",
    ".bslib-value-box p{margin:0}",
    ".btn-link.bl-col{padding:0;font-size:inherit;vertical-align:baseline}",
    "a:focus-visible,button:focus-visible,input:focus-visible,select:focus-visible,textarea:focus-visible,",
    ".selectize-input.focus{outline:2px solid var(--bs-primary);outline-offset:2px}",
    "@media (max-width:575.98px){.navbar-brand{font-size:1rem}.bslib-page-navbar>.container-fluid{padding:0 8px}}"
  )
}

#' The page's script: the copy button.
#' @return JavaScript text.
#' @noRd
.bl_app_js <- function() {
  paste0(
    "$(document).on('click','.bl-copy',function(){var el=document.getElementById($(this).data('target'));",
    "if(el&&navigator.clipboard){navigator.clipboard.writeText(el.textContent)}});"
  )
}

#' One tab of the page, by id.
#' @param id The tab id.
#' @param specs The tab specs.
#' @return A nav panel.
#' @noRd
.bl_app_tab <- function(id, specs) {
  s <- Filter(function(s) s$id == id, specs)[[1L]]
  bslib::nav_panel(s$title, value = s$id, .bl_tab_ui(s$id, s))
}

#' The page.
#' @return A shiny UI.
#' @noRd
.bl_app_ui <- function() {
  specs <- .bl_app_specs()
  tab <- function(id) .bl_app_tab(id, specs)
  bslib::page_navbar(
    title = "rmoriebricklayer", id = "tabs", lang = "en", theme = .bl_app_theme(), fillable = FALSE,
    window_title = "rmoriebricklayer dashboard", selected = "describe",
    header = shiny::tagList(shiny::tags$head(shiny::tags$style(shiny::HTML(.bl_app_css())),
                                             shiny::tags$script(shiny::HTML(.bl_app_js()))),
                            shiny::useBusyIndicators()),
    sidebar = bslib::sidebar(id = "datasidebar", title = "Data", width = 290, open = "closed",
                             .bl_data_ui("data")),
    bslib::nav_menu("Data", tab("describe"), tab("dist")),
    bslib::nav_menu("Over time", tab("yoy"), tab("rates"), tab("trends")),
    bslib::nav_menu("Causal and survey", tab("survey"), tab("policy")),
    bslib::nav_menu("Capsules", tab("drift"),
                    bslib::nav_panel("Capsule", value = "capsule", .bl_cps_ui("capsule")),
                    bslib::nav_panel("Proof ledger", value = "ledger", .bl_ldgr_ui("ledger"))),
    bslib::nav_menu("Domains", tab("fnmi"), tab("justice"), tab("air"), tab("hawkes"),
                    bslib::nav_panel("Search and rescue", value = "search", .bl_srch_ui("search"))),
    bslib::nav_panel("Report", value = "report", .bl_rpt_ui("report")),
    bslib::nav_panel("Settings", value = "settings", .bl_set_ui("settings")),
    bslib::nav_spacer(),
    bslib::nav_item(shiny::bookmarkButton(label = "Share this view", class = "btn-sm btn-outline-secondary",
                                          title = "A link that reopens this tab with the same data and form")),
    bslib::nav_item(bslib::input_dark_mode(id = "mode"))
  )
}

#' The server.
#' @param init The data to start with, from .bl_app_init().
#' @return A shiny server function.
#' @noRd
.bl_app_server <- function(init) {
  function(input, output, session) {
    set <- .bl_set_server("settings")
    dat <- .bl_data_server("data", init)
    rpt <- shiny::reactiveVal(list())
    active <- shiny::reactive(input$tabs %||% "describe")
    mode <- shiny::reactive(input$mode %||% "light")
    for (s in .bl_app_specs()) .bl_tab_server(s$id, s, dat, rpt, set, active, mode)
    .bl_drift_server(input, output, session)
    .bl_cps_server("capsule", dat, rpt, active)
    .bl_srch_server("search", rpt)
    .bl_ldgr_server("ledger", dat, rpt, active)
    .bl_rpt_server("report", rpt)
  }
}

# ---- data source --------------------------------------------------------------------------------

#' The data source panel of the sidebar.
#' @param id The module id.
#' @return A tag list.
#' @noRd
.bl_data_ui <- function(id) {
  ns <- shiny::NS(id)
  dm <- rmbldemo()
  shiny::tagList(
    shiny::tags$p(class = "bl-about", "Each tab opens on its own demo data. Data chosen here is used by every tab."),
    bslib::accordion(
      id = ns("acc"), open = "Source", multiple = TRUE,
      bslib::accordion_panel(
        "Source",
        shiny::radioButtons(ns("src"), NULL, c("Demo dataset" = "demo", "CSV file" = "csv",
                                               "Capsule directory" = "capsule", "data.rmorie.com table" = "hub")),
        shiny::conditionalPanel("input.src == 'demo'", ns = ns,
                                shiny::selectInput(ns("demo"), "Demo dataset",
                                                   stats::setNames(dm$name, paste0(dm$name, ": ", dm$description))),
                                shiny::actionButton(ns("demoload"), "Use this dataset", class = "btn-sm btn-primary")),
        shiny::conditionalPanel("input.src == 'csv'", ns = ns,
                                shiny::fileInput(ns("csv"), "CSV file (plain or gzip)", accept = c(".csv", ".gz"))),
        shiny::conditionalPanel("input.src == 'capsule'", ns = ns,
                                shiny::textInput(ns("cpsdir"), "Capsule directory"),
                                shiny::actionButton(ns("cpsload"), "Load the pinned data", class = "btn-sm")),
        shiny::conditionalPanel("input.src == 'hub'", ns = ns,
                                shiny::uiOutput(ns("signin")),
                                shiny::actionButton(ns("hublist"), "List the tables", class = "btn-sm"),
                                shiny::selectInput(ns("hubkey"), "Table", NULL),
                                shiny::actionButton(ns("hubload"), "Load the table", class = "btn-sm"))
      ),
      bslib::accordion_panel(
        "Loaded datasets",
        shiny::actionButton(ns("alldemos"), "Load all demos", class = "btn-sm btn-outline-primary w-100 mb-2"),
        shiny::selectInput(ns("pick"), "Active dataset", NULL)
      ),
      bslib::accordion_panel("Columns", shiny::uiOutput(ns("colsui")))
    ),
    shiny::uiOutput(ns("status"))
  )
}

#' The data source server.
#' @param id The module id.
#' @param init The data to start with.
#' @return A reactive value holding list(data, code, label, capsule).
#' @noRd
.bl_data_server <- function(id, init) {
  shiny::moduleServer(id, function(input, output, session) {
    shiny::setBookmarkExclude(c("csv", "demoload", "cpsload", "hublist", "hubload", "alldemos", "acc"))
    cur <- shiny::reactiveVal(init)
    msg <- shiny::reactiveVal(NULL)
    loaded <- shiny::reactiveVal(if (is.data.frame(init$data)) stats::setNames(list(init), init$label) else list())
    keep <- function(rs) {
      l <- loaded()
      for (r in rs) l[[r$label]] <- r
      loaded(l)
      shiny::updateSelectInput(session, "pick", choices = names(l), selected = rs[[length(rs)]]$label)
    }
    take <- function(r) {
      if (inherits(r, "bl_app_error")) {
        msg(r)
        .bl_app_toast(r)
      } else {
        cur(r)
        msg(NULL)
        keep(list(r))
      }
    }
    shiny::observeEvent(input$demoload, take(.bl_app_try(.bl_app_demo(input$demo))))
    shiny::observeEvent(input$alldemos, {
      rs <- lapply(rmbldemo()$name, .bl_app_demo)
      keep(rs)
      cur(rs[[length(rs)]])
      shiny::showNotification(sprintf("%d demo datasets loaded: pick one under Active dataset.", length(rs)),
                              type = "message")
    })
    shiny::observeEvent(input$pick, {
      r <- loaded()[[input$pick]]
      if (!is.null(r) && !identical(r$label, cur()$label)) cur(r)
    }, ignoreInit = TRUE)
    shiny::observeEvent(input$csv, take(.bl_app_try(.bl_app_read(input$csv$datapath, input$csv$name))))
    shiny::observeEvent(input$cpsload, take(.bl_app_try(.bl_app_capsule(input$cpsdir))))
    shiny::observeEvent(input$hublist, {
      r <- .bl_app_try(dtabs())
      if (inherits(r, "bl_app_error")) {
        msg(r)
      } else {
        shiny::updateSelectInput(session, "hubkey", choices = stats::setNames(r$key, paste(r$key, "-", r$name)))
      }
    })
    shiny::observeEvent(input$hubload, take(.bl_app_try({
      key <- input$hubkey
      list(data = dload(key), code = sprintf("data <- dload(%s)", deparse(key)), label = key, capsule = NULL)
    })))
    output$signin <- shiny::renderUI({
      # whether a key is stored, never the key
      shiny::tags$p(class = "bl-about", if (is.null(.bl_hosted_key())) {
        "Not signed in: run `rmbl login` in a terminal, then list the tables."
      } else {
        "Signed in: the data key stays where `rmbl login` stored it."
      })
    })
    output$status <- shiny::renderUI({
      m <- msg()
      if (!is.null(m)) return(.bl_app_err_ui(m))
      d <- cur()
      if (!is.data.frame(d$data)) return(shiny::tags$p(class = "bl-about", "No dataset chosen here yet."))
      shiny::tags$p(shiny::tags$strong(d$label),
                    sprintf(": %s rows, %d columns", format(nrow(d$data), big.mark = ","), ncol(d$data)))
    })
    output$cols <- shiny::renderTable(.bl_app_types(cur()$data))
    output$colsui <- shiny::renderUI({
      if (!is.data.frame(cur()$data)) return(shiny::tags$p(class = "bl-about", "Choose a dataset to see its columns."))
      shiny::tags$div(class = "bl-scroll", shiny::tableOutput(session$ns("cols")))
    })
    cur
  })
}

# ---- one analysis tab ---------------------------------------------------------------------------

#' The download menu of a plot card: PNG, SVG, the table as CSV and the result.
#' @param ns The namespace function.
#' @return A tag.
#' @noRd
.bl_dl_menu <- function(ns) {
  item <- function(id, lab) shiny::tags$li(shiny::downloadLink(ns(id), lab, class = "dropdown-item"))
  shiny::tags$div(class = "dropdown bl-tools",
                  shiny::tags$button(class = "btn btn-sm btn-outline-secondary dropdown-toggle", type = "button",
                                     `data-bs-toggle` = "dropdown", `aria-expanded` = "false", "Download"),
                  shiny::tags$ul(class = "dropdown-menu dropdown-menu-end",
                                 item("png", "Plot as PNG"), item("svg", "Plot as SVG"),
                                 item("csv", "Table as CSV"), item("dl", "The result (as the package writes it)")))
}

#' The form, value boxes and cards of one tab.
#' @param id The module id.
#' @param s The tab's spec.
#' @return A tag.
#' @noRd
.bl_tab_ui <- function(id, s) {
  ns <- shiny::NS(id)
  fns <- vapply(s$fns, `[[`, "", "label")
  card <- function(title, ..., tools = NULL, full = TRUE) {
    bslib::card(full_screen = full, bslib::card_header(title, tools), bslib::card_body(...))
  }
  plot_args <- list(ns("plot"), height = "420px", hover = shiny::hoverOpts(ns("hover"), delay = 120))
  bslib::layout_sidebar(
    fillable = FALSE,
    sidebar = bslib::sidebar(
      id = ns("side"), title = "Analysis", width = 300, open = list(desktop = "open", mobile = "always-above"),
      shiny::selectInput(ns("source"), "Data", c(s$sources, "The dataset chosen at the left" = ""),
                         selected = unname(s$sources[[1L]])),
      shiny::selectInput(ns("fn"), "Analysis", stats::setNames(names(s$fns), fns)),
      shiny::uiOutput(ns("form")),
      bslib::input_task_button(ns("run"), "Run", label_busy = "Running...", class = "btn-primary"),
      shiny::actionButton(ns("add"), "Add to report", class = "btn-outline-secondary")
    ),
    shiny::tags$div(class = "bl-lead", s$about),
    shiny::tags$div(`aria-live` = "polite", shiny::uiOutput(ns("err"))),
    shiny::uiOutput(ns("vbox")),
    bslib::layout_columns(
      col_widths = bslib::breakpoints(sm = 12, xl = c(8, 4)),
      card("Plot", do.call(shiny::plotOutput, plot_args), shiny::uiOutput(ns("hoverinfo")), tools = .bl_dl_menu(ns)),
      card("Method", shiny::uiOutput(ns("method")), full = FALSE)
    ),
    if (identical(s$linked, "density")) .bl_drift_brush_ui(ns),
    bslib::layout_columns(
      col_widths = bslib::breakpoints(sm = 12, xl = c(6, 6)),
      card("Diagnostics", shiny::uiOutput(ns("diagsel")), shiny::uiOutput(ns("diag"))),
      card("Table", shiny::uiOutput(ns("table")),
           bslib::accordion(open = FALSE, bslib::accordion_panel("Printed result",
                                                                 shiny::verbatimTextOutput(ns("print")))))
    ),
    card("Reproducible R call", shiny::verbatimTextOutput(ns("code")), full = FALSE,
         tools = shiny::tags$div(class = "bl-tools",
                                 shiny::tags$button(type = "button", class = "btn btn-sm btn-outline-secondary bl-copy",
                                                    `data-target` = ns("code"), "Copy"))),
    if (is.function(s$extra)) s$extra()
  )
}

#' The values the form of an analysis starts with, by input name, as the page's controls
#' hold them: a column argument takes the first of its defaults the data has.
#' @param f The analysis spec.
#' @param cols The column names of the data, or NULL to take the first default.
#' @return A named list.
#' @noRd
.bl_form_defaults <- function(f, cols = NULL) {
  out <- list()
  first <- function(def) {
    d <- if (is.null(cols)) def else intersect(def, cols)
    if (length(d)) d[[1L]] else ""
  }
  for (st in c(f$steps, if (!is.null(f$plot)) list(f$plot), lapply(f$diag, `[[`, "step"))) {
    for (nm in names(st$args)) {
      a <- st$args[[nm]]
      v <- switch(a$type,
        col = , vec = , date = first(a$default),
        area = a$default %||% "",
        cols = , mat = , frame = if (is.null(cols)) a$default else intersect(a$default, cols),
        choices = a$default,
        num = a$default %||% NA,
        text = , nums = , texts = , seq = paste(a$default %||% "", collapse = ", "),
        choice = a$default %||% a$choices[[1L]],
        flag = isTRUE(a$default),
        NULL
      )
      if (!is.null(v)) out[[paste0("a_", .bl_arg_id(nm, a))]] <- v
    }
  }
  out
}

#' The data of a tab: an example source of the spec, or the data loaded at the left.
#' @param src The chosen source: "" or an R expression from the spec.
#' @param dat The data loaded at the left.
#' @return A list: data and code.
#' @noRd
.bl_tab_data <- function(src, dat) {
  if (is.null(src) || !nzchar(src)) return(list(data = dat$data, code = dat$code))
  list(data = eval(str2lang(src), new.env(parent = asNamespace("rmoriebricklayer"))),
       code = paste("data <-", src))
}

#' One form control.
#' @param ns The namespace function.
#' @param nm The argument's input name.
#' @param a The argument's spec.
#' @param cols The column names of the data.
#' @return A tag, or NULL for an argument with no control.
#' @noRd
.bl_arg_ui <- function(ns, nm, a, cols) {
  id <- ns(paste0("a_", nm))
  lab <- a$label %||% nm
  pick <- function(def) {
    d <- intersect(def, cols)
    if (length(d)) d[[1L]] else ""
  }
  switch(a$type,
    col = , vec = , date = shiny::selectInput(id, lab, c("", cols), selected = pick(a$default)),
    cols = , mat = , frame = shiny::selectInput(id, lab, cols, multiple = TRUE, selected = intersect(a$default, cols)),
    num = shiny::numericInput(id, lab, a$default %||% NA),
    text = , nums = , texts = , seq = shiny::textInput(id, lab, paste(a$default %||% "", collapse = ", ")),
    area = shiny::textAreaInput(id, lab, a$default %||% "", rows = 8),
    choice = shiny::selectInput(id, lab, a$choices, selected = a$default),
    choices = shiny::selectInput(id, lab, a$choices, multiple = TRUE, selected = a$default),
    flag = shiny::checkboxInput(id, lab, isTRUE(a$default)),
    NULL
  )
}

#' The input name of an argument: its own `input`, else its name.
#' @param nm The argument's name.
#' @param a Its spec.
#' @return One string.
#' @noRd
.bl_arg_id <- function(nm, a) a$input %||% nm

#' The value an argument takes in the call, from its control; NULL leaves it out.
#' @param a The argument's spec.
#' @param v The control's value.
#' @param set The settings.
#' @return A value or a language object, or NULL.
#' @noRd
.bl_arg_val <- function(a, v, set) {
  has <- length(v) && !all(is.na(v)) && !identical(v, "")
  split <- function(v) trimws(strsplit(v, ",", fixed = TRUE)[[1L]])
  nums <- function(v) {
    n <- suppressWarnings(as.numeric(split(v)))
    if (anyNA(n)) stop(sprintf("`%s` must be numbers separated by commas", a$label %||% "a value"), call. = FALSE)
    n
  }
  data <- as.name("data")
  switch(a$type,
    data = data, ref = as.name(a$name), fixed = a$value, seed = set$seed,
    col = , choice = , text = , area = if (has) v,
    cols = , choices = if (has) as.character(v),
    vec = if (has) call("[[", data, v),
    date = if (has) call("as.Date", call("[[", data, v)),
    frame = if (has) call("[", data, as.character(v)),
    mat = if (has) call("as.matrix", call("[", data, as.character(v))),
    num = if (has) v,
    nums = if (has) nums(v),
    texts = if (has) split(v),
    seq = if (has) {
      n <- nums(v)
      if (length(n) != 3L) stop(sprintf("`%s` must be from, to, by", a$label %||% "a range"), call. = FALSE)
      call("seq", n[[1L]], n[[2L]], by = n[[3L]])
    },
    flag = isTRUE(v)
  )
}

#' Builds the call of one step from the form.
#' @param st The step: fn and args.
#' @param input The inputs.
#' @param set The settings.
#' @return A call.
#' @noRd
.bl_step_call <- function(st, input, set) {
  args <- list()
  for (nm in names(st$args)) {
    a <- st$args[[nm]]
    v <- .bl_arg_val(a, input[[paste0("a_", .bl_arg_id(nm, a))]], set)
    if (is.null(v)) next
    args[length(args) + 1L] <- list(v)
    names(args)[length(args)] <- if (isTRUE(a$pos)) "" else nm
  }
  as.call(c(list(if (grepl("::", st$fn, fixed = TRUE)) str2lang(st$fn) else as.name(st$fn)), args))
}

#' The row filter of a tab, as a call, or NULL when no value is chosen.
#' @param filters The filterable columns.
#' @param input The inputs.
#' @param d The data.
#' @return A call or NULL.
#' @noRd
.bl_tab_filter <- function(filters, input, d) {
  cond <- NULL
  for (f in intersect(filters, names(d))) {
    v <- input[[paste0("f_", make.names(f))]]
    if (!length(v)) next
    one <- call("%in%", call("[[", as.name("data"), f), v)
    cond <- if (is.null(cond)) one else call("&", cond, one)
  }
  if (is.null(cond)) return(NULL)
  call("<-", as.name("data"), as.call(list(as.name("["), as.name("data"), cond, quote(expr = ), drop = FALSE)))
}

#' Deparses a call to one line of code.
#' @param x The call.
#' @return One string.
#' @noRd
.bl_code <- function(x) paste(deparse(x, width.cutoff = 500L), collapse = " ")

#' Runs one analysis: the filter, each step, then the plot (to a null device) and the
#' diagnostic plots' calls.
#' @param f The analysis spec.
#' @param s The tab spec.
#' @param d The tab's data, from .bl_tab_data().
#' @param input The inputs.
#' @param set The settings.
#' @return A list: value, code, env, plot (a call or NULL), diag (named calls), title and
#'   hover (the period column, or NULL).
#' @noRd
.bl_tab_run <- function(f, s, d, input, set) {
  if (isTRUE(f$needs_data %||% TRUE) && !is.data.frame(d$data)) {
    stop(structure(class = c("bl_nodata", "error", "condition"),
                   list(message = "No data yet: choose an example in Data, or a dataset at the left.", call = NULL)))
  }
  env <- new.env(parent = asNamespace("rmoriebricklayer"))
  env$data <- d$data
  code <- d$code
  flt <- .bl_tab_filter(s$filters, input, d$data)
  if (!is.null(flt)) {
    eval(flt, env)
    code <- c(code, .bl_code(flt))
  }
  value <- NULL
  for (st in f$steps) {
    cl <- .bl_step_call(st, input, set)
    value <- eval(cl, env)
    assign(st$out, value, envir = env)
    code <- c(code, paste(st$out, "<-", .bl_code(cl)))
  }
  pl <- if (!is.null(f$plot)) .bl_step_call(f$plot, input, set)
  if (!is.null(pl)) {
    grDevices::pdf(NULL)
    on.exit(grDevices::dev.off(), add = TRUE)
    drawn <- eval(pl, env)
    if (!length(f$steps)) value <- drawn
    code <- c(code, .bl_code(pl))
  }
  dg <- lapply(f$diag, function(g) .bl_step_call(g$step, input, set))
  names(dg) <- vapply(f$diag, `[[`, "", "label")
  if (length(dg)) code <- c(code, "# diagnostics", vapply(dg, .bl_code, ""))
  hv <- if (!is.null(f$hover)) input[[paste0("a_", f$hover)]]
  list(value = value, code = code, env = env, plot = pl, diag = dg, title = f$label,
       hover = if (length(hv) && nzchar(hv)) hv)
}

#' Runs a function in a forked background process when it is long and the platform can
#' fork, as a promise; else runs it here and returns its value.
#' @param fn The function, of no arguments.
#' @param long Whether to run it in the background.
#' @return A promise, or the value.
#' @noRd
.bl_bg <- function(fn, long = FALSE) {
  if (!isTRUE(long) || .Platform$OS.type != "unix" || !requireNamespace("promises", quietly = TRUE) ||
        !requireNamespace("later", quietly = TRUE)) {
    return(fn())
  }
  job <- parallel::mcparallel(fn(), silent = TRUE)
  promises::promise(function(resolve, reject) {
    poll <- function() {
      r <- parallel::mccollect(job, wait = FALSE)
      if (is.null(r)) return(later::later(poll, 0.1))
      v <- r[[1L]]
      if (is.null(v) || inherits(v, "try-error")) {
        reject(simpleError(if (is.null(v)) "the background run ended without a result" else
          conditionMessage(attr(v, "condition"))))
      } else {
        resolve(v)
      }
    }
    poll()
  })
}

#' The form and outputs of one tab.
#' @param id The module id.
#' @param s The tab spec.
#' @param dat The data loaded at the left.
#' @param rpt The report's entries.
#' @param set The settings.
#' @param active The id of the tab on the page; the tab runs its first analysis when it
#'   is first shown.
#' @param mode The colour mode of the page, "light" or "dark".
#' @return NULL, invisibly.
#' @noRd
.bl_tab_server <- function(id, s, dat, rpt, set, active = shiny::reactive(id), mode = shiny::reactive("light")) {
  # forced here: the tabs are made in a loop, and a promise first read by an observer or a task would see
  # the loop's last spec (every tab ran the Hawkes analysis)
  force(s)
  shiny::moduleServer(id, function(input, output, session) {
    shiny::setBookmarkExclude(c("run", "add", "pickcol", "hover", "dbrush", "side"))
    res <- shiny::reactiveVal(NULL)
    restored <- shiny::reactiveVal(list())
    shiny::onRestore(function(state) restored(state$input))
    # before the page has sent its inputs, the tab's first example is its data
    tabdata <- shiny::reactive(.bl_app_try(.bl_tab_data(input$source %||% unname(s$sources[[1L]]), dat())))
    task <- shiny::ExtendedTask$new(function(f, d, inp, st) {
      .bl_bg(function() .bl_app_try(.bl_tab_run(f, s, d, inp, st)), f$long)
    })
    bslib::bind_task_button(task, "run")
    go <- function(inp) {
      d <- tabdata()
      if (inherits(d, "bl_app_error")) return(res(d))
      inp <- utils::modifyList(restored(), inp)
      f <- s$fns[[inp$fn %||% names(s$fns)[1L]]]
      cols <- if (is.data.frame(d$data)) names(d$data)
      task$invoke(f, d, utils::modifyList(.bl_form_defaults(f, cols), inp), set())
    }
    shiny::observeEvent(input$run, go(shiny::reactiveValuesToList(input)))
    # the tab runs its first analysis (or the restored one) on its example data when first shown
    shiny::observeEvent(active(), {
      if (identical(active(), id) && task$status() == "initial") go(shiny::reactiveValuesToList(input))
    })
    # a dataset chosen at the left becomes the tab's data, and runs
    shiny::observeEvent(dat(), {
      shiny::updateSelectInput(session, "source", selected = "")
      restored(list())
    }, ignoreInit = TRUE)
    shiny::observe({
      st <- task$status()
      if (st %in% c("success", "error")) {
        r <- .bl_app_try(task$result())
        res(r)
        .bl_app_toast(r)
      }
    })
    output$form <- shiny::renderUI({
      f <- s$fns[[input$fn %||% names(s$fns)[1L]]]
      d <- tabdata()
      cols <- if (is.data.frame(d$data)) names(d$data) else character()
      args <- list()
      for (st in c(f$steps, if (!is.null(f$plot)) list(f$plot), lapply(f$diag, `[[`, "step"))) {
        for (nm in names(st$args)) args[[.bl_arg_id(nm, st$args[[nm]])]] <- st$args[[nm]]
      }
      flt <- lapply(intersect(s$filters, cols), function(fc) {
        shiny::selectInput(session$ns(paste0("f_", make.names(fc))), sprintf("Rows where %s is", fc),
                           sort(unique(as.character(d$data[[fc]]))), multiple = TRUE)
      })
      shiny::tagList(if (!is.null(f$about)) shiny::tags$p(class = "bl-about", f$about), flt,
                     lapply(names(args), function(nm) .bl_arg_ui(session$ns, nm, args[[nm]], cols)))
    })
    ok <- function() {
      r <- res()
      !is.null(r) && !inherits(r, "bl_app_error")
    }
    data_n <- function() {
      d <- tabdata()
      if (!inherits(d, "bl_app_error") && is.data.frame(d$data)) nrow(d$data)
    }
    output$code <- shiny::renderText(if (ok()) paste(res()$code, collapse = "\n") else "")
    output$err <- shiny::renderUI(if (inherits(res(), "bl_app_error")) .bl_app_err_ui(res()))
    output$vbox <- shiny::renderUI(if (ok()) .bl_vbox_ui(.bl_headline(res()$value, data_n())))
    output$method <- shiny::renderUI({
      f <- s$fns[[input$fn %||% names(s$fns)[1L]]]
      .bl_method_ui(f, s, if (ok()) .bl_headline(res()$value, data_n()), if (ok()) res()$value)
    })
    output$plot <- shiny::renderPlot({
      shiny::req(ok())
      .bl_plot_run(res()$plot, res(), mode())
    }, res = 96, bg = "transparent")
    output$hoverinfo <- shiny::renderUI({
      shiny::req(ok(), res()$hover)
      .bl_hover_ui(res()$value, res()$hover, input$hover)
    })
    output$diagsel <- shiny::renderUI({
      shiny::req(ok())
      ch <- .bl_diag_choices(res())
      if (length(ch)) {
        shiny::tagList(shiny::selectInput(session$ns("diagwhich"), "Diagnostic plot", ch),
                       shiny::plotOutput(session$ns("diagplot"), height = "320px"))
      }
    })
    output$diagplot <- shiny::renderPlot({
      shiny::req(ok())
      ch <- .bl_diag_choices(res())
      shiny::req(length(ch) > 0L)
      w <- input$diagwhich %||% ch[[1L]]
      .bl_draw_diag(res(), if (w %in% ch) w else ch[[1L]], mode())
    }, res = 96, bg = "transparent")
    output$diag <- shiny::renderUI(if (ok()) .bl_diag_ui(res()$value))
    output$table <- shiny::renderUI({
      shiny::req(ok())
      d <- tabdata()
      .bl_table_ui(res()$value, set()$digits, if (identical(s$linked, "columns") && is.data.frame(d$data)) {
        list(ns = session$ns, cols = names(d$data))
      })
    })
    output$print <- shiny::renderPrint({
      shiny::req(ok())
      op <- options(digits = set()$digits)
      on.exit(options(op), add = TRUE)
      print(res()$value)
    })
    output$dl <- shiny::downloadHandler(
      filename = function() .bl_dl_name(res()$value, id),
      content = function(file) .bl_dl_write(res()$value, file)
    )
    output$png <- shiny::downloadHandler(paste0("rmbl-", id, ".png"), function(file) {
      .bl_save_plot(res(), file, "png")
    })
    output$svg <- shiny::downloadHandler(paste0("rmbl-", id, ".svg"), function(file) {
      .bl_save_plot(res(), file, "svg")
    })
    output$csv <- shiny::downloadHandler(paste0("rmbl-", id, ".csv"), function(file) {
      utils::write.csv(.bl_main_table(res()$value), file, row.names = FALSE)
    })
    # a column of the profile opens its distribution
    shiny::observeEvent(input$pickcol, {
      d <- tabdata()
      shiny::req(!inherits(d, "bl_app_error"), input$pickcol %in% names(d$data))
      shiny::showModal(shiny::modalDialog(
        title = sprintf("The distribution of %s", input$pickcol), size = "l", easyClose = TRUE,
        shiny::plotOutput(session$ns("colplot"), height = "360px"), shiny::tableOutput(session$ns("colsumm"))))
    })
    output$colplot <- shiny::renderPlot({
      d <- tabdata()
      shiny::req(input$pickcol %in% names(d$data))
      .bl_col_plot(d$data[[input$pickcol]], input$pickcol, mode())
    }, res = 96, bg = "transparent")
    output$colsumm <- shiny::renderTable({
      d <- tabdata()
      shiny::req(input$pickcol %in% names(d$data))
      .bl_col_summary(d$data[[input$pickcol]])
    })
    if (identical(s$linked, "density")) .bl_drift_brush_server(input, output, session, tabdata, mode)
    shiny::observeEvent(input$add, if (ok()) {
      rpt(c(rpt(), list(.bl_rpt_entry(res()))))
      shiny::showNotification(sprintf("Added \"%s\" to the report.", res()$title), type = "message", duration = 3)
    })
    invisible(NULL)
  })
}

#' The file name of a downloaded result.
#' @param x The result.
#' @param id The tab.
#' @return One string.
#' @noRd
.bl_dl_name <- function(x, id) {
  paste0("rmbl-", id, if (inherits(x, "rmbl_yoy")) ".html" else if (.bl_dl_table(x, TRUE)) ".csv" else ".txt")
}

#' A result as a table for download, or whether there is one.
#' @param x The result.
#' @param test Whether only to say if there is one.
#' @return A data frame (or NULL), or TRUE/FALSE.
#' @noRd
.bl_dl_table <- function(x, test = FALSE) {
  t <- if (is.data.frame(x)) x else if (is.list(x) && is.data.frame(x$table)) x$table else
    if (is.atomic(x) && is.numeric(x) && is.null(dim(x))) data.frame(value = as.numeric(x))
  if (test) !is.null(t) else as.data.frame(t)
}

#' Writes a downloaded result: a yoy() table as yoyhtml() draws it, a table as CSV,
#' else the print.
#' @param x The result.
#' @param file The file.
#' @return The file, invisibly.
#' @noRd
.bl_dl_write <- function(x, file) {
  if (inherits(x, "rmbl_yoy")) {
    yoyhtml(x, file)
  } else if (.bl_dl_table(x, TRUE)) {
    utils::write.csv(.bl_dl_table(x), file, row.names = FALSE)
  } else {
    writeLines(utils::capture.output(print(x)), file)
  }
  invisible(file)
}

#' Runs the app verb: `rmbl app [PATH] [--port N] [--no-browser]`.
#' @param rest The arguments after the verb.
#' @param flag A function that returns the value of an option, or NULL.
#' @param has A function that tells whether an option was given.
#' @param out The function that prints the verb's output.
#' @param usage_error A function that raises a usage error.
#' @return The exit status.
#' @noRd
.bl_cli_app <- function(rest, flag, has, out, usage_error) {
  port <- flag("--port")
  pos <- setdiff(rest, c("--port", port, "--no-browser"))
  if (length(pos) > 1L) usage_error("usage: app [PATH] [--port N] [--no-browser]")
  if (!is.null(port) && !grepl("^[0-9]{1,5}$", port)) usage_error("--port takes a port number")
  path <- if (length(pos)) pos[[1L]]
  if (!is.null(path) && !file.exists(path)) stop("no such file or directory: ", path, call. = FALSE)
  app <- if (is.null(path)) rmblapp() else if (dir.exists(path)) rmblapp(capsule = path) else rmblapp(data = path)
  out(sprintf("starting the dashboard%s; Ctrl-C stops it\n", if (is.null(port)) "" else paste(" on port", port)))
  .bl_app_launch(app, if (!is.null(port)) as.integer(port), !has("--no-browser"))
  0L
}

#' Starts the app and waits until it is stopped.
#' @param app The app.
#' @param port The port, or NULL for shiny's choice.
#' @param browser Whether to open a browser.
#' @return NULL, invisibly.
#' @noRd
.bl_app_launch <- function(app, port, browser) {
  shiny::runApp(app, port = port %||% getOption("shiny.port"), launch.browser = browser)
  invisible(NULL)
}
