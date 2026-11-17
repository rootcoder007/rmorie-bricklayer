# The 0.5.x names in the command line. 1.0.0 renamed most functions; their old
# names are no longer R functions (eleven kept for rmoriedata 0.3.x,
# rmbl-compat, and four generics, rmbl-aliases). The command line still knows
# them, from inst/compat/compat_names_map.tsv: `describe` and `examples` answer
# for an old name, `run` calls a function by its old or new name, and `migrate`
# rewrites a 0.5.x script to the 1.0.0 names.

#' Returns the map of 0.5.x names.
#'
#' One row per renamed function: old, new, old_args, new_args, values (from
#' inst/compat/compat_names_map.tsv, read once).
#' @return A data frame.
#' @noRd
.bl_old_map <- function() {
  m <- .rmbl_compat_env$names_map
  if (is.null(m)) {
    p <- system.file(
      "compat",
      "compat_names_map.tsv",
      package = "rmoriebricklayer"
    )
    m <- utils::read.delim(
      p,
      stringsAsFactors = FALSE,
      na.strings = character(),
      colClasses = "character"
    )
    .rmbl_compat_env$names_map <- m
  }
  m
}

#' Returns the map row of a 0.5.x name.
#' @param name A function name.
#' @return A list (old, new, args: a named vector old -> new, values: a list per
#'   argument of named vectors old value -> new value, dots: a named vector of
#'   names renamed in `...`), or NULL.
#' @noRd
.bl_old_row <- function(name) {
  m <- .bl_old_map()
  i <- match(name, m$old)
  if (is.na(i)) {
    return(NULL)
  }
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
  list(
    old = m$old[i],
    new = m$new[i],
    args = stats::setNames(na, oa),
    values = vals,
    dots = if (is.null(dots)) character() else dots
  )
}

#' Says that a command or function was removed in 1.1.1, and why.
#' @param x A verb, help topic or function name.
#' @return One string, or NULL when `x` was not removed.
#' @noRd
.bl_gone <- function(x) {
  key <- "the curated tables need no sign-in"
  arc <- "nothing in the package uses archive.rmorie.com any more"
  why <- c(
    login = key, logout = key, dlogin = key, dlogout = key,
    arcfind = arc, arcget = arc
  )
  if (length(x) == 1L && x %in% names(why)) {
    sprintf("'%s' was removed in 1.1.1: %s", x, why[[x]])
  }
}

#' Says what a 0.5.x name became.
#' @param r A row from .bl_old_row().
#' @return One string.
#' @noRd
.bl_old_note <- function(r) {
  ch <- r$args[names(r$args) != r$args]
  ch <- c(ch, r$dots)
  # four names lasted from 1.0.0 to 1.1.0
  late <- r$old %in% c("anltab", "yoy", "plotecdf", "plotsm")
  s <- sprintf(
    "%s() is the %s name of %s() (renamed in %s)",
    r$old,
    if (late) "1.0.0" else "0.5.x",
    r$new,
    if (late) "1.1.1" else "1.0.0"
  )
  if (length(ch)) {
    s <- paste0(s, "; arguments: ", paste(names(ch), "->", ch, collapse = ", "))
  }
  for (a in names(r$values)) {
    s <- paste0(
      s,
      "; ",
      a,
      " values: ",
      paste(names(r$values[[a]]), "->", r$values[[a]], collapse = ", ")
    )
  }
  paste0(s, "\n")
}

