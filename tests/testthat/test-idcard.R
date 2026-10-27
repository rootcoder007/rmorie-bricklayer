# SPDX-License-Identifier: AGPL-3.0-or-later

# Identity cards: a key, the name and identifiers it vouches for, self-signed.

id_key <- function() fipskg("ML-DSA-44", seed = as.raw(1:32))

test_that("a card is made, written, read back and verified", {
  key <- id_key()
  f <- withr::local_tempfile(fileext = ".json")
  made <- idcrd(
    key,
    "Ada Lovelace",
    orcid = "https://orcid.org/0000-0002-1825-0097",
    email = "ada@example.org",
    url = "https://example.org/ada",
    affil = "Analytical Engines",
    file = f
  )
  expect_s3_class(made, "rmbl_id_card")
  expect_identical(made$orcid, "0000-0002-1825-0097")
  card <- idcrdrd(f)
  expect_identical(card$fingerprint, made$fingerprint)
  expect_match(card$fingerprint, "^([0-9A-F]{4} ){15}[0-9A-F]{4}$")
  res <- idcrdvrf(
    f,
    fpr = gsub(" ", "", tolower(card$fingerprint), fixed = TRUE)
  )
  expect_true(res$ok)
  expect_identical(
    res$checks$check,
    c(
      "card_complete",
      "card_type",
      "signature",
      "in_date",
      "orcid",
      "fingerprint"
    )
  )
  expect_output(print(card), "Identity card")
  expect_output(print(res), "verified")
})

test_that("a changed card, a wrong fingerprint and an old card fail", {
  key <- id_key()
  card <- idcrd(key, "Ada Lovelace", days = 30)
  bad <- card
  bad$name <- "Someone Else"
  r <- idcrdvrf(bad)
  expect_false(r$ok)
  expect_false(r$checks$ok[r$checks$check == "signature"])
  expect_match(
    r$checks$detail[r$checks$check == "signature"],
    "changed after signing"
  )
  other <- idcrd(fipskg("ML-DSA-44", seed = as.raw(32:1)), "Ada Lovelace")
  w <- idcrdvrf(card, fpr = other$fingerprint)
  expect_false(w$ok)
  expect_match(w$checks$detail[w$checks$check == "fingerprint"], "NOT the one")
  late <- idcrdvrf(card, at = Sys.time() + 40 * 86400)
  expect_false(late$checks$ok[late$checks$check == "in_date"])
  early <- idcrdvrf(card, at = "2000-01-01")
  expect_false(early$ok)
  expect_output(print(late), "NOT verified")
})

test_that("an attestation or a bundle is checked against the card's key", {
  key <- id_key()
  card <- idcrd(key, "Ada Lovelace")
  man <- mkmnf(list(project = "demo"), env = FALSE)
  mine <- cpsatst(man, key)
  expect_true(idcrdvrf(card, atst = mine)$ok)
  expect_true(idcrdvrf(card, atst = list(attestation = mine))$ok)
  theirs <- cpsatst(man, fipskg("ML-DSA-44", seed = as.raw(32:1)))
  r <- idcrdvrf(card, atst = theirs)
  expect_false(r$ok)
  expect_match(
    r$checks$detail[r$checks$check == "signed_by_card"],
    "different key"
  )
  expect_error(idcrdvrf(card, atst = list(a = 1)), "must be an attestation")
})

test_that("an XMSS key makes a card too", {
  # a fresh key is in this session's used-index record (helper-xmss.R)
  key <- pqckg(height = 2L)
  card <- idcrd(key, "Ada Lovelace")
  expect_identical(card$scheme, "xmss-sha256")
  expect_true(idcrdvrf(card)$ok)
})

test_that("bad keys and fields are refused", {
  key <- id_key()
  expect_error(idcrd("secret", "Ada"), "private signing key")
  expect_error(idcrd(fipspubkey(key), "Ada"), "private signing key")
  expect_error(idcrd(key, NULL), "`name` must be one non-empty string")
  expect_error(idcrd(key, ""), "`name` must be one non-empty string")
  expect_error(idcrd(key, "Ada", email = 1), "`email` must be one")
  expect_error(
    idcrd(key, "Ada", orcid = "0000-0002-1825-0098"),
    "wrong check digit"
  )
  expect_error(idcrd(key, "Ada", orcid = "1234"), "must look like")
  expect_error(idcrd(key, "Ada", email = "nobody"), "not an e-mail address")
  expect_error(idcrd(key, "Ada", url = "http://x.org"), "https://")
  expect_error(idcrd(key, "Ada", days = 0), "positive whole number")
  expect_error(idcrd(key, "Ada", days = 1.5), "positive whole number")
  f <- withr::local_tempfile(fileext = ".json")
  writeLines("{\"type\": \"something else\"}", f)
  expect_error(idcrdrd(f), "not an identity card")
  expect_error(idcrdvrf(idcrd(key, "Ada"), fpr = 1), "`fpr` must be one")
  expect_error(
    idcrdvrf(idcrd(key, "Ada"), at = "not a time"),
    "must be one time"
  )
})

test_that("ORCID check digits follow ISO 7064 MOD 11-2", {
  expect_true(.bl_id_orcid_ok("0000-0002-1825-0097"))
  expect_true(.bl_id_orcid_ok("0000-0001-5109-3700"))
  expect_true(.bl_id_orcid_ok("0000-0002-1694-233X"))
  expect_false(.bl_id_orcid_ok("0000-0002-1694-2330"))
})

test_that("a card with an unusable key or none says why", {
  expect_identical(.bl_id_fpr(list()), "")
  card <- idcrd(id_key(), "Ada Lovelace")
  bad <- card
  bad$public <- "00"
  r <- idcrdvrf(bad)
  expect_false(r$checks$ok[r$checks$check == "signature"])
  expect_match(r$checks$detail[r$checks$check == "signature"],
    "not usable for this scheme", fixed = TRUE)
})
