# Input contracts found by the degenerate-input sweep of 2026-09-18: every
# call here used to return a value that looked like an answer.

test_that("numeric kernels refuse non-numeric input instead of coercing", {
  for (f in list(core_mean, core_var, core_sd, core_median, core_mad, core_iqr,
                 core_moments, core_quantile, core_trimmed_mean,
                 core_winsorized_mean, core_tukey_fences, core_midranks,
                 core_bootstrap_mean, inline_hist, core_normal_pdf,
                 core_normal_logpdf, hurwitz_zeta)) {
    expect_error(f("abc"), "must be numeric")
    expect_error(f(list(1, 2)), "must be numeric")
    expect_error(f(data.frame(a = 1)), "must be numeric")
  }
  expect_error(core_cor("a", "b"), "must be numeric")
  expect_error(core_cor_spearman("a", "b"), "must be numeric")
  expect_error(core_dist("a", "b"), "must be numeric")
  expect_error(core_weighted("a", 1), "must be numeric")
  expect_error(core_ipw_weights("a", 0.5), "must be numeric")
  expect_true(is.nan(core_mean(numeric(0))))
  expect_true(is.na(core_mean(c(1, NA))))
  expect_equal(core_mean(c(TRUE, FALSE)), 0.5)
})

test_that("drift screens, Benford and concentration need real samples", {
  expect_error(drift_ks(numeric(0), 1:5), "at least one non-missing")
  expect_error(drift_psi(1:5, numeric(0)), "at least one non-missing")
  expect_error(drift_ks(c(1, Inf, 2), c(1, 2, 3)), "finite")
  expect_error(drift_ks("a", 1:5), "must be numeric")
  expect_error(benford_test("x"), "must be numeric")
  expect_true(is.na(gini(numeric(0))))
  expect_error(gini(Inf), "finite")
  expect_error(lorenz(c(1, -2)), "non-negative")
  expect_true(is.na(top_share(NaN, 0.1)$share))
  expect_error(cramers_v(NA), "finite non-negative")
  expect_error(cramers_v(matrix(c(1, -1, 2, 3), 2)), "finite non-negative")
  expect_error(expected_counts(Inf, 1, "a"), "finite")
  expect_error(funnel_limits(numeric(0)), "at least one non-missing")
  expect_error(sir("x", 1), "must be numeric")
})

test_that("sketch registers are validated", {
  expect_error(distinct_count(-1), "non-negative integer")
  expect_error(distinct_count(c(1.5, 2)), "non-negative integer")
  expect_error(sketch_merge("", ""), "must be numeric")
  expect_equal(distinct_count(integer(0)), 0)
  s <- distinct_sketch(c("a", "b", "a"))
  expect_equal(round(distinct_count(s)), 2)
  expect_equal(distinct_count(NULL), 0)
})

test_that("hashes treat NA as NA and signatures need text or bytes", {
  expect_true(is.na(core_crc32(NA)))
  expect_true(is.na(core_sha512(NA)))
  expect_true(is.na(core_blake2b(NA)))
  expect_true(is.na(core_sha256(NA)))
  expect_equal(core_sha512(c("a", NA))[1], core_sha512("a"))
  expect_error(core_hmac_sha256(-1, "m"), "character or raw")
  expect_error(derive_key(1, 2), "character or raw")
  expect_error(capsule_sign(-1, "k"), "character or raw")
  expect_error(bricklayer_json_base64url_dec(-1), "must be character")
  expect_error(bricklayer_json_base64url_dec("not base64!"), "not base64url")
})

test_that("stock-and-flow measures need finite dates and quantities", {
  expect_error(adp(Inf), "finite")
  expect_error(alos(Inf, 1), "finite")
  expect_error(admissions(Inf, Inf), "finite")
  expect_error(stock_flow(Inf, 1), "finite")
  expect_error(period_days(-1, -1), "dates")
  expect_error(adp("3"), "must be numeric")
})

