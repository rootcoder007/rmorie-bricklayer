# SPDX-License-Identifier: AGPL-3.0-or-later
# The XMSS state record: the signatures seen, and the refusals that keep an
# index from being used twice.

test_that("xmssidxseen() of a directory with no bundles is empty", {
  dir <- withr::local_tempdir()
  s <- xmssidxseen(dir)
  expect_s3_class(s, "data.frame")
  expect_identical(nrow(s), 0L)
  expect_named(s, c("key", "index", "sig", "where", "reused"))
})

test_that("xmssidxseen() refuses a missing path and a bad seen-log", {
  expect_error(
    xmssidxseen(file.path(tempdir(), "no-such-path-a7")),
    "not an existing directory or bundle file"
  )
  expect_error(xmssidxseen(tempdir(), seenlog = 1), "must be file paths")
})

test_that("a bundle without an XMSS signature adds no row", {
  dir <- withr::local_tempdir()
  writeLines(
    tojs(list(attestation = list(scheme = "hmac-sha256")), auto_unbox = TRUE),
    file.path(dir, "capsule_bundle.json")
  )
  expect_null(.rmbl_xmss_bundle_row(file.path(dir, "capsule_bundle.json")))
  expect_identical(nrow(xmssidxseen(dir)), 0L)
})

test_that("sector counts and stale copies are refused", {
  expect_error(.rmbl_xmss_sector_count(3L, 16L), "power of two")
  expect_error(.rmbl_xmss_sector_count(16L, 16L), "power of two")
  expect_null(.rmbl_xmss_sector_count(NULL, 16L))
  seen <- data.frame(
    key = "k",
    index = 5L,
    sig = "s",
    where = "b.json",
    stringsAsFactors = FALSE
  )
  expect_error(.rmbl_xmss_stale(seen, "k", 0L, 7L, 3L), "stale copy")
  expect_null(.rmbl_xmss_stale(seen, "k", 0L, 7L, 5L))
})
