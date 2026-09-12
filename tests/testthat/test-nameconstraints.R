# Name constraints, certificate policies, path length, and revocation.
#
# Every verdict asserted here was cross-checked against `openssl
# verify` on the same certificates: it accepts nc_leaf_good and rejects
# the other three, accepts pol_leaf_ok under an explicit policy and
# rejects pol_leaf_other. Agreeing with an independent implementation on
# which certificates are BAD is the part that matters -- a verifier that
# accepts everything passes any test that only uses valid input.

x509_fx <- function() {
  fx <- readLines(test_path("x509-fixtures.txt"), warn = FALSE)
  fx <- fx[!startsWith(fx, "#") & nzchar(fx)]
  parts <- strsplit(fx, "|", fixed = TRUE)
  stats::setNames(lapply(parts, function(p) .rmbl_hex_to_raw(p[2L])),
                  vapply(parts, `[[`, character(1), 1L))
}

test_that("name constraints are read out of the certificate", {
  f <- x509_fx()
  ca <- cert_parse(f$nc_ca)
  nc <- ca$name_constraints
  expect_false(is.null(nc))
  types <- vapply(nc$permitted, `[[`, character(1), "type")
  expect_setequal(types, c("dns", "email", "dirname"))
  expect_identical(vapply(nc$excluded, `[[`, character(1), "type"), "dns")
  expect_identical(
    nc$permitted[[which(types == "dns")]]$value, "example.org")
  # the leaf's own names, for the constraint to bite on
  leaf <- cert_parse(f$nc_leaf_good)
  san <- vapply(leaf$san, `[[`, character(1), "type")
  expect_setequal(san, c("dns", "email"))
})

test_that("the matching rules differ by name type, as the RFC says", {
  # DNS: a constraint covers the name itself and anything under it
  expect_true(.rmbl_nc_match_dns("example.org", "example.org"))
  expect_true(.rmbl_nc_match_dns("host.example.org", "example.org"))
  expect_true(.rmbl_nc_match_dns("HOST.EXAMPLE.ORG", "example.org"))
  # and must not match a name that merely ends with the same letters
  expect_false(.rmbl_nc_match_dns("notexample.org", "example.org"))
  expect_false(.rmbl_nc_match_dns("example.org.evil.com", "example.org"))
  # a dot-prefixed constraint is subdomains only
  expect_false(.rmbl_nc_match_dns("example.org", ".example.org"))
  expect_true(.rmbl_nc_match_dns("host.example.org", ".example.org"))

  # email: a host constraint is NOT satisfied by a subdomain, which is
  # where reusing the DNS rule would be too permissive
  expect_true(.rmbl_nc_match_email("a@example.org", "example.org"))
  expect_false(.rmbl_nc_match_email("a@sub.example.org", "example.org"))
  expect_true(.rmbl_nc_match_email("a@sub.example.org", ".example.org"))
  expect_true(.rmbl_nc_match_email("a@example.org", "a@example.org"))
  expect_false(.rmbl_nc_match_email("b@example.org", "a@example.org"))

  # IP: the constraint is address then mask
  v4 <- as.raw(c(192, 168, 5, 9))
  expect_true(.rmbl_nc_match_ip(v4, as.raw(c(192, 168, 0, 0,
                                             255, 255, 0, 0))))
  expect_false(.rmbl_nc_match_ip(v4, as.raw(c(10, 0, 0, 0,
                                              255, 0, 0, 0))))
  # a mask of the wrong width is not a match rather than an error
  expect_false(.rmbl_nc_match_ip(v4, as.raw(c(192, 168, 0, 0))))

  # URI matching goes on the host
  expect_true(.rmbl_nc_match_uri("http://host.example.org/x",
                                 "example.org"))
  expect_false(.rmbl_nc_match_uri("http://evil.com/x", "example.org"))
  expect_true(.rmbl_nc_match_uri("https://u:p@host.example.org:8443/a",
                                 "example.org"))
})

