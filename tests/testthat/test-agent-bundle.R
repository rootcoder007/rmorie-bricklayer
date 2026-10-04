# SPDX-License-Identifier: AGPL-3.0-or-later

test_that("agent_bundle() returns a setup hint when no key is stored", {
  Sys.setenv(XDG_CONFIG_HOME = tempfile("xdg-"))
  on.exit(Sys.unsetenv("XDG_CONFIG_HOME"), add = TRUE)
  withr::local_envvar(MORIE_HOSTED_KEY = NA)
  expect_match(agent_bundle("hello"), "No language-model route")
  expect_match(agent_bundle("hello"), "llm.rmorie.com", fixed = TRUE)
  expect_match(agent_bundle("hello", backend = "hosted"), "rmbl login")
  expect_error(agent_bundle("hello", backend = "gemini"), "should be one of")
  expect_error(agent_bundle("hello", backend = "ollama"), "should be one of")
})

test_that("agent_bundle() sends the request with its preamble to the hosted tier", {
  withr::local_envvar(MORIE_HOSTED_KEY = "sk-x", MORIE_HOSTED_BASE_URL = NA)
  seen <- NULL
  testthat::local_mocked_bindings(bricklayer_llm_ask = function(prompt, model = NULL, ...) {
    seen <<- list(prompt = prompt, model = model)
    "ok"
  })
  expect_equal(agent_bundle("fix the SHA256 (and it's manifest)", model = "m1"), "ok")
  expect_match(seen$prompt, "^You are helping build")
  expect_match(seen$prompt, "(and it's manifest)", fixed = TRUE)
  expect_equal(seen$model, "m1")
})
