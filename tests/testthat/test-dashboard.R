# The dashboard: the page and every panel build, each analysis of each tab runs
# through its module server (as an ExtendedTask) on its demo data and shows the
# call it ran, its value boxes, method, diagnostics, table and plots, and the
# data, report, capsule and ledger panels do what their buttons say. No server
# is started. ponytail: the whole file skips on CRAN (38 s there, shiny is a
# Suggests); every CI leg still runs it.
skip_on_cran()

ns <- asNamespace("rmoriebricklayer")
specs <- function() ns$.bl_app_specs()
spec <- function(id) Filter(function(s) s$id == id, specs())[[1L]]
setting <- function() shiny::reactive(list(digits = 4L, seed = 1L))
nodata <- list(data = NULL, code = character(), label = "none", capsule = NULL)
html <- function(x) {
  if (is.character(x)) {
    paste(x, collapse = "")
  } else {
    paste(as.character(x$html), collapse = "")
  }
}

# lets the task's promise settle: the background run's poll and the result's
# callbacks
settle <- function(session, task, res, n = 600L) {
  for (i in seq_len(n)) {
    later::run_now(0.02)
    session$flushReact()
    if (
      !identical(shiny::isolate(task$status()), "running") &&
        !is.null(shiny::isolate(res()))
    ) {
      break
    }
  }
}

# runs one analysis of a tab through its module server and returns what the page
# shows
run_tab <- function(
  id,
  fn,
  source = NULL,
  inputs = list(),
  dat = nodata,
  mode = "light",
  extra = NULL
) {
  s <- spec(id)
  src <- if (is.null(source)) unname(s$sources[[1L]]) else source
  rec <- new.env()
  rec$got <- NULL
  shiny::testServer(
    ns$.bl_tab_server,
    args = list(
      id = id,
      s = s,
      dat = shiny::reactiveVal(dat),
      rpt = shiny::reactiveVal(list()),
      set = setting(),
      active = shiny::reactive(""),
      mode = shiny::reactive(mode)
    ),
    {
      do.call(session$setInputs, c(list(source = src, fn = fn), inputs))
      session$setInputs(run = 1)
      settle(session, task, res)
      r <- res()
      out <- function(o) {
        tryCatch(output[[o]], error = function(e) {
          paste("output error:", conditionMessage(e))
        })
      }
      rec$got <- list(res = r, code = output$code, err = html(output$err))
      if (!inherits(r, "bl_app_error")) {
        rec$got$print <- output$print
        rec$got$vbox <- html(output$vbox)
        rec$got$method <- html(output$method)
        rec$got$table <- html(output$table)
        rec$got$diag <- html(output$diag)
        rec$got$plot <- out("plot")
        ch <- ns$.bl_diag_choices(r)
        rec$got$diags <- lapply(ch, function(w) {
          session$setInputs(diagwhich = w)
          out("diagplot")
        })
        rec$got$diagsel <- html(out("diagsel"))
        rec$got$dl <- file.exists(output$dl)
        rec$got$png <- file.exists(output$png)
        rec$got$csv <- file.exists(output$csv)
        if (ns$.bl_have_cairo()) {
          rec$got$svg <- file.exists(output$svg)
        }
        rec$got$hover <- html(out("hoverinfo"))
      }
      if (is.function(extra)) {
        extra(session, output, input)
      }
      session$setInputs(add = 1)
      rec$got$rpt <- rpt()
    }
  )
  rec$got
}

expect_ran <- function(g, fn) {
  if (inherits(g$res, "bl_app_error")) {
    fail(paste(fn, "refused:", g$res$msg))
  }
  expect_false(inherits(g$res, "bl_app_error"))
  expect_true(any(grepl(paste0(fn, "("), g$code, fixed = TRUE)), info = g$code)
  expect_true(nzchar(g$print))
  expect_length(g$rpt, 1L)
  expect_match(g$vbox, "Verdict", fixed = TRUE)
  expect_match(g$method, "What the numbers mean", fixed = TRUE)
  for (p in c(list(g$plot), g$diags)) {
    expect_false(is.character(p) && startsWith(p, "output error"), info = p)
  }
}

test_that("the page and every panel build", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  html <- as.character(ns$.bl_app_ui())
  for (t in c(
    "Describe",
    "Year over year",
    "Rates",
    "Trends",
    "Survey",
    "Distributions",
    "Drift",
    "Capsule",
    "Policy",
    "Courts and corrections",
    "Air pollution",
    "Hawkes",
    "Proof ledger",
    "Report",
    "Settings",
    "Over time",
    "Causal and survey",
    "Capsules",
    "Domains",
    "Share this view",
    "Load all demos"
  )) {
    expect_match(html, t, fixed = TRUE)
  }
  expect_match(html, "bslib-value-box|bslib-sidebar-layout")
  for (s in specs()) {
    expect_s3_class(ns$.bl_tab_ui(s$id, s), "shiny.tag")
  }
  app <- rmblapp()
  expect_s3_class(app, "shiny.appobj")
  expect_identical(app$appOptions$bookmarkStore, "url")
  expect_s3_class(rmblapp(data.frame(a = 1:3)), "shiny.appobj")
  d <- data.frame(a = 1:3)
  init <- ns$.bl_app_init(d, NULL, "d")
  expect_identical(init$code, "data <- d")
  expect_identical(ns$.bl_app_init(d, NULL, "data")$code, character())
  expect_null(ns$.bl_app_init(NULL, NULL)$data)
  expect_error(
    rmblapp(data = 3),
    "rmblapp: `data` must be a data frame or the path of a CSV file"
  )
  expect_match(
    as.character(ns$.bl_drift_ui("drift")),
    "Reference CSV",
    fixed = TRUE
  )
  # every tab opens on a demo dataset
  for (s in specs()) {
    expect_match(s$sources[[1L]], "rmbldemo(", fixed = TRUE)
  }
  # a column argument takes the first of its defaults the data has
  f <- spec("policy")$fns$plndid
  expect_identical(
    ns$.bl_form_defaults(f, c("district", "month", "crmrate"))$a_unit,
    "district"
  )
  expect_identical(
    ns$.bl_form_defaults(f, names(rmbldemo("court")))$a_unit,
    "court"
  )
  expect_identical(ns$.bl_form_defaults(f)$a_unit, "court")
  expect_identical(ns$.bl_form_defaults(f, "x")$a_y, "")
})

test_that("rmblapp() refuses without shiny, in its own words", {
  testthat::local_mocked_bindings(
    requireNamespace = function(...) FALSE,
    .package = "base"
  )
  expect_error(rmblapp(), "rmblapp: the dashboard needs the shiny package")
})

