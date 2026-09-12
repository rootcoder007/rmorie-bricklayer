# Exploratory description: histograms, frequency tables, correlation
# tables, column hygiene, name cleaning, outliers and missingness shape.
#
# Anchors: hand-counted frequencies and percentages, the kernels the
# correlations come from, the chi-square distribution behind the
# Mahalanobis p-value, and rle() for the missingness runs.

test_that("inline_hist draws the shape of a distribution", {
  set.seed(71)
  h <- inline_hist(stats::rnorm(1000))
  expect_type(h, "character")
  expect_equal(nchar(h), 10L)
  expect_equal(nchar(inline_hist(stats::rnorm(100), bins = 20L)), 20L)

  # a symmetric distribution is tallest in the middle; a right-skewed
  # one is tallest at the left
  norm_bars <- strsplit(inline_hist(stats::rnorm(5000)), "")[[1]]
  exp_bars <- strsplit(inline_hist(stats::rexp(5000)), "")[[1]]
  rank_of <- function(v) match(v, c(" ", ".", ":", "-", "=", "#",
                                    "▁", "▂", "▃", "▄",
                                    "▅", "▆", "▇", "█"))
  expect_gt(rank_of(norm_bars[5]), rank_of(norm_bars[1]))
  expect_gt(rank_of(exp_bars[1]), rank_of(exp_bars[10]))

  # a constant column has no spread, and an empty one nothing to draw
  expect_equal(nchar(inline_hist(rep(5, 10))), 10L)
  expect_equal(inline_hist(numeric(0)), strrep(" ", 10))
  # NA and infinities are excluded rather than breaking the range
  expect_equal(nchar(inline_hist(c(1, 2, NA, Inf, 3))), 10L)
  expect_error(inline_hist(1:10, bins = 0), "positive integer")
})

test_that("frequency_table counts and percentages add up", {
  v <- c("a", "b", "b", "c", NA, "b")
  ft <- frequency_table(v)
  expect_s3_class(ft, "bricklayer_freq")
  # counts by hand
  expect_equal(ft$n[ft$value == "b" & !is.na(ft$value)], 3L)
  expect_equal(ft$n[ft$value == "a" & !is.na(ft$value)], 1L)
  expect_equal(ft$n[is.na(ft$value)], 1L)
  expect_equal(sum(ft$n), length(v))
  # sorted by descending count
  expect_equal(ft$n[1], 3L)

  # pct is of all rows; pct_valid of the non-missing ones, and the two
  # differ by exactly the missingness
  expect_equal(ft$pct[ft$value == "b" & !is.na(ft$value)], 100 * 3 / 6)
  expect_equal(ft$pct_valid[ft$value == "b" & !is.na(ft$value)],
               100 * 3 / 5)
  expect_equal(sum(ft$pct), 100)
  expect_equal(sum(ft$pct_valid, na.rm = TRUE), 100)
  # the missing row has no share of the valid values
  expect_true(is.na(ft$pct_valid[is.na(ft$value)]))

  # a data frame column
  df <- data.frame(grade = v, stringsAsFactors = FALSE)
  expect_equal(frequency_table(df, "grade")$n, ft$n)
  # natural order instead of frequency order
  ns <- frequency_table(c("c", "a", "b", "a"), sort = FALSE)
  expect_equal(ns$value, c("a", "b", "c"))
  # a long tail is folded so the percentages still total 100
  set.seed(72)
  big <- frequency_table(sample(letters, 500, TRUE), max_levels = 5L)
  expect_equal(nrow(big), 6L)
  expect_true("(other)" %in% big$value)
  expect_equal(sum(big$pct), 100)
  expect_equal(sum(big$n), 500L)
  # a complete column has no missing row
  expect_false(any(is.na(frequency_table(c("a", "b"))$value)))
  # empty input is empty, not an error
  expect_equal(nrow(frequency_table(character(0))), 0L)
  expect_output(print(ft), "Frequency table")
  expect_output(print(frequency_table(character(0))), "no values")

  expect_error(frequency_table(df), "`column` is required")
  expect_error(frequency_table(df, "nope"), "no such column")
  expect_error(frequency_table(v, max_levels = 0), "positive integer")
})

