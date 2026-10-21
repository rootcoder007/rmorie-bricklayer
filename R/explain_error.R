# SPDX-License-Identifier: AGPL-3.0-or-later
#
# What an error from one of the MORIE packages means, without a language model: every message the
# packages can raise is written in their code (stop(), warning(), a usage error), so the code itself
# is searched. Each function's body is walked once a session; a message built with sprintf() or
# paste() becomes a pattern with its variable parts as wildcards, and the function that raises it
# is traced back to the exported functions that reach it. Nothing is shipped or kept, so the list
# cannot fall behind the code; nothing leaves the machine.

.bl_ee_memo <- new.env(parent = emptyenv())

.bl_ee_calls <- c("stop", "warning", "usage_error", "gettextf")

#' A message argument as text: literal parts kept, everything computed replaced by a marker.
#' @param e An expression from a function body: a string or a call that builds one.
#' @return The template, with \dQuote{\001} where a part is computed.
#' @noRd
.bl_ee_text <- function(e) {
  if (is.character(e) && length(e) == 1L && !is.na(e)) return(e)
  if (!is.call(e)) return("\001")
  fn <- e[[1L]]
  nm <- if (is.name(fn)) as.character(fn) else ""
  args <- as.list(e)[-1L]
  if (nm %in% c("sprintf", "gettextf") && length(args)) {
    named <- names(args) %||% rep("", length(args))
    fmt <- .bl_ee_text(args[[if ("fmt" %in% named) match("fmt", named) else 1L]])
    fmt <- gsub("%%", "\002", fmt, fixed = TRUE)
    fmt <- gsub("%[-+ 0#]*[0-9*]*(\\.[0-9*]+)?[sdifeEgGxXo]", "\001", fmt)
    return(gsub("\002", "%", fmt, fixed = TRUE))
  }
  if (nm %in% c("paste", "paste0")) {
    named <- names(args) %||% rep("", length(args))
    sep <- if (nm == "paste0") "" else " "
    if ("sep" %in% named) {
      s <- args[[match("sep", named)]]
      sep <- if (is.character(s) && length(s) == 1L) s else "\001"
    }
    parts <- args[!named %in% c("sep", "collapse")]
    return(paste(vapply(parts, .bl_ee_text, ""), collapse = sep))
  }
  "\001"
}

#' Every (function, kind, template) in a function body.
#' @param e An expression or a function.
#' @param out An environment whose `rows` list collects the messages found.
#' @return `out`, invisibly.
#' @noRd
.bl_ee_walk <- function(e, out) {
  if (is.call(e)) {
    fn <- e[[1L]]
    nm <- if (is.name(fn)) as.character(fn) else ""
    if (nm %in% c("stop", "warning", "usage_error")) {
      args <- as.list(e)[-1L]
      named <- names(args) %||% rep("", length(args))
      parts <- args[!named %in% c("call.", "immediate.", "noBreaks.", "domain")]
      # the name of the function that refused (.rmbl_fn()) is matched as an optional prefix below
      parts <- parts[!vapply(parts, identical, NA, quote(.rmbl_fn()))]
      if (length(parts)) {
        txt <- paste(vapply(parts, .bl_ee_text, ""), collapse = "")
        lit <- gsub("\001", "", txt, fixed = TRUE)
        if (nchar(gsub("[^[:alpha:]]", "", lit)) >= 12L) {
          out$rows[[length(out$rows) + 1L]] <- c(kind = if (nm == "warning") "warning" else "error", template = txt)
        }
      }
    }
    for (a in as.list(e)) if (!missing(a)) .bl_ee_walk(a, out)
  } else if (is.function(e)) {
    .bl_ee_walk(body(e), out)
  }
  invisible(out)
}

#' Whether reading the messages takes long enough to say so first: by the size of the namespaces
#' (a package of some 18,000 objects takes a while; this one, about 1,200, takes a second).
#' @param pkgs The package names.
#' @param limit The number of objects above which the namespaces count as large.
#' @return TRUE or FALSE.
#' @noRd
.bl_ee_big <- function(pkgs, limit = 5000L) {
  sum(vapply(pkgs, function(p) length(ls(asNamespace(p), all.names = TRUE)), 0L)) > limit
}

