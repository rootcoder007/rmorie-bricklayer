# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Language-model routes, tried in this order: an OpenAI-compatible endpoint
# of your own (MORIE_LLM_BASE_URL), a local Ollama server (OLLAMA_HOST,
# default http://localhost:11434) and, last, the hosted MORIE tier. The
# hosted tier's addresses come from the signed services document
# (bricklayer_services()), never from a constant here, so they can move
# without a package release; its key is personal, issued on request at
# https://rmorie.com/access or minted by the GitHub / emailed-code sign-in,
# and stored in a credentials file the other MORIE packages read as well.
# Every request goes through the package's own libcurl binding.

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
  # created empty and made private BEFORE the key is written, so no umask
  # ever leaves it world-readable, even briefly
  file.create(tmp)
  Sys.chmod(tmp, mode = "0600")
  writeLines(
    bricklayer_json_to_json(data, auto_unbox = TRUE, pretty = TRUE),
    tmp
  )
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

# The hosted endpoint, or NULL when disabled. MORIE_HOSTED_BASE_URL overrides
# ("" on POSIX or "off" on any platform disables; Windows drops a variable set
# to ""); otherwise the signed services document decides, and a document
# with the tier switched off disables it here too.
.bl_hosted_base <- function() {
  if (!"MORIE_HOSTED_BASE_URL" %in% names(Sys.getenv())) {
    svc <- .rmbl_services_llm()
    if (!identical(svc$mode, "key") || !nzchar(svc$base_url %||% "")) return(NULL)
    return(svc$base_url)
  }
  v <- sub("/+$", "", trimws(Sys.getenv("MORIE_HOSTED_BASE_URL")))
  if (!nzchar(v) || tolower(v) %in% c("off", "none", "disabled")) return(NULL)
  # the bearer key is sent to this endpoint: https and a public address
  .rmbl_check_public_url(v, "MORIE_HOSTED_BASE_URL")
}

.bl_hosted_auth <- function() {
  v <- sub("/+$", "", trimws(Sys.getenv("MORIE_HOSTED_AUTH_URL", unset = "")))
  if (nzchar(v)) return(v)
  a <- .rmbl_services_llm()$auth_url %||% ""
  if (nzchar(a)) a else paste0(.bl_hosted_base() %||% "https://llm.rmorie.com", "/auth")
}

.bl_hosted_model <- function() {
  v <- trimws(Sys.getenv("MORIE_HOSTED_MODEL", unset = ""))
  if (nzchar(v)) return(v)
  m <- .rmbl_services_llm()$default_model %||% ""
  if (nzchar(m)) m else "minimax-m3:cloud"
}

# Why the hosted tier is off, for messages.
.bl_hosted_off_reason <- function() {
  if ("MORIE_HOSTED_BASE_URL" %in% names(Sys.getenv())) return("MORIE_HOSTED_BASE_URL=off")
  notice <- bricklayer_services(offline = TRUE)$notice %||% ""
  paste0("switched off in the services document", if (nzchar(notice)) paste0(": ", notice))
}

# How to get a key, in one line.
.bl_access_hint <- function() {
  sprintf(paste("request a key at %s, then `%s login --token KEY` (R: bricklayer_llm_login(token = ));",
                "`%s login` signs in with GitHub or an emailed code"),
          .rmbl_services_llm()$request_access %||% "https://rmorie.com/access", .bl_prog(), .bl_prog())
}

# The GET seam: the hosted tier's model list (a public https address, checked).
.bl_http_get <- function(url, timeout, headers) {
  .rmbl_check_public_url(url, "url")
  .Call(C_rmbl_http_get, url, as.integer(timeout), headers)
}

# ---- the routes in front of the hosted tier -----------------------------------
#
# An endpoint of your own and a local Ollama server are addresses from your own
# environment, not from a document, so the anti-SSRF policy that guards every
# other URL is relaxed for them in one precise way: plain http on the loopback
# interface is admitted while the call runs (options(rmoriebricklayer.allow_loopback)),
# nothing else private, and a redirect off the loopback host meets the usual rules.
.bl_with_local <- function(expr) {
  old <- options(rmoriebricklayer.allow_loopback = TRUE)
  on.exit(options(old), add = TRUE)
  force(expr)
}

