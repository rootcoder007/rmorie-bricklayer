# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Saved language-model settings: which route `ask` takes, the address, key
# and model of each route. Every setting has an environment variable too;
# a variable that is set wins over the saved value, so a one-off
# `OLLAMA_MODEL=x rmbl ask ...` still works. The file is
# $XDG_CONFIG_HOME/morie/llm.json (private, 0600), next to the shared
# credentials file, and is only ever written by llmcfg() or
# `rmbl config`, never by examples or tests.

# The settings table and the provider presets never change in a session: they are built once
# (data.frame() and rbind() over the sixteen presets cost about 0.1 s a time, and reading the
# settings asked for them dozens of times) and kept in .bl_cfg_state.
.bl_cfg_state <- new.env(parent = emptyenv())

.bl_cfg_presets <- function() {
  if (is.null(.bl_cfg_state$presets)) .bl_cfg_state$presets <- .bl_llm_presets()
  .bl_cfg_state$presets
}

.bl_config_spec <- function() {
  if (is.null(.bl_cfg_state$spec)) .bl_cfg_state$spec <- .bl_config_spec_build()
  .bl_cfg_state$spec
}

.bl_config_spec_build <- function() {
  base <- data.frame(
    key = c("route", "own.url", "own.key", "own.model", "ollama.url", "ollama.model", "ollama.key"),
    env = c("MORIE_LLM_ROUTE", "MORIE_LLM_BASE_URL", "MORIE_LLM_API_KEY", "MORIE_LLM_MODEL",
            "OLLAMA_HOST", "OLLAMA_MODEL", "OLLAMA_API_KEY"),
    secret = c(FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, TRUE),
    help = c(
      paste("which route `ask` uses: auto (own endpoint, then each provider with a key, then Ollama),",
            "own, ollama or a provider"),
      paste("your own OpenAI-compatible server, e.g. http://localhost:1234/v1 (LM Studio),",
            "http://localhost:8080/v1 (llama-server -m /path/model.gguf) or https://api.example.org/v1"),
      "API key for your own server (sent as a Bearer token)",
      "model name on your own server",
      "your Ollama server, e.g. http://localhost:11434 or 192.168.1.20:11434; off to skip Ollama",
      "Ollama model to use (default: the first one pulled)",
      "API key for an Ollama server that wants one"
    ),
    stringsAsFactors = FALSE
  )
  # one key and one model per provider (bring your own key), named after the provider's own variable
  ps <- .bl_cfg_presets()
  prov <- data.frame(
    key = c(rbind(paste0(ps$id, ".key"), paste0(ps$id, ".model"))),
    env = c(rbind(ps$key_env, .bl_preset_model_env(ps$id))),
    secret = rep(c(TRUE, FALSE), nrow(ps)),
    help = c(rbind(sprintf("your %s API key (sent only to %s)", ps$label, ps$base),
                   ifelse(is.na(ps$default_model), sprintf("%s model to use (`rmbl models --route %s` lists them)",
                                                           ps$label, ps$id),
                          sprintf("%s model to use (default %s)", ps$label, ps$default_model)))),
    stringsAsFactors = FALSE
  )
  rbind(base, prov)
}

.bl_config_path <- function() file.path(dirname(.bl_credentials_path()), "llm.json")

# TRUE when the settings file parses; a file that does not is reported once per change and
# treated as empty for reading, and is never written over (its saved keys would be lost)
.bl_config_parses <- function(p) {
  !is.null(.bl_config_object(p))
}

# The settings file as a named list, or NULL when it is not a JSON object ([], "x", 5 and a
# syntax error alike).
.bl_config_object <- function(p) {
  lines <- readLines(p, warn = FALSE)
  # `[]`, `"x"` and `5` parse, and an empty array reads as an empty list: only an object will do
  if (!startsWith(trimws(paste(lines, collapse = "")), "{")) return(NULL)
  out <- tryCatch(.rmbl_json_text(lines, simplifyVector = TRUE, bigint_as_char = TRUE), error = function(e) NULL)
  if (!is.list(out)) return(NULL)
  out
}

