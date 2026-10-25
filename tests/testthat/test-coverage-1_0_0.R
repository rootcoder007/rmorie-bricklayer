# Lines of 1.0.0 the suite had not reached (codecov patch of 5e7a0813): the
# refusals and the rarer branches of the Indigenous estimators, the
# capture-and-upload seams, and a download that cannot be renamed into place.

.cov_stub <- function(serve) {
  force(serve)
  function(url, dest, wb = "", tmout = 120L) {
    b <- serve[[url]]
    if (is.null(b)) {
      stop("blfetch: could not reach", call. = FALSE)
    }
    writeBin(b, dest)
    invisible("live")
  }
}

.cov_tbl <- function() {
  data.frame(
    g = c("A", "A", "B", "B"),
    ind = rep(c("w", "d"), 2),
    e = c(60, 20, 50, 30),
    lo = c(55, 15, 45, 25),
    hi = c(65, 25, 55, 35),
    q = "",
    stringsAsFactors = FALSE
  )
}

test_that(
  paste0(
    "ordcmp() refuses what is not a table, a column it cannot find, and a ",
    "bad quality column"
  ),
  {
    expect_error(
      ordcmp(1, "g", "r", "e", "lo", "hi", lvls = "a", ref = "A"),
      "must be a data frame"
    )
    d <- data.frame(g = "A", r = "x", e = 1, lo = 0, hi = 2)
    expect_error(
      ordcmp(d, "g", "r", "e", "lo", "nope", lvls = "x", ref = "A"),
      "column `nope` not found"
    )
    expect_error(
      ordcmp(d, "g", "r", "e", "lo", "hi", lvls = "x", ref = "A", qual = "zz"),
      "column `zz` not found"
    )
  }
)

test_that(
  paste0(
    "ordcmp(): an interval that misses its estimate is not compared, and a ",
    "zero-width one gives no interval"
  ),
  {
    lv <- c("Low", "High")
    d <- data.frame(
      g = rep(c("R", "A", "B"), each = 2),
      r = rep(lv, 3),
      e = c(40, 60, 30, 70, 50, 50),
      lo = c(38, 58, 45, 68, 50, 50), # A's first limit lies above its estimate
      # B's limits equal its estimates: no sampling error
      hi = c(42, 62, 32, 72, 50, 50),
      stringsAsFactors = FALSE
    )
    expect_warning(
      oc <- ordcmp(d, "g", "r", "e", "lo", "hi", lvls = lv, ref = "R"),
      "does not contain its estimate"
    )
    expect_true(is.na(oc$probbet[oc$group == "A"]))
    b <- oc[oc$group == "B", ]
    expect_false(is.na(b$probbet))
    expect_true(is.na(b$lower) && is.na(b$upper))
  }
)

test_that(
  paste0(
    "stdprev() refuses a bad standard and ",
    "group labels of the wrong length"
  ),
  {
    expect_error(
      stdprev(c(10, 20), c(8, 18), c(12, 22), std = c(0, 0)),
      "non-negative counts"
    )
    expect_error(
      stdprev(c(10, 20), c(8, 18), c(12, 22), std = c(1, NA)),
      "non-negative counts"
    )
    expect_error(
      stdprev(c(10, 20), c(8, 18), c(12, 22), std = c(1, 1), grp = "only one"),
      "one label per row"
    )
  }
)

test_that(
  paste0(
    "welprof() and the column helper refuse a non-table, a missing column ",
    "and non-text indicators"
  ),
  {
    d <- .cov_tbl()
    expect_error(
      welprof(1, "g", "ind", "e", "lo", "hi", well = "w", distress = "d"),
      "must be a data frame"
    )
    expect_error(
      welprof(d, "g", "ind", "e", "lo", "nope", well = "w", distress = "d"),
      "column `nope` not found"
    )
    expect_error(
      welprof(
        d,
        "g",
        "ind",
        "e",
        "lo",
        "hi",
        well = "w",
        distress = "d",
        qual = "zz"
      ),
      "column `zz` not found"
    )
    expect_error(
      welprof(d, "g", "ind", "e", "lo", "hi", well = 1, distress = "d"),
      "must name indicators"
    )
    expect_error(
      welprof(
        d,
        "g",
        "ind",
        "e",
        "lo",
        "hi",
        well = "w",
        distress = NA_character_
      ),
      "must name indicators"
    )
    expect_error(
      rmoriebricklayer:::.rmbl_col(d, "zz", "grp"),
      "column `zz` not found"
    )
  }
)

