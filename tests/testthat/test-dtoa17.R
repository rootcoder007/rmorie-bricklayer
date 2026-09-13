# The writer's half of "the reader is ours". sprintf("%.17g") asks the
# platform, and Windows aarch64 answers wrongly: it renders the largest
# double one ulp low, so the text reads back as a DIFFERENT double and
# eight round-trip assertions in test-attest.R and test-json-edges.R
# failed there while passing everywhere else. The digits now come from
# exact integer arithmetic in src/rmbl_strtod.cpp.

d17 <- function(x) .rmbl_dtoa17(x)

hard <- c(.Machine$double.xmax, .Machine$double.xmin, .Machine$double.eps,
          2^-1074, 5e-324, 1e-310, 1e300, 1e308, 1e-300, 1 / 3, pi, exp(1),
          1234567.891011, 0, -0, 1e16, 1e17, 1e15, 1e-4, 1e-5,
          0.1, 0.2, 0.3, 2^53, 2^53 + 2, -1e300, -0.1)

test_that("seventeen digits recover the double they came from", {
  # THE SUBSTANCE, and it holds on every IEEE platform because nothing
  # here consults the platform: the text this package writes reads back
  # as the same bits. A wrong digit anywhere fails this.
  set.seed(20260913)
  bits <- vapply(seq_len(4000), function(i)
    readBin(as.raw(sample(0:255, 8, TRUE)), "double", 1L, 8L), numeric(1))
  v <- c(hard, bits[is.finite(bits)])
  back <- .rmbl_strtod(d17(v))
  expect_identical(back, v)
})

test_that("the named extremes get their known decimals", {
  expect_identical(d17(.Machine$double.xmax), "1.7976931348623157e+308")
  expect_identical(d17(1e300), "1.0000000000000001e+300")
  expect_identical(d17(0), "0")
  expect_identical(d17(-0), "-0")
  expect_identical(d17(1), "1")
  expect_identical(d17(-1.5), "-1.5")
  # %g switches to scientific outside [-4, 17)
  expect_identical(d17(1e16), "10000000000000000")
  expect_identical(d17(1e17), "1e+17")
  expect_identical(d17(1e-4), "0.0001")
  expect_identical(d17(1e-5), "1.0000000000000001e-05")
  expect_identical(d17(c(NA_real_, Inf, -Inf, NaN)),
                   rep(NA_character_, 4L))
})

test_that("the layout is the platform's wherever the platform is right", {
  # Not a comparison of the package to itself: sprintf is an INDEPENDENT
  # implementation, and this asserts agreement only on the values it
  # actually gets right, which is every value on a correct library and
  # most of them even on a broken one. It is what keeps the %g layout
  # (trailing zeros, exponent width, the fixed/scientific switch) honest.
  set.seed(7)
  bits <- vapply(seq_len(4000), function(i)
    readBin(as.raw(sample(0:255, 8, TRUE)), "double", 1L, 8L), numeric(1))
  v <- c(hard, bits[is.finite(bits)])
  plat <- sprintf("%.17g", v)
  trustworthy <- !is.na(.rmbl_strtod(plat)) & .rmbl_strtod(plat) == v
  expect_gt(sum(trustworthy), 0L)
  expect_identical(d17(v)[trustworthy], plat[trustworthy])
})

test_that("a vendored bundle with no compiled library still writes numbers", {
  # json_native.R is vendored standalone into the otis-mrp bundle, where
  # C_rmbl_dtoa17 does not exist. That must degrade to the platform, not
  # error -- the same trap that broke the bundle with C_rmbl_strtod.
  env <- new.env(parent = asNamespace("rmoriebricklayer"))
  local({
    .rmbl_native <- new.env(parent = emptyenv())
    fn <- get(".rmbl_dtoa17", envir = asNamespace("rmoriebricklayer"))
    environment(fn) <- list2env(
      list(.rmbl_native = .rmbl_native,
           exists = function(...) FALSE),
      parent = asNamespace("rmoriebricklayer"))
    expect_identical(fn(1.5), "1.5")
    expect_identical(fn(.Machine$double.xmax), sprintf("%.17g", .Machine$double.xmax))
  }, envir = env)
})
