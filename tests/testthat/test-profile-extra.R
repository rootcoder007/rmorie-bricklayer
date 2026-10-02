# One-row frames and negative correlations in the profiling helpers.

test_that("missingness_pattern handles a one-row frame", {
  p <- missingness_pattern(data.frame(a = NA, b = 1))
  expect_identical(nrow(p), 1L)
  expect_identical(p$n_missing, 1L)
})

test_that("a negative correlation prints its bar to the left", {
  d <- data.frame(x = 1:10, y = -(1:10) + c(0.1, 0, 0.2, 0, 0.1, 0, 0.3, 0, 0.1, 0), z = (1:10)^2)
  out <- capture.output(print(top_correlations(d, n = 3L)))
  expect_true(any(grepl("#|", out, fixed = TRUE)))
  expect_true(any(grepl("|#", out, fixed = TRUE)))
})
