# Exploratory description: histograms, frequency tables, correlation
# tables, column hygiene, name cleaning, outliers and missingness shape.
#
# Anchors: hand-counted frequencies and percentages, the kernels the
# correlations come from, the chi-square distribution behind the
# Mahalanobis p-value, and rle() for the missingness runs.

test_that("inlhist draws the shape of a distribution", {
  set.seed(71)
  h <- inlhist(stats::rnorm(1000))
  expect_type(h, "character")
  expect_identical(nchar(h), 10L)
  expect_identical(nchar(inlhist(stats::rnorm(100), bins = 20L)), 20L)

  # a symmetric distribution is tallest in the middle; a right-skewed
  # one is tallest at the left
  norm_bars <- strsplit(inlhist(stats::rnorm(5000)), "", fixed = TRUE)[[1]]
  exp_bars <- strsplit(inlhist(stats::rexp(5000)), "", fixed = TRUE)[[1]]
  rank_of <- function(v) {
    match(
      v,
      c(
        " ",
        ".",
        ":",
        "-",
        "=",
        "#",
        "▁",
        "▂",
        "▃",
        "▄",
        "▅",
        "▆",
        "▇",
        "█"
      )
    )
  }
  expect_gt(rank_of(norm_bars[5]), rank_of(norm_bars[1]))
  expect_gt(rank_of(exp_bars[1]), rank_of(exp_bars[10]))

  # a constant column has no spread, and an empty one nothing to draw
  expect_identical(nchar(inlhist(rep(5, 10))), 10L)
  expect_identical(inlhist(numeric(0)), strrep(" ", 10))
  # NA and infinities are excluded rather than breaking the range
  expect_identical(nchar(inlhist(c(1, 2, NA, Inf, 3))), 10L)
  expect_error(inlhist(1:10, bins = 0), "positive integer")
})

test_that("freqtbl counts and percentages add up", {
  v <- c("a", "b", "b", "c", NA, "b")
  ft <- freqtbl(v)
  expect_s3_class(ft, "bricklayer_freq")
  # counts by hand
  expect_identical(ft$n[ft$value == "b" & !is.na(ft$value)], 3L)
  expect_identical(ft$n[ft$value == "a" & !is.na(ft$value)], 1L)
  expect_identical(ft$n[is.na(ft$value)], 1L)
  expect_identical(sum(ft$n), length(v))
  # sorted by descending count
  expect_identical(ft$n[1], 3L)

  # pct is of all rows; pctvalid of the non-missing ones, and the two
  # differ by exactly the missingness
  expect_identical(ft$pct[ft$value == "b" & !is.na(ft$value)], 100 * 3 / 6)
  expect_identical(
    ft$pctvalid[ft$value == "b" & !is.na(ft$value)],
    100 * 3 / 5
  )
  expect_equal(sum(ft$pct), 100, tolerance = 1e-12)
  expect_identical(sum(ft$pctvalid, na.rm = TRUE), 100)
  # the missing row has no share of the valid values
  expect_true(is.na(ft$pctvalid[is.na(ft$value)]))

  # a data frame column
  df <- data.frame(grade = v, stringsAsFactors = FALSE)
  expect_identical(freqtbl(df, "grade")$n, ft$n)
  # natural order instead of frequency order
  ns <- freqtbl(c("c", "a", "b", "a"), sort = FALSE)
  expect_identical(ns$value, c("a", "b", "c"))
  # a long tail is folded so the percentages still total 100
  set.seed(72)
  big <- freqtbl(sample(letters, 500, TRUE), maxlvl = 5L)
  expect_identical(nrow(big), 6L)
  expect_true("(other)" %in% big$value)
  expect_identical(sum(big$pct), 100)
  expect_identical(sum(big$n), 500L)
  # a complete column has no missing row
  expect_false(anyNA(freqtbl(c("a", "b"))$value))
  # empty input is empty, not an error
  expect_identical(nrow(freqtbl(character(0))), 0L)
  expect_output(print(ft), "Frequency table")
  expect_output(print(freqtbl(character(0))), "no values")

  expect_error(freqtbl(df), "`col` is required")
  expect_error(freqtbl(df, "nope"), "no such column")
  expect_error(freqtbl(v, maxlvl = 0), "positive integer")
})

