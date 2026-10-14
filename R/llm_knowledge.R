# SPDX-License-Identifier: AGPL-3.0-or-later
#
# What a language model knows about the MORIE packages when you ask it something: the installed
# help pages themselves, read where R keeps them (tools::Rd_db), so the knowledge is always the
# version you have installed and nothing is shipped twice. The model gets an index of every
# exported function (name, arguments, title) in its system prompt, and five read-only tools to
# look further: search the help, read a page, read its examples, list the datasets and read a
# vignette. A model that cannot call tools (many small local ones) gets the pages that match the
# question instead, found by a BM25 search over the help text in R. Nothing here runs code: the
# model answers with code for you to run.

.bl_kn_cache <- new.env(parent = emptyenv())

# A package with more help pages than this is searched, not listed in full.
.bl_kn_list_max <- 800L

# The MORIE packages installed here whose help the model gets (rmorie, with its thousands of
# pages, is searched by the tools; only its functions nearest the question are listed).
.bl_kn_default_packages <- function() {
  pk <- c("rmoriebricklayer", "rmoriedata", "rmorie")
  pk[vapply(pk, function(p) nzchar(system.file(package = p)), logical(1))]
}

.bl_rd_plain <- function(x) {
  if (is.character(x)) return(paste(x, collapse = ""))
  tag <- attr(x, "Rd_tag") %||% ""
  if (identical(tag, "COMMENT")) return("")
  paste(vapply(x, .bl_rd_plain, ""), collapse = "")
}

.bl_rd_section <- function(rd, tag) {
  hit <- rd[.bl_rd_tags(rd) == tag]
  if (!length(hit)) return("")
  trimws(gsub("[[:space:]]+", " ", .bl_rd_plain(hit[[1L]])))
}

.bl_kn_tokens <- function(x) {
  w <- strsplit(tolower(x), "[^a-z0-9_]+")[[1L]]
  w <- w[nchar(w) >= 2L]
  stop_words <- c("the", "of", "and", "to", "in", "is", "for", "an", "or", "by", "on", "be", "as", "it", "at",
                  "with", "from", "that", "this", "are", "its", "when", "which", "not", "one", "each", "if",
                  "can", "do", "does", "how", "what", "use", "using", "my", "me", "into", "per",
                  "function", "functions", "package", "packages", "want", "need", "way", "there", "any", "some")
  w <- w[!w %in% stop_words]
  # a light stem, so "emissions" finds "emission" and "testing" finds "test": the same word in
  # the question and on the page, however each is inflected
  long <- nchar(w) > 4L
  w[long] <- sub("ies$", "y", w[long])
  w[long] <- sub("([^su])s$", "\\1", w[long])
  long <- nchar(w) > 5L
  w[long] <- sub("(ing|ed)$", "", w[long])
  w
}

# The help pages of one installed package: one record per page (name, aliases, title,
# description, usage, exported, tokens), cached for the session and the installed version.
.bl_kn_pages <- function(pkg) {
  ver <- tryCatch(as.character(utils::packageVersion(pkg)), error = function(e) "")
  key <- paste(pkg, ver)
  if (!is.null(.bl_kn_cache[[key]])) return(.bl_kn_cache[[key]])
  db <- if (identical(pkg, "rmoriebricklayer")) .bl_rd_db() else
    tryCatch(tools::Rd_db(pkg), error = function(e) list())
  exports <- tryCatch(getNamespaceExports(pkg), error = function(e) character())
  pages <- list()
  for (f in names(db)) {
    rd <- db[[f]]
    kw <- unlist(lapply(rd[.bl_rd_tags(rd) == "\\keyword"], .bl_rd_plain))
    if ("internal" %in% trimws(kw)) next
    al <- .bl_rd_aliases(rd)
    exp <- intersect(al, exports)
    title <- .bl_rd_section(rd, "\\title")
    desc <- .bl_rd_section(rd, "\\description")
    usage <- .bl_rd_section(rd, "\\usage")
    text <- paste(title, title, title, paste(al, collapse = " "), paste(al, collapse = " "), desc, usage,
                  .bl_rd_plain(rd[!.bl_rd_tags(rd) %in% c("\\examples", "\\alias", "\\name")]))
    pages[[length(pages) + 1L]] <- list(pkg = pkg, file = f, name = if (length(exp)) exp[[1L]] else al[[1L]],
                                        aliases = al, exported = exp, title = title, desc = desc, usage = usage,
                                        tokens = .bl_kn_tokens(text), rd = rd)
  }
  assign(key, pages, envir = .bl_kn_cache)
  pages
}

