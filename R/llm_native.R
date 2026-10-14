# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Language models, bring your own key: an OpenAI-compatible endpoint of your own
# (MORIE_LLM_BASE_URL), each provider whose key is set (R/llm_providers.R), and a
# local Ollama server (OLLAMA_HOST, default http://localhost:11434). The hosted MORIE
# language-model tier is retired. The MORIE key that remains is the data key for
# data.rmorie.com: personal, issued on request at https://www.rmorie.com/access or
# by the GitHub / emailed-code sign-in, stored in a credentials file the other MORIE
# packages read as well; its sign-in addresses come from the signed services
# document (bricklayer_services()). Every request goes through the package's own
# libcurl binding.

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
  out <- .bl_credentials_object(p)
  if (is.null(out)) {
    # the file is shared with morie and rmorie: a file that does not parse is said, not read as
    # "no key" and then written over by the next login (which deleted the other entries)
    stop(sprintf("%s is not a JSON object; fix or remove it (it is shared with morie and rmorie)", p),
         call. = FALSE)
  }
  out
}

# The credentials file as a named list, or NULL when it is not a JSON object.
.bl_credentials_object <- function(p, simplify = TRUE) {
  txt <- .bl_read_text(p)
  if (!startsWith(trimws(txt), "{")) return(NULL)  # an array or a scalar is not the credentials object
  out <- tryCatch(bricklayer_json_from_json(txt, simplifyVector = simplify, bigint_as_char = TRUE),
                  error = function(e) NULL)
  if (!is.list(out)) return(NULL)
  out
}

# The file as written: no vector simplification, so another package's arrays, nulls and large
# integers come back out as they went in (the file is shared with morie and rmorie).
.bl_credentials_raw <- function() {
  p <- .bl_credentials_path()
  if (!file.exists(p)) return(list())
  out <- .bl_credentials_object(p, simplify = FALSE)
  if (is.null(out)) {
    stop(sprintf("%s is not a JSON object; fix or remove it (it is shared with morie and rmorie)", p),
         call. = FALSE)
  }
  out
}

.bl_write_credentials <- function(data) .bl_write_private_json(.bl_credentials_path(), data)

# The file as text, bytes kept (the file is shared with morie and rmorie, whose numbers,
# arrays and non-ASCII text must come back out exactly as they went in).
# The credentials file as UTF-8 text, refused with a plain reason when it is not: readChar()
# stopped at a NUL byte and dropped what followed it, a Latin-1 file failed in the JSON parser
# with a message about bytes, and a 10 MB file took minutes in the member scanner (review of
# 02a38be, B5). A credentials file is a few hundred bytes; past 1 MB it is not one.
.bl_read_text <- function(p) {
  n <- file.size(p)
  if (is.na(n)) stop(sprintf("cannot read %s", p), call. = FALSE)
  if (n > 1048576) stop(sprintf("%s is %s bytes: too large to be a credentials file", p, format(n, big.mark = ",")),
                        call. = FALSE)
  raw <- readBin(p, "raw", n)
  if (any(raw == as.raw(0L))) stop(sprintf("%s contains a NUL byte: it is not a JSON text file", p), call. = FALSE)
  txt <- rawToChar(raw)
  Encoding(txt) <- "UTF-8"
  if (!validUTF8(txt)) {
    stop(sprintf("%s is not UTF-8 text (it may be Latin-1): save it as UTF-8", p), call. = FALSE)
  }
  txt
}

.bl_write_private_text <- function(p, txt) {
  dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE)
  tmp <- tempfile(pattern = ".cred-", tmpdir = dirname(p), fileext = ".tmp")
  file.create(tmp)
  Sys.chmod(tmp, mode = "0600")
  writeLines(txt, tmp, useBytes = TRUE, sep = "")
  if (!isTRUE(file.rename(tmp, p))) {
    unlink(tmp)
    stop(sprintf("could not write %s", p), call. = FALSE)
  }
  invisible(p)
}

# The top-level members of a JSON object as character spans: the key's opening quote, where
# the value starts and where it ends. With them the file is edited as text, so every byte
# that is not one of this package's own members stays exactly as it was. NULL when the text
# is not a JSON object.
.bl_json_top_members <- function(txt) {
  ch <- strsplit(txt, "", fixed = TRUE)[[1L]]
  n <- length(ch)
  ws <- c(" ", "\t", "\r", "\n")
  skip_ws <- function(i) {
    while (i <= n && ch[[i]] %in% ws) i <- i + 1L
    i
  }
  scan_string <- function(i) {   # ch[i] is the opening quote; the index of the closing one
    i <- i + 1L
    while (i <= n) {
      if (ch[[i]] == "\\") i <- i + 2L else if (ch[[i]] == "\"") return(i) else i <- i + 1L
    }
    NA_integer_
  }
  scan_value <- function(i) {    # the index of the value's last character
    c0 <- ch[[i]]
    if (c0 == "\"") return(scan_string(i))
    if (c0 %in% c("{", "[")) {
      depth <- 0L
      while (i <= n) {
        if (ch[[i]] == "\"") {
          i <- scan_string(i)
          if (is.na(i)) return(NA_integer_)
        } else if (ch[[i]] %in% c("{", "[")) {
          depth <- depth + 1L
        } else if (ch[[i]] %in% c("}", "]")) {
          depth <- depth - 1L
          if (depth == 0L) return(i)
        }
        i <- i + 1L
      }
      return(NA_integer_)
    }
    while (i <= n && !ch[[i]] %in% c(",", "}", ws)) i <- i + 1L
    i - 1L
  }
  i <- skip_ws(1L)
  if (i > n || ch[[i]] != "{") return(NULL)
  out <- list()
  i <- skip_ws(i + 1L)
  while (i <= n && ch[[i]] != "}") {
    if (ch[[i]] != "\"") return(NULL)
    ks <- i
    ke <- scan_string(i)
    if (is.na(ke)) return(NULL)
    key <- if (ke > ks + 1L) paste(ch[(ks + 1L):(ke - 1L)], collapse = "") else ""
    i <- skip_ws(ke + 1L)
    if (i > n || ch[[i]] != ":") return(NULL)
    i <- skip_ws(i + 1L)
    if (i > n) return(NULL)
    vs <- i
    ve <- scan_value(i)
    if (is.na(ve) || ve < vs) return(NULL)
    out[[length(out) + 1L]] <- list(key = key, start = ks, vstart = vs, end = ve)
    i <- skip_ws(ve + 1L)
    if (i <= n && ch[[i]] == ",") i <- skip_ws(i + 1L)
  }
  if (i > n) return(NULL)
  out
}

