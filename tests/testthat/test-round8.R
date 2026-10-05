# Fresh-user round 8: exit codes. A failure exits 1, a usage error (a bad or empty
# argument value, an unknown option) exits 2, as every other verb does.

.cap8 <- function(...) {
  txt <- character()
  status <- bricklayer_cli(c(...), out = function(s) txt <<- c(txt, s))
  list(status = status, text = paste(txt, collapse = ""))
}

test_that("help refuses an unknown option like every other verb", {
  r <- .cap8("help", "--nosuch-flag-xyz")
  expect_equal(r$status, 2L)
  expect_match(r$text, "unknown option --nosuch-flag-xyz")
  expect_equal(.cap8("help")$status, 0L)
  expect_equal(.cap8("help", "--help")$status, 0L)
})

test_that("an empty prompt or request, and a malformed --email, are usage errors", {
  r <- .cap8("ask", "")
  expect_equal(r$status, 2L)
  expect_match(r$text, "the prompt is empty")
  expect_false(grepl("`prompt`", r$text, fixed = TRUE))
  expect_equal(.cap8("ask", "  ")$status, 2L)
  expect_equal(.cap8("bundle", "")$status, 2L)
  r <- .cap8("login", "--email", "notanemail")
  expect_equal(r$status, 2L)
  expect_match(r$text, "'notanemail' is not an email address")
})

test_that("bundle with no language-model route fails", {
  skip_if_cannot_mock()
  testthat::local_mocked_bindings(.bl_hosted_base = function(...) NULL)
  r <- .cap8("bundle", "scaffold", "a", "bundle")
  expect_equal(r$status, 1L)
  expect_match(r$text, "No language-model route is set up")
})

test_that("a fractional or vector parameter is refused, not truncated to another setting", {
  expect_error(kem_keygen(512.5), "one of 512, 768 or 1024")
  expect_error(kem_keygen(c(512, 768)), "one of 512, 768 or 1024")
  expect_error(kem_keygen("768"), "one of 512, 768 or 1024")
  expect_identical(kem_keygen(768)$level, 768L)
  expect_error(pqc_keygen(2.5), "`height` must be a whole number, not 2.5")
  expect_identical(pqc_keygen(2)$height, 2L)
  expect_error(random_bytes(3.5), "whole number")
})

pg <- function(...) paste0("<html><body>", paste0("<p>", c(...), "</p>", collapse = ""), "</body></html>")

test_that("JSON matches jsonlite where options are not forwarded (raw, Date epoch, compact objects)", {
  j <- function(...) as.character(bricklayer_json_to_json(...))
  # jsonlite writes raw = "js" with its defaults: an array even under auto_unbox
  expect_identical(j(as.raw(0x23), raw = "js", auto_unbox = TRUE), "(new Uint8Array([35]))")
  expect_identical(j(as.raw(c(0x0f, 0xff)), raw = "hex"), "[\"f\",\"ff\"]")
  expect_identical(j(data.frame(r = I(list(as.raw(c(1, 0xab))))), raw = "hex"), "[{\"r\":[\"1\",\"ab\"]}]")
  expect_identical(j(data.frame(a = as.Date("2021-01-02")), Date = "epoch", always_decimal = TRUE),
                   "[{\"a\":18629}]")
  expect_identical(j(list(t = as.POSIXct(0, origin = "1970-01-01", tz = "UTC")), POSIXt = "mongo", pretty = TRUE),
                   "{\n  \"t\": [\n    {\"$date\":0}\n  ]\n}")
  expect_identical(j(list(b = as.raw(1:3)), raw = "mongo", pretty = TRUE),
                   "{\n  \"b\": {\"$binary\":\"AQID\",\"$type\":\"5\"}\n}")
  expect_identical(suppressMessages(j(list(v = c(a = 1.5, b = 2)), keep_vec_names = TRUE, pretty = TRUE,
                                      always_decimal = TRUE)),
                   "{\n  \"v\": {\"a\":1.5,\"b\":2}\n}")
  # keep_vec_names is a formal of jsonlite's data.frame method: no column sees it
  expect_identical(j(data.frame(l = I(list(c(a = 1, b = 2)))), keep_vec_names = TRUE), "[{\"l\":[1,2]}]")
})

test_that("serialize rounds doubles to digits; I(17) round-trips them exactly", {
  expect_identical(as.character(bricklayer_json_serialize(1 / 3)),
                   "{\"type\":\"double\",\"attributes\":{},\"value\":[0.33333333]}")
  x <- c(1 / 3, .Machine$double.xmax, 2^53 + 2, 5e-324)
  expect_identical(bricklayer_json_unserialize(bricklayer_json_serialize(x, digits = I(17))), x)
})

test_that("a count is a whole number in the integer range, not TRUE or Inf, with no coercion warning", {
  d <- drbg_new(as.raw(0:47))
  expect_error(drbg_generate(d, TRUE), "`n` must be a whole number, not TRUE")
  expect_no_warning(expect_error(drbg_generate(d, Inf), "`n` must be a whole number, not Inf"))
  expect_no_warning(expect_error(hqc_sizes(Inf), "one of 1, 3 or 5"))
  expect_error(random_bytes(1e10), "`n` is too large")
})

