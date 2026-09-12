# The branches the main suites do not reach: guards, degenerate inputs,
# and the ASCII fallbacks.
#
# These matter for a provenance tool more than the line count suggests.
# A guard that has never run is a guard nobody knows is broken, and the
# whole point of an error path here is that it fires on the day the data
# arrives malformed.

test_that("the ASCII fallbacks are exercised, not just declared", {
  old <- Sys.getenv("RMBL_ASCII_ONLY", unset = NA)
  on.exit({
    if (is.na(old)) Sys.unsetenv("RMBL_ASCII_ONLY")
    else Sys.setenv(RMBL_ASCII_ONLY = old)
  }, add = TRUE)
  Sys.setenv(RMBL_ASCII_ONLY = "1")

  set.seed(1)
  # the histogram's ASCII level set
  h <- inline_hist(stats::rnorm(500))
  expect_false(grepl("[^\x01-\x7f]", h, useBytes = TRUE))
  expect_true(all(strsplit(h, "")[[1]] %in% c(" ", ".", ":", "-", "=", "#")))
  # a constant column in ASCII mode
  expect_false(grepl("[^\x01-\x7f]", inline_hist(rep(2, 10)),
                     useBytes = TRUE))

  # the missingness map's ASCII shades
  df <- data.frame(a = c(rep(NA, 10), 1:40), b = 1:50)
  lines <- utils::capture.output(missingness_map(df, height = 5L))
  txt <- paste(lines, collapse = "\n")
  expect_false(grepl("[^\x01-\x7f]", txt, useBytes = TRUE))
  expect_match(txt, "legend")

  # every report renders in ASCII
  for (obj in list(
      capsule_drift(data.frame(v = stats::rnorm(50)),
                    data.frame(v = stats::rnorm(50))),
      benford_test(10^stats::runif(200, 0, 4)),
      profile_columns(data.frame(x = stats::rnorm(20))),
      missingness_pattern(df),
      missing_runs(df),
      mahalanobis_outliers(data.frame(a = stats::rnorm(40),
                                      b = stats::rnorm(40))),
      frequency_table(c("a", "b", "b")),
      correlation_table(data.frame(a = stats::rnorm(30),
                                   b = stats::rnorm(30)))
    )) {
    out <- paste(utils::capture.output(print(obj)), collapse = "\n")
    expect_false(grepl("[^\x01-\x7f]", out, useBytes = TRUE))
  }
})

test_that("every print method survives having its columns subset away", {
  set.seed(2)
  df <- data.frame(a = stats::rnorm(40), b = letters[1:40],
                   stringsAsFactors = FALSE)
  df$c <- df$a + stats::rnorm(40)
  num <- data.frame(a = df$a, c = df$c)

  # a classed data frame keeps its class when columns go, so each print
  # method must fall back rather than error on the caller's subset
  expect_output(print(profile_columns(df)[, c("column", "mean")]), "column")
  expect_output(print(frequency_table(df, "b")[, c("pct", "pct_valid")]),
                "pct")
  expect_output(print(correlation_table(num)[, "correlation",
                                             drop = FALSE]), "correlation")
  expect_output(print(top_correlations(num)[, c("x", "y")]), "x")
  expect_output(print(missingness_pattern(df)[, c("pattern", "n_rows")]),
                "pattern")
  gap <- data.frame(v = c(1, NA, NA, 4))
  expect_output(print(missing_runs(gap)[, c("column", "length")]), "column")
  expect_output(print(mahalanobis_outliers(num)[1:3, c("row", "distance")]),
                "row")
  # and none of them returns visibly
  expect_identical(withVisible(print(
    profile_columns(df)[, "column", drop = FALSE]))$visible, FALSE)
})