test_that("a constrained CA cannot issue outside its name space", {
  f <- x509_fx()
  ca <- cert_parse(f$nc_ca)
  at <- ca$not_before + 86400
  # openssl verify accepts this one and rejects the rest
  good <- cert_chain_verify(f$nc_leaf_good, trust = ca, at_time = at)
  expect_true(good$ok)
  expect_true(all(good$checks$ok))

  for (nm in c("nc_leaf_outside", "nc_leaf_excluded", "nc_leaf_baddn")) {
    r <- cert_chain_verify(f[[nm]], trust = ca, at_time = at)
    expect_false(r$ok, info = nm)
    bad <- r$checks[!r$checks$ok, ]
    expect_true(any(grepl("name constraints", bad$check)), info = nm)
  }
  # the reason is reported, not just the verdict
  out <- cert_chain_verify(f$nc_leaf_outside, trust = ca, at_time = at)
  expect_match(out$checks$detail[grepl("name constraints",
                                       out$checks$check)],
               "outside every permitted subtree")
  exc <- cert_chain_verify(f$nc_leaf_excluded, trust = ca, at_time = at)
  expect_match(exc$checks$detail[grepl("name constraints",
                                       exc$checks$check)],
               "excluded subtree")
})

test_that("certificate policies are processed and can be required", {
  f <- x509_fx()
  ca <- cert_parse(f$pol_ca)
  at <- ca$not_before + 86400
  want <- "1.2.3.4.100"

  ok <- cert_chain_verify(f$pol_leaf_ok, trust = ca, at_time = at,
                          policies = want)
  expect_true(ok$ok)
  # anyPolicy asserts whatever is still valid, so it satisfies the ask
  any_ok <- cert_chain_verify(f$pol_leaf_any, trust = ca, at_time = at,
                              policies = want)
  expect_true(any_ok$ok)
  # a different policy does not, and neither does none at all
  for (nm in c("pol_leaf_other", "pol_leaf_none")) {
    r <- cert_chain_verify(f[[nm]], trust = ca, at_time = at,
                           policies = want)
    expect_false(r$ok, info = nm)
    expect_false(r$checks$ok[r$checks$check == "certificate policies"],
                 info = nm)
  }
  # with nothing required, policies are not a reason to fail
  expect_true(cert_chain_verify(f$pol_leaf_other, trust = ca,
                                at_time = at)$ok)
  expect_false(any(cert_chain_verify(f$pol_leaf_other, trust = ca,
                                     at_time = at)$checks$check ==
                     "certificate policies"))
  # the surviving set is reported
  expect_identical(ok$policies$authorities_constrained_to, want)
})

test_that("the policy state machine honours its counters", {
  # These are unit tests on the tree rather than on certificates,
  # because building a certificate for every combination of three
  # counters is a lot of OpenSSL for arithmetic that can be checked
  # directly.
  anyp <- "2.5.29.32.0"
  anchor <- list(policies = character(0))
  mk <- function(...) utils::modifyList(
    list(policies = character(0), policy_mappings = NULL,
         require_explicit_policy = NA_integer_,
         inhibit_policy_mapping = NA_integer_,
         inhibit_any_policy = NA_integer_), list(...))

  # a path that agrees on one policy keeps it
  t1 <- .rmbl_policy_tree(list(mk(policies = "1.2.3"), anchor),
                          initial = "1.2.3")
  expect_identical(t1$authorities_constrained_to, "1.2.3")
  expect_true(t1$ok)

  # requireExplicitPolicy:0 at the anchor makes an empty policy set fatal
  t2 <- .rmbl_policy_tree(
    list(mk(policies = character(0)),
         mk(require_explicit_policy = 0L)),
    initial = anyp)
  expect_true(t2$explicit_required)
  expect_false(t2$ok)

  # mapping renames a policy as the path descends
  t3 <- .rmbl_policy_tree(
    list(mk(policies = "9.9.9"),
         mk(policies = "1.2.3",
            policy_mappings = list(list(issuer = "1.2.3",
                                        subject = "9.9.9"))),
         anchor),
    initial = "9.9.9")
  expect_true("9.9.9" %in% t3$valid)

  # mapping to or from anyPolicy is forbidden and empties the set
  t4 <- .rmbl_policy_tree(
    list(mk(policies = "1.2.3"),
         mk(policies = "1.2.3",
            policy_mappings = list(list(issuer = "1.2.3",
                                        subject = anyp))),
         anchor),
    initial = "1.2.3")
  expect_length(t4$valid, 0L)
  expect_true(any(grepl("anyPolicy", t4$notes)))
})

