# Provenance digests: SHA-512, CRC-32, HMAC-SHA-256, Merkle trees.
#
# Anchors outside the package: the FIPS 180-4 published SHA-512 vectors,
# the RFC 4231 HMAC-SHA-256 test cases, the ITU V.42 CRC-32 check value,
# and for the Merkle tree the construction recomputed by hand from
# csha256() over the concatenated child BYTES.

test_that("SHA-512 matches the published FIPS 180-4 vectors", {
  expect_equal(csha512("abc"), paste0(
    "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a",
    "2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"
  ))
  # the empty message exercises the pure-padding path
  expect_equal(csha512(""), paste0(
    "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce",
    "47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e"
  ))
  # 112 bytes forces a second compression block, the classic padding bug
  expect_equal(csha512(paste0(
    "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmno",
    "ijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu"
  )), paste0(
    "8e959b75dae313da8cf4f72814fc143f8f7779c6eb9f7fa17299aeadb6889018",
    "501d289e4900f7e4331b99dec4b5433ac7d329eeb6dd26545e96e55b874be909"
  ))

  expect_equal(nchar(csha512("abc")), 128L)
  # vectorised over character input
  expect_equal(
    csha512(c("abc", "")),
    c(csha512("abc"), csha512(""))
  )
  expect_length(csha512(c("a", "b", "c")), 3L)
  # raw input hashes the same bytes to the same digest
  expect_identical(csha512("abc"), csha512(charToRaw("abc")))
  # a one-bit change changes the digest completely
  expect_false(identical(csha512("abc"), csha512("abd")))
  # twice the width of SHA-256
  expect_equal(nchar(csha512("x")), 2L * nchar(csha256("x")))
  # lowercase hex only
  expect_match(csha512("abc"), "^[0-9a-f]{128}$")
})

test_that("CRC-32 matches the ITU V.42 check value", {
  # the standard check value for "123456789"
  expect_equal(ccrc32("123456789"), 0xCBF43926)
  expect_equal(ccrc32(""), 0)
  expect_equal(ccrc32("A"), 0xD3D99E8B)
  # vectorised, and sensitive to one changed byte
  expect_equal(ccrc32(c("123456789", "")), c(0xCBF43926, 0))
  expect_false(ccrc32("brick") == ccrc32("brack"))
  # raw and character agree on the same bytes
  expect_equal(ccrc32(charToRaw("123456789")), 0xCBF43926)
  # the result is an unsigned 32-bit value, returned as a double because
  # values above 2^31 - 1 are not R integers
  expect_type(ccrc32("123456789"), "double")
  expect_true(all(ccrc32(c("a", "bb", "ccc")) >= 0))
  expect_true(all(ccrc32(c("a", "bb", "ccc")) < 2^32))
})

test_that("HMAC-SHA-256 matches the RFC 4231 test cases", {
  # case 1: a 20-byte key of 0x0b
  expect_equal(
    chmac(as.raw(rep(0x0b, 20)), "Hi There"),
    "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7"
  )
  # case 2: a short ASCII key
  expect_equal(
    chmac("Jefe", "what do ya want for nothing?"),
    "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843"
  )
  # case 3: a 20-byte key of 0xaa over 50 bytes of 0xdd
  expect_equal(
    chmac(
      as.raw(rep(0xaa, 20)),
      as.raw(rep(0xdd, 50))
    ),
    "773ea91e36800e46854db8ebd09181a72959098b3ef8c122d9635514ced565fe"
  )
  # case 6: a 131-byte key, longer than the 64-byte block, so it is
  # hashed down first
  expect_equal(
    chmac(
      as.raw(rep(0xaa, 131)),
      "Test Using Larger Than Block-Size Key - Hash Key First"
    ),
    "60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54"
  )

  # the key is what makes it an authentication tag rather than a digest
  expect_false(identical(
    chmac("key-a", "m"),
    chmac("key-b", "m")
  ))
  expect_false(identical(
    chmac("k", "m1"),
    chmac("k", "m2")
  ))
  # and it is not the plain digest of key and message concatenated
  expect_false(identical(chmac("k", "m"), csha256("km")))
  expect_match(chmac("k", "m"), "^[0-9a-f]{64}$")
  # deterministic
  expect_identical(chmac("k", "m"), chmac("k", "m"))
  # an empty key and an empty message are both accepted
  expect_match(chmac("", ""), "^[0-9a-f]{64}$")

  expect_error(chmac(c("a", "b"), "m"), "length-1")
  expect_error(chmac("k", c("m", "n")), "length-1")
})

