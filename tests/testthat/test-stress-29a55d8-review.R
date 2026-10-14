# SPDX-License-Identifier: AGPL-3.0-or-later
# Reproducers for the review of 29a55d8 (G1-G6, F1-F5 and the LOW list): each failed before its fix.

ns <- function(x) get(x, envir = asNamespace("rmoriebricklayer"))

# ---- G1: Ctrl-C while a model thinks is raised, and the prompt is never sent again ----------

test_that("G1: an interrupted POST is not retried", {
  calls <- 0L
  local_mocked_bindings(.bl_post_json = function(...) {
    calls <<- calls + 1L
    list(status = -1L, json = NULL, error = "interrupted (Ctrl-C)")
  })
  rt <- list(name = "OpenAI", id = "openai", api = "openai", base = "https://api.openai.com/v1", key = "sk-x")
  expect_error(ns(".bl_llm_chat")(rt, "m", list(list(role = "user", content = "q"))), "interrupted")
  expect_identical(calls, 1L)
  # a dropped connection, by contrast, still gets its one more try
  calls <- 0L
  local_mocked_bindings(.bl_post_json = function(...) {
    calls <<- calls + 1L
    list(status = -1L, json = NULL, error = "could not connect")
  })
  expect_error(ns(".bl_llm_chat")(rt, "m", list(list(role = "user", content = "q"))), "could not reach")
  expect_identical(calls, 2L)
})

test_that("G1: the C side flags the interrupt the wait consumed (the barrier raises it)", {
  f <- testthat::test_path("..", "..", "src", "rmbl_fetch.cpp")
  skip_if(!file.exists(f), "the sources are not beside the tests")
  src <- readLines(f)
  i <- grep("C_rmbl_http_post_impl(SEXP url", src, fixed = TRUE)
  expect_true(any(grepl("if (interrupted) rmbl_kernel_interrupted = 1;", src[i:(i + 40)], fixed = TRUE)))
})

# ---- G2, G3: a stored key is bound to an address; a new token is checked at the document's ----

test_that("G2: with the model tier off, a key saved for another address is not sent to the data service", {
  withr::local_envvar(XDG_CONFIG_HOME = withr::local_tempdir(), MORIE_HOSTED_BASE_URL = NA, MORIE_DATA_URL = NA)
  p <- ns(".bl_credentials_path")()
  dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE)
  writeLines('{"hosted_key": "sk-other", "hosted_base_url": "https://gw.company.example"}', p)
  st <- ns(".bl_hosted_key_state")()
  expect_identical(st$state, "other_address")
  expect_null(st$key)
  expect_null(ns(".bl_data_key")())
  # saved for the data address (what a new login writes): used
  writeLines(sprintf('{"hosted_key": "sk-data", "hosted_base_url": "%s"}', ns(".bl_key_address")()), p)
  expect_identical(ns(".bl_hosted_key_state")()$state, "ok")
  # and a new login records that address
  ns(".bl_store_key")("sk-new", "someone")
  cred <- ns(".bl_read_credentials")()
  expect_identical(sub("/+$", "", cred$hosted_base_url), ns(".bl_key_address")())
  expect_match(cred$hosted_base_url, "^https://")
})

test_that("G3: `login --token` checks the key at the signed document's data address, never MORIE_DATA_URL", {
  seen <- character()
  local_mocked_bindings(.bl_http_get = function(url, timeout, headers) {
    seen <<- c(seen, url)
    list(status = 200L, body = charToRaw("{}"), error = "")
  })
  withr::local_envvar(MORIE_DATA_URL = "https://data2.stub.example")
  expect_true(ns(".bl_check_token")("sk-under-test"))
  expect_length(seen, 1L)
  expect_false(grepl("data2.stub.example", seen))
  expect_true(startsWith(seen, sub("/+$", "", ns(".rmbl_services_data")()$base_url)))
})

# ---- G4, F3: the answer cache --------------------------------------------------------------

