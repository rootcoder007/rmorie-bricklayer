# SPDX-License-Identifier: AGPL-3.0-or-later

test_that("agent_bundle() returns a setup hint when no key is stored", {
  Sys.setenv(XDG_CONFIG_HOME = tempfile("xdg-"))
  on.exit(Sys.unsetenv("XDG_CONFIG_HOME"), add = TRUE)
  withr::local_envvar(OPENAI_API_KEY = NA, OLLAMA_HOST = "off")
  expect_match(agent_bundle("hello"), "No language-model route")
  expect_match(agent_bundle("hello"), "config setup` walks through it", fixed = TRUE)
  expect_match(agent_bundle("hello", route = "ollama"), "local Ollama: OLLAMA_HOST=off")
  expect_false(grepl("own endpoint", agent_bundle("hello", route = "ollama")))
  expect_error(agent_bundle("hello", route = "gemini"), "no key for Google Gemini: set GEMINI_API_KEY")
  expect_error(agent_bundle("hello", route = "hosted"), "retired")
  expect_error(agent_bundle("hello", route = "cloud"), "should be one of")
})

test_that("agent_bundle() sends the request with the bundle task to the route", {
  withr::local_envvar(OPENAI_API_KEY = "sk-x")
  seen <- NULL
  testthat::local_mocked_bindings(bricklayer_llm_ask = function(prompt, model = NULL, route = NULL,
                                                                system_prompt = NULL, ...) {
    seen <<- list(prompt = prompt, model = model, route = route, system_prompt = system_prompt)
    "ok"
  })
  expect_equal(agent_bundle("fix the SHA256 (and it's manifest)", model = "m1", route = "openai"), "ok")
  expect_identical(seen$prompt, "fix the SHA256 (and it's manifest)")
  expect_match(seen$system_prompt, "^The task is a brick-proof, reproducible data bundle")
  expect_equal(seen$model, "m1")
  expect_equal(seen$route, "openai")
})