# The whole file as the real parser reads it, before a byte is edited: the member scanner alone
# accepted bare words, missing commas, trailing garbage and duplicate keys, wrote the key into
# such a file and every later read failed (review of 52a8883, B5). A key listed twice is refused:
# morie reads the last and this package edited the first.
.bl_credentials_text_ok <- function(txt) {
  mem <- .bl_json_top_members(txt)
  if (is.null(mem)) return(FALSE)
  obj <- tryCatch(bricklayer_json_from_json(txt, simplifyVector = FALSE, bigint_as_char = TRUE),
                  error = function(e) NULL)
  if (!is.list(obj) || (length(obj) && is.null(names(obj)))) return(FALSE)
  keys <- vapply(mem, function(m) m$key, "")
  !anyDuplicated(keys) && length(obj) == length(mem)
}

# Set (value a string) or remove (value NULL) one top-level member by editing the text.
.bl_credentials_text_set <- function(txt, key, value) {
  mem <- .bl_json_top_members(txt)
  if (is.null(mem)) stop("the credentials file is not a JSON object", call. = FALSE)
  nch <- nchar(txt)
  hit <- Filter(function(m) identical(m$key, key), mem)
  lit <- if (is.null(value)) NULL else as.character(bricklayer_json_to_json(value, auto_unbox = TRUE))
  if (length(hit)) {
    m <- hit[[1L]]
    if (is.null(value)) {
      before <- substr(txt, 1L, m$start - 1L)
      after <- substr(txt, m$end + 1L, nch)
      if (grepl("^[ \t\r\n]*,", after)) {
        after <- sub("^[ \t\r\n]*,[ \t]*", "", after)      # the comma that led to the next member
      } else {
        before <- sub(",[ \t\r\n]*$", "\n", before)         # the comma that led from the previous one
      }
      return(paste0(before, after))
    }
    return(paste0(substr(txt, 1L, m$vstart - 1L), lit, substr(txt, m$end + 1L, nch)))
  }
  if (is.null(value)) return(txt)
  open <- regexpr("{", txt, fixed = TRUE)
  paste0(substr(txt, 1L, open), "\n  \"", key, "\": ", lit, if (length(mem)) "," else "", substr(txt, open + 1L, nch))
}

.bl_write_private_json <- function(p, data) {
  dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE)
  tmp <- paste0(p, ".tmp")
  # created empty and made private BEFORE the key is written, so no umask
  # ever leaves it world-readable, even briefly
  file.create(tmp)
  Sys.chmod(tmp, mode = "0600")
  writeLines(
    bricklayer_json_to_json(data, auto_unbox = TRUE, pretty = TRUE, null = "null"),
    tmp
  )
  file.rename(tmp, p)
  invisible(p)
}

.bl_store_key <- function(key, user = NULL) {
  p <- .bl_credentials_path()
  txt <- if (file.exists(p)) .bl_read_text(p) else "{}"
  if (!.bl_credentials_text_ok(txt)) {
    stop(sprintf(paste("%s is not a JSON object (or not valid JSON, or lists a key twice); fix or remove it",
                       "before a key is saved (writing into it would leave a file no package can read)"), p),
         call. = FALSE)
  }
  # the file is edited as text: this package's three members are set, every other byte stays
  new <- .bl_credentials_text_set(txt, "hosted_key", key)
  if (!is.null(user)) new <- .bl_credentials_text_set(new, "hosted_user", user)
  new <- .bl_credentials_text_set(new, "hosted_base_url", .bl_hosted_base())
  back <- if (.bl_credentials_text_ok(new)) {
    bricklayer_json_from_json(new, simplifyVector = FALSE, bigint_as_char = TRUE)
  } else {
    NULL
  }
  if (!identical(back$hosted_key, key)) {
    stop(sprintf("could not store the key in %s without damaging it; the file was left as it was", p), call. = FALSE)
  }
  .bl_write_private_text(p, new)
}

.bl_hosted_key <- function() {
  st <- .bl_hosted_key_state()
  if (identical(st$state, "other_address")) {
    # said once per session and pair of addresses: route resolution asks more than once, and the
    # same line came twice (review of 02a38be, L3)
    said <- paste(st$saved_for, st$now)
    if (!isTRUE(.bl_said_once[[said]])) {
      assign(said, TRUE, envir = .bl_said_once)
      message(sprintf("the stored data key was issued for %s and is not sent to %s", st$saved_for, st$now))
    }
    return(NULL)
  }
  st$key
}
.bl_said_once <- new.env(parent = emptyenv())

# The stored hosted key and whether it may be sent: state "none", "ok" or "other_address" (a key
# saved for another address than the one in use), with no message.
.bl_hosted_key_state <- function() {
  env <- trimws(Sys.getenv("MORIE_HOSTED_KEY", unset = ""))
  if (nzchar(env)) {
    return(list(state = "ok", key = env))
  }
  cred <- .bl_read_credentials()
  key <- cred$hosted_key
  if (!is.character(key) || length(key) != 1L || !nzchar(key)) return(list(state = "none", key = NULL))
  # the key was issued for the address it was saved with: an address set afterwards in the
  # environment or the config gets no key, the same rule as the own and Ollama keys
  saved_for <- cred$hosted_base_url
  if (!is.character(saved_for) || length(saved_for) != 1L || !nzchar(saved_for)) {
    # a file without the address (morie writes one): the key goes to the signed services
    # document's address and nowhere else (the data service, now that no model is hosted)
    saved_for <- .rmbl_services_llm()$base_url %||% ""
    if (!nzchar(saved_for)) saved_for <- .rmbl_services_data()$base_url %||% ""
  }
  now <- tryCatch(.bl_hosted_base(), error = function(e) NULL)
  if (nzchar(saved_for) && !is.null(now) && !identical(sub("/+$", "", saved_for), sub("/+$", "", now))) {
    return(list(state = "other_address", key = NULL, saved_for = saved_for, now = now))
  }
  list(state = "ok", key = key)
}