test_that("G4: the cache is off from a script, keeps the question's case and checks the stored question", {
  withr::local_options(rmoriebricklayer.llm_cache = NULL, morie.progress = TRUE, morie.quiet = NULL)
  withr::local_envvar(MORIE_LLM_CACHE = NA, TESTTHAT = NA, `_R_CHECK_PACKAGE_NAME_` = NA)
  local_mocked_bindings(.bl_stdin_tty = function() FALSE, .package = "rmoriebricklayer")
  expect_false(ns(".bl_answer_cache_on")())   # the command line's progress option alone is not a terminal
  rt <- list(name = "openai", base = "https://api.openai.com/v1")
  k <- ns(".bl_answer_key")
  expect_false(identical(k(rt, "m", "what is df$X?"), k(rt, "m", "WHAT IS DF$x?")))
})

# ---- G6: the lock is released whatever happens inside the locked call -------------------------

test_that("G6: an error inside the locked call releases the lock; a busy lock returns the sentinel", {
  lock <- file.path(withr::local_tempdir(), "rec.flock")
  busy <- new.env()
  expect_error(.Call(ns("C_rmbl_flock_with"), lock, function() stop("inside"), busy), "inside")
  # free again: taken at once by the next call
  expect_identical(.Call(ns("C_rmbl_flock_with"), lock, function() "ran", busy), "ran")
  # held by this process through acquire: the locked call answers `busy` and holds nothing
  fd <- .Call(ns("C_rmbl_flock_acquire"), lock, 0L)
  expect_true(fd > 2L)
  expect_identical(.Call(ns("C_rmbl_flock_with"), lock, function() "ran", busy), busy)
  .Call(ns("C_rmbl_flock_release"), fd)
  expect_identical(.Call(ns("C_rmbl_flock_with"), lock, function() 42, busy), 42)
  expect_error(.Call(ns("C_rmbl_flock_with"), lock, "not a function", busy), "must be a function")
})

test_that("E11 residual: a record whose name starts with another's keeps its temporary files", {
  d <- withr::local_tempdir()
  a <- file.path(d, "pre.txt")
  b <- file.path(d, "pre.txt.xmss-b")
  bt <- file.path(d, "pre.txt.xmss-b.xmss-1a2b.tmp")   # b's in-flight file
  writeLines("x", bt)
  stale <- file.path(d, "pre.txt.xmss-9f9f.tmp")        # a's own leftover
  writeLines("x", stale)
  ns(".rmbl_xmss_record_write")(a, c(k = "1"))
  expect_true(file.exists(bt))
  expect_false(file.exists(stale))
})

# ---- L1: model and provider text reaches the terminal printable ----------------------------

test_that("L1: escapes in an answer, a model list and an error body are stripped", {
  ans <- "line one\n\u001b[2Jline two\t\u001b]52;c;ZGFuZ2Vy\u0007 end\u202e"
  got <- ns(".rmbl_printable")(ans, lines = TRUE)
  expect_identical(got, "line one\nline two\t end")
  reply <- list(choices = list(list(finish_reason = "stop", message = list(content = ans))))
  local_mocked_bindings(.bl_post_json = function(...) list(status = 200L, json = reply, error = ""))
  rt <- list(name = "OpenAI", id = "openai", api = "openai", base = "https://api.openai.com/v1", key = "sk-x")
  expect_identical(ns(".bl_llm_chat")(rt, "m", list(list(role = "user", content = "q")))$text,
                   "line one\nline two\t end")
  local_mocked_bindings(.bl_http_get = function(...) {
    list(status = 200L, body = charToRaw('{"data":[{"id":"m\\u001b[2J1"},{"id":"ok"}]}'), error = "")
  })
  expect_identical(ns(".bl_llm_list_models")(list(name = "OpenAI", id = "openai", api = "openai",
                                                  base = "https://api.openai.com/v1", key = "k",
                                                  models_endpoint = TRUE)), c("m1", "ok"))
  expect_error(ns(".bl_reply_error")(list(status = 500L, json = list(error = list(message = "bad\033[2J"))), "X"),
               "X answered 500: bad$")
  expect_identical(ns(".bl_llm_wait_label")("m\033[2J"), ns(".bl_llm_wait_label")("m"))
})

# ---- L2: tool calls keep the "always text" contract --------------------------------------------

