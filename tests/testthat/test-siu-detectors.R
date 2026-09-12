# The SIU parser's individual field detectors, on the inputs the shipped
# synthetic fixture does not contain: the abbreviation fallback for the
# police service, the non-City location forms, each injury verb and body
# part, multiple statutes, both charge outcomes, the inline signature
# form, French and unrecognised reports, and the date parser's edges.
#
# Every input below is invented for the test. None is a real report, and
# the names are fictional.
#
# The parser is a deterministic text parser, so the anchor is what the
# documented rule says the field should be -- read off the rule, not off
# the parser's own output.

parse_text <- function(body) {
  # the parser accepts raw HTML; wrap the body so html_to_text runs
  bricklayer_parse_siu(paste0("<html><body><p>", body, "</p></body></html>"))
}

test_that("the police service falls back to the force abbreviations", {
  # With no "<Name> Police Service" phrase anywhere, the abbreviation
  # table is the only way to identify the force.
  for (pair in list(c("OPP", "Ontario Provincial Police"),
                    c("TPS", "Toronto Police Service"),
                    c("RCMP", "RCMP"),
                    c("NRPS", "Niagara Regional Police Service"))) {
    body <- paste0("The Investigation\nSubject Officers\n",
                   "Officers of the ", pair[1], " attended the scene.")
    expect_equal(unname(parse_text(body)["police_service"]), pair[2])
  }
  # a spelled-out service beats the abbreviation, because the
  # most-frequent full name wins before the table is consulted
  named <- paste0("The Investigation\nSubject Officers\n",
                  "Lakeshore Police Service responded. ",
                  "Lakeshore Police Service later notified the SIU. ",
                  "An OPP unit assisted.")
  expect_equal(unname(parse_text(named)["police_service"]),
               "Lakeshore Police Service")
  # the most frequent name wins over a one-off mention
  two <- paste0("The Investigation\nSubject Officers\n",
                "Riverton Police Service attended. ",
                "Riverton Police Service secured the scene. ",
                "Hillcrest Police Service was not involved.")
  expect_equal(unname(parse_text(two)["police_service"]),
               "Riverton Police Service")
  # a leading connective captured by the greedy prefix is stripped
  lead <- paste0("The Investigation\nSubject Officers\n",
                 "The Northvale Police Service attended the scene. ",
                 "The Northvale Police Service filed a report.")
  expect_false(grepl("^The ", unname(parse_text(lead)["police_service"])))
  expect_match(unname(parse_text(lead)["police_service"]), "Northvale")
  # nothing identifiable leaves the field empty rather than guessing
  none <- "The Investigation\nSubject Officers\nNo force is named here."
  expect_equal(unname(parse_text(none)["police_service"]), "")
})

test_that("the location detector handles every municipal form", {
  for (kind in c("Township", "City", "Town", "Municipality", "Region")) {
    body <- paste0("The Investigation\nSubject Officers\n",
                   "The incident occurred in the ", kind,
                   " of Elmwood, shortly after midnight.")
    expect_equal(unname(parse_text(body)["location_of_call"]),
                 paste0(kind, " of Elmwood"))
  }
  # a phrase wrapped mid-sentence still matches, because the text is
  # flattened before the pattern runs -- report HTML wraps lines inside
  # a phrase and a space-separated pattern would otherwise miss it
  wrapped <- paste0("The Investigation\nSubject Officers\n",
                    "The incident occurred in the City of\nElmwood on a",
                    " Tuesday.")
  expect_equal(unname(parse_text(wrapped)["location_of_call"]), "City of Elmwood")
  # the terminator can be a comma, a full stop, or a following preposition
  for (tail in c(", late at night.", ". Officers attended.",
                 " when officers arrived.", " at first light.",
                 " on the following day.")) {
    body <- paste0("The Investigation\nSubject Officers\n",
                   "It happened in the Town of Fairhaven", tail)
    expect_equal(unname(parse_text(body)["location_of_call"]), "Town of Fairhaven")
  }
  # a hyphenated place name survives
  hyph <- paste0("The Investigation\nSubject Officers\n",
                 "in the City of Stoney-Brook, at dusk.")
  expect_equal(unname(parse_text(hyph)["location_of_call"]),
               "City of Stoney-Brook")
  # no location phrase leaves it empty
  expect_equal(unname(parse_text(
    "The Investigation\nSubject Officers\nNo place is given.")["location_of_call"]),
    "")
})

