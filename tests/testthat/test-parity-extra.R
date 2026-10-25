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
  structural <- data.frame(
    id = 1:10,
    a = c(rep(NA, 3), 4:10),
    b = c(rep(NA, 3), 4:10)
  )
  scattered <- data.frame(
    id = 1:10,
    a = c(rep(NA, 3), 4:10),
    b = c(1:7, rep(NA, 3))
  )
  expect_equal(sum(is.na(structural$a)), sum(is.na(scattered$a)))
  expect_equal(sum(is.na(structural$b)), sum(is.na(scattered$b)))

  s <- misspat(structural)
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
  d <- misspat(scattered)
  expect_equal(nrow(d), 3L)
  expect_true(all(c("...", ".X.", "..X") %in% d$pattern))
  # so the two frames are distinguishable despite matching rates
  expect_false(nrow(s) == nrow(d))

  # the rows and percentages account for the whole frame
  expect_equal(sum(s$n_rows), nrow(structural))
  expect_equal(sum(s$pctrows), 100)
  # most frequent first
  expect_equal(s$n_rows, sort(s$n_rows, decreasing = TRUE))
  # the column order is carried, so a pattern string can be read
  expect_equal(attr(s, "columns"), names(structural))
  expect_equal(nchar(s$pattern[1]), ncol(structural))

  # a complete frame has exactly one pattern, with no columns named
  cc <- misspat(data.frame(x = 1:3, y = 4:6))
  expect_equal(nrow(cc), 1L)
  expect_equal(cc$pattern, "..")
  expect_equal(cc$n_missing, 0L)
  expect_equal(cc$columns, "")
  # an all-missing frame is the opposite extreme
  am <- misspat(data.frame(x = c(NA, NA), y = c(NA, NA)))
  expect_equal(am$pattern, "XX")
  expect_equal(am$pctrows, 100)
  # maxpat truncates, most frequent kept
  set.seed(61)
  wide <- as.data.frame(matrix(
    ifelse(stats::runif(300) < 0.5, NA, 1),
    ncol = 6
  ))
  expect_lte(nrow(misspat(wide, maxpat = 3L)), 3L)
  # a zero-row frame is empty, not an error
  expect_equal(nrow(misspat(data.frame(x = numeric(0)))), 0L)

  expect_output(print(s), "Missingness patterns")
  expect_error(misspat(1:5), "data frame")
  expect_error(misspat(data.frame()), "no columns")
  expect_error(misspat(structural, maxpat = 0), "positive integer")
})

test_that("topcors ranks by strength and uses the right method", {
  set.seed(62)
  n <- 300
  df <- data.frame(
    a = stats::rnorm(n),
    b = stats::rnorm(n),
    grade = sample(letters[1:3], n, TRUE),
    stringsAsFactors = FALSE
  )
  df$c <- df$a * 2 + stats::rnorm(n, sd = 0.05) # near-perfect with a
  df$d <- exp(df$a) # monotone but curved

  tc <- topcors(df)
  expect_s3_class(tc, "bricklayer_correlations")
  # the non-numeric column is ignored
  expect_false("grade" %in% c(tc$x, tc$y))
  # strongest first
  expect_equal(tc$abscor, sort(tc$abscor, decreasing = TRUE))
  expect_true(all(abs(tc$correlation) <= 1))
  # the values come from the kernel, not somewhere else
  pick <- tc[1L, ]
  expect_equal(pick$correlation, cspr(df[[pick$x]], df[[pick$y]]))
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
  sp <- topcors(df, meth = "spearman", n = 20)
  pe <- topcors(df, meth = "pearson", n = 20)
  sp_ad <- abs(sp$correlation[
    (sp$x == "a" & sp$y == "d") |
      (sp$x == "d" & sp$y == "a")
  ])
  pe_ad <- abs(pe$correlation[
    (pe$x == "a" & pe$y == "d") |
      (pe$x == "d" & pe$y == "a")
  ])
  expect_gt(sp_ad, 0.99)
  expect_lt(pe_ad, sp_ad)
  expect_equal(attr(pe, "method"), "pearson")
  expect_equal(
    pe$correlation[1],
    ccorr(df[[pe$x[1]]], df[[pe$y[1]]]),
    tolerance = 1e-8
  )

  # n and minabs both filter
  expect_equal(nrow(topcors(df, n = 2L)), 2L)
  expect_true(all(topcors(df, minabs = 0.5)$abscor >= 0.5))
  # only the exactly-monotone pair clears a threshold of 1
  expect_equal(nrow(topcors(df, minabs = 1.0)), 1L)
  expect_equal(nrow(topcors(df[, c("a", "b")], minabs = 0.99)), 0L)
  # NA is dropped pairwise rather than poisoning the pair
  gappy <- df
  gappy$a[1:10] <- NA
  expect_true(all(is.finite(topcors(gappy)$correlation)))
  expect_output(print(tc), "Top correlations")
  expect_output(print(topcors(df[, c("a", "b")], minabs = 0.99)), "none above")

  expect_error(topcors(data.frame(a = 1:3)), "two numeric")
  expect_error(topcors(1:5), "data frame")
  expect_error(topcors(df, n = 0), "positive integer")
  expect_error(topcors(df, minabs = 2), "\\[0, 1\\]")
})

