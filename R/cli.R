# SPDX-License-Identifier: AGPL-3.0-or-later
#
# The rmoriebricklayer command line, shipped inside the package.
# `inst/bin/rmoriebricklayer` is a two-line launcher that runs
# blcli() through Rscript; instcli() links it into a
# directory on PATH (an R package cannot install executables itself,
# and it only does so when the user calls instcli()).

#' Calls interactive(), so that tests can mock it.
#'
#' interactive() is a primitive: tests cannot mock it in the installed package,
#' so they mock this
#' @return `interactive()`.
#' @noRd
.bl_interactive <- function() interactive()

#' Signals an interrupt condition and stops.
#'
#' Ctrl-C at a prompt read by a shell child: the same condition R raises for its
#' own interrupt, so the command exits 130 (128 + SIGINT) and not as a usage
#' error
#' @return Does not return.
#' @noRd
.bl_signal_interrupt <- function() {
  signalCondition(structure(
    class = c("interrupt", "condition"),
    list(message = "interrupted", call = NULL)
  ))
  stop("interrupted", call. = FALSE)
}
#' Tells whether standard input is a terminal.
#' @return TRUE or FALSE.
#' @noRd
.bl_stdin_tty <- function() isatty(stdin())
#' Finds a program on PATH, /bin or /usr/bin without starting a child process.
#'
#' A program in the usual places, found without a child process: Sys.which()
#' runs one, and R ignores SIGINT while a child runs (as system() does), so a
#' Ctrl-C landing there killed only the child. Sys.which(\code{"sh"}) came back
#' \code{""}, the prompt fell back to a blocking read of stdin that ignores
#' Ctrl-C, and the command waited at the prompt (a Ctrl-C 0.18 s after start,
#' 2026-10-14). The search runs over PATH, as the shell does, then /bin and
#' /usr/bin: /bin and /usr/bin alone missed stty on a NixOS-style layout, so the
#' key was echoed as it was typed (network stress test of 5e1dce5).
#' @param name The program's file name.
#' @return The program's path, or \code{""} when it is not found.
#' @noRd
.bl_find_program <- function(name) {
  dirs <- c(
    strsplit(Sys.getenv("PATH"), .Platform$path.sep, fixed = TRUE)[[1L]],
    "/bin",
    "/usr/bin"
  )
  p <- file.path(unique(dirs[nzchar(dirs)]), name)
  p <- p[file.exists(p) & !dir.exists(p)]
  p <- p[file.access(p, 1L) == 0L]
  if (length(p)) p[[1L]] else ""
}
#' Tells whether a program can be found by `.bl_find_program()`.
#' @param name The program's file name.
#' @return TRUE or FALSE.
#' @noRd
.bl_have_program <- function(name) nzchar(.bl_find_program(name))
#' Tells whether standard output is a terminal.
#' @return TRUE or FALSE.
#' @noRd
.bl_stdout_tty <- function() isatty(stdout())

#' Reads one typed line for a prompt.
#'
#' One typed line for a prompt (the key of `login --token`, the emailed code).
#' The launchers run Rscript, where readline() returns \code{""} at once, so
#' outside an interactive session read one line of stdin: typed at a terminal,
#' or piped (`echo KEY | rmbl login --token` keeps the key out of the shell
#' history). Closed or empty stdin gives \code{""}.
#' @param prompt The prompt text.
#' @param con A connection to read from instead of the terminal or standard
#'   input, or NULL.
#' @param secret Whether the line is a key, read without echo at a terminal.
#' @return The line, trimmed; \code{""} for closed or empty input.
#' @noRd
.bl_readline <- function(prompt, con = NULL, secret = FALSE) {
  # a key typed at a terminal is not echoed (stty, where there is one);
  # elsewhere it is read as any other line, which is what piping `echo KEY |`
  # relies on
  hide <- isTRUE(secret) &&
    is.null(con) &&
    .Platform$OS.type == "unix" &&
    .bl_stdin_tty() &&
    .bl_have_program("stty")
  if (.bl_interactive()) {
    if (hide) {
      system2("stty", "-echo", stdout = FALSE, stderr = FALSE)
      on.exit(
        {
          system2("stty", "echo", stdout = FALSE, stderr = FALSE)
          cat("\n", file = stderr())
        },
        add = TRUE
      )
    }
    return(trimws(readline(prompt)))
  }
  if (
    is.null(con) &&
      .bl_stdin_tty() &&
      .Platform$OS.type == "unix" &&
      .bl_have_program("sh")
  ) {
    # R's blocking read of a terminal ignores Ctrl-C until Enter: a shell `read`
    # child sees the terminal's interrupt at once, and Ctrl-D ends it with an
    # empty line. the line comes back over a pipe, never through a shell
    # argument or the history. The echo is switched off and back on by the shell
    # itself, with a trap, so Ctrl-C cannot leave the terminal silent (review of
    # 52a8883, B6); an interrupted read exits 130 and is an interrupt here too
    # The trap also prints a marker: where /bin/sh is dash (Debian, Ubuntu),
    # system2() reports no exit status for the trapped `exit 130`, so Ctrl-C
    # came back as an empty line and a usage error (exit 2; review of 02a38be,
    # C10; bash keeps the status). A typed line cannot hold the marker: Ctrl-C
    # never reaches the input. The shell prints the prompt itself, once its trap
    # is set and the echo is off, and marks a read that completed: R printed the
    # prompt before the child started, so a key typed at once was echoed, and a
    # Ctrl-C in those milliseconds killed the child before its trap and came
    # back as an empty line, exit 2 (review of e57fed5, the C10 leftovers).
    # Output without the completion mark is a read that never finished: an
    # interrupt. The prompt reaches the shell in the environment, never in the
    # script.
    mark <- "\001RMBL-INTERRUPTED\001"
    done <- "\002RMBL-LINE\002"
    # the prompt goes straight to the terminal (this branch runs only when stdin
    # is one): the child's stderr stays discarded, as before, which keeps R's
    # wait on it what it was
    ask <- "printf '%s' \"$RMBL_PROMPT\" > /dev/tty; IFS= read -r l; "
    script <- if (hide) {
      paste0(
        "trap 'stty echo; printf \"\\001RMBL-INTERRUPTED\\001\"; exit 130' ",
        "INT TERM HUP; ",
        "stty -echo; ",
        ask,
        "stty echo; printf '\\002RMBL-LINE\\002%s' \"$l\""
      )
    } else {
      paste0(
        "trap 'printf \"\\001RMBL-INTERRUPTED\\001\"; exit 130' INT TERM HUP; ",
        ask,
        "printf '\\002RMBL-LINE\\002%s' \"$l\""
      )
    }
    # the prompt is handed over in the environment R passes on, not as a
    # `VAR=value sh` prefix: with the prefix /bin/sh kept itself alive as the
    # child's parent, Ctrl-C killed it, and R raised an interrupt of its own
    # after the handled one (exit 1, not 130)
    old_prompt <- Sys.getenv("RMBL_PROMPT", unset = NA)
    Sys.setenv(RMBL_PROMPT = prompt)
    on.exit(
      if (is.na(old_prompt)) {
        Sys.unsetenv("RMBL_PROMPT")
      } else {
        Sys.setenv(RMBL_PROMPT = old_prompt)
      },
      add = TRUE
    )
    # Ctrl-C reaches R as well as the child (one foreground process group): R's
    # own interrupt is held until the read is over, so it arrives once, here,
    # inside the caller's handler, rather than a moment later on top of the
    # interrupt the child reported (exit 1, "Execution halted"; R-devel CI on
    # 487b956 and a704645) a Ctrl-C already pending (one that landed while R or
    # the package was starting) is taken now: left pending, it was lost once the
    # read began, and the command waited at the prompt
    .Call(C_rmbl_check_interrupt)
    # the sh found above, not whichever `sh` comes first on PATH
    l <- suspendInterrupts(suppressWarnings(system2(
      .bl_find_program("sh"),
      c("-c", shQuote(script)),
      stdout = TRUE,
      stderr = FALSE
    )))
    if (hide) {
      cat("\n", file = stderr())
    }
    st <- attr(l, "status")
    l <- paste(as.character(l), collapse = "")
    if (
      identical(as.integer(st), 130L) ||
        grepl(mark, l, fixed = TRUE) ||
        !grepl(done, l, fixed = TRUE)
    ) {
      .bl_signal_interrupt()
    }
    return(trimws(substring(l, regexpr(done, l, fixed = TRUE) + nchar(done))))
  }
  if (is.null(con)) {
    con <- file("stdin")
    on.exit(close(con), add = TRUE)
  }
  if (.bl_stdin_tty()) {
    cat(prompt, file = stderr())
  }
  trimws(paste(readLines(con, n = 1L, warn = FALSE), collapse = ""))
}