test_that("age and sex are read from the descriptive phrase", {
  for (noun in c("woman", "man", "female", "male", "girl", "boy",
                 "person", "individual", "youth", "child", "adult")) {
    body <- paste0("The Investigation\nSubject Officers\n",
                   "The Complainant is a 34-year-old ", noun, ".")
    f <- parse_text(body)
    expect_equal(unname(f["age_affected"]), "34")
    expect_equal(unname(f["sex_gender_affected"]), noun)
  }
  # spaces instead of hyphens, and mixed case
  spaced <- parse_text(paste0("The Investigation\nSubject Officers\n",
                              "a 7 year old Child was present."))
  expect_equal(unname(spaced["age_affected"]), "7")
  expect_equal(unname(spaced["sex_gender_affected"]), "child")
  # a three-digit age is still read
  old <- parse_text(paste0("The Investigation\nSubject Officers\n",
                           "a 101-year-old woman"))
  expect_equal(unname(old["age_affected"]), "101")
  # no such phrase leaves both empty
  none <- parse_text("The Investigation\nSubject Officers\nNo age given.")
  expect_equal(unname(none["age_affected"]), "")
  expect_equal(unname(none["sex_gender_affected"]), "")
})

test_that("specific injuries are matched by verb and body part", {
  for (verb in c("fractured", "fracture", "broken", "lacerated",
                 "gunshot", "stabbed", "burns")) {
    for (part in c("rib", "leg", "arm", "skull", "wrist", "ankle",
                   "jaw", "nose", "spine")) {
      body <- paste0("The Investigation\nSubject Officers\n",
                     "Nature of Injuries\nThe Complainant had a ",
                     verb, " right ", part, " confirmed at hospital.")
      got <- unname(parse_text(body)["specific_injuries"])
      expect_match(got, part)
      expect_true(nzchar(got))
    }
  }
  # the match is case-insensitive
  expect_match(unname(parse_text(paste0(
    "The Investigation\nSubject Officers\n",
    "A BROKEN LEG was diagnosed."))["specific_injuries"]), "LEG")
  # an injury with no recognised body part is not reported, rather than
  # a partial phrase being invented
  expect_equal(unname(parse_text(paste0(
    "The Investigation\nSubject Officers\n",
    "The Complainant was bruised."))["specific_injuries"]), "")
})

test_that("multiple statutes are collected and de-duplicated", {
  body <- paste0(
    "The Investigation\nSubject Officers\n",
    "Relevant Legislation\n",
    "Section 25(1), Criminal Code -- Protection of persons\n",
    "Section 34, Criminal Code -- Defence of person\n",
    "Section 320.13, Highway Traffic Act -- Dangerous driving\n",
    "Analysis and Director's Decision\n",
    "No charges shall issue.")
  got <- unname(parse_text(body)["relevant_legislation"])
  # each distinct act appears once, joined by a semicolon
  expect_match(got, "Criminal Code")
  expect_match(got, "Highway Traffic Act")
  expect_equal(length(gregexpr("Criminal Code", got)[[1]]), 1L)
  expect_match(got, ";")
  # no legislation section leaves the field empty
  expect_equal(unname(parse_text(
    "The Investigation\nSubject Officers\nNothing here.")[
      "relevant_legislation"]), "")
})

test_that("the charge outcome reads both decisions", {
  header <- "The Investigation\nSubject Officers\n"
  # every documented no-charge phrasing resolves to FALSE
  for (phrase in c("no charges shall issue",
                   "there is no basis for charges",
                   "no reasonable grounds exist",
                   "I do not lay charges",
                   "I decline to lay a charge",
                   "the grounds lack the necessary grounds")) {
    body <- paste0(header, "Analysis and Director's Decision\n",
                   "Having reviewed the evidence, ", phrase, ".")
    expect_equal(unname(parse_text(body)["charges_recommended"]), "FALSE")
  }
  # and the charge phrasings to TRUE
  for (phrase in c("the officer was charged with assault",
                   "criminal charges have been laid",
                   "charges have been laid against the official")) {
    body <- paste0(header, "Analysis and Director's Decision\n", phrase, ".")
    expect_equal(unname(parse_text(body)["charges_recommended"]), "TRUE")
  }
  # a no-charge phrase takes precedence, since it is checked first and a
  # report that says both is a report declining to charge
  both <- paste0(header, "Analysis and Director's Decision\n",
                 "No charges shall issue; no one was charged with anything.")
  expect_equal(unname(parse_text(both)["charges_recommended"]), "FALSE")
  # a decision section with neither phrasing is left empty
  expect_equal(unname(parse_text(paste0(
    header, "Analysis and Director's Decision\n",
    "The matter is closed."))["charges_recommended"]), "")
  # the curly-apostrophe spelling of the header is recognised too
  curly <- paste0(header, "Analysis and Director’s Decision\n",
                  "No charges shall issue.")
  expect_equal(unname(parse_text(curly)["charges_recommended"]), "FALSE")
})

test_that("the director's name is read from either signature form", {
  header <- "The Investigation\nSubject Officers\n"
  # the block form
  block <- paste0(header, "Dated at Toronto.\n\nAlex Morrow\nDirector\n",
                  "Special Investigations Unit")
  expect_equal(unname(parse_text(block)["directors_name"]), "Alex Morrow")
  # the inline form
  inline <- paste0(header, "Signed by Jordan Vale, Director")
  expect_equal(unname(parse_text(inline)["directors_name"]), "Jordan Vale")
  # a three-part name
  three <- paste0(header, "Mary Anne Fielding\nDirector")
  expect_equal(unname(parse_text(three)["directors_name"]),
               "Mary Anne Fielding")
  # a name containing "the" is rejected as boilerplate rather than
  # reported as a person
  boiler <- paste0(header, "Report of the Director")
  expect_equal(unname(parse_text(boiler)["directors_name"]), "")
  # no signature leaves it empty
  expect_equal(unname(parse_text(paste0(header, "No signature."))[
    "directors_name"]), "")
})

