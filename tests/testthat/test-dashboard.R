# The dashboard: the page and every panel build, each analysis of each tab runs through its module
# server and shows the call it ran, and the data, report, capsule and ledger panels do what their
# buttons say. No server is started.

ns <- asNamespace("rmoriebricklayer")
specs <- function() ns$.bl_app_specs()
spec <- function(id) Filter(function(s) s$id == id, specs())[[1L]]
setting <- function() shiny::reactive(list(digits = 4L, seed = 1L))
nodata <- list(data = NULL, code = character(), label = "none", capsule = NULL)
html <- function(x) paste(as.character(x$html), collapse = "")

# the values the form starts with, as the page's controls hold them
form_defaults <- function(f) {
  out <- list()
  for (st in c(f$steps, if (!is.null(f$plot)) list(f$plot))) {
    for (nm in names(st$args)) {
      a <- st$args[[nm]]
      id <- paste0("a_", a$input %||% nm)
      v <- switch(a$type,
        col = , vec = , date = a$default %||% "",
        cols = , mat = , frame = , choices = a$default,
        num = a$default %||% NA,
        text = , nums = , texts = , seq = paste(a$default %||% "", collapse = ", "),
        area = a$default %||% "",
        choice = a$default %||% a$choices[[1L]],
        flag = isTRUE(a$default),
        NULL
      )
      if (!is.null(v)) out[[id]] <- v
    }
  }
  out
}

# runs one analysis of a tab through its module server and returns what the page shows
run_tab <- function(id, fn, source = NULL, inputs = list(), dat = nodata) {
  s <- spec(id)
  src <- if (is.null(source)) unname(s$sources[[1L]]) else source
  got <- NULL
  shiny::testServer(ns$.bl_tab_server, args = list(id = id, s = s, dat = shiny::reactiveVal(dat),
                                                    rpt = shiny::reactiveVal(list()), set = setting()), {
    vals <- utils::modifyList(c(list(source = src, fn = fn), form_defaults(s$fns[[fn]])), inputs)
    do.call(session$setInputs, vals)
    session$setInputs(run = 1)
    r <- res()
    got <<- list(res = r, code = output$code, print = if (!inherits(r, "bl_app_error")) output$print,
                 err = html(output$err), plot = if (!inherits(r, "bl_app_error") && !is.null(r$plot)) output$plot)
    if (!inherits(r, "bl_app_error")) got$dl <<- file.exists(output$dl)
    session$setInputs(add = 1)
    got$rpt <<- rpt()
  })
  got
}

expect_ran <- function(g, fn) {
  if (inherits(g$res, "bl_app_error")) fail(paste(fn, "refused:", g$res$msg))
  expect_false(inherits(g$res, "bl_app_error"))
  expect_true(any(grepl(paste0(fn, "("), g$code, fixed = TRUE)), info = g$code)
  expect_true(nzchar(g$print))
  expect_length(g$rpt, 1L)
}

test_that("the page and every panel build", {
  skip_if_not_installed("shiny")
  html <- as.character(ns$.bl_app_ui())
  for (t in c("Describe", "Year over year", "Rates", "Trends", "Survey", "Distributions", "Drift", "Capsule",
              "Policy", "Courts and corrections", "Air pollution", "Hawkes", "Proof ledger", "Report", "Settings")) {
    expect_match(html, t, fixed = TRUE)
  }
  for (s in specs()) expect_s3_class(ns$.bl_tab_ui(s$id, s), "shiny.tag.list")
  expect_s3_class(rmblapp(), "shiny.appobj")
  expect_s3_class(rmblapp(data.frame(a = 1:3)), "shiny.appobj")
  d <- data.frame(a = 1:3)
  init <- ns$.bl_app_init(d, NULL, "d")
  expect_identical(init$code, "data <- d")
  expect_identical(ns$.bl_app_init(d, NULL, "data")$code, character())
  expect_null(ns$.bl_app_init(NULL, NULL)$data)
  expect_error(rmblapp(data = 3), "rmblapp: `data` must be a data frame or the path of a CSV file")
  expect_match(as.character(ns$.bl_drift_ui("drift")), "Reference CSV", fixed = TRUE)
})