test_that("the OCSP request is the one OpenSSL builds", {
  f <- x509_fx()
  leaf <- cert_parse(f$nc_aia)
  ca <- cert_parse(f$nc_ca)
  req <- .rmbl_ocsp_request(leaf, ca)
  # Byte equality with `openssl ocsp -reqout` checks the DER encoder,
  # the CertID structure, and the SHA-1 over the issuer's encoded name
  # and public key all at once. A responder keys on exactly these
  # bytes, so anything else gets "unauthorized".
  expect_identical(req, f$ocsp_request)

  # the distribution point and responder URLs are read out, and only
  # http ones: following an ldap or file URL from the certificate being
  # checked would be taking instructions from it
  expect_identical(.rmbl_crl_urls(leaf), "http://crl.example.org/root.crl")
  expect_identical(.rmbl_ocsp_urls(leaf),
                   "http://ocsp.example.org/responder")
  expect_length(.rmbl_crl_urls(ca), 0L)
})

test_that("a revoked certificate is caught, and fetching is opt-in", {
  f <- x509_fx()
  ca <- cert_parse(f$nc_ca)
  at <- ca$not_before + 86400
  r <- cert_chain_verify(f$nc_leaf_good, trust = ca, at_time = at,
                         crls = f$nc_crl)
  expect_false(r$ok)
  rev <- r$checks[grepl("revocation", r$checks$check), ]
  expect_false(rev$ok[1])
  expect_match(rev$detail[1], "is on a CRL")

  # revocation = "none" skips it even with a CRL in hand
  skipped <- cert_chain_verify(f$nc_leaf_good, trust = ca, at_time = at,
                               crls = f$nc_crl, revocation = "none")
  expect_true(skipped$ok)
  expect_false(any(grepl("revocation", skipped$checks$check)))

  # and the default never reaches the network: with no CRL supplied
  # there is no revocation row at all, rather than a silent pass
  bare <- cert_chain_verify(f$nc_leaf_good, trust = ca, at_time = at)
  expect_false(any(grepl("revocation|crl fetch|ocsp", bare$checks$check)))
  expect_error(cert_chain_verify(f$nc_leaf_good, trust = ca,
                                 revocation = "sometimes"), "arg")
})

test_that("SHA-1 matches its FIPS vectors", {
  # present only for OCSP CertID, never for a signature
  expect_identical(
    .rmbl_hexlify(.Call(C_rmbl_sha1, charToRaw("abc"))),
    "a9993e364706816aba3e25717850c26c9cd0d89d")
  expect_identical(
    .rmbl_hexlify(.Call(C_rmbl_sha1, raw(0))),
    "da39a3ee5e6b4b0d3255bfef95601890afd80709")
  # both sides of the padding boundary
  expect_identical(
    .rmbl_hexlify(.Call(C_rmbl_sha1, charToRaw(strrep("a", 55)))),
    "c1c8bbdc22796e28c0e15163d20899b65621d65a")
  expect_identical(
    .rmbl_hexlify(.Call(C_rmbl_sha1, charToRaw(strrep("a", 56)))),
    "c2db330f6083854c99d4b5bfb6e8f29f201be699")
})
