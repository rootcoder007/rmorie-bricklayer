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
#'   \item{\code{login [--token [KEY]] [--email ADDRESS]}}{sign in to the
#'     hosted MORIE LLM tier: paste a key (prompts when KEY is omitted), or
#'     with the rmorie package installed run its GitHub or emailed-code
#'     flow}
#'   \item{\code{logout}}{forget the hosted key}
#'   \item{\code{doctor}}{report the language-model routes available here}
#'   \item{\code{ask PROMPT...}}{send a prompt to the model and print the
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
  args <- as.character(args)
  verb <- if (length(args)) args[[1L]] else "help"
  rest <- args[-1L]
  flag <- function(name) {
    i <- match(name, rest)
    if (is.na(i)) return(NULL)
    if (i == length(rest)) {
      stop(sprintf("%s needs a value", name), call. = FALSE)
    }
    rest[[i + 1L]]
  }
  has <- function(name) name %in% rest
  status <- 0L
  tryCatch({
    switch(verb,
      login = {
        if (has("--token")) {
          i <- match("--token", rest)
          tok <- if (i < length(rest)) rest[[i + 1L]] else ""
          if (!nzchar(tok)) tok <- trimws(readline("Paste your MORIE key: "))
          bricklayer_llm_login(token = tok)
        } else {
          bricklayer_llm_login(email = flag("--email"))
        }
        out(sprintf("Logged in to %s\n", .bl_hosted_base() %||% "(disabled)"))
      },
      logout = bricklayer_llm_logout(),
      doctor = {
        st <- bricklayer_llm_status()
        for (i in seq_len(nrow(st))) {
          out(sprintf("  %-20s %-16s %s\n", st$route[i], st$status[i],
                      st$detail[i]))
        }
      },
      ask = {
        if (!length(rest) || identical(rest[[1L]], "--help")) {
          out("usage: rmoriebricklayer ask PROMPT...\n")
        } else {
          out(paste0(bricklayer_llm_ask(paste(rest, collapse = " ")), "\n"))
        }
      },
      bundle = {
        if (!length(rest)) {
          stop("usage: rmoriebricklayer bundle REQUEST...", call. = FALSE)
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
            out(sprintf(paste0("  %-", w, "s  %s\n"), tab$name[i],
                        tab$title[i]))
          }
        }
      },
      describe = {
        if (!length(rest)) {
          stop("usage: rmoriebricklayer describe NAME", call. = FALSE)
        }
        out(.bl_describe(rest[[1L]]))
      },
      examples = {
        if (!length(rest)) {
          stop("usage: rmoriebricklayer examples NAME", call. = FALSE)
        }
        out(.bl_examples(rest[[1L]]))
      },
      version = out(sprintf("rmoriebricklayer %s\n", as.character(
        utils::packageVersion("rmoriebricklayer")))),
      help = ,
      `--help` = ,
      `-h` = out(paste0(
        "usage: rmoriebricklayer <verb> [options]\n\n",
        "  login [--token [KEY]] [--email ADDRESS]   sign in to the hosted ",
        "MORIE LLM tier\n",
        "  logout                                    forget the hosted key\n",
        "  doctor                                    language-model routes ",
        "available here\n",
        "  ask PROMPT...                             ask the model\n",
        "  bundle REQUEST...                         agent_bundle() from the ",
        "shell\n",
        "  functions [PATTERN]                       exported functions and ",
        "their titles\n",
        "  describe NAME                             help page of one ",
        "function\n",
        "  examples NAME                             its examples\n",
        "  version                                   package version\n")),
      stop(sprintf("unknown verb '%s' (try: rmoriebricklayer help)", verb),
           call. = FALSE))
  }, error = function(e) {
    out(paste0("rmoriebricklayer: ", conditionMessage(e), "\n"))
    status <<- 1L
  })
  invisible(status)
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# The Rd database of this package: the installed copy when there is one,
# else the man/ directory of a source tree loaded with pkgload.
.bl_rd_db <- function() {
  db <- tryCatch(tools::Rd_db("rmoriebricklayer"), error = function(e) NULL)
  if (length(db)) return(db)
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
    if (name %in% .bl_rd_aliases(rd)) return(rd)
  }
  NULL
}

# Rd2txt renders a whole page; sections come back headed "Usage:",
# "Arguments:", "Examples:" when underlining is off.
.bl_rd_text <- function(rd) {
  txt <- utils::capture.output(
    tools::Rd2txt(rd, options = list(underline_titles = FALSE, width = 78)))
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
                                  collapse = ""))
    }
  }
  data.frame(name = ns, title = unname(titles), stringsAsFactors = FALSE)
}

.bl_describe <- function(name) {
  rd <- .bl_rd_for(name)
  if (is.null(rd)) return(sprintf("no help page for '%s'\n", name))
  txt <- .bl_rd_text(rd)
  cut <- which(txt == "Examples:")
  if (length(cut)) txt <- txt[seq_len(cut[1L] - 1L)]
  paste0(paste(txt, collapse = "\n"), "\n")
}

.bl_examples <- function(name) {
  rd <- .bl_rd_for(name)
  if (is.null(rd)) return(sprintf("no help page for '%s'\n", name))
  txt <- .bl_rd_text(rd)
  start <- which(txt == "Examples:")
  if (!length(start)) return(sprintf("'%s' has no examples\n", name))
  paste0(paste(txt[-seq_len(start[1L])], collapse = "\n"), "\n")
}

#' Install the rmoriebricklayer command-line launcher
#'
#' Links the launcher shipped in the package (\code{inst/bin/rmoriebricklayer})
#' into a directory on your PATH so that \code{rmoriebricklayer login},
#' \code{rmoriebricklayer ask ...} and the other verbs of
#' \code{\link{bricklayer_cli}} work from any shell. On Windows a
#' \code{rmoriebricklayer.cmd} wrapper is written instead of a symlink.
#' Nothing outside \code{dir} is touched, and only when you call this.
#' @param dir Target directory (default \code{~/.local/bin}; created if
#'   absent).
#' @param name Command name (default \code{rmoriebricklayer}).
#' @return The path of the installed launcher, invisibly.
#' @examples
#' \dontrun{
#' install_cli()
#' }
#' @export
install_cli <- function(dir = file.path(path.expand("~"), ".local", "bin"),
                        name = "rmoriebricklayer") {
  src <- system.file("bin", "rmoriebricklayer", package = "rmoriebricklayer")
  if (!nzchar(src)) stop("the launcher is missing from this installation")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  if (.Platform$OS.type == "windows") {
    target <- file.path(dir, paste0(name, ".cmd"))
    writeLines(paste0("@echo off\r\nRscript --vanilla -e ",
                      "\"rmoriebricklayer::bricklayer_cli()\" --args %*"),
               target)
  } else {
    target <- file.path(dir, name)
    if (file.exists(target) || !is.na(Sys.readlink(target))) unlink(target)
    ok <- file.symlink(src, target)
    if (!isTRUE(ok)) {
      file.copy(src, target, overwrite = TRUE)
      Sys.chmod(target, "0755")
    }
    Sys.chmod(src, "0755")
  }
  on_path <- dir %in% strsplit(Sys.getenv("PATH"), .Platform$path.sep)[[1L]]
  message(sprintf("Installed %s%s", target,
                  if (on_path) "" else sprintf("; add %s to your PATH", dir)))
  invisible(target)
}