test_that("rmblapp() refuses without shiny, in its own words", {
  testthat::local_mocked_bindings(requireNamespace = function(...) FALSE, .package = "base")
  expect_error(rmblapp(), "rmblapp: the dashboard needs the shiny package")
})

test_that("a CSV file is read with the package's reader and the call to read it is shown", {
  skip_if_not_installed("shiny")
  f <- tempfile(fileext = ".csv")
  utils::write.csv(data.frame(year = 2020:2022, n = c(5L, 7L, 9L), area = c("a", "b", "c")), f, row.names = FALSE)
  r <- ns$.bl_app_read(f, "counts.csv")
  expect_identical(r$data, utils::read.csv(f, stringsAsFactors = FALSE))
  expect_identical(r$code, "data <- utils::read.csv(\"counts.csv\", stringsAsFactors = FALSE)")
  expect_identical(ns$.bl_app_init(f, NULL)$data, r$data)
  ty <- ns$.bl_app_types(r$data)
  expect_identical(ty$type, c("integer", "integer", "character"))
  expect_null(ns$.bl_app_types(NULL))
  shiny::testServer(ns$.bl_data_server, args = list(id = "data", init = nodata), {
    session$setInputs(csv = list(datapath = f, name = "counts.csv"))
    expect_identical(cur()$data, r$data)
    expect_match(html(output$status), "3 rows, 3 columns")
    expect_match(output$cols, "integer")
    # a file that is not a table is refused, in the reader's words
    bad <- tempfile(fileext = ".csv")
    writeLines(c("a,b", "1,2,3"), bad)
    session$setInputs(csv = list(datapath = bad, name = "bad.csv"))
    expect_match(html(output$status), "Refused")
    unlink(bad)
  })
  unlink(f)
})

test_that("the data panel loads a capsule's pinned data and a data.rmorie.com table", {
  skip_if_not_installed("shiny")
  d <- usecpstmpl(tempfile("capsule-"), ex = TRUE)
  invisible(cpsrfrsh(d))
  local_mocked_bindings(dtabs = function(...) data.frame(key = "db/t", name = "A table", rows = 2L),
                        dload = function(key, ...) data.frame(x = 1:2), .bl_hosted_key = function() NULL)
  shiny::testServer(ns$.bl_data_server, args = list(id = "data", init = nodata), {
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
  })
  local_mocked_bindings(dtabs = function(...) stop("the data service did not answer"),
                        .bl_hosted_key = function() "k")
  shiny::testServer(ns$.bl_data_server, args = list(id = "data", init = nodata), {
    expect_match(html(output$signin), "Signed in")
    session$setInputs(hublist = 1)
    expect_match(html(output$status), "the data service did not answer")
  })
  # a capsule with no pinned data yet
  e <- usecpstmpl(tempfile("capsule-"), ex = TRUE)
  expect_error(ns$.bl_app_capsule(e), "pinned data file is missing")
  expect_identical(ns$.bl_app_init(NULL, d)$capsule, normalizePath(d))
})

