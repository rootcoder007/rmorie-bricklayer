# SPDX-License-Identifier: AGPL-3.0-or-later
# The analysis dashboard: a shiny app over the package's own functions. Each tab is a form over
# exported functions (dashboard_specs.R); a run evaluates exactly the call it shows, so what the
# page computed can be pasted into a script and computed again.

#' Open the analysis dashboard
#'
#' A local web app over the package's analyses: load a CSV file, the pinned data of a
#' capsule, or a table from data.rmorie.com (after `rmbl login`), then run the
#' analysis families through forms, with the package's own plots and reports.
#' Everything runs on this machine in this R session; nothing is sent anywhere except
#' the data.rmorie.com requests you make.
#'
#' @details Every analysis shows the R call it ran, and runs exactly that call, so a
#'   result can be reproduced in a script by copying the code. A refusal is shown as
#'   the package words it, with [explerr()]'s explanation of where
#'   it comes from beside it. The tabs:
#' \describe{
#'   \item{Describe}{[profcols()],
#'     [freqtbl()], [cortbl()],
#'     [mahaoutl()], [missgrid()] and the
#'     distribution plots ([plotrdg()],
#'     [plotecdf()], [plotvln()],
#'     [plothex()], [plotgain()]); the
#'     column types are listed under the data source.}
#'   \item{Year over year}{[yoy()] with period, value, group, minimum
#'     base and direction, its plot, and the [yoyhtml()] page to
#'     download.}
#'   \item{Rates}{[rtcalc()], [ratechg()] and
#'     [shrs()], with intervals and plots.}
#'   \item{Trends}{[trndtst()] (Mann-Kendall with the Theil-Sen
#'     slope), [stepchg()], [cnttrnd()], and
#'     [plotcal()], [plothrz()],
#'     [plotsm()] and [plotbump()].}
#'   \item{Survey}{[svydes()] with weights, strata, clusters or
#'     replicate weights, then [svyest()] or
#'     [svycmp()].}
#'   \item{Distributions}{[dstfit()] with its density, QQ, PP and
#'     tail plots, and a synthetic sample from a fit through
#'     [mksyncol()].}
#'   \item{Drift}{the drift app of [drftapp()] on two uploaded CSV
#'     files.}
#'   \item{Capsule}{the provenance of a capsule (source, pinned digest, manifest,
#'     attestation, bundle files) and its verification rows, with buttons that run
#'     [vrfcps()] and [cpschk()], or
#'     [cpsrfrsh()].}
#'   \item{Policy}{the panel and policy-evaluation functions on panel data:
#'     [plndid()], [evstudy()],
#'     [stgatt()], [bacondcmp()],
#'     [swtdid()], [perminf()],
#'     [syndid()], [mtchdid()],
#'     [wcb()], [loounit()],
#'     [cohtrnd()], [plnpwr()],
#'     [baltab()] and [tse()].}
#'   \item{First Nations, Metis and Inuit}{the bundled Statistics Canada tables
#'     ([indiex()]) or a table of your own in the same layout:
#'     [indgap()], [dstntst()],
#'     [ordcmp()], [welprof()] with
#'     [dualcont()], [healchg()],
#'     [mhcont()], [stdprev()] and
#'     [trcprog()]. Each distinction is reported on its own,
#'     suppressed cells stay suppressed with their quality flags, and the panel states
#'     the OCAP and CARE principles and the source tables.}
#'   \item{Courts and corrections}{[stkflow()],
#'     [caseflow()], [clrdcmp()],
#'     [dispmix()], [lifetbl()],
#'     [crmdens()], [knoxtst()],
#'     [rgnmapintg()], and the SIU report readers
#'     [siuprs()] and [siuso()] on pasted text.}
#'   \item{Air pollution}{[plmfld()] and
#'     [gplume()] for a Gaussian plume,
#'     [crfpm25()], [crfno2()],
#'     [polbrdn()] and [vrfpol()].}
#'   \item{Hawkes}{[chwkfit()] with
#'     [plothwk()] (intensity, time-rescaling QQ, branching tree)
#'     and [chwksim()].}
#'   \item{Proof ledger}{a ledger ([ldgrread()]) from a file, a
#'     capsule or an installed package, its theorems with their status and covered
#'     functions, and [ldgrchk()].}
#'   \item{Report}{the results added from the tabs, as one self-contained HTML page
#'     (plots as inline SVG, year-over-year tables as [yoyhtml()]
#'     draws them), as Markdown, or as a GitHub comment to copy.}
#'   \item{Settings}{light, dark or the system's theme, digits, and the seed of the
#'     seeded analyses.}
#' }
#' The data key of data.rmorie.com is never held by the app:
#' [dload()] reads it from where `rmbl login` stored it.
#'
#' The dashboard needs the shiny package (Suggests); without it `rmblapp()`
#' refuses.
#' @param data A data frame, or the path of a CSV file, to start with; `NULL`
#'   for none.
#' @param capsule The directory of a capsule whose pinned data to start with;
#'   `NULL` for none.
#' @param ... Options passed to [shiny::shinyApp()], such
#'   as `port` and `launch.browser`.
#' @return A shiny app object; printing it (or
#'   [shiny::runApp()]) starts it.
#' @seealso `rmbl app` on the command line ([blcli()]).
#' @examplesIf interactive()
#' rmblapp(indiex("health"))
#' @export
rmblapp <- function(data = NULL, capsule = NULL, ...) {
  .bl_app_need()
  init <- .bl_app_init(data, capsule, deparse(substitute(data))[1L])
  shiny::shinyApp(ui = .bl_app_ui(), server = .bl_app_server(init), options = list(...))
}

