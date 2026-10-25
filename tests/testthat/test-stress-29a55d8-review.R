# battery: runs in CI and locally; CRAN runs the correctness core
testthat::skip_on_cran()
# SPDX-License-Identifier: AGPL-3.0-or-later Reproducers for the review of
# 29a55d8 (G1-G6, F1-F5 and the LOW list): each failed before its fix.

ns <- function(x) get(x, envir = asNamespace("rmoriebricklayer"))

# ---- G1: Ctrl-C while a model thinks is raised, and the prompt is never sent
# again ---

test_that("G1: an interrupted POST is not retried", {
  calls <- 0L
  local_mocked_bindings(.bl_post_json = function(...) {
    calls <<- calls + 1L
    list(status = -1L, json = NULL, error = "interrupted (Ctrl-C)")
  })
  rt <- list(
    name = "OpenAI",
    id = "openai",
    api = "openai",
    base = "https://api.openai.com/v1",
    key = "sk-x"
  )
  expect_error(
    ns(".bl_llm_chat")(rt, "m", list(list(role = "user", content = "q"))),
    "interrupted"
  )
  expect_identical(calls, 1L)
  # nor is a timed-out or dropped POST: the prompt goes once (review of 46de6a9)
  calls <- 0L
  local_mocked_bindings(.bl_post_json = function(...) {
    calls <<- calls + 1L
    list(
      status = -1L,
      json = NULL,
      error = "Operation timed out after 120000 milliseconds"
    )
  })
  expect_error(
    ns(".bl_llm_chat")(rt, "m", list(list(role = "user", content = "q"))),
    "could not reach"
  )
  expect_identical(calls, 1L)
})

test_that(
  paste0(
    "G1: the C side flags the interrupt the wait consumed (the barrier ",
    "raises it)"
  ),
  {
    f <- testthat::test_path("..", "..", "src", "rmbl_fetch.cpp")
    skip_if(!file.exists(f), "the sources are not beside the tests")
    src <- readLines(f)
    i <- grep("C_rmbl_http_post_impl(SEXP url", src, fixed = TRUE)
    expect_true(any(grepl(
      "if (interrupted) rmbl_kernel_interrupted = 1;",
      src[i:(i + 40)],
      fixed = TRUE
    )))
  }
)

# ---- G2, G3: a stored key is bound to an address; a new token is checked at
# the document's ----

test_that(
  paste0(
    "G2: with the model tier off, a key saved for another address is not ",
    "sent to the data service"
  ),
  {
    withr::local_envvar(
      XDG_CONFIG_HOME = withr::local_tempdir(),
      MORIE_HOSTED_BASE_URL = NA,
      MORIE_DATA_URL = NA,
      MORIE_HOSTED_KEY = NA
    )
    p <- ns(".bl_credentials_path")()
    dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE)
    writeLines(
      paste0(
        '{"hosted_key": "sk-other", "hosted_base_url": ',
        '"https://gw.company.example"}'
      ),
      p
    )
    st <- ns(".bl_hosted_key_state")()
    expect_identical(st$state, "other_address")
    expect_null(st$key)
    expect_null(ns(".bl_data_key")())
    # saved for the data address (what a new login writes): used
    writeLines(
      sprintf(
        '{"hosted_key": "sk-data", "hosted_base_url": "%s"}',
        ns(".bl_key_address")()
      ),
      p
    )
    expect_identical(ns(".bl_hosted_key_state")()$state, "ok")
    # and a new login records that address
    ns(".bl_store_key")("sk-new", "someone")
    cred <- ns(".bl_read_credentials")()
    expect_identical(
      sub("/+$", "", cred$hosted_base_url),
      ns(".bl_key_address")()
    )
    expect_match(cred$hosted_base_url, "^https://")
  }
)