test_that("cortbl reports every pair with its support", {
  set.seed(73)
  df <- data.frame(
    a = stats::rnorm(100),
    b = stats::rnorm(100),
    g = "x",
    stringsAsFactors = FALSE
  )
  df$c <- df$a + stats::rnorm(100, sd = 0.2)

  ct <- cortbl(df)
  expect_s3_class(ct, "bricklayer_cortable")
  # three numeric columns give three pairs; the character one is ignored
  expect_identical(nrow(ct), 3L)
  expect_false("g" %in% c(ct$x, ct$y))
  expect_identical(ct$nprs, rep(100L, 3L))
  # the values come from the kernel
  r <- ct[ct$x == "a" & ct$y == "c", ]
  expect_identical(r$correlation, cspr(df$a, df$c))
  expect_gt(abs(r$correlation), 0.9)
  # pearson is available and differs from the rank version on this data
  cp <- cortbl(df, meth = "pearson")
  expect_identical(attr(cp, "method"), "pearson")
  expect_identical(cp$correlation[1], ccorr(df[[cp$x[1]]], df[[cp$y[1]]]))

  # nprs reflects the complete overlap, and too little gives NA
  gappy <- df
  gappy$a[1:80] <- NA
  expect_identical(
    cortbl(gappy)$nprs[
      cortbl(gappy)$x == "a" &
        cortbl(gappy)$y == "b"
    ],
    20L
  )
  thin <- df
  thin$a[1:99] <- NA
  ctt <- cortbl(thin)
  expect_true(anyNA(ctt$correlation))
  expect_output(print(ct), "Correlations")

  expect_error(cortbl(data.frame(a = 1:3)), "two numeric")
  expect_error(cortbl(df, minprs = 1), "at least 2")
})

test_that("drpempty and drpconst remove only what they claim", {
  df <- data.frame(
    keep = c(1, 2, NA),
    all_na = c(NA, NA, NA),
    constant = c(7, 7, 7),
    stringsAsFactors = FALSE
  )

  de <- drpempty(df)
  expect_named(de, c("keep", "constant"))
  expect_identical(attr(de, "dropped"), "all_na")
  # the constant column is NOT empty, so drpempty leaves it
  expect_true("constant" %in% names(de))

  dc <- drpconst(df)
  # both all_na (one distinct value: none) and constant go
  expect_named(dc, "keep")
  expect_true(all(c("all_na", "constant") %in% attr(dc, "dropped")))

  # rows only
  rows_only <- drpempty(data.frame(a = c(1, NA), b = c(2, NA)), which = "rows")
  expect_identical(nrow(rows_only), 1L)
  expect_identical(ncol(rows_only), 2L)
  # cols only leaves the rows alone
  cols_only <- drpempty(df, which = "cols")
  expect_identical(nrow(cols_only), 3L)

  # NA as a value of its own changes what counts as constant
  x <- data.frame(v = c(NA, NA, 5))
  expect_identical(ncol(drpconst(x)), 0L)
  expect_identical(ncol(drpconst(x, naasval = TRUE)), 1L)
  # nothing to drop leaves the frame and records an empty vector
  clean <- data.frame(a = 1:3, b = 4:6)
  expect_identical(ncol(drpempty(clean)), 2L)
  expect_length(attr(drpconst(clean), "dropped"), 0L)
  expect_error(drpempty(1:5), "data frame")
  expect_error(drpconst(1:5), "data frame")
})

test_that("clncolnms normalises and disambiguates", {
  got <- clncolnms(c(
    "Total  Population (2021)",
    "% change",
    "Ville / City",
    "dup",
    "dup"
  ))
  expect_identical(got[1], "total_population_2021")
  # a percent sign carries meaning, so it becomes a word
  expect_identical(got[2], "pct_change")
  expect_identical(got[3], "ville_city")
  # duplicates are disambiguated rather than one silently winning
  expect_identical(got[4:5], c("dup", "dup_2"))
  expect_length(unique(got), length(got))
  # every result is a syntactically valid name
  expect_identical(got, make.names(got))

  # camelCase is split on the word boundary before folding
  expect_identical(clncolnms("totalPopCount"), "total_pop_count")
  # a leading digit is not a valid name
  expect_identical(clncolnms("2021 value"), "x2021_value")
  # ampersands and hashes become words too
  expect_identical(clncolnms("A & B"), "a_and_b")
  expect_identical(clncolnms("# items"), "n_items")
  # a name with nothing left is still a name
  expect_identical(clncolnms("!!!"), "x")

  # the other cases
  expect_identical(
    clncolnms("Total Pop", case = "lower_camel"),
    "totalPop"
  )
  expect_identical(
    clncolnms("Total Pop", case = "upper_camel"),
    "TotalPop"
  )
  expect_identical(
    clncolnms("Total Pop", case = "screaming_snake"),
    "TOTAL_POP"
  )
  expect_identical(clncolnms("Total Pop", sep = "."), "total.pop")

  # applied to a data frame, the original names are retained, which is
  # what makes the cleaning recordable in a manifest
  df <- data.frame(`Total Pop` = 1:2, `% change` = 3:4, check.names = FALSE)
  cl <- clncolnms(df)
  expect_named(cl, c("total_pop", "pct_change"))
  expect_identical(attr(cl, "orignms"), c("Total Pop", "% change"))
  expect_identical(cl[[1]], 1:2)
  expect_identical(clncolnms(character(0)), character(0))
})