test_that("a Hawkes fit refuses an event rate its bounded baseline cannot reach", {
  tt <- seq(1, 1e308, length.out = 100)
  expect_error(core_hawkes_fit(tt, 1e308), "outside what the fit can represent")
})

test_that("the incident date: the sentence after the notification, the analysis, 'of <date>'", {
  p <- bricklayer_parse_siu(pg(
    "The Investigation", "Notification of the SIU",
    paste0("On July 9, 2019, at 9:59 a.m., the City of Kawartha Lakes Police Service ( CKLPS ) ",
           "contacted the SIU to report a serious injury. On July 8, 2019 at about 3:50 p.m., ",
           "CKLPS were called to a residence."),
    "The Team", "Number of SIU Investigators assigned: 2",
    "Incident Narrative", "The facts are not in dispute.",
    "Relevant Legislation", "Section 25(1), Criminal Code",
    "Analysis and Director's Decision", "There are no grounds."))
  expect_identical(p[["date_of_incident_iso"]], "2019-07-08")
  expect_identical(p[["date_siu_notified_iso"]], "2019-07-09")
  p <- bricklayer_parse_siu(pg(
    "The Investigation", "Notification of the SIU",
    paste0("On December 5, 2020, at 0046 hrs, the Ontario Provincial Police ( OPP ) notified the SIU ",
           "of the Complainant's injury."),
    "The Team", "Number of SIU Investigators assigned: 2",
    "Incident Narrative", "The Complainant was injured in a collision.",
    "Relevant Legislation", "Section 320.13, Criminal Code",
    "Analysis and Director's Decision",
    "On December 4, 2020, the Complainant rolled his SUV, suffering serious injuries."))
  expect_identical(p[["date_of_incident_iso"]], "2020-12-04")
  p <- bricklayer_parse_siu(pg(
    "The Investigation", "Notification of the SIU",
    paste0("On January 7, 2020, at 5:05 a.m., the Cornwall Police Service ( CPS ) notified the SIU of ",
           "the Complainant's injury."),
    "The Team", "Number of SIU Investigators assigned: 3",
    "Incident Narrative", "Just before 4:00 a.m. of January 7, 2020, the Complainant fled his home.",
    "Relevant Legislation", "Section 25(1), Criminal Code"))
  expect_identical(p[["date_of_incident_iso"]], "2020-01-07")
  # the passive notification: "The SIU was notified of the incident by ... on <date>"
  p <- bricklayer_parse_siu(pg(
    "The Investigation",
    paste0("The SIU was notified of the incident by a member of the Toronto Police Service ( TPS ) on ",
           "October 27, 2017 who advised of an injury."),
    "Incident Narrative", "On October 23, 2017, at approximately 11:19 p.m., the TPS executed a search warrant."))
  expect_identical(p[["date_siu_notified_iso"]], "2017-10-27")
  expect_identical(p[["date_of_incident_iso"]], "2017-10-23")
})

test_that("French dates with the ordinal set apart ('1 er septembre') and the notification without its heading", {
  p <- bricklayer_parse_siu(pg(
    "L'enqu\u00eate", "Agents impliqu\u00e9s", "AI n o 1 A particip\u00e9 \u00e0 une entrevue",
    "\u00c9l\u00e9ments de preuve",
    "L' UES a \u00e9t\u00e9 avis\u00e9e de l'incident par le SPRN le 1 er septembre 2016 \u00e0 22 h 15.",
    "Le 1 er septembre 2016, un mandat a \u00e9t\u00e9 d\u00e9livr\u00e9 pour l'arrestation du plaignant.",
    "Date : 27 juillet 2017"))
  expect_identical(p[["date_siu_notified_iso"]], "2016-09-01")
  expect_identical(p[["date_of_incident_iso"]], "2016-09-01")
})

test_that("resolve_so reads French reports: the AI roster, legacy ordinals, and not the boilerplate", {
  fr <- function(...) {
    paste(c("Unit\u00e9 des enqu\u00eates sp\u00e9ciales (UES)",
            paste0("les noms de personnes, y compris des t\u00e9moins civils ",
                   "et des agents impliqu\u00e9s et t\u00e9moins;"),
            ...), collapse = "\n")
  }
  r <- bricklayer_siu_resolve_so(fr("Agents impliqu\u00e9s",
                                    "AI n o 1 N'a pas consenti \u00e0 participer \u00e0 une entrevue",
                                    "AI n o 2 N'a pas consenti \u00e0 participer \u00e0 une entrevue",
                                    "Agents t\u00e9moins", "AT n o 1 A particip\u00e9 \u00e0 une entrevue"))
  expect_identical(r$count, 2L)
  so <- function(...) bricklayer_siu_resolve_so(fr(...))$count
  ai <- "AI N'a pas consenti \u00e0 se soumettre \u00e0 une entrevue"
  at1 <- "AT n o 1 A particip\u00e9 \u00e0 une entrevue"
  at2 <- "AT n o 2 A particip\u00e9 \u00e0 une entrevue"
  law <- paste0("En vertu de la Loi sur l' UES , les agents impliqu\u00e9s sont invit\u00e9s ",
                "\u00e0 participer \u00e0 une entrevue.")
  expect_identical(so("Agent impliqu\u00e9", ai, law, "l'un ou l'autre des agents impliqu\u00e9s"), 1L)
  listed <- "Les agents suivants ont \u00e9t\u00e9 identifi\u00e9s comme \u00e9tant des agents impliqu\u00e9s."
  expect_identical(so(listed, "agent impliqu\u00e9 n o 1", "agent impliqu\u00e9 n o 2",
                      "agent impliqu\u00e9 n o 3"), 3L)
  expect_identical(so("L' UES a conclu qu'aucun agent impliqu\u00e9 n'a \u00e9t\u00e9 d\u00e9sign\u00e9.", at1), 0L)
  expect_identical(so(at1, at2), 0L)
})