test_that(
  paste0(
    "a CSV file is read with the package's reader and the call to read it ",
    "is shown"
  ),
  {
    skip_if_not_installed("shiny")
    f <- tempfile(fileext = ".csv")
    utils::write.csv(
      data.frame(
        year = 2020:2022,
        n = c(5L, 7L, 9L),
        area = c("a", "b", "c"),
        stringsAsFactors = FALSE
      ),
      f,
      row.names = FALSE
    )
    r <- ns$.bl_app_read(f, "counts.csv")
    expect_identical(r$data, utils::read.csv(f, stringsAsFactors = FALSE))
    expect_identical(
      r$code,
      "data <- utils::read.csv(\"counts.csv\", stringsAsFactors = FALSE)"
    )
    expect_identical(ns$.bl_app_init(f, NULL)$data, r$data)
    ty <- ns$.bl_app_types(r$data)
    expect_identical(ty$type, c("integer", "integer", "character"))
    expect_null(ns$.bl_app_types(NULL))
    shiny::testServer(
      ns$.bl_data_server,
      args = list(id = "data", init = nodata),
      {
        expect_match(html(output$status), "No dataset chosen")
        expect_match(html(output$colsui), "Choose a dataset")
        session$setInputs(csv = list(datapath = f, name = "counts.csv"))
        expect_identical(cur()$data, r$data)
        expect_match(html(output$status), "3 rows, 3 columns")
        expect_match(output$cols, "integer")
        expect_match(html(output$colsui), "data-cols", fixed = TRUE)
        # a file that is not a table is refused, in the reader's words
        bad <- tempfile(fileext = ".csv")
        writeLines(c("a,b", "1,2,3"), bad)
        session$setInputs(csv = list(datapath = bad, name = "bad.csv"))
        expect_match(html(output$status), "Refused")
        unlink(bad)
      }
    )
    unlink(f)
  }
)

test_that(
  paste0(
    "the data panel loads a demo, all the demos, and picks among the loaded ",
    "datasets"
  ),
  {
    skip_if_not_installed("shiny")
    init <- ns$.bl_app_init(data.frame(a = 1), NULL, "x")
    shiny::testServer(
      ns$.bl_data_server,
      args = list(id = "data", init = init),
      {
        session$setInputs(demo = "court", demoload = 1)
        expect_identical(cur()$code, "data <- rmbldemo(\"court\")")
        expect_identical(cur()$data, rmbldemo("court"))
        expect_setequal(
          names(loaded()),
          c("x (given to rmblapp())", "court (demo)")
        )
        session$setInputs(alldemos = 1)
        expect_length(loaded(), nrow(rmbldemo()) + 1L)
        expect_identical(cur()$label, "ledger (demo)")
        session$setInputs(pick = "survey (demo)")
        expect_identical(cur()$data, rmbldemo("survey"))
        session$setInputs(pick = "no such dataset")
        expect_identical(cur()$label, "survey (demo)")
      }
    )
  }
)

test_that(
  paste0(
    "the data panel loads a capsule's pinned ",
    "data and a data.rmorie.com table"
  ),
  {
    skip_if_not_installed("shiny")
    d <- usecpstmpl(tempfile("capsule-"), ex = TRUE)
    invisible(cpsrfrsh(d))
    local_mocked_bindings(
      dtabs = function(...) {
        data.frame(
          key = "db/t",
          name = "A table",
          rows = 2L,
          stringsAsFactors = FALSE
        )
      },
      dload = function(key, ...) data.frame(x = 1:2),
      .bl_hosted_key = function() NULL
    )
    shiny::testServer(
      ns$.bl_data_server,
      args = list(id = "data", init = nodata),
      {
        session$setInputs(cpsdir = d, cpsload = 1)
        expect_identical(cur()$capsule, normalizePath(d))
        expect_match(cur()$label, "capsule")
        session$setInputs(cpsdir = tempfile(), cpsload = 2)
        expect_match(html(output$status), "not an existing directory")
        expect_match(html(output$signin), "Not signed in")
        session$setInputs(hublist = 1)
        session$setInputs(hubkey = "db/t", hubload = 1)
        expect_identical(cur()$code, "data <- dload(\"db/t\")")
        expect_identical(cur()$data, data.frame(x = 1:2))
      }
    )
    local_mocked_bindings(
      dtabs = function(...) stop("the data service did not answer"),
      .bl_hosted_key = function() "k"
    )
    shiny::testServer(
      ns$.bl_data_server,
      args = list(id = "data", init = nodata),
      {
        expect_match(html(output$signin), "Signed in")
        session$setInputs(hublist = 1)
        expect_match(html(output$status), "the data service did not answer")
      }
    )
    # a capsule with no pinned data yet
    e <- usecpstmpl(tempfile("capsule-"), ex = TRUE)
    expect_error(ns$.bl_app_capsule(e), "pinned data file is missing")
    expect_identical(ns$.bl_app_init(NULL, d)$capsule, normalizePath(d))
  }
)

