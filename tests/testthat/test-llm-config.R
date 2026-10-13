# Saved language-model settings (bricklayer_llm_config(), `rmbl config`) and
# the route `ask` takes with them. Everything is written under a temporary
# XDG_CONFIG_HOME; nothing leaves the machine.

cf_env <- function(env = parent.frame()) {
  withr::local_envvar(c(MORIE_LLM_BASE_URL = NA, MORIE_LLM_API_KEY = NA, MORIE_LLM_MODEL = NA,
                        MORIE_LLM_ROUTE = NA, OLLAMA_HOST = NA, OLLAMA_BASE_URL = NA,
                        OLLAMA_MODEL = NA, OLLAMA_API_KEY = NA,
                        MORIE_OPENAI_MODEL = NA, XDG_CONFIG_HOME = withr::local_tempdir(.local_envir = env)),
                      .local_envir = env)
}
cf_reply <- function(text) {
  list(status = 200L, body = charToRaw(bricklayer_json_to_json(
    list(choices = list(list(message = list(role = "assistant", content = text)))), auto_unbox = TRUE)))
}
cf_tags <- function(...) {
  list(status = 200L, body = charToRaw(bricklayer_json_to_json(
    list(models = lapply(c(...), function(n) list(name = n))), auto_unbox = TRUE)))
}
cf_out <- function(args) {
  buf <- character()
  st <- bricklayer_cli(args, out = function(s) buf <<- c(buf, s))
  list(status = st, text = paste(buf, collapse = ""))
}

test_that("a running Ollama with nothing pulled no longer hides a provider's key", {
  cf_env()
  withr::local_envvar(c(OPENAI_API_KEY = "sk-h", MORIE_OPENAI_MODEL = "gpt-x"))
  sent <- NULL
  testthat::local_mocked_bindings(
    .bl_http_get_local = function(...) cf_tags(),  # Ollama answers, with no models
    .bl_http_post = function(url, body, ...) {
      sent <<- list(url = url, body = rawToChar(body))
      cf_reply("provider says hi")
    },
    .bl_http_post_local = function(...) stop("an empty Ollama must not be asked"),
    .package = "rmoriebricklayer")
  expect_identical(bricklayer_llm_ask("hi"), "provider says hi")
  expect_match(sent$url, "^https://api.openai.com/v1/chat/completions")
  expect_identical(bricklayer_llm_ask("hi", model = "gpt-y"), "provider says hi")
  expect_match(sent$body, "\"model\":\"gpt-y\"", fixed = TRUE)
  # insisting on Ollama still says what is missing
  expect_error(bricklayer_llm_ask("hi", route = "ollama"), "local Ollama has no model to use")
  # and an OLLAMA_MODEL makes the empty server a route again (it may pull on demand)
  withr::local_envvar(c(OLLAMA_MODEL = "qwen3:8b", OPENAI_API_KEY = NA))
  testthat::local_mocked_bindings(.bl_http_post_local = function(url, ...) cf_reply(url),
                                  .package = "rmoriebricklayer")
  expect_match(bricklayer_llm_ask("hi"), "^http://localhost:11434/")
})

test_that("settings are saved privately, shown with their source, and the environment wins", {
  cf_env()
  tab <- bricklayer_llm_config()
  expect_identical(tab$key[1:3], c("route", "own.url", "own.key"))
  expect_true(all(tab$source == "default"))
  expect_false(file.exists(rmoriebricklayer:::.bl_config_path()))  # reading writes nothing
  bricklayer_llm_config(route = "openai", openai.model = "gpt-x",
                        ollama.url = "http://192.168.1.20:11434", own.key = "sk-own-secret-key")
  p <- rmoriebricklayer:::.bl_config_path()
  expect_true(file.exists(p))
  if (.Platform$OS.type == "unix") expect_identical(format(file.mode(p)), "600")
  tab <- bricklayer_llm_config()
  row <- function(k) tab[tab$key == k, ]
  expect_identical(row("route")$value, "openai")
  expect_identical(row("route")$source, "saved")
  expect_identical(row("openai.model")$value, "gpt-x")
  expect_identical(row("ollama.url")$value, "http://192.168.1.20:11434")
  expect_identical(row("own.key")$value, "set")  # no character of a key is ever shown
  expect_identical(rmoriebricklayer:::.bl_ollama_base(), "http://192.168.1.20:11434")
  withr::local_envvar(c(OPENAI_API_KEY = "sk-o"))
  expect_identical(rmoriebricklayer:::.bl_provider_route("openai")$model, "gpt-x")
  # an environment variable that is set wins, and says so
  withr::local_envvar(c(MORIE_OPENAI_MODEL = "gpt-y"))
  expect_identical(rmoriebricklayer:::.bl_provider_route("openai")$model, "gpt-y")
  expect_identical(bricklayer_llm_config()$source[bricklayer_llm_config()$key == "openai.model"], "environment")
  expect_warning(bricklayer_llm_config(openai.model = "x"), "MORIE_OPENAI_MODEL is set in the environment")
  # NULL or "" removes; the file goes when nothing is left
  withr::local_envvar(c(MORIE_OPENAI_MODEL = NA))
  bricklayer_llm_config(route = NULL, openai.model = "", ollama.url = NULL, own.key = NULL)
  expect_false(file.exists(p))
})

