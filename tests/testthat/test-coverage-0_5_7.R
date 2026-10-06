# Branches the 0.5.7 review left untested: the revocation client end to
# end against recorded OCSP answers, the error paths of the C entry points,
# and the small R guards. Every expectation is an exact value or message.

C <- function(nm) get(nm, envir = asNamespace("rmoriebricklayer"))
msg <- function(expr) {
  tryCatch({
    expr
    NULL
  }, error = function(e) conditionMessage(e))
}

# ---------------------------------------------------------------- #
# revocation: RFC 6960 OCSP and RFC 5280 CRLs, offline
# ---------------------------------------------------------------- #

test_that("the CRL and OCSP URLs come out of the extensions, http only", {
  f <- x509_fx()
  leaf <- cert_parse(f$ocsp_good)
  ca <- cert_parse(f$ocsp_ca)
  # the ldap distribution point is dropped: a verifier that followed it
  # would be following instructions from the thing it is checking
  expect_identical(.rmbl_crl_urls(leaf), "http://crl.example.org/ca.crl")
  expect_identical(.rmbl_ocsp_urls(leaf), "http://ocsp.example.org/")
  expect_length(.rmbl_crl_urls(ca), 0L)
  expect_identical(.rmbl_ext_urls(list(der = as.raw(0xff)), "2.5.29.31", NULL), character(0))
  # the request is byte for byte what OpenSSL builds for the same pair
  expect_identical(.rmbl_ocsp_request(leaf, ca), f$ocsp_req_good)
  expect_identical(.rmbl_url_encode("a b/+~"), "a%20b%2F%2B~")
  expect_null(.rmbl_node_bytes(NULL, as.raw(1)))
  expect_null(.rmbl_node_bytes(list(start = 5L, offset = 6L, length = 10L), as.raw(1:4)))
})

test_that("the fetcher takes DER, unwraps PEM, and returns NULL for anything else", {
  f <- x509_fx()
  der <- f$ocsp_crl_der
  pem <- f$ocsp_crl_pem
  expect_identical(rawToChar(pem[1:10]), "-----BEGIN")
  testthat::local_mocked_bindings(.rmbl_net_get_file = function(url, fallback, tmp, timeout) {
    writeBin(if (grepl("pem$", url)) pem else der, tmp)
    200L
  })
  expect_identical(.rmbl_http_der("http://crl.example.org/ca.crl"), der)
  expect_identical(.rmbl_http_der("http://crl.example.org/ca.pem"), der)
  # not a public http(s) URL: never fetched
  expect_null(.rmbl_http_der("ldap://x.example.org/cn=crl"))
  expect_null(.rmbl_http_der("http://127.0.0.1/ca.crl"))
  testthat::local_mocked_bindings(.rmbl_net_get_file = function(url, fallback, tmp, timeout) NULL)
  expect_null(.rmbl_http_der("http://crl.example.org/ca.crl"))
  testthat::local_mocked_bindings(.rmbl_net_get_file = function(url, fallback, tmp, timeout) {
    writeBin(raw(0), tmp)
    200L
  })
  expect_null(.rmbl_http_der("http://crl.example.org/ca.crl"))
})

test_that("OCSP answers parse, verify under the path, and every refusal is named", {
  f <- x509_fx()
  leaf <- cert_parse(f$ocsp_good)
  ca <- cert_parse(f$ocsp_ca)
  path <- list(leaf, ca)

  good <- .rmbl_ocsp_parse(f$ocsp_resp_good, leaf, path)
  expect_true(good$ok)
  expect_identical(good$detail, "the responder says good, signed")

  rv <- .rmbl_ocsp_parse(f$ocsp_resp_revoked, cert_parse(f$ocsp_revoked), path)
  expect_false(rv$ok)
  expect_identical(rv$detail, "the responder says revoked, signed")

  un <- .rmbl_ocsp_parse(f$ocsp_resp_unknown, cert_parse(f$ocsp_unknown), path)
  expect_false(un$ok)
  expect_identical(un$detail, "the responder says unknown, signed")

  # SHA-384, no certificate carried: the CA in the path signs it
  nc <- .rmbl_ocsp_parse(f$ocsp_resp_good_nocerts, leaf, path)
  expect_true(nc$ok)
  # the same answer with the CA missing from the path has nobody to vouch
  nope <- .rmbl_ocsp_parse(f$ocsp_resp_good_nocerts, leaf, list(leaf))
  expect_false(nope$ok)
  expect_identical(nope$detail, paste0("the responder said 'good' but its signature ",
                                       "does not verify under any certificate in the path"))
  # a delegated responder: its certificate travels in the answer and the
  # CA in the path issued it
  dl <- .rmbl_ocsp_parse(f$ocsp_resp_good_delegated, leaf, path)
  expect_true(dl$ok)
  # ECDSA P-256 responder
  ec <- .rmbl_ocsp_parse(f$ocsp_resp_ec_good, cert_parse(f$ocsp_ecleaf),
                         list(cert_parse(f$ocsp_ecleaf), cert_parse(f$ocsp_ecca)))
  expect_true(ec$ok)

  # the status word alone decides whether there is an answer
  expect_identical(.rmbl_ocsp_parse(as.raw(c(0x30, 0x03, 0x0a, 0x01, 0x03)), leaf, path)$detail,
                   "the responder answered 'tryLater'")
  expect_identical(.rmbl_ocsp_parse(as.raw(c(0x30, 0x03, 0x0a, 0x01, 0x07)), leaf, path)$detail,
                   "the responder answered '7'")
  expect_identical(.rmbl_ocsp_parse(as.raw(0xff), leaf, path)$detail, "the OCSP answer is not DER")
  expect_identical(.rmbl_ocsp_parse(as.raw(c(0x30, 0x03, 0x0a, 0x01, 0x00)), leaf, path)$detail,
                   "the answer carries no response bytes")
  # response bytes that hold something other than a BasicOCSPResponse
  inner <- as.raw(c(0x30, 0x08, 0x02, 0x01, 0x01, 0x02, 0x01, 0x01, 0x05, 0x00))
  notbasic <- c(as.raw(c(0x30, 0x0f, 0x0a, 0x01, 0x00, 0x04, 0x0a)), inner)
  expect_identical(.rmbl_ocsp_parse(notbasic, leaf, path)$detail, "no BasicOCSPResponse in the answer")
  # the right shape with no SingleResponse inside
  basic <- as.raw(c(0x30, 0x10, 0x30, 0x03, 0x02, 0x01, 0x01,
                    0x30, 0x05, 0x06, 0x03, 0x2a, 0x03, 0x04, 0x03, 0x02, 0x00, 0x01))
  nosingle <- c(as.raw(c(0x30, 0x17, 0x0a, 0x01, 0x00, 0x04, 0x12)), basic)
  expect_identical(.rmbl_ocsp_parse(nosingle, leaf, path)$detail, "no SingleResponse in the answer")
  # a signature algorithm this package does not verify is reported, not trusted
  testthat::local_mocked_bindings(.rmbl_x509_sigalg_name = function(oid) "MD5withRSA")
  md5 <- .rmbl_ocsp_parse(f$ocsp_resp_good, leaf, path)
  expect_false(md5$ok)
  expect_identical(md5$detail,
                   "the responder said 'good' but it is signed with MD5withRSA, which is not verified here")
})

