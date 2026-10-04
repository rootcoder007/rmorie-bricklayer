# SPDX-License-Identifier: AGPL-3.0-or-later
#
# The rmoriebricklayer command line, shipped inside the package.
# `inst/bin/rmoriebricklayer` is a two-line launcher that runs
# bricklayer_cli() through Rscript; install_cli() links it into a
# directory on PATH (an R package cannot install executables itself,
# and it only does so when the user calls install_cli()).

#' Run the rmoriebricklayer command line
#'
#' Dispatches the verbs of the \code{rmoriebricklayer} launcher:
#' \describe{
#'   \item{\code{login [--token [KEY]] [--email ADDRESS [--code CODE]]
#'     [--no-browser]}}{sign in to the hosted MORIE LLM tier: the GitHub
#'     device flow by default, a code sent to \code{--email}, or a key
#'     you paste with \code{--token} (prompts when KEY is omitted)}
#'   \item{\code{logout}}{forget the hosted key}
#'   \item{\code{doctor}}{report the language-model routes available here}
#'   \item{\code{models}}{list the models the hosted tier offers your key
#'     (default marked)}
#'   \item{\code{data list}}{the curated tables at data.rmorie.com}
#'   \item{\code{data pull db/table}}{download one table as CSV}
#'   \item{\code{ask [--model NAME] PROMPT...}}{send a prompt to the model
#'     (or the named one) and print the
#'     reply}
#'   \item{\code{bundle REQUEST...}}{\code{\link{agent_bundle}} from the
#'     shell}
#'   \item{\code{functions [PATTERN]}}{list the exported functions with
#'     their one-line titles, optionally filtered by a regular expression}
#'   \item{\code{describe NAME}}{title, usage, arguments and description of
#'     one function, from its help page}
#'   \item{\code{examples NAME}}{print the examples of one function}
#'   \item{\code{version}}{print the package version}
#'   \item{\code{help}}{this list}
#' }
#' @param args Character vector of arguments; defaults to the command line.
#' @param out Function that receives the output text (default: the
#'   console).
#' @return The exit status, invisibly (0 on success).
#' @examples
#' bricklayer_cli("version")
#' bricklayer_cli("help")
#' bricklayer_cli(c("functions", "json"))
#' bricklayer_cli(c("describe", "analyse_table"))
#' @export
bricklayer_cli <- function(args = commandArgs(trailingOnly = TRUE),
                           out = cat) {
  old_progress <- options(morie.progress = TRUE)  # downloads draw their bar
  on.exit(options(old_progress), add = TRUE)
  args <- as.character(args)
  if (length(args) && identical(args[[1L]], "--args")) args <- args[-1L]  # R >= 4.6 keeps the separator
  verb <- if (length(args)) args[[1L]] else "help"
  rest <- args[-1L]
  prog <- .bl_prog()
  usage_error <- function(msg) {
    stop(structure(class = c("bl_usage", "error", "condition"), list(message = msg, call = NULL)))
  }
  flag <- function(name) {
    i <- match(name, rest)
    if (is.na(i)) {
      return(NULL)
    }
    if (i == length(rest) || startsWith(rest[[i + 1L]], "--")) {
      usage_error(sprintf("%s needs a value", name))
    }
    rest[[i + 1L]]
  }
  has <- function(name) name %in% rest
  # `VERB --help` describes the verb and never runs it (logout --help used to forget the key)
  if (!verb %in% c("help", "--help", "-h") && any(rest %in% c("--help", "-h"))) {
    u <- .bl_verb_usage(verb, prog)
    if (is.null(u)) {
      out(sprintf("%s: unknown verb '%s' (try: %s help)\n", prog, verb, prog))
      return(invisible(2L))
    }
    out(u)
    return(invisible(0L))
  }
  status <- 0L
  tryCatch(
    {
      switch(verb,
        login = {
          if (has("--token")) {
            i <- match("--token", rest)
            tok <- if (i < length(rest)) rest[[i + 1L]] else ""
            # readline() answers "" at once when nobody can type (Rscript, a pipe): no hang, a usage error
            if (!nzchar(tok)) tok <- trimws(readline("Paste your MORIE key: "))
            if (!nzchar(tok)) {
              usage_error("--token needs a value: login --token KEY (or run it in a terminal to paste it)")
            }
            .bl_check_token(tok)
            bricklayer_llm_login(token = tok)
          } else {
            if (has("--code") && is.null(flag("--email"))) {
              usage_error("--code needs --email ADDRESS (the code was sent there)")
            }
            bricklayer_llm_login(
              email = flag("--email"), code = flag("--code"),
              open_browser = !has("--no-browser") &&
                interactive()
            )
          }
          out(sprintf("Logged in to %s\n", .bl_hosted_base() %||% "(disabled)"))
        },
        logout = bricklayer_llm_logout(),
        doctor = {
          st <- bricklayer_llm_status()
          for (i in seq_len(nrow(st))) {
            out(sprintf(
              "  %-20s %-16s %s\n", st$route[i], st$status[i],
              st$detail[i]
            ))
          }
        },
        models = .bl_cli_models(out),
        ask = {
          mdl <- flag("--model")
          if (!is.null(mdl)) rest <- rest[-(match("--model", rest) + 0:1)]
          if (!length(rest)) {
            usage_error(sprintf("usage: %s ask [--model NAME] PROMPT...", prog))
          } else {
            prompt <- paste(rest, collapse = " ")
            out(paste0(bricklayer_llm_ask(prompt, model = mdl), "\n"))
          }
        },
        bundle = {
          if (!length(rest)) {
            usage_error(sprintf("usage: %s bundle REQUEST...", prog))
          }
          out(paste0(agent_bundle(paste(rest, collapse = " ")), "\n"))
        },
        functions = {
          tab <- .bl_function_index(if (length(rest)) rest[[1L]] else NULL)
          if (!nrow(tab)) {
            out("no exported function matches\n")
          } else {
            w <- max(nchar(tab$name))
            for (i in seq_len(nrow(tab))) {
              out(sprintf(
                paste0("  %-", w, "s  %s\n"), tab$name[i],
                tab$title[i]
              ))
            }
          }
        },
        describe = {
          if (!length(rest)) {
            usage_error(sprintf("usage: %s describe NAME", prog))
          }
          if (is.null(.bl_rd_for(rest[[1L]]))) {
            out(sprintf("no help page for '%s' (%s functions lists them)\n", rest[[1L]], prog))
            status <- 1L
          } else {
            out(.bl_describe(rest[[1L]]))
          }
        },
        examples = {
          if (!length(rest)) {
            usage_error(sprintf("usage: %s examples NAME", prog))
          }
          if (is.null(.bl_rd_for(rest[[1L]]))) {
            out(sprintf("no help page for '%s' (%s functions lists them)\n", rest[[1L]], prog))
            status <- 1L
          } else {
            out(.bl_examples(rest[[1L]]))
          }
        },
        data = status <- .bl_cli_data(rest, flag, out),
        `--version` = ,
        `-v` = ,
        version = out(sprintf("rmoriebricklayer %s\n", as.character(
          utils::packageVersion("rmoriebricklayer")
        ))),
        help = ,
        `--help` = ,
        `-h` = out(paste0(
          sprintf("usage: %s <verb> [options]   (rmbl is the same command as rmoriebricklayer)\n\n", prog),
          "  login [--email ADDRESS] [--token [KEY]]   sign in to the hosted ",
          "MORIE LLM tier\n",
          "        [--code CODE] [--no-browser]\n",
          "  logout                                    forget the hosted key\n",
          "  doctor                                    language-model routes ",
          "available here\n",
          "  models                                    models the hosted tier ",
          "offers your key\n",
          "  ask [--model NAME] PROMPT...              ask the model\n",
          "  bundle REQUEST...                         agent_bundle() from ",
          "the ",
          "shell\n",
          "  functions [PATTERN]                       exported functions and ",
          "their titles\n",
          "  describe NAME                             help page of one ",
          "function\n",
          "  examples NAME                             its examples\n",
          "  data list                                 curated tables at ",
          "data.rmorie.com\n",
          "  data pull db/table [--out FILE.csv]       download one of them ",
          "(your MORIE key)\n",
          "  version                                   package version\n"
        )),
        usage_error(sprintf("unknown verb '%s' (try: %s help)", verb, prog))
      )
    },
    error = function(e) {
      out(paste0(prog, ": ", conditionMessage(e), "\n"))
      status <<- if (inherits(e, "bl_usage")) 2L else 1L
    }
  )
  invisible(status)
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# One usage line per verb, for `VERB --help`; NULL for a verb that does not exist.
.bl_verb_usage <- function(verb, prog = "rmoriebricklayer") {
  u <- c(
    login = paste("login [--email ADDRESS [--code CODE]] [--no-browser] | login --token KEY",
                  "  sign in to the hosted MORIE LLM tier"),
    logout = "logout   forget the hosted key",
    doctor = "doctor   report the language-model routes available here",
    models = "models   the models the hosted tier offers your key (default marked)",
    ask = "ask [--model NAME] PROMPT...   ask the model",
    bundle = "bundle REQUEST...   agent_bundle() from the shell",
    functions = "functions [PATTERN]   exported functions and their titles",
    describe = "describe NAME   help page of one function",
    examples = "examples NAME   the examples of one function",
    data = "data list | data pull db/table [--out FILE.csv]   curated tables at data.rmorie.com (your MORIE key)",
    version = "version   package version"
  )
  if (!verb %in% names(u)) return(NULL)
  sprintf("usage: %s %s\n", prog, u[[verb]])
}

# The Rd database of this package: the installed copy when there is one,
# else the man/ directory of a source tree loaded with pkgload.
.bl_rd_db <- function() {
  db <- tryCatch(tools::Rd_db("rmoriebricklayer"), error = function(e) NULL)
  if (length(db)) {
    return(db)
  }
  man <- system.file("man", package = "rmoriebricklayer")
  if (nzchar(man)) {
    db <- tryCatch(tools::Rd_db(dir = dirname(man)), error = function(e) NULL)
  }
  if (length(db)) db else list()
}

.bl_rd_tags <- function(rd) {
  vapply(rd, function(x) attr(x, "Rd_tag") %||% "", "")
}

.bl_rd_aliases <- function(rd) {
  al <- rd[.bl_rd_tags(rd) == "\\alias"]
  unlist(lapply(al, function(a) as.character(a[[1L]])))
}

.bl_rd_for <- function(name) {
  for (rd in .bl_rd_db()) {
    if (name %in% .bl_rd_aliases(rd)) {
      return(rd)
    }
  }
  NULL
}

# Rd2txt renders a whole page; sections come back headed "Usage:",
# "Arguments:", "Examples:" when underlining is off.
.bl_rd_text <- function(rd) {
  txt <- utils::capture.output(
    tools::Rd2txt(rd, options = list(underline_titles = FALSE, width = 78))
  )
  txt
}

.bl_function_index <- function(pattern = NULL) {
  ns <- getNamespaceExports("rmoriebricklayer")
  ns <- sort(ns[!startsWith(ns, ".")])
  if (!is.null(pattern)) ns <- ns[grepl(pattern, ns)]
  titles <- character(length(ns))
  names(titles) <- ns
  for (rd in .bl_rd_db()) {
    hit <- intersect(.bl_rd_aliases(rd), ns)
    if (!length(hit)) next
    ti <- which(.bl_rd_tags(rd) == "\\title")
    if (length(ti)) {
      titles[hit] <- trimws(paste(as.character(unlist(rd[[ti[1L]]])),
        collapse = ""
      ))
    }
  }
  data.frame(name = ns, title = unname(titles), stringsAsFactors = FALSE)
}

.bl_describe <- function(name) {
  rd <- .bl_rd_for(name)
  if (is.null(rd)) {
    return(sprintf("no help page for '%s'\n", name))
  }
  txt <- .bl_rd_text(rd)
  cut <- which(txt == "Examples:")
  if (length(cut)) txt <- txt[seq_len(cut[1L] - 1L)]
  paste0(paste(txt, collapse = "\n"), "\n")
}

.bl_examples <- function(name) {
  rd <- .bl_rd_for(name)
  if (is.null(rd)) {
    return(sprintf("no help page for '%s'\n", name))
  }
  txt <- .bl_rd_text(rd)
  start <- which(txt == "Examples:")
  if (!length(start)) {
    return(sprintf("'%s' has no examples\n", name))
  }
  paste0(paste(txt[-seq_len(start[1L])], collapse = "\n"), "\n")
}

#' Install the rmoriebricklayer command-line launcher
#'
#' Links the launcher shipped in the package (\code{inst/bin/rmoriebricklayer})
#' into a directory on your PATH so that \code{rmoriebricklayer login},
#' \code{rmbl ask ...} and the other verbs of
#' \code{\link{bricklayer_cli}} work from any shell. On Windows a
#' \code{rmoriebricklayer.cmd} wrapper is written instead of a symlink.
#' Nothing outside \code{dir} is touched, and only when you call this.
#' @param dir Target directory (default \code{~/.local/bin}; created if
#'   absent).
#' @param name Command names to install (default both \code{rmoriebricklayer}
#'   and its short form \code{rmbl}; every verb works under either).
#' @return The path of the installed \code{rmoriebricklayer} launcher,
#'   invisibly (\code{rmbl} is written beside it).
#' @examples
#' \dontrun{
#' install_cli()
#' }
#' @export
install_cli <- function(dir = file.path(path.expand("~"), ".local", "bin"),
                        name = c("rmoriebricklayer", "rmbl")) {
  src <- system.file("bin", "rmoriebricklayer", package = "rmoriebricklayer")
  if (!nzchar(src)) stop("the launcher is missing from this installation")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  # the launcher pins the library this copy of the package lives in, inside R with .libPaths(),
  # so the shell's R_LIBS or an R_LIBS in ~/.Renviron cannot swap in another copy
  lib <- normalizePath(dirname(system.file(package = "rmoriebricklayer")), winslash = "/")
  targets <- character()
  for (nm in name) {
    if (.Platform$OS.type == "windows") {
      # nocov start -- the Windows wrapper; the coverage runner is Linux
      target <- file.path(dir, paste0(nm, ".cmd"))
      writeLines(sprintf(paste0("@echo off\r\nset RMBL_PROG=", nm, "\r\nRscript --no-save --no-restore -e ",
                                "\".libPaths(c('%s', .libPaths())); ",
                                "q <- rmoriebricklayer::bricklayer_cli(); quit(status = as.integer(q))\" %%*"),
                         lib), target)
      # nocov end
    } else {
      target <- file.path(dir, nm)
      if (file.exists(target) || !is.na(Sys.readlink(target))) unlink(target)
      body <- paste0("suppressPackageStartupMessages({ .libPaths(c(\"", lib, "\", .libPaths())); ",
                     "q <- rmoriebricklayer::bricklayer_cli(); quit(status = as.integer(q)) })")
      writeLines(c("#!/bin/sh",
                   sprintf("# %s: the rmoriebricklayer command line (written by rmoriebricklayer::install_cli())", nm),
                   sprintf("# runs the package in %s (pinned with .libPaths() inside R)", lib),
                   sprintf("export RMBL_PROG=%s", nm),
                   sprintf("exec Rscript --no-save --no-restore -e '%s' \"$@\"", body)),
                 target)
      Sys.chmod(target, "0755")
    }
    targets <- c(targets, target)
  }
  on_path <- dir %in% strsplit(Sys.getenv("PATH"), .Platform$path.sep)[[1L]]
  message(sprintf(
    "Installed %s%s", paste(targets, collapse = " and "),
    if (on_path) "" else sprintf("; add %s to your PATH", dir)
  ))
  invisible(targets[[1L]])  # the primary launcher's path; rmbl sits beside it
}

# The models verb: the hosted tier's list for this key, default marked.
.bl_cli_models <- function(out) {
  if (is.null(.bl_hosted_base())) {
    out("Hosted MORIE tier: disabled (MORIE_HOSTED_BASE_URL=off)\n")
  } else if (is.null(.bl_hosted_key())) {
    out(sprintf("Hosted MORIE tier: not logged in -- %s login\n", .bl_prog()))
  } else {
    hm <- bricklayer_llm_models()
    state <- .bl_key_state(hm)
    if (identical(state, "rejected")) {
      out(sprintf(paste0("Hosted MORIE tier (%s): the gateway rejected the stored key ",
                         "(a newer sign-in elsewhere replaces it): run `%s login` again\n"),
                  .bl_hosted_base(), .bl_prog()))
    } else if (!length(hm)) {
      out(sprintf("Hosted MORIE tier (%s): logged in, gateway not reachable (network?); try again\n",
                  .bl_hosted_base()))
    } else {
      out(sprintf(
        "Hosted MORIE tier (%s); default marked *:\n",
        .bl_hosted_base()
      ))
      for (m in hm) {
        mark <- if (identical(m, attr(hm, "default"))) "*" else " "
        out(sprintf("  %s %s\n", mark, m))
      }
      out(paste0(
        sprintf("Pick one per call with `%s ask --model NAME ...`", .bl_prog()),
        ", or set MORIE_HOSTED_MODEL.\n"
      ))
    }
  }
}

# The data verb: the curated tables at data.rmorie.com.
.bl_cli_data <- function(rest, flag, out) {
  sub <- if (length(rest)) rest[[1L]] else "list"
  if (identical(sub, "list")) {
    tables <- bricklayer_data_tables()
    tbl <- utils::capture.output(print(tables, row.names = FALSE))
    out(paste0(paste(tbl, collapse = "\n"), "\n"))
  } else if (identical(sub, "pull") && length(rest) >= 2L) {
    df <- bricklayer_data_load(rest[[2L]])
    dest <- flag("--out") %||%
      paste0(gsub("[^A-Za-z0-9_.-]", "_", rest[[2L]]), ".csv")
    ok <- tryCatch({
      suppressWarnings(utils::write.csv(df, dest, row.names = FALSE))
      TRUE
    }, error = function(e) FALSE)
    if (!ok) {
      out(sprintf("cannot write %s (the directory does not exist, or no permission)\n", dest))
      return(1L)
    }
    out(sprintf("wrote %s  (%d rows, %d cols)\n", dest, nrow(df), ncol(df)))
  } else {
    out(paste0(
      sprintf("usage: %s data list | ", .bl_prog()),
      "data pull db/table [--out FILE.csv]\n"
    ))
    # asking for help is not a mistake: --help exits 0 like every other verb's help
    return(if (identical(sub, "--help") || identical(sub, "-h") || identical(sub, "help")) 0L else 2L)
  }
  0L
}
