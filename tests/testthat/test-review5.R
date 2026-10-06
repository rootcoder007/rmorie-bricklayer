# The 0.5.8 diff review and the SIU review (2026-10-06): the stack-overflow class
# from the sites 0.5.8 did not reach, the cost of its line cap, the quadratic scans,
# and the smaller divergences. Every hostile shape also runs through the subprocess
# battery in test-review3.R (N1), which enumerates the entry points itself.

r5 <- function(nm) get(nm, envir = asNamespace("rmoriebricklayer"))

test_that("the reviewers' inputs return in-process: whitespace bytes, boilerplate, glossary, HTML", {
  expect_type(bricklayer_parse_siu(paste0("SO #1", strrep("\f", 25000), "x")), "character")
  expect_type(bricklayer_parse_siu(paste0("SO #1", strrep("\v", 25000), "x")), "character")
  expect_type(bricklayer_siu_resolve_so(paste0("SO #1", strrep("\r", 25000), "x"))$reason, "character")
  r <- bricklayer_siu_resolve_so(paste0("this information may include", strrep("a b\n", 15000), "affected person."))
  expect_type(r$reason, "character")
  r <- bricklayer_siu_resolve_so(paste0("this information may include", strrep("a b\n", 12500)))
  expect_type(r$reason, "character")
  r <- bricklayer_siu_resolve_so(paste0("who, in the opinion of the SIU Director, is not a subject officer ",
                                        strrep("a b\n", 12500)))
  expect_type(r$reason, "character")
  f <- bricklayer_parse_siu(paste0("<html><body><p>this information may include</p>",
                                   strrep("<li>a b</li>", 12000), "</body></html>"))
  expect_type(f, "character")
  # the 0.5.7 reproducer stays fixed
  expect_identical(bricklayer_siu_text(strrep(" ", 25000)), " ")
})

test_that("the boilerplate scans remove what the regexes removed, and only that", {
  # a report with one tagged SO: the privacy paragraph and the glossary sentence, in both
  # phrasings, must not change that verdict (0.5.8's regexes stripped them; the scans do too)
  base <- "Subject Officials\nSO #1 Interviewed.\n"
  expect_identical(bricklayer_siu_resolve_so(base)$count, 1L)
  boiler <- paste0("This information may include the name of a subject official, ",
                   "a witness official and the affected person. ")
  glossary <- c(paste("A witness officer is a police officer who, in the opinion of the SIU Director,",
                      "is involved but is not a subject officer."),
                paste("A witness officer is one who in the SIU Director's opinion is involved",
                      "and is not a subject official. Next."))
  expect_identical(bricklayer_siu_resolve_so(paste0(boiler, base))$count, 1L)
  for (g in glossary) expect_identical(bricklayer_siu_resolve_so(paste0(base, g))$count, 1L, info = g)
  # and with the sentence but no tag at all, the glossary's "not a subject officer" is not a cue
  for (g in glossary) {
    r <- bricklayer_siu_resolve_so(paste0("Preamble.\n", g, "\nThe Team\nNumber of SIU Investigators assigned: 3\n"))
    expect_false(grepl("glossary|not a subject", r$reason, ignore.case = TRUE), info = g)
  }
})

test_that("a split long line is placed at a sentence end and is warned about, never silent", {
  pad <- substr(strrep("word ", 500), 1, 1991)
  s <- paste0("Notification of the SIU\n", pad, "the Toronto Police Service reported the incident.\n")
  w <- NULL
  f <- withCallingHandlers(bricklayer_parse_siu(s), warning = function(c) {
    w <<- conditionMessage(c)
    invokeRestart("muffleWarning")
  })
  expect_match(w, "1 line longer than 2000 characters was split")
  expect_null(attr(f, "split_lines"))
  # with a sentence end inside the window the field itself stays whole
  s2 <- paste0("Notification of the SIU\n", substr(strrep("word ", 500), 1, 1900), ". ",
               "On January 5, 2023, the Toronto Police Service reported the incident. More words follow here.\n")
  f2 <- suppressWarnings(bricklayer_parse_siu(s2))
  expect_identical(unname(f2["police_service"]), "Toronto Police Service")
  # short documents: no warning at all
  expect_silent(bricklayer_parse_siu(paste0("Notification of the SIU\n",
                                            "On January 5, 2023, the Toronto Police Service reported it.\n")))
  expect_silent(bricklayer_siu_text("<p>short</p>"))
  expect_warning(bricklayer_siu_text(paste0("<p>", strrep("word ", 1000), "</p>")), "longer than 2000")
  expect_warning(bricklayer_siu_resolve_so(strrep("word ", 1000)), "longer than 2000")
})

