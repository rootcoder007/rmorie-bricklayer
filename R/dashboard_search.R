# SPDX-License-Identifier: AGPL-3.0-or-later The dashboard's "Search and rescue"
# tab: the search theory family of R/search.R behind a form, with the POD and
# POS numbers, the four plots and the R call that reproduces them.

#' The search and rescue panel.
#' @param id The search module's id, for its input namespace.
#' @return A tag list.
#' @noRd
.bl_srch_ui <- function(id) {
  ns <- shiny::NS(id)
  figs <- srchfig()
  shiny::tagList(
    shiny::tags$div(
      class = "bl-about",
      paste(
        "Koopman's search theory: how likely a search is to detect the",
        "object, where the object may be, and",
        "where a fixed effort does the most good (ltrlrng(), srchpod(),",
        "pswppod(), datumpmap(), opteffort(),",
        "optcrcsrch())."
      )
    ),
    .bl_srch_inputs(ns),
    .bl_srch_outputs(ns, figs)
  )
}

#' The search and rescue panel's inputs.
#' @param ns The search module's namespace function, for its inputs.
#' @return A fluid row of three input columns.
#' @noRd
.bl_srch_inputs <- function(ns) {
  num <- function(name, label, value, min = 0, step = 0.1) {
    shiny::numericInput(ns(name), label, value, min = min, step = step)
  }
  col <- function(...) shiny::column(4, ...)
  shiny::fluidRow(
    col(
      shiny::selectInput(
        ns("model"),
        "Lateral range model",
        c(
          "Inverse cube" = "invcube",
          "Definite range" = "definite",
          "M-Beta" = "mbeta"
        )
      ),
      num("m", "M-Beta detection probability", 0.8, step = 0.05),
      num("W", "Sweep width W", 1),
      num("effort", "Effort (track length)", 30, step = 1)
    ),
    col(
      num("coverage", "Coverage", 1),
      shiny::selectInput(
        ns("podmodel"),
        "POD model for the coverage",
        c(
          "Random search" = "random",
          "Definite range" = "definite",
          "Inverse cube" = "invcube"
        )
      ),
      num("S", "Track spacing S", 1.3),
      num("navsd", "Navigation error (standard deviation)", 0)
    ),
    col(
      shiny::selectInput(
        ns("datum"),
        "Datum",
        c("Point" = "point", "Line" = "line", "Area" = "area")
      ),
      num("sigma", "Datum sigma", 2),
      num("endx", "Line end or area corner, x", 4, min = NA),
      num("endy", "Line end or area corner, y", 2, min = NA)
    )
  )
}

#' The search and rescue panel's outputs.
#' @param ns The search module's namespace function, for its outputs.
#' @param figs The figure table from srchfig().
#' @return A tag list.
#' @noRd
.bl_srch_outputs <- function(ns, figs) {
  shiny::tagList(
    shiny::actionButton(ns("add"), "Add to report"),
    shiny::uiOutput(ns("err")),
    shiny::tags$h3("Probability of detection and of success"),
    shiny::tableOutput(ns("numbers")),
    shiny::fluidRow(
      shiny::column(6, shiny::plotOutput(ns("lrplot"))),
      shiny::column(6, shiny::plotOutput(ns("podplot")))
    ),
    shiny::fluidRow(
      shiny::column(6, shiny::plotOutput(ns("mapplot"))),
      shiny::column(6, shiny::plotOutput(ns("effplot")))
    ),
    shiny::tags$h3("R call"),
    shiny::verbatimTextOutput(ns("code")),
    shiny::tags$h3("The figures of The Theory of Search (Frost 1996)"),
    shiny::selectInput(
      ns("fig"),
      "Figure",
      stats::setNames(
        figs$fig,
        sprintf("%s. %s (%s)", figs$fig, figs$caption, figs$how)
      )
    ),
    shiny::plotOutput(ns("figplot"), height = "460px"),
    shiny::verbatimTextOutput(ns("figcode"))
  )
}

#' The R calls behind the panel, from its inputs.
#' @param i A list of the panel's inputs.
#' @return A named list of calls, evaluated in order (`map` before `alloc`).
#' @noRd
.bl_srch_calls <- function(i) {
  end <- if (i$datum == "point") NULL else c(i$endx, i$endy)
  pts <- c(0, end)
  lim <- signif(c(min(pts) - 3 * i$sigma, max(pts) + 3 * i$sigma), 3)
  m <- if (i$model == "mbeta") i$m else 1
  list(
    lr = bquote(
      lr <- ltrlrng(
        seq(-.(2 * i$W), .(2 * i$W), length.out = 41),
        W = .(i$W),
        model = .(i$model),
        m = .(m)
      )
    ),
    pod = bquote(pod <- srchpod(.(i$coverage), model = .(i$podmodel))),
    sweep = bquote(
      sweep <- pswppod(
        W = .(i$W),
        S = .(i$S),
        model = .(i$model),
        m = .(m),
        navsd = .(i$navsd),
        npts = 401
      )
    ),
    map = bquote(
      map <- datumpmap(
        seq(.(lim[1]), .(lim[2]), length.out = 25),
        seq(.(lim[1]), .(lim[2]), length.out = 25),
        datum = .(i$datum),
        center = c(0, 0),
        sigma = .(i$sigma),
        end = .(end)
      )
    ),
    alloc = bquote(alloc <- opteffort(map, W = .(i$W), effort = .(i$effort))),
    circle = bquote(
      circle <- optcrcsrch(sigma = .(i$sigma), W = .(i$W), effort = .(i$effort))
    )
  )
}

