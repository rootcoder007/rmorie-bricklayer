# Input contracts found by the degenerate-input sweep of 2026-09-18: every
# call here used to return a value that looked like an answer.

test_that("numeric kernels refuse non-numeric input instead of coercing", {
  for (f in list(cmn, cvari, csdev, cmed, cmad, ciqr,
                 cmom, cqnt, ctrmmean,
                 cwinsmean, ctkyfnc, cmidrk,
                 cbootmean, inlhist, cnormpdf,
                 cnormlpdf, hurwzeta)) {
    expect_error(f("abc"), "must be numeric")
    expect_error(f(list(1, 2)), "must be numeric")
    expect_error(f(data.frame(a = 1)), "must be numeric")
  }
  expect_error(ccorr("a", "b"), "must be numeric")
  expect_error(cspr("a", "b"), "must be numeric")
  expect_error(cdistm("a", "b"), "must be numeric")
  expect_error(cwtd("a", 1), "must be numeric")
  expect_error(cipw("a", 0.5), "must be numeric")
  expect_true(is.nan(cmn(numeric(0))))
  expect_true(is.na(cmn(c(1, NA))))
  expect_equal(cmn(c(TRUE, FALSE)), 0.5)
})

test_that("drift screens, Benford and concentration need real samples", {
  expect_error(drftks(numeric(0), 1:5), "at least one non-missing")
  expect_error(drftpsi(1:5, numeric(0)), "at least one non-missing")
  expect_error(drftks(c(1, Inf, 2), c(1, 2, 3)), "finite")
  expect_error(drftks("a", 1:5), "must be numeric")
  expect_error(benfordtst("x"), "must be numeric")
  expect_error(ginicoef(numeric(0)), "no values")
  expect_error(ginicoef(Inf), "finite")
  expect_error(lorenzc(c(1, -2)), "non-negative")
  expect_error(topshr(NaN, 0.1), "no values")
  expect_error(cramerv(NA), "finite non-negative")
  expect_error(cramerv(matrix(c(1, -1, 2, 3), 2)), "finite non-negative")
  expect_error(expcnts(Inf, 1, "a"), "finite")
  expect_error(fnllim(numeric(0)), "at least one non-missing")
  expect_error(stdinc("x", 1), "must be numeric")
})

test_that("sketch registers are validated", {
  expect_error(dstncnt(-1), "non-negative integer")
  expect_error(dstncnt(c(1.5, 2)), "non-negative integer")
  expect_error(skchmrg("", ""), "must be numeric")
  expect_equal(dstncnt(integer(0)), 0)
  s <- dstnskch(c("a", "b", "a"))
  expect_equal(round(dstncnt(s)), 2)
  expect_equal(dstncnt(NULL), 0)
})

test_that("hashes treat NA as NA and signatures need text or bytes", {
  expect_true(is.na(ccrc32(NA)))
  expect_true(is.na(csha512(NA)))
  expect_true(is.na(cblake2b(NA)))
  expect_true(is.na(csha256(NA)))
  expect_equal(csha512(c("a", NA))[1], csha512("a"))
  expect_error(chmac(-1, "m"), "character or raw")
  expect_error(drvkey(1, 2), "character or raw")
  expect_error(cpssign(-1, "k"), "character or raw")
  expect_error(jsb64udec(-1), "must be character")
  expect_error(jsb64udec("not base64!"), "not base64url")
})

test_that("stock-and-flow measures need finite dates and quantities", {
  expect_error(adp(Inf), "finite")
  expect_error(alos(Inf, 1), "finite")
  expect_error(admits(Inf, Inf), "finite")
  expect_error(stkflow(Inf, 1), "finite")
  expect_error(perdays(-1, -1), "dates")
  expect_error(adp("3"), "must be numeric")
})

test_that("parsers, rules, manifests and guards refuse wrong input", {
  expect_error(prsbands(-1), "character band labels")
  expect_error(bandvals(NA), "character band labels")
  expect_error(fylbl(-1), "positive")
  expect_error(fylbl(list()), "numeric or character")
  for (f in list(rulenull, ruleuniq, ruleincr,
                 rulemad)) {
    expect_error(f(NULL), "single non-empty string")
    expect_error(f(-1), "single non-empty string")
  }
  expect_error(rulebtw(NULL, 0, 1), "single non-empty string")
  expect_error(ruleinset(Inf, "a"), "single non-empty string")
  expect_error(rulerx(NaN, "a"), "single non-empty string")
  expect_error(mkmnf(-1), "must be a list")
  expect_error(mnfcanon(NA), "must be a list")
  expect_error(mnfdgst(NULL), "must be a list")
  expect_error(vrfrcd(NULL, NULL, c(a = "b")), "atomic vectors")
  expect_error(grdbin(NULL, "d"), "atomic vector")
  expect_error(grdlvls(c("a"), NULL), "non-empty character")
  expect_error(capdeps(-1), "package names")
})

test_that("I/O helpers refuse empty paths and missing capsules", {
  expect_error(fdl("", ""), "single non-empty string")
  expect_error(dldata(NULL, "x"), "single non-empty string")
  expect_error(wbsnpurl(""), "single non-empty string")
  expect_error(wrmnfjs(list(), ""), "single non-empty string")
  expect_error(wrtxtfb("t", ""), "single non-empty string")
  expect_error(vrfcps(""), "single non-empty string")
  expect_error(vrfcps("/no/such/dir/at/all"),
               "not an existing directory")
  expect_error(valsch(NULL, NULL), "data frame")
  expect_error(schval(NULL, NULL), "data frame")
  expect_error(rvkfetch(""), "non-empty list of parsed certificates")
})

test_that("vrfsha256 accepts the digest as provenance JSON delivers it", {
  p <- tempfile()
  writeLines("abc", p)
  h <- sha256file(p)
  expect_true(vrfsha256(p, h)$match)
  expect_true(vrfsha256(p, list(h))$match)
  expect_true(vrfsha256(p, toupper(h))$match)
  expect_false(vrfsha256(p, paste0("0", substr(h, 2, 64)))$match)
  expect_error(vrfsha256(p, c(h, h)), "single SHA-256")
})

test_that("IPW weights refuse non-binary treatment, bad propensities", {
  expect_error(cipw(c(1, 2, 1), c(0.5, 0.5, 0.5)), "coded 0/1")
  expect_error(cipw(c(0, 1), c(-0.2, 0.5)), "\\[0, 1\\]")
  expect_error(cipw(c(0, 1), c(0.5, 1.4)), "\\[0, 1\\]")
  w <- cipw(c(1, NA, 0), c(0.5, 0.5, NA))
  expect_true(is.na(w[2]) && is.na(w[3]))
  expect_equal(w[1], 2)
})

test_that("sir separates excess from deficit and pubbnd labels NA", {
  r <- stdinc(obs = c(5, 30), expd = c(20, 20))
  expect_false(r$excess[1])
  expect_true(r$deficit[1])
  expect_true(r$significant[1])
  expect_true(r$excess[2])
  expect_false(r$deficit[2])
  b <- pubbnd(c(10, NA))
  expect_equal(b$status, c("exact", "missing"))
})

test_that("midranks keep NA in place and registers must be finite", {
  expect_equal(cmidrk(c(3, NA, 1, 3)), c(2.5, NA, 1, 2.5))
  expect_equal(cmidrk(NA), NA_real_)
  expect_error(skchmrg(Inf, Inf), "non-negative integer registers")
  expect_error(dstncnt(c(1, NaN)), "non-negative integer registers")
})
