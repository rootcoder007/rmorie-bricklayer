# police_service is the service of the subject officials, read from the
# director's analysis -- not the force that notified the SIU. Each report
# below is invented for the test; the services and places are fictional
# except the Ontario Provincial Police and Toronto Police Service, which the
# case-number letter rule names.

page <- function(...) paste0("<html><body>", paste0("<p>", c(...), "</p>", collapse = ""), "</body></html>")
service <- function(...) bricklayer_parse_siu(page(...))[["police_service"]]

test_that("the subject official's service wins over the notifying force", {
  expect_equal(
    service("Notification of the SIU",
            "The Lakeshore Police Service ( LPS ) notified the SIU of the injury.",
            "Analysis and Director's Decision",
            "The Complainant was hurt while in the custody of the LPS.",
            "The SO of the Hillcrest Police Service was identified as the subject official."),
    "Hillcrest Police Service")
  # an abbreviation the page defined is read back as the full name
  expect_equal(
    service("The Lakeshore Police Service ( LPS ) notified the SIU.",
            "Hillcrest Police Service ( HPS ) officers attended.",
            "Analysis and Director's Decision",
            "The SO , an HPS officer, arrested the Complainant."),
    "Hillcrest Police Service")
})

test_that("a subject-official sentence without a service reads the sentence before it", {
  expect_equal(
    service("The Lakeshore Police Service notified the SIU.",
            "Analysis and Director's Decision",
            "The Complainant was arrested by Riverton Police Service officers.",
            "The SO was identified as the subject official."),
    "Riverton Police Service")
})

test_that("with no service near a subject official, the analysis's most-named service wins", {
  expect_equal(
    service("The Lakeshore Police Service notified the SIU.",
            "Analysis and Director's Decision",
            "The Complainant fell from a balcony.",
            "The SO was identified as the subject official.",
            "Riverton Police Service records were reviewed.",
            "Riverton Police Service officers had attended; the Lakeshore Police Service assisted."),
    "Riverton Police Service")
  # a page's own abbreviation replaces the default reading of the same letters
  expect_equal(
    service("The Pinecrest Regional Police ( PRP ) notified the SIU.",
            "Analysis and Director's Decision",
            "The SO , a PRP officer, made the arrest."),
    "Pinecrest Regional Police")
})

test_that("the case-number letter rules out services of the wrong kind", {
  # P = Ontario Provincial Police
  expect_equal(
    service("Director's Report for Case # 21-PCI-500",
            "Analysis and Director's Decision",
            "The SO of the Hillcrest Police Service assisted the OPP in the arrest."),
    "Ontario Provincial Police")
  # T = Toronto Police Service, even when another service is named first
  expect_equal(
    service("Director's Report for Case # 21-TCI-501",
            "Analysis and Director's Decision",
            paste0("The SO , an off-duty officer, held the Complainant for the Hillcrest Police Service ",
                   "until TPS officers arrived.")),
    "Toronto Police Service")
  # O = any other service: the OPP is ruled out
  expect_equal(
    service("Director's Report for Case # 21-OCI-502",
            "Analysis and Director's Decision",
            "The SO had assisted the OPP before Riverton Police Service officers made the arrest."),
    "Riverton Police Service")
})

test_that("French reports read the agent impliqu\u00e9's service", {
  expect_equal(
    service("T\u00e9moins civils", "Agents impliqu\u00e9s",
            "Notification de l\u2019UES",
            "La Police provinciale de l\u2019Ontario ( PPO ) a avis\u00e9 l\u2019UES de la blessure.",
            "Analyse et d\u00e9cision du directeur",
            paste0("Un agent du Service de police de Rivi\u00e8reville, l\u2019AI , ",
                   "a \u00e9t\u00e9 d\u00e9sign\u00e9 comme agent impliqu\u00e9.")),
    "Service de police de Rivi\u00e8reville")
})

test_that("a legacy report's Police service header decides", {
  expect_equal(
    service("File #: 10-OFD-900 Police service: Lakeshore Incident date: May 9, 2010",
            "Notification of the SIU The Riverton Police Service notified the SIU.",
            "Officers of the Lakeshore Police Service attended."),
    "Lakeshore Police Service")
  # the header alone, when no full name contains it
  expect_equal(
    service("File #: 10-OFD-901 Police service: Elmwood Incident date: May 9, 2010",
            "Notification of the SIU The Riverton Police Service notified the SIU."),
    "Elmwood")
})
