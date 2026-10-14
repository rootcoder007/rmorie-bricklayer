# Bring your own key: the provider presets, the three wire formats (OpenAI chat completions,
# Anthropic Messages, Gemini generateContent) with tool calls, the route order, and the help the
# model gets. The replies are shaped as each provider documents them; a stand-in server answers,
# so nothing reaches a provider.

ns <- function(f) get(f, envir = asNamespace("rmoriebricklayer"))

# every provider key and route variable cleared, Ollama off, settings in a scratch folder
byok_clean <- function(env = parent.frame()) {
  ps <- ns(".bl_llm_presets")()
  vars <- c(ps$key_env, ps$alt_env[nzchar(ps$alt_env)], ns(".bl_preset_model_env")(ps$id),
            "MORIE_LLM_ROUTE", "MORIE_LLM_BASE_URL", "MORIE_LLM_API_KEY", "MORIE_LLM_MODEL", "OLLAMA_MODEL",
            "OLLAMA_API_KEY", "OLLAMA_BASE_URL")
  withr::local_envvar(stats::setNames(rep(NA_character_, length(vars)), vars), .local_envir = env)
  withr::local_envvar(c(OLLAMA_HOST = "off", XDG_CONFIG_HOME = withr::local_tempdir(.local_envir = env)),
                      .local_envir = env)
}

# a stand-in for .bl_post_json: records each request, answers with the next reply in `replies`
fake_post <- function(replies) {
  s <- new.env()
  s$calls <- list()
  s$post <- function(url, payload, timeout = 30, headers = NULL, local = FALSE) {
    s$calls[[length(s$calls) + 1L]] <- list(url = url, payload = payload, headers = headers)
    r <- replies[[min(length(s$calls), length(replies))]]
    if (is.function(r)) r() else list(status = 200L, json = r, error = "")
  }
  s
}

tool_def <- list(list(name = "get_help", description = "help",
                      parameters = list(type = "object", properties = list(name = list(type = "string")),
                                        required = I("name"))))
convo <- list(list(role = "system", content = "be brief"), list(role = "user", content = "hi"),
              list(role = "assistant", content = "", tool_calls = list(list(id = "c1", name = "get_help",
                                                                             arguments = list(name = "knox_test")))),
              list(role = "tool", tool_call_id = "c1", name = "get_help", content = "Knox test page"))

test_that("the presets are the providers' documented addresses, each with its key variable", {
  ps <- bricklayer_llm_providers()
  expect_true(all(c("openai", "anthropic", "gemini", "openrouter", "groq", "together", "fireworks", "deepseek",
                    "mistral", "xai", "cerebras", "perplexity", "huggingface", "opencode", "cohere",
                    "nvidia") %in% ps$id))
  expect_false(anyDuplicated(ps$id) > 0)
  expect_true(all(startsWith(ps$base, "https://")))
  expect_true(all(grepl("^[A-Z][A-Z0-9_]+$", ps$key_env)))
  expect_identical(ps$base[ps$id == "anthropic"], "https://api.anthropic.com")
  expect_identical(ps$base[ps$id == "groq"], "https://api.groq.com/openai/v1")
  expect_identical(ps$base[ps$id == "huggingface"], "https://router.huggingface.co/v1")
  expect_identical(ps$base[ps$id == "opencode"], "https://opencode.ai/zen/v1")
  expect_identical(ps$api[ps$id == "gemini"], "gemini")
  byok_clean()
  expect_false(any(bricklayer_llm_providers()$key_set))
  withr::local_envvar(GOOGLE_API_KEY = "g-key")   # Gemini's alternative variable counts too
  expect_true(bricklayer_llm_providers()$key_set[ps$id == "gemini"])
})