test_that(
  paste0(
    "holbal() and dstntst() refuse a non-table and name a missing quality ",
    "column"
  ),
  {
    d <- .cov_tbl()
    expect_error(holbal(1, "g", "ind", "e", "lo", "hi"), "must be a data frame")
    expect_error(dstntst(1, "g", "e", "lo", "hi"), "must be a data frame")
    expect_error(
      dstntst(d, "g", "e", "lo", "hi", qual = "zz"),
      "column `zz` not found"
    )
    expect_error(connassoc(1, "p", "x", "y"), "must be a data frame")
  }
)

test_that(
  paste0(
    "scests() picks the Statistics column beside a Characteristics column, ",
    "and skips an empty measure"
  ),
  {
    grp <- rep(c("First Nations", "Inuit"), each = 4)
    stat <- rep(
      c(
        "Rate (A)",
        "Rate (B)",
        "Low 95% confidence interval",
        "High 95% confidence interval"
      ),
      2
    )
    x <- data.frame(
      REF_DATE = "2022",
      GEO = "Canada",
      Characteristics = grp,
      Statistics = stat,
      VALUE = c(50, NA, 45, 55, 40, NA, 35, 45),
      STATUS = "",
      stringsAsFactors = FALSE
    )
    e <- scests(x)
    expect_s3_class(e, "data.frame")
    # the measure with no values cannot be what the limits belong to
    expect_true(all(
      e$lower <= e$estimate & e$estimate <= e$upper,
      na.rm = TRUE
    ))
    expect_true(any(
      e$lower ==
        c(45, 35)[match(e$Characteristics, c("First Nations", "Inuit"))],
      na.rm = TRUE
    ))
  }
)

test_that(
  paste0(
    "sctidy() and cnsprof() take a data service key, and sctidy() refuses ",
    "other things"
  ),
  {
    local_mocked_bindings(dload = function(key, ...) {
      if (grepl("^statcan_indigenous/tbl_[0-9]{8}$", key)) {
        return(data.frame(
          REF_DATE = "2022",
          GEO = "Canada",
          VALUE = 1,
          STATUS = "",
          stringsAsFactors = FALSE
        ))
      }
      indiex("censuspop")
    })
    expect_s3_class(sctidy("13100924"), "data.frame")
    expect_s3_class(cnsprof("statcan_indigenous/census"), "rmbl_census_profile")
    expect_error(sctidy(3), "data frame or a table key")
    expect_error(cnsprof(3), "data frame or a data service key")
  }
)