#' Builds the table of every message the packages raise.
#'
#' The table for the packages: one row per message, with the function raising it and the exported
#' functions it is reached from.
#' @param pkgs The package names.
#' @return A data frame with `package`, `raised_by`, `kind`, `template`, `exported` and `words`.
#' @noRd
.bl_ee_table <- function(pkgs) {
  key <- paste(pkgs, vapply(pkgs, function(p) as.character(utils::packageVersion(p)), ""), collapse = " ")
  if (!is.null(.bl_ee_memo[[key]])) return(.bl_ee_memo[[key]])
  # a large package has thousands of messages: the table is kept between sessions beside the saved answers
  # (same rules: a person watching, removed when the versions change), built once per version
  f <- if (.bl_answer_cache_on()) {
    file.path(.bl_answer_dir(), paste0("messages-", substr(csha256(key), 1L, 16L), ".rds"))
  }
  if (!is.null(f) && file.exists(f)) {
    tab <- tryCatch(readRDS(f), error = function(e) NULL)
    if (is.data.frame(tab) && "template" %in% names(tab)) {
      assign(key, tab, envir = .bl_ee_memo)
      return(tab)
    }
  }
  if (!is.null(f) && .bl_ee_big(pkgs)) message("Reading the messages of ", paste(pkgs, collapse = ", "),
                                             " (once for these versions; it takes a little while)")
  cols <- list(package = character(), raised_by = character(), kind = character(), template = character(),
               exported = character())
  for (p in pkgs) {
    ns <- asNamespace(p)
    exp <- getNamespaceExports(p)
    fns <- Filter(function(n) is.function(get(n, envir = ns)), ls(ns, all.names = TRUE))
    syms <- lapply(fns, function(n) all.names(body(get(n, envir = ns)), unique = TRUE))
    names(syms) <- fns
    # who calls whom, in one pass: a body naming a function of the package calls it
    from <- rep(names(syms), lengths(syms))
    to <- unlist(syms, use.names = FALSE)
    hit <- to %in% fns
    callers <- split(from[hit], to[hit])
    # the exported functions a function is reached from, a few calls up
    reach <- function(f) {
      seen <- f
      frontier <- f
      for (i in 1:4) {
        frontier <- setdiff(unique(unlist(callers[frontier])), seen)
        if (!length(frontier)) break
        seen <- c(seen, frontier)
      }
      # a dot-named function is internal even where a package exports it
      sort(grep("^[.]", intersect(seen, exp), value = TRUE, invert = TRUE))
    }
    for (n in fns) {
      # only a body that raises something is walked further
      if (!any(c("stop", "warning", "usage_error") %in% syms[[n]])) next
      w <- .bl_ee_walk(get(n, envir = ns), new.env())$rows
      if (!length(w)) next
      m <- do.call(rbind, w)
      k <- nrow(m)
      cols$package <- c(cols$package, rep(p, k))
      cols$raised_by <- c(cols$raised_by, rep(n, k))
      cols$kind <- c(cols$kind, m[, "kind"])
      cols$template <- c(cols$template, m[, "template"])
      cols$exported <- c(cols$exported, rep(paste(reach(n), collapse = ", "), k))
    }
  }
  tab <- as.data.frame(cols, stringsAsFactors = FALSE)
  tab <- tab[!duplicated(tab[c("package", "raised_by", "template")]), , drop = FALSE]
  tab$words <- lapply(gsub("\001", " ", tab$template, fixed = TRUE), .bl_ee_words)
  rownames(tab) <- NULL
  assign(key, tab, envir = .bl_ee_memo)
  if (!is.null(f)) {
    tryCatch({
      .bl_private_dir(dirname(f))
      old <- setdiff(list.files(dirname(f), pattern = "^messages-.*[.]rds$", full.names = TRUE), f)
      unlink(old)  # one table kept: the versions installed now
      saveRDS(tab, f)
      Sys.chmod(f, "0600")
    }, error = function(e) NULL, warning = function(w) NULL)
  }
  tab
}