test_that("a saved route is the one ask takes; bad settings are refused", {
  cf_env()
  withr::local_envvar(c(OPENAI_API_KEY = "sk-h", MORIE_OPENAI_MODEL = "gpt-x"))
  testthat::local_mocked_bindings(
    .bl_http_get_local = function(...) cf_tags("llama3.2"),
    .bl_http_post = function(url, ...) cf_reply(url),
    .bl_http_post_local = function(url, ...) cf_reply(url),
    .package = "rmoriebricklayer")
  expect_match(bricklayer_llm_ask("x"), "^https://api.openai.com/v1/")  # auto: the provider's key first
  bricklayer_llm_config(route = "ollama")
  expect_match(bricklayer_llm_ask("x"), "^http://localhost:11434/")
  bricklayer_llm_config(route = "openai")
  expect_match(bricklayer_llm_ask("x"), "^https://api.openai.com/v1/")
  expect_match(bricklayer_llm_ask("x", route = "ollama"), "^http://localhost:11434/")  # the argument wins
  withr::local_envvar(c(MORIE_LLM_ROUTE = "ollama"))
  expect_match(bricklayer_llm_ask("x"), "^http://localhost:11434/")
  withr::local_envvar(c(MORIE_LLM_ROUTE = NA))
  bricklayer_llm_config(own.url = "http://localhost:1234/v1", own.model = "m", route = "own")
  expect_match(bricklayer_llm_ask("x"), "^http://localhost:1234/v1/chat")
  expect_error(bricklayer_llm_config(route = "cloud"), "route must be one of")
  expect_error(bricklayer_llm_config(own.url = "localhost:1234"), "own.url must be an http")
  expect_error(bricklayer_llm_config(hosted.url = "http://llm.example.org"), "unknown setting 'hosted.url'")
  expect_error(bricklayer_llm_config(colour = "red"), "unknown setting 'colour'")
  expect_error(bricklayer_llm_config("hosted"), "key = value")
  # a route saved by an older version, hosted, is passed over for auto, said once
  bricklayer_llm_config(route = NULL)
  cfg <- rmoriebricklayer:::.bl_config_path()
  writeLines('{"route":"hosted"}', cfg)
  expect_match(suppressMessages(bricklayer_llm_ask("x")), "^https://api.openai.com/v1/")
})

test_that("a provider's key is saved privately in llm.json and never shown; hosted.key is gone", {
  cf_env()
  bricklayer_llm_config(openai.key = "sk-new-openai-key")
  p <- rmoriebricklayer:::.bl_config_path()
  expect_true(file.exists(p))
  if (.Platform$OS.type == "unix") expect_identical(format(file.mode(p)), "600")
  expect_identical(rmoriebricklayer:::.bl_preset_key("openai"), "sk-new-openai-key")
  tab <- bricklayer_llm_config()
  expect_identical(tab$value[tab$key == "openai.key"], "set")
  expect_false(any(grepl("sk-new-openai-key", unlist(tab), fixed = TRUE)))
  expect_identical(tab$source[tab$key == "openai.key"], "saved")
  bricklayer_llm_config(openai.key = NULL)
  expect_null(rmoriebricklayer:::.bl_preset_key("openai"))
  expect_error(bricklayer_llm_config(hosted.key = "sk-x"), "unknown setting 'hosted.key'")
})