test_that("OpenAI format: tools as functions, tool results as tool messages, the reply's tool calls read", {
  rt <- list(name = "OpenAI", id = "openai", api = "openai", base = "https://api.openai.com/v1", key = "sk-o")
  reply <- list(id = "chatcmpl-1", choices = list(list(index = 0L, finish_reason = "tool_calls",
    message = list(role = "assistant", content = NULL, tool_calls = list(list(id = "call_9", type = "function",
      `function` = list(name = "search_docs", arguments = "{\"query\":\"replicate weights\"}")))))))
  s <- fake_post(list(reply))
  local_mocked_bindings(.bl_post_json = s$post)
  out <- ns(".bl_llm_chat")(rt, "gpt-x", convo, tools = tool_def)
  req <- s$calls[[1L]]
  expect_identical(req$url, "https://api.openai.com/v1/chat/completions")
  expect_true("Authorization: Bearer sk-o" %in% req$headers)
  expect_identical(req$payload$tools[[1L]]$type, "function")
  expect_identical(req$payload$tools[[1L]][["function"]]$name, "get_help")
  expect_identical(req$payload$messages[[4L]]$role, "tool")
  expect_identical(req$payload$messages[[4L]]$tool_call_id, "c1")
  expect_identical(req$payload$messages[[3L]]$tool_calls[[1L]][["function"]]$arguments, "{\"name\":\"knox_test\"}")
  expect_identical(out$tool_calls[[1L]]$name, "search_docs")
  expect_identical(out$tool_calls[[1L]]$arguments$query, "replicate weights")
  expect_identical(out$finish, "tool_calls")
  # Perplexity documents /chat/completions at its root, without /v1
  pp <- ns(".bl_llm_request")(list(id = "perplexity", api = "openai", base = "https://api.perplexity.ai"),
                              "sonar-pro", convo, NULL, 100L)
  expect_identical(pp$url, "https://api.perplexity.ai/chat/completions")
  # own and Ollama addresses are kept without /v1, which the request adds
  own <- ns(".bl_llm_request")(list(name = "own endpoint", api = "openai", base = "http://localhost:1234"),
                               "m", convo, NULL, 100L)
  expect_identical(own$url, "http://localhost:1234/v1/chat/completions")
})

test_that("Anthropic Messages: system apart, tool results in a user turn, x-api-key and the version header", {
  rt <- list(name = "Anthropic", id = "anthropic", api = "anthropic", base = "https://api.anthropic.com",
             key = "sk-ant")
  reply <- list(id = "msg_1", type = "message", role = "assistant", stop_reason = "tool_use",
                content = list(list(type = "text", text = "Let me look."),
                               list(type = "tool_use", id = "toolu_1", name = "get_help",
                                    input = list(name = "survey_design"))))
  s <- fake_post(list(reply))
  local_mocked_bindings(.bl_post_json = s$post)
  out <- ns(".bl_llm_chat")(rt, "claude-opus-5-5", c(convo, list(list(role = "tool", tool_call_id = "c2",
                                                                       name = "get_help", content = "more"))),
                            tools = tool_def)
  req <- s$calls[[1L]]
  expect_identical(req$url, "https://api.anthropic.com/v1/messages")
  expect_true(all(c("x-api-key: sk-ant", "anthropic-version: 2023-06-01") %in% req$headers))
  expect_false(any(grepl("Authorization", req$headers)))
  expect_identical(req$payload$system, "be brief")
  expect_identical(req$payload$tools[[1L]]$input_schema$type, "object")
  roles <- vapply(req$payload$messages, function(m) m$role, "")
  expect_identical(roles, c("user", "assistant", "user"))
  # the two tool results travel in one user turn
  expect_length(req$payload$messages[[3L]]$content, 2L)
  expect_identical(req$payload$messages[[3L]]$content[[1L]]$type, "tool_result")
  expect_identical(req$payload$messages[[3L]]$content[[1L]]$tool_use_id, "c1")
  expect_identical(req$payload$messages[[2L]]$content[[1L]]$type, "tool_use")
  expect_identical(out$text, "Let me look.")
  expect_identical(out$tool_calls[[1L]]$id, "toolu_1")
  expect_identical(out$tool_calls[[1L]]$arguments$name, "survey_design")
})

test_that("Gemini generateContent: the model in the path, functionDeclarations, functionResponse, x-goog-api-key", {
  rt <- list(name = "Google Gemini", id = "gemini", api = "gemini", base = "https://generativelanguage.googleapis.com",
             key = "g-key")
  reply <- list(candidates = list(list(finishReason = "STOP", content = list(role = "model", parts = list(
    list(functionCall = list(name = "get_examples", args = list(name = "knox_test"))))))))
  s <- fake_post(list(reply))
  local_mocked_bindings(.bl_post_json = s$post)
  out <- ns(".bl_llm_chat")(rt, "models/gemini-x-pro", convo, tools = tool_def)
  req <- s$calls[[1L]]
  expect_identical(req$url, "https://generativelanguage.googleapis.com/v1beta/models/gemini-x-pro:generateContent")
  expect_identical(req$headers, "x-goog-api-key: g-key")
  expect_identical(req$payload$systemInstruction$parts[[1L]]$text, "be brief")
  decl <- req$payload$tools[[1L]]$functionDeclarations[[1L]]
  expect_identical(decl$parameters$type, "OBJECT")
  expect_identical(decl$parameters$properties$name$type, "STRING")
  expect_identical(req$payload$contents[[2L]]$role, "model")
  expect_identical(req$payload$contents[[3L]]$parts[[1L]]$functionResponse$name, "get_help")
  expect_identical(out$tool_calls[[1L]]$name, "get_examples")
  expect_identical(out$tool_calls[[1L]]$arguments$name, "knox_test")
  # no key in the address, only in the header
  expect_false(grepl("key=", req$url, fixed = TRUE))
})

