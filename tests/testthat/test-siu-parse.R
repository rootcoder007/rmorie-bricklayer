# SPDX-License-Identifier: AGPL-3.0-or-later
# SIU core: schema fields asserted against the synthetic report fixture.
# Fully offline.

fixture <- system.file(
  "extdata",
  "siu_synthetic_report.html",
  package = "rmoriebricklayer"
)

test_that("schema is the 16 reviewed fields with count flags", {
  sch <- siusch()
  expect_identical(nrow(sch), 16L)
  expect_true(sch$count[sch$name == "number_of_subject_officials"])
  expect_false(sch$count[sch$name == "directors_name"])
})

test_that("parser extracts the key fields from the synthetic report", {
  f <- siuprs(fixture)
  expect_identical(unname(f["_language"]), "en")
  expect_identical(unname(f["police_service"]), "Barrie Police Service")
  expect_identical(unname(f["date_of_incident_iso"]), "2023-01-05")
  expect_identical(unname(f["date_siu_notified_iso"]), "2023-01-06")
  expect_identical(unname(f["date_of_director_decision_iso"]), "2023-04-28")
  expect_identical(unname(f["number_of_subject_officials"]), "2")
  expect_identical(unname(f["number_of_witness_officials"]), "3")
  expect_identical(unname(f["number_of_civilian_witnesses"]), "2")
  expect_identical(unname(f["directors_name"]), "Joseph Martino")
  expect_match(unname(f["specific_injuries"]), "fractured left arm")
})

test_that("raw HTML input works the same as a file path", {
  html <- paste(readLines(fixture, warn = FALSE), collapse = "\n")
  expect_identical(siuprs(html)[["directors_name"]], "Joseph Martino")
})

test_that("SO resolver applies rules in order", {
  expect_identical(
    siuso(
      "SO #1 Interviewed\nSO #2 Declined\nSO #3 Interviewed"
    )$count,
    3L
  )
  expect_identical(
    siuso(
      "The SO was interviewed. WO #1 is not a subject official."
    )$count,
    1L
  )
  expect_identical(
    siuso(
      "No subject official was designated."
    )$count,
    0L
  )
  expect_true(is.na(
    siuso(
      "The report discusses the incident only."
    )$count
  ))
})

test_that("date helper handles both human forms and garbage", {
  expect_identical(siudate(c("January 5, 2023", "junk")), c("2023-01-05", ""))
})

# -- regression cases from the 2182-report zero-wrong pass ----------------

test_that("glossary note never feeds the zero rule (both era phrasings)", {
  g1 <- paste(
    "A witness officer is a police officer who, in the opinion of",
    "the SIU Director, is involved in the incident under",
    "investigation but is not a subject officer.",
    "The SO was interviewed."
  )
  expect_identical(siuso(g1)$count, 1L)
  g2 <- paste(
    "An official who, in the SIU Director’s opinion, is",
    "involved in the incident under investigation but is not a",
    "subject official. The SO declined an interview."
  )
  expect_identical(siuso(g2)$count, 1L)
})

test_that("ordinals are case-strict, #-required, and roster-anchored", {
  # 'also 59' must not read as SO 59
  r <- siuso(
    "The pursuit also 59 seconds later ended. The SO stopped the car."
  )
  expect_identical(r$count, 1L)
  # lone narrative ordinal without the #1 anchor is another force's shorthand
  r <- siuso(
    paste0(
      "WO #6 and SO #7 of the neighbouring service stopped a Jeep. The SO ",
      "was interviewed."
    )
  )
  expect_identical(r$count, 1L)
  # a real roster anchors at #1
  r <- siuso("SO #1 and SO #2 were interviewed.")
  expect_identical(r$count, 2L)
})

test_that("team section beats narrative and tolerates mislabelled rosters", {
  txt <- paste(
    "Subject Officers SO #1 Declined interview.",
    "SO #1 Declined interview, notes received.",
    "\nIncident Narrative\nOfficers responded."
  )
  expect_identical(siuso(txt)$count, 2L) # 2 status entries
})

test_that("non-breaking spaces do not blind the scanners", {
  txt <- paste0(
    "Subject Officers SO #1 Declined interview. SO #2 ",
    "Declined interview."
  )
  expect_identical(siuso(txt)$count, 2L)
})