#' Rewrites 0.5.x calls in R source to the 1.0.0 names.
#'
#' Each call of a renamed function (bare or rmoriebricklayer::; a bare name
#' the script defines itself is the script's own) gets its new
#' name, its named arguments their new names and each renamed allowed value (a
#' string literal) its new value. A renamed function passed by name as an
#' argument (`lapply(x, yoy)`) and a string naming one in do.call(),
#' match.fun(), get(), get0() or exists() get the new name too, unless the
#' script defines that name itself. A name after `$` or `@` (a list element or
#' a method), or qualified with another package, is not this package's and is
#' left alone. Only parsed tokens change: comments, strings and spacing stay.
#' @param lines The source, a character vector of lines.
#' @return list(lines = the rewritten source, n = the number of changes).
#' @noRd
.bl_migrate_text <- function(lines) {
  pd <- utils::getParseData(
    parse(text = lines, keep.source = TRUE),
    includeText = TRUE
  )
  # a name in backquotes is the name: `yoy`(1) calls yoy (audit of 21478080,
  # P2); an edit replaces the token by its place, quotes included
  sym <- pd$token %in%
    c("SYMBOL_FUNCTION_CALL", "SYMBOL", "SYMBOL_SUB", "SYMBOL_FORMALS")
  pd$text[sym] <- gsub("^`|`$", "", pd$text[sym])
  m <- .bl_old_map()
  edits <- list()
  hits <- which(pd$token == "SYMBOL_FUNCTION_CALL" & pd$text %in% m$old)
  def <- .bl_migrate_defined(pd)
  # a call looks for a function: a loop variable or a constant of the same
  # name is passed over, as R passes over it
  fdef <- def[def$fun, , drop = FALSE]
  for (h in hits) {
    qual <- any(pd$token[pd$parent == pd$parent[h]] == "SYMBOL_PACKAGE")
    own <- !qual && .bl_migrate_own(pd, h, pd$text[h], fdef)
    if (!.bl_migrate_ours(pd, h) || own) {
      next
    }
    r <- .bl_old_row(pd$text[h])
    edits <- c(
      edits,
      list(.bl_migrate_edit(pd, h, r$new)),
      .bl_migrate_args(pd, pd$parent[h], r)
    )
  }
  edits <- c(edits, .bl_migrate_refs(pd, m))
  list(lines = .bl_migrate_apply(lines, edits), n = length(edits))
}

#' Says whether a name token is this package's: not after `$` or `@` (an
#' element or a method: `obj$rate()` is not rate()) and not qualified with
#' another package.
#' @param pd The parse data.
#' @param row The token's row in `pd`.
#' @return TRUE or FALSE.
#' @noRd
.bl_migrate_ours <- function(pd, row) {
  sib <- pd$parent == pd$parent[row]
  if (any(pd$token[sib] %in% c("'$'", "'@'"))) {
    return(FALSE)
  }
  pkg <- pd$text[sib & pd$token == "SYMBOL_PACKAGE"]
  !length(pkg) || identical(pkg, "rmoriebricklayer")
}

#' The children of a parse-data node, in source order.
#' @param pd The parse data.
#' @param id The node's parse id.
#' @return Row numbers of `pd`.
#' @noRd
.bl_pd_kids <- function(pd, id) {
  k <- which(pd$parent == id)
  k[order(pd$line1[k], pd$col1[k])]
}

#' Says whether a parse node opens a scope: a function definition, or a call
#' of local(), with() or within(), whose expression runs in an environment of
#' its own (`with(list(), {share <- sum})` defines nothing at the top level;
#' audit of 716154bd, N11).
#' @param pd The parse data.
#' @param id The node's parse id.
#' @return TRUE or FALSE.
#' @noRd
.bl_pd_is_scope <- function(pd, id) {
  k <- .bl_pd_kids(pd, id)
  if (any(pd$token[k] %in% c("FUNCTION", "'\\\\'"))) {
    return(TRUE)
  }
  # every node asked about is a parent, so it has a first child
  length(k) > 0L &&
    pd$token[k[1L]] == "expr" &&
    any(
      pd$parent == pd$id[k[1L]] &
        pd$token == "SYMBOL_FUNCTION_CALL" &
        pd$text %in% c("local", "with", "within")
    )
}

#' The scopes a parse node sits in, innermost first: the ids of the function
#' definitions and local() calls around it, then 0 for the top level.
#' @param pd The parse data.
#' @param id The node's parse id.
#' @return An integer vector ending in 0.
#' @noRd
.bl_pd_scopes <- function(pd, id) {
  out <- integer()
  repeat {
    id <- pd$parent[match(id, pd$id)]
    if (is.na(id) || id <= 0L) {
      break
    }
    if (.bl_pd_is_scope(pd, id)) {
      out <- c(out, id)
    }
  }
  c(out, 0L)
}