.bl_read_config <- function() {
  p <- .bl_config_path()
  if (!file.exists(p)) return(list())
  out <- .bl_config_object(p)
  if (is.null(out)) {
    # a saved route or key that is silently dropped sends a prompt where the user said not to
    # send it; a settings file that cannot be read stops the call until it is fixed
    stop(sprintf(paste("%s is not a JSON object and the saved route and keys cannot be read; fix or remove it",
                       "(`rmbl config reset` moves it aside)"), p),
         call. = FALSE)
  }
  # a setting of the wrong type (route: 5, [..], true, "") would be read as unset and the call
  # would go hosted; it is an error in the file, said as one
  spec <- .bl_config_spec()
  for (k in intersect(names(out), spec$key)) {
    v <- out[[k]]
    if (!is.character(v) || length(v) != 1L || is.na(v) || !nzchar(trimws(v))) {
      stop(sprintf(paste("%s: `%s` must be a non-empty string, not %s; fix or remove it",
                         "(`rmbl config reset` moves it aside)"), p, k,
                   if (is.null(v)) "null" else paste(class(v)[1L], "of length", length(v))), call. = FALSE)
    }
  }
  out
}

.bl_write_config <- function(data) {
  p <- .bl_config_path()
  if (file.exists(p) && !.bl_config_parses(p)) {
    stop(sprintf(paste("%s is not valid JSON; fix or remove it (`rmbl config reset` moves it aside)",
                       "before saving a setting",
                       "(writing over it would drop the keys it holds)"), p), call. = FALSE)
  }
  if (!length(data)) {
    if (file.exists(p)) unlink(p)
    return(invisible(p))
  }
  # only the settings that changed are written, in place: the rest of the file stays as it was
  # written (a full rewrite cut floats to 4 digits, unboxed one-element arrays, turned a "" key into
  # "1" and rounded integers past 2^53; network stress test of 5e1dce5). credentials.json is
  # written the same way.
  old <- if (file.exists(p)) .bl_read_config() else list()
  txt <- if (file.exists(p)) .bl_read_text(p) else "{}"
  for (k in union(names(old), names(data))) {
    if (nzchar(k) && !identical(old[[k]], data[[k]])) txt <- .bl_credentials_text_set(txt, k, data[[k]])
  }
  if (!endsWith(txt, "\n")) txt <- paste0(txt, "\n")   # a text file ends its last line
  .bl_write_private_text(p, txt)
}

# The saved value behind an environment variable's name, or NULL.
.bl_config_value <- function(env) {
  spec <- .bl_config_spec()
  key <- spec$key[match(env, spec$env)]
  if (is.na(key)) return(NULL)
  # while llmcfg() builds its table the file is read once, not once per setting
  v <- (.bl_cfg_state$snap %||% .bl_read_config())[[key]]
  if (is.character(v) && length(v) == 1L && nzchar(trimws(v))) trimws(v) else NULL
}

# Where a setting comes from right now: "environment", "saved", or "default".
.bl_config_source <- function(key, env) {
  if (nzchar(trimws(Sys.getenv(env, unset = "")))) return("environment")
  if (!is.null(.bl_config_value(env))) "saved" else "default"
}

# How a key is displayed: only whether one is set. No character of it is ever printed.
.bl_mask <- function(v) {
  if (is.null(v) || !nzchar(v)) "(not set)" else "set"
}