.bl_kn_all_pages <- function(pkgs) unlist(lapply(pkgs, .bl_kn_pages), recursive = FALSE)

# The call of `fn` in a usage section, its parentheses balanced (an argument default such as
# c("a", "b") holds its own), spaces inside the brackets dropped: "survey_design(data, weights, ...)".
.bl_kn_call <- function(usage, fn) {
  at <- regexpr(paste0(fn, "("), usage, fixed = TRUE)
  if (at < 0L) return(fn)
  ch <- strsplit(substring(usage, at), "")[[1L]]
  depth <- 0L
  for (i in seq_along(ch)) {
    if (ch[i] == "(") depth <- depth + 1L
    if (ch[i] == ")") {
      depth <- depth - 1L
      if (depth == 0L) break
    }
  }
  sig <- paste(ch[seq_len(i)], collapse = "")
  gsub(" +\\)", ")", gsub("\\( +", "(", sig))
}

# One line per exported function: name(arguments)  -- title. A long signature is cut.
.bl_kn_index_lines <- function(pages) {
  out <- character()
  for (p in pages) {
    for (fn in p$exported) {
      sig <- .bl_kn_call(p$usage, fn)
      if (nchar(sig) > 160L) sig <- paste0(substr(sig, 1L, 156L), "...)")
      out <- c(out, sprintf("%s  -- %s", sig, p$title))
    }
  }
  unique(out)
}

# BM25 over the pages' text: the best `k` pages for a query (k1 = 1.2, b = 0.75).
.bl_kn_search <- function(query, pages, k = 8L) {
  q <- unique(.bl_kn_tokens(query))
  if (!length(q) || !length(pages)) return(list())
  n <- length(pages)
  len <- vapply(pages, function(p) length(p$tokens), 1L)
  avg <- max(mean(len), 1)
  df <- vapply(q, function(t) sum(vapply(pages, function(p) t %in% p$tokens, logical(1))), 1L)
  idf <- log(1 + (n - df + 0.5) / (df + 0.5))
  score <- vapply(seq_len(n), function(i) {
    tf <- vapply(q, function(t) sum(pages[[i]]$tokens == t), 1L)
    sum(idf * tf * 2.2 / (tf + 1.2 * (1 - 0.75 + 0.75 * len[i] / avg)))
  }, 0)
  # a page named in the query comes first
  named <- vapply(pages, function(p) any(tolower(p$aliases) %in% q), logical(1))
  score <- score + ifelse(named, 100, 0)
  o <- order(-score)
  o <- o[score[o] > 0]
  pages[utils::head(o, k)]
}

.bl_kn_find <- function(name, pages) {
  hit <- Filter(function(p) name %in% p$aliases, pages)
  if (length(hit)) hit[[1L]] else NULL
}

.bl_kn_render <- function(p) paste(.bl_rd_text(p$rd), collapse = "\n")

.bl_kn_clip <- function(x, n = 9000L) if (nchar(x) > n) paste0(substr(x, 1L, n), "\n[... cut]") else x

# ---- the tools the model may call ------------------------------------------------------------

.bl_kn_tools <- function() {
  str <- function(d) list(type = "string", description = d)
  obj <- function(props, req) list(type = "object", properties = props, required = I(req))
  list(
    list(name = "search_docs", description = paste("Search the help pages of the MORIE R packages; returns the",
                                                   "best matching functions with their titles."),
         parameters = obj(list(query = str("what to look for, in plain words")), "query")),
    list(name = "get_help", description = "The full help page of one function: usage, arguments, value, details.",
         parameters = obj(list(name = str("the function name, e.g. survey_design")), "name")),
    list(name = "get_examples", description = "The runnable examples from one function's help page.",
         parameters = obj(list(name = str("the function name")), "name")),
    list(name = "list_datasets", description = paste("Datasets the packages ship or can load (bundled files and",
                                                     "the curated tables at data.rmorie.com), filtered by a word."),
         parameters = obj(list(filter = str("a word to filter by, or empty for all")), character())),
    list(name = "get_vignette", description = "A package vignette (a long worked guide); with no name, the list.",
         parameters = obj(list(name = str("the vignette name, or empty to list them")), character()))
  )
}

