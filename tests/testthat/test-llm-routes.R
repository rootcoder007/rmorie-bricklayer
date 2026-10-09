# The language-model routes in front of the hosted tier (an endpoint of your
# own, a local Ollama server), the order they are tried in, and the one precise
# relaxation of the URL policy they need: plain http on the loopback host.

rt_env <- function(env = parent.frame()) {
  withr::local_envvar(c(MORIE_LLM_BASE_URL = NA, MORIE_LLM_API_KEY = NA, MORIE_LLM_MODEL = NA,
                        OLLAMA_HOST = "off", OLLAMA_BASE_URL = NA, OLLAMA_MODEL = NA, OLLAMA_API_KEY = NA,
                        MORIE_HOSTED_BASE_URL = NA, MORIE_HOSTED_KEY = NA, MORIE_HOSTED_MODEL = NA,
                        XDG_CONFIG_HOME = withr::local_tempdir(.local_envir = env)),
                      .local_envir = env)
}
rt_reply <- function(text) {
  list(status = 200L, body = charToRaw(bricklayer_json_to_json(
    list(choices = list(list(message = list(role = "assistant", content = text)))), auto_unbox = TRUE)))
}
rt_tags <- function(...) {
  list(status = 200L, body = charToRaw(bricklayer_json_to_json(
    list(models = lapply(c(...), function(n) list(name = n))), auto_unbox = TRUE)))
}
rt_ns <- function(nm) get(nm, envir = asNamespace("rmoriebricklayer"))

test_that("an endpoint of your own on a private LAN literal takes the local seam; names and link-local do not", {
  rt_env()
  withr::local_envvar(c(MORIE_LLM_BASE_URL = "http://10.0.0.5:8000", MORIE_LLM_API_KEY = "sk-own",
                        MORIE_LLM_MODEL = "my-model"))
  seen <- NULL
  testthat::local_mocked_bindings(
    .bl_http_post = function(...) stop("a LAN endpoint must take the local seam"),
    .bl_http_post_local = function(url, body, content_type, timeout, headers) {
      seen <<- list(url = url, headers = headers)
      rt_reply("lan says hi")
    },
    .package = "rmoriebricklayer")
  expect_identical(bricklayer_llm_ask("hi"), "lan says hi")
  expect_identical(seen$url, "http://10.0.0.5:8000/v1/chat/completions")
  expect_identical(seen$headers, "Authorization: Bearer sk-own")
  for (base in c("http://169.254.169.254/", "http://100.64.0.1:8000", "http://api.example.org/", "http://lmstudio/")) {
    withr::local_envvar(c(MORIE_LLM_BASE_URL = base))
    expect_error(bricklayer_llm_ask("hi"), "https://", info = base)
  }
})

test_that("an endpoint of your own is the first route, with its key and model", {
  rt_env()
  withr::local_envvar(c(MORIE_LLM_BASE_URL = "https://api.example.org/v1/", MORIE_LLM_API_KEY = "sk-own",
                        MORIE_LLM_MODEL = "my-model"))
  seen <- NULL
  # a REMOTE endpoint of your own goes through the ordinary POST seam: no loopback relaxation
  testthat::local_mocked_bindings(
    .bl_http_post = function(url, body, content_type, timeout, headers) {
      seen <<- list(url = url, headers = headers, body = rawToChar(body), seam = "public")
      rt_reply("own says hi")
    },
    .bl_http_post_local = function(...) stop("a remote endpoint must not take the loopback seam"),
    .package = "rmoriebricklayer")
  expect_identical(bricklayer_llm_ask("hi"), "own says hi")
  expect_identical(seen$url, "https://api.example.org/v1/chat/completions")
  expect_identical(seen$headers, "Authorization: Bearer sk-own")
  expect_match(seen$body, "\"model\":\"my-model\"", fixed = TRUE)
  expect_identical(seen$seam, "public")
  withr::local_envvar(c(MORIE_LLM_BASE_URL = "https://api.example.org/v1/"))
  st <- bricklayer_llm_status()
  expect_identical(st$route, c("own endpoint", "local Ollama", "hosted MORIE tier"))
  expect_identical(st$status[1], "configured")
  expect_match(st$detail[1], "https://api.example.org  model: my-model", fixed = TRUE)
  # no key configured: no Authorization header at all
  withr::local_envvar(c(MORIE_LLM_API_KEY = NA))
  bricklayer_llm_ask("hi")
  expect_null(seen$headers)
  # no model: said plainly
  withr::local_envvar(c(MORIE_LLM_MODEL = NA))
  expect_error(bricklayer_llm_ask("hi"), "own endpoint has no model to use")
  expect_match(bricklayer_llm_status()$detail[1], "(the server's first)", fixed = TRUE)
  withr::local_envvar(c(MORIE_LLM_BASE_URL = "ftp://x"))
  expect_error(bricklayer_llm_ask("hi"), "must be an http(s):// URL", fixed = TRUE)
  withr::local_envvar(c(MORIE_LLM_BASE_URL = "off"))
  expect_identical(bricklayer_llm_status()$status[1], "not set")
})