test_that("the language detector needs two markers to commit", {
  # two or more English markers, and more of them than French
  en <- paste0("The Investigation\nSubject Officers\n",
               "Civilian Witnesses\nWitness Officers\n")
  expect_equal(unname(parse_text(en)["_language"]), "en")
  # two or more French markers
  fr <- paste0("L'enquête\nTémoins civils\n",
               "Agents impliqués\nExercice du mandat\n")
  expect_equal(unname(parse_text(fr)["_language"]), "fr")
  # a single marker is not enough to commit either way
  one <- "The Investigation\nnothing else recognisable"
  expect_equal(unname(parse_text(one)["_language"]), "unknown")
  # no markers at all
  expect_equal(unname(parse_text("Plain prose with no headings.")[
    "_language"]), "unknown")
  # a tie commits to neither
  tie <- paste0("The Investigation\nWitness Officers\n",
                "L'enquête\nTémoins civils\n")
  expect_equal(unname(parse_text(tie)["_language"]), "unknown")
})

test_that("the date parser handles its edges", {
  # the human form
  expect_equal(bricklayer_siu_iso_date("January 5, 2023"), "2023-01-05")
  expect_equal(bricklayer_siu_iso_date("December 31, 1999"), "1999-12-31")
  # without the comma
  expect_equal(bricklayer_siu_iso_date("March 7 2021"), "2021-03-07")
  # every month name
  months <- c("January", "February", "March", "April", "May", "June",
              "July", "August", "September", "October", "November",
              "December")
  for (i in seq_along(months)) {
    expect_equal(bricklayer_siu_iso_date(paste(months[i], "1, 2020")),
                 sprintf("2020-%02d-01", i))
  }
  # already-ISO input passes through unchanged
  expect_equal(bricklayer_siu_iso_date("2023-04-28"), "2023-04-28")
  # anything unparseable is empty rather than a guess
  expect_equal(bricklayer_siu_iso_date("sometime last spring"), "")
  expect_equal(bricklayer_siu_iso_date(""), "")
  expect_equal(bricklayer_siu_iso_date("2023/04/28"), "")
  # a date embedded in a sentence is still found
  expect_equal(bricklayer_siu_iso_date("dated at Toronto on May 9, 2022"),
               "2022-05-09")
})

test_that("html_to_text strips markup and decodes entities", {
  t <- bricklayer_siu_text(
    "<html><head><style>p{color:red}</style></head><body>x</body></html>")
  expect_type(t, "character")
  # tags are removed and text survives
  plain <- bricklayer_siu_text("<p>Hello <b>there</b></p>")
  expect_match(plain, "Hello")
  expect_match(plain, "there")
  expect_false(grepl("<", plain, fixed = TRUE))
  # entities are decoded
  ent <- bricklayer_siu_text("<p>Smith &amp; Jones &lt;note&gt; &nbsp;end</p>")
  expect_match(ent, "&", fixed = TRUE)
  expect_match(ent, "<note>", fixed = TRUE)
  # script and style content is not text
  noscript <- bricklayer_siu_text(
    "<p>keep</p><script>var x = 'drop';</script>")
  expect_match(noscript, "keep")
  expect_false(grepl("var x", noscript, fixed = TRUE))
})

test_that("the officer and witness counts read their own labels", {
  body <- paste0(
    "The Investigation\n",
    "The Team\n",
    "Number of SIU Investigators assigned: 4\n",
    "Number of SIU Forensic Investigators assigned: 2\n",
    "Subject Officials\nSO #1 Interviewed\nSO #2 Declined\n",
    "Witness Officials\nWO #1 Interviewed\nWO #2 Interviewed\n",
    "WO #3 Interviewed\n",
    "Civilian Witnesses\nCW #1 Interviewed\n")
  f <- parse_text(body)
  expect_equal(unname(f["number_of_subject_officers"]), "2")
  expect_equal(unname(f["number_of_witness_officials"]), "3")
  expect_equal(unname(f["number_of_civilian_witnesses"]), "1")

  # ZERO is a real answer, not a missing one: a witness-officer-only case
  # genuinely has no subject official, and the schema flags these fields
  # as counts for exactly that reason
  none <- paste0("The Investigation\n",
                 "Witness Officials\nWO #1 Interviewed\n",
                 "Civilian Witnesses\nCW #1 Interviewed\n")
  sch <- bricklayer_siu_schema()
  expect_true(sch$is_count[sch$name == "number_of_subject_officers"])
  expect_equal(unname(parse_text(none)["number_of_witness_officials"]), "1")
})