# The hosted endpoint, or NULL when disabled. MORIE_HOSTED_BASE_URL overrides
# ("" on POSIX or "off" on any platform disables; Windows drops a variable set
# to ""); otherwise the signed services document decides, and a document
# with the tier switched off disables it here too.
.bl_hosted_base <- function() {
  saved <- .bl_config_value("MORIE_HOSTED_BASE_URL")
  if (!"MORIE_HOSTED_BASE_URL" %in% names(Sys.getenv()) && is.null(saved)) {
    svc <- .rmbl_services_llm()
    if (!identical(svc$mode, "key") || !nzchar(svc$base_url %||% "")) return(NULL)
    return(svc$base_url)
  }
  v <- sub("/+$", "", trimws(Sys.getenv("MORIE_HOSTED_BASE_URL", unset = saved %||% "")))
  if (!nzchar(v) || tolower(v) %in% c("off", "none", "disabled")) return(NULL)
  # the bearer key is sent to this endpoint: https and a public address
  .rmbl_check_public_url(v, "MORIE_HOSTED_BASE_URL")
}

# The sign-in service that issues the data key: the services document's data.auth_url, else the
# auth_url of its llm block (documents signed before the data service issued its own keys).
.bl_hosted_auth <- function() {
  v <- sub("/+$", "", trimws(Sys.getenv("MORIE_HOSTED_AUTH_URL", unset = "")))
  if (nzchar(v)) return(.rmbl_check_public_url(v, "MORIE_HOSTED_AUTH_URL"))  # a code and a key go there
  for (a in c(.rmbl_services_data()$auth_url, .rmbl_services_llm()$auth_url)) if (nzchar(a %||% "")) return(a)
  paste0(.rmbl_services_data()$base_url %||% "https://data.rmorie.com", "/auth")
}



# How to get a key, in one line.
.bl_access_hint <- function() {
  sprintf(paste("request a key at %s, then `%s login --token` and paste it when asked",
                "(R: bricklayer_llm_login(token = )); `%s login` signs in with GitHub or an emailed code"),
          .rmbl_services_llm()$request_access %||% "https://www.rmorie.com/access", .bl_prog(), .bl_prog())
}

# The GET seam for public https addresses (a provider model list, the data key check).
.bl_http_get <- function(url, timeout, headers) {
  .rmbl_check_public_url(url, "url")
  .Call(C_rmbl_http_get, url, as.integer(timeout), headers, FALSE)
}

# ---- your own endpoint and a local Ollama server ------------------------------
#
# An endpoint of your own and a local Ollama server are addresses from your own
# environment, not from a document, so the anti-SSRF policy that guards every
# other URL is relaxed for them in one precise way: plain http to the loopback
# host or to a LITERAL private LAN address (10/8, 172.16/12, 192.168/16,
# fc00::/7: an LM Studio or vLLM box on your own network, diff review D4) is
# admitted, as an argument of that one call (never an option: a global switch
# relaxed every fetch in the process, fourth review), only when the address IS
# such a literal, and a redirect off it meets the usual rules. Link-local
# (169.254/16, the metadata range) and every name stay under the full policy.
.bl_loopback_url <- function(url) {
  host <- paste0("(localhost|127\\.[0-9.]+|10\\.[0-9.]+|192\\.168\\.[0-9.]+|",
                 "172\\.(1[6-9]|2[0-9]|3[01])\\.[0-9.]+|\\[::1\\]|\\[::ffff:127\\.[0-9.]+\\]|",
                 "\\[f[cd][0-9a-f]{2}:[0-9a-f:.]*\\])")
  grepl(paste0("^https?://", host, "(:[0-9]+)?(/|$)"), url, ignore.case = TRUE)
}

.bl_own_base <- function() {
  v <- sub("/+$", "", .bl_env1("MORIE_LLM_BASE_URL") %||% "")
  if (!nzchar(v) || tolower(v) %in% c("off", "none", "disabled")) return(NULL)
  if (!grepl("^https?://[^/[:space:]]+", v)) {
    stop("MORIE_LLM_BASE_URL must be an http(s):// URL (an OpenAI-compatible server)", call. = FALSE)
  }
  v <- sub("/v1$", "", v)  # the base, with or without the /v1 most servers document
  # your own server: a loopback or private-LAN literal over plain http, or a public https address
  if (!.bl_loopback_url(v)) .rmbl_check_public_url(v, "MORIE_LLM_BASE_URL")
  v
}
# An environment variable, else the value saved under it by bricklayer_llm_config().
.bl_env1 <- function(name) {
  v <- trimws(Sys.getenv(name, unset = ""))
  if (nzchar(v)) v else .bl_config_value(name)
}

.bl_ollama_base <- function() {
  # the environment wins over the saved setting, whichever of the two names it uses
  env <- function(n) {
    v <- trimws(Sys.getenv(n, unset = ""))
    if (nzchar(v)) v else NULL
  }
  v <- env("OLLAMA_HOST") %||% env("OLLAMA_BASE_URL") %||% .bl_config_value("OLLAMA_HOST") %||%
    .bl_config_value("OLLAMA_BASE_URL") %||% "http://localhost:11434"
  if (tolower(v) %in% c("off", "none", "disabled")) return(NULL)
  if (!grepl("^https?://", v)) v <- paste0("http://", v)  # OLLAMA_HOST is often host:port
  sub("/+$", "", v)
}

# Ollama was pointed at on purpose (environment or saved setting), not the default address.
# Own-endpoint settings without an address: a model or key alone cannot be a route, and saying
# so is what keeps "a prompt never leaves the machine silently" true for this case too.
.bl_own_configured <- function() {
  !is.null(.bl_env1("MORIE_LLM_MODEL")) || !is.null(.bl_env1("MORIE_LLM_API_KEY"))
}

.bl_ollama_configured <- function() {
  !is.null(.bl_env1("OLLAMA_HOST")) || !is.null(.bl_env1("OLLAMA_BASE_URL")) ||
    !is.null(.bl_env1("OLLAMA_MODEL")) || !is.null(.bl_env1("OLLAMA_API_KEY"))
}

.bl_bearer <- function(key) if (is.null(key)) NULL else paste("Authorization: Bearer", key)

