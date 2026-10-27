# SPDX-License-Identifier: AGPL-3.0-or-later

# The provider presets and the three wire formats, built and read without a
# network.

test_that("the presets list every provider once, with its own key variable", {
  ps <- .bl_llm_presets()
  expect_s3_class(ps, "data.frame")
  expect_identical(nrow(ps), 16L)
  expect_identical(anyDuplicated(ps$id), 0L)
  expect_identical(ps$id[1:3], c("openai", "anthropic", "gemini"))
  expect_identical(ps$id[16L], "nvidia")
  expect_true(all(ps$api %in% c("openai", "anthropic", "gemini")))
  expect_true(all(startsWith(ps$base, "https://")))
  expect_false(.bl_preset("perplexity")$models)
  expect_identical(.bl_preset("gemini")$alt_env, "GOOGLE_API_KEY")
  expect_true(is.na(.bl_preset("nonesuch")$id))
  row <- .bl_preset_row("x", "X", "https://x.example", "openai", "X_KEY")
  expect_identical(row$alt_env, "")
  expect_true(row$models)
})

test_that("a key with a line break in it is refused", {
  expect_null(.bl_key_text(NULL, "K"))
  expect_identical(.bl_key_text("sk-1", "K"), "sk-1")
  expect_error(.bl_key_text("sk\n1", "MY_KEY"), "MY_KEY has a line break")
})

test_that("each wire format gets its address and headers", {
  msgs <- list(list(role = "user", content = "hi"))
  an <- list(api = "anthropic", base = "https://a.example", key = "k")
  ge <- list(api = "gemini", base = "https://g.example", key = "k")
  op <- list(api = "openai", base = "https://o.example", key = "k", id = "o")
  own <- list(api = "openai", base = "https://own.example", key = NULL)
  expect_identical(
    .bl_llm_request(an, "m", msgs, NULL, 10L)$url,
    "https://a.example/v1/messages"
  )
  expect_identical(
    .bl_llm_request(ge, "models/g1", msgs, NULL, 10L)$url,
    "https://g.example/v1beta/models/g1:generateContent"
  )
  expect_identical(
    .bl_llm_request(op, "m", msgs, NULL, 10L)$url,
    "https://o.example/chat/completions"
  )
  expect_identical(.bl_openai_base(own), "https://own.example/v1")
  expect_identical(
    .bl_llm_headers(an),
    c("x-api-key: k", "anthropic-version: 2023-06-01")
  )
  expect_identical(.bl_llm_headers(ge), "x-goog-api-key: k")
})

test_that("a conversation with tool calls becomes Anthropic turns", {
  msgs <- list(
    list(role = "system", content = "be brief"),
    list(role = "user", content = "q"),
    list(
      role = "assistant",
      content = "",
      tool_calls = list(list(id = "c1", name = "f", arguments = list()))
    ),
    list(role = "tool", tool_call_id = "c1", content = "r1"),
    list(role = "tool", tool_call_id = "c2", content = "r2")
  )
  tools <- list(list(name = "f", description = "d", parameters = list()))
  b <- .bl_anthropic_body("m", msgs, tools, 50)
  expect_identical(b$max_tokens, 50L)
  expect_identical(b$system, "be brief")
  expect_length(b$messages, 3L)
  expect_identical(b$messages[[2L]]$content[[1L]]$type, "tool_use")
  # the two tool results travel in one user turn
  expect_length(b$messages[[3L]]$content, 2L)
  expect_identical(b$tools[[1L]]$name, "f")
  long <- list(list(role = "system", content = strrep("x", 4000L)))
  expect_identical(
    .bl_anthropic_body("m", long, NULL, 5)$system[[1L]]$cache_control$type,
    "ephemeral"
  )
})

test_that("a conversation with tool calls becomes Gemini contents", {
  msgs <- list(
    list(role = "system", content = "be brief"),
    list(role = "user", content = "q"),
    list(
      role = "assistant",
      content = "thinking",
      tool_calls = list(list(id = "f-1", name = "f", arguments = list(a = 1)))
    ),
    list(role = "tool", name = "f", content = "r1"),
    list(role = "tool", name = "f", content = "r2")
  )
  b <- .bl_gemini_body(msgs, NULL, 20)
  expect_identical(b$generationConfig$maxOutputTokens, 20L)
  expect_identical(b$systemInstruction$parts[[1L]]$text, "be brief")
  expect_length(b$contents, 3L)
  expect_identical(b$contents[[2L]]$role, "model")
  expect_length(b$contents[[2L]]$parts, 2L)
  expect_length(b$contents[[3L]]$parts, 2L)
})

test_that("the replies of the three formats read alike", {
  a <- .bl_anthropic_parse(list(
    content = list(
      list(type = "text", text = "hello"),
      list(type = "tool_use", id = "t", name = "f", input = list(x = 1))
    ),
    stop_reason = "tool_use"
  ))
  expect_identical(a$text, "hello")
  expect_identical(a$tool_calls[[1L]]$name, "f")
  expect_identical(a$finish, "tool_use")
  g <- .bl_gemini_parse(list(
    candidates = list(list(
      content = list(parts = list(list(functionCall = list(name = "f")))),
      finishReason = "STOP"
    ))
  ))
  expect_identical(g$tool_calls[[1L]]$id, "f-1")
  expect_identical(.bl_gemini_parse(list())$finish, "")
  o <- .bl_openai_parse(list(
    choices = list(list(
      message = list(content = "hi"),
      finish_reason = "stop"
    ))
  ))
  expect_identical(o$text, "hi")
  expect_identical(.bl_llm_parse(list(api = "openai"), list())$text, "")
})

test_that("a failed reply is an error naming the route", {
  rt <- list(name = "own endpoint", base = "https://own.example", key = "k")
  expect_null(.bl_llm_check_reply(rt, "m", list(status = 200L, json = list())))
  local_mocked_bindings(
    .bl_reply_error = function(res, what, secret) stop("failed: ", what)
  )
  expect_error(
    .bl_llm_check_reply(rt, "m", list(status = 500L, json = list())),
    "failed: the own endpoint"
  )
  expect_error(
    .bl_llm_check_reply(
      rt,
      "m",
      list(status = 200L, json = list(error = list(message = "x")))
    ),
    "failed: the own endpoint"
  )
})