test_that(
  paste0(
    "G2 note: a key a pre-0.5.12 login saved for llm.rmorie.com goes to the ",
    "data address, nowhere else"
  ),
  {
    withr::local_envvar(
      XDG_CONFIG_HOME = withr::local_tempdir(),
      MORIE_HOSTED_BASE_URL = NA,
      MORIE_DATA_URL = NA,
      MORIE_HOSTED_KEY = NA
    )
    p <- ns(".bl_credentials_path")()
    dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE)
    for (u in c("https://llm.rmorie.com", "https://llm.rmorie.com/")) {
      writeLines(
        sprintf('{"hosted_key": "sk-old", "hosted_base_url": "%s"}', u),
        p
      )
      st <- ns(".bl_hosted_key_state")()
      expect_identical(st$state, "ok", info = u)
      expect_identical(st$key, "sk-old", info = u)
    }
    # only that exact address: a look-alike stays bound to itself
    for (u in c(
      "https://llm.rmorie.com.evil.example",
      "http://llm.rmorie.com",
      "https://llm2.rmorie.com"
    )) {
      writeLines(
        sprintf('{"hosted_key": "sk-old", "hosted_base_url": "%s"}', u),
        p
      )
      expect_identical(
        ns(".bl_hosted_key_state")()$state,
        "other_address",
        info = u
      )
    }
    # and only toward the signed document's data address: with the key address
    # moved elsewhere it is held back
    writeLines(
      '{"hosted_key": "sk-old", "hosted_base_url": "https://llm.rmorie.com"}',
      p
    )
    local_mocked_bindings(
      .bl_key_address = function() "https://gw.company.example",
      .package = "rmoriebricklayer"
    )
    expect_identical(ns(".bl_hosted_key_state")()$state, "other_address")
  }
)

test_that(
  paste0(
    "G3: `login --token` checks the key at the signed document's data ",
    "address, never MORIE_DATA_URL"
  ),
  {
    seen <- character()
    local_mocked_bindings(.bl_http_get = function(url, timeout, headers) {
      seen <<- c(seen, url)
      list(status = 200L, body = charToRaw("{}"), error = "")
    })
    withr::local_envvar(MORIE_DATA_URL = "https://data2.stub.example")
    expect_true(ns(".bl_check_token")("sk-under-test"))
    expect_length(seen, 1L)
    expect_false(grepl("data2.stub.example", seen))
    expect_true(startsWith(
      seen,
      sub("/+$", "", ns(".rmbl_services_data")()$base_url)
    ))
  }
)

# ---- G4, F3: the answer cache ------------------------------------------------

test_that(
  paste0(
    "G4: the cache is off from a script, keeps the question's case and ",
    "checks the stored question"
  ),
  {
    withr::local_options(
      rmoriebricklayer.llmcache = NULL,
      morie.progress = TRUE,
      morie.quiet = NULL
    )
    withr::local_envvar(
      MORIE_LLM_CACHE = NA,
      TESTTHAT = NA,
      `_R_CHECK_PACKAGE_NAME_` = NA
    )
    local_mocked_bindings(
      .bl_stdin_tty = function() FALSE,
      .package = "rmoriebricklayer"
    )
    # the command line's progress option alone is not a terminal
    expect_false(ns(".bl_answer_cache_on")())
    rt <- list(name = "openai", base = "https://api.openai.com/v1")
    k <- ns(".bl_answer_key")
    expect_false(identical(
      k(rt, "m", "what is df$X?"),
      k(rt, "m", "WHAT IS DF$x?")
    ))
  }
)

# ---- G6: the lock is released whatever happens inside the locked call --------

test_that(
  paste0(
    "G6: an error inside the locked call releases the lock; a busy lock ",
    "returns the sentinel"
  ),
  {
    lock <- file.path(withr::local_tempdir(), "rec.flock")
    busy <- new.env()
    expect_error(
      .Call(ns("C_rmbl_flock_with"), lock, function() stop("inside"), busy),
      "inside"
    )
    # free again: taken at once by the next call
    expect_identical(
      .Call(ns("C_rmbl_flock_with"), lock, function() "ran", busy),
      "ran"
    )
    # held by this process through acquire: the locked call answers `busy` and
    # holds nothing
    fd <- .Call(ns("C_rmbl_flock_acquire"), lock, 0L)
    expect_true(fd > 2L)
    expect_identical(
      .Call(ns("C_rmbl_flock_with"), lock, function() "ran", busy),
      busy
    )
    .Call(ns("C_rmbl_flock_release"), fd)
    expect_identical(
      .Call(ns("C_rmbl_flock_with"), lock, function() 42, busy),
      42
    )
    expect_error(
      .Call(ns("C_rmbl_flock_with"), lock, "not a function", busy),
      "must be a function"
    )
  }
)