test_that("digest comparison is length-aware and constant-time", {
  tag <- chmac("k", "m")
  expect_true(cdgsteq(tag, chmac("k", "m")))
  expect_false(cdgsteq(tag, chmac("k", "tampered")))
  # a differing length is not equal, and does not error
  expect_false(cdgsteq(tag, "short"))
  expect_false(cdgsteq("", tag))
  expect_true(cdgsteq("", ""))
  # it compares the whole string, not a prefix -- a tag agreeing on all
  # but the last character must still be rejected
  almost <- paste0(
    substring(tag, 1L, 63L),
    if (substring(tag, 64L) == "a") "b" else "a"
  )
  expect_false(cdgsteq(tag, almost))
  # and one differing only in the FIRST character, which is what a
  # short-circuiting comparison would leak
  first <- paste0(
    if (substring(tag, 1L, 1L) == "a") "b" else "a",
    substring(tag, 2L)
  )
  expect_false(cdgsteq(tag, first))
  expect_error(cdgsteq(c("a", "b"), "a"), "length-1")
})

test_that("the Merkle root is the hand-computed construction", {
  # hashing the concatenated BYTES of two child digests, which is what
  # the tree does -- not the concatenated hex spelling. Scheme 2 (0.5.13 on) prefixes a node
  # with 0x01 and a leaf with 0x00 (RFC 6962); scheme 1 had neither
  pair <- function(h1, h2) {
    hex <- paste0(h1, h2)
    csha256(c(as.raw(1L), as.raw(strtoi(substring(
      hex, seq(1L, 127L, 2L),
      seq(2L, 128L, 2L)
    ), 16L))))
  }
  leaf <- function(x) csha256(c(as.raw(0L), charToRaw(x)))
  la <- leaf("a")
  lb <- leaf("b")
  lc <- leaf("c")
  ld <- leaf("d")

  # a single chunk's root is its own leaf digest
  expect_equal(mrkroot("a"), la)
  # two chunks are one compression
  expect_equal(mrkroot(c("a", "b")), pair(la, lb))
  # four chunks are a balanced tree
  expect_equal(
    mrkroot(c("a", "b", "c", "d")),
    pair(pair(la, lb), pair(lc, ld))
  )
  # three chunks PROMOTE the unpaired leaf rather than duplicating it
  expect_equal(mrkroot(c("a", "b", "c")), pair(pair(la, lb), lc))
  # which is what stops two different chunk lists sharing a root: were
  # the last leaf duplicated, c("a","b","c") and c("a","b","c","c") would
  # collide
  expect_false(identical(
    mrkroot(c("a", "b", "c")),
    mrkroot(c("a", "b", "c", "c"))
  ))
  # five chunks promote at two levels
  expect_equal(
    mrkroot(c("a", "b", "c", "d", "a")),
    pair(pair(pair(la, lb), pair(lc, ld)), la)
  )

  # the leaves are the per-chunk digests
  expect_equal(mrklvs(c("a", "b", "c")), c(la, lb, lc))
  expect_equal(mrklvs(character(0)), character(0))
  expect_true(is.na(mrkroot(character(0))))
  # order matters
  expect_false(identical(mrkroot(c("a", "b")), mrkroot(c("b", "a"))))
  # any change to any chunk changes the root
  expect_false(identical(
    mrkroot(c("a", "b", "c", "d")),
    mrkroot(c("a", "b", "c", "d "))
  ))
  expect_match(mrkroot(c("a", "b")), "^[0-9a-f]{64}$")
  expect_error(mrkroot(c("a", NA)), "must not contain NA")
})