.bl_own_base <- function() {
  v <- sub("/+$", "", trimws(Sys.getenv("MORIE_LLM_BASE_URL", unset = "")))
  if (!nzchar(v) || tolower(v) %in% c("off", "none", "disabled")) return(NULL)
  if (!grepl("^https?://[^/[:space:]]+", v)) {
    stop("MORIE_LLM_BASE_URL must be an http(s):// URL (an OpenAI-compatible server)", call. = FALSE)
  }
  sub("/v1$", "", v)  # the base, with or without the /v1 most servers document
}
.bl_env1 <- function(name) {
  v <- trimws(Sys.getenv(name, unset = ""))
  if (nzchar(v)) v else NULL
}

.bl_ollama_base <- function() {
  v <- .bl_env1("OLLAMA_HOST") %||% .bl_env1("OLLAMA_BASE_URL") %||% "http://localhost:11434"
  if (tolower(v) %in% c("off", "none", "disabled")) return(NULL)
  if (!grepl("^https?://", v)) v <- paste0("http://", v)  # OLLAMA_HOST is often host:port
  sub("/+$", "", v)
}

.bl_bearer <- function(key) if (is.null(key)) NULL else paste("Authorization: Bearer", key)

# GET for the local routes: the loopback relaxation on, the usual public-URL
# pre-flight off (the address is the user's own). One seam, so tests can
# stand in a server.
.bl_http_get_local <- function(url, timeout, headers) {
  .bl_with_local(.Call(C_rmbl_http_get, url, as.integer(timeout), headers))
}

# The models a local Ollama server has (GET /api/tags): a character vector,
# or NULL when nothing answers there.
.bl_ollama_tags <- function(base, timeout = 2) {
  res <- tryCatch(.bl_http_get_local(paste0(base, "/api/tags"), timeout, .bl_bearer(.bl_env1("OLLAMA_API_KEY"))),
                  error = function(e) NULL)
  if (is.null(res) || !identical(as.integer(res$status), 200L)) return(NULL)
  parsed <- tryCatch(bricklayer_json_from_json(rawToChar(res$body), simplifyVector = FALSE),
                     error = function(e) NULL)
  nm <- vapply(parsed$models %||% list(), function(m) as.character(m$name %||% m$model %||% "")[1L], "")
  nm[nzchar(nm)]
}

# The route a question takes: list(name, base, key, model, local), or NULL
# when nothing answers. `route` forces one of "own", "ollama", "hosted".
.bl_llm_route <- function(route = NULL, probe_timeout = 2) {
  for (r in route %||% c("own", "ollama", "hosted")) {
    hit <- switch(r,
      own = {
        base <- .bl_own_base()
        if (!is.null(base)) {
          list(name = "own endpoint", base = base, key = .bl_env1("MORIE_LLM_API_KEY"),
               model = .bl_env1("MORIE_LLM_MODEL"), local = TRUE)
        }
      },
      ollama = {
        base <- .bl_ollama_base()
        tags <- if (!is.null(base)) .bl_ollama_tags(base, probe_timeout)
        if (!is.null(tags)) {
          list(name = "local Ollama", base = base, key = .bl_env1("OLLAMA_API_KEY"),
               model = .bl_env1("OLLAMA_MODEL") %||% (if (length(tags)) tags[[1L]]),
               local = TRUE, models = tags)
        }
      },
      hosted = {
        base <- .bl_hosted_base()
        key <- .bl_hosted_key()
        if (!is.null(base) && !is.null(key)) {
          list(name = "hosted MORIE tier", base = base, key = key, model = .bl_hosted_model(), local = FALSE)
        }
      },
      stop(sprintf("unknown route '%s' (own, ollama or hosted)", r), call. = FALSE)
    )
    if (!is.null(hit)) return(hit)
  }
  NULL
}

