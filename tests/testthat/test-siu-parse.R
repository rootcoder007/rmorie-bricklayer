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

# -- regression cases from the 2182-report zero-wrong pass ----------------

test_that("glossary note never feeds the zero rule (both era phrasings)", {
  g1 <- paste("A witness officer is a police officer who, in the opinion of",
              "the SIU Director, is involved in the incident under",
              "investigation but is not a subject officer.",
              "The SO was interviewed.")
  expect_equal(bricklayer_siu_resolve_so(g1)$count, 1L)
  g2 <- paste("An official who, in the SIU Director’s opinion, is",
              "involved in the incident under investigation but is not a",
              "subject official. The SO declined an interview.")
  expect_equal(bricklayer_siu_resolve_so(g2)$count, 1L)
})

test_that("ordinals are case-strict, #-required, and roster-anchored", {
  # 'also 59' must not read as SO 59
  r <- bricklayer_siu_resolve_so(
    "The pursuit also 59 seconds later ended. The SO stopped the car.")
  expect_equal(r$count, 1L)
  # lone narrative ordinal without the #1 anchor is another force's shorthand
  r <- bricklayer_siu_resolve_so(
    "WO #6 and SO #7 of the neighbouring service stopped a Jeep. The SO was interviewed.")
  expect_equal(r$count, 1L)
  # a real roster anchors at #1
  r <- bricklayer_siu_resolve_so("SO #1 and SO #2 were interviewed.")
  expect_equal(r$count, 2L)
})

test_that("team section beats narrative and tolerates mislabelled rosters", {
  txt <- paste("Subject Officers SO #1 Declined interview.",
               "SO #1 Declined interview, notes received.",
               "\nIncident Narrative\nOfficers responded.")
  expect_equal(bricklayer_siu_resolve_so(txt)$count, 2L)  # 2 status entries
})

test_that("non-breaking spaces do not blind the scanners", {
  txt <- paste0("Subject Officers SO #1 Declined interview. SO #2 ",
                "Declined interview.")
  expect_equal(bricklayer_siu_resolve_so(txt)$count, 2L)
})

test_that("plural cue and unresolved paths work", {
  expect_equal(bricklayer_siu_resolve_so(
    "The two subject officials responded to the call.")$count, 2L)
  r <- bricklayer_siu_resolve_so("The report discusses the incident only.")
  expect_true(is.na(r$count))
  expect_true(nzchar(r$reason))
})

test_that("bindings validate their inputs", {
  expect_error(bricklayer_siu_text(1L))
  expect_error(bricklayer_siu_resolve_so(NA_character_))
  expect_error(bricklayer_parse_siu(c("a", "b")))
  expect_error(bricklayer_siu_iso_date(5))
})

test_that("fetch_parse_siu fails gracefully when the fetch cannot happen", {
  # invalid drid errors inside bricklayer_fetch_siu -> message + NULL
  expect_message(
    out <- bricklayer_fetch_parse_siu(-1),
    "could not fetch"
  )
  expect_null(out)
})

test_that("the privacy paragraph never counts as a subject mention", {
  txt <- paste("This information may include the Subject Officer name(s)",
               "and other evidence. No subject official was designated.")
  expect_equal(bricklayer_siu_resolve_so(txt)$count, 0L)
})
