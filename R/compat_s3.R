# Hand-written part of the 0.5.x compatibility layer: the helpers the generated aliases in
# R/compat_names.R call, and the four 0.5.13 S3 generics with their methods.

# The names of `...` with the 0.5.x argument names in `map` (old = new) renamed, or NULL when
# none needs renaming.
.rmbl_alias_dots <- function(map, ...) {
  n <- ...names()
  k <- n %in% names(map)
  if (!any(k)) return(NULL)
  n[k] <- unname(map[n[k]])
  n
}

# Evaluates `cl` (the forwarding call without `...`) in the alias frame `env` with the alias's
# `...` appended as ..1, ..2, ... under the renamed names `nm`, so promises stay lazy.
.rmbl_alias_redot <- function(cl, nm, env) {
  d <- lapply(seq_along(nm), function(i) as.name(paste0("..", i)))
  names(d) <- nm
  eval(as.call(c(as.list(cl), d)), env)
}

# The four 0.5.13 S3 generics. They stay generics, so methods written for them still dispatch;
# each method takes the 0.5.13 arguments and calls the new generic with the new names. The call
# is rebuilt from the argument expressions, so a bare column name still reads as one.

#' @rdname rmbl-aliases
#' @usage NULL
#' @export
rate <- function(x, ...) UseMethod("rate")

#' @rdname rmbl-aliases
#' @usage NULL
#' @export
rate.data.frame <- function(x, count, population, by = NULL, per = 1000,
                            conf_level = 0.95, min_count = 0, ...) {
  r <- withVisible(eval(substitute(rtcalc(x = x, count = count, pop = population, by = by, per = per,
                         conflvl = conf_level, mincnt = min_count, ...)), parent.frame()))
  .rmbl_alias_out("rate", r)
}

#' @rdname rmbl-aliases
#' @usage NULL
#' @export
rate.default <- function(x, population, per = 1000, conf_level = 0.95, min_count = 0, ...) {
  r <- withVisible(eval(substitute(rtcalc(x = x, pop = population, per = per, conflvl = conf_level,
                         mincnt = min_count, ...)), parent.frame()))
  .rmbl_alias_out("rate", r)
}

#' @rdname rmbl-aliases
#' @usage NULL
#' @export
rate_change <- function(x, ...) UseMethod("rate_change")

#' @rdname rmbl-aliases
#' @usage NULL
#' @export
rate_change.data.frame <- function(x, count, population, period, by = NULL, lag = 1L,
                                   per = 1000, conf_level = 0.95, min_count = 0, ...) {
  r <- withVisible(eval(substitute(ratechg(x = x, count = count, pop = population, prd = period, by = by,
                          lag = lag, per = per, conflvl = conf_level, mincnt = min_count,
                          ...)), parent.frame()))
  .rmbl_alias_out("rate_change", r)
}

#' @rdname rmbl-aliases
#' @usage NULL
#' @export
rate_change.default <- function(x, ...) {
  # ratechg.default refuses: there is no result to rename
  eval(substitute(ratechg(x = x, ...)), parent.frame())
}

#' @rdname rmbl-aliases
#' @usage NULL
#' @export
share <- function(x, ...) UseMethod("share")

#' @rdname rmbl-aliases
#' @usage NULL
#' @export
share.data.frame <- function(x, count, by = NULL, total = NULL, conf_level = 0.95, ...) {
  r <- withVisible(eval(substitute(shrs(x = x, count = count, by = by, total = total, conflvl = conf_level,
                       ...)), parent.frame()))
  .rmbl_alias_out("share", r)
}

#' @rdname rmbl-aliases
#' @usage NULL
#' @export
share.default <- function(x, total = NULL, conf_level = 0.95, ...) {
  r <- withVisible(eval(substitute(shrs(x = x, total = total, conflvl = conf_level, ...)), parent.frame()))
  .rmbl_alias_out("share", r)
}

#' @rdname rmbl-aliases
#' @usage NULL
#' @export
yoy_summary <- function(object, ...) UseMethod("yoy_summary")