.bl_kn_datasets <- function(filter, pkgs) {
  out <- character()
  for (p in pkgs) {
    d <- system.file("extdata", package = p)
    if (nzchar(d)) out <- c(out, sprintf("%s: system.file(\"extdata\", \"%s\", package = \"%s\")", p,
                                         list.files(d), p))
  }
  # the curated tables, from the manifest already on disk (no network from a tool)
  m <- file.path(.bl_data_cache_dir(), "manifest.json")
  if (file.exists(m)) {
    j <- tryCatch(.rmbl_json_text(paste(readLines(m, warn = FALSE), collapse = "\n"), simplifyVector = FALSE),
                  error = function(e) NULL)
    for (d in j$datasets %||% list()) {
      out <- c(out, sprintf("data.rmorie.com: bricklayer_data_load(\"%s\")  %s", d$key %||% "",
                            substr(.bl_data_name(d), 1L, 90L)))
    }
  }
  if (nzchar(filter %||% "")) out <- out[grepl(filter, out, ignore.case = TRUE)]
  if (!length(out)) return("no dataset matches: simulate example data instead, and invent no dataset name")
  .bl_kn_clip(paste(utils::head(out, 200L), collapse = "\n"))
}

# The installed doc/ folder of each package ("" when it has none).
.bl_kn_doc_dir <- function(p) system.file("doc", package = p)

.bl_kn_vignette <- function(name, pkgs) {
  docs <- as.character(unlist(lapply(pkgs, function(p) {
    d <- .bl_kn_doc_dir(p)
    if (nzchar(d)) list.files(d, pattern = "[.](Rmd|R)$", full.names = TRUE)
  })))
  if (!length(docs)) return("no vignettes are installed with these packages")
  rmd <- docs[endsWith(docs, ".Rmd")]
  if (!nzchar(name %||% "")) {
    return(paste(sprintf("%s (%s)", sub("[.]Rmd$", "", basename(rmd)), basename(dirname(dirname(rmd)))),
                 collapse = "\n"))
  }
  hit <- rmd[sub("[.]Rmd$", "", basename(rmd)) == name]
  if (!length(hit)) return(sprintf("no vignette '%s'", name))
  .bl_kn_clip(paste(readLines(hit[[1L]], warn = FALSE), collapse = "\n"), 14000L)
}

# Run one tool call: always text, never an error (a bad call is answered in words). `clip` is the
# most text a page may return (smaller for a local model, whose context is small).
.bl_kn_run_tool <- function(call, pkgs, clip = 9000L) {
  a <- call$arguments
  arg <- function(n) {
    v <- a[[n]]
    if (is.character(v) && length(v) == 1L) v else ""
  }
  pages <- .bl_kn_all_pages(pkgs)
  missing <- function(nm) {
    if (!nzchar(nm)) return("give the function's name as a string (search_docs finds it)")
    sprintf("'%s' does not exist in these packages: do not use it (search_docs finds what does)", nm)
  }
  switch(call$name,
    search_docs = {
      hit <- .bl_kn_search(arg("query"), pages, 10L)
      if (!length(hit)) "nothing matches; try other words" else
        paste(vapply(hit, function(p) sprintf("%s (%s): %s", p$name, p$pkg, p$title), ""), collapse = "\n")
    },
    get_help = {
      p <- .bl_kn_find(arg("name"), pages)
      if (is.null(p)) missing(arg("name")) else .bl_kn_clip(.bl_kn_render(p), clip)
    },
    get_examples = {
      p <- .bl_kn_find(arg("name"), pages)
      if (is.null(p)) {
        missing(arg("name"))
      } else {
        txt <- .bl_rd_text(p$rd)
        s <- which(txt == "Examples:")
        if (!length(s)) "no examples on that page" else .bl_kn_clip(paste(txt[-seq_len(s[1L])], collapse = "\n"), clip)
      }
    },
    list_datasets = .bl_kn_datasets(arg("filter"), pkgs),
    get_vignette = .bl_kn_vignette(arg("name"), pkgs),
    sprintf("there is no tool '%s'", call$name))
}

# ---- the conversation ------------------------------------------------------------------------