test_that("envdiff reports exactly what moved", {
  a <- capenv()
  expect_true(envdiff(a, a)$identical)
  expect_equal(nrow(envdiff(a, a)$packages), 0L)
  expect_null(envdiff(a, a)$r_version)

  # a moved package version
  b <- a
  nm <- names(b$packages)[1L]
  b$packages[[nm]] <- "0.0.0"
  d <- envdiff(a, b)
  expect_false(d$identical)
  expect_equal(nrow(d$packages), 1L)
  expect_equal(d$packages$package, nm)
  expect_equal(d$packages$change, "changed")
  expect_equal(d$packages$b, "0.0.0")

  # an added and a removed package
  add <- a
  add$packages <- c(add$packages, brandnew = "1.0.0")
  expect_equal(envdiff(a, add)$packages$change, "added")
  rem <- a
  rem$packages <- rem$packages[-1L]
  expect_equal(envdiff(a, rem)$packages$change, "removed")
  expect_true(is.na(envdiff(a, rem)$packages$b))

  # the R version and platform are compared too
  rv <- a
  rv$r_version <- "1.0.0"
  expect_false(envdiff(a, rv)$identical)
  expect_equal(envdiff(a, rv)$r_version[["b"]], "1.0.0")
  pf <- a
  pf$platform <- "somewhere-else"
  expect_equal(envdiff(a, pf)$platform[["b"]], "somewhere-else")

  # whole manifests are accepted, not just the environment block
  m <- mkmnf(list(run = "demo"))
  expect_true(envdiff(m, m)$identical)
  expect_true(envdiff(m, m$environment)$identical)
  expect_output(print(envdiff(a, a)), "environments match")
  expect_output(print(envdiff(a, b)), "environments differ")
  expect_output(print(envdiff(a, b)), nm, fixed = TRUE)
  expect_error(envdiff(1, 2), "environment records or manifests")
})

