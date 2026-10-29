# The c29 recheck (independent black-box run) and the hostile battery that
# followed it: each case that reached a raw R error, a stray warning or a
# wrong answer, as a regression test.

test_that("weights of 1e308 next to 1 keep every weight a normal number", {
  w <- c(1e308, 1, 1, 1)
  s <- .rmbl_wscale(w)
  expect_true(is.finite(sum(s * s)))
  expect_true(all(s >= .Machine$double.xmin))
  expect_identical(s / s[2L], w / w[2L])
  expect_identical(.rmbl_wscale(c(1, 2)), c(1, 2))
})

test_that("evstudy() with one unit weighted 1e308 gives no LAPACK error", {
  set.seed(1)
  dd <- expand.grid(unit = 1:12, time = 1:8)
  dd$ft <- ifelse(dd$unit <= 6, 5L, NA_integer_)
  dd$y <- rnorm(nrow(dd)) + as.numeric(!is.na(dd$ft) & dd$time >= dd$ft)
  dd$w <- 1
  dd$w[dd$unit == 1] <- 1e308
  expect_no_error(
    evstudy(dd, "unit", "time", "y", "ft", leads = 2, lags = 2, w = "w")
  )
})

test_that("loounit() errors name loounit(), not plndid()", {
  d <- data.frame(u = 1:2, t = 1:2, y = 1:2, d = 0:1)
  e <- tryCatch(loounit(d, "u", "t", "y", "nope"),
                error = conditionMessage)
  expect_false(startsWith(e, "plndid"))
})

test_that("readers given a folder say so", {
  d <- withr::local_tempdir()
  expect_error(siuprs(d), "is a folder")
  expect_error(fromjs(d), "is a folder")
  expect_error(wbrtry(d), "is a folder")
  f <- withr::local_tempfile(lines = "x")
  expect_error(mkbndlproj(f), "is a file, not a folder")
})

test_that("writers refuse a name longer than file systems allow", {
  long <- file.path(tempdir(), strrep("w", 300))
  expect_error(.rmbl_out_file(long, "file"), "longer than the 255 bytes")
  expect_identical(.rmbl_out_file(file.path(tempdir(), "ok.txt"), "file"),
                   file.path(tempdir(), "ok.txt"))
})

test_that("OIDs decode long arcs and a first arc of 2.x without warnings", {
  expect_no_warning(s <- .rmbl_oid_string(
    as.raw(c(0x2a, 0xff, 0xff, 0xff, 0xff, 0xff, 0x7f))
  ))
  expect_false(grepl("NA", s, fixed = TRUE))
  expect_identical(.rmbl_oid_string(as.raw(c(0x88, 0x37, 0x03))), "2.999.3")
  expect_identical(
    .rmbl_oid_string(as.raw(c(0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d))),
    "1.2.840.113549"
  )
  # a truncated arc or a non-minimal 0x80 lead is not an OID
  expect_true(is.na(.rmbl_oid_string(as.raw(c(0x2a, 0x86)))))
  expect_true(is.na(.rmbl_oid_string(as.raw(c(0x2a, 0x80, 0x01)))))
})

test_that("ralloc() refuses a ratio past the integers, blocks or not", {
  expect_error(ralloc(10, arms = c("A", "B"), ratio = c(2^31, 1)),
               "summing to at most 1000000")
  expect_error(ralloc(10, arms = c("A", "B"), ratio = c(2^31, 1), block = 4),
               "summing to at most 1000000")
})

test_that("argument checks the battery found missing", {
  expect_error(clncolnms(NA), "must be a data frame or column names")
  expect_error(rsvidx(2^31, 1), "at most 2147483647")
  ref <- data.frame(a = c(1, 2, 3, 4))
  expect_error(cpsdrft(ref, ref, psithr = list(1)), "psithr")
  expect_error(.bl_id_atst_row(list(), 1), "must be an attestation")
  expect_error(.bl_cols(9L, "x"), "must be colours")
  expect_error(.bl_check_bw(1e308), "`bw` must be one positive number")
  expect_error(tojs(1, digits = Inf), "from 0 to 22")
  expect_error(blcli(character(), out = function() 1),
               "must be a function that writes text")
})