# GET for the local routes: the loopback relaxation passed for a loopback
# address, the usual checks for anything else. One seam, so tests can stand
# in a server.
.bl_http_get_local <- function(url, timeout, headers) {
  .Call(C_rmbl_http_get, url, as.integer(timeout), headers, .bl_loopback_url(url))
}
# POST for the local routes, the same way.
.bl_http_post_local <- function(url, body, content_type, timeout, headers) {
  .Call(C_rmbl_http_post, url, body, content_type, as.integer(timeout), headers, .bl_loopback_url(url))
}

# The models a local Ollama server has (GET /api/tags): a character vector, or NULL when nothing
# answers there. Attributes: `remote`, the models Ollama serves from its cloud (a remote_host:
# minimax-m3:cloud, gpt-oss:120b-cloud), and `context`, the context length each one reports.
.bl_ollama_tags <- function(base, timeout = 2) {
  key <- .bl_key_for("OLLAMA_API_KEY", "OLLAMA_HOST")
  res <- tryCatch(.bl_http_get_local(paste0(base, "/api/tags"), timeout, .bl_bearer(key)),
                  error = function(e) NULL)
  if (is.null(res) || !identical(as.integer(res$status), 200L)) return(NULL)
  parsed <- tryCatch(.rmbl_json_text(res$body, simplifyVector = FALSE),
                     error = function(e) NULL)
  ms <- parsed$models %||% list()
  nm <- vapply(ms, function(m) as.character(m$name %||% m$model %||% "")[1L], "")
  remote <- vapply(ms, function(m) nzchar(as.character(m$remote_host %||% "")[1L]), logical(1))
  ctx <- vapply(ms, function(m) {
    v <- suppressWarnings(as.numeric(m$details$context_length %||% m$context_length %||% NA)[1L])
    if (is.finite(v)) v else NA_real_
  }, 0)
  keep <- nzchar(nm)
  structure(nm[keep], remote = nm[keep & remote], context = stats::setNames(ctx[keep], nm[keep]))
}

# The routes a question can take, in the automatic order: an endpoint of your own when one is
# configured, then every provider whose key is set (in the order of .bl_llm_presets()), then a
# local Ollama server when it answers with a model. Bring your own key: the hosted MORIE tier
# is retired, and no prompt goes anywhere you did not set up.
.bl_llm_route_names <- function() c("own", .bl_llm_presets()$id, "ollama")

.bl_hosted_retired <- function() {
  sprintf(paste("the hosted MORIE language-model tier is retired: bring your own key (a provider's",
                "variable such as ANTHROPIC_API_KEY or OPENAI_API_KEY, or `%s config set <provider>.key`)",
                "or run a model locally (Ollama); `%s config setup` walks through it"), .bl_prog(), .bl_prog())
}

# The route a question takes: list(name, api, base, key, model, local, ...), or NULL when nothing
# is set up. `route` forces one: "own", "ollama" or a provider id ("anthropic", "openai", ...).
.bl_llm_route <- function(route = NULL, probe_timeout = 2) {
  if (identical(route, "auto")) {
    route <- NULL
  } else if (is.null(route)) {
    saved <- tolower(.bl_env1("MORIE_LLM_ROUTE") %||% "auto")
    if (identical(saved, "hosted")) {
      # a route saved before the hosted tier was retired: said once, then the automatic order
      if (!isTRUE(.bl_said_once[["hosted-retired"]])) {
        assign("hosted-retired", TRUE, envir = .bl_said_once)
        message(paste0(.bl_hosted_retired(), "; the saved route `hosted` is ignored"))
      }
      saved <- "auto"
    }
    if (!saved %in% c("auto", .bl_llm_route_names())) {
      stop(sprintf("MORIE_LLM_ROUTE (or the saved route) must be auto, own, ollama or a provider (%s), not '%s'",
                   paste(.bl_llm_presets()$id, collapse = ", "), saved), call. = FALSE)
    }
    if (!identical(saved, "auto")) route <- saved
  }
  if (identical(route, "hosted")) stop(.bl_hosted_retired(), call. = FALSE)
  presets <- .bl_llm_presets()$id
  skipped <- character()
  for (r in route %||% .bl_llm_route_names()) {
    hit <- if (identical(r, "own")) {
      base <- .bl_own_base()
      if (!is.null(base)) {
        list(name = "own endpoint", api = "openai", base = base,
             key = .bl_key_for("MORIE_LLM_API_KEY", "MORIE_LLM_BASE_URL"),
             model = .bl_env1("MORIE_LLM_MODEL"), local = .bl_loopback_url(base))
      } else {
        if (.bl_own_configured()) {
          skipped <- c(skipped, "own endpoint: a model or key is set but no address (MORIE_LLM_BASE_URL or own.url)")
        }
        NULL
      }
    } else if (identical(r, "ollama")) {
      base <- .bl_ollama_base()
      tags <- if (!is.null(base)) .bl_ollama_tags(base, probe_timeout)
      usable <- length(tags) > 0L || !is.null(.bl_env1("OLLAMA_MODEL")) || identical(route, "ollama")
      if (!is.null(tags) && !usable) skipped <- c(skipped, sprintf("local Ollama at %s has no model pulled", base))
      if (!is.null(base) && is.null(tags) && .bl_ollama_configured()) {
        skipped <- c(skipped, sprintf("local Ollama at %s is not answering", base))
      }
      if (!is.null(tags) && usable) {
        list(name = "local Ollama", api = "openai", base = base, key = .bl_key_for("OLLAMA_API_KEY", "OLLAMA_HOST"),
             model = .bl_env1("OLLAMA_MODEL") %||% (if (length(tags)) tags[[1L]]),
             local = .bl_loopback_url(base), models = as.character(tags), remote = attr(tags, "remote"),
             context = attr(tags, "context"))
      }
    } else if (r %in% presets) {
      rt <- .bl_provider_route(r)
      if (is.null(rt) && identical(route, r)) {
        pr <- .bl_preset(r)
        stop(sprintf("no key for %s: set %s, or `%s config set %s.key` (it asks for the key)", pr$label,
                     pr$key_env, .bl_prog(), r), call. = FALSE)
      }
      rt
    } else {
      stop(sprintf("unknown route '%s' (own, ollama or a provider: %s)", r, paste(presets, collapse = ", ")),
           call. = FALSE)
    }
    if (!is.null(hit)) {
      if (length(skipped)) message(sprintf("%s; using %s", paste(skipped, collapse = "; "), .bl_route_what(hit)))
      return(hit)
    }
  }
  NULL
}