test_that("plural cue and unresolved paths work", {
  expect_identical(
    siuso(
      "The two subject officials responded to the call."
    )$count,
    2L
  )
  r <- siuso("The report discusses the incident only.")
  expect_true(is.na(r$count))
  expect_true(nzchar(r$reason))
})

test_that("bindings validate their inputs", {
  expect_error(siutxt(1L))
  expect_error(siuso(NA_character_))
  expect_error(siuprs(NA_character_), "not NA")
  # several reports parse to one row each
  expect_identical(nrow(siuprs(c("<p>a</p>", "<p>b</p>"))), 2L)
  expect_error(siudate(5))
})

test_that("fetch_parse_siu fails gracefully when the fetch cannot happen", {
  # a fetch that fails (no network, no report) -> message + NULL
  skip_if_cannot_mock()
  local_mocked_bindings(siufetch = function(...) stop("offline"))
  expect_message(
    {
      out <- siufprs(648)
    },
    "could not fetch"
  )
  expect_null(out)
  # an invalid drid is an argument error, before any network
  expect_error(siufprs(-1), "one positive report number")
})

test_that("the privacy paragraph never counts as a subject mention", {
  txt <- paste(
    "This information may include the Subject Officer name(s)",
    "and other evidence. No subject official was designated."
  )
  expect_identical(siuso(txt)$count, 0L)
})

test_that("French dates and accented entities parse", {
  expect_identical(siudate("3 août 2017"), "2017-08-03")
  expect_identical(siudate("1er janvier 2020"), "2020-01-01")
  expect_identical(siudate("August 3, 2017"), "2017-08-03")
  expect_identical(siudate("no date here"), "")
  txt <- siutxt(
    paste0(
      "<p>Director&#039;s report &ndash; Qu&eacute;bec, fran&ccedil;ais ",
      "&#x00e9;t&#233;</p>"
    )
  )
  expect_identical(trimws(txt), "Director's report - Québec, français été")
  # every French month, and numeric entities that need three and four UTF-8
  # bytes
  fr <- c(
    "janvier",
    "février",
    "fevrier",
    "mars",
    "avril",
    "mai",
    "juin",
    "juillet",
    "août",
    "aout",
    "septembre",
    "octobre",
    "novembre",
    "décembre",
    "decembre"
  )
  mo <- c(1, 2, 2, 3, 4, 5, 6, 7, 8, 8, 9, 10, 11, 12, 12)
  for (i in seq_along(fr)) {
    expect_identical(
      siudate(paste("5", fr[i], "2021")),
      sprintf("2021-%02d-05", mo[i])
    )
  }
  # the curly apostrophe folds to a straight one, as the SIU fields expect
  txt <- siutxt("<p>Director&#8217;s &#x20AC;5 &#128512;</p>")
  expect_identical(trimws(txt), "Director's \u20ac5 \U0001F600")
})


test_that(
  paste0(
    "ordinal dates and the police service are read from a report like ",
    "17-OVI-201"
  ),
  {
    html <- paste0(
      "<html><body><h2>The Investigation</h2><h3>Notification of the SIU</h3>",
      "<p>At approximately 11:46 a.m. on August 3rd, 2017, the Guelph ",
      "Police Service ( GPS ) notified the SIU ",
      "of the injury.</p><p>Under the Police Services Act, the Director ",
      "decides. The Ontario Police Services Board ",
      "and the Police Services Act are named again here: Police Services ",
      "Act.</p>",
      "<h2>Incident Narrative</h2><p>The GPS reported that at 10:30 a.m., ",
      "on August 3rd, 2017, three masked men ",
      "attempted to rob a bank.</p></body></html>"
    )
    f <- siuprs(html)
    expect_identical(f[["police_service"]], "Guelph Police Service")
    expect_identical(f[["date_siu_notified_iso"]], "2017-08-03")
    expect_identical(siudate("August 3rd, 2017"), "2017-08-03")
    expect_identical(siudate("June 21st 2019"), "2019-06-21")
  }
)

test_that("data --help exits 0 and an empty fetch URL is refused in words", {
  rec <- new.env()
  rec$out <- character()
  expect_identical(
    blcli(c("data", "--help"), out = function(x) rec$out <- c(rec$out, x)),
    0L
  )
  expect_error(
    blfetch("", tempfile()),
    "`url` must be one non-empty URL string"
  )
  expect_error(
    blfetch("https://example.org", ""),
    "`dest` must be one non-empty file path"
  )
})