test_that("errors and empty replies are said; the key never appears in an error", {
  rt <- list(name = "OpenAI", id = "openai", api = "openai", base = "https://api.openai.com/v1", key = "sk-secret-123")
  s <- fake_post(list(list(error = list(message = "Incorrect API key provided: sk-secret-123"))))
  s2 <- s
  s$post2 <- function(...) list(status = 401L, json = list(error = list(message = "bad key sk-secret-123")), error = "")
  local_mocked_bindings(.bl_post_json = s$post2)
  err <- tryCatch(ns(".bl_llm_chat")(rt, "m", convo), error = conditionMessage)
  expect_match(err, "rejected your key \\(HTTP 401\\)")
  expect_false(grepl("sk-secret-123", err, fixed = TRUE))
  local_mocked_bindings(.bl_post_json = function(...) {
    list(status = 400L, json = list(error = list(message = "model x does not support tools, key sk-secret-123")),
         error = "")
  })
  err2 <- tryCatch(ns(".bl_llm_chat")(rt, "m", convo), error = conditionMessage)
  expect_match(err2, "answered 400")
  expect_false(grepl("sk-secret-123", err2, fixed = TRUE))
  local_mocked_bindings(.bl_post_json = function(...) {
    list(status = 200L, json = list(choices = list(list(finish_reason = "length", message = list(content = "")))),
         error = "")
  })
  expect_error(ns(".bl_llm_chat")(rt, "m", convo), "returned no text \\(finish reason: length")
})

test_that("the route order: your own endpoint, then a provider with a key, then Ollama; hosted is retired", {
  byok_clean()
  expect_null(ns(".bl_llm_route")())
  withr::local_envvar(GROQ_API_KEY = "gsk", ANTHROPIC_API_KEY = "ant")
  rt <- ns(".bl_llm_route")()
  # the first provider with a key, in the presets' order
  expect_identical(rt$id, "anthropic")
  expect_identical(rt$model, "claude-opus-5-5")
  expect_identical(ns(".bl_llm_route")("groq")$key, "gsk")
  withr::local_envvar(MORIE_LLM_BASE_URL = "http://localhost:1234/v1", MORIE_LLM_MODEL = "m")
  expect_identical(ns(".bl_llm_route")()$name, "own endpoint")
  withr::local_envvar(MORIE_LLM_ROUTE = "groq")
  expect_identical(ns(".bl_llm_route")()$id, "groq")
  expect_error(ns(".bl_llm_route")("openai"), "no key for OpenAI: set OPENAI_API_KEY")
  expect_error(ns(".bl_llm_route")("hosted"), "retired")
  expect_error(bricklayer_llm_ask("x", route = "hosted"), "retired")
  withr::local_envvar(MORIE_LLM_ROUTE = "hosted")
  expect_message(rt2 <- ns(".bl_llm_route")(), "saved route `hosted` is ignored")
  expect_identical(rt2$name, "own endpoint")
  withr::local_envvar(MORIE_LLM_ROUTE = "nonsense")
  expect_error(ns(".bl_llm_route")(), "must be auto, own, ollama or a provider")
})

test_that("a provider with no model chosen says how to choose one, listing what it offers", {
  byok_clean()
  withr::local_envvar(OPENAI_API_KEY = "sk-o")
  local_mocked_bindings(.bl_http_get = function(url, timeout, headers) {
    list(status = 200L, body = charToRaw('{"data":[{"id":"gpt-a"},{"id":"gpt-b"}]}'), error = "")
  })
  err <- tryCatch(bricklayer_llm_ask("hi", docs = FALSE), error = conditionMessage)
  expect_match(err, "OpenAI has no model to use \\(it offers: gpt-a, gpt-b\\)")
  expect_match(err, "config set openai.model NAME")
  m <- bricklayer_llm_models()
  expect_identical(as.character(m), c("gpt-a", "gpt-b"))
  expect_identical(attr(m, "route"), "OpenAI")
})

