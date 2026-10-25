# Schema inference, the extended structural validator, and the
# tamper-evident manifest chain.
#
# The schema tests close the loop: everything infsch() emits must
# be a field valsch() actually checks, and each check must fire
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
  sch <- infsch(df)
  expect_s3_class(sch, "bricklayer_schema")
  expect_equal(sch$expected_columns, names(df))
  expect_equal(unname(sch$expected_types[["id"]]), "integer")
  expect_equal(unname(sch$expected_types[["grade"]]), "character")

  # it accepts the data it came from
  expect_length(valsch(df, list(schema = sch)), 0L)
  expect_true(schval(df, list(schema = sch)))

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
  tight <- infsch(df, slack = 0)
  expect_equal(tight$numeric_ranges[["score"]][["min"]], min(df$score))
  expect_equal(tight$structural_invariants$min_data_rows, 100L)
  expect_length(valsch(df, list(schema = tight)), 0L)
  # a wider slack accepts more
  wide <- infsch(df, slack = 0.5)
  expect_gt(
    wide$numeric_ranges[["score"]][["max"]],
    sch$numeric_ranges[["score"]][["max"]]
  )
  # maxlvl decides what counts as categorical
  expect_null(infsch(df, maxlvl = 2L)$expected_value_sets[["grade"]])
  expect_false(is.null(infsch(df, maxlvl = 200L)$expected_value_sets[["note"]]))
  # a constant numeric column still gets a usable range rather than a
  # zero-width one
  cs <- infsch(data.frame(k = rep(5, 10)))
  expect_lt(cs$numeric_ranges[["k"]][["min"]], 5)
  expect_gt(cs$numeric_ranges[["k"]][["max"]], 5)
  expect_length(valsch(data.frame(k = rep(5, 10)), list(schema = cs)), 0L)

  expect_output(print(sch), "Inferred schema")
  expect_error(infsch(1:5), "data frame")
  expect_error(infsch(data.frame()), "no columns")
  expect_error(infsch(df, slack = -1), "non-negative")
  expect_error(infsch(df, maxlvl = 0), "positive integer")
})

test_that("every inferred field is a field the validator checks", {
  set.seed(52)
  df <- data.frame(
    id = 1:50,
    score = stats::runif(50, 0, 10),
    grade = sample(c("a", "b"), 50, TRUE),
    stringsAsFactors = FALSE
  )
  sch <- infsch(df)

  # expected_columns: a missing column is fatal
  gone <- valsch(df[, -2], list(schema = sch))
  expect_true(length(gone) > 0L)
  expect_equal(gone$missing_columns$severity, "fatal")
  expect_error(schval(df[, -2], list(schema = sch)))

  # structural_invariants: row counts either side of the bounds
  expect_true(
    "row_count_low" %in%
      names(valsch(df[1:5, ], list(schema = sch)))
  )
  big <- df[rep(1:50, 4), ]
  expect_true(
    "row_count_high" %in%
      names(valsch(big, list(schema = sch)))
  )

  # expected_value_sets: an unseen level
  newlev <- df
  newlev$grade[1] <- "z"
  expect_true(
    "unexpected_grade" %in%
      names(valsch(newlev, list(schema = sch)))
  )

  # expected_types: a column that changed type
  retyped <- df
  retyped$grade <- seq_len(50)
  expect_true(
    "type_grade" %in%
      names(valsch(retyped, list(schema = sch)))
  )
  # but integer widening to double is NOT a type change
  widened <- df
  widened$id <- as.numeric(widened$id)
  expect_false(any(grepl("^type_", names(valsch(widened, list(schema = sch))))))

  # numeric_ranges: a value outside the padded range
  outlier <- df
  outlier$score[1] <- 1e6
  iss <- valsch(outlier, list(schema = sch))
  expect_true("range_score" %in% names(iss))
  expect_match(iss$range_score$message, "outside")

  # max_missing_fraction: more NA than the schema allows
  gappy <- df
  gappy$score[1:40] <- NA
  expect_true(
    "missing_score" %in%
      names(valsch(gappy, list(schema = sch)))
  )

  # every one of these is a warning, not fatal, so a caller can decide
  for (nm in c(
    "row_count_low",
    "unexpected_grade",
    "type_grade",
    "range_score",
    "missing_score"
  )) {
    all_iss <- c(
      valsch(df[1:5, ], list(schema = sch)),
      valsch(newlev, list(schema = sch)),
      valsch(retyped, list(schema = sch)),
      valsch(outlier, list(schema = sch)),
      valsch(gappy, list(schema = sch))
    )
    if (!is.null(all_iss[[nm]])) {
      expect_equal(all_iss[[nm]]$severity, "warning")
    }
  }

  # an absent schema field is simply not checked, so an older schema
  # keeps working
  expect_length(
    valsch(
      retyped,
      list(
        schema = list(
          expected_columns = names(df)
        )
      )
    ),
    0L
  )
  # an empty schema checks nothing, and says so (review of e57fed5)
  expect_identical(
    valsch(df, list(schema = list()))$schema_empty$severity,
    "warning"
  )
  expect_length(valsch(df, NULL), 0L)
  expect_length(valsch(df, list()), 0L)
})

