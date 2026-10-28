# ralloc() and rallocvrf(): randomisation lists with a sealed commitment

test_that("ralloc makes a reproducible permuted-block list", {
  a <- ralloc(40, seed = "teaching example")
  expect_s3_class(a, "rmbl_alloc")
  expect_identical(nrow(a), 40L)
  expect_identical(a$id[c(1L, 40L)], c("P-0001", "P-0040"))
  expect_setequal(unique(a$arm), c("A", "B"))
  b <- ralloc(40, seed = "teaching example")
  expect_identical(a$arm, b$arm)
  expect_identical(attr(a, "alloc")$digest, attr(b, "alloc")$digest)
  expect_match(attr(a, "alloc")$digest, "^[0-9a-f]{64}$")
  # every complete block holds the arms in the ratio
  sizes <- table(a$block)
  # the last block may be cut at n, so only the ones before it are whole
  full <- utils::head(as.integer(names(sizes)), -1L)
  for (k in full) {
    expect_identical(sum(a$arm[a$block == k] == "A"),
                     sum(a$arm[a$block == k] == "B"))
  }
  expect_true(all(sizes[-length(sizes)] %in% c(4L, 6L)))
  # another seed, another list
  expect_false(identical(ralloc(40, seed = "other")$arm, a$arm))
})

test_that("ralloc stratifies, takes a ratio, codes kits and prefixes ids", {
  s <- ralloc(arms = c("drug", "placebo"), ratio = c(2, 1),
              strata = c(Toronto = 30, Ottawa = 24), codes = TRUE,
              seed = 7, prefix = "TRIAL")
  expect_identical(nrow(s), 54L)
  expect_identical(as.vector(table(s$stratum)[c("Toronto", "Ottawa")]),
                   c(30L, 24L))
  expect_identical(sum(s$arm[s$stratum == "Toronto"] == "drug"), 20L)
  expect_match(s$kit, "^[2-9A-HJ-KMNP-Z]{6}$")
  expect_false(anyDuplicated(s$kit) > 0L)
  expect_match(s$id[1L], "^TRIAL-0001$")
  st <- data.frame(site = c("a", "a", "b"), sex = c("f", "m", "f"),
                   n = c(4, 6, 8), stringsAsFactors = FALSE)
  d <- ralloc(strata = st, seed = 2)
  expect_identical(unique(d$stratum), c("a / f", "a / m", "b / f"))
  expect_identical(ralloc(18, strata = st, seed = 2)$arm, d$arm)
})

test_that("simple randomisation follows the ratio without bias", {
  r <- ralloc(9000, arms = c("x", "y"), ratio = c(2, 1), block = NULL,
              seed = 3)
  expect_true(all(is.na(r$block)))
  p <- mean(r$arm == "x")
  expect_lt(abs(p - 2 / 3), 4 * sqrt(2 / 9 / 9000))
  # the first place of a block of 4 is A half the time
  first <- vapply(seq_len(400), function(i) {
    ralloc(4, block = 4, seed = i)$arm[1L]
  }, "")
  expect_lt(abs(mean(first == "A") - 0.5), 4 * sqrt(0.25 / 400))
})

test_that("the seed may be raw, hexadecimal, a word or drawn", {
  raw48 <- as.raw(0:47)
  a <- ralloc(12, seed = raw48)
  hex <- attr(a, "alloc")$seed
  expect_identical(nchar(hex), 96L)
  expect_identical(ralloc(12, seed = hex)$arm, a$arm)
  expect_identical(ralloc(12, seed = toupper(hex))$arm, a$arm)
  r1 <- ralloc(12)
  r2 <- ralloc(12)
  expect_false(identical(attr(r1, "alloc")$seed, attr(r2, "alloc")$seed))
  expect_error(ralloc(12, seed = as.raw(1:4)), "48 bytes")
})