#' Strips the prefix R prints before an error or a warning and makes fancy quotes plain.
#'
#' \dQuote{Error in f(x) : msg} / \dQuote{Error: msg} / \dQuote{Warning message:} as R
#' prints them, fancy quotes made plain
#' @param msg The message as the user pasted it.
#' @return One string.
#' @noRd
.bl_ee_clean <- function(msg) {
  m <- paste(msg, collapse = " ")
  m <- gsub("[\u2018\u2019]", "'", gsub("[\u201c\u201d]", "\"", m))
  m <- sub("^\\s*(Error|Warning)( message)?( in [^:]*)?\\s*:\\s*", "", m)
  m <- sub("^\\s*(Error|Warning)( message)?s?:?\\s*$", "", m)
  trimws(gsub("[[:space:]]+", " ", m))
}

# The words that tell one message from another: three letters or more, the common ones left out.
.bl_ee_stop <- c("the", "and", "for", "not", "must", "with", "this", "that", "are", "was", "has", "have", "from",
                 "one", "only", "can", "cannot", "its", "use", "found", "given", "should", "when", "than", "into",
                 "any", "all", "but", "out", "had", "you", "your", "there", "here", "which", "what", "been", "will")
#' Splits a text into the words that tell one message from another.
#' @param x The text.
#' @return The distinct words of three letters or more, the common ones and numbers left out.
#' @noRd
.bl_ee_words <- function(x) {
  w <- tolower(unlist(strsplit(x, "[^[:alnum:]_]+")))
  unique(w[nchar(w) >= 3L & !w %in% .bl_ee_stop & !grepl("^[0-9]+$", w)])
}