# The value a setting has right now (the default spelled out), for display.
.bl_config_effective <- function(key) {
  fixed <- switch(key,
    route = {
      r <- .bl_env1("MORIE_LLM_ROUTE") %||% "auto"
      if (identical(tolower(r), "hosted")) "auto (the saved route `hosted` is retired and ignored)" else r
    },
    own.url = .bl_env1("MORIE_LLM_BASE_URL") %||% "(not set)",
    own.key = .bl_mask(.bl_env1("MORIE_LLM_API_KEY")),
    own.model = .bl_env1("MORIE_LLM_MODEL") %||% "(not set)",
    ollama.url = .bl_env1("OLLAMA_HOST") %||% .bl_env1("OLLAMA_BASE_URL") %||% "http://localhost:11434",
    ollama.model = .bl_env1("OLLAMA_MODEL") %||% "(the first one pulled)",
    ollama.key = .bl_mask(.bl_env1("OLLAMA_API_KEY")),
    NULL)
  if (!is.null(fixed)) return(.rmbl_printable(fixed))
  id <- sub("[.](key|model)$", "", key)
  ps <- .bl_cfg_presets()
  pr <- ps[match(id, ps$id), , drop = FALSE]
  if (endsWith(key, ".key")) return(.bl_mask(.bl_cfg_preset_key(pr, id)))
  .rmbl_printable(.bl_env1(.bl_preset_model_env(id)) %||%
                    (if (!is.na(pr$default_model)) pr$default_model else "(not chosen)"))
}

# .bl_preset_key() (R/llm_providers.R) over the cached preset row: the provider's variable, its
# alternative spelling, else the saved value. The same three steps, without rebuilding the presets.
.bl_cfg_preset_key <- function(pr, id) {
  for (e in c(pr$key_env, if (nzchar(pr$alt_env)) pr$alt_env)) {
    v <- trimws(Sys.getenv(e, unset = ""))
    if (nzchar(v)) return(.bl_key_text(v, e))
  }
  .bl_key_text(.bl_config_value(pr$key_env), paste0(id, ".key"))
}

# An address that is saved must be one address: no whitespace, no `#fragment`, no `user@`.
.bl_url_sane <- function(value, key) {
  if (grepl("[[:space:][:cntrl:]#@]", value)) {
    stop(sprintf("%s must be a plain address with no spaces, fragment or user information", key), call. = FALSE)
  }
  invisible(TRUE)
}

.bl_config_check <- function(key, value) {
  if (key %in% c("own.url", "ollama.url") && !tolower(value) %in% c("off", "none", "disabled")) {
    .bl_url_sane(value, key)
  }
  if (endsWith(key, ".key") && grepl("[[:cntrl:]]", value)) {
    stop(sprintf("%s has a line break or control character in it: give the key alone", key), call. = FALSE)
  }
  switch(key,
    route = {
      if (identical(value, "hosted")) stop(.bl_hosted_retired(), call. = FALSE)
      if (!value %in% c("auto", .bl_llm_route_names())) {
        stop(sprintf("route must be one of: auto, own, ollama, %s", paste(.bl_llm_presets()$id, collapse = ", ")),
             call. = FALSE)
      }
    },
    own.url = if (!tolower(value) %in% c("off", "none", "disabled")) {
      if (!grepl("^https?://[^/[:space:]]+", value)) {
        stop("own.url must be an http(s):// address, e.g. http://localhost:1234/v1", call. = FALSE)
      }
      # the same check the address gets when it is used: a metadata or link-local address is
      # refused when it is saved, not only later
      v <- sub("/v1$", "", sub("/+$", "", value))
      if (!.bl_loopback_url(v)) .rmbl_check_public_url(v, "own.url")
    },
    ollama.url = if (!tolower(value) %in% c("off", "none", "disabled")) {
      has_scheme <- grepl("^[a-z][a-z0-9+.-]*://", value, ignore.case = TRUE)
      if (grepl("[[:space:]]", value) || (has_scheme && !grepl("^https?://", value, ignore.case = TRUE))) {
        stop("ollama.url must be an http(s):// address such as http://localhost:11434 (or host:port)", call. = FALSE)
      }
      # the same check own.url gets: a metadata or link-local address is refused when saved
      v <- sub("/+$", "", if (has_scheme) value else paste0("http://", value))
      if (!.bl_loopback_url(v)) .rmbl_check_public_url(v, "ollama.url")
    },
    NULL
  )
  invisible(TRUE)
}

