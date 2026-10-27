# SPDX-License-Identifier: AGPL-3.0-or-later

test_that("the cache is off under a test run", {
  expect_false(.bl_answer_cache_on())
  expect_null(.bl_answer_get("k", "q"))
  expect_false(.bl_answer_put("k", "q", "m", "a"))
})

test_that("a question's key depends on everything that shapes the answer", {
  rt <- list(name = "own", base = "http://h", key = "sk")
  k <- .bl_answer_key(rt, "m", "what  is\n it")
  expect_identical(k, .bl_answer_key(rt, "m", " what is it "))
  expect_false(identical(k, .bl_answer_key(rt, "m2", "what is it")))
  expect_false(identical(
    k,
    .bl_answer_key(utils::modifyList(rt, list(key = "sk2")), "m", "what is it")
  ))
  expect_false(identical(k, .bl_answer_key(rt, "m", "what is it", NULL, "s")))
  expect_identical(.bl_answer_question("  a \t b\n"), "a b")
})

test_that("an answer kept is given back for the same question only", {
  d <- withr::local_tempdir()
  withr::local_options(rmoriebricklayer.llmcachedir = d)
  local_mocked_bindings(.bl_answer_cache_on = function() TRUE)
  # the once-a-session note is marked as shown for this test only
  said <- as.list(.bl_said_once)
  withr::defer({
    rm(list = ls(.bl_said_once, all.names = TRUE), envir = .bl_said_once)
    list2env(said, envir = .bl_said_once)
  })
  assign("answer-cache", TRUE, envir = .bl_said_once)
  key <- .bl_answer_key(list(name = "own"), "m", "q one")
  expect_true(.bl_answer_put(key, "q one", "m", "the answer"))
  got <- .bl_answer_get(key, "q one")
  expect_identical(as.character(got), "the answer")
  expect_null(.bl_answer_get(key, "another question"))
  expect_false(.bl_answer_put(key, "q one", "m", ""))
  writeLines("[1, 2]", file.path(d, "bad.json"))
  expect_null(.bl_answer_get("bad", NULL))
})

test_that("cache options set by hand to unusable values are refused by name", {
  withr::local_options(rmoriebricklayer.llmcachedays = "x")
  expect_error(.bl_answer_days(), "llmcachedays must be one number of days")
  withr::local_options(rmoriebricklayer.llmcachedays = NA)
  expect_error(.bl_answer_days(), "llmcachedays must be one number of days")
  withr::local_options(rmoriebricklayer.llmcachedays = 7)
  expect_identical(.bl_answer_days(), 7)
  withr::local_options(rmoriebricklayer.llmcachedir = TRUE)
  expect_error(.bl_answer_dir(), "llmcachedir must be one folder path")
})