test_that("every analysis of every tab runs and shows the call it ran", {
  skip_if_not_installed("shiny")
  skip_on_cran()
  d14 <- c(f_period = "2019/2022", f_age = "Total, 18 years and over")
  mh <- "Perceived mental health, very good or excellent"
  cases <- list(
    describe = list(profcols = list(), missgrid = list(), cortbl = list(),
                    freqtbl = list(a_col = "Month"),
                    mahaoutl = list(source = "datasets::mtcars"),
                    plotrdg = list(a_x = "Ozone", a_grp = "Month"), plotecdf = list(a_x = "Ozone", a_grp = "Month"),
                    plotvln = list(a_x = "Ozone", a_grp = "Month"), plothex = list(a_x = "Temp", a_y = "Wind"),
                    plotgain = list(a_x = "Ozone", a_grp = "Month")),
    yoy = list(yoy = list(a_by = "area", a_minbase = 20, a_dir = "lower")),
    rates = list(rtcalc = list(a_by = "area"), ratechg = list(a_by = "area"), shrs = list(a_by = "area")),
    trends = list(trndtst = list(), stepchg = list(a_nperm = 999), cnttrnd = list(), plotcal = list(source = 3L),
                  plothrz = list(source = 2L), plotsm = list(source = 2L), plotbump = list(source = 2L)),
    survey = list(svyest = list(a_by = "region"), svycmp = list(a_ref = "north")),
    dist = list(dstfit = list(a_nboot = 20, a_which = "qq"), synth = list(a_nboot = 0, a_n = 50)),
    policy = list(plndid = list(), evstudy = list(), stgatt = list(a_reps = 19), bacondcmp = list(),
                  swtdid = list(a_reps = 19), perminf = list(a_reps = 49, a_type = "histogram"),
                  syndid = list(a_reps = 10, source = 2L), mtchdid = list(), wcb = list(a_reps = 99, a_cl = "region"),
                  loounit = list(), cohtrnd = list(), plnpwr = list(a_reps = 10, a_eff = "0, 1"),
                  baltab = list(), tse = list()),
    fnmi = list(published = list(), indgap = c(as.list(d14), list(f_indicator = mh)),
                dstntst = c(as.list(d14), list(f_indicator = mh, f_group = c("First Nations", "Métis", "Inuit"))),
                ordcmp = list(source = 2L, f_region = "Canada"),
                welprof = list(source = 3L),
                healchg = list(f_age = "Total, 18 years and over", f_indicator = mh),
                mhcont = list(source = 3L),
                stdprev = list(source = 4L, f_measure = "Seriously contemplated suicide in the past 12 months",
                               f_age = c("15 to 24 years", "25 to 34 years", "35 to 44 years", "45 to 54 years",
                                         "55 years and over")),
                trcprog = list()),
    justice = list(caseflow = list(), clrdcmp = list(source = 2L, f_year = c("2014", "2022")),
                   dispmix = list(source = 3L, a_cnts = c("withdrawn_stayed_before_trial", "guilty_plea_before_trial",
                                                          "following_trial")),
                   lifetbl = list(), crmdens = list(source = 4L), knoxtst = list(source = 4L),
                   rgnmapintg = list(source = "", a_unit = "inst",
                                                                                     a_reg = "cd"),
                   siuso = list(a_text = "Subject Officials\nSO #1 Interviewed\nSO #2 Declined interview"),
                   siuprs = list(a_html = paste(readLines(system.file("extdata", "siu_synthetic_report.html",
                                                                      package = "rmoriebricklayer")),
                                                collapse = "\n")),
                   stkflow = list(source = "", a_days = "days", a_people = "people", a_prd = "prd")),
    air = list(plmfld = list(), profile = list(), gplume = list(), crfpm25 = list(), crfno2 = list(),
               polbrdn = list(), vrfpol = list()),
    hawkes = list(chwkfit = list(a_what = "tree"), chwksim = list(), chwkjit = list())
  )
  own <- list(stkflow = data.frame(days = c(100200, 104000, 99000), people = c(9800, 9500, 9900), prd = 2023:2025),
              rgnmapintg = data.frame(inst = c("North Jail", "South Jail"), cd = c("3557", "3520")))
  for (id in names(cases)) {
    s <- spec(id)
    expect_setequal(names(cases[[id]]), names(s$fns))
    for (fn in names(cases[[id]])) {
      inp <- cases[[id]][[fn]]
      src <- inp$source
      if (is.numeric(src)) src <- unname(s$sources[[src]])
      inp$source <- NULL
      dat <- if (!is.null(own[[fn]])) list(data = own[[fn]], code = "data <- own", label = "own", capsule = NULL) else
        nodata
      g <- run_tab(id, fn, src, inp, dat)
      called <- if (length(s$fns[[fn]]$steps)) s$fns[[fn]]$steps[[length(s$fns[[fn]]$steps)]]$fn else
        s$fns[[fn]]$plot$fn
      expect_ran(g, sub("^utils::", "", called))
      expect_true(g$dl)
    }
  }
})

