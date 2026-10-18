# The ready-made rule vocabulary.
#
# Every rule is tested twice: it must FIRE on data that violates it and
# stay SILENT on data that does not. A rule that never fires is worse
# than no rule, because it reads like a guarantee.

test_that("ruleinset accepts the set and rejects the rest", {
  ok <- data.frame(g = c("a", "b", "c"), stringsAsFactors = FALSE)
  bad <- data.frame(g = c("a", "z", "b"), stringsAsFactors = FALSE)
  r <- ruleinset("g", c("a", "b", "c"))
  expect_s3_class(r, "bricklayer_rule")
  expect_equal(r$name, "g_in_set")
  expect_length(valrules(ok, r), 0L)
  iss <- valrules(bad, r)
  expect_length(iss, 1L)
  expect_equal(iss$g_in_set$rows, 2L)
  expect_equal(iss$g_in_set$n_failed, 1L)
  # NA passes by default, so missingness is reported once and not twice
  expect_length(valrules(data.frame(g = c("a", NA)), r), 0L)
  expect_length(valrules(data.frame(g = c("a", NA)),
                               ruleinset("g", "a", napass = FALSE)), 1L)
  # severity is carried
  expect_equal(valrules(bad, ruleinset("g", "a",
    sev = "fatal"))$g_in_set$severity, "fatal")
  # numbers are compared as their rendered values
  expect_length(valrules(data.frame(g = c(1, 2)),
                               ruleinset("g", c(1, 2))), 0L)
})

test_that("rulebtw enforces inclusive bounds", {
  r <- rulebtw("v", 0, 100)
  expect_length(valrules(data.frame(v = c(0, 50, 100)), r), 0L)
  iss <- valrules(data.frame(v = c(-1, 50, 101)), r)
  expect_equal(iss$v_between$n_failed, 2L)
  expect_equal(iss$v_between$rows, c(1L, 3L))
  # the bounds themselves pass, which is what "inclusive" means
  expect_length(valrules(data.frame(v = 0), r), 0L)
  expect_length(valrules(data.frame(v = 100), r), 0L)
  expect_length(valrules(data.frame(v = c(1, NA)), r), 0L)
  expect_length(valrules(data.frame(v = c(1, NA)),
                               rulebtw("v", 0, 100,
                                            napass = FALSE)), 1L)
  expect_error(rulebtw("v", 100, 0), "`lo` <= `hi`")
  expect_error(rulebtw("v", NA, 1), "non-missing")
})

test_that("rulenull and ruleuniq fire on their own violations", {
  nn <- rulenull("v")
  expect_length(valrules(data.frame(v = 1:3), nn), 0L)
  iss <- valrules(data.frame(v = c(1, NA, NA)), nn)
  expect_equal(iss$v_not_null$n_failed, 2L)
  expect_equal(iss$v_not_null$rows, c(2L, 3L))

  un <- ruleuniq("id")
  expect_length(valrules(data.frame(id = 1:3), un), 0L)
  d <- valrules(data.frame(id = c(1, 2, 2, 3, 3)), un)
  # duplicated() marks the repeats, not the first occurrence
  expect_equal(d$id_unique$rows, c(3L, 5L))
  expect_equal(d$id_unique$n_failed, 2L)
  # NA counts as a value for uniqueness, so two NAs are a duplicate
  expect_length(valrules(data.frame(id = c(NA, NA)), un), 1L)
})

test_that("rulerx matches the pattern it was given", {
  r <- rulerx("email", "^[^@]+@[^@]+\\.[a-z]+$")
  good <- data.frame(email = c("a@b.com", "c@d.org"),
                     stringsAsFactors = FALSE)
  bad <- data.frame(email = c("a@b.com", "nope", "@x.com"),
                    stringsAsFactors = FALSE)
  expect_length(valrules(good, r), 0L)
  iss <- valrules(bad, r)
  expect_equal(iss$email_regex$rows, c(2L, 3L))
  expect_match(iss$email_regex$message, "not matching")
  expect_length(valrules(data.frame(email = NA_character_), r), 0L)
  expect_length(valrules(data.frame(email = NA_character_),
                               rulerx("email", "x", napass = FALSE)), 1L)
})

test_that("ruleincr checks the order of the whole column", {
  r <- ruleincr("day")
  expect_length(valrules(data.frame(day = 1:5), r), 0L)
  # non-decreasing allows a repeat
  expect_length(valrules(data.frame(day = c(1, 2, 2, 3)), r), 0L)
  expect_length(valrules(data.frame(day = c(1, 3, 2)), r), 1L)
  # strictly does not allow the repeat
  st <- ruleincr("day", strict = TRUE)
  expect_length(valrules(data.frame(day = c(1, 2, 2, 3)), st), 1L)
  expect_length(valrules(data.frame(day = 1:4), st), 0L)
  expect_match(valrules(data.frame(day = c(1, 2, 2)), st)$day_increasing$message,
               "strictly increasing")
  # a whole-column rule reports no row indices, because the failure is
  # not attributable to one row
  expect_null(valrules(data.frame(day = c(3, 1)), r)$day_increasing$rows)
})

