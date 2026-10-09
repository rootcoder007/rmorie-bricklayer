# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Saved language-model settings: which route `ask` takes, the address, key
# and model of each route. Every setting has an environment variable too;
# a variable that is set wins over the saved value, so a one-off
# `OLLAMA_MODEL=x rmbl ask ...` still works. The file is
# $XDG_CONFIG_HOME/morie/llm.json (private, 0600), next to the shared
# credentials file, and is only ever written by bricklayer_llm_config() or
# `rmbl config`, never by examples or tests.

.bl_config_spec <- function() {
  data.frame(
    key = c("route", "own.url", "own.key", "own.model",
            "ollama.url", "ollama.model", "ollama.key",
            "hosted.url", "hosted.model", "hosted.key"),
    env = c("MORIE_LLM_ROUTE", "MORIE_LLM_BASE_URL", "MORIE_LLM_API_KEY", "MORIE_LLM_MODEL",
            "OLLAMA_HOST", "OLLAMA_MODEL", "OLLAMA_API_KEY",
            "MORIE_HOSTED_BASE_URL", "MORIE_HOSTED_MODEL", "MORIE_HOSTED_KEY"),
    secret = c(FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, FALSE, TRUE),
    help = c(
      "which route `ask` uses: auto (own endpoint, then Ollama, then hosted), own, ollama or hosted",
      paste("your own OpenAI-compatible server, e.g. http://localhost:1234/v1 (LM Studio),",
            "http://localhost:8080/v1 (llama-server -m /path/model.gguf) or https://api.example.org/v1"),
      "API key for your own server (sent as a Bearer token)",
      "model name on your own server",
      "your Ollama server, e.g. http://localhost:11434 or 192.168.1.20:11434; off to skip Ollama",
      "Ollama model to use (default: the first one pulled)",
      "API key for an Ollama server that wants one",
      "hosted MORIE tier address (default: from the signed services document); off to skip it",
      "hosted model (default: the tier's default; `rmbl models` lists them)",
      "your MORIE key (stored by `rmbl login`; checked with the gateway before it is saved)"
    ),
    stringsAsFactors = FALSE
  )
}

.bl_config_path <- function() file.path(dirname(.bl_credentials_path()), "llm.json")

.bl_read_config <- function() {
  p <- .bl_config_path()
  if (!file.exists(p)) return(list())
  out <- tryCatch(.rmbl_json_text(readLines(p, warn = FALSE), simplifyVector = TRUE),
                  error = function(e) NULL)
  if (is.list(out)) out else list()
}

.bl_write_config <- function(data) {
  p <- .bl_config_path()
  if (!length(data)) {
    if (file.exists(p)) unlink(p)
    return(invisible(p))
  }
  .bl_write_private_json(p, data)
}

# The saved value behind an environment variable's name, or NULL.
.bl_config_value <- function(env) {
  spec <- .bl_config_spec()
  key <- spec$key[match(env, spec$env)]
  if (is.na(key) || identical(key, "hosted.key")) return(NULL)  # the key lives in credentials.json
  v <- .bl_read_config()[[key]]
  if (is.character(v) && length(v) == 1L && nzchar(trimws(v))) trimws(v) else NULL
}

# Where a setting comes from right now: "environment", "saved", or "default".
.bl_config_source <- function(key, env) {
  if (nzchar(trimws(Sys.getenv(env, unset = "")))) return("environment")
  if (identical(key, "hosted.key")) {
    return(if (is.null(.bl_read_credentials()$hosted_key)) "default" else "saved")
  }
  if (!is.null(.bl_config_value(env))) "saved" else "default"
}

.bl_mask <- function(v) {
  if (is.null(v) || !nzchar(v)) return("(not set)")
  if (nchar(v) <= 8L) return("****")
  paste0(substr(v, 1L, 4L), "...", substr(v, nchar(v) - 3L, nchar(v)))
}

# The value a setting has right now (the default spelled out), for display.
.bl_config_effective <- function(key) {
  switch(key,
    route = .bl_env1("MORIE_LLM_ROUTE") %||% "auto",
    own.url = .bl_env1("MORIE_LLM_BASE_URL") %||% "(not set)",
    own.key = .bl_mask(.bl_env1("MORIE_LLM_API_KEY")),
    own.model = .bl_env1("MORIE_LLM_MODEL") %||% "(the server's first)",
    ollama.url = .bl_env1("OLLAMA_HOST") %||% .bl_env1("OLLAMA_BASE_URL") %||% "http://localhost:11434",
    ollama.model = .bl_env1("OLLAMA_MODEL") %||% "(the first one pulled)",
    ollama.key = .bl_mask(.bl_env1("OLLAMA_API_KEY")),
    hosted.url = tryCatch(.bl_hosted_base() %||% "off", error = function(e) conditionMessage(e)),
    hosted.model = .bl_hosted_model(),
    hosted.key = .bl_mask(.bl_hosted_key())
  )
}

