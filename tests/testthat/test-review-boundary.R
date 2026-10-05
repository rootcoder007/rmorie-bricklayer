# The boundary defects of the 0.5.5 review: what the tool does when a check
# cannot be made, and when the bytes are hostile.

make_capsule <- function() {
  d <- file.path(tempfile("rmbl-cap-"), "caps")
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  f <- file.path(d, "data.csv")
  write.csv(data.frame(region = c("A", "B"), count = c(10, 20)), f, row.names = FALSE)
  list(dir = d, file = f, sha = sha256_file(f))
}
write_prov <- function(d, txt) writeLines(txt, file.path(d, "data_provenance.json"))

test_that("verify_capsule fails when it cannot check, not only when a check fails", {
  cp <- make_capsule()
  write_prov(cp$dir, sprintf('{"resource":{"filename":"data.csv","sha256":"%s"}}', cp$sha))
  honest <- verify_capsule(cp$dir)
  expect_s3_class(honest, "bricklayer_capsule_check")
  expect_true(honest$ok)
  expect_output(print(honest), "intact")

  # alter the data, then delete one field at a time: every one must FAIL
  write.csv(data.frame(region = c("A", "B"), count = c(10, 999)), cp$file, row.names = FALSE)
  write_prov(cp$dir, sprintf('{"resource":{"filename":"data.csv","sha256":"%s"}}', cp$sha))
  expect_false(verify_capsule(cp$dir)$ok)
  write_prov(cp$dir, '{"resource":{"filename":"data.csv"}}')
  r <- verify_capsule(cp$dir)
  expect_false(r$ok)
  expect_false(r$checks$ok[r$checks$check == "data_sha256"])
  expect_match(r$checks$detail[r$checks$check == "data_sha256"], "no sha256 recorded")
  write_prov(cp$dir, '{"resource":{"other":"x"}}')
  expect_false(verify_capsule(cp$dir)$ok)
  write_prov(cp$dir, '{"meta":{"note":"none"}}')
  expect_false(verify_capsule(cp$dir)$ok)
  write_prov(cp$dir, "{}")
  r <- verify_capsule(cp$dir)
  expect_false(r$ok)
  expect_output(print(r), "NOT VERIFIED")
})

test_that("verify_capsule refuses a path that escapes the capsule", {
  cp <- make_capsule()
  outside <- file.path(dirname(cp$dir), "outside.csv")
  writeLines("content outside the capsule", outside)
  write_prov(cp$dir, sprintf('{"resource":{"filename":"../outside.csv","sha256":"%s"}}',
                             sha256_file(outside)))
  r <- verify_capsule(cp$dir)
  expect_false(r$ok)
  expect_false(r$checks$ok[r$checks$check == "data_present"])
  expect_null(rmoriebricklayer:::.rmbl_safe_rel("../x", cp$dir))
  expect_null(rmoriebricklayer:::.rmbl_safe_rel("/etc/passwd", cp$dir))
  expect_null(rmoriebricklayer:::.rmbl_safe_rel("C:/x", cp$dir))
  expect_null(rmoriebricklayer:::.rmbl_safe_rel("~/x", cp$dir))
  expect_type(rmoriebricklayer:::.rmbl_safe_rel("sub/data.csv", cp$dir), "character")
})

test_that("verify_capsule treats a pinned script digest and a synthetic sidecar as checks", {
  cp <- make_capsule()
  write_prov(cp$dir, sprintf(
    '{"resource":{"filename":"data.csv","sha256":"%s"},"script":{"sha256":"%s"}}',
    cp$sha, strrep("0", 64)))
  r <- verify_capsule(cp$dir)
  expect_false(r$ok)
  expect_match(r$checks$detail[r$checks$check == "script_sha256"], "no script file is named")
  write_prov(cp$dir, sprintf('{"resource":{"filename":"data.csv","sha256":"%s"}}', cp$sha))
  writeLines('{"synthetic":true}', paste0(cp$file, ".synthetic"))
  r <- verify_capsule(cp$dir)
  expect_false(r$ok)
  expect_true("data_not_synthetic" %in% r$checks$check)
})

test_that("the JSON parser refuses duplicate keys, deep nesting and lone surrogates", {
  expect_error(bricklayer_json_from_json('{"sha256":"aaaa","sha256":"bbbb"}'), "duplicate key")
  kept <- bricklayer_json_from_json('{"a":1,"a":2}', duplicate_keys = "keep",
                                    simplifyVector = FALSE)
  expect_length(kept, 2L)
  deep <- paste0(strrep("[", 20000), strrep("]", 20000))
  expect_error(bricklayer_json_from_json(deep), "nesting deeper than 200")
  expect_error(bricklayer_json_from_json('{"k":"\\ud800"}'), "lone surrogate")
  expect_identical(bricklayer_json_from_json('{"k":"\\ud83d\\ude00"}')$k, "\U0001F600")
  expect_warning(v <- bricklayer_json_from_json("[12345678901234567890]"), "exceeds 2\\^53")
  expect_identical(bricklayer_json_from_json("[12345678901234567890]", bigint_as_char = TRUE),
                   "12345678901234567890")
})

test_that("bricklayer_json_unserialize rebuilds data, not code, unless trusted", {
  f <- factor(c("b", "a"), levels = c("a", "b", "c"))
  expect_identical(bricklayer_json_unserialize(bricklayer_json_serialize(f)), f)
  expect_error(bricklayer_json_unserialize(bricklayer_json_serialize(sum)), "refuses to rebuild a 'builtin'")
  expect_error(bricklayer_json_unserialize(bricklayer_json_serialize(quote(system("true")))),
               "refuses to rebuild a 'language'")
  expect_error(bricklayer_json_unserialize(bricklayer_json_serialize(function(x) x + 1)),
               "refuses to rebuild a 'closure'")
  expect_identical(bricklayer_json_unserialize(bricklayer_json_serialize(sum), trusted = TRUE), sum)
})

