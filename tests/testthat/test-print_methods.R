# The output surface. These assert what the reader actually gets: the
# verdict is present, the numbers behind it are present, a secret is
# never present, and the layout degrades to ASCII when asked.

test_that("the drift report leads with its verdict and shows the tests", {
  set.seed(31)
  ref <- data.frame(
    v = stats::rnorm(200),
    g = sample(c("a", "b"), 200, TRUE),
    stringsAsFactors = FALSE
  )
  cur <- data.frame(
    v = stats::rnorm(200, mean = 1.5),
    g = sample(c("a", "b"), 200, TRUE),
    stringsAsFactors = FALSE
  )

  d <- cpsdrft(ref, cur)
  txt <- format(d)
  expect_type(txt, "character")
  expect_gt(length(txt), 5L)
  all_of_it <- paste(txt, collapse = "\n")
  # the verdict, and the evidence behind it
  expect_match(all_of_it, "DRIFT DETECTED")
  expect_match(all_of_it, "Capsule drift report")
  expect_match(all_of_it, "Per-column tests")
  expect_match(all_of_it, "\\bv\\b")
  expect_match(all_of_it, "200")
  # print() emits the same lines and returns its argument invisibly
  expect_output(print(d), "DRIFT DETECTED")
  expect_false(withVisible(print(d))$visible)
  expect_identical(
    suppressWarnings(capture.output(print(d))),
    capture.output(.rmbl_cat(format(d), d))
  )

  # a clean comparison says so instead
  clean <- cpsdrft(ref, ref)
  expect_match(paste(format(clean), collapse = "\n"), "no drift detected")
  expect_false(grepl(
    "DRIFT DETECTED",
    paste(format(clean), collapse = "\n"),
    fixed = TRUE
  ))

  # added and removed columns are surfaced
  gone <- cpsdrft(ref, cur[, "v", drop = FALSE])
  expect_match(paste(format(gone), collapse = "\n"), "columns removed")
  more <- cur
  more$extra <- 1
  expect_match(
    paste(format(cpsdrft(ref, more)), collapse = "\n"),
    "columns added"
  )

  # the summary is the condensed form
  expect_output(print(summary(d)), "drift detected")
  expect_output(print(summary(clean)), "no drift detected")
})

test_that("the reports fall back to ASCII when told to", {
  old <- Sys.getenv("RMBL_ASCII_ONLY", unset = NA)
  on.exit(
    {
      if (is.na(old)) {
        Sys.unsetenv("RMBL_ASCII_ONLY")
      } else {
        Sys.setenv(RMBL_ASCII_ONLY = old)
      }
    },
    add = TRUE
  )
  Sys.setenv(RMBL_ASCII_ONLY = "1")

  set.seed(32)
  d <- cpsdrft(
    data.frame(v = stats::rnorm(80)),
    data.frame(v = stats::rnorm(80))
  )
  txt <- paste(format(d), collapse = "\n")
  # every character is representable in ASCII
  expect_false(grepl("[^\x01-\x7f]", txt, useBytes = TRUE))
  expect_match(txt, "no drift detected")

  b <- benfordtst(10^stats::runif(300, 0, 5))
  expect_false(grepl(
    "[^\x01-\x7f]",
    paste(format(b), collapse = "\n"),
    useBytes = TRUE
  ))
  k <- pqckg(height = 2)
  expect_false(grepl(
    "[^\x01-\x7f]",
    paste(format(k), collapse = "\n"),
    useBytes = TRUE
  ))
  expect_false(grepl(
    "[^\x01-\x7f]",
    paste(format(cpssign("m", k)), collapse = "\n"),
    useBytes = TRUE
  ))
})

