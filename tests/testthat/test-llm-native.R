# SPDX-License-Identifier: AGPL-3.0-or-later
#
# The native hosted-LLM route and the command line. The HTTP layer is
# replaced by canned replies; the credentials file lives in a temporary
# XDG_CONFIG_HOME. Nothing leaves the machine and nothing touches $HOME.

.sandbox <- function(env = parent.frame()) {
  dir <- tempfile("xdg-")
  dir.create(dir)
  old <- Sys.getenv(c("XDG_CONFIG_HOME", "MORIE_HOSTED_KEY",
                      "MORIE_HOSTED_BASE_URL", "MORIE_HOSTED_MODEL"),
                    unset = NA)
  Sys.setenv(XDG_CONFIG_HOME = dir)
  Sys.unsetenv(c("MORIE_HOSTED_KEY", "MORIE_HOSTED_BASE_URL",
                 "MORIE_HOSTED_MODEL"))
  withr_restore <- function() {
    for (nm in names(old)) {
      if (is.na(old[[nm]])) Sys.unsetenv(nm) else do.call(Sys.setenv,
                                                          as.list(old[nm]))
    }
    unlink(dir, recursive = TRUE)
  }
  do.call(on.exit, list(substitute(withr_restore()), add = TRUE),
          envir = env)
  assign("withr_restore", withr_restore, envir = env)
  dir
}

.reply <- function(text, status = 200L) {
  body <- bricklayer_json_to_json(
    list(choices = list(list(message = list(role = "assistant",
                                            content = text)))),
    auto_unbox = TRUE)
  list(status = status, body = charToRaw(body))
}

test_that("a token is stored owner-only in the shared credentials file", {
  dir <- .sandbox()
  expect_message(bricklayer_llm_login(token = "  sk-test "), "Token stored")
  p <- file.path(dir, "morie", "credentials.json")
  expect_true(file.exists(p))
  if (.Platform$OS.type != "windows") {
    expect_equal(as.character(file.info(p)$mode), "600")
  }
  expect_equal(.bl_hosted_key(), "sk-test")
  expect_error(bricklayer_llm_login(token = " "), "empty token")
  expect_message(expect_true(bricklayer_llm_logout()), "Logged out")
  expect_false(file.exists(p))
  expect_null(.bl_hosted_key())
  expect_message(expect_false(bricklayer_llm_logout()), "No hosted key")
})

test_that("the environment key wins and off disables the tier", {
  .sandbox()
  bricklayer_llm_login(token = "file-key")
  Sys.setenv(MORIE_HOSTED_KEY = "env-key")
  expect_equal(.bl_hosted_key(), "env-key")
  Sys.setenv(MORIE_HOSTED_BASE_URL = "off")
  expect_null(.bl_hosted_base())
  expect_error(bricklayer_llm_ask("hi"), "disabled")
  Sys.setenv(MORIE_HOSTED_BASE_URL = "https://gw.example/")
  expect_equal(.bl_hosted_base(), "https://gw.example")
})

test_that("the native route posts a bearer-authenticated chat request", {
  .sandbox()
  suppressMessages(bricklayer_llm_login(token = "sk-abc"))
  seen <- NULL
  testthat::local_mocked_bindings(
    .bl_http_post = function(url, body, content_type, timeout, headers) {
      seen <<- list(url = url, body = rawToChar(body), ct = content_type,
                    headers = headers)
      .reply("MORIE")
    })
  expect_equal(bricklayer_llm_ask("say MORIE"), "MORIE")
  expect_equal(seen$url, "https://llm.rmorie.com/v1/chat/completions")
  expect_equal(seen$headers, "Authorization: Bearer sk-abc")
  expect_equal(seen$ct, "application/json")
  req <- bricklayer_json_from_json(seen$body, simplifyVector = FALSE)
  expect_equal(req$model, "minimax-m3:cloud")
  expect_equal(req$messages[[1]]$content, "say MORIE")
  Sys.setenv(MORIE_HOSTED_MODEL = "gemma4:31b-cloud")
  bricklayer_llm_ask("again", system_prompt = "be brief")
  req <- bricklayer_json_from_json(seen$body, simplifyVector = FALSE)
  expect_equal(req$model, "gemma4:31b-cloud")
  expect_equal(req$messages[[1]]$role, "system")
})