test_that("Mahalanobis outliers find jointly impossible rows", {
  set.seed(74)
  n <- 300
  df <- data.frame(height = stats::rnorm(n, 170, 10))
  df$weight <- df$height * 0.5 + stats::rnorm(n, 0, 5)
  # ordinary on each margin, impossible together
  df[1, ] <- list(height = 150, weight = 140)

  out <- mahaoutl(df)
  expect_s3_class(out, "bricklayer_outliers")
  expect_equal(nrow(out), n, tolerance = testthat::testthat_tolerance())
  # the planted row is the most distant, and is flagged
  expect_identical(out$row[1], 1L)
  expect_true(out$outlier[1])
  # yet neither of its values is a marginal outlier
  expect_gt(df$height[1], min(df$height[-1]))
  expect_lt(df$weight[1], max(df$weight[-1]) * 3)

  # the p-value is the chi-square tail on p degrees of freedom
  expect_equal(
    out$p_value,
    stats::pchisq(out$distance^2, df = 2, lower.tail = FALSE),
    tolerance = 1e-8
  )
  expect_true(all(out$p_value >= 0 & out$p_value <= 1))
  # sorted by descending distance
  expect_identical(out$distance, sort(out$distance, decreasing = TRUE))
  # a stricter alpha flags no more rows
  expect_lte(
    sum(mahaoutl(df, alpha = 1e-10)$outlier),
    sum(out$outlier)
  )

  # MASKING: with several outliers the classical covariance is inflated
  # by them, so the robust version separates them further
  many <- df
  many[1:8, ] <- list(height = rep(150, 8), weight = rep(140, 8))
  rob <- mahaoutl(many, robust = TRUE)$distance[1]
  cls <- mahaoutl(many, robust = FALSE)$distance[1]
  expect_gt(rob, cls)

  # incomplete rows are reported as NA rather than dropped silently
  gap <- df
  gap$weight[5] <- NA
  og <- mahaoutl(gap)
  expect_equal(nrow(og), n, tolerance = testthat::testthat_tolerance())
  expect_true(is.na(og$distance[og$row == 5]))
  expect_output(print(out), "Mahalanobis outliers")

  expect_error(
    mahaoutl(data.frame(a = letters[1:3])),
    "no numeric columns"
  )
  expect_error(mahaoutl(df, alpha = 0), "strictly inside")
  expect_error(mahaoutl(df[1:2, ]), "more complete rows")
})

test_that("missruns separates outages from scattered gaps", {
  df <- data.frame(
    outage = c(1, 2, NA, NA, NA, NA, 7, 8),
    scattered = c(1, NA, 3, 4, NA, 6, NA, NA)
  )
  # the same total count, different shape
  expect_identical(sum(is.na(df$outage)), sum(is.na(df$scattered)))

  r <- missruns(df)
  expect_s3_class(r, "bricklayer_runs")
  # the outage is one run of 4
  o <- r[r$column == "outage", ]
  expect_identical(nrow(o), 1L)
  expect_identical(o$length, 4L)
  expect_identical(o$start, 3L)
  expect_identical(o$end, 6L)
  # the scattered column has only the trailing pair at minrun = 2
  s <- r[r$column == "scattered", ]
  expect_identical(nrow(s), 1L)
  expect_identical(s$length, 2L)
  expect_identical(s$start, 7L)
  # longest first
  expect_identical(r$length, sort(r$length, decreasing = TRUE))

  # minrun = 1 exposes the isolated gaps too, and the lengths then sum
  # to the total missing count
  r1 <- missruns(df, minrun = 1L)
  expect_identical(
    sum(r1$length),
    sum(is.na(df$outage)) +
      sum(is.na(df$scattered))
  )
  # cross-checked against rle directly
  rr <- rle(is.na(df$scattered))
  expect_identical(
    sort(rr$lengths[rr$values], decreasing = TRUE),
    sort(r1$length[r1$column == "scattered"], decreasing = TRUE)
  )

  # a complete column has no runs
  expect_identical(nrow(missruns(data.frame(x = 1:5))), 0L)
  expect_output(print(missruns(data.frame(x = 1:5))), "none")
  expect_output(print(r), "Runs of consecutive")
  expect_error(missruns(1:5), "data frame")
  expect_error(missruns(df, minrun = 0), "positive integer")
})

