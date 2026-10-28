# The readings of the boxed results: built from each result's numbers, so two
# different results read differently.

test_that(".rd_list() names a few labels and counts the rest", {
  expect_identical(.rd_list(character()), "none")
  expect_identical(.rd_list("a"), "a")
  expect_identical(.rd_list(c("a", "b", "c")), "a, b and c")
  expect_identical(.rd_list(letters[1:7], 2L), "a, b and 5 more")
})

test_that(".rd_groups() names the highest and lowest and their overlap", {
  r <- .rd_groups(c("x", "y"), c(1, 5), c(0.5, 4), c(1.5, 6), "rate")
  expect_identical(r[1L], "Highest rate: y (5); lowest: x (1).")
  expect_match(r[2L], "do not overlap", fixed = TRUE)
  r2 <- .rd_groups(c("x", "y"), c(1, 1.2), c(0.5, 0.6), c(1.5, 1.8), "rate")
  expect_match(r2[2L], "overlap, which alone does not mean", fixed = TRUE)
  expect_identical(.rd_groups("x", 3, 2, 4, "rate"), "x: rate 3 [2, 4].")
  expect_match(.rd_groups(c("x", "y"), c(2, 2)), "same estimate", fixed = TRUE)
  expect_match(.rd_groups("x", NA_real_), "No group", fixed = TRUE)
  expect_match(.rd_groups(c("a", "b"), c(13796, 15080)), "13,796",
    fixed = TRUE)
})

test_that(".rd_null() and .rd_test() follow the numbers", {
  r <- .rd_null(c("a", "b", "c"), c(1.1, 0.5, 0.2), c(1.5, 1.5, 0.9), 1,
    "Up", "Down")
  expect_identical(r, c(
    "Up (interval above 1): a.",
    "Down (interval below 1): c.",
    "Not distinguishable from 1 (interval includes it): b."
  ))
  expect_identical(.rd_null("a", NA, NA, 0, "U", "D"),
    "No row has an interval to judge it by.")
  expect_identical(.rd_test(0.011, 0.05, "Clustered", "No pattern"),
    "Clustered (p = 0.011, below 0.05).")
  expect_identical(.rd_test(0.42, 0.05, "Clustered", "No pattern"),
    "No pattern (p = 0.420, not below 0.05).")
  expect_match(.rd_test(NA, 0.05, "a", "b"), "no p-value", fixed = TRUE)
  expect_identical(.rd_alpha(0.9), 0.1)
  expect_identical(.rd_alpha(NULL), 0.05)
})

test_that("the cleaning summaries go to the message stream as a box", {
  expect_message(
    .rmbl_note_box(c("-- T --", "  a", strrep("-", 10))),
    "T"
  )
  expect_identical(.rmbl_dim_txt(c(1L, 2L)), "1 row, 2 columns")
  expect_null(.rmbl_dim_txt(NULL))
  fl <- .mf_flat(list(a = 1, b = list(c = "x", d = NULL)))
  expect_identical(fl$field, c("a", "b$c", "b$d"))
  expect_identical(fl$value, c("1", "x", ""))
})

test_that("the group readings handle one-row indicators and flat labels", {
  d <- data.frame(
    indicator = c("a", "a", "b"),
    estimate = c(1, 5, 3),
    lower = c(0.5, 4, 2),
    upper = c(1.5, 6, 4),
    stringsAsFactors = FALSE
  )
  expect_match(.an_wp_reading(d), "On 1 of 2 indicators", fixed = TRUE)
  one <- data.frame(
    geo = c("X", "X"), group = c("g", "g"), stringsAsFactors = FALSE
  )
  expect_identical(.an_ps_labels(one), c("g", "g"))
  expect_identical(.an_ps_labels(data.frame(v = 1:2)), c("row 1", "row 2"))
})