# A saved key belongs to the address it was saved with: a one-off address in the environment
# (MORIE_LLM_BASE_URL=..., OLLAMA_HOST=...) gets the environment's key or none, never the key
# saved for another server.
.bl_key_for <- function(key_env, url_env) {
  env_key <- trimws(Sys.getenv(key_env, unset = ""))
  if (nzchar(env_key)) return(env_key)
  env_url <- trimws(Sys.getenv(url_env, unset = ""))
  if (identical(url_env, "OLLAMA_HOST") && !nzchar(env_url)) {
    env_url <- trimws(Sys.getenv("OLLAMA_BASE_URL", unset = ""))
  }
  saved_url <- .bl_config_value(url_env)
  if (nzchar(env_url) && !identical(sub("/+$", "", env_url), sub("/+$", "", saved_url %||% ""))) return(NULL)
  .bl_config_value(key_env)
}

# What to set up, when no route (or the one asked for) answers.
.bl_no_route_message <- function(route = NULL) {
  prog <- .bl_prog()
  ollama <- .bl_ollama_base()
  ollama_line <- if (is.null(ollama)) {
    "local Ollama: OLLAMA_HOST=off"
  } else if (is.null(.bl_ollama_tags(ollama))) {
    sprintf(paste("local Ollama: nothing answers at %s (install Ollama from https://ollama.com and pull a model,",
                  "or `%s config set ollama.url ADDRESS`)"), ollama, prog)
  } else {
    sprintf("local Ollama: no model pulled at %s (`ollama pull NAME`)", ollama)
  }
  ps <- .bl_llm_presets()
  key_line <- sprintf(paste("a provider's key: set its variable (%s, ...) or `%s config set PROVIDER.key`;",
                            "providers: %s"), paste(utils::head(ps$key_env, 4L), collapse = ", "), prog,
                      paste(ps$id, collapse = ", "))
  own_line <- sprintf(paste("own endpoint: `%s config set own.url URL` (and own.model, own.key) for any",
                            "OpenAI-compatible server (LM Studio, vLLM, llama.cpp, a company gateway)"), prog)
  lines <- switch(route %||% "any", own = own_line, ollama = ollama_line, c(key_line, ollama_line, own_line))
  paste(c("No language-model route is set up on this machine: bring your own key, or run a model locally:",
          paste0("  ", lines), sprintf("`%s config setup` walks through it.", prog)), collapse = "\n")
}

# What to do when a route has no model to use.
.bl_no_model_message <- function(rt) {
  prog <- .bl_prog()
  have <- tryCatch(.bl_llm_list_models(rt), error = function(e) NULL)
  shown <- if (length(have)) sprintf(" (it offers: %s%s)", paste(utils::head(have, 8L), collapse = ", "),
                                     if (length(have) > 8L) sprintf(", ... %d in all: `%s models`", length(have), prog)
                                     else "") else ""
  how <- if (identical(rt$name, "own endpoint")) {
    sprintf("`%s config set own.model NAME`", prog)
  } else if (identical(rt$name, "local Ollama")) {
    sprintf("pull one (`ollama pull NAME`) or `%s config set ollama.model NAME`", prog)
  } else {
    sprintf("`%s config set %s.model NAME`, or --model NAME for one call", prog, rt$id)
  }
  sprintf("%s has no model to use%s: %s", .bl_route_what(rt), shown, how)
}

#' The language-model route that would answer
#'
#' Which route \code{\link{bricklayer_llm_ask}} would take now, without sending
#' anything: your own endpoint, a provider whose key is set, or Ollama, in that
#' order (or the one \code{route} names).
#'
#' @param route \code{NULL} (the saved setting, else the automatic order),
#'   \code{"auto"}, \code{"own"}, \code{"ollama"} or a provider id from
#'   \code{\link{bricklayer_llm_providers}}.
#' @return \code{NULL} when no route is set up, else a list with \code{route}
#'   (the id \code{route =} takes), \code{name}, \code{model} (\code{NULL} when
#'   none is chosen) and \code{base} (the address requests go to).
#' @examples
#' old <- Sys.getenv("OLLAMA_HOST", unset = NA)
#' Sys.setenv(OLLAMA_HOST = "off")
#' str(bricklayer_llm_route_info("ollama"))
#' if (is.na(old)) Sys.unsetenv("OLLAMA_HOST") else Sys.setenv(OLLAMA_HOST = old)
#' @export
bricklayer_llm_route_info <- function(route = NULL) {
  if (identical(route, "hosted")) stop(.bl_hosted_retired(), call. = FALSE)
  if (!is.null(route)) route <- match.arg(route, c("auto", .bl_llm_route_names()))
  rt <- .bl_llm_route(route)
  if (is.null(rt)) return(NULL)
  list(route = .bl_route_id(rt), name = rt$name, model = rt$model, base = rt$base)
}

#' A conversation with a language model
#'
#' Sends a whole conversation (system, user and assistant turns) to the route
#' \code{\link{bricklayer_llm_ask}} would take, and returns the reply. Unlike
#' \code{bricklayer_llm_ask()} it adds nothing to the conversation: no help
#' pages, no tools.
#'
#' @param messages A list of turns, each \code{list(role = , content = )} with
#'   role \code{"system"}, \code{"user"} or \code{"assistant"}.
#' @inheritParams bricklayer_llm_ask
#' @return The reply text.
#' @examples
#' \dontrun{
#' bricklayer_llm_chat(list(list(role = "user", content = "Name one survey weight type.")))
#' }
#' @export
bricklayer_llm_chat <- function(messages, model = NULL, route = NULL, timeout = 120) {
  ok <- is.list(messages) && length(messages) && all(vapply(messages, function(m) {
    is.list(m) && is.character(m$role) && length(m$role) == 1L && m$role %in% c("system", "user", "assistant") &&
      is.character(m$content) && length(m$content) == 1L && !is.na(m$content)
  }, logical(1)))
  if (!ok) stop("`messages` must be a list of list(role = \"system\"|\"user\"|\"assistant\", content = text)",
                call. = FALSE)
  if (identical(route, "hosted")) stop(.bl_hosted_retired(), call. = FALSE)
  if (!is.null(route)) route <- match.arg(route, c("auto", .bl_llm_route_names()))
  timeout <- .rmbl_num(timeout, "timeout")
  rt <- .bl_llm_route(route)
  if (is.null(rt)) stop(.bl_no_route_message(route), call. = FALSE)
  model <- model %||% rt$model
  if (is.null(model) || !nzchar(model)) stop(.bl_no_model_message(rt), call. = FALSE)
  .bl_llm_chat(rt, model, lapply(messages, function(m) list(role = m$role, content = m$content)),
               timeout = timeout)$text
}

