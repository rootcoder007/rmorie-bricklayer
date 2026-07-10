# SPDX-License-Identifier: AGPL-3.0-or-later
# Synthetic-column generators and the CSV writer: type behaviour,
# determinism, RNG-state hygiene, row replication, core_normal_pdf.

test_that("make_synthetic_column honours each documented type", {
  set.seed(1)
  s <- make_synthetic_column(list(type = "sample", values = c("a", "b")), 50)
  expect_true(all(s %in% c("a", "b")))

  b <- make_synthetic_column(
    list(type = "bernoulli", p = 1, labels = c("Yes", "No")), 20
  )
  expect_true(all(b == "Yes"))

  p <- make_synthetic_column(list(type = "poisson", lambda = 2, min = 1), 200)
  expect_true(all(p >= 1))

  ids <- make_synthetic_column(
    list(type = "id_pattern", pattern = "case-{seq:05d}"), 3
  )
  expect_identical(ids, c("case-00001", "case-00002", "case-00003"))

  yr_ctx <- list(fy = c(2024, 2024, 2025))
  ids_yr <- make_synthetic_column(
    list(type = "id_pattern", pattern = "{year}-{seq:05d}", year_col = "fy"),
    3, ctx = yr_ctx
  )
  expect_identical(ids_yr, c("2024-00001", "2024-00002", "2025-00001"))

  sq <- make_synthetic_column(list(type = "sequence", from = 5L), 3)
  expect_identical(sq, 5:7)

  expect_error(make_synthetic_column(list(type = "no-such-type"), 3))
})

test_that("make_synthetic_csv is deterministic and restores the caller RNG state", {
  schema <- list(
    seed = 42L, n_rows = 25L,
    columns = list(
      fy = list(type = "sample", values = list(2024L, 2025L)),
      id = list(type = "id_pattern", pattern = "{year}-{seq:05d}", year_col = "fy"),
      alert = list(type = "bernoulli", p = 0.4, labels = list("Yes", "No"))
    )
  )
  f1 <- tempfile(fileext = ".csv")
  f2 <- tempfile(fileext = ".csv")

  set.seed(999)
  before <- .Random.seed
  info <- make_synthetic_csv(schema, f1)
  expect_identical(.Random.seed, before)

  make_synthetic_csv(schema, f2)
  expect_identical(sha256_file(f1), sha256_file(f2))
  expect_identical(info$rows, 25L)
  expect_identical(info$seed, 42L)

  df <- utils::read.csv(f1, stringsAsFactors = FALSE)
  expect_identical(names(df), c("fy", "id", "alert"))
  expect_true(all(df$alert %in% c("Yes", "No")))
})

test_that("make_synthetic_csv row_replication expands person rows", {
  schema <- list(
    seed = 7L, n_rows = 10L,
    row_replication = list(values = list(2L), weights = list(1)),
    columns = list(
      region = list(type = "sample", values = list("East", "West"))
    )
  )
  f <- tempfile(fileext = ".csv")
  info <- make_synthetic_csv(schema, f)
  expect_identical(info$rows, 20L)
})

test_that("core_normal_pdf agrees with stats::dnorm", {
  x <- c(-2, -0.5, 0, 1.7)
  expect_equal(core_normal_pdf(x), stats::dnorm(x), tolerance = 1e-12)
  expect_equal(core_normal_pdf(x, mean = 3, sd = 2),
               stats::dnorm(x, 3, 2), tolerance = 1e-12)
})

