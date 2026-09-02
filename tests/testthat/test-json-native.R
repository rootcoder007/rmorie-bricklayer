# SPDX-License-Identifier: AGPL-3.0-or-later
# Native JSON codec + SHA-256 file hash: pinned against jsonlite/digest
# (both Suggests-only) whenever they are installed, and against literal
# expectations always.

test_that("native JSON parser handles the manifest shapes", {
  txt <- '{"a":1,"b":[1,2,3],"c":{"d":"x","e":null},"f":true,"g":[{"k":1},{"k":2}]}'
  lst <- bricklayer_json_from_json(txt, simplifyVector = FALSE)
  expect_equal(lst$a, 1)
  expect_equal(unlist(lst$b), c(1, 2, 3))
  expect_null(lst$c$e)
  expect_true(lst$f)
  expect_equal(lst$g[[2]]$k, 2)
  df <- bricklayer_json_from_json(txt)$g
  expect_s3_class(df, "data.frame")
  expect_equal(df$k, c(1, 2))
})

test_that("native encoder round-trips through its own parser", {
  x <- list(name = "capsule", n = 3L, tags = c("a", "b"), nested = list(p = 0.5, q = NA),
            rows = data.frame(id = 1:2, v = c(1.5, NA)))
  txt <- bricklayer_json_to_json(x, auto_unbox = TRUE, pretty = TRUE, na = "null", null = "null")
  back <- bricklayer_json_from_json(txt, simplifyVector = FALSE)
  expect_equal(back$name, "capsule")
  expect_equal(back$n, 3)
  expect_equal(unlist(back$tags), c("a", "b"))
  expect_null(back$nested$q)
  expect_equal(back$rows[[2]]$id, 2)
  expect_null(back$rows[[2]]$v)
})

test_that("native codec agrees with jsonlite on the manifest round trip", {
  skip_if_not_installed("jsonlite")
  x <- list(name = "capsule", n = 3L, tags = c("a", "b"), nested = list(p = 0.5),
            rows = data.frame(id = 1:2, v = c(1.5, 2.5)))
  ours   <- bricklayer_json_to_json(x, auto_unbox = TRUE, pretty = TRUE, na = "null", null = "null")
  theirs <- as.character(jsonlite::toJSON(x, auto_unbox = TRUE, pretty = TRUE, na = "null", null = "null"))
  expect_equal(jsonlite::fromJSON(ours, simplifyVector = FALSE),
               jsonlite::fromJSON(theirs, simplifyVector = FALSE))
  expect_equal(bricklayer_json_from_json(theirs, simplifyVector = FALSE),
               jsonlite::fromJSON(theirs, simplifyVector = FALSE))
  expect_equal(bricklayer_json_from_json(theirs), jsonlite::fromJSON(theirs))
})

test_that("write_manifest_json output is readable by jsonlite and by us", {
  skip_if_not_installed("jsonlite")
  m <- list(schema = "bricklayer/1", files = data.frame(path = c("a.csv", "b.csv"),
                                                       sha256 = c("00", "ff"), stringsAsFactors = FALSE))
  path <- tempfile(fileext = ".json")
  write_manifest_json(m, path)
  expect_equal(jsonlite::fromJSON(path, simplifyVector = FALSE),
               .rmbl_read_json(path, simplify = FALSE))
  expect_equal(.rmbl_read_json(path, simplify = FALSE)$files[[2]]$sha256, "ff")
})

test_that("sha256_file matches digest and a known vector", {
  path <- tempfile()
  writeBin(charToRaw("abc"), path)
  expect_equal(sha256_file(path),
               "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
  skip_if_not_installed("digest")
  big <- tempfile()
  writeBin(as.raw(sample(0:255, 70000, TRUE)), big)
  expect_equal(sha256_file(big), digest::digest(file = big, algo = "sha256"))
})
