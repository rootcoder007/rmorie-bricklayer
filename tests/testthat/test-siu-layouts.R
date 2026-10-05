# Counts and fields in every report layout: 2020-on English ("Witness Officials ( WO )",
# the singular "Civilian Witness ( CW )"), French ("Agents témoins ( AT )", "AT no 1",
# "AT n o 1"), and the legacy layouts with no role sections. Synthetic pages, written to the
# SIU's layouts.
pg <- function(...) paste0("<html><body>", paste0("<p>", c(...), "</p>", collapse = ""), "</body></html>")

test_that("the 2020-on English layout: abbreviated and singular role headings", {
  p <- bricklayer_parse_siu(pg(
    "The Investigation", "Notification of the SIU", "Mandate Engaged",
    "A person sustains a \"serious injury\" if they suffer a fracture to the skull, or to a limb, rib or vertebra.",
    "special constables of the Niagara Parks Commission are officials.",
    "The Investigation",
    "The Team", "Number of SIU Investigators assigned: 3", "Number of SIU Forensic Investigators assigned: 1",
    "Civilian Witness ( CW )", "CW Interviewed",
    "Subject Official ( SO )", "SO Interviewed, but declined to submit notes",
    "Witness Officials ( WO )", "WO #1 Interviewed", "WO #2 Interviewed", "WO #3 Interviewed",
    "Evidence", "The Complainant was taken to hospital and diagnosed with a fractured left wrist.",
    "Analysis and Director's Decision", "There are no reasonable grounds to believe that the SO committed an offence."))
  expect_identical(p[["siu_investigators"]], "3")
  expect_identical(p[["siu_forensics_investigators"]], "1")
  expect_identical(p[["number_of_civilian_witnesses"]], "1")
  expect_identical(p[["number_of_subject_officials"]], "1")
  expect_identical(p[["number_of_witness_officials"]], "3")
  # the narrative's injury, not the mandate's definition or "constables"
  expect_identical(p[["specific_injuries"]], "fractured left wrist")
  expect_identical(p[["charges_recommended"]], "FALSE")
})

test_that("no civilian witnesses, and no identified subject officer, are not counts of one", {
  p <- bricklayer_parse_siu(pg(
    "The Investigation", "Notification of the SIU", "Civilian Witnesses",
    "No civilian witnesses were identified, nor did any come forward.",
    "Witness Officers", "Witness Officer #1", "Analysis and Director's Decision",
    "The SIU could not identify an SO; the investigation is closed."))
  expect_identical(p[["number_of_civilian_witnesses"]], "0")
  expect_identical(p[["number_of_subject_officials"]], "")
  expect_identical(p[["number_of_witness_officials"]], "1")
})

test_that("French reports: AI / AT / TC, numbered 'no 1' or 'n o 1', and the French team lines", {
  p <- bricklayer_parse_siu(pg(
    "L’enquête", "Mandat de l’UES",
    "Une personne subit une blessure grave si elle souffre d’une fracture du crâne, d’un membre, d’une côte.",
    "L’enquête", "L’équipe",
    "Nombre d’enquêteurs de l’UES assignés : 3",
    "Nombre d’enquêteurs spécialistes des sciences judiciaires de l’UES assignés : 0",
    "Témoins civils ( TC )", "TC no 1 A participé à une entrevue", "TC no 2 A participé à une entrevue",
    "Agents impliqués ( AI )", "AI n o 1 N’a pas consenti à une entrevue", "AI n o 2 A participé",
    "Agents témoins ( AT )", "AT no 1 A participé à une entrevue",
    "Éléments de preuve", "On lui a diagnostiqué une fracture de l’épaule droite.",
    "Dispositions législatives pertinentes", "Paragraphe 25(1) du Code criminel -- Protection des personnes autorisées",
    "Analyse et décision du directeur",
    "Je n’ai aucun motif raisonnable de croire que l’AI a commis une infraction. Le dossier est clos."))
  expect_identical(p[["_language"]], "fr")
  expect_identical(p[["siu_investigators"]], "3")
  expect_identical(p[["siu_forensics_investigators"]], "0")
  expect_identical(p[["number_of_civilian_witnesses"]], "2")
  expect_identical(p[["number_of_subject_officials"]], "2")
  expect_identical(p[["number_of_witness_officials"]], "1")
  expect_identical(p[["specific_injuries"]], "fracture de l’épaule droite")
  expect_identical(p[["relevant_legislation"]], "Code criminel")
  expect_identical(p[["charges_recommended"]], "FALSE")
})

test_that("the legacy layouts: numbered roles in the text and teams in words, English and French", {
  en <- bricklayer_parse_siu(pg(
    "File #: 10-PFD-078 Police service: Lakeshore Incident date: May 9, 2010",
    "A witness officer is a police officer who is involved but is not a subject officer.",
    "Three SIU investigators and two forensic investigators ( FIs ) were dispatched.",
    "Civilian Witness #1 and Civilian Witness #3 were interviewed.",
    "Witness Officer #1 (May 11, 2010)", "Witness Officer #2 (May 12, 2010)",
    "Subject Officer #1 declined an interview."))
  expect_identical(en[["_language"]], "en")
  expect_identical(en[["siu_investigators"]], "3")
  expect_identical(en[["siu_forensics_investigators"]], "2")
  expect_identical(en[["number_of_civilian_witnesses"]], "3")
  expect_identical(en[["number_of_witness_officials"]], "2")
  expect_identical(en[["number_of_subject_officials"]], "1")
  fr <- bricklayer_parse_siu(pg(
    "Dossier n o : 06-OFD-069", "Service de police : Police régionale de Peel",
    "Date de l’incident : Le 17 avril 2006", "L’enquête",
    "Cinq enquêteurs et trois techniciens en identification médicolégale de l’UES ont été dépêchés.",
    "L’agent témoin n o 1 et l’agent témoin n o 2 ont répondu.",
    "L’UES a interviewé le témoin civil n o 1, le témoin civil n o 2 et le témoin civil n o 4.",
    "Agents témoins"))
  expect_identical(fr[["_language"]], "fr")
  expect_identical(fr[["siu_investigators"]], "5")
  expect_identical(fr[["siu_forensics_investigators"]], "3")
  expect_identical(fr[["number_of_civilian_witnesses"]], "4")
})
