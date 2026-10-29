# Every branch the c29 / n29 / 42d41d4 fixes added, reached by a test (patch
# coverage), with real inputs where the branch is reachable from the API.

test_that("a pre-trend test with a singular variance is NA, not an error", {
  fit <- list(coef = c(`k-2` = 0.5, `k-1` = 0.2),
              vcov = matrix(0, 2, 2, dimnames = list(c("k-2", "k-1"),
                                                     c("k-2", "k-1"))),
              clusters = 10L)
  pt <- .rmbl_es_pretrend(fit, c(-2L, -1L))
  expect_true(is.na(pt$F))
  expect_true(is.na(pt$p_value))
})

test_that("a count model with a singular design says so", {
  X <- matrix(0, 4, 2)
  fit <- list(fitted.values = rep(1, 4))
  expect_error(
    .rmbl_pp_vcov(X, fit, Inf, rep(1, 4), 1:4, list(), 2L),
    "leave the design singular"
  )
})

test_that("OID arcs past 2^53 are not decoded", {
  expect_true(is.na(.rmbl_oid_string(
    as.raw(c(0x2a, rep(0xff, 8), 0x7f))
  )))
})

test_that("a writer refuses a folder it cannot write in", {
  skip_on_os("windows")
  skip_if(identical(Sys.info()[["user"]], "root"), "root writes anywhere")
  d <- withr::local_tempdir()
  Sys.chmod(d, "0500")
  on.exit(Sys.chmod(d, "0700"), add = TRUE)
  expect_error(.rmbl_out_file(file.path(d, "out.txt"), "file"),
               "cannot be written to")
})

test_that("usecpstmpl() refuses a name too long for a file system", {
  expect_error(usecpstmpl(file.path(tempdir(), strrep("c", 300))),
               "longer than the 255 bytes")
})

test_that("a bad size cap option falls back to 512 MiB", {
  d <- withr::local_tempdir()
  writeLines("x", file.path(d, "a.txt"))
  z <- file.path(d, "a.zip")
  withr::with_dir(d, utils::zip(z, "a.txt", flags = "-q"))
  skip_if_not(file.exists(z), "no zip program")
  withr::local_options(rmbl.bundle.maxsize = "x")
  expect_error(.bndlchk_unzip(z, file.path(d, "x")), "no setup_and_run.R")
})

test_that("with systemd allowed the check finds systemctl on the PATH", {
  withr::local_options(rmbl.bundle.systemd = TRUE)
  expect_type(.bndlchk_sc(), "character")
  withr::local_options(rmbl.bundle.systemd = FALSE)
  expect_identical(.bndlchk_sc(), "")
})

test_that("openssl is the SHA-256 tool when nothing else is there", {
  only <- function(keep) {
    function(names) {
      stats::setNames(ifelse(names == keep, file.path("/usr/bin", keep), ""),
                      names)
    }
  }
  local_mocked_bindings(Sys.which = only("openssl"), .package = "base")
  t <- .rmbl_shatool("Linux")
  expect_identical(t$args, c("dgst", "-sha256", "-r"))
  expect_true(t$plain)
  expect_true(.rmbl_shatool("Windows")$plain)
  h <- strrep("a", 64)
  expect_identical(.rmbl_shaout(paste0(h, " *f.txt"), ""), h)
})

test_that("facts that are lists print their parts", {
  expect_identical(.rmbl_fact(list(1, "a", list(2))), "1, a, <list>")
})

test_that("a label mixing ASCII and an unspellable script keeps both", {
  withr::local_envvar(RMBL_ASCII_ONLY = "1")
  local_mocked_bindings(.rmbl_has_stringi = function() FALSE)
  expect_identical(.rmbl_txt("a中"), "a<U+4E2D>")
})

test_that("a table of numbers too wide to cut is left whole", {
  cols <- list(c("n", strrep("9", 40)), c("m", strrep("8", 40)))
  expect_identical(.rmbl_fit(cols, c(TRUE, TRUE), 30L), cols)
})

test_that("a stat table too wide for the console is stacked", {
  withr::local_options(width = 30)
  df <- data.frame(group = c("a", "b"), estimate = c(1.5, 2.5),
                   lower = c(1, 2), upper = c(2, 3), p.value = c(0.01, 0.2))
  out <- .rmbl_stat_table(df)
  expect_true(any(grepl("^  group +a$", out)))
  expect_true(all(nchar(out) <= 30L))
  expect_false(identical(out, .rmbl_stat_table(df, stack = FALSE)))
})

test_that("cpsxvrf() refuses a key or context it cannot use", {
  sig <- structure(list(scheme = "ML-DSA-44"), class = "bricklayer_signature")
  expect_error(cpsxvrf("m", sig, 1), "must be a key pair from cpskg")
  expect_error(cpsxvrf("m", sig, "abc"), "must be a key pair from cpskg")
  expect_error(cpsxvrf("m", sig, list(), ctx = new.env()),
               "`ctx` must be one string")
})

test_that("ghcmt() refuses a failon that is not check names", {
  local_mocked_bindings(.bl_is_cpschk = function(x) invisible(TRUE))
  expect_error(ghcmt(list(), failon = 1), "`failon` must be NULL")
})

test_that("a label function that fails names yoylbl()", {
  y <- yoy(data.frame(year = 2019:2022, n = c(10, 12, 9, 15)), "n", "year")
  expect_error(yoylbl(y, function() "x"), "yoylbl: `labels` failed")
})

test_that("a statistic that fails names bandsens()", {
  b <- prsbands(c("1", "2 to 5", "6 to 10", "Greater than 10"))
  expect_error(bandsens(b, c(1200, 430, 110, 38), stat = function() 1),
               "bandsens: `stat` failed")
})

test_that("edges given as a matrix are refused", {
  expect_error(.sr_incr(matrix(1:4, 2), "xedg"), "not a matrix")
})

test_that("a characteristic id past the integers names no characteristic", {
  x <- data.frame(chaid = 1L, characteristic = "a")
  expect_error(.rmbl_profshr_pick(x, 2^31, "numerator"),
               "names no characteristic")
})

test_that("plothwk() refuses event times outside the fit's window", {
  fit <- list(horizon = 10)
  expect_error(.hk_times(c(1, 20), fit), "in the fit's window, 0 to 10")
  expect_error(.hk_times(c(1, NA), fit), "finite and none missing")
  expect_identical(.hk_times(c(3, 1), fit), c(1, 3))
})

test_that("plots check colours and escape titles", {
  grDevices::pdf(NULL)
  withr::defer(grDevices::dev.off())
  set.seed(1)
  expect_error(plotcal(as.Date("2024-01-01") + 0:9, 1:10, col = "x"),
               "must be colours")
  expect_error(plothex(rnorm(20), rnorm(20), col = "x"), "must be colours")
  expect_no_warning(plotsm(1:6, rep(1:3, 2), rep(c("a", "b"), each = 3),
                           main = "A\033[2J"))
})