test_that("a Merkle proof verifies exactly the chunk it was built for", {
  chunks <- c("c1", "c2", "c3", "c4", "c5", "c6", "c7", "c8")
  root <- mrkroot(chunks)
  # every chunk proves its own membership
  for (i in seq_along(chunks)) {
    pr <- mrkprf(chunks, i)
    expect_length(pr$sibling, 3L) # three levels for eight leaves
    expect_true(all(pr$side %in% c("left", "right")))
    expect_true(mrkvrf(chunks[i], pr, root))
    # and proves nothing else
    expect_false(mrkvrf("not-a-chunk", pr, root))
    expect_false(mrkvrf(chunks[i], pr, mrklvs("x")[1]))
  }
  # a proof for one index does not verify another chunk
  pr3 <- mrkprf(chunks, 3)
  expect_false(mrkvrf(chunks[4], pr3, root))
  # a tampered sibling breaks the path
  bad <- pr3
  bad$sibling[1] <- csha256("wrong")
  expect_false(mrkvrf(chunks[3], bad, root))
  # so does flipping which side a sibling sits on
  flipped <- pr3
  flipped$side <- ifelse(flipped$side == "left", "right", "left")
  expect_false(mrkvrf(chunks[3], flipped, root))

  # a single-chunk tree needs no siblings at all
  one <- mrkprf("solo", 1)
  expect_length(one$sibling, 0L)
  expect_true(mrkvrf("solo", one, mrkroot("solo")))
  # an unbalanced tree still proves every leaf
  odd <- c("x", "y", "z")
  oroot <- mrkroot(odd)
  for (i in 1:3) {
    expect_true(mrkvrf(odd[i], mrkprf(odd, i), oroot))
  }

  expect_error(mrkprf(chunks, 0), "between 1 and")
  expect_error(mrkprf(chunks, 9), "between 1 and")
  expect_error(mrkvrf("a", list(bad = 1), "x"), "mrkprf")
  expect_error(mrkvrf(c("a", "b"), one, "x"), "a single chunk")
})

test_that("chnkfile splits a file and pins it", {
  p <- tempfile()
  on.exit(unlink(p), add = TRUE)
  writeLines(rep("abcdefghij", 40), p) # 440 bytes

  ch <- chnkfile(p, chnkbytes = 100L)
  expect_equal(length(ch), 5L)
  # chunks are bytes, because a file is bytes and an R string cannot
  # hold a zero one
  expect_true(all(vapply(ch, is.raw, TRUE)))
  expect_length(ch[[1L]], 100L)
  # the chunks reconstruct the file exactly
  expect_identical(unlist(ch), readBin(p, "raw", n = 1e6))
  # one chunk covering the whole file is the whole file
  expect_equal(length(chnkfile(p, chnkbytes = 1e6)), 1L)
  expect_equal(
    mrkroot(chnkfile(p, 1e6)),
    csha256(c(as.raw(0L), chnkfile(p, 1e6)[[1L]]))  # the leaf prefix of scheme 2
  )
  # editing one chunk's worth of bytes moves exactly one leaf
  before <- mrklvs(ch)
  p2 <- tempfile()
  on.exit(unlink(p2), add = TRUE)
  txt <- rep("abcdefghij", 40)
  txt[15] <- "ABCDEFGHIJ"
  writeLines(txt, p2)
  after <- mrklvs(chnkfile(p2, chnkbytes = 100L))
  expect_equal(length(which(before != after)), 1L)

  # an empty file has no chunks
  e <- tempfile()
  on.exit(unlink(e), add = TRUE)
  file.create(e)
  expect_length(chnkfile(e), 0L)

  expect_error(chnkfile(tempfile()), "no such file")
  expect_error(chnkfile(p, chnkbytes = 0), "positive integer")
})

test_that("file digests stream to the same value at any block size", {
  p <- tempfile()
  on.exit(unlink(p), add = TRUE)
  writeLines(rep("capsule payload", 200), p)

  want512 <- csha512(rawToChar(readBin(p, "raw", n = 1e7)))
  expect_equal(sha512file(p), want512)
  # the block size is a speed knob and cannot change the digest
  expect_equal(sha512file(p, blkbytes = 7L), want512)
  expect_equal(sha512file(p, blkbytes = 1L), want512)
  expect_equal(crc32file(p), ccrc32(rawToChar(readBin(p, "raw", n = 1e7))))
  expect_equal(crc32file(p, blkbytes = 13L), crc32file(p))
  # and the existing SHA-256 file digest still agrees with the core
  expect_equal(sha256file(p), csha256(rawToChar(readBin(p, "raw",
    n = 1e7
  ))))

  e <- tempfile()
  on.exit(unlink(e), add = TRUE)
  file.create(e)
  expect_equal(sha512file(e), csha512(""))
  expect_equal(crc32file(e), 0)

  expect_error(sha512file(tempfile()), "no such file")
  expect_error(crc32file(p, blkbytes = 0), "positive integer")
})
