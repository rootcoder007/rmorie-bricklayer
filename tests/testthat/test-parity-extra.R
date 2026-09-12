# Missingness patterns, correlation ranking, environment diffing,
# compressed JSON and declarative rules.
#
# These are the features peer packages provide and bricklayer lacked.
# Each is anchored on what it must compute, not on the peer's output:
# the missingness patterns are counted by hand, the correlations come
# from the kernels, the JSON must round trip, and each rule must fire on
# violating data and stay silent on clean data.

test_that("missingness patterns distinguish structural from scattered", {
  # the same per-column rates, missing together vs independently
  structural <- data.frame(id = 1:10,
                           a = c(rep(NA, 3), 4:10),
                           b = c(rep(NA, 3), 4:10))
  scattered <- data.frame(id = 1:10,
                          a = c(rep(NA, 3), 4:10),
                          b = c(1:7, rep(NA, 3)))
  expect_equal(sum(is.na(structural$a)), sum(is.na(scattered$a)))
  expect_equal(sum(is.na(structural$b)), sum(is.na(scattered$b)))

  s <- missingness_pattern(structural)
  expect_s3_class(s, "bricklayer_missingness")
  # two patterns: all present, or both columns missing together
  expect_equal(nrow(s), 2L)
  expect_true("..." %in% s$pattern)
  expect_true(".XX" %in% s$pattern)
  expect_equal(s$n_rows[s$pattern == ".XX"], 3L)
  expect_equal(s$n_rows[s$pattern == "..."], 7L)
  expect_equal(s$columns[s$pattern == ".XX"], "a, b")
  expect_equal(s$n_missing[s$pattern == ".XX"], 2L)

  # the scattered frame has three patterns, which is the finding
  d <- missingness_pattern(scattered)
  expect_equal(nrow(d), 3L)
  expect_true(all(c("...", ".X.", "..X") %in% d$pattern))
  # so the two frames are distinguishable despite matching rates
  expect_false(nrow(s) == nrow(d))

  # the rows and percentages account for the whole frame
  expect_equal(sum(s$n_rows), nrow(structural))
  expect_equal(sum(s$pct_rows), 100)
  # most frequent first
  expect_equal(s$n_rows, sort(s$n_rows, decreasing = TRUE))
  # the column order is carried, so a pattern string can be read
  expect_equal(attr(s, "columns"), names(structural))
  expect_equal(nchar(s$pattern[1]), ncol(structural))

  # a complete frame has exactly one pattern, with no columns named
  cc <- missingness_pattern(data.frame(x = 1:3, y = 4:6))
  expect_equal(nrow(cc), 1L)
  expect_equal(cc$pattern, "..")
  expect_equal(cc$n_missing, 0L)
  expect_equal(cc$columns, "")
  # an all-missing frame is the opposite extreme
  am <- missingness_pattern(data.frame(x = c(NA, NA), y = c(NA, NA)))
  expect_equal(am$pattern, "XX")
  expect_equal(am$pct_rows, 100)
  # max_patterns truncates, most frequent kept
  set.seed(61)
  wide <- as.data.frame(matrix(ifelse(stats::runif(300) < 0.5, NA, 1),
                               ncol = 6))
  expect_lte(nrow(missingness_pattern(wide, max_patterns = 3L)), 3L)
  # a zero-row frame is empty, not an error
  expect_equal(nrow(missingness_pattern(data.frame(x = numeric(0)))), 0L)

  expect_output(print(s), "Missingness patterns")
  expect_error(missingness_pattern(1:5), "data frame")
  expect_error(missingness_pattern(data.frame()), "no columns")
  expect_error(missingness_pattern(structural, max_patterns = 0),
               "positive integer")
})