test_that("each API's model list is read in its own shape", {
  lm <- ns(".bl_llm_list_models")
  local_mocked_bindings(.bl_http_get = function(url, timeout, headers) {
    body <- if (grepl("anthropic", url)) '{"data":[{"id":"claude-opus-5-5","type":"model"}]}' else
      '{"models":[{"name":"models/gemini-x","supportedGenerationMethods":["generateContent"]},
                  {"name":"models/embed-y","supportedGenerationMethods":["embedContent"]}]}'
    list(status = 200L, body = charToRaw(body), error = "", url = url)
  })
  expect_identical(lm(list(id = "anthropic", api = "anthropic", base = "https://api.anthropic.com", key = "k",
                           models_endpoint = TRUE)), "claude-opus-5-5")
  expect_identical(lm(list(id = "gemini", api = "gemini", base = "https://generativelanguage.googleapis.com",
                           key = "k", models_endpoint = TRUE)), "gemini-x")
  # a provider without a model list says so with NULL, and a failed list is NULL too
  expect_null(lm(list(id = "perplexity", api = "openai", models_endpoint = FALSE)))
  local_mocked_bindings(.bl_http_get = function(...) list(status = 500L, body = raw(0), error = ""))
  expect_null(lm(list(id = "openai", api = "openai", base = "https://api.openai.com/v1", key = "k",
                      models_endpoint = TRUE)))
})

test_that("keys are saved privately per provider, shown only as set, and the variable wins", {
  byok_clean()
  bricklayer_llm_config(anthropic.key = "sk-ant-saved", anthropic.model = "claude-x")
  tab <- bricklayer_llm_config()
  expect_identical(tab$value[tab$key == "anthropic.key"], "set")
  expect_identical(tab$source[tab$key == "anthropic.key"], "saved")
  expect_identical(tab$value[tab$key == "anthropic.model"], "claude-x")
  expect_false(any(grepl("sk-ant-saved", unlist(tab), fixed = TRUE)))
  p <- ns(".bl_config_path")()
  if (.Platform$OS.type == "unix") expect_identical(format(file.info(p)$mode), "600")
  expect_identical(ns(".bl_llm_route")()$key, "sk-ant-saved")
  withr::local_envvar(ANTHROPIC_API_KEY = "sk-ant-env")
  expect_identical(ns(".bl_llm_route")()$key, "sk-ant-env")
  expect_error(bricklayer_llm_config(route = "hosted"), "retired")
  expect_error(bricklayer_llm_config(route = "nowhere"), "route must be one of")
  expect_identical(bricklayer_llm_config(route = "groq")$value[1], "groq")
})

# ---- the help the model gets -------------------------------------------------------------------

test_that("the index lists every exported function that has a help page of its own", {
  pages <- ns(".bl_kn_pages")("rmoriebricklayer")
  idx <- ns(".bl_kn_index_lines")(pages)
  named <- sub("[( ].*$", "", idx)
  ex <- getNamespaceExports("rmoriebricklayer")
  documented <- unique(unlist(lapply(pages, function(p) p$exported)))
  expect_setequal(intersect(ex, documented), intersect(named, ex))
  # an export missing from the index is documented only on an internal page
  db <- ns(".bl_rd_db")()
  internal <- unlist(lapply(db, function(rd) {
    kw <- unlist(lapply(rd[ns(".bl_rd_tags")(rd) == "\\keyword"], ns(".bl_rd_plain")))
    if ("internal" %in% trimws(kw)) ns(".bl_rd_aliases")(rd)
  }))
  expect_true(all(setdiff(ex[!startsWith(ex, ".")], named) %in% c(internal, "%||%")))
  expect_true(any(grepl("^survey_design\\(data, weights", idx)))
})

test_that("the help search finds the right page for plain-words questions", {
  pages <- ns(".bl_kn_all_pages")("rmoriebricklayer")
  top <- function(q, k = 3L) vapply(ns(".bl_kn_search")(q, pages, k), function(p) p$name, "")
  expect_true("survey_design" %in% top("replicate weights bootstrap survey proportion"))
  expect_true("wayback_save" %in% top("archive many urls in the wayback machine"))
  expect_true("knox_test" %in% top("near repeat burglary clustering in space and time"))
  expect_identical(top("crime_density")[1L], "crime_density")
  expect_length(ns(".bl_kn_search")("", pages), 0L)
})

test_that("the tools answer in words, never with an error", {
  run <- function(tool, ...) ns(".bl_kn_run_tool")(list(name = tool, arguments = list(...)), "rmoriebricklayer")
  expect_match(run("search_docs", query = "kernel density of incidents"), "crime_density")
  expect_match(run("get_help", name = "knox_test"), "Knox test")
  expect_match(run("get_help", name = "no_such_fn"), "no_such_fn. does not exist in these packages: do not use it")
  expect_match(run("get_examples", name = "no_such_fn"), "does not exist in these packages")
  expect_match(run("get_examples", name = "knox_test"), "knox_test\\(")
  expect_match(run("list_datasets", filter = "tps"), "tps_break_enter_d14_2024.csv")
  expect_match(run("list_datasets", filter = "zzz-nothing"), "no dataset matches")
  expect_type(run("get_vignette"), "character")
  expect_match(run("get_vignette", name = "no-such-vignette"), "no vignette|no vignettes")
  expect_match(run("rm_rf"), "there is no tool")
  expect_match(run("get_help", name = 5), "give the function's name as a string")
})

