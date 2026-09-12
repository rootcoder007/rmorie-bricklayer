# Schema inference, the extended structural validator, and the
# tamper-evident manifest chain.
#
# The schema tests close the loop: everything infer_schema() emits must
# be a field validate_schema() actually checks, and each check must fire
# on data that violates it and stay silent on data that does not. The
# chain tests assert the property that distinguishes a chain from a bag
# of digests -- that deleting or reordering an entry is detectable.

test_that("an inferred schema validates the data it was learned from", {
  set.seed(51)
  df <- data.frame(
    id = 1:100,
    score = stats::runif(100, 0, 10),
    grade = sample(c("a", "b", "c"), 100, TRUE),
    note = paste0("free text ", 1:100),
    stringsAsFactors = FALSE
  )
  sch <- infer_schema(df)
  expect_s3_class(sch, "bricklayer_schema")
  expect_equal(sch$expected_columns, names(df))
  expect_equal(unname(sch$expected_types[["id"]]), "integer")
  expect_equal(unname(sch$expected_types[["grade"]]), "character")

  # it accepts the data it came from
  expect_length(validate_schema(df, list(schema = sch)), 0L)
  expect_true(apply_schema_validation(df, list(schema = sch)))

  # low-cardinality columns get their levels pinned; free text does not
  expect_equal(sch$expected_value_sets[["grade"]], c("a", "b", "c"))
  expect_null(sch$expected_value_sets[["note"]])
  # numeric columns get a padded range
  expect_true(sch$numeric_ranges[["score"]][["min"]] < min(df$score))
  expect_true(sch$numeric_ranges[["score"]][["max"]] > max(df$score))
  # row bounds straddle the observed count
  expect_lte(sch$structural_invariants$min_data_rows, 100L)
  expect_gte(sch$structural_invariants$max_data_rows, 100L)

  # slack = 0 pins exactly, so the range is the observed range
  tight <- infer_schema(df, slack = 0)
  expect_equal(tight$numeric_ranges[["score"]][["min"]], min(df$score))
  expect_equal(tight$structural_invariants$min_data_rows, 100L)
  expect_length(validate_schema(df, list(schema = tight)), 0L)
  # a wider slack accepts more
  wide <- infer_schema(df, slack = 0.5)
  expect_gt(wide$numeric_ranges[["score"]][["max"]],
            sch$numeric_ranges[["score"]][["max"]])
  # max_levels decides what counts as categorical
  expect_null(infer_schema(df, max_levels = 2L)$expected_value_sets[["grade"]])
  expect_false(is.null(infer_schema(df,
    max_levels = 200L)$expected_value_sets[["note"]]))
  # a constant numeric column still gets a usable range rather than a
  # zero-width one
  cs <- infer_schema(data.frame(k = rep(5, 10)))
  expect_lt(cs$numeric_ranges[["k"]][["min"]], 5)
  expect_gt(cs$numeric_ranges[["k"]][["max"]], 5)
  expect_length(validate_schema(data.frame(k = rep(5, 10)),
                                list(schema = cs)), 0L)

  expect_output(print(sch), "Inferred schema")
  expect_error(infer_schema(1:5), "data frame")
  expect_error(infer_schema(data.frame()), "no columns")
  expect_error(infer_schema(df, slack = -1), "non-negative")
  expect_error(infer_schema(df, max_levels = 0), "positive integer")
})

