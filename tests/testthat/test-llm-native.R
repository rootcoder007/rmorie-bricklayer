# SPDX-License-Identifier: AGPL-3.0-or-later
#
# The native hosted-LLM route and the command line. The HTTP layer is
# replaced by canned replies; the credentials file lives in a temporary
# XDG_CONFIG_HOME. Nothing leaves the machine and nothing touches $HOME.

.sandbox <- function(env = parent.frame()) {
  # storing a token asks the gateway first: offline here, the check passes
  testthat::local_mocked_bindings(.bl_check_token = function(token) invisible(TRUE), .env = env)
  dir <- tempfile("xdg-")
  dir.create(dir)
  old <- Sys.getenv(
    c(
      "XDG_CONFIG_HOME", "MORIE_HOSTED_KEY",
      "MORIE_HOSTED_BASE_URL", "MORIE_HOSTED_MODEL",
      "MORIE_LLM_BASE_URL", "OLLAMA_HOST"
    ),
    unset = NA
  )
  # the hosted route alone is under test here: no endpoint of our own, no local Ollama
  Sys.setenv(XDG_CONFIG_HOME = dir, OLLAMA_HOST = "off")
  Sys.unsetenv(c(
    "MORIE_HOSTED_KEY", "MORIE_HOSTED_BASE_URL",
    "MORIE_HOSTED_MODEL", "MORIE_LLM_BASE_URL"
  ))
  withr_restore <- function() {
    for (nm in names(old)) {
      if (is.na(old[[nm]])) {
        Sys.unsetenv(nm)
      } else {
        do.call(
          Sys.setenv,
          as.list(old[nm])
        )
      }
    }
    unlink(dir, recursive = TRUE)
  }
  do.call(on.exit, list(substitute(withr_restore()), add = TRUE),
    envir = env
  )
  assign("withr_restore", withr_restore, envir = env)
  dir
}

.reply <- function(text, status = 200L) {
  body <- bricklayer_json_to_json(
    list(choices = list(list(message = list(
      role = "assistant",
      content = text
    )))),
    auto_unbox = TRUE
  )
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
  suppressMessages(bricklayer_llm_login(token = "file-key"))
  Sys.setenv(MORIE_HOSTED_KEY = "env-key")
  expect_equal(.bl_hosted_key(), "env-key")
  Sys.setenv(MORIE_HOSTED_BASE_URL = "off")
  expect_null(.bl_hosted_base())
  expect_error(bricklayer_llm_ask("hi"), "hosted MORIE tier: disabled (MORIE_HOSTED_BASE_URL=off)", fixed = TRUE)
  Sys.setenv(MORIE_HOSTED_BASE_URL = "https://gw.example/")
  expect_equal(.bl_hosted_base(), "https://gw.example")
})

test_that("the native route posts a bearer-authenticated chat request", {
  .sandbox()
  suppressMessages(bricklayer_llm_login(token = "sk-abc"))
  seen <- NULL
  testthat::local_mocked_bindings(
    .bl_http_post = function(url, body, content_type, timeout, headers) {
      seen <<- list(
        url = url, body = rawToChar(body), ct = content_type,
        headers = headers
      )
      .reply("MORIE")
    }
  )
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
    .bl_http_post = function(...) {
      list(status = 429L, body = charToRaw(
        "{\"error\":{\"message\":\"Rate limit exceeded\"}}"
      ))
    }
  )
  expect_error(bricklayer_llm_ask("hi"), "429: Rate limit exceeded")
  testthat::local_mocked_bindings(.bl_http_post = function(...) NULL)
  expect_error(bricklayer_llm_ask("hi"), "could not reach the hosted MORIE LLM tier")
})

test_that("agent_bundle() uses the hosted route when a key is stored", {
  .sandbox()
  suppressMessages(bricklayer_llm_login(token = "sk-abc"))
  seen <- NULL
  testthat::local_mocked_bindings(
    .bl_http_post = function(url, body, content_type, timeout, headers) {
      seen <<- rawToChar(body)
      .reply("Pin the SHA256 in the manifest.")
    }
  )
  expect_match(agent_bundle("add provenance"), "Pin the SHA256")
  expect_match(seen, "brick-proof", fixed = TRUE)
  suppressMessages(bricklayer_llm_logout())
  expect_match(agent_bundle("x", backend = "hosted"), "No language-model route is set up")
})