test_that(
  paste0(
    "E11 residual: a record whose name starts with another's keeps its ",
    "temporary files"
  ),
  {
    d <- withr::local_tempdir()
    a <- file.path(d, "pre.txt")
    b <- file.path(d, "pre.txt.xmss-b")
    bt <- file.path(d, "pre.txt.xmss-b.xmss-1a2b.tmp") # b's in-flight file
    writeLines("x", bt)
    stale <- file.path(d, "pre.txt.xmss-9f9f.tmp") # a's own leftover
    writeLines("x", stale)
    ns(".rmbl_xmss_record_write")(a, c(k = "1"))
    expect_true(file.exists(bt))
    expect_false(file.exists(stale))
  }
)

# ---- L1: model and provider text reaches the terminal printable --------------

test_that(
  paste0(
    "L1: escapes in an answer, a model list ",
    "and an error body are stripped"
  ),
  {
    ans <- "line one\n\u001b[2Jline two\t\u001b]52;c;ZGFuZ2Vy\u0007 end\u202e"
    got <- ns(".rmbl_printable")(ans, lines = TRUE)
    expect_identical(got, "line one\nline two\t end")
    reply <- list(
      choices = list(list(
        finish_reason = "stop",
        message = list(content = ans)
      ))
    )
    local_mocked_bindings(.bl_post_json = function(...) {
      list(status = 200L, json = reply, error = "")
    })
    rt <- list(
      name = "OpenAI",
      id = "openai",
      api = "openai",
      base = "https://api.openai.com/v1",
      key = "sk-x"
    )
    expect_identical(
      ns(".bl_llm_chat")(
        rt,
        "m",
        list(list(role = "user", content = "q"))
      )$text,
      "line one\nline two\t end"
    )
    local_mocked_bindings(.bl_http_get = function(...) {
      list(
        status = 200L,
        body = charToRaw('{"data":[{"id":"m\\u001b[2J1"},{"id":"ok"}]}'),
        error = ""
      )
    })
    expect_identical(
      ns(".bl_llm_list_models")(list(
        name = "OpenAI",
        id = "openai",
        api = "openai",
        base = "https://api.openai.com/v1",
        key = "k",
        models_endpoint = TRUE
      )),
      c("m1", "ok")
    )
    expect_error(
      ns(".bl_reply_error")(
        list(status = 500L, json = list(error = list(message = "bad\033[2J"))),
        "X"
      ),
      "X answered 500: bad$"
    )
    expect_identical(
      ns(".bl_llm_wait_label")("m\033[2J"),
      ns(".bl_llm_wait_label")("m")
    )
  }
)

# ---- L2: tool calls keep the "always text" contract --------------------------

