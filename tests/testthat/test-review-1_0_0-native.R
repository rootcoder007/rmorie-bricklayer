# battery: runs in CI and locally; CRAN runs the correctness core
testthat::skip_on_cran()
# The native-code review of 1.0.0: one test per finding, each failing on the
# code the review read.

hexraw <- function(h) {
  at <- seq(1L, nchar(h), 2L)
  as.raw(strtoi(substring(h, at, at + 1L), 16L))
}

# a child R that answers `times` requests on `port` with `status` and `body`, as
# in test-cran-stress-b617a3f.R
serve_bg <- function(port, status, body, times = 1L) {
  ready <- tempfile("listening-")
  code <- sprintf(
    paste0(
      "srv <- serverSocket(%dL); on.exit(close(srv)); writeLines('ok', '%s');",
      "for (i in seq_len(%dL)) {",
      "con <- socketAccept(srv, blocking = TRUE, open = 'r+b', timeout = 30);",
      "repeat { l <- readLines(con, n = 1L, warn = FALSE);",
      "if (!length(l) || !nzchar(sub('\\\\r$', '', l))) break };",
      "b <- %s;",
      "head <- paste0('HTTP/1.1 ', %s, '\\r\\nContent-Type: ",
      "application/json\\r\\n',",
      "               'Content-Length: ', nchar(b, 'bytes'), ",
      "'\\r\\nConnection: close\\r\\n');",
      "writeLines(head, con, sep = '\\r\\n');",
      "writeChar(b, con, eos = NULL); flush(con); close(con) }"
    ),
    port,
    ready,
    times,
    deparse(body),
    deparse(status)
  )
  rscript_bg(code)
  wait_files(ready, 30)
}
free_port <- function() 20000L + sample.int(20000L, 1L)

# ---- H1: ECDSA length checks -------------------------------------------------

test_that(
  paste0(
    "H1: an ECDSA r, s or key coordinate longer than the curve is not a ",
    "signature"
  ),
  {
    # RFC 6979 A.2.5, P-256, SHA-256, message "sample"
    qx <- hexraw(
      "60fed4ba255a9d31c961eb74c6356d68c049b8923b61fa6ce669622e60f29fb6"
    )
    qy <- hexraw(
      "7903fe1008b8bc99a41ae9e95628bc64f2f1b20c2d7e9f5177a3c294d4462299"
    )
    r <- hexraw(
      "efd48b2aacb6a8fd1140dd9cd45e81d69d2c877b56aaf991c34d0ea84eaf3716"
    )
    s <- hexraw(
      "f7cb1c942d657c41d436c7a1b6e29f65f3e900dbb9aff4064dc4ab2f843acda8"
    )
    dig <- .rmbl_ts_digest("sha256", charToRaw("sample"))
    v <- function(qx, qy, r, s) {
      .Call(C_rmbl_ecdsa_verify, "P-256", qx, qy, r, s, dig)
    }
    expect_true(v(qx, qy, r, s))
    # r' = 2^1152 + r was cut back to r and verified (TRUE before the fix)
    expect_false(v(qx, qy, c(as.raw(1), raw(112), r), s))
    expect_false(v(qx, qy, r, c(as.raw(1), raw(112), s)))
    # a zero-padded key coordinate is not the field element either
    expect_false(v(c(as.raw(0), qx), qy, r, s))
    expect_false(v(qx, qy[-1], r, s))
  }
)

test_that(
  paste0(
    "H1: the scalar of ec_mul is at most 144 ",
    "bytes, and a long one is refused"
  ),
  {
    # c(1, 144 zero bytes) was read as 0 and gave the point at infinity (TRUE
    # before the fix)
    expect_error(
      .Call(C_rmbl_ec_mul, "P-256", c(as.raw(1), raw(144))),
      "at most 144 bytes"
    )
    expect_identical(
      .Call(C_rmbl_ec_mul, "P-256", c(raw(143), as.raw(2)))$x,
      .Call(C_rmbl_ec_mul, "P-256", as.raw(2))$x
    )
  }
)

# ---- H2: the pin, the URL and the socket guard -------------------------------