#' The POD and POS numbers of a run.
#' @param r The run's results.
#' @param i The panel's inputs.
#' @return A data frame.
#' @noRd
.bl_srch_numbers <- function(r, i) {
  data.frame(
    quantity = c(
      sprintf(
        "POD at coverage %s (%s)",
        format(i$coverage),
        .sr_model_name(i$podmodel)
      ),
      sprintf("Parallel sweep POD, S = %s", format(i$S)),
      "POS of the optimal allocation over the map",
      "POS of Koopman's optimal circular search",
      "Probability outside the map"
    ),
    value = c(
      as.numeric(r$pod),
      r$sweep,
      r$alloc$pos,
      r$circle$pos,
      r$map$outside
    )
  )
}

#' The search and rescue server.
#' @param id The search module's id, as given to .bl_srch_ui().
#' @param rpt The reactive report entries; a search is added to them.
#' @return The reactive run (results, calls and the environment they ran in),
#'   invisibly.
#' @noRd
.bl_srch_server <- function(id, rpt) {
  shiny::moduleServer(id, function(input, output, session) {
    res <- .bl_srch_res(input)
    ok <- function() {
      r <- res()
      shiny::req(!inherits(r, "bl_app_error"))
      r
    }
    code <- shiny::reactive({
      c(
        "library(rmoriebricklayer)",
        vapply(
          ok()$calls,
          function(cl) deparse1(cl, collapse = "\n", width.cutoff = 80L),
          ""
        )
      )
    })
    .bl_srch_render(input, output, res, ok, code)
    shiny::observeEvent(input$add, {
      r <- ok()
      rpt(c(
        rpt(),
        list(.bl_rpt_entry(list(
          title = "Search and rescue",
          code = code(),
          value = r$numbers,
          plot = quote(plot(alloc)),
          env = r$env
        )))
      ))
    })
    invisible(res)
  })
}

#' The search and rescue panel's run, as a reactive.
#' @param input The module's inputs.
#' @return A reactive giving the results, calls, environment and numbers, or
#'   the app's error object.
#' @noRd
.bl_srch_res <- function(input) {
  keys <- c(
    "model",
    "m",
    "W",
    "coverage",
    "podmodel",
    "S",
    "navsd",
    "datum",
    "sigma",
    "endx",
    "endy",
    "effort"
  )
  shiny::reactive({
    i <- stats::setNames(lapply(keys, function(k) input[[k]]), keys)
    .bl_app_try({
      calls <- .bl_srch_calls(i)
      env <- new.env(parent = environment(.bl_srch_server))
      for (cl in calls) {
        eval(cl, env)
      }
      r <- mget(names(calls), envir = env)
      list(r = r, calls = calls, env = env, numbers = .bl_srch_numbers(r, i))
    })
  })
}

#' Fills the search and rescue panel's outputs.
#' @param input,output The module's inputs and outputs.
#' @param res The panel's run, a reactive.
#' @param ok A function giving the run once it has no error.
#' @param code The reactive R call text.
#' @return NULL, invisibly.
#' @noRd
.bl_srch_render <- function(input, output, res, ok, code) {
  output$err <- shiny::renderUI(
    if (inherits(res(), "bl_app_error")) .bl_app_err_ui(res())
  )
  output$numbers <- shiny::renderTable(ok()$numbers, digits = 4)
  output$lrplot <- shiny::renderPlot(plot(ok()$r$lr))
  output$podplot <- shiny::renderPlot(plot(ok()$r$pod))
  output$mapplot <- shiny::renderPlot(plot(ok()$r$map))
  output$effplot <- shiny::renderPlot(plot(ok()$r$alloc))
  output$code <- shiny::renderText(paste(code(), collapse = "\n"))
  output$figplot <- shiny::renderPlot({
    shiny::req(input$fig)
    srchfig(input$fig)
  })
  output$figcode <- shiny::renderText({
    shiny::req(input$fig)
    sprintf("library(rmoriebricklayer)\nsrchfig(%s)", deparse(input$fig))
  })
  invisible(NULL)
}