test_that("L2: a nameless tool call, a regex filter, an empty reply and a flood of calls are handled", {
  expect_match(ns(".bl_kn_run_tool")(list(name = NULL, arguments = list()), "rmoriebricklayer"), "no tool")
  expect_match(ns(".bl_kn_run_tool")(list(name = list("a", "b"), arguments = list()), "rmoriebricklayer"), "no tool")
  expect_type(ns(".bl_kn_run_tool")(list(name = "list_datasets", arguments = list(filter = "([")), "rmoriebricklayer"),
              "character")
  expect_identical(ns(".bl_openai_parse")(list(choices = list())), list(text = "", tool_calls = list(), finish = ""))
  expect_identical(ns(".bl_gemini_parse")(list(candidates = list()))$text, "")
  rt <- list(name = "OpenAI", id = "openai", api = "openai", base = "https://api.openai.com/v1", key = "sk-x")
  local_mocked_bindings(.bl_post_json = function(...) list(status = 200L, json = list(choices = list()), error = ""))
  expect_error(ns(".bl_llm_chat")(rt, "m", list(list(role = "user", content = "q"))), "returned no text")
  # a turn with 40 tool calls: every call is answered, the ones past the cap with "not run"
  flood <- list(choices = list(list(finish_reason = "tool_calls", message = list(content = "", tool_calls = lapply(1:40,
    function(i) list(id = paste0("c", i), `function` = list(name = "get_help", arguments = '{"name":"knox_test"}')))))))
  done <- list(choices = list(list(finish_reason = "stop", message = list(content = "Use knox_test()."))))
  n <- 0L
  sent <- list()
  local_mocked_bindings(.bl_post_json = function(url, payload, ...) {
    n <<- n + 1L
    sent[[n]] <<- payload
    list(status = 200L, json = if (n == 1L) flood else done, error = "")
  })
  withr::local_envvar(MORIE_LLM_CONTEXT = "200000")
  expect_match(ns(".bl_llm_assist")(rt, "m", "near repeats", "rmoriebricklayer", max_rounds = 2L), "knox_test")
  tool_msgs <- Filter(function(m) identical(m$role, "tool"), sent[[2L]]$messages)
  expect_length(tool_msgs, 40L)
  expect_identical(sum(grepl("^not run: at most", vapply(tool_msgs, function(m) m$content, ""))), 40L - 12L)
  # an endless tool loop ends in an error, never an empty answer with exit 0
  n <- 0L
  local_mocked_bindings(.bl_post_json = function(url, payload, ...) {
    n <<- n + 1L
    list(status = 200L, json = if (n <= 3L) flood else list(choices = list()), error = "")
  })
  expect_error(ns(".bl_llm_assist")(rt, "m", "near repeats", "rmoriebricklayer", max_rounds = 2L), "returned no text")
})

# ---- L3: a key with a line break never becomes two headers ---------------------------------

test_that("L3: CR or LF in a key is refused in R and in C", {
  withr::local_envvar(GEMINI_API_KEY = "AIza\r\nX-Injected: yes", GOOGLE_API_KEY = NA)
  expect_error(ns(".bl_preset_key")("gemini"), "line break")
  withr::local_envvar(GEMINI_API_KEY = NA, MORIE_LLM_API_KEY = "k\nX: y")
  expect_error(ns(".bl_key_for")("MORIE_LLM_API_KEY", "MORIE_LLM_BASE_URL"), "line break")
  withr::local_envvar(MORIE_LLM_API_KEY = NA, XDG_CONFIG_HOME = withr::local_tempdir())
  expect_error(bricklayer_llm_config(gemini.key = "AIza\r\nX: y"), "line break")
  expect_error(.Call(ns("C_rmbl_http_post"), "https://example.invalid/x", raw(0), "application/json", 1L,
                     "X-A: a\r\nX-B: b", FALSE), "line break")
  expect_error(.Call(ns("C_rmbl_http_get"), "https://example.invalid/x", 1L, "X-A: a\nX-B: b", FALSE), "line break")
})

# ---- L5: the settings file is written through a fresh temporary name --------------------------

test_that("L5: a planted llm.json.tmp symlink is not followed", {
  skip_on_os("windows")
  withr::local_envvar(XDG_CONFIG_HOME = withr::local_tempdir())
  p <- ns(".bl_config_path")()
  dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE)
  target <- file.path(withr::local_tempdir(), "victim")
  writeLines("untouched", target)
  file.symlink(target, paste0(p, ".tmp"))
  bricklayer_llm_config(openai.key = "sk-secret")
  expect_identical(readLines(target), "untouched")
  expect_true(file.exists(p))
  expect_true(any(grepl("sk-secret", readLines(p))))
})

