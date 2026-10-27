# `aye`, `tellme` and a bare question are the ask verb (Vee, 2026-10-14); a lone
# unknown word is still an unknown verb, so a typo never reaches a model.

ask_via_cli <- function(args) {
  rec <- new.env()
  rec$seen <- NULL
  testthat::local_mocked_bindings(
    llmask = function(prompt, model = NULL, route = NULL, fresh = FALSE) {
      rec$seen <- list(
        prompt = prompt,
        model = model,
        route = route,
        fresh = fresh
      )
      "the answer"
    },
    .package = "rmoriebricklayer"
  )
  rec$txt <- character()
  st <- blcli(args, out = function(s) rec$txt <- c(rec$txt, s))
  list(status = st, out = paste(rec$txt, collapse = ""), seen = rec$seen)
}

test_that("aye and tellme ask, with every option ask takes", {
  for (v in c("ask", "aye", "tellme")) {
    r <- ask_via_cli(c(
      v,
      "--route",
      "own",
      "--model",
      "m1",
      "--fresh",
      "how",
      "are",
      "you"
    ))
    expect_identical(r$status, 0L, info = v)
    expect_identical(r$seen$prompt, "how are you", info = v)
    expect_identical(r$seen$route, "own", info = v)
    expect_identical(r$seen$model, "m1", info = v)
    expect_true(r$seen$fresh, info = v)
    expect_match(r$out, "the answer", fixed = TRUE, info = v)
  }
})

test_that("a quoted question with no verb is asked", {
  r <- ask_via_cli("how do I weight a survey?")
  expect_identical(r$status, 0L)
  expect_identical(r$seen$prompt, "how do I weight a survey?")
  # one word with a question mark, and the options ask takes after the question
  r <- ask_via_cli("why?")
  expect_identical(r$seen$prompt, "why?")
  r <- ask_via_cli(c("how?", "--fresh", "--route", "own"))
  expect_identical(r$seen$prompt, "how?")
  expect_true(r$seen$fresh)
  expect_identical(r$seen$route, "own")
  # R >= 4.6 keeps the --args separator
  r <- ask_via_cli(c("--args", "how do I weight a survey?"))
  expect_identical(r$seen$prompt, "how do I weight a survey?")
})

test_that("a lone unknown word, a verb, or an option is not sent to a model", {
  r <- ask_via_cli("hepl")
  expect_identical(r$status, 2L)
  expect_null(r$seen)
  expect_match(r$out, "unknown verb 'hepl'", fixed = TRUE)
  r <- ask_via_cli(c("logn", "now"))
  expect_identical(r$status, 2L)
  expect_null(r$seen)
  # a real verb with a spaced argument stays that verb (functions, not
  # explain-error: that builds the session's message table, and under this mock
  # it would be built from the mock)
  r <- ask_via_cli(c("functions", "survey design?"))
  expect_null(r$seen)
  r <- ask_via_cli(c("--weird", "flag?"))
  expect_null(r$seen)
})

test_that("aye and tellme with no prompt say how to ask", {
  for (v in c("aye", "tellme")) {
    r <- ask_via_cli(v)
    expect_identical(r$status, 2L, info = v)
    expect_match(r$out, "ask [--route ROUTE]", fixed = TRUE, info = v)
    expect_null(r$seen)
  }
  # `aye --help` describes ask
  rec <- new.env()
  rec$txt <- character()
  expect_identical(
    blcli(c("aye", "--help"), out = function(s) rec$txt <- c(rec$txt, s)),
    0L
  )
  expect_match(paste(rec$txt, collapse = ""), "ask the model", fixed = TRUE)
})

test_that("help lists the other names of ask", {
  rec <- new.env()
  rec$txt <- character()
  blcli("help", out = function(s) rec$txt <- c(rec$txt, s))
  expect_match(paste(rec$txt, collapse = ""), "aye, tellme", fixed = TRUE)
})

test_that("every launcher turns a top-level Ctrl-C into exit 130", {
  for (nm in c("rmbl", "rmoriebricklayer")) {
    f <- system.file("bin", nm, package = "rmoriebricklayer")
    skip_if_not(nzchar(f))
    expect_match(
      paste(readLines(f), collapse = "\n"),
      "tryCatch(rmoriebricklayer::blcli(), interrupt = function(e) 130L)",
      fixed = TRUE
    )
  }
  skip_on_os("windows")
  d <- withr::local_tempdir()
  invisible(utils::capture.output(suppressMessages(instcli(dir = d))))
  for (nm in list.files(d)) {
    expect_match(
      paste(readLines(file.path(d, nm)), collapse = "\n"),
      "interrupt = function(e) 130L",
      fixed = TRUE,
      info = nm
    )
  }
})

test_that(
  paste0(
    "the prompt finds sh and stty without a child process (a Ctrl-C there ",
    "was lost)"
  ),
  {
    skip_on_os("windows")
    have <- .bl_have_program
    expect_true(have("sh"))
    expect_false(have("no-such-program-rmbl"))
    # .bl_readline asks it, never Sys.which(), which runs a child that a Ctrl-C
    # kills alone
    body_txt <- paste(deparse(.bl_readline), collapse = "\n")
    expect_false(grepl("Sys.which", body_txt, fixed = TRUE))
  }
)

test_that(
  paste0(
    "typos, file names and keys are never taken for a question (network ",
    "stress test of 5e1dce5)"
  ),
  {
    crlf_key <- paste0("sk-ant-", strrep("a", 40), "\r")
    cases <- list(
      c("explain-eror", "object 'x' not found"),
      c("wayabck", "my urls.txt"),
      "My Documents/urls.txt",
      "C:\\Users\\me\\My Documents\\notes.txt",
      "models?",
      "version?",
      "doctor?",
      "logout?",
      "?",
      c("conifg", "set", "anthropic.key", crlf_key),
      paste("please use", strrep("k", 40)),
      c("what", "is", "PSI?"),
      c("how do I weight a survey?", "extra"),
      "line one\nline two"
    )
    for (a in cases) {
      r <- ask_via_cli(a)
      expect_null(r$seen, label = paste(a, collapse = " | "))
      expect_identical(r$status, 2L, label = paste(a, collapse = " | "))
    }
    # a near miss names the verb it is close to, and nothing echoes the key
    r <- ask_via_cli(c("explain-eror", "object 'x' not found"))
    expect_match(
      r$out,
      "did you mean `rmoriebricklayer explain-error`",
      fixed = TRUE
    )
    r <- ask_via_cli(c("conifg", "set", "anthropic.key", crlf_key))
    expect_false(grepl(strrep("a", 40), r$out, fixed = TRUE))
    expect_match(r$out, "did you mean `rmoriebricklayer config`", fixed = TRUE)
  }
)
