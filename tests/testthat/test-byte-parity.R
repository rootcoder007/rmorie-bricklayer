# Byte-for-byte parity against OTHER implementations.
#
# Published test vectors prove a primitive reproduces a handful of
# documented inputs. They do not prove it agrees with the libraries a
# user's pipeline already contains, and they do not exercise the lengths
# where a padding or block-boundary bug hides. So every hash, keyed hash,
# checksum, key-derivation, base64 and JSON output here is compared with
# an independent implementation -- digest, openssl, jsonlite, and base R's
# own gzip codec -- over a length sweep that crosses every block boundary
# in the construction.
#
# A capsule's provenance is only worth anything if the digest it records
# is the same number anybody else would compute for the same bytes.

skip_if_no <- function(pkg) skip_if_not_installed(pkg)

# lengths chosen to straddle every boundary that matters: SHA-256's
# 64-byte block and its 55/56-byte padding cut-off, SHA-512's 128-byte
# block and 111/112-byte cut-off, and base64's three-byte group
byte_lengths <- sort(unique(c(
  0:8, 54:57, 62:66, 110:113, 119:121, 126:130, 191:193, 255, 256, 257,
  1000, 4096
)))

# strtoi() gives NA above 2^31 - 1, so it cannot read a full CRC-32
hex_to_num <- function(h) {
  d <- strtoi(strsplit(h, "")[[1L]], base = 16L)
  sum(d * 16^rev(seq_along(d) - 1L))
}

rnd <- function(n, seed) {
  set.seed(seed)
  if (n == 0L) return(raw(0))
  as.raw(sample.int(256L, n, replace = TRUE) - 1L)
}

test_that("SHA-256 agrees with digest and openssl at every boundary", {
  skip_if_no("digest")
  skip_if_no("openssl")
  for (n in byte_lengths) {
    b <- rnd(n, 1000L + n)
    got <- core_sha256(b)
    expect_identical(got, digest::digest(b, algo = "sha256", serialize = FALSE))
    expect_identical(got, paste(openssl::sha256(b), collapse = ""))
  }
  # and on a string, where the bytes hashed must be the string's own
  for (s in c("", "a", "abc", strrep("x", 55), strrep("x", 56),
              strrep("x", 64), strrep("y", 1000))) {
    expect_identical(core_sha256(s),
                     digest::digest(s, algo = "sha256", serialize = FALSE))
    # a string and its bytes are the same input
    expect_identical(core_sha256(s), core_sha256(charToRaw(s)))
  }
  # a megabyte, to catch a length counter that overflows past 2^19 bits
  big <- rnd(1048576L, 7L)
  expect_identical(core_sha256(big),
                   digest::digest(big, algo = "sha256", serialize = FALSE))
})

test_that("SHA-512 agrees with digest and openssl at every boundary", {
  skip_if_no("digest")
  skip_if_no("openssl")
  for (n in byte_lengths) {
    b <- rnd(n, 2000L + n)
    got <- core_sha512(b)
    expect_identical(got, digest::digest(b, algo = "sha512", serialize = FALSE))
    expect_identical(got, paste(openssl::sha512(b), collapse = ""))
  }
  for (s in c("", "abc", strrep("x", 111), strrep("x", 112),
              strrep("x", 128))) {
    expect_identical(core_sha512(s),
                     digest::digest(s, algo = "sha512", serialize = FALSE))
    expect_identical(core_sha512(s), core_sha512(charToRaw(s)))
  }
})

test_that("CRC-32 agrees with digest as a number", {
  skip_if_no("digest")
  # digest reports the checksum in hex, this reports it as a number; the
  # two must be the same integer, which is what a manifest compares
  for (n in byte_lengths) {
    b <- rnd(n, 3000L + n)
    expect_identical(core_crc32(b),
                     hex_to_num(digest::digest(b, algo = "crc32",
                                               serialize = FALSE)))
  }
  # the checksum stays inside the unsigned 32-bit range
  vals <- vapply(byte_lengths, function(n) core_crc32(rnd(n, 40L + n)), 0)
  expect_true(all(vals >= 0 & vals <= 4294967295))
})

