# The ready-made rule vocabulary.
#
# Every rule is tested twice: it must FIRE on data that violates it and
# stay SILENT on data that does not. A rule that never fires is worse
# than no rule, because it reads like a guarantee.

test_that("rule_in_set accepts the set and rejects the rest", {
  ok <- data.frame(g = c("a", "b", "c"), stringsAsFactors = FALSE)
  bad <- data.frame(g = c("a", "z", "b"), stringsAsFactors = FALSE)
  r <- rule_in_set("g", c("a", "b", "c"))
  expect_s3_class(r, "bricklayer_rule")
  expect_equal(r$name, "g_in_set")
  expect_length(validate_rules(ok, r), 0L)
  iss <- validate_rules(bad, r)
  expect_length(iss, 1L)
  expect_equal(iss$g_in_set$rows, 2L)
  expect_equal(iss$g_in_set$n_failed, 1L)
  # NA passes by default, so missingness is reported once and not twice
  expect_length(validate_rules(data.frame(g = c("a", NA)), r), 0L)
  expect_length(validate_rules(data.frame(g = c("a", NA)),
                               rule_in_set("g", "a", na_pass = FALSE)), 1L)
  # severity is carried
  expect_equal(validate_rules(bad, rule_in_set("g", "a",
    severity = "fatal"))$g_in_set$severity, "fatal")
  # numbers are compared as their rendered values
  expect_length(validate_rules(data.frame(g = c(1, 2)),
                               rule_in_set("g", c(1, 2))), 0L)
})

test_that("rule_between enforces inclusive bounds", {
  r <- rule_between("v", 0, 100)
  expect_length(validate_rules(data.frame(v = c(0, 50, 100)), r), 0L)
  iss <- validate_rules(data.frame(v = c(-1, 50, 101)), r)
  expect_equal(iss$v_between$n_failed, 2L)
  expect_equal(iss$v_between$rows, c(1L, 3L))
  # the bounds themselves pass, which is what "inclusive" means
  expect_length(validate_rules(data.frame(v = 0), r), 0L)
  expect_length(validate_rules(data.frame(v = 100), r), 0L)
  expect_length(validate_rules(data.frame(v = c(1, NA)), r), 0L)
  expect_length(validate_rules(data.frame(v = c(1, NA)),
                               rule_between("v", 0, 100,
                                            na_pass = FALSE)), 1L)
  expect_error(rule_between("v", 100, 0), "`lo` <= `hi`")
  expect_error(rule_between("v", NA, 1), "non-missing")
})

test_that("rule_not_null and rule_unique fire on their own violations", {
  nn <- rule_not_null("v")
  expect_length(validate_rules(data.frame(v = 1:3), nn), 0L)
  iss <- validate_rules(data.frame(v = c(1, NA, NA)), nn)
  expect_equal(iss$v_not_null$n_failed, 2L)
  expect_equal(iss$v_not_null$rows, c(2L, 3L))

  un <- rule_unique("id")
  expect_length(validate_rules(data.frame(id = 1:3), un), 0L)
  d <- validate_rules(data.frame(id = c(1, 2, 2, 3, 3)), un)
  # duplicated() marks the repeats, not the first occurrence
  expect_equal(d$id_unique$rows, c(3L, 5L))
  expect_equal(d$id_unique$n_failed, 2L)
  # NA counts as a value for uniqueness, so two NAs are a duplicate
  expect_length(validate_rules(data.frame(id = c(NA, NA)), un), 1L)
})

test_that("rule_regex matches the pattern it was given", {
  r <- rule_regex("email", "^[^@]+@[^@]+\\.[a-z]+$")
  good <- data.frame(email = c("a@b.com", "c@d.org"),
                     stringsAsFactors = FALSE)
  bad <- data.frame(email = c("a@b.com", "nope", "@x.com"),
                    stringsAsFactors = FALSE)
  expect_length(validate_rules(good, r), 0L)
  iss <- validate_rules(bad, r)
  expect_equal(iss$email_regex$rows, c(2L, 3L))
  expect_match(iss$email_regex$message, "not matching")
  expect_length(validate_rules(data.frame(email = NA_character_), r), 0L)
  expect_length(validate_rules(data.frame(email = NA_character_),
                               rule_regex("email", "x", na_pass = FALSE)), 1L)
})

test_that("rule_increasing checks the order of the whole column", {
  r <- rule_increasing("day")
  expect_length(validate_rules(data.frame(day = 1:5), r), 0L)
  # non-decreasing allows a repeat
  expect_length(validate_rules(data.frame(day = c(1, 2, 2, 3)), r), 0L)
  expect_length(validate_rules(data.frame(day = c(1, 3, 2)), r), 1L)
  # strictly does not allow the repeat
  st <- rule_increasing("day", strictly = TRUE)
  expect_length(validate_rules(data.frame(day = c(1, 2, 2, 3)), st), 1L)
  expect_length(validate_rules(data.frame(day = 1:4), st), 0L)
  expect_match(validate_rules(data.frame(day = c(1, 2, 2)), st)$day_increasing$message,
               "strictly increasing")
  # a whole-column rule reports no row indices, because the failure is
  # not attributable to one row
  expect_null(validate_rules(data.frame(day = c(3, 1)), r)$day_increasing$rows)
})

