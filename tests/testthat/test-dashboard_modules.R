# SPDX-License-Identifier: AGPL-3.0-or-later

test_that("check rows get a status word, in the order of the chain", {
  rows <- data.frame(
    ok = c(TRUE, FALSE, FALSE, FALSE),
    severity = c("error", "note", "warn", "error"),
    check = c("a", "b", "c", "d"),
    stringsAsFactors = FALSE
  )
  st <- .bl_status_rows(rows)
  expect_identical(st$status, c("pass", "note", "warn", "FAIL"))
  expect_identical(st$part, rep("", 4L))
  expect_named(st, c("status", "part", "check", "severity", "detail"))
  none <- .bl_status_rows(rows[0L, ])
  expect_identical(nrow(none), 0L)
})

test_that("a nested list becomes field and value rows", {
  f <- .bl_fields(list(a = 1, b = list(c = "x", d = c(1, 2))))
  expect_identical(f$field, c("a", "b.c", "b.d"))
  expect_identical(f$value, c("1", "x", "1, 2"))
})

test_that("a ledger link points at the commit, or there is none", {
  t <- list(file = "Rmorie/Gini.lean", line = 42)
  expect_identical(
    .bl_ldgr_link(list(repo = "o/r", commit = "abc"), t),
    "https://github.com/o/r/blob/abc/Rmorie/Gini.lean#L42"
  )
  expect_identical(
    .bl_ldgr_link(list(repo = "https://x.org/o/r.git/", commit = "1"), t),
    "https://x.org/o/r/blob/1/Rmorie/Gini.lean#L42"
  )
  expect_null(.bl_ldgr_link(list(repo = "a b c", commit = "1"), t))
})

test_that("the installed ledgers are listed by package and file", {
  d <- withr::local_tempdir()
  file.create(file.path(d, c("one.json", "two.txt")))
  got <- .bl_ldgr_installed(
    c("p", "q"),
    find = function(p) if (p == "p") d else ""
  )
  expect_named(got, "p: one.json")
  expect_identical(basename(unname(got)), "one.json")
})
