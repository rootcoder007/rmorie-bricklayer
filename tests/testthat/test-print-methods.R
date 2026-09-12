# The output surface. These assert what the reader actually gets: the
# verdict is present, the numbers behind it are present, a secret is
# never present, and the layout degrades to ASCII when asked.

test_that("the drift report leads with its verdict and shows the tests", {
  set.seed(31)
  ref <- data.frame(v = stats::rnorm(200),
                    g = sample(c("a", "b"), 200, TRUE),
                    stringsAsFactors = FALSE)
  cur <- data.frame(v = stats::rnorm(200, mean = 1.5),
                    g = sample(c("a", "b"), 200, TRUE),
                    stringsAsFactors = FALSE)

  d <- capsule_drift(ref, cur)
  txt <- format(d)
  expect_type(txt, "character")
  expect_true(length(txt) > 5L)
  all_of_it <- paste(txt, collapse = "\n")
  # the verdict, and the evidence behind it
  expect_match(all_of_it, "DRIFT DETECTED")
  expect_match(all_of_it, "Capsule drift report")
  expect_match(all_of_it, "Per-column tests")
  expect_match(all_of_it, "\\bv\\b")
  expect_match(all_of_it, "200")
  # print() emits the same lines and returns its argument invisibly
  expect_output(print(d), "DRIFT DETECTED")
  expect_identical(withVisible(print(d))$visible, FALSE)
  expect_identical(suppressWarnings(capture.output(print(d))),
                   capture.output(cat(format(d), sep = "\n")))

  # a clean comparison says so instead
  clean <- capsule_drift(ref, ref)
  expect_match(paste(format(clean), collapse = "\n"), "no drift detected")
  expect_false(grepl("DRIFT DETECTED",
                     paste(format(clean), collapse = "\n")))

  # added and removed columns are surfaced
  gone <- capsule_drift(ref, cur[, "v", drop = FALSE])
  expect_match(paste(format(gone), collapse = "\n"), "columns removed")
  more <- cur
  more$extra <- 1
  expect_match(paste(format(capsule_drift(ref, more)), collapse = "\n"),
               "columns added")

  # the summary is the condensed form
  expect_output(print(summary(d)), "drift detected")
  expect_output(print(summary(clean)), "no drift detected")
})

test_that("the reports fall back to ASCII when told to", {
  old <- Sys.getenv("RMBL_ASCII_ONLY", unset = NA)
  on.exit({
    if (is.na(old)) Sys.unsetenv("RMBL_ASCII_ONLY")
    else Sys.setenv(RMBL_ASCII_ONLY = old)
  }, add = TRUE)
  Sys.setenv(RMBL_ASCII_ONLY = "1")

  set.seed(32)
  d <- capsule_drift(data.frame(v = stats::rnorm(80)),
                     data.frame(v = stats::rnorm(80)))
  txt <- paste(format(d), collapse = "\n")
  # every character is representable in ASCII
  expect_false(grepl("[^\x01-\x7f]", txt, useBytes = TRUE))
  expect_match(txt, "no drift detected")

  b <- benford_test(10^stats::runif(300, 0, 5))
  expect_false(grepl("[^\x01-\x7f]", paste(format(b), collapse = "\n"),
                     useBytes = TRUE))
  k <- pqc_keygen(height = 2)
  expect_false(grepl("[^\x01-\x7f]", paste(format(k), collapse = "\n"),
                     useBytes = TRUE))
  expect_false(grepl("[^\x01-\x7f]",
                     paste(format(capsule_sign("m", k)), collapse = "\n"),
                     useBytes = TRUE))
})

test_that("the Benford report shows the digits and its own caveat", {
  set.seed(33)
  b <- benford_test(10^stats::runif(2000, 0, 6))
  txt <- paste(format(b), collapse = "\n")
  expect_match(txt, "Benford first-digit screen")
  expect_match(txt, "consistent with Benford")
  expect_match(txt, "chi-square")
  # every digit is listed with its observed and expected share
  expect_match(txt, "digit")
  for (d in 1:9) expect_match(txt, paste0("\\b", d, "\\b"))
  expect_output(print(b), "Benford")

  # a failing screen says so, and says it is only a screen
  flat <- benford_test(as.numeric(paste0(rep(1:9, each = 200), "00")))
  ftxt <- paste(format(flat), collapse = "\n")
  expect_match(ftxt, "departs from Benford")
  expect_match(ftxt, "screen only")
  expect_equal(unname(summary(b)[["df"]]), 8)
})

