# The 0.5.x names in the command line. 1.0.0 renamed most functions; their old names are no longer R
# functions (eleven kept for rmoriedata 0.3.x, rmbl-compat, and four generics, rmbl-aliases). The
# command line still knows them, from inst/compat/compat_names_map.tsv: `describe` and `examples`
# answer for an old name, `run` calls a function by its old or new name, and `migrate` rewrites a
# 0.5.x script to the 1.0.0 names.

#' Returns the map of 0.5.x names.
#'
#' One row per renamed function: old, new, old_args, new_args, values (from
#' inst/compat/compat_names_map.tsv, read once).
#' @return A data frame.
#' @noRd
.bl_old_map <- function() {
  m <- .rmbl_compat_env$names_map
  if (is.null(m)) {
    p <- system.file("compat", "compat_names_map.tsv", package = "rmoriebricklayer")
    m <- utils::read.delim(p, stringsAsFactors = FALSE, na.strings = character(),
                           colClasses = "character")
    .rmbl_compat_env$names_map <- m
  }
  m
}

#' Returns the map row of a 0.5.x name.
#' @param name A function name.
#' @return A list (old, new, args: a named vector old -> new, values: a list per argument of named
#'   vectors old value -> new value, dots: a named vector of names renamed in `...`), or NULL.
#' @noRd
.bl_old_row <- function(name) {
  m <- .bl_old_map()
  i <- match(name, m$old)
  if (is.na(i)) return(NULL)
  oa <- strsplit(m$old_args[i], ",", fixed = TRUE)[[1L]]
  na <- strsplit(m$new_args[i], ",", fixed = TRUE)[[1L]]
  vals <- list()
  for (v in strsplit(m$values[i], ";", fixed = TRUE)[[1L]]) {
    # arg:old=new, arg `...` for a name passed through the dots
    arg <- sub(":.*$", "", v)
    kv <- strsplit(sub("^[^:]*:", "", v), "=", fixed = TRUE)[[1L]]
    vals[[arg]] <- c(vals[[arg]], stats::setNames(kv[[2L]], kv[[1L]]))
  }
  dots <- vals[["..."]]
  vals[["..."]] <- NULL
  list(old = m$old[i], new = m$new[i], args = stats::setNames(na, oa), values = vals,
       dots = if (is.null(dots)) character() else dots)
}

#' Says what a 0.5.x name became.
#' @param r A row from .bl_old_row().
#' @return One string.
#' @noRd
.bl_old_note <- function(r) {
  ch <- r$args[names(r$args) != r$args]
  ch <- c(ch, r$dots)
  s <- sprintf("%s() is the 0.5.x name of %s() (renamed in 1.0.0)", r$old, r$new)
  if (length(ch)) s <- paste0(s, "; arguments: ", paste(names(ch), "->", ch, collapse = ", "))
  for (a in names(r$values)) {
    s <- paste0(s, "; ", a, " values: ", paste(names(r$values[[a]]), "->", r$values[[a]], collapse = ", "))
  }
  paste0(s, "\n")
}

#' Rewrites 0.5.x calls in R source to the 1.0.0 names.
#'
#' Each call of a renamed function (bare or rmoriebricklayer::) gets its new name, its named
#' arguments their new names and each renamed allowed value (a string literal) its new value. Only
#' parsed tokens change: comments, strings and spacing stay.
#' @param lines The source, a character vector of lines.
#' @return list(lines = the rewritten source, n = the number of changes).
#' @noRd
.bl_migrate_text <- function(lines) {
  pd <- utils::getParseData(parse(text = lines, keep.source = TRUE), includeText = TRUE)
  m <- .bl_old_map()
  edits <- list()
  add <- function(row, new) {
    edits[[length(edits) + 1L]] <<- list(l = pd$line1[row], c1 = pd$col1[row], c2 = pd$col2[row], new = new)
  }
  hits <- which(pd$token == "SYMBOL_FUNCTION_CALL" & pd$text %in% m$old)
  for (h in hits) {
    # a call of another package's function of the same name is not ours
    fe <- pd$parent[h]
    pkg <- pd[pd$parent == fe & pd$token == "SYMBOL_PACKAGE", "text"]
    if (length(pkg) && !identical(pkg, "rmoriebricklayer")) next
    r <- .bl_old_row(pd$text[h])
    add(h, r$new)
    call <- pd$parent[pd$id == fe]
    kids <- which(pd$parent == call)
    kids <- kids[order(pd$line1[kids], pd$col1[kids])]
    for (k in seq_along(kids)) {
      j <- kids[k]
      if (pd$token[j] != "SYMBOL_SUB") next
      a <- pd$text[j]
      to <- if (a %in% names(r$args)) r$args[[a]] else if (a %in% names(r$dots)) r$dots[[a]] else a
      if (!identical(to, a)) add(j, to)
      vm <- r$values[[a]]
      if (is.null(vm) || k + 2L > length(kids)) next
      v <- kids[k + 2L]  # SYMBOL_SUB, EQ_SUB, then the value
      s <- which(pd$parent == pd$id[v] & pd$token == "STR_CONST")
      if (length(s) != 1L) next
      q <- substr(pd$text[s], 1L, 1L)
      val <- substr(pd$text[s], 2L, nchar(pd$text[s]) - 1L)
      if (val %in% names(vm)) add(s, paste0(q, vm[[val]], q))
    }
  }
  # right to left, so the columns of the edits still to make stay put
  ord <- order(-vapply(edits, `[[`, 1, "l"), -vapply(edits, `[[`, 1, "c1"))
  for (e in edits[ord]) {
    x <- lines[e$l]
    lines[e$l] <- paste0(substr(x, 1L, e$c1 - 1L), e$new, substr(x, e$c2 + 1L, nchar(x)))
  }
  list(lines = lines, n = length(edits))
}