test_that(
  paste0(
    "every analysis of every tab runs on its demo data and shows the call ",
    "it ran"
  ),
  {
    skip_if_not_installed("shiny")
    skip_if_not_installed("bslib")
    skip_on_cran()
    d14 <- c(f_period = "2019/2022", f_age = "Total, 18 years and over")
    mh <- "Perceived mental health, very good or excellent"
    cases <- list(
      describe = list(
        profcols = list(),
        missgrid = list(),
        cortbl = list(),
        freqtbl = list(),
        mahaoutl = list(source = "datasets::mtcars"),
        plotrdg = list(),
        plotecdf = list(),
        plotvln = list(),
        plothex = list(),
        plotgain = list()
      ),
      yoy = list(yoy = list(a_minbase = 20, a_dir = "lower")),
      rates = list(rtcalc = list(), ratechg = list(), shrs = list(source = 2L)),
      trends = list(
        trndtst = list(),
        stepchg = list(a_nperm = 999),
        cnttrnd = list(),
        plotcal = list(source = 4L),
        plothrz = list(source = 2L),
        plotsm = list(source = 2L),
        plotbump = list(source = 2L)
      ),
      survey = list(svyest = list(), svycmp = list(a_ref = "Central")),
      dist = list(
        dstfit = list(a_nboot = 20, a_which = "qq"),
        synth = list(a_nboot = 0, a_n = 50)
      ),
      policy = list(
        plndid = list(),
        evstudy = list(),
        stgatt = list(a_reps = 19),
        bacondcmp = list(),
        swtdid = list(a_reps = 19),
        perminf = list(a_reps = 49, a_type = "histogram"),
        syndid = list(a_reps = 10, source = 2L),
        mtchdid = list(),
        wcb = list(a_reps = 99, a_cl = "region"),
        loounit = list(),
        cohtrnd = list(),
        plnpwr = list(a_reps = 10, a_eff = "0, 8"),
        baltab = list(),
        tse = list()
      ),
      drift = list(cpsdrft = list()),
      fnmi = list(
        published = list(),
        indgap = c(as.list(d14), list(f_indicator = mh)),
        dstntst = c(
          as.list(d14),
          list(f_indicator = mh, f_group = c("First Nations", "Métis", "Inuit"))
        ),
        ordcmp = list(source = 3L, f_region = "Canada"),
        welprof = list(source = 4L),
        healchg = list(f_age = "Total, 18 years and over", f_indicator = mh),
        mhcont = list(source = 4L),
        stdprev = list(
          source = 5L,
          f_measure = "Seriously contemplated suicide in the past 12 months",
          f_age = c(
            "15 to 24 years",
            "25 to 34 years",
            "35 to 44 years",
            "45 to 54 years",
            "55 years and over"
          )
        ),
        trcprog = list()
      ),
      justice = list(
        caseflow = list(),
        stkflow = list(source = 2L),
        clrdcmp = list(source = 5L, f_year = c("2014", "2022")),
        dispmix = list(
          source = 6L,
          a_cnts = c(
            "withdrawn_stayed_before_trial",
            "guilty_plea_before_trial",
            "following_trial"
          )
        ),
        lifetbl = list(),
        crmdens = list(source = 7L),
        knoxtst = list(source = 7L),
        rgnmapintg = list(source = 3L),
        siuso = list(
          a_text = paste0(
            "Subject Officials\nSO #1 ",
            "Interviewed\nSO #2 Declined interview"
          )
        ),
        siuprs = list(
          a_html = paste(
            readLines(system.file(
              "extdata",
              "siu_synthetic_report.html",
              package = "rmoriebricklayer"
            )),
            collapse = "\n"
          )
        )
      ),
      air = list(
        plmfld = list(),
        monitors = list(),
        profile = list(),
        gplume = list(),
        crfpm25 = list(),
        crfno2 = list(),
        polbrdn = list(),
        vrfpol = list()
      ),
      hawkes = list(
        chwkfit = list(a_what = "tree"),
        chwksim = list(),
        chwkjit = list()
      )
    )
    expect_setequal(names(cases), vapply(specs(), `[[`, "", "id"))
    for (id in names(cases)) {
      s <- spec(id)
      expect_setequal(names(cases[[id]]), names(s$fns))
      for (fn in names(cases[[id]])) {
        inp <- cases[[id]][[fn]]
        src <- inp$source
        if (is.numeric(src)) {
          src <- unname(s$sources[[src]])
        }
        inp$source <- NULL
        g <- run_tab(id, fn, src, inp)
        called <- if (length(s$fns[[fn]]$steps)) {
          s$fns[[fn]]$steps[[length(s$fns[[fn]]$steps)]]$fn
        } else {
          s$fns[[fn]]$plot$fn
        }
        expect_ran(g, sub("^utils::", "", called))
        expect_true(g$dl)
        expect_true(g$png)
        expect_true(g$csv)
      }
    }
  }
)

test_that(
  paste0(
    "the value boxes, the method card and the diagnostics say what the ",
    "numbers are"
  ),
  {
    skip_if_not_installed("shiny")
    skip_if_not_installed("bslib")
    g <- run_tab("policy", "plndid")
    expect_match(g$vbox, ">Estimate<", fixed = TRUE)
    expect_match(g$vbox, "95% confidence", fixed = TRUE)
    expect_match(g$vbox, "Unlikely to be chance", fixed = TRUE)
    expect_match(g$method, "unit and period fixed effects", fixed = TRUE)
    expect_match(g$method, "Parallel trends", fixed = TRUE)
    expect_match(g$method, "?plndid", fixed = TRUE)
    # the demo's reform lowers the delay by 12 days, and the estimate finds it
    expect_lt(abs(g$res$value$estimate + 12), 2)
    b <- run_tab("policy", "baltab")
    expect_match(b$method, "standardised mean difference", fixed = TRUE)
    h <- run_tab("hawkes", "chwkfit")
    expect_match(h$method, "Branching ratio", fixed = TRUE)
    expect_match(h$method, "Time-rescaling KS", fixed = TRUE)
    expect_match(h$diagsel, "Time-rescaling QQ plot", fixed = TRUE)
    ct <- run_tab("trends", "cnttrnd", inputs = list())
    expect_match(ct$method, "Dispersion", fixed = TRUE)
    expect_match(ct$diagsel, "Observed and fitted", fixed = TRUE)
    ds <- run_tab(
      "fnmi",
      "dstntst",
      inputs = list(
        f_period = "2019/2022",
        f_age = "Total, 18 years and over",
        f_indicator = "Daily smoker"
      )
    )
    expect_match(ds$method, "I-squared", fixed = TRUE)
    dm <- run_tab(
      "justice",
      "dispmix",
      source = unname(spec("justice")$sources[[6L]]),
      inputs = list(
        a_cnts = c(
          "withdrawn_stayed_before_trial",
          "guilty_plea_before_trial",
          "following_trial"
        )
      )
    )
    expect_match(dm$method, "Cramer", fixed = TRUE)
    expect_match(dm$diag, "homogeneity", fixed = TRUE)
    cr <- run_tab("describe", "cortbl")
    expect_match(cr$method, "Strongest correlation", fixed = TRUE)
    dr <- run_tab("drift", "cpsdrft")
    expect_match(dr$vbox, "Drift in at least one column", fixed = TRUE)
    expect_match(dr$method, "Largest PSI", fixed = TRUE)
    rr <- run_tab("air", "crfno2")
    expect_match(rr$method, "higher than the reference", fixed = TRUE)
    # a result with no test, and one with no table
    pf <- run_tab("describe", "profcols")
    expect_match(pf$vbox, "Descriptive: no test", fixed = TRUE)
    expect_match(pf$table, "bl-col", fixed = TRUE)
    mg <- run_tab("describe", "missgrid")
    expect_match(mg$table, "<pre>", fixed = TRUE)
    expect_match(mg$diag, "no checks beyond its table", fixed = TRUE)
    # an interval that includes the reference, a fit that did not converge
    expect_match(
      ns$.bl_headline(data.frame(
        estimate = 0.2,
        lower = -1,
        upper = 1
      ))$verdict,
      "includes 0"
    )
    expect_match(
      ns$.bl_headline(list(slope = 2, converged = FALSE))$verdict,
      "did not converge"
    )
    expect_identical(
      ns$.bl_headline(data.frame(estimate = numeric()))$verdict,
      "No rows"
    )
    expect_identical(
      ns$.bl_headline(list(
        overall = data.frame(estimate = 1),
        p_value = 0.01
      ))$p,
      0.01
    )
    expect_match(
      ns$.bl_headline(list(verdict = "worse", estimate = 1))$verdict,
      "worse"
    )
    expect_null(ns$.bl_num(NULL))
    expect_match(ns$.bl_meaning(NULL), "Run the analysis")
    expect_match(
      ns$.bl_meaning(list(est = NULL, p = NULL)),
      "descriptive result"
    )
    expect_match(
      paste(
        ns$.bl_effect_lines(list(smdafter = c(0.02, -0.05))),
        collapse = ""
      ),
      "balanced"
    )
    expect_match(
      paste(
        ns$.bl_effect_lines(list(dispersion = 3, overdispersed = TRUE)),
        collapse = ""
      ),
      "too narrow"
    )
    expect_match(
      paste(ns$.bl_effect_lines(list(kspva = 0.01)), collapse = ""),
      "does not fit"
    )
    expect_match(
      paste(ns$.bl_effect_lines(list(rr = 0.8)), collapse = ""),
      "lower"
    )
    expect_identical(ns$.bl_rd_method("no_such_function_here"), "")
    expect_identical(ns$.bl_cell(list(), 4L), "")
    expect_identical(ns$.bl_cell(c(1, NA), 4L), "1, NA")
    expect_identical(nrow(ns$.bl_main_table(NULL)), 0L)
    expect_identical(nrow(ns$.bl_main_table(list(a = 1, b = "x"))), 2L)
    expect_identical(nrow(ns$.bl_scalars(1:3)), 0L)
    expect_null(ns$.bl_interval_rows(data.frame(
      estimate = 1:50,
      lower = 0,
      upper = 2
    )))
    expect_null(ns$.bl_interval_rows(data.frame(
      estimate = NA_real_,
      lower = 0,
      upper = 2
    )))
    expect_match(
      html(list(html = ns$.bl_table_ui(data.frame()))),
      "has no table"
    )
    expect_match(
      html(list(html = ns$.bl_table_ui(data.frame(a = 1:250)))),
      "first 200 of 250"
    )
  }
)