test_that("the query POSTs, falls back to GET with the request in the URL, and reports silence", {
  f <- x509_fx()
  leaf <- cert_parse(f$ocsp_good)
  ca <- cert_parse(f$ocsp_ca)
  path <- list(leaf, ca)
  url <- "http://ocsp.example.org/"
  posted <- NULL
  testthat::local_mocked_bindings(.rmbl_net_post = function(url, body, content_type, timeout) {
    posted <<- list(url = url, body = body, ct = content_type)
    list(status = 200L, body = f$ocsp_resp_good, error = "")
  })
  q <- .rmbl_ocsp_query(leaf, ca, url, path)
  expect_true(q$ok)
  expect_identical(posted$body, f$ocsp_req_good)
  expect_identical(posted$ct, "application/ocsp-request")
  # a responder that refuses POST is asked by GET, request base64 in the path
  seen <- NULL
  testthat::local_mocked_bindings(
    .rmbl_net_post = function(url, body, content_type, timeout) list(status = 500L, body = raw(0), error = ""),
    .rmbl_net_get_file = function(url, fallback, tmp, timeout) {
      seen <<- url
      writeBin(f$ocsp_resp_good, tmp)
      200L
    })
  q <- .rmbl_ocsp_query(leaf, ca, url, path)
  expect_true(q$ok)
  expect_identical(seen, paste0(url, .rmbl_url_encode(bricklayer_json_base64_enc(f$ocsp_req_good))))
  # nobody answers either way
  testthat::local_mocked_bindings(
    .rmbl_net_post = function(url, body, content_type, timeout) NULL,
    .rmbl_net_get_file = function(url, fallback, tmp, timeout) NULL)
  q <- .rmbl_ocsp_query(leaf, ca, url, path)
  expect_false(q$ok)
  expect_identical(q$detail, "no answer from http://ocsp.example.org/ over POST or GET")
  # an issuer whose DER has no key: no request can be built
  q <- .rmbl_ocsp_query(leaf, list(der = as.raw(c(0x30, 0x00))), url, path)
  expect_identical(q$detail, "could not build an OCSP request")
})

test_that("revocation_fetch walks the path with one note per URL", {
  f <- x509_fx()
  leaf <- cert_parse(f$ocsp_good)
  ca <- cert_parse(f$ocsp_ca)
  testthat::local_mocked_bindings(
    .rmbl_net_post = function(url, body, content_type, timeout) {
      list(status = 200L, body = f$ocsp_resp_good, error = "")
    },
    .rmbl_net_get_file = function(url, fallback, tmp, timeout) {
      writeBin(f$ocsp_crl_der, tmp)
      200L
    })
  r <- revocation_fetch(list(leaf, ca))
  expect_identical(names(r$notes), c("crl fetch [1]", "ocsp [1]"))
  expect_identical(r$ok, c(TRUE, TRUE))
  expect_length(r$crls, 1L)
  expect_identical(r$crls[[1]], f$ocsp_crl_der)
  expect_identical(r$notes[["crl fetch [1]"]],
                   sprintf("%d bytes from http://crl.example.org/ca.crl", length(f$ocsp_crl_der)))
  expect_identical(r$notes[["ocsp [1]"]], "the responder says good, signed")
  # an unreachable distribution point is a failed check, not a pass
  testthat::local_mocked_bindings(.rmbl_net_get_file = function(url, fallback, tmp, timeout) NULL)
  r2 <- .rmbl_revocation_fetch(list(leaf, ca))
  expect_false(r2$ok[[1]])
  expect_identical(r2$notes[["crl fetch [1]"]], "could not retrieve http://crl.example.org/ca.crl")
  # the entry point takes a parsed path, nothing else
  expect_error(revocation_fetch("leaf.crt"), "non-empty list of parsed certificates")
  expect_error(revocation_fetch(list()), "non-empty list of parsed certificates")
  expect_error(revocation_fetch(list(leaf), timeout = 0), "`timeout` must be positive")
})