test_that("HMAC-SHA-256 agrees with openssl across the key-length cases", {
  skip_if_no("openssl")
  # the three cases in RFC 2104 are a key shorter than the block, exactly
  # the block, and longer than the block (which must be hashed first)
  for (kn in c(0L, 1L, 20L, 31L, 32L, 63L, 64L, 65L, 100L, 200L)) {
    key <- rnd(kn, 5000L + kn)
    for (mn in c(0L, 1L, 55L, 56L, 64L, 65L, 1000L)) {
      msg <- rnd(mn, 6000L + mn)
      expect_identical(
        core_hmac_sha256(key, msg),
        paste(openssl::sha256(msg, key = key), collapse = ""))
    }
  }
  # a string key and message go the same way
  expect_identical(core_hmac_sha256("key", "message"),
                   paste(openssl::sha256(charToRaw("message"),
                                         key = charToRaw("key")),
                         collapse = ""))
  # changing one bit of the key changes the tag: the key is actually used
  k1 <- rnd(32L, 11L)
  k2 <- k1
  k2[1] <- as.raw(bitwXor(as.integer(k2[1]), 1L))
  expect_false(identical(core_hmac_sha256(k1, "m"),
                         core_hmac_sha256(k2, "m")))
})

test_that("BLAKE2b agrees with openssl at its full digest length", {
  skip_if_no("openssl")
  # openssl's blake2b is the 512-bit variant; the digest length is part of
  # BLAKE2b's parameter block, so this is the only length that can be
  # compared directly -- a shorter output is a different function, not a
  # truncation
  for (n in c(0L, 1L, 64L, 127L, 128L, 129L, 1000L)) {
    b <- rnd(n, 7000L + n)
    expect_identical(core_blake2b(b, length = 64L),
                     paste(openssl::blake2b(b), collapse = ""))
  }
  # and truncating the 512-bit digest is NOT the 256-bit one
  b <- rnd(100L, 8L)
  expect_false(identical(core_blake2b(b, length = 32L),
                         substring(core_blake2b(b, length = 64L), 1L, 64L)))
})

test_that("the derived key matches an independent PBKDF2", {
  # PBKDF2-HMAC-SHA-256 rebuilt in R from the package's own HMAC: the
  # composition is independent of the C implementation even though the
  # primitive is shared, so this catches a wrong counter, a wrong XOR
  # fold, or a wrong block index
  ref <- function(pass, salt, iter, dklen) {
    hexraw <- function(h) .rmbl_hex_to_raw(h)
    out <- raw(0)
    block <- 1L
    while (length(out) < dklen) {
      ctr <- as.raw(c(bitwAnd(bitwShiftR(block, 24L), 255L),
                      bitwAnd(bitwShiftR(block, 16L), 255L),
                      bitwAnd(bitwShiftR(block, 8L), 255L),
                      bitwAnd(block, 255L)))
      u <- hexraw(core_hmac_sha256(pass, c(salt, ctr)))
      acc <- u
      for (i in seq_len(iter - 1L)) {
        u <- hexraw(core_hmac_sha256(pass, u))
        acc <- as.raw(bitwXor(as.integer(acc), as.integer(u)))
      }
      out <- c(out, acc)
      block <- block + 1L
    }
    paste(sprintf("%02x", as.integer(out[seq_len(dklen)])), collapse = "")
  }
  for (iter in c(1L, 2L, 17L)) {
    for (dk in c(1L, 16L, 20L, 32L, 40L, 64L)) {
      expect_identical(derive_key("password", "salt", iter, dk),
                       ref(charToRaw("password"), charToRaw("salt"),
                           iter, dk))
    }
  }
  # RFC 6070 is for HMAC-SHA-1, so its digests do not apply, but its
  # structure does: a longer key than one block, and a derived length
  # spanning several blocks, must both come out right
  expect_identical(derive_key(strrep("p", 100), "NaCl", 3L, 80L),
                   ref(charToRaw(strrep("p", 100)), charToRaw("NaCl"),
                       3L, 80L))
  # more iterations is a different key, so the count is not ignored
  expect_false(identical(derive_key("p", "s", 1L, 32L),
                         derive_key("p", "s", 2L, 32L)))
  # and a longer request extends the same prefix, block by block
  expect_identical(substring(derive_key("p", "s", 4L, 64L), 1L, 64L),
                   derive_key("p", "s", 4L, 32L))
})