test_that("bricklayer_llm_status() names the hosted route", {
  .sandbox()
  st <- bricklayer_llm_status()
  expect_equal(st$route, c("own endpoint", "local Ollama", "hosted MORIE tier"))
  expect_equal(st$status[3], "not logged in")
  expect_match(st$detail[3], "request a key at https://rmorie.com/access")
  suppressMessages(bricklayer_llm_login(token = "sk-abc"))
  expect_equal(bricklayer_llm_status()$status[3], "key stored")
})

test_that("the command line dispatches its verbs", {
  .sandbox()
  cap <- function(...) {
    buf <- character()
    st <- bricklayer_cli(c(...), out = function(s) buf <<- c(buf, s))
    list(text = paste(buf, collapse = ""), status = st)
  }
  expect_match(cap("version")$text, "rmoriebricklayer 0\\.")
  expect_match(cap()$text, "usage: rmoriebricklayer")
  expect_equal(cap("frobnicate")$status, 2L)  # an unknown verb is a usage error
  # `login --token` asks the gateway first: here it accepts the key
  testthat::local_mocked_bindings(.bl_models_reply = function(...) list(status = 200L, body = charToRaw("{}")))
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
  expect_equal(cap("bundle")$status, 2L)  # a missing request is a usage error
  expect_equal(suppressMessages(cap("logout"))$status, 0L)
  expect_null(.bl_hosted_key())
})

test_that("models lists the hosted tier's models and ask --model names one", {
  .sandbox()
  cap <- function(...) {
    buf <- character()
    st <- bricklayer_cli(c(...), out = function(s) buf <<- c(buf, s))
    list(text = paste(buf, collapse = ""), status = st)
  }
  expect_match(cap("models")$text, "not logged in")
  expect_length(bricklayer_llm_models(), 0L)
  suppressMessages(bricklayer_llm_login(token = "sk-models"))
  seen <- NULL
  testthat::local_mocked_bindings(.bl_http_get = function(url, timeout, headers) {
    seen <<- list(url = url, headers = headers)
    list(status = 200L, body = charToRaw('{"data":[{"id":"a:cloud"},{"id":"b:cloud"}]}'))
  })
  old_model <- Sys.getenv("MORIE_HOSTED_MODEL", unset = NA)
  on.exit(if (is.na(old_model)) {
    Sys.unsetenv("MORIE_HOSTED_MODEL")
  } else {
    Sys.setenv(MORIE_HOSTED_MODEL = old_model)
  }, add = TRUE)
  Sys.setenv(MORIE_HOSTED_MODEL = "b:cloud")
  hm <- bricklayer_llm_models()
  expect_equal(as.character(hm), c("a:cloud", "b:cloud"))
  expect_equal(attr(hm, "default"), "b:cloud")
  expect_equal(seen$url, "https://llm.rmorie.com/v1/models")
  expect_equal(seen$headers, "Authorization: Bearer sk-models")
  Sys.setenv(MORIE_HOSTED_MODEL = "retired:cloud")
  expect_equal(attr(bricklayer_llm_models(), "default"), "a:cloud")
  m <- cap("models")
  expect_equal(m$status, 0L)
  expect_match(m$text, "default marked \\*:\n  \\* a:cloud\n    b:cloud\n")
  expect_match(cap("doctor")$text, "models: a:cloud, b:cloud \\(default a:cloud\\)")
  testthat::local_mocked_bindings(.bl_http_get = function(...) list(status = 502L, body = raw()))
  expect_length(bricklayer_llm_models(), 0L)
  expect_match(cap("models")$text, "gateway not reachable")
  asked <- NULL
  testthat::local_mocked_bindings(bricklayer_llm_ask = function(prompt, model = NULL, ...) {
    asked <<- model
    "echo"
  })
  expect_equal(cap("ask", "--model", "a:cloud", "hi", "there")$text, "echo\n")
  expect_equal(asked, "a:cloud")
  expect_equal(cap("ask", "hi")$text, "echo\n")
  expect_null(asked)
  expect_match(cap("ask", "--help")$text,
               "usage: rmoriebricklayer ask \\[--route own\\|ollama\\|hosted\\|auto\\] \\[--model NAME\\]")
})