# The instructions stay the same from one question to the next (the functions picked for a question
# travel with the question), so a server's prompt cache can reuse them: Ollama, OpenAI, DeepSeek and
# Gemini do it on their own for an unchanged start, Anthropic when asked (.bl_anthropic_body).
.bl_kn_system <- function(pkgs, index_lines, extra = NULL) {
  where <- if (length(index_lines)) "the index below lists every one" else
    "the ones nearest the question are listed with it, and search_docs finds the rest"
  paste(c(
    sprintf(paste("You help people use the R packages %s. Answer with short explanations and R code they can run.",
                  "When these packages have a function for the task (%s), use it rather",
                  "than another package's; load them with library(%s). Otherwise use base R. Never invent a function,",
                  "an argument, a package or a dataset. Before you give code that calls a package function, read its",
                  "help page (get_help); search_docs finds the right page when you are unsure of the name. Say plainly",
                  "when the packages cannot do something. Only these packages are installed: load no other MORIE",
                  "package. For example data, simulate it, or use a dataset that list_datasets names. Never say the",
                  "packages lack something before search_docs has looked for it under other words (a synonym, the",
                  "thing measured, the field it belongs to); the pages listed with the question are where to start."),
            paste(pkgs, collapse = " and "), where, pkgs[[1L]]),
    extra,
    if (length(index_lines)) c("", "Exported functions (name(arguments)  -- title):", index_lines)), collapse = "\n")
}

# A model that says it cannot take tools (HTTP 400 naming them, as Ollama and many servers answer)
.bl_kn_no_tools <- function(e) {
  grepl("(?i)\\b(tools?|tool_choice|function[ _]?call(ing)?|functions)\\b", conditionMessage(e), perl = TRUE) &&
    grepl("(?i)answered 4[0-9][0-9]", conditionMessage(e), perl = TRUE)
}

# How much the model can take in, in tokens: what decides how much of the help goes into its
# instructions. A provider's model (any key you bring) and a model Ollama serves from its cloud
# (minimax-m3:cloud reports 512,000) have room for all of it. A model Ollama runs on this machine
# or the LAN works in Ollama's own context window, 4,096 tokens unless the server was started with
# OLLAMA_CONTEXT_LENGTH, whatever the model could take, and on a CPU it reads the whole prompt
# again every round. Your own endpoint is taken as large when it is remote and as 8,192 when it is
# on this machine (LM Studio and llama.cpp start small too). MORIE_LLM_CONTEXT (tokens) overrides.
.bl_llm_capacity <- function(rt, model) {
  set <- suppressWarnings(as.numeric(.bl_env1("MORIE_LLM_CONTEXT") %||% NA))
  if (is.finite(set) && set > 0) return(set)
  if (!is.null(rt$id)) return(128000)
  if (identical(rt$name, "local Ollama")) {
    # ollama.com itself (OLLAMA_HOST=https://ollama.com with OLLAMA_API_KEY), or any Ollama not on
    # this machine or the LAN, is the server's business: its models run in their own context
    if (model %in% (rt$remote %||% character()) || !isTRUE(rt$local)) {
      v <- unname((rt$context %||% c())[model])
      return(if (length(v) && is.finite(v)) v else 128000)
    }
    srv <- suppressWarnings(as.numeric(Sys.getenv("OLLAMA_CONTEXT_LENGTH", unset = NA)))
    return(if (is.finite(srv) && srv > 0) srv else 4096)
  }
  if (isTRUE(rt$local)) 8192 else 128000
}

# What a context of that size gets: the whole index of every function with full help pages and six
# rounds of lookups; or, for a small one, the functions nearest the question, shorter pages and
# fewer rounds. Every tier can still reach every function: search_docs and get_help look up any
# page of the packages.
.bl_llm_tier <- function(tokens) {
  if (tokens >= 32000) return(list(name = "full", index = Inf, clip = 9000L, rounds = 6L, pages = 6L))
  if (tokens >= 8000) return(list(name = "compact", index = 120L, clip = 4000L, rounds = 4L, pages = 4L))
  list(name = "small", index = 40L, clip = 2500L, rounds = 3L, pages = 2L)
}