#' @rdname rmbl-aliases
#' @usage NULL
#' @export
yoy_summary.default <- function(object, ...) {
  .rmbl_alias_out("yoy_summary", withVisible(yoysmry(.rmbl_new_names(object), ...)))
}

#' @rdname rmbl-aliases
#' @usage NULL
#' @export
yoy_summary.rmbl_yoy <- function(object, ...) {
  .rmbl_alias_out("yoy_summary", withVisible(yoysmry(.rmbl_new_names(object), ...)))
}

# Inputs: a result an alias returned (marked "rmbl_old") is turned back into its 1.0.0 names
# before the 1.0.0 function reads it. Every argument the caller gave is checked, except those the
# target reads unevaluated (a bare column name); `skip` names them.
.rmbl_alias_in <- function(env, skip = character()) {
  for (a in setdiff(names(formals(sys.function(-1L))), c("...", skip))) {
    if (!eval(call("missing", as.name(a)), env)) {
      v <- get(a, envir = env)
      if (inherits(v, "rmbl_old")) assign(a, .rmbl_new_names(v), envir = env)
    }
  }
  invisible(NULL)
}

# The delimited writers: the header row an alias writes is under the 0.5.x names as well, in the
# text returned and in the file written.
.rmbl_alias_header <- function(v, file, map) {
  fix <- function(l) {
    i <- which(!startsWith(l, "#"))[1L]
    if (is.na(i)) return(l)
    sep <- if (grepl("\t", l[i])) "\t" else ","
    h <- strsplit(l[i], sep, fixed = TRUE)[[1L]]
    k <- h %in% names(map)
    h[k] <- unname(map[h[k]])
    l[i] <- paste(h, collapse = sep)
    l
  }
  x <- v$value
  # a text file only: yoy_write() also writes PDF and HTML
  if (is.character(file) && length(file) == 1L && grepl("[.](csv|tsv|txt)$", file, ignore.case = TRUE) &&
      file.exists(file)) {
    writeLines(fix(readLines(file, warn = FALSE)), file)
  } else if (is.character(x) && length(x) == 1L) {
    x <- paste(fix(strsplit(x, "\n", fixed = TRUE)[[1L]]), collapse = "\n")
    if (endsWith(v$value, "\n")) x <- paste0(x, "\n")
  }
  if (v$visible) x else invisible(x)
}

# The generics an "rmbl_old" result is drawn, printed or summarised with: the package's own
# method gets the result in its 1.0.0 names (and print() returns the object as given); with no
# method of the package's, R's own runs on the 0.5.x names.
.rmbl_old_call <- function(generic, x, ...) {
  ns <- asNamespace("rmoriebricklayer")
  cls <- setdiff(oldClass(x), "rmbl_old")
  own <- any(vapply(cls, function(k) {
    f <- utils::getS3method(generic, k, optional = TRUE)
    !is.null(f) && identical(environment(f), ns)
  }, NA))
  if (own) {
    r <- withVisible(match.fun(generic)(.rmbl_new_names(x), ...))
    if (identical(generic, "print")) return(invisible(x))
    # the method's own result (a summary, the points drawn) under the same 0.5.x names
    done <- attr(x, "rmbl_names")
    return(if (r$visible) .rmbl_names_swap(r$value, done) else invisible(.rmbl_names_swap(r$value, done)))
  }
  class(x) <- cls
  attr(x, "rmbl_names") <- NULL
  r <- match.fun(generic)(x, ...)
  if (identical(generic, "print")) invisible(x) else r
}

#' @rdname rmbl-aliases
#' @usage NULL
#' @export
print.rmbl_old <- function(x, ...) .rmbl_old_call("print", x, ...)

#' @rdname rmbl-aliases
#' @usage NULL
#' @export
format.rmbl_old <- function(x, ...) .rmbl_old_call("format", x, ...)

#' @rdname rmbl-aliases
#' @usage NULL
#' @export
plot.rmbl_old <- function(x, ...) .rmbl_old_call("plot", x, ...)

#' @rdname rmbl-aliases
#' @usage NULL
#' @export
summary.rmbl_old <- function(object, ...) .rmbl_old_call("summary", object, ...)
