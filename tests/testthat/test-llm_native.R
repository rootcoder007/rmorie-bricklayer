# battery: runs in CI and locally; CRAN runs the correctness core
testthat::skip_on_cran()
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# The native language-model route (a provider's key) and the command line.
# The HTTP layer is replaced by canned replies; the
# credentials file lives in a temporary XDG_CONFIG_HOME. Nothing leaves the
# machine and nothing touches $HOME.

.sandbox <- function(env = parent.frame()) {
  dir <- tempfile("xdg-")
  dir.create(dir)
  old <- Sys.getenv(
    c(
      "XDG_CONFIG_HOME",
      "MORIE_HOSTED_KEY",
      "MORIE_HOSTED_BASE_URL",
      "MORIE_HOSTED_MODEL",
      "MORIE_LLM_BASE_URL",
      "OLLAMA_HOST",
      "OPENAI_API_KEY",
      "MORIE_OPENAI_MODEL"
    ),
    unset = NA
  )
  # a provider's key alone is under test here: no endpoint of our own, no local
  # Ollama
  Sys.setenv(XDG_CONFIG_HOME = dir, OLLAMA_HOST = "off")
  Sys.unsetenv(c(
    "MORIE_HOSTED_KEY",
    "MORIE_HOSTED_BASE_URL",
    "MORIE_HOSTED_MODEL",
    "MORIE_LLM_BASE_URL",
    "OPENAI_API_KEY",
    "MORIE_OPENAI_MODEL"
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
  do.call(on.exit, list(substitute(withr_restore()), add = TRUE), envir = env)
  assign("withr_restore", withr_restore, envir = env)
  dir
}

.reply <- function(text, status = 200L) {
  body <- tojs(
    list(
      choices = list(list(
        message = list(
          role = "assistant",
          content = text
        )
      ))
    ),
    auto_unbox = TRUE
  )
  list(status = status, body = charToRaw(body))
}

test_that(
  paste0(
    "a data key is no model route"
  ),
  {
    .sandbox()
    Sys.setenv(MORIE_HOSTED_KEY = "env-key")
    expect_error(
      llmask("hi"),
      "No language-model route is set up",
      fixed = TRUE
    )
  }
)

test_that("the native route posts a bearer-authenticated chat request", {
  .sandbox()
  Sys.setenv(OPENAI_API_KEY = "sk-abc", MORIE_OPENAI_MODEL = "gpt-x")
  rec <- new.env()
  rec$seen <- NULL
  testthat::local_mocked_bindings(
    .bl_http_post = function(url, body, content_type, timeout, headers) {
      rec$seen <- list(
        url = url,
        body = rawToChar(body),
        ct = content_type,
        headers = headers
      )
      .reply("MORIE")
    }
  )
  expect_identical(llmask("say MORIE", docs = FALSE), "MORIE")
  expect_identical(rec$seen$url, "https://api.openai.com/v1/chat/completions")
  expect_identical(rec$seen$headers, "Authorization: Bearer sk-abc")
  expect_identical(rec$seen$ct, "application/json")
  req <- fromjs(rec$seen$body, simplifyVector = FALSE)
  expect_identical(req$model, "gpt-x")
  expect_identical(req$messages[[1]]$content, "say MORIE")
  Sys.setenv(MORIE_OPENAI_MODEL = "gpt-y")
  llmask("again", syspro = "be brief", docs = FALSE)
  req <- fromjs(rec$seen$body, simplifyVector = FALSE)
  expect_identical(req$model, "gpt-y")
  expect_identical(req$messages[[1]]$role, "system")
})

test_that("gateway errors are reported with their message", {
  .sandbox()
  expect_error(llmask("hi"), "config setup` walks through it")
  Sys.setenv(OPENAI_API_KEY = "sk-abc", MORIE_OPENAI_MODEL = "gpt-x")
  testthat::local_mocked_bindings(
    .bl_http_post = function(...) {
      list(
        status = 429L,
        body = charToRaw(
          "{\"error\":{\"message\":\"Rate limit exceeded\"}}"
        )
      )
    }
  )
  expect_error(llmask("hi"), "429: Rate limit exceeded")
  testthat::local_mocked_bindings(.bl_http_post = function(...) NULL)
  expect_error(llmask("hi"), "could not reach OpenAI")
})

test_that("agentbndl() uses a provider when its key is set", {
  .sandbox()
  Sys.setenv(OPENAI_API_KEY = "sk-abc", MORIE_OPENAI_MODEL = "gpt-x")
  rec <- new.env()
  rec$seen <- NULL
  testthat::local_mocked_bindings(
    .bl_http_post = function(url, body, content_type, timeout, headers) {
      rec$seen <- rawToChar(body)
      .reply("Pin the SHA256 in the manifest.")
    }
  )
  expect_match(agentbndl("add provenance"), "Pin the SHA256")
  expect_match(rec$seen, "brick-proof", fixed = TRUE)
  Sys.unsetenv("OPENAI_API_KEY")
  expect_match(agentbndl("x"), "No language-model route is set up")
})

test_that("llmstat() names the providers and which have a key", {
  .sandbox()
  st <- llmstat()
  expect_identical(
    st$route,
    c("own endpoint", "other providers", "local Ollama")
  )
  expect_identical(st$status[2], "no key")
  expect_match(
    st$detail[2],
    "openai (OPENAI_API_KEY), anthropic (ANTHROPIC_API_KEY)",
    fixed = TRUE
  )
  Sys.setenv(OPENAI_API_KEY = "sk-abc", MORIE_OPENAI_MODEL = "gpt-x")
  st <- llmstat()
  expect_identical(
    st$route,
    c("own endpoint", "OpenAI", "other providers", "local Ollama")
  )
  expect_identical(st$status[2], "key set")
  expect_match(
    st$detail[2],
    "https://api.openai.com/v1  model: gpt-x",
    fixed = TRUE
  )
  expect_false(grepl("openai (OPENAI_API_KEY)", st$detail[3], fixed = TRUE))
})

test_that("the command line dispatches its verbs", {
  .sandbox()
  cap <- function(...) {
    rec <- new.env()
    rec$buf <- character()
    st <- blcli(c(...), out = function(s) rec$buf <- c(rec$buf, s))
    list(text = paste(rec$buf, collapse = ""), status = st)
  }
  expect_match(
    cap("version")$text,
    paste0("rmoriebricklayer ", utils::packageVersion("rmoriebricklayer")),
    fixed = TRUE
  )
  expect_match(cap()$text, "usage: rmoriebricklayer")
  # an unknown verb is a usage error
  expect_identical(cap("frobnicate")$status, 2L)
  expect_match(cap("frobnicate")$text, "unknown verb")
  d <- cap("doctor")
  # the data key is not a language model
  expect_match(d$text, "ask has no route yet")
  Sys.setenv(OPENAI_API_KEY = "sk-abc", MORIE_OPENAI_MODEL = "gpt-x")
  testthat::local_mocked_bindings(.bl_http_post = function(...) .reply("echo"))
  expect_identical(cap("ask", "what", "is", "MORIE")$text, "echo\n")
  expect_match(cap("ask", "--help")$text, "usage: rmoriebricklayer ask")
  expect_identical(cap("bundle", "scaffold", "it")$text, "echo\n")
  # a missing request is a usage error
  expect_identical(cap("bundle")$status, 2L)
})

test_that("models lists the route's models and ask --model names one", {
  .sandbox()
  cap <- function(...) {
    rec <- new.env()
    rec$buf <- character()
    st <- blcli(c(...), out = function(s) rec$buf <- c(rec$buf, s))
    list(text = paste(rec$buf, collapse = ""), status = st)
  }
  expect_match(cap("models")$text, "No language-model route is set up")
  expect_length(llmmdls(), 0L)
  Sys.setenv(OPENAI_API_KEY = "sk-models", MORIE_OPENAI_MODEL = "b-model")
  rec <- new.env()
  rec$seen <- NULL
  testthat::local_mocked_bindings(.bl_http_get = function(
    url,
    timeout,
    headers
  ) {
    rec$seen <- list(url = url, headers = headers)
    list(
      status = 200L,
      body = charToRaw('{"data":[{"id":"a-model"},{"id":"b-model"}]}')
    )
  })
  hm <- llmmdls()
  expect_identical(as.character(hm), c("a-model", "b-model"))
  expect_identical(attr(hm, "default"), "b-model")
  expect_identical(attr(hm, "route"), "OpenAI")
  expect_identical(rec$seen$url, "https://api.openai.com/v1/models")
  expect_identical(rec$seen$headers, "Authorization: Bearer sk-models")
  m <- cap("models")
  expect_identical(m$status, 0L)
  expect_match(
    m$text,
    "OpenAI; the model in use is marked \\*:\n    a-model\n  \\* b-model\n"
  )
  expect_match(m$text, "config set openai.model NAME", fixed = TRUE)
  testthat::local_mocked_bindings(.bl_http_get = function(...) {
    list(status = 502L, body = raw())
  })
  expect_length(llmmdls(), 0L)
  expect_match(
    cap("models")$text,
    "OpenAI: no model list to show .*the model in use is b-model"
  )
  rec$asked <- NULL
  testthat::local_mocked_bindings(llmask = function(prompt, model = NULL, ...) {
    rec$asked <- model
    "echo"
  })
  expect_identical(
    cap("ask", "--model", "a-model", "hi", "there")$text,
    "echo\n"
  )
  expect_identical(rec$asked, "a-model")
  expect_identical(cap("ask", "hi")$text, "echo\n")
  expect_null(rec$asked)
  expect_match(
    cap("ask", "--help")$text,
    paste0(
      "usage: rmoriebricklayer ask \\[--route ",
      "auto\\|own\\|ollama\\|PROVIDER\\] \\[--model NAME\\]"
    )
  )
})

test_that("the command line helps people find their way around the package", {
  cap <- function(...) {
    rec <- new.env()
    rec$buf <- character()
    st <- blcli(c(...), out = function(s) rec$buf <- c(rec$buf, s))
    list(text = paste(rec$buf, collapse = ""), status = st)
  }
  f <- cap("functions", "^(fromjs|tojs)$")
  expect_identical(f$status, 0L)
  lines <- strsplit(f$text, "\n", fixed = TRUE)[[1]]
  expect_length(lines, 2L)
  expect_match(lines[1], "^  fromjs  .+")
  expect_match(cap("functions", "zzz_nothing")$text, "no exported function")
  d <- cap("describe", "agentbndl")
  expect_identical(d$status, 0L)
  expect_match(d$text, "Usage:")
  expect_match(d$text, "agentbndl(req", fixed = TRUE)
  expect_match(d$text, "Arguments:")
  expect_match(cap("describe", "no_such_fn")$text, "no help page")
  expect_identical(cap("describe")$status, 2L) # a missing name is a usage error
  e <- cap("examples", "llmstat")
  expect_match(e$text, "llmstat()", fixed = TRUE)
})

test_that("the launcher ships and instcli() links it into a directory", {
  src <- system.file("bin", "rmoriebricklayer", package = "rmoriebricklayer")
  expect_true(nzchar(src))
  expect_match(readLines(src)[1], "^#!/bin/sh")
  expect_true(any(grepl("blcli", readLines(src), fixed = TRUE)))
  dir <- tempfile("bin-")
  target <- suppressMessages(instcli(dir = dir))
  expect_true(file.exists(target))
  if (.Platform$OS.type != "windows") {
    expect_identical(unname(file.access(target, 1L)), 0L)
  }
  unlink(dir, recursive = TRUE)
})

test_that("the credentials path copes with no XDG dir", {
  dir <- .sandbox()
  old <- Sys.getenv("XDG_CONFIG_HOME")
  Sys.unsetenv("XDG_CONFIG_HOME")
  expect_match(
    .bl_credentials_path(),
    file.path(".config", "morie", "credentials.json"),
    fixed = TRUE
  )
  Sys.setenv(XDG_CONFIG_HOME = old)
})

test_that("the real POST primitive reports an unreachable host as -1", {
  # port 9 (discard) on the loopback is closed on every CI runner; nothing
  # leaves the machine
  res <- .bl_http_post(
    "http://127.0.0.1:9/v1/chat/completions",
    charToRaw("{}"),
    "application/json",
    2L,
    NULL
  )
  expect_identical(as.integer(res$status), -1L)
  expect_error(
    .bl_http_post(
      "http://127.0.0.1:9/",
      charToRaw("{}"),
      "application/json",
      2L,
      42
    ),
    "headers"
  )
})

test_that(
  paste0(
    "a reply without text and a reply with a ",
    "plain error string are reported"
  ),
  {
    .sandbox()
    Sys.setenv(OPENAI_API_KEY = "sk-abc", MORIE_OPENAI_MODEL = "gpt-x")
    testthat::local_mocked_bindings(.bl_http_post = function(...) {
      list(
        status = 200L,
        body = charToRaw("{\"choices\":[{\"message\":{\"content\":\"\"}}]}")
      )
    })
    expect_error(llmask("hi"), "returned no text")
    testthat::local_mocked_bindings(.bl_http_post = function(...) {
      list(
        status = 500L,
        body = charToRaw("{\"error\":\"boom\"}")
      )
    })
    expect_error(llmask("hi"), "500: boom")
    testthat::local_mocked_bindings(.bl_http_post = function(...) {
      list(
        status = 502L,
        body = charToRaw("not json")
      )
    })
    expect_error(llmask("hi"), "answered 502$")
  }
)

test_that("examples needs the name of a documented function", {
  .sandbox()
  cap <- function(...) {
    rec <- new.env()
    rec$buf <- character()
    st <- blcli(c(...), out = function(s) rec$buf <- c(rec$buf, s))
    list(text = paste(rec$buf, collapse = ""), status = st)
  }
  # a missing name is a usage error
  expect_identical(cap("examples")$status, 2L)
  expect_match(cap("examples", "no_such_fn")$text, "no help page")
})

test_that(
  paste0(
    "the Rd database falls back to the man directory and instcli copies ",
    "when it cannot link"
  ),
  {
    testthat::local_mocked_bindings(
      Rd_db = function(package, dir, ...) {
        if (!missing(package)) {
          stop("no installed help")
        }
        list()
      },
      .package = "tools"
    )
    expect_identical(.bl_rd_db(), list())
    testthat::local_mocked_bindings(
      file.symlink = function(from, to) FALSE,
      .package = "base"
    )
    dir <- tempfile("bin-")
    target <- suppressMessages(instcli(dir = dir))
    expect_true(file.exists(target))
    if (.Platform$OS.type == "windows") {
      expect_match(readLines(target)[1], "^@echo off") # the .cmd wrapper
    } else {
      expect_false(!is.na(Sys.readlink(target)) && nzchar(Sys.readlink(target)))
      expect_match(readLines(target)[1], "^#!/bin/sh")
    }
    unlink(dir, recursive = TRUE)
  }
)

test_that(
  paste0(
    "the status says when Ollama is off, and an explicit model reaches the ",
    "provider"
  ),
  {
    .sandbox()
    st <- llmstat()
    expect_identical(st$status[3], "disabled")
    expect_identical(st$detail[3], "OLLAMA_HOST=off")

    withr::local_envvar(OPENAI_API_KEY = "sk-test")
    rec <- new.env()
    rec$seen <- NULL
    testthat::local_mocked_bindings(.bl_post_json = function(
      url,
      payload,
      ...
    ) {
      rec$seen <- payload
      list(
        status = 200L,
        json = list(choices = list(list(message = list(content = "pong"))))
      )
    })
    expect_identical(
      llmask("ping", model = "custom-model", docs = FALSE),
      "pong"
    )
    expect_identical(rec$seen$model, "custom-model")
  }
)

test_that(
  paste0(
    "instcli() writes both launchers, pinned with .libPaths() and without ",
    "--args"
  ),
  {
    skip_on_os("windows")
    d <- withr::local_tempdir()
    primary <- suppressMessages(instcli(dir = d))
    expect_identical(basename(primary), "rmoriebricklayer")
    paths <- file.path(d, c("rmoriebricklayer", "rmbl"))
    expect_true(all(file.exists(paths)))
    for (p in paths) {
      txt <- paste(readLines(p), collapse = "\n")
      expect_match(txt, ".libPaths(c(", fixed = TRUE)
      expect_false(grepl("--args", txt, fixed = TRUE))
      expect_false(grepl("--vanilla", txt, fixed = TRUE))
      expect_identical(unname(file.access(p, 1L)), 0L)
    }
    # a second install replaces the launchers it finds, links included
    file.remove(paths[[2L]])
    file.symlink(paths[[1L]], paths[[2L]])
    suppressMessages(instcli(dir = d))
    expect_true(
      is.na(Sys.readlink(paths[[2L]])) || !nzchar(Sys.readlink(paths[[2L]]))
    )
    expect_match(
      paste(readLines(paths[[2L]]), collapse = "\n"),
      "# rmbl: the rmoriebricklayer command line",
      fixed = TRUE
    )
  }
)


test_that(
  paste0(
    "a dropped connection is not retried (the prompt goes once) and is ",
    "named with curl's reason"
  ),
  {
    .sandbox()
    Sys.setenv(OPENAI_API_KEY = "sk-abc", MORIE_OPENAI_MODEL = "gpt-x")
    rec <- new.env()
    rec$n <- 0L
    testthat::local_mocked_bindings(
      .bl_http_post = function(url, body, content_type, timeout, headers) {
        rec$n <- rec$n + 1L
        if (rec$n > 1L) {
          return(.reply("back"))
        }
        list(
          status = -1L,
          body = raw(),
          error = "Recv failure: Connection reset by peer"
        )
      }
    )
    # one send: a POST that timed out may have been read by the provider (review
    # of 46de6a9)
    expect_error(llmask("hi"), "could not reach OpenAI")
    expect_identical(rec$n, 1L)
    testthat::local_mocked_bindings(
      .bl_http_post = function(url, body, content_type, timeout, headers) {
        list(
          status = -1L,
          body = raw(),
          error = "Recv failure: Connection reset by peer"
        )
      }
    )
    expect_error(
      llmask("hi"),
      "could not reach OpenAI .*\\(Recv failure: Connection reset by peer\\)"
    )
  }
)

test_that(
  paste0(
    "an empty answer names why, and the request leaves room for reasoning ",
    "models"
  ),
  {
    .sandbox()
    Sys.setenv(OPENAI_API_KEY = "sk-abc", MORIE_OPENAI_MODEL = "gpt-x")
    rec <- new.env()
    rec$seen <- NULL
    testthat::local_mocked_bindings(
      .bl_http_post = function(url, body, content_type, timeout, headers) {
        rec$seen <- fromjs(rawToChar(body), simplifyVector = FALSE)
        b <- tojs(
          list(
            choices = list(list(
              message = list(content = ""),
              finish_reason = "length"
            ))
          ),
          auto_unbox = TRUE
        )
        list(status = 200L, body = charToRaw(b))
      }
    )
    expect_error(
      llmask("hi"),
      "OpenAI returned no text \\(finish reason: length"
    )
    expect_identical(rec$seen$max_tokens, 4096L)
  }
)

test_that(
  paste0(
    "agentbndl asks with the package's help at hand, which names every ",
    "function"
  ),
  {
    .sandbox()
    Sys.setenv(OPENAI_API_KEY = "sk-abc", MORIE_OPENAI_MODEL = "gpt-x")
    rec <- new.env()
    rec$sent <- NULL
    testthat::local_mocked_bindings(llmask = function(
      prompt,
      ...,
      docs = TRUE
    ) {
      rec$sent <- list(prompt = prompt, docs = docs)
      "plan"
    })
    expect_identical(agentbndl("bundle analysis.R"), "plan")
    expect_true(rec$sent$docs)
    index <- paste(
      .bl_kn_index_lines(.bl_kn_all_pages("rmoriebricklayer")),
      collapse = "\n"
    )
    for (fn in c("rslvckan(", "fdl(", "mkmnf(", "cpsbndl(")) {
      expect_true(grepl(fn, index, fixed = TRUE), info = fn)
    }
  }
)
