# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Answers kept on this machine: the same question, on the same route, model, packages (and their
# versions) and instructions, comes back at once instead of asking the model again. Nothing is
# hosted: each answer is a small owner-only file under tools::R_user_dir("rmoriebricklayer",
# "cache"), kept 30 days (options(rmoriebricklayer.llm_cache_days)), at most the 200 newest
# (rmoriebricklayer.llm_cache_max): each save removes the rest, so the folder stays a few hundred
# KB, as CRAN asks of a package's cache (small, and outdated material removed). Only for a person at a
# terminal (`rmbl ask` with the terminal on both stdin and stdout) or an interactive R session, so
# scripts, pipelines, tests and checks never write there (`rmbl ask ... </dev/null >file` did, under
# the download bar's rule, which the command line always turns on; review of 29a55d8, G4). The
# first save in a session says where the answers go. MORIE_LLM_CACHE=off or
# options(rmoriebricklayer.llm_cache = FALSE) turns it off, fresh = TRUE (`ask --fresh`) asks again
# and keeps the new answer.

.bl_answer_cache_on <- function() {
  # never under a test run or R CMD check, of this package or of one that drives its command line
  if (identical(Sys.getenv("TESTTHAT"), "true") || nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_"))) return(FALSE)
  !tolower(Sys.getenv("MORIE_LLM_CACHE", "")) %in% c("off", "0", "false", "no") &&
    !isFALSE(getOption("rmoriebricklayer.llm_cache")) && !isTRUE(getOption("morie.quiet")) &&
    (interactive() || (.bl_stdin_tty() && .bl_stdout_tty()))
}

.bl_answer_dir <- function() {
  getOption("rmoriebricklayer.llm_cache_dir") %||% file.path(tools::R_user_dir("rmoriebricklayer", "cache"), "answers")
}

# The question is matched spacing aside, and in its own case (R is case-sensitive: df$X is not
# df$x; F3); everything else exactly.
.bl_answer_question <- function(prompt) gsub("[[:space:]]+", " ", trimws(prompt))

.bl_answer_key <- function(rt, model, prompt, pkgs = NULL, system_prompt = NULL) {
  vers <- vapply(pkgs, function(p) as.character(utils::packageVersion(p)), "")
  q <- .bl_answer_question(prompt)
  core_sha256(paste(c("v1", rt$name %||% "", rt$base %||% "", model %||% "", paste(pkgs, vers),
                      system_prompt %||% "", q), collapse = "\x1f"))
}

.bl_answer_get <- function(key, prompt = NULL) {
  if (!.bl_answer_cache_on()) return(NULL)
  f <- file.path(.bl_answer_dir(), paste0(key, ".json"))
  if (!file.exists(f)) return(NULL)
  days <- getOption("rmoriebricklayer.llm_cache_days", 30)
  if (difftime(Sys.time(), file.mtime(f), units = "days") > days) {
    unlink(f)
    return(NULL)
  }
  # the text parser: a file's contents are data, never a URL or a path to follow
  rec <- tryCatch(.rmbl_json_text(paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n"),
                                  simplifyVector = FALSE), error = function(e) NULL)
  ans <- rec$answer
  if (!is.character(ans) || length(ans) != 1L || !nzchar(ans)) return(NULL)
  # the stored question must be this one: a file is never trusted on its name alone
  if (!is.null(prompt) && !identical(.bl_answer_question(rec$question %||% ""), .bl_answer_question(prompt))) {
    return(NULL)
  }
  structure(ans, cached = rec$time %||% "")
}

.bl_answer_put <- function(key, prompt, model, answer) {
  if (!.bl_answer_cache_on() || !is.character(answer) || length(answer) != 1L || !nzchar(answer)) {
    return(invisible(FALSE))
  }
  d <- .bl_answer_dir()
  if (!isTRUE(.bl_said_once[["answer-cache"]])) {
    assign("answer-cache", TRUE, envir = .bl_said_once)
    message(sprintf(paste("(answers are kept on this machine for 30 days under %s, owner-only, so the same",
                          "question is answered at once; MORIE_LLM_CACHE=off turns that off)"), d))
  }
  ok <- tryCatch({
    if (!dir.exists(d)) dir.create(d, recursive = TRUE, mode = "0700")
    f <- file.path(d, paste0(key, ".json"))
    tmp <- paste0(f, ".tmp")
    writeLines(enc2utf8(bricklayer_json_to_json(list(question = prompt, model = model %||% "", answer = answer,
                                                    time = format(Sys.time(), "%Y-%m-%d %H:%M")),
                                               auto_unbox = TRUE)), tmp, useBytes = TRUE)
    Sys.chmod(tmp, "0600")
    file.rename(tmp, f)
  }, error = function(e) FALSE, warning = function(w) FALSE)
  .bl_answer_prune(d)
  invisible(isTRUE(ok))
}

# Expired answers go, and past the cap the oldest; leftover .tmp files of an interrupted save too.
.bl_answer_prune <- function(d = .bl_answer_dir()) {
  fs <- list.files(d, pattern = "^[0-9a-f]{64}[.]json$|[.]tmp$", full.names = TRUE)
  if (!length(fs)) return(invisible(0L))
  age <- as.numeric(difftime(Sys.time(), file.mtime(fs), units = "days"))
  drop <- age > getOption("rmoriebricklayer.llm_cache_days", 30) | (endsWith(fs, ".tmp") & age > 1 / 24)
  keep <- fs[!drop & endsWith(fs, ".json")]
  cap <- getOption("rmoriebricklayer.llm_cache_max", 200L)
  if (length(keep) > cap) drop[fs %in% keep[order(file.mtime(keep), decreasing = TRUE)][-seq_len(cap)]] <- TRUE
  unlink(fs[drop])
  invisible(sum(drop))
}
