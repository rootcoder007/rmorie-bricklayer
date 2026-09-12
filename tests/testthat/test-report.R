# The one-call assessment. What matters here is not that each underlying
# check works -- they have their own suites -- but that the report
# COMPOSES them honestly: the severity ordering is right, a fatal finding
# is fatal, one problem is reported once rather than three times, and a
# clean report does not overclaim.

ref_frame <- function(n = 200, seed = 1) {
  set.seed(seed)
  data.frame(id = seq_len(n), score = stats::runif(n, 0, 10),
             grade = sample(c("a", "b", "c"), n, TRUE),
             stringsAsFactors = FALSE)
}

test_that("a clean capsule reports nothing and says so carefully", {
  ref <- ref_frame()
  cur <- ref
  set.seed(99)
  cur$score <- stats::runif(200, 0, 10)
  r <- capsule_report(cur, reference = ref, schema = infer_schema(ref))
  expect_s3_class(r, "bricklayer_report")
  expect_equal(r$verdict, "clean")
  expect_equal(nrow(r$findings), 0L)
  expect_equal(r$n_rows, 200L)
  expect_equal(r$n_cols, 3L)
  # the digest is of the data, and stable
  expect_equal(r$digest$data_digest, digest_object(cur))
  # the profile and missingness are carried for the reader
  expect_s3_class(r$profile, "bricklayer_profile")
  expect_equal(r$missingness[["n_missing"]], 0)
  expect_s3_class(r$drift, "bricklayer_drift")

  # the rendering does NOT claim the data is correct
  txt <- paste(format(r), collapse = "\n")
  expect_match(txt, "found nothing")
  expect_match(txt, "proof of correctness")
  expect_match(txt, "blind spot")
  expect_output(print(r), "Capsule report")
  expect_equal(unname(summary(r)["verdict"]), "clean")
})

test_that("findings are ordered worst first and counted by severity", {
  ref <- ref_frame()
  bad <- ref
  bad$score <- bad$score * 5           # rescaled: drift and out of range
  bad$grade[1:80] <- "z"               # a new category
  bad$dead <- NA_real_                 # entirely missing
  bad$flat <- 7                        # constant
  r <- capsule_report(bad, reference = ref, schema = infer_schema(ref))

  expect_equal(r$verdict, "warn")
  expect_gt(nrow(r$findings), 3L)
  # fatal before warn before note, always
  rank <- c(fatal = 1L, warn = 2L, note = 3L)
  expect_equal(rank[r$findings$severity],
               sort(rank[r$findings$severity]), ignore_attr = TRUE)
  # the specific findings are present
  expect_true("drift" %in% r$findings$check)
  expect_true("schema" %in% r$findings$check)
  expect_true(any(r$findings$check == "missing" &
                    grepl("dead", r$findings$subject)))
  # the summary counts agree with the table
  s <- summary(r)
  expect_equal(as.integer(s[["warn"]]),
               sum(r$findings$severity == "warn"))
  expect_equal(as.integer(s[["note"]]),
               sum(r$findings$severity == "note"))
  expect_equal(as.integer(s[["fatal"]]), 0L)
  # every finding names a subject and a detail
  expect_true(all(nzchar(r$findings$subject)))
  expect_true(all(nzchar(r$findings$detail)))
})

test_that("a missing required column is fatal", {
  ref <- ref_frame()
  gone <- ref[, c("id", "score")]
  r <- capsule_report(gone, reference = ref, schema = infer_schema(ref))
  expect_equal(r$verdict, "fatal")
  expect_gt(sum(r$findings$severity == "fatal"), 0L)
  # both the schema and the drift comparison notice it
  fatal <- r$findings[r$findings$severity == "fatal", ]
  expect_true(any(grepl("grade", fatal$subject) |
                    grepl("grade", fatal$detail)))
  expect_match(paste(format(r), collapse = "\n"), "FATAL")
  # and fatal outranks everything else in the ordering
  expect_equal(r$findings$severity[1], "fatal")
})

test_that("one problem is reported once, not three times", {
  # An entirely-missing column is missing, is trivially constant, and
  # makes the covariance singular. Reporting all three would bury the
  # real findings under a single cause.
  ref <- ref_frame()
  d <- ref
  d$dead <- NA_real_
  r <- capsule_report(d, reference = ref)
  dead_rows <- r$findings[grepl("dead", r$findings$subject), ]
  # it is named as missing, and not also as constant
  expect_true(any(dead_rows$check == "missing"))
  expect_false(any(dead_rows$check == "shape" &
                     grepl("constant", dead_rows$detail)))
  # nor does it produce an outlier-scan complaint, which would be this
  # check declining to run rather than a fact about the data
  expect_false(any(grepl("complete rows", r$findings$detail)))

  # a constant column is likewise not also reported as collinear
  c2 <- ref
  c2$flat <- 7
  rc <- capsule_report(c2, reference = ref)
  expect_true(any(rc$findings$check == "shape" &
                    grepl("constant", rc$findings$detail)))
  expect_false(any(grepl("collinear", rc$findings$detail)))

  # but a GENUINELY duplicated column is reported as collinear, which
  # is the case that tells the reader something new
  dup <- ref
  dup$score2 <- dup$score
  rd <- capsule_report(dup, reference = ref)
  expect_true(any(grepl("collinear", rd$findings$detail)))
  expect_match(rd$findings$detail[grepl("collinear", rd$findings$detail)],
               "duplicated or derived")
})