.bl_config_check <- function(key, value) {
  switch(key,
    route = if (!value %in% c("auto", "own", "ollama", "hosted")) {
      stop("route must be one of: auto, own, ollama, hosted", call. = FALSE)
    },
    own.url = if (!tolower(value) %in% c("off", "none", "disabled") && !grepl("^https?://[^/[:space:]]+", value)) {
      stop("own.url must be an http(s):// address, e.g. http://localhost:1234/v1", call. = FALSE)
    },
    hosted.url = if (!tolower(value) %in% c("off", "none", "disabled")) {
      .rmbl_check_public_url(sub("/+$", "", value), "hosted.url")
    },
    ollama.url = if (grepl("[[:space:]]", value)) {
      stop("ollama.url must be an address such as http://localhost:11434", call. = FALSE)
    },
    NULL
  )
  invisible(TRUE)
}

#' Show or save the language-model settings
#'
#' Every setting that decides how \code{\link{bricklayer_llm_ask}} reaches a
#' model, in one place: which route to use, and the address, key and model
#' of your own OpenAI-compatible server, of a local or LAN Ollama server, and
#' of the hosted MORIE tier. Settings are saved in
#' \code{$XDG_CONFIG_HOME/morie/llm.json} (default \code{~/.config/morie/}),
#' a private file this function writes only when you pass a setting; the
#' hosted key goes to the shared credentials file through
#' \code{\link{bricklayer_llm_login}}, which checks it with the gateway first.
#' An environment variable that is set (the \code{env} column) wins over a
#' saved value.
#'
#' The same is available from the shell: \code{rmbl config} lists the
#' settings, \code{rmbl config set KEY VALUE} and \code{rmbl config unset KEY}
#' change one, and \code{rmbl config setup} walks through all of them.
#'
#' @param ... Settings to save, as \code{key = value}: \code{route}
#'   (\code{"auto"}, \code{"own"}, \code{"ollama"} or \code{"hosted"}),
#'   \code{own.url}, \code{own.key}, \code{own.model}, \code{ollama.url},
#'   \code{ollama.model}, \code{ollama.key}, \code{hosted.url},
#'   \code{hosted.model}, \code{hosted.key}. \code{NULL} or \code{""} removes
#'   a saved setting. With no arguments nothing is written.
#' @return A data frame with one row per setting: \code{key}, \code{value}
#'   (keys shown shortened), \code{source} (\code{"environment"},
#'   \code{"saved"} or \code{"default"}), \code{env} (the variable that
#'   overrides it) and \code{help}; visibly when called with no settings.
#' @examples
#' # reading the settings writes nothing
#' bricklayer_llm_config()
#' \dontrun{
#' # always use the hosted tier with one model
#' bricklayer_llm_config(route = "hosted", hosted.model = "gpt-oss-120b:cf")
#' # an Ollama server on another machine
#' bricklayer_llm_config(ollama.url = "http://192.168.1.20:11434", ollama.model = "qwen3:8b")
#' # your own OpenAI-compatible server
#' bricklayer_llm_config(own.url = "http://localhost:1234/v1", own.model = "my-model")
#' # back to the automatic order
#' bricklayer_llm_config(route = NULL)
#' }
#' @export
bricklayer_llm_config <- function(...) {
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
    for (k in nm) {
      v <- args[[k]]
      v <- if (is.null(v) || (length(v) == 1L && is.na(v))) "" else trimws(as.character(v))
      if (length(v) != 1L) stop(sprintf("%s takes one value", k), call. = FALSE)
      if (identical(k, "hosted.key")) {
        if (nzchar(v)) bricklayer_llm_login(token = v) else bricklayer_llm_logout()
        next
      }
      if (nzchar(v)) {
        if (identical(k, "route")) v <- tolower(v)
        .bl_config_check(k, v)
        data[[k]] <- v
      } else {
        data[[k]] <- NULL
      }
    }
    .bl_write_config(data)
    env_set <- spec$env[match(setdiff(nm, "hosted.key"), spec$key)]
    env_set <- env_set[vapply(env_set, function(e) nzchar(Sys.getenv(e, unset = "")), TRUE)]
    if (length(env_set)) {
      warning(sprintf("%s is set in the environment and still wins over the saved value",
                      paste(env_set, collapse = ", ")), call. = FALSE)
    }
  }
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
      out(sprintf("  %-13s %-40s %s\n", tab$key[i], tab$value[i],
                  if (identical(tab$source[i], "default")) "" else paste0("(", tab$source[i], ")")))
    }
  }
  switch(sub_verb,
    show = ,
    list = {
      show(bricklayer_llm_config())
      out(paste0(
        sprintf("\nSaved in %s. ", .bl_config_path()),
        "An environment variable that is set wins over a saved value.\n",
        sprintf("Change one:  %s config set route hosted\n", prog),
        sprintf("Walk through all of them:  %s config setup\n", prog),
        sprintf("What each one means:  %s config help\n", prog)
      ))
    },
    help = {
      for (i in seq_len(nrow(spec))) {
        out(sprintf("  %-13s %s\n  %-13s (environment variable %s)\n", spec$key[i], spec$help[i], "", spec$env[i]))
      }
      out(paste0(
        "\nExamples:\n",
        sprintf("  %s config set route hosted                         always use the hosted tier\n", prog),
        sprintf("  %s config set hosted.model gpt-oss-120b:cf         its model\n", prog),
        sprintf("  %s config set ollama.url http://192.168.1.20:11434  Ollama on another machine\n", prog),
        sprintf("  %s config set ollama.model qwen3:8b\n", prog),
        sprintf("  %s config set own.url http://localhost:1234/v1     LM Studio, vLLM, llama.cpp ...\n", prog),
        sprintf("  %s config set own.key KEY\n", prog),
        sprintf("  %s config unset route                              back to the automatic order\n", prog)
      ))
    },
    get = {
      k <- need_key()
      out(paste0(.bl_config_effective(k), "\n"))
    },
    set = {
      k <- need_key()
      v <- if (length(args) >= 2L) paste(args[-1L], collapse = " ") else ""
      if (!nzchar(v) && spec$secret[match(k, spec$key)]) v <- .bl_readline(sprintf("%s: ", k))
      if (!nzchar(v)) usage_error(sprintf("usage: %s config set %s VALUE", prog, k))
      withCallingHandlers(do.call(bricklayer_llm_config, stats::setNames(list(v), k)),
        warning = function(w) {
          out(paste0(prog, ": ", conditionMessage(w), "\n"))
          invokeRestart("muffleWarning")
        })
      out(sprintf("%s = %s\n", k, .bl_config_effective(k)))
    },
    unset = {
      k <- need_key()
      do.call(bricklayer_llm_config, stats::setNames(list(NULL), k))
      out(sprintf("%s = %s\n", k, .bl_config_effective(k)))
    },
    path = out(paste0(.bl_config_path(), "\n")),
    setup = .bl_config_setup(out),
    usage_error(sprintf("usage: %s config [show | help | get KEY | set KEY VALUE | unset KEY | setup | path]", prog))
  )
  invisible(0L)
}