test_that("`config` from the shell: show, help, set, get, unset, path; doctor names the route ask takes", {
  cf_env()
  withr::local_envvar(c(OLLAMA_HOST = "off"))
  r <- cf_out("config")
  expect_equal(r$status, 0L)
  expect_match(r$text, "route +auto")
  expect_match(r$text, "config setup")
  expect_match(cf_out(c("config", "help"))$text, "MORIE_LLM_ROUTE")
  r <- cf_out(c("config", "set", "route", "anthropic"))
  expect_equal(r$status, 0L)
  expect_match(r$text, "route = anthropic")
  expect_identical(cf_out(c("config", "get", "route"))$text, "anthropic\n")
  expect_match(cf_out("config")$text, "route +anthropic +\\(saved\\)")
  expect_match(cf_out(c("config", "unset", "route"))$text, "route = auto")
  expect_identical(cf_out(c("config", "path"))$text, paste0(rmoriebricklayer:::.bl_config_path(), "\n"))
  expect_equal(cf_out(c("config", "set", "colour", "red"))$status, 2L)
  expect_equal(cf_out(c("config", "set", "route"))$status, 2L)
  expect_match(cf_out(c("config", "set", "route", "cloud"))$text, "route must be one of")
  expect_equal(cf_out(c("config", "frobnicate"))$status, 2L)
  expect_match(cf_out(c("config", "--help"))$text, "usage: .* config")
  # doctor: no route yet, then the provider with its model
  expect_match(cf_out("doctor")$text, "ask has no route yet")
  withr::local_envvar(c(OPENAI_API_KEY = "sk-h"))
  cf_out(c("config", "set", "openai.model", "gpt-oss-120b"))
  expect_match(cf_out("doctor")$text, "ask uses: OpenAI, model gpt-oss-120b")
})

test_that("`ask --route` picks the route for one call", {
  cf_env()
  withr::local_envvar(c(OPENAI_API_KEY = "sk-h", MORIE_OPENAI_MODEL = "gpt-x",
                        MORIE_LLM_BASE_URL = "https://own.example.org", MORIE_LLM_MODEL = "m"))
  testthat::local_mocked_bindings(.bl_http_post = function(url, ...) cf_reply(url),
                                  .package = "rmoriebricklayer")
  expect_match(cf_out(c("ask", "hi"))$text, "^https://own.example.org/")
  expect_match(cf_out(c("ask", "--route", "openai", "hi"))$text, "^https://api.openai.com/v1/")
  expect_match(cf_out(c("ask", "--route", "hosted", "hi"))$text, "retired")
  expect_match(cf_out(c("ask", "--route", "auto", "hi"))$text, "^https://own.example.org/")
  expect_equal(cf_out(c("ask", "--route", "cloud", "hi"))$status, 2L)
})

test_that("`config setup` walks through the settings and saves the answers", {
  cf_env()
  answers <- c("ollama", "http://192.168.1.20:11434", "qwen3:8b")
  testthat::local_mocked_bindings(
    .bl_readline = function(prompt, con = NULL, ...) {
      a <- answers[1L]
      answers <<- answers[-1L]
      if (is.na(a)) "" else a
    },
    .bl_http_get_local = function(...) list(status = -1L, body = raw()),
    .package = "rmoriebricklayer")
  r <- cf_out(c("config", "setup"))
  expect_equal(r$status, 0L)
  tab <- bricklayer_llm_config()
  expect_identical(tab$value[tab$key == "route"], "ollama")
  expect_identical(tab$value[tab$key == "ollama.url"], "http://192.168.1.20:11434")
  expect_identical(tab$value[tab$key == "ollama.model"], "qwen3:8b")
  expect_match(r$text, "Saved in ")
})

test_that("`help` lists the verbs and has a page per topic", {
  cf_env()
  h <- cf_out("help")
  expect_equal(h$status, 0L)
  expect_match(h$text, "config setup")
  expect_match(h$text, "help llm")
  expect_match(cf_out(c("help", "start"))$text, "Getting started")
  expect_match(cf_out(c("help", "llm"))$text, "config set route anthropic")
  expect_match(cf_out(c("help", "config"))$text, "MORIE_ANTHROPIC_MODEL")
  expect_match(cf_out(c("help", "r"))$text, "bricklayer_llm_config\\(route = \"anthropic\"")
  expect_match(cf_out(c("help", "ask"))$text, "usage: .* ask \\[--route")
  expect_equal(cf_out(c("help", "nonsense"))$status, 2L)
})

