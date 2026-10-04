# SPDX-License-Identifier: AGPL-3.0-or-later
#
# The hosted MORIE LLM tier (https://llm.rmorie.com), reached through the
# package's own libcurl POST: one key per user, minted by a GitHub device
# flow or an emailed one-time code, stored in a credentials file that the
# other MORIE packages read as well. No other package is involved.

.bl_hosted_default_base <- "https://llm.rmorie.com"
.bl_hosted_default_auth <- "https://llm.rmorie.com/auth"
.bl_hosted_default_model <- "minimax-m3:cloud"

# $XDG_CONFIG_HOME/morie/credentials.json, the file the morie (Python)
# and rmorie (R) packages read and write too, so one sign-in serves all.
# Reading it is always allowed; it is only ever written by an
# explicit sign-in (bricklayer_llm_login()), never by examples or tests,
# which point XDG_CONFIG_HOME at a temporary directory.
.bl_credentials_path <- function() {
  base <- trimws(Sys.getenv("XDG_CONFIG_HOME", unset = ""))
  if (!nzchar(base)) base <- file.path(path.expand("~"), ".config")
  file.path(base, "morie", "credentials.json")
}

.bl_read_credentials <- function() {
  p <- .bl_credentials_path()
  if (!file.exists(p)) {
    return(list())
  }
  txt <- paste(readLines(p, warn = FALSE), collapse = "\n")
  out <- tryCatch(bricklayer_json_from_json(txt, simplifyVector = TRUE),
    error = function(e) NULL
  )
  if (is.list(out)) out else list()
}

.bl_write_credentials <- function(data) {
  p <- .bl_credentials_path()
  dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE)
  tmp <- paste0(p, ".tmp")
  writeLines(
    bricklayer_json_to_json(data, auto_unbox = TRUE, pretty = TRUE),
    tmp
  )
  Sys.chmod(tmp, mode = "0600")
  file.rename(tmp, p)
  invisible(p)
}

.bl_store_key <- function(key, user = NULL) {
  data <- .bl_read_credentials()
  data$hosted_key <- key
  if (!is.null(user)) data$hosted_user <- user
  data$hosted_base_url <- .bl_hosted_base()
  .bl_write_credentials(data)
}