# What to set up, when no route (or the one asked for) answers.
.bl_no_route_message <- function(route = NULL) {
  hosted <- .bl_hosted_base()
  hosted_line <- if (is.null(hosted)) {
    sprintf("hosted MORIE tier: disabled (%s); %s", .bl_hosted_off_reason(), .bl_access_hint())
  } else {
    sprintf("hosted MORIE tier: no key stored; %s", .bl_access_hint())
  }
  ollama <- .bl_ollama_base()
  ollama_line <- if (is.null(ollama)) {
    "local Ollama: OLLAMA_HOST=off"
  } else {
    sprintf("local Ollama: nothing answers at %s (install Ollama and pull a model, or point OLLAMA_HOST at a server)",
            ollama)
  }
  own_line <- paste("own endpoint: set MORIE_LLM_BASE_URL (and MORIE_LLM_API_KEY, MORIE_LLM_MODEL)",
                    "to any OpenAI-compatible server")
  lines <- switch(route %||% "any",
    own = own_line, ollama = ollama_line, hosted = hosted_line,
    c(own_line, ollama_line, hosted_line))
  paste(c("No language-model route is set up on this machine:", paste0("  ", lines)), collapse = "\n")
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
  timeout <- .rmbl_num(timeout, "timeout")
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
    stop(sprintf("the gateway did not accept that key (HTTP %d); nothing stored (%s)",
                 as.integer(res$status), .bl_access_hint()), call. = FALSE)
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
# parsed reply (NULL when the body is not JSON). `local` is the own-endpoint /
# Ollama relaxation described above.
.bl_post_json <- function(url, payload, timeout = 30, headers = NULL, local = FALSE) {
  raw <- charToRaw(enc2utf8(bricklayer_json_to_json(payload,
    auto_unbox = TRUE
  )))
  res <- if (isTRUE(local)) {
    .bl_with_local(.bl_http_post(url, raw, "application/json", timeout, headers))
  } else {
    .bl_http_post(url, raw, "application/json", timeout, headers)
  }
  if (is.null(res)) {
    return(list(status = -1L, json = NULL, error = ""))
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
  list(status = as.integer(res$status), json = json, error = res$error %||% "")
}

.bl_reply_error <- function(res, what) {
  if (!isTRUE(res$status > 0L)) {
    # libcurl gives -1 when no HTTP answer came at all; its own reason says which way it failed
    why <- if (nzchar(res$error %||% "")) res$error else "no network, or a proxy refused the connection"
    stop(sprintf("could not reach %s (%s)", what, why), call. = FALSE)
  }
  if (identical(what, "the hosted MORIE LLM tier") && isTRUE(res$status %in% c(401L, 403L))) {
    stop(sprintf(paste("the hosted MORIE LLM tier rejected your key (HTTP %d):",
                       "run `%s login` again, or `%s login --token KEY`"),
                 res$status, .bl_prog(), .bl_prog()), call. = FALSE)
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

#' Ask a language model
#'
#' Sends one prompt to the first language-model route that answers from
#' this machine and returns the reply. Routes, in order:
#' \enumerate{
#'   \item an OpenAI-compatible endpoint of your own: \code{MORIE_LLM_BASE_URL},
#'     with \code{MORIE_LLM_API_KEY} and \code{MORIE_LLM_MODEL} when it needs them;
#'   \item a local Ollama server: \code{OLLAMA_HOST} (or
#'     \code{OLLAMA_BASE_URL}), default \code{http://localhost:11434}, model
#'     \code{OLLAMA_MODEL} or the first one the server lists; \code{OLLAMA_HOST=off}
#'     skips it;
#'   \item the hosted MORIE tier, a last resort for people who can run neither:
#'     its address comes from \code{\link{bricklayer_services}} and it needs the
#'     key stored by \code{\link{bricklayer_llm_login}} (or \code{MORIE_HOSTED_KEY}).
#'     Keys are personal and issued on request at \url{https://rmorie.com/access}.
#' }
#' \code{\link{bricklayer_llm_status}} shows which route a question would take.
#'
#' @param prompt Character scalar.
#' @param model Model id; default the route's own (see above).
#' @param timeout Seconds to wait for the reply.
#' @param system_prompt Optional system message.
#' @param route \code{NULL} (the first that answers) or one of \code{"own"},
#'   \code{"ollama"}, \code{"hosted"} to insist on a route.
#' @return Character scalar with the reply. Errors, saying what to set up,
#'   when no route answers, and when the server answers with an error.
#' @examples
#' \dontrun{
#' bricklayer_llm_ask("What does a SHA-256 provenance record protect against?")
#' bricklayer_llm_ask("Explain an E-value of 2.1", route = "ollama")
#' }
#' @export
bricklayer_llm_ask <- function(prompt, model = NULL, timeout = 120,
                               system_prompt = NULL, route = NULL) {
  prompt <- .rmbl_string1(prompt, "prompt")
  if (!is.null(route)) route <- match.arg(route, c("own", "ollama", "hosted"))
  rt <- .bl_llm_route(route)
  if (is.null(rt)) stop(.bl_no_route_message(route), call. = FALSE)
  what <- if (identical(rt$name, "hosted MORIE tier")) "the hosted MORIE LLM tier" else paste("the", rt$name)
  asked_model <- model
  model <- model %||% rt$model
  if (is.null(model) || !nzchar(model)) {
    stop(sprintf("%s has no model to use: pull one (`ollama pull NAME`) or set %s", rt$name,
                 if (identical(rt$name, "own endpoint")) "MORIE_LLM_MODEL" else "OLLAMA_MODEL"), call. = FALSE)
  }
  msgs <- list()
  if (!is.null(system_prompt)) {
    msgs[[length(msgs) + 1L]] <- list(role = "system", content = system_prompt)
  }
  msgs[[length(msgs) + 1L]] <- list(role = "user", content = prompt)
  ask <- function() {
    .bl_post_json(paste0(rt$base, "/v1/chat/completions"),
      list(
        model = model,
        messages = msgs,
        # reasoning models think first: without room the answer comes back empty
        max_tokens = 4096L
      ),
      timeout = timeout,
      headers = .bl_bearer(rt$key),
      local = isTRUE(rt$local)
    )
  }
  res <- ask()
  if (!isTRUE(res$status > 0L)) {
    Sys.sleep(1)  # one retry: a dropped connection is often momentary
    res <- ask()
  }
  if (res$status != 200L) {
    if (identical(rt$name, "hosted MORIE tier") && !is.null(asked_model) && isTRUE(res$status %in% c(401L, 403L))) {
      # the gateway answers 403 for a model the key does not have: say that, not "log in again"
      have <- tryCatch(bricklayer_llm_models(), error = function(e) character())
      if (length(have) && !asked_model %in% have) {
        stop(sprintf("the hosted tier has no model '%s' (`%s models` lists the %d it has)",
                     asked_model, .bl_prog(), length(have)), call. = FALSE)
      }
    }
    .bl_reply_error(res, what)
  }
  txt <- res$json$choices[[1L]]$message$content
  if (!is.character(txt) || !length(txt) || !any(nzchar(txt))) {
    why <- res$json$choices[[1L]]$finish_reason %||% ""
    stop(paste0(what, " returned no text",
                if (nzchar(why)) sprintf(" (finish_reason: %s; try again, or another model with --model)", why)),
         call. = FALSE)
  }
  paste(txt, collapse = "\n")
}

#' Sign in to the hosted MORIE language model
#'
#' Stores a personal key for the hosted MORIE tier in
#' \code{$XDG_CONFIG_HOME/morie/credentials.json} (owner-only; the file
#' the \code{morie}, \code{rmorie} and \code{rmoriedata} packages read too,
#' so one sign-in serves all of them). The tier is a last resort behind a
#' local model or your own endpoint (see \code{\link{bricklayer_llm_ask}});
#' keys are personal and issued on request at \url{https://rmorie.com/access}.
#' The sign-in addresses come from \code{\link{bricklayer_services}}. Three ways in:
#' \itemize{
#'   \item \code{token}: a key you already have, from the website or an
#'     email. It is checked with the gateway first and stored only when
#'     the gateway accepts it; a refused key, or no answer, stores nothing.
#'   \item \code{email}: a 6-digit code is sent to the address (valid
#'     ten minutes, single use); you type it, or pass \code{code}.
#'   \item neither: the GitHub device flow; a code is shown to enter at
#'     github.com, and the key arrives once you approve.
#' }
#' Nothing is written except by this explicit call.
#'
#' @param token A key issued at \url{https://rmorie.com/access}.
#' @param email Sign in with a code sent to this address.
#' @param code The emailed code, when you already have it.
#' @param open_browser Open the GitHub page for the device flow.
#' @param poll_max_seconds How long the device flow waits for approval.
#' @return The key, invisibly.
#' @examples
#' \dontrun{
#' bricklayer_llm_login(token = "<key issued at https://rmorie.com/access>")
#' bricklayer_llm_login(email = "you@example.com")
#' bricklayer_llm_login() # GitHub device flow
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
    # ask the gateway first: a mistyped key in the shared file breaks rmorie and morie too
    .bl_check_token(token)
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
#' @return A data frame with one row per route, in the order
#'   \code{\link{bricklayer_llm_ask}} tries them (own endpoint, local Ollama,
#'   hosted MORIE tier): \code{route}, \code{status} and \code{detail}.
#'   Printed by \code{rmoriebricklayer doctor}.
#' @examples
#' bricklayer_llm_status()
#' @export
bricklayer_llm_status <- function() {
  own <- .bl_own_base()
  own_row <- if (is.null(own)) {
    c("own endpoint", "not set",
      "MORIE_LLM_BASE_URL (+ MORIE_LLM_API_KEY, MORIE_LLM_MODEL): any OpenAI-compatible server")
  } else {
    c("own endpoint", "configured",
      sprintf("%s  model: %s", own, .bl_env1("MORIE_LLM_MODEL") %||% "(the server's first)"))
  }
  ob <- .bl_ollama_base()
  ollama_row <- if (is.null(ob)) {
    c("local Ollama", "disabled", "OLLAMA_HOST=off")
  } else {
    tags <- .bl_ollama_tags(ob)
    if (is.null(tags)) {
      c("local Ollama", "not running",
        sprintf("%s (install Ollama and pull a model, or point OLLAMA_HOST at a server)", ob))
    } else if (!length(tags)) {
      c("local Ollama", "no models", sprintf("%s (`ollama pull NAME`)", ob))
    } else {
      c("local Ollama", "available",
        sprintf("%s  models: %s (default %s)", ob, paste(tags, collapse = ", "),
                .bl_env1("OLLAMA_MODEL") %||% tags[[1L]]))
    }
  }
  base <- .bl_hosted_base()
  key <- .bl_hosted_key()
  hosted_row <- if (is.null(base)) {
    c("hosted MORIE tier", "disabled", .bl_hosted_off_reason())
  } else if (is.null(key)) {
    c("hosted MORIE tier", "not logged in", sprintf("%s  (%s)", base, .bl_access_hint()))
  } else {
    hm <- bricklayer_llm_models()
    c("hosted MORIE tier", "key stored", switch(.bl_key_state(hm),
      ok = sprintf("%s  models: %s (default %s)", base, paste(hm, collapse = ", "), attr(hm, "default")),
      rejected = sprintf("%s  (key rejected by the gateway -- run `%s login` again, or `%s login --token KEY`)",
                         base, .bl_prog(), .bl_prog()),
      sprintf("%s  (gateway not reachable)", base)
    ))
  }
  m <- rbind(own_row, ollama_row, hosted_row)
  data.frame(route = unname(m[, 1L]), status = unname(m[, 2L]), detail = unname(m[, 3L]),
             stringsAsFactors = FALSE)
}