test_that("gateway errors are reported with their message", {
  .sandbox()
  expect_error(bricklayer_llm_ask("hi"), "bricklayer_llm_login")
  suppressMessages(bricklayer_llm_login(token = "sk-abc"))
  testthat::local_mocked_bindings(
    .bl_http_post = function(...) list(status = 429L, body = charToRaw(
      "{\"error\":{\"message\":\"Rate limit exceeded\"}}")))
  expect_error(bricklayer_llm_ask("hi"), "429: Rate limit exceeded")
  testthat::local_mocked_bindings(.bl_http_post = function(...) NULL)
  expect_error(bricklayer_llm_ask("hi"), "answered -1")
})

test_that("agent_bundle() uses the hosted route when a key is stored", {
  .sandbox()
  suppressMessages(bricklayer_llm_login(token = "sk-abc"))
  seen <- NULL
  testthat::local_mocked_bindings(
    .bl_http_post = function(url, body, content_type, timeout, headers) {
      seen <<- rawToChar(body)
      .reply("Pin the SHA256 in the manifest.")
    })
  expect_match(agent_bundle("add provenance"), "Pin the SHA256")
  expect_match(seen, "brick-proof", fixed = TRUE)
  suppressMessages(bricklayer_llm_logout())
  expect_match(agent_bundle("x", backend = "hosted"), "No key for the hosted")
})

test_that("bricklayer_llm_status() names the two routes", {
  .sandbox()
  testthat::local_mocked_bindings(Sys.which = function(names) c(rmorie = ""),
                                  .package = "base")
  st <- bricklayer_llm_status()
  expect_equal(st$route, c("hosted MORIE tier", "rmorie-cli agent"))
  expect_equal(st$status, c("not logged in", "absent"))
  suppressMessages(bricklayer_llm_login(token = "sk-abc"))
  expect_equal(bricklayer_llm_status()$status[1], "key stored")
})

test_that("the command line dispatches its verbs", {
  .sandbox()
  testthat::local_mocked_bindings(Sys.which = function(names) c(rmorie = ""),
                                  .package = "base")
  cap <- function(...) {
    buf <- character()
    st <- bricklayer_cli(c(...), out = function(s) buf <<- c(buf, s))
    list(text = paste(buf, collapse = ""), status = st)
  }
  expect_match(cap("version")$text, "rmoriebricklayer 0\\.")
  expect_match(cap()$text, "usage: rmoriebricklayer")
  expect_equal(cap("frobnicate")$status, 1L)
  expect_match(cap("frobnicate")$text, "unknown verb")
  r <- suppressMessages(cap("login", "--token", "sk-cli"))
  expect_equal(r$status, 0L)
  expect_match(r$text, "Logged in to https://llm.rmorie.com")
  expect_equal(.bl_hosted_key(), "sk-cli")
  d <- cap("doctor")
  expect_match(d$text, "hosted MORIE tier +key stored")
  testthat::local_mocked_bindings(.bl_http_post = function(...) .reply("echo"))
  expect_equal(cap("ask", "what", "is", "MORIE")$text, "echo\n")
  expect_match(cap("ask", "--help")$text, "usage: rmoriebricklayer ask")
  expect_equal(cap("bundle", "scaffold", "it")$text, "echo\n")
  expect_equal(cap("bundle")$status, 1L)
  expect_equal(suppressMessages(cap("logout"))$status, 0L)
  expect_null(.bl_hosted_key())
})

