# bricklayer_explain_error(): where a message comes from, read from the code itself

ns <- function(x) get(x, envir = asNamespace("rmoriebricklayer"))

test_that("an error of the packages is traced to the code that raises it, without a model", {
  pk <- "rmoriebricklayer"
  r <- bricklayer_explain_error("Error: `prompt` must be a single non-empty string", packages = pk)
  expect_identical(r$match[1L], "exact")
  expect_identical(r$raised_by[1L], ".rmbl_string1")
  expect_match(r$exported[1L], "bricklayer_llm_ask")
  expect_identical(r$message[1L], "`...` must be a single non-empty string")
  # a condition, a try-error and the last error all work
  e <- tryCatch(bricklayer_llm_config(no.such = 1), error = function(e) e)
  expect_true(any(bricklayer_explain_error(e, packages = pk)$raised_by == "bricklayer_llm_config"))
  te <- try(bricklayer_llm_config(no.such = 1), silent = TRUE)
  expect_identical(bricklayer_explain_error(te, packages = pk)$match[1L], "exact")
  # with no message, the last error of the session
  expect_identical(bricklayer_explain_error(packages = pk)$match[1L], "exact")
  # cut short or retyped: matched by its words
  w <- bricklayer_explain_error("unknown setting 'foo'", packages = pk)
  expect_true(nrow(w) >= 1L)
  # R's own errors, and nonsense, are not claimed
  expect_identical(nrow(bricklayer_explain_error("object 'zz' not found", packages = pk)), 0L)
  expect_identical(nrow(bricklayer_explain_error("Error: ", packages = pk)), 0L)
  expect_error(bricklayer_explain_error(NA_character_), "text of an error")
  expect_error(bricklayer_explain_error("x", n = 0), "whole number")
  expect_error(bricklayer_explain_error("x", packages = "no.such.pkg.zz"), "not installed")
  expect_error(bricklayer_explain_error("x", packages = NA_character_), "installed packages")
  one <- bricklayer_explain_error("`prompt` must be a single non-empty string", packages = pk, n = 1)
  expect_identical(nrow(one), 1L)
})

test_that("message templates: sprintf, paste, paste0 with sep, and computed parts become wildcards", {
  tx <- ns(".bl_ee_text")
  expect_identical(tx(quote(sprintf("bad %s: %d%% of %5.2f", a, b, c))), "bad \001: \001% of \001")
  expect_identical(tx(quote(paste("a", x, "b"))), "a \001 b")
  expect_identical(tx(quote(paste("a", "b", sep = "-"))), "a-b")
  expect_identical(tx(quote(paste("a", "b", sep = s))), "a\001b")
  expect_identical(tx(quote(paste0("a", f(x)))), "a\001")
  expect_identical(tx(quote(gettextf(fmt = "n=%d", 1L))), "n=\001")
  expect_identical(tx(quote(x)), "\001")
  f <- function() {
    if (TRUE) stop("this message is long enough to count", call. = FALSE)
    warning("a warning that is long enough too")
    stop("short")
  }
  rows <- ns(".bl_ee_walk")(f, new.env())$rows
  expect_identical(vapply(rows, function(r) r[["kind"]], ""), c("error", "warning"))
})

test_that("the messages table is kept between sessions for a person watching, one copy per version", {
  d <- withr::local_tempdir()
  withr::local_options(rmoriebricklayer.llm_cache = NULL, rmoriebricklayer.llm_cache_dir = d, morie.progress = TRUE,
                       morie.quiet = NULL)
  withr::local_envvar(TESTTHAT = NA, `_R_CHECK_PACKAGE_NAME_` = NA, MORIE_LLM_CACHE = NA)
  writeLines("x", file.path(d, "messages-0000000000000000.rds"))  # an older version's
  memo <- ns(".bl_ee_memo")
  rm(list = ls(memo, all.names = TRUE), envir = memo)
  t1 <- ns(".bl_ee_table")("rmoriebricklayer")
  f <- list.files(d, pattern = "^messages-")
  expect_length(f, 1L)
  expect_false(identical(f, "messages-0000000000000000.rds"))
  memo <- ns(".bl_ee_memo")
  rm(list = ls(memo, all.names = TRUE), envir = memo)
  expect_identical(ns(".bl_ee_table")("rmoriebricklayer"), t1)  # read back
  # the answers' pruning leaves it alone
  ns(".bl_answer_prune")(d)
  expect_length(list.files(d, pattern = "^messages-"), 1L)
})

test_that("explain-error from the shell", {
  out <- function(...) {
    b <- character()
    st <- bricklayer_cli(c(...), out = function(x) b <<- c(b, x))
    list(status = st, text = paste(b, collapse = ""))
  }
  r <- out("explain-error", "`prompt` must be a single non-empty string")
  expect_identical(as.integer(r$status), 0L)
  expect_match(r$text, "raised in rmoriebricklayer::.rmbl_string1")
  expect_match(r$text, "describe ")
  r <- out("explain-error", "object 'zz' not found")
  expect_identical(as.integer(r$status), 1L)
  expect_match(r$text, "Not a message of these packages")
  r <- out("explain-error")
  expect_identical(as.integer(r$status), 2L)
  expect_match(r$text, "usage:")
})