test_that("a French report with no roster takes the resolver's count, as an English one does", {
  p <- bricklayer_parse_siu(pg(
    "L\u0027enqu\u00eate", "\u00c9l\u00e9ments de preuve",
    paste0("Le 14 avril 2005, l\u0027agent(e) impliqu\u00e9(e) n o 1 , l\u0027agent(e) impliqu\u00e9(e) n o 2 ",
           "et l\u0027agent(e) impliqu\u00e9(e) n o 3 ont tous fourni une d\u00e9claration.")))
  expect_identical(p[["_language"]], "fr")
  expect_identical(p[["number_of_subject_officials"]], "3")
})

test_that("data pull refuses an unwritable --out before it downloads the table", {
  skip_if_cannot_mock()
  testthat::local_mocked_bindings(bricklayer_data_load = function(key) stop("the table was downloaded"))
  r <- .cap8("data", "pull", "hib/x", "--out", "/nonexistent-dir-r8/x.csv")
  expect_equal(r$status, 1L)
  expect_match(r$text, "cannot write /nonexistent-dir-r8/x.csv")
  expect_false(grepl("downloaded", r$text))
  r <- .cap8("data", "pull", "hib/x", "--out", tempdir())
  expect_equal(r$status, 1L)
})

test_that("a fit reports the parameters its estimate leaves on the box", {
  sim <- function(horizon, mu, eta, beta) {
    set.seed(1)
    gen <- all <- stats::runif(stats::rpois(1, mu * horizon), 0, horizon)
    while (length(gen)) {
      k <- stats::rpois(length(gen), eta)
      gen <- rep(gen, k) + stats::rexp(sum(k), beta)
      gen <- gen[gen <= horizon]
      all <- c(all, gen)
    }
    sort(all)
  }
  x <- sim(730, 2, 0.3, 0.5)
  d <- floor(x[x < 100])
  # day-dated times lock a Weibull onto the one-day lattice: the shape runs to its wall
  f <- suppressWarnings(core_hawkes_fit(d, 100, "weibull"))
  expect_true(f$converged)
  expect_identical(f$at_bound, "alpha")
  expect_equal(f$kernel_params[[1]], 15)
  # spread across the day, the same events have an interior maximum
  expect_identical(core_hawkes_fit(core_hawkes_jitter(d), 100, "weibull")$at_bound, character(0))
  expect_identical(core_hawkes_fit(x, 730)$at_bound, character(0))
})

test_that("bad inputs get argument errors in words, not R internals", {
  expect_identical(bricklayer_json_base64url_dec(character(0)), bricklayer_json_base64_dec(character(0)))
  expect_identical(bricklayer_json_base64url_dec(c("YQ", "")), charToRaw("a"))
  expect_error(bricklayer_json_unserialize(-1), "one string of JSON")
  expect_error(bricklayer_json_unserialize(1e300), "one string of JSON")
  expect_error(capsule_bundle(character(0)), "`dir`")
  expect_error(yoy(Inf), "infinite entry")
  expect_no_warning(expect_error(distinct_count(1e300), "non-negative integer registers"))
  expect_no_warning(expect_error(sketch_merge(1e300, 1), "non-negative integer registers"))
  for (bad in list(NA, "abc", -1, Inf, 1.5, c(1, 2))) {
    expect_error(bricklayer_fetch_parse_siu(bad), "one positive report number", info = deparse(bad))
  }
})

test_that("jitter keeps an event dated on the horizon inside the window", {
  set.seed(4)
  d <- sort(c(floor(stats::runif(300, 0, 100)), 100))
  j <- core_hawkes_jitter(d, horizon = 100)
  expect_lte(max(j), 100)
  expect_identical(sum(j == 100), 1L)
  expect_true(is.list(core_hawkes_fit(j, 100)))
  expect_error(core_hawkes_fit(core_hawkes_jitter(d), 100), "horizon = ")
  expect_identical(core_hawkes_jitter(d), core_hawkes_jitter(d, horizon = Inf))
  expect_error(core_hawkes_jitter(d, horizon = 50), "must not exceed")
})