test_that("ask with the help: a tool round trip, then the answer", {
  byok_clean()
  withr::local_envvar(OPENAI_API_KEY = "sk-o", MORIE_OPENAI_MODEL = "gpt-x")
  first <- list(choices = list(list(finish_reason = "tool_calls", message = list(content = "", tool_calls = list(
    list(id = "call_1", type = "function", `function` = list(name = "get_help",
                                                            arguments = "{\"name\":\"survey_design\"}")))))))
  final <- list(choices = list(list(finish_reason = "stop", message = list(
    content = "Use survey_design(d, weights = \"w\", replicates = reps, type = \"bootstrap\")."))))
  s <- fake_post(list(first, final))
  local_mocked_bindings(.bl_post_json = s$post)
  ans <- bricklayer_llm_ask("how do I use bootstrap replicate weights?")
  expect_match(ans, "survey_design")
  expect_length(s$calls, 2L)
  sys <- s$calls[[1L]]$payload$messages[[1L]]$content
  expect_match(sys, "rmoriebricklayer")
  expect_match(sys, "survey_design(data, weights", fixed = TRUE)
  expect_length(s$calls[[1L]]$payload$tools, 5L)
  # the tool's answer (the help page) went back to the model
  back <- s$calls[[2L]]$payload$messages
  tool_msg <- back[[length(back)]]
  expect_identical(tool_msg$role, "tool")
  expect_match(tool_msg$content, "Describe a complex survey design")
  # docs = FALSE sends the prompt alone
  s2 <- fake_post(list(final))
  local_mocked_bindings(.bl_post_json = s2$post)
  bricklayer_llm_ask("hello", docs = FALSE)
  expect_length(s2$calls[[1L]]$payload$messages, 1L)
  expect_null(s2$calls[[1L]]$payload$tools)
  expect_error(bricklayer_llm_ask("x", packages = "noSuchPkgXYZ"), "not installed")
})

test_that("a model without tools gets the matching help pages instead; spent rounds still give an answer", {
  byok_clean()
  withr::local_envvar(OPENAI_API_KEY = "sk-o", MORIE_OPENAI_MODEL = "small")
  refuse <- function() {
    list(status = 400L, json = list(error = list(message = "small does not support tools")), error = "")
  }
  ok <- list(choices = list(list(finish_reason = "stop", message = list(content = "Use knox_test()."))))
  s <- fake_post(list(refuse, ok))
  local_mocked_bindings(.bl_post_json = s$post)
  expect_match(bricklayer_llm_ask("near repeat burglary in space and time"), "knox_test")
  second <- s$calls[[2L]]$payload
  expect_null(second$tools)
  expect_match(second$messages[[1L]]$content, "Help pages that match the question")
  expect_match(second$messages[[1L]]$content, "Knox")
  # a model that keeps calling tools is stopped after the rounds and asked for its answer
  loop <- list(choices = list(list(finish_reason = "tool_calls", message = list(content = "", tool_calls = list(
    list(id = "c", type = "function", `function` = list(name = "search_docs", arguments = "{\"query\":\"x\"}")))))))
  s3 <- fake_post(c(rep(list(loop), 6L), list(ok)))
  local_mocked_bindings(.bl_post_json = s3$post)
  ans <- bricklayer_llm_ask("anything")
  expect_match(ans, "knox_test")
  expect_length(s3$calls, 7L)
  expect_null(s3$calls[[7L]]$payload$tools)
  # another error is not mistaken for a model without tools
  s4 <- fake_post(list(function() list(status = 500L, json = list(error = list(message = "overloaded")), error = "")))
  local_mocked_bindings(.bl_post_json = s4$post)
  expect_error(bricklayer_llm_ask("x"), "answered 500: overloaded")
})

test_that("an empty turn after the lookups is asked once more, without tools, for the answer", {
  byok_clean()
  rt <- list(name = "OpenAI", id = "openai", api = "openai", base = "https://api.openai.com/v1", key = "k")
  call <- list(choices = list(list(finish_reason = "tool_calls", message = list(content = NULL, tool_calls = list(
    list(id = "c1", type = "function", `function` = list(name = "get_help", arguments = '{"name":"knox_test"}'))))))
  )
  empty <- list(choices = list(list(finish_reason = "stop", message = list(content = "  \n"))))
  final <- list(choices = list(list(finish_reason = "stop", message = list(content = "use knox_test()"))))
  s <- fake_post(list(call, empty, final))
  local_mocked_bindings(.bl_post_json = s$post)
  expect_identical(ns(".bl_llm_assist")(rt, "m", "space-time clustering", "rmoriebricklayer"), "use knox_test()")
  expect_length(s$calls, 3L)
  expect_null(s$calls[[3L]]$payload$tools)
  expect_match(s$calls[[3L]]$payload$messages[[length(s$calls[[3L]]$payload$messages)]]$content, "Answer now")
  # and an empty answer then is an error that says so
  s <- fake_post(list(call, empty, empty))
  local_mocked_bindings(.bl_post_json = s$post)
  expect_error(ns(".bl_llm_assist")(rt, "m", "space-time clustering", "rmoriebricklayer"), "OpenAI returned no text")
})