test_that("every inferred field is a field the validator checks", {
  set.seed(52)
  df <- data.frame(id = 1:50, score = stats::runif(50, 0, 10),
                   grade = sample(c("a", "b"), 50, TRUE),
                   stringsAsFactors = FALSE)
  sch <- infer_schema(df)

  # expected_columns: a missing column is fatal
  gone <- validate_schema(df[, -2], list(schema = sch))
  expect_true(length(gone) > 0L)
  expect_equal(gone$missing_columns$severity, "fatal")
  expect_error(apply_schema_validation(df[, -2], list(schema = sch)))

  # structural_invariants: row counts either side of the bounds
  expect_true("row_count_low" %in%
                names(validate_schema(df[1:5, ], list(schema = sch))))
  big <- df[rep(1:50, 4), ]
  expect_true("row_count_high" %in%
                names(validate_schema(big, list(schema = sch))))

  # expected_value_sets: an unseen level
  newlev <- df
  newlev$grade[1] <- "z"
  expect_true("unexpected_grade" %in%
                names(validate_schema(newlev, list(schema = sch))))

  # expected_types: a column that changed type
  retyped <- df
  retyped$grade <- seq_len(50)
  expect_true("type_grade" %in%
                names(validate_schema(retyped, list(schema = sch))))
  # but integer widening to double is NOT a type change
  widened <- df
  widened$id <- as.numeric(widened$id)
  expect_false(any(grepl("^type_", names(validate_schema(widened,
                                                         list(schema = sch))))))

  # numeric_ranges: a value outside the padded range
  outlier <- df
  outlier$score[1] <- 1e6
  iss <- validate_schema(outlier, list(schema = sch))
  expect_true("range_score" %in% names(iss))
  expect_match(iss$range_score$message, "outside")

  # max_missing_fraction: more NA than the schema allows
  gappy <- df
  gappy$score[1:40] <- NA
  expect_true("missing_score" %in%
                names(validate_schema(gappy, list(schema = sch))))

  # every one of these is a warning, not fatal, so a caller can decide
  for (nm in c("row_count_low", "unexpected_grade", "type_grade",
               "range_score", "missing_score")) {
    all_iss <- c(validate_schema(df[1:5, ], list(schema = sch)),
                 validate_schema(newlev, list(schema = sch)),
                 validate_schema(retyped, list(schema = sch)),
                 validate_schema(outlier, list(schema = sch)),
                 validate_schema(gappy, list(schema = sch)))
    if (!is.null(all_iss[[nm]])) {
      expect_equal(all_iss[[nm]]$severity, "warning")
    }
  }

  # an absent schema field is simply not checked, so an older schema
  # keeps working
  expect_length(validate_schema(retyped, list(schema = list(
    expected_columns = names(df)))), 0L)
  expect_length(validate_schema(df, list(schema = list())), 0L)
  expect_length(validate_schema(df, NULL), 0L)
  expect_length(validate_schema(df, list()), 0L)
})

test_that("the chain links each entry to the one before it", {
  ch <- chain_new()
  expect_s3_class(ch, "bricklayer_chain")
  expect_equal(chain_head(ch), paste(rep("0", 64), collapse = ""))
  expect_true(chain_verify(ch)$valid)
  expect_equal(chain_verify(ch)$n, 0L)

  ch <- chain_append(ch, "manifest 1", label = "run-1")
  ch <- chain_append(ch, "manifest 2", label = "run-2")
  ch <- chain_append(ch, "manifest 3", label = "run-3")

  expect_equal(length(ch$entries), 3L)
  expect_true(chain_verify(ch)$valid)
  expect_true(is.na(chain_verify(ch)$broken_at))
  expect_equal(chain_verify(ch)$n, 3L)
  expect_equal(chain_head(ch), ch$entries[[3]]$digest)
  # each entry names its predecessor, and the first names the genesis
  expect_equal(ch$entries[[1]]$prev, paste(rep("0", 64), collapse = ""))
  expect_equal(ch$entries[[2]]$prev, ch$entries[[1]]$digest)
  expect_equal(ch$entries[[3]]$prev, ch$entries[[2]]$digest)
  # the link digest covers the payload AND the predecessor
  expect_equal(ch$entries[[2]]$digest,
               core_sha256(paste0(ch$entries[[1]]$digest, ":",
                                  ch$entries[[2]]$payload)))
  expect_equal(ch$entries[[1]]$payload, core_sha256("manifest 1"))
  expect_equal(ch$entries[[2]]$label, "run-2")

  # the head depends on the whole history: the same entries in a
  # different order give a different head
  other <- chain_append(chain_append(chain_append(chain_new(),
    "manifest 2"), "manifest 1"), "manifest 3")
  expect_false(identical(chain_head(other), chain_head(ch)))
  # and appending anything changes the head
  expect_false(identical(chain_head(chain_append(ch, "manifest 4")),
                         chain_head(ch)))
})