test_that("the email sign-in requests a code and exchanges it for a key", {
  .sandbox()
  seen <- list()
  testthat::local_mocked_bindings(
    .bl_http_post = function(url, body, content_type, timeout, headers) {
      seen[[length(seen) + 1L]] <<- list(url = url, body = rawToChar(body))
      if (grepl("/email/code$", url)) {
        return(list(status = 200L,
                    body = charToRaw("{\"sent\":true,\"expires_in\":600}")))
      }
      list(status = 200L,
           body = charToRaw("{\"api_key\":\"sk-mail\",\"user\":\"mail:abc\"}"))
    })
  key <- suppressMessages(bricklayer_llm_login(email = " Vee@Example.com",
                                               code = " 123456 "))
  expect_equal(key, "sk-mail")
  expect_length(seen, 1L)  # a supplied code skips the request step
  expect_equal(seen[[1]]$url, "https://llm.rmorie.com/auth/email/verify")
  req <- bricklayer_json_from_json(seen[[1]]$body)
  expect_equal(req$email, "vee@example.com")
  expect_equal(req$code, "123456")
  expect_equal(.bl_hosted_key(), "sk-mail")
  expect_equal(.bl_read_credentials()$hosted_user, "mail:abc")
  expect_error(bricklayer_llm_login(email = "nope"), "email address")
  testthat::local_mocked_bindings(
    .bl_http_post = function(...) list(status = 403L, body = charToRaw(
      "{\"error\":\"wrong code\"}")))
  expect_error(bricklayer_llm_login(email = "vee@example.com", code = "0"),
               "403: wrong code")
})

test_that("the device flow polls until GitHub approval and stores the key", {
  .sandbox()
  polls <- 0L
  testthat::local_mocked_bindings(
    .bl_http_post = function(url, body, content_type, timeout, headers) {
      if (grepl("/device/code$", url)) {
        return(list(status = 200L, body = charToRaw(paste0(
          "{\"device_code\":\"dev-1\",\"user_code\":\"ABCD-1234\",",
          "\"verification_uri\":\"https://github.com/login/device\",",
          "\"interval\":0}"))))
      }
      polls <<- polls + 1L
      if (polls < 3L) return(list(status = 428L, body = charToRaw(
        "{\"error\":\"authorization_pending\"}")))
      list(status = 200L, body = charToRaw(
        "{\"api_key\":\"sk-dev\",\"user\":\"octocat\"}"))
    })
  expect_message(key <- bricklayer_llm_login(open_browser = FALSE,
                                             poll_max_seconds = 5),
                 "ABCD-1234")
  expect_equal(key, "sk-dev")
  expect_equal(polls, 3L)
  expect_equal(.bl_hosted_key(), "sk-dev")
  expect_equal(.bl_read_credentials()$hosted_user, "octocat")
})

test_that("the command line helps people find their way around the package", {
  cap <- function(...) {
    buf <- character()
    st <- bricklayer_cli(c(...), out = function(s) buf <<- c(buf, s))
    list(text = paste(buf, collapse = ""), status = st)
  }
  f <- cap("functions", "^bricklayer_json_(to|from)_json$")
  expect_equal(f$status, 0L)
  lines <- strsplit(f$text, "\n", fixed = TRUE)[[1]]
  expect_length(lines, 2L)
  expect_match(lines[1], "^  bricklayer_json_from_json  .+")
  expect_match(cap("functions", "zzz_nothing")$text, "no exported function")
  d <- cap("describe", "agent_bundle")
  expect_equal(d$status, 0L)
  expect_match(d$text, "Usage:")
  expect_match(d$text, "agent_bundle(request", fixed = TRUE)
  expect_match(d$text, "Arguments:")
  expect_match(cap("describe", "no_such_fn")$text, "no help page")
  expect_equal(cap("describe")$status, 1L)
  e <- cap("examples", "bricklayer_llm_status")
  expect_match(e$text, "bricklayer_llm_status()", fixed = TRUE)
})

test_that("the launcher ships and install_cli() links it into a directory", {
  src <- system.file("bin", "rmoriebricklayer", package = "rmoriebricklayer")
  expect_true(nzchar(src))
  expect_match(readLines(src)[1], "^#!/bin/sh")
  expect_true(any(grepl("bricklayer_cli", readLines(src), fixed = TRUE)))
  dir <- tempfile("bin-")
  target <- suppressMessages(install_cli(dir = dir))
  expect_true(file.exists(target))
  if (.Platform$OS.type != "windows") {
    expect_true(file.access(target, 1L) == 0L)
  }
  unlink(dir, recursive = TRUE)
})