test_that("the chain links each entry to the one before it", {
  ch <- chnnew()
  expect_s3_class(ch, "bricklayer_chain")
  expect_equal(chnhead(ch), paste(rep("0", 64), collapse = ""))
  expect_true(chnvrf(ch)$valid)
  expect_equal(chnvrf(ch)$n, 0L)

  ch <- chnapp(ch, "manifest 1", label = "run-1")
  ch <- chnapp(ch, "manifest 2", label = "run-2")
  ch <- chnapp(ch, "manifest 3", label = "run-3")

  expect_equal(length(ch$entries), 3L)
  expect_true(chnvrf(ch)$valid)
  expect_true(is.na(chnvrf(ch)$broken_at))
  expect_equal(chnvrf(ch)$n, 3L)
  expect_equal(chnhead(ch), ch$entries[[3]]$digest)
  # each entry names its predecessor, and the first names the genesis
  expect_equal(ch$entries[[1]]$prev, paste(rep("0", 64), collapse = ""))
  expect_equal(ch$entries[[2]]$prev, ch$entries[[1]]$digest)
  expect_equal(ch$entries[[3]]$prev, ch$entries[[2]]$digest)
  # the link digest covers the payload, the label AND the predecessor (scheme 2
  # since 0.5.13; scheme 1 was "<prev>:<payload>", without the label)
  expect_equal(
    ch$entries[[2]]$digest,
    csha256(paste0(
      "v2|",
      ch$entries[[1]]$digest,
      "|",
      ch$entries[[2]]$payload,
      "|1run-2"
    ))
  )
  expect_equal(ch$entries[[1]]$payload, csha256("manifest 1"))
  expect_equal(ch$entries[[2]]$label, "run-2")

  # the head depends on the whole history: the same entries in a
  # different order give a different head
  other <- chnapp(
    chnapp(chnapp(chnnew(), "manifest 2"), "manifest 1"),
    "manifest 3"
  )
  expect_false(identical(chnhead(other), chnhead(ch)))
  # and appending anything changes the head
  expect_false(identical(chnhead(chnapp(ch, "manifest 4")), chnhead(ch)))
})