test_that("editing, deleting or reordering an entry is detected", {
  ch <- chain_new()
  for (i in 1:5) ch <- chain_append(ch, paste("manifest", i))
  expect_true(chain_verify(ch)$valid)

  # editing an entry's payload breaks its own link
  edited <- ch
  edited$entries[[3]]$payload <- core_sha256("substituted")
  expect_false(chain_verify(edited)$valid)
  expect_equal(chain_verify(edited)$broken_at, 3L)

  # editing its digest breaks it too
  ed2 <- ch
  ed2$entries[[2]]$digest <- core_sha256("forged")
  expect_false(chain_verify(ed2)$valid)
  expect_equal(chain_verify(ed2)$broken_at, 2L)

  # DELETING an entry is the case a per-manifest digest cannot catch:
  # every remaining manifest is individually intact, but the chain is not
  dropped <- ch
  dropped$entries[[3]] <- NULL
  expect_equal(length(dropped$entries), 4L)
  expect_false(chain_verify(dropped)$valid)
  expect_equal(chain_verify(dropped)$broken_at, 3L)

  # so is reordering
  swapped <- ch
  swapped$entries[c(2, 3)] <- swapped$entries[c(3, 2)]
  expect_false(chain_verify(swapped)$valid)
  # and inserting a well-formed entry in the middle
  inserted <- ch
  inserted$entries <- append(inserted$entries, list(ch$entries[[5]]),
                             after = 2L)
  expect_false(chain_verify(inserted)$valid)

  # truncating from the END is NOT detectable from the links alone --
  # the remaining prefix is perfectly valid
  truncated <- ch
  truncated$entries[[5]] <- NULL
  expect_true(chain_verify(truncated)$valid)
  expect_false(identical(chain_head(truncated), chain_head(ch)))

  # and the converse: a MIDDLE deletion leaves the last entry's stored
  # digest untouched, so the head does not change even though the chain
  # is broken. Head and links each miss what the other catches.
  expect_equal(chain_head(dropped), chain_head(ch))
  expect_false(chain_verify(dropped)$valid)

  # the seal covers both, which is why it is the thing to sign
  expect_false(identical(chain_seal(truncated), chain_seal(ch)))
  expect_true(is.na(chain_seal(dropped)))
  expect_true(is.na(chain_seal(edited)))
  expect_equal(chain_seal(ch), chain_seal(ch))
  expect_match(chain_seal(ch), "^[0-9a-f]{64}$")

  key <- pqc_keygen(height = 2)
  sig <- capsule_sign(chain_seal(ch), key)
  pub <- signing_public_key(key)
  expect_true(capsule_verify(chain_seal(ch), sig, pub))
  # a truncated chain still seals, but to a different value
  expect_false(capsule_verify(chain_seal(truncated), sig, pub))
  # a chain whose links do not agree has no seal to present at all, and
  # the verifier refuses NA rather than treating it as a value
  for (broken in list(dropped, swapped, inserted, edited)) {
    expect_true(is.na(chain_seal(broken)))
    expect_error(capsule_verify(chain_seal(broken), sig, pub), "length-1")
  }

  expect_output(print(ch), "chain intact")
  expect_output(print(edited), "BROKEN")
  expect_output(print(chain_verify(ch)), "chain intact")
  expect_output(print(chain_verify(edited)), "broken at entry 3")
  expect_output(print(chain_new()), "empty")
})

test_that("the chain records arbitrary objects deterministically", {
  # a manifest is a list, not a string, so the digest must cover lists
  m1 <- list(source = "https://example.org/a.csv", sha256 = "abc",
             rows = 100L)
  m2 <- list(source = "https://example.org/a.csv", sha256 = "abc",
             rows = 101L)
  a <- chain_append(chain_new(), m1)
  b <- chain_append(chain_new(), m1)
  c3 <- chain_append(chain_new(), m2)

  # the same object gives the same digest across calls
  expect_equal(chain_head(a), chain_head(b))
  # a one-field difference gives a different one
  expect_false(identical(chain_head(a), chain_head(c3)))
  expect_true(chain_verify(a)$valid)

  # data frames work too
  df <- data.frame(x = 1:3, y = letters[1:3], stringsAsFactors = FALSE)
  d <- chain_append(chain_new(), df)
  expect_true(chain_verify(d)$valid)
  expect_equal(chain_head(d), chain_head(chain_append(chain_new(), df)))
  df2 <- df
  df2$x[1] <- 99L
  expect_false(identical(chain_head(d),
                         chain_head(chain_append(chain_new(), df2))))
  # a label is metadata and does not enter the payload digest
  expect_equal(chain_append(chain_new(), m1, label = "x")$entries[[1]]$payload,
               chain_append(chain_new(), m1, label = "y")$entries[[1]]$payload)

  expect_error(chain_append(list(), "x"), "chain_new")
  expect_error(chain_head(list()), "chain_new")
  expect_error(chain_verify(list()), "chain_new")
})
