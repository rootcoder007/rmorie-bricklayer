# SPDX-License-Identifier: AGPL-3.0-or-later
# Dashboard helpers no other test reached: they build tags, no app runs.

test_that("the headline of a drift that moved no column", {
  d <- data.frame(id = 1:40, v = c(1:20, 1:20))
  dr <- cpsdrft(d, d)
  expect_false(dr$anydrft)
  expect_identical(
    .bl_hl_verdict(dr, NULL, NULL, NULL, NULL, NULL),
    list(verdict = "No column drifted", good = FALSE)
  )
})

test_that("the capsule value boxes say Failed when a check failed", {
  skip_if_not_installed("bslib")
  vb <- .bl_cps_vbox(
    data.frame(status = c("pass", "FAIL"), stringsAsFactors = FALSE),
    list(
      prov = data.frame(
        field = "resource.filename",
        value = "f.csv",
        stringsAsFactors = FALSE
      ),
      files = NULL
    )
  )
  h <- as.character(vb)
  expect_match(h, "Failed", fixed = TRUE)
  expect_match(h, "1 of 2", fixed = TRUE)
  expect_false(grepl("Verified", h, fixed = TRUE))
})

test_that("a ledger row with no repository link shows the place as text", {
  skip_if_not_installed("shiny")
  th <- list(
    id = "T1",
    status = "proved",
    sorry_count = 0L,
    statement = "x = x",
    file = "a.lean",
    line = 3L,
    covers = list()
  )
  h <- as.character(.bl_ldgr_row(th, list(repo = "not a repo", commit = "abc")))
  expect_match(h, "<td>a.lean:3</td>", fixed = TRUE)
  expect_false(grepl("<a ", h, fixed = TRUE))
})

test_that("a report section with no plot has an empty figure", {
  f <- tempfile(fileext = ".html")
  s <- .bl_rpt_section(
    list(title = "T<1>", code = "x <- 1", text = "out", svg = NULL, yoy = NULL),
    1L,
    f
  )
  expect_identical(
    s,
    paste0(
      "<section><h2>T&lt;1&gt;</h2><pre><code>x &lt;- 1</code></pre>",
      "<pre>out</pre><figure></figure></section>"
    )
  )
})

test_that("the search panel's inputs are numeric inputs", {
  skip_if_not_installed("shiny")
  h <- as.character(.bl_srch_ui("srch"))
  expect_match(h, "type=\"number\"", fixed = TRUE)
  expect_match(h, "id=\"srch-", fixed = TRUE)
})
