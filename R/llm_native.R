# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Language models, bring your own key: an OpenAI-compatible endpoint of your own
# (MORIE_LLM_BASE_URL), each provider whose key is set (R/llm_providers.R), and a
# local Ollama server (OLLAMA_HOST, default http://localhost:11434). The hosted MORIE
# language-model tier is retired. The MORIE key that remains is the data key for
# data.rmorie.com: personal, issued by the GitHub / emailed-code sign-in at
# data.rmorie.com/auth or on request at https://www.rmorie.com/access, stored
# in a credentials file the other MORIE packages read as well; its sign-in addresses come from the signed services
# document (svcs()). Every request goes through the package's own
# libcurl binding.

#' Returns the path of the shared credentials file.
#'
#' $XDG_CONFIG_HOME/morie/credentials.json, the file the morie (Python)
#' and rmorie (R) packages read and write too, so one sign-in serves all.
#' Reading it is always allowed; it is only ever written by an
#' explicit sign-in (dlogin()), never by examples or tests,
#' which point XDG_CONFIG_HOME at a temporary directory.
#' @return One path.
#' @noRd
.bl_credentials_path <- function() {
  base <- trimws(Sys.getenv("XDG_CONFIG_HOME", unset = ""))
  if (!nzchar(base)) base <- file.path(path.expand("~"), ".config")
  file.path(base, "morie", "credentials.json")
}

#' Reads the shared credentials file, refusing one that is not a JSON object.
#' @return A named list, empty when the file does not exist.
#' @noRd
.bl_read_credentials <- function() {
  p <- .bl_credentials_path()
  if (!file.exists(p)) {
    return(list())
  }
  out <- .bl_credentials_object(p)
  if (is.null(out)) {
    # the file is shared with morie and rmorie: a file that does not parse is said, not read as
    # "no key" and then written over by the next login (which deleted the other entries)
    stop(.rmbl_fn(), sprintf("%s is not a JSON object; fix or remove it (it is shared with morie and rmorie)", p),
         call. = FALSE)
  }
  out
}

#' The credentials file as a named list, or NULL when it is not a JSON object.
#' @param p The path of the credentials file.
#' @param simplify Whether the JSON parser simplifies vectors.
#' @return A named list, or NULL.
#' @noRd
.bl_credentials_object <- function(p, simplify = TRUE) {
  txt <- .bl_read_text(p)
  if (!startsWith(trimws(txt), "{")) return(NULL)  # an array or a scalar is not the credentials object
  out <- tryCatch(fromjs(txt, simplifyVector = simplify, bigint_as_char = TRUE),
                  error = function(e) NULL)
  if (!is.list(out)) return(NULL)
  out
}

#' Reads the credentials file without simplifying its values.
#'
#' The file as written: no vector simplification, so another package's arrays, nulls and large
#' integers come back out as they went in (the file is shared with morie and rmorie).
#' @return A named list, empty when the file does not exist.
#' @noRd
.bl_credentials_raw <- function() {
  p <- .bl_credentials_path()
  if (!file.exists(p)) return(list())
  out <- .bl_credentials_object(p, simplify = FALSE)
  if (is.null(out)) {
    stop(.rmbl_fn(), sprintf("%s is not a JSON object; fix or remove it (it is shared with morie and rmorie)", p),
         call. = FALSE)
  }
  out
}

#' Writes the credentials file as private JSON.
#' @param data The named list to write.
#' @return The path, invisibly.
#' @noRd
.bl_write_credentials <- function(data) .bl_write_private_json(.bl_credentials_path(), data)

#' Reads the credentials file as UTF-8 text.
#'
#' The file as text, bytes kept (the file is shared with morie and rmorie, whose numbers,
#' arrays and non-ASCII text must come back out exactly as they went in).
#' The credentials file as UTF-8 text, refused with a plain reason when it is not: readChar()
#' stopped at a NUL byte and dropped what followed it, a Latin-1 file failed in the JSON parser
#' with a message about bytes, and a 10 MB file took minutes in the member scanner (review of
#' 02a38be, B5). A credentials file is a few hundred bytes; past 1 MB it is not one.
#' @param p The path of the credentials file.
#' @return One string.
#' @noRd
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

#' Writes text to a file through an owner-only temporary file and a rename.
#' @param p The path to write.
#' @param txt The text.
#' @return The path, invisibly.
#' @noRd
.bl_write_private_text <- function(p, txt) {
  # the directory as private as its files: under umask 000 it came out 0777 (review of 46de6a9)
  .bl_private_dir(dirname(p))
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

#' Finds the top-level members of a JSON object as character spans.
#'
#' The top-level members of a JSON object as character spans: the key's opening quote, where
#' the value starts and where it ends. With them the file is edited as text, so every byte
#' that is not one of this package's own members stays exactly as it was. NULL when the text
#' is not a JSON object.
#' @param txt The JSON text.
#' @return A list with, per member, its `key`, `start`, `vstart` and `end`; NULL when the text is not a JSON object.
#' @noRd
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

#' Checks that the credentials text parses and names no key twice.
#'
#' The whole file as the real parser reads it, before a byte is edited: the member scanner alone
#' accepted bare words, missing commas, trailing garbage and duplicate keys, wrote the key into
#' such a file and every later read failed (review of 52a8883, B5). A key listed twice is refused:
#' morie reads the last and this package edited the first.
#' @param txt The JSON text.
#' @return `TRUE` or `FALSE`.
#' @noRd
.bl_credentials_text_ok <- function(txt) {
  mem <- .bl_json_top_members(txt)
  if (is.null(mem)) return(FALSE)
  obj <- tryCatch(fromjs(txt, simplifyVector = FALSE, bigint_as_char = TRUE),
                  error = function(e) NULL)
  if (!is.list(obj) || (length(obj) && is.null(names(obj)))) return(FALSE)
  keys <- vapply(mem, function(m) m$key, "")
  !anyDuplicated(keys) && length(obj) == length(mem)
}

#' Set (value a string) or remove (value NULL) one top-level member by editing the text.
#' @param txt The JSON text.
#' @param key The member name.
#' @param value A string, or NULL to remove the member.
#' @return The edited text.
#' @noRd
.bl_credentials_text_set <- function(txt, key, value) {
  mem <- .bl_json_top_members(txt)
  if (is.null(mem)) stop("the credentials file is not a JSON object", call. = FALSE)
  nch <- nchar(txt)
  hit <- Filter(function(m) identical(m$key, key), mem)
  lit <- if (is.null(value)) NULL else as.character(tojs(value, auto_unbox = TRUE))
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


#' Creates a folder owner-only, or makes an existing one owner-only.
#'
#' A folder for keys, settings or saved answers: created owner-only, and made owner-only when it is
#' already there (mode = "0700" applies only to a folder dir.create() makes, so one an earlier version
#' left at 0777 under umask 000 stayed open; network stress test of 5e1dce5). Windows has no modes.
#' @param d The folder.
#' @return `d`, invisibly.
#' @noRd
.bl_private_dir <- function(d) {
  if (!dir.exists(d)) dir.create(d, recursive = TRUE, showWarnings = FALSE, mode = "0700")
  if (.Platform$OS.type == "unix" && dir.exists(d)) Sys.chmod(d, "0700", use_umask = FALSE)
  invisible(d)
}

#' Writes a list as pretty JSON to an owner-only file.
#' @param p The path to write.
#' @param data The list to write.
#' @return The path, invisibly.
#' @noRd
.bl_write_private_json <- function(p, data) {
  # through the one private writer: a fresh temporary name each time (a planted llm.json.tmp
  # symlink had its target overwritten with the keys; review of 29a55d8, L5), created empty and
  # made 0600 before a byte is written
  .bl_write_private_text(p, paste0(tojs(data, auto_unbox = TRUE, pretty = TRUE, null = "null"),
                                   "\n"))
  invisible(p)
}

#' Stores the data key, its user and its address in the credentials file, keeping every other byte.
#' @param key The data key.
#' @param user The user name the sign-in service gave, or NULL.
#' @return The path, invisibly.
#' @noRd
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
  new <- .bl_credentials_text_set(new, "hosted_base_url", .bl_key_address())
  back <- if (.bl_credentials_text_ok(new)) {
    fromjs(new, simplifyVector = FALSE, bigint_as_char = TRUE)
  } else {
    NULL
  }
  if (!identical(back$hosted_key, key)) {
    stop(sprintf("could not store the key in %s without damaging it; the file was left as it was", p), call. = FALSE)
  }
  .bl_write_private_text(p, new)
}

#' Returns the stored data key when it may be sent to the address in use.
#' @return The key, or NULL (with a message, once, when it was saved for another address).
#' @noRd
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

#' The stored hosted key and whether it may be sent: state "none", "ok" or "other_address" (a key
#' saved for another address than the one in use), with no message.
#' @return A list with `state` and `key`, and for `"other_address"` the `saved_for` and `now` addresses.
#' @noRd
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
  # the comparison runs whatever the services document says: with the model tier off it is the
  # data address (a key saved for another server went to data.rmorie.com when `now` was NULL;
  # review of 29a55d8, G2)
  now <- tryCatch(.bl_key_address(), error = function(e) NULL)
  # credentials written before 0.5.12 name the retired model tier's address: the same issuer and
  # key store as the data service, so such a key still goes to the signed document's data address,
  # and to no other (those users signed in again otherwise; review of 46de6a9, G2 note)
  data_base <- sub("/+$", "", .rmbl_services_data()$base_url %||% "")
  if (sub("/+$", "", saved_for) %in% .bl_legacy_key_addresses && nzchar(data_base) &&
        identical(sub("/+$", "", now %||% ""), data_base)) {
    saved_for <- data_base
  }
  if (nzchar(saved_for) && !identical(sub("/+$", "", saved_for), sub("/+$", "", now %||% ""))) {
    return(list(state = "other_address", key = NULL, saved_for = saved_for, now = now %||% ""))
  }
  list(state = "ok", key = key)
}