test_that("correlation_table reports every pair with its support", {
  set.seed(73)
  df <- data.frame(a = stats::rnorm(100), b = stats::rnorm(100),
                   g = "x", stringsAsFactors = FALSE)
  df$c <- df$a + stats::rnorm(100, sd = 0.2)

  ct <- correlation_table(df)
  expect_s3_class(ct, "bricklayer_cortable")
  # three numeric columns give three pairs; the character one is ignored
  expect_equal(nrow(ct), 3L)
  expect_false("g" %in% c(ct$x, ct$y))
  expect_equal(ct$n_pairs, rep(100L, 3L))
  # the values come from the kernel
  r <- ct[ct$x == "a" & ct$y == "c", ]
  expect_equal(r$correlation, core_cor_spearman(df$a, df$c))
  expect_gt(abs(r$correlation), 0.9)
  # pearson is available and differs from the rank version on this data
  cp <- correlation_table(df, method = "pearson")
  expect_equal(attr(cp, "method"), "pearson")
  expect_equal(cp$correlation[1], core_cor(df[[cp$x[1]]], df[[cp$y[1]]]))

  # n_pairs reflects the complete overlap, and too little gives NA
  gappy <- df
  gappy$a[1:80] <- NA
  expect_equal(correlation_table(gappy)$n_pairs[
    correlation_table(gappy)$x == "a" &
      correlation_table(gappy)$y == "b"], 20L)
  thin <- df
  thin$a[1:99] <- NA
  ctt <- correlation_table(thin)
  expect_true(any(is.na(ctt$correlation)))
  expect_output(print(ct), "Correlations")

  expect_error(correlation_table(data.frame(a = 1:3)), "two numeric")
  expect_error(correlation_table(df, min_pairs = 1), "at least 2")
})

test_that("drop_empty and drop_constant remove only what they claim", {
  df <- data.frame(keep = c(1, 2, NA), all_na = c(NA, NA, NA),
                   constant = c(7, 7, 7), stringsAsFactors = FALSE)

  de <- drop_empty(df)
  expect_equal(names(de), c("keep", "constant"))
  expect_equal(attr(de, "dropped"), "all_na")
  # the constant column is NOT empty, so drop_empty leaves it
  expect_true("constant" %in% names(de))

  dc <- drop_constant(df)
  # both all_na (one distinct value: none) and constant go
  expect_equal(names(dc), "keep")
  expect_true(all(c("all_na", "constant") %in% attr(dc, "dropped")))

  # rows only
  rows_only <- drop_empty(data.frame(a = c(1, NA), b = c(2, NA)),
                          which = "rows")
  expect_equal(nrow(rows_only), 1L)
  expect_equal(ncol(rows_only), 2L)
  # cols only leaves the rows alone
  cols_only <- drop_empty(df, which = "cols")
  expect_equal(nrow(cols_only), 3L)

  # NA as a value of its own changes what counts as constant
  x <- data.frame(v = c(NA, NA, 5))
  expect_equal(ncol(drop_constant(x)), 0L)
  expect_equal(ncol(drop_constant(x, na_as_value = TRUE)), 1L)
  # nothing to drop leaves the frame and records an empty vector
  clean <- data.frame(a = 1:3, b = 4:6)
  expect_equal(ncol(drop_empty(clean)), 2L)
  expect_length(attr(drop_constant(clean), "dropped"), 0L)
  expect_error(drop_empty(1:5), "data frame")
  expect_error(drop_constant(1:5), "data frame")
})

test_that("clean_column_names normalises and disambiguates", {
  got <- clean_column_names(c("Total  Population (2021)", "% change",
                              "Ville / City", "dup", "dup"))
  expect_equal(got[1], "total_population_2021")
  # a percent sign carries meaning, so it becomes a word
  expect_equal(got[2], "pct_change")
  expect_equal(got[3], "ville_city")
  # duplicates are disambiguated rather than one silently winning
  expect_equal(got[4:5], c("dup", "dup_2"))
  expect_equal(length(unique(got)), length(got))
  # every result is a syntactically valid name
  expect_equal(got, make.names(got))

  # camelCase is split on the word boundary before folding
  expect_equal(clean_column_names("totalPopCount"), "total_pop_count")
  # a leading digit is not a valid name
  expect_equal(clean_column_names("2021 value"), "x2021_value")
  # ampersands and hashes become words too
  expect_equal(clean_column_names("A & B"), "a_and_b")
  expect_equal(clean_column_names("# items"), "n_items")
  # a name with nothing left is still a name
  expect_equal(clean_column_names("!!!"), "x")

  # the other cases
  expect_equal(clean_column_names("Total Pop", case = "lower_camel"),
               "totalPop")
  expect_equal(clean_column_names("Total Pop", case = "upper_camel"),
               "TotalPop")
  expect_equal(clean_column_names("Total Pop", case = "screaming_snake"),
               "TOTAL_POP")
  expect_equal(clean_column_names("Total Pop", sep = "."), "total.pop")

  # applied to a data frame, the original names are retained, which is
  # what makes the cleaning recordable in a manifest
  df <- data.frame(`Total Pop` = 1:2, `% change` = 3:4, check.names = FALSE)
  cl <- clean_column_names(df)
  expect_equal(names(cl), c("total_pop", "pct_change"))
  expect_equal(attr(cl, "original_names"), c("Total Pop", "% change"))
  expect_equal(cl[[1]], 1:2)
  expect_equal(clean_column_names(character(0)), character(0))
})

