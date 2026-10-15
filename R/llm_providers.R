# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Bring your own key: the language-model providers the package can talk to, with your key (or a
# model on your own machine). Every provider here is reached directly from your R session; no
# MORIE server sits in between, and nothing is sent anywhere until a key or a local server is set
# up. Three wire formats cover them all: the OpenAI chat-completions format (which most providers
# and every local server speak), Anthropic's Messages API and Google's Gemini generateContent.
#
# Each preset's address, key header and key variable are the provider's documented ones
# (checked 2026-10-13):
#   OpenAI       https://platform.openai.com/docs/api-reference/chat
#   Anthropic    https://docs.anthropic.com/en/api/messages (x-api-key, anthropic-version 2023-06-01)
#   Gemini       https://ai.google.dev/gemini-api/docs/function-calling (x-goog-api-key, v1beta)
#   OpenRouter   https://openrouter.ai/docs/api-reference/overview
#   Groq         https://console.groq.com/docs/openai
#   Together     https://docs.together.ai/docs/openai-api-compatibility
#   Fireworks    https://docs.fireworks.ai/tools-sdks/openai-compatibility
#   DeepSeek     https://api-docs.deepseek.com/
#   Mistral      https://docs.mistral.ai/api/
#   xAI          https://docs.x.ai/docs/api-reference
#   Cerebras     https://inference-docs.cerebras.ai/resources/openai
#   Perplexity   https://docs.perplexity.ai/docs/sonar/openai-compatibility (POST /chat/completions)
#   Hugging Face https://huggingface.co/docs/inference-providers (router.huggingface.co/v1, HF_TOKEN)
#   OpenCode Zen https://opencode.ai/docs/zen/ (opencode.ai/zen/v1, OPENCODE_API_KEY)
#   Cohere       https://docs.cohere.com/docs/compatibility-api (api.cohere.ai/compatibility/v1)
#   NVIDIA NIM   https://docs.api.nvidia.com/nim/reference/llm-apis (integrate.api.nvidia.com/v1)
# A provider not listed here that speaks the OpenAI format (a company gateway, Azure's v1 endpoint,
# LM Studio, vLLM, llama.cpp) is the "own" route: own.url, own.key, own.model.

.bl_llm_presets <- function() {
  p <- function(id, label, base, api, key_env, alt_env = "", default_model = NA_character_, models = TRUE) {
    data.frame(id = id, label = label, base = base, api = api, key_env = key_env, alt_env = alt_env,
               default_model = default_model, models = models, stringsAsFactors = FALSE)
  }
  rbind(
    p("openai", "OpenAI", "https://api.openai.com/v1", "openai", "OPENAI_API_KEY"),
    p("anthropic", "Anthropic", "https://api.anthropic.com", "anthropic", "ANTHROPIC_API_KEY",
      default_model = "claude-opus-5-5"),
    p("gemini", "Google Gemini", "https://generativelanguage.googleapis.com", "gemini", "GEMINI_API_KEY",
      alt_env = "GOOGLE_API_KEY"),
    p("openrouter", "OpenRouter", "https://openrouter.ai/api/v1", "openai", "OPENROUTER_API_KEY"),
    p("groq", "Groq", "https://api.groq.com/openai/v1", "openai", "GROQ_API_KEY"),
    p("together", "Together AI", "https://api.together.xyz/v1", "openai", "TOGETHER_API_KEY"),
    p("fireworks", "Fireworks AI", "https://api.fireworks.ai/inference/v1", "openai", "FIREWORKS_API_KEY"),
    p("deepseek", "DeepSeek", "https://api.deepseek.com/v1", "openai", "DEEPSEEK_API_KEY"),
    p("mistral", "Mistral", "https://api.mistral.ai/v1", "openai", "MISTRAL_API_KEY"),
    p("xai", "xAI", "https://api.x.ai/v1", "openai", "XAI_API_KEY"),
    p("cerebras", "Cerebras", "https://api.cerebras.ai/v1", "openai", "CEREBRAS_API_KEY"),
    p("perplexity", "Perplexity", "https://api.perplexity.ai", "openai", "PERPLEXITY_API_KEY",
      default_model = "sonar-pro", models = FALSE),
    p("huggingface", "Hugging Face", "https://router.huggingface.co/v1", "openai", "HF_TOKEN",
      alt_env = "HUGGINGFACE_HUB_TOKEN"),
    p("opencode", "OpenCode Zen", "https://opencode.ai/zen/v1", "openai", "OPENCODE_API_KEY"),
    p("cohere", "Cohere", "https://api.cohere.ai/compatibility/v1", "openai", "COHERE_API_KEY",
      alt_env = "CO_API_KEY"),
    p("nvidia", "NVIDIA NIM", "https://integrate.api.nvidia.com/v1", "openai", "NVIDIA_API_KEY")
  )
}