test_that("top_correlations ranks by strength and uses the right method", {
  set.seed(62)
  n <- 300
  df <- data.frame(a = stats::rnorm(n), b = stats::rnorm(n),
                   grade = sample(letters[1:3], n, TRUE),
                   stringsAsFactors = FALSE)
  df$c <- df$a * 2 + stats::rnorm(n, sd = 0.05)   # near-perfect with a
  df$d <- exp(df$a)                               # monotone but curved

  tc <- top_correlations(df)
  expect_s3_class(tc, "bricklayer_correlations")
  # the non-numeric column is ignored
  expect_false("grade" %in% c(tc$x, tc$y))
  # strongest first
  expect_equal(tc$abs_correlation, sort(tc$abs_correlation,
                                        decreasing = TRUE))
  expect_true(all(abs(tc$correlation) <= 1))
  # the values come from the kernel, not somewhere else
  pick <- tc[1L, ]
  expect_equal(pick$correlation,
               core_cor_spearman(df[[pick$x]], df[[pick$y]]))
  # d = exp(a) is STRICTLY monotone in a, so its rank correlation is
  # exactly 1 -- stronger than the noisy near-linear pair (a, c), which
  # is the ordering Spearman should produce
  expect_true(all(c("a", "d") %in% c(tc$x[1], tc$y[1])))
  expect_equal(abs(tc$correlation[1]), 1)
  ac <- tc[(tc$x == "a" & tc$y == "c") | (tc$x == "c" & tc$y == "a"), ]
  expect_gt(abs(ac$correlation), 0.95)
  expect_lt(abs(ac$correlation), 1)

  # Spearman sees the curved pair at full strength; Pearson understates
  # it, which is the reason Spearman is the default
  sp <- top_correlations(df, method = "spearman", n = 20)
  pe <- top_correlations(df, method = "pearson", n = 20)
  sp_ad <- abs(sp$correlation[(sp$x == "a" & sp$y == "d") |
                                (sp$x == "d" & sp$y == "a")])
  pe_ad <- abs(pe$correlation[(pe$x == "a" & pe$y == "d") |
                                (pe$x == "d" & pe$y == "a")])
  expect_gt(sp_ad, 0.99)
  expect_lt(pe_ad, sp_ad)
  expect_equal(attr(pe, "method"), "pearson")
  expect_equal(pe$correlation[1], core_cor(df[[pe$x[1]]], df[[pe$y[1]]]),
               tolerance = 1e-8)

  # n and min_abs both filter
  expect_equal(nrow(top_correlations(df, n = 2L)), 2L)
  expect_true(all(top_correlations(df, min_abs = 0.5)$abs_correlation >= 0.5))
  # only the exactly-monotone pair clears a threshold of 1
  expect_equal(nrow(top_correlations(df, min_abs = 1.0)), 1L)
  expect_equal(nrow(top_correlations(df[, c("a", "b")], min_abs = 0.99)), 0L)
  # NA is dropped pairwise rather than poisoning the pair
  gappy <- df
  gappy$a[1:10] <- NA
  expect_true(all(is.finite(top_correlations(gappy)$correlation)))
  expect_output(print(tc), "Top correlations")
  expect_output(print(top_correlations(df[, c("a", "b")], min_abs = 0.99)),
                "none above")

  expect_error(top_correlations(data.frame(a = 1:3)), "two numeric")
  expect_error(top_correlations(1:5), "data frame")
  expect_error(top_correlations(df, n = 0), "positive integer")
  expect_error(top_correlations(df, min_abs = 2), "\\[0, 1\\]")
})

test_that("environment_diff reports exactly what moved", {
  a <- capture_environment()
  expect_true(environment_diff(a, a)$identical)
  expect_equal(nrow(environment_diff(a, a)$packages), 0L)
  expect_null(environment_diff(a, a)$r_version)

  # a moved package version
  b <- a
  nm <- names(b$packages)[1L]
  b$packages[[nm]] <- "0.0.0"
  d <- environment_diff(a, b)
  expect_false(d$identical)
  expect_equal(nrow(d$packages), 1L)
  expect_equal(d$packages$package, nm)
  expect_equal(d$packages$change, "changed")
  expect_equal(d$packages$b, "0.0.0")

  # an added and a removed package
  add <- a
  add$packages <- c(add$packages, brandnew = "1.0.0")
  expect_equal(environment_diff(a, add)$packages$change, "added")
  rem <- a
  rem$packages <- rem$packages[-1L]
  expect_equal(environment_diff(a, rem)$packages$change, "removed")
  expect_true(is.na(environment_diff(a, rem)$packages$b))

  # the R version and platform are compared too
  rv <- a
  rv$r_version <- "1.0.0"
  expect_false(environment_diff(a, rv)$identical)
  expect_equal(environment_diff(a, rv)$r_version[["b"]], "1.0.0")
  pf <- a
  pf$platform <- "somewhere-else"
  expect_equal(environment_diff(a, pf)$platform[["b"]], "somewhere-else")

  # whole manifests are accepted, not just the environment block
  m <- make_manifest(list(run = "demo"))
  expect_true(environment_diff(m, m)$identical)
  expect_true(environment_diff(m, m$environment)$identical)
  expect_output(print(environment_diff(a, a)), "environments match")
  expect_output(print(environment_diff(a, b)), "environments differ")
  expect_output(print(environment_diff(a, b)), nm, fixed = TRUE)
  expect_error(environment_diff(1, 2), "environment records or manifests")
})