#' Models a language-model route offers
#'
#' Asks the provider (or your own server, or Ollama) which models your key
#' can use, through the package's own libcurl binding.
#'
#' @param route \code{NULL} (the route \code{\link{bricklayer_llm_ask}}
#'   would take) or a route name: \code{"own"}, \code{"ollama"} or a
#'   provider id (see \code{\link{bricklayer_llm_providers}}).
#' @param timeout Seconds to wait for the answer.
#' @return A character vector of model names, empty when no route is set up
#'   or the provider does not list its models, with attributes
#'   \code{"default"} (the model \code{bricklayer_llm_ask()} uses when none
#'   is named) and \code{"route"}.
#' @examples
#' \donttest{
#' m <- bricklayer_llm_models()
#' attr(m, "default")
#' }
#' @export
bricklayer_llm_models <- function(route = NULL, timeout = 15) {
  timeout <- .rmbl_num(timeout, "timeout")
  rt <- .bl_llm_route(route)
  if (is.null(rt)) return(structure(character(), default = NULL, route = NULL))
  ids <- .bl_llm_list_models(rt, timeout) %||% character()
  structure(ids, default = rt$model, route = rt$name)
}

#' The language-model providers a key can be brought for
#'
#' Every provider \code{\link{bricklayer_llm_ask}} can reach with your own
#' key, with the environment variable that holds it, the address it is sent
#' to and the wire format used. Nothing is contacted.
#'
#' @return A data frame: \code{id} (the route name), \code{label},
#'   \code{key_env} (and \code{alt_env}), \code{base}, \code{api}
#'   (\code{"openai"}, \code{"anthropic"} or \code{"gemini"}),
#'   \code{default_model} and \code{key_set} (whether a key is set here).
#' @examples
#' bricklayer_llm_providers()[, c("id", "key_env", "key_set")]
#' @export
bricklayer_llm_providers <- function() {
  ps <- .bl_llm_presets()
  ps$key_set <- vapply(ps$id, function(i) !is.null(.bl_preset_key(i)), logical(1), USE.NAMES = FALSE)
  ps$models <- NULL
  ps
}

# Ask the data service whether it knows a key: GET /v1/whoami, or /manifest.json from a service
# that predates /v1/whoami (it answers 404 there). The reply, or NULL when nothing answered.
.bl_key_reply <- function(base, key, timeout = 10) {
  get <- function(p) {
    tryCatch(.bl_http_get(paste0(base, p), timeout, paste("Authorization: Bearer", key)), error = function(e) NULL)
  }
  res <- get("/v1/whoami")
  if (identical(as.integer(res$status), 404L)) res <- get("/manifest.json")
  res
}

# `login --token KEY`: ask the data service before the key replaces a working one in the shared
# file (stored as is, a mistyped key left all three packages reporting "key rejected").
.bl_check_token <- function(token) {
  base <- tryCatch(.bl_data_url(), error = function(e) NULL)
  if (is.null(base)) return(invisible(TRUE))
  res <- .bl_key_reply(base, token)
  if (is.null(res)) {
    stop(sprintf("could not reach %s to check the key; nothing stored (try again)", base), call. = FALSE)
  }
  if (!identical(as.integer(res$status), 200L)) {
    stop(sprintf("the data service did not accept that key (HTTP %d); nothing stored (%s)",
                 as.integer(res$status), .bl_access_hint()), call. = FALSE)
  }
  invisible(TRUE)
}


# One seam for the HTTP layer so tests can stand in canned replies.
.bl_http_post <- function(url, body, content_type, timeout, headers) {
  .Call(
    C_rmbl_http_post, url, body, content_type, as.integer(timeout),
    headers, FALSE
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
    .bl_http_post_local(url, raw, "application/json", timeout, headers)
  } else {
    .bl_http_post(url, raw, "application/json", timeout, headers)
  }
  if (is.null(res)) {
    return(list(status = -1L, json = NULL, error = ""))
  }
  json <- NULL
  if (length(res$body)) {
    json <- tryCatch(
      .rmbl_json_text(res$body,
        simplifyVector = FALSE
      ),
      error = function(e) NULL
    )
  }
  list(status = as.integer(res$status), json = json, error = res$error %||% "")
}

.bl_reply_error <- function(res, what, secret = NULL) {
  if (!isTRUE(res$status > 0L)) {
    # libcurl gives -1 when no HTTP answer came at all; its own reason says which way it failed
    why <- if (nzchar(res$error %||% "")) res$error else "no network, or a proxy refused the connection"
    stop(sprintf("could not reach %s (%s)", what, why), call. = FALSE)
  }
  if (!is.null(secret) && isTRUE(res$status %in% c(401L, 403L))) {
    stop(sprintf("%s rejected your key (HTTP %d): check it (`%s config` shows which key is used, never its value)",
                 what, res$status, .bl_prog()), call. = FALSE)
  }
  msg <- res$json$error
  if (is.list(msg)) msg <- msg$message
  detail <- ""
  if (is.character(msg) && length(msg) == 1L) {
    detail <- paste0(": ", .bl_redact(msg, secret))
  }
  stop(sprintf("%s answered %d%s", what, res$status, detail), call. = FALSE)
}

# The sign-in service names the page to open; only a public https address is
# handed to the OS browser (the service could otherwise name any scheme).
.bl_browsable <- function(uri) {
  is.character(uri) && length(uri) == 1L && grepl("^https://", uri) &&
    !inherits(tryCatch(.rmbl_check_public_url(uri, "verification_uri"), error = function(e) e), "error")
}