test_that("the name cleaner handles the shapes that produce nothing", {
  # a data frame with no columns
  expect_equal(ncol(clean_column_names(data.frame())), 0L)
  expect_equal(clean_column_names(character(0)), character(0))
  # names that reduce to nothing become a valid name anyway
  expect_equal(clean_column_names(c("!!!", "@@@")), c("x", "x_2"))
  expect_equal(clean_column_names("   "), "x")
  # case = "none" normalises the separators only, keeping the case
  expect_equal(clean_column_names("Total Pop Count", case = "none"),
               "Total_Pop_Count")
  # a single word through the camel cases exercises the empty tail
  expect_equal(clean_column_names("total", case = "lower_camel"), "total")
  expect_equal(clean_column_names("total", case = "upper_camel"), "Total")
  # a name that is only punctuation alongside a real one still
  # disambiguates
  expect_equal(length(unique(clean_column_names(c("a", "!!", "??", "a")))), 4L)
})

test_that("drop_constant and drop_empty handle a frame with no columns", {
  empty <- data.frame()
  expect_equal(ncol(drop_constant(empty)), 0L)
  expect_length(attr(drop_constant(empty), "dropped"), 0L)
  expect_equal(ncol(drop_empty(empty)), 0L)
  # a frame with columns but no rows
  norows <- data.frame(a = numeric(0), b = character(0),
                       stringsAsFactors = FALSE)
  expect_equal(nrow(drop_empty(norows)), 0L)
  # every column constant leaves nothing behind
  allconst <- data.frame(a = c(1, 1), b = c("x", "x"),
                         stringsAsFactors = FALSE)
  expect_equal(ncol(drop_constant(allconst)), 0L)
  expect_equal(sort(attr(drop_constant(allconst), "dropped")), c("a", "b"))
})

test_that("Mahalanobis distances refuse what they cannot compute", {
  set.seed(3)
  # a matrix is accepted as well as a data frame
  m <- cbind(a = stats::rnorm(40), b = stats::rnorm(40))
  expect_s3_class(mahalanobis_outliers(m), "bricklayer_outliers")
  expect_equal(nrow(mahalanobis_outliers(m)), 40L)
  # perfectly collinear columns have no distance defined
  coll <- data.frame(a = 1:40)
  coll$b <- coll$a * 2
  expect_error(mahalanobis_outliers(coll), "collinear")
  # a single numeric column still works: it is the standardised distance
  one <- mahalanobis_outliers(data.frame(v = c(stats::rnorm(40), 50)))
  expect_true(one$outlier[1])
  expect_equal(one$row[1], 41L)
  expect_error(mahalanobis_outliers("not data"),
               "data frame or a numeric matrix")
  expect_error(mahalanobis_outliers(data.frame(a = letters[1:5])),
               "no numeric columns")
})

test_that("the missingness tools handle empty and single-column frames", {
  # one column: the pattern matrix degenerates to a vector
  one <- missingness_pattern(data.frame(v = c(1, NA, 3)))
  expect_equal(nrow(one), 2L)
  expect_true(all(c(".", "X") %in% one$pattern))
  expect_equal(one$n_rows[one$pattern == "X"], 1L)
  expect_equal(attr(one, "columns"), "v")

  # no columns at all
  expect_error(missingness_pattern(data.frame()), "no columns")
  expect_error(missing_runs(data.frame()), "no columns")
  expect_error(missingness_map(data.frame()), "no columns")
  expect_error(missingness_summary(data.frame()), "no columns")

  # a column whose gaps are all shorter than min_run contributes nothing
  short <- data.frame(v = c(1, NA, 3, NA, 5))
  expect_equal(nrow(missing_runs(short, min_run = 2L)), 0L)
  expect_equal(nrow(missing_runs(short, min_run = 1L)), 2L)
  # a frame where one column qualifies and another does not
  mixed <- data.frame(a = c(1, NA, 3, NA, 5),
                      b = c(1, NA, NA, NA, 5))
  mr <- missing_runs(mixed, min_run = 2L)
  expect_equal(mr$column, "b")
  expect_equal(mr$length, 3L)
})

test_that("Merkle helpers reject malformed input rather than guessing", {
  expect_error(merkle_leaves(c("a", NA)), "must not contain NA")
  expect_error(merkle_proof(c("a", NA), 1), "must not contain NA")
  # a proof whose two vectors disagree in length is malformed, not a
  # verification failure to be reported as FALSE
  bad <- list(sibling = c("aa", "bb"), side = "left")
  expect_error(merkle_verify("x", bad, "root"), "differ in length")
  # an empty proof verifies only the single-leaf tree
  expect_true(merkle_verify("solo", list(sibling = character(0),
                                         side = character(0)),
                            merkle_root("solo")))
  expect_false(merkle_verify("other", list(sibling = character(0),
                                           side = character(0)),
                             merkle_root("solo")))
})