#' The names a script defines itself, each with the scope it is defined in:
#' assigned (`<-`, `=`, `->`; `<<-` and `->>` define at the top level),
#' function arguments, loop variables, and names given as a string to
#' assign(), delayedAssign(), makeActiveBinding(), setGeneric() or
#' setMethod(). A name is the script's own only where its definition is in
#' reach: `rate <- function(x) x` inside one function says nothing about a
#' call of rate() at the top level. `fun` is FALSE for a name that cannot hold
#' a function: a loop variable, or one assigned a constant. A call of the name
#' still finds the function (`for (yoy in 1:3)` then `yoy(1)`; audit of
#' 21478080, P2).
#' @param pd The parse data.
#' @return A data frame: name, scope (a parse id, 0 for the top level), fun.
#' @noRd
.bl_migrate_defined <- function(pd) {
  bare <- function(x) gsub("^`|`$", "", x)
  here <- function(row) .bl_pd_scopes(pd, pd$id[row])[1L]
  f <- which(pd$token == "SYMBOL_FORMALS")
  name <- bare(pd$text[f])
  scope <- pd$parent[f]
  fun <- rep(TRUE, length(f))
  as <- which(pd$token %in% c("LEFT_ASSIGN", "EQ_ASSIGN", "RIGHT_ASSIGN"))
  for (a in as) {
    k <- .bl_pd_kids(pd, pd$parent[a])
    right <- pd$token[a] == "RIGHT_ASSIGN"
    tgt <- if (right) k[length(k)] else k[1L]
    val <- if (right) k[1L] else k[length(k)]
    nm <- bare(pd$text[pd$parent == pd$id[tgt] & pd$token == "SYMBOL"])
    top <- pd$text[a] %in% c("<<-", "->>")
    name <- c(name, nm)
    scope <- c(scope, rep(if (top) 0L else here(a), length(nm)))
    fun <- c(fun, rep(!.bl_pd_is_const(pd, val), length(nm)))
  }
  fc <- which(pd$token == "forcond")
  for (r in fc) {
    nm <- bare(pd$text[pd$parent == pd$id[r] & pd$token == "SYMBOL"])
    name <- c(name, nm)
    scope <- c(scope, rep(here(r), length(nm)))
    fun <- c(fun, rep(FALSE, length(nm)))
  }
  s <- .bl_migrate_by_string(pd, here)
  data.frame(
    name = c(name, s$name),
    scope = c(scope, s$scope),
    fun = c(fun, rep(TRUE, length(s$name))),
    stringsAsFactors = FALSE
  )
}

#' Says whether a parse node is a constant alone: a number, a string, TRUE,
#' NULL.
#' @param pd The parse data.
#' @param row The node's row in `pd`.
#' @return TRUE or FALSE.
#' @noRd
.bl_pd_is_const <- function(pd, row) {
  k <- which(pd$parent == pd$id[row])
  length(k) == 1L &&
    pd$token[k] %in% c("NUM_CONST", "STR_CONST", "NULL_CONST")
}

#' The names given as a string to assign(), delayedAssign(),
#' makeActiveBinding(), setGeneric() or setMethod(), each with its scope.
#' @param pd The parse data.
#' @param here A function of a row: the scope it is in.
#' @return list(name, scope).
#' @noRd
.bl_migrate_by_string <- function(pd, here) {
  fns <- c(
    "assign", "delayedAssign", "makeActiveBinding", "setGeneric", "setMethod"
  )
  name <- character()
  scope <- integer()
  for (r in which(pd$token == "SYMBOL_FUNCTION_CALL" & pd$text %in% fns)) {
    a <- .bl_migrate_by_string1(pd, r)
    if (!is.null(a)) {
      name <- c(name, a$name)
      # an environment named in the call (assign(envir = globalenv()) in a
      # function) may be any scope, so the name counts everywhere: it was
      # taken as the function's own (audit of 716154bd, N11)
      scope <- c(scope, if (a$any) 0L else here(r))
    }
  }
  list(name = name, scope = scope)
}