test_that("the help in the prompt follows the model's capacity: all of it for a large one, the nearest for a small", {
  byok_clean()
  cap <- ns(".bl_llm_capacity")
  tier <- function(rt, m) ns(".bl_llm_tier")(cap(rt, m))$name
  ollama <- list(name = "local Ollama", api = "openai", base = "http://localhost:11434", local = TRUE, model = "m",
                 models = c("gemma3:4b", "minimax-m3:cloud", "gpt-oss:120b-cloud"),
                 remote = c("minimax-m3:cloud", "gpt-oss:120b-cloud"),
                 context = c("gemma3:4b" = 131072, "minimax-m3:cloud" = 512000, "gpt-oss:120b-cloud" = NA))
  # a model Ollama serves from its cloud has its full context; one it runs here gets Ollama's window
  expect_identical(cap(ollama, "minimax-m3:cloud"), 512000)
  expect_identical(cap(ollama, "gpt-oss:120b-cloud"), 128000)
  expect_identical(cap(ollama, "gemma3:4b"), 4096)
  expect_identical(tier(ollama, "minimax-m3:cloud"), "full")
  expect_identical(tier(ollama, "gemma3:4b"), "small")
  # Ollama's own cloud API (ollama.url https://ollama.com, with ollama.key) is not this machine
  cloud_api <- utils::modifyList(ollama, list(base = "https://ollama.com", local = FALSE, remote = character()))
  expect_identical(tier(cloud_api, "gpt-oss:120b"), "full")
  withr::local_envvar(OLLAMA_CONTEXT_LENGTH = "16384")
  expect_identical(tier(ollama, "gemma3:4b"), "compact")
  withr::local_envvar(OLLAMA_CONTEXT_LENGTH = NA)
  # a provider's model, a remote server of your own: large; your own server on this machine: compact
  expect_identical(tier(list(name = "OpenAI", id = "openai"), "gpt-x"), "full")
  expect_identical(tier(list(name = "own endpoint", local = FALSE), "m"), "full")
  expect_identical(tier(list(name = "own endpoint", local = TRUE), "m"), "compact")
  # MORIE_LLM_CONTEXT says what the model takes, whatever the route
  withr::local_envvar(MORIE_LLM_CONTEXT = "2048")
  expect_identical(tier(list(name = "OpenAI", id = "openai"), "gpt-x"), "small")
  withr::local_envvar(MORIE_LLM_CONTEXT = "not a number")
  expect_identical(tier(list(name = "OpenAI", id = "openai"), "gpt-x"), "full")
  withr::local_envvar(MORIE_LLM_CONTEXT = NA)

  ok <- list(choices = list(list(finish_reason = "stop", message = list(content = "ok"))))
  index_size <- function(model) {
    s <- fake_post(list(ok))
    local_mocked_bindings(.bl_post_json = s$post)
    ns(".bl_llm_assist")(ollama, model, "survey replicate weights", "rmoriebricklayer")
    sys <- s$calls[[1L]]$payload$messages[[1L]]$content
    list(n = length(grep("  -- ", strsplit(sys, "\n")[[1L]])), sys = sys)
  }
  small <- index_size("gemma3:4b")
  expect_lte(small$n, 40L)
  expect_match(small$sys, "survey_design")
  full <- index_size("minimax-m3:cloud")
  every <- length(ns(".bl_kn_index_lines")(Filter(function(p) p$pkg == "rmoriebricklayer",
                                                   ns(".bl_kn_all_pages")("rmoriebricklayer"))))
  expect_gte(full$n, every)  # a large model sees every function
  expect_gt(full$n, 200L)
})