# Where pre-0.5.12 logins recorded the key: the retired language-model tier's gateway.
.bl_legacy_key_addresses <- "https://llm.rmorie.com"

#' The address a stored key belongs to: the model tier's while the services document has one, else
#' the data service's (the signed document's, never MORIE_DATA_URL). "" when neither is known.
#' @return One address without a trailing slash, or `""`.
#' @noRd
.bl_key_address <- function() {
  a <- tryCatch(.bl_hosted_base(), error = function(e) NULL)
  if (is.null(a)) a <- .rmbl_services_data()$base_url %||% ""
  sub("/+$", "", a)
}

#' Returns the address of the retired language-model tier, if any.
#'
#' The address a stored key was issued for under the retired language-model tier, or NULL (the
#' signed services document now switches that tier off, and a key is bound to the data address).
#' MORIE_HOSTED_BASE_URL overrides ("" on POSIX or "off" on any platform disables; Windows drops a
#' variable set to "").
#' @return One address, or NULL.
#' @noRd
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

#' Returns the address of the sign-in service.
#'
#' The sign-in service that issues the data key: the services document's data.auth_url, else the
#' auth_url of its llm block (documents signed before the data service issued its own keys).
#' @return One address.
#' @noRd
.bl_hosted_auth <- function() {
  v <- sub("/+$", "", trimws(Sys.getenv("MORIE_HOSTED_AUTH_URL", unset = "")))
  if (nzchar(v)) return(.rmbl_check_public_url(v, "MORIE_HOSTED_AUTH_URL"))  # a code and a key go there
  for (a in c(.rmbl_services_data()$auth_url, .rmbl_services_llm()$auth_url)) if (nzchar(a %||% "")) return(a)
  paste0(.rmbl_services_data()$base_url %||% "https://data.rmorie.com", "/auth")
}



#' How to get a key, in one line.
#' @return One string.
#' @noRd
.bl_access_hint <- function() {
  sprintf(paste("`%s login` signs in with GitHub or an emailed code; a key you were given:",
                "`%s login --token` and paste it when asked (R: dlogin(token = )); or ask at %s"),
          .bl_prog(), .bl_prog(), .rmbl_services_data()$request_access %||% "https://www.rmorie.com/access")
}

#' The GET seam for public https addresses (a provider model list, the data key check).
#' @param url The address.
#' @param timeout The timeout in seconds.
#' @param headers Request headers, or NULL.
#' @return The response list from the native GET.
#' @noRd
.bl_http_get <- function(url, timeout, headers) {
  .rmbl_check_public_url(url, "url")
  .bl_net(url, .Call(C_rmbl_http_get, url, as.integer(timeout), headers, FALSE))
}

# ---- your own endpoint and a local Ollama server ------------------------------
#
#' Tells whether an address is a loopback or literal private-LAN address.
#'
#' An endpoint of your own and a local Ollama server are addresses from your own
#' environment, not from a document, so the anti-SSRF policy that guards every
#' other URL is relaxed for them in one precise way: plain http to the loopback
#' host or to a LITERAL private LAN address (10/8, 172.16/12, 192.168/16,
#' fc00::/7: an LM Studio or vLLM box on your own network, diff review D4) is
#' admitted, as an argument of that one call (never an option: a global switch
#' relaxed every fetch in the process, fourth review), only when the address IS
#' such a literal, and a redirect off it meets the usual rules. Link-local
#' (169.254/16, the metadata range) and every name stay under the full policy.
#' @param url The address.
#' @return `TRUE` or `FALSE`.
#' @noRd
.bl_loopback_url <- function(url) {
  host <- paste0("(localhost|127\\.[0-9.]+|10\\.[0-9.]+|192\\.168\\.[0-9.]+|",
                 "172\\.(1[6-9]|2[0-9]|3[01])\\.[0-9.]+|\\[::1\\]|\\[::ffff:127\\.[0-9.]+\\]|",
                 "\\[f[cd][0-9a-f]{2}:[0-9a-f:.]*\\])")
  grepl(paste0("^https?://", host, "(:[0-9]+)?(/|$)"), url, ignore.case = TRUE)
}

#' Returns the base address of your own OpenAI-compatible endpoint, if set.
#' @return One address without `/v1`, or NULL.
#' @noRd
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
#' An environment variable, else the value saved under it by llmcfg().
#' @param name The variable name.
#' @return The value, or NULL when neither is set.
#' @noRd
.bl_env1 <- function(name) {
  v <- trimws(Sys.getenv(name, unset = ""))
  if (nzchar(v)) v else .bl_config_value(name)
}

#' Returns the address of the Ollama server, from the environment, the saved setting or the default.
#' @return One address, or NULL when Ollama is switched off.
#' @noRd
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

#' Tells whether own-endpoint settings are present.
#'
#' Own-endpoint settings without an address: a model or key alone cannot be a route, and saying
#' so is what keeps "a prompt never leaves the machine silently" true for this case too.
#' @return `TRUE` or `FALSE`.
#' @noRd
.bl_own_configured <- function() {
  !is.null(.bl_env1("MORIE_LLM_MODEL")) || !is.null(.bl_env1("MORIE_LLM_API_KEY"))
}

#' Ollama was pointed at on purpose (environment or saved setting), not the default address.
#' @return `TRUE` or `FALSE`.
#' @noRd
.bl_ollama_configured <- function() {
  !is.null(.bl_env1("OLLAMA_HOST")) || !is.null(.bl_env1("OLLAMA_BASE_URL")) ||
    !is.null(.bl_env1("OLLAMA_MODEL")) || !is.null(.bl_env1("OLLAMA_API_KEY"))
}

#' Builds an Authorization header for a key.
#' @param key The key, or NULL.
#' @return One header string, or NULL.
#' @noRd
.bl_bearer <- function(key) if (is.null(key)) NULL else paste("Authorization: Bearer", key)

#' Sends a GET for a local route.
#'
#' GET for the local routes: the loopback relaxation passed for a loopback
#' address, the usual checks for anything else. One seam, so tests can stand
#' in a server.
#' @param url The address.
#' @param timeout The timeout in seconds.
#' @param headers Request headers, or NULL.
#' @return The response list from the native GET.
#' @noRd
.bl_http_get_local <- function(url, timeout, headers) {
  .bl_net(url, .Call(C_rmbl_http_get, url, as.integer(timeout), headers, .bl_loopback_url(url)))
}
#' POST for the local routes, the same way.
#' @param url The address.
#' @param body The request body as raw bytes.
#' @param content_type The body's media type.
#' @param timeout The timeout in seconds.
#' @param headers Request headers, or NULL.
#' @return The response list from the native POST.
#' @noRd
.bl_http_post_local <- function(url, body, content_type, timeout, headers) {
  .Call(C_rmbl_http_post, url, body, content_type, as.integer(timeout), headers, .bl_loopback_url(url))
}

#' Lists the models a local Ollama server has.
#'
#' The models a local Ollama server has (GET /api/tags): a character vector, or NULL when nothing
#' answers there. Attributes: `remote`, the models Ollama serves from its cloud (a remote_host:
#' minimax-m3:cloud, gpt-oss:120b-cloud), and `context`, the context length each one reports.
#' @param base The Ollama address.
#' @param timeout The timeout in seconds.
#' @return A character vector with attributes `remote` and `context`, or NULL.
#' @noRd
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
  nm <- .rmbl_printable(nm)   # a server's names reach the terminal (`models --route ollama`)
  keep <- nzchar(nm)
  structure(nm[keep], remote = nm[keep & remote], context = stats::setNames(ctx[keep], nm[keep]))
}

#' Lists the routes a question can take, in the automatic order.
#'
#' The routes a question can take, in the automatic order: an endpoint of your own when one is
#' configured, then every provider whose key is set (in the order of .bl_llm_presets()), then a
#' local Ollama server when it answers with a model. Bring your own key: the hosted MORIE tier
#' is retired, and no prompt goes anywhere you did not set up.
#' @return A character vector of route names.
#' @noRd
.bl_llm_route_names <- function() c("own", .bl_llm_presets()$id, "ollama")