#' Run the rmoriebricklayer command line
#'
#' Dispatches the verbs of the \code{rmoriebricklayer} launcher: \describe{
#' \item{\code{login [--token] [--email ADDRESS [--code CODE]]
#' [--no-browser]}}{sign in for the curated tables at data.rmorie.com (a free
#' MORIE data key, issued at \code{www.rmorie.com/access/}): a key you paste
#' with \code{--token} (read from the terminal or a pipe when KEY is omitted), a
#' code sent to \code{--email}, or the GitHub device flow}
#' \item{\code{logout}}{forget the data key} \item{\code{doctor}}{report the
#' language-model routes available here (own endpoint, each provider with your
#' key, local Ollama), in the order \code{ask} tries them} \item{\code{models
#' [--route ROUTE]}}{list the models your provider (or server) offers, the one
#' in use marked} \item{\code{data list}}{the curated tables at data.rmorie.com}
#' \item{\code{data pull db/table}}{download one table as CSV} \item{\code{app
#' [PATH] [--port N] [--no-browser]}}{open the analysis dashboard
#' (\code{\link{rmblapp}}) on this machine, with PATH, a CSV file or a capsule
#' directory, loaded; needs the shiny package} \item{\code{config [setup | set
#' KEY VALUE | unset KEY | get KEY | help]}}{show or change the settings of the
#' language model (\code{\link{llmcfg}}): the route \code{ask} uses and the
#' address, key and model of each route; \code{setup} walks through them}
#' \item{\code{ask [--route ROUTE] [--model NAME] [--fresh] PROMPT...}}{send a
#' prompt to the model (or the named one, on the named route) and print the
#' reply; the same question again is answered from this machine (\code{--fresh}
#' asks anew). \code{aye} and \code{tellme} are the same verb, and a quoted
#' question with no verb (\code{rmbl "how do I weight a survey?"}) is asked too}
#' \item{\code{explain-error MESSAGE...}}{where an error of these packages comes
#' from (\code{\link{explerr}}), without a model or the network}
#' \item{\code{bundle REQUEST...}}{\code{\link{agentbndl}} from the shell}
#' \item{\code{wayback FILE [--out FILE.jsonl] [--jobs N] [--within 30d] [--max
#' N]}}{save every URL listed in FILE (one per line; blank lines and \code{#}
#' comments skipped) in the Internet Archive's Wayback Machine with
#' \code{\link{wbsave}}, results in \code{--out} (default
#' \code{FILE.wayback.jsonl}), so a stopped run carries on; \code{wayback
#' --retry FILE.jsonl [--include-gone]} retries the failures of an earlier run
#' (\code{\link{wbrtry}})} \item{\code{verify PATH [--json] [--fail-on LEVEL]
#' [--public-key HEX]}}{check every capsule under PATH as the rmbl GitHub Action
#' does (\code{\link{cpschk}}): each file against its JSON Schema
#' (\code{\link{schemapath}}), \code{\link{vrfcps}} and
#' \code{\link{cpsbndlvrf}}. The secret of an HMAC bundle is read from
#' \code{RMBL_KEY}, which is then removed from the environment. Prints the
#' Markdown report, or JSON with \code{--json}; exits 1 when a failed row is at
#' or above \code{--fail-on} (\code{error}, the default, \code{drift} or
#' \code{warn}). \code{--base MANIFEST|DIR} compares each manifest with its base
#' copy, \code{--manifests GLOB} checks only the capsule files matching GLOB,
#' \code{--snapshot} looks up each source's latest Wayback snapshot and
#' \code{--no-footprint} leaves the footprint (\code{\link{co2fp}}) out of the
#' report. \code{--seen-log FILE} adds the signatures an XMSS seen-log lists to
#' those under PATH: an XMSS index one key signed twice fails its
#' \code{xmss_index} row} \item{\code{drift PATH [--json] [--fail-on LEVEL]
#' [--html FILE] [--app]}}{ verify, then fetch each source again and compare it
#' column by column (\code{\link{cpsdrft}}, Benford): a column past
#' \code{--psi-warn X} (0.1) is a warning, a flagged one past \code{--psi-fail
#' X} (0.25) drift. \code{--allow-file} accepts \code{file://} sources,
#' \code{--cache DIR} keeps each source and reads it when a fetch fails; the
#' options of verify apply. \code{--html FILE} writes the interactive report
#' (\code{\link{drfthtml}}) and \code{--app} opens it as a Shiny app
#' (\code{\link{drftapp}})} \item{\code{refresh PATH}}{pin each source's new
#' bytes (\code{\link{cpsrfrsh}}) and print what changed
#' (\code{\link{mnfdiff}})} \item{\code{report PATH [--format md|json]}}{the
#' verify report, exit 0; the options of verify apply} \item{\code{sign PATH
#' [--scheme S] [--key-file F] [--overwrite]}}{pin each provenance on its first
#' run and sign each capsule into \code{capsule_bundle.json}
#' (\code{\link{cpsseal}}), then verify as \code{verify} does. The key is
#' \code{RMBL_KEY}, removed from the environment at once, or the contents of
#' \code{--key-file}, and is never printed: the shared secret for \code{hmac}
#' (the default), else the JSON of a \code{\link{fipskg}} key, or its secret hex
#' with \code{--public-key}, or the JSON of a \code{\link{pqckg}} key for
#' \code{xmss-sha256} (see the section XMSS keys). An existing bundle is refused
#' without \code{--overwrite}} \item{\code{functions [PATTERN]}}{list the
#' exported functions with their one-line titles, optionally filtered by a
#' regular expression} \item{\code{describe NAME}}{title, usage, arguments and
#' description of one function, from its help page} \item{\code{examples
#' NAME}}{print the examples of one function} \item{\code{version}}{print the
#' package version (also \code{--version}, \code{-v})} \item{\code{help
#' [VERB]}}{this list, or one verb's usage (also \code{--help}, \code{-h};
#' \code{VERB --help} shows a verb's usage without running it)} } The launcher
#' installed by \code{\link{instcli}} calls this function with the shell's
#' arguments and exits with its status. Calling it from R is the same as typing
#' the command, which is how the examples below work.
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
#' launcher sets it) and \code{options(rmoriebricklayer.dcache)} is not,
#' the data.rmorie.com manifest and tables are kept in
#' \code{tools::R_user_dir("rmoriebricklayer", "cache")} rather than a fresh
#' temporary folder. The verbs \code{login}, \code{logout} and
#' \code{config} write the shared credentials and settings files;
#' \code{ask}, \code{models}, \code{data}, \code{bundle} and
#' \code{wayback} use the network, and \code{drift} and \code{refresh}
#' fetch each capsule's source (\code{refresh} writes the capsule),
#' \code{sign} writes each capsule's provenance and bundle;
#' \code{verify} and \code{report} only read the capsule files;
#' \code{functions}, \code{describe},
#' \code{examples}, \code{explain-error}, \code{version} and \code{help}
#' only read the installed help.
#'
#' @section XMSS keys: An XMSS key (\code{\link{pqckg}}) signs each of its
#' \code{2^height} indices once; two signatures at one index let anyone forge a
#' third. Its private key never changes, but its state, the indices already
#' used, changes with every signature, and a copy of an old state signs used
#' indices again (RFC 10033, \dQuote{Hash-Based Signatures: State and Backup
#' Management}, sections 2 and 4). \code{rmbl sign --scheme xmss-sha256
#' --key-file KEY} therefore treats the key file as the state: \itemize{ \item
#' Before anything is signed it rewrites KEY, under a lock, through a temporary
#' file in the same directory that is flushed to the disk and renamed over it,
#' with \code{next_index} advanced and the state in a \code{used} field:
#' \code{highest} (the highest index used), \code{generation} (one more at every
#' write), \code{writer} (a digest of the host name and boot id), the last
#' \code{reserved} block and, once split, \code{sectors}. A crash after that
#' write loses the reserved indices and never reuses one. A KEY that cannot be
#' rewritten (not writable, a read-only file system) is refused. \item
#' \code{--state-file FILE} keeps the state in FILE (an absolute path to a
#' writable regular file, or a new file in a writable directory) and only reads
#' KEY; a key in \code{RMBL_KEY} needs it. The command line never uses the
#' configuration directory that \code{\link{cpssign}} uses in an R session; it
#' reads and updates the record in \code{RMBL_XMSS_INDEX_FILE} only when that is
#' set. \item \code{--sectors K --sector NAME} (K a power of two, at most half
#' the indices) splits the indices into K disjoint ranges and signs only in one
#' of them, which keeps its own highest index; the range of NAME is SHA-256 of
#' NAME and the key fingerprint, modulo K. Two names land in one sector by
#' chance, so for real use give each runner its own \code{--sector-index I}. A
#' sector that is used up is refused. Once split, sign only through \code{rmbl
#' sign}. \item \code{--reserve N} marks the next N indices used in one write
#' (at least one per capsule signed); the capsules of the run are signed from
#' that block, and the indices it does not use are lost, as RFC 10033, section
#' 5.9 allows. \item A stale copy is refused: when a bundle under PATH, or the
#' \code{--seen-log FILE} that every \code{rmbl sign} appends its signatures to,
#' shows this key signed an index above what the state says, nothing is signed.
#' A note says when another host wrote the state last. \item When N or fewer
#' indices are left in the range (\code{--warn-left N}, by default a tenth of
#' the range) a warning is printed in the report and on standard error (RFC
#' 10033, section 3.4). } A CI secret is a fixed copy of the key that every job
#' starts from, so each job would sign the same indices again: in CI sign with
#' ML-DSA (\code{\link{fipskg}}), or keep the XMSS state in a file that persists
#' between jobs and give each concurrent runner its own sector. \code{rmbl
#' verify} shows each XMSS signature's index and key fingerprint, and
#' \code{\link{xmssidxseen}} lists indices signed twice. NIST SP 800-208
#' approves XMSS only when the key is made and used inside a hardware
#' cryptographic module that never exports it; a key file is software, so this
#' follows the software guidance of RFC 10033 and is not a validated SP 800-208
#' deployment.
#'
#' @param args Character vector of arguments, verb first. The default is the
#'   command line, \code{commandArgs(trailingOnly = TRUE)}. An empty vector
#'   prints the help.
#' @param out Function that receives the output text, one string at a time
#'   (default \code{cat}, the console). Pass a function that collects the
#'   strings to capture the output.
#' @return The exit status (integer scalar), invisibly: 0 on success, 1 on
#'   failure, 2 for a usage error, 130 when interrupted.
#' @seealso \code{\link{instcli}} to put the command on your PATH.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' blcli("version")
#' blcli("help")
#'
#' # one verb's usage
#' blcli(c("help", "data"))
#'
#' # capture the output instead of printing it
#' con <- textConnection("lines", "w")
#' status <- blcli(c("functions", "^drbg_"), out = function(x) {
#'   cat(x, file = con)
#' })
#' close(con)
#' status
#' lines
#'
#' # an unknown verb is a usage error: status 2, nothing run
#' blcli("nonsense")
#'
#' # check a capsule as the rmbl GitHub Action does
#' d <- usecpstmpl(tempfile("capsule-"), ex = TRUE)
#' invisible(cpsrfrsh(d))
#' blcli(c("verify", d))
#'
#' @examplesIf interactive()
#' # these read every help page, which takes a few seconds
#' blcli(c("functions", "json"))
#' blcli(c("describe", "anltab"))
#' blcli(c("examples", "perdays"))
#' @export
blcli <- function(args = commandArgs(trailingOnly = TRUE), out = cat) {
  if (!is.function(out)) {
    stop(
      "`out` must be a function that writes text, as cat() does",
      call. = FALSE
    )
  }
  old_progress <- options(morie.progress = TRUE) # downloads draw their bar
  on.exit(options(old_progress), add = TRUE)
  if (nzchar(Sys.getenv("RMBL_PROG")) && is.null(.rmbl_getopt("dcache"))) {
    # from the shell every call is a new R session: keep the data.rmorie.com
    # manifest and tables in the user cache (tools::R_user_dir) instead of a
    # fresh tempdir() each time
    old_cache <- options(
      rmoriebricklayer.dcache = tools::R_user_dir("rmoriebricklayer", "cache")
    )
    on.exit(options(old_cache), add = TRUE)
  }
  # NA or a closure failed in R's words further on (pre-CRAN audit of 30bed8e)
  if (!is.null(args) && (!is.atomic(args) || anyNA(args))) {
    stop(
      .rmbl_fn(),
      "`args` must be a character vector of command-line words, with no NA",
      call. = FALSE
    )
  }
  a <- .bl_cli_words(as.character(args))
  verb <- a$verb
  rest <- a$rest
  tail_args <- a$tail_args
  prog <- .bl_prog()
  # `VERB --help` describes the verb and never runs it (logout --help used to
  # forget the key)
  if (
    !verb %in% c("help", "--help", "-h") && any(rest %in% c("--help", "-h"))
  ) {
    u <- .bl_verb_usage(verb, prog)
    if (is.null(u)) {
      out(sprintf("%s: %s\n", prog, .bl_unknown_verb(verb, prog)))
      return(invisible(2L))
    }
    out(u)
    return(invisible(0L))
  }
  bad <- .bl_cli_bad_opts(verb, rest, prog)
  if (length(bad)) {
    out(sprintf(
      "%s %s: unknown option %s (%s %s --help)\n",
      prog,
      verb,
      bad[[1L]],
      prog,
      verb
    ))
    return(invisible(2L))
  }
  # the handlers return the exit status: usage error 2, any other error 1,
  # Ctrl-C 130
  status <- tryCatch(
    {
      # arguments after a bare `--` are a prompt or a request: only ask and
      # bundle take one, and every other verb ignored them (`functions -- a b`
      # listed everything)
      if (length(tail_args) && !verb %in% c("ask", "bundle", "explain-error")) {
        # the verb as it prints: an escape sequence typed into it is not sent to
        # the terminal
        .bl_cli_usage_error(sprintf(
          "%s takes no arguments after --",
          .rmbl_printable(verb)
        ))
      }
      handler <- .bl_cli_handlers()[[verb]]
      if (is.null(handler)) {
        .bl_cli_usage_error(.bl_unknown_verb(verb, prog))
      }
      ctx <- list(
        verb = verb,
        rest = rest,
        tail_args = tail_args,
        out = out,
        prog = prog
      )
      st <- handler(ctx)
      if (is.null(st)) 0L else st
    },
    error = function(e) {
      out(paste0(prog, ": ", conditionMessage(e), "\n"))
      if (inherits(e, "bl_usage")) 2L else 1L
    },
    interrupt = function(e) {
      # Ctrl-C at a prompt: the shell convention, 128 + SIGINT, not a usage
      # error
      out(paste0(prog, ": interrupted\n"))
      130L
    }
  )
  invisible(status)
}