test_that("a local Ollama server is the second route; its first model is the default", {
  rt_env()
  withr::local_envvar(c(OLLAMA_HOST = "127.0.0.1:11434"))  # the form Ollama itself uses
  calls <- list()
  testthat::local_mocked_bindings(
    .bl_http_post = function(...) stop("a loopback server takes the local seam"),
    .bl_http_post_local = function(url, body, content_type, timeout, headers) {
      calls$post <<- list(url = url, headers = headers, body = rawToChar(body))
      rt_reply("llama says hi")
    },
    .bl_http_get_local = function(url, timeout, headers) {
      calls$get <<- list(url = url, headers = headers)
      rt_tags("llama3.2:latest", "qwen3:8b")
    },
    .package = "rmoriebricklayer")
  expect_identical(bricklayer_llm_ask("hi"), "llama says hi")
  expect_identical(calls$get$url, "http://127.0.0.1:11434/api/tags")
  expect_null(calls$get$headers)
  expect_identical(calls$post$url, "http://127.0.0.1:11434/v1/chat/completions")
  expect_null(calls$post$headers)
  expect_match(calls$post$body, "\"model\":\"llama3.2:latest\"", fixed = TRUE)
  withr::local_envvar(c(OLLAMA_MODEL = "qwen3:8b", OLLAMA_API_KEY = "ok-1"))
  bricklayer_llm_ask("hi")
  expect_match(calls$post$body, "\"model\":\"qwen3:8b\"", fixed = TRUE)
  expect_identical(calls$post$headers, "Authorization: Bearer ok-1")
  expect_identical(calls$get$headers, "Authorization: Bearer ok-1")
  st <- bricklayer_llm_status()
  expect_identical(st$status[2], "available")
  expect_match(st$detail[2], "llama3.2:latest, qwen3:8b (default qwen3:8b)", fixed = TRUE)
  # OLLAMA_BASE_URL is the other spelling, trailing slash dropped
  withr::local_envvar(c(OLLAMA_HOST = NA, OLLAMA_BASE_URL = "http://localhost:11434/"))
  bricklayer_llm_ask("hi")
  expect_identical(calls$post$url, "http://localhost:11434/v1/chat/completions")
  # a server with no models pulled yet
  testthat::local_mocked_bindings(.bl_http_get_local = function(...) rt_tags(), .package = "rmoriebricklayer")
  withr::local_envvar(c(OLLAMA_MODEL = NA))
  expect_error(bricklayer_llm_ask("hi", route = "ollama"), "local Ollama has no model to use")
  # left to choose, an empty Ollama is passed over rather than stopping the call
  expect_error(bricklayer_llm_ask("hi"), "No language-model route")
  expect_identical(bricklayer_llm_status()$status[2], "no models")
  # nothing listening: the route is skipped, and status says so
  testthat::local_mocked_bindings(
    .bl_http_get_local = function(...) list(status = -1L, body = raw(), error = "refused"),
    .package = "rmoriebricklayer")
  expect_identical(bricklayer_llm_status()$status[2], "not running")
  expect_error(bricklayer_llm_ask("hi"), "No language-model route")
  testthat::local_mocked_bindings(.bl_http_get_local = function(...) stop("boom"), .package = "rmoriebricklayer")
  expect_null(rt_ns(".bl_ollama_tags")("http://localhost:11434"))
  # a reply that is not JSON is "no models", not an error
  testthat::local_mocked_bindings(.bl_http_get_local = function(...) list(status = 200L, body = charToRaw("<html>")),
                                  .package = "rmoriebricklayer")
  expect_identical(rt_ns(".bl_ollama_tags")("http://localhost:11434"), character())
})

