# SPDX-License-Identifier: AGPL-3.0-or-later

test_that("infsch() learns columns, types, ranges and value sets", {
  d <- data.frame(
    n = c(1, 5, 10),
    g = c("a", "b", "a"),
    k = c(2, 2, 2),
    stringsAsFactors = FALSE
  )
  s <- infsch(d, slack = 0.1)
  expect_s3_class(s, "bricklayer_schema")
  expect_identical(s$expected_columns, c("n", "g", "k"))
  expect_identical(
    unname(s$expected_types),
    c("numeric", "character", "numeric")
  )
  expect_equal(s$numeric_ranges$n, c(min = 0.1, max = 10.9), tolerance = 1e-12)
  expect_equal(s$numeric_ranges$k, c(min = 1.8, max = 2.2), tolerance = 1e-12)
  expect_identical(s$expected_value_sets$g, c("a", "b"))
  expect_identical(s$structural_invariants$min_data_rows, 2L)
  expect_identical(s$structural_invariants$max_data_rows, 4L)
  expect_named(s$max_missing_fraction, c("n", "g", "k"))
})

test_that("a column with too many levels gets no value set", {
  d <- data.frame(g = letters[1:6], stringsAsFactors = FALSE)
  expect_null(infsch(d, maxlvl = 5)$expected_value_sets$g)
  out <- format(infsch(data.frame(g = letters[1:6]), maxlvl = 10))
  expect_true(any(grepl("(6 levels)", out, fixed = TRUE)))
})

test_that("infsch() refuses what it cannot learn from", {
  expect_error(infsch(1:3), "must be a data frame")
  expect_error(infsch(data.frame()), "no columns")
  expect_error(infsch(data.frame(a = 1), slack = -1), "non-negative")
  expect_error(infsch(data.frame(a = 1), maxlvl = 0), "positive integer")
})

# Prints `x` on an ASCII console: the lines and what print() returned.
o1_box <- function(x, ...) {
  withr::local_envvar(RMBL_ASCII_ONLY = "1")
  tmp <- withr::local_tempfile()
  v <- withr::with_output_sink(tmp, withVisible(print(x, ...)))
  list(out = readLines(tmp), v = v)
}

# The box's frame, its title and the facts expected in it.
o1_expect_box <- function(b, x, title, facts = character()) {
  expect_false(b$v$visible)
  expect_identical(b$v$value, x)
  expect_match(b$out[1L], "^\\+-- ")
  expect_true(grepl(title, b$out[1L], fixed = TRUE))
  expect_match(b$out[length(b$out)], "^\\+-+\\+$")
  for (f in facts) {
    expect_true(any(grepl(f, b$out, fixed = TRUE)), info = f)
  }
}

test_that("an inferred schema prints as a box", {
  s <- infsch(data.frame(
    g = c("a", "b"),
    x = c(1, 2),
    stringsAsFactors = FALSE
  ))
  o1_expect_box(o1_box(s), s, "Inferred schema", c("Columns", "valsch()"))
})
