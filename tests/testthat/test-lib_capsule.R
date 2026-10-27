# SPDX-License-Identifier: AGPL-3.0-or-later
# Capsule verification, the environment record and citations.

test_that("vrfcps() verifies a capsule whose data matches its digest", {
  dir <- withr::local_tempdir("capsule-")
  utils::write.csv(
    data.frame(id = 1:3),
    file.path(dir, "d.csv"),
    row.names = FALSE
  )
  prov <- list(
    resource = list(
      filename = "d.csv",
      sha256 = sha256file(file.path(dir, "d.csv"))
    )
  )
  writeLines(
    tojs(prov, auto_unbox = TRUE),
    file.path(dir, "data_provenance.json")
  )
  out <- vrfcps(dir)
  expect_s3_class(out, "bricklayer_capsule_check")
  expect_true(out$ok)
  expect_length(out$missing, 0L)
  expect_output(print(out))
  # changed bytes fail the digest row
  utils::write.csv(
    data.frame(id = 4:6),
    file.path(dir, "d.csv"),
    row.names = FALSE
  )
  bad <- vrfcps(dir)
  expect_false(bad$ok)
  expect_false(bad$checks$ok[bad$checks$check == "data_sha256"])
})

test_that("vrfcps() refuses a missing directory and fails an empty one", {
  expect_error(
    vrfcps(file.path(tempdir(), "no-such-capsule-a7")),
    "not an existing directory"
  )
  dir <- withr::local_tempdir("capsule-")
  out <- vrfcps(dir)
  expect_false(out$ok)
  expect_true("provenance_readable" %in% out$checks$check)
})

test_that("capenv() records the session", {
  e <- capenv("stats")
  expect_identical(e$r_version, as.character(getRversion()))
  expect_named(e$packages, "stats")
  expect_error(capenv(NA_character_), "package names")
})

test_that("citecps() cites a provenance as text and BibTeX", {
  expect_null(citecps(NULL))
  expect_error(citecps("x"), "provenance list")
  prov <- list(
    dataset = list(
      publisher = "Ministry",
      package_slug = "data-on-x",
      licence_short = "OGL"
    ),
    resource = list(name = "Table A", direct_url = "https://example.org/a.csv"),
    captured_at_utc = "2024-05-06T07:08:09Z"
  )
  cc <- citecps(prov)
  expect_identical(
    cc$text,
    paste0(
      "Ministry (2024). Table A [Data set]. https://example.org/a.csv ",
      "Retrieved 2024-05-06. Licence: OGL."
    )
  )
  expect_match(cc$bibtex, "@misc{dataonx2024,", fixed = TRUE)
  expect_match(
    cc$bibtex,
    "note = {Retrieved 2024-05-06; licence: OGL}",
    fixed = TRUE
  )
  prov$dataset$doi <- "10.1/xyz"
  expect_match(citecps(prov)$text, "https://doi.org/10.1/xyz", fixed = TRUE)
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

test_that("a capsule verification prints as a box", {
  out <- list(
    ok = FALSE,
    checks = data.frame(
      check = c("provenance_readable", "data_sha256"),
      ok = c(TRUE, FALSE),
      detail = c("data_provenance.json", "digest differs"),
      stringsAsFactors = FALSE
    ),
    required = "data_sha256",
    missing = "schema_valid"
  )
  class(out) <- c("bricklayer_capsule_check", "list")
  b <- o1_box(out)
  o1_expect_box(
    b,
    out,
    "Capsule verification",
    c("NOT VERIFIED", "1 of 2 passed", "schema_valid")
  )
  expect_true(any(grepl("required check was never made", b$out, fixed = TRUE)))
})

# ---- capenv() and citecps() print as boxes; their JSON is unchanged ---------

test_that("capenv() carries a class, reads its packages and seed", {
  e <- capenv(c("stats", "notapackage123"))
  expect_s3_class(e, c("rmbl_capenv", "list"))
  expect_identical(tojs(e, auto_unbox = TRUE), tojs(unclass(e),
    auto_unbox = TRUE))
  expect_box2(e, "Computing environment",
    c("not installed here: notapackage123", "not installed"))
  expect_match(.mf_env_reading(c(a = "1"), TRUE)[2L], "can be replayed",
    fixed = TRUE)
  expect_match(.mf_env_reading(c(a = "1"), FALSE)[2L], "cannot be replayed",
    fixed = TRUE)
})

test_that("citecps() carries a class and reads its link", {
  prov <- list(dataset = list(publisher = "P"),
    resource = list(name = "T", direct_url = "https://x.org/a.csv"))
  cit <- citecps(prov)
  expect_s3_class(cit, c("rmbl_citation", "list"))
  expect_identical(tojs(cit), tojs(unclass(cit)))
  expect_box2(cit, "Data citation", c("download address", "@misc"))
  prov$dataset$doi <- "10.1/x"
  expect_box2(citecps(prov), "Data citation", "by DOI")
})

test_that("an environment or citation without its fields prints as a list", {
  e <- structure(list(r = "4.5.0"), class = c("rmbl_capenv", "list"))
  expect_identical(format(e), utils::capture.output(print(unclass(e))))
  ci <- structure(list(text = 1), class = c("rmbl_citation", "list"))
  expect_identical(format(ci), utils::capture.output(print(unclass(ci))))
})