#' The name one call of assign() and the like defines, read from the call as
#' R matches its arguments: by name in any order, or by position
#' (`assign(value = f, x = "yoy")` defines yoy; audit of 21478080, P2).
#' @param pd The parse data.
#' @param r The row of the function's name in `pd`.
#' @return NULL when the name is not a string; else list(name, any), `any`
#'   TRUE when the call names an environment other than its own.
#' @noRd
.bl_migrate_by_string1 <- function(pd, r) {
  fn <- pd$text[r]
  call_id <- pd$parent[match(pd$parent[r], pd$id)]
  cl <- tryCatch(
    str2lang(pd$text[match(call_id, pd$id)]),
    error = function(e) NULL
  )
  def <- switch(
    fn,
    assign = base::assign,
    delayedAssign = base::delayedAssign,
    makeActiveBinding = base::makeActiveBinding,
    setGeneric = function(name, def, ...) NULL,
    function(f, signature, definition, ...) NULL
  )
  m <- if (is.call(cl)) {
    tryCatch(as.list(match.call(def, cl)), error = function(e) NULL)
  }
  arg <- c(
    assign = "x", delayedAssign = "x", makeActiveBinding = "sym",
    setGeneric = "name", setMethod = "f"
  )[[fn]]
  nm <- m[[arg]]
  if (!is.character(nm) || length(nm) != 1L || is.na(nm)) {
    return(NULL)
  }
  envs <- switch(
    fn,
    assign = c("pos", "envir"),
    delayedAssign = "assign.env",
    makeActiveBinding = "env",
    character()
  )
  own <- vapply(m[intersect(envs, names(m))], identical, NA,
                quote(environment()))
  list(name = nm, any = !length(envs) || !all(own))
}

#' Says whether a name used at a parse row is one the script defines in a
#' scope that reaches that row.
#' @param pd The parse data.
#' @param row The row of the use.
#' @param name The name used.
#' @param def The definitions (.bl_migrate_defined()).
#' @return TRUE or FALSE.
#' @noRd
.bl_migrate_own <- function(pd, row, name, def) {
  any(def$name == name & def$scope %in% .bl_pd_scopes(pd, pd$id[row]))
}

#' The edits to renamed functions referred to without a call: passed by name
#' as an argument, or named by a string in do.call() and the like.
#' @param pd The parse data.
#' @param m The map of 0.5.x names.
#' @return A list of edits (.bl_migrate_edit()).
#' @noRd
.bl_migrate_refs <- function(pd, m) {
  old <- m$old
  def <- .bl_migrate_defined(pd)
  fdef <- def[def$fun, , drop = FALSE]
  edits <- list()
  for (s in which(pd$token == "SYMBOL" & pd$text %in% old)) {
    if (
      .bl_migrate_ours(pd, s) &&
        .bl_migrate_is_arg(pd, pd$parent[s]) &&
        !.bl_migrate_own(pd, s, pd$text[s], def)
    ) {
      edits <- c(
        edits,
        list(.bl_migrate_edit(pd, s, .bl_old_row(pd$text[s])$new))
      )
    }
  }
  for (s in which(pd$token == "STR_CONST")) {
    q <- substr(pd$text[s], 1L, 1L)
    val <- substr(pd$text[s], 2L, nchar(pd$text[s]) - 1L)
    fs <- if (q %in% c("'", "\"") && val %in% old) {
      .bl_migrate_fn_str(pd, s)
    } else {
      ""
    }
    # do.call() and match.fun() look for a function, as a call does
    seen <- if (fs %in% c("do.call", "match.fun")) fdef else def
    if (nzchar(fs) && !.bl_migrate_own(pd, s, val, seen)) {
      new <- paste0(q, .bl_old_row(val)$new, q)
      edits <- c(edits, list(.bl_migrate_edit(pd, s, new)))
    }
  }
  edits
}