test_that("a wide table without symbol columns tidies with an empty STATUS", {
  w <- data.frame(
    REF_DATE = c("2021", "2022"),
    GEO = "Canada",
    `Group:First Nations [1]` = c(1, 2),
    `Group:Inuit [2]` = c(3, 4),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  t <- rmoriebricklayer:::.rmbl_statcan_long(w)
  expect_identical(unique(t$STATUS), "")
  expect_identical(nrow(t), 4L)
})

test_that(
  paste0(
    "member numbers are left alone with one ",
    "dimension or a short coordinate"
  ),
  {
    one <- data.frame(
      GEO = "Canada",
      DGUID = "2021A000011124",
      Group = "A",
      COORDINATE = "1.1",
      VALUE = 1
    )
    expect_identical(rmoriebricklayer:::.rmbl_statcan_members(one), one)
    two <- data.frame(
      GEO = "Canada",
      DGUID = "x",
      Group = c("A", "A"),
      Age = c("0-4", "5-9"),
      COORDINATE = c("1.1", "1"),
      VALUE = 1:2
    )
    expect_identical(rmoriebricklayer:::.rmbl_statcan_members(two), two)
  }
)

test_that("pooled rows must be named as text", {
  expect_error(
    rmoriebricklayer:::.rmbl_pan_indigenous("Total", pooled_groups = 1),
    "labels of the rows"
  )
  expect_error(
    rmoriebricklayer:::.rmbl_pan_indigenous(
      "Total",
      pooled_groups = NA_character_
    ),
    "labels of the rows"
  )
})

test_that("trcprog() refuses years out of order", {
  expect_error(trcprog(c(1, 2), c(2017, 2016)), "must be increasing")
})

test_that(
  paste0(
    "cnsstd() refuses a non-profile, non-text ages, and a geography that ",
    "names several places"
  ),
  {
    expect_error(cnsstd(data.frame(a = 1)), "must come from cnsprof")
    p <- cnsprof(indiex("censuspop"))
    expect_error(cnsstd(p, ages = 1), "must name age groups")
    d <- p[p$geo == "Canada", ]
    d$geo <- "Twice"
    d2 <- d
    d2$dguid <- paste0(d2$dguid, "b")
    pp <- rbind(d, d2)
    class(pp) <- class(p)
    expect_error(cnsstd(pp, geo = "Twice"), "names 2 places")
  }
)

test_that("plot.rmbl_census_cwb() says when no place has the component", {
  cw <- cnscwb(cnsprof(indiex("censuspop")), cnsprof(indiex("censushh")))
  cw$income <- NA_real_
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_error(plot(cw, component = "income"), "no place has a value")
})

test_that(
  paste0(
    "arccap(): a missing folder is made, a repeated name is numbered, no ",
    "capture at all stops"
  ),
  {
    dir <- file.path(withr::local_tempdir(), "deeper", "still")
    local_mocked_bindings(
      blfetch = .cov_stub(list(
        "https://s.org/a/x.csv" = charToRaw("A"),
        "https://s.org/b/x.csv" = charToRaw("B")
      ))
    )
    r <- arccap(
      c("https://s.org/a/x.csv", "https://s.org/b/x.csv"),
      dir,
      tsa = NULL
    )
    expect_true(dir.exists(dir))
    expect_identical(r$file, c("x.csv", "002_x.csv"))
    expect_error(
      arccap("https://s.org/gone", withr::local_tempdir(), tsa = NULL),
      "no URL could be fetched"
    )
  }
)

test_that(
  paste0(
    "arccap(): a silent time-stamping authority is a warning, a refused ",
    "upload stops"
  ),
  {
    dir <- withr::local_tempdir()
    local_mocked_bindings(
      blfetch = .cov_stub(list("https://s.org/a.zip" = charToRaw("AAA"))),
      .bl_tsa_post = function(url, body, timeout) {
        list(status = 503L, body = raw(), error = "")
      },
      .bl_ia_put = function(url, path, content_type, headers, timeout) {
        list(status = 403L, body = raw(), error = "forbidden")
      }
    )
    expect_warning(
      r <- arccap("https://s.org/a.zip", dir),
      "did not answer \\(HTTP 503\\)"
    )
    expect_null(attr(r, "timestamp"))
    local_mocked_bindings(.bl_tsa_post = function(url, body, timeout) {
      list(status = 0L, body = raw(), error = "down")
    })
    expect_warning(
      arccap("https://s.org/a.zip", dir),
      "did not answer \\(down\\)"
    )
    expect_error(
      suppressWarnings(arccap(
        "https://s.org/a.zip",
        dir,
        item = "test-item-2026",
        ak = "AK1",
        sk = "SK1"
      )),
      "archive.org refused manifest.json \\(HTTP 403 forbidden\\)"
    )
  }
)

test_that(
  paste0(
    "the capture seams reach the transport: a closed loopback port answers ",
    "with an error, not a crash"
  ),
  {
    # two connects to the loopback discard port (final audit of 1.0.0, #10)
    skip_on_cran()
    u <- "http://127.0.0.1:9/tsa"
    r <- .bl_tsa_post(u, as.raw(1:4), 2L)
    expect_false(identical(r$status, 200L))
    f <- withr::local_tempfile(lines = "x")
    r2 <- .bl_ia_put(
      "http://127.0.0.1:9/item/f",
      f,
      "application/octet-stream",
      character(),
      2L
    )
    expect_false(identical(r2$status, 200L))
  }
)

test_that(
  paste0(
    "fetchvrf() falls back to a copy when the kept file cannot be renamed ",
    "into place"
  ),
  {
    # a folder as the destination: rename refuses it, copy puts the file inside
    # it
    dest <- file.path(withr::local_tempdir(), "into")
    dir.create(dest)
    local_mocked_bindings(blfetch = function(url, dest, wb = "", tmout = 120L) {
      writeBin(charToRaw("hello"), dest)
      invisible("live")
    })
    r <- fetchvrf("https://s.org/a.bin", dest)
    expect_true(file.exists(file.path(dest, "into.part")))
    expect_identical(r$tried$outcome, "kept")
  }
)