test_that("base64 agrees with openssl over every padding case", {
  skip_if_no("openssl")
  for (n in byte_lengths) {
    b <- rnd(n, 9000L + n)
    got <- bricklayer_json_base64_enc(b)
    # this codec is a jsonlite-parity codec, so jsonlite is the exact
    # reference -- MIME line wrapping included, which survives inside
    # JSON as an escaped \n
    skip_if_no("jsonlite")
    expect_identical(got, jsonlite::base64_enc(b))
    # and the alphabet and padding agree with openssl once both sides'
    # line breaks are removed
    expect_identical(gsub("\n", "", got, fixed = TRUE),
                     gsub("\n", "", openssl::base64_encode(b),
                          fixed = TRUE))
    # and decodes back to exactly the bytes
    expect_identical(bricklayer_json_base64_dec(got), b)
  }
  # the URL-safe alphabet differs only in the two characters that are
  # unsafe in a URL, and drops the padding
  for (n in 0:40) {
    b <- rnd(n, 500L + n)
    std <- gsub("\n", "", openssl::base64_encode(b), fixed = TRUE)
    want <- gsub("=", "", chartr("+/", "-_", std), fixed = TRUE)
    # the URL-safe form carries no line breaks, since it exists to go
    # into a URL
    expect_identical(bricklayer_json_base64url_enc(b), want)
    expect_identical(bricklayer_json_base64url_dec(
      bricklayer_json_base64url_enc(b)), b)
  }
  # the line-wrapping rule is driven by the INPUT block, not the output
  # width, so sweep every length across several block boundaries rather
  # than sampling: 52, 53 and 54 bytes all encode to 72 characters and
  # only 54 of them terminates a block
  skip_if_no("jsonlite")
  for (n in 0:400) {
    b <- as.raw(rep(65L, n))
    expect_identical(bricklayer_json_base64_enc(b), jsonlite::base64_enc(b))
  }
  # the two bytes that separate the alphabets, so the substitution is
  # actually exercised rather than merely possible
  expect_identical(bricklayer_json_base64_enc(as.raw(c(0xfb, 0xff))), "+/8=")
  expect_identical(bricklayer_json_base64url_enc(as.raw(c(0xfb, 0xff))), "-_8")
})

test_that("the JSON writer agrees with jsonlite", {
  skip_if_no("jsonlite")
  cases <- list(
    list(), list(a = 1L), list(a = 1.5, b = "x"),
    list(a = c(1L, 2L, 3L)), list(a = c(TRUE, FALSE)),
    list(a = NULL), list(a = list(b = list(c = 1L))),
    list(a = "quote\"and\\slash"), list(a = "tab\tnewline\n"),
    list(a = c(1.0, NA, NaN, Inf, -Inf)),
    list(a = c("x", NA_character_)),
    list(a = 1e-10, b = 1e10),
    setNames(list(1L), "key with spaces")
  )
  for (x in cases) {
    expect_identical(
      as.character(bricklayer_json_to_json(x, auto_unbox = FALSE)),
      as.character(jsonlite::toJSON(x, auto_unbox = FALSE, digits = NA)))
  }
  # a data frame, in each of the three orientations jsonlite offers
  df <- data.frame(i = 1:3, x = c(1.5, 2.5, 3.5),
                   s = c("a", "b", "c"), stringsAsFactors = FALSE)
  for (orient in c("rows", "columns", "values")) {
    expect_identical(
      as.character(bricklayer_json_to_json(df, dataframe = orient)),
      as.character(jsonlite::toJSON(df, dataframe = orient, digits = NA)))
  }
  # and the round trip returns the same structure
  for (x in cases[-6]) {
    expect_equal(bricklayer_json_from_json(
      as.character(bricklayer_json_to_json(x, auto_unbox = FALSE))),
      jsonlite::fromJSON(
        as.character(jsonlite::toJSON(x, auto_unbox = FALSE, digits = NA))))
  }
})