#' Says that the hosted language-model tier is retired and what to do instead.
#' @return One string.
#' @noRd
.bl_hosted_retired <- function() {
  sprintf(paste("the hosted MORIE language-model tier is retired: bring your own key (a provider's",
                "variable such as ANTHROPIC_API_KEY or OPENAI_API_KEY, or `%s config set <provider>.key`)",
                "or run a model locally (Ollama); `%s config setup` walks through it"), .bl_prog(), .bl_prog())
}

#' Finds the route a question takes.
#'
#' The route a question takes: list(name, api, base, key, model, local, ...), or NULL when nothing
#' is set up. `route` forces one: "own", "ollama" or a provider id ("anthropic", "openai", ...).
#' @param route NULL or `"auto"` for the automatic order, else one route name.
#' @param probe_timeout The timeout in seconds for asking a local server for its models.
#' @return A route list, or NULL.
#' @noRd
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

#' Returns the key for an address setting.
#'
#' A saved key belongs to the address it was saved with: a one-off address in the environment
#' (MORIE_LLM_BASE_URL=..., OLLAMA_HOST=...) gets the environment's key or none, never the key
#' saved for another server.
#' @param key_env The name of the key variable.
#' @param url_env The name of the address variable.
#' @return The key, or NULL.
#' @noRd
.bl_key_for <- function(key_env, url_env) {
  env_key <- trimws(Sys.getenv(key_env, unset = ""))
  if (nzchar(env_key)) return(.bl_key_text(env_key, key_env))
  env_url <- trimws(Sys.getenv(url_env, unset = ""))
  if (identical(url_env, "OLLAMA_HOST") && !nzchar(env_url)) {
    env_url <- trimws(Sys.getenv("OLLAMA_BASE_URL", unset = ""))
  }
  saved_url <- .bl_config_value(url_env)
  if (nzchar(env_url) && !identical(sub("/+$", "", env_url), sub("/+$", "", saved_url %||% ""))) return(NULL)
  .bl_key_text(.bl_config_value(key_env), key_env)
}