# A server's error text can quote the key it was sent, in any phrasing. The key
# itself is redacted by value, the usual spellings of a bearer or an sk- key by
# shape, and the two LiteLLM phrasings seen in the wild are cut as before.
.bl_redact <- function(msg, secret = NULL) {
  msg <- sub("(?i)[.,;]?\\s*(received api key|key hash).*$", "", msg, perl = TRUE)
  for (sec in secret) if (is.character(sec) && nzchar(sec)) msg <- gsub(sec, "<key>", msg, fixed = TRUE)
  msg <- gsub("(?i)bearer\\s+[A-Za-z0-9._~+/=-]{8,}", "Bearer <key>", msg, perl = TRUE)
  gsub("\\bsk-[A-Za-z0-9._-]{6,}", "<key>", msg, perl = TRUE)
}

# The command name the user typed (the launchers set RMBL_PROG; rmbl and rmoriebricklayer are one command).
.bl_prog <- function() {
  p <- Sys.getenv("RMBL_PROG", "")
  if (nzchar(p)) p else "rmoriebricklayer"
}

#' Ask a language model
#'
#' Sends one prompt to the first language model that is set up on this
#' machine and returns the reply. Bring your own key, or run a model
#' locally: nothing is sent anywhere you did not set up. In order:
#' \enumerate{
#'   \item an OpenAI-compatible endpoint of your own: \code{MORIE_LLM_BASE_URL}
#'     (with \code{MORIE_LLM_API_KEY} and \code{MORIE_LLM_MODEL} when it needs
#'     them), e.g. LM Studio, vLLM, llama.cpp or a company gateway. An
#'     \code{https} address, or plain \code{http} to the loopback host or to a
#'     literal private LAN address (\code{10/8}, \code{172.16/12},
#'     \code{192.168/16}, \code{fc00::/7}: an LM Studio or vLLM box on your own
#'     network); a host name over plain http is refused. It is not probed, so a
#'     configured endpoint that is down is an error, not a silent hop elsewhere;
#'   \item a provider whose key is set (see
#'     \code{\link{bricklayer_llm_providers}}): OpenAI, Anthropic, Google
#'     Gemini, OpenRouter, Groq, Together, Fireworks, DeepSeek, Mistral, xAI,
#'     Cerebras, Perplexity, Hugging Face, OpenCode Zen, Cohere and NVIDIA,
#'     each through its own documented API with its own key variable
#'     (\code{ANTHROPIC_API_KEY}, \code{OPENAI_API_KEY}, ...);
#'   \item a local Ollama server: \code{OLLAMA_HOST} (default
#'     \code{http://localhost:11434}), model \code{OLLAMA_MODEL} or the first
#'     one pulled; \code{OLLAMA_HOST=off} skips it.
#' }
#' \code{\link{bricklayer_llm_status}} shows what is set up and which route
#' a question would take.
#'
#' With \code{docs = TRUE} (the default) the model knows the packages: its
#' instructions carry an index of every exported function of
#' rmoriebricklayer and rmoriedata (name, arguments, title, read from the
#' help pages installed here), and it may call five read-only tools to
#' search the help, read a page or its examples, list the datasets and read
#' a vignette before it answers. A model that cannot call tools gets the
#' help pages that best match the question (a BM25 search in R) instead.
#' Nothing the model asks for is run: it answers with code for you to run.
#
#' @param prompt Character scalar.
#' @param model Model id; default the route's own (see above).
#' @param timeout Seconds to wait for the reply.
#' @param system_prompt Optional system message.
#' @param route \code{NULL} (the saved route, else the first that is set up),
#'   \code{"auto"} (the automatic order this time, ignoring a saved route),
#'   or \code{"own"}, \code{"ollama"} or a provider id to insist on one.
#' @param docs Give the model the packages' help (see Details);
#'   \code{FALSE} sends the prompt alone.
#' @param packages The installed packages whose help the model gets; default
#'   rmoriebricklayer and rmoriedata (those installed). Add \code{"rmorie"}
#'   to let it search that package's help too.
#' @return Character scalar with the reply. Errors, saying what to set up,
#'   when no route answers, and when the server answers with an error.
#' @examples
#' \dontrun{
#' Sys.setenv(ANTHROPIC_API_KEY = "...")   # your own key
#' bricklayer_llm_ask("What does a SHA-256 provenance record protect against?")
#' bricklayer_llm_ask("Explain an E-value of 2.1", route = "ollama")
#' }
#' @export
bricklayer_llm_ask <- function(prompt, model = NULL, timeout = 120,
                               system_prompt = NULL, route = NULL, docs = TRUE, packages = NULL) {
  prompt <- .rmbl_string1(prompt, "prompt")
  if (identical(route, "hosted")) stop(.bl_hosted_retired(), call. = FALSE)
  if (!is.null(route)) route <- match.arg(route, c("auto", .bl_llm_route_names()))
  rt <- .bl_llm_route(route)
  if (is.null(rt)) stop(.bl_no_route_message(route), call. = FALSE)
  model <- model %||% rt$model
  if (is.null(model) || !nzchar(model)) stop(.bl_no_model_message(rt), call. = FALSE)
  .bl_check_flag(docs, "docs")
  if (docs) {
    pk <- packages %||% .bl_kn_default_packages()
    if (!is.character(pk) || !length(pk) || anyNA(pk)) stop("`packages` must name installed packages", call. = FALSE)
    missing <- pk[!vapply(pk, function(x) nzchar(system.file(package = x)), logical(1))]
    if (length(missing)) stop(sprintf("not installed: %s", paste(missing, collapse = ", ")), call. = FALSE)
    return(.bl_llm_assist(rt, model, prompt, pk, system_extra = system_prompt, timeout = timeout))
  }
  msgs <- list()
  if (!is.null(system_prompt)) msgs[[1L]] <- list(role = "system", content = system_prompt)
  msgs[[length(msgs) + 1L]] <- list(role = "user", content = prompt)
  .bl_llm_chat(rt, model, msgs, timeout = timeout)$text
}