test_that("compressed JSON round trips and is smaller", {
  set.seed(63)
  x <- list(rows = data.frame(id = 1:200, value = round(stats::runif(200), 4)))
  enc <- jsgzenc(x)
  expect_type(enc, "character")
  expect_length(enc, 1L)
  # a record-shaped payload repeats its keys, so gzip wins comfortably
  expect_lt(nchar(enc), nchar(tojs(x)))

  back <- jsgzdec(enc)
  expect_equal(back$rows$id, 1:200)
  expect_equal(back$rows$value, x$rows$value)

  # raw mode skips base64, for writing to a file
  bytes <- jsgzenc(x, raw = TRUE)
  expect_true(is.raw(bytes))
  expect_equal(jsgzdec(bytes, raw = TRUE)$rows$id, 1:200)
  # the base64 form decodes to the same bytes
  expect_equal(jsb64dec(enc), bytes)
  # deterministic
  expect_identical(jsgzenc(x), enc)

  # simple values survive too
  expect_equal(jsgzdec(jsgzenc(list(a = 1, b = "x")))$b, "x")
  expect_equal(jsgzdec(jsgzenc(1:5)), 1:5)
  # a round trip through a file, which is the raw mode's purpose
  p <- tempfile()
  on.exit(unlink(p), add = TRUE)
  writeBin(jsgzenc(x, raw = TRUE), p)
  expect_equal(jsgzdec(readBin(p, "raw", n = 1e6), raw = TRUE)$rows$id, 1:200)

  expect_error(jsgzdec(charToRaw("x")), class = "error")
  expect_error(jsgzdec("abc", raw = TRUE), "raw vector")
})

test_that("declared rules fire on violations and stay silent otherwise", {
  df <- data.frame(
    id = c(1, 2, 2),
    age = c(30, -5, 40),
    start = c(1, 5, 3),
    end = c(2, 4, 9)
  )
  rules <- list(
    rul("age_non_negative", function(v) v >= 0, col = "age"),
    rul("id_unique", function(v) !anyDuplicated(v), col = "id", sev = "fatal"),
    rul("dates_ordered", function(d) all(d$start <= d$end))
  )
  iss <- valrules(df, rules)
  expect_true(all(
    c("age_non_negative", "id_unique", "dates_ordered") %in% names(iss)
  ))
  # a row-wise rule reports how many rows failed and which
  expect_equal(iss$age_non_negative$n_failed, 1L)
  expect_equal(iss$age_non_negative$rows, 2L)
  expect_equal(iss$age_non_negative$severity, "warning")
  expect_match(iss$age_non_negative$message, "1 of 3 rows")
  # severity is carried through
  expect_equal(iss$id_unique$severity, "fatal")

  # clean data produces nothing at all
  clean <- data.frame(id = 1:3, age = c(30, 31, 40), start = 1:3, end = 4:6)
  expect_length(valrules(clean, rules), 0L)
  # a single rule need not be wrapped in a list
  expect_length(valrules(clean, rules[[1]]), 0L)
  expect_length(valrules(df, rules[[1]]), 1L)

  # a rule whose column is absent is SKIPPED, not failed: the missing
  # column is valsch()'s finding
  expect_length(valrules(data.frame(id = 1:3), rules[1:2]), 0L)

  # a rule that errors is a failure, never a silent pass
  broken <- list(rul("bad", function(v) stop("boom"), col = "age"))
  bi <- valrules(clean, broken)
  expect_length(bi, 1L)
  expect_match(bi$bad$message, "could not be evaluated")
  expect_match(bi$bad$message, "boom")
  # nor is a rule returning the wrong type
  wrong <- list(rul("wrong", function(v) "yes", col = "age"))
  expect_match(valrules(clean, wrong)$wrong$message, "not a logical")

  # NA is a failure: a rule that cannot decide has not been satisfied
  nas <- data.frame(age = c(1, NA, 3))
  expect_equal(valrules(nas, rules[[1]])$age_non_negative$n_failed, 1L)

  # the issues compose with valsch and go through the same
  # raising wrapper
  sch <- infsch(clean)
  expect_length(
    c(valsch(clean, list(schema = sch)), valrules(clean, rules)),
    0L
  )
  # an empty schema checks nothing: asked to validate against it is refused
  # (review of e57fed5)
  expect_error(schval(df, list(schema = list())), "schema is empty")

  expect_output(print(rules[[1]]), "age_non_negative")
  expect_output(print(rules[[3]]), "table-level")
  expect_error(rul("", function(v) TRUE), "non-empty")
  expect_error(rul("x", "not a function"), "must be a function")
  expect_error(valrules(df, list("not a rule")), "must come from rul")
  expect_error(valrules(1:5, rules), "data frame")
})
