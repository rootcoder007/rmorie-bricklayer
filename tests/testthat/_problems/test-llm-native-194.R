# Extracted from test-llm-native.R:194

# prequel ----------------------------------------------------------------------
.sandbox <- function(env = parent.frame()) {
  dir <- tempfile("xdg-")
  dir.create(dir)
  old <- Sys.getenv(c("XDG_CONFIG_HOME", "MORIE_HOSTED_KEY",
                      "MORIE_HOSTED_BASE_URL", "MORIE_HOSTED_MODEL"),
                    unset = NA)
  Sys.setenv(XDG_CONFIG_HOME = dir)
  Sys.unsetenv(c("MORIE_HOSTED_KEY", "MORIE_HOSTED_BASE_URL",
                 "MORIE_HOSTED_MODEL"))
  withr_restore <- function() {
    for (nm in names(old)) {
      if (is.na(old[[nm]])) Sys.unsetenv(nm) else do.call(Sys.setenv,
                                                          as.list(old[nm]))
    }
    unlink(dir, recursive = TRUE)
  }
  do.call(on.exit, list(substitute(withr_restore()), add = TRUE),
          envir = env)
  assign("withr_restore", withr_restore, envir = env)
  dir
}
.reply <- function(text, status = 200L) {
  body <- bricklayer_json_to_json(
    list(choices = list(list(message = list(role = "assistant",
                                            content = text)))),
    auto_unbox = TRUE)
  list(status = status, body = charToRaw(body))
}

# test -------------------------------------------------------------------------
src <- system.file("bin", "rmoriebricklayer", package = "rmoriebricklayer")
expect_true(nzchar(src))
expect_match(readLines(src)[1], "^#!/bin/sh")
expect_true(any(grepl("bricklayer_cli", readLines(src), fixed = TRUE)))
dir <- tempfile("bin-")
target <- suppressMessages(install_cli(dir = dir))