test_that(
  paste0(
    "L2: a nameless tool call, a regex filter, an empty reply and a flood ",
    "of calls are handled"
  ),
  {
    expect_match(
      ns(".bl_kn_run_tool")(
        list(name = NULL, arguments = list()),
        "rmoriebricklayer"
      ),
      "no tool"
    )
    expect_match(
      ns(".bl_kn_run_tool")(
        list(name = list("a", "b"), arguments = list()),
        "rmoriebricklayer"
      ),
      "no tool"
    )
    expect_type(
      ns(".bl_kn_run_tool")(
        list(name = "list_datasets", arguments = list(filter = "([")),
        "rmoriebricklayer"
      ),
      "character"
    )
    expect_identical(
      ns(".bl_openai_parse")(list(choices = list())),
      list(text = "", tool_calls = list(), finish = "")
    )
    expect_identical(ns(".bl_gemini_parse")(list(candidates = list()))$text, "")
    rt <- list(
      name = "OpenAI",
      id = "openai",
      api = "openai",
      base = "https://api.openai.com/v1",
      key = "sk-x"
    )
    local_mocked_bindings(.bl_post_json = function(...) {
      list(status = 200L, json = list(choices = list()), error = "")
    })
    expect_error(
      ns(".bl_llm_chat")(rt, "m", list(list(role = "user", content = "q"))),
      "returned no text"
    )
    # a turn with 40 tool calls: every call is answered, the ones past the cap
    # with "not run"
    flood <- list(
      choices = list(list(
        finish_reason = "tool_calls",
        message = list(
          content = "",
          tool_calls = lapply(1:40, function(i) {
            list(
              id = paste0("c", i),
              `function` = list(
                name = "get_help",
                arguments = '{"name":"knox_test"}'
              )
            )
          })
        )
      ))
    )
    done <- list(
      choices = list(list(
        finish_reason = "stop",
        message = list(content = "Use knoxtst().")
      ))
    )
    n <- 0L
    sent <- list()
    local_mocked_bindings(.bl_post_json = function(url, payload, ...) {
      n <<- n + 1L
      sent[[n]] <<- payload
      list(status = 200L, json = if (n == 1L) flood else done, error = "")
    })
    withr::local_envvar(MORIE_LLM_CONTEXT = "200000")
    expect_match(
      ns(".bl_llm_assist")(
        rt,
        "m",
        "near repeats",
        "rmoriebricklayer",
        max_rounds = 2L
      ),
      "knoxtst"
    )
    tool_msgs <- Filter(
      function(m) identical(m$role, "tool"),
      sent[[2L]]$messages
    )
    # the rest are dropped from the turn, and the model told
    expect_length(tool_msgs, 12L)
    asst <- Filter(
      function(m) identical(m$role, "assistant"),
      sent[[2L]]$messages
    )
    expect_length(asst[[1L]]$tool_calls, 12L)
    told <- vapply(sent[[2L]]$messages, function(m) m$content %||% "", "")
    expect_true(any(grepl("Only the first 12 of your 40", told)))
    # with the last tool result, not a user turn after the tool results
    roles <- vapply(sent[[2L]]$messages, function(m) m$role %||% "", "")
    expect_false(any(roles[-1L] == "user" & roles[-length(roles)] == "tool"))
    # an endless tool loop ends in an error, never an empty answer with exit 0
    n <- 0L
    local_mocked_bindings(.bl_post_json = function(url, payload, ...) {
      n <<- n + 1L
      list(
        status = 200L,
        json = if (n <= 3L) flood else list(choices = list()),
        error = ""
      )
    })
    expect_error(
      ns(".bl_llm_assist")(
        rt,
        "m",
        "near repeats",
        "rmoriebricklayer",
        max_rounds = 2L
      ),
      "returned no text"
    )
  }
)

# ---- L3: a key with a line break never becomes two headers -------------------

test_that("L3: CR or LF in a key is refused in R and in C", {
  withr::local_envvar(
    GEMINI_API_KEY = "AIza\r\nX-Injected: yes",
    GOOGLE_API_KEY = NA
  )
  expect_error(ns(".bl_preset_key")("gemini"), "line break")
  withr::local_envvar(GEMINI_API_KEY = NA, MORIE_LLM_API_KEY = "k\nX: y")
  expect_error(
    ns(".bl_key_for")("MORIE_LLM_API_KEY", "MORIE_LLM_BASE_URL"),
    "line break"
  )
  withr::local_envvar(
    MORIE_LLM_API_KEY = NA,
    XDG_CONFIG_HOME = withr::local_tempdir()
  )
  expect_error(llmcfg(gemini.key = "AIza\r\nX: y"), "line break")
  expect_error(
    .Call(
      ns("C_rmbl_http_post"),
      "https://example.invalid/x",
      raw(0),
      "application/json",
      1L,
      "X-A: a\r\nX-B: b",
      FALSE
    ),
    "line break"
  )
  expect_error(
    .Call(
      ns("C_rmbl_http_get"),
      "https://example.invalid/x",
      1L,
      "X-A: a\nX-B: b",
      FALSE
    ),
    "line break"
  )
})