test_that("the CLI: models for a route, ask --route with a provider, and the retired route said", {
  byok_clean()
  withr::local_envvar(GROQ_API_KEY = "gsk", MORIE_GROQ_MODEL = "llama-x")
  local_mocked_bindings(.bl_http_get = function(...) {
    list(status = 200L, body = charToRaw('{"data":[{"id":"llama-x"},{"id":"other"}]}'), error = "")
  })
  out <- character()
  st <- bricklayer_cli(c("models", "--route", "groq"), out = function(x) out <<- c(out, x))
  expect_identical(st, 0L)
  expect_true(any(grepl("\\* llama-x", out)))
  expect_identical(bricklayer_cli(c("models", "--route", "nowhere"), out = function(x) NULL), 2L)
  final <- list(choices = list(list(finish_reason = "stop", message = list(content = "pong"))))
  s <- fake_post(list(final))
  local_mocked_bindings(.bl_post_json = s$post)
  out <- character()
  expect_identical(bricklayer_cli(c("ask", "--route", "groq", "ping"), out = function(x) out <<- c(out, x)), 0L)
  expect_true(any(grepl("pong", out)))
  expect_identical(s$calls[[1L]]$url, "https://api.groq.com/openai/v1/chat/completions")
  out <- character()
  expect_identical(bricklayer_cli(c("ask", "--route", "hosted", "x"), out = function(x) out <<- c(out, x)), 1L)
  expect_true(any(grepl("retired", out)))
  # no route: models says what to set up
  withr::local_envvar(GROQ_API_KEY = NA)
  out <- character()
  expect_identical(bricklayer_cli("models", out = function(x) out <<- c(out, x)), 1L)
  expect_true(any(grepl("bring your own key", out)))
})

test_that("the dataset tool lists the curated tables from the manifest on disk; vignettes list and read", {
  byok_clean()
  cache <- withr::local_tempdir()
  writeLines('{"datasets":[{"key":"ncvs_38604/incidents","name":"NCVS incidents"}]}', file.path(cache, "manifest.json"))
  local_mocked_bindings(.bl_data_cache_dir = function() cache)
  run <- function(tool, ...) ns(".bl_kn_run_tool")(list(name = tool, arguments = list(...)), "rmoriebricklayer")
  expect_match(run("list_datasets", filter = "ncvs"), "bricklayer_data_load(\"ncvs_38604/incidents\")", fixed = TRUE)
  # a manifest that does not parse is passed over
  writeLines("{not json", file.path(cache, "manifest.json"))
  expect_false(grepl("data.rmorie.com", run("list_datasets"), fixed = TRUE))
  docdir <- file.path(withr::local_tempdir(), "rmoriebricklayer", "doc")  # an installed package's doc/
  dir.create(docdir, recursive = TRUE)
  writeLines(c("---", "title: Survey guide", "---", "Use survey_design()."), file.path(docdir, "survey.Rmd"))
  local_mocked_bindings(.bl_kn_doc_dir = function(p) docdir)
  expect_identical(run("get_vignette"), "survey (rmoriebricklayer)")
  expect_match(run("get_vignette", name = "survey"), "Use survey_design()", fixed = TRUE)
  expect_identical(run("get_vignette", name = "nope"), "no vignette 'nope'")
  local_mocked_bindings(.bl_kn_doc_dir = function(p) "")
  expect_identical(run("get_vignette"), "no vignettes are installed with these packages")
})

test_that("help text helpers: comments dropped, a usage without the call, a page without examples", {
  expect_identical(ns(".bl_rd_plain")(structure(list("hidden"), Rd_tag = "COMMENT")), "")
  expect_identical(ns(".bl_kn_call")("other_fn(x)", "survey_design"), "survey_design")
  local_mocked_bindings(.bl_rd_text = function(rd) c("Title", "Description:", "no code here"))
  out <- ns(".bl_kn_run_tool")(list(name = "get_examples", arguments = list(name = "knox_test")), "rmoriebricklayer")
  expect_identical(out, "no examples on that page")
})

test_that("Ollama's list keeps which models run in its cloud and each one's context", {
  byok_clean()
  body <- paste0('{"models":[{"name":"minimax-m3:cloud","remote_host":"https://ollama.com:443",',
                 '"details":{"context_length":512000}},{"name":"gemma3:4b","details":{}},{"name":""}]}')
  local_mocked_bindings(.bl_http_get_local = function(...) list(status = 200L, body = charToRaw(body)))
  tags <- ns(".bl_ollama_tags")("http://localhost:11434")
  expect_identical(as.character(tags), c("minimax-m3:cloud", "gemma3:4b"))
  expect_identical(attr(tags, "remote"), "minimax-m3:cloud")
  expect_identical(unname(attr(tags, "context")), c(512000, NA))
})

test_that("ask with docs refuses packages that are not named or not installed", {
  byok_clean()
  withr::local_envvar(OPENAI_API_KEY = "k", MORIE_OPENAI_MODEL = "m")
  expect_error(bricklayer_llm_ask("hi", packages = NA_character_), "`packages` must name installed packages")
  expect_error(bricklayer_llm_ask("hi", packages = "no.such.pkg.zz"), "not installed: no.such.pkg.zz")
})

