# SPDX-License-Identifier: AGPL-3.0-or-later
#
# siuprs(): its argument checks, a saved report read by path, and several
# reports at once.

test_that("siuprs() refuses what is not report text", {
  expect_error(siuprs(character()), "not an empty vector")
  expect_error(siuprs(NA_character_), "not NA")
  expect_error(siuprs(1), "not numeric")
  expect_error(
    siuprs(file.path(tempdir(), "no-such-report.html")),
    "no such file"
  )
})

test_that("siuprs() reads a saved report and one row per report", {
  en <- paste0(
    "<html><body><h2>The Investigation</h2><p>Mandate ",
    "engaged</p><p>Witness Officers</p>",
    "<p>Fifteen SIU investigators and 14 forensic investigators were ",
    "dispatched.</p></body></html>"
  )
  f <- withr::local_tempfile(fileext = ".html")
  writeLines(en, f)
  r <- siuprs(f)
  expect_identical(r, siuprs(en))
  expect_identical(unname(r[["siu_forensics_investigators"]]), "14")
  two <- siuprs(c(en, en))
  expect_s3_class(two, "data.frame")
  expect_identical(nrow(two), 2L)
  expect_identical(two$siu_forensics_investigators, c("14", "14"))
})

test_that("siuso() reads a French plural cue given as a number", {
  r <- siuso(paste(
    "3 agents impliqu\u00e9s ont \u00e9t\u00e9 d\u00e9sign\u00e9s",
    "dans cette affaire."
  ))
  expect_identical(r$count, 3L)
  expect_match(r$reason, "plural cue", fixed = TRUE)
})