test_that("H2: the URL libcurl is handed and the host the pin names agree", {
  p <- .Call(
    C_rmbl_net_probe,
    "https://example.com./a?b=c.",
    "8.8.8.8",
    FALSE,
    NA
  )
  # before the fix the check stripped the dot from its own copy only: the pin
  # said example.com and libcurl was asked for example.com.
  expect_identical(p$url, "https://example.com/a?b=c.")
  expect_identical(p$host, "example.com")
  pr <- function(u) .Call(C_rmbl_net_probe, u, "8.8.8.8", FALSE, NA)$url
  expect_identical(
    pr("https://Example.COM.:8443/x"),
    "https://Example.COM:8443/x"
  )
  expect_identical(pr("https://[2001:db8::1]/"), "https://[2001:db8::1]/")
  expect_identical(
    .Call(C_rmbl_url_check, "https://example.com./", FALSE, FALSE, FALSE),
    ""
  )
  expect_match(
    .Call(C_rmbl_url_check, "https://example.com../", FALSE, FALSE, FALSE),
    "malformed"
  )
  expect_match(
    .Call(C_rmbl_url_check, "https://localhost./", FALSE, FALSE, FALSE),
    "local"
  )
})

test_that(
  paste0(
    "H2: a socket to a private or loopback ",
    "address is refused at connect time"
  ),
  {
    conn <- function(a, local = FALSE) {
      .Call(C_rmbl_net_probe, "https://example.com/", a, local, NA)$connect
    }
    for (a in c(
      "127.0.0.1",
      "10.1.2.3",
      "169.254.169.254",
      "192.168.0.1",
      "100.64.0.1",
      "0.0.0.0",
      "::1",
      "::ffff:127.0.0.1",
      "fe80::1",
      "fd00::1"
    )) {
      expect_false(conn(a), info = a)
    }
    expect_true(conn("8.8.8.8"))
    # NA where the host has no IPv6 sockets (a kernel booted with
    # ipv6.disable=1): the probe cannot say, and said "refused" before (R CMD
    # check failed there; final audit of 1.0.0, #1)
    v6 <- conn("2001:4860:4860::8888")
    if (is.na(v6)) {
      skip("this host has no IPv6 sockets")
    }
    expect_true(v6)
    # a hop the policy admitted to a local host (allow_loopback) may connect
    # there
    expect_true(conn("127.0.0.1", TRUE))
    expect_identical(conn("not-an-address"), NA)
  }
)

test_that(
  paste0(
    "H2: a proxy on the loopback interface ",
    "is refused, not connected to"
  ),
  {
    skip_on_cran()
    port <- free_port()
    # listens, never answers
    srv <- tryCatch(serverSocket(port), error = function(e) NULL)
    skip_if(is.null(srv), "no local port")
    on.exit(close(srv), add = TRUE)
    prx <- sprintf("http://127.0.0.1:%d", port)
    withr::local_envvar(
      https_proxy = prx,
      HTTPS_PROXY = prx,
      no_proxy = "",
      NO_PROXY = ""
    )
    # a public literal needs no DNS: the only socket libcurl opens is the
    # proxy's, and the guard refuses it at once (before the fix the request sat
    # at the silent proxy for its timeout)
    t0 <- Sys.time()
    r <- .Call(C_rmbl_http_get, "https://8.8.8.8/", 5L, NULL, FALSE)
    expect_identical(r$status, -1L)
    expect_lt(as.numeric(difftime(Sys.time(), t0, units = "secs")), 4)
  }
)

test_that("H2: a trailing-dot host is fetched through the pin (live)", {
  skip_if_not(
    identical(Sys.getenv("RMBL_LIVE_TESTS"), "1"),
    "live: RMBL_LIVE_TESTS=1"
  )
  r <- .Call(C_rmbl_http_get, "https://cloud.r-project.org./", 30L, NULL, FALSE)
  expect_identical(r$status, 200L)
})

# ---- H3: strtod --------------------------------------------------------------