# ---- L5: the settings file is written through a fresh temporary name ---------

test_that("L5: a planted llm.json.tmp symlink is not followed", {
  skip_on_os("windows")
  withr::local_envvar(XDG_CONFIG_HOME = withr::local_tempdir())
  p <- ns(".bl_config_path")()
  dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE)
  target <- file.path(withr::local_tempdir(), "victim")
  writeLines("untouched", target)
  file.symlink(target, paste0(p, ".tmp"))
  llmcfg(openai.key = "sk-secret")
  expect_identical(readLines(target), "untouched")
  expect_true(file.exists(p))
  expect_true(any(grepl("sk-secret", readLines(p))))
})

# ---- the rest of the LOW list ------------------------------------------------

test_that(
  paste0(
    "knoxtst drops an incident without a ",
    "location or time, as its siblings do"
  ),
  {
    set.seed(5)
    x <- c(runif(40, -79.5, -79.3), NA, Inf)
    y <- c(runif(40, 43.6, 43.8), 43.7, 43.7)
    t <- c(1:40, 41, 42)
    expect_message(
      k <- knoxtst(x, y, t, 500, 3, nsim = 19, seed = 1),
      "2 incidents without a usable location"
    )
    expect_s3_class(k, "rmbl_knox")
    expect_error(
      knoxtst(x[1:40], y[1:40], t[1:40], 500, 3, nsim = 19, maxprs = TRUE),
      "must be a number"
    )
  }
)

test_that("hotpers says when it drops (0, 0)", {
  set.seed(6)
  lon <- c(runif(50, -79.5, -79.3), 0)
  lat <- c(runif(50, 43.6, 43.8), 0)
  expect_message(
    hotpers(lon, lat, rep(1:2, length.out = 51), cell = 1),
    "1 incident at \\(0, 0\\)"
  )
})

test_that(
  paste0(
    "the planar cell key tells 1e15 from 1e15 + 1, and indices past 2^52 ",
    "are compared directly"
  ),
  {
    x <- c(1e15, 1e15 + 1, 1e15 + 2) * 3
    cp <- ns(".jx_close_pairs")(x, c(0, 0, 0), 1, 1e6)
    # the three points are three apart: no pair is within 1
    expect_identical(length(cp$i), 0L)
    # at 8e15 / 1 the index is still a whole number; at 1e12 / 1e-6 it is not
    # (review of 46de6a9)
    expect_identical(
      length(
        ns(".jx_close_pairs")(
          c(8e15, 8e15 + 0.5, 8e15 + 3),
          c(0, 0, 0),
          1,
          1e6
        )$i
      ),
      1L
    )
    # 1e12 + 1e-7 is the double 1e12: one pair at distance 0, found directly (it
    # was refused; the statistics stress test of 5e1dce5 asked for the test to
    # run rather than refuse)
    expect_identical(
      length(ns(".jx_close_pairs")(c(1e12, 1e12 + 1e-7), c(0, 0), 1e-6, 1e6)$i),
      1L
    )
  }
)

test_that(
  paste0(
    "hotpers says when it drops an incident ",
    "without a location or period"
  ),
  {
    set.seed(7)
    lon <- c(runif(50, -79.5, -79.3), NA)
    lat <- c(runif(50, 43.6, 43.8), 43.7)
    expect_message(
      hotpers(lon, lat, rep(1:2, length.out = 51), cell = 1),
      "1 incident without a usable"
    )
  }
)

test_that(
  paste0(
    "a burden at rate 0 or population 0 draws; the rate message allows an ",
    "age-specific rate"
  ),
  {
    grDevices::pdf(NULL)
    on.exit(grDevices::dev.off(), add = TRUE)
    b0 <- polbrdn(
      expomean = 10,
      expoprev = 1,
      brate = 0,
      pop = 1000,
      poll = "pm25"
    )
    expect_s3_class(plot(b0), "data.frame")
    p0 <- polbrdn(
      expomean = 10,
      expoprev = 1,
      brate = 0.01,
      pop = 0,
      poll = "pm25"
    )
    expect_s3_class(plot(p0), "data.frame")
    expect_error(
      polbrdn(
        expomean = 10,
        expoprev = 1,
        brate = 0.15,
        pop = 1000,
        poll = "pm25"
      ),
      "age-specific rate"
    )
  }
)