test_that(
  paste0(
    "plots follow the dark mode, and draw a note where a result has neither ",
    "plot nor interval"
  ),
  {
    skip_if_not_installed("shiny")
    skip_if_not_installed("bslib")
    g <- run_tab(
      "policy",
      "wcb",
      inputs = list(a_reps = 99, a_cl = "region"),
      mode = "dark"
    )
    expect_false(inherits(g$res, "bl_app_error"))
    expect_type(g$plot, "list")
    f <- tempfile(fileext = ".png")
    grDevices::png(f)
    expect_null(ns$.bl_noplot("nothing"))
    expect_null(ns$.bl_col_plot(c(1, 2, 2, 3, NA), "x", "dark"))
    expect_null(ns$.bl_col_plot(c("a", "b", "b"), "y"))
    grDevices::dev.off()
    expect_identical(ns$.bl_col_summary(c(1, 2, NA))$value[[2L]], 1)
    expect_identical(ns$.bl_col_summary(c("a", "b", "b"))$statistic[[4L]], "b")
    # an SVG without cairo is refused, in words
    local_mocked_bindings(.bl_have_cairo = function() FALSE)
    expect_error(
      ns$.bl_save_plot(list(plot = NULL, value = 1), tempfile(), "svg"),
      "no SVG device"
    )
  }
)

test_that(
  paste0(
    "linked views: a column opens its distribution, a period its rows, a ",
    "brushed range its shares"
  ),
  {
    skip_if_not_installed("shiny")
    skip_if_not_installed("bslib")
    rec <- new.env()
    rec$seen <- list()
    run_tab("describe", "profcols", extra = function(session, output, input) {
      session$setInputs(pickcol = "income")
      rec$seen$plot <- output$colplot
      rec$seen$summ <- output$colsumm
      session$setInputs(pickcol = "sex")
      rec$seen$summ2 <- output$colsumm
    })
    expect_type(rec$seen$plot, "list")
    expect_match(rec$seen$summ, "median", fixed = TRUE)
    expect_match(rec$seen$summ2, "Female", fixed = TRUE)
    run_tab("yoy", "yoy", extra = function(session, output, input) {
      rec$seen$none <- html(output$hoverinfo)
      session$setInputs(hover = list(x = 2020.2, y = 0))
      rec$seen$hover <- html(output$hoverinfo)
    })
    expect_match(rec$seen$none, "Point at the plot", fixed = TRUE)
    expect_match(rec$seen$hover, "year 2020", fixed = TRUE)
    expect_match(rec$seen$hover, "Downtown", fixed = TRUE)
    # a plot whose x axis counts the periods 1, 2, ...
    v <- data.frame(
      period = c("a", "b", "c"),
      n = 1:3,
      stringsAsFactors = FALSE
    )
    expect_match(
      html(list(html = ns$.bl_hover_ui(v, "period", list(x = 2.2)))),
      "period b",
      fixed = TRUE
    )
    run_tab("drift", "cpsdrft", extra = function(session, output, input) {
      rec$seen$dcol <- html(output$dcolui)
      session$setInputs(dcol = "income")
      rec$seen$dens <- output$dens
      rec$seen$none2 <- html(output$dshare)
      session$setInputs(dbrush = list(xmin = 40000, xmax = 60000))
      rec$seen$share <- html(output$dshare)
    })
    expect_match(rec$seen$dcol, "income", fixed = TRUE)
    expect_type(rec$seen$dens, "list")
    expect_match(rec$seen$none2, "Drag across", fixed = TRUE)
    expect_match(rec$seen$share, "reference", fixed = TRUE)
    sn <- ns$.bl_snaps(rmbldemo("drift"))
    sh <- ns$.bl_brush_share(sn, "age", -Inf, Inf)
    expect_identical(sh$share, c(100, 100))
    expect_null(ns$.bl_snaps(data.frame(
      snapshot = "a",
      x = 1,
      stringsAsFactors = FALSE
    )))
    expect_null(ns$.bl_snaps(data.frame(x = 1)))
  }
)

