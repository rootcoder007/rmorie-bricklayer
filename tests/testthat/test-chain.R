# SPDX-License-Identifier: AGPL-3.0-or-later
# The hash chain of manifests: chnnew(), chnapp(), chnhead(), chnseal() and
# chnvrf().

test_that("a new chain is empty, with a genesis of 64 zeros", {
  ch <- chnnew()
  expect_s3_class(ch, "bricklayer_chain")
  expect_length(ch$entries, 0L)
  expect_identical(ch$genesis, strrep("0", 64L))
  expect_identical(chnhead(ch), strrep("0", 64L))
  expect_true(chnvrf(ch)$valid)
})

test_that("appending links each entry to the one before", {
  ch <- chnnew()
  ch <- chnapp(ch, "manifest 1", label = "run-1")
  ch <- chnapp(ch, "manifest 2", label = "run-2")
  expect_length(ch$entries, 2L)
  v <- chnvrf(ch)
  expect_true(v$valid)
  expect_identical(v$n, 2L)
  expect_true(is.na(v$broken_at))
  expect_false(identical(chnhead(ch), strrep("0", 64L)))
  s <- chnseal(ch)
  expect_type(s, "character")
  expect_identical(nchar(s), 64L)
})

test_that("an edited or dropped entry breaks the chain and its seal", {
  ch <- chnnew()
  for (i in 1:3) {
    ch <- chnapp(ch, sprintf("manifest %d", i), label = sprintf("run-%d", i))
  }
  edited <- ch
  edited$entries[[2]]$digest <- csha256("something else")
  expect_false(chnvrf(edited)$valid)
  dropped <- ch
  dropped$entries[[2]] <- NULL
  expect_false(chnvrf(dropped)$valid)
  expect_identical(chnseal(dropped), NA_character_)
  truncated <- ch
  truncated$entries[[3]] <- NULL
  expect_false(identical(chnseal(truncated), chnseal(ch)))
})

test_that("only chains are accepted, and a chain prints", {
  expect_error(chnvrf(list(entries = list())))
  ch <- chnapp(chnnew(), list(run = 1, mean = 2.5), label = "list entry")
  expect_output(print(ch))
  expect_output(print(chnvrf(ch)))
})

# Prints `x` on an ASCII console: the lines and what print() returned.
o1_box <- function(x, ...) {
  withr::local_envvar(RMBL_ASCII_ONLY = "1")
  tmp <- withr::local_tempfile()
  v <- withr::with_output_sink(tmp, withVisible(print(x, ...)))
  list(out = readLines(tmp), v = v)
}

# The box's frame, its title and the facts expected in it.
o1_expect_box <- function(b, x, title, facts = character()) {
  expect_false(b$v$visible)
  expect_identical(b$v$value, x)
  expect_match(b$out[1L], "^\\+-- ")
  expect_true(grepl(title, b$out[1L], fixed = TRUE))
  expect_match(b$out[length(b$out)], "^\\+-+\\+$")
  for (f in facts) {
    expect_true(any(grepl(f, b$out, fixed = TRUE)), info = f)
  }
}

test_that("chains and their checks print as boxes", {
  ch <- chnapp(chnnew(), list(run = 1), label = "first")
  ch <- chnapp(ch, list(run = 2))
  o1_expect_box(o1_box(ch), ch, "Manifest chain", c("chain intact", "first"))
  ck <- chnvrf(ch)
  o1_expect_box(o1_box(ck), ck, "Manifest chain check", "2 entries")
  bad <- ck
  bad$valid <- FALSE
  bad$broken_at <- 2L
  b <- o1_box(bad)
  o1_expect_box(b, bad, "Manifest chain check", "broken at entry 2 of 2")
  expect_true(any(grepl("Broken at", b$out, fixed = TRUE)))
  e <- chnnew()
  o1_expect_box(o1_box(e), e, "Manifest chain", "(empty)")
})

test_that("a label digests to the same bytes in every locale", {
  lab <- rawToChar(as.raw(c(0x63, 0x61, 0x66, 0xc3, 0xa9)))
  here <- chnapp(chnnew(), "x", label = lab)$entries[[1L]]$digest
  # the digest rmoriebricklayer 1.1.0 gives in a UTF-8 locale
  expect_true(startsWith(here, "2bee4f27559cddda"))
  skip_if_lowmem()
  f <- withr::local_tempfile(fileext = ".rds")
  code <- paste0(
    "ch <- rmoriebricklayer::chnapp(rmoriebricklayer::chnnew(), 'x', ",
    "label = rawToChar(as.raw(c(0x63, 0x61, 0x66, 0xc3, 0xa9)))); ",
    "saveRDS(ch, ", deparse(f), "); ",
    "cat(ch$entries[[1]]$digest, rmoriebricklayer::chnvrf(ch)$valid)"
  )
  out <- withr::with_envvar(
    c(
      LC_ALL = "C",
      LANG = "C",
      R_TESTS = NA,
      R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep)
    ),
    system2(
      file.path(R.home("bin"), "Rscript"),
      c("--vanilla", "-e", shQuote(code)),
      stdout = TRUE,
      stderr = FALSE
    )
  )
  expect_identical(utils::tail(out, 1L), paste(here, "TRUE"))
  expect_true(chnvrf(readRDS(f))$valid)
})

test_that("a label that is no text is refused, and never verifies", {
  skip_if(isTRUE(l10n_info()[["Latin-1"]]))
  expect_error(
    chnapp(chnnew(), "x", label = "caf\xe9"),
    "chnapp: `label` holds text that is neither valid UTF-8 nor text"
  )
  ch <- chnapp(chnnew(), "x", label = "cafe")
  ch$entries[[1L]]$label <- "caf\xe9"
  expect_false(chnvrf(ch)$valid)
})