test_that("`config setup` covers a provider's key and model, and on auto Ollama and your own server", {
  cf_env()
  answers <- c("openai", "sk-typed-key-1234", "gpt-x")
  testthat::local_mocked_bindings(
    .bl_readline = function(prompt, con = NULL, ...) {
      a <- answers[1L]
      answers <<- answers[-1L]
      if (is.na(a)) "" else a
    },
    .bl_http_get = function(...) list(status = 200L, body = charToRaw('{"data":[{"id":"gpt-x"}]}')),
    .bl_http_get_local = function(...) list(status = -1L, body = raw()),
    .package = "rmoriebricklayer")
  r <- suppressMessages(cf_out(c("config", "setup")))
  expect_equal(r$status, 0L)
  expect_match(r$text, "Models: gpt-x", fixed = TRUE)
  expect_false(grepl("sk-typed-key-1234", r$text, fixed = TRUE))
  tab <- bricklayer_llm_config()
  val <- function(k) tab$value[tab$key == k]
  expect_identical(val("route"), "openai")
  expect_identical(val("openai.key"), "set")
  expect_identical(val("openai.model"), "gpt-x")
  expect_match(r$text, "ask uses: OpenAI, model gpt-x")
  answers <- c("auto", "off", "", "http://localhost:1234/v1", "local-model", "sk-own-key-5678")
  r <- cf_out(c("config", "setup"))
  tab <- bricklayer_llm_config()
  expect_identical(val("route"), "auto")
  expect_identical(val("ollama.url"), "off")
  expect_identical(val("own.url"), "http://localhost:1234/v1")
  expect_identical(val("own.model"), "local-model")
  expect_identical(val("own.key"), "set")
  expect_match(r$text, "ask uses: own endpoint, model local-model")
  # an unknown route answer falls back to auto
  answers <- c("cloud", "", "", "", "")
  cf_out(c("config", "setup"))
  expect_identical(bricklayer_llm_config()$value[1], "auto")
})

test_that("config refuses a malformed Ollama address and names settings it does not know", {
  cf_env()
  expect_error(bricklayer_llm_config(ollama.url = "local host"), "ollama.url must be")
  expect_error(bricklayer_llm_config(route = c("a", "b")), "route takes one value")
  bricklayer_llm_config(route = "OLLAMA")
  expect_identical(bricklayer_llm_config()$value[1], "ollama")
  expect_identical(rmoriebricklayer:::.bl_config_value("NOT_A_SETTING"), NULL)
  # a damaged file is an error (the saved route must not be silently dropped); it is never
  # written over, so it is removed before the settings below are saved
  writeLines("not json at all", rmoriebricklayer:::.bl_config_path())
  expect_error(rmoriebricklayer:::.bl_read_config(), "not a JSON object")
  unlink(rmoriebricklayer:::.bl_config_path())
  # `config get` and `config set` of a key that is not there
  expect_equal(cf_out(c("config", "get"))$status, 2L)
  expect_equal(cf_out(c("config", "unset", "nope"))$status, 2L)
  # a secret typed at the prompt when no value is given
  testthat::local_mocked_bindings(.bl_readline = function(prompt, con = NULL, ...) "sk-prompted-9999",
                                  .package = "rmoriebricklayer")
  expect_match(cf_out(c("config", "set", "own.key"))$text, "own.key = set", fixed = TRUE)
  # an environment variable set over a saved one is reported from the shell, not raised
  withr::local_envvar(c(OLLAMA_MODEL = "env-model"))
  expect_match(cf_out(c("config", "set", "ollama.model", "saved-model"))$text,
               "OLLAMA_MODEL is set in the environment")
})

test_that("doctor says why ask would fail when a saved address is unusable", {
  cf_env()
  withr::local_envvar(c(OLLAMA_HOST = "off"))
  testthat::local_mocked_bindings(.bl_llm_route = function(...) stop("bad address"),
                                  .package = "rmoriebricklayer")
  expect_match(cf_out("doctor")$text, "ask would fail: bad address")
})