test_that("svycmp takes a numeric domain label", {
  d <- data.frame(
    y = c(rnorm(30, 1), rnorm(30, 2)),
    yr = rep(c(2022, 2023), each = 30),
    w = 1
  )
  des <- svydes(d, w = "w")
  a <- svycmp(des, d, "y", by = "yr", ref = 2023)
  b <- svycmp(des, d, "y", by = "yr", ref = "2023")
  expect_equal(a$difference, b$difference)
})

test_that("an assumption with ok = NA is reported as NA, not a raw error", {
  rep <- list(
    status = "ok",
    command = "x",
    pollutant = "pm25",
    outcome = "deaths",
    inputs = list(),
    pipeline = list(),
    assumptions = list(list(assumption = "a", ok = NA, note = "unknown"))
  )
  expect_match(polrpttxt(rep), "\\[NA\\] a")
})

test_that("the progress frame takes a NaN time", {
  fr <- .Call(
    ns("C_rmbl_progress_frame"),
    0.5,
    NaN,
    40L,
    TRUE,
    FALSE,
    TRUE,
    c(10, 20, 30)
  )
  expect_false(grepl("-2147483648", fr, fixed = TRUE))
})

# ---- review of 46de6a9 -------------------------------------------------------

test_that(
  paste0(
    "H4/H7: the daily-limit default is retried tomorrow; the run cap counts ",
    "between captures"
  ),
  {
    expect_true(ns(".bl_wb_daily_failure")("captured already today"))
    expect_true(ns(".bl_wb_daily_failure")(
      "You have already captured this URL today"
    ))
    expect_false(ns(".bl_wb_daily_failure")("Server returned 404"))
  }
)

test_that(
  paste0(
    "H6: a cached answer is made printable on the way out; odd files are a ",
    "miss"
  ),
  {
    real_on <- ns(".bl_answer_cache_on")
    d <- withr::local_tempdir()
    withr::local_options(rmoriebricklayer.llmcachedir = d)
    local_mocked_bindings(
      .bl_answer_cache_on = function() TRUE,
      .package = "rmoriebricklayer"
    )
    k <- strrep("a", 64)
    writeLines(
      tojs(
        list(
          question = "q",
          model = "m",
          answer = "x\u001b[2Jy\u001b]52;c;Zm9v\u0007z",
          time = "t\u001b[2J"
        ),
        auto_unbox = TRUE
      ),
      file.path(d, paste0(k, ".json"))
    )
    got <- ns(".bl_answer_get")(k, "q")
    expect_identical(as.character(got), "xyz")
    expect_identical(attr(got, "cached"), "t")
    writeLines("\"just a string\"", file.path(d, paste0(k, ".json")))
    expect_null(ns(".bl_answer_get")(k, "q"))
    writeLines("[1, 2]", file.path(d, paste0(k, ".json")))
    expect_null(ns(".bl_answer_get")(k, "q"))
    # every spelling of off, and the option as text
    withr::local_options(
      rmoriebricklayer.llmcache = NULL,
      morie.progress = TRUE,
      morie.quiet = NULL
    )
    withr::local_envvar(TESTTHAT = NA, `_R_CHECK_PACKAGE_NAME_` = NA)
    local_mocked_bindings(
      .bl_answer_cache_on = real_on,
      .bl_stdin_tty = function() TRUE,
      .bl_stdout_tty = function() TRUE,
      .package = "rmoriebricklayer"
    )
    for (v in c(" off", "disabled", "none", "No", "0")) {
      withr::with_envvar(
        c(MORIE_LLM_CACHE = v),
        expect_false(ns(".bl_answer_cache_on")(), label = v)
      )
    }
    withr::local_envvar(MORIE_LLM_CACHE = NA)
    withr::with_options(
      list(rmoriebricklayer.llmcache = "no"),
      expect_false(ns(".bl_answer_cache_on")())
    )
    withr::with_options(
      list(rmoriebricklayer.llmcache = TRUE),
      expect_true(ns(".bl_answer_cache_on")())
    )
  }
)