test_that("the gzip codec is real gzip", {
  # a stream is only useful if something else can read it, so decode it
  # with base R's own inflater rather than with the encoder's inverse
  x <- list(a = 1:100, b = strrep("compress me ", 200))
  enc <- json_gzip_encode(x, raw = TRUE)
  expect_true(is.raw(enc))
  # the gzip magic number and deflate method, per RFC 1952
  expect_identical(enc[1:3], as.raw(c(0x1f, 0x8b, 0x08)))
  txt <- rawToChar(memDecompress(enc, type = "gzip"))
  expect_identical(json_gzip_decode(enc, raw = TRUE), x)
  # and raw bytes are recognised as bytes without having to say so again
  expect_identical(json_gzip_decode(enc), x)
  # while a character input still has to be base64
  expect_error(json_gzip_decode("not base64 at all", raw = TRUE),
               "must be a raw vector")
  skip_if_no("jsonlite")
  expect_equal(jsonlite::fromJSON(txt, simplifyVector = FALSE)$a[[1]], 1L)
  # the header records no modification time, so the same input always
  # gives the same bytes and a capsule digest does not move with the
  # clock
  expect_identical(enc, json_gzip_encode(x, raw = TRUE))
  expect_identical(enc[5:8], as.raw(c(0, 0, 0, 0)))
  # the trailer is the CRC-32 and length of the UNCOMPRESSED data, little
  # endian, which is what an external tool checks before it trusts the
  # output
  n <- length(enc)
  le <- function(r) sum(as.integer(r) * 256^(0:3))
  expect_identical(le(enc[(n - 7):(n - 4)]), core_crc32(charToRaw(txt)))
  expect_identical(le(enc[(n - 3):n]), as.numeric(nchar(txt, "bytes")))
  # and an external gzip reads it too, where one is available
  gz <- Sys.which("gzip")
  if (nzchar(gz)) {
    p <- tempfile(fileext = ".gz")
    writeBin(enc, p)
    out <- suppressWarnings(system2(gz, c("-dc", shQuote(p)),
                                    stdout = TRUE, stderr = FALSE))
    expect_identical(paste(out, collapse = ""), txt)
    unlink(p)
  }
  # compression actually happened
  expect_lt(length(enc), nchar(txt))
})

test_that("the Merkle tree matches a tree rebuilt with digest", {
  skip_if_no("digest")
  hexraw <- function(h) .rmbl_hex_to_raw(h)
  ref_root <- function(chunks) {
    lvl <- vapply(chunks, function(b) {
      digest::digest(b, algo = "sha256", serialize = FALSE)
    }, "")
    while (length(lvl) > 1L) {
      up <- character(0)
      i <- 1L
      while (i + 1L <= length(lvl)) {
        up <- c(up, digest::digest(c(hexraw(lvl[i]), hexraw(lvl[i + 1L])),
                                   algo = "sha256", serialize = FALSE))
        i <- i + 2L
      }
      # an unpaired node is PROMOTED, not duplicated: duplicating it
      # makes two different leaf sets collide (the CVE-2012-2459 shape)
      if (i == length(lvl)) up <- c(up, lvl[i])
      lvl <- up
    }
    lvl
  }
  # every leaf count from one to seventeen, so odd levels -- where the
  # promotion happens -- occur at several depths
  for (k in 1:17) {
    ch <- lapply(seq_len(k), function(i) rnd(10L + i, 300L + i))
    expect_identical(merkle_root(ch), ref_root(ch))
    expect_identical(merkle_leaves(ch),
                     vapply(ch, function(b) {
                       digest::digest(b, algo = "sha256", serialize = FALSE)
                     }, ""))
  }
  # promotion, demonstrated: duplicating the last leaf of a three-leaf
  # tree must NOT give the same root as the three-leaf tree
  a <- lapply(1:3, function(i) rnd(8L, i))
  expect_false(identical(merkle_root(a), merkle_root(c(a, a[3]))))
  # a proof verifies at every index, for binary chunks
  root <- merkle_root(a)
  for (i in 1:3) {
    expect_true(merkle_verify(a[[i]], merkle_proof(a, i), root))
  }
})

