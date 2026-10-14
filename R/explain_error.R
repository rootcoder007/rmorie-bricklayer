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

# A message argument as text: literal parts kept, everything computed replaced by a marker.
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

# Every (function, kind, template) in a function body.
.bl_ee_walk <- function(e, out) {
  if (is.call(e)) {
    fn <- e[[1L]]
    nm <- if (is.name(fn)) as.character(fn) else ""
    if (nm %in% c("stop", "warning", "usage_error")) {
      args <- as.list(e)[-1L]
      named <- names(args) %||% rep("", length(args))
      parts <- args[!named %in% c("call.", "immediate.", "noBreaks.", "domain")]
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

# The table for the packages: one row per message, with the function raising it and the exported
# functions it is reached from.
.bl_ee_table <- function(pkgs) {
  key <- paste(pkgs, vapply(pkgs, function(p) as.character(utils::packageVersion(p)), ""), collapse = " ")
  if (!is.null(.bl_ee_memo[[key]])) return(.bl_ee_memo[[key]])
  # rmorie has some 18,000 messages: the table is kept between sessions beside the saved answers
  # (same rules: a person watching, removed when the versions change), built once per version
  f <- if (.bl_answer_cache_on()) {
    file.path(.bl_answer_dir(), paste0("messages-", substr(core_sha256(key), 1L, 16L), ".rds"))
  }
  if (!is.null(f) && file.exists(f)) {
    tab <- tryCatch(readRDS(f), error = function(e) NULL)
    if (is.data.frame(tab) && "template" %in% names(tab)) {
      assign(key, tab, envir = .bl_ee_memo)
      return(tab)
    }
  }
  if (!is.null(f) && "rmorie" %in% pkgs) message("Reading the messages of ", paste(pkgs, collapse = ", "),
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
      cols$exported <- c(cols$exported, rep(paste(utils::head(reach(n), 6L), collapse = ", "), k))
    }
  }
  tab <- as.data.frame(cols, stringsAsFactors = FALSE)
  tab <- tab[!duplicated(tab[c("package", "raised_by", "template")]), , drop = FALSE]
  tab$words <- lapply(gsub("\001", " ", tab$template, fixed = TRUE), .bl_ee_words)
  rownames(tab) <- NULL
  assign(key, tab, envir = .bl_ee_memo)
  if (!is.null(f)) {
    tryCatch({
      if (!dir.exists(dirname(f))) dir.create(dirname(f), recursive = TRUE, mode = "0700")
      old <- setdiff(list.files(dirname(f), pattern = "^messages-.*[.]rds$", full.names = TRUE), f)
      unlink(old)  # one table kept: the versions installed now
      saveRDS(tab, f)
      Sys.chmod(f, "0600")
    }, error = function(e) NULL, warning = function(w) NULL)
  }
  tab
}

# "Error in f(x) : msg" / "Error: msg" / "Warning message:" as R prints them, fancy quotes made plain
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
.bl_ee_words <- function(x) {
  w <- tolower(unlist(strsplit(x, "[^[:alnum:]_]+")))
  unique(w[nchar(w) >= 3L & !w %in% .bl_ee_stop & !grepl("^[0-9]+$", w)])
}

#' Explain an error from rmoriebricklayer (or rmoriedata, or rmorie)
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
#' @param message The message: the text of an error, as R printed it ("Error
#'   in f(x) : ..." is fine), or a condition. Default: the last error of this
#'   session (\code{geterrmessage()}).
#' @param packages The installed packages to search; default
#'   rmoriebricklayer, rmoriedata and rmorie (those installed).
#' @param n How many matches to return, best first.
#' @return A data frame, best match first: \code{package}, \code{raised_by}
#'   (the function whose code raises it), \code{exported} (the exported
#'   functions that reach it), \code{kind} (error or warning), \code{message}
#'   (the message as written, with \code{...} where a value goes) and
#'   \code{match} ("exact" or the share of its words found). No rows when the
#'   message is not one of these packages' own: it came from another package
#'   or from R, and \code{\link{bricklayer_llm_ask}} can help with it.
#' @examples
#' msg <- "`prompt` must be a single non-empty string"
#' bricklayer_explain_error(msg, packages = "rmoriebricklayer")
#' r <- try(bricklayer_llm_config(no.such = 1), silent = TRUE)
#' bricklayer_explain_error(r, packages = "rmoriebricklayer")
#' @export
bricklayer_explain_error <- function(message = geterrmessage(), packages = NULL, n = 3L) {
  if (inherits(message, "condition")) message <- conditionMessage(message)
  if (inherits(message, "try-error")) message <- attr(message, "condition")$message %||% as.character(message)
  if (!is.character(message) || !length(message) || anyNA(message)) {
    stop("`message` must be the text of an error (or a condition)", call. = FALSE)
  }
  if (!is.numeric(n) || length(n) != 1L || is.na(n) || n < 1 || n != round(n)) {
    stop("`n` must be a whole number of 1 or more", call. = FALSE)
  }
  n <- as.integer(n)
  pk <- packages %||% .bl_kn_default_packages()
  if (!is.character(pk) || !length(pk) || anyNA(pk)) stop("`packages` must name installed packages", call. = FALSE)
  missing <- pk[!vapply(pk, function(x) nzchar(system.file(package = x)), logical(1))]
  if (length(missing)) stop(sprintf("not installed: %s", paste(missing, collapse = ", ")), call. = FALSE)
  msg <- .bl_ee_clean(message)
  tab <- .bl_ee_table(pk)
  empty <- cbind(tab[0L, c("package", "raised_by", "exported", "kind")], message = character(), match = character())
  if (!nzchar(msg) || !nrow(tab)) return(empty)
  # exact: the template as a regular expression, its variable parts as wildcards
  rx <- vapply(strsplit(tab$template, "\001", fixed = TRUE), function(p) {
    paste0("^", paste(gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", p), collapse = "(.*?)"))
  }, "")
  rx <- ifelse(endsWith(tab$template, "\001"), paste0(rx, "(.*)"), rx)
  exact <- vapply(rx, function(r) isTRUE(tryCatch(grepl(r, msg, perl = TRUE), error = function(e) FALSE)), NA)
  lit_len <- nchar(gsub("\001", "", tab$template, fixed = TRUE))
  # otherwise by words: how much of your message the template explains, and how much of the
  # template your message carries (a message cut short, or typed from memory)
  mw <- .bl_ee_words(msg)
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
  out$message <- gsub("\001", "...", tab$template[keep], fixed = TRUE)
  out$match <- ifelse(exact[keep], "exact", sprintf("%d%% of its words", round(100 * share[keep])))
  rownames(out) <- NULL
  out
}

# The shell verb: the matches in words.
.bl_cli_explain <- function(rest, out, prog) {
  if (!length(rest)) {
    out(sprintf("usage: %s explain-error MESSAGE...   (quote it: %s explain-error \"the error text\")\n", prog, prog))
    return(2L)
  }
  r <- bricklayer_explain_error(paste(rest, collapse = " "))
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