test_that(
  paste0(
    "a tab runs its first analysis when first shown, and a dataset chosen ",
    "at the left becomes its data"
  ),
  {
    skip_if_not_installed("shiny")
    skip_if_not_installed("bslib")
    s <- spec("policy")
    act <- shiny::reactiveVal("describe")
    dat <- shiny::reactiveVal(nodata)
    shiny::testServer(
      ns$.bl_tab_server,
      args = list(
        id = "policy",
        s = s,
        dat = dat,
        rpt = shiny::reactiveVal(list()),
        set = setting(),
        active = act
      ),
      {
        session$setInputs(source = unname(s$sources[[1L]]))
        expect_identical(task$status(), "initial")
        act("policy")
        session$flushReact()
        settle(session, task, res)
        expect_match(
          output$code,
          "did <- plndid(data, unit = \"court\"",
          fixed = TRUE
        )
        dat(ns$.bl_app_demo("court"))
        session$flushReact()
        session$setInputs(source = "", run = 1)
        settle(session, task, res)
        expect_match(output$code, "data <- rmbldemo(\"court\")", fixed = TRUE)
      }
    )
  }
)

test_that(
  paste0(
    "long analyses run as an ExtendedTask in the background; a failed run ",
    "is a refusal and a toast"
  ),
  {
    skip_if_not_installed("shiny")
    skip_if_not_installed("bslib")
    skip_on_os("windows")
    # the background run itself: a value, an error, and a process that ended
    # without a result
    wait <- function(p) {
      rec <- new.env()
      rec$out <- NULL
      promises::then(p, function(v) rec$out <- list(ok = v), function(e) {
        rec$out <- list(err = conditionMessage(e))
      })
      for (i in 1:300) {
        later::run_now(0.02)
        if (!is.null(rec$out)) break
      }
      rec$out
    }
    expect_identical(wait(ns$.bl_bg(function() 6 * 7, TRUE))$ok, 42)
    expect_match(
      wait(ns$.bl_bg(function() stop("no luck"), TRUE))$err,
      "no luck"
    )
    expect_identical(ns$.bl_bg(function() 1, FALSE), 1)
    local_mocked_bindings(
      mccollect = function(...) list(NULL),
      .package = "parallel"
    )
    expect_match(
      wait(ns$.bl_bg(function() 1, TRUE))$err,
      "ended without a result"
    )
  }
)

test_that(
  paste0(
    "the task path through a mocked long task: running, then the result; a ",
    "rejection is a refusal"
  ),
  {
    skip_if_not_installed("shiny")
    skip_if_not_installed("bslib")
    slow <- function(fn, long = FALSE) {
      promises::promise(function(resolve, reject) {
        later::later(function() resolve(fn()), 0.05)
      })
    }
    local_mocked_bindings(.bl_bg = slow)
    s <- spec("hawkes")
    shiny::testServer(
      ns$.bl_tab_server,
      args = list(
        id = "hawkes",
        s = s,
        dat = shiny::reactiveVal(nodata),
        rpt = shiny::reactiveVal(list()),
        set = setting(),
        active = shiny::reactive("")
      ),
      {
        session$setInputs(
          source = unname(s$sources[[1L]]),
          fn = "chwkfit",
          run = 1
        )
        expect_identical(task$status(), "running")
        expect_null(res())
        settle(session, task, res)
        expect_identical(task$status(), "success")
        expect_match(output$code, "chwkfit(", fixed = TRUE)
      }
    )
    local_mocked_bindings(.bl_bg = function(fn, long = FALSE) {
      promises::promise_reject(simpleError("the fork died"))
    })
    # shiny reports a rejected ExtendedTask with a warning of its own; the
    # refusal is what is tested
    expect_warning(
      shiny::testServer(
        ns$.bl_tab_server,
        args = list(
          id = "hawkes",
          s = s,
          dat = shiny::reactiveVal(nodata),
          rpt = shiny::reactiveVal(list()),
          set = setting(),
          active = shiny::reactive("")
        ),
        {
          session$setInputs(
            source = unname(s$sources[[1L]]),
            fn = "chwkfit",
            run = 1
          )
          settle(session, task, res)
          expect_identical(task$status(), "error")
          expect_match(html(output$err), "the fork died")
        }
      ),
      "the fork died"
    )
  }
)

test_that(
  paste0(
    "bookmarking: the URL of a view restores its tab, data, analysis and ",
    "form, and reruns it"
  ),
  {
    skip_if_not_installed("shiny")
    skip_if_not_installed("bslib")
    skip_on_cran()
    # the encoding side: the inputs the page bookmarks, as shiny writes them
    # into the URL
    q <- paste0(
      "?_inputs_&tabs=%22policy%22&policy-fn=%22evstudy%22&policy-source=",
      utils::URLencode(
        deparse(unname(spec("policy")$sources[[2L]])),
        reserved = TRUE
      ),
      "&policy-a_leads=2&policy-run=3"
    )
    rc <- asNamespace("shiny")$RestoreContext$new(q)
    page <- asNamespace("shiny")$withRestoreContext(
      rc,
      as.character(ns$.bl_app_ui())
    )
    expect_match(page, "<option value=\"evstudy\" selected>", fixed = TRUE)
    expect_match(page, "data-value=\"policy\"", fixed = TRUE)
    # the server side: the restored form is rerun on the restored data
    s <- spec("policy")
    shiny::testServer(
      ns$.bl_tab_server,
      args = list(
        id = "policy",
        s = s,
        dat = shiny::reactiveVal(nodata),
        rpt = shiny::reactiveVal(list()),
        set = setting(),
        active = shiny::reactive("")
      ),
      {
        restored(list(fn = "evstudy", a_leads = 2))
        session$setInputs(source = unname(s$sources[[2L]]), run = 1)
        settle(session, task, res)
        expect_match(output$code, "leads = 2", fixed = TRUE)
        expect_match(output$code, "C03", fixed = TRUE)
      }
    )
    # the buttons are not bookmarked, so a restored link does not press them
    shiny::testServer(ns$.bl_app_server(nodata), {
      expect_true(all(
        c("policy-run", "policy-add", "data-alldemos") %in%
          session$getBookmarkExclude()
      ))
    })
  }
)

