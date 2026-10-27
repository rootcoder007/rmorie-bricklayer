# battery: runs in CI and locally; CRAN runs the correctness core
testthat::skip_on_cran()
# Native-code review of 1.0.0: the SIU text passes and the distinct-count
# sketch (M9, M10, M11 and the tolower item).

siu_page <- function(body) {
  siuprs(paste0("<html><body><p>", body, "</p></body></html>"))
}

test_that("M9: the glossary strip is linear in the number of heads", {
  # each head is found, the tail never is; every search used to rescan to
  # the end of the text, 27.8 s at 8000 repeats. Linear: four times the heads
  # take about four times as long (quadratic: about sixteen)
  head <- "who in the opinion of the SIU Director "
  # one long line is split for the extractors, which warns
  t2000 <- system.time(suppressWarnings(siuso(strrep(head, 2000L))))[[
    "elapsed"
  ]]
  t8000 <- system.time({
    r <- suppressWarnings(siuso(strrep(head, 8000L)))
  })[["elapsed"]]
  expect_type(r, "list")
  expect_lt(t8000 / max(t2000, 0.05), 8)
  expect_lt(t8000, wall_limit(6))
})

test_that("M9: unclosed script openers are one pass, not one scan each", {
  # 2.94 s at 2e5 openers before the guard; linear: four times the openers,
  # about four times the time
  t5e4 <- system.time(suppressWarnings(siutxt(strrep("<script", 5e4))))[[
    "elapsed"
  ]]
  t2e5 <- system.time({
    out <- suppressWarnings(siutxt(strrep("<script", 2e5)))
  })[["elapsed"]]
  expect_type(out, "character")
  expect_lt(t2e5 / max(t5e4, 0.05), 8)
  expect_lt(t2e5, wall_limit(6))
  # a closed element still goes
  expect_identical(trimws(siutxt("a<script>x</script>b")), "a b")
})

test_that("M10: SIU input in latin1 is read as the text it is", {
  html <- "<p>Le 5 décembre 2023, café</p>"
  lat <- iconv(html, "UTF-8", "latin1")
  expect_identical(Encoding(lat), "latin1")
  out <- siutxt(lat)
  expect_true(validUTF8(out))
  expect_identical(enc2utf8(out), enc2utf8(siutxt(html)))
  date <- iconv("5 décembre 2023", "UTF-8", "latin1")
  expect_identical(Encoding(date), "latin1")
  expect_identical(siudate(date), "2023-12-05")
})

test_that(
  paste0(
    "M10: the distinct-count sketch counts one string once, whatever its ",
    "encoding"
  ),
  {
    u <- "café"
    l <- iconv(u, "UTF-8", "latin1")
    expect_identical(Encoding(l), "latin1")
    expect_identical(dstnskch(l), dstnskch(u))
    expect_equal(dstncnt(dstnskch(c(u, l))), 1, tolerance = 0.01)
  }
)

test_that("M11: an impossible ISO date is refused, as the spelled-out one is", {
  expect_identical(siudate("February 30, 2023"), "")
  expect_identical(siudate("2023-02-30"), "")
  expect_identical(siudate("2023-13-45"), "")
  expect_identical(siudate("2023-00-10"), "")
  expect_identical(siudate("2023-02-29"), "")
  expect_identical(siudate("2024-02-29"), "2024-02-29")
  expect_identical(siudate("2000-02-29"), "2000-02-29")
  expect_identical(siudate("1900-02-29"), "")
  expect_identical(siudate("2023-04-28"), "2023-04-28")
})

test_that("M11: a director whose name contains the letters t, h, e is kept", {
  header <- "The Investigation\nSubject Officers\n"
  block <- paste0(
    header,
    "Dated at Toronto.\n\nHeather Smith\nDirector\n",
    "Special Investigations Unit"
  )
  expect_identical(unname(siu_page(block)["directors_name"]), "Heather Smith")
  inline <- paste0(header, "Signed by Matthew Theroux, Director")
  expect_identical(
    unname(siu_page(inline)["directors_name"]),
    "Matthew Theroux"
  )
  # "the" as a word of its own is still boilerplate, not a person
  boiler <- paste0(header, "About The Director\nDirector")
  expect_identical(unname(siu_page(boiler)["directors_name"]), "")
})

test_that(
  paste0(
    "M11: a surrogate or out-of-range ",
    "numeric entity decodes to nothing"
  ),
  {
    for (e in c("&#xD800;", "&#xdfff;", "&#55296;", "&#0;", "&#x110000;")) {
      out <- siutxt(paste0("<p>a", e, "b</p>"))
      expect_true(validUTF8(out), info = e)
      expect_identical(trimws(out), "ab", info = e)
    }
    # the code points either side of the surrogates still decode
    expect_identical(trimws(siutxt("<p>&#xD7FF;&#xE000;</p>")), "퟿")
  }
)

test_that("M11: each entity is decoded once, in one pass", {
  out <- siutxt("<p>&amp;lt;b&amp;gt; &amp;eacute;</p>")
  expect_identical(trimws(out), "&lt;b&gt; &eacute;")
  expect_identical(
    trimws(siutxt("<p>&amp;amp; &amp;#233;</p>")),
    "&amp; &#233;"
  )
  # single entities as before
  expect_identical(
    trimws(siutxt("<p>&lt;b&gt; &eacute;t&eacute; &rsquo;&hellip;</p>")),
    "<b> été '..."
  )
})

test_that("lower-casing a UTF-8 page is defined behaviour", {
  # non-ASCII bytes through the SIU lower-casing (a negative char to
  # tolower was undefined); the result is unchanged, and no crash
  txt <- paste0("<p>", strrep("ÉTÉ à ", 50), "</p>")
  expect_true(validUTF8(siutxt(txt)))
  expect_type(siuso(paste("Les agents impliqués", strrep("é", 100))), "list")
})