test_that("chunk_file handles a file that is an exact multiple of the block", {
  p <- tempfile()
  on.exit(unlink(p), add = TRUE)
  # exactly 100 bytes, read in blocks of 50: the third read returns
  # nothing, which is the loop's other exit
  writeBin(as.raw(rep(65L, 100)), p)
  ch <- chunk_file(p, chunk_bytes = 50L)
  expect_length(ch, 2L)
  expect_equal(nchar(ch[1]), 50L)
  expect_equal(paste(ch, collapse = ""), strrep("A", 100))
  # and a block larger than the file
  expect_length(chunk_file(p, chunk_bytes = 1000L), 1L)
  # the digests agree whatever the block size
  expect_equal(sha512_file(p, block_bytes = 7L), sha512_file(p))
  expect_equal(crc32_file(p, block_bytes = 3L), crc32_file(p))
})

test_that("the key helpers reject malformed keys and salts", {
  expect_error(derive_key("pw", c("s1", "s2")), "length-1")
  expect_error(derive_key("pw", NA), "length-1")
  expect_error(core_blake2b("m", key = c("k1", "k2")), "length-1")
  expect_error(core_blake2b("m", key = NA), "length-1")
  # a raw salt and a raw key are fine
  expect_match(derive_key("pw", charToRaw("salt"), 10), "^[0-9a-f]{64}$")
  expect_match(core_blake2b("m", key = charToRaw("k")), "^[0-9a-f]{64}$")
})

test_that("the drift tests refuse degenerate category counts", {
  expect_error(drift_chisq(c(a = 1, b = 1), c(a = 0, b = 0)),
               "`expected` has no counts")
  expect_error(drift_chisq(c(a = 0), c(a = 1)), "`observed` has no counts")
  # homogeneity: an unnamed numeric cannot be aligned by category
  expect_error(drift_homogeneity(c(1, 2), c(p = 1, q = 2)), "must be named")
  expect_error(drift_homogeneity(c(p = 1, q = 2), c(1, 2)), "must be named")
  expect_error(drift_homogeneity(c(p = 0, q = 0), c(p = 1, q = 1)),
               "at least one observation")
  expect_error(drift_homogeneity(c(p = 1), c(p = 0)),
               "at least one observation")
})

test_that("capsule_drift reports untestable columns rather than guessing", {
  set.seed(4)
  ref <- data.frame(num = stats::rnorm(60),
                    cat = sample(c("a", "b"), 60, TRUE),
                    stringsAsFactors = FALSE)
  # an all-missing CATEGORICAL column has nothing to compare
  cur <- ref
  cur$cat <- NA_character_
  d <- capsule_drift(ref, cur)
  row <- d$columns[d$columns$column == "cat", ]
  expect_equal(row$type, "categorical")
  expect_true(is.na(row$drifted))
  expect_true(is.na(row$statistic))
  # and an all-missing NUMERIC one likewise
  cur2 <- ref
  cur2$num <- NA_real_
  row2 <- capsule_drift(ref, cur2)$columns
  expect_true(is.na(row2$drifted[row2$column == "num"]))
  # the report still prints, with the untestable rows marked
  expect_output(print(d), "Capsule drift report")
})

test_that("the rule constructors validate their own arguments", {
  expect_error(rule("x", function(v) TRUE, column = ""),
               "non-empty string or NULL")
  expect_error(rule("x", function(v) TRUE, column = NA),
               "non-empty string or NULL")
  # `rules` must be a rule or a list of them
  expect_error(validate_rules(data.frame(a = 1), "not a rule"),
               "must be a rule\\(\\) or a list")
  expect_error(validate_rules(data.frame(a = 1), 42),
               "must be a rule\\(\\) or a list")
})