test_that("the regex-free passes are linear: unclosed <script> and bare < in bulk", {
  t1 <- system.time(bricklayer_siu_text(strrep("<script>", 40000)))[["elapsed"]]      # 320 KB
  t2 <- system.time(bricklayer_siu_text(strrep("<script>", 80000)))[["elapsed"]]      # 640 KB
  expect_lt(t1, 5)
  expect_lt(t2, 5)
  t3 <- system.time(suppressWarnings(bricklayer_siu_text(strrep("<", 400000))))[["elapsed"]]
  expect_lt(t3, 5)
  # a closed element is still stripped, in place
  out <- bricklayer_siu_text("<p>a</p><script>var x = 1;</script><p>b</p>")
  expect_false(grepl("var x", out, fixed = TRUE))
  expect_match(out, "a\\s+b")
})

test_that("the smaller divergences: date cap errors, nine-digit tags, zero-padded entities, entity case", {
  expect_identical(bricklayer_siu_iso_date(paste0("January 5, 2023", strrep(" ", 4081))), "2023-01-05")
  expect_error(bricklayer_siu_iso_date(paste0("January 5, 2023", strrep(" ", 4082))), "longer than 4096 bytes")
  f <- bricklayer_parse_siu("Subject Officials\nSO #1234567\n")
  expect_identical(unname(f["number_of_subject_officials"]), "1234567")
  f <- bricklayer_parse_siu(paste0("Subject Officials\nSO #", strrep("4", 12), "\n"))
  expect_identical(unname(f["number_of_subject_officials"]), "1")
  expect_identical(trimws(bricklayer_siu_text("<p>caf&#0000000233; &#x00000000E9;</p>")), "café é")
  expect_identical(trimws(bricklayer_siu_text("<p>&apos;a&apos; &APOS;b&APOS; &hellip; &HELLIP;</p>")),
                   "'a' &APOS;b&APOS; ... &HELLIP;")
  # a long non-HTML string is parsed: the one warning is the split (a 5000-character line),
  # never file.exists()'s "expanded path length"
  w <- character()
  withCallingHandlers(bricklayer_parse_siu(strrep("1234567890", 500)), warning = function(c) {
    w <<- c(w, conditionMessage(c))
    invokeRestart("muffleWarning")
  })
  expect_true(all(grepl("longer than 2000", w)))
  expect_false(any(grepl("expanded path", w)))
})

test_that("interrupt polling: the SIU core carries a hook the barrier installs", {
  d <- testthat::test_path("..", "..", "src")
  skip_if(!dir.exists(d) || !file.exists(file.path(d, "siu_parse.cpp")), "package sources not available from here")
  p <- readLines(file.path(d, "siu_parse.cpp"), warn = FALSE)
  rs <- readLines(file.path(d, "siu_resolve.cpp"), warn = FALSE)
  glue <- readLines(file.path(d, "rmbl_siu.cpp"), warn = FALSE)
  expect_true(any(grepl("interrupt_fn& interrupt_hook()", p, fixed = TRUE)))
  expect_gte(sum(grepl("poll_every(", c(p, rs), fixed = TRUE) | grepl("poll_interrupt()", c(p, rs), fixed = TRUE)), 8L)
  expect_true(any(grepl("siu::interrupt_hook() = siu_interrupt_hook", glue, fixed = TRUE)))
  # the two exported kernels raise only after their buffers are gone
  kdf <- readLines(file.path(d, "rmbl_kdf.cpp"), warn = FALSE)
  ser <- readLines(file.path(d, "rmbl_series.cpp"), warn = FALSE)
  expect_true(any(grepl("rmbl_interrupt_raise_unbarriered()", kdf, fixed = TRUE)))
  expect_true(any(grepl("rmbl_interrupt_raise_unbarriered()", ser, fixed = TRUE)))
  bar <- readLines(file.path(d, "rmbl_barrier.cpp"), warn = FALSE)
  i <- grep("rmbl_interrupt_pending", bar)[1]
  expect_false(any(grepl("if (rmbl_barrier_depth == 0) rmbl_raise_interrupt();", bar[i:(i + 12)], fixed = TRUE)))
})