test_that("the Benford report shows the digits and its own caveat", {
  set.seed(33)
  b <- benfordtst(10^stats::runif(2000, 0, 6))
  txt <- paste(format(b), collapse = "\n")
  expect_match(txt, "Benford first-digit screen")
  expect_match(txt, "consistent with Benford")
  expect_match(txt, "chi-square")
  # every digit is listed with its observed and expected share
  expect_match(txt, "digit")
  for (d in 1:9) {
    expect_match(txt, paste0("\\b", d, "\\b"))
  }
  expect_output(print(b), "Benford")

  # a failing screen says so, and says it is only a screen
  flat <- benfordtst(as.numeric(paste0(rep(1:9, each = 200), "00")))
  ftxt <- paste(format(flat), collapse = "\n")
  expect_match(ftxt, "departs from Benford")
  expect_match(ftxt, "screen only")
  expect_identical(unname(summary(b)[["df"]]), 8)
})

test_that("keys and signatures print without ever showing the secret", {
  s1 <- strrep("11", 32)
  s2 <- strrep("22", 32)
  key <- pqckg(height = 2, skseed = s1, pubseed = s2)
  # a key from given seeds is not registered at birth (review of 52a8883)
  xmssregkey(key)

  txt <- paste(format(key), collapse = "\n")
  expect_match(txt, "Signing key")
  expect_match(txt, key$root, fixed = TRUE)
  expect_match(txt, "0 of 4 signatures")
  expect_match(txt, "withheld")
  # the secret seed must not appear anywhere in the rendering
  expect_false(grepl(s1, txt, fixed = TRUE))
  expect_output(print(key), "Signing key")

  # the public key prints its root and nothing secret
  ptxt <- paste(format(signpubkey(key)), collapse = "\n")
  expect_match(ptxt, "Public verification key")
  expect_match(ptxt, key$root, fixed = TRUE)
  expect_false(grepl(s1, ptxt, fixed = TRUE))

  # the usage counter advances in the rendering as leaves are consumed
  sig <- cpssign("m", key)
  expect_match(
    paste(format(xmssadv(key, sig)), collapse = "\n"),
    "1 of 4 signatures"
  )

  # a signature prints its index and an abbreviated body, not 2 KB of hex
  stxt <- paste(format(sig), collapse = "\n")
  expect_match(stxt, "Capsule signature")
  expect_match(stxt, "xmss-sha256")
  expect_match(stxt, "2144 bytes")
  expect_match(stxt, "2 nodes")
  expect_lt(nchar(stxt), 1000L)
  expect_false(grepl(s1, stxt, fixed = TRUE))
  # an HMAC signature prints its tag in full, since it is short
  h <- cpssign("m", "k", "hmac")
  expect_match(paste(format(h), collapse = "\n"), h$signature, fixed = TRUE)
  expect_output(print(h), "hmac")
})