#' Says whether an expression is an argument of a call (not the function
#' called, not the body of a function or an if).
#' @param pd The parse data.
#' @param e The expression's parse id.
#' @return TRUE or FALSE.
#' @noRd
.bl_migrate_is_arg <- function(pd, e) {
  k <- .bl_pd_kids(pd, pd$parent[match(e, pd$id)])
  length(k) >= 3L &&
    pd$token[k[1L]] == "expr" &&
    pd$token[k[2L]] == "'('" &&
    pd$id[k[1L]] != e
}

#' Says whether a string is the function named in do.call(), match.fun(),
#' get(), get0() or exists(): their first argument, or `what`, `FUN` or `x`.
#' @param pd The parse data.
#' @param s The string's row in `pd`.
#' @return The name of the function the string is passed to, or "".
#' @noRd
.bl_migrate_fn_str <- function(pd, s) {
  e <- pd$parent[s]
  if (!.bl_migrate_is_arg(pd, e)) {
    return("")
  }
  k <- .bl_pd_kids(pd, pd$parent[match(e, pd$id)])
  fn <- pd$text[
    pd$parent == pd$id[k[1L]] & pd$token == "SYMBOL_FUNCTION_CALL"
  ]
  ok <- c("do.call", "match.fun", "get", "get0", "exists")
  if (length(fn) != 1L || !fn %in% ok) {
    return("")
  }
  i <- match(e, pd$id[k])
  if (pd$token[k[i - 1L]] == "EQ_SUB") {
    return(if (pd$text[k[i - 2L]] %in% c("what", "FUN", "x")) fn else "")
  }
  # the first unnamed argument
  args <- k[-(1:2)]
  args <- args[pd$token[args] == "expr"]
  named <- vapply(
    args,
    function(a) pd$token[k[match(a, k) - 1L]] == "EQ_SUB",
    NA
  )
  if (identical(args[!named][1L], k[i])) fn else ""
}

#' Reads one file for the migrate verb.
#'
#' A folder, a missing file or one that cannot be read is said in one line: a
#' folder reached readLines() and failed as "cannot open the connection", with
#' base R's warnings (audit of 21478080, P4).
#' @param f The file named on the command line.
#' @return list(lines, why): `why` NULL when the file was read.
#' @noRd
.bl_migrate_read <- function(f) {
  why <- if (!file.exists(f)) {
    "no such file"
  } else if (dir.exists(f)) {
    "a folder, not an R file"
  } else if (!identical(.rmbl_path_kind(path.expand(f)), "regular")) {
    # a pipe or a device has no end to read to
    "not a regular file (a device, a pipe or a socket)"
  }
  lines <- if (is.null(why)) {
    tryCatch(
      suppressWarnings(.rmbl_rlines(f, encoding = "UTF-8")),
      error = function(e) NULL
    )
  }
  if (is.null(why) && is.null(lines)) {
    why <- "cannot be read (no permission, or not a file)"
  }
  list(lines = lines, why = why)
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
    old <- .bl_migrate_read(f)
    if (!is.null(old$why)) {
      out(sprintf("%s: %s\n", f, old$why))
      status <- 1L
      next
    }
    old <- old$lines
    res <- tryCatch(.bl_migrate_text(old), error = function(e) e)
    if (inherits(res, "error")) {
      out(sprintf(
        "%s: not R code R can parse (%s)\n",
        f,
        conditionMessage(res)
      ))
      status <- 1L
      next
    }
    if (!res$n) {
      out(sprintf("%s: no 0.5.x names\n", f))
      next
    }
    d <- which(old != res$lines)
    for (i in d) {
      out(sprintf("%s:%d\n- %s\n+ %s\n", f, i, old[i], res$lines[i]))
    }
    if (has("--write")) {
      .rmbl_wlines(res$lines, f)
      out(sprintf("%s: %d changes written\n", f, res$n))
    } else {
      out(sprintf("%s: %d changes (--write writes them)\n", f, res$n))
    }
  }
  status
}

