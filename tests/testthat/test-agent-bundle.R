# SPDX-License-Identifier: AGPL-3.0-or-later

test_that("agent_bundle() returns an install hint when the CLI is absent", {
  testthat::local_mocked_bindings(Sys.which = function(names) c(rmorie = ""),
                                  .package = "base")
  expect_match(agent_bundle("hello"), "rmorie CLI not found")
})

test_that("agent_bundle() shell-quotes the request, backend and model", {
  skip_on_os("windows")
  dir <- tempfile("fakecli-"); dir.create(dir)
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