#' Sign in for the curated tables at data.rmorie.com
#'
#' Stores your personal MORIE data key in
#' \code{$XDG_CONFIG_HOME/morie/credentials.json} (owner-only; the file
#' the \code{morie}, \code{rmorie} and \code{rmoriedata} packages read too,
#' so one sign-in serves all of them). The key opens the curated tables
#' (\code{\link{bricklayer_data_load}}); it is not used for language models,
#' which run on your own key or a local model (\code{\link{bricklayer_llm_ask}}).
#' Keys are personal and issued on request at \url{https://www.rmorie.com/access/}.
#' The sign-in addresses come from \code{\link{bricklayer_services}}. Three ways in:
#' \itemize{
#'   \item \code{token}: a key you already have, from the website or an
#'     email. It is checked with the service first and stored only when
#'     it is accepted; a refused key, or no answer, stores nothing.
#'   \item \code{email}: a 6-digit code is sent to the address (valid
#'     ten minutes, single use); you type it, or pass \code{code}.
#'   \item neither: the GitHub device flow; a code is shown to enter at
#'     github.com, and the key arrives once you approve.
#' }
#' Nothing is written except by this explicit call.
#'
#' @param token A key issued at \url{https://www.rmorie.com/access/}.
#' @param email Sign in with a code sent to this address.
#' @param code The emailed code, when you already have it.
#' @param open_browser Open the GitHub page for the device flow.
#' @param poll_max_seconds How long the device flow waits for approval.
#' @return The key, invisibly.
#' @examples
#' \dontrun{
#' bricklayer_llm_login(token = "<key issued at https://www.rmorie.com/access/>")
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
  if (isTRUE(open_browser) && .bl_browsable(info$verification_uri)) {
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

#' Forget the MORIE data key
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
  p <- .bl_credentials_path()
  had <- FALSE
  if (file.exists(p)) {
    txt <- .bl_read_text(p)
    if (!.bl_credentials_text_ok(txt)) {
      stop(sprintf(paste("%s is not a JSON object (or not valid JSON, or lists a key twice); fix or remove it",
                         "(it is shared with morie and rmorie)"), p), call. = FALSE)
    }
    mem <- .bl_json_top_members(txt)
    had <- any(vapply(mem, function(m) identical(m$key, "hosted_key"), logical(1)))
    for (k in c("hosted_key", "hosted_user", "hosted_base_url")) txt <- .bl_credentials_text_set(txt, k, NULL)
    left <- .bl_json_top_members(txt)
    if (!.bl_credentials_text_ok(txt) || "hosted_key" %in% vapply(left, function(m) m$key, "")) {
      stop(sprintf("could not remove the key from %s without damaging it; the file was left as it was", p),
           call. = FALSE)
    }
    if (length(left)) .bl_write_private_text(p, txt) else unlink(p)
  }
  message(if (had) {
    "Logged out: the MORIE data key was removed."
  } else {
    "No MORIE data key was stored."
  })
  invisible(had)
}

#' Report the language-model routes available from this machine
#'
#' @return A data frame with one row per route, in the order
#'   \code{\link{bricklayer_llm_ask}} tries them (own endpoint, each provider
#'   whose key is set, local Ollama; the providers without a key share one
#'   row): \code{route}, \code{status} and \code{detail}. Nothing is sent to a
#'   provider; a local Ollama server is asked for its model list. Printed by
#'   \code{rmoriebricklayer doctor}.
#' @examples
#' # with the local route off the call reaches no network
#' old <- Sys.getenv("OLLAMA_HOST", unset = NA)
#' Sys.setenv(OLLAMA_HOST = "off")
#' bricklayer_llm_status()
#' if (is.na(old)) Sys.unsetenv("OLLAMA_HOST") else Sys.setenv(OLLAMA_HOST = old)
#' @export
bricklayer_llm_status <- function() {
  # a settings file the package cannot read is reported as a row, so `doctor` still answers
  cfg_err <- tryCatch({
    .bl_read_config()
    NULL
  }, error = function(e) conditionMessage(e))
  if (!is.null(cfg_err)) {
    return(data.frame(route = "settings", status = "unreadable",
                      detail = sprintf("%s; `%s config reset` moves the file aside", cfg_err, .bl_prog()),
                      stringsAsFactors = FALSE))
  }
  own <- .bl_own_base()
  rows <- list(if (is.null(own)) {
    c("own endpoint", "not set",
      "MORIE_LLM_BASE_URL (+ MORIE_LLM_API_KEY, MORIE_LLM_MODEL): any OpenAI-compatible server")
  } else {
    c("own endpoint", "configured", sprintf("%s  model: %s", own, .bl_env1("MORIE_LLM_MODEL") %||% "(not chosen)"))
  })
  ps <- .bl_llm_presets()
  without <- character()
  for (i in seq_len(nrow(ps))) {
    rt <- .bl_provider_route(ps$id[i])
    if (is.null(rt)) {
      without <- c(without, sprintf("%s (%s)", ps$id[i], ps$key_env[i]))
    } else {
      rows[[length(rows) + 1L]] <- c(ps$label[i], "key set",
        sprintf("%s  model: %s", ps$base[i], rt$model %||% sprintf("(not chosen: `%s models --route %s`)",
                                                                    .bl_prog(), ps$id[i])))
    }
  }
  if (length(without)) {
    rows[[length(rows) + 1L]] <- c("other providers", "no key", paste(without, collapse = ", "))
  }
  ob <- .bl_ollama_base()
  rows[[length(rows) + 1L]] <- if (is.null(ob)) {
    c("local Ollama", "disabled", "OLLAMA_HOST=off")
  } else {
    tags <- .bl_ollama_tags(ob)
    if (is.null(tags)) {
      c("local Ollama", "not running",
        sprintf("%s (install Ollama and pull a model, or point OLLAMA_HOST at a server)", ob))
    } else if (!length(tags)) {
      c("local Ollama", "no models", sprintf("%s (`ollama pull NAME`)", ob))
    } else {
      c("local Ollama", "available", sprintf("%s  models: %s (default %s)", ob, paste(tags, collapse = ", "),
                                             .bl_env1("OLLAMA_MODEL") %||% tags[[1L]]))
    }
  }
  m <- do.call(rbind, rows)
  data.frame(route = unname(m[, 1L]), status = unname(m[, 2L]), detail = unname(m[, 3L]), stringsAsFactors = FALSE)
}
