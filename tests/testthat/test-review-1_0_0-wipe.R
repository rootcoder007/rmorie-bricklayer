# Review of 1.0.0, M8 (secrets wiped on every path), the native argument names
# of M7 and the /dev/urandom read. A wipe cannot be seen from R: these tests
# show that the primitives whose buffers are now wiped still give their
# published answers, so the wipes run after the last read of each buffer and
# never before it.

hx <- function(r) paste(sprintf("%02x", as.integer(r)), collapse = "")

test_that(
  paste0(
    "SHA-3 and SHAKE one-shots still match ",
    "FIPS 202 with their state wiped"
  ),
  {
    sh <- function(w, x, n = 0L) {
      hx(.Call(C_rmbl_shake, as.integer(w), x, as.integer(n)))
    }
    expect_identical(
      sh(3256, ""),
      "a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a"
    )
    expect_identical(
      sh(3256, "abc"),
      "3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532"
    )
    expect_identical(
      sh(128, "", 32L),
      "7f9c2ba4e88f827d616045507605853ed73b8093f6efbc88eb1a6eacfa66ef26"
    )
    # twice in a row: nothing of the first call's state is left to the second
    expect_identical(sh(3256, "abc"), sh(3256, "abc"))
  }
)

test_that("SHA-512, HMAC and PBKDF2 still give the published vectors", {
  expect_identical(
    csha512("abc"),
    paste0(
      "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55",
      "d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94f",
      "a54ca49f"
    )
  )
  key <- as.raw(rep(0x0b, 20L))
  msg <- charToRaw("Hi There")
  expect_identical(
    hx(.Call(C_rmbl_hmac_shax, 512L, key, msg)),
    paste0(
      "87aa7cdea5ef619d4ff0b4241a1d6cb02379f4e2ce4ec2787ad0b30545e1",
      "7cdedaa833b7d6b8a702038b274eaea3f4e4be9d914eeb61f1702e696c20",
      "3a126854"
    )
  )
  # a key longer than the block (hashed first) through both HMAC entry points
  long <- as.raw(rep(0xaa, 131L))
  m6 <- charToRaw("Test Using Larger Than Block-Size Key - Hash Key First")
  want <- "60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54"
  expect_identical(hx(.Call(C_rmbl_hmac_shax, 256L, long, m6)), want)
  expect_identical(.Call(C_rmbl_hmac_sha256, long, m6), want)
  # RFC 7914 section 11 and the common PBKDF2-HMAC-SHA256 vector
  expect_identical(
    .Call(C_rmbl_pbkdf2, "password", "salt", 1L, 32L),
    "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b"
  )
  expect_identical(
    .Call(C_rmbl_pbkdf2, "passwd", "salt", 1L, 64L),
    paste0(
      "55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc",
      "49ca9cccf179b645991664b39d77ef317c71b845b1e30bd509112041d3a19783"
    )
  )
})

test_that(
  paste0(
    "a keyed BLAKE2b gives the same tag for a raw and a character key, call ",
    "after call"
  ),
  {
    a <- .Call(C_rmbl_blake2b, "message", charToRaw("k3y"), 32L)
    expect_identical(.Call(C_rmbl_blake2b, "message", "k3y", 32L), a)
    expect_identical(.Call(C_rmbl_blake2b, "message", charToRaw("k3y"), 32L), a)
    expect_false(identical(.Call(C_rmbl_blake2b, "message", NULL, 32L), a))
  }
)

test_that(
  paste0(
    "XMSS signs and verifies with its seeds wiped, and the refused seed is ",
    "still named"
  ),
  {
    h <- function(b) strrep(sprintf("%02x", b), 32L)
    sks <- h(1L)
    prf <- h(2L)
    pub <- h(3L)
    root <- .Call(C_rmbl_xmss_keygen, sks, pub, 2L)
    for (i in 0:1) {
      s <- .Call(C_rmbl_xmss_sign, sks, prf, pub, 2L, i, "a message")
      expect_identical(s$root, root)
      expect_true(.Call(
        C_rmbl_xmss_verify,
        pub,
        root,
        2L,
        i,
        "a message",
        s$wots,
        s$auth,
        s$randomizer
      ))
      expect_false(.Call(
        C_rmbl_xmss_verify,
        pub,
        root,
        2L,
        i,
        "another",
        s$wots,
        s$auth,
        s$randomizer
      ))
    }
    # the same signature twice: the wiped buffers were not read after the wipe
    expect_identical(
      .Call(C_rmbl_xmss_sign, sks, prf, pub, 2L, 1L, "m")$wire,
      .Call(C_rmbl_xmss_sign, sks, prf, pub, 2L, 1L, "m")$wire
    )
    expect_error(.Call(C_rmbl_xmss_sign, "zz", prf, pub, 2L, 0L, "m"), "skseed")
    expect_error(.Call(C_rmbl_xmss_sign, sks, "zz", pub, 2L, 0L, "m"), "skprf")
  }
)