#' The migrate verb: rewrites 0.5.x scripts to the 1.0.0 names.
#' @noRd
.bl_cli_migrate <- function(rest, has, out, usage_error, prog) {
  files <- setdiff(rest, "--write")
  if (!length(files) || any(startsWith(files, "--"))) {
    usage_error(sprintf("usage: %s migrate FILE.R... [--write]", prog))
  }
  status <- 0L
  for (f in files) {
    if (!file.exists(f)) {
      out(sprintf("%s: no such file\n", f))
      status <- 1L
      next
    }
    old <- readLines(f, warn = FALSE, encoding = "UTF-8")
    res <- tryCatch(.bl_migrate_text(old), error = function(e) e)
    if (inherits(res, "error")) {
      out(sprintf("%s: not R code R can parse (%s)\n", f, conditionMessage(res)))
      status <- 1L
      next
    }
    if (!res$n) {
      out(sprintf("%s: no 0.5.x names\n", f))
      next
    }
    d <- which(old != res$lines)
    for (i in d) out(sprintf("%s:%d\n- %s\n+ %s\n", f, i, old[i], res$lines[i]))
    if (has("--write")) {
      writeLines(res$lines, f, useBytes = TRUE)
      out(sprintf("%s: %d changes written\n", f, res$n))
    } else {
      out(sprintf("%s: %d changes (--write writes them)\n", f, res$n))
    }
  }
  status
}

#' Reads one command-line value for run.
#'
#' A .csv or .rds file that exists is read; otherwise a comma-separated list becomes a vector,
#' and numbers, TRUE/FALSE and NA their type (utils::type.convert); NULL is NULL.
#' @noRd
.bl_run_value <- function(s) {
  if (identical(s, "NULL")) return(NULL)
  if (file.exists(s) && grepl("\\.csv$", s, ignore.case = TRUE)) return(utils::read.csv(s))
  if (file.exists(s) && grepl("\\.rds$", s, ignore.case = TRUE)) return(readRDS(s))
  utils::type.convert(strsplit(s, ",", fixed = TRUE)[[1L]], as.is = TRUE)
}

#' The run verb: calls a function by its 0.5.x or 1.0.0 name.
#' @noRd
.bl_cli_run <- function(rest, out, usage_error, prog) {
  if (!length(rest)) usage_error(sprintf("usage: %s run NAME [VALUE...] [--ARG VALUE...]", prog))
  name <- rest[[1L]]
  r <- .bl_old_row(name)
  ns <- asNamespace("rmoriebricklayer")
  fn <- if (is.null(r)) name else r$new
  if (!fn %in% getNamespaceExports(ns)) {
    usage_error(sprintf("'%s' is not a function of rmoriebricklayer, old or new (%s functions lists them)",
                        .rmbl_printable(name), prog))
  }
  words <- rest[-1L]
  args <- list()
  i <- 1L
  while (i <= length(words)) {
    w <- words[[i]]
    if (startsWith(w, "--") && nchar(w) > 2L) {
      a <- substring(w, 3L)
      flagonly <- i == length(words) || startsWith(words[[i + 1L]], "--")
      v <- if (flagonly) TRUE else .bl_run_value(words[[i + 1L]])
      if (!is.null(r)) {
        vm <- r$values[[a]]
        if (is.character(v) && !is.null(vm)) v <- unname(ifelse(v %in% names(vm), vm[v], v))
        a <- if (a %in% names(r$args)) r$args[[a]] else if (a %in% names(r$dots)) r$dots[[a]] else a
      }
      args[a] <- list(v)
      i <- i + if (flagonly) 1L else 2L
    } else {
      args[length(args) + 1L] <- list(.bl_run_value(w))
      i <- i + 1L
    }
  }
  if (!is.null(r)) out(sprintf("(%s() is now %s())\n", name, fn))
  v <- withVisible(do.call(getExportedValue(ns, fn), args))
  if (v$visible) out(paste0(paste(utils::capture.output(print(v$value)), collapse = "\n"), "\n"))
  0L
}
