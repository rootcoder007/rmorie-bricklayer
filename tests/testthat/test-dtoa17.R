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
  # The inputs are transported as bit patterns, NOT written as decimal
  # literals. A literal in this file is parsed by the platform's strtod,
  # and macOS arm64's loses low bits above about 1e100 -- the very bug
  # src/rmbl_strtod.cpp exists to route around. Written as `1e300` this
  # test asserted the wrong thing there: the platform handed over a
  # different double, the converter rendered THAT double correctly as
  # ...0006e+300, and the assertion failed against a value macOS never
  # had. The expectations below are the exact seventeen-digit decimals,
  # computed by exact rational arithmetic, of the doubles named by these
  # byte patterns.
  dbl <- function(hex)
    readBin(as.raw(strtoi(substring(hex, seq(1L, 15L, 2L), seq(2L, 16L, 2L)),
                          16L)), "double", n = 1L, size = 8L,
            endian = "little")

  expect_identical(d17(dbl("9c7500883ce4377e")), "1.0000000000000001e+300")
  expect_identical(d17(dbl("0080e03779c34143")), "10000000000000000")
  expect_identical(d17(dbl("00a0d88557347643")), "1e+17")
  expect_identical(d17(dbl("2d431cebe2361a3f")), "0.0001")
  expect_identical(d17(dbl("f168e388b5f8e43e")), "1.0000000000000001e-05")
  expect_identical(d17(dbl("9a9999999999b93f")), "0.10000000000000001")

  # These are exact in binary, or built by R rather than parsed, so no
  # reader can disagree about them.
  expect_identical(d17(.Machine$double.xmax), "1.7976931348623157e+308")
  expect_identical(d17(0), "0")
  expect_identical(d17(-0), "-0")
  expect_identical(d17(1), "1")
  expect_identical(d17(-1.5), "-1.5")
  expect_identical(d17(c(NA_real_, Inf, -Inf, NaN)), rep(NA_character_, 4L))
})

test_that("the digits match an independent exact computation", {
  # This replaces a comparison against sprintf, which was not sound: at
  # seventeen significant digits MORE THAN ONE decimal string maps to the
  # same double, so "the platform's text round-trips" does not imply "the
  # platform's text is correctly rounded". Windows x86_64 emits strings
  # that round-trip but are not correctly rounded, and this package's --
  # correctly rounded -- legitimately differed, which failed the old test
  # for the wrong reason.
  #
  # The table below is an independent authority instead: each expected
  # string was computed offline from the EXACT rational value of the
  # double by Python's decimal module, then laid out by the %.17g rules.
  # No C library is consulted at any point, here or there, so it can fail.
  dbl <- function(hex)
    readBin(as.raw(strtoi(substring(hex, seq(1L, 15L, 2L), seq(2L, 16L, 2L)),
                          16L)), "double", n = 1L, size = 8L,
            endian = "little")
  cases <- rbind(
    c("9c7500883ce4377e", "1.0000000000000001e+300"),
    c("59f3f8c21f6ea501", "1e-300"),
    c("0080e03779c34143", "10000000000000000"),
    c("00a0d88557347643", "1e+17"),
    c("2d431cebe2361a3f", "0.0001"),
    c("f168e388b5f8e43e", "1.0000000000000001e-05"),
    c("9a9999999999b93f", "0.10000000000000001"),
    c("9a9999999999c93f", "0.20000000000000001"),
    c("555555555555d53f", "0.33333333333333331"),
    c("182d4454fb210940", "3.1415926535897931"),
    c("6957148b0abf0540", "2.7182818284590451"),
    c("014c19e487d63241", "1234567.8910109999"),
    c("0100000000000000", "4.9406564584124654e-324"),
    c("0000000000001000", "2.2250738585072014e-308"),
    c("ffffffffffffef7f", "1.7976931348623157e+308"),
    c("9c7500883ce437fe", "-1.0000000000000001e+300"),
    c("9a9999999999b9bf", "-0.10000000000000001"),
    c("00000054346f9d41", "123456789"),
    c("48afbc9af2d77a3e", "9.9999999999999995e-08"),
    c("f64ae1c7022db544", "9.9999999999999992e+22"),
    c("9693c9dcff66edf2", "-4.0152112842841951e+245"),
    c("68e76a6a02deba21", "3.3619009816731713e-146"),
    c("719648074f90d89d", "-6.6649404493585431e-165"),
    c("0e54e86370dd0261", "2.0720701071819464e+159"),
    c("8d4f2c5286e46d46", "1.8946733434113611e+31"),
    c("5246562f57acfa83", "-1.7106430142317635e-289"),
    c("81e35f7e87f02006", "3.7328139556498916e-279"),
    c("0be54cd0439a1b78", "3.6455752936780224e+270"),
    c("4f2d4a28fc7fe427", "1.6258643392515954e-116"),
    c("6e01e4923b7d5dc3", "-33201876582270392"),
    c("1e0303ac604df779", "3.304562491689226e+279"),
    c("6ec6b11e8edfe706", "2.1547939443644499e-275"),
    c("b773742008f77a81", "-1.5728389612277301e-301"),
    c("bcde5e24b8e4092e", "6.5082005246653052e-87"),
    c("38bc3e5623a2071f", "3.3619993130805698e-159"),
    c("cc8ee32b8439c0b7", "-3.7250022433914927e-40"),
    c("84a2db3ca97517dd", "-2.7936941065457046e+140"),
    c("27d544b0efd9d591", "-9.4454089800808447e-223"),
    c("475b19ab7ef214a1", "-2.5597000559836064e-149"),
    c("943ed43ba2408fe8", "-4.5628020344463799e+195"),
    c("dbd31072a030a00f", "2.0367551750215806e-233"),
    c("ce62a4e9371f3746", "1.8319093673963964e+30"),
    c("6a272256ee0a0901", "1.1411835984623888e-303"),
    c("6ee3a7512b3929e4", "-3.1192465903441063e+174")
  )
  for (i in seq_len(nrow(cases))) {
    v <- dbl(cases[i, 1L])
    expect_identical(d17(v), cases[i, 2L], info = cases[i, 1L])
  }
})

test_that("the layout follows the %.17g rules", {
  set.seed(99)
  bits <- vapply(seq_len(2000), function(i)
    readBin(as.raw(sample(0:255, 8, TRUE)), "double", n = 1L, size = 8L),
    numeric(1))
  v <- bits[is.finite(bits) & bits != 0]
  s <- d17(v)
  sci <- grepl("e", s, fixed = TRUE)
  # scientific exactly when the decimal exponent leaves [-4, 17)
  x <- as.integer(sub(".*e", "", s[sci]))
  expect_true(all(x < -4L | x >= 17L))
  # the exponent always carries at least two digits, with a sign
  expect_true(all(grepl("e[+-][0-9]{2,}$", s[sci])))
  # a fraction never ends in a zero, and a bare integer never gains a point
  frac <- grepl(".", s, fixed = TRUE)
  expect_false(any(grepl("0$", sub("e.*", "", s[frac]))))
  expect_false(any(grepl("\\.$", s)))
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