# Ask with the packages' help at hand: tools when the model takes them, else the matching pages in
# the prompt. Returns the reply text.
.bl_llm_assist <- function(rt, model, prompt, pkgs, system_extra = NULL, timeout = 120, max_rounds = NULL) {
  pages <- .bl_kn_all_pages(pkgs)
  tier <- .bl_llm_tier(.bl_llm_capacity(rt, model))
  # a package with thousands of pages (rmorie) is not listed whole: its functions nearest the
  # question are, and the tools reach the rest
  big <- names(which(table(vapply(pages, function(p) p$pkg, "")) > .bl_kn_list_max))
  listed <- Filter(function(p) p$pkg %in% pkgs && !p$pkg %in% big, pages)
  near_big <- if (length(big)) .bl_kn_search(prompt, Filter(function(p) p$pkg %in% big, pages), 40L) else list()
  # the index that does not depend on the question goes into the instructions; the functions
  # picked for this question (all of them for a small model) go with the question
  index <- .bl_kn_index_lines(listed)
  near <- near_big
  if (length(index) + length(near) > tier$index) {
    index <- character()
    near <- .bl_kn_search(prompt, pages, tier$index)
  }
  clip <- tier$clip
  max_rounds <- max_rounds %||% tier$rounds
  if (length(big)) {
    system_extra <- c(system_extra, sprintf(paste("%s has %d more functions than are listed below: search_docs finds",
                                                  "the right one by what it does, and get_help reads it."),
                                            paste(big, collapse = " and "),
                                            sum(vapply(pages, function(p) p$pkg %in% big, NA)) - length(near_big)))
  }
  sys <- .bl_kn_system(pkgs, index, system_extra)
  # the help pages closest to the question go with it for every model, so a large one starts from
  # them too instead of from memory
  if (!length(near)) near <- .bl_kn_search(prompt, pages, 6L)
  ask <- prompt
  if (length(near)) {
    ask <- paste(c(prompt, "", "Functions nearest this question (name(arguments)  -- title):",
                   .bl_kn_index_lines(near)), collapse = "\n")
  }
  msgs <- list(list(role = "system", content = sys), list(role = "user", content = ask))
  tools <- .bl_kn_tools()
  looked <- 0L
  on.exit(.bl_wait$what <- NULL, add = TRUE)
  for (round in seq_len(max_rounds)) {
    res <- tryCatch(.bl_llm_chat(rt, model, msgs, tools = tools, timeout = timeout, allow_empty = TRUE),
                    error = function(e) e)
    if (inherits(res, "error")) {
      if (round == 1L && .bl_kn_no_tools(res)) {
        return(.bl_llm_assist_plain(rt, model, prompt, pkgs, sys, timeout, tier))
      }
      stop(res)
    }
    if (!length(res$tool_calls)) {
      if (nzchar(res$text)) return(res$text)
      break  # an empty turn after its lookups: asked once more below, for the answer itself
    }
    msgs[[length(msgs) + 1L]] <- list(role = "assistant", content = res$text, tool_calls = res$tool_calls)
    for (tc in res$tool_calls) {
      msgs[[length(msgs) + 1L]] <- list(role = "tool", tool_call_id = tc$id, name = tc$name,
                                        content = .bl_kn_run_tool(tc, pkgs, clip))
    }
    looked <- looked + length(res$tool_calls)
    .bl_wait$what <- sprintf("thinking (%d help %s read so far)", looked, if (looked == 1L) "page" else "pages")
  }
  # the rounds are spent, or a turn came back empty: one last turn without tools, so an answer comes back
  msgs[[length(msgs) + 1L]] <- list(role = "user", content = "Answer now with what you have found.")
  .bl_llm_chat(rt, model, msgs, timeout = timeout)$text
}

# No tools: the pages that match the question go into the prompt.
.bl_llm_assist_plain <- function(rt, model, prompt, pkgs, sys, timeout, tier = .bl_llm_tier(128000)) {
  hit <- .bl_kn_search(prompt, .bl_kn_all_pages(pkgs), tier$pages)
  ctx <- vapply(hit, function(p) .bl_kn_clip(.bl_kn_render(p), tier$clip), "")
  sys2 <- paste(c(sys, "", "Help pages that match the question:", ctx), collapse = "\n\n")
  .bl_llm_chat(rt, model, list(list(role = "system", content = sys2), list(role = "user", content = prompt)),
               timeout = timeout)$text
}
