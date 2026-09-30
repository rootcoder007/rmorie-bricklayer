# SPDX-License-Identifier: AGPL-3.0-or-later
#
# The hosted MORIE LLM tier (https://llm.rmorie.com), reached natively
# through the package's own libcurl POST. This is the fallback used when
# the rmorie package is not installed; when it is, rmorie's fuller
# provider chain (local Ollama, hosted, Gemini, OpenAI, keyword) is used
# instead. Both packages share one credentials file, so signing in with
# either signs in for both.

.bl_hosted_default_base <- "https://llm.rmorie.com"
.bl_hosted_default_model <- "minimax-m3:cloud"

# $XDG_CONFIG_HOME/morie/credentials.json, the same file morie and rmorie
# read. Reading it is always allowed; it is only ever written by an
# explicit sign-in (bricklayer_llm_login()), never by examples or tests,
# which point XDG_CONFIG_HOME at a temporary directory.
.bl_credentials_path <- function() {
  base <- trimws(Sys.getenv("XDG_CONFIG_HOME", unset = ""))
  if (!nzchar(base)) base <- file.path(path.expand("~"), ".config")
  file.path(base, "morie", "credentials.json")
}

.bl_read_credentials <- function() {
  p <- .bl_credentials_path()
  if (!file.exists(p)) return(list())
  txt <- paste(readLines(p, warn = FALSE), collapse = "\n")
  out <- tryCatch(bricklayer_json_from_json(txt, simplifyVector = TRUE),
                  error = function(e) NULL)
  if (is.list(out)) out else list()
}

.bl_write_credentials <- function(data) {
  p <- .bl_credentials_path()
  dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE)
  tmp <- paste0(p, ".tmp")
  writeLines(bricklayer_json_to_json(data, auto_unbox = TRUE, pretty = TRUE),
             tmp)
  Sys.chmod(tmp, mode = "0600")
  file.rename(tmp, p)
  invisible(p)
}

.bl_hosted_key <- function() {
  env <- trimws(Sys.getenv("MORIE_HOSTED_KEY", unset = ""))
  if (nzchar(env)) return(env)
  key <- .bl_read_credentials()$hosted_key
  if (is.character(key) && length(key) == 1L && nzchar(key)) key else NULL
}

# The endpoint, or NULL when disabled: "" (POSIX) or "off" (any platform,
# Windows drops a variable set to "").
.bl_hosted_base <- function() {
  if (!"MORIE_HOSTED_BASE_URL" %in% names(Sys.getenv())) {
    return(.bl_hosted_default_base)
  }
  v <- sub("/+$", "", trimws(Sys.getenv("MORIE_HOSTED_BASE_URL")))
  if (nzchar(v) && !tolower(v) %in% c("off", "none", "disabled")) v else NULL
}

.bl_hosted_model <- function() {
  v <- trimws(Sys.getenv("MORIE_HOSTED_MODEL", unset = ""))
  if (nzchar(v)) v else .bl_hosted_default_model
}

# One seam for the HTTP layer so tests can stand in canned replies.
.bl_http_post <- function(url, body, content_type, timeout, headers) {
  .Call(C_rmbl_http_post, url, body, content_type, as.integer(timeout),
        headers)
}

# rmorie is an Enhances (it lives on r-universe, not CRAN, so nothing may
# try to install it during a check); its functions are looked up by name.
.bl_has_rmorie <- function() requireNamespace("rmorie", quietly = TRUE)
.bl_rmorie <- function(name) getExportedValue("rmorie", name)

#' Ask the hosted MORIE language model
#'
#' Sends one prompt to the MORIE LLM tier at
#' \url{https://llm.rmorie.com} with the key stored by
#' \code{\link{bricklayer_llm_login}} (or \code{MORIE_HOSTED_KEY}) and
#' returns the reply. When the \code{rmorie} package is installed the
#' request goes through \code{rmorie::morie_llm_ask()} instead, whose
#' chain also tries a local Ollama first and your own Gemini or OpenAI
#' keys after the hosted tier.
#'
#' @param prompt Character scalar.
#' @param model Model id; default \code{MORIE_HOSTED_MODEL} or
#'   \code{"minimax-m3:cloud"}.
#' @param timeout Seconds to wait for the reply.
#' @param system_prompt Optional system message.
#' @return Character scalar with the reply. Errors when no key is stored,
#'   the tier is disabled (\code{MORIE_HOSTED_BASE_URL=off}) or the
#'   gateway answers with an error.
#' @examples
#' \dontrun{
#' bricklayer_llm_login(token = "<key from https://llm.rmorie.com>")
#' bricklayer_llm_ask("What does a SHA-256 provenance record protect against?")
#' }
#' @export
bricklayer_llm_ask <- function(prompt, model = NULL, timeout = 120,
                               system_prompt = NULL) {
  stopifnot(is.character(prompt), length(prompt) == 1L, nzchar(prompt))
  if (.bl_has_rmorie()) {
    ask <- .bl_rmorie("morie_llm_ask")
    return(paste(as.character(
      ask(prompt, model = model, system_prompt = system_prompt,
          timeout = timeout)), collapse = "\n"))
  }
  .bl_hosted_ask(prompt, model = model, timeout = timeout,
                 system_prompt = system_prompt)
}