test_that("editing, deleting or reordering an entry is detected", {
  ch <- chnnew()
  for (i in 1:5) {
    ch <- chnapp(ch, paste("manifest", i))
  }
  expect_true(chnvrf(ch)$valid)

  # editing an entry's payload breaks its own link
  edited <- ch
  edited$entries[[3]]$payload <- csha256("substituted")
  expect_false(chnvrf(edited)$valid)
  expect_equal(chnvrf(edited)$broken_at, 3L)

  # editing its digest breaks it too
  ed2 <- ch
  ed2$entries[[2]]$digest <- csha256("forged")
  expect_false(chnvrf(ed2)$valid)
  expect_equal(chnvrf(ed2)$broken_at, 2L)

  # DELETING an entry is the case a per-manifest digest cannot catch:
  # every remaining manifest is individually intact, but the chain is not
  dropped <- ch
  dropped$entries[[3]] <- NULL
  expect_equal(length(dropped$entries), 4L)
  expect_false(chnvrf(dropped)$valid)
  expect_equal(chnvrf(dropped)$broken_at, 3L)

  # so is reordering
  swapped <- ch
  swapped$entries[c(2, 3)] <- swapped$entries[c(3, 2)]
  expect_false(chnvrf(swapped)$valid)
  # and inserting a well-formed entry in the middle
  inserted <- ch
  inserted$entries <- append(
    inserted$entries,
    list(ch$entries[[5]]),
    after = 2L
  )
  expect_false(chnvrf(inserted)$valid)

  # truncating from the END is NOT detectable from the links alone --
  # the remaining prefix is perfectly valid
  truncated <- ch
  truncated$entries[[5]] <- NULL
  expect_true(chnvrf(truncated)$valid)
  expect_false(identical(chnhead(truncated), chnhead(ch)))

  # and the converse: a MIDDLE deletion leaves the last entry's stored
  # digest untouched, so the head does not change even though the chain
  # is broken. Head and links each miss what the other catches.
  expect_equal(chnhead(dropped), chnhead(ch))
  expect_false(chnvrf(dropped)$valid)

  # the seal covers both, which is why it is the thing to sign
  expect_false(identical(chnseal(truncated), chnseal(ch)))
  expect_true(is.na(chnseal(dropped)))
  expect_true(is.na(chnseal(edited)))
  expect_equal(chnseal(ch), chnseal(ch))
  expect_match(chnseal(ch), "^[0-9a-f]{64}$")

  key <- pqckg(height = 2)
  sig <- cpssign(chnseal(ch), key)
  pub <- signpubkey(key)
  expect_true(cpsvrf(chnseal(ch), sig, pub))
  # a truncated chain still seals, but to a different value
  expect_false(cpsvrf(chnseal(truncated), sig, pub))
  # a chain whose links do not agree has no seal to present at all, and
  # the verifier refuses NA rather than treating it as a value
  for (broken in list(dropped, swapped, inserted, edited)) {
    expect_true(is.na(chnseal(broken)))
    expect_error(cpsvrf(chnseal(broken), sig, pub), "length-1")
  }

  expect_output(print(ch), "chain intact")
  expect_output(print(edited), "BROKEN")
  expect_output(print(chnvrf(ch)), "chain intact")
  expect_output(print(chnvrf(edited)), "broken at entry 3")
  expect_output(print(chnnew()), "empty")
})

test_that("the chain records arbitrary objects deterministically", {
  # a manifest is a list, not a string, so the digest must cover lists
  m1 <- list(source = "https://example.org/a.csv", sha256 = "abc", rows = 100L)
  m2 <- list(source = "https://example.org/a.csv", sha256 = "abc", rows = 101L)
  a <- chnapp(chnnew(), m1)
  b <- chnapp(chnnew(), m1)
  c3 <- chnapp(chnnew(), m2)

  # the same object gives the same digest across calls
  expect_equal(chnhead(a), chnhead(b))
  # a one-field difference gives a different one
  expect_false(identical(chnhead(a), chnhead(c3)))
  expect_true(chnvrf(a)$valid)

  # data frames work too
  df <- data.frame(x = 1:3, y = letters[1:3], stringsAsFactors = FALSE)
  d <- chnapp(chnnew(), df)
  expect_true(chnvrf(d)$valid)
  expect_equal(chnhead(d), chnhead(chnapp(chnnew(), df)))
  df2 <- df
  df2$x[1] <- 99L
  expect_false(identical(chnhead(d), chnhead(chnapp(chnnew(), df2))))
  # a label is metadata and does not enter the payload digest
  expect_equal(
    chnapp(chnnew(), m1, label = "x")$entries[[1]]$payload,
    chnapp(chnnew(), m1, label = "y")$entries[[1]]$payload
  )

  expect_error(chnapp(list(), "x"), "chnnew")
  expect_error(chnhead(list()), "chnnew")
  expect_error(chnvrf(list()), "chnnew")
})
