# Project Wycheproof (C2SP/wycheproof, testvectors_v1): signature-verification
# vectors built to catch what a home-grown verifier gets wrong -- malformed
# DER, non-canonical integers, r or s outside [1, n-1], points off the curve,
# padding and DigestInfo variants in PKCS#1 v1.5. Every "valid" vector must
# verify and every "invalid" one must not; "acceptable" vectors (legal but
# legacy encodings) are reported, and this verifier rejects them.

wp_read <- function(name) {
  utils::read.delim(test_path(name), sep = "|", quote = "", comment.char = "#",
                    header = FALSE, colClasses = "character", fill = TRUE,
                    strip.white = FALSE)
}
hex2raw <- function(h) if (!nzchar(h)) raw(0) else rmoriebricklayer:::.rmbl_hex_to_raw(h)
coord <- function(h, n) {
  r <- hex2raw(h)
  while (length(r) > n && r[1] == as.raw(0)) r <- r[-1]
  if (length(r) > n) return(NULL)
  c(raw(n - length(r)), r)
}

wp_ecdsa <- function(file, curve, alg, n) {
  v <- wp_read(file)
  names(v) <- c("tcId", "group", "result", "flags", "qx", "qy", "msg", "sig", "comment")
  verified <- logical(nrow(v))
  for (i in seq_len(nrow(v))) {
    qx <- coord(v$qx[i], n)
    qy <- coord(v$qy[i], n)
    rs <- rmoriebricklayer:::.rmbl_ecdsa_rs(hex2raw(v$sig[i]))
    if (is.null(qx) || is.null(qy) || is.null(rs)) next
    dig <- rmoriebricklayer:::.rmbl_ts_digest(alg, hex2raw(v$msg[i]))
    verified[i] <- isTRUE(tryCatch(
      .Call(rmoriebricklayer:::C_rmbl_ecdsa_verify, curve, qx, qy, rs$r, rs$s, dig),
      error = function(e) FALSE))
  }
  list(v = v, verified = verified)
}

wp_check <- function(res) {
  v <- res$v
  ok <- res$verified
  must <- v$result == "valid"
  bad_reject <- which(must & !ok)
  bad_accept <- which(v$result == "invalid" & ok)
  accepted_legacy <- which(v$result == "acceptable" & ok)
  label <- function(idx) paste(sprintf("tcId %s (%s)", v$tcId[idx], v$comment[idx]), collapse = "; ")
  expect(length(bad_reject) == 0L, sprintf("%d valid signature(s) rejected: %s", length(bad_reject), label(bad_reject)))
  expect(length(bad_accept) == 0L,
         sprintf("%d invalid signature(s) accepted: %s", length(bad_accept), label(bad_accept)))
  expect(length(accepted_legacy) == 0L,
         sprintf("%d legacy encoding(s) accepted: %s", length(accepted_legacy), label(accepted_legacy)))
  c(valid = sum(must), invalid = sum(v$result == "invalid"), acceptable = sum(v$result == "acceptable"))
}

test_that("ECDSA P-256 / SHA-256 verification passes the Wycheproof suite", {
  counts <- wp_check(wp_ecdsa("wycheproof-ecdsa-p256-sha256.txt", "P-256", "sha256", 32L))
  expect_gte(counts[["valid"]], 100L)
  expect_gte(counts[["invalid"]], 300L)
})

test_that("ECDSA P-384 / SHA-384 verification passes the Wycheproof suite", {
  counts <- wp_check(wp_ecdsa("wycheproof-ecdsa-p384-sha384.txt", "P-384", "sha384", 48L))
  expect_gte(counts[["valid"]], 100L)
  expect_gte(counts[["invalid"]], 300L)
})

test_that("RSASSA-PKCS1-v1_5 2048 / SHA-256 verification passes the Wycheproof suite", {
  v <- wp_read("wycheproof-rsa-pkcs1-2048-sha256.txt")
  names(v) <- c("tcId", "group", "result", "flags", "n", "e", "sha", "msg", "sig", "comment")
  verified <- logical(nrow(v))
  for (i in seq_len(nrow(v))) {
    # the vectors carry n as an ASN.1 INTEGER (a leading zero byte keeps
    # it positive); the key is the magnitude
    n_raw <- hex2raw(v$n[i])
    while (length(n_raw) > 1L && n_raw[1] == as.raw(0)) n_raw <- n_raw[-1]
    em <- tryCatch(
      .Call(rmoriebricklayer:::C_rmbl_rsa_recover, hex2raw(v$sig[i]), n_raw, hex2raw(v$e[i])),
      error = function(e) NULL)
    if (is.null(em)) next
    verified[i] <- isTRUE(rmoriebricklayer:::.rmbl_pkcs1_check(em, "sha256", hex2raw(v$msg[i]))$ok)
  }
  counts <- wp_check(list(v = v, verified = verified))
  expect_gte(counts[["valid"]], 9L)
  expect_gte(counts[["invalid"]], 150L)
})