test_that("top_correlations reports a pair with too little overlap as NA", {
  set.seed(5)
  df <- data.frame(a = stats::rnorm(50), b = stats::rnorm(50))
  # leave only two complete pairs, below the three a correlation needs
  df$a[3:50] <- NA
  expect_equal(nrow(top_correlations(df)), 0L)
  expect_true(is.na(correlation_table(df)$correlation))
  expect_equal(correlation_table(df)$n_pairs, 2L)
})

test_that("environment_diff renders the version and platform rows", {
  a <- capture_environment()
  b <- a
  b$r_version <- "0.0.0"
  b$platform <- "nowhere-unknown"
  txt <- paste(format(environment_diff(a, b)), collapse = "\n")
  expect_match(txt, "R version")
  expect_match(txt, "0\\.0\\.0")
  expect_match(txt, "platform")
  expect_match(txt, "nowhere-unknown")
  expect_match(txt, "environments differ")
  # an environment record with no package list still compares
  bare <- list(r_version = "4.5.0", platform = "x", packages = NULL)
  expect_true(is.list(environment_diff(bare, bare)))
  expect_true(environment_diff(bare, bare)$identical)
  expect_equal(nrow(environment_diff(bare, bare)$packages), 0L)
})

test_that("the MCAR machinery handles its degenerate cases", {
  # a matrix input, and an all-missing column dropped down to too few
  expect_error(mcar_test(data.frame(a = stats::rnorm(20),
                                    dead = rep(NA_real_, 20))),
               "too few complete columns")

  # COLLINEAR columns are refused, not worked around. The EM step floors
  # the covariance's eigenvalues to keep it invertible, so without this
  # check the statistic would be a function of that floor rather than of
  # the data -- a number that looks like an answer and is not one.
  set.seed(6)
  coll <- data.frame(a = stats::rnorm(60))
  coll$b <- coll$a            # exactly collinear
  coll$b[1:20] <- NA
  expect_error(mcar_test(coll), "collinear")
  # so is a deterministic linear combination of two other columns
  lc <- data.frame(x = stats::rnorm(60), y = stats::rnorm(60))
  lc$z <- lc$x + lc$y
  lc$z[1:15] <- NA
  expect_error(mcar_test(lc), "collinear")
  # and a constant column, which is the rank-one case of the same thing
  const <- data.frame(a = stats::rnorm(40), b = rep(2, 40))
  const$a[1:10] <- NA
  expect_error(mcar_test(const), "collinear|constant")
  # the message points at the tools that find the culprit
  expect_error(mcar_test(coll), "top_correlations")
  # a full-rank frame with the same missingness is fine
  ok <- data.frame(a = stats::rnorm(60), b = stats::rnorm(60))
  ok$b[1:20] <- NA
  expect_true(is.finite(mcar_test(ok)$statistic))

  # the positive-definite repair, called directly on an indefinite matrix
  ind <- matrix(c(1, 2, 2, 1), 2, 2)      # eigenvalues 3 and -1
  expect_true(min(eigen(ind, symmetric = TRUE)$values) < 0)
  fixed <- rmoriebricklayer:::.rmbl_make_pd(ind)
  expect_true(min(eigen(fixed, symmetric = TRUE)$values) > 0)
  expect_equal(fixed, t(fixed))
  # an already positive-definite matrix is returned untouched
  pd <- diag(2)
  expect_equal(rmoriebricklayer:::.rmbl_make_pd(pd), pd)

  # a row with nothing observed contributes only the prior, which is the
  # EM's other branch; reachable by calling the estimator directly
  set.seed(7)
  X <- cbind(stats::rnorm(40), stats::rnorm(40))
  X[1, ] <- NA                 # a wholly missing row
  X[5, 2] <- NA
  fit <- rmoriebricklayer:::.rmbl_em_mvn(X)
  expect_false(is.null(fit))
  expect_length(fit$mu, 2L)
  expect_true(all(is.finite(fit$mu)))
  expect_true(min(eigen(fit$sigma, symmetric = TRUE)$values) > 0)

  # the printed report on complete data, where no test is possible
  complete <- mcar_test(data.frame(a = stats::rnorm(40),
                                   b = stats::rnorm(40)))
  txt <- paste(format(complete), collapse = "\n")
  expect_match(txt, "no test possible")
  expect_match(txt, "nothing to test")
  expect_true(is.na(complete$p_value))
})