test_that("rule_within_n_mads finds outliers robustly", {
  r <- rule_within_n_mads("v", 5)
  tight <- data.frame(v = c(1, 2, 3, 2, 1))
  expect_length(validate_rules(tight, r), 0L)
  # one wild value against a tight bulk
  wild <- data.frame(v = c(1, 2, 3, 2, 1, 900))
  iss <- validate_rules(wild, r)
  expect_equal(iss$v_within_mads$rows, 6L)
  # several outliers do not mask each other, because the MAD is robust
  many <- data.frame(v = c(1, 2, 3, 2, 1, 2, 3, 900, 905, 910))
  expect_gte(validate_rules(many, r)$v_within_mads$n_failed, 3L)
  # a larger multiplier is more permissive
  expect_length(validate_rules(wild, rule_within_n_mads("v", 1e6)), 0L)
  # a column where over half the values are identical has a zero MAD;
  # anything that differs is then an outlier, rather than a division by
  # zero
  half <- data.frame(v = c(5, 5, 5, 5, 5, 9))
  expect_equal(validate_rules(half, r)$v_within_mads$rows, 6L)
  # NA passes by default and an all-NA column has nothing to judge
  expect_length(validate_rules(data.frame(v = c(1, 2, NA)), r), 0L)
  expect_length(validate_rules(data.frame(v = rep(NA_real_, 3)), r), 0L)
  expect_error(rule_within_n_mads("v", 0), "must be positive")
})

test_that("the table-level rules check the table", {
  df <- data.frame(a = c(1, NA, 3), b = c(1, 2, 3))
  cr <- rule_complete_rows()
  expect_equal(validate_rules(df, cr)$complete_rows$rows, 2L)
  expect_length(validate_rules(data.frame(a = 1:2, b = 3:4), cr), 0L)

  dup <- data.frame(x = c(1, 1, 2), y = c("a", "a", "b"),
                    stringsAsFactors = FALSE)
  dr <- rule_distinct_rows()
  expect_equal(validate_rules(dup, dr)$distinct_rows$rows, 2L)
  expect_length(validate_rules(data.frame(x = 1:3), dr), 0L)
  # restricted to named columns
  partial <- data.frame(id = c(1, 1), note = c("p", "q"),
                        stringsAsFactors = FALSE)
  expect_length(validate_rules(partial, rule_distinct_rows()), 0L)
  expect_length(validate_rules(partial, rule_distinct_rows("id")), 1L)
  # a named column that is absent cannot constrain anything
  expect_length(validate_rules(partial, rule_distinct_rows("nope")), 0L)

  cc <- rule_col_count(2)
  expect_length(validate_rules(df, cc), 0L)
  expect_length(validate_rules(data.frame(a = 1), cc), 1L)
  expect_match(validate_rules(data.frame(a = 1), cc)$col_count$message,
               "Expected 2 columns")
  expect_error(rule_col_count(-1), "non-negative")
})

test_that("the rule library composes into one gate", {
  rules <- list(
    rule_unique("id", severity = "fatal"),
    rule_in_set("grade", c("a", "b", "c")),
    rule_between("score", 0, 100),
    rule_not_null("score"),
    rule_increasing("day"),
    rule_within_n_mads("score", 5),
    rule_complete_rows(),
    rule_distinct_rows(),
    rule_col_count(5)
  )
  clean <- data.frame(id = 1:4, grade = c("a", "b", "c", "a"),
                      score = c(10, 20, 30, 40), day = 1:4,
                      extra = 1:4, stringsAsFactors = FALSE)
  # every rule passes on clean data: none of them is vacuous, and none
  # of them is trigger-happy
  expect_length(validate_rules(clean, rules), 0L)

  dirty <- data.frame(id = c(1, 1, 3, 4), grade = c("a", "z", "c", "a"),
                      score = c(10, NA, 3000, 40), day = c(1, 3, 2, 4),
                      extra = 1:4, stringsAsFactors = FALSE)
  iss <- validate_rules(dirty, rules)
  expect_true(all(c("id_unique", "grade_in_set", "score_between",
                    "score_not_null", "day_increasing",
                    "complete_rows") %in% names(iss)))
  # the fatal one is marked as such, so apply_schema_validation raises
  expect_equal(iss$id_unique$severity, "fatal")
  expect_error(
    {
      for (nm in names(iss)) {
        if (iss[[nm]]$severity == "fatal") stop(iss[[nm]]$message)
      }
    }, "duplicate")

  # and they compose with the structural schema checks
  sch <- infer_schema(clean)
  both <- c(validate_schema(clean, list(schema = sch)),
            validate_rules(clean, rules))
  expect_length(both, 0L)
  expect_gt(length(c(validate_schema(dirty, list(schema = sch)),
                     validate_rules(dirty, rules))), 3L)
})