.bl_preset <- function(id) {
  ps <- .bl_llm_presets()
  ps[match(id, ps$id), , drop = FALSE]
}

# The settings variable that holds a provider's model, e.g. MORIE_ANTHROPIC_MODEL.
.bl_preset_model_env <- function(id) paste0("MORIE_", toupper(id), "_MODEL")

# A provider's key: its variable, the alternative spelling, else the value saved with
# `rmbl config set <id>.key`. NULL when none is set.
.bl_preset_key <- function(id) {
  pr <- .bl_preset(id)
  for (e in c(pr$key_env, if (nzchar(pr$alt_env)) pr$alt_env)) {
    v <- trimws(Sys.getenv(e, unset = ""))
    if (nzchar(v)) return(.bl_key_text(v, e))
  }
  .bl_key_text(.bl_config_value(pr$key_env), paste0(id, ".key"))
}

# A key is one line of printable text: a line break or control character inside one would go to
# the wire as a second request header (review of 29a55d8, L3). NULL passes through.
.bl_key_text <- function(key, what) {
  if (!is.null(key) && grepl("[[:cntrl:]]", key)) {
    stop(sprintf("%s has a line break or control character in it: set it to the key alone", what), call. = FALSE)
  }
  key
}

# The route for a provider: list(name, id, api, base, key, model, local = FALSE), or NULL when no key.
.bl_provider_route <- function(id) {
  pr <- .bl_preset(id)
  key <- .bl_preset_key(id)
  if (is.null(key)) return(NULL)
  model <- .bl_env1(.bl_preset_model_env(id)) %||% (if (!is.na(pr$default_model)) pr$default_model)
  list(name = pr$label, id = id, api = pr$api, base = pr$base, key = key, model = model, local = FALSE,
       models_endpoint = isTRUE(pr$models))
}

# The request headers a route needs: its key in the provider's own header.
.bl_llm_headers <- function(rt) {
  key <- rt$key
  switch(rt$api %||% "openai",
    anthropic = c(if (!is.null(key)) paste("x-api-key:", key), "anthropic-version: 2023-06-01"),
    gemini = if (!is.null(key)) paste("x-goog-api-key:", key),
    .bl_bearer(key))
}

# The base the OpenAI-format paths hang off: a preset's documented base (with its /v1 when it has
# one), or the own/Ollama address with /v1 added (those are stored without it).
.bl_openai_base <- function(rt) {
  if (!is.null(rt$id)) rt$base else paste0(rt$base, "/v1")
}

# ---- one conversation format, three wire formats ---------------------------------------------
#
# A conversation is a list of messages, each a list with a role: "system" or "user" with
# content; "assistant" with content and tool_calls (each with id, name and arguments); "tool"
# with tool_call_id, name and content.
# A tool is list(name, description, parameters), parameters a JSON schema (as an R list).
# .bl_llm_chat() returns list(text, tool_calls, finish).

.bl_json_object <- function(x) if (length(x)) x else structure(list(), names = character())

.bl_openai_body <- function(model, messages, tools, max_tokens) {
  msgs <- lapply(messages, function(m) {
    if (identical(m$role, "tool")) {
      return(list(role = "tool", tool_call_id = m$tool_call_id, content = m$content))
    }
    out <- list(role = m$role, content = m$content %||% "")
    if (length(m$tool_calls)) {
      out$tool_calls <- lapply(m$tool_calls, function(tc) {
        list(id = tc$id, type = "function",
             `function` = list(name = tc$name,
                               arguments = as.character(bricklayer_json_to_json(.bl_json_object(tc$arguments),
                                                                                 auto_unbox = TRUE))))
      })
    }
    out
  })
  body <- list(model = model, messages = msgs, max_tokens = as.integer(max_tokens))
  if (length(tools)) {
    body$tools <- lapply(tools, function(t) {
      list(type = "function", `function` = list(name = t$name, description = t$description,
                                                parameters = t$parameters))
    })
  }
  body
}