test_that("ralloc prints counts, never assignments or the seed", {
  s <- ralloc(arms = c("drug", "placebo"), ratio = c(2, 1),
              strata = c(Toronto = 30, Ottawa = 24), codes = TRUE, seed = 7)
  out <- expect_box2(s, "Randomisation list",
                     c("permuted blocks of 6 or 9 within strata",
                       "drug, placebo (2:1)", "concealed",
                       attr(s, "alloc")$digest, "only the id and kit"))
  flat <- paste(out, collapse = " ")
  expect_false(grepl(attr(s, "alloc")$seed, flat, fixed = TRUE))
  expect_false(grepl(s$kit[1L], flat, fixed = TRUE))
  expect_box2(ralloc(8, block = 4, seed = 1), "Randomisation list",
              "Every stratum is exactly in the ratio")
  expect_box2(ralloc(31, block = NULL, seed = 1), "Randomisation list",
              "Simple randomisation lets the totals drift")
  expect_box2(ralloc(9, seed = 1), "Randomisation list",
              "a little off the ratio")
  # without its settings it prints as the plain table it is
  bare <- structure(data.frame(id = "P-1", arm = "A",
                               stringsAsFactors = FALSE),
                    class = c("rmbl_alloc", "data.frame"))
  expect_false(any(grepl("Commitment", format(bare), fixed = TRUE)))
})

test_that("ralloc draws each arm's count, never the order", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  s <- ralloc(arms = c("drug", "placebo"), ratio = c(2, 1), n = 30, seed = 4)
  got <- plot(s)
  expect_named(got, c("arm", "allocated", "target"))
  expect_identical(nrow(got), 2L)
  expect_identical(got$allocated[1L], sum(s$arm == "drug"))
  expect_identical(got$target, c(20, 10))
  # the plot is the counts and nothing else: no order, no participant
  expect_identical(
    got$allocated,
    as.vector(table(factor(s$arm, levels = c("drug", "placebo"))))
  )
  # a reordered list (the same people, other arms' order) plots the same
  s2 <- s
  s2$arm <- rev(s$arm)
  expect_identical(plot(s2)$allocated, got$allocated)
  expect_error(plot.rmbl_alloc(1), "`x` must be a rmbl_alloc object")
})

test_that("rallocvrf passes the list committed to and fails any other", {
  a <- ralloc(20, seed = "teaching example")
  com <- attr(a, "alloc")$digest
  ok <- rallocvrf(a, digest = com)
  expect_true(ok$ok)
  expect_true(all(ok$checks$ok))
  expect_box2(ok, "Randomisation list: verified", com)
  expect_true(rallocvrf(a)$ok)
  expect_true(rallocvrf(a, digest = toupper(com))$ok)
  b <- a
  b$arm[3L] <- if (b$arm[3L] == "A") "B" else "A"
  bad <- rallocvrf(b, digest = com)
  expect_false(bad$ok)
  expect_identical(bad$checks$ok, c(FALSE, FALSE, TRUE))
  expect_box2(bad, "NOT verified", "differ from the commitment")
  other <- rallocvrf(a, digest = com, seed = "another seed")
  expect_identical(other$checks$ok[1:2], c(FALSE, FALSE))
  d <- a[c(1L, 1L, 3:20), ]
  attr(d, "alloc") <- attr(a, "alloc")
  expect_false(rallocvrf(d)$checks$ok[3L])
  expect_error(rallocvrf(data.frame(arm = "A", stringsAsFactors = FALSE)),
               "from ralloc")
})

test_that("ralloc refuses settings it cannot honour", {
  expect_error(ralloc(10, arms = "A"), "two or more different")
  expect_error(ralloc(10, arms = c("A", "A")), "two or more different")
  expect_error(ralloc(10, arms = c("A", NA)), "two or more different")
  expect_error(ralloc(10, ratio = c(1, 1.5)), "positive whole number")
  expect_error(ralloc(10, ratio = 1), "positive whole number")
  expect_error(ralloc(10, ratio = c(0, 1)), "positive whole number")
  expect_error(ralloc(30, block = 5), "positive multiple of 2")
  expect_error(ralloc(30, block = c(4, NA)), "positive multiple of 2")
  expect_error(ralloc(30, block = character()), "positive multiple of 2")
  expect_error(ralloc(0), "n")
  expect_error(ralloc(), "n")
  expect_error(ralloc(10, strata = c(a = 4, b = 4)), "strata's total")
  expect_error(ralloc(strata = c(4, 4)), "name each stratum")
  expect_error(ralloc(strata = stats::setNames(c(4, 4), c("a", "a"))),
               "name each stratum")
  expect_error(ralloc(strata = c(a = 4.5)), "name each stratum")
  expect_error(
    ralloc(strata = data.frame(site = "a", stringsAsFactors = FALSE)),
    "stratum columns"
  )
  expect_error(ralloc(10, codes = NA), "codes")
  expect_error(ralloc(10, prefix = ""), "prefix")
})
