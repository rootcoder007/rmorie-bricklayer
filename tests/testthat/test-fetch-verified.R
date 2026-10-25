# fetchvrf(): the source, then each mirror, kept only when the digest matches

.fv_stub <- function(serve) {
  # serve: named list url -> bytes (raw) or NULL (the URL fails)
  force(serve)
  function(url, dest, wb = "", tmout = 120L) {
    b <- serve[[url]]
    if (is.null(b)) {
      stop(sprintf("blfetch: could not reach %s", url), call. = FALSE)
    }
    writeBin(b, dest)
    invisible("live")
  }
}

test_that("fetchvrf() keeps the source when it serves the pinned bytes", {
  good <- charToRaw("a,b\n1,2\n")
  d <- tempfile(fileext = ".csv")
  ref <- sha256file({
    f <- tempfile()
    writeBin(good, f)
    f
  })
  local_mocked_bindings(
    blfetch = .fv_stub(list("https://example.org/t.csv" = good))
  )
  r <- fetchvrf("https://example.org/t.csv", d, sha256 = ref)
  expect_identical(r$source, "live")
  expect_identical(readBin(d, "raw", 100), good)
  expect_identical(r$tried$outcome, "kept")
  expect_false(file.exists(paste0(d, ".part")))
})

test_that(
  paste0(
    "fetchvrf() falls through a failed source and a changed copy to a ",
    "matching mirror"
  ),
  {
    good <- charToRaw("a,b\n1,2\n")
    f <- tempfile()
    writeBin(good, f)
    ref <- sha256file(f)
    d <- tempfile(fileext = ".csv")
    local_mocked_bindings(
      blfetch = .fv_stub(list(
        "https://mirror-one.org/t.csv" = charToRaw("a,b\n1,3\n"),
        "https://archive.org/download/item/t.csv" = good
      ))
    )
    r <- fetchvrf(
      "https://example.org/t.csv",
      d,
      sha256 = toupper(ref),
      mirrors = c(
        "https://mirror-one.org/t.csv",
        "https://archive.org/download/item/t.csv"
      )
    )
    expect_identical(r$source, "mirror")
    expect_identical(r$url, "https://archive.org/download/item/t.csv")
    expect_match(r$tried$outcome[1], "^failed")
    expect_match(r$tried$outcome[2], "^refused: SHA-256")
    expect_identical(r$tried$outcome[3], "kept")
    expect_identical(sha256file(d), ref)
  }
)

test_that(
  paste0(
    "fetchvrf() without a digest keeps the ",
    "first copy and reports its digest"
  ),
  {
    b <- charToRaw("x")
    local_mocked_bindings(blfetch = .fv_stub(list("https://example.org/x" = b)))
    d <- tempfile()
    r <- fetchvrf("https://example.org/x", d)
    expect_identical(r$sha256, sha256file(d))
    expect_identical(r$bytes, 1)
  }
)

test_that("fetchvrf() says what every source did when none serves the file", {
  local_mocked_bindings(
    blfetch = .fv_stub(list("https://m.org/x" = charToRaw("y")))
  )
  expect_error(
    fetchvrf(
      "https://example.org/x",
      tempfile(),
      sha256 = strrep("a", 64),
      mirrors = "https://m.org/x"
    ),
    paste0(
      "with the pinned SHA-256:\n  https://example.org/x: failed.*\n  ",
      "https://m.org/x: refused"
    )
  )
  expect_error(
    fetchvrf("https://example.org/x", tempfile(), sha256 = "abc"),
    "64 hexadecimal"
  )
  expect_error(
    fetchvrf("https://example.org/x", tempfile(), mirrors = NA_character_),
    "`mirrors`"
  )
})