#' The lines of a .csv named to run, from its bytes on disk.
#'
#' A compressed file is said to be one (gzip and xz by their magic, bzip2
#' by its header and block mark: "BZh" alone is how a text file may begin),
#' and a NUL byte or an empty file is refused in the table's own words.
#' @param path The .csv file, already found to be a regular file.
#' @return Its lines, one element each.
#' @noRd
.bl_run_csv <- function(path) {
  h <- readBin(path, "raw", 10L)
  is <- function(m, at = 1L) {
    length(h) >= at + length(m) - 1L &&
      identical(h[at + seq_along(m) - 1L], m)
  }
  kind <- if (is(as.raw(c(0x1f, 0x8b)))) {
    "gzip"
  } else if (is(as.raw(c(0xfd, 0x37, 0x7a, 0x58, 0x5a, 0x00)))) {
    "xz"
  } else if (is(charToRaw("BZh")) && is(charToRaw("1AY&SY"), 5L)) {
    "bzip2"
  }
  shown <- .rmbl_shown(path)
  if (!is.null(kind)) {
    stop(
      "run: the .csv is compressed (", kind, ") and is read as it is on ",
      "disk; decompress it first: ", shown,
      call. = FALSE
    )
  }
  if (!length(h)) {
    stop("run: the .csv is empty: ", shown, call. = FALSE)
  }
  # readLines() cuts a line at a NUL without a word
  if (any(readBin(path, "raw", file.size(path)) == as.raw(0L))) {
    stop(
      "run: the .csv holds a NUL byte, so it is no table of text: ", shown,
      call. = FALSE
    )
  }
  .rmbl_rlines(path)
}

#' Reads one command-line value for run.
#'
#' A .csv or .rds file that exists is read; otherwise a comma-separated list
#' becomes a vector, and numbers, TRUE/FALSE and NA their type
#' (utils::type.convert); NULL is NULL.
#' @noRd
.bl_run_value <- function(s) {
  if (identical(s, "NULL")) {
    return(NULL)
  }
  # a file the user names: a pipe or a device is refused, and a .csv is
  # read from its bytes on disk (read.csv() of a path inflates gzip)
  if (file.exists(s) && grepl("\\.csv$", s, ignore.case = TRUE)) {
    return(utils::read.csv(text = .bl_run_csv(.rmbl_file1(s, "VALUE"))))
  }
  if (file.exists(s) && grepl("\\.rds$", s, ignore.case = TRUE)) {
    return(readRDS(.rmbl_file1(s, "VALUE")))
  }
  utils::type.convert(strsplit(s, ",", fixed = TRUE)[[1L]], as.is = TRUE)
}

#' The run verb: calls a function by its 0.5.x or 1.0.0 name.
#' @noRd
.bl_cli_run <- function(rest, out, usage_error, prog) {
  if (!length(rest)) {
    usage_error(sprintf("usage: %s run NAME [VALUE...] [--ARG VALUE...]", prog))
  }
  name <- rest[[1L]]
  r <- .bl_old_row(name)
  ns <- asNamespace("rmoriebricklayer")
  fn <- if (is.null(r)) name else r$new
  if (!fn %in% getNamespaceExports(ns)) {
    usage_error(sprintf(
      paste0(
        "'%s' is not a function of rmoriebricklayer, old or new (%s ",
        "functions lists them)"
      ),
      .rmbl_printable(name),
      prog
    ))
  }
  args <- .bl_run_args(rest[-1L], r)
  if (!is.null(r)) {
    out(sprintf("(%s() is now %s())\n", name, fn))
  }
  v <- withVisible(do.call(getExportedValue(ns, fn), args))
  if (v$visible) {
    out(paste0(
      paste(utils::capture.output(print(v$value)), collapse = "\n"),
      "\n"
    ))
  }
  0L
}