#' Show or save the language-model settings
#'
#' Every setting that decides how \code{\link{llmask}} reaches a
#' model, in one place: which route to use; your key and model for each
#' provider (bring your own key: see \code{\link{llmprvd}});
#' the address, key and model of your own OpenAI-compatible server; and of a
#' local or LAN Ollama server. Called with no arguments it only reads: it
#' returns a table of every setting, its current value, and where that value
#' comes from. Called with \code{key = value} pairs it saves those settings
#' first. Keys are never printed, only whether one is set.
#'
#' @details
#' \strong{Where settings live.} Saved settings are kept in
#' \code{$XDG_CONFIG_HOME/morie/llm.json} (\code{~/.config/morie/llm.json}
#' when \code{XDG_CONFIG_HOME} is unset), a private file (mode 0600, in a
#' private directory) next to the shared \code{credentials.json}. The file is
#' written only when you pass a setting; only the settings that change are
#' rewritten in place, so the rest of the file stays exactly as it was. An
#' empty set of settings removes the file.
#'
#' \strong{Precedence.} An environment variable that is set (the \code{env}
#' column, for example \code{ANTHROPIC_API_KEY} or \code{OLLAMA_HOST}) wins
#' over a saved value, which wins over the built-in default. Saving a
#' setting whose variable is set warns that the variable still wins. A
#' provider key is also read from the provider's alternative variable where
#' it has one (\code{GOOGLE_API_KEY} for Gemini, \code{HUGGINGFACE_HUB_TOKEN}
#' for Hugging Face, \code{CO_API_KEY} for Cohere).
#'
#' \strong{Checks when saving.} Names must be among the settings listed in
#' the \code{key} column (\code{"unknown setting"} otherwise) and every value
#' passed as \code{key = value} with one value each. \code{route} must be
#' \code{"auto"}, \code{"own"}, \code{"ollama"} or a provider id; the
#' retired \code{"hosted"} route is refused. \code{own.url} must be an
#' \code{http(s)://} address and \code{ollama.url} an address or
#' \code{host:port}; both are refused if they contain spaces, a fragment or
#' user information, and, unless they point at this machine or a private LAN
#' address, they get the package's public-address check (a metadata or
#' link-local address is refused). \code{"off"}, \code{"none"} or
#' \code{"disabled"} turns a server off. A key with a line break or control
#' character in it is refused. A new \code{own.url} or \code{ollama.url}
#' drops the key saved for the old server (with a message), so a key is
#' never sent to a server it was not saved for. A settings file that is not
#' a JSON object, or holds a setting that is not a non-empty string, stops
#' every call until it is fixed or moved aside with \code{rmbl config reset}.
#'
#' Reading the settings takes a few milliseconds: the table of settings is
#' built once per session and the file is read once per call. Nothing is
#' sent over the network by this function.
#'
#' The same is available from the shell: \code{rmbl config} lists the
#' settings, \code{rmbl config set KEY VALUE} and \code{rmbl config unset KEY}
#' change one (a key is asked for without echo when no value is given), and
#' \code{rmbl config setup} walks through them.
#'
#' @param ... Settings to save, as \code{key = value}: \code{route}
#'   (\code{"auto"}, \code{"own"}, \code{"ollama"} or a provider id such as
#'   \code{"anthropic"}; case is ignored), \code{<provider>.key} and
#'   \code{<provider>.model} (e.g. \code{anthropic.key},
#'   \code{openai.model}), \code{own.url}, \code{own.key},
#'   \code{own.model}, \code{ollama.url}, \code{ollama.model},
#'   \code{ollama.key}. Each value is a single string (leading and trailing
#'   spaces are removed). \code{NULL}, \code{NA} or \code{""} removes a
#'   saved setting. With no arguments nothing is written.
#' @return A data frame with one row per setting (seven general settings
#'   followed by a key and a model row for each provider) and five character
#'   columns: \code{key} (the setting's name), \code{value} (its current
#'   value, the default spelled out; a key only as \code{"set"} or
#'   \code{"(not set)"}), \code{source} (\code{"environment"},
#'   \code{"saved"} or \code{"default"}), \code{env} (the environment
#'   variable that overrides it) and \code{help} (what it is for). Returned
#'   visibly when called with no settings, invisibly after saving.
#' @seealso \code{\link{llmprvd}} for the providers and
#'   their variables, \code{\link{llmstat}} for which routes
#'   are reachable, \code{\link{llmask}} which uses these
#'   settings.
#' @examples
#' # Work in a temporary settings directory so your own settings are
#' # untouched.
#' old <- Sys.getenv("XDG_CONFIG_HOME", unset = NA)
#' Sys.setenv(XDG_CONFIG_HOME = tempfile("cfg"))
#'
#' # Reading the settings writes nothing.
#' cfg <- llmcfg()
#' head(cfg[, c("key", "value", "source")])
#' nrow(cfg)
#'
#' # Save a local Ollama model and use it for every request; the key column
#' # shows where each value now comes from.
#' llmcfg(ollama.model = "qwen3:8b", route = "ollama")
#' cfg <- llmcfg()
#' cfg[cfg$key %in% c("route", "ollama.model"), c("key", "value", "source")]
#'
#' # A key is shown only as set or not set.
#' llmcfg(own.url = "http://localhost:1234/v1", own.key = "k-123")
#' cfg <- llmcfg()
#' cfg$value[cfg$key == "own.key"]
#'
#' # Back to the defaults: NULL removes a saved setting.
#' llmcfg(route = NULL, ollama.model = NULL, own.url = NULL,
#'                       own.key = NULL)
#'
#' # Unknown settings and retired routes are refused.
#' try(llmcfg(colour = "blue"))
#' try(llmcfg(route = "hosted"))
#'
#' if (is.na(old)) Sys.unsetenv("XDG_CONFIG_HOME") else Sys.setenv(XDG_CONFIG_HOME = old)
#' \dontrun{
#' # your Anthropic key and model, and always use them
#' llmcfg(anthropic.key = "sk-ant-...", route = "anthropic")
#' # an Ollama server on another machine
#' llmcfg(ollama.url = "http://192.168.1.20:11434", ollama.model = "qwen3:8b")
#' }
#' @export
llmcfg <- function(...) {
  args <- list(...)
  spec <- .bl_config_spec()
  if (length(args)) {
    nm <- names(args)
    if (is.null(nm) || any(!nzchar(nm))) stop("settings are passed as key = value", call. = FALSE)
    bad <- setdiff(nm, spec$key)
    if (length(bad)) {
      stop(sprintf("unknown setting '%s' (one of: %s)", bad[[1L]], paste(spec$key, collapse = ", ")),
           call. = FALSE)
    }
    data <- .bl_read_config()
    # an address before its key in one call, so the key is saved for the new server, not dropped
    nm <- c(intersect(c("own.url", "ollama.url"), nm), setdiff(nm, c("own.url", "ollama.url")))
    for (k in nm) {
      v <- args[[k]]
      v <- if (is.null(v) || (length(v) == 1L && is.na(v))) "" else trimws(as.character(v))
      if (length(v) != 1L) stop(sprintf("%s takes one value", k), call. = FALSE)
      if (nzchar(v)) {
        if (identical(k, "route")) v <- tolower(v)
        .bl_config_check(k, v)
        # a key belongs to the server it was saved for: a new address drops the old key rather
        # than sending it to the new server
        key_of <- c(own.url = "own.key", ollama.url = "ollama.key")[k]
        moved <- !is.na(key_of) && !is.null(data[[key_of]]) &&
          !identical(sub("/+$", "", v), sub("/+$", "", data[[k]] %||% ""))
        if (moved) {
          data[[key_of]] <- NULL
          message(sprintf("%s changed: the saved %s was dropped (set it again for the new server)", k, key_of))
        }
        data[[k]] <- v
      } else {
        data[[k]] <- NULL
      }
    }
    .bl_write_config(data)
    env_set <- spec$env[match(nm, spec$key)]
    env_set <- env_set[vapply(env_set, function(e) nzchar(Sys.getenv(e, unset = "")), TRUE)]
    if (length(env_set)) {
      warning(sprintf("%s is set in the environment and still wins over the saved value",
                      paste(env_set, collapse = ", ")), call. = FALSE)
    }
  }
  .bl_cfg_state$snap <- .bl_read_config()
  on.exit(.bl_cfg_state$snap <- NULL, add = TRUE)
  tab <- data.frame(
    key = spec$key,
    value = vapply(spec$key, .bl_config_effective, "", USE.NAMES = FALSE),
    source = mapply(.bl_config_source, spec$key, spec$env, USE.NAMES = FALSE),
    env = spec$env,
    help = spec$help,
    stringsAsFactors = FALSE
  )
  if (length(args)) invisible(tab) else tab
}