test_that("a file's digest is the digest of its bytes", {
  # the streaming file path and the in-memory path must not disagree, and
  # a binary file with zero bytes in it is the case that used to be
  # impossible to chunk at all
  p <- tempfile()
  on.exit(unlink(p), add = TRUE)
  bytes <- rnd(5000L, 77L)
  writeBin(bytes, p)
  expect_identical(sha256_file(p), core_sha256(bytes))
  expect_identical(sha512_file(p), core_sha512(bytes))
  expect_identical(crc32_file(p), core_crc32(bytes))
  skip_if_no("digest")
  expect_identical(sha256_file(p),
                   digest::digest(file = p, algo = "sha256"))
  expect_identical(sha512_file(p),
                   digest::digest(file = p, algo = "sha512"))
  # chunking reproduces the file exactly, and the block size changes only
  # the tree, never the bytes
  for (cb in c(1L, 7L, 512L, 5000L, 10000L)) {
    ch <- chunk_file(p, chunk_bytes = cb)
    expect_identical(unlist(ch), bytes)
    expect_identical(core_sha256(unlist(ch)), sha256_file(p))
  }
  # a file containing every byte value, including zero
  writeBin(as.raw(0:255), p)
  ch <- chunk_file(p, chunk_bytes = 64L)
  expect_length(ch, 4L)
  expect_identical(unlist(ch), as.raw(0:255))
  expect_identical(merkle_leaves(ch)[1L], core_sha256(as.raw(0:63)))
  # an empty file has no chunks
  writeBin(raw(0), p)
  expect_length(chunk_file(p), 0L)
  expect_true(is.na(merkle_root(chunk_file(p))))
})

test_that("digest_object routes to the same primitives", {
  skip_if_no("digest")
  b <- rnd(300L, 55L)
  # digest_object fingerprints an R OBJECT, so it hashes the object's
  # serialisation rather than the bytes of a raw vector -- that is the
  # difference between "these bytes" and "this value", and a list and a
  # data frame have no bytes of their own to hash
  ser <- serialize(b, NULL, version = 2L, xdr = TRUE)
  expect_identical(digest_object(b, "sha256"), core_sha256(ser))
  expect_identical(digest_object(b, "sha512"), core_sha512(ser))
  expect_identical(digest_object(b, "blake2b"), core_blake2b(ser))
  expect_identical(digest_object(b, "crc32"), core_crc32(ser))
  # the serialisation is version- and endianness-pinned, so the same
  # value gives the same digest on any machine
  expect_identical(digest_object(list(a = 1L, b = "x"), "sha256"),
                   core_sha256(serialize(list(a = 1L, b = "x"), NULL,
                                         version = 2L, xdr = TRUE)))
  # a key gives the KEYED digest rather than being accepted and ignored
  expect_identical(digest_object(b, "sha256", key = "k"),
                   core_hmac_sha256("k", ser))
  expect_false(identical(digest_object(b, "sha256", key = "k"),
                         digest_object(b, "sha256")))
  expect_identical(digest_object(b, "blake2b", key = "k"),
                   core_blake2b(ser, key = "k", length = 32L))
  expect_false(identical(digest_object(b, "blake2b", key = "k"),
                         digest_object(b, "blake2b")))
  # and an algorithm with no keyed form refuses the key instead of
  # answering an authentication request with a plain checksum
  expect_error(digest_object(b, "crc32", key = "k"), "not supported")
  expect_error(digest_object(b, "sha512", key = "k"), "not supported")
})

test_that("constant-time comparison still compares", {
  # a comparison that is safe against timing must still be correct
  a <- core_sha256("x")
  expect_true(core_digest_equal(a, a))
  expect_false(core_digest_equal(a, core_sha256("y")))
  # a length mismatch is unequal, not an error
  expect_false(core_digest_equal(a, substring(a, 1L, 10L)))
  expect_false(core_digest_equal(a, ""))
  # differing in the last character only, which a short-circuit compare
  # would get right but a length-only compare would not
  b <- paste0(substring(a, 1L, 63L), if (substring(a, 64L) == "a") "b" else "a")
  expect_false(core_digest_equal(a, b))
})
