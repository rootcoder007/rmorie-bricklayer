# SPDX-License-Identifier: AGPL-3.0-or-later

test_that("the dashboard has its twelve tabs, in order", {
  sp <- .bl_app_specs()
  expect_length(sp, 12L)
  expect_identical(
    vapply(sp, `[[`, "", "id"),
    c(
      "describe",
      "yoy",
      "rates",
      "trends",
      "survey",
      "dist",
      "policy",
      "drift",
      "fnmi",
      "justice",
      "air",
      "hawkes"
    )
  )
})

test_that("each tab has its fields and its analyses, in order", {
  sp <- .bl_app_specs()
  names(sp) <- vapply(sp, `[[`, "", "id")
  fields <- list(
    describe = c(
      "id",
      "title",
      "filters",
      "linked",
      "about",
      "assume",
      "sources",
      "fns"
    ),
    yoy = c(
      "id",
      "title",
      "filters",
      "about",
      "assume",
      "sources",
      "fns"
    ),
    rates = c(
      "id",
      "title",
      "filters",
      "about",
      "assume",
      "sources",
      "fns"
    ),
    trends = c(
      "id",
      "title",
      "filters",
      "about",
      "assume",
      "sources",
      "fns"
    ),
    survey = c(
      "id",
      "title",
      "filters",
      "about",
      "assume",
      "sources",
      "fns"
    ),
    dist = c(
      "id",
      "title",
      "filters",
      "about",
      "assume",
      "sources",
      "fns"
    ),
    policy = c(
      "id",
      "title",
      "filters",
      "about",
      "assume",
      "sources",
      "fns"
    ),
    drift = c(
      "id",
      "title",
      "filters",
      "linked",
      "extra",
      "about",
      "assume",
      "sources",
      "fns"
    ),
    fnmi = c(
      "id",
      "title",
      "filters",
      "assume",
      "about",
      "sources",
      "fns"
    ),
    justice = c(
      "id",
      "title",
      "filters",
      "about",
      "assume",
      "sources",
      "fns"
    ),
    air = c(
      "id",
      "title",
      "filters",
      "about",
      "assume",
      "sources",
      "fns"
    ),
    hawkes = c(
      "id",
      "title",
      "filters",
      "about",
      "assume",
      "sources",
      "fns"
    )
  )
  fns <- list(
    describe = c(
      "profcols",
      "freqtbl",
      "cortbl",
      "mahaoutl",
      "missgrid",
      "plotrdg",
      "plotecdf",
      "plotvln",
      "plothex",
      "plotgain"
    ),
    yoy = "yoy",
    rates = c(
      "rtcalc",
      "ratechg",
      "shrs"
    ),
    trends = c(
      "trndtst",
      "stepchg",
      "cnttrnd",
      "plotcal",
      "plothrz",
      "plotsm",
      "plotbump"
    ),
    survey = c(
      "svyest",
      "svycmp"
    ),
    dist = c(
      "dstfit",
      "synth"
    ),
    policy = c(
      "plndid",
      "evstudy",
      "stgatt",
      "bacondcmp",
      "swtdid",
      "perminf",
      "syndid",
      "mtchdid",
      "wcb",
      "loounit",
      "cohtrnd",
      "plnpwr",
      "baltab",
      "tse"
    ),
    drift = "cpsdrft",
    fnmi = c(
      "published",
      "indgap",
      "dstntst",
      "ordcmp",
      "welprof",
      "healchg",
      "mhcont",
      "stdprev",
      "trcprog"
    ),
    justice = c(
      "caseflow",
      "stkflow",
      "clrdcmp",
      "dispmix",
      "lifetbl",
      "crmdens",
      "knoxtst",
      "rgnmapintg",
      "siuprs",
      "siuso"
    ),
    air = c(
      "plmfld",
      "monitors",
      "profile",
      "gplume",
      "crfpm25",
      "crfno2",
      "polbrdn",
      "vrfpol"
    ),
    hawkes = c(
      "chwkfit",
      "chwksim",
      "chwkjit"
    )
  )
  for (id in names(fields)) {
    expect_named(sp[[id]], fields[[id]], info = id)
    expect_named(sp[[id]]$fns, fns[[id]], info = id)
  }
})

test_that("every analysis calls exported functions with known controls", {
  types <- c(
    "data",
    "ref",
    "fixed",
    "seed",
    "col",
    "cols",
    "vec",
    "date",
    "frame",
    "mat",
    "num",
    "nums",
    "text",
    "texts",
    "seq",
    "area",
    "choice",
    "choices",
    "flag"
  )
  ex <- getNamespaceExports("rmoriebricklayer")
  for (tab in .bl_app_specs()) {
    for (nm in names(tab$fns)) {
      f <- tab$fns[[nm]]
      expect_type(f$label, "character")
      steps <- c(f$steps, list(f$plot), lapply(f$diag, `[[`, "step"))
      for (st in Filter(Negate(is.null), steps)) {
        expect_true(
          st$fn %in% c(ex, "plot") || grepl("::", st$fn, fixed = TRUE),
          info = paste(tab$id, nm)
        )
        for (a in st$args) {
          expect_true(a$type %in% types, info = paste(tab$id, nm, st$fn))
        }
      }
    }
  }
})

test_that("the shared controls are built once for every tab", {
  k <- .bl_app_kit()
  expect_true(all(
    c("D", "X", "col", "panel", "ind", "q", "series", "ser1") %in% names(k)
  ))
  expect_identical(k$col("A", "b"), .ua("col", label = "A", default = "b"))
  st <- k$panel("plndid", "res")
  expect_identical(st$fn, "plndid")
  expect_identical(st$args$trtd$default, "reformed")
  expect_identical(st$args$cl$type, "col")
  expect_null(k$panel("stgatt", "res", trt = "gvar", cl = FALSE)$args$cl)
})
