# SPDX-License-Identifier: AGPL-3.0-or-later

test_that("mksyncol draws each column type", {
  set.seed(1)
  s <- mksyncol(list(type = "sample", values = list("a", "b")), 20)
  expect_length(s, 20L)
  expect_true(all(s %in% c("a", "b")))
  b <- mksyncol(list(type = "bernoulli", p = 0.5, labels = list("Y", "N")), 30)
  expect_true(all(b %in% c("Y", "N")))
  expect_true(all(
    mksyncol(list(type = "bernoulli", p = 1), 5, basep = rep(0, 5)) == "Yes"
  ))
  expect_true(all(
    mksyncol(list(type = "bernoulli", p = 0), 5) == "No"
  ))
  p <- mksyncol(list(type = "poisson", lambda = 2, min = 1), 50)
  expect_gte(min(p), 1)
  expect_identical(
    mksyncol(list(type = "id_pattern", pattern = "c-{seq:05d}"), 3),
    c("c-00001", "c-00002", "c-00003")
  )
  expect_identical(
    unname(mksyncol(
      list(type = "id_pattern", pattern = "{year}-{seq:05d}", year_col = "y"),
      3,
      ctx = list(y = c(2024, 2024, 2025))
    )),
    c("2024-00001", "2024-00002", "2025-00001")
  )
  expect_identical(
    mksyncol(list(type = "sequence", from = 10L), 3),
    10:12
  )
})

test_that("mksyncol draws from a fitted distribution and refuses a bad fit", {
  set.seed(2)
  f <- dstfit(stats::rexp(200, 2), fams = "exponential", nboot = 0)
  x <- mksyncol(list(type = "fitted", fit = f), 10)
  expect_length(x, 10L)
  expect_true(all(x > 0))
  expect_error(
    mksyncol(list(type = "fitted", fit = list()), 3),
    "needs `fit`, a dstfit"
  )
  expect_error(
    mksyncol(list(type = "fitted", fit = f, family = "gamma"), 3),
    "no converged gamma family"
  )
  expect_error(mksyncol(list(type = "nope"), 3), "Unknown synthetic column")
  expect_error(mksyncol("x", 3), "must be a column spec list")
})

test_that("mksyncsv writes the CSV and its marker, keeping the caller's RNG", {
  # mksyncsv() flags the session as synthetic; later tests start unflagged
  st <- .rmbl_synth_state
  made <- st$made
  withr::defer({
    st$made <- made
  })
  recipe <- list(
    n_rows = 8,
    seed = 42,
    columns = list(
      year = list(type = "sample", values = list(2024, 2025)),
      alert = list(type = "bernoulli", p = 0.2),
      id = list(type = "id_pattern", pattern = "p-{seq:05d}")
    )
  )
  out <- tempfile(fileext = ".csv")
  set.seed(7)
  before <- .Random.seed
  res <- mksyncsv(recipe, out)
  expect_identical(.Random.seed, before)
  expect_s3_class(res, "bricklayer_synthetic")
  expect_identical(res$rows, 8L)
  expect_identical(res$seed, 42)
  expect_true(file.exists(res$sidecar))
  df <- utils::read.csv(out)
  expect_named(df, c("year", "alert", "id"))
  # the same recipe and seed give the same file
  out2 <- tempfile(fileext = ".csv")
  mksyncsv(recipe, out2)
  expect_identical(readLines(out), readLines(out2))
  expect_identical(mksyncsv(recipe, tempfile(), nrows = 3)$rows, 3L)
  side <- readLines(res$sidecar)
  expect_true(any(grepl("\"synthetic\": true", side, fixed = TRUE)))
  expect_match(format(res)[1L], "SYNTHETIC data")
  expect_output(print(res), "SYNTHETIC data")
  expect_error(mksyncsv("not a recipe", tempfile()), "must be a schema list")
})

test_that("the marker file escapes a quote in its strings", {
  out <- tempfile(fileext = ".csv")
  side <- .syn_sidecar(out, 3L, 1, "a\"b")
  expect_true(any(
    readLines(side) == "  \"recipe_sha256\": \"a\\\"b\","
  ))
  expect_true(any(
    readLines(.syn_sidecar(out, 3L, 1, NA)) == "  \"recipe_sha256\": null,"
  ))
})

# ---- boxed printouts ---------------------------------------------------------

# print() of a result in an 80-column ASCII console: the lines, whether the
# value was visible, and the value.
.o2_box <- function(x, ...) {
  withr::local_options(rmoriebricklayer.width = 80, rmoriebricklayer.numcol = 1)
  withr::local_envvar(RMBL_ASCII_ONLY = "1")
  out <- utils::capture.output({
    r <- withVisible(print(x, ...))
  })
  list(out = out, vis = r$visible, value = r$value)
}

# The checks every boxed printout passes: an ASCII box under its title, no
# line past the console, print() returning its argument invisibly, format()
# giving character lines that hold the facts.
.o2_check <- function(x, title, facts = character(0)) {
  b <- .o2_box(x)
  testthat::expect_false(b$vis)
  testthat::expect_identical(b$value, x)
  testthat::expect_true(startsWith(b$out[1L], paste0("+-- ", title, " -")))
  testthat::expect_match(b$out[length(b$out)], "^\\+-+\\+$")
  testthat::expect_true(all(nchar(b$out) <= 80L))
  txt <- format(x)
  testthat::expect_type(txt, "character")
  # the text with the box and the wrapping taken out, for phrases
  flat <- gsub("[| ]+", " ", paste(b$out, collapse = " "))
  for (f in facts) {
    testthat::expect_true(grepl(f, flat, fixed = TRUE), info = f)
  }
  invisible(b$out)
}

test_that("a synthetic file's record prints as a box", {
  # mksyncsv() flags the session as synthetic; later tests start unflagged
  st <- .rmbl_synth_state
  made <- st$made
  withr::defer({
    st$made <- made
  })
  f <- withr::local_tempfile(fileext = ".csv")
  s <- mksyncsv(
    list(columns = list(a = list(type = "poisson", lambda = 2))),
    f,
    nrows = 5,
    seed = 1
  )
  .o2_check(s, "SYNTHETIC data (generated from a recipe, not fetched)",
    c("Sidecar", "Recipe sha256"))
})

test_that("a synthetic record sourced on its own prints without the box", {
  # in a capsule bundle the file is sourced alone: no box helpers beside it
  alone <- function(f) {
    keep <- c(
      "{", "(", "<-", "if", "!", "exists", "return", "c", "sprintf", "$",
      "format", "format.default", "substr", "cat", "invisible", "::", ":::"
    )
    environment(f) <- list2env(
      mget(keep, envir = baseenv()),
      parent = emptyenv()
    )
    f
  }
  x <- structure(
    list(
      path = "a.csv", sidecar = "a.csv.synthetic.json", rows = 5L,
      seed = 1, recipe_sha256 = strrep("ab", 32L)
    ),
    class = c("bricklayer_synthetic", "list")
  )
  out <- alone(format.bricklayer_synthetic)(x)
  expect_identical(out, c(
    "SYNTHETIC data (generated from a recipe, not fetched)",
    "  file    a.csv",
    "  sidecar a.csv.synthetic.json",
    "  rows 5, seed 1, recipe sha256 abababababababab"
  ))
  pr_alone <- alone(print.bricklayer_synthetic)
  res <- NULL
  pr <- utils::capture.output({
    res <- pr_alone(x)
  })
  expect_identical(res, x)
  expect_true(any(grepl("Recipe sha256", pr, fixed = TRUE)))
})