# `rmbl config setup`: one question per route, Enter keeps what is there.
.bl_config_setup <- function(out) {
  prog <- .bl_prog()
  ask <- function(q, current = "") {
    a <- .bl_readline(sprintf("%s%s: ", q, if (nzchar(current)) sprintf(" [%s]", current) else ""))
    if (nzchar(a)) a else current
  }
  set <- function(...) bricklayer_llm_config(...)
  out("Language-model setup. Press Enter to keep the value in [brackets].\n\n")
  route <- tolower(ask("Which should `ask` use: auto, hosted, ollama or own", .bl_config_effective("route")))
  if (!route %in% c("auto", "own", "ollama", "hosted")) route <- "auto"
  set(route = if (identical(route, "auto")) NULL else route)
  if (route %in% c("auto", "hosted")) {
    if (is.null(.bl_hosted_key())) {
      out(sprintf("\nThe hosted tier needs a MORIE key: `%s login` (GitHub or an emailed code),\n", prog))
      out("or paste one issued at https://www.rmorie.com/access here.\n")
      k <- ask("MORIE key (Enter to skip)")
      if (nzchar(k)) set(hosted.key = k)
    }
    if (!is.null(.bl_hosted_key())) {
      have <- tryCatch(bricklayer_llm_models(), error = function(e) character())
      if (length(have)) out(sprintf("Models: %s\n", paste(have, collapse = ", ")))
      m <- ask("Hosted model", .bl_config_effective("hosted.model"))
      unchanged <- identical(m, .bl_hosted_model()) && is.null(.bl_config_value("MORIE_HOSTED_MODEL"))
      set(hosted.model = if (unchanged) NULL else m)
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
      k <- ask("API key for it (Enter for none or to keep)")
      if (nzchar(k)) set(own.key = k)
    }
  }
  out(sprintf("\nSaved in %s.\n\n", .bl_config_path()))
  .bl_cli_doctor(out)
  invisible(0L)
}

# `rmbl doctor`: the routes, then the one `ask` would take now.
.bl_cli_doctor <- function(out) {
  st <- bricklayer_llm_status()
  for (i in seq_len(nrow(st))) {
    out(sprintf("  %-20s %-16s %s\n", st$route[i], st$status[i], st$detail[i]))
  }
  rt <- tryCatch(.bl_llm_route(), error = function(e) e)
  prog <- .bl_prog()
  if (inherits(rt, "error")) {
    out(sprintf("\n  ask would fail: %s\n", conditionMessage(rt)))
  } else if (is.null(rt)) {
    out(sprintf("\n  ask has no route yet: `%s login` for the hosted tier, or `%s config setup`\n", prog, prog))
  } else {
    out(sprintf("\n  ask uses: %s, model %s%s\n", rt$name, rt$model %||% "(none)",
                if (identical(.bl_config_effective("route"), "auto")) "" else
                  sprintf("  (route = %s)", .bl_config_effective("route"))))
  }
  out(sprintf("  change it: %s config set route hosted|ollama|own|auto  (all settings: %s config)\n", prog, prog))
}