.bl_openai_parse <- function(json) {
  if (!length(json$choices)) return(list(text = "", tool_calls = list(), finish = ""))
  ch <- json$choices[[1L]]
  msg <- ch$message
  calls <- lapply(msg$tool_calls %||% list(), function(tc) {
    args <- tc[["function"]]$arguments
    parsed <- if (is.character(args) && length(args) == 1L) {
      tryCatch(.rmbl_json_text(args, simplifyVector = FALSE), error = function(e) list())
    } else if (is.list(args)) {
      args
    } else {
      list()
    }
    list(id = as.character(tc$id %||% tc[["function"]]$name), name = as.character(tc[["function"]]$name %||% ""),
         arguments = if (is.list(parsed)) parsed else list())
  })
  txt <- msg$content
  list(text = if (is.character(txt)) paste(txt, collapse = "\n") else "", tool_calls = calls,
       finish = as.character(ch$finish_reason %||% ""))
}

.bl_anthropic_body <- function(model, messages, tools, max_tokens) {
  sys <- vapply(Filter(function(m) identical(m$role, "system"), messages), function(m) m$content, "")
  out <- list()
  for (m in Filter(function(m) !identical(m$role, "system"), messages)) {
    if (identical(m$role, "tool")) {
      block <- list(type = "tool_result", tool_use_id = m$tool_call_id, content = m$content)
      n <- length(out)
      # consecutive tool results travel in one user turn, as the API asks
      if (n && identical(out[[n]]$role, "user") && is.list(out[[n]]$content) &&
            identical(out[[n]]$content[[1L]]$type, "tool_result")) {
        out[[n]]$content[[length(out[[n]]$content) + 1L]] <- block
      } else {
        out[[n + 1L]] <- list(role = "user", content = list(block))
      }
    } else if (identical(m$role, "assistant")) {
      blocks <- list()
      if (nzchar(m$content %||% "")) blocks[[1L]] <- list(type = "text", text = m$content)
      for (tc in m$tool_calls) {
        blocks[[length(blocks) + 1L]] <- list(type = "tool_use", id = tc$id, name = tc$name,
                                              input = .bl_json_object(tc$arguments))
      }
      out[[length(out) + 1L]] <- list(role = "assistant", content = blocks)
    } else {
      out[[length(out) + 1L]] <- list(role = "user", content = m$content)
    }
  }
  body <- list(model = model, max_tokens = as.integer(max_tokens), messages = out)
  if (length(sys)) {
    body$system <- paste(sys, collapse = "\n\n")
    # instructions this long are the same every question: Anthropic keeps them for the next one when
    # asked (a prompt under 1,024 tokens is not cached, so a short one goes as it is)
    if (nchar(body$system) >= 4000L) {
      body$system <- list(list(type = "text", text = body$system, cache_control = list(type = "ephemeral")))
    }
  }
  if (length(tools)) {
    body$tools <- lapply(tools, function(t) {
      list(name = t$name, description = t$description, input_schema = t$parameters)
    })
  }
  body
}

.bl_anthropic_parse <- function(json) {
  txt <- character()
  calls <- list()
  for (b in json$content %||% list()) {
    if (identical(b$type, "text")) txt <- c(txt, as.character(b$text %||% ""))
    if (identical(b$type, "tool_use")) {
      calls[[length(calls) + 1L]] <- list(id = as.character(b$id), name = as.character(b$name),
                                          arguments = if (is.list(b$input)) b$input else list())
    }
  }
  list(text = paste(txt, collapse = "\n"), tool_calls = calls, finish = as.character(json$stop_reason %||% ""))
}

# Gemini's schema types are upper-case (OpenAPI's STRING, OBJECT ...).
.bl_gemini_schema <- function(s) {
  if (!is.list(s)) return(s)
  if (is.character(s$type)) s$type <- toupper(s$type)
  if (is.list(s$properties)) s$properties <- lapply(s$properties, .bl_gemini_schema)
  if (is.list(s$items)) s$items <- .bl_gemini_schema(s$items)
  s
}

