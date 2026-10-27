# One-row frames and negative correlations in the profiling helpers.

test_that("misspat handles a one-row frame", {
  p <- misspat(data.frame(a = NA, b = 1))
  expect_identical(nrow(p), 1L)
  expect_identical(p$n_missing, 1L)
})

test_that("a negative correlation prints its bar to the left", {
  d <- data.frame(
    x = 1:10,
    y = -(1:10) + c(0.1, 0, 0.2, 0, 0.1, 0, 0.3, 0, 0.1, 0),
    z = (1:10)^2
  )
  out <- capture.output(print(topcors(d, n = 3L)))
  expect_true(any(grepl("#|", out, fixed = TRUE)))
  expect_true(any(grepl("|#", out, fixed = TRUE)))
})

test_that("envdiff reports a field present in one record only", {
  d <- envdiff(list(a = 1), list(a = 1, b = 2))
  expect_false(d$identical)
  expect_identical(d$fields, "b")
  expect_output(print(d), "other fields")
  x <- capenv("stats")
  y <- x
  y$captured_utc <- "1999-01-01T00:00:00Z"
  expect_true(envdiff(x, y)$identical)
  expect_identical(envdiff(x, y)$fields, character(0))
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

test_that("missingness, correlations and environment diffs print as boxes", {
  d <- data.frame(a = c(1, NA, 3, 4), b = c(NA, NA, 3, 1), c = 1:4)
  s <- misspat(d)
  o1_expect_box(o1_box(s), s, "Missingness patterns", c("pattern", "a, b, c"))
  tc <- topcors(d, minabs = 0)
  o1_expect_box(o1_box(tc), tc, "Top correlations", "Pairs")
  none <- topcors(data.frame(p = 1:4, q = c(2, 1, 4, 3)), minabs = 0.99)
  expect_true(any(grepl("none above", format(none), fixed = TRUE)))
  e <- envdiff(list(r_version = "4.4.0"), list(r_version = "4.5.0"))
  o1_expect_box(o1_box(e), e, "Environment diff", "4.4.0 -> 4.5.0")
  expect_identical(.bl_cor_bar(-0.2), paste0(strrep(" ", 8), "##|",
    strrep(" ", 10)))
})

test_that("a missingness table without its columns prints plainly", {
  expect_plain_df("bricklayer_missingness")
})