#' What to set up, when no route (or the one asked for) answers.
#' @param route The route asked for, or NULL for any.
#' @return One string, several lines.
#' @noRd
.bl_no_route_message <- function(route = NULL) {
  prog <- .bl_prog()
  ollama <- .bl_ollama_base()
  ollama_line <- if (is.null(ollama)) {
    "local Ollama: OLLAMA_HOST=off"
  } else if (is.null(.bl_ollama_tags(ollama))) {
    sprintf(paste("local Ollama: nothing answers at %s (installed? start its server with `ollama serve`,",
                  "or open the Ollama app; not installed: https://ollama.com, then `ollama pull NAME`;",
                  "on another machine: `%s config set ollama.url ADDRESS`)"), ollama, prog)
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

#' What to do when a route has no model to use.
#' @param rt The route list.
#' @return One string.
#' @noRd
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
#' Reports which route \code{\link{llmask}} and
#' \code{\link{llmchat}} would take right now, without sending a
#' prompt anywhere. Use it to check, before asking a question, that the
#' question would go to the server you expect (your own endpoint, a provider
#' whose key is set, or a local Ollama server) and which model it would use.
#'
#' @details
#' The automatic order is: an OpenAI-compatible endpoint of your own
#' (\code{MORIE_LLM_BASE_URL}, or \code{own.url} saved with
#' \code{rmoriebricklayer config set}); then every provider of
#' \code{\link{llmprvd}} whose key is set, in the order of
#' that table; then a local Ollama server, at \code{OLLAMA_HOST} or by default at
#' \code{http://localhost:11434}, when it answers with at least one pulled model
#' or \code{OLLAMA_MODEL} is set. A saved route replaces the automatic order
#' when \code{route = NULL}; it comes from \code{MORIE_LLM_ROUTE} or from the
#' \code{route} saved in the settings file.
#'
#' Nothing is sent to a provider. The only network contact is the Ollama
#' probe, a \code{GET /api/tags} to the Ollama address with a 2 second
#' timeout; \code{OLLAMA_HOST=off} skips it. Your own endpoint is not probed.
#'
#' Errors: \code{route = "hosted"} (the hosted MORIE tier is retired); a
#' \code{route} that is not one of the accepted names; a provider route
#' named explicitly with no key set; a \code{MORIE_LLM_BASE_URL} that is not
#' \code{https} to a public address or plain \code{http} to the loopback
#' host or a literal private LAN address. When automatic resolution skips a
#' route that is half set up (a model or key without an address, an Ollama
#' that does not answer) a message says so.
#'
#' @param route Character scalar or \code{NULL} (the default). \code{NULL}
#'   uses the saved route, else the automatic order; \code{"auto"} uses the
#'   automatic order and ignores a saved route; \code{"own"},
#'   \code{"ollama"} or a provider id from the \code{id} column of
#'   \code{\link{llmprvd}} (such as \code{"anthropic"})
#'   asks about that one route only.
#' @return \code{NULL} when no route is set up (or the named one is not
#'   available), else a list of four elements: \code{route} (character, the
#'   id that \code{route =} takes: \code{"own"}, \code{"ollama"} or a
#'   provider id), \code{name} (character, a readable label such as
#'   \code{"own endpoint"}, \code{"local Ollama"} or \code{"Anthropic"}),
#'   \code{model} (character, or \code{NULL} when no model is chosen) and
#'   \code{base} (character, the base address requests go to, without a
#'   trailing \code{/v1} for your own endpoint).
#' @seealso \code{\link{llmstat}} for every route at once,
#'   \code{\link{llmprvd}} for the provider ids.
#' @examples
#' # keep the examples away from your real settings and from the network
#' old <- Sys.getenv(c("XDG_CONFIG_HOME", "OLLAMA_HOST",
#'                     "MORIE_LLM_BASE_URL", "MORIE_LLM_MODEL"),
#'                   unset = NA)
#' Sys.setenv(XDG_CONFIG_HOME = tempfile(), OLLAMA_HOST = "off")
#'
#' # Ollama switched off: that route is not available
#' llmrte("ollama")
#'
#' # an OpenAI-compatible server of your own on this machine (not contacted here)
#' Sys.setenv(MORIE_LLM_BASE_URL = "http://localhost:8080/v1", MORIE_LLM_MODEL = "llama3")
#' str(llmrte())
#'
#' # the retired hosted tier, and a route name that does not exist
#' try(llmrte("hosted"))
#' try(llmrte("nope"))
#'
#' for (v in names(old)) {
#'   if (is.na(old[[v]])) Sys.unsetenv(v) else do.call(Sys.setenv, as.list(old[v]))
#' }
#' @export
llmrte <- function(route = NULL) {
  if (identical(route, "hosted")) stop(.bl_hosted_retired(), call. = FALSE)
  if (!is.null(route)) route <- .rmbl_arg(route, c("auto", .bl_llm_route_names()))
  rt <- .bl_llm_route(route)
  if (is.null(rt)) return(NULL)
  list(route = .bl_route_id(rt), name = rt$name, model = rt$model, base = rt$base)
}

#' A conversation with a language model
#'
#' Sends a whole conversation (system, user and earlier assistant turns) to
#' the route \code{\link{llmask}} would take, and returns the
#' model's next reply. Use it when you manage the conversation yourself, for
#' example to keep a multi-turn exchange or to give the model earlier answers
#' as context. Unlike \code{llmask()} it adds nothing to the
#' conversation (no help pages, no tools) and it never reads or writes the
#' saved-answer cache.
#'
#' @details
#' The route is resolved exactly as in \code{\link{llmrte}}.
#' The turns are sent in the provider's own wire format (the OpenAI chat
#' completions format for most providers, your own endpoint and Ollama;
#' Anthropic's Messages API; Google's Gemini \code{generateContent}). One
#' request is made, through the package's own libcurl binding, and waits at
#' most \code{tmout} seconds.
#'
#' Errors, before anything is sent: \code{msgs} is not a non-empty list
#' of turns each with a single \code{role} among \code{"system"},
#' \code{"user"} and \code{"assistant"} and a single non-missing character
#' \code{content}; \code{route = "hosted"} or an unknown route; no route is
#' set up (the message says what to set); the route has no model and
#' \code{model} is not given. After sending: the server cannot be reached,
#' rejects the key (HTTP 401 or 403), or answers with an error. The key is
#' redacted from any error text a server echoes back.
#'
#' @param msgs A non-empty list of turns, each a list with two
#'   character scalars: \code{role}, one of \code{"system"}, \code{"user"}
#'   or \code{"assistant"}, and \code{content}, the text of that turn. The
#'   last turn is normally a \code{"user"} turn. Other elements of a turn are
#'   dropped.
#' @inheritParams llmask
#' @return A character scalar: the text of the model's reply.
#' @seealso \code{\link{llmask}} for one question with the
#'   package help at hand.
#' @examples
#' old <- Sys.getenv(c("XDG_CONFIG_HOME", "OLLAMA_HOST"), unset = NA)
#' Sys.setenv(XDG_CONFIG_HOME = tempfile(), OLLAMA_HOST = "off")
#'
#' # a conversation is a list of role/content turns
#' turns <- list(
#'   list(role = "system", content = "Answer in one sentence."),
#'   list(role = "user", content = "Name one type of survey weight.")
#' )
#' str(turns)
#'
#' # a malformed turn is refused before anything is sent
#' try(llmchat(list("Name one type of survey weight.")))
#'
#' # with no route set up the error says what to set up
#' try(llmchat(turns, route = "ollama"))
#'
#' for (v in names(old)) {
#'   if (is.na(old[[v]])) Sys.unsetenv(v) else do.call(Sys.setenv, as.list(old[v]))
#' }
#'
#' @examplesIf interactive()
#' # needs a key or a local model, and the network
#' Sys.setenv(ANTHROPIC_API_KEY = "...")
#' llmchat(turns)
#' llmchat(c(turns, list(
#'   list(role = "assistant", content = "A design weight."),
#'   list(role = "user", content = "And a second one?")
#' )))
#' @export
llmchat <- function(msgs, model = NULL, route = NULL, tmout = 120) {
  ok <- is.list(msgs) && length(msgs) && all(vapply(msgs, function(m) {
    is.list(m) && is.character(m$role) && length(m$role) == 1L && m$role %in% c("system", "user", "assistant") &&
      is.character(m$content) && length(m$content) == 1L && !is.na(m$content)
  }, logical(1)))
  if (!ok) stop("`msgs` must be a list of list(role = \"system\"|\"user\"|\"assistant\", content = text)",
                call. = FALSE)
  if (identical(route, "hosted")) stop(.bl_hosted_retired(), call. = FALSE)
  if (!is.null(route)) route <- .rmbl_arg(route, c("auto", .bl_llm_route_names()))
  tmout <- .rmbl_num(tmout, "tmout")
  rt <- .bl_llm_route(route)
  if (is.null(rt)) stop(.bl_no_route_message(route), call. = FALSE)
  model <- model %||% rt$model
  if (is.null(model) || !nzchar(model)) stop(.bl_no_model_message(rt), call. = FALSE)
  .bl_llm_chat(rt, model, lapply(msgs, function(m) list(role = m$role, content = m$content)),
               timeout = tmout)$text
}

#' Models a language-model route offers
#'
#' Asks the provider (or your own server, or a local Ollama server) which
#' models your key can use, so you can pick one for the \code{model}
#' argument of \code{\link{llmask}} or save it with
#' \code{rmoriebricklayer config set PROVIDER.model NAME}. The request goes
#' through the package's own libcurl binding; no prompt is sent.
#'
#' @details
#' The route is resolved as in \code{\link{llmrte}}. The
#' list comes from the provider's model endpoint: \code{GET /models} in the
#' OpenAI format (own endpoint and most providers), \code{GET /v1/models}
#' for Anthropic, \code{GET /v1beta/models} for Gemini (only models that
#' support \code{generateContent} are kept), and \code{GET /api/tags} for
#' Ollama. Perplexity publishes no model list, so its route returns an empty
#' vector. A failed request, a non-200 answer or a reply that is not JSON
#' also gives an empty vector, not an error, so check
#' \code{\link{llmstat}} when the list is unexpectedly empty.
#' Names are cleaned of control characters before they are returned.
#'
#' Errors only while resolving the route: \code{"hosted"}, an unknown
#' route, a provider named with no key set, or a \code{tmout} that is not
#' a single positive number.
#'
#' @param route Character scalar or \code{NULL} (the default: the route
#'   \code{\link{llmask}} would take). Otherwise \code{"auto"},
#'   \code{"own"}, \code{"ollama"} or a provider id from
#'   \code{\link{llmprvd}}.
#' @param tmout Numeric scalar, seconds to wait for the model list;
#'   default \code{15}.
#' @return A character vector of model ids (possibly empty) with two
#'   attributes: \code{"default"}, the model \code{llmask()} uses
#'   when \code{model} is not given (character, or \code{NULL} when none is
#'   chosen), and \code{"route"}, the readable name of the route asked
#'   (such as \code{"OpenAI"} or \code{"local Ollama"}; \code{NULL} when no
#'   route is set up).
#' @examples
#' old <- Sys.getenv(c("XDG_CONFIG_HOME", "OLLAMA_HOST"), unset = NA)
#' Sys.setenv(XDG_CONFIG_HOME = tempfile(), OLLAMA_HOST = "off")
#'
#' # no route set up: an empty vector, nothing contacted
#' m <- llmmdls(route = "ollama")
#' length(m)
#' attributes(m)
#'
#' # a provider named without its key is an error
#' try(llmmdls(route = "anthropic"))
#'
#' for (v in names(old)) {
#'   if (is.na(old[[v]])) Sys.unsetenv(v) else do.call(Sys.setenv, as.list(old[v]))
#' }
#'
#' @examplesIf interactive()
#' # with a key set, the provider is asked (network)
#' m <- llmmdls(route = "openai", tmout = 10)
#' head(m)
#' attr(m, "default")
#' @export
llmmdls <- function(route = NULL, tmout = 15) {
  if (!is.null(route) && (!is.character(route) || length(route) != 1L || is.na(route))) {
    stop("`route` must be a single route name, or NULL", call. = FALSE)
  }
  tmout <- .rmbl_num(tmout, "tmout")
  rt <- .bl_llm_route(route)
  if (is.null(rt)) return(structure(character(), default = NULL, route = NULL))
  ids <- .bl_llm_list_models(rt, tmout) %||% character()
  structure(ids, default = rt$model, route = rt$name)
}

#' The language-model providers a key can be brought for
#'
#' Lists every provider \code{\link{llmask}} can reach with your
#' own key: the environment variable that holds the key, the address the key
#' and prompts are sent to, the wire format used, and whether a key is set on
#' this machine. Use it to find the variable name to set for a provider, or
#' the \code{id} to pass as \code{route}. Nothing is contacted.
#'
#' @details
#' The table is fixed in the package (the providers' documented addresses
#' and key variables). A key counts as set when the provider's variable
#' (\code{key_env}), its alternative spelling (\code{alt_env}), or a key
#' saved with \code{rmoriebricklayer config set ID.key} is non-empty; key
#' values are never returned. A key with a line break or control character
#' in it is an error. A server that speaks the OpenAI format but is not in
#' the table is used as your own endpoint (\code{MORIE_LLM_BASE_URL}).
#'
#' @return A data frame with one row per provider (16 rows) and eight
#'   columns: \code{id} (character, the value \code{route =} takes),
#'   \code{label} (character, readable name), \code{base} (character, the
#'   API base address), \code{api} (character, the wire format:
#'   \code{"openai"}, \code{"anthropic"} or \code{"gemini"}),
#'   \code{key_env} (character, the environment variable for the key),
#'   \code{alt_env} (character, an alternative variable, \code{""} when
#'   none), \code{default_model} (character, the model used when none is
#'   chosen, \code{NA} when the provider has no default) and \code{key_set}
#'   (logical, whether a key is set here).
#' @seealso \code{\link{llmstat}}, \code{\link{llmrte}}.
#' @examples
#' p <- llmprvd()
#' p[, c("id", "key_env", "key_set")]
#'
#' # the providers that use the Anthropic or Gemini wire format
#' p[p$api != "openai", c("id", "api", "base")]
#'
#' # providers with a default model
#' p[!is.na(p$default_model), c("id", "default_model")]
#' @export
llmprvd <- function() {
  ps <- .bl_llm_presets()
  ps$key_set <- vapply(ps$id, function(i) !is.null(.bl_preset_key(i)), logical(1), USE.NAMES = FALSE)
  ps$models <- NULL
  ps
}

#' Asks the data service whether it knows a key.
#'
#' Ask the data service whether it knows a key: GET /v1/whoami, or /manifest.json from a service
#' that predates /v1/whoami (it answers 404 there). The reply, or NULL when nothing answered.
#' @param base The data service address.
#' @param key The key.
#' @param timeout The timeout in seconds.
#' @return The response list, or NULL.
#' @noRd
.bl_key_reply <- function(base, key, timeout = 10) {
  get <- function(p) {
    tryCatch(.bl_http_get(paste0(base, p), timeout, paste("Authorization: Bearer", key)), error = function(e) NULL)
  }
  res <- get("/v1/whoami")
  if (identical(as.integer(res$status), 404L)) res <- get("/manifest.json")
  res
}

#' Checks a pasted key with the data service before it is stored.
#'
#' `login --token KEY`: ask the data service before the key replaces a working one in the shared
#' file (stored as is, a mistyped key left all three packages reporting "key rejected").
#' @param token The key.
#' @return `TRUE`, invisibly.
#' @noRd
.bl_check_token <- function(token) {
  # the signed document's address only: MORIE_DATA_URL is never sent a key under test (G3)
  base <- sub("/+$", "", .rmbl_services_data()$base_url %||% "")
  if (!nzchar(base) || !identical(.rmbl_services_data()$mode, "key")) return(invisible(TRUE))
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


#' One seam for the HTTP layer so tests can stand in canned replies.
#' @param url The address.
#' @param body The request body as raw bytes.
#' @param content_type The body's media type.
#' @param timeout The timeout in seconds.
#' @param headers Request headers, or NULL.
#' @return The response list from the native POST.
#' @noRd
.bl_http_post <- function(url, body, content_type, timeout, headers) {
  .Call(
    C_rmbl_http_post, url, body, content_type, as.integer(timeout),
    headers, FALSE
  )
}

#' Posts a JSON document and parses the reply.
#'
#' POST a JSON document, get back list(status, json) where json is the
#' parsed reply (NULL when the body is not JSON). `local` is the own-endpoint /
#' Ollama relaxation described above.
#' @param url The address.
#' @param payload The list to send as JSON.
#' @param timeout The timeout in seconds.
#' @param headers Request headers, or NULL.
#' @param local Whether the loopback relaxation applies.
#' @return A list with `status`, `json` and `error`.
#' @noRd
.bl_post_json <- function(url, payload, timeout = 30, headers = NULL, local = FALSE) {
  raw <- charToRaw(enc2utf8(tojs(payload,
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
    # an event stream (a server that streams though no stream was asked for, or one that reports a
    # failure as an SSE error event): the event that carries an error is the reply, so its message is
    # said, not "returned no text" (CRAN stress test of b617a3f)
    if (is.null(json)) json <- .bl_sse_error(res$body)
  }
  list(status = as.integer(res$status), json = json, error = res$error %||% "")
}

#' The first `data:` line of an event stream whose JSON holds an error, as that JSON; NULL otherwise.
#' @param body The response body, raw or text.
#' @return A list, or NULL.
#' @noRd
.bl_sse_error <- function(body) {
  txt <- tryCatch(if (is.raw(body)) rawToChar(body) else as.character(body), error = function(e) "")
  if (length(txt) != 1L || !grepl("^(event|data):", txt)) return(NULL)
  for (d in sub("^data:[[:space:]]*", "", grep("^data:", strsplit(txt, "\r?\n")[[1L]], value = TRUE))) {
    j <- tryCatch(.rmbl_json_text(d, simplifyVector = FALSE), error = function(e) NULL)
    if (is.list(j) && !is.null(j$error)) return(j)
  }
  NULL
}

#' Stops with a plain message for a failed reply.
#' @param res The reply list from `.bl_post_json()`.
#' @param what The service, as named in the message.
#' @param secret Keys to redact from the message, or NULL.
#' @noRd
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
    detail <- paste0(": ", .rmbl_printable(.bl_redact(msg, secret)))
  }
  stop(sprintf("%s answered %d%s", what, res$status, detail), call. = FALSE)
}

#' Tells whether a sign-in page may be handed to the browser.
#'
#' The sign-in service names the page to open; only a public https address is
#' handed to the OS browser (the service could otherwise name any scheme).
#' @param uri The address the sign-in service named.
#' @return `TRUE` or `FALSE`.
#' @noRd
.bl_browsable <- function(uri) {
  is.character(uri) && length(uri) == 1L && grepl("^https://", uri) &&
    !inherits(tryCatch(.rmbl_check_public_url(uri, "verification_uri"), error = function(e) e), "error")
}

#' Removes keys from a server's error text.
#'
#' A server's error text can quote the key it was sent, in any phrasing. The key
#' itself is redacted by value, the usual spellings of a bearer or an sk- key by
#' shape, and the two LiteLLM phrasings seen in the wild are cut as before.
#' @param msg The error text.
#' @param secret The keys sent, or NULL.
#' @return The redacted text.
#' @noRd
.bl_redact <- function(msg, secret = NULL) {
  msg <- sub("(?i)[.,;]?\\s*(received api key|key hash).*$", "", msg, perl = TRUE)
  for (sec in secret) if (is.character(sec) && nzchar(sec)) msg <- gsub(sec, "<key>", msg, fixed = TRUE)
  msg <- gsub("(?i)bearer\\s+[A-Za-z0-9._~+/=-]{8,}", "Bearer <key>", msg, perl = TRUE)
  gsub("\\bsk-[A-Za-z0-9._-]{6,}", "<key>", msg, perl = TRUE)
}

#' The command name the user typed (the launchers set RMBL_PROG; rmbl and rmoriebricklayer are one command).
#' @return One string.
#' @noRd
.bl_prog <- function() {
  p <- Sys.getenv("RMBL_PROG", "")
  if (nzchar(p)) p else "rmoriebricklayer"
}

#' Checks a model name and refuses one that looks like a key.
#'
#' A model name to send, or NULL. The name travels in the request body: a key given as one
#' (`--model sk-...`) went with it (CRAN stress test of 0.5.14).
#' @param model One model name, or NULL.
#' @return `model`.
#' @noRd
.bl_model_name <- function(model) {
  if (is.null(model)) return(NULL)
  if (!is.character(model) || length(model) != 1L || is.na(model)) {
    stop("`model` must be one model name", call. = FALSE)
  }
  # a model is a name (gpt-4o-mini, claude-sonnet-4-5, llama3.1:8b, mistral-large-latest): words
  # and version numbers joined by - . : /. A UUID, groups of mixed-case letters and digits joined
  # by dashes (bf3RrVH-ZUyZo5t-u075Nfn-0JumknD), a segment of 15 characters or more that mixes
  # cases and digits with no word in it, or a key of any known prefix is a key, and was sent as the
  # model (80 of 144 key shapes; final audit of 1.0.0, #7)
  segs <- strsplit(model, "[-.:/_]")[[1L]]
  mixed <- grepl("[A-Z]", segs) & grepl("[a-z]", segs) & nchar(segs) >= 5L
  keyish <- .bl_key_dense(model) ||
    grepl(paste0("^(sk-|sk_|AIza|gsk_|xai-|hf_|r8_|pplx-|fw_|csk-|ghp_|gho_|ghs_|",
                 "github_pat_|glpat-|nvapi-)[A-Za-z0-9_-]{12,}"), model) ||
    grepl("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", model) ||
    sum(mixed) >= 2L ||
    any(nchar(segs) >= 15L & grepl("[0-9]", segs) & grepl("[A-Za-z]", segs) & !grepl("^[a-z]+[0-9.]*[a-z]*$", segs)) ||
    (!grepl("[-.:/_ ]", model) && nchar(model) >= 15L && grepl("[A-Z]", model) && grepl("[a-z]", model))
  if (keyish) {
    stop(paste("`model` looks like a key, so it is not sent: a model is a name such as gpt-4o-mini;",
               "a key is saved with llmcfg()"), call. = FALSE)
  }
  model
}

#' Ask a language model
#'
#' Sends one prompt to the first language model that is set up on this
#' machine and returns the reply. Bring your own key, or run a model
#' locally: nothing is sent anywhere you did not set up. In order:
#' \enumerate{
#'   \item your own OpenAI-compatible endpoint, \code{MORIE_LLM_BASE_URL}
#'     (with \code{MORIE_LLM_API_KEY} and \code{MORIE_LLM_MODEL} when it needs
#'     them), e.g. LM Studio, vLLM, llama.cpp or a company gateway. An
#'     \code{https} address, or plain \code{http} to the loopback host or to a
#'     literal private LAN address (\code{10/8}, \code{172.16/12},
#'     \code{192.168/16}, \code{fc00::/7}: an LM Studio or vLLM box on your own
#'     network); a host name over plain http is refused. It is not probed, so a
#'     configured endpoint that is down is an error, not a silent hop elsewhere;
#'   \item a provider whose key is set (see
#'     \code{\link{llmprvd}}): OpenAI, Anthropic, Google
#'     Gemini, OpenRouter, Groq, Together, Fireworks, DeepSeek, Mistral, xAI,
#'     Cerebras, Perplexity, Hugging Face, OpenCode Zen, Cohere and NVIDIA,
#'     each through its own documented API with its own key variable
#'     (\code{ANTHROPIC_API_KEY}, \code{OPENAI_API_KEY}, ...);
#'   \item a local Ollama server at \code{OLLAMA_HOST}, by default
#'     \code{http://localhost:11434}, with the model \code{OLLAMA_MODEL} or the
#'     first one pulled; \code{OLLAMA_HOST=off} skips it.
#' }
#' \code{\link{llmstat}} shows what is set up and which route
#' a question would take.
#'
#' @details
#' With \code{docs = TRUE} (the default) the model is given the help of the
#' packages named in \code{pkgs} (read from the help pages installed
#' here) and may call five read-only tools before it answers:
#' \code{search_docs}, \code{get_help}, \code{get_examples},
#' \code{list_datasets} and \code{get_vignette}. How much help goes into the
#' instructions depends on the model's context size: a model with at least
#' 32,000 tokens gets an index of every exported function (name, arguments,
#' title) and up to six rounds of lookups; 8,000 to 32,000 tokens, the 120
#' functions nearest the question and four rounds; smaller, the 40 nearest
#' and three rounds. A package with very many pages is never listed whole:
#' its functions nearest the question are listed and the tools reach the
#' rest. "Nearest" is a BM25 search over the help text in R (\eqn{k_1 =
#' 1.2}, \eqn{b = 0.75}). A model that cannot call tools gets the best
#' matching pages in the prompt instead. Nothing the model asks for is run:
#' it answers with code for you to run.
#'
#' With \code{docs = TRUE} the whole exchange is given at most three times
#' \code{tmout}; a lookup round that would start after that is not
#' started and the call errors. With \code{docs = FALSE} one request is made
#' with \code{syspro} (when given) and \code{prompt}.
#'
#' Saved answers: a person at a terminal (the command line with a terminal
#' on both stdin and stdout) or in an interactive GUI session gets a saved
#' answer back at once when the question (spacing aside; case counts),
#' route, address, model, packages and their versions, and
#' \code{syspro} all match. Answers are kept as owner-only files in the
#' folder that \code{tools::R_user_dir()} gives for \code{"rmoriebricklayer"}
#' and \code{"cache"}: for 30 days, which the option
#' \code{rmoriebricklayer.llmcachedays} changes, and at most the 200 newest,
#' which the option \code{rmoriebricklayer.llmcachemax} changes. The
#' first save in a session says where answers go. Nothing is saved from a
#' script, a pipeline, a test run, \code{R CMD check}, or with
#' \code{options(morie.quiet = TRUE)}. Saving is also turned off by
#' \code{MORIE_LLM_CACHE=off}, or by the option \code{rmoriebricklayer.llmcache}
#' set to \code{FALSE}.
#'
#' Errors: \code{prompt} is not a single non-empty string; \code{fresh} or
#' \code{docs} is not \code{TRUE} or \code{FALSE}; \code{route = "hosted"}
#' or an unknown route; no route is set up (the message lists what to set);
#' no model is chosen for the route; \code{pkgs} names a package that is
#' not installed; and, after sending, an unreachable server, a rejected key
#' (HTTP 401 or 403) or an error reply. The key is redacted from any error
#' text a server echoes back.
#'
#' @param prompt Character scalar: the question, in plain text.
#' @param model Character scalar or \code{NULL} (the default): the model id
#'   to use (a value shaped like a key is refused, never sent).
#'   \code{NULL} uses the route's own choice: \code{MORIE_LLM_MODEL}
#'   for your own endpoint, \code{OLLAMA_MODEL} or the first pulled model
#'   for Ollama, the saved \code{PROVIDER.model} or the provider's default
#'   model (see \code{\link{llmprvd}}).
#' @param tmout Numeric scalar, seconds to wait for each reply; default
#'   \code{120}. With \code{docs = TRUE} the whole exchange gets at most
#'   three times this.
#' @param syspro Character scalar or \code{NULL} (the default): extra
#'   instructions sent as the system message (added to the package's own
#'   instructions when \code{docs = TRUE}).
#' @param route Character scalar or \code{NULL} (the default: the saved
#'   route, else the first that is set up). \code{"auto"} uses the
#'   automatic order and ignores a saved route; \code{"own"},
#'   \code{"ollama"} or a provider id insists on that one.
#' @param docs Logical scalar, default \code{TRUE}: give the model the
#'   packages' help and the lookup tools (see Details). \code{FALSE} sends
#'   the prompt alone.
#' @param pkgs Character vector or \code{NULL} (the default): the
#'   installed packages whose help the model gets. \code{NULL} means
#'   \code{"rmoriebricklayer"}, or the comma-separated list in the
#'   environment variable \code{RMBL_PACKAGES} (which a package built on
#'   this one sets for its own command line). Ignored when
#'   \code{docs = FALSE}.
#' @param fresh Logical scalar, default \code{FALSE}. \code{TRUE} asks the
#'   model even when a saved answer matches (see Details), and saves the
#'   new answer in its place.
#' @return A character scalar with the reply. A saved answer carries the
#'   time it was saved as attribute \code{cached}.
#' @seealso \code{\link{llmchat}} for a conversation without the
#'   help; \code{\link{llmstat}} and
#'   \code{\link{llmrte}} to see where a question would go.
#' @examples
#' old <- Sys.getenv(c("XDG_CONFIG_HOME", "OLLAMA_HOST"), unset = NA)
#' Sys.setenv(XDG_CONFIG_HOME = tempfile(), OLLAMA_HOST = "off")
#'
#' # arguments are checked before any route is resolved
#' try(llmask(c("two", "questions")))
#'
#' # a provider named explicitly without its key
#' try(llmask("What is a capsule?", route = "anthropic"))
#'
#' # no route set up: the error lists what to set up
#' try(llmask("What is a capsule?", route = "ollama", docs = FALSE))
#'
#' for (v in names(old)) {
#'   if (is.na(old[[v]])) Sys.unsetenv(v) else do.call(Sys.setenv, as.list(old[v]))
#' }
#'
#' @examplesIf interactive()
#' # needs your own key or a local model, and the network
#' Sys.setenv(ANTHROPIC_API_KEY = "...")
#' llmask("What does a SHA-256 provenance record protect against?")
#' llmask("Explain an E-value of 2.1", route = "ollama")
#' llmask("Summarise Benford's law in two lines", docs = FALSE,
#'                    syspro = "You are terse.")
#' @export
llmask <- function(prompt, model = NULL, tmout = 120,
                               syspro = NULL, route = NULL, docs = TRUE, pkgs = NULL,
                               fresh = FALSE) {
  prompt <- .rmbl_string1(prompt, "prompt")
  .bl_check_flag(fresh, "fresh")
  model <- .bl_model_name(model)   # before a route is looked for: a key given as one is said first
  if (identical(route, "hosted")) stop(.bl_hosted_retired(), call. = FALSE)
  if (!is.null(route)) route <- .rmbl_arg(route, c("auto", .bl_llm_route_names()))
  rt <- .bl_llm_route(route)
  if (is.null(rt)) stop(.bl_no_route_message(route), call. = FALSE)
  model <- .bl_model_name(model %||% rt$model)
  if (is.null(model) || !nzchar(model)) stop(.bl_no_model_message(rt), call. = FALSE)
  .bl_check_flag(docs, "docs")
  if (docs) {
    pk <- pkgs %||% .bl_kn_default_packages()
    if (!is.character(pk) || !length(pk) || anyNA(pk)) stop("llmask: `pkgs` must name installed packages",
                                                            call. = FALSE)
    missing <- pk[!vapply(pk, function(x) nzchar(system.file(package = x)), logical(1))]
    if (length(missing)) stop(sprintf("llmask: not installed: %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
  key <- .bl_answer_key(rt, model, prompt, if (docs) pk, syspro)
  if (!fresh && !is.null(hit <- .bl_answer_get(key, prompt))) return(hit)
  ans <- if (docs) {
    .bl_llm_assist(rt, model, prompt, pk, system_extra = syspro, timeout = tmout)
  } else {
    msgs <- list()
    if (!is.null(syspro)) msgs[[1L]] <- list(role = "system", content = syspro)
    msgs[[length(msgs) + 1L]] <- list(role = "user", content = prompt)
    .bl_llm_chat(rt, model, msgs, timeout = tmout)$text
  }
  .bl_answer_put(key, prompt, model, ans)
  ans
}

#' Sign in for the curated tables at data.rmorie.com
#'
#' Stores your personal MORIE data key in
#' \code{$XDG_CONFIG_HOME/morie/credentials.json} (owner-only; the file
#' the \code{morie}, \code{rmorie} and \code{rmoriedata} packages read too,
#' so one sign-in serves all of them). The key opens the curated tables
#' (\code{\link{dload}}); it is not used for language models,
#' which run on your own key or a local model (\code{\link{llmask}}).
#' Keys are personal: the GitHub or emailed-code sign-in issues one, or ask at
#' \url{https://www.rmorie.com/access/}.
#' The sign-in addresses come from \code{\link{svcs}}. Three ways in:
#' \itemize{
#'   \item \code{token}: a key you already have, from the website or an
#'     email. It is checked with the service first and stored only when
#'     it is accepted; a refused key, or no answer, stores nothing.
#'   \item \code{email}: a one-time code is sent to the address (valid
#'     ten minutes, single use); you type it, or pass \code{code}.
#'   \item neither: the GitHub device flow; a code is shown to enter at
#'     github.com, and the key arrives once you approve.
#' }
#' Nothing is written except by this explicit call.
#'
#' @details
#' The credentials file is edited as text: only the three members this
#' package owns (\code{hosted_key}, \code{hosted_user} and
#' \code{hosted_base_url}, the address the key was issued for) are set, and
#' every other byte stays, so entries written by the other packages survive.
#' The file is written through a fresh temporary name, created owner-only
#' (mode 0600, folder 0700 on Unix) before the key is written. A file that
#' is not a JSON object, is not valid JSON or names a member twice is
#' refused rather than overwritten. \code{XDG_CONFIG_HOME} moves the file;
#' when unset it is \code{~/.config/morie/credentials.json}.
#'
#' The sign-in service address is the signed services document's
#' \code{data.auth_url} (see \code{\link{svcs}}), or the environment variable
#' \code{MORIE_HOSTED_AUTH_URL} when set (it must be a public \code{https}
#' address). The device flow polls every \code{interval} seconds the
#' service names (5 by default), prints a progress line about every 30
#' seconds, and stops with an error after \code{pollmaxsec}.
#'
#' Errors: an empty \code{token}; a \code{token} the data service does not
#' accept, or no answer from it (nothing is stored); an \code{email} that is
#' empty or not of the form \code{name@domain.tld}; no code typed at the
#' prompt; a refused code; a sign-in service that answers with an error or
#' returns no key; a credentials file that cannot be edited safely.
#'
#' @param token Character scalar or \code{NULL} (the default): a key you
#'   already have, issued at \url{https://www.rmorie.com/access/}.
#'   Surrounding spaces are removed. Takes precedence over \code{email}.
#' @param email Character scalar or \code{NULL} (the default): sign in with
#'   a one-time code sent to this address. Lower-cased before use.
#' @param code Character scalar or \code{NULL} (the default): the emailed
#'   code when you already have it; \code{NULL} sends a new code and asks
#'   for it at the console. Used only with \code{email}.
#' @param openbro Logical scalar, default \code{interactive()}: open
#'   the GitHub page for the device flow in the system browser (only a
#'   public \code{https} address is opened).
#' @param pollmaxsec Numeric scalar, default \code{600}: how many
#'   seconds the device flow waits for you to approve the sign-in.
#' @param accter Logical scalar, default \code{FALSE}: \code{TRUE}
#'   accepts the data access terms (read them at
#'   \url{https://data.rmorie.com/terms}) without the console asking. A new
#'   key is issued only once they are accepted, here or at the prompt.
#' @param name Character scalar or \code{NULL}: your name (asked for when
#'   \code{NULL}). Required for a new key.
#' @param affil Character scalar or \code{NULL}: your university,
#'   employer or organisation (optional; asked for when \code{NULL}).
#' @param purp Character scalar or \code{NULL}: why you need the data, a
#'   sentence or two (asked for when \code{NULL}). Required for a new key.
#' @param restr Logical scalar or \code{NULL}: \code{TRUE} also accepts
#'   Schedule B of the terms, which opens the restricted tables (ICPSR, NCVS
#'   38604, A2AJ case law); \code{NULL} asks at the console.
#' @param supnm,suprole,supemail Character scalars
#'   or \code{NULL}: the supervisor, department chair, director or
#'   coordinator who knows of your use, their role and their email. Required
#'   with \code{restricted = TRUE}; asked for when \code{NULL}. The role is
#'   one of \code{"supervisor"}, \code{"chair"}, \code{"director"},
#'   \code{"coordinator"} or \code{"other"}.
#' @return The key (character scalar), invisibly. A message names the file
#'   it was stored in.
#' @seealso \code{\link{dlogout}} to remove the key.
#' @examples
#' old <- Sys.getenv("XDG_CONFIG_HOME", unset = NA)
#' Sys.setenv(XDG_CONFIG_HOME = tempfile())   # never touch your real credentials
#'
#' # input checks that need no network
#' try(dlogin(token = "   "))
#' try(dlogin(email = "not-an-email"))
#'
#' if (is.na(old)) Sys.unsetenv("XDG_CONFIG_HOME") else Sys.setenv(XDG_CONFIG_HOME = old)
#'
#' @examplesIf interactive()
#' # these contact the sign-in service
#' dlogin(token = "<key issued at https://www.rmorie.com/access/>")
#' dlogin(email = "you@example.com")
#' dlogin(email = "you@example.com", code = "123456")
#' dlogin() # GitHub device flow; asks for the terms, name and reason
#' # everything given up front, for a script
#' dlogin(accter = TRUE, name = "Ada Lovelace",
#'                      purp = "Course project on court delays in Ontario.")
#' @export
dlogin <- function(token = NULL, email = NULL, code = NULL,
                                 openbro = interactive(),
                                 pollmaxsec = 600,
                                 accter = FALSE, name = NULL, affil = NULL,
                                 purp = NULL, restr = NULL,
                                 supnm = NULL, suprole = NULL,
                                 supemail = NULL) {
  if (!is.null(token)) {
    if (!is.character(token) && !is.numeric(token)) stop("`token` must be one string", call. = FALSE)
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
  if (!is.null(email)) .bl_check_email(email)
  # a new key: the terms are accepted, and who is asking and why is said, before any sign-in starts
  profile <- .bl_signin_profile(accept_terms = accter, name = name, affiliation = affil,
                                purpose = purp, restricted = restr,
                                supervisor_name = supnm, supervisor_role = suprole,
                                supervisor_email = supemail)
  if (!is.null(email)) {
    return(.bl_login_email(email, code, profile))
  }
  .bl_login_device(openbro, pollmaxsec, profile)
}

#' The email check, before anything is asked or sent.
#' @param email The address given.
#' @return The address in lower case, invisibly.
#' @noRd
.bl_check_email <- function(email) {
  email <- tolower(trimws(as.character(email)))
  if (length(email) != 1L || is.na(email) || !nzchar(email)) {
    stop(.rmbl_fn(), "an email address is required", call. = FALSE)
  }
  if (!grepl("^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$", email)) {
    stop(.rmbl_fn(), sprintf("'%s' is not an email address", email), call. = FALSE)
  }
  invisible(email)
}

#' The current version of the data access terms and where to read them, from the sign-in service.
#' @param auth The sign-in service address.
#' @return A list with the terms `version` and `url`.
#' @noRd
.bl_terms_info <- function(auth = .bl_hosted_auth()) {
  base <- sub("/auth$", "", auth)
  res <- tryCatch(.bl_http_get(paste0(base, "/terms.json"), 20L, NULL), error = function(e) NULL)
  j <- if (!is.null(res) && isTRUE(res$status == 200L)) {
    tryCatch(.rmbl_json_text(res$body, simplifyVector = FALSE), error = function(e) NULL)
  }
  v <- j$version
  if (!is.character(v) || length(v) != 1L || !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", v)) {
    stop(sprintf("could not read the data access terms from %s/terms.json; try again, or sign in at %s/",
                 base, base), call. = FALSE)
  }
  list(version = v, url = if (is.character(j$url) && length(j$url) == 1L) j$url else paste0(base, "/terms"))
}

.bl_SUPERVISOR_ROLES <- c("supervisor", "chair", "director", "coordinator", "other")

#' Collects the profile a new key needs.
#'
#' Everything a new key needs said first: the terms accepted (y/N at the console, or accter =
#' TRUE), the person's name and reason, and for Schedule B a supervisor, chair, director or
#' coordinator. Arguments win; what is missing is asked for; a missing required answer stops here,
#' before any request that could issue a key. The data service checks the same things.
#' @param accept_terms Whether the data access terms are accepted.
#' @param name The person's name, or NULL to ask.
#' @param affiliation The person's affiliation, or NULL to ask.
#' @param purpose The reason for access, or NULL to ask.
#' @param restricted Whether Schedule B tables are wanted, or NULL to ask.
#' @param supervisor_name The supervisor's name, or NULL to ask.
#' @param supervisor_role The supervisor's role, or NULL to ask.
#' @param supervisor_email The supervisor's email, or NULL to ask.
#' @return A named list sent with the sign-in request.
#' @noRd
.bl_signin_profile <- function(accept_terms = FALSE, name = NULL, affiliation = NULL, purpose = NULL,
                               restricted = NULL, supervisor_name = NULL, supervisor_role = NULL,
                               supervisor_email = NULL) {
  one <- function(x) if (is.null(x)) NULL else trimws(as.character(x)[1L])
  ask <- function(prompt, given) {
    g <- one(given)
    if (!is.null(g)) g else .bl_readline(prompt)
  }
  terms <- .bl_terms_info()
  if (!isTRUE(accept_terms)) {
    message(paste0(
      "Data access terms, version ", terms$version, " (", terms$url, "). In short:\n",
      "  - the key is for you alone; keep it private;\n",
      "  - use the tables for research, teaching, journalism, policy work or analysis;\n",
      "  - do not redistribute the tables themselves; cite each source as its licence asks;\n",
      "  - no warranty, and you cover claims that come from your misuse;\n",
      "  - a register of who holds each key is kept, and may be disclosed where the law requires."))
    a <- tolower(.bl_readline(sprintf("Do you accept the data access terms, version %s? [y/N]: ", terms$version)))
    if (!a %in% c("y", "yes")) {
      stop(sprintf(paste("the data access terms were not accepted, so no key was issued; read them at %s",
                         "and accept with `%s login --accept-terms` (R: accept_terms = TRUE)"),
                   terms$url, .bl_prog()), call. = FALSE)
    }
  }
  need <- function(what, flag, arg) {
    stop(sprintf("%s is needed for a key: pass %s (R: %s = ) or answer the prompt", what, flag, arg), call. = FALSE)
  }
  nm <- ask("Your name: ", name)
  if (nchar(nm) < 2L) need("your name", "--name", "name")
  af <- ask("Your university, employer or organisation (Enter to skip): ", affiliation)
  pu <- ask("Why you need the data (a sentence or two): ", purpose)
  if (nchar(pu) < 20L) need("the reason you need the data, a sentence or two,", "--reason", "purpose")
  rs <- if (is.null(restricted)) {
    tolower(.bl_readline(paste("Also open the restricted tables (ICPSR, NCVS 38604, A2AJ case law)",
                               "under Schedule B? [y/N]: "))) %in% c("y", "yes")
  } else {
    isTRUE(restricted)
  }
  out <- list(accept_terms = terms$version, name = nm, affiliation = if (nzchar(af)) af else NULL,
              purpose = pu, accept_restricted = rs,
              client = paste0("rmoriebricklayer/", utils::packageVersion("rmoriebricklayer")))
  if (rs) {
    sn <- ask("Your supervisor's, department chair's, director's or coordinator's name: ", supervisor_name)
    if (!nzchar(sn)) {
      need("for the restricted tables, a supervisor's, chair's, director's or coordinator's name",
           "--supervisor-name", "supervisor_name")
    }
    sr <- tolower(ask(sprintf("Their role (%s): ", paste(.bl_SUPERVISOR_ROLES, collapse = ", ")), supervisor_role))
    if (!sr %in% .bl_SUPERVISOR_ROLES) {
      need(sprintf("their role, one of %s,", paste(.bl_SUPERVISOR_ROLES, collapse = ", ")),
           "--supervisor-role", "supervisor_role")
    }
    se <- tolower(ask("Their email: ", supervisor_email))
    if (!grepl("^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$", se)) {
      need("their email address", "--supervisor-email", "supervisor_email")
    }
    out <- c(out, list(supervisor_name = sn, supervisor_role = sr, supervisor_email = se))
  }
  out
}

#' Signs in with a one-time code sent by email and stores the key.
#' @param email The email address.
#' @param code The code, or NULL to request one and ask for it.
#' @param profile The profile from `.bl_signin_profile()`.
#' @return The key, invisibly.
#' @noRd
.bl_login_email <- function(email, code = NULL, profile = list()) {
  auth <- .bl_hosted_auth()
  email <- tolower(trimws(as.character(email)))
  if (length(email) != 1L || is.na(email) || !nzchar(email)) {
    stop(.rmbl_fn(), "an email address is required", call. = FALSE)
  }
  if (!grepl("^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$", email)) {
    stop(.rmbl_fn(), sprintf("'%s' is not an email address", email), call. = FALSE)
  }
  if (is.null(code)) {
    res <- .bl_post_json(paste0(auth, "/email/code"), c(list(email = email), profile))
    if (res$status != 200L) .bl_reply_error(res, "the sign-in service")
    message(sprintf(
      "A one-time code (like ABCDE-FGHJK) was sent to %s; it is valid for 10 minutes.",
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

#' Signs in with the GitHub device flow and stores the key.
#' @param open_browser Whether the sign-in page is opened in the browser.
#' @param poll_max_seconds How long to wait for the approval.
#' @param profile The profile from `.bl_signin_profile()`.
#' @return The key, invisibly.
#' @noRd
.bl_login_device <- function(open_browser = interactive(),
                             poll_max_seconds = 600, profile = list()) {
  auth <- .bl_hosted_auth()
  start <- .bl_post_json(paste0(auth, "/device/code"), profile)
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
#' Removes the MORIE data key that \code{\link{dlogin}}
#' stored, so this machine can no longer load the curated tables at
#' data.rmorie.com until you sign in again. Use it on a shared machine, or
#' to switch to another key. Nothing is contacted.
#'
#' @details
#' The shared credentials file is \code{credentials.json} in the folder
#' \code{$XDG_CONFIG_HOME/morie}, else in \code{~/.config/morie}. It is edited as
#' text. Three members are removed: \code{hosted_key}, \code{hosted_user} and
#' \code{hosted_base_url}. Every other entry (written by \code{morie}, \code{rmorie} or
#' \code{rmoriedata}) is kept byte for byte. When nothing else is left the
#' file is deleted. A key set in the environment variable
#' \code{MORIE_HOSTED_KEY} is not touched. A message says whether a key was
#' removed.
#'
#' Errors when the file is not a JSON object (or not valid JSON, or names a
#' member twice), and when the key cannot be removed without damaging the
#' file; in both cases the file is left as it was.
#'
#' @return Logical scalar, invisibly: \code{TRUE} when a key was removed,
#'   \code{FALSE} when none was stored.
#' @seealso \code{\link{dlogin}}.
#' @examples
#' old <- Sys.getenv("XDG_CONFIG_HOME", unset = NA)
#' Sys.setenv(XDG_CONFIG_HOME = tempfile())   # a scratch credentials folder
#'
#' # nothing stored yet
#' dlogout()
#'
#' # a file holding a key and another tool's entry: only the key goes
#' d <- file.path(Sys.getenv("XDG_CONFIG_HOME"), "morie")
#' dir.create(d, recursive = TRUE)
#' writeLines('{"hosted_key": "k-123", "other_tool": 1}', file.path(d, "credentials.json"))
#' dlogout()
#' readLines(file.path(d, "credentials.json"))
#'
#' # a damaged file is refused, not overwritten
#' writeLines("not json", file.path(d, "credentials.json"))
#' try(dlogout())
#'
#' if (is.na(old)) Sys.unsetenv("XDG_CONFIG_HOME") else Sys.setenv(XDG_CONFIG_HOME = old)
#' @export
dlogout <- function() {
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
#' Shows, in one table, every way \code{\link{llmask}} could
#' reach a language model from this machine and whether each is ready: your
#' own endpoint, each provider whose key is set, and a local Ollama server.
#' Use it to find out why a question fails with "no route", or which model
#' a route would use. The command line prints it as part of
#' \code{rmoriebricklayer doctor}.
#'
#' @details
#' Rows come in the order \code{llmask()} tries the routes. The
#' providers without a key share one row that names each one with its key
#' variable. Key values are never shown. Nothing is sent to a provider; the
#' only network contact is a \code{GET /api/tags} to the Ollama address
#' (\code{OLLAMA_HOST}, default \code{http://localhost:11434}; 2 second
#' timeout) unless \code{OLLAMA_HOST=off}.
#'
#' A settings file (\code{llm.json} next to the credentials file) that
#' cannot be read does not make the call fail: the result is then a single
#' row with \code{route = "settings"} and \code{status = "unreadable"},
#' with the reason and the command that moves the file aside.
#'
#' @return A data frame with one row per route and three character columns:
#'   \code{route} (\code{"own endpoint"}, a provider label such as
#'   \code{"Anthropic"}, \code{"other providers"} or \code{"local Ollama"}),
#'   \code{status} (\code{"not set"} or \code{"configured"} for your own
#'   endpoint; \code{"key set"} for a provider; \code{"no key"} for the
#'   shared row; \code{"disabled"}, \code{"not running"},
#'   \code{"no models"} or \code{"available"} for Ollama) and \code{detail}
#'   (the address and model, or what to set up).
#' @seealso \code{\link{llmrte}} for the one route a
#'   question would take; \code{\link{llmprvd}}.
#' @examples
#' old <- Sys.getenv(c("XDG_CONFIG_HOME", "OLLAMA_HOST",
#'                     "MORIE_LLM_BASE_URL", "MORIE_LLM_MODEL"),
#'                   unset = NA)
#' # a scratch settings folder and the local route off: no network at all
#' Sys.setenv(XDG_CONFIG_HOME = tempfile(), OLLAMA_HOST = "off")
#' st <- llmstat()
#' st[, c("route", "status")]
#'
#' # your own OpenAI-compatible server shows as configured (it is not contacted)
#' Sys.setenv(MORIE_LLM_BASE_URL = "http://localhost:8080", MORIE_LLM_MODEL = "llama3")
#' llmstat()[1, ]
#'
#' for (v in names(old)) {
#'   if (is.na(old[[v]])) Sys.unsetenv(v) else do.call(Sys.setenv, as.list(old[v]))
#' }
#' @export
llmstat <- function() {
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
        sprintf(paste("%s (start it with `ollama serve`; or install Ollama, pull a model,",
                      "or point OLLAMA_HOST at a server)"), ob))
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