test_that("the email sign-in requests a code and exchanges it for a key", {
  .sandbox()
  seen <- list()
  testthat::local_mocked_bindings(
    .bl_http_post = function(url, body, content_type, timeout, headers) {
      seen[[length(seen) + 1L]] <<- list(url = url, body = rawToChar(body))
      if (grepl("/email/code$", url)) {
        return(list(
          status = 200L,
          body = charToRaw("{\"sent\":true,\"expires_in\":600}")
        ))
      }
      list(
        status = 200L,
        body = charToRaw("{\"api_key\":\"sk-mail\",\"user\":\"mail:abc\"}")
      )
    }
  )
  key <- suppressMessages(bricklayer_llm_login(
    email = " Vee@Example.com",
    code = " 123456 "
  ))
  expect_equal(key, "sk-mail")
  expect_length(seen, 1L) # a supplied code skips the request step
  expect_equal(seen[[1]]$url, "https://llm.rmorie.com/auth/email/verify")
  req <- bricklayer_json_from_json(seen[[1]]$body)
  expect_equal(req$email, "vee@example.com")
  expect_equal(req$code, "123456")
  expect_equal(.bl_hosted_key(), "sk-mail")
  expect_equal(.bl_read_credentials()$hosted_user, "mail:abc")
  expect_error(bricklayer_llm_login(email = "nope"), "email address")
  testthat::local_mocked_bindings(
    .bl_http_post = function(...) {
      list(status = 403L, body = charToRaw(
        "{\"error\":\"wrong code\"}"
      ))
    }
  )
  expect_error(
    bricklayer_llm_login(email = "vee@example.com", code = "0"),
    "403: wrong code"
  )
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
          "\"interval\":0}"
        ))))
      }
      polls <<- polls + 1L
      if (polls < 3L) {
        return(list(status = 428L, body = charToRaw(
          "{\"error\":\"authorization_pending\"}"
        )))
      }
      list(status = 200L, body = charToRaw(
        "{\"api_key\":\"sk-dev\",\"user\":\"octocat\"}"
      ))
    }
  )
  msgs <- testthat::capture_messages(
    key <- bricklayer_llm_login(
      open_browser = FALSE,
      poll_max_seconds = 5
    )
  )
  expect_match(paste(msgs, collapse = ""), "ABCD-1234")
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
  expect_equal(cap("describe")$status, 2L)  # a missing name is a usage error
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

test_that("the credentials path and reader cope with no XDG dir and bad JSON", {
  dir <- .sandbox()
  old <- Sys.getenv("XDG_CONFIG_HOME")
  Sys.unsetenv("XDG_CONFIG_HOME")
  expect_match(.bl_credentials_path(),
    file.path(".config", "morie", "credentials.json"),
    fixed = TRUE
  )
  Sys.setenv(XDG_CONFIG_HOME = old)
  p <- .bl_credentials_path()
  dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE)
  writeLines("{not json", p)
  expect_equal(.bl_read_credentials(), list())
  expect_null(.bl_hosted_key())
  Sys.setenv(MORIE_HOSTED_AUTH_URL = "https://auth.example/x/")
  expect_equal(.bl_hosted_auth(), "https://auth.example/x")
  Sys.unsetenv("MORIE_HOSTED_AUTH_URL")
  expect_equal(.bl_hosted_auth(), "https://llm.rmorie.com/auth")
})

test_that("the real POST primitive reports an unreachable host as -1", {
  # port 9 (discard) on the loopback is closed on every CI runner; nothing
  # leaves the machine
  res <- .bl_http_post(
    "http://127.0.0.1:9/v1/chat/completions",
    charToRaw("{}"), "application/json", 2L, NULL
  )
  expect_equal(as.integer(res$status), -1L)
  expect_error(
    .bl_http_post(
      "http://127.0.0.1:9/", charToRaw("{}"),
      "application/json", 2L, 42
    ),
    "headers"
  )
})