test_that("a tab shows the exact call, the refusal and its explanation", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  src <- unname(spec("yoy")$sources[[2L]])
  g <- run_tab(
    "yoy",
    "yoy",
    source = src,
    inputs = list(a_by = "area", a_minbase = 20)
  )
  expect_identical(
    strsplit(g$code, "\n", fixed = TRUE)[[1L]][2L],
    paste(
      "y <- yoy(data, value = \"n\", prd = \"year\", by = \"area\", lag = 1,",
      "units = \"count\",",
      "minbase = 20, dir = \"neutral\")"
    )
  )
  expect_match(g$code, "plot(y)", fixed = TRUE)
  expect_match(g$code, "plot(y, what = \"value\")", fixed = TRUE)
  expect_s3_class(g$rpt[[1L]]$yoy, "rmbl_yoy")
  # the same call in a script gives the same table
  data <- eval(str2lang(src))
  y <- yoy(
    data,
    value = "n",
    prd = "year",
    by = "area",
    lag = 1,
    units = "count",
    minbase = 20,
    dir = "neutral"
  )
  expect_identical(as.data.frame(g$res$value), as.data.frame(y))
  bad <- run_tab("yoy", "yoy", inputs = list(a_value = "nope"))
  expect_s3_class(bad$res, "bl_app_error")
  expect_match(bad$err, "Refused")
  expect_match(bad$err, "not found")
  expect_match(bad$res$why, "Raised by rmoriebricklayer::")
  expect_identical(ns$.bl_app_why(simpleError("object 'zz' not found")), "")
  # no data and no example: a note, not a refusal
  none <- run_tab("yoy", "yoy", source = "")
  expect_match(none$res$msg, "No data yet")
  expect_true(none$res$nodata)
  expect_false(grepl("Refused", none$err, fixed = TRUE))
  # a source that does not evaluate
  ugly <- run_tab("yoy", "yoy", source = "stop('no such table')")
  expect_match(ugly$res$msg, "no such table")
  # numbers typed as text
  nums <- run_tab("policy", "plnpwr", inputs = list(a_eff = "0, x"))
  expect_match(nums$res$msg, "numbers separated by commas")
  sq <- run_tab("air", "plmfld", inputs = list(a_x = "100, 200"))
  expect_match(sq$res$msg, "from, to, by")
})

test_that("results download as the package writes them", {
  skip_if_not_installed("shiny")
  f <- tempfile()
  y <- yoy(c(1, 2, 4))
  expect_identical(ns$.bl_dl_name(y, "yoy"), "rmbl-yoy.html")
  ns$.bl_dl_write(y, f)
  expect_match(paste(readLines(f), collapse = ""), "<table>", fixed = TRUE)
  expect_identical(ns$.bl_dl_name(data.frame(a = 1), "x"), "rmbl-x.csv")
  ns$.bl_dl_write(data.frame(a = 1:2), f)
  expect_identical(utils::read.csv(f)$a, 1:2)
  fit <- dstfit(c(1, 2, 3, 5, 8, 13), nboot = 0)
  ns$.bl_dl_write(fit, f)
  expect_true("family" %in% names(utils::read.csv(f)))
  ns$.bl_dl_write(c(1.5, 2.5), f)
  expect_identical(utils::read.csv(f)$value, c(1.5, 2.5))
  expect_identical(ns$.bl_dl_name(list(a = "b"), "x"), "rmbl-x.txt")
  ns$.bl_dl_write(list(a = "b"), f)
  expect_match(readLines(f)[1L], "$a", fixed = TRUE)
  skip_if_not(ns$.bl_have_cairo())
  r <- list(plot = quote(plot(1:3)), env = globalenv(), value = 1)
  ns$.bl_save_plot(r, f, "svg")
  expect_match(paste(readLines(f, 3L), collapse = ""), "<svg", fixed = TRUE)
  unlink(f)
})

test_that(
  paste0(
    "the report assembles one HTML page, ",
    "Markdown and the GitHub comment"
  ),
  {
    skip_if_not_installed("shiny")
    skip_if_not_installed("bslib")
    g <- run_tab("yoy", "yoy")
    h <- run_tab("rates", "rtcalc")
    entries <- c(g$rpt, h$rpt)
    page <- ns$.bl_rpt_html(entries, "Counts")
    expect_match(page, "<title>Counts</title>", fixed = TRUE)
    # inline SVG with per-plot ids where cairo works; a PNG data URI otherwise
    # (macOS runners)
    fig <- if (ns$.bl_have_cairo()) "<svg" else "data:image/png;base64,"
    expect_match(page, fig, fixed = TRUE)
    if (ns$.bl_have_cairo()) {
      expect_match(page, "id=\"p2-", fixed = TRUE)
    }
    expect_match(page, "<div class=\"scroll\"><table>", fixed = TRUE)
    expect_match(page, "rtcalc(data", fixed = TRUE)
    md <- ns$.bl_rpt_md(entries, "Counts")
    expect_match(md, "^# Counts")
    expect_match(md, "```r\ndata <-")
    # no SVG device: a PNG data URI instead
    local_mocked_bindings(.bl_have_cairo = function() FALSE)
    expect_match(
      ns$.bl_svg(quote(plot(1:3)), globalenv()),
      "data:image/png;base64,",
      fixed = TRUE
    )
    shiny::testServer(
      ns$.bl_rpt_server,
      args = list(id = "report", rpt = shiny::reactiveVal(entries)),
      {
        session$setInputs(title = "Counts", pick = c("1", "2"))
        expect_match(output$gh, "## Change from period to period", fixed = TRUE)
        expect_match(
          paste(readLines(output$html), collapse = ""),
          fig,
          fixed = TRUE
        )
        expect_match(readLines(output$md)[1L], "# Counts", fixed = TRUE)
        session$setInputs(pick = character())
        expect_identical(output$gh, "")
        session$setInputs(clear = 1)
        expect_length(rpt(), 0L)
      }
    )
    expect_s3_class(ns$.bl_rpt_ui("report"), "shiny.tag")
  }
)

test_that("the settings switch the theme and set digits and the seed", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  shiny::testServer(ns$.bl_set_server, args = list(id = "settings"), {
    session$setInputs(theme = "auto")
    session$setInputs(theme = "dark", digits = 99, seed = 7)
    expect_identical(session$returned(), list(digits = 15L, seed = 7L))
    session$setInputs(digits = NA, seed = NA)
    expect_identical(session$returned(), list(digits = 4L, seed = 1L))
  })
  expect_s3_class(ns$.bl_set_ui("settings"), "shiny.tag")
})

