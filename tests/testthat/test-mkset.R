# mkset(): several results as one report

set_parts <- function() {
  d <- data.frame(
    year = rep(2020:2023, 2), grp = rep(c("a", "b"), each = 4),
    n = c(5, 7, 9, 11, 4, 6, 8, 7), pop = 1000,
    stringsAsFactors = FALSE
  )
  list(
    g = ginicoef(c(3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5)),
    r = rtcalc(d, "n", "pop", by = "grp"),
    y = yoy(c(10, 12, 15, 11))
  )
}

test_that("mkset heads each result and prints the whole report", {
  p <- set_parts()
  s <- mkset("How unequal" = p$g, p$r, 1:3, title = "My study")
  expect_s3_class(s, "rmbl_set")
  expect_identical(s$title, "My study")
  expect_identical(names(s$items)[1L], "How unequal")
  expect_identical(names(s$items)[2L], "Rate per 1,000")
  expect_identical(names(s$items)[3L], "Result 3 (integer)")
  # the contents is one box; the results follow it, each under its number
  withr::local_envvar(RMBL_ASCII_ONLY = "1")
  fl <- gsub("\\s+", " ", paste(format(s), collapse = " "))
  for (h in c("My study", "How unequal", "Rate per 1,000", "rmbl_rate")) {
    expect_true(grepl(h, fl, fixed = TRUE), info = h)
  }
  vis <- NULL
  out <- utils::capture.output({
    vis <- withVisible(print(s))
  })
  expect_false(vis$visible)
  expect_match(out[1L], "^\\+-- ")
  expect_true(any(out == "1. How unequal"))
  expect_true(any(out == "3. Result 3 (integer)"))
  expect_true(any(grepl("Gini coefficient", out, fixed = TRUE)))
  # one plain list is the list of results
  s2 <- mkset(list(a = p$g, b = p$r))
  expect_named(s2$items, c("a", "b"))
  expect_identical(s2$title, "Analysis results")
})

test_that("mkset writes text, Markdown and one HTML page", {
  p <- set_parts()
  d <- withr::local_tempdir()
  tx <- mkset(p$g, p$r, title = "T", file = file.path(d, "r.txt"))
  expect_true(file.exists(attr(tx, "path")))
  txt <- readLines(file.path(d, "r.txt"), encoding = "UTF-8")
  expect_true(any(grepl("Gini coefficient", txt, fixed = TRUE)))
  expect_false(any(grepl("\033[", txt, fixed = TRUE)))
  expect_true(all(nchar(txt, type = "width") <= 80L))
  mkset("Gini" = p$g, "Change" = p$y, title = "T",
        file = file.path(d, "r.md"))
  md <- readLines(file.path(d, "r.md"), encoding = "UTF-8")
  expect_identical(md[1L], "# T")
  expect_true(all(c("## Gini", "## Change") %in% md))
  expect_false(any(md == "```r"))
  expect_true(any(startsWith(md, "|")))
  mkset("Gini" = p$g, "Rates" = p$r, "Change" = p$y, title = "T & co",
        file = file.path(d, "r.html"))
  h <- paste(readLines(file.path(d, "r.html"), encoding = "UTF-8"),
             collapse = "\n")
  expect_match(h, "<title>T &amp; co</title>", fixed = TRUE)
  expect_match(h, "3 results, each as it prints, with its plot", fixed = TRUE)
  sec <- gregexpr("<section>", h, fixed = TRUE)
  expect_identical(lengths(regmatches(h, sec)), 3L)
  expect_match(h, "<svg|<img")
  expect_false(grepl("<pre><code>", h, fixed = TRUE))
  mkset(p$g, plots = FALSE, file = file.path(d, "n.htm"))
  h2 <- paste(readLines(file.path(d, "n.htm")), collapse = "\n")
  expect_false(grepl("<svg|<img", h2))
  expect_match(h2, "1 result, each as it prints.", fixed = TRUE)
})

test_that("a plot that fails is left out, the box kept", {
  bad <- structure(list(), class = "rmbl_rate")
  expect_null(asNamespace("rmoriebricklayer")$.mkset_plot(bad))
  expect_null(asNamespace("rmoriebricklayer")$.mkset_plot(1:3))
  # a data frame, or a result with no plot method of its own, gets no
  # pairs plot (which warned on text columns)
  df <- data.frame(a = c("x", "y"), b = 1:2)
  expect_silent(n1 <- asNamespace("rmoriebricklayer")$.mkset_plot(df))
  expect_null(n1)
  cls <- structure(df, class = c("rmbl_noplot", "data.frame"))
  expect_null(asNamespace("rmoriebricklayer")$.mkset_plot(cls))
  # past the size limit the plot is a picture, not vectors
  y <- yoy(c(10, 12, 15, 11))
  big <- asNamespace("rmoriebricklayer")$.mkset_plot(y, big = 10)
  expect_match(big, "^<img alt=\"plot\" src=\"data:image/png;base64,")
})

test_that("mkset refuses what it cannot do", {
  p <- set_parts()
  expect_error(mkset(), "at least one result")
  expect_error(mkset(list()), "at least one result")
  expect_error(mkset(p$g, file = file.path(tempdir(), "r.pdf")),
               "must end in .html, .md or .txt, not .pdf")
  expect_error(mkset(p$g, title = 1), "title")
  expect_error(mkset(p$g, plots = NA), "plots")
})

test_that("a result's name cannot write escapes to the terminal", {
  p <- set_parts()
  nm <- c("a\033]0;owned\007b", "c\u009b2Jd", "e\rf")
  s <- mkset(stats::setNames(list(p$g, p$y, 1:3), nm))
  out <- utils::capture.output(print(s))
  txt <- paste(out, collapse = "\n")
  # no raw ESC, BEL, CSI or CR reaches the console: they print escaped
  expect_false(grepl("[\007\r]", txt))
  expect_false(grepl("\033]", txt, fixed = TRUE))
  expect_false(grepl("\u009b", txt, fixed = TRUE))
  expect_true(any(grepl("1. a\\033]0;owned\\ab", out, fixed = TRUE)))
  expect_true(any(grepl("2. c<U+009B>2Jd", out, fixed = TRUE)))
})
