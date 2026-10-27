# The eleven 0.5.x names rmoriedata 0.3.x (CRAN) calls: each forwards with its
# arguments mapped.

test_that(
  paste0(
    "the signing wrappers round-trip the ",
    "way rmoriedata 0.3.3 uses them"
  ),
  {
    key <- pqc_keygen(height = 2)
    expect_s3_class(key, "bricklayer_signing_key")
    bytes <- charToRaw("path,size,sha256\n")
    sig <- capsule_sign(core_sha256(bytes), key)
    expect_s3_class(sig, "bricklayer_signature")
    # rmoriedata writes the signature and the public key through the JSON
    # wrappers and reads them back as plain lists with the class set, the public
    # key carrying `pub_seed`
    sig_txt <- bricklayer_json_to_json(unclass(sig), auto_unbox = TRUE)
    pub <- unclass(signing_public_key(key))
    names(pub)[names(pub) == "pubseed"] <- "pub_seed"
    pub_txt <- bricklayer_json_to_json(pub, auto_unbox = TRUE)
    sig2 <- bricklayer_json_from_json(sig_txt)
    class(sig2) <- c("bricklayer_signature", "list")
    pub2 <- bricklayer_json_from_json(pub_txt)
    class(pub2) <- c("bricklayer_public_key", "list")
    expect_true(capsule_verify(core_sha256(bytes), sig2, pub2))
    expect_false(capsule_verify(core_sha256(c(bytes, as.raw(1L))), sig2, pub2))
    expect_identical(
      capsule_verify(
        core_sha256(bytes),
        sig,
        key,
        context = NULL,
        prehash = "none"
      ),
      cpsvrf(csha256(bytes), sig, key, prehash = "none")
    )
  }
)

test_that("the seeded key generator maps its argument names", {
  seeds <- lapply(1:3, function(i) strrep(sprintf("%02d", i), 32))
  a <- pqc_keygen(
    2,
    sk_seed = seeds[[1]],
    pub_seed = seeds[[2]],
    sk_prf = seeds[[3]]
  )
  b <- pqckg(2, skseed = seeds[[1]], pubseed = seeds[[2]], skprf = seeds[[3]])
  expect_identical(a$root, b$root)
  expect_identical(signing_public_key(a), signpubkey(b))
})

test_that("the core and file wrappers equal the new names", {
  f <- tempfile()
  writeLines("abc", f)
  expect_identical(sha256_file(f), sha256file(f))
  expect_identical(core_sha256("provenance"), csha256("provenance"))
  expect_identical(core_mean(c(2, 4, 4, 4, 5, 5, 7, 9)), 5)
  expect_identical(
    bricklayer_json_to_json(list(a = 1), auto_unbox = TRUE),
    tojs(list(a = 1), auto_unbox = TRUE)
  )
  expect_identical(
    bricklayer_json_from_json("{\"a\":[1,2]}"),
    fromjs("{\"a\":[1,2]}")
  )
})

test_that("the network wrappers map wayback and timeout onto the new names", {
  seen <- new.env()
  local_mocked_bindings(
    blfetch = function(url, dest, wb = "", tmout = 120L) {
      seen$v <- list(url, dest, wb, tmout)
      dest
    },
    wbsnpurl = function(url, ts = NULL) list(url = url, ts = ts)
  )
  expect_identical(
    bricklayer_fetch(
      "https://example.org/x.csv",
      "d.csv",
      wayback = "20240101",
      timeout = 7L
    ),
    "d.csv"
  )
  expect_identical(
    seen$v,
    list("https://example.org/x.csv", "d.csv", "20240101", 7L)
  )
  expect_identical(
    wayback_snapshot_url("https://example.org", timestamp = "2024"),
    list(url = "https://example.org", ts = "2024")
  )
})

test_that("0.5.x aliases name their own arguments in errors", {
  expect_error(pqc_keygen(2, sk_seed = "zz"), "`sk_seed` must be 64 hex")
  expect_error(
    wayback_snapshot_url("https://a.org", timestamp = "zz"),
    "wayback_snapshot_url: `timestamp` must be NULL"
  )
  k <- fipskg("ML-DSA-44")
  expect_error(
    capsule_sign("m", k, deterministic = NA),
    "capsule_sign: `deterministic` must be TRUE or FALSE"
  )
  expect_error(capsule_verify(function() 1, NULL, k), "`message` must be data")
})

test_that("an error the alias map does not change is raised as it was", {
  e <- structure(
    class = c("cz_error", "error", "condition"),
    list(message = "boom", call = NULL)
  )
  expect_error(
    .rmbl_compat_errors(stop(e), "newfn", "oldfn", list(a = "b")),
    class = "cz_error"
  )
})
