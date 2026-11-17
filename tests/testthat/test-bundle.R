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
    # uv resolves the morie project's packages over the network (pypi.org)
    # and writes its .venv outside tempdir(): never on CRAN
    skip_on_cran()
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

test_that("bundles and bundle checks print as boxes", {
  d <- tempfile("bnd-")
  dir.create(d)
  writeLines("a,b", file.path(d, "data.csv"))
  m <- mkmnf(list(project = "demo"), env = FALSE)
  key <- fipskg("ML-DSA-44")
  p <- file.path(d, "capsule_bundle.json")
  bnd <- cpsbndl(d, m, key, path = p)
  o1_expect_box(o1_box(bnd), bnd, "Capsule bundle", c("Files", "ML-DSA-44"))
  ck <- cpsbndlvrf(bnd, d)
  o1_expect_box(o1_box(ck), ck, "Bundle check: OK", "VERIFIED")
})

test_that(
  paste0(
    "a bundle whose note is not ASCII verifies in a C locale too ",
    "(JSON is read as UTF-8 whatever the locale)"
  ),
  {
    # the parser itself: UTF-8 bytes of unknown encoding come back marked
    v <- .rmbl_json_text(rawToChar(as.raw(c(0x22, 0xc3, 0xa9, 0x22))))
    expect_identical(Encoding(v), "UTF-8")
    expect_identical(charToRaw(v), as.raw(c(0xc3, 0xa9)))
    skip_on_cran()
    dir <- withr::local_tempdir()
    writeLines(c("x,y", "1,a", "2,b"), file.path(dir, "d.csv"))
    m <- mkmnf(list(dataset = "demo"), env = FALSE)
    note <- "Métis \U1F600 line sep"
    b <- cpsbndl(dir, m, fx_secret, note = note)
    mf <- file.path(withr::local_tempdir(), "m.rds")
    saveRDS(m, mf)
    code <- paste0(
      "r <- rmoriebricklayer::cpsbndlvrf(", deparse(attr(b, "path")),
      ", ", deparse(dir), ", man = readRDS(", deparse(mf), "), key = ",
      deparse(fx_secret), "); cat(l10n_info()[['UTF-8']], isTRUE(r$ok))"
    )
    skip_if_lowmem()
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
    expect_identical(utils::tail(out, 1L), "FALSE TRUE")
  }
)

test_that("a bundle with fields no signature covers fails", {
  dir <- withr::local_tempdir()
  writeLines("x", file.path(dir, "a.csv"))
  m <- mkmnf(list(x = 1), env = FALSE)
  k <- fipskg("ML-DSA-44", seed = as.raw(1:32))
  bp <- file.path(withr::local_tempdir(), "b.json")
  cpsbndl(dir, m, k, path = bp)
  expect_true(cpsbndlvrf(bp, dir, man = m, keyexp = k$public)$ok)
  edit <- function(f) {
    b <- fromjs(bp, simplifyVector = FALSE)
    p <- tempfile(fileext = ".json")
    writeLines(tojs(f(b), auto_unbox = TRUE, pretty = TRUE, na = "null",
                    null = "null", digits = I(17)), p)
    cpsbndlvrf(p, dir, man = m, keyexp = k$public)
  }
  expect_true(edit(identity)$ok)
  r <- edit(function(b) c(b, list(unsigned_claim = "reviewed")))
  expect_false(r$ok)
  expect_match(
    r$checks$detail[r$checks$check == "no_unsigned_fields"],
    "not covered by the signature: unsigned_claim"
  )
  r <- edit(function(b) {
    b$attestation$reviewer <- "x"
    b
  })
  expect_false(r$ok)
  expect_true("attestation:no_unsigned_fields" %in% r$checks$check)
  r <- edit(function(b) {
    b$attestation$signature$signature <- toupper(
      b$attestation$signature$signature
    )
    b
  })
  expect_false(r$ok)
  r <- edit(function(b) {
    b$attestation$signature$prehash <- "sha512"
    b
  })
  expect_false(r$ok)
})