test_that("ECDSA on P-256 with a digest longer than the order shifts the excess bits off", {
  f <- x509_fx()
  k <- cert_parse(f$ocsp_ecleaf)$key
  expect_identical(k$type, "EC")
  m <- charToRaw("ocsp fixture message")
  rs <- .rmbl_ecdsa_rs(f$ocsp_ec_sig512)
  expect_true(.Call(C("C_rmbl_ecdsa_verify"), k$curve, k$x, k$y, rs$r, rs$s, .rmbl_ts_digest("sha512", m)))
  rs <- .rmbl_ecdsa_rs(f$ocsp_ec_sig384)
  expect_true(.Call(C("C_rmbl_ecdsa_verify"), k$curve, k$x, k$y, rs$r, rs$s, .rmbl_ts_digest("sha384", m)))
  expect_false(.Call(C("C_rmbl_ecdsa_verify"), k$curve, k$x, k$y, rs$r, rs$s,
                     .rmbl_ts_digest("sha384", charToRaw("ocsp fixture messagE"))))
  expect_identical(msg(.Call(C("C_rmbl_ec_order"), "P-999")), "unsupported curve: P-999")
  expect_identical(msg(.Call(C("C_rmbl_ec_order"), 1L)), "`curve` must be a single string")
  expect_identical(msg(.Call(C("C_rmbl_ec_mul"), 1L, as.raw(1))), "`curve` must be a single string")
})

# ---------------------------------------------------------------- #
# C entry points: argument errors and degenerate inputs
# ---------------------------------------------------------------- #

test_that("series and stats kernels: Bernoulli values, degenerate inputs, argument types", {
  # zeta(-n, 1) = -B_{n+1} / (n + 1): B_4 = -1/30, B_5 = 0, B_6 = 1/42
  expect_equal(hurwitz_zeta(-3, 1), 1 / 120)
  expect_equal(hurwitz_zeta(-4, 1), 0)
  expect_equal(hurwitz_zeta(-5, 1), -1 / 252)
  neg <- "concentration measures need non-negative values"
  expect_identical(msg(.Call(C("C_rmbl_gini"), c(1, -1))), neg)
  expect_identical(msg(.Call(C("C_rmbl_lorenz"), c(1, -1))), neg)
  expect_identical(msg(.Call(C("C_rmbl_top_share"), c(1, -1), 0.5)), neg)
  expect_identical(msg(.Call(C("C_rmbl_theil_sen"), 1:3, 1:3)), "`x` and `y` must be double vectors")
  # an even number of pairwise slopes takes the mean of the middle two:
  # slopes 2, 1/2, 4/3, -1, 1, 3 -> (1 + 4/3) / 2
  ts <- .Call(C("C_rmbl_theil_sen"), c(1, 2, 3, 4), c(1, 3, 2, 5))
  expect_equal(ts$slope, 7 / 6)
  expect_equal(ts$pairs, 6)
  # a constant x has no variance to autocorrelate: the kernel says so with NA
  mi <- .Call(C("C_rmbl_morans_i"), c(1, 1, 1), c(1L, 0L, 2L, 1L), c(0L, 1L, 3L),
              c(1L, 2L, 1L), rep(1, 4), 0L, NULL)
  expect_identical(mi, list(I = NA_real_, cross = NA_real_, W = 4, null = numeric(0)))
  # top_share over a long vector of fractions is one pass, not n * m
  x <- as.numeric(1:1e5)
  t0 <- proc.time()[["elapsed"]]
  ts2 <- .Call(C("C_rmbl_top_share"), x, rep(0.5, 1e5))
  expect_lt(proc.time()[["elapsed"]] - t0, 5)
  expect_equal(ts2$share[1], sum(50001:1e5) / sum(x))
  expect_identical(ts2$units[1], 50000L)
  expect_identical(.Call(C("C_rmbl_quantile"), c(1, NaN), 0.5), NaN)
  expect_identical(.Call(C("C_rmbl_cov_matrix"), matrix(1, 1, 2)), matrix(NaN, 2, 2))
  expect_identical(.Call(C("C_rmbl_ks"), c(1, NA), 2)[1:2], c(NaN, NaN))
  expect_identical(.Call(C("C_rmbl_bootstrap_mean"), numeric(0), 3L, 1), rep(NaN, 3))
  expect_identical(msg(.Call(C("C_rmbl_euclid"), 1:2, 1:3)), "a and b must have the same length")
  expect_identical(msg(.Call(C("C_rmbl_sha256"), 1L)),
                   "rmbl_sha256 expects a length-1 character vector or a raw vector")
  expect_identical(msg(.Call(C("C_rmbl_sha512"), c("a", NA))), "`x` contains a missing string (element 2)")
  expect_identical(msg(.Call(C("C_rmbl_blake2b"), c("a", NA), NULL, 32L)),
                   "`x` contains a missing string (element 2)")
  expect_identical(.Call(C("C_rmbl_hll_count"), integer(0)), 0)
  expect_identical(msg(.Call(C("C_rmbl_hll_add"), "a", 3L, integer(16))), "`p` must be between 4 and 20")
})

test_that("decimal conversion: the specials, the subnormal edge, a carried rounding, 800 digits", {
  got <- .Call(C("C_rmbl_strtod"), c("Inf", "-inf", "NaN", "nan", "1e-400", "5e-324",
                                     "2.4703282292062328e-324", paste0("1", strrep("0", 800)),
                                     "1.9999999999999999999", strrep("9", 800), " +0.1e1"))
  expect_identical(got, c(Inf, -Inf, NaN, NaN, 0, 2^-1074, 2^-1074, Inf, 2, Inf, 1))
  # 1e-243 is the double just below the power of ten: seventeen digits
  # round to 10.000..., which has to carry into the exponent
  expect_identical(.Call(C("C_rmbl_dtoa17"), as.numeric("1e-243")), "1e-243")
  expect_identical(sprintf("%.30e", as.numeric("1e-243")) > "9.9999", TRUE)
})