test_that("H3: digits past the 768 kept still decide a halfway case", {
  # one plus two to the power -53, halfway between 1 and the next double
  half <- "1.00000000000000011102230246251565404236316680908203125"
  st <- function(s) .Call(C_rmbl_strtod, s)
  # the review's string: 1 before the fix
  expect_identical(st(paste0(half, strrep("0", 800), "1")), 1.0000000000000002)
  expect_identical(st(paste0(half, strrep("0", 800), "1")), 1 + 2^-52)
  expect_identical(st(paste0(half, strrep("0", 800))), 1) # a tie: to even
  # just below
  expect_identical(st(paste0(sub("5$", "4", half), strrep("9", 900))), 1)
  # 1 + 3 * 2^-53 lies halfway between 1 + 2^-52 (odd) and 1 + 2^-51 (even)
  half3 <- "1.00000000000000033306690738754696212708950042724609375"
  expect_identical(st(half3), 1 + 2^-51)
  expect_identical(st(paste0(half3, strrep("0", 800), "1")), 1 + 2^-51)
  expect_identical(
    st(paste0(sub("5$", "4", half3), strrep("9", 800))),
    1 + 2^-52
  )
  # the integer part: 2^53 + 1 is halfway between 2^53 and 2^53 + 2
  expect_identical(
    st(paste0("9007199254740993", strrep("0", 800), "e-800")),
    2^53
  )
  expect_identical(
    st(paste0("9007199254740993", strrep("0", 800), "1e-801")),
    2^53 + 2
  )
  expect_identical(st(paste0("-", half, strrep("0", 800), "1")), -(1 + 2^-52))
})

test_that(
  paste0(
    "H3, LOW: the specials take nothing after them, as as.numeric() reads ",
    "them"
  ),
  {
    x <- c(
      "Info",
      "nanny",
      "Infx",
      "NaN1",
      "INF",
      "Infinity",
      "infinity",
      "-inf",
      "+nan",
      " NaN ",
      "Inf"
    )
    # "Info" and "nanny" read as Inf and NaN before the fix
    expect_identical(.Call(C_rmbl_strtod, x), suppressWarnings(as.numeric(x)))
  }
)

# ---- H4: the regularized incomplete gamma for large shapes -------------------

test_that("H4: cgamcdf() is accurate for large shapes", {
  # at x = a it gave 0.4786, 0.2375 and 0.0797 before the fix
  for (a in c(1e4, 1e5, 1e6)) {
    for (x in c(a - 3 * sqrt(a), a, a + 3 * sqrt(a))) {
      expect_equal(
        cgamcdf(a, x),
        stats::pgamma(x, a),
        tolerance = 1e-10,
        info = sprintf("a = %g, x = %g", a, x)
      )
    }
  }
  x <- c(0.1, 1, 3.5, 20)
  expect_equal(cgamcdf(2.5, x), stats::pgamma(x, 2.5), tolerance = 1e-12)
})

# ---- M1: timeouts ------------------------------------------------------------

test_that(
  paste0(
    "M1: a missing, zero or negative timeout ",
    "is the default, never no limit"
  ),
  {
    tmo <- function(x) {
      .Call(
        C_rmbl_net_probe,
        "https://example.com/",
        "8.8.8.8",
        FALSE,
        x
      )$timeout
    }
    for (x in list(
      NA,
      NA_integer_,
      NA_real_,
      0L,
      0,
      -1L,
      -1,
      NaN,
      Inf,
      1e300,
      "5",
      NULL,
      c(5, 6)
    )) {
      expect_identical(tmo(x), 30, info = deparse(x))
    }
    expect_identical(tmo(5L), 5)
    expect_identical(tmo(7.9), 7)
  }
)

test_that(
  paste0(
    "M1: each transport stops at its timeout against a server that never ",
    "answers"
  ),
  {
    skip_on_cran()
    port <- free_port()
    srv <- tryCatch(serverSocket(port), error = function(e) NULL)
    skip_if(is.null(srv), "no local port")
    on.exit(close(srv), add = TRUE)
    url <- sprintf("http://127.0.0.1:%d/x", port)
    up <- tempfile()
    writeBin(as.raw(1:3), up)
    took <- function(expr) {
      t0 <- Sys.time()
      force(expr)
      as.numeric(difftime(Sys.time(), t0, units = "secs"))
    }
    expect_lt(took(.Call(C_rmbl_http_get, url, 1L, NULL, TRUE)), 4)
    expect_lt(
      took(.Call(
        C_rmbl_http_post,
        url,
        as.raw(1:3),
        "text/plain",
        1L,
        NULL,
        TRUE
      )),
      4
    )
    expect_lt(
      took(.Call(C_rmbl_http_put, url, up, "text/plain", 1L, NULL, TRUE)),
      4
    )
    expect_lt(
      took(.Call(
        C_rmbl_http_download,
        url,
        tempfile(),
        1L,
        NULL,
        NULL,
        NULL,
        TRUE
      )),
      4
    )
  }
)

# ---- M2, M3: destinations ----------------------------------------------------