#' One edit for .bl_migrate_text(): a parsed token and its replacement.
#' @param pd The parse data.
#' @param row The token's row in `pd`.
#' @param new The replacement text.
#' @return list(l, c1, c2, new).
#' @noRd
.bl_migrate_edit <- function(pd, row, new) {
  list(
    l = pd$line1[row],
    c1 = pd$col1[row],
    c2 = pd$col2[row],
    new = new
  )
}

#' The new name of an argument of a renamed function.
#' @param r A row from .bl_old_row().
#' @param a The argument's name as written.
#' @return Its 1.0.0 name (`a` when it was not renamed).
#' @noRd
.bl_old_arg_name <- function(r, a) {
  if (a %in% names(r$args)) {
    r$args[[a]]
  } else if (a %in% names(r$dots)) {
    r$dots[[a]]
  } else {
    a
  }
}

#' The edits to the named arguments of one renamed call.
#' @param pd The parse data.
#' @param fe The parse id of the call's function expression.
#' @param r The function's row from .bl_old_row().
#' @return A list of edits (.bl_migrate_edit()).
#' @noRd
.bl_migrate_args <- function(pd, fe, r) {
  kids <- .bl_pd_kids(pd, pd$parent[pd$id == fe])
  edits <- list()
  for (k in seq_along(kids)) {
    j <- kids[k]
    if (pd$token[j] != "SYMBOL_SUB") {
      next
    }
    a <- pd$text[j]
    to <- .bl_old_arg_name(r, a)
    if (!identical(to, a)) {
      edits <- c(edits, list(.bl_migrate_edit(pd, j, to)))
    }
    edits <- c(edits, .bl_migrate_value(pd, kids, k, r$values[[a]]))
  }
  edits
}

#' The edit to a renamed allowed value passed to a named argument.
#' @param pd The parse data.
#' @param kids The rows of the call's children, in source order.
#' @param k The position in `kids` of the argument's name.
#' @param vm The argument's renamed values (old -> new), or NULL.
#' @return A list of at most one edit.
#' @noRd
.bl_migrate_value <- function(pd, kids, k, vm) {
  if (is.null(vm) || k + 2L > length(kids)) {
    return(list())
  }
  v <- kids[k + 2L] # SYMBOL_SUB, EQ_SUB, then the value
  s <- which(pd$parent == pd$id[v] & pd$token == "STR_CONST")
  if (length(s) != 1L) {
    return(list())
  }
  q <- substr(pd$text[s], 1L, 1L)
  val <- substr(pd$text[s], 2L, nchar(pd$text[s]) - 1L)
  if (val %in% names(vm)) {
    return(list(.bl_migrate_edit(pd, s, paste0(q, vm[[val]], q))))
  }
  list()
}

#' Applies the edits of .bl_migrate_text() to the source.
#' @param lines The source, a character vector of lines.
#' @param edits A list of edits (.bl_migrate_edit()).
#' @return The rewritten lines.
#' @noRd
.bl_migrate_apply <- function(lines, edits) {
  # right to left, so the columns of the edits still to make stay put
  ord <- order(-vapply(edits, `[[`, 1, "l"), -vapply(edits, `[[`, 1, "c1"))
  for (e in edits[ord]) {
    x <- lines[e$l]
    lines[e$l] <- paste0(
      substr(x, 1L, e$c1 - 1L),
      e$new,
      substr(x, e$c2 + 1L, nchar(x))
    )
  }
  lines
}

#' The arguments of the run verb, from the words after the function's name.
#' @param words The command-line words.
#' @param r The function's row from .bl_old_row(), or NULL for a 1.0.0 name.
#' @return A list of arguments for do.call().
#' @noRd
.bl_run_args <- function(words, r) {
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
        if (is.character(v) && !is.null(vm)) {
          v <- unname(ifelse(v %in% names(vm), vm[v], v))
        }
        a <- .bl_old_arg_name(r, a)
      }
      args[a] <- list(v)
      i <- i + if (flagonly) 1L else 2L
    } else {
      args[length(args) + 1L] <- list(.bl_run_value(w))
      i <- i + 1L
    }
  }
  args
}