test_that("http entry points check their arguments before touching the network", {
  expect_identical(.Call(C("C_rmbl_url_check"), "http://[::1]:8080/", TRUE, FALSE),
                   "a local or private address (::1)")
  expect_identical(.Call(C("C_rmbl_url_check"), "http://[::10.1.2.3]/", TRUE, FALSE),
                   "a local or private address (::10.1.2.3)")
  expect_identical(.Call(C("C_rmbl_url_check"), "http://[::8.8.8.8]/", TRUE, FALSE), "")
  expect_identical(.Call(C("C_rmbl_url_check"), "http://[::1]x/", TRUE, FALSE), "malformed authority")
  expect_true(.rmbl_private_host(NA))
  expect_true(.rmbl_private_host(""))
  # extra headers are accepted; the refusal comes back as a status, not a crash
  r <- .Call(C("C_rmbl_http_post"), "http://127.0.0.1/", raw(0), "text/plain", 1L, c("X-A: b"))
  expect_identical(r$status, -1L)
  expect_match(r$error, "plain http is refused", fixed = TRUE)
  expect_identical(msg(.Call(C("C_rmbl_http_post"), 1L, raw(0), "text/plain", 1L, NULL)),
                   "`url` must be a single string")
  expect_identical(msg(.Call(C("C_rmbl_http_post"), "https://a.example.org/", raw(0), 1L, 1L, NULL)),
                   "`content_type` must be a single string")
  expect_identical(msg(.Call(C("C_rmbl_http_post"), "https://a.example.org/", raw(0), "t", 1L, 1L)),
                   "`headers` must be a character vector or NULL")
  expect_identical(msg(.Call(C("C_rmbl_http_get"), 1L, 1L, NULL)), "`url` must be a single string")
  expect_identical(msg(.Call(C("C_rmbl_http_get"), "https://a.example.org/", 1L, 1L)),
                   "`headers` must be a character vector or NULL")
})

test_that("post-quantum entry points name the argument they refuse", {
  kp <- .Call(C("C_rmbl_mldsa_keypair"), 44L, raw(32))
  expect_identical(msg(.Call(C("C_rmbl_mldsa_mu"), 44L, kp[[1]], as.raw(1), raw(0), "foo")),
                   "`prehash` must be one of none, sha256, sha512, shake128, shake256")
  expect_identical(msg(.Call(C("C_rmbl_mldsa_mu"), 44L, kp[[1]], as.raw(1), raw(0), 1L)),
                   "`prehash` must be a single string")
  expect_identical(msg(.Call(C("C_rmbl_mldsa_mu"), 44L, kp[[1]], as.raw(1), raw(300), NULL)),
                   "`ctx` must be a raw vector of at most 255 bytes")
  expect_identical(msg(.Call(C("C_rmbl_mldsa_sizes"), 99L)), "`mode` must be 44, 65 or 87")
  expect_identical(msg(.Call(C("C_rmbl_mlkem_sizes"), 1L)), "`level` must be 512, 768 or 1024")
  expect_identical(msg(.Call(C("C_rmbl_mlkem_sizes"), "a")),
                   "`level` must be a single integer: 512, 768 or 1024")
  expect_identical(msg(.Call(C("C_rmbl_mlkem_keygen"), 512L, raw(3))),
                   "`seed` must be a raw vector of 64 bytes (d || z)")
  expect_identical(msg(.Call(C("C_rmbl_mlkem_encaps"), 512L, raw(800), raw(3))),
                   "`m` must be a raw vector of 32 bytes")
  expect_identical(msg(.Call(C("C_rmbl_hmac_shax"), "a", raw(1), raw(1))), "`bits` must be 256 or 512")
  expect_identical(msg(.Call(C("C_rmbl_hmac_shax"), 256L, "k", raw(1))), "`key` and `msg` must be raw vectors")
  expect_identical(msg(.Call(C("C_rmbl_mgf1"), "a", raw(1), 4L)), "`bits` must be 256 or 512")
  expect_identical(msg(.Call(C("C_rmbl_mgf1"), 128L, raw(1), 4L)), "`bits` must be 256 or 512")
  expect_identical(msg(.Call(C("C_rmbl_slhdsa_sizes"), 1L)), "`set` must be a single parameter set name")
  skp <- .Call(C("C_rmbl_slhdsa_keypair"), "SLH-DSA-SHAKE-128f", raw(48))
  expect_identical(msg(.Call(C("C_rmbl_slhdsa_sign"), "SLH-DSA-SHAKE-128f", skp[[2]], as.raw(1), raw(300), NULL, NULL)),
                   "`ctx` must be a raw vector of at most 255 bytes")
  expect_false(.Call(C("C_rmbl_slhdsa_verify"), "SLH-DSA-SHAKE-128f", skp[[1]], as.raw(1), raw(300), raw(10), NULL))
  # an XMSS index past the tree is a refusal, not a read past the end
  expect_false(.Call(C("C_rmbl_xmss_verify"), strrep("00", 32), strrep("00", 32), 4L, 16L,
                     as.raw(1), "", "", strrep("00", 32)))
})

# ---------------------------------------------------------------- #
# JSON
# ---------------------------------------------------------------- #

