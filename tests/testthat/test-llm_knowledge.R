# SPDX-License-Identifier: AGPL-3.0-or-later

fake_pages <- function() {
  list(
    list(
      pkg = "rmoriebricklayer",
      name = "trndtst",
      aliases = "trndtst",
      exported = "trndtst",
      title = "Mann-Kendall trend test",
      usage = "trndtst(y, x = NULL, conflvl = 0.95)",
      tokens = .bl_kn_tokens("Mann-Kendall trend test of a series"),
      rd = NULL
    ),
    list(
      pkg = "rmoriebricklayer",
      name = "ginicoef",
      aliases = c("ginicoef", "concentration"),
      exported = "ginicoef",
      title = "Concentration of a total across units",
      usage = "ginicoef(x, na.rm = TRUE)",
      tokens = .bl_kn_tokens("Gini coefficient concentration of a total"),
      rd = NULL
    )
  )
}

test_that("search terms drop stop words and are lightly stemmed", {
  expect_identical(
    .bl_kn_tokens("The emissions of the testing stories"),
    c("emission", "test", "story")
  )
  sw <- .bl_kn_stop_words()
  expect_length(sw, 48L)
  expect_true(all(c("the", "function", "some") %in% sw))
  expect_false(anyDuplicated(sw) > 0L)
})

test_that("the tools are declared with their schemas", {
  tl <- .bl_kn_tools()
  expect_identical(
    vapply(tl, `[[`, "", "name"),
    c(
      "search_docs",
      "get_help",
      "get_examples",
      "list_datasets",
      "get_vignette"
    )
  )
  expect_identical(tl[[1L]]$parameters$required, I("query"))
  expect_identical(tl[[4L]]$parameters$required, I(character()))
  expect_identical(
    .bl_kn_tool_str("d"),
    list(type = "string", description = "d")
  )
})

test_that("a usage's call is cut out with its brackets balanced", {
  expect_identical(
    .bl_kn_call("f(a = c(\"x\", \"y\"), b) g(1)", "f"),
    "f(a = c(\"x\", \"y\"), b)"
  )
  expect_identical(.bl_kn_call("g(1)", "f"), "f")
  expect_identical(.bl_kn_clip("abcdef", 3L), "abc\n[... cut]")
  expect_identical(.bl_kn_clip("abc", 3L), "abc")
})

test_that("the tools answer in words, never with an error", {
  local_mocked_bindings(
    .bl_kn_all_pages = function(pkgs) fake_pages(),
    .bl_kn_render = function(p) paste("help of", p$name),
    .bl_rd_text = function(rd) c("Usage:", "x", "Examples:", "trndtst(1:5)")
  )
  run <- function(tool, ...) {
    .bl_kn_run_tool(list(name = tool, arguments = list(...)), "x")
  }
  expect_match(run("search_docs", query = "trend"), "^trndtst \\(")
  expect_identical(
    run("search_docs", query = "zzzz"),
    "nothing matches; try other words"
  )
  expect_equal(
    run("get_help", name = "ginicoef"),
    "help of ginicoef",
    tolerance = testthat::testthat_tolerance()
  )
  expect_match(run("get_help", name = "nope"), "'nope' does not exist")
  expect_match(run("get_help"), "give the function's name as a string")
  expect_equal(
    run("get_examples", name = "trndtst"),
    "trndtst(1:5)",
    tolerance = testthat::testthat_tolerance()
  )
  expect_match(run("get_examples", name = "nope"), "does not exist")
  expect_identical(run("frobnicate"), "there is no tool 'frobnicate'")
  expect_identical(
    .bl_kn_run_tool(list(name = c("a", "b")), "x"),
    "there is no tool ''"
  )
})

test_that("an example-less page says so", {
  local_mocked_bindings(
    .bl_kn_all_pages = function(pkgs) fake_pages(),
    .bl_rd_text = function(rd) c("Usage:", "x")
  )
  expect_identical(
    .bl_kn_tool_examples("trndtst", fake_pages(), 100L),
    "no examples on that page"
  )
})

test_that("the question carries the functions nearest it", {
  near <- fake_pages()
  tier <- .bl_llm_tier(4000)
  expect_identical(tier$name, "small")
  expect_identical(.bl_llm_tier(10000)$name, "compact")
  expect_identical(.bl_llm_tier(64000)$name, "full")
  ask <- .bl_kn_ask("q?", near, tier, character())
  expect_match(ask, "^q\\?\n\nFunctions nearest this question")
  expect_match(ask, "trndtst(y, x = NULL, conflvl = 0.95)", fixed = TRUE)
  expect_identical(.bl_kn_ask("q?", list(), tier, character()), "q?")
  expect_null(.bl_kn_big_note(character(), near, list()))
  expect_match(
    .bl_kn_big_note("rmoriebricklayer", near, list()),
    "^rmoriebricklayer has 2 more functions"
  )
})

test_that("a spent conversation budget is an error that says so", {
  local_mocked_bindings(.bl_route_what = function(rt) "the model")
  expect_error(
    .bl_llm_left(proc.time()[["elapsed"]] - 1, 10, list()),
    "the model gave no answer within 30 seconds"
  )
  expect_lte(.bl_llm_left(proc.time()[["elapsed"]] + 100, 10, list()), 10)
})

test_that("the assistant looks up help, then answers", {
  seen <- new.env()
  seen$n <- 0L
  local_mocked_bindings(
    .bl_kn_all_pages = function(pkgs) fake_pages(),
    .bl_llm_capacity = function(rt, model) 128000,
    .bl_llm_chat = function(rt, model, msgs, ...) {
      seen$n <- seen$n + 1L
      seen$msgs <- msgs
      if (seen$n == 1L) {
        list(
          text = "",
          tool_calls = list(list(
            id = "c1",
            name = "search_docs",
            arguments = list(query = "trend")
          ))
        )
      } else {
        list(text = "use trndtst()", tool_calls = list())
      }
    }
  )
  ans <- .bl_llm_assist(list(), "m", "a trend test", "rmoriebricklayer")
  expect_identical(ans, "use trndtst()")
  expect_identical(seen$n, 2L)
  roles <- vapply(seen$msgs, `[[`, "", "role")
  expect_identical(roles, c("system", "user", "assistant", "tool"))
  expect_match(seen$msgs[[4L]]$content, "trndtst")
})

test_that("an empty last answer is an error", {
  local_mocked_bindings(
    .bl_kn_all_pages = function(pkgs) fake_pages(),
    .bl_llm_capacity = function(rt, model) 128000,
    .bl_route_what = function(rt) "the model",
    .bl_llm_chat = function(rt, model, msgs, ...) {
      list(text = "", tool_calls = list())
    }
  )
  expect_error(
    .bl_llm_assist(list(), "m", "q", "rmoriebricklayer", max_rounds = 1L),
    "the model returned no text after 1 rounds"
  )
})