test_that(
  paste0(
    "ML-DSA unmasked signing still verifies and matches the masked signer ",
    "byte for byte"
  ),
  {
    kp <- .Call(C_rmbl_mldsa_keypair, 44L, as.raw(1:32))
    msg <- charToRaw("wiped")
    rnd <- as.raw(rep(7L, 32L))
    plain <- .Call(
      C_rmbl_mldsa_sign,
      44L,
      kp[[2]],
      msg,
      raw(0),
      rnd,
      "none",
      FALSE
    )
    masked <- .Call(
      C_rmbl_mldsa_sign,
      44L,
      kp[[2]],
      msg,
      raw(0),
      rnd,
      "none",
      TRUE
    )
    expect_identical(plain, masked)
    expect_true(.Call(
      C_rmbl_mldsa_verify,
      44L,
      kp[[1]],
      msg,
      raw(0),
      plain,
      "none"
    ))
    expect_identical(
      .Call(C_rmbl_mldsa_sign, 44L, kp[[2]], msg, raw(0), rnd, "none", FALSE),
      plain
    )
  }
)

test_that("the native argument errors name the R arguments", {
  # DRBG: the person and addl arguments of drbgnew, drbgrsd and drbggen
  expect_error(
    .Call(C_rmbl_drbg_instantiate, as.raw(1:48), raw(49)),
    "`person`"
  )
  expect_error(
    .Call(C_rmbl_drbg_reseed, raw(32), raw(16), as.raw(1:48), raw(49)),
    "`addl`"
  )
  expect_error(
    .Call(C_rmbl_drbg_generate, raw(32), raw(16), 16L, raw(49)),
    "`addl`"
  )
  # PBKDF2: the pass argument of drvkey
  expect_error(.Call(C_rmbl_pbkdf2, NA_character_, "salt", 1L, 32L), "`pass`")
  # SLH-DSA: the per-signature randomness is `rnd`
  set <- "SLH-DSA-SHAKE-128f"
  kp <- .Call(C_rmbl_slhdsa_keypair, set, as.raw(1:48))
  expect_error(
    .Call(C_rmbl_slhdsa_sign_internal, set, kp[[2]], charToRaw("m"), raw(3)),
    "`rnd` must be a raw vector of 16 bytes"
  )
  expect_error(
    .Call(
      C_rmbl_slhdsa_sign,
      set,
      kp[[2]],
      charToRaw("m"),
      raw(0),
      raw(3),
      "none"
    ),
    "`rnd`"
  )
})

test_that(
  paste0(
    "the operating system's random bytes arrive whole and leave no ",
    "descriptor open"
  ),
  {
    a <- .Call(C_rmbl_os_random, 64L)
    b <- .Call(C_rmbl_os_random, 64L)
    expect_length(a, 64L)
    expect_false(identical(a, b))
    # on Linux the read goes through getrandom(2) when the kernel has it, else
    # through /dev/urandom opened close-on-exec; either way no descriptor to it
    # outlives the call
    skip_if_not(dir.exists("/proc/self/fd"), "no /proc/self/fd")
    urandom_fds <- function() {
      l <- suppressWarnings(Sys.readlink(list.files(
        "/proc/self/fd",
        full.names = TRUE
      )))
      sum(l == "/dev/urandom")
    }
    before <- urandom_fds()
    for (i in 1:5) {
      .Call(C_rmbl_os_random, 4096L)
    }
    expect_identical(urandom_fds(), before)
  }
)