# `rmbl config ...`
.bl_cli_config <- function(rest, out, usage_error) {
  prog <- .bl_prog()
  spec <- .bl_config_spec()
  sub_verb <- if (length(rest)) rest[[1L]] else "show"
  args <- rest[-1L]
  need_key <- function() {
    if (!length(args)) usage_error(sprintf("usage: %s config %s KEY%s", prog, sub_verb,
                                           if (identical(sub_verb, "set")) " VALUE" else ""))
    if (!args[[1L]] %in% spec$key) {
      usage_error(sprintf("unknown setting '%s' (one of: %s)", args[[1L]], paste(spec$key, collapse = ", ")))
    }
    args[[1L]]
  }
  show <- function(tab) {
    for (i in seq_len(nrow(tab))) {
      out(sprintf("  %-18s %-40s %s\n", tab$key[i], tab$value[i],
                  if (identical(tab$source[i], "default")) "" else paste0("(", tab$source[i], ")")))
    }
  }
  if (sub_verb %in% c("show", "list", "help") && length(args)) {
    usage_error(sprintf("usage: %s config %s", prog, sub_verb))
  }
  if (sub_verb %in% c("get", "unset") && length(args) > 1L) {
    usage_error(sprintf("usage: %s config %s KEY", prog, sub_verb))
  }
  switch(sub_verb,
    show = ,
    list = {
      show(llmcfg())
      out(paste0(
        sprintf("\nSaved in %s. ", .bl_config_path()),
        "An environment variable that is set wins over a saved value.\n",
        sprintf("Change one:  %s config set route anthropic\n", prog),
        sprintf("Walk through all of them:  %s config setup\n", prog),
        sprintf("What each one means:  %s config help\n", prog)
      ))
    },
    help = {
      for (i in seq_len(nrow(spec))) {
        out(sprintf("  %-18s %s\n  %-18s (environment variable %s)\n", spec$key[i], spec$help[i], "", spec$env[i]))
      }
      out(paste0(
        "\nExamples:\n",
        sprintf("  %s config set anthropic.key             (asks for the key: nothing in the shell history)\n", prog),
        sprintf("  %s config set anthropic.model claude-opus-5-5\n", prog),
        sprintf("  %s config set route anthropic          always use that provider\n", prog),
        sprintf("  %s config set ollama.url http://192.168.1.20:11434  Ollama on another machine\n", prog),
        sprintf("  %s config set ollama.model qwen3:8b\n", prog),
        sprintf("  %s config set own.url http://localhost:1234/v1     LM Studio, vLLM, llama.cpp ...\n", prog),
        sprintf("  %s config unset route                              back to the automatic order\n", prog)
      ))
    },
    get = {
      k <- need_key()
      out(paste0(.bl_config_effective(k), "\n"))
    },
    reset = {
      force <- identical(args, "--force")
      if (length(args) && !force) usage_error(sprintf("usage: %s config reset [--force]", prog))
      moved <- .bl_config_reset(force = force)
      out(if (is.null(moved)) "no settings file to move aside\n" else
            sprintf("moved the settings aside to %s; the defaults apply until you set something\n", moved))
    },
    set = {
      k <- need_key()
      v <- if (length(args) >= 2L) paste(args[-1L], collapse = " ") else ""
      if (!nzchar(v) && spec$secret[match(k, spec$key)]) v <- .bl_readline(sprintf("%s: ", k), secret = TRUE)
      if (!nzchar(v)) usage_error(sprintf("usage: %s config set %s VALUE", prog, k))
      withCallingHandlers(do.call(llmcfg, stats::setNames(list(v), k)),
        warning = function(w) {
          out(paste0(prog, ": ", conditionMessage(w), "\n"))
          invokeRestart("muffleWarning")
        })
      out(sprintf("%s = %s\n", k, .bl_config_effective(k)))
    },
    unset = {
      k <- need_key()
      do.call(llmcfg, stats::setNames(list(NULL), k))
      out(sprintf("%s = %s\n", k, .bl_config_effective(k)))
    },
    path = {
      if (length(args)) usage_error(sprintf("usage: %s config path", prog))
      out(paste0(.bl_config_path(), "\n"))
    },
    setup = {
      if (length(args)) usage_error(sprintf("usage: %s config setup", prog))
      .bl_config_setup(out)
    },
    usage_error(sprintf(paste("usage: %s config [show | help | get KEY | set KEY VALUE | unset KEY | setup | path |",
                              "reset [--force]]"), prog))
  )
  invisible(0L)
}