test_that(
  paste0(
    "the capsule panel shows the provenance, the bundle and the ",
    "verification rows"
  ),
  {
    skip_if_not_installed("shiny")
    skip_if_not_installed("bslib")
    d <- usecpstmpl(tempfile("capsule-"), ex = TRUE)
    invisible(cpsrfrsh(d))
    m <- mkmnf(list(dataset = "dash"), env = FALSE)
    writeLines(tojs(m, auto_unbox = TRUE), file.path(d, "manifest.json"))
    cpsbndl(d, m, fipskg("ML-DSA-44"))
    dat <- shiny::reactiveVal(list(
      data = NULL,
      code = character(),
      label = "c",
      capsule = d
    ))
    shiny::testServer(
      ns$.bl_cps_server,
      args = list(id = "capsule", dat = dat, rpt = shiny::reactiveVal(list())),
      {
        expect_null(output$vbox)
        session$setInputs(dir = d, show = 1)
        expect_match(output$prov, "resource.sha256", fixed = TRUE)
        expect_match(output$atst, "ML-DSA-44", fixed = TRUE)
        expect_match(output$files, "otis_a01_individuals.csv", fixed = TRUE)
        expect_match(output$manifest, "dataset", fixed = TRUE)
        expect_match(html(output$vbox), "Verify to check", fixed = TRUE)
        session$setInputs(verify = 1)
        expect_match(output$rows, "data_sha256", fixed = TRUE)
        expect_match(output$code, "vrfcps(dir)", fixed = TRUE)
        expect_match(html(output$vbox), "Checks passed", fixed = TRUE)
        session$setInputs(add = 1)
        expect_length(rpt(), 1L)
        session$setInputs(refresh = 1)
        expect_match(output$rows, "unchanged", fixed = TRUE)
        session$setInputs(dir = tempfile(), show = 2)
        expect_match(html(output$err), "not an existing directory")
      }
    )
    # the tab opens on the demo capsule
    act <- shiny::reactiveVal("")
    shiny::testServer(
      ns$.bl_cps_server,
      args = list(
        id = "capsule",
        dat = shiny::reactiveVal(nodata),
        rpt = shiny::reactiveVal(list()),
        active = act
      ),
      {
        session$setInputs(dir = "")
        act("capsule")
        session$flushReact()
        expect_match(output$prov, "otis_a01_individuals.csv", fixed = TRUE)
        session$setInputs(demo = 1)
        expect_match(output$code, "loadprov", fixed = TRUE)
      }
    )
    expect_identical(ns$.bl_cps_demo(), ns$.bl_cps_demo())
    st <- ns$.bl_status_rows(data.frame(
      ok = c(TRUE, FALSE),
      check = c("a", "b"),
      stringsAsFactors = FALSE
    ))
    expect_identical(st$status, c("pass", "FAIL"))
    st <- ns$.bl_status_rows(data.frame(
      ok = c(FALSE, FALSE, FALSE),
      severity = c("note", "warn", "error"),
      check = "a",
      stringsAsFactors = FALSE
    ))
    expect_identical(st$status, c("note", "warn", "FAIL"))
    expect_s3_class(ns$.bl_cps_ui("capsule"), "shiny.tag")
  }
)

test_that(
  paste0(
    "the ledger panel loads a ledger from ",
    "each source and runs its checks"
  ),
  {
    skip_if_not_installed("shiny")
    skip_if_not_installed("bslib")
    smp <- system.file(
      "extdata",
      "ledger_sample.json",
      package = "rmoriebricklayer"
    )
    cap <- tempfile("ledger-capsule-")
    dir.create(cap)
    file.copy(smp, file.path(cap, "ledger.json"))
    led <- ldgrread(smp)
    writeLines(
      tojs(
        list(
          kind = "ledger",
          source = list(
            commit = led$source$commit,
            build_digest = led$source$build_digest
          ),
          resource = list(
            filename = "ledger.json",
            sha256 = sha256file(file.path(cap, "ledger.json"))
          )
        ),
        auto_unbox = TRUE
      ),
      file.path(cap, "data_provenance.json")
    )
    expect_length(ns$.bl_ldgr_installed("rmoriebricklayer"), 0L)
    ld <- tempfile("ledgers-")
    dir.create(ld)
    file.copy(smp, file.path(ld, "proofs.json"))
    expect_named(
      ns$.bl_ldgr_installed("x", find = function(p) ld),
      "x: proofs.json"
    )
    # with no packages named it looks in every installed package (here none
    # ships a ledger)
    expect_length(ns$.bl_ldgr_installed(find = function(p) ""), 0L)
    local_mocked_bindings(.bl_ldgr_installed = function(...) {
      c("pkg: ledger.json" = smp)
    })
    dat <- shiny::reactiveVal(list(
      data = NULL,
      code = character(),
      label = "c",
      capsule = cap
    ))
    shiny::testServer(
      ns$.bl_ldgr_server,
      args = list(id = "ledger", dat = dat, rpt = shiny::reactiveVal(list())),
      {
        expect_null(output$vbox)
        session$setInputs(src = "sample", load = 1)
        expect_match(html(output$thm), "bl-chip bl-ok", fixed = TRUE)
        expect_match(
          html(output$thm),
          "blob/0123456789abcdef0123456789abcdef01234567/Rmorie/Gini.lean#L42",
          fixed = TRUE
        )
        expect_match(html(output$thm), "installed", fixed = TRUE)
        expect_match(html(output$vbox), "Not run", fixed = TRUE)
        session$setInputs(check = 1)
        expect_match(output$rows, "check: gini-equal", fixed = TRUE)
        expect_match(output$code, "ldgrchk(led)", fixed = TRUE)
        expect_match(html(output$vbox), "pass", fixed = TRUE)
        session$setInputs(add = 1)
        expect_length(rpt(), 1L)
        session$setInputs(
          src = "file",
          file = list(datapath = smp, name = "mine.json"),
          load = 2
        )
        expect_match(output$code, "path <- \"mine.json\"", fixed = TRUE)
        session$setInputs(src = "capsule", dir = cap, load = 3)
        expect_match(output$prov, "ledger", fixed = TRUE)
        session$setInputs(check = 2)
        expect_match(output$rows, "ledger_commit_pinned", fixed = TRUE)
        session$setInputs(src = "inst", find = 1, inst = smp, load = 4)
        expect_match(output$code, smp, fixed = TRUE)
        session$setInputs(src = "inst", inst = "", load = 5)
        expect_match(
          html(output$err),
          "find and choose an installed ledger first"
        )
      }
    )
    # the tab opens on the demo ledger, whose checks run
    act <- shiny::reactiveVal("")
    shiny::testServer(
      ns$.bl_ldgr_server,
      args = list(
        id = "ledger",
        dat = shiny::reactiveVal(nodata),
        rpt = shiny::reactiveVal(list()),
        active = act
      ),
      {
        act("ledger")
        session$flushReact()
        expect_match(output$code, "rmbldemo(\"ledger\")", fixed = TRUE)
        expect_match(html(output$vbox), ">120<", fixed = TRUE)
        session$setInputs(check = 1)
        expect_match(output$rows, "thm-001", fixed = TRUE)
      }
    )
    expect_error(
      ns$.bl_ldgr_path(list(src = "file", file = NULL)),
      "choose a ledger file first"
    )
    # a check that cannot run is a refusal on the panel
    local_mocked_bindings(ldgrchk = function(...) stop("no checks today"))
    shiny::testServer(
      ns$.bl_ldgr_server,
      args = list(
        id = "ledger",
        dat = shiny::reactiveVal(nodata),
        rpt = shiny::reactiveVal(list())
      ),
      {
        session$setInputs(src = "sample", load = 1, check = 1)
        expect_match(html(output$err), "no checks today")
      }
    )
    expect_null(ns$.bl_ldgr_link(
      list(repo = "a b c", commit = "1"),
      list(file = "x", line = 1)
    ))
    expect_identical(
      ns$.bl_ldgr_link(
        list(repo = "o/n", commit = "1"),
        list(file = "x", line = 1)
      ),
      "https://github.com/o/n/blob/1/x#L1"
    )
    expect_s3_class(ns$.bl_ldgr_ui("ledger"), "shiny.tag")
  }
)

