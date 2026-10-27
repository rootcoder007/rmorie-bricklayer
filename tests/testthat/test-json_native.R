# SPDX-License-Identifier: AGPL-3.0-or-later
# Native JSON codec + SHA-256 file hash: pinned against jsonlite/digest
# (both Suggests-only) whenever they are installed, and against literal
# expectations always.

test_that("native JSON parser handles the manifest shapes", {
  txt <- paste0(
    '{"a":1,"b":[1,2,3],"c":{"d":"x","e":null},"f":true,"g":[{"k":1},{"k":2',
    "}]}"
  )
  lst <- fromjs(txt, simplifyVector = FALSE)
  expect_equal(lst$a, 1, tolerance = testthat::testthat_tolerance())
  expect_equal(
    unlist(lst$b),
    c(1, 2, 3),
    tolerance = testthat::testthat_tolerance()
  )
  expect_null(lst$c$e)
  expect_true(lst$f)
  expect_equal(lst$g[[2]]$k, 2, tolerance = testthat::testthat_tolerance())
  df <- fromjs(txt)$g
  expect_s3_class(df, "data.frame")
  expect_equal(df$k, c(1, 2), tolerance = testthat::testthat_tolerance())
})

test_that("native encoder round-trips through its own parser", {
  x <- list(
    name = "capsule",
    n = 3L,
    tags = c("a", "b"),
    nested = list(p = 0.5, q = NA),
    rows = data.frame(id = 1:2, v = c(1.5, NA))
  )
  txt <- tojs(x, auto_unbox = TRUE, pretty = TRUE, na = "null", null = "null")
  back <- fromjs(txt, simplifyVector = FALSE)
  expect_identical(back$name, "capsule")
  expect_equal(back$n, 3, tolerance = testthat::testthat_tolerance())
  expect_identical(unlist(back$tags), c("a", "b"))
  expect_null(back$nested$q)
  expect_equal(back$rows[[2]]$id, 2, tolerance = testthat::testthat_tolerance())
  expect_null(back$rows[[2]]$v)
})

test_that("native codec agrees with jsonlite on the manifest round trip", {
  skip_if_not_installed("jsonlite")
  x <- list(
    name = "capsule",
    n = 3L,
    tags = c("a", "b"),
    nested = list(p = 0.5),
    rows = data.frame(id = 1:2, v = c(1.5, 2.5))
  )
  ours <- tojs(x, auto_unbox = TRUE, pretty = TRUE, na = "null", null = "null")
  theirs <- as.character(jsonlite::toJSON(
    x,
    auto_unbox = TRUE,
    pretty = TRUE,
    na = "null",
    null = "null"
  ))
  expect_identical(
    jsonlite::fromJSON(ours, simplifyVector = FALSE),
    jsonlite::fromJSON(theirs, simplifyVector = FALSE)
  )
  expect_identical(
    fromjs(theirs, simplifyVector = FALSE),
    jsonlite::fromJSON(theirs, simplifyVector = FALSE)
  )
  expect_identical(fromjs(theirs), jsonlite::fromJSON(theirs))
})

test_that("wrmnfjs output is readable by jsonlite and by us", {
  skip_if_not_installed("jsonlite")
  m <- list(
    schema = "bricklayer/1",
    files = data.frame(
      path = c("a.csv", "b.csv"),
      sha256 = c("00", "ff"),
      stringsAsFactors = FALSE
    )
  )
  path <- tempfile(fileext = ".json")
  wrmnfjs(m, path)
  expect_identical(
    jsonlite::fromJSON(path, simplifyVector = FALSE),
    .rmbl_read_json(path, simplify = FALSE)
  )
  expect_identical(
    .rmbl_read_json(path, simplify = FALSE)$files[[2]]$sha256,
    "ff"
  )
})

test_that("sha256file matches digest and a known vector", {
  path <- tempfile()
  writeBin(charToRaw("abc"), path)
  expect_identical(
    sha256file(path),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  )
  skip_if_not_installed("digest")
  big <- tempfile()
  writeBin(as.raw(sample(0:255, 70000, TRUE)), big)
  expect_identical(sha256file(big), digest::digest(file = big, algo = "sha256"))
})

test_that("JSON flags must be TRUE or FALSE", {
  expect_error(
    fromjs("[1]", simplifyVector = "yes"),
    "fromjs: `simplifyVector` must be TRUE or FALSE"
  )
  expect_error(fromjs("[1]", simplifyMatrix = NA), "`simplifyMatrix` must be")
  expect_error(jsser(1, pretty = "yes"), "jsser: `pretty` must be TRUE or")
  expect_error(jsunser(jsser(1), trusted = NA), "`trusted` must be TRUE or")
  expect_error(tojs(1, pretty = NA), "`pretty` must be TRUE, FALSE or one")
  expect_error(tojs(1, pretty = "yes"), "`pretty` must be TRUE, FALSE or one")
  expect_identical(unclass(tojs(1, pretty = FALSE)), "[1]")
  expect_identical(
    unclass(tojs(list(a = 1), pretty = TRUE)),
    "{\n  \"a\": [1]\n}"
  )
  expect_identical(fromjs("[1, 2]", simplifyVector = FALSE), list(1L, 2L))
})

test_that("jsb64dec refuses NA and padding inside the text", {
  expect_error(jsb64dec(NA_character_), "jsb64dec: `input` must not be NA")
  expect_error(jsb64dec(c("YQ==", "Yg==")), "padding before its end")
  expect_error(jsb64dec("YQ==="), "padding before its end")
  expect_identical(jsb64dec("YQ=="), charToRaw("a"))
  expect_identical(jsb64dec("YWI"), charToRaw("ab"))
  expect_identical(jsb64dec(c("YWJj", "ZGVm")), charToRaw("abcdef"))
  long <- jsb64enc(strrep("x", 200))
  expect_identical(rawToChar(jsb64dec(long)), strrep("x", 200))
})