test_that("profcols describes each column by its own type", {
  set.seed(34)
  df <- data.frame(
    clean = stats::rnorm(100),
    skewed = c(stats::rnorm(99), 500),
    grade = sample(c("a", "b", "c"), 100, TRUE),
    gappy = c(rep(NA_real_, 10), stats::runif(90)),
    allna = rep(NA_real_, 100),
    stringsAsFactors = FALSE
  )
  p <- profcols(df)
  expect_s3_class(p, "bricklayer_profile")
  expect_identical(nrow(p), 5L)
  expect_identical(p$column, names(df))
  expect_true(all(
    c(
      "n_missing",
      "pct_missing",
      "median",
      "mad",
      "mean",
      "sd",
      "n_distinct",
      "skewness",
      "n_outliers"
    ) %in%
      names(p)
  ))

  # missingness is counted and expressed as a share
  expect_identical(p$n_missing[p$column == "gappy"], 10L)
  expect_identical(p$pct_missing[p$column == "gappy"], 10)
  expect_identical(p$n_missing[p$column == "clean"], 0L)

  # the numeric summaries agree with the kernels they come from
  expect_identical(p$mean[p$column == "clean"], mean(df$clean))
  expect_identical(p$median[p$column == "clean"], cmed(df$clean))
  expect_identical(p$mad[p$column == "clean"], cmad(df$clean))
  expect_equal(p$sd[p$column == "clean"], stats::sd(df$clean),
    tolerance = 1e-12)
  expect_identical(p$min[p$column == "clean"], min(df$clean))
  # and the NA-bearing column is summarised on its complete cases
  expect_identical(p$mean[p$column == "gappy"], mean(df$gappy, na.rm = TRUE))

  # the outlier announces itself as a gap between mean and median, and in
  # the fence count
  expect_gt(
    abs(
      p$mean[p$column == "skewed"] -
        p$median[p$column == "skewed"]
    ),
    1
  )
  expect_lt(
    abs(
      p$mean[p$column == "clean"] -
        p$median[p$column == "clean"]
    ),
    0.5
  )
  expect_gte(p$n_outliers[p$column == "skewed"], 1L)
  expect_gt(p$skewness[p$column == "skewed"], 1)

  # a categorical column reports levels and its most common value, and no
  # mean
  expect_true(is.na(p$mean[p$column == "grade"]))
  expect_identical(p$n_distinct[p$column == "grade"], 3L)
  expect_true(p$top[p$column == "grade"] %in% c("a", "b", "c"))
  expect_identical(
    p$top[p$column == "grade"],
    names(sort(table(df$grade), decreasing = TRUE))[1]
  )
  # an all-missing column reports nothing rather than guessing
  expect_true(is.na(p$mean[p$column == "allna"]))
  expect_identical(p$n_missing[p$column == "allna"], 100L)

  # the quantile columns are the ones asked for
  expect_true(all(c("q25", "q50", "q75") %in% names(p)))
  expect_identical(p$q50[p$column == "clean"], cmed(df$clean))
  expect_true("q10" %in% names(profcols(df, qnts = 0.1)))
  expect_false("q25" %in% names(profcols(df, qnts = 0.1)))

  expect_output(print(p), "Column profile")
  expect_false(withVisible(print(p))$visible)
  expect_error(profcols(1:5), "data frame")
  expect_error(profcols(data.frame()), "no columns")
})

test_that("a titled block prints as a box that fits the console", {
  withr::local_options(rmoriebricklayer.width = 60, rmoriebricklayer.numcol = 1)
  withr::local_envvar(RMBL_ASCII_ONLY = "1")
  long <- paste(rep("word", 30), collapse = " ")
  lines <- c(
    .rmbl_rule("Demo"),
    .rmbl_kv(list(a = "short", b = long)),
    .rmbl_rule()
  )
  out <- utils::capture.output(.rmbl_cat(lines))
  expect_match(out[1L], "^\\+-- Demo -+\\+$")
  expect_match(out[length(out)], "^\\+-+\\+$")
  expect_true(all(nchar(out) == nchar(out[1L])))
  expect_true(all(nchar(out) <= 59L))
  # the long value wraps under its own column
  expect_match(out[3L], "^\\|   b  word word")
  expect_match(out[4L], "^\\|      word")
})

test_that("a result with a verdict gets a status line and marked checks", {
  withr::local_options(width = 80, rmoriebricklayer.numcol = 1)
  withr::local_envvar(RMBL_ASCII_ONLY = "1")
  x <- list(
    ok = FALSE,
    checks = data.frame(
      check = c("a", "b"),
      ok = c(TRUE, FALSE),
      stringsAsFactors = FALSE
    )
  )
  lines <- c(.rmbl_rule("Check"), "  ok   a", "  FAIL b", .rmbl_rule())
  out <- utils::capture.output(.rmbl_cat(lines, x))
  expect_match(out[2L], "X NOT VERIFIED  - 1 of 2 checks failed", fixed = TRUE)
  expect_match(out[4L], "|   OK   a", fixed = TRUE)
  expect_match(out[5L], "|   X    b", fixed = TRUE)
  x$ok <- TRUE
  x$checks$ok <- TRUE
  out <- utils::capture.output(.rmbl_cat(lines, x))
  expect_match(out[2L], "OK VERIFIED  - 2 of 2 checks passed", fixed = TRUE)
})