test_that(
  paste0(
    "the saved config directory is private; model names from a server print ",
    "clean"
  ),
  {
    skip_on_os("windows")
    withr::local_envvar(XDG_CONFIG_HOME = withr::local_tempdir())
    old <- Sys.umask("000")
    on.exit(Sys.umask(old), add = TRUE)
    llmcfg(openai.model = "gpt\u001b[2J-x")
    p <- ns(".bl_config_path")()
    expect_identical(as.character(file.info(dirname(p))$mode), "700")
    expect_identical(ns(".bl_config_effective")("openai.model"), "gpt-x")
    local_mocked_bindings(
      .bl_http_get_local = function(...) {
        list(
          status = 200L,
          body = charToRaw(
            '{"models":[{"name":"m\\u001b[2J1"},{"name":"ok"}]}'
          ),
          error = ""
        )
      },
      .package = "rmoriebricklayer"
    )
    expect_identical(
      as.character(ns(".bl_ollama_tags")("http://localhost:11434")),
      c("m1", "ok")
    )
  }
)

test_that(
  paste0(
    "gunzip and a GET take Ctrl-C (the C ",
    "side reports, the barrier raises)"
  ),
  {
    g <- testthat::test_path("..", "..", "src", "rmbl_gunzip.c")
    skip_if(
      !file.exists(g),
      "the sources are not beside the tests (an installed package)"
    )
    src <- readLines(g)
    expect_true(any(grepl("rmbl_interrupt_pending()", src, fixed = TRUE)))
    f <- readLines(testthat::test_path("..", "..", "src", "rmbl_fetch.cpp"))
    expect_true(any(grepl(
      "CURLOPT_XFERINFOFUNCTION, get_xferinfo",
      f,
      fixed = TRUE
    )))
  }
)

test_that("an estimate without a standard error plots without a warning", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  d <- data.frame(
    y = rnorm(20),
    g = rep(c("a", "b"), 10),
    w = 1,
    s = 1:20,
    p = 1:20
  )
  des <- svydes(d, w = "w", strata = "s", psu = "p", lonely = "remove")
  e <- svyest(des, d, "y", by = "g")
  expect_true(all(is.na(e$se)))
  expect_no_warning(plot(e))
  expect_no_warning(plot(svycmp(des, d, "y", by = "g")))
})

test_that("drftpsi bins and clrdcmp base are refused in words", {
  x <- rnorm(200)
  expect_error(drftpsi(x, x, bins = c(2, 3)), "one whole number")
  expect_error(drftpsi(x, x, bins = 1e9), "at most 1,000,000")
  expect_error(drftpsi(x, x, bins = 1), "at least 2")
  expect_error(
    clrdcmp(
      c(5, 6, 7, 8),
      c(10, 10, 10, 10),
      c("a", "b", "a", "b"),
      c("x", "x", "y", "y"),
      base = 1i
    ),
    "one of the two values"
  )
  expect_error(
    clrdcmp(
      c(5, 6, 7, 8),
      c(10, 10, 10, 10),
      c("a", "b", "a", "b"),
      c("x", "x", "y", "y"),
      base = NA
    ),
    "one of the two values"
  )
})

test_that(
  paste0(
    "a choice argument is refused in the package's words, naming what was ",
    "given"
  ),
  {
    d4 <- data.frame(y = 1:4, w = 1)
    expect_error(
      svydes(d4, w = "w", reps = cbind(1:4, 4:1), type = "jackknife"),
      "`type` must be one of \"bootstrap\".*not \"jackknife\""
    )
    expect_error(
      lifetbl(c(0, 1, 2), 1:2, conftype = 3),
      "`conftype` must be one of"
    )
    f <- function(what = c("mean", "total")) ns(".rmbl_arg")(what)
    expect_identical(f(), "mean")
    expect_identical(f("tot"), "total")
    expect_error(
      f("sum"),
      "`what` must be one of \"mean\", \"total\", not \"sum\""
    )
    g <- function(what = c("a", "b", "c")) ns(".rmbl_arg")(what, several = TRUE)
    expect_identical(g(c("c", "a")), c("c", "a"))
    expect_error(g(c("a", "z")), "one or more of")
  }
)