test_that("a tab shows the exact call, the refusal and its explanation", {
  skip_if_not_installed("shiny")
  g <- run_tab("yoy", "yoy", inputs = list(a_by = "area", a_minbase = 20))
  expect_identical(strsplit(g$code, "\n")[[1L]][2L],
                   paste("y <- yoy(data, value = \"n\", prd = \"year\", by = \"area\", lag = 1, units = \"count\",",
                         "minbase = 20, dir = \"neutral\")"))
  expect_match(g$code, "plot(y)", fixed = TRUE)
  expect_s3_class(g$rpt[[1L]]$yoy, "rmbl_yoy")
  # the same call in a script gives the same table
  data <- eval(str2lang(spec("yoy")$sources[[1L]]))
  y <- yoy(data, value = "n", prd = "year", by = "area", lag = 1, units = "count", minbase = 20, dir = "neutral")
  expect_identical(as.data.frame(g$res$value), as.data.frame(y))
  bad <- run_tab("yoy", "yoy", inputs = list(a_value = "nope"))
  expect_s3_class(bad$res, "bl_app_error")
  expect_match(bad$err, "Refused")
  expect_match(bad$err, "not found")
  expect_match(bad$res$why, "Raised by rmoriebricklayer::")
  expect_identical(ns$.bl_app_why(simpleError("object 'zz' not found")), "")
  # no data and no example
  none <- run_tab("yoy", "yoy", source = "")
  expect_match(none$res$msg, "load data at the left")
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
  unlink(f)
})

test_that("the report assembles one HTML page, Markdown and the GitHub comment", {
  skip_if_not_installed("shiny")
  g <- run_tab("yoy", "yoy")
  h <- run_tab("rates", "rtcalc", inputs = list(a_by = "area"))
  entries <- c(g$rpt, h$rpt)
  page <- ns$.bl_rpt_html(entries, "Counts")
  expect_match(page, "<title>Counts</title>", fixed = TRUE)
  expect_match(page, "<svg", fixed = TRUE)
  expect_match(page, "id=\"p2-", fixed = TRUE)
  expect_match(page, "<div class=\"scroll\"><table>", fixed = TRUE)
  expect_match(page, "rtcalc(data", fixed = TRUE)
  md <- ns$.bl_rpt_md(entries, "Counts")
  expect_match(md, "^# Counts")
  expect_match(md, "```r\ndata <-")
  # no SVG device: a PNG data URI instead
  local_mocked_bindings(.bl_have_cairo = function() FALSE)
  expect_match(ns$.bl_svg(quote(plot(1:3)), globalenv()), "data:image/png;base64,", fixed = TRUE)
  shiny::testServer(ns$.bl_rpt_server, args = list(id = "report", rpt = shiny::reactiveVal(entries)), {
    session$setInputs(title = "Counts", pick = c("1", "2"))
    expect_match(output$gh, "## Change from period to period", fixed = TRUE)
    expect_match(paste(readLines(output$html), collapse = ""), "<svg", fixed = TRUE)
    expect_match(readLines(output$md)[1L], "# Counts", fixed = TRUE)
    session$setInputs(pick = character())
    expect_identical(output$gh, "")
    session$setInputs(clear = 1)
    expect_length(rpt(), 0L)
  })
  expect_s3_class(ns$.bl_rpt_ui("report"), "shiny.tag.list")
})

test_that("the settings switch the theme and set digits and the seed", {
  skip_if_not_installed("shiny")
  shiny::testServer(ns$.bl_set_server, args = list(id = "settings"), {
    session$setInputs(theme = "dark", digits = 99, seed = 7)
    expect_identical(session$returned(), list(digits = 15L, seed = 7L))
    session$setInputs(digits = NA, seed = NA)
    expect_identical(session$returned(), list(digits = 4L, seed = 1L))
  })
  expect_s3_class(ns$.bl_set_ui("settings"), "shiny.tag.list")
})

