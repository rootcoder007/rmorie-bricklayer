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

test_that("files are written as UTF-8 in a C locale too", {
  skip_on_os("windows")
  old <- Sys.getlocale("LC_CTYPE")
  on.exit(Sys.setlocale("LC_CTYPE", old), add = TRUE)
  skip_if(!nzchar(suppressWarnings(Sys.setlocale("LC_CTYPE", "C"))),
          "no C locale")
  f <- withr::local_tempfile()
  .rmbl_wlines(tojs(list(file = "\u00e9.csv")), f)
  expect_gt(grepRaw(as.raw(c(0xc3, 0xa9)), readBin(f, "raw", 100L),
                    fixed = TRUE), 0L)
  expect_false(grepl("<U+", rawToChar(readBin(f, "raw", 100L)), fixed = TRUE))
})

# ---- the rest of the patch: every branch codecov found unreached ----

test_that("with no XDG_RUNTIME_DIR the user's runtime folder is /run/user", {
  withr::local_envvar(XDG_RUNTIME_DIR = "")
  expect_match(.bndlchk_uenv(), "^XDG_RUNTIME_DIR=/run/user/")
})

test_that("a run in a PID namespace looks for no user services", {
  skip_on_os(c("windows", "mac", "solaris"))
  # "env" stands in for unshare: the run's command is then the same
  local_mocked_bindings(.bndlchk_unshare = function(...) "env")
  root <- withr::local_tempdir()
  writeLines("cat('ran\\n')", file.path(root, "setup_and_run.R"))
  r <- .bndlchk_run(root, NULL, FALSE, win = FALSE)
  expect_identical(r$status, 0L)
  expect_match(r$isolation, "pid namespace", fixed = TRUE)
})

test_that("process listing and its helpers outside Linux", {
  expect_identical(.bndlchk_desc(NULL), integer())
  expect_length(.bndlchk_left("rmblchk-none", sys = "Darwin"), 0L)
  expect_null(.bndlchk_unshare(""))
  skip_on_os(c("windows", "mac", "solaris"))
  expect_null(.bndlchk_unshare(Sys.which("false")))
  local_mocked_bindings(Sys.info = function(...) c(sysname = "Darwin"),
                        .package = "base")
  expect_null(.bndlchk_procs())
})

test_that("every SHA-256 tool a system may have is found", {
  only <- function(keep) {
    function(names) {
      stats::setNames(ifelse(names %in% keep, file.path("/x", names), ""),
                      names)
    }
  }
  local_mocked_bindings(Sys.which = only("certutil"), .package = "base")
  expect_identical(.rmbl_shatool("Windows")$args, "-hashfile")
  local_mocked_bindings(Sys.which = only("shasum"), .package = "base")
  expect_identical(.rmbl_shatool("Linux")$args, c("-a", "256"))
  local_mocked_bindings(Sys.which = only(c("sha256sum", "shasum")),
                        .package = "base")
  expect_identical(.rmbl_shatool("Darwin")$args, c("-a", "256"))
  local_mocked_bindings(.rmbl_shatool = function(sys) NULL)
  expect_null(.rmbl_ossha(tempfile()))
})

test_that("a timestamp whose checks all passed reads not verified", {
  need <- c("token_structure", "message_imprint", "signature",
            "attribute_digest")
  ts <- list(checks = data.frame(check = need, ok = TRUE))
  expect_identical(.bl_ts_failed(ts), "not verified")
})

test_that("a URL ending in .. names the capture index", {
  expect_identical(.bl_capture_name("https://x.org/a/.."), "index")
})

test_that("rows the Wayback refuses offline are never sent", {
  local_mocked_bindings(.bl_cap_wb_why = function(u) "not http(s)")
  out <- data.frame(url = "ftp://x.org/a", wayback = NA_character_)
  r <- .bl_cap_wayback(out, TRUE, "AK", "SK")
  expect_identical(r$wayback, "not asked: not http(s)")
})

test_that("certprs passes the package's own refusals through", {
  local_mocked_bindings(.rmbl_certprs = function(der) {
    stop(simpleError("boom"))
  })
  expect_error(certprs(as.raw(1:3)), "^boom$")
})

test_that("a certificate whose tbsCertificate is cut short is refused", {
  der <- as.raw(c(
    0x30, 0x18,
    0x30, 0x03, 0x02, 0x01, 0x01,
    0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01,
    0x0b, 0x05, 0x00,
    0x03, 0x02, 0x00, 0x00
  ))
  expect_error(certprs(der), "tbsCertificate is incomplete")
})

test_that("a plain text column in a table is escaped, not formatted", {
  out <- .md_table(data.frame(period = c("a\033[2J", "b"), n = 1:2),
                   plain = "period")
  txt <- paste(out, collapse = "\n")
  expect_false(grepl("\033", txt, fixed = TRUE))
  expect_match(txt, "b", fixed = TRUE)
})

test_that("folding to ASCII spells or names each character", {
  expect_identical(.rmbl_fold1("aé"), "ae")
  local_mocked_bindings(toascii = function(x, ...) "")
  expect_identical(.rmbl_fold1("aé"), "a<U+00E9>")
})

test_that("a plot title may be an expression", {
  e <- expression(alpha^2)
  expect_identical(.bl_main(e, "x"), e)
})

test_that("a token with no digest algorithm or an empty certificates field", {
  set <- list(class = 0L, tag = 17, constructed = TRUE, children = list())
  expect_error(.rmbl_ts_digest_algs(set), "digestAlgorithms is empty")
  sd <- list(children = list(list(class = 2L, tag = 0, constructed = TRUE,
                                  children = list())))
  expect_error(.rmbl_ts_certs(sd, raw()), "certificates field is empty")
})

test_that("a signature algorithm that names another digest is refused", {
  expect_match(
    .rmbl_ts_sigalg_why("1.2.840.113549.1.1.11", "RSA", "sha384"),
    "names sha256, the SignerInfo digest is sha384", fixed = TRUE
  )
  expect_null(.rmbl_ts_sigalg_why("1.2.840.113549.1.1.11", "RSA", "sha256"))
})
