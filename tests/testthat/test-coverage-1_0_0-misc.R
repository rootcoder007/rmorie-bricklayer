# Lines of 1.0.0 the suite had not reached outside the policy estimators (codecov of 186bc3ef): the JSON
# codec's rarer branches, the progress line without a size, a BRR replicate set that keeps every row,
# the refusals of the spread, capture and verified-download helpers, a trivial zero of the Hurwitz
# zeta, a census table with one dimension, and the titles of the plots in R/plots.R. Each test names
# the lines it reaches.

test_that("tojs() unboxes a scalar that carries a class of its own", {
  # reaches the scalar branch of .rmbl_json_as that keeps the classes after "scalar" (a Date here)
  d <- structure(as.Date("2024-01-02"), class = c("scalar", "Date"))
  expect_identical(as.character(tojs(list(d = d))), "{\"d\":\"2024-01-02\"}")
  expect_identical(as.character(tojs(structure(1.5, class = c("scalar", "numeric")))), "1.5")
})

test_that("fromjs() reads a string of many escapes, each after some text", {
  # reaches the escape loop of the string reader: the text before a backslash is pushed, and the
  # piece buffer doubles past its 32 slots
  s <- paste0("\"", strrep("ab\\n", 40), "\"")
  expect_identical(fromjs(s), strrep("ab\n", 40))
  expect_identical(fromjs("\"x\\ty\\u00e9z\""), "x\ty\u00e9z")
})

test_that("the progress line without a known size is a spinner with the bytes and the rate", {
  # reaches the size-unknown branch of .bl_dl_line (the spinner glyph, the bytes so far, the rate)
  t0 <- proc.time()[["elapsed"]] - 2
  l <- .bl_dl_line("table", 4096, NA_real_, t0, 1L)
  expect_match(l, "^table  / 4\\.0 KB  [0-9.]+ (B|KB)/s$")
  l2 <- .bl_dl_line("rows", 1234567, NA_real_, t0, 6L, unit = "rows")
  expect_match(l2, "^rows  - 1,234,567 rows  [0-9,]+ rows/s$")
})

test_that("svydes(type = \"brr\") warns of replicates that leave no row out with many factors", {
  # reaches the BRR warning "leaves no row out and is no rescaled weight, as a BRR replicate is"
  d <- data.frame(w = rep(c(1, 2), 10), y = 1:20)
  withr::with_seed(1, for (b in 1:8) d[[paste0("r", b)]] <- d$w * sample(1:3, 20, TRUE))
  expect_warning(des <- svydes(d, w = "w", reps = paste0("r", 1:8), type = "brr"),
                 "replicate r1 leaves no row out and is no rescaled weight, as a BRR replicate is")
  expect_s3_class(des, "rmbl_svy_design")
})

test_that("sprd() refuses negative or all-zero weights", {
  # reaches sprd's refusal of weights below zero, or all zero
  expect_error(sprd(1:3, w = c(-1, 1, 1)), "`w` must be 0 or more, not all 0")
  expect_error(sprd(1:3, w = c(0, 0, 0)), "`w` must be 0 or more, not all 0")
})

test_that("arccap() says so when it cannot create the capture folder", {
  # reaches arccap's "cannot create" refusal: the folder would be inside a regular file
  f <- withr::local_tempfile()
  writeLines("x", f)
  expect_error(suppressWarnings(arccap("https://example.org/a.csv", file.path(f, "sub"))), "cannot create")
})

test_that("hurwzeta() keeps a trivial zero of the Fourier route exact", {
  # reaches .rmbl_hurwitz_fourier's exact zero: at s = -6 and q = 1/2 every cosine of the series is 0,
  # and zeta(-6, 3/2) is zeta(-6, 1/2) less (1/2)^6, with zeta(-6, 1/2) = (2^-6 - 1) zeta(-6) = 0
  expect_identical(.rmbl_hurwitz_fourier(-6, 0.5), 0)
  expect_identical(hurwzeta(-6, 1.5), -1 / 64)
})