test_that("the capsule panel shows the provenance, the bundle and the verification rows", {
  skip_if_not_installed("shiny")
  d <- usecpstmpl(tempfile("capsule-"), ex = TRUE)
  invisible(cpsrfrsh(d))
  m <- mkmnf(list(dataset = "dash"), env = FALSE)
  writeLines(tojs(m, auto_unbox = TRUE), file.path(d, "manifest.json"))
  cpsbndl(d, m, fipskg("ML-DSA-44"))
  dat <- shiny::reactiveVal(list(data = NULL, code = character(), label = "c", capsule = d))
  shiny::testServer(ns$.bl_cps_server, args = list(id = "capsule", dat = dat, rpt = shiny::reactiveVal(list())), {
    session$setInputs(dir = d, show = 1)
    expect_match(output$prov, "resource.sha256", fixed = TRUE)
    expect_match(output$atst, "ML-DSA-44", fixed = TRUE)
    expect_match(output$files, "otis_a01_individuals.csv", fixed = TRUE)
    expect_match(output$manifest, "dataset", fixed = TRUE)
    session$setInputs(verify = 1)
    expect_match(output$rows, "data_sha256", fixed = TRUE)
    expect_match(output$code, "vrfcps(dir)", fixed = TRUE)
    session$setInputs(add = 1)
    expect_length(rpt(), 1L)
    session$setInputs(refresh = 1)
    expect_match(output$rows, "unchanged", fixed = TRUE)
    session$setInputs(dir = tempfile(), show = 2)
    expect_match(html(output$err), "not an existing directory")
  })
  st <- ns$.bl_status_rows(data.frame(ok = c(TRUE, FALSE), check = c("a", "b")))
  expect_identical(st$status, c("pass", "FAIL"))
  st <- ns$.bl_status_rows(data.frame(ok = c(FALSE, FALSE, FALSE), severity = c("note", "warn", "error"), check = "a"))
  expect_identical(st$status, c("note", "warn", "FAIL"))
  expect_s3_class(ns$.bl_cps_ui("capsule"), "shiny.tag.list")
})

test_that("the ledger panel loads a ledger from each source and runs its checks", {
  skip_if_not_installed("shiny")
  smp <- system.file("extdata", "ledger_sample.json", package = "rmoriebricklayer")
  cap <- tempfile("ledger-capsule-")
  dir.create(cap)
  file.copy(smp, file.path(cap, "ledger.json"))
  led <- ldgrread(smp)
  writeLines(tojs(list(kind = "ledger", source = list(commit = led$source$commit,
                                                      build_digest = led$source$build_digest),
                       resource = list(filename = "ledger.json", sha256 = sha256file(file.path(cap, "ledger.json")))),
                  auto_unbox = TRUE), file.path(cap, "data_provenance.json"))
  expect_length(ns$.bl_ldgr_installed("rmoriebricklayer"), 0L)
  ld <- tempfile("ledgers-")
  dir.create(ld)
  file.copy(smp, file.path(ld, "proofs.json"))
  expect_identical(names(ns$.bl_ldgr_installed("x", find = function(p) ld)), "x: proofs.json")
  local_mocked_bindings(.bl_ldgr_installed = function(...) c("pkg: ledger.json" = smp))
  dat <- shiny::reactiveVal(list(data = NULL, code = character(), label = "c", capsule = cap))
  shiny::testServer(ns$.bl_ldgr_server, args = list(id = "ledger", dat = dat, rpt = shiny::reactiveVal(list())), {
    session$setInputs(src = "sample", load = 1)
    expect_match(html(output$thm), "bl-chip bl-ok", fixed = TRUE)
    expect_match(html(output$thm), "blob/0123456789abcdef0123456789abcdef01234567/Rmorie/Gini.lean#L42",
                 fixed = TRUE)
    expect_match(html(output$thm), "installed", fixed = TRUE)
    session$setInputs(check = 1)
    expect_match(output$rows, "check: gini-equal", fixed = TRUE)
    expect_match(output$code, "ldgrchk(led)", fixed = TRUE)
    session$setInputs(add = 1)
    expect_length(rpt(), 1L)
    session$setInputs(src = "file", file = list(datapath = smp, name = "mine.json"), load = 2)
    expect_match(output$code, "path <- \"mine.json\"", fixed = TRUE)
    session$setInputs(src = "capsule", dir = cap, load = 3)
    expect_match(output$prov, "ledger", fixed = TRUE)
    session$setInputs(check = 2)
    expect_match(output$rows, "ledger_commit_pinned", fixed = TRUE)
    session$setInputs(src = "inst", find = 1, inst = smp, load = 4)
    expect_match(output$code, smp, fixed = TRUE)
    session$setInputs(src = "inst", inst = "", load = 5)
    expect_match(html(output$err), "find and choose an installed ledger first")
  })
  expect_error(ns$.bl_ldgr_path(list(src = "file", file = NULL)), "choose a ledger file first")
  # a check that cannot run is a refusal on the panel
  local_mocked_bindings(ldgrchk = function(...) stop("no checks today"))
  shiny::testServer(ns$.bl_ldgr_server, args = list(id = "ledger", dat = shiny::reactiveVal(nodata),
                                                    rpt = shiny::reactiveVal(list())), {
    session$setInputs(src = "sample", load = 1, check = 1)
    expect_match(html(output$err), "no checks today")
  })
  expect_null(ns$.bl_ldgr_link(list(repo = "a b c", commit = "1"), list(file = "x", line = 1)))
  expect_identical(ns$.bl_ldgr_link(list(repo = "o/n", commit = "1"), list(file = "x", line = 1)),
                   "https://github.com/o/n/blob/1/x#L1")
  expect_s3_class(ns$.bl_ldgr_ui("ledger"), "shiny.tag.list")
})