.bl_gemini_body <- function(messages, tools, max_tokens) {
  sys <- vapply(Filter(function(m) identical(m$role, "system"), messages), function(m) m$content, "")
  contents <- list()
  for (m in Filter(function(m) !identical(m$role, "system"), messages)) {
    if (identical(m$role, "tool")) {
      part <- list(functionResponse = list(name = m$name, response = list(content = m$content)))
      n <- length(contents)
      if (n && identical(contents[[n]]$role, "user") && !is.null(contents[[n]]$parts[[1L]]$functionResponse)) {
        contents[[n]]$parts[[length(contents[[n]]$parts) + 1L]] <- part
      } else {
        contents[[n + 1L]] <- list(role = "user", parts = list(part))
      }
    } else if (identical(m$role, "assistant")) {
      parts <- list()
      if (nzchar(m$content %||% "")) parts[[1L]] <- list(text = m$content)
      for (tc in m$tool_calls) {
        parts[[length(parts) + 1L]] <- list(functionCall = list(name = tc$name, args = .bl_json_object(tc$arguments)))
      }
      contents[[length(contents) + 1L]] <- list(role = "model", parts = parts)
    } else {
      contents[[length(contents) + 1L]] <- list(role = "user", parts = list(list(text = m$content)))
    }
  }
  body <- list(contents = contents, generationConfig = list(maxOutputTokens = as.integer(max_tokens)))
  if (length(sys)) body$systemInstruction <- list(parts = list(list(text = paste(sys, collapse = "\n\n"))))
  if (length(tools)) {
    body$tools <- list(list(functionDeclarations = lapply(tools, function(t) {
      list(name = t$name, description = t$description, parameters = .bl_gemini_schema(t$parameters))
    })))
  }
  body
}

.bl_gemini_parse <- function(json) {
  if (!length(json$candidates)) return(list(text = "", tool_calls = list(), finish = ""))
  cand <- json$candidates[[1L]]
  txt <- character()
  calls <- list()
  for (p in cand$content$parts %||% list()) {
    if (!is.null(p$text)) txt <- c(txt, as.character(p$text))
    if (!is.null(p$functionCall)) {
      fc <- p$functionCall
      # Gemini's calls carry no id: the name and the position stand in for one
      calls[[length(calls) + 1L]] <- list(id = sprintf("%s-%d", fc$name, length(calls) + 1L),
                                          name = as.character(fc$name),
                                          arguments = if (is.list(fc$args)) fc$args else list())
    }
  }
  list(text = paste(txt, collapse = "\n"), tool_calls = calls, finish = as.character(cand$finishReason %||% ""))
}

# Where a route's chat request goes, and the body for it.
.bl_llm_request <- function(rt, model, messages, tools, max_tokens) {
  switch(rt$api %||% "openai",
    anthropic = list(url = paste0(rt$base, "/v1/messages"),
                     body = .bl_anthropic_body(model, messages, tools, max_tokens)),
    gemini = list(url = sprintf("%s/v1beta/models/%s:generateContent", rt$base,
                                utils::URLencode(sub("^models/", "", model), reserved = TRUE)),
                  body = .bl_gemini_body(messages, tools, max_tokens)),
    list(url = paste0(.bl_openai_base(rt), "/chat/completions"),
         body = .bl_openai_body(model, messages, tools, max_tokens)))
}

.bl_llm_parse <- function(rt, json) {
  switch(rt$api %||% "openai",
    anthropic = .bl_anthropic_parse(json),
    gemini = .bl_gemini_parse(json),
    .bl_openai_parse(json))
}

# What a person watching a terminal sees while the model works: "<model> is thinking", with a
# turning spinner and the seconds so far (drawn by the POST in src/rmbl_fetch.cpp, wiped when the
# reply comes). Nothing when nobody is watching or the session is quiet (the download bar's rule).
.bl_wait <- new.env(parent = emptyenv())

.bl_llm_wait_label <- function(model) {
  if (.bl_dl_quiet() || !.bl_stderr_tty()) return("")
  # the model's name can come from a server's own list (Ollama's /api/tags): printable or nothing
  paste(.rmbl_printable(model %||% "the model"), "is", .bl_wait$what %||% "thinking")
}

