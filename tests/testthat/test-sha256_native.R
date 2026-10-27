# SPDX-License-Identifier: AGPL-3.0-or-later
# The pure-R SHA-256 that standalone capsule bundles fall back to must be
# FIPS 180-4 exact and identical to the compiled core at every padding
# boundary.

test_that("pure-R SHA-256 reproduces the FIPS 180-4 vectors", {
  expect_identical(
    .rmbl_sha256_hex(charToRaw("abc")),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  )
  expect_identical(
    .rmbl_sha256_hex(raw(0)),
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  )
  expect_identical(
    .rmbl_sha256_hex(charToRaw(
      "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
    )),
    "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"
  )
})

test_that("pure-R SHA-256 matches the compiled core across block boundaries", {
  set.seed(11)
  for (n in c(1, 31, 55, 56, 57, 63, 64, 65, 119, 120, 128, 300, 1000)) {
    b <- as.raw(sample(0:255, n, TRUE))
    expect_identical(
      .rmbl_sha256_hex(b),
      csha256(b),
      label = paste("length", n)
    )
  }
  expect_identical(.rmbl_hexlify(as.raw(c(0, 15, 16, 255))), "000f10ff")
})

test_that(
  paste0(
    "sha256file uses the pure-R digest ",
    "when the compiled core is absent"
  ),
  {
    p <- tempfile()
    writeBin(charToRaw("abc"), p)
    expect_identical(
      sha256file(p),
      "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    )
    # simulate a standalone bundle: source the file into a bare env. The
    # sources sit next to the tests only in a source checkout, not in an
    # installed package (R CMD check), so skip there.
    src <- testthat::test_path("..", "..", "R", "sha256_native.R")
    skip_if(
      !file.exists(src),
      "package sources not present (installed package)"
    )
    e <- new.env(parent = baseenv())
    sys.source(src, envir = e)
    expect_identical(
      e$.rmbl_sha256_hex(charToRaw("abc")),
      "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    )
  }
)

test_that("codec branches the parity grid does not reach", {
  expect_identical(
    as.character(tojs(charToRaw("hi"), raw = "js")),
    "(new Uint8Array([104,105]))"
  )
  expect_identical(
    as.character(tojs(charToRaw("hi"), raw = "int")),
    "[104,105]"
  )
  expect_identical(
    as.character(tojs(charToRaw("hi"), raw = "hex")),
    '["68","69"]'
  )
  expect_match(
    as.character(tojs(charToRaw("hi"), raw = "mongo")),
    '"\\$binary"'
  )
  expect_identical(as.character(tojs(NULL, null = "null")), "null")
  expect_identical(
    as.character(tojs(structure(list(a = 1), class = "odd"), force = TRUE)),
    '{"a":[1]}'
  )
  expect_error(tojs(structure(list(a = 1), class = "odd")), "No method")
  expect_error(bricklayer_json_unbox(1:2), "length 2")
  expect_error(bricklayer_json_unbox(list(a = 1)), "atomic")
  v <- bricklayer_json_validate("[1,")
  expect_false(isTRUE(v))
  expect_true(nzchar(attr(v, "err")))
  expect_error(fromjs(42), "must be a JSON string")
  expect_identical(
    fromjs("[9007199254740993]", bigint_as_char = TRUE),
    "9007199254740993"
  )
  expect_identical(
    fromjs('{"$date":1700000000000}'),
    structure(1700000000, class = c("POSIXct", "POSIXt"))
  )
})