.bl_hosted_ask <- function(prompt, model = NULL, timeout = 120,
                           system_prompt = NULL) {
  base <- .bl_hosted_base()
  if (is.null(base)) stop("the hosted MORIE LLM tier is disabled ",
                          "(MORIE_HOSTED_BASE_URL)")
  key <- .bl_hosted_key()
  if (is.null(key)) {
    stop("no key for https://llm.rmorie.com: run bricklayer_llm_login() ",
         "(or `rmoriebricklayer login` from the shell)")
  }
  msgs <- list()
  if (!is.null(system_prompt)) {
    msgs[[length(msgs) + 1L]] <- list(role = "system", content = system_prompt)
  }
  msgs[[length(msgs) + 1L]] <- list(role = "user", content = prompt)
  body <- list(model = if (is.null(model)) .bl_hosted_model() else model,
               messages = msgs)
  raw <- charToRaw(enc2utf8(bricklayer_json_to_json(body, auto_unbox = TRUE)))
  res <- .bl_http_post(paste0(base, "/v1/chat/completions"), raw,
                       "application/json", timeout,
                       paste("Authorization: Bearer", key))
  if (is.null(res) || !identical(as.integer(res$status), 200L)) {
    st <- if (is.null(res)) -1L else as.integer(res$status)
    detail <- ""
    if (!is.null(res) && length(res$body)) {
      err <- tryCatch(bricklayer_json_from_json(rawToChar(res$body)),
                      error = function(e) NULL)
      msg <- err$error$message
      if (is.character(msg) && length(msg) == 1L) detail <- paste0(": ", msg)
    }
    stop(sprintf("the hosted MORIE LLM tier answered %d%s", st, detail))
  }
  out <- bricklayer_json_from_json(rawToChar(res$body),
                                   simplifyVector = FALSE)
  txt <- out$choices[[1L]]$message$content
  if (!is.character(txt) || !length(txt)) stop("the gateway returned no text")
  paste(txt, collapse = "\n")
}

#' Sign in to the hosted MORIE language model
#'
#' Stores a key for \url{https://llm.rmorie.com} in the credentials file
#' shared with the \code{morie} and \code{rmorie} packages
#' (\code{$XDG_CONFIG_HOME/morie/credentials.json}, owner-only). Pass
#' a key obtained from the website (\code{token}); or, with the
#' \code{rmorie} package installed, leave \code{token} empty to run
#' rmorie's GitHub device flow or emailed-code flow (\code{email}).
#' Nothing is written except by this explicit call.
#'
#' @param token A key from \url{https://llm.rmorie.com}; stored as is.
#' @param email With \code{rmorie} installed: sign in with a 6-digit code
#'   sent to this address instead of GitHub.
#' @return The key, invisibly.
#' @examples
#' \dontrun{
#' bricklayer_llm_login(token = "<key from https://llm.rmorie.com>")
#' bricklayer_llm_login()                         # GitHub, needs rmorie
#' bricklayer_llm_login(email = "you@example.com")  # emailed code, needs rmorie
#' }
#' @export
bricklayer_llm_login <- function(token = NULL, email = NULL) {
  if (!is.null(token)) {
    token <- trimws(as.character(token))
    if (length(token) != 1L || !nzchar(token)) {
      stop("an empty token cannot be stored")
    }
    data <- .bl_read_credentials()
    data$hosted_key <- token
    data$hosted_base_url <- .bl_hosted_base()
    p <- .bl_write_credentials(data)
    message(sprintf("Token stored in %s", p))
    return(invisible(token))
  }
  if (.bl_has_rmorie()) {
    login <- .bl_rmorie("morie_llm_login")
    return(invisible(login(email = email)))
  }
  stop("bricklayer_llm_login() without a token needs the rmorie package ",
       "for the GitHub or email sign-in. Either install rmorie ",
       "(install.packages(\"rmorie\", repos = c(",
       "\"https://rootcoder007.r-universe.dev\", ",
       "\"https://cloud.r-project.org\"))) or get a key in the browser at ",
       "https://llm.rmorie.com and pass it as `token`.")
}

#' Forget the hosted MORIE language-model key
#'
#' Removes the key from the shared credentials file (and the file itself
#' when nothing else is stored in it).
#' @return \code{TRUE} when a key was removed, invisibly.
#' @examples
#' \dontrun{
#' bricklayer_llm_logout()
#' }
#' @export
bricklayer_llm_logout <- function() {
  data <- .bl_read_credentials()
  had <- !is.null(data$hosted_key)
  data$hosted_key <- NULL
  data$hosted_user <- NULL
  data$hosted_base_url <- NULL
  p <- .bl_credentials_path()
  if (length(data)) {
    .bl_write_credentials(data)
  } else if (file.exists(p)) {
    unlink(p)
  }
  message(if (had) "Logged out of the hosted MORIE LLM tier." else
            "No hosted key was stored.")
  invisible(had)
}

#' Report the language-model routes available from this machine
#'
#' @return A data frame with one row per route: \code{route},
#'   \code{status} and \code{detail}. Printed by \code{rmoriebricklayer
#'   doctor}.
#' @examples
#' bricklayer_llm_status()
#' @export
bricklayer_llm_status <- function() {
  base <- .bl_hosted_base()
  key <- .bl_hosted_key()
  data.frame(
    route = c("rmorie package", "hosted MORIE tier", "rmorie-cli agent"),
    status = c(
      if (.bl_has_rmorie()) "installed" else "absent",
      if (is.null(base)) "disabled"
      else if (is.null(key)) "not logged in" else "key stored",
      if (nzchar(.rmorie_cli_binary())) "on PATH" else "absent"),
    detail = c(
      "local Ollama, hosted tier, Gemini, OpenAI, keyword fallback",
      if (is.null(base)) "MORIE_HOSTED_BASE_URL=off" else base,
      "backend = \"ollama\" or \"anthropic\" in agent_bundle()"),
    stringsAsFactors = FALSE)
}