test_that("facts of any type print, plot titles show control bytes escaped", {
  expect_identical(.rmbl_fact(function() 1), "<function>")
  expect_identical(.rmbl_fact(new.env()), "<environment>")
  expect_false(grepl("\033", .bl_main("A\033[2J", "d"), fixed = TRUE))
  expect_identical(.bl_main(NULL, "d"), "d")
})

test_that("big counts get thousands separators without integer overflow", {
  expect_no_warning(s <- .rd_num(2^31))
  expect_identical(s, "2,147,483,648")
  expect_no_warning(.rd_num(1e308))
})

test_that("a label the console cannot spell keeps its characters as <U+XXXX>", {
  withr::local_envvar(RMBL_ASCII_ONLY = "1")
  local_mocked_bindings(.rmbl_has_stringi = function() FALSE)
  expect_identical(.rmbl_txt("中文"), "<U+4E2D><U+6587>")
  expect_identical(.rmbl_txt("Métis"), "Metis")
})

test_that("tables fit the console: long labels are cut, numbers never", {
  cols <- list(c("label", strrep("w", 300)), c("n", "12"))
  fit <- .rmbl_fit(cols, c(FALSE, TRUE), 30L)
  expect_lte(nchar(fit[[1L]][2L]), 26L)
  expect_true(endsWith(fit[[1L]][2L], "..."))
  expect_identical(fit[[2L]], c("n", "12"))
  withr::local_options(width = 30)
  d <- data.frame(g = rep(c(strrep("w", 300), "b"), each = 2),
                  p = rep(2020:2021, 2), n = c(10, 12, 5, 6))
  out <- format(yoy(d, "n", "p", by = "g"))
  rows <- out[grepl("202[01]", out)]
  expect_true(all(nchar(rows, type = "width") <= 40L))
  expect_false(any(grepl(strrep("w", 41), out, fixed = TRUE)))
})

test_that("the bundle wrapper does not wait out the limit for a short run", {
  skip_on_os("windows")
  d <- withr::local_tempdir()
  w <- file.path(d, "w.sh")
  writeLines(.bndlchk_wrap(), w)
  t0 <- proc.time()[["elapsed"]]
  st <- system2("sh", c(shQuote(w), "30", shQuote(file.path(d, "m")),
                        "sh", "-c", shQuote("exit 3")),
                stdout = FALSE, stderr = FALSE)
  expect_identical(as.integer(st), 3L)
  expect_lt(proc.time()[["elapsed"]] - t0, 10)
})

test_that("the reaper leaves processes below the session's older children", {
  before <- data.frame(pid = c(10L, 20L), ppid = c(1L, 1L),
                       state = "S", key = c("10 a", "20 b"))
  now <- data.frame(
    pid = c(10L, 11L, 12L, 13L), ppid = c(1L, 10L, 1L, 12L),
    state = "S", key = c("10 a", "11 c", "12 d", "13 e")
  )
  local_mocked_bindings(.bndlchk_procs = function() now)
  expect_identical(sort(.bndlchk_desc(before, me = 1L)), c(12L, 13L))
})

test_that("mkbndl refuses names its own check would refuse", {
  skip_on_os(c("windows", "mac"))
  b <- withr::local_tempdir()
  dir.create(file.path(b, "top"))
  writeLines("a", file.path(b, "top", "Notes.txt"))
  writeLines("b", file.path(b, "top", "notes.txt"))
  expect_error(.bndl_ents(b, "top", 65535L), "differ only in case")
  unlink(file.path(b, "top", "notes.txt"))
  writeLines("c", file.path(b, "top", "back\\slash.txt"))
  expect_error(.bndl_ents(b, "top", 65535L), "backslash")
})

test_that("mkbndlchk() refuses a zip that unpacks past the size cap", {
  d <- withr::local_tempdir()
  f <- file.path(d, "big.txt")
  writeLines(strrep("0", 5000), f)
  z <- file.path(d, "b.zip")
  withr::with_dir(d, utils::zip(z, "big.txt", flags = "-q"))
  skip_if_not(file.exists(z), "no zip program")
  withr::local_options(rmbl.bundle.maxsize = 1000)
  expect_error(.bndlchk_unzip(z, file.path(d, "x")), "more than the")
})