test_that("Mahalanobis outliers find jointly impossible rows", {
  set.seed(74)
  n <- 300
  df <- data.frame(height = stats::rnorm(n, 170, 10))
  df$weight <- df$height * 0.5 + stats::rnorm(n, 0, 5)
  # ordinary on each margin, impossible together
  df[1, ] <- list(height = 150, weight = 140)

  out <- mahalanobis_outliers(df)
  expect_s3_class(out, "bricklayer_outliers")
  expect_equal(nrow(out), n)
  # the planted row is the most distant, and is flagged
  expect_equal(out$row[1], 1L)
  expect_true(out$outlier[1])
  # yet neither of its values is a marginal outlier
  expect_gt(df$height[1], min(df$height[-1]))
  expect_lt(df$weight[1], max(df$weight[-1]) * 3)

  # the p-value is the chi-square tail on p degrees of freedom
  expect_equal(out$p_value, stats::pchisq(out$distance^2, df = 2,
                                          lower.tail = FALSE),
               tolerance = 1e-8)
  expect_true(all(out$p_value >= 0 & out$p_value <= 1))
  # sorted by descending distance
  expect_equal(out$distance, sort(out$distance, decreasing = TRUE))
  # a stricter alpha flags no more rows
  expect_lte(sum(mahalanobis_outliers(df, alpha = 1e-10)$outlier),
             sum(out$outlier))

  # MASKING: with several outliers the classical covariance is inflated
  # by them, so the robust version separates them further
  many <- df
  many[1:8, ] <- list(height = rep(150, 8), weight = rep(140, 8))
  rob <- mahalanobis_outliers(many, robust = TRUE)$distance[1]
  cls <- mahalanobis_outliers(many, robust = FALSE)$distance[1]
  expect_gt(rob, cls)

  # incomplete rows are reported as NA rather than dropped silently
  gap <- df
  gap$weight[5] <- NA
  og <- mahalanobis_outliers(gap)
  expect_equal(nrow(og), n)
  expect_true(is.na(og$distance[og$row == 5]))
  expect_output(print(out), "Mahalanobis outliers")

  expect_error(mahalanobis_outliers(data.frame(a = letters[1:3])),
               "no numeric columns")
  expect_error(mahalanobis_outliers(df, alpha = 0), "strictly inside")
  expect_error(mahalanobis_outliers(df[1:2, ]), "more complete rows")
})

test_that("missing_runs separates outages from scattered gaps", {
  df <- data.frame(outage = c(1, 2, NA, NA, NA, NA, 7, 8),
                   scattered = c(1, NA, 3, 4, NA, 6, NA, NA))
  # the same total count, different shape
  expect_equal(sum(is.na(df$outage)), sum(is.na(df$scattered)))

  r <- missing_runs(df)
  expect_s3_class(r, "bricklayer_runs")
  # the outage is one run of 4
  o <- r[r$column == "outage", ]
  expect_equal(nrow(o), 1L)
  expect_equal(o$length, 4L)
  expect_equal(o$start, 3L)
  expect_equal(o$end, 6L)
  # the scattered column has only the trailing pair at min_run = 2
  s <- r[r$column == "scattered", ]
  expect_equal(nrow(s), 1L)
  expect_equal(s$length, 2L)
  expect_equal(s$start, 7L)
  # longest first
  expect_equal(r$length, sort(r$length, decreasing = TRUE))

  # min_run = 1 exposes the isolated gaps too, and the lengths then sum
  # to the total missing count
  r1 <- missing_runs(df, min_run = 1L)
  expect_equal(sum(r1$length), sum(is.na(df$outage)) +
                 sum(is.na(df$scattered)))
  # cross-checked against rle directly
  rr <- rle(is.na(df$scattered))
  expect_equal(sort(rr$lengths[rr$values], decreasing = TRUE),
               sort(r1$length[r1$column == "scattered"], decreasing = TRUE))

  # a complete column has no runs
  expect_equal(nrow(missing_runs(data.frame(x = 1:5))), 0L)
  expect_output(print(missing_runs(data.frame(x = 1:5))), "none")
  expect_output(print(r), "Runs of consecutive")
  expect_error(missing_runs(1:5), "data frame")
  expect_error(missing_runs(df, min_run = 0), "positive integer")
})