.bl_hosted_key <- function() {
  env <- trimws(Sys.getenv("MORIE_HOSTED_KEY", unset = ""))
  if (nzchar(env)) {
    return(env)
  }
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

.bl_hosted_auth <- function() {
  v <- sub("/+$", "", trimws(Sys.getenv("MORIE_HOSTED_AUTH_URL", unset = "")))
  if (nzchar(v)) v else .bl_hosted_default_auth
}

.bl_hosted_model <- function() {
  v <- trimws(Sys.getenv("MORIE_HOSTED_MODEL", unset = ""))
  if (nzchar(v)) v else .bl_hosted_default_model
}

# The GET seam: the hosted tier's model list.
.bl_http_get <- function(url, timeout, headers) {
  .Call(C_rmbl_http_get, url, as.integer(timeout), headers)
}

#' Models offered by the hosted MORIE LLM tier
#'
#' Asks the gateway (\code{GET /v1/models}) which models the stored key may
#' use, through the package's own libcurl binding.
#'
#' @param timeout Seconds to wait for the gateway.
#' @return A character vector of model names, empty when the tier is disabled,
#'   no key is stored, or the gateway does not answer, with attribute
#'   \code{"default"}: the model \code{bricklayer_llm_ask()} uses when none
#'   is named (the configured one when offered, else the first listed).
#' @examples
#' \donttest{
#' m <- bricklayer_llm_models()
#' attr(m, "default")
#' }
#' @export
bricklayer_llm_models <- function(timeout = 10) {
  base <- .bl_hosted_base()
  key <- .bl_hosted_key()
  if (is.null(base) || is.null(key)) {
    return(structure(character(), default = NULL, http_status = NA_integer_))
  }
  res <- .bl_models_reply(base, key, timeout)
  if (is.null(res) || !identical(as.integer(res$status), 200L)) {
    # http_status says why the list is empty: 401/403 a rejected key, NA no answer at all
    return(structure(character(), default = NULL,
                     http_status = if (is.null(res)) NA_integer_ else as.integer(res$status)))
  }
  parsed <- tryCatch(bricklayer_json_from_json(rawToChar(res$body), simplifyVector = FALSE),
    error = function(e) NULL
  )
  ids <- vapply(parsed$data %||% list(), function(m) as.character(m$id %||% ""), "")
  ids <- ids[nzchar(ids)]
  wanted <- .bl_hosted_model()
  structure(ids, default = if (length(ids) && !wanted %in% ids) ids[[1L]] else wanted)
}

# GET /v1/models with a key: the reply, or NULL when the gateway did not answer.
.bl_models_reply <- function(base, key, timeout = 10) {
  tryCatch(
    .bl_http_get(paste0(base, "/v1/models"), timeout, paste("Authorization: Bearer", key)),
    error = function(e) NULL
  )
}

# `login --token KEY`: ask the gateway before the key replaces a working one in the shared file
# (stored as is, a mistyped key left all three packages reporting "key rejected").
.bl_check_token <- function(token) {
  base <- .bl_hosted_base()
  if (is.null(base)) return(invisible(TRUE))
  res <- .bl_models_reply(base, token)
  if (is.null(res)) {
    stop(sprintf("could not reach %s to check the key; nothing stored (try again)", base), call. = FALSE)
  }
  if (!identical(as.integer(res$status), 200L)) {
    stop(sprintf("the gateway did not accept that key (HTTP %d); nothing stored (`%s login` mints one)",
                 as.integer(res$status), .bl_prog()), call. = FALSE)
  }
  invisible(TRUE)
}

# One line for a key the gateway refused, or for a gateway that did not answer.
.bl_key_state <- function(models) {
  st <- attr(models, "http_status")
  if (length(models)) return("ok")
  if (isTRUE(st %in% c(401L, 403L))) return("rejected")
  "unreachable"
}

# One seam for the HTTP layer so tests can stand in canned replies.
.bl_http_post <- function(url, body, content_type, timeout, headers) {
  .Call(
    C_rmbl_http_post, url, body, content_type, as.integer(timeout),
    headers
  )
}

# POST a JSON document, get back list(status, json) where json is the
# parsed reply (NULL when the body is not JSON).
.bl_post_json <- function(url, payload, timeout = 30, headers = NULL) {
  raw <- charToRaw(enc2utf8(bricklayer_json_to_json(payload,
    auto_unbox = TRUE
  )))
  res <- .bl_http_post(url, raw, "application/json", timeout, headers)
  if (is.null(res)) {
    return(list(status = -1L, json = NULL))
  }
  json <- NULL
  if (length(res$body)) {
    json <- tryCatch(
      bricklayer_json_from_json(rawToChar(res$body),
        simplifyVector = FALSE
      ),
      error = function(e) NULL
    )
  }
  list(status = as.integer(res$status), json = json)
}

.bl_reply_error <- function(res, what) {
  if (identical(what, "the hosted MORIE LLM tier") && isTRUE(res$status %in% c(401L, 403L))) {
    stop(sprintf("the hosted MORIE LLM tier rejected your key (HTTP %d): run `%s login` again",
                 res$status, .bl_prog()), call. = FALSE)
  }
  msg <- res$json$error
  if (is.list(msg)) msg <- msg$message
  detail <- ""
  if (is.character(msg) && length(msg) == 1L) {
    # a gateway error can quote the key it was sent ("Received API Key = sk-...", a key hash): never print it
    msg <- sub("(?i)[.,;]?\\s*(received api key|key hash).*$", "", msg, perl = TRUE)
    detail <- paste0(": ", msg)
  }
  stop(sprintf("%s answered %d%s", what, res$status, detail), call. = FALSE)
}

# The command name the user typed (the launchers set RMBL_PROG; rmbl and rmoriebricklayer are one command).
.bl_prog <- function() {
  p <- Sys.getenv("RMBL_PROG", "")
  if (nzchar(p)) p else "rmoriebricklayer"
}

#' Ask the hosted MORIE language model
#'
#' Sends one prompt to the MORIE LLM tier at
#' \url{https://llm.rmorie.com} with the key stored by
#' \code{\link{bricklayer_llm_login}} (or \code{MORIE_HOSTED_KEY}) and
#' returns the reply.
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
#' bricklayer_llm_login(email = "you@example.com")
#' bricklayer_llm_ask("What does a SHA-256 provenance record protect against?")
#' }
#' @export
bricklayer_llm_ask <- function(prompt, model = NULL, timeout = 120,
                               system_prompt = NULL) {
  stopifnot(is.character(prompt), length(prompt) == 1L, nzchar(prompt))
  base <- .bl_hosted_base()
  if (is.null(base)) {
    stop("the hosted MORIE LLM tier is disabled (MORIE_HOSTED_BASE_URL)",
      call. = FALSE
    )
  }
  key <- .bl_hosted_key()
  if (is.null(key)) {
    stop("no key for https://llm.rmorie.com: run bricklayer_llm_login() ",
      sprintf("(or `%s login` from the shell)", .bl_prog()),
      call. = FALSE
    )
  }
  msgs <- list()
  if (!is.null(system_prompt)) {
    msgs[[length(msgs) + 1L]] <- list(role = "system", content = system_prompt)
  }
  msgs[[length(msgs) + 1L]] <- list(role = "user", content = prompt)
  res <- .bl_post_json(paste0(base, "/v1/chat/completions"),
    list(
      model = if (is.null(model)) {
        .bl_hosted_model()
      } else {
        model
      },
      messages = msgs
    ),
    timeout = timeout,
    headers = paste("Authorization: Bearer", key)
  )
  if (res$status != 200L) .bl_reply_error(res, "the hosted MORIE LLM tier")
  txt <- res$json$choices[[1L]]$message$content
  if (!is.character(txt) || !length(txt) || !any(nzchar(txt))) {
    stop("the gateway returned no text", call. = FALSE)
  }
  paste(txt, collapse = "\n")
}

#' Sign in to the hosted MORIE language model
#'
#' Mints a personal key for \url{https://llm.rmorie.com} and stores it in
#' \code{$XDG_CONFIG_HOME/morie/credentials.json} (owner-only; the file
#' the \code{morie} and \code{rmorie} packages read too, so one sign-in
#' serves all three). Three ways in:
#' \itemize{
#'   \item \code{token}: a key you already have, from the website or an
#'     email; stored as is.
#'   \item \code{email}: a 6-digit code is sent to the address (valid
#'     ten minutes, single use); you type it, or pass \code{code}.
#'   \item neither: the GitHub device flow; a code is shown to enter at
#'     github.com, and the key arrives once you approve.
#' }
#' Nothing is written except by this explicit call.
#'
#' @param token A key from \url{https://llm.rmorie.com}.
#' @param email Sign in with a code sent to this address.
#' @param code The emailed code, when you already have it.
#' @param open_browser Open the GitHub page for the device flow.
#' @param poll_max_seconds How long the device flow waits for approval.
#' @return The key, invisibly.
#' @examples
#' \dontrun{
#' bricklayer_llm_login(email = "you@example.com")
#' bricklayer_llm_login() # GitHub device flow
#' bricklayer_llm_login(token = "<key from https://llm.rmorie.com>")
#' }
#' @export
bricklayer_llm_login <- function(token = NULL, email = NULL, code = NULL,
                                 open_browser = interactive(),
                                 poll_max_seconds = 600) {
  if (!is.null(token)) {
    token <- trimws(as.character(token))
    if (length(token) != 1L || !nzchar(token)) {
      stop("an empty token cannot be stored", call. = FALSE)
    }
    p <- .bl_store_key(token)
    message(sprintf("Token stored in %s", p))
    return(invisible(token))
  }
  if (!is.null(email)) {
    return(.bl_login_email(email, code))
  }
  .bl_login_device(open_browser, poll_max_seconds)
}

.bl_login_email <- function(email, code = NULL) {
  auth <- .bl_hosted_auth()
  email <- tolower(trimws(as.character(email)))
  if (length(email) != 1L || is.na(email) || !nzchar(email)) {
    stop("an email address is required", call. = FALSE)
  }
  if (!grepl("^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$", email)) {
    stop(sprintf("'%s' is not an email address", email), call. = FALSE)
  }
  if (is.null(code)) {
    res <- .bl_post_json(paste0(auth, "/email/code"), list(email = email))
    if (res$status != 200L) .bl_reply_error(res, "the sign-in service")
    message(sprintf(
      "A 6-digit code was sent to %s (valid for 10 minutes).",
      email
    ))
    code <- .bl_readline("Enter the code: ")
    if (!nzchar(code)) {
      stop(sprintf("no code entered; finish with `%s login --email %s --code CODE`", .bl_prog(), email),
           call. = FALSE)
    }
  }
  res <- .bl_post_json(
    paste0(auth, "/email/verify"),
    list(email = email, code = trimws(code))
  )
  if (res$status != 200L) .bl_reply_error(res, "the sign-in service")
  key <- res$json$api_key
  if (!is.character(key) || !nzchar(key)) {
    stop("the sign-in service returned no key", call. = FALSE)
  }
  p <- .bl_store_key(key, res$json$user)
  message(sprintf("Logged in; key stored in %s", p))
  invisible(key)
}

.bl_login_device <- function(open_browser = interactive(),
                             poll_max_seconds = 600) {
  auth <- .bl_hosted_auth()
  start <- .bl_post_json(paste0(auth, "/device/code"), list())
  if (start$status != 200L) .bl_reply_error(start, "the sign-in service")
  info <- start$json
  message(sprintf(
    "Sign in at %s and enter the code: %s",
    info$verification_uri, info$user_code
  ))
  if (isTRUE(open_browser)) {
    try(utils::browseURL(info$verification_uri), silent = TRUE)
  }
  interval <- as.numeric(if (is.null(info$interval)) 5 else info$interval)
  deadline <- Sys.time() + poll_max_seconds
  waited <- 0
  while (Sys.time() < deadline) {
    Sys.sleep(interval)
    waited <- waited + interval
    if (waited %% 30 < interval) {
      # a silent wait reads as a hang
      message(sprintf("still waiting for the sign-in to be approved (%ds elapsed; Ctrl-C stops)", as.integer(waited)))
    }
    res <- .bl_post_json(
      paste0(auth, "/device/token"),
      list(device_code = info$device_code)
    )
    if (res$status == 200L && is.character(res$json$api_key)) {
      p <- .bl_store_key(res$json$api_key, res$json$user)
      message(sprintf(
        "Logged in as %s; key stored in %s",
        if (is.null(res$json$user)) "user" else res$json$user,
        p
      ))
      return(invisible(res$json$api_key))
    }
    if (res$status != 428L) .bl_reply_error(res, "the sign-in service")
  }
  stop("timed out waiting for the GitHub approval", call. = FALSE)
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
  message(if (had) {
    "Logged out of the hosted MORIE LLM tier."
  } else {
    "No hosted key was stored."
  })
  invisible(had)
}

#' Report the language-model routes available from this machine
#'
#' @return A data frame with one row per route (the hosted MORIE tier):
#'   \code{route}, \code{status} and \code{detail}. Printed by
#'   \code{rmoriebricklayer doctor}.
#' @examples
#' bricklayer_llm_status()
#' @export
bricklayer_llm_status <- function() {
  base <- .bl_hosted_base()
  key <- .bl_hosted_key()
  data.frame(
    route = "hosted MORIE tier",
    status = if (is.null(base)) {
      "disabled"
    } else if (is.null(key)) {
      "not logged in"
    } else {
      "key stored"
    },
    detail = if (is.null(base)) {
      "MORIE_HOSTED_BASE_URL=off"
    } else if (is.null(key)) {
      base
    } else {
      hm <- bricklayer_llm_models()
      switch(.bl_key_state(hm),
        ok = sprintf("%s  models: %s (default %s)", base, paste(hm, collapse = ", "), attr(hm, "default")),
        rejected = sprintf("%s  (key rejected by the gateway -- run `%s login` again)", base, .bl_prog()),
        sprintf("%s  (gateway not reachable)", base)
      )
    },
    stringsAsFactors = FALSE
  )
}