# `rmbl config setup`: where `ask` should go (a provider with your key, Ollama, or your own server),
# then that route's settings. Enter keeps what is there.
.bl_config_setup <- function(out) {
  prog <- .bl_prog()
  ask <- function(q, current = "", secret = FALSE) {
    # a key is typed without echo, like `login --token` (review of 52a8883, B6)
    a <- .bl_readline(sprintf("%s%s: ", q, if (nzchar(current)) sprintf(" [%s]", current) else ""), secret = secret)
    if (nzchar(a)) a else current
  }
  set <- function(...) llmcfg(...)
  ps <- .bl_llm_presets()
  out("Language-model setup: bring your own key, or run a model locally. Enter keeps the value in [brackets].\n\n")
  out(sprintf("Providers: %s\n", paste(ps$id, collapse = ", ")))
  out("Or: ollama (a model on this or another machine), own (any OpenAI-compatible server), auto.\n")
  route <- tolower(ask("Which should `ask` use", .bl_config_effective("route")))
  if (!route %in% c("auto", .bl_llm_route_names())) {
    out(sprintf("'%s' is not one of them; keeping auto\n", route))
    route <- "auto"
  }
  set(route = if (identical(route, "auto")) NULL else route)
  if (route %in% ps$id) {
    pr <- .bl_preset(route)
    if (is.null(.bl_preset_key(route))) {
      # the explanation is part of the prompt the shell prints once echo is off: printed by R first,
      # a key pasted straight away was echoed (network stress test of 5e1dce5)
      k <- ask(sprintf(paste0("\nYour %s key (it is saved privately and sent only to %s; %s also works)\n",
                              "%s key (Enter to skip)"), pr$label, pr$base, pr$key_env, pr$label), secret = TRUE)
      if (nzchar(k)) do.call(set, stats::setNames(list(k), paste0(route, ".key")))
    }
    if (!is.null(.bl_preset_key(route))) {
      have <- tryCatch(llmmdls(route), error = function(e) character())
      if (length(have)) out(sprintf("Models: %s\n", paste(utils::head(have, 30L), collapse = ", ")))
      m <- ask(sprintf("%s model", pr$label), .bl_env1(.bl_preset_model_env(route)) %||%
                 (if (!is.na(pr$default_model)) pr$default_model else ""))
      if (nzchar(m)) do.call(set, stats::setNames(list(m), paste0(route, ".model")))
    }
  }
  if (route %in% c("auto", "ollama")) {
    u <- ask("\nOllama address (off to skip Ollama)", .bl_config_effective("ollama.url"))
    set(ollama.url = if (identical(u, "http://localhost:11434")) NULL else u)
    m <- ask("Ollama model (Enter for the first pulled)", .bl_env1("OLLAMA_MODEL") %||% "")
    set(ollama.model = m)
  }
  if (route %in% c("auto", "own")) {
    u <- ask("\nYour own OpenAI-compatible server (Enter to skip)", .bl_env1("MORIE_LLM_BASE_URL") %||% "")
    set(own.url = u)
    if (nzchar(u)) {
      set(own.model = ask("Model on that server", .bl_env1("MORIE_LLM_MODEL") %||% ""))
      k <- ask("API key for it (Enter for none or to keep)", secret = TRUE)
      if (nzchar(k)) set(own.key = k)
    }
  }
  out(sprintf("\nSaved in %s.\n\n", .bl_config_path()))
  .bl_cli_doctor(out)
  invisible(0L)
}