test_that("writer: scalars with extra classes, AsIs, class fall-through, force, 1-d arrays", {
  tj <- function(...) as.character(bricklayer_json_to_json(...))
  expect_identical(tj(structure(1, class = c("scalar", "numeric"))), "1")
  expect_identical(tj(I(5), auto_unbox = TRUE), "[5]")
  expect_identical(tj(structure(list(a = 1), class = c("foo", "list"))), "{\"a\":[1]}")
  expect_identical(tj(structure(list(a = 1), class = "zzz"), force = TRUE), "{\"a\":[1]}")
  expect_identical(tj(array(1:3)), "[1,2,3]")
  df <- data.frame(a = 1:2)
  df$b <- list(1, 2:3)
  expect_identical(tj(df, auto_unbox = TRUE), "[{\"a\":1,\"b\":1},{\"a\":2,\"b\":[2,3]}]")
  df2 <- data.frame(a = 1:2)
  df2$b <- list(list(x = 1), list(y = 2))
  expect_identical(tj(df2), "[{\"a\":1,\"b\":{\"x\":[1]}},{\"a\":2,\"b\":{\"y\":[2]}}]")
  expect_identical(tj(c(1 + 2i, NA), complex = "list", na = "string"),
                   "{\"real\":[1,\"NA\"],\"imaginary\":[2,0]}")
  expect_identical(.rmbl_json_dtoa2(3e9, 2), "3.000000e+09")
  expect_identical(.rmbl_json_dtoa2(1.999, 2), "2")
  expect_identical(.rmbl_json_dtoa2(-1.9999, 1), "-2")
})

test_that("simplifier helpers answer FALSE/empty for the shapes they do not handle", {
  expect_false(.rmbl_json_is_scalarlist(1))
  expect_identical(.rmbl_json_null_to_na(list()), list())
  expect_false(.rmbl_json_is_datelist(1))
  d1 <- as.POSIXct("2020-01-01", tz = "UTC")
  expect_true(.rmbl_json_is_datelist(list(d1, NULL)))
  v <- .rmbl_json_list_to_vec(list(d1, d1 + 86400))
  expect_s3_class(v, "POSIXct")
  expect_identical(as.numeric(v), c(1577836800, 1577923200))
  expect_identical(.rmbl_json_parse_date(TRUE), TRUE)
  a <- .rmbl_json_simplify(list(list(list(1, 2), list(3, 4)), list(list(5, 6), list(7, 8))),
                           columnmajor = TRUE)
  expect_identical(dim(a), c(2L, 2L, 2L))
  expect_identical(a[, , 1], matrix(c(1, 2, 3, 4), 2))   # inner arrays are columns
  expect_identical(.rmbl_json_written_integer("1e+"), NULL)
  expect_identical(.rmbl_json_written_integer("1.25e1"), NULL)
  expect_identical(.rmbl_json_written_integer("0e0"), "0")
  expect_identical(.rmbl_json_written_integer("1.5e1"), "15")
})

test_that("the reformatter names every malformation and decodes surrogate pairs", {
  bad <- function(s) msg(bricklayer_json_minify(s))
  expect_identical(bad("-"), "invalid number at character 2")
  expect_identical(bad("{[]}"), "keys must be strings at character 2")
  expect_identical(bad("[1:2]"), "unexpected ':' at character 3")
  expect_identical(bad("{\"a\":1 \"b\":2}"), "expected ',' between members at character 11")
  expect_identical(bad("{1:2}"), "keys must be strings at character 2")
  expect_identical(bad("[1"), "unexpected end of input at character 3")
  expect_identical(as.character(bricklayer_json_minify("\"\\ud83d\\ude00\"")), "\"\U0001F600\"")
  expect_identical(bad("\"\\ud83d\\u0041\""), "lone surrogate escape at character 1")
  # a string with more escapes than the part buffer starts with
  long <- paste0("\"", strrep("\\n", 300), "\"")
  expect_identical(nchar(as.character(bricklayer_json_minify(long))), 602L)
})

# ---------------------------------------------------------------- #
# R-level guards and small branches
# ---------------------------------------------------------------- #

test_that("drift: empty samples, zero expectations, one category, date detection", {
  expect_error(drift_ks(c(NA, NA), 1), "non-missing")
  expect_error(drift_psi(c(NA, NA), 1), "non-missing")
  expect_error(drift_chisq(c(a = 1, b = 2), c(a = 0, b = 0)), "`expected` has no counts")
  h <- drift_homogeneity(c("a", "a"), "a")
  expect_identical(attr(h, "method"), "inapplicable: one category")
  expect_true(is.na(h[["p_value"]]))
  expect_error(capsule_drift(data.frame(a = 1:5), data.frame(a = 1:5), identifier_levels = 1),
               "`identifier_levels` must be a single integer of at least 2")
  expect_identical(.rmbl_as_dates(as.Date("2020-01-01")), as.Date("2020-01-01"))
  expect_null(.rmbl_as_dates(1))
  dt <- .rmbl_as_dates(c("2020-01-01 10:00", NA))
  expect_s3_class(dt, "POSIXct")
  expect_identical(as.numeric(dt), c(1577872800, NA))
  expect_null(.rmbl_as_dates(c("2020-01-01T10:00:00", "2020-01-01 25:99")))
})

test_that("concentration and contingency guards", {
  expect_error(gini(c(1, -1)), "`x` must be non-negative")
  expect_identical(cramers_v(matrix(0, 2, 2))$method, "table too small after dropping empty rows/columns")
  expect_error(cramers_v(matrix(c(-1, 2, 3, 4), 2)), "finite non-negative counts")
})