test_that("the whole app's server starts with every module", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  shiny::testServer(ns$.bl_app_server(nodata), {
    session$setInputs(
      `settings-theme` = "auto",
      tabs = "describe",
      mode = "light"
    )
    # the drift app runs on the dashboard's session: two CSV files give its
    # column table
    set.seed(5)
    f1 <- tempfile(fileext = ".csv")
    f2 <- tempfile(fileext = ".csv")
    utils::write.csv(data.frame(v = stats::rnorm(200)), f1, row.names = FALSE)
    utils::write.csv(
      data.frame(v = stats::rnorm(200, 1)),
      f2,
      row.names = FALSE
    )
    session$setInputs(
      warn = 0.1,
      fail = 0.25,
      alpha = 0.01,
      bins = 10,
      refcsv = list(datapath = f1),
      curcsv = list(datapath = f2)
    )
    expect_match(output$tab, "v", fixed = TRUE)
  })
})

test_that(
  paste0(
    "rmbl app launches through the ",
    "launcher, refuses a bad path and port"
  ),
  {
    skip_if_not_installed("shiny")
    rec <- new.env()
    rec$seen <- NULL
    local_mocked_bindings(.bl_app_launch = function(app, port, browser) {
      rec$seen <- list(app, port, browser)
    })
    rec$buf <- character()
    st <- blcli(c("app", "--port", "8123", "--no-browser"), out = function(s) {
      rec$buf <- c(rec$buf, s)
    })
    expect_identical(st, 0L)
    expect_s3_class(rec$seen[[1L]], "shiny.appobj")
    expect_identical(rec$seen[2:3], list(8123L, FALSE))
    expect_match(paste(rec$buf, collapse = ""), "on port 8123")
    d <- usecpstmpl(tempfile("capsule-"), ex = TRUE)
    invisible(cpsrfrsh(d))
    expect_identical(blcli(c("app", d), out = function(s) NULL), 0L)
    expect_true(rec$seen[[3L]])
    f <- tempfile(fileext = ".csv")
    utils::write.csv(data.frame(a = 1), f, row.names = FALSE)
    expect_identical(blcli(c("app", f), out = function(s) NULL), 0L)
    expect_identical(blcli(c("app", tempfile()), out = function(s) NULL), 1L)
    expect_identical(blcli(c("app", "--port", "x"), out = function(s) NULL), 2L)
    expect_identical(blcli(c("app", "a", "b"), out = function(s) NULL), 2L)
    rec$help <- character()
    blcli("help", out = function(s) rec$help <- c(rec$help, s))
    expect_match(
      paste(rec$help, collapse = ""),
      "app [PATH] [--port N] [--no-browser]",
      fixed = TRUE
    )
    expect_error(schemapath("nope"), "capsule, bundle, manifest or ledger")
    expect_match(schemapath("ledger"), "ledger.schema.json", fixed = TRUE)
    unlink(f)
  }
)

test_that("the launcher hands the app to shiny::runApp()", {
  skip_if_not_installed("shiny")
  local_mocked_bindings(runApp = function(...) "ran", .package = "shiny")
  expect_null(ns$.bl_app_launch(NULL, NULL, FALSE))
})

test_that("tabs made in a loop each keep their own spec", {
  skip_if_not_installed("shiny")
  shiny::testServer(ns$.bl_app_server(nodata), {
    for (tab in c("yoy", "hawkes")) {
      session$setInputs(tabs = tab)
      for (i in seq_len(300L)) {
        later::run_now(0.02)
        session$flushReact()
        if (nzchar(output[[paste0(tab, "-code")]])) break
      }
    }
    expect_match(output[["yoy-code"]], "yoy(data", fixed = TRUE)
    expect_match(output[["hawkes-code"]], "chwkfit(", fixed = TRUE)
  })
})

test_that("the source tables are a comma-separated list of links", {
  skip_if_not_installed("shiny")
  about <- as.character(
    Filter(function(s) s$id == "fnmi", ns$.bl_app_specs())[[1L]]$about
  )
  expect_match(about, "13-10-0924-01</a>, <a", fixed = TRUE)
})

test_that(
  paste0(
    "the SVG device is probed once, and a build whose cairo cannot load ",
    "falls back to PNG"
  ),
  {
    cache <- ns$.bl_cairo_cache
    old <- cache$ok
    on.exit(
      if (is.null(old)) {
        rm(list = ls(cache), envir = cache)
      } else {
        assign("ok", old, envir = cache)
      },
      add = TRUE
    )
    # a probe that fails the way the macOS runners do: capabilities() says
    # cairo, the device does not open
    rm(list = ls(cache), envir = cache)
    local_mocked_bindings(.bl_cairo_probe = function() {
      stop("failed to load cairo DLL")
    })
    expect_false(ns$.bl_have_cairo())
    expect_false(ns$.bl_have_cairo()) # cached: the probe is not run again
    expect_match(
      ns$.bl_svg(quote(plot(1:3)), globalenv()),
      "data:image/png;base64,",
      fixed = TRUE
    )
    expect_error(
      ns$.bl_save_plot(
        list(plot = quote(plot(1:3)), env = globalenv(), value = 1),
        tempfile(),
        "svg"
      ),
      "no SVG device"
    )
    # a probe that succeeds
    rm(list = ls(cache), envir = cache)
    local_mocked_bindings(.bl_cairo_probe = function() TRUE)
    expect_identical(ns$.bl_have_cairo(), isTRUE(capabilities("cairo")))
  }
)