test_that("keys and signatures print without ever showing the secret", {
  s1 <- paste(rep("11", 32), collapse = "")
  s2 <- paste(rep("22", 32), collapse = "")
  key <- pqc_keygen(height = 2, sk_seed = s1, pub_seed = s2)

  txt <- paste(format(key), collapse = "\n")
  expect_match(txt, "Signing key")
  expect_match(txt, key$root, fixed = TRUE)
  expect_match(txt, "0 of 4 signatures")
  expect_match(txt, "withheld")
  # the secret seed must not appear anywhere in the rendering
  expect_false(grepl(s1, txt, fixed = TRUE))
  expect_output(print(key), "Signing key")

  # the public key prints its root and nothing secret
  ptxt <- paste(format(signing_public_key(key)), collapse = "\n")
  expect_match(ptxt, "Public verification key")
  expect_match(ptxt, key$root, fixed = TRUE)
  expect_false(grepl(s1, ptxt, fixed = TRUE))

  # the usage counter advances in the rendering as leaves are consumed
  sig <- capsule_sign("m", key)
  expect_match(paste(format(sig$key_state), collapse = "\n"),
               "1 of 4 signatures")

  # a signature prints its index and an abbreviated body, not 2 KB of hex
  stxt <- paste(format(sig), collapse = "\n")
  expect_match(stxt, "Capsule signature")
  expect_match(stxt, "xmss-sha256")
  expect_match(stxt, "2144 bytes")
  expect_match(stxt, "2 nodes")
  expect_true(nchar(stxt) < 1000L)
  expect_false(grepl(s1, stxt, fixed = TRUE))
  # an HMAC signature prints its tag in full, since it is short
  h <- capsule_sign("m", "k", "hmac")
  expect_match(paste(format(h), collapse = "\n"), h$signature, fixed = TRUE)
  expect_output(print(h), "hmac")
})

test_that("profile_columns describes each column by its own type", {
  set.seed(34)
  df <- data.frame(
    clean = stats::rnorm(100),
    skewed = c(stats::rnorm(99), 500),
    grade = sample(c("a", "b", "c"), 100, TRUE),
    gappy = c(rep(NA_real_, 10), stats::runif(90)),
    allna = rep(NA_real_, 100),
    stringsAsFactors = FALSE
  )
  p <- profile_columns(df)
  expect_s3_class(p, "bricklayer_profile")
  expect_equal(nrow(p), 5L)
  expect_equal(p$column, names(df))
  expect_true(all(c("n_missing", "pct_missing", "median", "mad", "mean",
                    "sd", "n_distinct", "skewness", "n_outliers") %in%
                    names(p)))

  # missingness is counted and expressed as a share
  expect_equal(p$n_missing[p$column == "gappy"], 10L)
  expect_equal(p$pct_missing[p$column == "gappy"], 10)
  expect_equal(p$n_missing[p$column == "clean"], 0L)

  # the numeric summaries agree with the kernels they come from
  expect_equal(p$mean[p$column == "clean"], mean(df$clean))
  expect_equal(p$median[p$column == "clean"], core_median(df$clean))
  expect_equal(p$mad[p$column == "clean"], core_mad(df$clean))
  expect_equal(p$sd[p$column == "clean"], stats::sd(df$clean))
  expect_equal(p$min[p$column == "clean"], min(df$clean))
  # and the NA-bearing column is summarised on its complete cases
  expect_equal(p$mean[p$column == "gappy"], mean(df$gappy, na.rm = TRUE))

  # the outlier announces itself as a gap between mean and median, and in
  # the fence count
  expect_gt(abs(p$mean[p$column == "skewed"] -
                  p$median[p$column == "skewed"]), 1)
  expect_lt(abs(p$mean[p$column == "clean"] -
                  p$median[p$column == "clean"]), 0.5)
  expect_gte(p$n_outliers[p$column == "skewed"], 1L)
  expect_gt(p$skewness[p$column == "skewed"], 1)

  # a categorical column reports levels and its most common value, and no
  # mean
  expect_true(is.na(p$mean[p$column == "grade"]))
  expect_equal(p$n_distinct[p$column == "grade"], 3L)
  expect_true(p$top[p$column == "grade"] %in% c("a", "b", "c"))
  expect_equal(p$top[p$column == "grade"],
               names(sort(table(df$grade), decreasing = TRUE))[1])
  # an all-missing column reports nothing rather than guessing
  expect_true(is.na(p$mean[p$column == "allna"]))
  expect_equal(p$n_missing[p$column == "allna"], 100L)

  # the quantile columns are the ones asked for
  expect_true(all(c("q25", "q50", "q75") %in% names(p)))
  expect_equal(p$q50[p$column == "clean"], core_median(df$clean))
  expect_true("q10" %in% names(profile_columns(df, quantiles = 0.1)))
  expect_false("q25" %in% names(profile_columns(df, quantiles = 0.1)))

  expect_output(print(p), "Column profile")
  expect_identical(withVisible(print(p))$visible, FALSE)
  expect_error(profile_columns(1:5), "data frame")
  expect_error(profile_columns(data.frame()), "no columns")
})