test_that("compressed JSON round trips and is smaller", {
  set.seed(63)
  x <- list(rows = data.frame(id = 1:200,
                              value = round(stats::runif(200), 4)))
  enc <- json_gzip_encode(x)
  expect_type(enc, "character")
  expect_length(enc, 1L)
  # a record-shaped payload repeats its keys, so gzip wins comfortably
  expect_lt(nchar(enc), nchar(bricklayer_json_to_json(x)))

  back <- json_gzip_decode(enc)
  expect_equal(back$rows$id, 1:200)
  expect_equal(back$rows$value, x$rows$value)

  # raw mode skips base64, for writing to a file
  bytes <- json_gzip_encode(x, raw = TRUE)
  expect_true(is.raw(bytes))
  expect_equal(json_gzip_decode(bytes, raw = TRUE)$rows$id, 1:200)
  # the base64 form decodes to the same bytes
  expect_equal(bricklayer_json_base64_dec(enc), bytes)
  # deterministic
  expect_identical(json_gzip_encode(x), enc)

  # simple values survive too
  expect_equal(json_gzip_decode(json_gzip_encode(list(a = 1, b = "x")))$b, "x")
  expect_equal(json_gzip_decode(json_gzip_encode(1:5)), 1:5)
  # a round trip through a file, which is the raw mode's purpose
  p <- tempfile()
  on.exit(unlink(p), add = TRUE)
  writeBin(json_gzip_encode(x, raw = TRUE), p)
  expect_equal(json_gzip_decode(readBin(p, "raw", n = 1e6),
                                raw = TRUE)$rows$id, 1:200)

  expect_error(json_gzip_decode(charToRaw("x")), class = "error")
  expect_error(json_gzip_decode("abc", raw = TRUE), "raw vector")
})

test_that("declared rules fire on violations and stay silent otherwise", {
  df <- data.frame(id = c(1, 2, 2), age = c(30, -5, 40),
                   start = c(1, 5, 3), end = c(2, 4, 9))
  rules <- list(
    rule("age_non_negative", function(v) v >= 0, column = "age"),
    rule("id_unique", function(v) !anyDuplicated(v), column = "id",
         severity = "fatal"),
    rule("dates_ordered", function(d) all(d$start <= d$end))
  )
  iss <- validate_rules(df, rules)
  expect_true(all(c("age_non_negative", "id_unique",
                    "dates_ordered") %in% names(iss)))
  # a row-wise rule reports how many rows failed and which
  expect_equal(iss$age_non_negative$n_failed, 1L)
  expect_equal(iss$age_non_negative$rows, 2L)
  expect_equal(iss$age_non_negative$severity, "warning")
  expect_match(iss$age_non_negative$message, "1 of 3 rows")
  # severity is carried through
  expect_equal(iss$id_unique$severity, "fatal")

  # clean data produces nothing at all
  clean <- data.frame(id = 1:3, age = c(30, 31, 40), start = 1:3,
                      end = 4:6)
  expect_length(validate_rules(clean, rules), 0L)
  # a single rule need not be wrapped in a list
  expect_length(validate_rules(clean, rules[[1]]), 0L)
  expect_length(validate_rules(df, rules[[1]]), 1L)

  # a rule whose column is absent is SKIPPED, not failed: the missing
  # column is validate_schema()'s finding
  expect_length(validate_rules(data.frame(id = 1:3), rules[1:2]), 0L)

  # a rule that errors is a failure, never a silent pass
  broken <- list(rule("bad", function(v) stop("boom"), column = "age"))
  bi <- validate_rules(clean, broken)
  expect_length(bi, 1L)
  expect_match(bi$bad$message, "could not be evaluated")
  expect_match(bi$bad$message, "boom")
  # nor is a rule returning the wrong type
  wrong <- list(rule("wrong", function(v) "yes", column = "age"))
  expect_match(validate_rules(clean, wrong)$wrong$message, "not a logical")

  # NA is a failure: a rule that cannot decide has not been satisfied
  nas <- data.frame(age = c(1, NA, 3))
  expect_equal(validate_rules(nas, rules[[1]])$age_non_negative$n_failed, 1L)

  # the issues compose with validate_schema and go through the same
  # raising wrapper
  sch <- infer_schema(clean)
  expect_length(c(validate_schema(clean, list(schema = sch)),
                  validate_rules(clean, rules)), 0L)
  expect_error(apply_schema_validation(df, list(schema = list())),
               NA)   # no schema issues; rules are applied separately

  expect_output(print(rules[[1]]), "age_non_negative")
  expect_output(print(rules[[3]]), "table-level")
  expect_error(rule("", function(v) TRUE), "non-empty")
  expect_error(rule("x", "not a function"), "must be a function")
  expect_error(validate_rules(df, list("not a rule")), "must come from rule")
  expect_error(validate_rules(1:5, rules), "data frame")
})