test_that("fetchvrf() says so when the download cannot be put in place", {
  # reaches fetchvrf's "cannot write" refusal: the rename and the copy both fail when the
  # destination is a folder that cannot be written
  local_mocked_bindings(blfetch = function(url, dest, wb = "", tmout = 120L) {
    writeBin(charToRaw("abc"), dest)
    invisible("live")
  }, .package = "rmoriebricklayer")
  dd <- withr::local_tempdir()
  Sys.chmod(dd, "0555")
  withr::defer(Sys.chmod(dd, "0755"))
  skip_if(file.access(dd, 2L) == 0L, "the folder stays writable (running as root)")
  expect_error(suppressWarnings(fetchvrf("https://example.org/a.csv", dd)), "cannot write")
  expect_false(file.exists(paste0(dd, ".part")))
})

test_that("sctidy() leaves the labels of a table with one dimension as they are", {
  # reaches .rmbl_statcan_members returning the table unchanged when fewer than two dimensions
  x <- data.frame(REF_DATE = "2021", GEO = "Canada", Sex = c("M", "M"), COORDINATE = c("1.1", "1.1"),
                  VALUE = c(1, 2), stringsAsFactors = FALSE)
  expect_identical(.rmbl_statcan_members(x), x)
  # the geography alone between GEO and the coordinate: one dimension, nothing to tell apart
  one <- data.frame(REF_DATE = "2021", GEO = "Canada", COORDINATE = "1", VALUE = 1, stringsAsFactors = FALSE)
  expect_identical(.rmbl_statcan_members(one), one)
  s <- sctidy(x)
  expect_identical(s$Sex, c("M", "M"))
  expect_identical(s$VALUE, c(1, 2))
})

test_that("chwkfit(meth = \"em\") with every event at the horizon puts the branching ratio at its floor", {
  # reaches the EM kernel step's guard for a zero CDF sum, in the objective, in its gradient and in
  # the ratio update: no event can have been triggered, so eta goes to its lower bound, not 0 / 0
  f <- suppressWarnings(chwkfit(rep(10, 60), 10, meth = "em"))
  expect_true(is.finite(f$braratio))
  expect_lt(f$braratio, 0.05)
})

test_that("the plots of R/plots.R fit their own or the caller's title", {
  # reaches the title lines (.bl_title of the default or given title) of the band-sensitivity, power,
  # funnel, bar and correlation plots
  seen <- character()
  local_mocked_bindings(.bl_title = function(title) {
    seen <<- c(seen, as.character(title))
    invisible(title)
  }, .package = "rmoriebricklayer")
  grDevices::pdf(NULL)
  withr::defer(grDevices::dev.off())
  s <- bandsens(prsbands(c("0-17", "18-24", "25-44", "45+")), c(10, 20, 30, 40), caps = c(60, 70, 80, 90))
  plot(s)
  plot(s, main = "t-bs")
  dd <- withr::with_seed(2, data.frame(x = stats::rnorm(60), y = stats::rnorm(60)))
  shift <- function(z, s) {
    z$y <- z$y + s * z$x
    z
  }
  pw <- cpspwr(dd, function(z) stats::cor(z$x, z$y), inject = shift, trt = "x", sizes = c(0, 0.5), n = 19,
               reps = 3, seed = 1)
  plot(pw, main = "t-pw")
  plotfnl(obs = c(4, 20, 50, 2), expd = c(5, 22, 40, 20), area = c("a", "b", "c", "d"), main = "t-fn")
  plot(freqtbl(data.frame(g = c("a", "b", "b")), "g"), main = "t-fq")
  plot(topcors(data.frame(a = 1:20, b = (1:20)^2, c = rev(1:20))), main = "t-tc")
  expect_true("Sensitivity to the open band's cap" %in% seen)
  expect_true(all(c("t-bs", "t-pw", "t-fn", "t-fq", "t-tc") %in% seen))
})