# One chat turn on a route: list(text, tool_calls, finish). No retry: the prompt goes once.
.bl_llm_chat <- function(rt, model, messages, tools = NULL, timeout = 120, max_tokens = 4096L, allow_empty = FALSE) {
  req <- .bl_llm_request(rt, model, messages, tools, max_tokens)
  lbl <- .bl_llm_wait_label(model %||% rt$model)
  if (nzchar(lbl)) {
    # the console's mode, as .bl_busy() passes it: c(colours, redraws, to stdout). The old logical
    # form always drew on stderr, which RStudio shows in the error colour
    con <- .bl_console()
    mode <- as.numeric(c(con$colors, TRUE, identical(con$out, "stdout")))
    .Call(C_rmbl_wait_label, lbl, con$unicode, mode)
    on.exit(.Call(C_rmbl_wait_label, "", con$unicode, mode), add = TRUE)
  }
  send <- function() {
    .bl_post_json(req$url, req$body, timeout = timeout, headers = .bl_llm_headers(rt), local = isTRUE(rt$local))
  }
  # one send, never two: a POST that timed out may have been read by the provider, and a retry
  # would send the prompt (and its cost) again (review of 46de6a9); the person asks again
  res <- send()
  if (!identical(res$status, 200L)) {
    if (isTRUE(res$status %in% c(400L, 403L, 404L))) {
      # a model the route does not have is often answered 400/403/404: name it, not the key
      have <- tryCatch(.bl_llm_list_models(rt), error = function(e) NULL)
      if (length(have) && !model %in% have) {
        stop(sprintf("%s has no model '%s' (`%s models --route %s` lists the %d it has)", .bl_route_what(rt),
                     model, .bl_prog(), .bl_route_id(rt), length(have)), call. = FALSE)
      }
    }
    .bl_reply_error(res, .bl_route_what(rt), secret = rt$key %||% "")
  }
  out <- .bl_llm_parse(rt, res$json)
  out$text <- .rmbl_printable(trimws(out$text), lines = TRUE)
  if (!allow_empty && !nzchar(out$text) && !length(out$tool_calls)) {
    stop(paste0(.bl_route_what(rt), " returned no text",
                if (nzchar(out$finish)) sprintf(" (finish reason: %s; try again, or another model)", out$finish)),
         call. = FALSE)
  }
  out
}

# The models a route offers, from the provider's own list (NULL when it has none to give).
.bl_llm_list_models <- function(rt, timeout = 15) {
  if (identical(rt$name, "local Ollama")) return(rt$models %||% .bl_ollama_tags(rt$base))
  if (!is.null(rt$id) && !isTRUE(rt$models_endpoint)) return(NULL)
  url <- switch(rt$api %||% "openai",
    anthropic = paste0(rt$base, "/v1/models?limit=1000"),
    gemini = paste0(rt$base, "/v1beta/models?pageSize=1000"),
    paste0(.bl_openai_base(rt), "/models"))
  get <- if (isTRUE(rt$local)) .bl_http_get_local else .bl_http_get
  res <- tryCatch(get(url, timeout, .bl_llm_headers(rt)), error = function(e) NULL)
  if (is.null(res) || !identical(as.integer(res$status), 200L)) return(NULL)
  j <- tryCatch(.rmbl_json_text(res$body, simplifyVector = FALSE), error = function(e) NULL)
  if (identical(rt$api, "gemini")) {
    ok <- Filter(function(m) "generateContent" %in% unlist(m$supportedGenerationMethods), j$models %||% list())
    return(.rmbl_printable(sub("^models/", "", vapply(ok, function(m) as.character(m$name %||% ""), ""))))
  }
  ids <- vapply(j$data %||% list(), function(m) as.character(m$id %||% "")[1L], "")
  .rmbl_printable(ids[nzchar(ids)])
}

# A route in a sentence: "the own endpoint", "the local Ollama", but "OpenAI".
.bl_route_what <- function(rt) if (is.null(rt$id)) paste("the", rt$name) else rt$name

# The name `--route` takes for a route.
.bl_route_id <- function(rt) rt$id %||% (if (identical(rt$name, "local Ollama")) "ollama" else "own")
