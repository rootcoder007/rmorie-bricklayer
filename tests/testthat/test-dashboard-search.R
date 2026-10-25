# The dashboard's "Search and rescue" panel, driven through shiny::testServer().
# No server is started.

test_that("the search and rescue panel computes what its R call reproduces", {
  skip_if_not_installed("shiny")
  ns <- asNamespace("rmoriebricklayer")
  ui <- paste(as.character(ns$.bl_srch_ui("sar")), collapse = "")
  expect_match(ui, "sar-navsd", fixed = TRUE)
  expect_match(ui, "6-6. Optimal search factors", fixed = TRUE)
  expect_match(as.character(ns$.bl_app_ui()), "Search and rescue", fixed = TRUE)
  rpt <- shiny::reactiveVal(list())
  shiny::testServer(ns$.bl_srch_server, args = list(id = "sar", rpt = rpt), {
    session$setInputs(
      model = "invcube",
      m = 0.8,
      W = 1,
      coverage = 1,
      podmodel = "random",
      S = 1.3,
      navsd = 0,
      datum = "point",
      sigma = 2,
      endx = 4,
      endy = 2,
      effort = 30
    )
    r <- res()$r
    expect_equal(as.numeric(r$pod), 1 - exp(-1))
    expect_equal(r$sweep, pswppod(1, 1.3, npts = 401), tolerance = 1e-12)
    expect_equal(r$circle$pos, optcrcsrch(2, 1, 30)$pos)
    expect_s3_class(r$map, "rmbl_datummap")
    expect_match(output$numbers, "Parallel sweep POD", fixed = TRUE)
    for (p in c("lrplot", "podplot", "mapplot", "effplot")) {
      expect_true(nzchar(output[[p]]$src))
    }
    code <- output$code
    expect_match(
      code,
      "alloc <- opteffort(map, W = 1, effort = 30)",
      fixed = TRUE
    )
    # the printed calls give the same answer
    env <- new.env()
    eval(
      parse(text = sub("library(rmoriebricklayer)", "", code, fixed = TRUE)),
      env
    )
    expect_equal(env$alloc$pos, r$alloc$pos)
    session$setInputs(add = 1)
    expect_length(rpt(), 1L)
    expect_identical(rpt()[[1L]]$title, "Search and rescue")
    session$setInputs(fig = "5-8")
    expect_true(nzchar(output$figplot$src))
    expect_match(output$figcode, "srchfig(\"5-8\")", fixed = TRUE)
    session$setInputs(model = "mbeta", datum = "line", navsd = 0.2)
    expect_match(output$code, "m = 0.8", fixed = TRUE)
    expect_identical(res()$r$map$datum, "line")
    expect_identical(paste(as.character(output$err$html), collapse = ""), "")
    session$setInputs(W = -1)
    expect_s3_class(res(), "bl_app_error")
    expect_match(
      paste(as.character(output$err$html), collapse = ""),
      "`W` must be positive",
      fixed = TRUE
    )
  })
})