#' The command-line words as a verb, its options and the words after a bare
#' `--`.
#'
#' `aye` and `tellme` are other names for ask, and a question with no verb is
#' asked when it plainly is one (.bl_bare_question): `rmbl "how do I weight a
#' survey?"`, `rmbl "how?" --fresh`. A typo with a quoted argument, a file name
#' or a pasted key stays an unknown verb and never reaches a model.
#' @param args The words.
#' @return A list: verb, rest and tail_args.
#' @noRd
.bl_cli_words <- function(args) {
  if (length(args) && identical(args[[1L]], "--args")) {
    args <- args[-1L]
  } # R >= 4.6 keeps the separator
  verb <- if (length(args)) args[[1L]] else "help"
  rest <- args[-1L]
  if (verb %in% c("aye", "tellme")) {
    verb <- "ask"
  } else if (is.null(.bl_verb_usage(verb)) && .bl_bare_question(args)) {
    rest <- args
    verb <- "ask"
  }
  # everything after a bare `--` is positional: a prompt or request that itself
  # starts with --
  dd <- match("--", rest)
  tail_args <- if (is.na(dd)) character() else rest[-seq_len(dd)]
  if (!is.na(dd)) {
    rest <- rest[seq_len(dd - 1L)]
  }
  list(verb = verb, rest = rest, tail_args = tail_args)
}

#' Stops with a usage error (exit status 2).
#' @param msg What is wrong.
#' @noRd
.bl_cli_usage_error <- function(msg) {
  stop(structure(
    class = c("bl_usage", "error", "condition"),
    list(message = msg, call = NULL)
  ))
}

#' The value of an option in `rest`, or NULL; an option at the end, or followed
#' by another option, is a usage error.
#' @param rest The words.
#' @param name The option.
#' @return The value, or NULL.
#' @noRd
.bl_cli_flag <- function(rest, name) {
  i <- match(name, rest)
  if (is.na(i)) {
    return(NULL)
  }
  if (i == length(rest) || startsWith(rest[[i + 1L]], "--")) {
    .bl_cli_usage_error(sprintf("%s needs a value", name))
  }
  rest[[i + 1L]]
}

#' The options each verb takes.
#'
#' An option the verb does not take is refused, not run (`logout --x` logged
#' out; ask sent it as the prompt) --force belongs to `config reset` alone:
#' offered to every config verb it became the value of `config set own.key
#' --force` (review of 02a38be, C6)
#' @param rest The words after the verb.
#' @return A list by verb.
#' @noRd
.bl_cli_known_opts <- function(rest) {
  list(
    login = c(
      "--email",
      "--code",
      "--no-browser",
      "--token",
      "--accept-terms",
      "--name",
      "--affiliation",
      "--reason",
      "--restricted",
      "--supervisor-name",
      "--supervisor-role",
      "--supervisor-email"
    ),
    ask = c("--model", "--route", "--fresh"),
    models = "--route",
    data = "--out",
    app = c("--port", "--no-browser"),
    wayback = c(
      "--out",
      "--jobs",
      "--within",
      "--max",
      "--retry",
      "--include-gone"
    ),
    archive = c(
      "--reason",
      "--dir",
      "--private",
      "--also",
      "--out",
      "--sha256",
      "--at",
      "--from",
      "--to",
      "--json"
    ),
    verify = c("--json", "--fail-on", .bl_capsule_opts),
    drift = c("--json", "--fail-on", .bl_capsule_opts, "--html", "--app"),
    report = c("--format", .bl_capsule_opts),
    sign = c(
      "--json",
      "--fail-on",
      "--scheme",
      "--key-file",
      "--public-key",
      "--overwrite",
      "--manifests",
      "--state-file",
      "--sectors",
      "--sector",
      "--sector-index",
      "--reserve",
      "--warn-left",
      "--seen-log"
    ),
    migrate = "--write",
    config = if (length(rest) && identical(rest[[1L]], "reset")) "--force"
  )
}

#' The options given that the verb does not take.
#' @param verb The verb.
#' @param rest The words after it.
#' @param prog The program's name.
#' @return The unknown options (empty when there are none to report).
#' @noRd
.bl_cli_bad_opts <- function(verb, rest, prog) {
  opts <- rest[startsWith(rest, "--")]
  values <- unlist(lapply(
    c(
      "--email",
      "--code",
      "--token",
      "--model",
      "--route",
      "--out",
      "--jobs",
      "--within",
      "--name",
      "--affiliation",
      "--reason",
      "--supervisor-name",
      "--supervisor-role",
      "--supervisor-email",
      "--port",
      .bl_capsule_valued,
      "--html"
    ),
    function(f) {
      i <- match(f, rest)
      if (!is.na(i) && i < length(rest)) rest[[i + 1L]] else NULL
    }
  ))
  bad <- setdiff(opts, c(.bl_cli_known_opts(rest)[[verb]], values))
  # run passes every --ARG on to the function, which refuses an argument it does
  # not take
  if (identical(verb, "run")) {
    return(character())
  }
  is_help <- verb %in% c("help", "--help", "-h")
  if (is_help) {
    bad <- setdiff(opts, c("--help", "-h"))
  }
  if (length(bad) && (is_help || !is.null(.bl_verb_usage(verb, prog)))) {
    return(bad)
  }
  character()
}

#' The verbs of the command line and their handlers. A handler takes the
#' context (verb, rest, tail_args, out, prog) and returns the exit status, or
#' NULL for 0.
#' @return A named list of functions.
#' @noRd
.bl_cli_handlers <- function() {
  capsule <- function(ctx) {
    .bl_cli_capsule(
      ctx$verb,
      ctx$rest,
      .bl_cli_flagger(ctx$rest),
      ctx$out,
      .bl_cli_usage_error
    )
  }
  version <- function(ctx) {
    if (length(c(ctx$rest, ctx$tail_args))) {
      .bl_cli_usage_error("version takes no arguments")
    }
    ctx$out(sprintf(
      "rmoriebricklayer %s\n",
      as.character(utils::packageVersion("rmoriebricklayer"))
    ))
    NULL
  }
  help <- function(ctx) {
    if (length(ctx$rest) > 1L) {
      .bl_cli_usage_error(sprintf("usage: %s help [VERB]", ctx$prog))
    }
    .bl_cli_help(ctx$rest, ctx$out)
  }
  list(
    login = .bl_v_login,
    logout = function(ctx) .bl_v_noargs(ctx, "logout", dlogout),
    doctor = function(ctx) {
      .bl_v_noargs(ctx, "doctor", function() .bl_cli_doctor(ctx$out))
    },
    config = function(ctx) {
      .bl_cli_config(ctx$rest, ctx$out, .bl_cli_usage_error)
      NULL
    },
    models = .bl_v_models,
    ask = .bl_v_ask,
    bundle = .bl_v_bundle,
    functions = .bl_v_functions,
    describe = function(ctx) .bl_v_describe(ctx, .bl_describe),
    examples = function(ctx) .bl_v_describe(ctx, .bl_examples, "examples"),
    migrate = function(ctx) {
      .bl_cli_migrate(
        ctx$rest,
        function(name) name %in% ctx$rest,
        ctx$out,
        .bl_cli_usage_error,
        ctx$prog
      )
    },
    run = function(ctx) {
      .bl_cli_run(ctx$rest, ctx$out, .bl_cli_usage_error, ctx$prog)
    },
    data = function(ctx) {
      .bl_cli_data(ctx$rest, .bl_cli_flagger(ctx$rest), ctx$out)
    },
    app = function(ctx) {
      .bl_cli_app(
        ctx$rest,
        .bl_cli_flagger(ctx$rest),
        function(name) name %in% ctx$rest,
        ctx$out,
        .bl_cli_usage_error
      )
    },
    `explain-error` = function(ctx) {
      .bl_cli_explain(c(ctx$rest, ctx$tail_args), ctx$out, ctx$prog)
    },
    wayback = function(ctx) {
      .bl_cli_wayback(ctx$rest, .bl_cli_flagger(ctx$rest), ctx$out)
    },
    archive = function(ctx) {
      .bl_cli_archive(ctx$rest, .bl_cli_flagger(ctx$rest), ctx$out)
    },
    sign = capsule,
    verify = capsule,
    drift = capsule,
    refresh = capsule,
    report = capsule,
    `--version` = version,
    `-v` = version,
    version = version,
    help = help,
    `--help` = help,
    `-h` = help
  )
}

#' A function of an option's name giving its value in `rest`.
#' @param rest The words.
#' @return The function.
#' @noRd
.bl_cli_flagger <- function(rest) function(name) .bl_cli_flag(rest, name)

#' A verb that takes no arguments.
#' @param ctx The command's context.
#' @param name The verb.
#' @param fn What it does.
#' @return NULL (exit status 0).
#' @noRd
.bl_v_noargs <- function(ctx, name, fn) {
  if (length(c(ctx$rest, ctx$tail_args))) {
    .bl_cli_usage_error(sprintf("%s takes no arguments", name))
  }
  fn()
  NULL
}