test_that("an empty folder is no content of a bundled capsule", {
  dir <- withr::local_tempdir()
  writeLines("x", file.path(dir, "a.csv"))
  m <- mkmnf(list(x = 1), env = FALSE)
  b <- cpsbndl(dir, m, "a secret")
  expect_true(cpsbndlvrf(b, dir, man = m, key = "a secret")$ok)
  # a bundle lists files only: reported, an empty folder failed every
  # capsule sealed with one, for ever
  dir.create(file.path(dir, "added", "deeper"), recursive = TRUE)
  expect_true(cpsbndlvrf(b, dir, man = m, key = "a secret")$ok)
  # a file put in it is reported
  writeLines("y", file.path(dir, "added", "deeper", "f.txt"))
  r <- cpsbndlvrf(b, dir, man = m, key = "a secret")
  expect_false(r$ok)
  row <- r$checks[r$checks$check == "no_unlisted_files", ]
  expect_false(row$ok)
  expect_identical(
    row$detail,
    "not covered by the bundle: added/deeper/f.txt"
  )
  unlink(file.path(dir, "added"), recursive = TRUE)
  expect_true(cpsbndlvrf(b, dir, man = m, key = "a secret")$ok)
})

test_that("cpsbndlrd() refuses a file over 32 MiB, the cap of JSON documents", {
  # read whole, a very large file failed in readLines() as "cannot allocate
  # buffer"; the file check refuses it first, in the package's words
  f <- withr::local_tempfile(fileext = ".json")
  writeBin(raw(32 * 2^20 + 1), f)
  expect_error(
    cpsbndlrd(f),
    "`path` is larger than the 33,554,432 bytes read",
    fixed = TRUE
  )
})

test_that("a bundle respelt with the same values still verifies", {
  # the signature covers the values a bundle records, not the bytes of its
  # JSON: rewritten without changing a value, a bundle keeps verifying (the
  # hex, context, pre-hash and fields are what have one accepted spelling);
  # a byte-order mark is no JSON the package's documents start with, and the
  # bundle is refused before anything is checked
  dir <- withr::local_tempdir()
  writeBin(charToRaw("hello\n"), file.path(dir, "a.csv"))
  m <- mkmnf(list(x = 1), env = FALSE)
  p <- attr(cpsbndl(dir, m, "a secret"), "path")
  orig <- readBin(p, "raw", file.size(p))
  txt <- rawToChar(orig)
  expect_match(txt, "\"a.csv\"", fixed = TRUE)
  expect_match(txt, "\"size_bytes\": 6\\b")
  respelt <- list(
    escape = charToRaw(sub("\"a.csv\"", "\"\\u0061.csv\"", txt,
                           fixed = TRUE)),
    decimal = charToRaw(sub("(\"size_bytes\": 6)\\b", "\\1.0", txt)),
    crlf = charToRaw(gsub("\n", "\r\n", txt, fixed = TRUE))
  )
  for (k in names(respelt)) {
    expect_false(identical(respelt[[k]], orig), info = k)
    writeBin(respelt[[k]], p)
    r <- cpsbndlvrf(p, dir, man = m, key = "a secret")
    expect_true(r$ok, info = k)
  }
  writeBin(c(as.raw(c(0xef, 0xbb, 0xbf)), orig), p)
  expect_error(cpsbndlvrf(p, dir, man = m, key = "a secret"), "not JSON")
})

test_that("capsule_bundle.json is exempt only when it is the bundle checked", {
  dir <- withr::local_tempdir()
  writeLines("x", file.path(dir, "a.csv"))
  m <- mkmnf(list(x = 1), env = FALSE)
  bp <- file.path(withr::local_tempdir(), "b.json")
  cpsbndl(dir, m, "a secret", path = bp)
  expect_true(cpsbndlvrf(bp, dir, man = m, key = "a secret")$ok)
  # checked from outside, a file planted under the bundle's usual name is
  # content the bundle does not list, whatever it holds
  writeLines("anything", file.path(dir, "capsule_bundle.json"))
  r <- cpsbndlvrf(bp, dir, man = m, key = "a secret")
  expect_false(r$ok)
  expect_identical(
    r$checks$detail[r$checks$check == "no_unlisted_files"],
    "not covered by the bundle: capsule_bundle.json"
  )
  # the bundle in its usual place is its own file: exempt when it is checked
  unlink(file.path(dir, "capsule_bundle.json"))
  ip <- attr(cpsbndl(dir, m, "a secret"), "path")
  expect_true(cpsbndlvrf(ip, dir, man = m, key = "a secret")$ok)
  expect_true(cpsbndlvrf(cpsbndlrd(ip), dir, man = m, key = "a secret")$ok)
})
