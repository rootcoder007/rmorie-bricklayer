# SPDX-License-Identifier: AGPL-3.0-or-later

test_that("agentbndl() returns a setup hint when no key is stored", {
  Sys.setenv(XDG_CONFIG_HOME = tempfile("xdg-"))
  on.exit(Sys.unsetenv("XDG_CONFIG_HOME"), add = TRUE)
  withr::local_envvar(OPENAI_API_KEY = NA, OLLAMA_HOST = "off", MORIE_LLM_BASE_URL = NA, MORIE_LLM_API_KEY = NA,
                      MORIE_LLM_ROUTE = NA)
  expect_match(agentbndl("hello"), "No language-model route")
  expect_match(agentbndl("hello"), "config setup` walks through it", fixed = TRUE)
  expect_match(agentbndl("hello", route = "ollama"), "local Ollama: OLLAMA_HOST=off")
  expect_false(grepl("own endpoint", agentbndl("hello", route = "ollama")))
  expect_error(agentbndl("hello", route = "gemini"), "no key for Google Gemini: set GEMINI_API_KEY")
  expect_error(agentbndl("hello", route = "hosted"), "retired")
  expect_error(agentbndl("hello", route = "cloud"), "must be one of")
})

test_that("agentbndl() sends the request with the bundle task to the route", {
  withr::local_envvar(OPENAI_API_KEY = "sk-x")
  seen <- NULL
  testthat::local_mocked_bindings(llmask = function(prompt, model = NULL, route = NULL,
                                                                syspro = NULL, ...) {
    seen <<- list(prompt = prompt, model = model, route = route, syspro = syspro)
    "ok"
  })
  expect_equal(agentbndl("fix the SHA256 (and it's manifest)", model = "m1", route = "openai"), "ok")
  expect_identical(seen$prompt, "fix the SHA256 (and it's manifest)")
  expect_match(seen$syspro, "^The task is a brick-proof, reproducible data bundle")
  expect_equal(seen$model, "m1")
  expect_equal(seen$route, "openai")
})