#' `login`: a pasted key, or GitHub or an emailed code.
#' @param ctx The command's context.
#' @return NULL (exit status 0).
#' @noRd
.bl_v_login <- function(ctx) {
  rest <- ctx$rest
  flag <- .bl_cli_flagger(rest)
  has <- function(name) name %in% rest
  if (has("--token")) {
    .bl_v_login_token(ctx)
  } else {
    if (has("--code") && is.null(flag("--email"))) {
      .bl_cli_usage_error(
        "--code needs --email ADDRESS (the code was sent there)"
      )
    }
    em <- flag("--email")
    if (
      !is.null(em) &&
        !grepl("^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$", trimws(em))
    ) {
      .bl_cli_usage_error(sprintf(
        "--email: '%s' is not an email address",
        em
      ))
    }
    dlogin(
      email = flag("--email"),
      code = flag("--code"),
      openbro = !has("--no-browser") &&
        interactive(),
      accter = has("--accept-terms"),
      name = flag("--name"),
      affil = flag("--affiliation"),
      purp = flag("--reason"),
      restr = if (has("--restricted")) TRUE else NULL,
      supnm = flag("--supervisor-name"),
      suprole = flag("--supervisor-role"),
      supemail = flag("--supervisor-email")
    )
  }
  ctx$out(sprintf(
    "Logged in: the curated tables at %s are open to you\n",
    tryCatch(.bl_data_url(), error = function(e) "data.rmorie.com")
  ))
  NULL
}

#' `login --token`: the key given (with a warning: it stays in the shell
#' history), or asked for.
#' @param ctx The command's context.
#' @noRd
.bl_v_login_token <- function(ctx) {
  rest <- ctx$rest
  i <- match("--token", rest)
  tok <- if (i < length(rest)) rest[[i + 1L]] else ""
  if (nzchar(tok)) {
    ctx$out(sprintf(
      paste(
        "%s: a key given on the command line stays in the",
        "shell history and is visible",
        "to other users in the process list; `%s login",
        "--token` with no value asks for it\n"
      ),
      ctx$prog,
      ctx$prog
    ))
  }
  if (!nzchar(tok)) {
    tok <- .bl_readline("Paste your MORIE key: ", secret = TRUE)
  }
  if (!nzchar(tok)) {
    .bl_cli_usage_error(
      paste0(
        "--token needs a key: run `login --token` and paste it ",
        "when asked"
      )
    )
  }
  dlogin(token = tok)
}

#' The usage error for a route the command line does not know.
#' @noRd
.bl_v_bad_route <- function() {
  .bl_cli_usage_error(sprintf(
    "--route takes auto, own, ollama or a provider (%s)",
    paste(.bl_llm_presets()$id, collapse = ", ")
  ))
}

#' `models`: the models a route offers.
#' @param ctx The command's context.
#' @return The exit status.
#' @noRd
.bl_v_models <- function(ctx) {
  rest <- ctx$rest
  rte <- .bl_cli_flag(rest, "--route")
  extra <- setdiff(rest, c("--route", rte))
  if (length(c(extra, ctx$tail_args))) {
    .bl_cli_usage_error(sprintf("usage: %s models [--route ROUTE]", ctx$prog))
  }
  if (!is.null(rte) && !rte %in% c("auto", .bl_llm_route_names())) {
    .bl_v_bad_route()
  }
  .bl_cli_models(ctx$out, rte)
}

#' `ask`: a question to the language model.
#' @param ctx The command's context.
#' @return NULL (exit status 0).
#' @noRd
.bl_v_ask <- function(ctx) {
  rest <- ctx$rest
  prog <- ctx$prog
  for (f in c("--model", "--route")) {
    if (sum(rest == f) > 1L) {
      .bl_cli_usage_error(sprintf(
        paste0(
          "%s may be given once (the second would become part of ",
          "the prompt)"
        ),
        f
      ))
    }
  }
  mdl <- .bl_cli_flag(rest, "--model")
  if (!is.null(mdl)) {
    rest <- rest[-(match("--model", rest) + 0:1)]
  }
  fresh <- "--fresh" %in% rest
  rest <- rest[rest != "--fresh"]
  rte <- .bl_cli_flag(rest, "--route")
  if (!is.null(rte)) {
    rest <- rest[-(match("--route", rest) + 0:1)]
    if (identical(rte, "hosted")) {
      stop(.bl_hosted_retired(), call. = FALSE)
    }
    # "auto" is passed through: it means the automatic order this time, over a
    # saved route
    if (!rte %in% c("auto", .bl_llm_route_names())) {
      .bl_v_bad_route()
    }
  }
  if (!length(rest) && !length(ctx$tail_args)) {
    .bl_cli_usage_error(sprintf(
      paste0(
        "usage: %s ask [--route ROUTE] [--model NAME] [--fresh] ",
        "[--] PROMPT..."
      ),
      prog
    ))
  }
  prompt <- paste(c(rest, ctx$tail_args), collapse = " ")
  if (!nzchar(trimws(prompt))) {
    .bl_cli_usage_error(sprintf(
      paste(
        "the prompt is empty (usage: %s ask [--route ROUTE]",
        "[--model NAME]",
        "[--fresh] PROMPT...)"
      ),
      prog
    ))
  }
  ans <- llmask(prompt, model = mdl, route = rte, fresh = fresh)
  ctx$out(paste0(ans, "\n"))
  if (!is.null(attr(ans, "cached"))) {
    ctx$out(sprintf(
      paste0(
        "(the answer saved on %s for this question; `%s ask ",
        "--fresh ...` asks the model again)\n"
      ),
      attr(ans, "cached"),
      prog
    ))
  }
  NULL
}

#' `bundle`: an agent bundle for a request.
#' @param ctx The command's context.
#' @return The exit status.
#' @noRd
.bl_v_bundle <- function(ctx) {
  rest <- c(ctx$rest, ctx$tail_args)
  if (!length(rest)) {
    .bl_cli_usage_error(sprintf("usage: %s bundle REQUEST...", ctx$prog))
  }
  if (!nzchar(trimws(paste(rest, collapse = " ")))) {
    .bl_cli_usage_error(sprintf(
      "the request is empty (usage: %s bundle REQUEST...)",
      ctx$prog
    ))
  }
  # with no language-model route agentbndl() explains how to set one up:
  # nothing was produced, so the command fails
  routed <- !is.null(.bl_llm_route())
  ctx$out(paste0(agentbndl(paste(rest, collapse = " ")), "\n"))
  if (!routed) 1L else NULL
}

#' `functions`: the exported functions, or those matching a pattern.
#' @param ctx The command's context.
#' @return NULL (exit status 0).
#' @noRd
.bl_v_functions <- function(ctx) {
  rest <- ctx$rest
  if (length(rest) > 1L) {
    .bl_cli_usage_error(sprintf("usage: %s functions [PATTERN]", ctx$prog))
  }
  tab <- .bl_function_index(if (length(rest)) rest[[1L]] else NULL)
  if (!nrow(tab)) {
    ctx$out("no exported function matches\n")
    return(NULL)
  }
  w <- max(nchar(tab$name))
  for (i in seq_len(nrow(tab))) {
    ctx$out(sprintf(paste0("  %-", w, "s  %s\n"), tab$name[i], tab$title[i]))
  }
  NULL
}

#' `describe` and `examples`: a function's help page or its examples, through
#' its 0.5.x name too.
#' @param ctx The command's context.
#' @param show The function that renders the page.
#' @param what The verb.
#' @return The exit status.
#' @noRd
.bl_v_describe <- function(ctx, show, what = "describe") {
  rest <- ctx$rest
  if (!length(rest)) {
    .bl_cli_usage_error(sprintf("usage: %s %s NAME", ctx$prog, what))
  }
  old <- if (is.null(.bl_rd_for(rest[[1L]]))) .bl_old_row(rest[[1L]])
  if (!is.null(old)) {
    ctx$out(.bl_old_note(old))
    ctx$out(show(old$new))
  } else if (is.null(.bl_rd_for(rest[[1L]]))) {
    ctx$out(sprintf(
      "no help page for '%s' (%s functions lists them)\n",
      rest[[1L]],
      ctx$prog
    ))
    return(1L)
  } else {
    ctx$out(show(rest[[1L]]))
  }
  NULL
}

