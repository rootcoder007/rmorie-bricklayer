# The terms and profile step before a new key: the terms are accepted (y/N or accept_terms = TRUE),
# a name and a reason are given, and Schedule B needs a supervisor, chair, director or coordinator.

answers <- function(...) {
  a <- c(...)
  i <- 0L
  function(prompt, ...) {
    i <<- i + 1L
    if (i <= length(a)) a[[i]] else ""
  }
}
terms_reply <- function(json, status = 200L) {
  function(url, timeout, headers) list(status = status, body = charToRaw(json))
}

test_that("the terms version and address come from the sign-in service", {
  seen <- NULL
  local_mocked_bindings(.bl_http_get = function(url, timeout, headers) {
    seen <<- url
    list(status = 200L, body = charToRaw('{"version":"2026-10-16","url":"https://data.example/terms"}'))
  })
  t <- .bl_terms_info("https://data.example/auth")
  expect_identical(seen, "https://data.example/terms.json")
  expect_identical(t, list(version = "2026-10-16", url = "https://data.example/terms"))
  # no url in the reply: the terms page next to the service
  local_mocked_bindings(.bl_http_get = terms_reply('{"version":"2026-10-16"}'))
  expect_identical(.bl_terms_info("https://data.example/auth")$url, "https://data.example/terms")
})

test_that("terms that cannot be read stop the sign-in", {
  local_mocked_bindings(.bl_http_get = terms_reply("{}", 503L))
  expect_error(.bl_terms_info("https://data.example/auth"), "could not read the data access terms")
  local_mocked_bindings(.bl_http_get = terms_reply('{"version":"latest"}'))
  expect_error(.bl_terms_info("https://data.example/auth"), "could not read the data access terms")
  local_mocked_bindings(.bl_http_get = function(...) stop("no network"))
  expect_error(.bl_terms_info("https://data.example/auth"), "https://data.example/terms.json")
})

test_that("an email address is checked before anything is asked", {
  expect_error(.bl_check_email(""), "an email address is required")
  expect_error(.bl_check_email(NA_character_), "an email address is required")
  expect_error(.bl_check_email("nope"), "'nope' is not an email address")
  expect_identical(.bl_check_email(" Ada@Example.org "), "ada@example.org")
})

test_that("terms not accepted at the prompt: no key, and how to accept", {
  local_mocked_bindings(.bl_terms_info = function(...) list(version = "2026-10-16", url = "https://data.example/terms"),
                        .bl_readline = answers("n"))
  expect_message(
    expect_error(.bl_signin_profile(), "were not accepted, so no key was issued.*--accept-terms"),
    "Data access terms, version 2026-10-16")
})

test_that("an accepted sign-in asks for name, organisation, reason and Schedule B", {
  local_mocked_bindings(.bl_terms_info = function(...) list(version = "2026-10-16", url = "u"),
                        .bl_readline = answers("YES", "Ada Lovelace", "", "Course project on court delays in Ontario.",
                                               "n"))
  p <- suppressMessages(.bl_signin_profile())
  expect_identical(p$accept_terms, "2026-10-16")
  expect_identical(p$name, "Ada Lovelace")
  expect_null(p$affiliation)
  expect_identical(p$purpose, "Course project on court delays in Ontario.")
  expect_false(p$accept_restricted)
  expect_match(p$client, "^rmoriebricklayer/")
  expect_null(p$supervisor_name)
})

test_that("a name and a reason are required", {
  local_mocked_bindings(.bl_terms_info = function(...) list(version = "2026-10-16", url = "u"),
                        .bl_readline = answers(""))
  expect_error(.bl_signin_profile(accept_terms = TRUE), "your name is needed for a key: pass --name")
  expect_error(.bl_signin_profile(accept_terms = TRUE, name = "Ada", purpose = "too short"),
               "the reason you need the data.*--reason")
})