test_that(
  paste0(
    "M2: a destination that cannot be written is a local failure, with no ",
    "Wayback lookup"
  ),
  {
    d <- tempfile("ro-")
    dir.create(d)
    on.exit(unlink(d, recursive = TRUE, force = TRUE), add = TRUE)
    t0 <- Sys.time()
    # a missing directory: refused before any request (it went on to the Wayback
    # Machine before)
    ff <- function(dest) {
      .Call(C_rmbl_fetch_fallback, "https://example.com/x", "", dest, 5L, "")
    }
    expect_identical(ff(file.path(d, "no", "x")), -2L)
    Sys.chmod(d, "0555")
    if (file.access(d, 2L) != 0L) {
      expect_identical(ff(file.path(d, "x")), -2L)
    }
    expect_lt(as.numeric(difftime(Sys.time(), t0, units = "secs")), 2)
    Sys.chmod(d, "0755")
  }
)

test_that("M2: a destination under ~ is expanded as R expands it", {
  skip_on_cran() # writes one file in the home directory, removed at once
  skip_on_os("windows")
  withr::local_envvar(HOME = tempdir())
  port <- free_port()
  skip_if_not(serve_bg(port, "200 OK", "hello", times = 2L), "no local server")
  base <- sprintf("http://127.0.0.1:%d", port)
  dest <- paste0("~/rmbl-m2-", Sys.getpid(), ".txt")
  full <- path.expand(dest)
  on.exit(unlink(full), add = TRUE)
  # "could not reach ...; the Wayback fallback failed" before the fix
  expect_identical(
    .Call(C_rmbl_fetch_fallback, paste0(base, "/x"), "", dest, 10L, base),
    0L
  )
  expect_identical(readLines(full, warn = FALSE), "hello")
  unlink(full)
  r <- .Call(
    C_rmbl_http_download,
    paste0(base, "/y"),
    dest,
    10L,
    NULL,
    NULL,
    NULL,
    TRUE
  )
  expect_identical(r$status, 200L)
  expect_true(file.exists(full))
})

test_that(
  paste0(
    "M3: a download that cannot be moved ",
    "into place leaves what was there"
  ),
  {
    skip_on_cran()
    skip_on_os("windows")
    port <- free_port()
    skip_if_not(serve_bg(port, "200 OK", "new", times = 1L), "no local server")
    # an empty directory where the file would go: rename() cannot replace it;
    # before the fix remove() took the directory away first and the download
    # replaced it
    d <- tempfile("dest-")
    dir.create(d)
    on.exit(unlink(d, recursive = TRUE), add = TRUE)
    url <- sprintf("http://127.0.0.1:%d/x", port)
    r <- .Call(C_rmbl_http_download, url, d, 10L, NULL, NULL, NULL, TRUE)
    expect_identical(r$status, -1L)
    expect_match(r$error, "cannot move the download into place")
    expect_true(dir.exists(d))
    expect_length(
      list.files(
        dirname(d),
        pattern = paste0("^", basename(d), "[.]rmbl-part")
      ),
      0L
    )
  }
)

test_that(
  paste0(
    "M4: the progress callback's arguments ",
    "survive a collection between them"
  ),
  {
    skip_on_cran()
    port <- free_port()
    skip_if_not(
      serve_bg(port, "200 OK", strrep("x", 5000), times = 1L),
      "no local server"
    )
    seen <- list()
    cb <- function(now, total) seen[[length(seen) + 1L]] <<- c(now, total)
    # a collection every fifth allocation: gctorture(TRUE) collects on every
    # one, which made the transfer take 29 s on a plain build and time out under
    # the sanitizers; five still puts a collection between the two arguments
    # many times over
    gctorture2(5L)
    on.exit(gctorture2(0L), add = TRUE)
    url <- sprintf("http://127.0.0.1:%d/x", port)
    r <- .Call(C_rmbl_http_download, url, tempfile(), 60L, NULL, cb, NULL, TRUE)
    gctorture2(0L)
    expect_identical(r$status, 200L)
    expect_gt(length(seen), 0L)
    ok <- vapply(
      seen,
      function(v) is.double(v) && length(v) == 2L && all(v >= 0),
      logical(1)
    )
    expect_true(all(ok))
  }
)

# ---- M5, M6: signatures that are not ones ------------------------------------