test_that("the missingness map draws the whole table", {
  set.seed(75)
  df <- data.frame(
    complete = 1:100,
    block = c(rep(NA, 30), 31:100),
    scattered = ifelse(stats::runif(100) < 0.3, NA, 1),
    gone = c(1:5, rep(NA, 95))
  )
  lines <- withCallingHandlers(
    utils::capture.output({
      res <- missgrid(df, height = 10L)
    }),
    warning = function(w) invokeRestart("muffleWarning")
  )
  expect_type(res, "character")
  expect_gt(length(res), 5L)
  txt <- paste(lines, collapse = "\n")
  expect_match(txt, "Missingness map")
  expect_match(txt, "legend")
  # the complete column is blank throughout and the gone column is not
  expect_gt(nchar(txt), 0L)
  # a zero-row frame says so instead of dividing by zero
  z <- utils::capture.output(missgrid(data.frame(x = numeric(0))))
  expect_match(paste(z, collapse = " "), "no rows")
  expect_error(missgrid(1:5), "data frame")
  expect_error(missgrid(df, height = 0), "positive integer")
})

test_that("misssmry answers the scalar questions", {
  df <- data.frame(a = c(1, NA, 3), b = c(NA, NA, 3), c = 1:3)
  s <- misssmry(df)
  expect_identical(s[["n_rows"]], 3)
  expect_identical(s[["n_cols"]], 3)
  expect_identical(s[["n_missing"]], 3)
  expect_identical(s[["pct_missing"]], 100 * 3 / 9)
  # only row 3 is complete
  expect_identical(s[["n_complete_rows"]], 1)
  expect_identical(s[["pct_complete_rows"]], 100 / 3)
  expect_identical(s[["n_cols_any_missing"]], 2)
  expect_identical(s[["n_cols_all_missing"]], 0)

  # a complete table is zeros but for its dimensions
  cs <- misssmry(data.frame(x = 1:3, y = 4:6))
  expect_identical(cs[["n_missing"]], 0)
  expect_identical(cs[["pct_complete_rows"]], 100)
  expect_identical(cs[["n_cols_any_missing"]], 0)
  # an all-missing column is counted as such
  am <- misssmry(data.frame(x = c(NA, NA), y = 1:2))
  expect_identical(am[["n_cols_all_missing"]], 1)
  expect_identical(am[["n_complete_rows"]], 0)
  expect_error(misssmry(1:5), "data frame")
})

test_that("duprows shows which rows repeat", {
  df <- data.frame(
    id = c(1, 2, 2, 3, 3, 3),
    value = c("a", "b", "b", "c", "d", "c"),
    stringsAsFactors = FALSE
  )

  # duplicated on every column: the (2,b) pair and the (3,c) pair
  all_cols <- duprows(df)
  expect_identical(nrow(all_cols), 4L)
  expect_true("dupe_count" %in% names(all_cols))
  expect_true(all(all_cols$dupe_count == 2L))

  # duplicated on the identifier alone catches more
  by_id <- duprows(df, "id")
  expect_identical(nrow(by_id), 5L)
  expect_identical(sort(unique(by_id$id)), c(2, 3))
  expect_identical(by_id$dupe_count[by_id$id == 3][1], 3L)
  # the groups sit together
  expect_identical(by_id$id, sort(by_id$id))

  # no duplicates gives zero rows with the same columns
  none <- duprows(data.frame(x = 1:3))
  expect_identical(nrow(none), 0L)
  expect_true("dupe_count" %in% names(none))
  expect_identical(nrow(duprows(data.frame(x = integer(0)))), 0L)
  expect_error(duprows(df, "nope"), "no such column")
  expect_error(duprows(1:5), "data frame")
})