test_that("Schedule B needs a supervisor, a role from the list and their email", {
  local_mocked_bindings(.bl_terms_info = function(...) list(version = "2026-10-16", url = "u"),
                        .bl_readline = answers(""))
  base <- list(accept_terms = TRUE, name = "Ada", affiliation = "Uni",
               purpose = "Thesis chapter on court delays in Ontario.", restricted = TRUE)
  expect_error(do.call(.bl_signin_profile, base), "supervisor's, chair's, director's or coordinator's name")
  expect_error(do.call(.bl_signin_profile, c(base, supervisor_name = "Dr B", supervisor_role = "boss")),
               "their role, one of supervisor, chair, director, coordinator, other")
  expect_error(do.call(.bl_signin_profile, c(base, supervisor_name = "Dr B", supervisor_role = "Chair",
                                              supervisor_email = "nope")), "their email address")
  p <- do.call(.bl_signin_profile, c(base, supervisor_name = "Dr B", supervisor_role = "Chair",
                                      supervisor_email = "B@Uni.example"))
  expect_true(p$accept_restricted)
  expect_identical(p$affiliation, "Uni")
  expect_identical(p[c("supervisor_name", "supervisor_role", "supervisor_email")],
                   list(supervisor_name = "Dr B", supervisor_role = "chair", supervisor_email = "b@uni.example"))
})

test_that("Schedule B can be chosen at the prompt, with the supervisor asked for too", {
  local_mocked_bindings(.bl_terms_info = function(...) list(version = "2026-10-16", url = "u"),
                        .bl_readline = answers("Ada", "Uni", "Thesis chapter on court delays in Ontario.", "y",
                                               "Dr B", "director", "b@uni.example"))
  p <- .bl_signin_profile(accept_terms = TRUE)
  expect_true(p$accept_restricted)
  expect_identical(p$supervisor_role, "director")
})

test_that("the profile goes with the sign-in request, and a bad address stops before it is asked", {
  posted <- list()
  local_mocked_bindings(
    .bl_signin_profile = function(...) list(accept_terms = "2026-10-16", name = "Ada"),
    .bl_post_json = function(url, payload, ...) {
      posted[[length(posted) + 1L]] <<- list(url = url, payload = payload)
      list(status = 503L, json = list(error = "down"), error = "")
    })
  expect_error(dlogin(email = "not-an-address"), "is not an email address")
  expect_length(posted, 0L)
  expect_error(dlogin(email = "ada@example.org"), "503")
  expect_identical(posted[[1L]]$payload, list(email = "ada@example.org", accept_terms = "2026-10-16", name = "Ada"))
  expect_error(dlogin(openbro = FALSE), "503")
  expect_match(posted[[2L]]$url, "/device/code$")
  expect_identical(posted[[2L]]$payload, list(accept_terms = "2026-10-16", name = "Ada"))
})

test_that("rmbl login passes the terms and profile flags through", {
  got <- NULL
  local_mocked_bindings(dlogin = function(...) {
    got <<- list(...)
    invisible("k")
  })
  buf <- character()
  st <- blcli(c("login", "--accept-terms", "--name", "Ada Lovelace", "--affiliation", "Uni",
                         "--reason", "Thesis chapter on court delays.", "--restricted",
                         "--supervisor-name", "Dr B", "--supervisor-role", "chair",
                         "--supervisor-email", "b@uni.example"), out = function(x) buf <<- c(buf, x))
  expect_identical(st, 0L)
  expect_true(got$accter)
  expect_identical(got[c("name", "affil", "purp", "supnm", "suprole", "supemail")],
                   list(name = "Ada Lovelace", affil = "Uni", purp = "Thesis chapter on court delays.",
                        supnm = "Dr B", suprole = "chair", supemail = "b@uni.example"))
  expect_true(got$restr)
  blcli(c("login", "--no-browser"), out = function(x) NULL)
  expect_false(got$accter)
  expect_null(got$restr)
  usage <- character()
  blcli(c("login", "--help"), out = function(x) usage <<- c(usage, x))
  expect_match(paste(usage, collapse = ""), "--accept-terms")
})