test_that("the fit, ledger, distance and certificate readings", {
  expect_identical(.bl_ldgr_reading(character()),
    "The ledger lists no theorems.")
  t0 <- data.frame(
    family = character(), aic = numeric(), stringsAsFactors = FALSE
  )
  expect_match(.rmbl_dstfit_reading(t0), "No family converged",
    fixed = TRUE)
  d <- data.frame(row = 1L, distance = NA_real_, p_value = NA_real_,
    outlier = FALSE)
  expect_identical(.rmbl_maha_reading(d, 0.01),
    "No row has a distance to judge.")
  now <- as.POSIXct("2026-01-01", tz = "UTC")
  ca <- list(
    not_before = now - 86400, not_after = now + 86400 * 10,
    is_ca = TRUE, self_signed = FALSE, issuer = "CN=Root"
  )
  r <- .rmbl_cert_reading(ca, now)
  expect_identical(r[2L], "An intermediate CA certificate, issued by CN=Root.")
})

test_that("the hot-spot, rate-change and survey readings", {
  p <- data.frame(hotshr = c(0.4, 0.5), jacpre = c(NA, 0.3))
  expect_match(.hp_reading(p, 1L, 5L)[2L], "the hot spots shift",
    fixed = TRUE)
  x <- data.frame(pctchg = c(NA_real_, NA_real_), pctlo = NA, pctup = NA)
  expect_match(.rate_chg_reading(x, list()), "No period has one",
    fixed = TRUE)
  x2 <- data.frame(pctchg = 20, pctlo = 5, pctup = 40)
  expect_identical(.rate_chg_reading(x2, list(period = NULL)),
    "Rose by more than chance (interval above 0): (+20.0%).")
  s <- data.frame(
    level = c("a", "b"), estimate = c(1, 2), lower = c(0.5, 1.5),
    upper = c(1.5, 2.5), cv = c(40, 5), stringsAsFactors = FALSE
  )
  r <- .svy_est_reading(s, list(by = NULL))
  expect_true(any(grepl("Too unstable to publish (cv above 33.3): a.", r,
    fixed = TRUE)))
  s1 <- data.frame(estimate = 1, lower = 0.5, upper = 1.5, cv = 20)
  expect_identical(.svy_est_reading(s1, list(by = NULL)),
    "Use with caution (cv 16.6 to 33.3): the estimate.")
})

test_that("the trend, concentration, fraction and chi-square readings", {
  expect_identical(.rmbl_tse_reading(data.frame(), NA_real_),
    "The breakdown value is not recorded.")
  expect_match(.rmbl_gini_reading(0.3, 10)[1L], "moderately concentrated",
    fixed = TRUE)
  r <- .rmbl_paf_reading(-0.2, c(lower = -0.4, upper = -0.1))
  expect_identical(r[2L], "Its interval stays below 0: the exposure protects.")
  x <- c(statistic = 0, df = 0, p_value = NA)
  expect_match(.rmbl_chisq_reading(x, "y", "n"), "One category on both",
    fixed = TRUE)
})

test_that("the manifest and provenance readings say what is recorded", {
  f <- .mf_meta_facts(list(a = 1:2, b = list(1, 2, 3), c = 1:10))
  expect_identical(f$a, "1, 2")
  expect_identical(f$b, "<list of 3>")
  expect_identical(f$c, "<integer of 10>")
  res <- list(
    n = list(group = NULL, observed = 3, expected = 3, status = "PASS"),
    m = list(observed = 1, status = "INFO")
  )
  tb <- .mf_results(res)
  expect_identical(tb$group, c("", ""))
  expect_identical(tb$status, c("PASS", "INFO"))
  r <- .mf_reading(res, list(synthetic = TRUE))
  expect_identical(r, c(
    "No cross-check differs; 1 of 2 pass and the rest are INFO.",
    "Built on synthetic data: every cross-check is INFO, not evidence."
  ))
  pr <- .mf_prov_reading(list(resource = list(synthetic = TRUE)))
  expect_identical(pr[2L], "The record marks its data as synthetic.")
})