test_that("name constraints: every GeneralName tag, empty inputs, the formatter", {
  g <- .rmbl_general_names(list(children = list(
    list(class = 0L, tag = 16),
    list(class = 2L, tag = 6, value = charToRaw("http://x")),
    list(class = 2L, tag = 9, value = as.raw(1)),
    list(class = 2L, tag = 7, value = as.raw(c(10, 0, 0, 1))))))
  expect_identical(vapply(g, `[[`, "", "type"), c("uri", "tag9", "ip"))
  expect_identical(g[[1]]$value, "http://x")
  expect_identical(.rmbl_raw_text(raw(0)), "")
  expect_identical(.rmbl_x509_rdns(list(children = list(list(children = list(list(children = list())))))),
                   list(list(NULL)))
  expect_null(.rmbl_name_constraints(as.raw(0xff)))
  expect_null(.rmbl_name_constraints(as.raw(c(0x30, 0x00))))
  expect_null(.rmbl_name_constraints(as.raw(c(0x30, 0x02, 0x05, 0x00))))
  expect_null(.rmbl_name_constraints(as.raw(c(0x30, 0x04, 0xa0, 0x02, 0x30, 0x00))))
  expect_true(.rmbl_nc_match_dns("a.example.org", ""))
  expect_true(.rmbl_nc_match_dirname(list(), list()))
  expect_false(.rmbl_nc_match_dirname(list(), list(1)))
  expect_true(is.na(.rmbl_nc_match(list(type = "uri", value = "a"), list(type = "dns", value = "a"))))
  expect_identical(.rmbl_nc_show(list(type = "ip", value = as.raw(c(10, 0, 0, 1)))), "10.0.0.1")
  expect_identical(.rmbl_nc_show(list(type = "dns", value = "a.example.org")), "a.example.org")
})

test_that("the policy tree honours inhibitPolicyMapping and inhibitAnyPolicy counters", {
  anchor <- list(policies = "1.2.3", inhibit_policy_mapping = 0L, inhibit_any_policy = 0L)
  mid <- list(policies = "1.2.3", policy_mappings = list(list(issuer = "1.2.3", subject = "1.2.4")))
  leaf <- list(policies = "1.2.4")
  r <- .rmbl_policy_tree(list(leaf, mid, anchor))
  expect_true(any(grepl("[2] asserts policy mappings while mapping is inhibited", r$notes, fixed = TRUE)))
  expect_identical(.rmbl_chr0(NULL), character(0))
  expect_identical(.rmbl_chr0(1:2), c("1", "2"))
})

test_that("mcar: degenerate inputs and a rejected test", {
  expect_identical(.rmbl_make_pd(matrix(NaN, 2, 2)), matrix(NaN, 2, 2))
  expect_null(.rmbl_em_mvn(matrix(NA_real_, 3, 2)))
  # too few complete rows for a covariance: pairwise moments start the EM
  r <- mcar_test(data.frame(a = c(NA, NA, 1, 2), b = c(1, 2, NA, NA)))
  expect_identical(r$df, 0)
  set.seed(2)
  d <- data.frame(a = rnorm(40), b = rnorm(40))
  d$b[d$a > 0.3] <- NA
  m <- mcar_test(d)
  expect_lt(m$p_value, 0.05)
  expect_true(any(grepl("MCAR rejected", format(m), fixed = TRUE)))
  expect_error(mahalanobis_outliers(data.frame(a = letters[1:5])), "no numeric columns")
})

test_that("analyse_table and its report: bad inputs, drift against a prior, missing values", {
  otis <- read.csv(system.file("extdata", "otis_a01_individuals.csv", package = "rmoriebricklayer"))
  expect_error(analyse_table(1), "`data` must be a data frame")
  expect_error(analyse_table(otis, value = "individuals", period = "year", prior = 1),
               "`prior` must be a data frame")
  prior <- otis
  prior$individuals <- round(prior$individuals * 0.9)
  prior$extra <- 1
  cur <- otis
  cur$individuals[1] <- NA
  a <- analyse_table(cur, value = "individuals", period = "year", prior = prior)
  md <- report_analysis(a, format = "markdown")
  expect_true(grepl("## Drift against the prior capsule", md, fixed = TRUE))
  expect_true(grepl("Columns removed: extra.", md, fixed = TRUE))
  expect_true(grepl("### Missing values", md, fixed = TRUE))
  expect_identical(.md_table(data.frame()), "(no rows)")
  # fewer than three periods: the trend is not tested, and the print says so
  short <- otis[otis$year %in% head(sort(unique(otis$year)), 2), ]
  out <- capture.output(print(analyse_table(short, value = "individuals", period = "year")))
  expect_true(any(grepl("fewer than three periods", out, fixed = TRUE)))
})

test_that("rates and shares refuse non-numeric columns, missing groups and impossible totals", {
  d <- data.frame(n = c("1", "2"), pop = c(10, 20), g = c("a", "b"), year = c(2000, 2001))
  expect_error(rate(d, count = "n", population = "pop"), "`n` must be numeric, not character")
  d$n <- c(1, 2)
  d$pop <- c("10", "20")
  expect_error(rate(d, count = "n", population = "pop"), "`pop` must be numeric, not character")
  d$pop <- c(10, 20)
  expect_error(share(d, count = "n", by = "zz"), "`by` column not found: zz")
  d2 <- d
  d2$n <- c("1", "2")
  expect_error(share(d2, count = "n"), "`n` must be numeric, not character")
  d3 <- d
  d3$n <- c(-1, 2)
  expect_error(share(d3, count = "n", by = "g"), "`count` must be non-negative")
  expect_error(share(d, count = "n", total = 0), "the total must be positive")
  expect_error(rate_change(d, count = "n", population = "pop", period = "year", by = "zz"),
               "`by` column not found: zz")
  d4 <- d
  d4$pop <- c(0, 20)
  expect_error(rate_change(d4, count = "n", population = "pop", period = "year"),
               "`population` must be positive")
  # a pair with no events on either side has no ratio
  ci <- .rate_ratio_ci(c(0, 1), c(0, 1), c(1, 1), c(1, 1), 0.95)
  expect_identical(is.na(ci$lower), c(TRUE, FALSE))
  expect_identical(is.na(ci$upper), c(TRUE, FALSE))
})