test_that("the three wire formats: arguments as an object or nothing, text beside tool calls, Gemini schemas", {
  parse <- ns(".bl_openai_parse")
  tc <- function(args) {
    call <- list(id = "c1", `function` = list(name = "get_help", arguments = args))
    list(choices = list(list(message = list(content = "", tool_calls = list(call)))))
  }
  expect_identical(parse(tc(list(name = "x")))$tool_calls[[1L]]$arguments, list(name = "x"))
  expect_identical(parse(tc(NULL))$tool_calls[[1L]]$arguments, list())
  convo <- list(list(role = "user", content = "q"),
                list(role = "assistant", content = "looking it up",
                     tool_calls = list(list(id = "c1", name = "get_help", arguments = list(name = "x")))),
                list(role = "tool", tool_call_id = "c1", name = "get_help", content = "page one"),
                list(role = "tool", tool_call_id = "c2", name = "get_help", content = "page two"))
  a <- ns(".bl_anthropic_body")("m", convo, NULL, 100L)
  expect_identical(a$messages[[2L]]$content[[1L]], list(type = "text", text = "looking it up"))
  g <- ns(".bl_gemini_body")(convo, NULL, 100L)
  expect_identical(g$contents[[2L]]$parts[[1L]], list(text = "looking it up"))
  expect_length(g$contents, 3L)  # the two tool results go back in one user turn
  expect_length(g$contents[[3L]]$parts, 2L)
  sch <- ns(".bl_gemini_schema")(list(type = "array", items = list(type = "string")))
  expect_identical(sch$items$type, "STRING")
  expect_identical(ns(".bl_gemini_schema")("plain"), "plain")
  out <- ns(".bl_gemini_parse")(list(candidates = list(list(finishReason = "STOP",
    content = list(parts = list(list(text = "first"), list(text = "second")))))))
  expect_identical(out$text, "first\nsecond")
})

test_that("a package with thousands of help pages is searched, not listed whole", {
  byok_clean()
  rt <- list(name = "OpenAI", id = "openai", api = "openai", base = "https://api.openai.com/v1", key = "k")
  ok <- list(choices = list(list(finish_reason = "stop", message = list(content = "ok"))))
  s <- fake_post(list(ok))
  local_mocked_bindings(.bl_post_json = s$post, .bl_kn_list_max = 50L)
  ns(".bl_llm_assist")(rt, "m", "survey replicate weights", "rmoriebricklayer")
  sys <- s$calls[[1L]]$payload$messages[[1L]]$content
  # rmoriebricklayer stands in for the big package here: 40 of its pages listed, the rest searched
  expect_match(sys, "rmoriebricklayer has [0-9]+ more functions than are listed below: search_docs")
  expect_lte(length(grep("  -- ", strsplit(sys, "\n")[[1L]])), 41L)
  expect_match(sys, "survey_design")
})

test_that("route_info says which route would answer; chat sends a whole conversation as it is", {
  byok_clean()
  expect_null(bricklayer_llm_route_info())
  expect_error(bricklayer_llm_route_info("hosted"), "retired")
  withr::local_envvar(GROQ_API_KEY = "gsk-x", MORIE_GROQ_MODEL = "llama-x")
  info <- bricklayer_llm_route_info()
  expect_identical(info[c("route", "name", "model")], list(route = "groq", name = "Groq", model = "llama-x"))
  expect_match(info$base, "^https://api.groq.com")
  s <- fake_post(list(list(choices = list(list(finish_reason = "stop", message = list(content = "pong"))))))
  local_mocked_bindings(.bl_post_json = s$post)
  convo <- list(list(role = "system", content = "be brief"), list(role = "user", content = "ping"),
                list(role = "assistant", content = "?"), list(role = "user", content = "ping again"))
  expect_identical(bricklayer_llm_chat(convo), "pong")
  sent <- s$calls[[1L]]$payload$messages
  expect_identical(vapply(sent, function(m) m$role, ""), c("system", "user", "assistant", "user"))
  expect_null(s$calls[[1L]]$payload$tools)  # nothing added
  expect_error(bricklayer_llm_chat(list(list(role = "tool", content = "x"))), "must be a list of")
  expect_error(bricklayer_llm_chat("ping"), "must be a list of")
  expect_error(bricklayer_llm_chat(convo, route = "hosted"), "retired")
  withr::local_envvar(GROQ_API_KEY = NA)
  expect_error(bricklayer_llm_chat(convo), "No language-model route")
  withr::local_envvar(GROQ_API_KEY = "gsk-x", MORIE_GROQ_MODEL = NA)
  expect_error(bricklayer_llm_chat(convo, route = "groq"), "Groq has no model to use")
})
