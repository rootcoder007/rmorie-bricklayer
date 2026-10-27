# fipsmod(), fipsmkg(): keys made and signatures computed inside an
# OpenSSL FIPS provider

fips_mod_or_skip <- function() {
  skip_on_cran()
  m <- tryCatch(fipsmod(), error = function(e) NULL)
  skip_if(is.null(m), "no OpenSSL 3.5 FIPS provider here")
  m
}

fake_openssl <- function(dir, version, providers = character(),
                         modulesdir = NULL) {
  f <- file.path(dir, "openssl")
  writeLines(c(
    "#!/bin/sh",
    sprintf("if [ \"$1\" = version ]; then echo '%s'; exit 0; fi", version),
    "if [ \"$1\" = list ]; then",
    paste0("  printf '%s\\n' ", paste(shQuote(providers), collapse = " ")),
    "  exit 0",
    "fi",
    if (is.null(modulesdir)) "if [ \"$1\" = info ]; then exit 1; fi" else
      sprintf("if [ \"$1\" = info ]; then echo '%s'; exit 0; fi",
              modulesdir),
    "if [ \"$1\" = fipsinstall ]; then exit 1; fi",
    "exit 1"
  ), f)
  Sys.chmod(f, "0755")
  f
}

test_that("keys made in the module sign, and both implementations agree", {
  mod <- fips_mod_or_skip()
  expect_s3_class(mod, "rmbl_fipsmod")
  expect_match(mod$name, "FIPS")
  expect_true(mod$status %in% c("validated", "validated without PQC",
                                "not listed"))
  expect_identical(fipsmod(), mod)
  for (s in c("ML-DSA-44", "SLH-DSA-SHA2-128s")) {
    k <- fipsmkg(s, mod)
    expect_s3_class(k, "rmbl_fipsmod_key")
    expect_s3_class(k, "bricklayer_fips_public_key")
    expect_identical(nchar(k$public), 2L * fipssz(s)[["public_key"]])
    sg <- cpssign("a manifest", k, ctx = "release")
    expect_identical(sg$module$name, mod$name)
    expect_true(cpsvrf("a manifest", sg, k, ctx = "release"), info = s)
    expect_false(cpsvrf("a manifest!", sg, k, ctx = "release"))
    expect_false(cpsvrf("a manifest", sg, k, ctx = "staging"))
    x <- cpsxvrf("a manifest", sg, k, ctx = "release")
    expect_true(x$ours)
    expect_true(isTRUE(x$openssl) || is.na(x$openssl))
  }
  k <- fipsmkg("ML-DSA-44", mod)
  expect_identical(cpssign("m", k, determ = TRUE)$signature,
                   cpssign("m", k, determ = TRUE)$signature)
  expect_error(cpssign("m", k, prehash = "sha256"), "pure")
  # the boxes, and the private key never printed
  expect_box2(k, "FIPS module key", c("ML-DSA-44", "not shown"))
  expect_false(any(grepl("PRIVATE", capture.output(print(k)))))
  expect_box2(mod, "FIPS module", mod$name)
  # an attestation signed by a module key verifies
  man <- mkmnf(list(project = "fips mode"), env = FALSE)
  at <- cpsatst(man, k)
  expect_true(cpschkatst(at, man)$ok)
  # a key from another module, or a damaged one, is refused
  other <- k
  other$module$build <- "0.0.0-not-this-one"
  expect_error(cpssign("m", other), "not the one that made this key")
  broken <- k
  broken$pem <- NULL
  expect_error(cpssign("m", broken), "damaged")
})

test_that("fipsmod refuses an openssl it cannot use", {
  skip_on_os("windows")
  d <- withr::local_tempdir()
  expect_error(fipsmod(openssl = ""), "not found")
  expect_error(fipsmod(fake_openssl(d, "OpenSSL 3.0.13 30 Jan 2024")),
               "older than 3.5")
  mute <- file.path(d, "mute")
  writeLines(c("#!/bin/sh", "exit 0"), mute)
  Sys.chmod(mute, "0755")
  expect_error(fipsmod(mute), "did not report its version")
  dflt <- fake_openssl(d, "OpenSSL 3.5.9 29 Sep 2026", c(
    "Providers:", "  default", "    name: OpenSSL Default Provider",
    "    version: 3.5.9", "    status: active"
  ), modulesdir = d)
  expect_error(fipsmod(dflt, conf = ""), "did not load")
  expect_error(fipsmod(dflt, conf = file.path(d, "none.cnf")),
               "not a file")
  expect_error(fipsmod(dflt, conf = c("a", "b")), "one path")
})

test_that("the provider listing and the list of validated modules read", {
  lines <- c(
    "Providers:", "  base", "    name: OpenSSL Base Provider",
    "    version: 3.5.9", "    status: active",
    "  fips", "    name: Chainguard FIPS Provider for OpenSSL",
    "    version: 3.6.0", "    status: active",
    "    build info: 3.6.0-r4", "    gettable provider parameters:"
  )
  p <- .rmbl_fipsmod_parse(lines)
  expect_identical(p, list(name = "Chainguard FIPS Provider for OpenSSL",
                           version = "3.6.0", build = "3.6.0-r4"))
  # an inactive provider, or one without a FIPS name, is not the module
  expect_null(.rmbl_fipsmod_parse(sub("active", "inactive", lines)))
  expect_null(.rmbl_fipsmod_parse(lines[1:5]))
  # without a build line the version stands in
  p2 <- .rmbl_fipsmod_parse(lines[c(1, 6:9)])
  expect_identical(p2$build, "3.6.0")
  # the shipped list knows certificate 5523 (with PQC) and 4985 (without)
  v <- .rmbl_fipsmod_lookup("Chainguard FIPS Provider for OpenSSL",
                            "3.6.0-r4")
  expect_identical(v, list(status = "validated", cmvp = "#5523",
                           pqc = TRUE))
  old <- .rmbl_fipsmod_lookup("OpenSSL FIPS Provider", "3.1.2")
  expect_identical(old$status, "validated without PQC")
  expect_identical(.rmbl_fipsmod_lookup("Some FIPS Provider", "1")$status,
                   "not listed")
  expect_identical(.rmbl_fipsmod_lookup("x", "1", file = "")$status,
                   "not listed")
  # the boxes for each status
  base <- list(name = "M", version = "1", build = "1", openssl = "o",
               openssl_version = "3.5.9", conf = "c")
  for (st in list(v, old, list(status = "not listed", cmvp = NA_character_,
                               pqc = FALSE))) {
    m <- structure(c(base, st), class = c("rmbl_fipsmod", "list"))
    expect_box2(m, "FIPS module", switch(
      st$status, "validated" = "#5523", "validated without PQC" =
        "not cover", "check NIST"
    ))
  }
})

test_that("fipsmkg refuses what has no FIPS module", {
  expect_error(fipsmkg("ML-DSA-44", list()), "fipsmod")
  expect_error(fipsmkg("SLH-DSA-SHA2-128s", mod = 1), "fipsmod")
  bad <- .rmbl_xvrf_spki(17L, as.raw(rep(1, 10)))
  expect_error(.rmbl_fipsmod_spki_key(bad, "ML-DSA-44"), "not a standard")
  expect_identical(.rmbl_fipsmod_short("abcd"), "abcd")
  expect_match(.rmbl_fipsmod_short(strrep("ab", 40)), "\\(40 bytes\\)")
  expect_identical(.rmbl_fipsmod_status_text("validated", "#1"),
                   "validated, CMVP #1")
  expect_identical(.rmbl_fipsmod_status_text("not listed", NA),
                   "not listed")
})