test_that("recompute compares labels by identity; seeds are recorded and restored", {
  m <- list(results = list(label = list(observed = "A"), other = list(observed = "B")))
  r <- manifest_recompute(m, data.frame(x = 1), list(label = function(d) "A", other = function(d) "C"))
  expect_identical(r$results$status, c("MATCH", "DIFFER"))
  expect_identical(r$results$detail[2], "recorded 'B', recomputed 'C'")
  # no generator state yet: one draw creates it so the record is real
  if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
    rm(".Random.seed", envir = globalenv())
  }
  rec <- manifest_record_seed(list())
  expect_true(is.list(rec$rng))
  expect_true(exists(".Random.seed", envir = globalenv(), inherits = FALSE))
  # a record that names only the main generator kind restores it
  set.seed(11)
  u1 <- runif(3)
  set.seed(11)
  state <- get(".Random.seed", envir = globalenv())
  short <- list(rng = list(kind = "Mersenne-Twister", state = state))
  runif(5)
  manifest_restore_seed(short)
  expect_identical(runif(3), u1)
})

test_that("CLI helpers without a terminal, a help page, or a writable destination", {
  expect_false(.bl_interactive())
  expect_identical(.bl_describe("no_such_fn"), "no help page for 'no_such_fn'\n")
  expect_identical(.bl_examples("no_such_fn"), "no help page for 'no_such_fn'\n")
  withr::with_envvar(c(MORIE_HOSTED_BASE_URL = "off"), {
    out <- character(0)
    .bl_cli_models(function(s) out <<- c(out, s))
    expect_identical(out, "Hosted MORIE tier: disabled (MORIE_HOSTED_BASE_URL=off)\n")
  })
  out <- character(0)
  rc <- .bl_cli_data(c("pull", "tbl"), function(f) "/nonexistent-dir-zz/out.csv",
                     function(s) out <<- c(out, s))
  expect_identical(rc, 1L)
  expect_match(out, "cannot write /nonexistent-dir-zz/out.csv", fixed = TRUE)
})

test_that("power, bounds, scan adjustment and falsification guards", {
  set.seed(3)
  d <- data.frame(t = rep(0:1, 10), y = rnorm(20))
  stat <- function(d) mean(d$y[d$t == 1]) - mean(d$y[d$t == 0])
  inj <- function(d, sz) {
    d$y <- d$y + sz * d$t
    d
  }
  expect_error(capsule_power(d[1:3, ], stat, inj, treatment = "t"), "at least 4 rows")
  expect_error(capsule_power(d, stat, inj, treatment = "zz"), "`treatment` is not a column")
  expect_error(capsule_power(d, stat, inj, treatment = "t", n = 5L), "`n` must be at least 9")
  expect_error(capsule_power(d, stat, inj, treatment = "t", reps = 0L), "`reps` must be at least 1")
  # an injector that returns nothing, a statistic that cannot be computed
  # on the data, and one that only answers on the unpermuted data: each
  # replicate is skipped rather than counted
  p1 <- capsule_power(d, stat, function(d, sz) NULL, treatment = "t", n = 19L, reps = 2L)
  p2 <- capsule_power(d, function(d) NA_real_, inj, treatment = "t", n = 19L, reps = 2L)
  p3 <- capsule_power(d, function(x) if (identical(x$t, d$t)) 1 else NA_real_, inj,
                      treatment = "t", n = 19L, reps = 2L)
  for (p in list(p1, p2, p3)) {
    expect_s3_class(p, "bricklayer_power")
    expect_true(all(p$curve$usable == 0L))
    expect_true(all(is.na(p$curve$power)))
  }
  expect_error(published_bounds(5, rounding = 0), "`rounding` must be a positive number")
  now <- published_bounds(c(45, 120), rounding = 5)
  prev <- published_bounds(c(40, 100, 7), rounding = 5)
  expect_error(change_envelope(now, prev), "same number of rows")
  e <- change_envelope(now, prev[1:2, ], population = c(1000, 2000), previous_population = c(900, 1900))
  expect_equal(e$rate_lower, 1000 * now$lower / c(1000, 2000))
  expect_equal(e$previous_rate_upper, 1000 * prev$upper[1:2] / c(900, 1900))
  expect_error(yoy_pvalues(1), "`y` must come from yoy()")
  expect_error(scan_adjust(1), "`x` must be a data frame")
  expect_identical(.exact_ratio_p(c(0, 3), c(0, 3)), c(NA, 1))
  cal <- structure(list(columns = data.frame(column = c("a", "b"), false_alarm_rate = c(0.5, 0)),
                        any_flag = 0.5, alpha = 0.01, n = 10L, alpha_familywise = 0.005),
                   class = "rmbl_drift_calibration")
  out <- capture.output(print(cal))
  expect_true(any(grepl("columns that fire on identical data", out, fixed = TRUE)))
  expect_true(any(grepl("a                             50.0%", out, fixed = TRUE)))
  # a statistic that only works on the full table leaves every subset NA
  full <- data.frame(y = rnorm(20))
  fz <- capsule_falsify(full, function(x) if (nrow(x) < 20L) stop("too small") else mean(x$y), n = 9L)
  row <- fz$controls[fz$controls$control == "subset_stability", ]
  expect_false(row$passed)
  expect_identical(row$detail, "the statistic could not be computed on any subset")
  expect_error(falsify_family(list(a = fz, fz)), "NAMED list")
  fam <- falsify_family(c(0.1, 0.2))
  expect_identical(fam$results$name, c("p1", "p2"))
  expect_identical(fam$results$adjusted, c(0.2, 0.2))
})