test_that("the whole app's server starts with every module", {
  skip_if_not_installed("shiny")
  shiny::testServer(ns$.bl_app_server(nodata), {
    session$setInputs(`settings-theme` = "auto")
    # the drift app runs on the dashboard's session: two CSV files give its column table
    set.seed(5)
    f1 <- tempfile(fileext = ".csv")
    f2 <- tempfile(fileext = ".csv")
    utils::write.csv(data.frame(v = stats::rnorm(200)), f1, row.names = FALSE)
    utils::write.csv(data.frame(v = stats::rnorm(200, 1)), f2, row.names = FALSE)
    session$setInputs(warn = 0.1, fail = 0.25, alpha = 0.01, bins = 10, refcsv = list(datapath = f1),
                      curcsv = list(datapath = f2))
    expect_match(output$tab, "v", fixed = TRUE)
  })
})

test_that("rmbl app launches through the launcher, refuses a bad path and port", {
  skip_if_not_installed("shiny")
  seen <- NULL
  local_mocked_bindings(.bl_app_launch = function(app, port, browser) seen <<- list(app, port, browser))
  buf <- character()
  st <- blcli(c("app", "--port", "8123", "--no-browser"), out = function(s) buf <<- c(buf, s))
  expect_identical(st, 0L)
  expect_s3_class(seen[[1L]], "shiny.appobj")
  expect_identical(seen[2:3], list(8123L, FALSE))
  expect_match(paste(buf, collapse = ""), "on port 8123")
  d <- usecpstmpl(tempfile("capsule-"), ex = TRUE)
  invisible(cpsrfrsh(d))
  expect_identical(blcli(c("app", d), out = function(s) NULL), 0L)
  expect_identical(seen[[3L]], TRUE)
  f <- tempfile(fileext = ".csv")
  utils::write.csv(data.frame(a = 1), f, row.names = FALSE)
  expect_identical(blcli(c("app", f), out = function(s) NULL), 0L)
  expect_identical(blcli(c("app", tempfile()), out = function(s) NULL), 1L)
  expect_identical(blcli(c("app", "--port", "x"), out = function(s) NULL), 2L)
  expect_identical(blcli(c("app", "a", "b"), out = function(s) NULL), 2L)
  help <- character()
  blcli("help", out = function(s) help <<- c(help, s))
  expect_match(paste(help, collapse = ""), "app [PATH] [--port N] [--no-browser]", fixed = TRUE)
  expect_error(schemapath("nope"), "capsule, bundle, manifest or ledger")
  expect_match(schemapath("ledger"), "ledger.schema.json", fixed = TRUE)
  unlink(f)
})

test_that("the launcher hands the app to shiny::runApp()", {
  skip_if_not_installed("shiny")
  local_mocked_bindings(runApp = function(...) "ran", .package = "shiny")
  expect_null(ns$.bl_app_launch(NULL, NULL, FALSE))
})