#' Refuses when shiny is not installed.
#' @return TRUE, invisibly.
#' @noRd
.bl_app_need <- function() {
  if (!requireNamespace("shiny", quietly = TRUE)) {
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
#' @return Its value, or a list of class bl_app_error with msg and why.
#' @noRd
.bl_app_try <- function(expr) {
  tryCatch(expr, error = function(e) {
    structure(list(msg = conditionMessage(e), why = .bl_app_why(e)), class = "bl_app_error")
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

#' The refusal panel of a failed run.
#' @param r A bl_app_error.
#' @return A tag.
#' @noRd
.bl_app_err_ui <- function(r) {
  shiny::tags$div(class = "bl-err", role = "alert",
                  shiny::tags$p(shiny::tags$strong("Refused: "), r$msg),
                  if (nzchar(r$why)) shiny::tags$p(class = "bl-why", r$why))
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

#' The page's style: the yoyhtml() tokens and typography, light and dark.
#' @return CSS text.
#' @noRd
.bl_app_css <- function() {
  paste0(
    ":root{--ink:#1a1a1a;--dim:#5c5c5c;--rule:#e0ddd8;--ground:#faf9f7;--panel:#ffffff;--bad:#c2492f;",
    "--good:#1b7f6b;--accent:#0072B2}",
    "@media (prefers-color-scheme:dark){:root:not([data-theme=light]){--ink:#eceae6;--dim:#a6a29b;",
    "--rule:#332f2b;--ground:#171513;--panel:#201d1a}}",
    ":root[data-theme=dark]{--ink:#eceae6;--dim:#a6a29b;--rule:#332f2b;--ground:#171513;--panel:#201d1a}",
    "body{background:var(--ground);color:var(--ink);font:14px/1.5 ui-sans-serif,-apple-system,'Segoe UI',",
    "Roboto,'Helvetica Neue',Arial,sans-serif}",
    ".well,.tab-content{background:var(--panel);border-color:var(--rule);color:var(--ink)}",
    ".nav-tabs>li>a{color:var(--dim)}.nav-tabs>li.active>a{color:var(--ink);background:var(--panel)}",
    "h1{font-size:1.5rem;margin:.8rem 0 .2rem}h2,h3{font-size:.85rem;text-transform:uppercase;",
    "letter-spacing:.08em;color:var(--dim);font-weight:600;margin:1.2rem 0 .5rem}",
    "pre{background:var(--ground);color:var(--ink);border:1px solid var(--rule)}",
    "table{border-collapse:collapse}th{font-size:.72rem;text-transform:uppercase;letter-spacing:.06em;",
    "color:var(--dim)}td,th{padding:.3rem .5rem;border-bottom:1px solid var(--rule)}",
    ".bl-err{border-left:4px solid var(--bad);padding:.5rem .9rem;margin:.6rem 0;background:var(--panel)}",
    ".bl-why{color:var(--dim)}.bl-about{color:var(--dim);margin:.5rem 0 1rem;max-width:60rem}",
    ".bl-chip{display:inline-block;padding:0 .45rem;border-radius:.6rem;font-size:.75rem;font-weight:600}",
    ".bl-ok{background:#e6f4f1;color:var(--good)}.bl-bad{background:#fbeae6;color:var(--bad)}",
    ".bl-warn{background:#fdf3d8;color:#8a6100}",
    "a:focus,button:focus,input:focus,select:focus,textarea:focus{outline:2px solid var(--accent);",
    "outline-offset:2px}"
  )
}

#' The page's script: the theme switch and the copy button.
#' @return JavaScript text.
#' @noRd
.bl_app_js <- function() {
  paste0(
    "$(document).on('shiny:connected',function(){",
    "Shiny.addCustomMessageHandler('bltheme',function(t){var r=document.documentElement;",
    "if(t==='auto'){r.removeAttribute('data-theme')}else{r.setAttribute('data-theme',t)}});});",
    "$(document).on('click','.bl-copy',function(){var el=document.getElementById($(this).data('target'));",
    "if(el&&navigator.clipboard){navigator.clipboard.writeText(el.textContent)}});"
  )
}

#' The page.
#' @return A shiny UI.
#' @noRd
.bl_app_ui <- function() {
  t <- shiny::tags
  specs <- .bl_app_specs()
  tabs <- lapply(specs, function(s) shiny::tabPanel(s$title, value = s$id, .bl_tab_ui(s$id, s)))
  tabs <- c(tabs[1:6], list(shiny::tabPanel("Drift", value = "drift", .bl_drift_ui("drift")),
                            shiny::tabPanel("Capsule", value = "capsule", .bl_cps_ui("capsule"))),
            tabs[-(1:6)],
            list(shiny::tabPanel("Proof ledger", value = "ledger", .bl_ldgr_ui("ledger")),
                 shiny::tabPanel("Report", value = "report", .bl_rpt_ui("report")),
                 shiny::tabPanel("Settings", value = "settings", .bl_set_ui("settings"))))
  shiny::fluidPage(
    title = "rmoriebricklayer dashboard", lang = "en",
    t$head(t$style(shiny::HTML(.bl_app_css())), t$script(shiny::HTML(.bl_app_js()))),
    t$header(t$h1("rmoriebricklayer dashboard"),
             t$p(class = "bl-about", "Every analysis runs on this machine and shows the R call it ran.")),
    shiny::sidebarLayout(
      shiny::sidebarPanel(.bl_data_ui("data"), width = 3),
      shiny::mainPanel(do.call(shiny::tabsetPanel, c(list(id = "tabs"), tabs)), width = 9)
    )
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
    for (s in .bl_app_specs()) .bl_tab_server(s$id, s, dat, rpt, set)
    .bl_drift_server(input, output, session)
    .bl_cps_server("capsule", dat, rpt)
    .bl_ldgr_server("ledger", dat, rpt)
    .bl_rpt_server("report", rpt)
  }
}

# ---- data source --------------------------------------------------------------------------------

#' The data source panel.
#' @param id The module id.
#' @return A tag list.
#' @noRd
.bl_data_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::tags$h2("Data"),
    shiny::radioButtons(ns("src"), "Source", c("CSV file" = "csv", "Capsule directory" = "capsule",
                                               "data.rmorie.com table" = "hub")),
    shiny::conditionalPanel("input.src == 'csv'", ns = ns,
                            shiny::fileInput(ns("csv"), "CSV file (plain or gzip)", accept = c(".csv", ".gz"))),
    shiny::conditionalPanel("input.src == 'capsule'", ns = ns,
                            shiny::textInput(ns("cpsdir"), "Capsule directory"),
                            shiny::actionButton(ns("cpsload"), "Load the pinned data")),
    shiny::conditionalPanel("input.src == 'hub'", ns = ns,
                            shiny::uiOutput(ns("signin")),
                            shiny::actionButton(ns("hublist"), "List the tables"),
                            shiny::selectInput(ns("hubkey"), "Table", NULL),
                            shiny::actionButton(ns("hubload"), "Load the table")),
    shiny::uiOutput(ns("status")),
    shiny::tags$h3("Columns"),
    shiny::tableOutput(ns("cols"))
  )
}

#' The data source server.
#' @param id The module id.
#' @param init The data to start with.
#' @return A reactive value holding list(data, code, label, capsule).
#' @noRd
.bl_data_server <- function(id, init) {
  shiny::moduleServer(id, function(input, output, session) {
    cur <- shiny::reactiveVal(init)
    msg <- shiny::reactiveVal(NULL)
    take <- function(r) {
      if (inherits(r, "bl_app_error")) {
        msg(r)
      } else {
        cur(r)
        msg(NULL)
      }
    }
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
      shiny::tags$p(shiny::tags$strong(d$label),
                    if (is.data.frame(d$data)) sprintf(": %s rows, %d columns", format(nrow(d$data), big.mark = ","),
                                                       ncol(d$data)))
    })
    output$cols <- shiny::renderTable(.bl_app_types(cur()$data))
    cur
  })
}

# ---- one analysis tab ---------------------------------------------------------------------------

#' The form, call and outputs of one tab.
#' @param id The module id.
#' @param s The tab's spec.
#' @return A tag list.
#' @noRd
.bl_tab_ui <- function(id, s) {
  ns <- shiny::NS(id)
  fns <- vapply(s$fns, `[[`, "", "label")
  shiny::tagList(
    shiny::tags$div(class = "bl-about", s$about),
    shiny::selectInput(ns("source"), "Data", c("The data loaded at the left" = "", s$sources)),
    shiny::selectInput(ns("fn"), "Analysis", stats::setNames(names(s$fns), fns)),
    shiny::uiOutput(ns("form")),
    shiny::actionButton(ns("run"), "Run", class = "btn-primary"),
    shiny::actionButton(ns("add"), "Add to report"),
    shiny::downloadButton(ns("dl"), "Download the result"),
    shiny::tags$h3("R call"),
    shiny::verbatimTextOutput(ns("code")),
    shiny::uiOutput(ns("err")),
    shiny::plotOutput(ns("plot"), height = "460px"),
    shiny::tags$h3("Result"),
    shiny::verbatimTextOutput(ns("print"))
  )
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
  pick <- function(def) if (!is.null(def) && all(def %in% cols)) def else ""
  switch(a$type,
    col = , vec = , date = shiny::selectInput(id, lab, c("", cols), selected = pick(a$default)),
    cols = , mat = , frame = shiny::selectInput(id, lab, cols, multiple = TRUE,
                                                selected = if (all(a$default %in% cols)) a$default),
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

#' Runs one analysis: the filter, each step, then the plot (to a null device).
#' @param f The analysis spec.
#' @param s The tab spec.
#' @param d The tab's data, from .bl_tab_data().
#' @param input The inputs.
#' @param set The settings.
#' @return A list: value, code, env, plot (a call or NULL) and title.
#' @noRd
.bl_tab_run <- function(f, s, d, input, set) {
  if (isTRUE(f$needs_data %||% TRUE) && !is.data.frame(d$data)) {
    stop("load data at the left, or choose an example in Data, first", call. = FALSE)
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
  list(value = value, code = code, env = env, plot = pl, title = f$label)
}

#' The form and outputs of one tab.
#' @param id The module id.
#' @param s The tab spec.
#' @param dat The data loaded at the left.
#' @param rpt The report's entries.
#' @param set The settings.
#' @return NULL, invisibly.
#' @noRd
.bl_tab_server <- function(id, s, dat, rpt, set) {
  shiny::moduleServer(id, function(input, output, session) {
    res <- shiny::reactiveVal(NULL)
    tabdata <- shiny::reactive(.bl_app_try(.bl_tab_data(input$source, dat())))
    output$form <- shiny::renderUI({
      f <- s$fns[[input$fn %||% names(s$fns)[1L]]]
      d <- tabdata()
      cols <- if (is.data.frame(d$data)) names(d$data) else character()
      args <- list()
      for (st in c(f$steps, if (!is.null(f$plot)) list(f$plot))) {
        for (nm in names(st$args)) args[[.bl_arg_id(nm, st$args[[nm]])]] <- st$args[[nm]]
      }
      flt <- lapply(intersect(s$filters, cols), function(fc) {
        shiny::selectInput(session$ns(paste0("f_", make.names(fc))), sprintf("Rows where %s is", fc),
                           sort(unique(as.character(d$data[[fc]]))), multiple = TRUE)
      })
      shiny::tagList(if (!is.null(f$about)) shiny::tags$p(class = "bl-about", f$about), flt,
                     lapply(names(args), function(nm) .bl_arg_ui(session$ns, nm, args[[nm]], cols)))
    })
    shiny::observeEvent(input$run, {
      d <- tabdata()
      res(if (inherits(d, "bl_app_error")) d else .bl_app_try(.bl_tab_run(s$fns[[input$fn]], s, d, input, set())))
    })
    ok <- function() {
      r <- res()
      !is.null(r) && !inherits(r, "bl_app_error")
    }
    output$code <- shiny::renderText(if (ok()) paste(res()$code, collapse = "\n") else "")
    output$err <- shiny::renderUI(if (inherits(res(), "bl_app_error")) .bl_app_err_ui(res()))
    output$plot <- shiny::renderPlot({
      shiny::req(ok(), res()$plot)
      eval(res()$plot, res()$env)
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
    shiny::observeEvent(input$add, if (ok()) rpt(c(rpt(), list(.bl_rpt_entry(res())))))
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
