# The fallback paths in the helpers: the pure-R SHA-256 a standalone
# capsule bundle uses, the ASCII transliteration without stringi, the
# invalid-UTF-8 branch, the URL branch of the JSON reader, and the
# package-version block of the run summary.
#
# These exist precisely for the environment the package is NOT normally
# tested in -- a sourced bundle with no compiled core, a machine without
# stringi, a file with broken encoding. An untested fallback is worse
# than none, because it is relied on exactly when nothing else works.

test_that("the pure-R SHA-256 agrees with the compiled core", {
  # sha256_file() uses the compiled core inside the package and this
  # pure-R FIPS 180-4 implementation when a capsule bundle is sourced
  # standalone. The two MUST agree, or a digest pinned by one would fail
  # to verify under the other.
  for (s in list("", "abc", "the quick brown fox",
                 paste(rep("x", 1000), collapse = ""),
                 "café 中文")) {
    bytes <- charToRaw(s)
    expect_equal(rmoriebricklayer:::.rmbl_sha256_hex(bytes),
                 core_sha256(bytes))
  }
  # the published NIST vector, through the pure-R path
  expect_equal(rmoriebricklayer:::.rmbl_sha256_hex(charToRaw("abc")),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
  # and over a multi-block input, which exercises the padding
  long <- charToRaw(paste(rep("abcdefghij", 30), collapse = ""))
  expect_equal(rmoriebricklayer:::.rmbl_sha256_hex(long), core_sha256(long))
  expect_match(rmoriebricklayer:::.rmbl_sha256_hex(charToRaw("x")),
               "^[0-9a-f]{64}$")

  # sha256_file() routes to one of them and must match either way
  p <- tempfile()
  on.exit(unlink(p), add = TRUE)
  writeBin(charToRaw("capsule payload"), p)
  expect_equal(sha256_file(p), core_sha256(charToRaw("capsule payload")))
  expect_equal(sha256_file(p),
               rmoriebricklayer:::.rmbl_sha256_hex(
                 charToRaw("capsule payload")))
})

test_that("the ASCII transliteration works without stringi", {
  # to_ascii() prefers stringi and falls back to this when it is absent.
  # Both must return pure 7-bit ASCII.
  fb <- rmoriebricklayer:::.to_ascii_fallback
  expect_equal(fb("plain"), "plain")
  # Latin accents fold to their base letters
  out <- fb(c("café", "naïve", "Angèla"))
  expect_false(any(grepl("[^ -~]", out)))
  expect_match(out[1], "^caf")
  # vectorised, and NA-safe
  expect_length(fb(c("a", "b", NA)), 3L)

  # to_ascii() itself guarantees 7-bit output on whichever path it took
  for (s in c("plain", "café", "中文", "Анг")) {
    expect_false(grepl("[^ -~]", to_ascii(s)))
  }
  expect_equal(to_ascii("plain name"), "plain name")
  # NA becomes empty rather than the string "NA"
  expect_equal(to_ascii(NA), "")

  # ascii_fallback() leaves valid text alone and transliterates the rest
  expect_equal(ascii_fallback("plain name"), "plain name")
  expect_equal(ascii_fallback(c("café", "resume"), force = TRUE)[2],
               "resume")
  expect_false(grepl("[^ -~]",
                     ascii_fallback("café", force = TRUE)))

  # INVALID UTF-8: a byte sequence that is not valid text at all. This is
  # the branch that fires on a file whose encoding was mislabelled.
  broken <- rawToChar(as.raw(c(0x61, 0xff, 0xfe, 0x62)))
  expect_false(validUTF8(enc2utf8(broken)))
  fixed <- ascii_fallback(broken)
  expect_false(grepl("[^ -~]", fixed))
  # valid elements beside a broken one are untouched
  mixed <- ascii_fallback(c("keep me", broken))
  expect_equal(mixed[1], "keep me")
  expect_false(grepl("[^ -~]", mixed[2]))
})

test_that("the JSON reader accepts a path, a string and a URL", {
  # a literal JSON string
  expect_equal(rmoriebricklayer:::.rmbl_read_json('{"a":1}')$a, 1)
  # a local file
  p <- tempfile(fileext = ".json")
  on.exit(unlink(p), add = TRUE)
  writeLines('{"name":"Layer0","n":3}', p)
  got <- rmoriebricklayer:::.rmbl_read_json(p)
  expect_equal(got$name, "Layer0")
  expect_equal(got$n, 3)
  # simplify = FALSE gives plain nested lists
  raw <- rmoriebricklayer:::.rmbl_read_json('{"a":[1,2]}', simplify = FALSE)
  expect_type(raw$a, "list")

  # a URL goes through the fetch core. Mocked, so the test needs no
  # network -- but the branch it exercises is the one a real capsule
  # build takes.
  seen <- NULL
  testthat::local_mocked_bindings(
    bricklayer_fetch = function(url, dest, ...) {
      seen <<- url
      writeLines('{"from":"url"}', dest)
      invisible(dest)
    }
  )
  u <- rmoriebricklayer:::.rmbl_read_json("https://example.org/x.json")
  expect_equal(u$from, "url")
  expect_equal(seen, "https://example.org/x.json")
  # http as well as https
  v <- rmoriebricklayer:::.rmbl_read_json("http://example.org/y.json")
  expect_equal(v$from, "url")
  expect_equal(seen, "http://example.org/y.json")
})

test_that("the run summary includes the package versions when recorded", {
  summary_text <- function(meta) {
    d <- file.path(tempdir(), paste0("rmbl_sum_", sample.int(1e6, 1)))
    dir.create(d, showWarnings = FALSE)
    on.exit(unlink(d, recursive = TRUE), add = TRUE)
    m <- make_manifest(meta, environment = FALSE)
    utils::capture.output({
      m <- record(m, "a", observed = 1, expected = 1)
      write_summary_txt(m, d, paths = list(capsule = d))
    })
    f <- list.files(d, pattern = "[.]txt$", full.names = TRUE)
    paste(readLines(f[1], warn = FALSE), collapse = "\n")
  }

  # without the version block
  bare <- summary_text(list(project = "demo"))
  expect_match(bare, "PASS")
  expect_false(grepl("R PACKAGE VERSIONS", bare))

  # WITH it: a version drift explains most numerical differences between
  # runs, so the summary names the versions it ran on
  txt <- summary_text(list(project = "demo",
                           r_package_versions = list(stats = "4.5.0",
                                                     methods = "4.4.1")))
  expect_match(txt, "R PACKAGE VERSIONS USED IN THIS RUN")
  expect_match(txt, "stats")
  expect_match(txt, "methods")
  expect_match(txt, "4.5.0", fixed = TRUE)
  expect_match(txt, "4.4.1", fixed = TRUE)
  expect_match(txt, "drift here explains")

  # an empty version list adds no block
  expect_false(grepl("R PACKAGE VERSIONS",
                     summary_text(list(project = "d",
                                       r_package_versions = list()))))
})