test_that("a reply without text and a reply with a plain error string are reported", {
  .sandbox()
  suppressMessages(bricklayer_llm_login(token = "sk-abc"))
  testthat::local_mocked_bindings(.bl_http_post = function(...) {
    list(
      status = 200L, body = charToRaw("{\"choices\":[{\"message\":{\"content\":\"\"}}]}")
    )
  })
  expect_error(bricklayer_llm_ask("hi"), "returned no text")
  testthat::local_mocked_bindings(.bl_http_post = function(...) {
    list(
      status = 500L, body = charToRaw("{\"error\":\"boom\"}")
    )
  })
  expect_error(bricklayer_llm_ask("hi"), "500: boom")
  testthat::local_mocked_bindings(.bl_http_post = function(...) {
    list(
      status = 502L, body = charToRaw("not json")
    )
  })
  expect_error(bricklayer_llm_ask("hi"), "answered 502$")
})

test_that("the email flow asks for the code when none is given and reports errors", {
  .sandbox()
  calls <- character()
  testthat::local_mocked_bindings(
    .bl_http_post = function(url, body, content_type, timeout, headers) {
      calls <<- c(calls, sub(".*/auth", "", url))
      if (grepl("/email/code$", url)) {
        return(list(status = 200L, body = charToRaw("{\"sent\":true}")))
      }
      list(status = 200L, body = charToRaw("{\"api_key\":\"sk-typed\"}"))
    }
  )
  testthat::local_mocked_bindings(.bl_readline = function(prompt) "654321")
  msgs <- testthat::capture_messages(
    key <- bricklayer_llm_login(email = "vee@example.com")
  )
  expect_match(paste(msgs, collapse = ""), "6-digit code")
  expect_equal(key, "sk-typed")
  expect_equal(calls, c("/email/code", "/email/verify"))
  testthat::local_mocked_bindings(.bl_http_post = function(...) {
    list(
      status = 429L, body = charToRaw("{\"error\":\"too many codes\"}")
    )
  })
  expect_error(
    bricklayer_llm_login(email = "vee@example.com"),
    "429: too many codes"
  )
  testthat::local_mocked_bindings(.bl_http_post = function(...) {
    list(
      status = 200L, body = charToRaw("{\"sent\":true}")
    )
  })
  expect_error(
    bricklayer_llm_login(email = "vee@example.com", code = "1"),
    "returned no key"
  )
})

test_that("the device flow opens the browser, rejects a hard error and times out", {
  .sandbox()
  opened <- NULL
  testthat::local_mocked_bindings(
    browseURL = function(url, ...) opened <<- url,
    .package = "utils"
  )
  start_reply <- list(status = 200L, body = charToRaw(paste0(
    "{\"device_code\":\"dev-2\",\"user_code\":\"WXYZ-0000\",",
    "\"verification_uri\":\"https://github.com/login/device\",\"interval\":0}"
  )))
  testthat::local_mocked_bindings(
    .bl_http_post = function(url, ...) {
      if (grepl("/device/code$", url)) {
        return(start_reply)
      }
      list(status = 400L, body = charToRaw("{\"error\":\"expired_token\"}"))
    }
  )
  expect_error(
    suppressMessages(bricklayer_llm_login(
      open_browser = TRUE,
      poll_max_seconds = 5
    )),
    "400: expired_token"
  )
  expect_equal(opened, "https://github.com/login/device")
  testthat::local_mocked_bindings(
    .bl_http_post = function(url, ...) {
      if (grepl("/device/code$", url)) {
        return(start_reply)
      }
      list(status = 428L, body = charToRaw("{\"error\":\"authorization_pending\"}"))
    }
  )
  expect_error(
    suppressMessages(bricklayer_llm_login(
      open_browser = FALSE,
      poll_max_seconds = 0
    )),
    "timed out"
  )
  testthat::local_mocked_bindings(.bl_http_post = function(...) {
    list(
      status = 503L, body = charToRaw("{\"error\":\"down\"}")
    )
  })
  expect_error(bricklayer_llm_login(open_browser = FALSE), "503: down")
})