test_that("signing helpers: keys without halves, contexts, pre-hash names", {
  mk <- fips_keygen("ML-DSA-44")
  nopub <- mk
  nopub$public <- NULL
  expect_error(fips_mu(nopub, "m"), "`key` has no usable public key")
  sg <- fips_sign_mu(mk, fips_mu(mk, "m"))
  sg2 <- sg
  sg2$signature <- NULL
  expect_false(fips_verify_mu(mk, fips_mu(mk, "m"), sg2))
  slh <- fips_keygen("SLH-DSA-SHAKE-128f")
  expect_error(fips_verify_mu(slh, raw(64), sg), "ML-DSA interface")
  expect_identical(.rmbl_fips_prehash(NULL), "none")
  expect_identical(.rmbl_fips_context(as.raw(1:3)), as.raw(1:3))
  kk <- kem_keygen(512L)
  kk$public <- NULL
  expect_error(kem_encapsulate(kk), "`key` has no usable public key")
  kk2 <- kem_keygen(512L)
  kk2$secret <- NA_character_
  expect_error(kem_decapsulate(kk2, raw(768)), "`key` has no usable secret key")
  # no operating-system entropy: refuse, never fall back to R's generator
  testthat::local_mocked_bindings(.rmbl_os_random = function(n) NULL)
  expect_error(random_bytes(4L), "no operating-system random source could be read")
})

test_that("digest helpers: chunk coercion, hex parsing, unknown prefixes", {
  expect_identical(.rmbl_chunk_bytes(list("a", as.raw(1))), list(charToRaw("a"), as.raw(1)))
  expect_error(.rmbl_chunk_bytes(list(1)), "chunk 1 must be a raw vector or a length-1 string")
  expect_identical(.rmbl_chunk_bytes(list()), list())
  expect_error(.rmbl_chunk_bytes(1), "`chunks` must be a character vector, a raw vector, or a list of these")
  expect_error(.rmbl_hex_to_raw("abc"), "hex string has odd length")
  expect_identical(.rmbl_hex_to_raw(""), raw(0))
  expect_null(.rmbl_pkcs1_prefix("md5"))
  expect_identical(.rmbl_num_input(NULL, "x"), numeric(0))
  expect_error(.rmbl_num_input(NULL, "x", allow_null = FALSE), "`x` must be numeric, got NULL")
  # a seeded evaluation in a session with no generator state leaves none behind
  if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
    rm(".Random.seed", envir = globalenv())
  }
  set.seed(1)
  u <- runif(1)
  rm(".Random.seed", envir = globalenv())
  expect_identical(.rmbl_with_seed(1, runif(1)), u)
  # ... and the state it created for itself is gone again
  expect_false(exists(".Random.seed", envir = globalenv(), inherits = FALSE))
})

test_that("categorical guards accept factors where they accept characters", {
  expect_identical(as.vector(decode_codes(factor(c("1", "2")), c("1" = "A", "2" = "B"))), c("A", "B"))
  expect_identical(guard_levels(factor(c("a", "b")), c("a", "b")), factor(c("a", "b"), levels = c("a", "b")))
  vr <- verify_recode(factor(c("x", "y")), factor(c("X", "Y")), c(x = "X", y = "Y"))
  expect_s3_class(vr, "data.frame")
  expect_identical(vr$Freq, c(1L, 0L, 0L, 1L))
  vm <- verify_marginals(factor(c("a", "a", "b")), c(a = 2, b = 1))
  expect_true(vm$ok)
  expect_identical(vm$counts, c(a = 2, b = 1))
})

test_that("printing: subsets without the method's columns, drift summaries, public keys, reports", {
  r <- rate(data.frame(n = c(1, 2), pop = c(10, 20)), count = "n", population = "pop")
  sub <- r[, 1:2]
  attr(sub, "zz") <- "extra attribute"
  expect_output(print(sub), "n")
  ref <- data.frame(a = 1:20, gone = 1:20)
  cur <- data.frame(a = 1:20, added = 1:20)
  s <- summary(capsule_drift(ref, cur))
  out <- capture.output(print(s))
  expect_true(any(grepl("added:   added", out, fixed = TRUE)))
  expect_true(any(grepl("removed: gone", out, fixed = TRUE)))
  pk <- signing_public_key(pqc_keygen(height = 4L))
  expect_output(print(pk), "scheme  xmss-sha256")
  expect_output(print(pk), "height  4")
  rep <- capsule_report(data.frame(x = 1:5))
  rep$digest$merkle_root <- strrep("ab", 32)
  rep$digest$signature_valid <- FALSE
  md <- report_markdown(rep)
  expect_true(sprintf("| merkle root | `%s` |", strrep("ab", 32)) %in% md)
  expect_true("| signature | **NOT verified** |" %in% md)
  sch <- infer_schema(data.frame(f = letters[1:6], stringsAsFactors = FALSE))
  expect_true(any(grepl("... (6 levels)", format(sch), fixed = TRUE)))
  expect_error(correlation_table(1), "`data` must be a data frame")
  expect_error(expected_counts(c(-1, 2), c(10, 10), c("a", "b")), "`counts` must be non-negative")
  expect_error(sir(-1, 1), "`observed` must be non-negative")
  expect_error(falsify_family(1:3), "p-values must lie in")
  expect_identical(to_ascii("Ångela"), "Angela")
})

test_that("yoy PDF with groups, verdict colours and notes", {
  y <- yoy(data.frame(year = rep(2000:2003, 2), g = rep(c("a", "b"), each = 4),
                      n = c(10, 12, 9, 15, 5, 4, 6, 3)), value = "n", period = "year", by = "g")
  expect_setequal(stats::na.omit(unique(as.data.frame(y)$verdict)), c("up", "down"))
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f), add = TRUE)
  yoy_pdf(y, f, notes = c("one", "two"))
  expect_true(file.size(f) > 0)
  expect_identical(readChar(f, 5L, useBytes = TRUE), "%PDF-")
})