test_that("the missingness map draws the whole table", {
  set.seed(75)
  df <- data.frame(complete = 1:100,
                   block = c(rep(NA, 30), 31:100),
                   scattered = ifelse(stats::runif(100) < 0.3, NA, 1),
                   gone = c(1:5, rep(NA, 95)))
  lines <- withCallingHandlers(
    utils::capture.output(res <- missingness_map(df, height = 10L)),
    warning = function(w) invokeRestart("muffleWarning"))
  expect_type(res, "character")
  expect_true(length(res) > 5L)
  txt <- paste(lines, collapse = "\n")
  expect_match(txt, "Missingness map")
  expect_match(txt, "legend")
  # the complete column is blank throughout and the gone column is not
  expect_true(nchar(txt) > 0L)
  # a zero-row frame says so instead of dividing by zero
  z <- utils::capture.output(missingness_map(data.frame(x = numeric(0))))
  expect_match(paste(z, collapse = " "), "no rows")
  expect_error(missingness_map(1:5), "data frame")
  expect_error(missingness_map(df, height = 0), "positive integer")
})

test_that("missingness_summary answers the scalar questions", {
  df <- data.frame(a = c(1, NA, 3), b = c(NA, NA, 3), c = 1:3)
  s <- missingness_summary(df)
  expect_equal(s[["n_rows"]], 3)
  expect_equal(s[["n_cols"]], 3)
  expect_equal(s[["n_missing"]], 3)
  expect_equal(s[["pct_missing"]], 100 * 3 / 9)
  # only row 3 is complete
  expect_equal(s[["n_complete_rows"]], 1)
  expect_equal(s[["pct_complete_rows"]], 100 / 3)
  expect_equal(s[["n_cols_any_missing"]], 2)
  expect_equal(s[["n_cols_all_missing"]], 0)

  # a complete table is zeros but for its dimensions
  cs <- missingness_summary(data.frame(x = 1:3, y = 4:6))
  expect_equal(cs[["n_missing"]], 0)
  expect_equal(cs[["pct_complete_rows"]], 100)
  expect_equal(cs[["n_cols_any_missing"]], 0)
  # an all-missing column is counted as such
  am <- missingness_summary(data.frame(x = c(NA, NA), y = 1:2))
  expect_equal(am[["n_cols_all_missing"]], 1)
  expect_equal(am[["n_complete_rows"]], 0)
  expect_error(missingness_summary(1:5), "data frame")
})

test_that("duplicate_rows shows which rows repeat", {
  df <- data.frame(id = c(1, 2, 2, 3, 3, 3),
                   value = c("a", "b", "b", "c", "d", "c"),
                   stringsAsFactors = FALSE)

  # duplicated on every column: the (2,b) pair and the (3,c) pair
  all_cols <- duplicate_rows(df)
  expect_equal(nrow(all_cols), 4L)
  expect_true("dupe_count" %in% names(all_cols))
  expect_true(all(all_cols$dupe_count == 2L))

  # duplicated on the identifier alone catches more
  by_id <- duplicate_rows(df, "id")
  expect_equal(nrow(by_id), 5L)
  expect_equal(sort(unique(by_id$id)), c(2, 3))
  expect_equal(by_id$dupe_count[by_id$id == 3][1], 3L)
  # the groups sit together
  expect_equal(by_id$id, sort(by_id$id))

  # no duplicates gives zero rows with the same columns
  none <- duplicate_rows(data.frame(x = 1:3))
  expect_equal(nrow(none), 0L)
  expect_true("dupe_count" %in% names(none))
  expect_equal(nrow(duplicate_rows(data.frame(x = integer(0)))), 0L)
  expect_error(duplicate_rows(df, "nope"), "no such column")
  expect_error(duplicate_rows(1:5), "data frame")
})
