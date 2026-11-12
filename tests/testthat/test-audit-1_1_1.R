# Findings of the black-box audit of 1.1.1 (every export, random and hostile
# input), each with the call that showed it.

test_that("quantiles with an infinite value agree with stats::quantile()", {
  for (x in list(c(-Inf, 1, 2), c(1, Inf), c(-Inf, 1), c(-Inf, 0, Inf))) {
    expect_identical(
      unname(cqnt(x)),
      stats::quantile(x, names = FALSE),
      info = toString(x)
    )
    expect_identical(cmed(x), stats::median(x), info = toString(x))
  }
  # two finite values whose difference overflows
  big <- c(-1.5e308, 1.5e308)
  expect_identical(cmed(big), stats::median(big))
  expect_identical(ciqr(c(-Inf, 1, 2, 3)), Inf)
})

test_that("the gamma CDF keeps its digits far below the shape", {
  for (a in c(10, 30, 200)) {
    for (x in c(1e-8, 1e-3, 1)) {
      expect_equal(
        cgamcdf(a, x),
        stats::pgamma(x, a),
        tolerance = 1e-11,
        info = paste(a, x)
      )
    }
  }
})

test_that("a bundle whose attestation has no signature is no bundle", {
  dir <- withr::local_tempdir()
  utils::write.csv(data.frame(x = 1:3), file.path(dir, "d.csv"))
  m <- mkmnf(list(dataset = "demo"), env = FALSE)
  p <- attr(cpsbndl(dir, m, "shared-secret"), "path")
  writeLines(sub("\"signature\":", "\"signaturX\":", readLines(p)), p)
  expect_error(cpsbndlrd(p), "not a capsule bundle")
  expect_error(
    cpsbndlvrf(p, dir, man = m, key = "shared-secret"),
    "not a capsule bundle"
  )
})

test_that("cpssign() names the keys it takes when given none of them", {
  expect_error(cpssign(charToRaw("a"), NULL), "fipskg\\(\\) or pqckg\\(\\)")
  expect_error(cpssign(charToRaw("a"), list(public = "00")), "shared secret")
})

test_that("a column name with a pipe, HTML or a line break stays in its cell", {
  d <- data.frame(yr = 2019:2021, n = c(5, 9, 7), g = "a|b")
  names(d)[2] <- "cases|<b>all</b>"
  md <- strsplit(yoymd(yoychg(d, names(d)[2], "yr", by = "g"), NULL), "\n")[[1]]
  cells <- lengths(gregexpr("(?<!\\\\)\\|", md[1:5], perl = TRUE))
  expect_identical(length(unique(cells)), 1L)
  expect_false(any(grepl("<b>", md, fixed = TRUE)))

  e <- data.frame(yr = 2019:2021, n = c(5, 9, 7))
  names(e)[2] <- "cases\nper day"
  f <- withr::local_tempfile(fileext = ".csv")
  yoycsv(yoychg(e, names(e)[2], "yr"), f)
  expect_identical(nrow(utils::read.csv(f, comment.char = "#")), 3L)
  g <- withr::local_tempfile(fileext = ".tsv")
  yoytsv(yoychg(e, names(e)[2], "yr"), g)
  expect_identical(nrow(utils::read.delim(g, comment.char = "#")), 3L)
})

test_that("rptanl() escapes a pipe in a group label", {
  d <- data.frame(
    year = rep(2018:2020, 2),
    grp = rep(c("A|B", "C"), each = 3),
    n = c(5, 7, 9, 3, 4, 6)
  )
  md <- strsplit(rptanl(anytab(d, value = "n", prd = "year", by = "grp")),
                 "\n")[[1]]
  tab <- md[grepl("^\\|", md)][1:4]
  cells <- lengths(gregexpr("(?<!\\\\)\\|", tab, perl = TRUE))
  expect_identical(length(unique(cells)), 1L)
})

test_that("the HTML report escapes a label once", {
  d <- data.frame(
    year = rep(2018:2020, 2),
    grp = rep(c("A|B & C <i>", "D"), each = 3),
    n = c(5, 7, 9, 3, 4, 6)
  )
  h <- rptanl(
    anytab(d, value = "n", prd = "year", by = "grp"),
    withr::local_tempfile(fileext = ".html")
  )
  cell <- unique(regmatches(h, gregexpr("<td>A[^<]*</td>", h))[[1]])
  expect_identical(cell, "<td>A|B &amp; C &lt;i&gt;</td>")
})

test_that("a bundle whose file list holds no records is no bundle", {
  dir <- withr::local_tempdir()
  utils::write.csv(data.frame(x = 1:3), file.path(dir, "d.csv"))
  m <- mkmnf(list(dataset = "demo"), env = FALSE)
  p <- attr(cpsbndl(dir, m, "shared-secret"), "path")
  b <- fromjs(paste(readLines(p), collapse = "\n"), simplifyVector = FALSE)
  for (bad in list(list("d.csv"), 1, "x", list(list(path = 1)))) {
    b$files <- bad
    writeLines(tojs(b, auto_unbox = TRUE), p)
    expect_error(cpsbndlrd(p), "not a capsule bundle")
    expect_error(
      cpsbndlvrf(p, dir, man = m, key = "shared-secret"),
      "not a capsule bundle"
    )
  }
})

test_that("the archive client takes short rows and names the host it asked", {
  row <- list("org,example)/a", "20260101000000", "https://example.org/a",
              "text/plain", "200", "D", "20")
  out <- .bl_arc_rows(list(row), "http://x")
  expect_identical(out$url, "https://example.org/a")
  expect_identical(out$status, 200L)
  expect_true(is.na(out$capture_id))
  withr::local_envvar(MORIE_ARCHIVE_URL = "http://127.0.0.1:9")
  why <- .bl_arc_why(list(status = -1L, error = "refused", json = NULL), "x")
  expect_match(why, "127.0.0.1:9 did not answer", fixed = TRUE)
  local_mocked_bindings(
    .bl_arc_req = function(...) {
      list(status = 200L, json = NULL, body = "<html>", error = "")
    }
  )
  expect_error(
    arcget("20260101000000-0123abcd", withr::local_tempfile()),
    "no capture record"
  )
  expect_error(arcfind("https://example.org/a"), "no list of captures")
})