test_that("logout keeps unrelated entries in the shared file", {
  .sandbox()
  .bl_write_credentials(list(hosted_key = "sk-x", other_tool = "keep"))
  expect_message(expect_true(bricklayer_llm_logout()), "Logged out")
  expect_equal(.bl_read_credentials(), list(other_tool = "keep"))
})

test_that("the command line prompts for a token, runs the device flow and checks flags", {
  .sandbox()
  cap <- function(...) {
    buf <- character()
    st <- bricklayer_cli(c(...), out = function(s) buf <<- c(buf, s))
    list(text = paste(buf, collapse = ""), status = st)
  }
  testthat::local_mocked_bindings(.bl_readline = function(prompt) "sk-prompted")
  testthat::local_mocked_bindings(.bl_models_reply = function(...) list(status = 200L, body = charToRaw("{}")))
  r <- suppressMessages(cap("login", "--token"))
  expect_equal(r$status, 0L)
  expect_equal(.bl_hosted_key(), "sk-prompted")
  suppressMessages(bricklayer_llm_logout())
  e <- cap("login", "--email")
  expect_equal(e$status, 2L)  # a flag without its value is a usage error
  expect_match(e$text, "--email needs a value")
  testthat::local_mocked_bindings(
    .bl_http_post = function(url, ...) {
      if (grepl("/device/code$", url)) {
        return(list(status = 200L, body = charToRaw(paste0(
          "{\"device_code\":\"d\",\"user_code\":\"AAAA-1111\",",
          "\"verification_uri\":\"https://github.com/login/device\",\"interval\":0}"
        ))))
      }
      list(status = 200L, body = charToRaw("{\"api_key\":\"sk-cli-dev\",\"user\":\"vee\"}"))
    }
  )
  d <- suppressMessages(cap("login", "--no-browser"))
  expect_equal(d$status, 0L)
  expect_equal(.bl_hosted_key(), "sk-cli-dev")
  expect_equal(cap("examples")$status, 2L)  # a missing name is a usage error
  expect_match(cap("examples", "no_such_fn")$text, "no help page")
})

test_that("the Rd database falls back to the man directory and install_cli copies when it cannot link", {
  testthat::local_mocked_bindings(
    Rd_db = function(package, dir, ...) {
      if (!missing(package)) stop("no installed help")
      list()
    },
    .package = "tools"
  )
  expect_equal(.bl_rd_db(), list())
  testthat::local_mocked_bindings(
    file.symlink = function(from, to) FALSE,
    .package = "base"
  )
  dir <- tempfile("bin-")
  target <- suppressMessages(install_cli(dir = dir))
  expect_true(file.exists(target))
  if (.Platform$OS.type == "windows") {
    expect_match(readLines(target)[1], "^@echo off") # the .cmd wrapper
  } else {
    expect_false(!is.na(Sys.readlink(target)) && nzchar(Sys.readlink(target)))
    expect_match(readLines(target)[1], "^#!/bin/sh")
  }
  unlink(dir, recursive = TRUE)
})

test_that("the status says when the tier is off, and an explicit model reaches the gateway", {
  .sandbox()
  withr::local_envvar(MORIE_HOSTED_BASE_URL = "off")
  st <- bricklayer_llm_status()
  expect_identical(st$status[3], "disabled")
  expect_identical(st$detail[3], "MORIE_HOSTED_BASE_URL=off")

  withr::local_envvar(MORIE_HOSTED_BASE_URL = "https://gw.example", MORIE_HOSTED_KEY = "sk-test")
  seen <- NULL
  testthat::local_mocked_bindings(.bl_post_json = function(url, payload, ...) {
    seen <<- payload
    list(status = 200L, json = list(choices = list(list(message = list(content = "pong")))))
  })
  expect_identical(bricklayer_llm_ask("ping", model = "custom-model"), "pong")
  expect_identical(seen$model, "custom-model")
})

