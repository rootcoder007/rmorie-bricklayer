# Lines of 1.0.0 in src/ the suite had not reached (codecov of 186bc3ef), each through the registered
# entry point it sits behind: argument refusals, an unreadable upload, the closed forms of the Hurwitz
# zeta at the non-positive integers, an overflowing mean, a P-521 digest longer than the order, an XMSS
# index past the tree, decimal ties, and a French cue. Each test names the lines it reaches.

.nat_hex <- function(h) as.raw(strtoi(substring(h, seq(1L, nchar(h), 2L), seq(2L, nchar(h), 2L)), 16L))

test_that("the PUT transport says so when the file to upload cannot be opened", {
  # reaches http_put_file's "cannot open the file to upload" (src/rmbl_fetch.cpp), before any network
  r <- .Call(C_rmbl_http_put, "https://example.org/x", file.path(withr::local_tempdir(), "none"), "text/plain",
             5L, character(), FALSE)
  expect_identical(r$status, -1L)
  expect_identical(r$error, "cannot open the file to upload")
  # reaches C_rmbl_http_put_impl's refusal of a content type that is not one string
  expect_error(.Call(C_rmbl_http_put, "https://example.org/x", "f", 1, 5L, character(), FALSE),
               "`content_type` must be a single string")
})

test_that("the native Hurwitz zeta at s = 0, -1, ..., -5 is the Bernoulli polynomial, and NA elsewhere", {
  # reaches hurwitz_zeta_scalar's closed form, every case of its switch, and its NA below s = 1, in the
  # series kernels of rmbl_series.cpp
  q <- 0.3
  bern <- list(function(q) q - 0.5, function(q) q^2 - q + 1 / 6, function(q) q^3 - 1.5 * q^2 + 0.5 * q,
               function(q) q^4 - 2 * q^3 + q^2 - 1 / 30,
               function(q) q^5 - 2.5 * q^4 + 5 / 3 * q^3 - q / 6,
               function(q) q^6 - 3 * q^5 + 2.5 * q^4 - 0.5 * q^2 + 1 / 42)
  for (n in 0:5) {
    expect_equal(.Call(C_rmbl_hurwitz_zeta, as.numeric(-n), q), -bern[[n + 1L]](q) / (n + 1), tolerance = 1e-14)
  }
  expect_equal(.Call(C_rmbl_hurwitz_zeta, -1, 1), -1 / 12)
  expect_true(is.na(.Call(C_rmbl_hurwitz_zeta, 0.5, 1)))
  expect_true(is.na(.Call(C_rmbl_hurwitz_zeta, -0.5, 1)))
  expect_true(is.na(.Call(C_rmbl_hurwitz_zeta, 2, -1)))
})

test_that("the native top share is NA for a fraction outside [0, 1] and for a zero total", {
  # reaches C_rmbl_top_share_impl's NA share and NA count (src/rmbl_series.cpp)
  r <- .Call(C_rmbl_top_share, c(1, 2, 3), c(0.5, NA, -0.1, 1.5))
  expect_equal(r[[1]], c(5 / 6, NA, NA, NA))
  expect_identical(r[[2]], c(2L, NA, NA, NA))
  z <- .Call(C_rmbl_top_share, c(0, 0), 0.5)
  expect_true(is.na(z[[1]]) && is.na(z[[2]]))
})

test_that("the native mean of values whose sum overflows is the running mean", {
  # reaches morie::core::mean's fall back to mean_running when the sum is not finite (src/morie_core.h)
  expect_identical(.Call(C_rmbl_mean, c(1e308, 1e308, 1e308)), 1e308)
  expect_equal(.Call(C_rmbl_mean, c(1.5e308, 1.7e308)), 1.6e308)
})

test_that("the native correlation refuses vectors of two lengths, and an R error leaves the barrier sound", {
  # reaches C_rmbl_cor_impl's length refusal (src/rmbl_core.cpp)
  expect_error(.Call(C_rmbl_cor, 1:3, 1:2), "x and y must have the same length")
  # reaches rmbl_unwound (src/rmbl_barrier.cpp): an R error inside the body (a list cannot be coerced)
  # unwinds the barrier, which puts its depth and flag back
  expect_error(.Call(C_rmbl_cor, list(1:2), 1), "cannot be coerced")
  expect_equal(.Call(C_rmbl_cor, c(1, 2, 3), c(2, 4, 7)), stats::cor(c(1, 2, 3), c(2, 4, 7)))
})