test_that("the odds and ends: timeout range, single-label message, mirror .sig URL, mode doc", {
  expect_error(bricklayer_download("https://example.org/x", tempfile(), timeout = 1e18, quiet = TRUE),
               "at most 2147483647")
  expect_error(.rmbl_check_public_url("https://metadata/"), "local or private")
  expect_error(.rmbl_check_public_url("https://instance-data/latest"), "local or private")
  expect_identical(r5(".rmbl_services_sig_url")("https://rmorie.com/.well-known/morie-services.json"),
                   "https://rmorie.com/.well-known/morie-services.sig")
  expect_identical(r5(".rmbl_services_sig_url")("https://mirror.example.org/services"),
                   "https://mirror.example.org/services.sig")
  rd <- tools::Rd_db("rmoriebricklayer")
  rdtxt <- function(nm) {
    paste(utils::capture.output(tools::Rd2txt(rd[[nm]], options = list(underline_titles = FALSE))), collapse = "\n")
  }
  expect_match(rdtxt("download_data.Rd"), "only.*\"wb\"")
  expect_match(rdtxt("bricklayer_json_to_json.Rd"), "quiet_vec_names")
  expect_match(rdtxt("bricklayer_llm_ask.Rd"), "configured")
  # the docs the diff review found missing
  expect_match(rdtxt("bricklayer_services.Rd"), "MORIE_SERVICES_URL")
  expect_match(rdtxt("bricklayer_parse_siu.Rd"), "2000 characters")
  expect_match(rdtxt("bricklayer_siu_text.Rd"), "2 MiB")
  expect_match(rdtxt("capsule_drift.Rd"), "20 distinct values")
  expect_match(rdtxt("bricklayer_download.Rd"), "2147483647")
  expect_match(rdtxt("bricklayer_llm_ask.Rd"), "192.168/16", fixed = TRUE)
  # log_p_value carries range p_value cannot: a chi-square of 1e4 on 1 df has p = 0 in
  # double, and its log tail agrees with the asymptotic -x/2 + log(sqrt(2/(pi x))) to 1e-3
  expect_identical(stats::pchisq(1e4, 1, lower.tail = FALSE), 0)
  lp <- r5(".rmbl_chisq_logp")(1e4, 1)
  expect_true(is.finite(lp))
  expect_lt(abs(lp - (-5000 + 0.5 * log(2 / (pi * 1e4)))), 1e-3)
})

test_that("Mann-Kendall interrupted inside the barrier raises R's interrupt, as PBKDF2 does (D2)", {
  skip_on_cran()
  skip_on_os("windows")
  skip_if(!nzchar(Sys.which("python3")) || !nzchar(Sys.which("timeout")), "no python3/timeout")
  # 120k points: the pair loop runs for many seconds unless the poll (every 512 rows) sees the
  # signal. The probe runs in a child with SIGINT reset to default, so it is conclusive even where
  # this process inherited SIGINT as ignored (a background chain, covr)
  got <- interrupt_probe(paste(
    "y <- as.numeric(seq_len(120000L)) + rep(c(0.5, -0.5), 60000L);",
    ".Call(rmoriebricklayer:::C_rmbl_mann_kendall, y)"))
  skip_if(startsWith(got, "inconclusive"), got)
  expect_identical(got, "interrupt")
  # the next call starts clean and answers
  mk <- .Call(r5("C_rmbl_mann_kendall"), c(1, 3, 2, 5, 4, 6))
  expect_true(all(is.finite(unlist(mk))))
})