test_that("the order is own endpoint, then Ollama, then hosted; `route` insists on one", {
  rt_env()
  withr::local_envvar(c(MORIE_LLM_BASE_URL = "https://own.example.org", MORIE_LLM_MODEL = "m",
                        OLLAMA_HOST = "localhost:11434", MORIE_HOSTED_KEY = "sk-h"))
  testthat::local_mocked_bindings(
    .bl_http_get_local = function(...) rt_tags("l"),
    .bl_http_post = function(url, ...) rt_reply(url),
    .bl_http_post_local = function(url, ...) rt_reply(url),
    .package = "rmoriebricklayer")
  expect_match(bricklayer_llm_ask("x"), "^https://own.example.org/")
  expect_match(bricklayer_llm_ask("x", route = "ollama"), "^http://localhost:11434/")
  expect_match(bricklayer_llm_ask("x", route = "hosted"), "^https://llm.rmorie.com/")
  withr::local_envvar(c(MORIE_LLM_BASE_URL = NA))
  expect_match(bricklayer_llm_ask("x"), "^http://localhost:11434/")
  withr::local_envvar(c(OLLAMA_HOST = "off"))
  expect_match(bricklayer_llm_ask("x"), "^https://llm.rmorie.com/")
  expect_error(bricklayer_llm_ask("x", route = "own"), "own endpoint: `[a-z]+ config set own.url URL`")
  expect_error(bricklayer_llm_ask("x", route = "ollama"), "local Ollama: OLLAMA_HOST=off")
  expect_error(bricklayer_llm_ask("x", route = "nope"), "should be one of")
  expect_error(rt_ns(".bl_llm_route")("nope"), "unknown route 'nope'")
  withr::local_envvar(c(MORIE_HOSTED_KEY = NA))
  e <- tryCatch(bricklayer_llm_ask("x"), error = function(e) conditionMessage(e))
  expect_match(e, "^No language-model route is set up on this machine:")
  expect_match(e, "own endpoint: `[a-z]+ config set own.url URL`")
  expect_match(e, "local Ollama: OLLAMA_HOST=off")
  expect_match(e, "hosted MORIE tier: no key stored; request a key at https://rmorie.com/access")
  expect_match(agent_bundle("x"), "rmorie.com/access")
  withr::local_envvar(c(OLLAMA_HOST = "localhost:11434"))
  testthat::local_mocked_bindings(.bl_http_get_local = function(...) list(status = -1L), .package = "rmoriebricklayer")
  expect_match(tryCatch(bricklayer_llm_ask("x"), error = conditionMessage),
               "local Ollama: nothing answers at http://localhost:11434")
  withr::local_envvar(c(MORIE_HOSTED_BASE_URL = "off"))
  expect_match(bricklayer_llm_status()$detail[3], "MORIE_HOSTED_BASE_URL=off")
  expect_match(agent_bundle("x", backend = "hosted"),
               "hosted MORIE tier: disabled (MORIE_HOSTED_BASE_URL=off)", fixed = TRUE)
})

test_that("the CLI doctor prints the three routes in order, and bundle fails without one", {
  rt_env()
  buf <- character()
  st <- bricklayer_cli("doctor", out = function(s) buf <<- c(buf, s))
  expect_equal(st, 0L)
  expect_match(buf[1], "^  own endpoint +not set")
  expect_match(buf[2], "^  local Ollama +disabled +OLLAMA_HOST=off")
  expect_match(buf[3], "^  hosted MORIE tier +not logged in .*rmorie.com/access")
  buf <- character()
  expect_equal(bricklayer_cli(c("bundle", "x"), out = function(s) buf <<- c(buf, s)), 1L)
  expect_match(paste(buf, collapse = ""), "No language-model route")
  buf <- character()
  bricklayer_cli("models", out = function(s) buf <<- c(buf, s))
  expect_match(buf[1], "^Hosted MORIE tier: not logged in -- request a key at https://rmorie.com/access")
})