test_that("the projected BFGS with no gradient tolerance stops when its line search fails twice", {
  # reaches hawkes_fit_pbfgs's line-search failure (src/morie_core.h): a first failure resets the
  # matrix and tries again, a second ends the fit
  t <- withr::with_seed(1, sort(stats::runif(200, 0, 100)))
  b <- .rmbl_hk_bounds("exponential", "constant")
  x0 <- .rmbl_hk_x0("exponential", "constant", 200, 100, mean(diff(t)))
  fit <- function(gtol) {
    .Call(C_rmbl_hawkes_fit_pbfgs, t, 100, 0L, 0L, 0L, 1e-9, 100, 1e-6, b$lower, b$upper, x0, 2000L, gtol)
  }
  r0 <- fit(1e-6)
  r1 <- fit(0)
  expect_lt(r1[[5]], 2000)
  expect_equal(r1[[4]], r0[[4]], tolerance = 1e-8)
  expect_lte(r1[[4]], r0[[4]])
})

test_that("P-521 verification takes the leftmost 521 bits of a digest longer than the order", {
  # reaches C_rmbl_ecdsa_verify_impl's right shift of the excess bits (src/rmbl_ecdsa.cpp). With the
  # key Q = G, r = Gx and s = 1 + Gx, the signature is valid for e = 1 exactly: u1 + u2 = (e + r) / s
  # = 1 puts R at G. 66 bytes (528 bits) ending 0x80 are e = 1 once shifted right by 7 bits, with or
  # without bytes after them; 65 bytes (520 bits, no shift) ending 0x80 are e = 128, and it fails
  gx <- paste0("00c6858e06b70404e9cd9e3ecb662395b4429c648139053fb521f828af606b4d",
               "3dbaa14b5e77efe75928fe1dc127a2ffa8de3348b3c1856a429bf97e7e31c2e5bd66")
  gy <- paste0("011839296a789a3bc0045c8a5fb42c7d1bd998f54449579b446817afbd17273e",
               "662c97ee72995ef42640c550b9013fad0761353c7086a272c24088be94769fd16650")
  s1 <- .nat_hex(gx)
  s1[66] <- as.raw(as.integer(s1[66]) + 1L)
  dg <- c(as.raw(rep(0, 65)), as.raw(0x80))
  v <- function(digest) .Call(C_rmbl_ecdsa_verify, "P-521", .nat_hex(gx), .nat_hex(gy), .nat_hex(gx), s1, digest)
  expect_true(v(c(dg, as.raw(c(0xff, 0xff, 0xff, 0xff)))))
  expect_true(v(dg))
  expect_false(v(dg[-1L]))
})

test_that("XMSS verification refuses a leaf index past the tree", {
  # reaches C_rmbl_xmss_verify_impl's refusal of an index of 2^h or more (src/rmbl_pqc.cpp)
  h <- function(n) strrep("00", n)
  expect_false(.Call(C_rmbl_xmss_verify, h(32), h(32), 2L, 4L, charToRaw("m"), h(67 * 32), h(2 * 32), h(32)))
})

test_that("a decimal exactly halfway between two doubles rounds to the even one", {
  # reaches the bignum comparison's equality (cmp returning 0, src/rmbl_strtod.cpp): the digits are
  # exactly 1 + 2^-53 and 2^53 + 1, ties that go to the even neighbour; a digit past the tie goes up
  expect_identical(.rmbl_strtod("1.00000000000000011102230246251565404236316680908203125"), 1)
  expect_identical(.rmbl_strtod("9007199254740993"), 9007199254740992)
  expect_identical(.rmbl_strtod("9007199254740993.0000000000000000000000000001"), 9007199254740994)
})

test_that("siuso() reads a French plural cue and a French zero", {
  # reaches resolve_fr past the roster and the ordinals, where the spelled French numbers are looked up,
  # in src/siu_resolve.cpp
  r <- siuso("Deux agents impliqu\u00e9s ont \u00e9t\u00e9 d\u00e9sign\u00e9s dans cette affaire.")
  expect_identical(r$count, 2L)
  expect_match(r$reason, "plural cue")
  z <- siuso("Aucun agent impliqu\u00e9 dans cette affaire.")
  expect_identical(z$count, 0L)
})