#' Explain an error from rmoriebricklayer (or a package built on it)
#'
#' Finds where an error or warning message comes from, without a language
#' model and without the network: every message the packages raise is written
#' in their code, so the code is searched. A message built from parts (a file
#' name, a number) matches with those parts as wildcards; one that was cut
#' short or retyped matches by its words. For each match you get the function
#' that raises it, the exported functions it is reached from (their help pages
#' say what they expect), and the message as written, which usually says what
#' to do.
#'
#' @details
#' The first call in a session walks the body of every function in the
#' searched packages and collects each \code{stop()}, \code{warning()} and
#' usage error whose literal text has at least 12 letters. A message built
#' with \code{sprintf()}, \code{gettextf()}, \code{paste()} or \code{paste0()}
#' becomes a template with its computed parts as wildcards. Each raising
#' function is traced up to four calls to the exported functions that reach
#' it (at most six are listed). The table is kept in memory for the session
#' (about a second to build for this package), and, while a person is
#' watching an interactive session and the answer cache is on, also saved as
#' an \code{.rds} file in the answer-cache directory.
#'
#' The answer-cache directory is the one \code{tools::R_user_dir()} gives for
#' \code{"rmoriebricklayer"} and \code{"cache"}, or the one the
#' \code{rmoriebricklayer.llmcachedir} option names when it is set. The cache is off under
#' \code{options(morie.quiet = TRUE)}, \code{MORIE_LLM_CACHE=off}, tests and
#' \code{R CMD check}.
#'
#' The message is cleaned first: an \dQuote{Error in f(x) :} or \dQuote{Warning message:}
#' prefix is dropped, curly quotes become straight ones and white space is
#' collapsed. A template that matches the start of the message as a regular
#' expression is an exact match and ranks first (longer templates before
#' shorter ones). Otherwise a template scores
#' \eqn{0.6 h / |m| + 0.4 h / |t|}, where \eqn{h} is the number of shared
#' words (three letters or more, common words left out, at least two
#' needed), \eqn{|m|} the words of the message and \eqn{|t|} those of the
#' template; scores of 0.55 and above are kept.
#'
#' Errors: \code{msg} that is not character text, a condition or a data
#' frame with the columns \code{check}, \code{ok} and \code{detail};
#' \code{n} not a whole number of 1 or more; \code{pkgs} that are not
#' installed.
#'
#' @param msg The message: the text of an error, as R printed it (\dQuote{Error
#'   in f(x) : ...} is fine), a condition object, or a \code{try()} result.
#'   Default: the last error of this session (\code{geterrmessage()}).
#'   Or a data frame of check rows with the columns \code{check},
#'   \code{ok} and \code{detail}, as \code{rmbl verify --json} writes
#'   them and \code{\link{vrfcps}} returns them in \code{checks}: each
#'   failed row is explained.
#' @param pkgs Character vector of installed packages to search. The default,
#'   \code{NULL}, means this package, or the comma-separated list in
#'   \code{RMBL_PACKAGES}: an environment variable that a package built on
#'   this one sets for its own command line.
#' @param n How many matches to return, best first: a whole number, default
#'   3.
#' @return A data frame with at most \code{n} rows, best match first, and the
#'   character columns \code{package}, \code{raised_by}
#'   (the function whose code raises it), \code{exported} (the exported
#'   functions that reach it, separated by commas), \code{kind} (\code{"error"} or
#'   \code{"warning"}), \code{message} (the message as written, with
#'   \code{...} where a value goes) and \code{match} (\code{"exact"} or the share
#'   of its words found, such as \code{"80\% of its words"}). No rows when the
#'   message is not one of these packages' own: it came from another package
#'   or from R, and \code{\link{llmask}} can help with it.
#'   For a data frame of check rows: one row per failed check, with the
#'   columns \code{check}, \code{detail}, \code{explanation} (what the
#'   failure means and what to do) and \code{raised_by} (\code{pkg::fn}
#'   when the detail is a message of these packages, else \code{NA}).
#' @examplesIf interactive() || any(nzchar(Sys.getenv(c("NOT_CRAN", "MY_UNIVERSE", "IN_PKGDOWN"))))
#' msg <- "`prompt` must be a single non-empty string"
#' explerr(msg, pkgs = "rmoriebricklayer")
#'
#' # a condition object
#' e <- tryCatch(kemsz(3), error = identity)
#' explerr(e, n = 1)
#'
#' # the failed rows of a capsule check
#' rows <- data.frame(check = c("data_present", "data_sha256"), ok = c(TRUE, FALSE),
#'                    detail = c("d.csv", "expected 01..., got 9c..."))
#' explerr(rows)$explanation
#'
#' # n must be at least 1
#' try(explerr(msg, n = 0))
#'
#' @examplesIf interactive()
#' # an error caught with try(), and the message as R prints it, with the call in front
#' r <- try(llmcfg(no.such = 1), silent = TRUE)
#' explerr(r, pkgs = "rmoriebricklayer")
#' explerr(
#'   "Error in mrkprf(x, 9) : `index` must be between 1 and the number of chunks",
#'   n = 1)
#'
#' # a message retyped from memory
#' explerr("index between number chunks", n = 1)
#'
#' # R's own messages are not in the table: no rows
#' nrow(explerr("object 'x' not found"))
#' @export
explerr <- function(msg = geterrmessage(), pkgs = NULL, n = 3L) {
  if (is.data.frame(msg)) return(.bl_explain_rows(msg, pkgs))
  if (inherits(msg, "condition")) msg <- conditionMessage(msg)
  if (inherits(msg, "try-error")) msg <- attr(msg, "condition")$message %||% as.character(msg)
  if (!is.character(msg) || !length(msg) || anyNA(msg)) {
    stop("`msg` must be the text of an error (or a condition)", call. = FALSE)
  }
  if (!is.numeric(n) || length(n) != 1L || is.na(n) || n < 1 || n != round(n)) {
    stop("`n` must be a whole number of 1 or more", call. = FALSE)
  }
  n <- as.integer(min(n, .Machine$integer.max))   # Inf: every match (as.integer(Inf) was NA)
  pk <- pkgs %||% .bl_kn_default_packages()
  if (!is.character(pk) || !length(pk) || anyNA(pk) || !all(nzchar(pk))) {
    stop("explerr: `pkgs` must name installed packages", call. = FALSE)
  }
  missing <- pk[!vapply(pk, function(x) nzchar(system.file(package = x)), logical(1))]
  if (length(missing)) stop(sprintf("explerr: not installed: %s", paste(missing, collapse = ", ")), call. = FALSE)
  .msg <- .bl_ee_clean(msg)
  tab <- .bl_ee_table(pk)
  empty <- cbind(tab[0L, c("package", "raised_by", "exported", "kind")], message = character(), match = character())
  if (!nzchar(.msg) || !nrow(tab)) return(empty)
  # exact: the template as a regular expression, its variable parts as wildcards, after the name of
  # the function that refused ("anltab: ") that a shared check puts first
  rx <- vapply(strsplit(tab$template, "\001", fixed = TRUE), function(p) {
    paste0("^(?:[A-Za-z][A-Za-z0-9._]*: )?", paste(gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", p), collapse = "(.*?)"))
  }, "")
  rx <- ifelse(endsWith(tab$template, "\001"), paste0(rx, "(.*)"), rx)
  exact <- vapply(rx, function(r) isTRUE(tryCatch(grepl(r, .msg, perl = TRUE), error = function(e) FALSE)), NA)
  lit_len <- nchar(gsub("\001", "", tab$template, fixed = TRUE))
  # otherwise by words: how much of your message the template explains, and how much of the
  # template your message carries (a message cut short, or typed from memory)
  mw <- .bl_ee_words(.msg)
  share <- vapply(tab$words, function(tw) {
    hit <- length(intersect(tw, mw))
    if (hit < 2L) return(0)  # one shared word is chance
    0.6 * hit / length(mw) + 0.4 * hit / length(tw)
  }, 0)
  score <- ifelse(exact, 2 + lit_len / 1e4, share)
  keep <- which(exact | share >= 0.55)
  if (!length(keep)) return(empty)
  keep <- keep[order(-score[keep])][seq_len(min(n, length(keep)))]
  out <- tab[keep, c("package", "raised_by", "exported", "kind"), drop = FALSE]
  # a shared check (.rmbl_string1) is reached from dozens of exports: the ones that take the argument
  # your message names come first, then six at most (the first six by name hid the one that raised it
  # once more functions checked their arguments)
  arg <- regmatches(.msg, regexpr("`[A-Za-z.][A-Za-z0-9._]*`", .msg))
  arg <- if (length(arg)) gsub("`", "", arg, fixed = TRUE) else ""
  out$exported <- vapply(seq_len(nrow(out)), function(i) {
    e <- strsplit(out$exported[[i]], ", ", fixed = TRUE)[[1L]]
    if (nzchar(arg) && length(e) > 1L) {
      ns <- asNamespace(out$package[[i]])
      takes <- vapply(e, function(f) {
        g <- get0(f, envir = ns, inherits = FALSE)
        is.function(g) && arg %in% names(formals(g))
      }, NA)
      e <- c(e[takes], e[!takes])
    }
    paste(utils::head(e, 6L), collapse = ", ")
  }, "")
  out$message <- gsub("\001", "...", tab$template[keep], fixed = TRUE)
  out$match <- ifelse(exact[keep], "exact", sprintf("%d%% of its words", round(100 * share[keep])))
  rownames(out) <- NULL
  out
}

#' The shell verb: the matches in words.
#' @param rest The message, as the words after the verb.
#' @param out The function that prints.
#' @param prog The program's name, used in the usage line.
#' @return The exit status: 0 on a match, 1 on none, 2 on a usage error.
#' @noRd
.bl_cli_explain <- function(rest, out, prog) {
  if (!length(rest)) {
    out(sprintf("usage: %s explain-error MESSAGE...   (quote it: %s explain-error \"the error text\")\n", prog, prog))
    return(2L)
  }
  r <- explerr(paste(rest, collapse = " "))
  if (!nrow(r)) {
    out(paste0("Not a message of these packages (it may come from R or another package). ",
               sprintf("`%s ask \"what does this error mean: ...\"` asks your model.\n", prog)))
    return(1L)
  }
  for (i in seq_len(nrow(r))) {
    out(sprintf("%s%s (%s, %s match)\n", if (i > 1L) "\n" else "", r$message[i], r$kind[i], r$match[i]))
    out(sprintf("  raised in %s::%s\n", r$package[i], r$raised_by[i]))
    if (nzchar(r$exported[i])) {
      first <- strsplit(r$exported[i], ", ", fixed = TRUE)[[1L]][1L]
      out(sprintf("  from %s; their help: `%s describe %s`\n", r$exported[i], prog, first))
    }
  }
  0L
}
