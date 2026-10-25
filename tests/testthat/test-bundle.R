# Capsule bundles signed with a shared secret (hmac), the scheme morie signs
# with: a bundle morie wrote verifies here, and one written here verifies with
# morie.

fx_secret <- "rmbl-test-secret-hmac" # a test secret, recorded on purpose
fx_key_id <- "1c28aab2838d16e632796fc899e5c4724117a19b60a66eb70f0a5b9bf55afe5b"

test_that(
  paste0(
    "a bundle signed by morie (hmac) verifies, and fails without or with ",
    "the wrong secret"
  ),
  {
    fx <- test_path("fixtures", "morie-hmac")
    b <- file.path(fx, "capsule_bundle.json")
    res <- cpsbndlvrf(b, fx, keyexp = fx_key_id, key = fx_secret)
    expect_true(res$ok)
    expect_true(res$checks$ok[res$checks$check == "attestation:signature"])
    expect_true(res$checks$ok[
      res$checks$check == "attestation:key_as_expected"
    ])
    expect_true(all(
      c("file:d.csv", "file:data_provenance.json") %in% res$checks$check
    ))
    expect_false(cpsbndlvrf(b, fx)$ok)
    bad <- cpsbndlvrf(b, fx, key = "not-the-secret")
    expect_false(bad$checks$ok[bad$checks$check == "attestation:signature"])
    # the capsule itself verifies too
    expect_true(vrfcps(fx)$ok)
  }
)

test_that(
  paste0(
    "an hmac bundle written here keeps the ",
    "secret out and verifies with morie"
  ),
  {
    dir <- withr::local_tempdir()
    writeLines(c("x,y", "1,a", "2,b"), file.path(dir, "d.csv"))
    m <- mkmnf(list(dataset = "demo"), env = FALSE)
    b <- cpsbndl(dir, m, fx_secret, note = "from R")
    expect_identical(b$attestation$public, fx_key_id)
    txt <- readLines(attr(b, "path"))
    expect_false(any(grepl(fx_secret, txt, fixed = TRUE)))
    expect_true(
      cpsbndlvrf(
        attr(b, "path"),
        dir,
        man = m,
        keyexp = fx_key_id,
        key = fx_secret
      )$ok
    )
    uv <- Sys.which("uv")
    morie <- Sys.getenv("MORIE_SRC", path.expand("~/work/morie"))
    skip_if(
      !nzchar(uv) ||
        !file.exists(file.path(morie, "src", "morie", "capsule", "_sign.py")),
      "uv or the morie source tree is absent"
    )
    out <- withr::with_envvar(
      c(MORIE_CAPSULE_KEY = fx_secret),
      suppressWarnings(system2(
        uv,
        c(
          "run",
          "--quiet",
          "--project",
          shQuote(morie),
          "morie",
          "capsule",
          "verify",
          shQuote(dir),
          "--public-key",
          fx_key_id,
          "--json"
        ),
        stdout = TRUE,
        stderr = FALSE
      ))
    )
    expect_null(attr(out, "status"))
    got <- fromjs(paste(out, collapse = "\n"), simplifyVector = FALSE)
    expect_true(got$bundle$ok)
    rows <- vapply(got$bundle$checks, function(r) r$check, "")
    oks <- vapply(got$bundle$checks, function(r) isTRUE(r$ok), TRUE)
    expect_true(oks[rows == "attestation:signature"])
    expect_true(oks[rows == "attestation:key_as_expected"])
  }
)