test_that("colour codes appear only where the console takes them", {
  withr::local_envvar(RMBL_ASCII_ONLY = "1")
  lines <- c(.rmbl_rule("Demo"), "  a  b", .rmbl_rule())
  withr::local_options(rmoriebricklayer.numcol = 1)
  expect_false(any(grepl(
    "\033[",
    utils::capture.output(.rmbl_cat(lines)),
    fixed = TRUE
  )))
  st <- .rmbl_box_styles(256L)
  expect_identical(st$title("t"), "\033[1mt\033[22m")
  expect_identical(.rmbl_vis_w(st$good("ab")), 2L)
})

test_that("lines that are not one titled block print as they are", {
  out <- utils::capture.output(.rmbl_cat(c("one", "two")))
  expect_identical(out, c("one", "two"))
  expect_null(.rmbl_verdict(list(ok = NA)))
  expect_identical(.rmbl_verdict(list(ok = TRUE))$text, "")
})

test_that("statistical numbers and p-values read as in a paper", {
  expect_identical(
    .rmbl_fmt_num(c(0.000012, 1234567, 0.5, 2, NA, -Inf, 1.16920)),
    c("1.200e-05", "1,234,567", "0.5", "2", "", "-Inf", "1.169")
  )
  expect_identical(
    .rmbl_fmt_p(c(0.0004, 0.017, 1, NA)),
    c("< 0.001", "0.017", "1.000", "")
  )
  expect_identical(.rmbl_fmt_ci(1.02, 1.33), "[1.02, 1.33]")
  expect_true(.rmbl_is_p_col("p_value"))
  expect_true(.rmbl_is_p_col("trend_p"))
  expect_false(.rmbl_is_p_col("estimate"))
})