test_that("rulemad finds outliers robustly", {
  r <- rulemad("v", 5)
  tight <- data.frame(v = c(1, 2, 3, 2, 1))
  expect_length(valrules(tight, r), 0L)
  # one wild value against a tight bulk
  wild <- data.frame(v = c(1, 2, 3, 2, 1, 900))
  iss <- valrules(wild, r)
  expect_equal(iss$v_within_mads$rows, 6L)
  # several outliers do not mask each other, because the MAD is robust
  many <- data.frame(v = c(1, 2, 3, 2, 1, 2, 3, 900, 905, 910))
  expect_gte(valrules(many, r)$v_within_mads$n_failed, 3L)
  # a larger multiplier is more permissive
  expect_length(valrules(wild, rulemad("v", 1e6)), 0L)
  # a column where over half the values are identical has a zero MAD;
  # anything that differs is then an outlier, rather than a division by
  # zero
  half <- data.frame(v = c(5, 5, 5, 5, 5, 9))
  expect_equal(valrules(half, r)$v_within_mads$rows, 6L)
  # NA passes by default and an all-NA column has nothing to judge
  expect_length(valrules(data.frame(v = c(1, 2, NA)), r), 0L)
  expect_length(valrules(data.frame(v = rep(NA_real_, 3)), r), 0L)
  expect_error(rulemad("v", 0), "must be positive")
})

test_that("the table-level rules check the table", {
  df <- data.frame(a = c(1, NA, 3), b = c(1, 2, 3))
  cr <- rulecmpl()
  expect_equal(valrules(df, cr)$complete_rows$rows, 2L)
  expect_length(valrules(data.frame(a = 1:2, b = 3:4), cr), 0L)

  dup <- data.frame(x = c(1, 1, 2), y = c("a", "a", "b"),
                    stringsAsFactors = FALSE)
  dr <- ruledstn()
  expect_equal(valrules(dup, dr)$distinct_rows$rows, 2L)
  expect_length(valrules(data.frame(x = 1:3), dr), 0L)
  # restricted to named columns
  partial <- data.frame(id = c(1, 1), note = c("p", "q"),
                        stringsAsFactors = FALSE)
  expect_length(valrules(partial, ruledstn()), 0L)
  expect_length(valrules(partial, ruledstn("id")), 1L)
  # a named column that is absent cannot constrain anything
  expect_length(valrules(partial, ruledstn("nope")), 0L)

  cc <- rulecolcnt(2)
  expect_length(valrules(df, cc), 0L)
  expect_length(valrules(data.frame(a = 1), cc), 1L)
  expect_match(valrules(data.frame(a = 1), cc)$col_count$message,
               "Expected 2 columns")
  expect_error(rulecolcnt(-1), "non-negative")
})

test_that("the rule library composes into one gate", {
  rules <- list(
    ruleuniq("id", sev = "fatal"),
    ruleinset("grade", c("a", "b", "c")),
    rulebtw("score", 0, 100),
    rulenull("score"),
    ruleincr("day"),
    rulemad("score", 5),
    rulecmpl(),
    ruledstn(),
    rulecolcnt(5)
  )
  clean <- data.frame(id = 1:4, grade = c("a", "b", "c", "a"),
                      score = c(10, 20, 30, 40), day = 1:4,
                      extra = 1:4, stringsAsFactors = FALSE)
  # every rule passes on clean data: none of them is vacuous, and none
  # of them is trigger-happy
  expect_length(valrules(clean, rules), 0L)

  dirty <- data.frame(id = c(1, 1, 3, 4), grade = c("a", "z", "c", "a"),
                      score = c(10, NA, 3000, 40), day = c(1, 3, 2, 4),
                      extra = 1:4, stringsAsFactors = FALSE)
  iss <- valrules(dirty, rules)
  expect_true(all(c("id_unique", "grade_in_set", "score_between",
                    "score_not_null", "day_increasing",
                    "complete_rows") %in% names(iss)))
  # the fatal one is marked as such, so schval raises
  expect_equal(iss$id_unique$severity, "fatal")
  expect_error(
    {
      for (nm in names(iss)) {
        if (iss[[nm]]$severity == "fatal") stop(iss[[nm]]$message)
      }
    }, "duplicate")

  # and they compose with the structural schema checks
  sch <- infsch(clean)
  both <- c(valsch(clean, list(schema = sch)),
            valrules(clean, rules))
  expect_length(both, 0L)
  expect_gt(length(c(valsch(dirty, list(schema = sch)),
                     valrules(dirty, rules))), 3L)
})

test_that("rulemad lets a missing value through only when asked", {
  d <- data.frame(v = c(1, 1.1, 0.9, 1.05, NA))
  expect_length(valrules(d, rulemad("v")), 0L)
  expect_length(valrules(d, rulemad("v", napass = FALSE)), 1L)
})