# ---- the rest of the LOW list ---------------------------------------------------------------

test_that("knox_test drops an incident without a location or time, as its siblings do", {
  set.seed(5)
  x <- c(runif(40, -79.5, -79.3), NA, Inf)
  y <- c(runif(40, 43.6, 43.8), 43.7, 43.7)
  t <- c(1:40, 41, 42)
  expect_message(k <- knox_test(x, y, t, 500, 3, nsim = 19, seed = 1), "2 incidents without a usable location")
  expect_s3_class(k, "rmbl_knox")
  expect_error(knox_test(x[1:40], y[1:40], t[1:40], 500, 3, nsim = 19, max_pairs = TRUE), "must be a number")
})

test_that("hotspot_persistence says when it drops (0, 0)", {
  set.seed(6)
  lon <- c(runif(50, -79.5, -79.3), 0)
  lat <- c(runif(50, 43.6, 43.8), 0)
  expect_message(hotspot_persistence(lon, lat, rep(1:2, length.out = 51), cell = 1), "1 incident at \\(0, 0\\)")
})

test_that("the planar cell key tells 1e15 from 1e15 + 1, and refuses indices past 2^53", {
  x <- c(1e15, 1e15 + 1, 1e15 + 2) * 3
  cp <- ns(".jx_close_pairs")(x, c(0, 0, 0), 1, 1e6)
  # the three points are three apart: no pair is within 1
  expect_identical(length(cp$i), 0L)
  # at 8e15 / 1 the index is still a whole number; at 1e12 / 1e-6 it is not (review of 46de6a9)
  expect_identical(length(ns(".jx_close_pairs")(c(8e15, 8e15 + 0.5, 8e15 + 3), c(0, 0, 0), 1, 1e6)$i), 1L)
  expect_error(ns(".jx_close_pairs")(c(1e12, 1e12 + 1e-7), c(0, 0), 1e-6, 1e6), "exceed 2\\^53")
})

test_that("hotspot_persistence says when it drops an incident without a location or period", {
  set.seed(7)
  lon <- c(runif(50, -79.5, -79.3), NA)
  lat <- c(runif(50, 43.6, 43.8), 43.7)
  expect_message(hotspot_persistence(lon, lat, rep(1:2, length.out = 51), cell = 1), "1 incident without a usable")
})

test_that("a burden at rate 0 or population 0 draws; the rate message allows an age-specific rate", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  b0 <- pollution_burden(exposure_mean = 10, exposure_prevalence = 1, baseline_rate = 0, population = 1000,
                         pollutant = "pm25")
  expect_s3_class(plot(b0), "data.frame")
  p0 <- pollution_burden(exposure_mean = 10, exposure_prevalence = 1, baseline_rate = 0.01, population = 0,
                         pollutant = "pm25")
  expect_s3_class(plot(p0), "data.frame")
  expect_error(pollution_burden(exposure_mean = 10, exposure_prevalence = 1, baseline_rate = 0.15, population = 1000,
                                pollutant = "pm25"), "age-specific rate")
})

test_that("survey_compare takes a numeric domain label", {
  d <- data.frame(y = c(rnorm(30, 1), rnorm(30, 2)), yr = rep(c(2022, 2023), each = 30), w = 1)
  des <- survey_design(d, weights = "w")
  a <- survey_compare(des, d, "y", by = "yr", ref = 2023)
  b <- survey_compare(des, d, "y", by = "yr", ref = "2023")
  expect_equal(a$difference, b$difference)
})

test_that("an assumption with ok = NA is reported as NA, not a raw error", {
  rep <- list(status = "ok", command = "x", pollutant = "pm25", outcome = "deaths", inputs = list(),
              pipeline = list(),
              assumptions = list(list(assumption = "a", ok = NA, note = "unknown")))
  expect_match(pollution_report_text(rep), "\\[NA\\] a")
})

test_that("the progress frame takes a NaN time", {
  fr <- .Call(ns("C_rmbl_progress_frame"), 0.5, NaN, 40L, TRUE, FALSE, TRUE, c(10, 20, 30))
  expect_false(grepl("-2147483648", fr, fixed = TRUE))
})