test_that(
  paste0(
    "a data frame with empty or repeated ",
    "column names is refused in words"
  ),
  {
    d <- data.frame(y = 1:6, w = 1)
    names(d)[2] <- ""
    # svydes() minds only the columns it uses: an unnamed column it does not use
    # is no reason to refuse the data (statistics stress test of 5e1dce5)
    expect_s3_class(svydes(d, w = "y"), "rmbl_svy_design")
    d2 <- data.frame(a = 1:6, b = 1:6)
    names(d2) <- c("a", "a")
    expect_error(svydes(d2, w = "a"), "two columns named a")
    expect_error(anltab(d2, value = "a", prd = "a"), "two columns named a")
  }
)

test_that("the CSV reader gives read.csv's table, byte for byte of meaning", {
  same <- function(txt) {
    ref <- utils::read.csv(text = txt, stringsAsFactors = FALSE, skipNul = TRUE)
    got <- ns(".bl_csv_from_bytes")(charToRaw(txt))
    expect_identical(got, ref, info = substr(txt, 1, 40))
  }
  same("a,b,c\n1,x,TRUE\n2,y,FALSE\n")
  same("a,b\n1,\"he said \"\"hi\"\"\"\n2,\"two\nlines\"\n")
  same("a,b\r\n1,2\r\n\r\n3,4\r\n")
  same("a,b\n1,NA\n\"NA\",2\nNA,\n")
  same("a b,c-d,1x\n1,2,3\n")
  same("a,a,b\n1,2,3\n")
  same("id,text\n07035394,\"0001\"\n2,x\n")
  same("a,b\n1.5,1e3\n2,1e400\n")
  same("a,b\n1,2\n3\n")
  same("a,b\n")
  same("x\n1\n2")
  same("a,b\n\"\",\"\"\n")
  same("a,b,c\nTRUE,1,T\n1,TRUE,F\n")
  same("a,b,c,d\n2147483647,2147483648,-2147483648,+5\n1,2,3,05\n")
  same("a,b,c\n1e3,0x10,Inf\n2.,.5,-inf\n")
  same("a,b\n 1,1 \n2,2\n")
  same("a,b\n,\n,\n")
  same("a,b\n1,\n2,\n")
  same("a\n1d5\n2\n")
  same("a,b\n1,2\n3,4.5\n")
  same("a\n12345678901234567890\n1\n")
  same("a,b\nT,F\ntrue,False\n")
  same("a,b\n1,2\nNA,NA\n")
  # a NUL byte is dropped, as skipNul = TRUE drops it; a byte-order mark is not
  # part of a name
  expect_identical(
    ns(".bl_csv_from_bytes")(as.raw(c(
      charToRaw("a,b\n1,x"),
      0,
      charToRaw("y\n")
    )))$b,
    "xy"
  )
  expect_identical(
    names(ns(".bl_csv_from_bytes")(as.raw(c(
      0xEF,
      0xBB,
      0xBF,
      charToRaw("a,b\n1,2\n")
    )))),
    c("a", "b")
  )
  expect_error(
    ns(".bl_csv_from_bytes")(charToRaw("a,b\n1,2,3\n")),
    "3 fields where the header has 2"
  )
  expect_error(
    ns(".bl_csv_from_bytes")(charToRaw("a,b\n1,\"open\n")),
    "never closes"
  )
  # through gzip, as the curated tables arrive
  f <- withr::local_tempfile(fileext = ".csv.gz")
  con <- gzfile(f, "w")
  writeLines(c("k,v,flag", "1,alpha,TRUE", "2,\"b,eta\",FALSE", "3,NA,NA"), con)
  close(con)
  expect_identical(
    ns(".bl_read_csv_gz")(f),
    utils::read.csv(gzfile(f), stringsAsFactors = FALSE, skipNul = TRUE)
  )
})