# `rmbl doctor`: the routes, then the one `ask` would take now.
.bl_cli_doctor <- function(out) {
  st <- llmstat()
  for (i in seq_len(nrow(st))) {
    out(sprintf("  %-20s %-16s %s\n", st$route[i], st$status[i], st$detail[i]))
  }
  rt <- tryCatch(.bl_llm_route(), error = function(e) e)
  prog <- .bl_prog()
  if (inherits(rt, "error")) {
    out(sprintf("\n  ask would fail: %s\n", conditionMessage(rt)))
  } else if (is.null(rt)) {
    out(sprintf(paste0("\n  ask has no route yet: set a provider's key (e.g. ANTHROPIC_API_KEY), pull an Ollama",
                       " model, or `%s config setup`\n"), prog))
  } else {
    out(sprintf("\n  ask uses: %s, model %s%s\n", rt$name, rt$model %||% "(none)",
                if (identical(.bl_config_effective("route"), "auto")) "" else
                  sprintf("  (route = %s)", .bl_config_effective("route"))))
  }
  out(sprintf("  change it: %s config set route PROVIDER|ollama|own|auto  (all settings: %s config)\n", prog, prog))
  # the sign-in key is for the curated tables only, never a language model
  ks <- tryCatch(.bl_hosted_key_state(), error = function(e) list(state = "none"))
  out(switch(ks$state,
    ok = "\n  data key: stored (the curated tables at data.rmorie.com are open to you)\n",
    other_address = sprintf("\n  data key: issued for %s, so not sent to %s (`%s login` again)\n",
                            ks$saved_for, ks$now, prog),
    sprintf("\n  data key: none (`%s login` opens the curated tables)\n", prog)))
}

# The recovery path for a settings file the package refuses to read: it is moved aside, never
# deleted, and the path of the copy is returned (NULL when there is no file).
.bl_config_reset <- function(force = FALSE) {
  p <- .bl_config_path()
  if (!file.exists(p)) return(NULL)
  readable <- tryCatch({
    .bl_read_config()
    TRUE
  }, error = function(e) FALSE)
  # a file that reads fine holds settings someone chose: it is moved only when asked twice
  if (readable && !isTRUE(force)) {
    stop(sprintf(paste("%s reads fine; `config reset` moves aside only a file that cannot be read.",
                       "To start from the defaults anyway: %s config reset --force"), p, .bl_prog()), call. = FALSE)
  }
  stamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
  base <- paste0(p, if (readable) ".reset-" else ".broken-", stamp)
  aside <- base
  k <- 1L
  # two resets in one second: the second backup gets its own name, the first is not overwritten
  while (file.exists(aside)) {
    aside <- paste0(base, "-", k)
    k <- k + 1L
  }
  if (!isTRUE(file.rename(p, aside))) stop(sprintf("could not move %s aside", p), call. = FALSE)
  aside
}