test_that("canonicalisation sorts a level with an empty-string key", {
  a <- stats::setNames(list(1, 2, 3), c("b", "", "a"))
  b <- stats::setNames(list(3, 1, 2), c("a", "b", ""))
  expect_identical(manifest_canonical(list(meta = a, results = list())),
                   manifest_canonical(list(meta = b, results = list())))
})

test_that("public URLs are https, public and never file://", {
  chk <- rmoriebricklayer:::.rmbl_check_public_url
  expect_identical(chk("https://data.ontario.ca/x.csv"), "https://data.ontario.ca/x.csv")
  expect_error(chk("file:///etc/passwd"), "https://")
  expect_error(chk("http://data.ontario.ca/x.csv"), "https://")
  expect_error(chk("https://localhost:8080/"), "local or private")
  expect_error(chk("https://127.0.0.1/"), "local or private")
  expect_error(chk("https://169.254.169.254/latest/meta-data/"), "local or private")
  expect_error(chk("https://10.0.0.5/"), "local or private")
  expect_error(chk("https://192.168.1.1/"), "local or private")
  expect_error(chk("https://172.16.0.1/"), "local or private")
  expect_error(chk("https://[::1]/"), "local or private")
  expect_error(chk("https://user@[fe80::1]/"), "local or private")
  expect_identical(chk("https://172.32.0.1/"), "https://172.32.0.1/")
  withr::local_options(rmoriebricklayer.allow_http = TRUE)
  expect_identical(chk("http://data.ontario.ca/"), "http://data.ontario.ca/")
  tf <- tempfile()
  writeLines("LOCAL", tf)
  expect_error(bricklayer_download(paste0("file://", tf), tempfile()), "https://")
  dest <- tempfile()
  bricklayer_download(paste0("file://", tf), dest, quiet = TRUE, allow_file = TRUE)
  expect_identical(readLines(dest), "LOCAL")
})

test_that("a capsule bundle covers dotfiles and refuses escaping paths", {
  d <- tempfile("bundle-")
  dir.create(d)
  writeLines("x", file.path(d, "a.txt"))
  writeLines("setwd('/')", file.path(d, ".Rprofile"))
  key <- pqc_keygen(height = 2L)
  man <- make_manifest(list(project = "p"), environment = FALSE)
  b <- capsule_bundle(d, man, key)
  expect_true(".Rprofile" %in% vapply(b$files, function(e) e$path, ""))
  chk <- capsule_bundle_verify(file.path(d, "capsule_bundle.json"), d, manifest = man)
  expect_true(chk$ok)
  writeLines("y", file.path(d, ".hidden"))
  chk2 <- capsule_bundle_verify(file.path(d, "capsule_bundle.json"), d, manifest = man)
  expect_false(chk2$checks$ok[chk2$checks$check == "no_unlisted_files"])
})

test_that("gzip JSON refuses a bomb by its ISIZE trailer", {
  g <- json_gzip_encode(list(a = 1))
  expect_identical(json_gzip_decode(g)$a, 1L)
  bytes <- bricklayer_json_base64_dec(g)
  bytes[(length(bytes) - 3L):length(bytes)] <- as.raw(c(0xff, 0xff, 0xff, 0xff))
  expect_error(json_gzip_decode(bytes), "ISIZE")
})

test_that("the synthetic flag belongs to the package, and synthetic data carry a sidecar", {
  withr::local_envvar(BRICKLAYER_SYNTHETIC = "1")
  m <- make_manifest(list(project = "p"), environment = FALSE)
  expect_true(m$meta$synthetic)
  m <- record(m, "n", observed = 5, expected = 5)
  expect_identical(m$results$n$status, "INFO")
  p <- write_manifest_json(list(meta = list(project = "q"), results = list()), tempfile(fileext = ".json"))
  expect_true(bricklayer_json_from_json(p, simplifyVector = FALSE)$meta$synthetic)
  withr::local_envvar(BRICKLAYER_SYNTHETIC = NA)
  schema <- list(seed = 3L, n_rows = 5L,
                 columns = list(region = list(type = "sample", values = list("E", "W"))))
  f <- tempfile(fileext = ".csv")
  info <- make_synthetic_csv(schema, f)
  expect_s3_class(info, "bricklayer_synthetic")
  expect_true(file.exists(paste0(f, ".synthetic")))
  expect_output(print(info), "SYNTHETIC")
})

test_that("hostile DER is an error, not an abort", {
  h <- "301405000488fffffffffffffff40000000000000000"
  b <- as.raw(strtoi(substring(h, seq(1, nchar(h), 2), seq(2, nchar(h), 2)), 16L))
  expect_error(.Call(rmoriebricklayer:::C_rmbl_der_parse, b), "not well-formed DER")
  h2 <- "300c0488ffffffffffffffff0100"
  b2 <- as.raw(strtoi(substring(h2, seq(1, nchar(h2), 2), seq(2, nchar(h2), 2)), 16L))
  expect_error(.Call(rmoriebricklayer:::C_rmbl_der_parse, b2), "not well-formed DER")
})

test_that("a DRBG reseeds itself in a new process", {
  d <- drbg_new(as.raw(0:47))
  expect_identical(d$pid, Sys.getpid())
  d$pid <- -1L
  x <- drbg_generate(d, 16)
  expect_identical(d$pid, Sys.getpid())
  # and the stream is no longer the deterministic one
  e <- drbg_new(as.raw(0:47))
  expect_false(identical(x, drbg_generate(e, 16)))
})