#' Tells whether a command line with no verb is a question to send to a model.
#'
#' A question typed with no verb, asked as `ask` would be: the first argument is
#' the question itself (two words or more, or ending in ?), it is not a verb or
#' a near miss of one, it holds no path, line break or key-shaped word, and what
#' follows is only options ask takes. Before, any argument with a space or a
#' last one ending in ? made the whole line a question:
#' `explain-eror "object 'x' not found"`, `"My Documents/urls.txt"` and
#' `conifg set anthropic.key "<key>\r"` (a CRLF key file) went to the model, the
#' key with them (network stress test of 5e1dce5).
#' @param args The command-line arguments.
#' @return TRUE or FALSE.
#' @noRd
.bl_bare_question <- function(args) {
  if (!length(args)) {
    return(FALSE)
  }
  q <- args[[1L]]
  # a tab is a pasted command line, not a question: `$'cnfig\tset\topenai.key'`
  # went to the model (re-test of the b617a3f CRAN stress fixes, finding 3)
  if (
    !nzchar(q) ||
      startsWith(q, "-") ||
      grepl("[\t\r\n\v\f]", q) ||
      grepl("[/\\]", q)
  ) {
    return(FALSE)
  }
  # a key-shaped run anywhere in the line, not only as a whole word: "KEY?",
  # "KEY," or "my key is KEY, thanks" went to a model, and to the wrong provider
  # (CRAN stress test of b617a3f, #2) zero-width characters are no characters: a
  # key broken by one every eleven characters read as words and went to a model
  # (final audit of 1.0.0, #7)
  q <- gsub("[\u200b\u200c\u200d\u2060\ufeff]", "", q)
  if (.bl_key_shaped(q)) {
    return(FALSE)
  }
  # ideographic and no-break spaces split words like a space
  q <- gsub("[\u3000\u00a0\u2007\u202f]", " ", q)
  q <- gsub("\uff1f", "?", q, fixed = TRUE)
  words <- strsplit(trimws(q), "[[:space:]]+")[[1L]]
  # letters in any script (PCRE's \p classes): [[:alpha:]] takes no CJK letter
  # in the C locale, so a Chinese question was refused there
  if (!any(grepl("\\p{L}{2,}", words, perl = TRUE))) {
    return(FALSE)
  }
  # a lone "?" or "!" is punctuation, not a word: `doctr ?` is a near miss of
  # `doctor`
  wordy <- words[grepl("[\\p{L}\\p{N}]", words, perl = TRUE)]
  if (length(wordy) < 2L && !endsWith(q, "?")) {
    return(FALSE)
  }
  if (length(wordy) == 1L) {
    w <- tolower(gsub("[[:punct:]]+", "", wordy[[1L]]))
    if (
      min(utils::adist(w, gsub("-", "", .bl_verb_names(), fixed = TRUE))) <= 2L
    ) {
      return(FALSE)
    }
  }
  # a line that opens with a verb or a near miss of one and is not asked as a
  # question is a command typed as one argument: "cnfig set openai.key" was sent
  # to the first provider. A question mark does not make a sentence of a
  # command's few words: "dat list?" and "conifg set openai.api_key?" went to a
  # model with it (final audit of 1.0.0, #6); a question of five words or more
  # that opens with a verb ("doctor says the data is fine, is it?") is still
  # asked ("describe the drift test?", four words, is a question; the command
  # lines above have three or fewer)
  if (
    .bl_verb_near(words[[1L]]) &&
      (!endsWith(trimws(q), "?") || length(wordy) <= 3L)
  ) {
    return(FALSE)
  }
  # a short line naming a file is a command's argument, not a question:
  # `urls.txt?` and `my urls.txt` were sent (18 of 64 bare file names; CRAN
  # stress test of 0.5.14). A question that names a file in a sentence is still
  # asked.
  if (
    length(wordy) <= 3L &&
      any(grepl("^[^.[:space:]]+\\.[A-Za-z][A-Za-z0-9]{0,4}[?!.,]*$", words))
  ) {
    return(FALSE)
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

#' Tells whether a text holds something shaped like a key.
#'
#' TRUE when the text holds a run of 24 or more key characters anywhere, not
#' only as a whole word. A function name is not one: an export of the package,
#' or snake_case words of up to 15 characters each (survey_design_replicates); a
#' key's random part is one long run, in one case or mixed.
#' @param x A string.
#' @return TRUE or FALSE.
#' @noRd
.bl_key_shaped <- function(x) {
  # a provider's key prefix and twelve key characters or more, a digit among
  # them, is a key however short: `sk-` and 20 characters went to a model
  # (re-test of the b617a3f CRAN stress fixes, finding 4)
  pre <- regmatches(
    x,
    gregexpr(
      paste0(
        "(sk-|sk_|AIza|gsk_|xai-|hf_|r8_|pplx-|fw_|csk-|ghp_|gho_|ghs_|",
        "github_pat_|glpat-|nvapi-)[A-Za-z0-9_-]{12,}"
      ),
      x
    )
  )[[1L]]
  if (
    any(grepl(
      "[0-9]",
      sub(
        paste0(
          "^(sk-|sk_|AIza|gsk_|xai-|hf_|r8_|pplx-|fw_|csk-|ghp_|gho_|ghs_|",
          "github_pat_|glpat-|nvapi-)"
        ),
        "",
        pre
      )
    ))
  ) {
    return(TRUE)
  }
  if (.bl_key_dense(x)) {
    return(TRUE)
  }
  # an AWS access key id: AKIA or ASIA and sixteen capitals or digits, which may
  # all be letters (audit of 30bed8e, #17)
  if (grepl("(AKIA|ASIA)[A-Z0-9]{16}", x)) {
    return(TRUE)
  }
  runs <- regmatches(x, gregexpr("[A-Za-z0-9_+=.:-]{24,}", x))[[1L]]
  runs <- sub("[.:=-]+$", "", runs)
  # words joined by _ or . (survey_design_replicates) are a name, not a key; a
  # segment that mixes letters and digits past a trailing number (k3j9sq2w_...)
  # is a key's, however short each segment. Two segments or more that carry
  # digits are a key's as well (abc123.def456.ghi789 read as a name; final audit
  # of 1.0.0, #7)
  segs <- strsplit(runs, "[_.]")
  named <- vapply(
    segs,
    function(seg) {
      all(grepl("^[a-z]+[0-9]*$", seg)) && sum(grepl("[0-9]", seg)) < 2L
    },
    NA
  )
  runs <- runs[
    nchar(runs) >= 24L &
      !(grepl("^[a-z][a-z0-9]{0,14}([_.][a-z0-9]{1,15})+$", runs) & named) &
      !runs %in% getNamespaceExports(asNamespace("rmoriebricklayer"))
  ]
  if (length(runs)) {
    return(TRUE)
  }
  # a key typed in groups (abcd1234efgh ijkl5678mnop qrst9012uvwx): three words
  # or more in a row of 8 to 16 letters and digits each, every one holding both
  # (final audit of 1.0.0, #7) zero-width characters are no characters and a
  # no-break or ideographic space splits words like a space, here as in the
  # question rule: a grouped key with no-break spaces between its groups went to
  # a model (re-check of 1.0.0)
  x <- gsub("[\u200b\u200c\u200d\u2060\ufeff]", "", x)
  x <- gsub("[\u3000\u00a0\u2007\u202f]", " ", x)
  # groups are split at anything but a letter or a digit, a space or not:
  # "abcd1234efgh;ijkl5678mnop; qrst9012uvwx" with no space went to a model with
  # each of ! # $ % & * , ; @ ^ | ~ (audit of 30bed8e)
  w <- strsplit(trimws(x), "[^A-Za-z0-9]+")[[1L]]
  grp <- grepl("^[A-Za-z0-9]{8,16}$", w) &
    grepl("[0-9]", w) &
    grepl("[A-Za-z]", w)
  r <- rle(grp)
  any(r$values & r$lengths >= 3L)
}

#' Tells whether a text holds a dense mixed run of letters and digits.
#'
#' TRUE when the text holds a run of 16 or more letters and digits, mixed, that
#' is not a word and a number (population2021): the shape of an archive.org S3
#' key (16 characters) and of most keys' random parts. They went to a model as
#' words (CRAN stress test of 0.5.14).
#' @param x A string.
#' @return TRUE or FALSE.
#' @noRd
.bl_key_dense <- function(x) {
  r <- regmatches(x, gregexpr("[A-Za-z0-9]{16,}", x))[[1L]]
  dense <- r[
    grepl("[0-9]", r) &
      grepl("[A-Za-z]", r) &
      !grepl("^([A-Za-z][a-z]+[0-9]{1,4}|[0-9]{1,4}[A-Za-z][a-z]+)$", r)
  ]
  if (length(dense)) {
    return(TRUE)
  }
  # sixteen letters or more with no digit, in both cases and changing case four
  # times or more (FAKEKXsOCOxzNZfl): no word is written so, and such keys went
  # to a model (final audit of 1.0.0, #7). A capitalised word (Rmoriebricklayer)
  # changes case once.
  letters_only <- r[!grepl("[0-9]", r)]
  any(vapply(
    letters_only,
    function(t) {
      cls <- grepl("[A-Z]", strsplit(t, "")[[1L]])
      sum(cls[-1L] != cls[-length(cls)]) >= 4L
    },
    NA
  ))
}

#' Every verb and spelling the command takes, for the bare-question rule and
#' \dQuote{did you mean}.
#' @return A character vector of verbs.
#' @noRd
.bl_verb_names <- function() {
  c(.bl_verb_usage(NULL), "help", "version", "aye", "tellme")
}

#' Tells whether a word is a verb or a near miss of one.
#'
#' TRUE when a word is a verb or a near miss of one: one edit for a word of four
#' or five letters, two for a longer one (shorter words, \code{"is"},
#' \code{"how"}, are too close to everything to tell)
#' @param word The word to test.
#' @return TRUE or FALSE.
#' @noRd
.bl_verb_near <- function(word) {
  w <- tolower(gsub("[\"'?!.,\uff1f[:punct:]]+", "", word))
  n <- nchar(w)
  # three letters too, one edit away (`dat list` was sent; CRAN stress test of
  # 0.5.14): of the words a question opens with only "are" is that near a verb
  # (aye); a hyphen is no letter on either side (`xplain-rror` is two edits from
  # explain-error)
  if (n < 3L || w == "are") {
    return(FALSE)
  }
  min(utils::adist(w, gsub("-", "", .bl_verb_names(), fixed = TRUE))) <=
    (if (n <= 5L) 1L else 2L)
}

#' The line for an unknown verb: the nearest verb when one is close, and how to
#' ask a model.
#' @param verb The verb as typed.
#' @param prog The command's name, as shown to the user.
#' @return One string.
#' @noRd
.bl_unknown_verb <- function(verb, prog) {
  v <- .bl_verb_names()
  # quotes and a trailing ? or ! around a typo are not part of it: `"doctr?"` is
  # a near miss too the first word of a command typed as one argument (`"cnfig
  # set openai.key"`, tab-joined) is the verb
  first <- strsplit(trimws(gsub("[\u3000\u00a0]", " ", verb)), "[[:space:]]+")[[
    1L
  ]]
  w <- if (length(first) > 1L && .bl_verb_near(first[[1L]])) {
    first[[1L]]
  } else {
    verb
  }
  d <- utils::adist(tolower(gsub("[\"'?!.,\uff1f\u3000[:space:]]+", "", w)), v)
  near <- if (min(d) <= 2L) {
    sprintf(" (did you mean `%s %s`?)", prog, v[which.min(d)])
  } else {
    ""
  }
  # a pasted key is not printed back to the terminal and its scrollback (network
  # stress test of 5e1dce5)
  shown <- if (.bl_key_shaped(verb)) {
    "(an argument like a key, not shown)"
  } else {
    .rmbl_printable(verb)
  }
  sprintf(
    "unknown verb '%s'%s; try `%s help`, or `%s ask \"QUESTION\"` for a model",
    shown,
    near,
    prog,
    prog
  )
}

#' One usage line per verb, for `VERB --help`; NULL for a verb that does not
#' exist.
#' @param verb The verb, or NULL for the names of every verb.
#' @param prog The command's name, as shown to the user.
#' @return One usage string, the verb names, or NULL.
#' @noRd
.bl_verb_usage <- function(verb, prog = "rmoriebricklayer") {
  u <- c(
    login = paste(
      "login [--email ADDRESS [--code CODE]] [--no-browser]",
      "[--accept-terms] [--name NAME]",
      "[--affiliation ORG] [--reason TEXT] [--restricted",
      "--supervisor-name NAME",
      "--supervisor-role ROLE --supervisor-email ADDRESS] | login --token",
      "  sign in for the curated tables at data.rmorie.com"
    ),
    logout = "logout   forget the data key",
    doctor = "doctor   report the language-model routes available here",
    models = paste0(
      "models [--route ROUTE]   the models your provider (or server) ",
      "offers (the one in use marked)"
    ),
    ask = paste(
      "ask [--route auto|own|ollama|PROVIDER] [--model NAME] [--fresh]",
      "PROMPT...",
      "  ask the model (your own key; --fresh: not the answer saved for",
      "the same question)"
    ),
    `explain-error` = paste0(
      "explain-error MESSAGE...   where an error of these packages comes ",
      "from, without a model"
    ),
    config = paste(
      "config [show | help | get KEY | set KEY VALUE | unset KEY |",
      "setup | path | reset]",
      "  show or change the language-model settings (route, addresses,",
      "keys, models)"
    ),
    bundle = "bundle REQUEST...   agentbndl() from the shell",
    functions = "functions [PATTERN]   exported functions and their titles",
    describe = paste0(
      "describe NAME   help page of one function (a 0.5.x name: what it ",
      "became, then its page)"
    ),
    examples = "examples NAME   the examples of one function",
    run = paste(
      "run NAME [VALUE...] [--ARG VALUE...]   call a function by its",
      "1.0.0 or 0.5.x name (old",
      "arguments and values translated); a .csv or .rds VALUE is read,",
      "a,b,c is a vector"
    ),
    migrate = paste0(
      "migrate FILE.R... [--write]   rewrite the 0.5.x names in R scripts ",
      "to 1.0.0 (shows the changes)"
    ),
    data = paste0(
      "data list | data pull db/table [--out FILE.csv]   curated tables ",
      "at data.rmorie.com (your MORIE key)"
    ),
    app = paste0(
      "app [PATH] [--port N] [--no-browser]   the analysis dashboard ",
      "(rmblapp()); PATH a CSV file or a capsule"
    ),
    wayback = paste(
      "wayback FILE [--out FILE.jsonl] [--jobs N] [--within 30d] [--max",
      "N]   archive every URL in FILE;",
      "wayback --retry FILE.jsonl [--include-gone]   retry the failures",
      "of an earlier run;",
      "(keys: IA_S3_ACCESS_KEY and IA_S3_SECRET_KEY, or their _FILE twins)"
    ),
    archive = paste(
      "archive save URL... --reason TEXT [--dir D] [--private] [--also",
      "wayback]   save from this",
      "connection to archive.rmorie.com (your key: login), with WARC",
      "copies in D;",
      "archive find URL [--from YYYY] [--to YYYY] [--json]   list its",
      "captures (URL* for a prefix);",
      "archive get ID|URL -o FILE [--sha256 HEX] [--at YYYYMMDD]   the",
      "exact bytes, checked"
    ),
    verify = paste(
      "verify PATH [--json] [--fail-on error|warn|drift] [--public-key",
      "HEX] [--base MANIFEST|DIR]",
      "[--manifests GLOB] [--snapshot] [--no-footprint] [--seen-log",
      "FILE]   check every capsule under",
      "PATH: schemas, data digests, bundle files and signature (an hmac",
      "secret in RMBL_KEY); --base",
      "compares each manifest with its base copy, --snapshot looks up",
      "each source's latest Wayback",
      "snapshot; an XMSS index the same key signed twice, under PATH or",
      "in --seen-log, fails its row"
    ),
    drift = paste(
      "drift PATH [--json] [--fail-on error|warn|drift] [--psi-warn",
      "0.1] [--psi-fail 0.25]",
      "[--allow-file] [--cache DIR] [the options of verify]   verify,",
      "then fetch each source again",
      "and compare it with the pin, column by column in the PSI bands",
      "(--allow-file: file:// sources;",
      "--cache: keep each source, read when a fetch fails); [--html",
      "FILE] writes the interactive report",
      "(drfthtml()), [--app] opens it as a Shiny app (drftapp())"
    ),
    refresh = paste0(
      "refresh PATH   fetch each capsule's source and pin its new bytes ",
      "in the provenance (cpsrfrsh())"
    ),
    sign = paste(
      "sign PATH [--scheme hmac|ML-DSA-44|...|xmss-sha256] [--key-file",
      "FILE] [--public-key HEX]",
      "[--overwrite] [--manifests GLOB] [--json] [--fail-on LEVEL]  ",
      "pin each provenance on its first run",
      "and sign each capsule into capsule_bundle.json (cpsseal()), then",
      "verify; the key is RMBL_KEY or",
      "the contents of --key-file (for a standardised scheme the JSON",
      "of fipskg(), or the secret's hex",
      "with --public-key), never printed. xmss-sha256: the key file is",
      "the key's state, rewritten before",
      "anything is signed; [--state-file FILE] keeps the state",
      "elsewhere, [--sectors K --sector NAME |",
      "--sector-index I] signs in one of K disjoint index ranges,",
      "[--reserve N] reserves N indices in one",
      "write, [--warn-left N] warns when N or fewer are left,",
      "[--seen-log FILE] refuses a stale copy of",
      "the key and logs each signature (help blcli, section XMSS keys)"
    ),
    report = paste0(
      "report PATH [--format md|json] [the options of verify]   the ",
      "verify report; never fails"
    ),
    version = "version   package version"
  )
  if (is.null(verb)) {
    return(names(u))
  }
  if (!verb %in% names(u)) {
    return(NULL)
  }
  sprintf("usage: %s %s\n", prog, u[[verb]])
}

#' Returns the Rd database of this package.
#'
#' The Rd database of this package: the installed copy when there is one,
#' else the man/ directory of a source tree loaded with pkgload.
#' @param db The installed Rd database, or NULL.
#' @param man The man directory of the installed package, or \code{""}.
#' @return A list of Rd objects, empty when there is none.
#' @noRd
.bl_rd_db <- function(
  db = tryCatch(tools::Rd_db("rmoriebricklayer"), error = function(e) NULL),
  man = system.file("man", package = "rmoriebricklayer")
) {
  if (length(db)) {
    return(db)
  }
  if (nzchar(man)) {
    db <- tryCatch(tools::Rd_db(dir = dirname(man)), error = function(e) NULL)
  }
  if (length(db)) db else list()
}

#' Returns the Rd tag of every top-level element of an Rd object.
#' @param rd An Rd object.
#' @return A character vector, \code{""} for an untagged element.
#' @noRd
.bl_rd_tags <- function(rd) {
  vapply(rd, function(x) attr(x, "Rd_tag") %||% "", "")
}

#' Returns the aliases of an Rd page.
#' @param rd An Rd object.
#' @return A character vector.
#' @noRd
.bl_rd_aliases <- function(rd) {
  al <- rd[.bl_rd_tags(rd) == "\\alias"]
  unlist(lapply(al, function(a) as.character(a[[1L]])))
}

#' Finds the help page whose aliases include a name.
#' @param name The function name.
#' @return An Rd object, or NULL.
#' @noRd
.bl_rd_for <- function(name) {
  for (rd in .bl_rd_db()) {
    if (name %in% .bl_rd_aliases(rd)) {
      return(rd)
    }
  }
  NULL
}

#' Renders an Rd page as plain text.
#'
#' Rd2txt renders a whole page; sections come back headed \code{"Usage:"},
#' \code{"Arguments:"}, \code{"Examples:"} when underlining is off.
#' @param rd An Rd object.
#' @return A character vector of lines.
#' @noRd
.bl_rd_text <- function(rd) {
  txt <- utils::capture.output(
    tools::Rd2txt(rd, options = list(underline_titles = FALSE, width = 78))
  )
  txt
}

#' Lists the exported functions and the titles of their help pages.
#' @param pattern A regular expression the names must match, or NULL for all.
#' @return A data frame with columns `name` and `title`.
#' @noRd
.bl_function_index <- function(pattern = NULL) {
  ns <- getNamespaceExports("rmoriebricklayer")
  ns <- sort(ns[!startsWith(ns, ".")])
  if (!is.null(pattern)) {
    ns <- ns[grepl(pattern, ns)]
  }
  titles <- character(length(ns))
  names(titles) <- ns
  for (rd in .bl_rd_db()) {
    hit <- intersect(.bl_rd_aliases(rd), ns)
    if (!length(hit)) {
      next
    }
    ti <- which(.bl_rd_tags(rd) == "\\title")
    if (length(ti)) {
      titles[hit] <- trimws(paste(
        as.character(unlist(rd[[ti[1L]]])),
        collapse = ""
      ))
    }
  }
  data.frame(name = ns, title = unname(titles), stringsAsFactors = FALSE)
}

#' Returns the help page of one function as text, without its examples.
#' @param name The function name.
#' @return One string.
#' @noRd
.bl_describe <- function(name) {
  rd <- .bl_rd_for(name)
  if (is.null(rd)) {
    return(sprintf("no help page for '%s'\n", name))
  }
  txt <- .bl_rd_text(rd)
  cut <- which(txt == "Examples:")
  if (length(cut)) {
    txt <- txt[seq_len(cut[1L] - 1L)]
  }
  paste0(paste(txt, collapse = "\n"), "\n")
}

#' Returns the examples section of one function's help page as text.
#' @param name The function name.
#' @return One string.
#' @noRd
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

#' Returns the path of the installed launcher.
#'
#' The installed launcher, \code{""} when it is missing (a function, so a test
#' can say it is missing without renaming a file in the installed library)
#' @return A path, or \code{""}.
#' @noRd
.bl_launcher <- function() {
  system.file("bin", "rmoriebricklayer", package = "rmoriebricklayer")
}

#' Install the rmoriebricklayer command-line launcher
#'
#' Writes small launcher scripts into a directory on your PATH so that
#' \code{rmoriebricklayer login}, \code{rmbl ask ...} and the other verbs of
#' \code{\link{blcli}} work from any shell. Run it once after
#' installing or upgrading the package. Nothing outside \code{dir} is
#' touched, and only when you call this.
#'
#' @details
#' On Unix-alikes each launcher is a \code{/bin/sh} script (mode 0755) that
#' sets \code{RMBL_PROG} to its own name and runs
#' \code{Rscript -e "rmoriebricklayer::blcli()"} with the shell's
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
#' \code{inst/bin} (a damaged installation); when \code{dir}
#' cannot be created or written, or is not one string; and
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
#' @seealso \code{\link{blcli}} for the verbs.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # into a scratch folder, so nothing on your PATH changes
#' d <- file.path(tempdir(), "bin")
#' p <- instcli(dir = d)
#' list.files(d)
#' readLines(p)[1:4]
#'
#' # one name only
#' instcli(dir = d, name = "rmbl")
#'
#' @examplesIf interactive()
#' instcli()   # ~/.local/bin/rmoriebricklayer and ~/.local/bin/rmbl
#' @export
instcli <- function(
  dir = file.path(path.expand("~"), ".local", "bin"),
  name = c("rmoriebricklayer", "rmbl")
) {
  # an empty `name` wrote nothing, printed "Installed ;" and failed on
  # targets[[1L]]
  if (
    !is.character(name) ||
      !length(name) ||
      anyNA(name) ||
      any(!nzchar(name)) ||
      any(basename(name) != name)
  ) {
    stop(
      "`name` must be one or more command names (non-empty, no NA, no ",
      "directory part)",
      call. = FALSE
    )
  }
  dir <- .rmbl_string1(dir, "dir")
  src <- .bl_launcher()
  if (!nzchar(src)) {
    stop("the launcher is missing from this installation", call. = FALSE)
  }
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  # a folder that cannot be made or written failed later in file()'s words
  # (pre-CRAN audit of 30bed8e)
  if (!dir.exists(dir) || file.access(dir, 2L) != 0L) {
    stop(
      .rmbl_fn(),
      sprintf("`dir` %s cannot be created or written", dir),
      call. = FALSE
    )
  }
  # the launcher pins the library this copy of the package lives in, inside R
  # with .libPaths(), so the shell's R_LIBS or an R_LIBS in ~/.Renviron cannot
  # swap in another copy
  lib <- normalizePath(
    dirname(system.file(package = "rmoriebricklayer")),
    winslash = "/"
  )
  targets <- character()
  for (nm in name) {
    if (.Platform$OS.type == "windows") {
      # nocov start -- the Windows wrapper; the coverage runner is Linux
      target <- file.path(dir, paste0(nm, ".cmd"))
      writeLines(
        sprintf(
          paste0(
            "@echo off\r\nset RMBL_PROG=",
            nm,
            "\r\nRscript --no-save --no-restore -e ",
            "\".libPaths(c('%s', .libPaths())); ",
            "q <- tryCatch(rmoriebricklayer::blcli(), interrupt = ",
            "function(e) 130L); ",
            "quit(status = as.integer(q))\" %%*"
          ),
          lib
        ),
        target
      )
      # nocov end
    } else {
      target <- file.path(dir, nm)
      if (file.exists(target) || !is.na(Sys.readlink(target))) {
        unlink(target)
      }
      # the library path is an R string literal (deparse() escapes it) inside
      # a single-quoted shell argument (a quote in the path becomes '\'')
      # a Ctrl-C that reaches the top level exits 130, not 1 (as inst/bin/rmbl)
      body <- paste0(
        "suppressPackageStartupMessages({ .libPaths(c(",
        deparse(lib),
        ", .libPaths())); ",
        "q <- tryCatch(rmoriebricklayer::blcli(), interrupt = ",
        "function(e) 130L); ",
        "quit(status = as.integer(q)) })"
      )
      body <- gsub("'", "'\\\\''", body)
      writeLines(
        c(
          "#!/bin/sh",
          sprintf(
            paste0(
              "# %s: the rmoriebricklayer command line (written by ",
              "rmoriebricklayer::instcli())"
            ),
            nm
          ),
          sprintf(
            "# runs the package in %s (pinned with .libPaths() inside R)",
            lib
          ),
          sprintf("export RMBL_PROG=%s", nm),
          sprintf("exec Rscript --no-save --no-restore -e '%s' \"$@\"", body)
        ),
        target
      )
      Sys.chmod(target, "0755")
    }
    targets <- c(targets, target)
  }
  on_path <- dir %in% strsplit(Sys.getenv("PATH"), .Platform$path.sep)[[1L]]
  message(sprintf(
    "Installed %s%s",
    paste(targets, collapse = " and "),
    if (on_path) "" else sprintf("; add %s to your PATH", dir)
  ))
  invisible(targets[[1L]]) # the primary launcher's path; rmbl sits beside it
}

#' The models verb: the models the route `ask` would take offers (or the one
#' named), default marked.
#' @param out The function that prints the verb's output.
#' @param route The route named with `--route`, or NULL.
#' @return The exit status, invisibly.
#' @noRd
.bl_cli_models <- function(out, route = NULL) {
  rt <- .bl_llm_route(route)
  if (is.null(rt)) {
    out(paste0(.bl_no_route_message(route), "\n"))
    return(invisible(1L))
  }
  have <- .bl_llm_list_models(rt) %||% character()
  if (!length(have)) {
    out(sprintf(
      paste0(
        "%s: no model list to show (the provider does not publish one, or ",
        "did not answer)%s\n"
      ),
      rt$name,
      if (!is.null(rt$model)) {
        sprintf("; the model in use is %s", rt$model)
      } else {
        ""
      }
    ))
    return(invisible(0L))
  }
  out(sprintf("%s; the model in use is marked *:\n", rt$name))
  for (m in have) {
    out(sprintf("  %s %s\n", if (identical(m, rt$model)) "*" else " ", m))
  }
  pick <- if (!is.null(rt$id)) {
    sprintf("`%s config set %s.model NAME`", .bl_prog(), rt$id)
  } else if (identical(rt$name, "local Ollama")) {
    sprintf("`%s config set ollama.model NAME`", .bl_prog())
  } else {
    sprintf("`%s config set own.model NAME`", .bl_prog())
  }
  out(sprintf(
    "Pick one per call with `%s ask --model NAME ...`, or keep one with %s.\n",
    .bl_prog(),
    pick
  ))
  invisible(0L)
}

#' Runs the wayback verb.
#'
#' The wayback verb: every URL in a file (one per line; blank lines and #
#' comments skipped) saved in the Wayback Machine by wbsave(), results in --out
#' (default FILE.wayback.jsonl), which also lets a stopped run carry on.
#' @param rest The arguments after the verb.
#' @param flag A function that returns the value of an option, or NULL.
#' @param out The function that prints the verb's output.
#' @return The exit status.
#' @noRd
.bl_cli_wayback <- function(rest, flag, out) {
  pos <- rest
  for (f in c("--out", "--jobs", "--within", "--max")) {
    i <- match(f, pos)
    if (!is.na(i)) pos <- pos[-c(i, i + 1L)]
  }
  cap <- flag("--max") %||% "1000"
  # --retry FILE.jsonl: the failures of an earlier run, looked up and captured
  # again (wbrtry)
  retry <- "--retry" %in% pos
  gone <- "--include-gone" %in% pos
  pos <- setdiff(pos, c("--retry", "--include-gone"))
  if (retry) {
    if (length(pos) != 1L || !file.exists(pos[[1L]])) {
      out(sprintf(
        "--retry takes the results file of an earlier run: %s\n",
        if (length(pos) == 1L) {
          paste("no such file", pos[[1L]])
        } else {
          "give one FILE.jsonl"
        }
      ))
      return(if (length(pos) == 1L) 1L else 2L)
    }
    res <- wbrtry(
      pos[[1L]],
      incgone = gone,
      jobs = flag("--jobs") %||% "4",
      within = flag("--within") %||% "30d",
      maxcap = cap
    )
    r <- attr(res, "retry")
    tab <- table(factor(
      res$status,
      levels = c("saved", "existing", "failed", "submitted")
    ))
    out(sprintf(
      paste(
        "%d failures: %d found already archived, %d captured again, %d",
        "left as gone,",
        "%d left for tomorrow (a daily limit); now %d saved, %d",
        "existing, %d failed in %s\n"
      ),
      r$failed,
      r$found_by_lookup,
      r$captured_again,
      r$left_as_gone,
      r$left_for_tomorrow,
      tab[["saved"]],
      tab[["existing"]],
      tab[["failed"]],
      pos[[1L]]
    ))
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
  res <- wbsave(
    urls,
    jobs = jobs,
    within = flag("--within") %||% "30d",
    output = flag("--out") %||% paste0(pos[[1L]], ".wayback.jsonl"),
    maxcap = cap
  )
  tab <- table(factor(
    res$status,
    levels = c("saved", "existing", "failed", "submitted")
  ))
  ns <- length(attr(res, "not_sent"))
  out(sprintf(
    "%d saved, %d existing, %d failed%s; results in %s\n",
    tab[["saved"]],
    tab[["existing"]],
    tab[["failed"]],
    if (ns) sprintf(", %d not sent (run again to continue)", ns) else "",
    flag("--out") %||% paste0(pos[[1L]], ".wayback.jsonl")
  ))
  if (tab[["failed"]] > 0L || ns > 0L) 1L else 0L
}

#' The data verb: the curated tables at data.rmorie.com.
#' @param rest The arguments after the verb.
#' @param flag A function that returns the value of an option, or NULL.
#' @param out The function that prints the verb's output.
#' @return The exit status.
#' @noRd
.bl_cli_data <- function(rest, flag, out) {
  sub <- if (length(rest)) rest[[1L]] else "list"
  # the positional words, without --out and its value: an extra word was
  # silently ignored
  pos <- rest
  i <- match("--out", pos)
  if (!is.na(i)) {
    pos <- pos[-c(i, i + 1L)]
  }
  if (
    (identical(sub, "list") && length(pos) > 1L) ||
      (identical(sub, "pull") && length(pos) > 2L)
  ) {
    out(sprintf(
      paste0(
        "usage: %s data list | data pull db/table [--out FILE.csv]  (one ",
        "table per pull)\n"
      ),
      .bl_prog()
    ))
    return(2L)
  }
  if (identical(sub, "list")) {
    out(.bl_format_data_tables(
      dtabs(),
      hint = sprintf(
        "`%s data pull KEY` downloads one (your MORIE key)",
        .bl_prog()
      )
    ))
  } else if (identical(sub, "pull") && length(rest) >= 2L) {
    dest <- flag("--out") %||%
      paste0(gsub("[^A-Za-z0-9_.-]", "_", rest[[2L]]), ".csv")
    # refuse an unwritable destination before downloading the table, not after
    dir <- dirname(dest)
    if (!dir.exists(dir) || file.access(dir, 2L) != 0L || dir.exists(dest)) {
      out(sprintf(
        "cannot write %s (the directory does not exist, or no permission)\n",
        dest
      ))
      return(1L)
    }
    df <- dload(rest[[2L]])
    ok <- tryCatch(
      {
        suppressWarnings(utils::write.csv(df, dest, row.names = FALSE))
        TRUE
      },
      error = function(e) FALSE
    )
    if (!ok) {
      out(sprintf(
        "cannot write %s (the directory does not exist, or no permission)\n",
        dest
      ))
      return(1L)
    }
    out(sprintf("wrote %s  (%d rows, %d cols)\n", dest, nrow(df), ncol(df)))
  } else {
    out(paste0(
      sprintf("usage: %s data list | ", .bl_prog()),
      "data pull db/table [--out FILE.csv]\n"
    ))
    # asking for help is not a mistake: --help exits 0 like every other verb's
    # help
    return(
      if (
        identical(sub, "--help") ||
          identical(sub, "-h") ||
          identical(sub, "help")
      ) {
        0L
      } else {
        2L
      }
    )
  }
  0L
}

#' `rmbl help [TOPIC]`: the verbs, a getting-started guide, and one page per
#' topic.
#' @param rest The arguments after the verb.
#' @param out The function that prints the verb's output.
#' @return The exit status.
#' @noRd
.bl_cli_help <- function(rest, out) {
  prog <- .bl_prog()
  topic <- if (length(rest) && !startsWith(rest[[1L]], "-")) rest[[1L]] else ""
  verbs <- paste0(
    sprintf(
      paste0(
        "usage: %s <verb> [options]   (rmbl is the same command as ",
        "rmoriebricklayer)\n\n"
      ),
      prog
    ),
    "Language models (your own key, or a model on your machine)\n",
    "  ask [--route R] [--model NAME] PROMPT...  ask a model and print ",
    "the reply (--fresh: ask anew)\n",
    "  aye, tellme, or just \"QUESTION?\"          the same as ask\n",
    "  explain-error \"MESSAGE\"                   where an error comes ",
    "from and what to do, no model needed\n",
    "  doctor                                    what is set up, and ",
    "which route ask will use\n",
    "  config                                    show every ",
    "language-model setting\n",
    "  config setup                              answer a few questions ",
    "to set them all\n",
    "  config set KEY VALUE | unset KEY          change one (keys: ",
    "config help)\n",
    "  config reset [--force]                    move an unreadable ",
    "settings file aside\n",
    "  models [--route R]                        models your provider ",
    "or server offers\n",
    "  bundle REQUEST...                         agentbndl() from the shell\n",
    "\nData and functions\n",
    "  login [--token] [--email ADDRESS]         sign in for the ",
    "curated tables at data.rmorie.com\n",
    "        [--code CODE] [--no-browser]\n",
    "  logout                                    forget the data key\n",
    "  data list                                 curated tables at ",
    "data.rmorie.com\n",
    "  data pull db/table [--out FILE.csv]       download one of them ",
    "(your MORIE data key)\n",
    "  app [PATH] [--port N] [--no-browser]      the analysis dashboard ",
    "on this machine (needs shiny)\n",
    "  wayback FILE [--out F.jsonl] [--jobs N]   archive every URL in ",
    "FILE (archive.org keys)\n",
    "  wayback --retry F.jsonl                   retry the failed URLs ",
    "of an earlier wayback run\n",
    "  archive save URL... --reason TEXT         save from this ",
    "connection to archive.rmorie.com\n",
    "  archive find URL | get ID -o FILE         list its captures; ",
    "fetch the exact bytes, checked\n",
    "  functions [PATTERN]                       exported functions and ",
    "their titles\n",
    "  describe NAME                             help page of one function\n",
    "  examples NAME                             its examples\n",
    "  version                                   package version\n",
    "\nCapsules (the checks of the rmbl GitHub Action)\n",
    "  verify PATH [--json] [--fail-on LEVEL]    schemas, digests, ",
    "bundle signature (hmac secret: RMBL_KEY)\n",
    "        [--base MANIFEST|DIR] [--snapshot]  manifests against ",
    "their base copies; Wayback snapshots\n",
    "  drift PATH [--json] [--fail-on LEVEL]     verify, then fetch ",
    "each source and compare it with the pin\n",
    "        [--psi-warn X] [--psi-fail X]       the PSI bands of the ",
    "column table (0.1 and 0.25)\n",
    "        [--html FILE] [--app]               and write the drift ",
    "report, or open it as an app\n",
    "  refresh PATH                              pin each source's new ",
    "bytes in its provenance\n",
    "  sign PATH [--scheme S] [--key-file F]     pin and sign each ",
    "capsule (key: RMBL_KEY or the file), verify\n",
    "  report PATH [--format md|json]            the verify report; ",
    "never fails\n",
    "\nMore help\n",
    sprintf("  %s help start      getting started, step by step\n", prog),
    sprintf(
      paste0(
        "  %s help llm        every way to point ask at a model (your ",
        "key, Ollama, your own server)\n"
      ),
      prog
    ),
    sprintf(
      paste0(
        "  %s help config     every setting, its environment variable, ",
        "and examples\n"
      ),
      prog
    ),
    sprintf("  %s help r          the same from R and Rscript\n", prog),
    sprintf("  %s VERB --help     one verb's usage\n", prog)
  )
  start <- paste0(
    "Getting started\n\n",
    "1. Check what is set up:\n",
    sprintf("     %s doctor\n", prog),
    "2. Bring a model (any one is enough):\n",
    "     your own key        export ANTHROPIC_API_KEY=...   (or ",
    "OPENAI_API_KEY, GEMINI_API_KEY, GROQ_API_KEY, ...)\n",
    sprintf(
      paste0(
        "                         %s config set anthropic.key   (asks for ",
        "it; saved privately)\n"
      ),
      prog
    ),
    "     local Ollama        ollama serve, then ollama pull qwen3:8b   ",
    "(https://ollama.com)\n",
    sprintf(
      paste0(
        "     your own server     %s config set own.url ",
        "http://localhost:1234/v1\n"
      ),
      prog
    ),
    sprintf("   or answer a few questions instead:  %s config setup\n", prog),
    "3. Ask:\n",
    sprintf("     %s ask \"what is a Benford screen for\"\n", prog),
    sprintf(
      paste0(
        "     %s ask --model NAME \"...\"                 (one model, this ",
        "time)\n"
      ),
      prog
    ),
    sprintf(
      paste0(
        "     %s ask --route ollama \"...\"               (one route, this ",
        "time)\n"
      ),
      prog
    ),
    "4. Make a choice stick:\n",
    sprintf("     %s config set route anthropic\n", prog),
    sprintf(
      "     %s config set anthropic.model NAME     (`%s models` lists them)\n",
      prog,
      prog
    ),
    "5. The curated tables (data.rmorie.com) need a free MORIE data key:\n",
    sprintf(
      paste0(
        "     %s login                  (GitHub, or --email ADDRESS for a ",
        "code)\n"
      ),
      prog
    )
  )
  ps <- .bl_llm_presets()
  llm <- paste0(
    "Where ask sends a prompt\n\n",
    "Bring your own key, or run a model locally: nothing is sent ",
    "anywhere you did not set up.\n",
    "With route = auto (the default) ask tries, in order: your own ",
    "server (if own.url is set), each\n",
    "provider whose key is set (in the order below), then a local ",
    "Ollama server (if it has a model).\n",
    sprintf(
      "`%s doctor` shows each one and the route ask will take.\n\n",
      prog
    ),
    "Providers (your key in its variable, or `config set PROVIDER.key`; ",
    "the model in PROVIDER.model)\n",
    paste(
      sprintf("  %-12s %-22s %s\n", ps$id, ps$key_env, ps$base),
      collapse = ""
    ),
    sprintf(
      "  %s models --route anthropic     the models your key can use\n",
      prog
    ),
    sprintf("  %s config set route anthropic   always use it\n\n", prog),
    "Ollama, on this machine or another\n",
    "  ollama serve                              start the server (or ",
    "open the Ollama app)\n",
    "  ollama pull qwen3:8b                      a model to use\n",
    sprintf("  %s config set ollama.url http://192.168.1.20:11434\n", prog),
    sprintf("  %s config set ollama.model qwen3:8b\n", prog),
    sprintf(
      "  %s config set ollama.url off          never try Ollama\n\n",
      prog
    ),
    "Your own OpenAI-compatible server (LM Studio, vLLM, llama.cpp, ",
    "Azure OpenAI's v1 endpoint, a gateway)\n",
    sprintf("  %s config set own.url http://localhost:1234/v1\n", prog),
    sprintf("  %s config set own.model NAME\n", prog),
    sprintf(
      paste0(
        "  %s config set own.key                 (prompts for the key, so ",
        "it stays out of history)\n\n"
      ),
      prog
    ),
    "A model file on your disk (.gguf) or a folder of Ollama models\n",
    "  ask talks to a server, not to files: start one on the file, then ",
    "point own.url at it\n",
    "  llama-server -m /path/to/model.gguf --port 8080      (llama.cpp)\n",
    sprintf("  %s config set own.url http://localhost:8080/v1\n", prog),
    "  OLLAMA_MODELS=/path/to/models ollama serve          (Ollama ",
    "reading another folder)\n\n",
    "One call only\n",
    sprintf("  %s ask --route ollama --model llama3.2 \"...\"\n", prog),
    "  MORIE_LLM_ROUTE=groq rmbl ask \"...\"      (environment variables ",
    "win over saved settings)\n"
  )
  r_help <- paste0(
    "From R (or Rscript -e '...': single quotes outside, double quotes ",
    "inside)\n\n",
    "  library(rmoriebricklayer)\n",
    "  llmstat()                                   # doctor\n",
    "  llmprvd()                                # every provider, its ",
    "key variable\n",
    "  llmcfg()                                   # every setting\n",
    "  Sys.setenv(ANTHROPIC_API_KEY = \"...\")                     # or ",
    "llmcfg(anthropic.key = ...)\n",
    "  llmcfg(route = \"anthropic\", anthropic.model = \"claude-opus-5-5\")\n",
    "  llmcfg(ollama.url = \"http://192.168.1.20:11434\", ollama.model = ",
    "\"qwen3:8b\")\n",
    "  llmcfg(own.url = \"http://localhost:1234/v1\", own.model = \"m\")\n",
    "  llmcfg(route = NULL)                       # back to auto\n",
    "  llmmdls()\n",
    "  llmask(\"What can a Benford screen show?\")\n",
    "  dlogin()                                    # the data key, for ",
    "data.rmorie.com\n\n",
    "From the shell:\n",
    "  Rscript -e 'cat(rmoriebricklayer::llmask(\"What can a Benford ",
    "screen show?\"), \"\\n\")'\n"
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

#' The archive verb: archive.rmorie.com from a terminal (arccap(upload =
#' "rmorie"), arcfind(), arcget()).
#' @param rest The arguments after the verb.
#' @param flag Looks up an option's value.
#' @param out Writes text.
#' @return The exit status.
#' @noRd
.bl_cli_archive <- function(rest, flag, out) {
  sub <- if (length(rest)) rest[[1L]] else ""
  args <- rest[-1L]
  pos <- args
  for (f in c(
    "--reason",
    "--dir",
    "--also",
    "-o",
    "--out",
    "--sha256",
    "--at",
    "--from",
    "--to"
  )) {
    i <- match(f, pos)
    if (!is.na(i)) pos <- pos[-c(i, i + 1L)]
  }
  pos <- setdiff(pos, c("--private", "--json"))
  usage <- function(code) {
    out(.bl_verb_usage("archive", .bl_prog()))
    code
  }
  if (sub %in% c("help", "--help", "-h")) {
    return(usage(0L))
  }
  if (!sub %in% c("save", "find", "get") || !length(pos)) {
    return(usage(2L))
  }
  if (sub == "save") {
    also <- flag("--also")
    if (!is.null(also) && !identical(also, "wayback")) {
      out("--also takes one value: wayback\n")
      return(2L)
    }
    reason <- flag("--reason")
    if (is.null(reason)) {
      out(
        paste0(
          "save needs --reason \"why you keep it\" (one sentence, 20 ",
          "characters or more)\n"
        )
      )
      return(2L)
    }
    dir <- flag("--dir") %||% file.path(getwd(), "captures")
    cap <- arccap(
      pos,
      dir,
      tsa = NULL,
      upload = c("rmorie", if (!is.null(also)) "wayback"),
      reason = reason,
      visibility = if ("--private" %in% args) "private" else "public"
    )
    d <- as.data.frame(unclass(cap))
    for (i in seq_len(nrow(d))) {
      out(sprintf(
        "%s  %s%s\n",
        d$status[i],
        d$url[i],
        if (!is.na(d$archive[i])) paste0("\n  ", d$archive[i]) else ""
      ))
    }
    out(sprintf("local copies and WARC files: %s\n", dir))
    return(if (all(d$status == "archived")) 0L else 1L)
  }
  if (sub == "find") {
    f <- arcfind(pos[[1L]], from = flag("--from"), to = flag("--to"))
    if ("--json" %in% args) {
      d <- as.data.frame(unclass(f))
      d$captured <- format(d$captured, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
      out(paste0(tojs(d, dataframe = "rows", auto_unbox = TRUE), "\n"))
    } else {
      out(paste0(paste(utils::capture.output(print(f)), collapse = "\n"), "\n"))
    }
    return(if (nrow(f)) 0L else 1L)
  }
  dest <- flag("-o") %||% flag("--out")
  if (is.null(dest)) {
    out("get needs -o FILE (where to write the bytes)\n")
    return(2L)
  }
  g <- arcget(pos[[1L]], dest, sha256 = flag("--sha256"), at = flag("--at"))
  out(sprintf(
    "%s  capture %s, SHA-256 %s\n",
    dest,
    attr(g, "capture_id"),
    attr(g, "sha256")
  ))
  0L
}