test_that("a statistical block has facts, an aligned table and a reading", {
  tab <- data.frame(
    term = c("a", "longer term"),
    estimate = c(1.5, -0.25),
    p_value = c(0.0001, 0.2),
    stringsAsFactors = FALSE
  )
  b <- .rmbl_stat_block(
    "Demo model",
    facts = list(method = "OLS", n = 120, skipped = NULL),
    table = tab,
    reading = "The first term is larger.",
    notes = "Two rows were dropped."
  )
  expect_match(b[1L], "Demo model")
  expect_true(any(grepl("method  OLS", b, fixed = TRUE)))
  expect_true(any(grepl("n       120", b, fixed = TRUE)))
  expect_false(any(grepl("skipped", b, fixed = TRUE)))
  head <- grep("estimate", b, fixed = TRUE, value = TRUE)
  expect_match(head, "term         estimate  p_value")
  expect_true(any(grepl("longer term +-0[.]2500 +0[.]200", b)))
  expect_true(any(grepl("< 0.001", b, fixed = TRUE)))
  expect_true(any(grepl("The first term is larger.", b, fixed = TRUE)))
  expect_true(any(grepl("Two rows were dropped.", b, fixed = TRUE)))
  # it is one titled block, so print() draws it as a box
  expect_true(.rmbl_is_block(b, list(unicode = TRUE)))
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

test_that("the drift, Benford, profile and key reports print as boxes", {
  set.seed(31)
  ref <- data.frame(v = stats::rnorm(200), g = sample(c("a", "b"), 200, TRUE))
  cur <- data.frame(
    v = stats::rnorm(200, 1.5),
    g = sample(c("a", "b"), 200, TRUE)
  )
  d <- cpsdrft(ref, cur)
  .o2_check(d, "Capsule drift report", c("DRIFT DETECTED", "Per-column tests"))
  .o2_check(summary(d), "Drift summary", c("2 of 2 columns", "v, g"))
  .o2_check(benfordtst(10^stats::runif(300, 0, 5)),
    "Benford first-digit screen", c("chi-square", "never proof"))
  pf <- profcols(data.frame(a = stats::rnorm(20), b = letters[1:20]))
  .o2_check(pf, "Column profile", c("With missing values", "skewness"))
  .o2_check(pf[, c("column", "mean")], "Column profile", "a subset of it")
})

test_that("result tables are split to fit the box and cut to their rows", {
  wide <- as.data.frame(matrix(seq_len(60) + 0.5, 2))
  lines <- .rmbl_res_block("Wide", tables = list(Caption = wide), maxrows = 1L)
  expect_true(all(nchar(lines[-c(1L, length(lines))]) <= 74L))
  expect_true(any(grepl("Caption", lines, fixed = TRUE)))
  expect_true(any(grepl("1 more rows", lines, fixed = TRUE)))
  expect_gt(sum(grepl("\\bV1\\b", lines)), 1L)
  expect_identical(.rmbl_ci_name(0.9), "90% CI")
  expect_identical(.rmbl_ci_name(NULL), "interval")
  expect_match(.rmbl_est_reading("It is", 1, -1, 2, 0.95), "includes 0")
  expect_match(.rmbl_rr_reading("It is", 0.8, 0.7, 0.9), "20% fall")
  fc <- .rmbl_flag_codes(data.frame(
    a = 1:2,
    flag = c(NA, "small"),
    stringsAsFactors = FALSE
  ))
  expect_identical(fc$df$flag, c("", "[1]"))
  expect_identical(fc$notes, "[1] small")
})

test_that("an over-long word is cut so no box line runs past the edge", {
  long <- strrep("a1b2", 40L)
  w <- .rmbl_box_wrap(paste0("  Digest  ", long), 40L)
  expect_true(all(.rmbl_vis_w(w) <= 40L))
  got <- gsub(" ", "", paste(w, collapse = ""), fixed = TRUE)
  expect_identical(got, paste0("Digest", long))
})

test_that("interval bounds show the same decimals", {
  expect_identical(.rmbl_fmt_ci(47, 56.2), "[47.0, 56.2]")
  expect_identical(.rmbl_fmt_ci(0.25, 3), "[0.25, 3.00]")
  expect_identical(.rmbl_fmt_ci(NA, 2.5), "[, 2.5]")
  expect_identical(.rmbl_fmt_ci(1e-6, 2.5), "[1.000e-06, 2.5]")
})

test_that("a table column shows one count of decimals", {
  expect_identical(
    .rmbl_fmt_col(c(0.9788, 1.038, 0.918)),
    c("0.9788", "1.0380", "0.9180")
  )
  expect_identical(.rmbl_fmt_col(c(12647, 9608)), c("12,647", "9,608"))
  expect_identical(.rmbl_fmt_col(c(1.5, NA, Inf)), c("1.500", "", "Inf"))
  expect_identical(.rmbl_fmt_col(c(1e-6, 2e-6)), .rmbl_fmt_num(c(1e-6, 2e-6)))
  tab <- .rmbl_stat_table(data.frame(
    g = c("a", "b"),
    r = c(0.9788, 0.918),
    stringsAsFactors = FALSE
  ))
  expect_true(any(grepl("0.9180", tab, fixed = TRUE)))
})

test_that("years print as years, adjusted p-values as p-values", {
  tab <- .rmbl_stat_table(data.frame(
    year = c(2021, 2022),
    pholm = c(1e-20, 0.04),
    n = c(1500, 20000)
  ))
  expect_true(any(grepl("2021", tab, fixed = TRUE)))
  expect_false(any(grepl("2,021", tab, fixed = TRUE)))
  expect_true(any(grepl("< 0.001", tab, fixed = TRUE)))
  expect_true(any(grepl("20,000", tab, fixed = TRUE)))
})

test_that("a column of intervals shares its decimals", {
  ci <- .rmbl_fmt_ci(c(0.06512, 3.110), c(0.9229, 3.781))
  expect_identical(ci, c("[0.065, 0.923]", "[3.110, 3.781]"))
})

# ---- result-driven Benford reading -------------------------------------------

test_that("benfordtst()'s reading says whether the digits depart", {
  set.seed(3)
  ok <- paste(format(benfordtst(10^stats::runif(2000, 0, 6))), collapse = " ")
  expect_match(gsub("\\s+", " ", ok), "are consistent with Benford's law (p",
    fixed = TRUE)
  bad <- benfordtst(as.numeric(paste0(sample(1:9, 2000, TRUE), "000")))
  txt <- gsub("\\s+", " ", paste(format(bad), collapse = " "))
  expect_match(txt, "depart from Benford's law (p < 0.001)", fixed = TRUE)
  expect_match(txt, "the largest gap is at 1,", fixed = TRUE)
})

test_that("the box helpers handle a missing estimate, interval or column", {
  expect_match(.rmbl_drift_reading(NULL, 0L, 0L), "No column was in both",
    fixed = TRUE)
  s <- paste0(" ", strrep("word ", 30))
  w <- .rmbl_box_wrap(s, 40L)
  expect_gt(length(w), 1L)
  expect_true(all(nchar(w) <= 40L))
  expect_true(all(grepl("^ [^ ]", w)))
  expect_identical(.rmbl_res_table(data.frame(), "Cap"),
    c("", "  Cap", "  (no rows)"))
  expect_null(.rmbl_est_reading("The effect is", NA_real_, 1, 2))
  expect_identical(
    .rmbl_est_reading("The effect is", 2, NA_real_, NA_real_),
    paste0("The effect is ", .rmbl_fmt_num(2),
      ": it has no interval to judge it by.")
  )
  df <- data.frame(a = 1:2)
  expect_identical(.rmbl_flag_codes(df), list(df = df, notes = NULL))
  expect_identical(.rmbl_ci_cols(df), df)
  expect_null(.rmbl_rr_reading("The ratio is", NA_real_, 1, 2))
})

test_that("C1 controls (U+009B is CSI) are escaped like C0 ones", {
  expect_identical(.rmbl_ctl_escape("a\u009b2Jb"), "a<U+009B>2Jb")
  expect_identical(.rmbl_ctl_escape("\u0080x\u009f"), "<U+0080>x<U+009F>")
  # letters above them are kept
  expect_identical(.rmbl_ctl_escape("M\u00e9tis"), "M\u00e9tis")
  out <- utils::capture.output(.rmbl_cat(c("-- T --", "lab\u009b31m", "--")))
  expect_false(any(grepl("\u009b", out, fixed = TRUE)))
  expect_true(any(grepl("lab<U+009B>31m", out, fixed = TRUE)))
})

test_that("a progress label or stage cannot write escapes to the console", {
  a <- .bl_anim_new(paste0("x\u009b2J", "\033]0;t\007"), 3, quiet = TRUE)
  expect_false(grepl("[\033\007]", a$label))
  expect_false(grepl("\u009b", a$label, fixed = TRUE))
  expect_match(a$label, "<U+009B>", fixed = TRUE)
})

test_that("colour codes in a label are escaped; the package's own are kept", {
  # a label could hide what follows (ESC [8m) or paint it
  expect_identical(.rmbl_ctl_escape("a\033[31mb\033[8mc"),
                   "a\\033[31mb\\033[8mc")
  expect_identical(.rmbl_ctl_escape("\033[38;2;1;2;3mx\033[0m", keep = TRUE),
                   "\033[38;2;1;2;3mx\033[0m")
  expect_identical(.rmbl_ctl_escape("\033[1mt\033[8mh\033[41mb", keep = TRUE),
                   "\033[1mt\\033[8mh\\033[41mb")
  # a box's own colours survive printing; a label's do not
  st <- .rmbl_box_styles(256L)
  out <- capture.output(.rmbl_cat(c(st$good("ok"), "x\033[8my")))
  expect_true(any(grepl("\033[32mok\033[39m", out, fixed = TRUE)))
  expect_false(any(grepl("\033[8m", out, fixed = TRUE)))
})
