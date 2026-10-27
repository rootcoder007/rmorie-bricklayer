# SPDX-License-Identifier: AGPL-3.0-or-later

test_that("row-wise and table-level rules report what fails", {
  d <- data.frame(age = c(30, -1, NA, 40), id = c(1, 2, 2, 3))
  rs <- list(
    rul("age_ok", function(v) v >= 0, col = "age"),
    rul("ids_unique", function(t) !anyDuplicated(t$id)),
    rul("absent", function(v) TRUE, col = "nope")
  )
  iss <- valrules(d, rs)
  expect_named(iss, c("age_ok", "ids_unique"))
  expect_identical(iss$age_ok$n_failed, 2L)
  expect_identical(iss$age_ok$rows, c(2L, 3L))
  expect_identical(iss$age_ok$message, "Rule 'age_ok' failed (2 of 4 rows)")
  expect_null(iss$ids_unique$rows)
})

test_that("a rule that errors or returns no logical is an issue, said", {
  d <- data.frame(x = 1:3)
  iss <- valrules(
    d,
    list(
      rul("boom", function(v) stop("bad"), col = "x"),
      rul("num", function(v) v * 2, col = "x")
    )
  )
  expect_match(iss$boom$message, "could not be evaluated: bad", fixed = TRUE)
  expect_match(iss$num$message, "returned numeric, not a logical", fixed = TRUE)
  expect_length(
    valrules(
      d[0L, , drop = FALSE],
      list(
        rul("pos", function(v) v > 0, col = "x")
      )
    ),
    0L
  )
})

test_that("a rule prints its name, severity and column", {
  expect_output(print(rul("r1", function(v) TRUE, col = "a")), "on `a`")
  expect_output(print(rul("r2", function(t) TRUE)), "table-level")
})

test_that("rul names col and msg", {
  f <- function() 1
  expect_error(rul("a", function(d) TRUE, col = f), "rul: `col` must be data")
  expect_error(rul("a", function(d) TRUE, msg = f), "rul: `msg` must be data")
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

test_that("a rule prints as a box", {
  r <- rul("r1", function(v) TRUE, col = "a")
  o1_expect_box(o1_box(r), r, "Rule r1", c("on `a`", "Severity"))
})