test_that("the optional inputs each switch on their own check", {
  ref <- ref_frame(120, seed = 4)
  # with no reference there is no drift section at all
  bare <- capsule_report(ref)
  expect_null(bare$drift)
  expect_false(any(bare$findings$check == "drift"))
  # with no schema there is no schema check
  expect_false(any(bare$findings$check == "schema"))

  # rules are applied when supplied
  rl <- list(rule_between("score", 0, 1))
  withr <- capsule_report(ref, rules = rl)
  expect_true(any(withr$findings$check == "rule"))
  expect_equal(withr$verdict, "warn")
  # a satisfied rule adds nothing
  ok <- capsule_report(ref, rules = list(rule_between("score", -1, 100)))
  expect_false(any(ok$findings$check == "rule"))

  # chunks add the Merkle root
  ch <- c("a", "b", "c")
  withch <- capsule_report(ref, chunks = ch)
  expect_equal(withch$digest$merkle_root, merkle_root(ch))
  expect_equal(withch$digest$n_chunks, 3L)
  expect_match(paste(format(withch), collapse = "\n"), "merkle root")

  # a valid signature over the data's digest verifies
  key <- pqc_keygen(height = 2)
  dig <- digest_object(ref)
  sig <- capsule_sign(dig, key)
  good <- capsule_report(ref, signature = sig,
                         key = signing_public_key(key))
  expect_true(good$digest$signature_valid)
  expect_false(any(good$findings$check == "signature"))
  expect_match(paste(format(good), collapse = "\n"), "verified")

  # a signature over something else does not, and that is a warning
  wrong <- capsule_sign("a different digest", sig$key_state)
  bad <- capsule_report(ref, signature = wrong,
                        key = signing_public_key(key))
  expect_false(bad$digest$signature_valid)
  expect_true(any(bad$findings$check == "signature"))
  expect_equal(bad$verdict, "warn")
  # a signature with no key to check it against is itself a warning
  nokey <- capsule_report(ref, signature = sig)
  expect_true(any(nokey$findings$check == "signature"))
  expect_match(nokey$findings$detail[nokey$findings$check == "signature"],
               "no key")
})

test_that("a contiguous gap is distinguished from scattered failures", {
  # the same number of missing values, in one block or spread about
  set.seed(7)
  n <- 200
  outage <- data.frame(v = c(rep(NA_real_, 40), stats::rnorm(160)))
  scattered <- data.frame(v = stats::rnorm(n))
  scattered$v[sample(n, 40)] <- NA
  expect_equal(sum(is.na(outage$v)), sum(is.na(scattered$v)))

  ro <- capsule_report(outage)
  rs <- capsule_report(scattered)
  # the block is reported as an outage; the scattered gaps are not
  expect_true(any(grepl("contiguous run", ro$findings$detail)))
  expect_false(any(grepl("contiguous run", rs$findings$detail)))
  expect_match(ro$findings$detail[grepl("contiguous", ro$findings$detail)],
               "one outage rather than scattered")
})

test_that("the Markdown rendering carries the findings and the caveat", {
  ref <- ref_frame()
  bad <- ref
  bad$score <- bad$score * 5
  r <- capsule_report(bad, reference = ref, schema = infer_schema(ref))

  md <- report_markdown(r)
  expect_type(md, "character")
  txt <- paste(md, collapse = "\n")
  expect_match(txt, "^# Capsule report")
  expect_match(txt, "Warnings")
  expect_match(txt, "## Findings")
  expect_match(txt, "| severity | check |", fixed = TRUE)
  expect_match(txt, r$digest$data_digest, fixed = TRUE)
  # the caveat travels with the report, not just the console output
  expect_match(txt, "## Caveat")
  expect_match(txt, "proof of correctness")
  expect_match(txt, "Benford")
  # a custom title
  expect_match(paste(report_markdown(r, title = "Run 42"), collapse = "\n"),
               "^# Run 42")

  # written to a file
  p <- tempfile(fileext = ".md")
  on.exit(unlink(p), add = TRUE)
  invisible(report_markdown(r, p))
  expect_true(file.exists(p))
  expect_equal(paste(readLines(p, warn = FALSE), collapse = "\n"), txt)

  # a clean report has no findings table but keeps the caveat
  clean <- capsule_report(ref, schema = infer_schema(ref))
  ctxt <- paste(report_markdown(clean), collapse = "\n")
  expect_false(grepl("## Findings", ctxt, fixed = TRUE))
  expect_match(ctxt, "## Caveat")
  expect_match(ctxt, "found nothing")

  expect_error(report_markdown(list()), "capsule_report")
})

