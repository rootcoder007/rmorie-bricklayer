# SPDX-License-Identifier: AGPL-3.0-or-later
# SIU core: schema fields asserted against the synthetic report fixture.
# Fully offline.

fixture <- system.file("extdata", "siu_synthetic_report.html",
                       package = "rmoriebricklayer")

test_that("schema is the 16 reviewed fields with count flags", {
  sch <- bricklayer_siu_schema()
  expect_equal(nrow(sch), 16L)
  expect_true(sch$is_count[sch$name == "number_of_subject_officers"])
  expect_false(sch$is_count[sch$name == "directors_name"])
})

test_that("parser extracts the key fields from the synthetic report", {
  f <- bricklayer_parse_siu(fixture)
  expect_equal(unname(f["_language"]), "en")
  expect_equal(unname(f["police_service"]), "Barrie Police Service")
  expect_equal(unname(f["date_of_incident_iso"]), "2023-01-05")
  expect_equal(unname(f["date_siu_notified_iso"]), "2023-01-06")
  expect_equal(unname(f["date_of_director_decision_iso"]), "2023-04-28")
  expect_equal(unname(f["number_of_subject_officers"]), "2")
  expect_equal(unname(f["number_of_witness_officials"]), "3")
  expect_equal(unname(f["number_of_civilian_witnesses"]), "2")
  expect_equal(unname(f["directors_name"]), "Joseph Martino")
  expect_match(unname(f["specific_injuries"]), "fractured left arm")
})

test_that("raw HTML input works the same as a file path", {
  html <- paste(readLines(fixture, warn = FALSE), collapse = "\n")
  expect_equal(bricklayer_parse_siu(html)[["directors_name"]],
               "Joseph Martino")
})

test_that("SO resolver applies rules in order", {
  expect_equal(bricklayer_siu_resolve_so(
    "SO #1 Interviewed\nSO #2 Declined\nSO #3 Interviewed")$count, 3L)
  expect_equal(bricklayer_siu_resolve_so(
    "The SO was interviewed. WO #1 is not a subject official.")$count, 1L)
  expect_equal(bricklayer_siu_resolve_so(
    "No subject official was designated.")$count, 0L)
  expect_true(is.na(bricklayer_siu_resolve_so(
    "The report discusses the incident only.")$count))
})

test_that("date helper handles both human forms and garbage", {
  expect_equal(bricklayer_siu_iso_date(c("January 5, 2023", "junk")),
               c("2023-01-05", ""))
})
