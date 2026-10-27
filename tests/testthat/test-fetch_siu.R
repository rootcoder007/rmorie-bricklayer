# SPDX-License-Identifier: AGPL-3.0-or-later

test_that("siufetch() builds the report's address and hands it to blfetch()", {
  got <- new.env()
  local_mocked_bindings(blfetch = function(url, dest, wb, tmout) {
    got$url <- url
    got$dest <- dest
    invisible(dest)
  })
  f <- tempfile(fileext = ".html")
  siufetch(648, f)
  expect_identical(
    got$url,
    "https://www.siu.on.ca/en/directors_report_details.php?drid=648"
  )
  expect_identical(got$dest, f)
  siufetch("12", f, lang = "fr")
  expect_identical(
    got$url,
    "https://www.siu.on.ca/fr/directors_report_details.php?drid=12"
  )
})

test_that("a report number must be one positive whole number", {
  expect_identical(.rmbl_drid(5), 5L)
  expect_identical(.rmbl_drid("7"), 7L)
  for (bad in list(1.5, 0, -1, NA, TRUE, "x", c(1, 2), list(1), 1e10)) {
    expect_error(.rmbl_drid(bad), "one positive report number")
  }
  expect_error(siufetch(1, dest = NULL), "dest")
})
