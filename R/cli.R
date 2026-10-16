# SPDX-License-Identifier: AGPL-3.0-or-later
#
# The rmoriebricklayer command line, shipped inside the package.
# `inst/bin/rmoriebricklayer` is a two-line launcher that runs
# bricklayer_cli() through Rscript; install_cli() links it into a
# directory on PATH (an R package cannot install executables itself,
# and it only does so when the user calls install_cli()).

# interactive() is a primitive: tests cannot mock it in the installed package, so they mock this
.bl_interactive <- function() interactive()

# Ctrl-C at a prompt read by a shell child: the same condition R raises for its own interrupt,
# so the command exits 130 (128 + SIGINT) and not as a usage error
.bl_signal_interrupt <- function() {
  signalCondition(structure(class = c("interrupt", "condition"), list(message = "interrupted", call = NULL)))
  stop("interrupted", call. = FALSE)
}
.bl_stdin_tty <- function() isatty(stdin())
# A program in the usual places, found without a child process: Sys.which() runs one, and R ignores
# SIGINT while a child runs (as system() does), so a Ctrl-C landing there killed only the child.
# Sys.which("sh") came back "", the prompt fell back to a blocking read of stdin that ignores
# Ctrl-C, and the command waited at the prompt (a Ctrl-C 0.18 s after start, 2026-10-14).
# The search runs over PATH, as the shell does, then /bin and /usr/bin: /bin and /usr/bin alone missed
# stty on a NixOS-style layout, so the key was echoed as it was typed (network stress test of 5e1dce5).
.bl_find_program <- function(name) {
  dirs <- c(strsplit(Sys.getenv("PATH"), .Platform$path.sep, fixed = TRUE)[[1L]], "/bin", "/usr/bin")
  p <- file.path(unique(dirs[nzchar(dirs)]), name)
  p <- p[file.exists(p) & !dir.exists(p)]
  p <- p[file.access(p, 1L) == 0L]
  if (length(p)) p[[1L]] else ""
}
.bl_have_program <- function(name) nzchar(.bl_find_program(name))
.bl_stdout_tty <- function() isatty(stdout())

# One typed line for a prompt (the key of `login --token`, the emailed code). The launchers run
# Rscript, where readline() returns "" at once, so outside an interactive session read one line of
# stdin: typed at a terminal, or piped (`echo KEY | rmbl login --token` keeps the key out of the shell
# history). Closed or empty stdin gives "".
.bl_readline <- function(prompt, con = NULL, secret = FALSE) {
  # a key typed at a terminal is not echoed (stty, where there is one); elsewhere it is
  # read as any other line, which is what piping `echo KEY |` relies on
  hide <- isTRUE(secret) && is.null(con) && .Platform$OS.type == "unix" && .bl_stdin_tty() &&
    .bl_have_program("stty")
  if (.bl_interactive()) {
    if (hide) {
      system2("stty", "-echo", stdout = FALSE, stderr = FALSE)
      on.exit({
        system2("stty", "echo", stdout = FALSE, stderr = FALSE)
        cat("\n", file = stderr())
      }, add = TRUE)
    }
    return(trimws(readline(prompt)))
  }
  if (is.null(con) && .bl_stdin_tty() && .Platform$OS.type == "unix" && .bl_have_program("sh")) {
    # R's blocking read of a terminal ignores Ctrl-C until Enter: a shell `read` child sees the
    # terminal's interrupt at once, and Ctrl-D ends it with an empty line. the line comes back
    # over a pipe, never through a shell argument or the history. The echo is switched off and
    # back on by the shell itself, with a trap, so Ctrl-C cannot leave the terminal silent
    # (review of 52a8883, B6); an interrupted read exits 130 and is an interrupt here too
    # The trap also prints a marker: where /bin/sh is dash (Debian, Ubuntu), system2() reports no
    # exit status for the trapped `exit 130`, so Ctrl-C came back as an empty line and a usage
    # error (exit 2; review of 02a38be, C10; bash keeps the status). A typed line cannot hold the
    # marker: Ctrl-C never reaches the input.
    # The shell prints the prompt itself, once its trap is set and the echo is off, and marks a
    # read that completed: R printed the prompt before the child started, so a key typed at once
    # was echoed, and a Ctrl-C in those milliseconds killed the child before its trap and came back
    # as an empty line, exit 2 (review of e57fed5, the C10 leftovers). Output without the
    # completion mark is a read that never finished: an interrupt. The prompt reaches the shell in
    # the environment, never in the script.
    mark <- "\001RMBL-INTERRUPTED\001"
    done <- "\002RMBL-LINE\002"
    # the prompt goes straight to the terminal (this branch runs only when stdin is one): the
    # child's stderr stays discarded, as before, which keeps R's wait on it what it was
    ask <- "printf '%s' \"$RMBL_PROMPT\" > /dev/tty; IFS= read -r l; "
    script <- if (hide) {
      paste0("trap 'stty echo; printf \"\\001RMBL-INTERRUPTED\\001\"; exit 130' INT TERM HUP; ",
             "stty -echo; ", ask, "stty echo; printf '\\002RMBL-LINE\\002%s' \"$l\"")
    } else {
      paste0("trap 'printf \"\\001RMBL-INTERRUPTED\\001\"; exit 130' INT TERM HUP; ", ask,
             "printf '\\002RMBL-LINE\\002%s' \"$l\"")
    }
    # the prompt is handed over in the environment R passes on, not as a `VAR=value sh` prefix: with
    # the prefix /bin/sh kept itself alive as the child's parent, Ctrl-C killed it, and R raised an
    # interrupt of its own after the handled one (exit 1, not 130)
    old_prompt <- Sys.getenv("RMBL_PROMPT", unset = NA)
    Sys.setenv(RMBL_PROMPT = prompt)
    on.exit(if (is.na(old_prompt)) Sys.unsetenv("RMBL_PROMPT") else Sys.setenv(RMBL_PROMPT = old_prompt), add = TRUE)
    # Ctrl-C reaches R as well as the child (one foreground process group): R's own interrupt is held
    # until the read is over, so it arrives once, here, inside the caller's handler, rather than a
    # moment later on top of the interrupt the child reported (exit 1, "Execution halted"; R-devel
    # CI on 487b956 and a704645)
    # a Ctrl-C already pending (one that landed while R or the package was starting) is taken now:
    # left pending, it was lost once the read began, and the command waited at the prompt
    .Call(C_rmbl_check_interrupt)
    # the sh found above, not whichever `sh` comes first on PATH
    l <- suspendInterrupts(suppressWarnings(system2(.bl_find_program("sh"), c("-c", shQuote(script)),
                                                    stdout = TRUE, stderr = FALSE)))
    if (hide) cat("\n", file = stderr())
    st <- attr(l, "status")
    l <- paste(as.character(l), collapse = "")
    if (identical(as.integer(st), 130L) || grepl(mark, l, fixed = TRUE) ||
          !grepl(done, l, fixed = TRUE)) {
      .bl_signal_interrupt()
    }
    return(trimws(substring(l, regexpr(done, l, fixed = TRUE) + nchar(done))))
  }
  if (is.null(con)) {
    con <- file("stdin")
    on.exit(close(con), add = TRUE)
  }
  if (.bl_stdin_tty()) cat(prompt, file = stderr())
  trimws(paste(readLines(con, n = 1L, warn = FALSE), collapse = ""))
}

