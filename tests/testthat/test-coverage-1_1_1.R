# Lines added in 1.1.1 that no test reached: each case calls the path it is
# on. No network; inputs of a few bytes.

cov_gz <- function(bytes) {
  f <- tempfile(fileext = ".csv.gz")
  con <- gzfile(f, "wb")
  writeBin(bytes, con)
  close(con)
  f
}

test_that("part of a table whose header has no columns is read whole", {
  ns <- asNamespace("rmoriebricklayer")
  f <- cov_gz(charToRaw("\"\"\n1\n2\n3\n"))
  whole <- ns$.bl_read_csv_gz(f)
  expect_identical(ns$.bl_csv_part(f, NULL, Inf, NULL, piece = 2), whole)
  two <- ns$.bl_csv_part(f, NULL, 2, NULL, piece = 2)
  expect_identical(dim(two), c(2L, 0L))
  some <- ns$.bl_csv_part(f, NULL, Inf, function(d) c(TRUE, FALSE, TRUE))
  expect_identical(dim(some), c(2L, 0L))
  expect_error(ns$.bl_csv_part(f, "a", Inf, NULL), "no column a")
})

test_that("the part reader reads a header longer than a piece", {
  ns <- asNamespace("rmoriebricklayer")
  head <- paste(sprintf("column_%02d", 1:20), collapse = ",")
  row <- paste(1:20, collapse = ",")
  f <- cov_gz(charToRaw(paste0(head, "\n", row, "\n")))
  expect_identical(
    ns$.bl_csv_part(f, NULL, Inf, NULL, piece = 4),
    ns$.bl_read_csv_gz(f)
  )
  # a header whose quote never closes is refused as a whole read refuses it
  f <- cov_gz(charToRaw("\"a,b\n1,2\n"))
  msg <- tryCatch(ns$.bl_read_csv_gz(f), error = conditionMessage)
  expect_match(msg, "in its header")
  expect_error(
    ns$.bl_csv_part(f, NULL, Inf, NULL, piece = 3),
    msg,
    fixed = TRUE
  )
})

test_that("a byte-order mark at the first record is dropped as a whole read", {
  ns <- asNamespace("rmoriebricklayer")
  bom <- as.raw(c(0xef, 0xbb, 0xbf))
  for (lead in list(raw(), charToRaw("\""), charToRaw("\"\""))) {
    rest <- if (length(lead) == 1L) "x\",2\n" else "1,2\n"
    b <- c(charToRaw("a,b\n\n"), lead, bom, charToRaw(paste0(rest, "3,4\n")))
    f <- cov_gz(b)
    whole <- tryCatch(ns$.bl_read_csv_gz(f), error = conditionMessage)
    expect_identical(
      tryCatch(
        ns$.bl_csv_part(f, NULL, Inf, NULL, piece = 64),
        error = conditionMessage
      ),
      whole,
      info = length(lead)
    )
  }
})

test_that("a download that writes no file, or cannot be moved, says so", {
  ns <- asNamespace("rmoriebricklayer")
  d <- withr::local_tempdir()
  local_mocked_bindings(
    .bl_data_url = function() "https://data.example.org",
    .bl_data_label = function(path) list(label = "db/t", size = NULL),
    bldl = function(url, dest, ...) invisible(dest)
  )
  expect_error(
    ns$.bl_data_get("/db/t.csv.gz", file.path(d, "t.csv.gz")),
    "the download of .* wrote no file"
  )
  local_mocked_bindings(bldl = function(url, dest, ...) {
    writeLines("x", dest)
    invisible(dest)
  })
  # the name is taken by a folder that is not empty
  dest <- file.path(d, "u.csv.gz")
  dir.create(file.path(dest, "inside"), recursive = TRUE)
  expect_error(
    ns$.bl_data_get("/db/u.csv.gz", dest),
    "could not be moved into place.*dcache = "
  )
})

test_that("a join with a part missing, or a short or stuck file, is refused", {
  ns <- asNamespace("rmoriebricklayer")
  d <- withr::local_tempdir()
  p <- file.path(d, c("00001", "00002"))
  writeBin(as.raw(1:3), p[1L])
  expect_error(
    ns$.bl_data_join(p, file.path(d, "t.csv.gz"), 3),
    "part 00002 is missing"
  )
  # the joined file now holds part 1; a write that drops a byte without a
  # warning shows in the size
  writeBin(as.raw(4:5), p[2L])
  local_mocked_bindings(.bl_write_raw = function(buf, out) {
    writeBin(buf[-1L], out)
    invisible(NULL)
  })
  expect_error(
    ns$.bl_data_join(p, file.path(d, "t.csv.gz"), 3),
    "is full or cannot be written"
  )
  local_mocked_bindings(.bl_write_raw = function(buf, out) {
    writeBin(buf, out)
    invisible(NULL)
  })
  # the final name is taken by a folder that is not empty
  dest <- file.path(d, "v.csv.gz")
  dir.create(file.path(dest, "inside"), recursive = TRUE)
  writeBin(as.raw(4:5), p[2L])
  expect_error(ns$.bl_data_join(p, dest, 3), "is full or cannot be written")
})

test_that("migrate reads assign() with no arguments or a positional env", {
  ns <- asNamespace("rmoriebricklayer")
  mig <- function(src) ns$.bl_migrate_text(src)$lines
  expect_identical(mig(c("assign()", "rate(1)"))[2L], "rtcalc(1)")
  pos <- c(
    "f <- function() assign(\"yoy\", function(d) d, globalenv())",
    "yoy(1)"
  )
  expect_identical(mig(pos), pos)
})

test_that("jsser() passes on an error that is not about depth", {
  local_mocked_bindings(.rmbl_json_pack = function(obj) stop("not packable"))
  expect_error(jsser(1), "not packable")
})

test_that("jsunser() wraps R's own refusal, and reads all-missing values", {
  s <- paste0(
    "{\"type\":\"integer\",\"value\":[1,2],\"attributes\":{\"dim\":",
    "{\"type\":\"integer\",\"value\":[3,3]}}}"
  )
  expect_error(jsunser(s), "not JSON written by jsser\\(\\) \\(dims")
  expect_identical(
    jsunser("{\"type\":\"integer\",\"value\":[\"NA\",null]}"),
    c(NA_integer_, NA_integer_)
  )
  z <- jsunser("{\"type\":\"complex\",\"value\":[null]}")
  expect_type(z, "complex")
  expect_length(z, 1L)
  expect_true(is.na(z))
})

test_that("jsgzenc() refuses JSON longer than jsgzdec() reads", {
  ns <- asNamespace("rmoriebricklayer")
  expect_null(ns$.rmbl_gz_json_cap(64 * 1024^2))
  expect_error(
    ns$.rmbl_gz_json_cap(64 * 1024^2 + 1),
    "jsgzenc: the JSON is 67108865 bytes"
  )
})