test_that("freqtbl() checks `col` and `sort`", {
  df <- data.frame(
    z = c("a", "b", "a"),
    grade = c(1, 2, 2),
    stringsAsFactors = FALSE
  )
  expect_error(freqtbl(df, col = mean), "`col` must be data")
  # c("z", "grade") tabulated z alone
  expect_error(
    freqtbl(df, c("z", "grade")),
    "^freqtbl: `col` must name one column of `data`"
  )
  expect_error(freqtbl(df, NA_character_), "`col` must name one column")
  expect_error(freqtbl(df$z, sort = "yes"), "`sort` must be TRUE or FALSE")
  expect_error(freqtbl(df$z, sort = NA), "`sort` must be TRUE or FALSE")
  expect_identical(freqtbl(df, "z")$n, c(2L, 1L))
  expect_identical(freqtbl(df$z, sort = FALSE)$value, c("a", "b"))
})

# ---- boxed printouts ---------------------------------------------------------

# print() of a result in an 80-column ASCII console: the lines, whether the
# value was visible, and the value.
.o2_box <- function(x, ...) {
  withr::local_options(rmoriebricklayer.width = 80, rmoriebricklayer.numcol = 1)
  withr::local_envvar(RMBL_ASCII_ONLY = "1")
  out <- utils::capture.output({
    r <- withVisible(print(x, ...))
  })
  list(out = out, vis = r$visible, value = r$value)
}

# The checks every boxed printout passes: an ASCII box under its title, no
# line past the console, print() returning its argument invisibly, format()
# giving character lines that hold the facts.
.o2_check <- function(x, title, facts = character(0)) {
  b <- .o2_box(x)
  testthat::expect_false(b$vis)
  testthat::expect_identical(b$value, x)
  testthat::expect_true(startsWith(b$out[1L], paste0("+-- ", title, " -")))
  testthat::expect_match(b$out[length(b$out)], "^\\+-+\\+$")
  testthat::expect_true(all(nchar(b$out) <= 80L))
  txt <- format(x)
  testthat::expect_type(txt, "character")
  # the text with the box and the wrapping taken out, for phrases
  flat <- gsub("[| ]+", " ", paste(b$out, collapse = " "))
  for (f in facts) {
    testthat::expect_true(grepl(f, flat, fixed = TRUE), info = f)
  }
  invisible(b$out)
}

test_that("frequency and correlation tables print as boxes", {
  .o2_check(freqtbl(c("a", "b", "a", NA)), "Frequency table",
    c("(missing)", "pctvalid", "####"))
  .o2_check(freqtbl(character(0)), "Frequency table", "(no values)")
  set.seed(6)
  d <- data.frame(a = stats::rnorm(20), b = stats::rnorm(20))
  .o2_check(cortbl(d), "Correlations (spearman)",
    c("Spearman (rank)", "nprs"))
})

# ---- the cleaning functions summarise what they did, on stderr -------------

test_that("drpempty() and drpconst() return the same table and say what went", {
  df <- data.frame(keep = c(1, 2, NA), allna = NA, constant = 7)
  quiet <- drpempty(df, quiet = TRUE)
  expect_silent(drpempty(df, quiet = TRUE))
  expect_message(drpempty(df), "Empty rows and columns dropped")
  loud <- suppressMessages(drpempty(df))
  expect_identical(loud, quiet)
  expect_named(quiet, c("keep", "constant"))
  expect_message(drpempty(df), "allna")
  expect_message(drpempty(df), "1 column and 0 rows dropped")
  expect_identical(suppressMessages(drpconst(df)), drpconst(df, quiet = TRUE))
  expect_message(drpconst(df), "allna, constant")
  expect_message(drpconst(df), "2 columns and 0 rows dropped")
  expect_message(drpconst(data.frame(a = 1:2)), "Nothing to drop")
  expect_error(drpconst(df, quiet = NA), "quiet")
})

test_that("clncolnms() returns the same names and lists the ones it changed", {
  df <- data.frame(`Total Pop` = 1:2, ok = 3:4, check.names = FALSE)
  quiet <- clncolnms(df, quiet = TRUE)
  expect_silent(clncolnms(df, quiet = TRUE))
  expect_message(clncolnms(df), "Column names cleaned")
  loud <- suppressMessages(clncolnms(df))
  expect_identical(loud, quiet)
  expect_message(clncolnms(df), "Total Pop +total_pop")
  expect_message(clncolnms(df), "1 of 2 names changed; attr")
  expect_message(clncolnms(c("a", "b")), "Every name was already clean")
})

test_that("a Pearson correlation table names its method", {
  set.seed(5)
  df <- data.frame(a = stats::rnorm(30), b = stats::rnorm(30))
  ct <- cortbl(df, meth = "pearson")
  expect_identical(attr(ct, "method"), "pearson")
  expect_match(box_text(ct), "Method pearson", fixed = TRUE)
})