#' Run the rmoriebricklayer command line
#'
#' Dispatches the verbs of the \code{rmoriebricklayer} launcher:
#' \describe{
#'   \item{\code{login [--token] [--email ADDRESS [--code CODE]]
#'     [--no-browser]}}{sign in for the curated tables at data.rmorie.com
#'     (a free MORIE data key, issued at \url{https://www.rmorie.com/access/}):
#'     a key you paste with \code{--token} (read from the terminal or a pipe
#'     when KEY is omitted), a code sent to \code{--email}, or the GitHub
#'     device flow}
#'   \item{\code{logout}}{forget the data key}
#'   \item{\code{doctor}}{report the language-model routes available here
#'     (own endpoint, each provider with your key, local Ollama), in the
#'     order \code{ask} tries them}
#'   \item{\code{models [--route ROUTE]}}{list the models your provider (or
#'     server) offers, the one in use marked}
#'   \item{\code{data list}}{the curated tables at data.rmorie.com}
#'   \item{\code{data pull db/table}}{download one table as CSV}
#'   \item{\code{config [setup | set KEY VALUE | unset KEY | get KEY | help]}}{show
#'     or change the language-model settings (\code{\link{bricklayer_llm_config}}):
#'     the route \code{ask} uses and the address, key and model of each route;
#'     \code{setup} walks through them}
#'   \item{\code{ask [--route ROUTE] [--model NAME] [--fresh] PROMPT...}}{send
#'     a prompt to the
#'     model (or the named one, on the named route) and print the reply; the
#'     same question again is answered from this machine (\code{--fresh} asks anew).
#'     \code{aye} and \code{tellme} are the same verb, and a quoted question with no
#'     verb (\code{rmbl "how do I weight a survey?"}) is asked too}
#'   \item{\code{explain-error MESSAGE...}}{where an error of these packages comes from
#'     (\code{\link{bricklayer_explain_error}}), without a model or the network}
#'   \item{\code{bundle REQUEST...}}{\code{\link{agent_bundle}} from the
#'     shell}
#'   \item{\code{wayback FILE [--out FILE.jsonl] [--jobs N] [--within 30d]
#'     [--max N]}}{save every URL listed in FILE (one per line; blank lines and
#'     \code{#} comments skipped) in the Internet Archive's Wayback Machine
#'     with \code{\link{wayback_save}}, results in \code{--out} (default
#'     \code{FILE.wayback.jsonl}), so a stopped run carries on;
#'     \code{wayback --retry FILE.jsonl [--include-gone]} retries the failures
#'     of an earlier run (\code{\link{wayback_retry}})}
#'   \item{\code{functions [PATTERN]}}{list the exported functions with
#'     their one-line titles, optionally filtered by a regular expression}
#'   \item{\code{describe NAME}}{title, usage, arguments and description of
#'     one function, from its help page}
#'   \item{\code{examples NAME}}{print the examples of one function}
#'   \item{\code{version}}{print the package version (also
#'     \code{--version}, \code{-v})}
#'   \item{\code{help [VERB]}}{this list, or one verb's usage (also
#'     \code{--help}, \code{-h}; \code{VERB --help} shows a verb's usage
#'     without running it)}
#' }
#' The launcher installed by \code{\link{install_cli}} calls this function
#' with the shell's arguments and exits with its status. Calling it from R is
#' the same as typing the command, which is how the examples below work.
#'
#' @details
#' An option a verb does not take is refused with exit status 2 rather than
#' ignored or sent as part of a prompt; everything after a bare \code{--} is
#' positional (for a prompt that itself starts with \code{--}) and only
#' \code{ask}, \code{bundle} and \code{explain-error} accept it. A first
#' argument that is plainly a question (two or more words, or ending in
#' \code{?}, with no path, line break or key-shaped word) and no verb is
#' asked as \code{ask} would ask it.
#'
#' Errors are not raised: every error is written to \code{out} as
#' \code{"PROG: message"} and turned into the exit status. The status is 0
#' on success, 1 when the verb failed (an error, nothing found, no route), 2
#' for a usage error (an unknown verb or option, a missing value) and 130 when
#' interrupted (Ctrl-C). The command name in messages is the environment
#' variable \code{RMBL_PROG}, else \code{rmoriebricklayer}.
#'
#' Side effects: during the call \code{options(morie.progress = TRUE)} is set,
#' so downloads draw a progress bar; when \code{RMBL_PROG} is set (the
#' launcher sets it) and \code{options(rmoriebricklayer.data_cache)} is not,
#' the data.rmorie.com manifest and tables are kept in
#' \code{tools::R_user_dir("rmoriebricklayer", "cache")} rather than a fresh
#' temporary folder. The verbs \code{login}, \code{logout} and
#' \code{config} write the shared credentials and settings files;
#' \code{ask}, \code{models}, \code{data}, \code{bundle} and
#' \code{wayback} use the network; \code{functions}, \code{describe},
#' \code{examples}, \code{explain-error}, \code{version} and \code{help}
#' only read the installed help.
#'
#' @param args Character vector of arguments, verb first; defaults to the
#'   command line (\code{commandArgs(trailingOnly = TRUE)}). An empty vector
#'   prints the help.
#' @param out Function that receives the output text, one string at a time
#'   (default \code{cat}, the console). Pass a function that collects the
#'   strings to capture the output.
#' @return The exit status (integer scalar), invisibly: 0 on success, 1 on
#'   failure, 2 for a usage error, 130 when interrupted.
#' @seealso \code{\link{install_cli}} to put the command on your PATH.
#' @examples
#' bricklayer_cli("version")
#' bricklayer_cli("help")
#' bricklayer_cli(c("functions", "json"))
#' bricklayer_cli(c("describe", "analyse_table"))
#'
#' # one verb's usage, and the examples of a help page
#' bricklayer_cli(c("help", "data"))
#' bricklayer_cli(c("examples", "period_days"))
#'
#' # capture the output instead of printing it
#' lines <- character()
#' status <- bricklayer_cli(c("functions", "^drbg_"),
#'                          out = function(x) lines <<- c(lines, x))
#' status
#' lines
#'
#' # an unknown verb is a usage error: status 2, nothing run
#' bricklayer_cli("nonsense")
#' @export
bricklayer_cli <- function(args = commandArgs(trailingOnly = TRUE),
                           out = cat) {
  old_progress <- options(morie.progress = TRUE)  # downloads draw their bar
  on.exit(options(old_progress), add = TRUE)
  if (nzchar(Sys.getenv("RMBL_PROG")) && is.null(getOption("rmoriebricklayer.data_cache"))) {
    # from the shell every call is a new R session: keep the data.rmorie.com manifest and tables in
    # the user cache (tools::R_user_dir) instead of a fresh tempdir() each time
    old_cache <- options(rmoriebricklayer.data_cache = tools::R_user_dir("rmoriebricklayer", "cache"))
    on.exit(options(old_cache), add = TRUE)
  }
  args <- as.character(args)
  if (length(args) && identical(args[[1L]], "--args")) args <- args[-1L]  # R >= 4.6 keeps the separator
  verb <- if (length(args)) args[[1L]] else "help"
  rest <- args[-1L]
  # `aye` and `tellme` are other names for ask, and a question with no verb is asked when it plainly
  # is one (.bl_bare_question): `rmbl "how do I weight a survey?"`, `rmbl "how?" --fresh`. A typo with
  # a quoted argument, a file name or a pasted key stays an unknown verb and never reaches a model.
  if (verb %in% c("aye", "tellme")) {
    verb <- "ask"
  } else if (is.null(.bl_verb_usage(verb)) && .bl_bare_question(args)) {
    rest <- args
    verb <- "ask"
  }
  # everything after a bare `--` is positional: a prompt or request that itself starts with --
  dd <- match("--", rest)
  tail_args <- if (is.na(dd)) character() else rest[-seq_len(dd)]
  if (!is.na(dd)) rest <- rest[seq_len(dd - 1L)]
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
      out(sprintf("%s: %s\n", prog, .bl_unknown_verb(verb, prog)))
      return(invisible(2L))
    }
    out(u)
    return(invisible(0L))
  }
  # an option the verb does not take is refused, not run (`logout --x` logged out; ask sent it as the prompt)
  # --force belongs to `config reset` alone: offered to every config verb it became the value of
  # `config set own.key --force` (review of 02a38be, C6)
  known <- list(login = c("--email", "--code", "--no-browser", "--token"), ask = c("--model", "--route", "--fresh"),
                models = "--route",
                data = "--out", wayback = c("--out", "--jobs", "--within", "--max", "--retry", "--include-gone"),
                config = if (length(rest) && identical(rest[[1L]], "reset")) "--force")
  opts <- rest[startsWith(rest, "--")]
  values <- unlist(lapply(c("--email", "--code", "--token", "--model", "--route", "--out", "--jobs", "--within"),
                          function(f) {
    i <- match(f, rest)
    if (!is.na(i) && i < length(rest)) rest[[i + 1L]] else NULL
  }))
  bad <- setdiff(opts, c(known[[verb]], values))
  if (verb %in% c("help", "--help", "-h")) bad <- setdiff(opts, c("--help", "-h"))
  if (length(bad) && (verb %in% c("help", "--help", "-h") || !is.null(.bl_verb_usage(verb, prog)))) {
    out(sprintf("%s %s: unknown option %s (%s %s --help)\n", prog, verb, bad[[1L]], prog, verb))
    return(invisible(2L))
  }
  status <- 0L
  tryCatch(
    {
      # arguments after a bare `--` are a prompt or a request: only ask and bundle take one, and
      # every other verb ignored them (`functions -- a b` listed everything)
      if (length(tail_args) && !verb %in% c("ask", "bundle", "explain-error")) {
        # the verb as it prints: an escape sequence typed into it is not sent to the terminal
        usage_error(sprintf("%s takes no arguments after --", .rmbl_printable(verb)))
      }
      switch(verb,
        login = {
          if (has("--token")) {
            i <- match("--token", rest)
            tok <- if (i < length(rest)) rest[[i + 1L]] else ""
            if (nzchar(tok)) {
              out(sprintf(paste("%s: a key given on the command line stays in the shell history and is visible",
                                "to other users in the process list; `%s login --token` with no value asks for it\n"),
                          prog, prog))
            }
            if (!nzchar(tok)) tok <- .bl_readline("Paste your MORIE key: ", secret = TRUE)
            if (!nzchar(tok)) {
              usage_error("--token needs a key: run `login --token` and paste it when asked")
            }
            bricklayer_llm_login(token = tok)
          } else {
            if (has("--code") && is.null(flag("--email"))) {
              usage_error("--code needs --email ADDRESS (the code was sent there)")
            }
            em <- flag("--email")
            if (!is.null(em) && !grepl("^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$", trimws(em))) {
              usage_error(sprintf("--email: '%s' is not an email address", em))
            }
            bricklayer_llm_login(
              email = flag("--email"), code = flag("--code"),
              open_browser = !has("--no-browser") &&
                interactive()
            )
          }
          out(sprintf("Logged in: the curated tables at %s are open to you\n",
                      tryCatch(.bl_data_url(), error = function(e) "data.rmorie.com")))
        },
        logout = {
          if (length(c(rest, tail_args))) usage_error("logout takes no arguments")
          bricklayer_llm_logout()
        },
        doctor = {
          if (length(c(rest, tail_args))) usage_error("doctor takes no arguments")
          .bl_cli_doctor(out)
        },
        config = .bl_cli_config(rest, out, usage_error),
        models = {
          rte <- flag("--route")
          extra <- setdiff(rest, c("--route", rte))
          if (length(c(extra, tail_args))) usage_error(sprintf("usage: %s models [--route ROUTE]", prog))
          if (!is.null(rte) && !rte %in% c("auto", .bl_llm_route_names())) {
            usage_error(sprintf("--route takes auto, own, ollama or a provider (%s)",
                                paste(.bl_llm_presets()$id, collapse = ", ")))
          }
          status <- .bl_cli_models(out, rte)
        },
        ask = {
          for (f in c("--model", "--route")) {
            if (sum(rest == f) > 1L) {
              usage_error(sprintf("%s may be given once (the second would become part of the prompt)", f))
            }
          }
          mdl <- flag("--model")
          if (!is.null(mdl)) rest <- rest[-(match("--model", rest) + 0:1)]
          fresh <- "--fresh" %in% rest
          rest <- rest[rest != "--fresh"]
          rte <- flag("--route")
          if (!is.null(rte)) {
            rest <- rest[-(match("--route", rest) + 0:1)]
            if (identical(rte, "hosted")) stop(.bl_hosted_retired(), call. = FALSE)
            if (!rte %in% c("auto", .bl_llm_route_names())) {
              usage_error(sprintf("--route takes auto, own, ollama or a provider (%s)",
                                  paste(.bl_llm_presets()$id, collapse = ", ")))
            }
            # "auto" is passed through: it means the automatic order this time, over a saved route
          }
          if (!length(rest) && !length(tail_args)) {
            usage_error(sprintf("usage: %s ask [--route ROUTE] [--model NAME] [--fresh] [--] PROMPT...", prog))
          } else {
            prompt <- paste(c(rest, tail_args), collapse = " ")
            if (!nzchar(trimws(prompt))) {
              usage_error(sprintf(paste("the prompt is empty (usage: %s ask [--route ROUTE] [--model NAME]",
                                        "[--fresh] PROMPT...)"), prog))
            }
            ans <- bricklayer_llm_ask(prompt, model = mdl, route = rte, fresh = fresh)
            out(paste0(ans, "\n"))
            if (!is.null(attr(ans, "cached"))) {
              out(sprintf("(the answer saved on %s for this question; `%s ask --fresh ...` asks the model again)\n",
                          attr(ans, "cached"), prog))
            }
          }
        },
        bundle = {
          rest <- c(rest, tail_args)
          if (!length(rest)) {
            usage_error(sprintf("usage: %s bundle REQUEST...", prog))
          }
          if (!nzchar(trimws(paste(rest, collapse = " ")))) {
            usage_error(sprintf("the request is empty (usage: %s bundle REQUEST...)", prog))
          }
          # with no language-model route agent_bundle() explains how to set one up: nothing was
          # produced, so the command fails
          routed <- !is.null(.bl_llm_route())
          out(paste0(agent_bundle(paste(rest, collapse = " ")), "\n"))
          if (!routed) status <- 1L
        },
        functions = {
          if (length(rest) > 1L) usage_error(sprintf("usage: %s functions [PATTERN]", prog))
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
        `explain-error` = status <- .bl_cli_explain(c(rest, tail_args), out, prog),
        wayback = status <- .bl_cli_wayback(rest, flag, out),
        `--version` = ,
        `-v` = ,
        version = {
          if (length(c(rest, tail_args))) usage_error("version takes no arguments")
          out(sprintf("rmoriebricklayer %s\n", as.character(utils::packageVersion("rmoriebricklayer"))))
        },
        help = ,
        `--help` = ,
        `-h` = {
          if (length(rest) > 1L) usage_error(sprintf("usage: %s help [VERB]", prog))
          status <- .bl_cli_help(rest, out)
        },
        usage_error(.bl_unknown_verb(verb, prog))
      )
    },
    error = function(e) {
      out(paste0(prog, ": ", conditionMessage(e), "\n"))
      status <<- if (inherits(e, "bl_usage")) 2L else 1L
    },
    interrupt = function(e) {
      # Ctrl-C at a prompt: the shell convention, 128 + SIGINT, not a usage error
      out(paste0(prog, ": interrupted\n"))
      status <<- 130L
    }
  )
  invisible(status)
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# One usage line per verb, for `VERB --help`; NULL for a verb that does not exist.
# A question typed with no verb, asked as `ask` would be: the first argument is the question itself
# (two words or more, or ending in ?), it is not a verb or a near miss of one, it holds no path, line
# break or key-shaped word, and what follows is only options ask takes. Before, any argument with a
# space or a last one ending in ? made the whole line a question: `explain-eror "object 'x' not
# found"`, `"My Documents/urls.txt"` and `conifg set anthropic.key "<key>\r"` (a CRLF key file) went to
# the model, the key with them (network stress test of 5e1dce5).
.bl_bare_question <- function(args) {
  if (!length(args)) return(FALSE)
  q <- args[[1L]]
  if (!nzchar(q) || startsWith(q, "-") || grepl("[\r\n\v\f]", q) || grepl("[/\\]", q)) return(FALSE)
  # a key-shaped run anywhere in the line, not only as a whole word: "KEY?", "KEY," or "my key is
  # KEY, thanks" went to a model, and to the wrong provider (CRAN stress test of b617a3f, #2)
  if (.bl_key_shaped(q)) return(FALSE)
  # ideographic, no-break and zero-width spaces split words like a space
  q <- gsub("[\u3000\u00a0\u2007\u202f\u200b\u200c\u200d\u2060\ufeff]", " ", q)
  q <- gsub("\uff1f", "?", q, fixed = TRUE)
  words <- strsplit(trimws(q), "[[:space:]]+")[[1L]]
  # letters in any script (PCRE's \p classes): [[:alpha:]] takes no CJK letter in the C locale, so a
  # Chinese question was refused there
  if (!any(grepl("\\p{L}{2,}", words, perl = TRUE))) return(FALSE)
  # a lone "?" or "!" is punctuation, not a word: `doctr ?` is a near miss of `doctor`
  wordy <- words[grepl("[\\p{L}\\p{N}]", words, perl = TRUE)]
  if (length(wordy) < 2L && !endsWith(q, "?")) return(FALSE)
  if (length(wordy) == 1L) {
    w <- tolower(gsub("[[:punct:]]+", "", wordy[[1L]]))
    if (min(utils::adist(w, .bl_verb_names())) <= 2L) return(FALSE)
  }
  rest <- args[-1L]
  i <- 1L
  while (i <= length(rest)) {
    if (rest[[i]] %in% c("--route", "--model")) {
      i <- i + 2L
    } else if (identical(rest[[i]], "--fresh")) {
      i <- i + 1L
    } else {
      return(FALSE)
    }
  }
  TRUE
}

# TRUE when the text holds a run of 24 or more key characters anywhere, not only as a whole word.
# A function name is not one: an export of the package, or snake_case words of up to 15 characters
# each (survey_design_replicates); a key's random part is one long run, in one case or mixed.
.bl_key_shaped <- function(x) {
  runs <- regmatches(x, gregexpr("[A-Za-z0-9_+=.:-]{24,}", x))[[1L]]
  runs <- sub("[.:=-]+$", "", runs)
  runs <- runs[nchar(runs) >= 24L & !grepl("^[a-z][a-z0-9]{0,14}([_.][a-z0-9]{1,15})+$", runs) &
                 !runs %in% getNamespaceExports(asNamespace("rmoriebricklayer"))]
  length(runs) > 0L
}

# Every verb and spelling the command takes, for the bare-question rule and "did you mean".
.bl_verb_names <- function() {
  c(.bl_verb_usage(NULL), "help", "version", "aye", "tellme")
}

# The line for an unknown verb: the nearest verb when one is close, and how to ask a model.
.bl_unknown_verb <- function(verb, prog) {
  v <- .bl_verb_names()
  # quotes and a trailing ? or ! around a typo are not part of it: `"doctr?"` is a near miss too
  d <- utils::adist(tolower(gsub("[\"'?!.,\uff1f\u3000[:space:]]+", "", verb)), v)
  near <- if (min(d) <= 2L) sprintf(" (did you mean `%s %s`?)", prog, v[which.min(d)]) else ""
  # a pasted key is not printed back to the terminal and its scrollback (network stress test of 5e1dce5)
  shown <- if (.bl_key_shaped(verb)) "(an argument like a key, not shown)" else .rmbl_printable(verb)
  sprintf("unknown verb '%s'%s; try `%s help`, or `%s ask \"QUESTION\"` for a model",
          shown, near, prog, prog)
}

.bl_verb_usage <- function(verb, prog = "rmoriebricklayer") {
  u <- c(
    login = paste("login [--email ADDRESS [--code CODE]] [--no-browser] | login --token",
                  "  sign in for the curated tables at data.rmorie.com"),
    logout = "logout   forget the data key",
    doctor = "doctor   report the language-model routes available here",
    models = "models [--route ROUTE]   the models your provider (or server) offers (the one in use marked)",
    ask = paste("ask [--route auto|own|ollama|PROVIDER] [--model NAME] [--fresh] PROMPT...",
                "  ask the model (your own key; --fresh: not the answer saved for the same question)"),
    `explain-error` = "explain-error MESSAGE...   where an error of these packages comes from, without a model",
    config = paste("config [show | help | get KEY | set KEY VALUE | unset KEY | setup | path | reset]",
                   "  show or change the language-model settings (route, addresses, keys, models)"),
    bundle = "bundle REQUEST...   agent_bundle() from the shell",
    functions = "functions [PATTERN]   exported functions and their titles",
    describe = "describe NAME   help page of one function",
    examples = "examples NAME   the examples of one function",
    data = "data list | data pull db/table [--out FILE.csv]   curated tables at data.rmorie.com (your MORIE key)",
    wayback = paste("wayback FILE [--out FILE.jsonl] [--jobs N] [--within 30d] [--max N]   archive every URL in FILE;",
                    "wayback --retry FILE.jsonl [--include-gone]   retry the failures of an earlier run;",
                    "(keys: IA_S3_ACCESS_KEY and IA_S3_SECRET_KEY, or their _FILE twins)"),
    version = "version   package version"
  )
  if (is.null(verb)) return(names(u))
  if (!verb %in% names(u)) return(NULL)
  sprintf("usage: %s %s\n", prog, u[[verb]])
}

# The Rd database of this package: the installed copy when there is one,
# else the man/ directory of a source tree loaded with pkgload.
.bl_rd_db <- function(db = tryCatch(tools::Rd_db("rmoriebricklayer"), error = function(e) NULL),
                      man = system.file("man", package = "rmoriebricklayer")) {
  if (length(db)) {
    return(db)
  }
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
#' Writes small launcher scripts into a directory on your PATH so that
#' \code{rmoriebricklayer login}, \code{rmbl ask ...} and the other verbs of
#' \code{\link{bricklayer_cli}} work from any shell. Run it once after
#' installing or upgrading the package. Nothing outside \code{dir} is
#' touched, and only when you call this.
#'
#' @details
#' On Unix-alikes each launcher is a \code{/bin/sh} script (mode 0755) that
#' sets \code{RMBL_PROG} to its own name and runs
#' \code{Rscript -e "rmoriebricklayer::bricklayer_cli()"} with the shell's
#' arguments, exiting with the function's status (130 on Ctrl-C). The library
#' this copy of the package is installed in is pinned inside R with
#' \code{.libPaths()}, so an \code{R_LIBS} set in the shell or in
#' \code{~/.Renviron} cannot make the command run another copy. An existing
#' file or link of the same name in \code{dir} is replaced. On Windows a
#' \code{NAME.cmd} batch wrapper doing the same is written instead. A message
#' names the files written and, when \code{dir} is not on the \code{PATH},
#' says to add it. Re-run it after moving the package to another library.
#'
#' Errors when the package installation has no launcher in
#' \code{inst/bin} (a damaged installation), and from base R when \code{dir}
#' cannot be created or written; when \code{dir} is not one string; and
#' when \code{name} is not a character vector of one or more command names
#' (empty, \code{NA}, an empty string or a name with a directory part is
#' refused).
#'
#' @param dir Character scalar, the target directory; default
#'   \code{~/.local/bin}. Created (with its parents) if absent.
#' @param name Character vector of command names to install; default both
#'   \code{rmoriebricklayer} and its short form \code{rmbl} (every verb works
#'   under either).
#' @return The path of the first launcher written (normally
#'   \code{rmoriebricklayer}), invisibly; the others are written beside it.
#' @seealso \code{\link{bricklayer_cli}} for the verbs.
#' @examples
#' # into a scratch folder, so nothing on your PATH changes
#' d <- file.path(tempdir(), "bin")
#' p <- install_cli(dir = d)
#' list.files(d)
#' readLines(p)[1:4]
#'
#' # one name only
#' install_cli(dir = d, name = "rmbl")
#' \dontrun{
#' install_cli()   # ~/.local/bin/rmoriebricklayer and ~/.local/bin/rmbl
#' }
#' @export
install_cli <- function(dir = file.path(path.expand("~"), ".local", "bin"),
                        name = c("rmoriebricklayer", "rmbl")) {
  # an empty `name` wrote nothing, printed "Installed ;" and failed on targets[[1L]]
  if (!is.character(name) || !length(name) || anyNA(name) || any(!nzchar(name)) ||
        any(basename(name) != name)) {
    stop("`name` must be one or more command names (non-empty, no NA, no directory part)", call. = FALSE)
  }
  dir <- .rmbl_string1(dir, "dir")
  src <- system.file("bin", "rmoriebricklayer", package = "rmoriebricklayer")
  if (!nzchar(src)) stop("the launcher is missing from this installation", call. = FALSE)
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
                                "q <- tryCatch(rmoriebricklayer::bricklayer_cli(), interrupt = function(e) 130L); ",
                                "quit(status = as.integer(q))\" %%*"),
                         lib), target)
      # nocov end
    } else {
      target <- file.path(dir, nm)
      if (file.exists(target) || !is.na(Sys.readlink(target))) unlink(target)
      # the library path is an R string literal (deparse() escapes it) inside
      # a single-quoted shell argument (a quote in the path becomes '\'')
      # a Ctrl-C that reaches the top level exits 130, not 1 (as inst/bin/rmbl)
      body <- paste0("suppressPackageStartupMessages({ .libPaths(c(", deparse(lib), ", .libPaths())); ",
                     "q <- tryCatch(rmoriebricklayer::bricklayer_cli(), interrupt = function(e) 130L); ",
                     "quit(status = as.integer(q)) })")
      body <- gsub("'", "'\\\\''", body)
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

# The models verb: the models the route `ask` would take offers (or the one named), default marked.
.bl_cli_models <- function(out, route = NULL) {
  rt <- .bl_llm_route(route)
  if (is.null(rt)) {
    out(paste0(.bl_no_route_message(route), "\n"))
    return(invisible(1L))
  }
  have <- .bl_llm_list_models(rt) %||% character()
  if (!length(have)) {
    out(sprintf("%s: no model list to show (the provider does not publish one, or did not answer)%s\n", rt$name,
                if (!is.null(rt$model)) sprintf("; the model in use is %s", rt$model) else ""))
    return(invisible(0L))
  }
  out(sprintf("%s; the model in use is marked *:\n", rt$name))
  for (m in have) out(sprintf("  %s %s\n", if (identical(m, rt$model)) "*" else " ", m))
  pick <- if (!is.null(rt$id)) sprintf("`%s config set %s.model NAME`", .bl_prog(), rt$id) else
    if (identical(rt$name, "local Ollama")) sprintf("`%s config set ollama.model NAME`", .bl_prog()) else
      sprintf("`%s config set own.model NAME`", .bl_prog())
  out(sprintf("Pick one per call with `%s ask --model NAME ...`, or keep one with %s.\n", .bl_prog(), pick))
  invisible(0L)
}

# The wayback verb: every URL in a file (one per line; blank lines and # comments skipped) saved
# in the Wayback Machine by wayback_save(), results in --out (default FILE.wayback.jsonl), which
# also lets a stopped run carry on.
.bl_cli_wayback <- function(rest, flag, out) {
  pos <- rest
  for (f in c("--out", "--jobs", "--within", "--max")) {
    i <- match(f, pos)
    if (!is.na(i)) pos <- pos[-c(i, i + 1L)]
  }
  cap <- flag("--max") %||% "1000"
  # --retry FILE.jsonl: the failures of an earlier run, looked up and captured again (wayback_retry)
  retry <- "--retry" %in% pos
  gone <- "--include-gone" %in% pos
  pos <- setdiff(pos, c("--retry", "--include-gone"))
  if (retry) {
    if (length(pos) != 1L || !file.exists(pos[[1L]])) {
      out(sprintf("--retry takes the results file of an earlier run: %s\n",
                  if (length(pos) == 1L) paste("no such file", pos[[1L]]) else "give one FILE.jsonl"))
      return(if (length(pos) == 1L) 1L else 2L)
    }
    res <- wayback_retry(pos[[1L]], include_gone = gone, jobs = flag("--jobs") %||% "4",
                         within = flag("--within") %||% "30d", max_captures = cap)
    r <- attr(res, "retry")
    tab <- table(factor(res$status, levels = c("saved", "existing", "failed", "submitted")))
    out(sprintf(paste("%d failures: %d found already archived, %d captured again, %d left as gone,",
                      "%d left for tomorrow (a daily limit); now %d saved, %d existing, %d failed in %s\n"),
                r$failed, r$found_by_lookup, r$captured_again, r$left_as_gone, r$left_for_tomorrow, tab[["saved"]],
                tab[["existing"]], tab[["failed"]], pos[[1L]]))
    return(if (tab[["failed"]] > 0L || tab[["submitted"]] > 0L) 1L else 0L)
  }
  if (length(pos) != 1L || pos[[1L]] %in% c("help", "--help", "-h")) {
    out(.bl_verb_usage("wayback", .bl_prog()))
    return(if (length(pos) == 1L) 0L else 2L)
  }
  if (!file.exists(pos[[1L]])) {
    out(sprintf("no such file: %s\n", pos[[1L]]))
    return(1L)
  }
  urls <- trimws(readLines(pos[[1L]], warn = FALSE))
  urls <- urls[nzchar(urls) & !startsWith(urls, "#")]
  jobs <- flag("--jobs") %||% "4"
  res <- wayback_save(urls, jobs = jobs, within = flag("--within") %||% "30d",
                      output = flag("--out") %||% paste0(pos[[1L]], ".wayback.jsonl"), max_captures = cap)
  tab <- table(factor(res$status, levels = c("saved", "existing", "failed", "submitted")))
  ns <- length(attr(res, "not_sent"))
  out(sprintf("%d saved, %d existing, %d failed%s; results in %s\n", tab[["saved"]], tab[["existing"]],
              tab[["failed"]], if (ns) sprintf(", %d not sent (run again to continue)", ns) else "",
              flag("--out") %||% paste0(pos[[1L]], ".wayback.jsonl")))
  if (tab[["failed"]] > 0L || ns > 0L) 1L else 0L
}

# The data verb: the curated tables at data.rmorie.com.
.bl_cli_data <- function(rest, flag, out) {
  sub <- if (length(rest)) rest[[1L]] else "list"
  # the positional words, without --out and its value: an extra word was silently ignored
  pos <- rest
  i <- match("--out", pos)
  if (!is.na(i)) pos <- pos[-c(i, i + 1L)]
  if ((identical(sub, "list") && length(pos) > 1L) || (identical(sub, "pull") && length(pos) > 2L)) {
    out(sprintf("usage: %s data list | data pull db/table [--out FILE.csv]  (one table per pull)\n", .bl_prog()))
    return(2L)
  }
  if (identical(sub, "list")) {
    out(.bl_format_data_tables(
      bricklayer_data_tables(),
      hint = sprintf("`%s data pull KEY` downloads one (your MORIE key)", .bl_prog())
    ))
  } else if (identical(sub, "pull") && length(rest) >= 2L) {
    dest <- flag("--out") %||%
      paste0(gsub("[^A-Za-z0-9_.-]", "_", rest[[2L]]), ".csv")
    # refuse an unwritable destination before downloading the table, not after
    dir <- dirname(dest)
    if (!dir.exists(dir) || file.access(dir, 2L) != 0L || dir.exists(dest)) {
      out(sprintf("cannot write %s (the directory does not exist, or no permission)\n", dest))
      return(1L)
    }
    df <- bricklayer_data_load(rest[[2L]])
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

# `rmbl help [TOPIC]`: the verbs, a getting-started guide, and one page per topic.
.bl_cli_help <- function(rest, out) {
  prog <- .bl_prog()
  topic <- if (length(rest) && !startsWith(rest[[1L]], "-")) rest[[1L]] else ""
  verbs <- paste0(
    sprintf("usage: %s <verb> [options]   (rmbl is the same command as rmoriebricklayer)\n\n", prog),
    "Language models (your own key, or a model on your machine)\n",
    "  ask [--route R] [--model NAME] PROMPT...  ask a model and print the reply (--fresh: ask anew)\n",
    "  aye, tellme, or just \"QUESTION?\"          the same as ask\n",
    "  explain-error \"MESSAGE\"                   where an error comes from and what to do, no model needed\n",
    "  doctor                                    what is set up, and which route ask will use\n",
    "  config                                    show every language-model setting\n",
    "  config setup                              answer a few questions to set them all\n",
    "  config set KEY VALUE | unset KEY          change one (keys: config help)\n",
    "  config reset [--force]                    move an unreadable settings file aside\n",
    "  models [--route R]                        models your provider or server offers\n",
    "  bundle REQUEST...                         agent_bundle() from the shell\n",
    "\nData and functions\n",
    "  login [--token] [--email ADDRESS]         sign in for the curated tables at data.rmorie.com\n",
    "        [--code CODE] [--no-browser]\n",
    "  logout                                    forget the data key\n",
    "  data list                                 curated tables at data.rmorie.com\n",
    "  data pull db/table [--out FILE.csv]       download one of them (your MORIE data key)\n",
    "  wayback FILE [--out F.jsonl] [--jobs N]   archive every URL in FILE (archive.org keys)\n",
    "  wayback --retry F.jsonl                   retry the failed URLs of an earlier wayback run\n",
    "  functions [PATTERN]                       exported functions and their titles\n",
    "  describe NAME                             help page of one function\n",
    "  examples NAME                             its examples\n",
    "  version                                   package version\n",
    "\nMore help\n",
    sprintf("  %s help start      getting started, step by step\n", prog),
    sprintf("  %s help llm        every way to point ask at a model (your key, Ollama, your own server)\n", prog),
    sprintf("  %s help config     every setting, its environment variable, and examples\n", prog),
    sprintf("  %s help r          the same from R and Rscript\n", prog),
    sprintf("  %s VERB --help     one verb's usage\n", prog)
  )
  start <- paste0(
    "Getting started\n\n",
    "1. Check what is set up:\n",
    sprintf("     %s doctor\n", prog),
    "2. Bring a model (any one is enough):\n",
    "     your own key        export ANTHROPIC_API_KEY=...   (or OPENAI_API_KEY, GEMINI_API_KEY, GROQ_API_KEY, ...)\n",
    sprintf("                         %s config set anthropic.key   (asks for it; saved privately)\n", prog),
    "     local Ollama        ollama serve, then ollama pull qwen3:8b   (https://ollama.com)\n",
    sprintf("     your own server     %s config set own.url http://localhost:1234/v1\n", prog),
    sprintf("   or answer a few questions instead:  %s config setup\n", prog),
    "3. Ask:\n",
    sprintf("     %s ask \"what is a Benford screen for\"\n", prog),
    sprintf("     %s ask --model NAME \"...\"                 (one model, this time)\n", prog),
    sprintf("     %s ask --route ollama \"...\"               (one route, this time)\n", prog),
    "4. Make a choice stick:\n",
    sprintf("     %s config set route anthropic\n", prog),
    sprintf("     %s config set anthropic.model NAME     (`%s models` lists them)\n", prog, prog),
    "5. The curated tables (data.rmorie.com) need a free MORIE data key:\n",
    sprintf("     %s login                  (GitHub, or --email ADDRESS for a code)\n", prog)
  )
  ps <- .bl_llm_presets()
  llm <- paste0(
    "Where ask sends a prompt\n\n",
    "Bring your own key, or run a model locally: nothing is sent anywhere you did not set up.\n",
    "With route = auto (the default) ask tries, in order: your own server (if own.url is set), each\n",
    "provider whose key is set (in the order below), then a local Ollama server (if it has a model).\n",
    sprintf("`%s doctor` shows each one and the route ask will take.\n\n", prog),
    "Providers (your key in its variable, or `config set PROVIDER.key`; the model in PROVIDER.model)\n",
    paste(sprintf("  %-12s %-22s %s\n", ps$id, ps$key_env, ps$base), collapse = ""),
    sprintf("  %s models --route anthropic     the models your key can use\n", prog),
    sprintf("  %s config set route anthropic   always use it\n\n", prog),
    "Ollama, on this machine or another\n",
    "  ollama serve                              start the server (or open the Ollama app)\n",
    "  ollama pull qwen3:8b                      a model to use\n",
    sprintf("  %s config set ollama.url http://192.168.1.20:11434\n", prog),
    sprintf("  %s config set ollama.model qwen3:8b\n", prog),
    sprintf("  %s config set ollama.url off          never try Ollama\n\n", prog),
    "Your own OpenAI-compatible server (LM Studio, vLLM, llama.cpp, Azure OpenAI's v1 endpoint, a gateway)\n",
    sprintf("  %s config set own.url http://localhost:1234/v1\n", prog),
    sprintf("  %s config set own.model NAME\n", prog),
    sprintf("  %s config set own.key                 (prompts for the key, so it stays out of history)\n\n", prog),
    "A model file on your disk (.gguf) or a folder of Ollama models\n",
    "  ask talks to a server, not to files: start one on the file, then point own.url at it\n",
    "  llama-server -m /path/to/model.gguf --port 8080      (llama.cpp)\n",
    sprintf("  %s config set own.url http://localhost:8080/v1\n", prog),
    "  OLLAMA_MODELS=/path/to/models ollama serve          (Ollama reading another folder)\n\n",
    "One call only\n",
    sprintf("  %s ask --route ollama --model llama3.2 \"...\"\n", prog),
    "  MORIE_LLM_ROUTE=groq rmbl ask \"...\"      (environment variables win over saved settings)\n"
  )
  r_help <- paste0(
    "From R (or Rscript -e '...': single quotes outside, double quotes inside)\n\n",
    "  library(rmoriebricklayer)\n",
    "  bricklayer_llm_status()                                   # doctor\n",
    "  bricklayer_llm_providers()                                # every provider, its key variable\n",
    "  bricklayer_llm_config()                                   # every setting\n",
    "  Sys.setenv(ANTHROPIC_API_KEY = \"...\")                     # or bricklayer_llm_config(anthropic.key = ...)\n",
    "  bricklayer_llm_config(route = \"anthropic\", anthropic.model = \"claude-opus-5-5\")\n",
    "  bricklayer_llm_config(ollama.url = \"http://192.168.1.20:11434\", ollama.model = \"qwen3:8b\")\n",
    "  bricklayer_llm_config(own.url = \"http://localhost:1234/v1\", own.model = \"m\")\n",
    "  bricklayer_llm_config(route = NULL)                       # back to auto\n",
    "  bricklayer_llm_models()\n",
    "  bricklayer_llm_ask(\"What can a Benford screen show?\")\n",
    "  bricklayer_llm_login()                                    # the data key, for data.rmorie.com\n\n",
    "From the shell:\n",
    "  Rscript -e 'cat(rmoriebricklayer::bricklayer_llm_ask(\"What can a Benford screen show?\"), \"\\n\")'\n"
  )
  if (!nzchar(topic)) {
    out(verbs)
  } else if (topic %in% c("start", "getting-started", "quickstart")) {
    out(start)
  } else if (topic %in% c("llm", "routes", "providers", "byok", "ollama")) {
    out(llm)
  } else if (identical(topic, "config")) {
    .bl_cli_config("help", out, function(m) stop(m, call. = FALSE))
  } else if (topic %in% c("r", "R", "rscript", "Rscript")) {
    out(r_help)
  } else if (!is.null(.bl_verb_usage(topic, prog))) {
    out(.bl_verb_usage(topic, prog))
  } else {
    out(sprintf("%s: no help topic '%s' (try: %s help)\n", prog, topic, prog))
    return(2L)
  }
  0L
}