test_that("install_cli() writes both launchers, pinned with .libPaths() and without --args", {
  skip_on_os("windows")
  d <- withr::local_tempdir()
  primary <- suppressMessages(install_cli(dir = d))
  expect_equal(basename(primary), "rmoriebricklayer")
  paths <- file.path(d, c("rmoriebricklayer", "rmbl"))
  expect_true(all(file.exists(paths)))
  for (p in paths) {
    txt <- paste(readLines(p), collapse = "\n")
    expect_match(txt, ".libPaths(c(", fixed = TRUE)
    expect_false(grepl("--args", txt, fixed = TRUE))
    expect_false(grepl("--vanilla", txt, fixed = TRUE))
    expect_true(file.access(p, 1L) == 0L)
  }
  # a second install replaces the launchers it finds, links included
  file.remove(paths[[2L]])
  file.symlink(paths[[1L]], paths[[2L]])
  suppressMessages(install_cli(dir = d))
  expect_true(is.na(Sys.readlink(paths[[2L]])) || !nzchar(Sys.readlink(paths[[2L]])))
  expect_match(paste(readLines(paths[[2L]]), collapse = "\n"),
               "# rmbl: the rmoriebricklayer command line", fixed = TRUE)
})

test_that("login --help prints the usage and the usage names rmbl", {
  buf <- character()
  st <- bricklayer_cli(c("login", "--help"), out = function(x) buf <<- c(buf, x))
  expect_equal(st, 0L)
  expect_match(paste(buf, collapse = ""), "usage: rmoriebricklayer login")
  buf <- character()
  bricklayer_cli("help", out = function(x) buf <<- c(buf, x))
  expect_match(paste(buf, collapse = ""), "rmbl is the same command")
})


test_that("a dropped connection is retried once and then named with curl's reason", {
  .sandbox()
  suppressMessages(bricklayer_llm_login(token = "sk-abc"))
  n <- 0L
  testthat::local_mocked_bindings(
    .bl_http_post = function(url, body, content_type, timeout, headers) {
      n <<- n + 1L
      if (n > 1L) return(.reply("back"))
      list(status = -1L, body = raw(), error = "Recv failure: Connection reset by peer")
    }
  )
  expect_equal(bricklayer_llm_ask("hi"), "back")  # the second try answered
  expect_equal(n, 2L)
  testthat::local_mocked_bindings(
    .bl_http_post = function(url, body, content_type, timeout, headers) {
      list(status = -1L, body = raw(), error = "Recv failure: Connection reset by peer")
    }
  )
  expect_error(bricklayer_llm_ask("hi"),
               "could not reach the hosted MORIE LLM tier \\(Recv failure: Connection reset by peer\\)")
})

test_that("an empty answer names why, and the request leaves room for reasoning models", {
  .sandbox()
  suppressMessages(bricklayer_llm_login(token = "sk-abc"))
  seen <- NULL
  testthat::local_mocked_bindings(
    .bl_http_post = function(url, body, content_type, timeout, headers) {
      seen <<- bricklayer_json_from_json(rawToChar(body), simplifyVector = FALSE)
      b <- bricklayer_json_to_json(list(choices = list(list(message = list(content = ""), finish_reason = "length"))),
                                   auto_unbox = TRUE)
      list(status = 200L, body = charToRaw(b))
    }
  )
  expect_error(bricklayer_llm_ask("hi"), "returned no text \\(finish_reason: length")
  expect_equal(seen$max_tokens, 4096L)
})

test_that("agent_bundle tells the model which functions the package has", {
  .sandbox()
  suppressMessages(bricklayer_llm_login(token = "sk-abc"))
  sent <- NULL
  testthat::local_mocked_bindings(bricklayer_llm_ask = function(prompt, ...) {
    sent <<- prompt
    "plan"
  })
  expect_equal(agent_bundle("bundle analysis.R"), "plan")
  for (fn in c("resolve_via_ckan()", "friendly_download()", "make_manifest()", "capsule_bundle()")) {
    expect_true(grepl(fn, sent, fixed = TRUE), info = fn)
  }
})