test_that("capsule_report refuses input it cannot assess", {
  expect_error(capsule_report(1:5), "data frame")
  expect_error(capsule_report(data.frame()), "no columns")
  # a single-column frame is assessable; the outlier scan just does not
  # apply, and that is not a finding
  one <- capsule_report(data.frame(v = stats::rnorm(50)))
  expect_s3_class(one, "bricklayer_report")
  expect_false(any(one$findings$check == "outliers"))
  # a zero-row frame does not divide by zero
  z <- capsule_report(data.frame(v = numeric(0)))
  expect_equal(z$n_rows, 0L)
  expect_s3_class(z, "bricklayer_report")
  # the outlier scan is skipped above its row cap rather than run
  big <- data.frame(a = stats::rnorm(100), b = stats::rnorm(100))
  expect_false(any(capsule_report(big, max_rows_outliers = 10L)$findings$check
                   == "outliers"))
})

test_that("the report notices heavy missingness and a Benford departure", {
  set.seed(11)
  n <- 400
  # over half of one column missing, which is a warning rather than a
  # note: an estimate from the remainder is not an estimate of the same
  # population
  d <- data.frame(v = stats::rnorm(n), mostly_gone = stats::rnorm(n))
  d$mostly_gone[1:260] <- NA
  r <- capsule_report(d)
  expect_true(any(r$findings$check == "missing" &
                    grepl("over half", r$findings$detail)))
  expect_equal(r$verdict, "warn")

  # a numeric column spanning orders of magnitude whose leading digits
  # are uniform: the Benford screen fires, as a NOTE, and says so
  # The leading digit is uniform while the MAGNITUDE still spans six
  # orders, which is what the screen is looking for: a narrow-range
  # column is skipped regardless, because Benford's law does not apply
  # there.
  b <- data.frame(
    normal_scale = 10^stats::runif(n, 0, 6),
    fabricated = sample(1:9, n, TRUE) * 10^sample(0:5, n, TRUE)
  )
  expect_gt(max(b$fabricated) / min(b$fabricated), 1000)
  rb <- capsule_report(b)
  ben <- rb$findings[rb$findings$check == "benford", ]
  expect_equal(nrow(ben), 1L)
  expect_equal(ben$subject, "fabricated")
  expect_equal(ben$severity, "note")
  expect_match(ben$detail, "screen, not a verdict")
  # the honestly-scaled column is not flagged
  expect_false("normal_scale" %in% ben$subject)
  # a narrow-range column is never screened at all, since Benford's law
  # does not apply there
  narrow <- capsule_report(data.frame(v = stats::runif(n, 10, 11)))
  expect_false(any(narrow$findings$check == "benford"))
})

test_that("a note-only report renders as such", {
  set.seed(12)
  ref <- ref_frame(150, seed = 12)
  dup <- ref
  dup$score2 <- dup$score          # collinear: a note, nothing worse
  r <- capsule_report(dup, reference = ref)
  expect_equal(r$verdict, "note")
  expect_equal(sum(r$findings$severity %in% c("fatal", "warn")), 0L)
  txt <- paste(format(r), collapse = "
")
  expect_match(txt, "notes only")
  expect_match(txt, "nothing blocking")
  expect_output(print(r), "notes only")
  # and in Markdown
  expect_match(paste(report_markdown(r), collapse = "
"), "Notes only")
})

test_that("a column that cannot be compared is reported as untestable", {
  set.seed(13)
  ref <- ref_frame(150, seed = 13)
  # the column exists on both sides but is entirely missing on one, so
  # no test applies -- which is a different statement from "no drift"
  cur <- ref
  cur$score <- NA_real_
  r <- capsule_report(cur, reference = ref)
  untest <- r$findings[grepl("not testable", r$findings$detail), ]
  expect_gte(nrow(untest), 1L)
  expect_equal(untest$check[1], "drift")
  expect_equal(untest$severity[1], "note")
  # and it is NOT reported as having drifted, which would be a claim the
  # data does not support
  drifted <- r$findings[r$findings$check == "drift" &
                          r$findings$severity == "warn", ]
  expect_false("score" %in% drifted$subject)
})

test_that("outliers are reported with the worst row named", {
  set.seed(14)
  n <- 300
  d <- data.frame(a = stats::rnorm(n))
  d$b <- d$a * 0.5 + stats::rnorm(n, 0, 2)
  # a row that is ordinary on each margin and impossible jointly
  d[7, ] <- list(a = -3, b = 12)
  r <- capsule_report(d)
  out <- r$findings[r$findings$check == "outliers", ]
  expect_equal(nrow(out), 1L)
  expect_equal(out$severity, "note")
  expect_match(out$detail, "jointly improbable")
  expect_match(out$detail, "row 7")
  expect_match(out$subject, "row")
})