test_that("parsers, rules, manifests and guards refuse wrong input", {
  expect_error(parse_bands(-1), "character band labels")
  expect_error(band_values(NA), "character band labels")
  expect_error(fiscal_year_label(-1), "positive")
  expect_error(fiscal_year_label(list()), "numeric or character")
  for (f in list(rule_not_null, rule_unique, rule_increasing,
                 rule_within_n_mads)) {
    expect_error(f(NULL), "single non-empty string")
    expect_error(f(-1), "single non-empty string")
  }
  expect_error(rule_between(NULL, 0, 1), "single non-empty string")
  expect_error(rule_in_set(Inf, "a"), "single non-empty string")
  expect_error(rule_regex(NaN, "a"), "single non-empty string")
  expect_error(make_manifest(-1), "must be a list")
  expect_error(manifest_canonical(NA), "must be a list")
  expect_error(manifest_digest(NULL), "must be a list")
  expect_error(verify_recode(NULL, NULL, c(a = "b")), "atomic vectors")
  expect_error(guard_binary(NULL, "d"), "atomic vector")
  expect_error(guard_levels(c("a"), NULL), "non-empty character")
  expect_error(capture_dependencies(-1), "package names")
})

test_that("I/O helpers refuse empty paths and missing capsules", {
  expect_error(friendly_download("", ""), "single non-empty string")
  expect_error(download_data(NULL, "x"), "single non-empty string")
  expect_error(wayback_snapshot_url(""), "single non-empty string")
  expect_error(write_manifest_json(list(), ""), "single non-empty string")
  expect_error(write_text_fallback("t", ""), "single non-empty string")
  expect_error(verify_capsule(""), "single non-empty string")
  expect_error(verify_capsule("/no/such/dir/at/all"),
               "not an existing directory")
  expect_error(validate_schema(NULL, NULL), "data frame")
  expect_error(apply_schema_validation(NULL, NULL), "data frame")
  expect_error(revocation_fetch(""), "single non-empty string")
})

test_that("verify_sha256 accepts the digest as provenance JSON delivers it", {
  p <- tempfile()
  writeLines("abc", p)
  h <- sha256_file(p)
  expect_true(verify_sha256(p, h)$match)
  expect_true(verify_sha256(p, list(h))$match)
  expect_true(verify_sha256(p, toupper(h))$match)
  expect_false(verify_sha256(p, paste0("0", substr(h, 2, 64)))$match)
  expect_error(verify_sha256(p, c(h, h)), "single SHA-256")
})

test_that("IPW weights refuse non-binary treatment, bad propensities", {
  expect_error(core_ipw_weights(c(1, 2, 1), c(0.5, 0.5, 0.5)), "coded 0/1")
  expect_error(core_ipw_weights(c(0, 1), c(-0.2, 0.5)), "\\[0, 1\\]")
  expect_error(core_ipw_weights(c(0, 1), c(0.5, 1.4)), "\\[0, 1\\]")
  w <- core_ipw_weights(c(1, NA, 0), c(0.5, 0.5, NA))
  expect_true(is.na(w[2]) && is.na(w[3]))
  expect_equal(w[1], 2)
})

test_that("sir separates excess from deficit and published_bounds labels NA", {
  r <- sir(observed = c(5, 30), expected = c(20, 20))
  expect_false(r$excess[1])
  expect_true(r$deficit[1])
  expect_true(r$significant[1])
  expect_true(r$excess[2])
  expect_false(r$deficit[2])
  b <- published_bounds(c(10, NA))
  expect_equal(b$status, c("exact", "missing"))
})

test_that("midranks keep NA in place and registers must be finite", {
  expect_equal(core_midranks(c(3, NA, 1, 3)), c(2.5, NA, 1, 2.5))
  expect_equal(core_midranks(NA), NA_real_)
  expect_error(sketch_merge(Inf, Inf), "non-negative integer registers")
  expect_error(distinct_count(c(1, NaN)), "non-negative integer registers")
})