test_that("plain http is admitted on the loopback host only when the call asks for it", {
  chk <- function(u, http = FALSE, lo = TRUE) .Call(rt_ns("C_rmbl_url_check"), u, http, FALSE, lo)
  expect_match(chk("http://localhost:11434/api/tags", lo = FALSE), "plain http is refused")
  expect_match(chk("http://127.0.0.1:11434/", lo = FALSE), "plain http is refused")
  # the option of 0.5.8 is gone: it was a process-wide switch (fourth review)
  withr::local_options(rmoriebricklayer.allow_loopback = TRUE)
  expect_match(chk("http://127.0.0.1:11434/", lo = FALSE), "plain http is refused")
  expect_identical(chk("http://localhost:11434/api/tags"), "")
  expect_identical(chk("http://LOCALHOST/"), "")
  expect_identical(chk("http://127.0.0.1:11434/"), "")
  expect_identical(chk("http://127.9.9.9/"), "")
  expect_identical(chk("http://[::1]:11434/"), "")
  expect_identical(chk("https://localhost/"), "")
  # loopback or a LITERAL private LAN address (D4); link-local, CGNAT, public
  # plain-http and every name stay refused
  expect_identical(chk("http://10.0.0.1/"), "")
  expect_identical(chk("https://192.168.0.9:8443/"), "")
  expect_identical(chk("http://[fd00::1]:8000/v1"), "")
  expect_match(chk("http://100.64.0.1/"), "plain http is refused")
  expect_match(chk("https://100.64.0.1/"), "local or private")
  expect_match(chk("http://lmstudio.lan/"), "plain http is refused")
  expect_match(chk("https://169.254.169.254/"), "local or private")
  expect_match(chk("http://example.org/"), "plain http is refused")
  expect_match(chk("http://[fe80::1]/"), "plain http is refused")
  expect_match(chk("https://[::2]/"), "local or private")
  expect_match(chk("https://metadata.internal/"), "local or internal")
  expect_match(chk("ftp://localhost/"), "scheme ftp:// is refused")
  # a redirect off the loopback host meets the ordinary rules, and a remote origin
  # can never redirect INTO the loopback host, relaxation or not
  rc <- function(from, to) .Call(rt_ns("C_rmbl_redirect_check"), from, to, FALSE, TRUE)
  expect_false(rc("http://localhost:11434/v1/x", "http://10.0.0.1/y")$ok)
  expect_false(rc("http://10.0.0.1:8000/v1/x", "http://localhost:11434/y")$ok)
  expect_false(rc("http://localhost:11434/v1/x", "http://127.0.0.1:11434/y")$ok)
  expect_true(rc("http://localhost:11434/v1/x", "http://localhost:11435/v2/y")$ok)
  expect_true(rc("http://192.168.1.50:1234/v1/x", "http://192.168.1.50:1234/v1/y")$ok)
  expect_false(rc("http://localhost:11434/v1/x", "http://example.org/y")$ok)
  expect_true(rc("http://localhost:11434/v1/x", "https://example.org/y")$ok)
  expect_false(rc("https://evil.example.net/x", "http://127.0.0.1:11434/api/tags")$ok)
  expect_false(rc("https://evil.example.net/x", "http://localhost/")$ok)
  # the public-URL validator in R takes the same argument
  expect_identical(.rmbl_check_public_url("http://localhost:11434", "OLLAMA_HOST", allow_loopback = TRUE),
                   "http://localhost:11434")
  expect_error(.rmbl_check_public_url("http://localhost:11434", "OLLAMA_HOST"), "https://")
})

test_that("the transport really reaches a plain-http loopback server under the option", {
  skip_on_cran()
  skip_on_os("windows")
  py <- Sys.which("python3")
  skip_if(!nzchar(py), "no python3 to serve a loopback page")
  port <- 18000L + sample.int(1000L, 1L)
  dir <- withr::local_tempdir()
  dir.create(file.path(dir, "api"))
  writeLines('{"models":[{"name":"probe:latest"}]}', file.path(dir, "api", "tags"))
  system2(py, c("-m", "http.server", port, "--bind", "127.0.0.1", "--directory", shQuote(dir)),
          wait = FALSE, stdout = FALSE, stderr = FALSE)
  withr::defer(suppressWarnings(system2("pkill", c("-f", shQuote(sprintf("http.server %d", port))),
                                        stdout = FALSE, stderr = FALSE)))
  base <- sprintf("http://127.0.0.1:%d", port)
  up <- FALSE
  for (i in 1:40) {
    up <- isTRUE(rt_ns(".bl_http_get_local")(paste0(base, "/api/tags"), 2, NULL)$status == 200L)
    if (up) break
    Sys.sleep(0.25)
  }
  skip_if(!up, "the loopback server did not come up")
  # without the option the C transport refuses before connecting
  r <- .Call(rt_ns("C_rmbl_http_get"), paste0(base, "/api/tags"), 5L, NULL, FALSE)
  expect_identical(r$status, -1L)
  expect_match(r$error, "plain http is refused")
  # the Ollama probe path admits it, and reads the model list
  expect_identical(rt_ns(".bl_ollama_tags")(base), "probe:latest")
  withr::local_envvar(c(OLLAMA_HOST = base, MORIE_LLM_BASE_URL = NA))
  expect_identical(bricklayer_llm_status()$status[2], "available")
  # a POST reaches the server too (http.server answers 501 to POST: the connection was made)
  res <- rt_ns(".bl_post_json")(paste0(base, "/v1/chat/completions"), list(a = 1), timeout = 5, local = TRUE)
  expect_identical(res$status, 501L)
  expect_error(bricklayer_llm_ask("hi", route = "ollama"), "local Ollama answered 501")
})
