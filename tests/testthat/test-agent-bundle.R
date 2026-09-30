# SPDX-License-Identifier: AGPL-3.0-or-later

test_that("agent_bundle() returns a setup hint when no route is available", {
  Sys.setenv(XDG_CONFIG_HOME = tempfile("xdg-"))
  on.exit(Sys.unsetenv("XDG_CONFIG_HOME"), add = TRUE)
  testthat::local_mocked_bindings(Sys.which = function(names) c(rmorie = ""),
                                  .package = "base")
  expect_match(agent_bundle("hello"), "No language-model route")
  expect_match(agent_bundle("hello"), "llm.rmorie.com", fixed = TRUE)
  expect_match(agent_bundle("hello", backend = "hosted"), "No key for the hosted")
  expect_error(agent_bundle("hello", backend = "gemini"), "should be one of")
})

test_that(".rmorie_cli_binary() ignores the launcher of the rmorie R package", {
  dir <- tempfile("launcher-")
  dir.create(dir)
  bin <- file.path(dir, "rmorie")
  writeLines(c("#!/bin/sh",
               "exec Rscript -e 'getNamespace(\"rmorie\")$morie_cli()' --args \"$@\""),
             bin)
  testthat::local_mocked_bindings(Sys.which = function(names) c(rmorie = bin),
                                  .package = "base")
  expect_equal(.rmorie_cli_binary(), "")
  writeLines(c("#!/bin/sh", "printf '%s\\n' \"$@\""), bin)
  expect_equal(unname(.rmorie_cli_binary()), bin)
})

test_that("agent_bundle() shell-quotes the request, backend and model", {
  skip_on_os("windows")
  Sys.setenv(XDG_CONFIG_HOME = tempfile("xdg-"))
  on.exit(Sys.unsetenv("XDG_CONFIG_HOME"), add = TRUE)
  dir <- tempfile("fakecli-")
  dir.create(dir)
  bin <- file.path(dir, "rmorie")
  writeLines(c("#!/bin/sh", "printf '%s\\n' \"$@\""), bin)
  Sys.chmod(bin, "0755")
  old_path <- Sys.getenv("PATH")
  on.exit(Sys.setenv(PATH = old_path), add = TRUE)
  Sys.setenv(PATH = paste(dir, old_path, sep = .Platform$path.sep))
  out <- agent_bundle("fix the SHA256 (and the Wayback fallback) for it's manifest",
                      backend = "ollama", model = "minimax-m3:cloud")
  lines <- strsplit(out, "\n", fixed = TRUE)[[1]]
  expect_equal(lines[1:5], c("agent", "--backend", "ollama", "-m", "minimax-m3:cloud"))
  expect_match(lines[6], "^You are helping build")
  expect_match(lines[6], "(and the Wayback fallback) for it's manifest", fixed = TRUE)
  expect_length(lines, 6L)
})