test_that("M5: an RSA signature is exactly the modulus length", {
  n <- as.raw(0x0b) # 11, e = 3: 2^3 mod 11 = 8
  expect_identical(
    .Call(C_rmbl_rsa_recover, as.raw(2), n, as.raw(3)),
    as.raw(8)
  )
  # 00 00 02 is the same number: it recovered 08 as well before the fix
  expect_error(
    .Call(C_rmbl_rsa_recover, as.raw(c(0, 0, 2)), n, as.raw(3)),
    "not the modulus length"
  )
  n2 <- as.raw(c(0xc0, rep(0xff, 127)))
  expect_error(
    .Call(C_rmbl_rsa_recover, as.raw(rep(0x42, 127)), n2, as.raw(3)),
    "127 bytes"
  )
  expect_length(
    .Call(C_rmbl_rsa_recover, as.raw(rep(0x42, 128)), n2, as.raw(3)),
    128L
  )
})

test_that(
  paste0(
    "M6: an XMSS signature with a randomizer ",
    "that is not hex does not verify"
  ),
  {
    h <- function(n) strrep("00", n)
    # an error, "`randomizer` must be 64 hex characters", before the fix
    expect_false(.Call(
      C_rmbl_xmss_verify,
      h(32),
      h(32),
      2L,
      0L,
      charToRaw("m"),
      h(67 * 32),
      h(2 * 32),
      strrep("z", 64)
    ))
    key <- pqckg(height = 2L)
    s <- cpssign("m", key)
    expect_true(cpsvrf("m", s, signpubkey(key)))
    bad <- unclass(s)
    bad$randomizer <- strrep("z", 64)
    bad$wire <- paste0(
      sprintf("%08x", as.integer(bad$index)),
      bad$randomizer,
      bad$signature,
      bad$auth
    )
    class(bad) <- class(s)
    expect_false(cpsvrf("m", bad, signpubkey(key)))
  }
)

# ---- M7: names ---------------------------------------------------------------

test_that(
  paste0(
    "M7: XMSS keys carry the documented field names, and an older key still ",
    "reads"
  ),
  {
    k <- pqckg(height = 2L)
    expect_true(all(
      c("pubseed", "skseed", "skprf", "next_index") %in% names(k)
    ))
    expect_false(any(c("pub_seed", "sk_seed", "sk_prf") %in% names(k)))
    expect_named(signpubkey(k), c("root", "pubseed", "height", "scheme"))
    expect_error(pqckg(1L, skseed = identity), "`skseed`")
    # a key saved by a build of 1.0.0 before the rename signs and verifies
    old <- unclass(pqckg(
      2L,
      skseed = strrep("ab", 32),
      pubseed = strrep("cd", 32),
      skprf = strrep("ef", 32)
    ))
    at <- match(c("pubseed", "skseed", "skprf"), names(old))
    names(old)[at] <- c("pub_seed", "sk_seed", "sk_prf")
    class(old) <- c("bricklayer_signing_key", "list")
    xmssregkey(old)
    s <- cpssign("m", old)
    expect_true(cpsvrf("m", s, signpubkey(old)))
    expect_identical(signpubkey(old)$pubseed, strrep("cd", 32))
  }
)

test_that("M7: output names and messages use the short names", {
  expect_named(
    kemsz(768),
    c("public", "secret", "ciphertext", "seed", "shared")
  )
  expect_named(
    hqcsz(1),
    c("public", "secret", "ciphertext", "seed", "message", "salt", "shared")
  )
  expect_true("count" %in% names(siusch()))
  expect_true("rnd" %in% names(fipssz("ML-DSA-44")))
  expect_equal(nchar(kemkg(512)$public) / 2, kemsz(512)[["public"]])
  expect_error(
    chwkfit(c(1, 5, 20), 10),
    "within \\[0, hor\\].*chwkjit\\(times, hor = \\)"
  )
  expect_error(chwkfit(c(1, 5), -1), "`hor` must be")
})

# ---- M12: the exported kernels and their .Call entries -----------------------

test_that("M12: Moran's I checks its arguments before it allocates", {
  x <- c(1, 2, 3)
  idx <- c(1L, 0L, 2L, 1L)
  st <- c(0L, 1L, 3L)
  ln <- c(1L, 2L, 1L)
  w <- rep(1, 4)
  expect_error(
    .Call(C_rmbl_morans_i, x, idx, st, ln, w, NA_integer_, NULL),
    "`nperm` must be"
  )
  expect_error(
    .Call(C_rmbl_morans_i, x, idx, st, ln, w, -5L, NULL),
    "`nperm` must be"
  )
  expect_error(
    .Call(C_rmbl_morans_i, x, c(1L, 0L, 7L, 1L), st, ln, w, 0L, NULL),
    "neighbour index outside"
  )
  expect_error(
    .Call(C_rmbl_morans_i, x, idx, c(0L, 1L, 9L), ln, w, 0L, NULL),
    "outside `idx`"
  )
  expect_error(
    .Call(C_rmbl_morans_i, x, idx, st, ln, w[-1], 0L, NULL),
    "one per neighbour"
  )
  expect_named(
    .Call(C_rmbl_morans_i, x, idx, st, ln, w, 99L, NULL),
    c("I", "cross", "W", "null")
  )
})

test_that("M12, LOW: midranks of a vector with NaN are defined", {
  expect_identical(.Call(C_rmbl_midranks, c(3, NaN, 1, 3)), c(2.5, NaN, 1, 2.5))
  expect_identical(.Call(C_rmbl_midranks, c(NaN, NaN)), c(NaN, NaN))
})

# ---- LOW ---------------------------------------------------------------------

test_that("LOW: the Hawkes entries refuse an eps or a window that is not one", {
  t <- c(1, 2, 4, 7)
  g <- function(eps, R = 10, d = 0.01) {
    .Call(
      C_rmbl_hawkes_nll_grad,
      t,
      10,
      0L,
      0,
      0.5,
      0L,
      1,
      0L,
      eps,
      R,
      d,
      FALSE
    )
  }
  expect_true(is.finite(g(1e-9)[[1]]))
  expect_error(g(NaN), "`eps` must be") # dropped the excitation term before
  expect_error(g(0), "`eps` must be") # an infinite truncation window before
  expect_error(g(1e-9, R = 0), "`soeR` must be")
  expect_error(g(1e-9, d = 2), "`soeDelta` must be")
  expect_error(
    .Call(
      C_rmbl_hawkes_fit_pbfgs,
      t,
      10,
      0L,
      0L,
      0L,
      NaN,
      10,
      0.01,
      c(-5, 0, 0.01),
      c(5, 0.99, 10),
      c(0, 0.5, 1),
      100L,
      1e-6
    ),
    "`eps` must be"
  )
})

test_that("LOW: the SHA-256 chunk state has no uninitialised bytes", {
  a <- .Call(C_rmbl_sha256_chunk, NULL, charToRaw("abc"), FALSE)
  expect_length(a, 112L)
  expect_identical(a[69:72], raw(4)) # the padding after `datalen`
  expect_identical(.Call(C_rmbl_sha256_chunk, a, NULL, TRUE), csha256("abc"))
})

test_that("LOW: the Wayback snapshot URL is read whole and unescaped", {
  skip_on_cran()
  skip_on_os("windows")
  port <- free_port()
  long <- paste0("https://example.org/", strrep("a", 3000))
  esc <- gsub("/", "\\\\/", paste0("http://web.archive.org/web/2024/", long))
  body <- paste0(
    '{"archived_snapshots":{"closest":{"available": true,"url":"',
    esc,
    '"}}}'
  )
  skip_if_not(serve_bg(port, "200 OK", body, times = 1L), "no local server")
  # cut at 2047 bytes, and with "\/" left in, before the fix
  api <- sprintf("http://127.0.0.1:%d", port)
  expect_identical(
    .Call(C_rmbl_wayback, "https://example.org/", 10L, api),
    paste0("https://web.archive.org/web/2024/", long)
  )
})

test_that("LOW: a wait for a held lock ends at a Ctrl-C or a time limit", {
  skip_on_os("windows")
  f <- tempfile("lock-")
  fd <- .Call(C_rmbl_flock_acquire, f, 0L)
  expect_gt(fd, 2L)
  on.exit(.Call(C_rmbl_flock_release, fd), add = TRUE)
  t0 <- Sys.time()
  setTimeLimit(elapsed = 1, transient = TRUE)
  r <- tryCatch(
    .Call(C_rmbl_flock_acquire, f, 20000L),
    error = function(e) conditionMessage(e),
    interrupt = function(e) "interrupt"
  )
  setTimeLimit(elapsed = Inf)
  # the wait ran its 20 s through the limit before the fix
  expect_match(r, "elapsed time limit|interrupt")
  expect_lt(as.numeric(difftime(Sys.time(), t0, units = "secs")), 6)
})
