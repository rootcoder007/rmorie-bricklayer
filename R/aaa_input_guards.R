# Input contracts shared by the exported primitives. A numeric kernel that
# silently coerces "abc" to NA, a hash that digests the text "NA", or a
# stock-and-flow measure that accepts Inf all return a value that looks
# like an answer. The degenerate-input sweep of 2026-09-18 found 117
# exports doing one of those; these guards make every such call an error
# that names the argument.

#' The function a refusal comes from, as "fn: ".
#'
#' A check several functions share still says which of them refused (srr G5.2a: every
#' message unique; "`data` must be a data frame" came from 21). It is the nearest frame on the
#' stack running an exported function or an S3 method of the package, the method named by its
#' generic; "" when there is none (an internal helper called on its own).
#' @return A string, "fn: " or "".
#' @noRd
.rmbl_fn <- function() {
  ns <- environment(.rmbl_fn)
  s3 <- getNamespaceInfo(ns, "S3methods")
  ex <- getNamespaceExports(ns)
  for (i in rev(seq_len(sys.nframe() - 1L))) {
    f <- sys.function(i)
    if (!identical(environment(f), ns)) next
    h <- sys.call(i)[[1L]]
    if (is.call(h) && as.character(h[[1L]]) %in% c("::", ":::")) h <- h[[3L]]
    # do.call(fromjs, ...) calls the function itself, not its name
    nm <- if (is.name(h)) as.character(h) else ex[vapply(ex, function(n) identical(get0(n, ns), f), NA)][1L]
    g <- if (!is.na(nm)) s3[which(s3[, 3L] == nm), 1L]
    if (length(g)) return(paste0(g[[1L]], ": "))
    if (!is.na(nm) && nm %in% ex) return(paste0(nm, ": "))
  }
  ""
}

#' Checks that an argument is numeric (or logical) and returns it as a double vector.
#' @param x The value passed by the user.
#' @param what The argument's name, used in the error message.
#' @param allow_null Whether NULL is accepted (it becomes `numeric(0)`).
#' @return A double vector.
#' @noRd
.rmbl_num_input <- function(x, what, allow_null = TRUE) {
  if (is.null(x)) {
    if (allow_null) return(numeric(0))
    stop(.rmbl_fn(), sprintf("`%s` must be numeric, got NULL", what), call. = FALSE)
  }
  if (is.factor(x) || is.character(x) || is.list(x) || is.data.frame(x) ||
        !(is.numeric(x) || is.logical(x))) {
    stop(.rmbl_fn(), sprintf("`%s` must be numeric, got %s", what, class(x)[1]),
      call. = FALSE
    )
  }
  as.numeric(x)
}

#' Checks that an argument is numeric with no infinite value and returns its non-missing values.
#' @param x The value passed by the user.
#' @param what The argument's name, used in the error message.
#' @param nonneg Whether negative values are refused.
#' @param min_n The least number of non-missing values accepted.
#' @return A double vector with the missing values dropped.
#' @noRd
.rmbl_finite_input <- function(x, what, nonneg = FALSE, min_n = 0L) {
  x <- .rmbl_num_input(x, what)
  x <- x[!is.na(x)]
  if (any(!is.finite(x))) {
    stop(.rmbl_fn(), sprintf("`%s` must be finite (no Inf)", what), call. = FALSE)
  }
  if (nonneg && any(x < 0)) {
    stop(.rmbl_fn(), sprintf("`%s` must be non-negative", what), call. = FALSE)
  }
  if (length(x) < min_n) {
    stop(.rmbl_fn(), sprintf("`%s` needs at least %s non-missing value%s, got %d", what,
                 if (min_n == 1L) "one" else as.character(min_n),
                 if (min_n == 1L) "" else "s", length(x)), call. = FALSE)
  }
  x
}

#' Checks that an argument is character (or raw, when allowed) and returns it unchanged.
#' @param x The value passed by the user.
#' @param what The argument's name, used in the error message.
#' @param allow_raw Whether a raw vector is accepted.
#' @return `x`.
#' @noRd
.rmbl_text_input <- function(x, what, allow_raw = TRUE) {
  if (allow_raw && is.raw(x)) return(x)
  # a logical NA is left to the caller's own length/NA check
  if (is.logical(x) && all(is.na(x))) return(x)
  if (!is.character(x)) {
    stop(.rmbl_fn(), sprintf("`%s` must be character%s, got %s", what,
                 if (allow_raw) " or raw" else "", class(x)[1]),
      call. = FALSE
    )
  }
  x
}

#' Checks a column-name argument.
#'
#' A column-name argument: text naming one column (or, with `several`, one or more), none missing or
#' empty. NULL or character(0) went on to data\[, cols\] and failed there as "get1index" (statistics
#' stress test of 5e1dce5).
#' @param x The column name or names passed by the user.
#' @param what The argument's name, used in the error message.
#' @param several Whether more than one column may be named.
#' @return `x`.
#' @noRd
.rmbl_colnames <- function(x, what, several = FALSE) {
  ok <- is.character(x) && length(x) >= 1L && !anyNA(x) && all(nzchar(x)) && (several || length(x) == 1L)
  if (!ok) {
    stop(.rmbl_fn(), sprintf("`%s` must name %s of `data`", what, if (several) "one or more columns" else "one column"),
         call. = FALSE)
  }
  x
}

#' Marks unmarked valid UTF-8 text as UTF-8.
#'
#' Text that is valid UTF-8 but carries no encoding mark is marked UTF-8, so that a group or level
#' a user types ("Metis" with an accent) matches the same bytes read from a table with
#' `encoding = "UTF-8"` in every locale: in a C locale R left the literal unmarked and
#' `%in%` called the two different (the C-locale CI cell, 1.0.0).
#' @param x A character vector; anything else is returned as it is.
#' @return `x`, with its unmarked valid UTF-8 elements marked UTF-8.
#' @noRd
.rmbl_utf8 <- function(x) {
  if (!is.character(x)) return(x)
  u <- !is.na(x) & Encoding(x) == "unknown" & validUTF8(x)
  if (any(u)) {
    v <- x[u]
    Encoding(v) <- "UTF-8"
    x[u] <- v
  }
  x
}

#' Checks that an argument is a single non-empty string and returns it marked UTF-8.
#' @param x The value passed by the user.
#' @param what The argument's name, used in the error message.
#' @return `x`, through `.rmbl_utf8()`.
#' @noRd
.rmbl_string1 <- function(x, what) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(trimws(x))) {
    stop(.rmbl_fn(), sprintf("`%s` must be a single non-empty string", what),
      call. = FALSE
    )
  }
  .rmbl_utf8(x)
}

#' Matches an argument against its accepted values.
#'
#' .rmbl_arg() in the package's words: `what` must be one of the choices, and what was given is named
#' (match.arg's "'arg' should be one of" names neither; review of 29a55d8, hostile battery). Without
#' `choices` they are the argument's default in the calling function, as .rmbl_arg() finds them.
#' @param arg The value passed by the user; NULL or the full default vector picks the first choice.
#' @param choices The accepted values.
#' @param several Whether more than one choice may be given.
#' @return The matched choice or choices.
#' @noRd
.rmbl_arg <- function(arg, choices, several = FALSE) {
  what <- paste(deparse(substitute(arg)), collapse = "")
  if (missing(choices)) {
    fn <- sys.function(sysp <- sys.parent())
    choices <- eval(formals(fn)[[what]], envir = sys.frame(sysp))
  }
  if (is.null(arg)) return(choices[[1L]])
  if (!several && identical(arg, choices)) return(choices[[1L]])
  shown <- paste(dQuote(choices, FALSE), collapse = ", ")
  given <- .rmbl_printable(paste(utils::head(deparse(arg), 1L), collapse = ""))
  if (!is.character(arg) || !length(arg) || anyNA(arg) || (!several && length(arg) != 1L)) {
    stop(.rmbl_fn(),
         sprintf("`%s` must be %s %s, not %s", what, if (several) "one or more of" else "one of", shown, given),
         call. = FALSE)
  }
  i <- pmatch(arg, choices, nomatch = 0L, duplicates.ok = several)
  if (any(i == 0L)) {
    stop(.rmbl_fn(),
         sprintf("`%s` must be %s %s, not %s", what, if (several) "one or more of" else "one of", shown, given),
         call. = FALSE)
  }
  unique(choices[i])
}

#' Checks that a data frame has unique, non-empty column names.
#'
#' A data frame's columns must be named, every name non-empty and no name twice: a frame built by
#' hand with NULL or "" names is refused in words, not with a subscript error later (review of
#' 29a55d8, hostile battery).
#' @param data The data frame passed by the user.
#' @param what The argument's name, used in the error message.
#' @return `TRUE`, invisibly.
#' @noRd
.rmbl_df_names <- function(data, what = "data") {
  if (!is.data.frame(data)) {
    stop(.rmbl_fn(),
         sprintf("`%s` must be a data frame, not %s", what, if (is.null(data)) "NULL" else class(data)[[1L]]),
         call. = FALSE)
  }
  nm <- names(data)
  if (length(data) && (is.null(nm) || anyNA(nm) || any(!nzchar(nm)))) {
    stop(.rmbl_fn(), sprintf("every column of `%s` must have a name (names(%s) has an empty one)", what, what),
         call. = FALSE)
  }
  if (anyDuplicated(nm)) {
    stop(.rmbl_fn(), sprintf("`%s` has two columns named %s: rename one", what, nm[duplicated(nm)][[1L]]),
         call. = FALSE)
  }
  invisible(TRUE)
}

#' Checks a seed for a native generator.
#'
#' A seed for a native generator: one whole number in [0, 2^53). The core casts it to an unsigned
#' 64-bit integer, and a NA, negative or fractional double cast that way is undefined behaviour.
#' @param seed The value passed by the user.
#' @param what The argument's name, used in the error message.
#' @return The seed as a double.
#' @noRd
.rmbl_seed <- function(seed, what = "seed") {
  seed <- .rmbl_num(seed, what)
  if (length(seed) != 1L || is.na(seed) || seed < 0 || seed != floor(seed) || seed >= 2^53) {
    stop(.rmbl_fn(), sprintf("`%s` must be a whole number in [0, 2^53)", what), call. = FALSE)
  }
  seed
}

#' A confidence level: one number strictly inside (0, 1); outside it the interval quantiles are NaN
#' @param x The value passed by the user.
#' @param what The argument's name, used in the error message.
#' @return The level as a double.
#' @noRd
.rmbl_conf_level <- function(x, what = "conflvl") {
  x <- .rmbl_num(x, what)
  if (length(x) != 1L || is.na(x) || x <= 0 || x >= 1) {
    stop(.rmbl_fn(), sprintf("`%s` must be a single number strictly between 0 and 1", what), call. = FALSE)
  }
  x
}

#' Checks that an argument is a number (a whole one with `integer`) and converts it.
#'
#' A numeric argument: text that is not a number is refused in words (as.numeric() turned it into NA
#' with "NAs introduced by coercion" and the function failed further on); every other type converts
#' exactly as as.numeric() / as.integer() always did.
#' @param x The value passed by the user.
#' @param what The argument's name, used in the error message.
#' @param integer Whether the value must be a whole number, returned as an integer.
#' @return A double vector, or an integer vector with `integer = TRUE`.
#' @noRd
.rmbl_num <- function(x, what, integer = FALSE) {
  # a list, a data frame, a factor, a complex number or a function is no number: as.numeric() refused
  # them in its own words ("'list' object cannot be coerced to type 'double'") or read a factor's codes
  # (re-test of the b617a3f CRAN stress fixes, hostile battery)
  if (!is.null(x) && (!is.atomic(x) || is.factor(x) || is.complex(x) || is.raw(x))) {
    stop(.rmbl_fn(), sprintf("`%s` must be a%s number, not %s", what, if (integer) " whole" else "",
                 if (is.data.frame(x)) "a data frame" else if (is.factor(x)) "a factor" else
                   if (is.function(x)) "a function" else class(x)[[1L]]), call. = FALSE)
  }
  # a date is a number of days, never a count: reps = Sys.Date() ran 20,000 replications (CRAN stress
  # test of 0.5.14). A period (the x of a trend) may be a date, so only counts refuse it.
  if (integer && inherits(x, c("Date", "POSIXt", "difftime"))) {
    stop(.rmbl_fn(), sprintf("`%s` must be a whole number, not a %s", what, class(x)[[1L]]), call. = FALSE)
  }
  if (is.character(x)) {
    v <- suppressWarnings(as.numeric(x))
    bad <- !is.na(x) & is.na(v) & nzchar(trimws(x)) & x != "NA"
    if (any(bad)) {
      stop(.rmbl_fn(), sprintf("`%s` must be numeric, not text such as \"%s\"", what, x[bad][1L]), call. = FALSE)
    }
    x <- v
  }
  # a number, not a flag: as.numeric(TRUE) is 1 (maxprs = TRUE was read as one pair)
  if (is.logical(x) && any(!is.na(x))) {
    stop(.rmbl_fn(),
         sprintf("`%s` must be a%s number, not %s", what, if (integer) " whole" else "", format(x[!is.na(x)][1L])),
         call. = FALSE)
  }
  if (!integer) return(as.numeric(x))
  # a whole number: as.integer() would read 2.5 as 2 and pick another setting silently, and
  # turn Inf or 1e10 into NA with a coercion warning
  x <- as.numeric(x)
  frac <- (is.finite(x) & x != floor(x)) | is.infinite(x)
  if (any(frac)) stop(.rmbl_fn(), sprintf("`%s` must be a whole number, not %s", what, format(x[frac][1L])),
                      call. = FALSE)
  big <- !is.na(x) & abs(x) > .Machine$integer.max
  if (any(big)) {
    stop(.rmbl_fn(), sprintf("`%s` is too large: %s (the limit is 2147483647)", what, format(x[big][1L])),
         call. = FALSE)
  }
  as.integer(x)
}

#' Checks where a function writes its output.
#'
#' Where a function writes: a connection, or one non-empty path (a number or NA reached file() and
#' writeLines() and failed in their words: "'con' is not a connection", "invalid 'description' argument")
#' @param file The connection or path passed by the user.
#' @param what The argument's name, used in the error message.
#' @param connection Whether a connection or NULL is accepted.
#' @return `file`.
#' @noRd
.rmbl_out_file <- function(file, what = "file", connection = TRUE) {
  # NULL: the writer returns the text instead
  if (connection && (is.null(file) || inherits(file, "connection"))) return(file)
  .rmbl_string1(file, what)
}

#' TRUE or FALSE, said in words when it is neither (`if (quiet)` failed on NA, a vector or a frame)
#' @param x The value passed by the user.
#' @param what The argument's name, used in the error message.
#' @return `x`.
#' @noRd
.rmbl_flag1 <- function(x, what) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    stop(.rmbl_fn(), sprintf("`%s` must be TRUE or FALSE", what), call. = FALSE)
  }
  x
}

#' One string, empty allowed (a title, an NA marker)
#' @param x The value passed by the user.
#' @param what The argument's name, used in the error message.
#' @return `x`.
#' @noRd
.rmbl_text1 <- function(x, what) {
  if (!is.character(x) || length(x) != 1L || is.na(x)) {
    stop(.rmbl_fn(), sprintf("`%s` must be a single string", what), call. = FALSE)
  }
  x
}

#' Checks a scalar numeric argument against a range.
#'
#' One number (a whole one with `integer`), finite, in \[min, max\]: the checks a scalar argument needs,
#' said in words. A list, a data frame, text that is no number, NA, a vector are each refused here, not
#' by the base R call they reached (`if (n < mintl)`: "missing value where TRUE/FALSE needed"; CRAN
#' stress test of 0.5.14)
#' @param x The value passed by the user.
#' @param what The argument's name, used in the error message.
#' @param min The smallest value accepted.
#' @param max The largest value accepted.
#' @param integer Whether the value must be a whole number.
#' @return The value as a double, or an integer with `integer = TRUE`.
#' @noRd
.rmbl_scalar <- function(x, what, min = -Inf, max = Inf, integer = FALSE) {
  v <- .rmbl_num(x, what, integer = integer)
  if (length(v) != 1L || is.na(v) || !is.finite(v) || v < min || v > max) {
    rng <- if (is.finite(min) && is.finite(max)) sprintf(" from %s to %s", format(min), format(max)) else
      if (is.finite(min)) sprintf(" of at least %s", format(min)) else
        if (is.finite(max)) sprintf(" of at most %s", format(max)) else ""
    stop(.rmbl_fn(), sprintf("`%s` must be one %s%s", what, if (integer) "whole number" else "number", rng),
         call. = FALSE)
  }
  v
}

#' Makes an error handler that returns a default but lets time limits through.
#'
#' An error handler for a user's function called in a loop (a statistic, an injection): the error
#' becomes `default`, except R's own time limits, which must end the call. Caught, they were each an NA,
#' and setTimeLimit() could never stop cpspwr() or cpsfals() (CRAN stress test of 0.5.14).
#' @param default The value an ordinary error becomes.
#' @return A handler function for `tryCatch(error = )`.
#' @noRd
.rmbl_or <- function(default) {
  force(default)
  function(e) {
    m <- conditionMessage(e)
    lim <- c("reached elapsed time limit", "reached CPU time limit",
             gettext("reached elapsed time limit", domain = "R"), gettext("reached CPU time limit", domain = "R"))
    if (any(startsWith(m, lim))) stop(e)
    default
  }
}

#' Refuses a function or an environment passed where data goes.
#'
#' A function where data goes: said in words, before as.character(), match() or `[` refuse it in
#' theirs ("cannot coerce type 'closure' to vector of type 'character'"; 64 such arguments in the
#' re-test of the b617a3f CRAN stress fixes). Called with the arguments named: .rmbl_no_fn(x = x)
#' @param ... The arguments to check, each named.
#' @return `TRUE`, invisibly.
#' @noRd
.rmbl_no_fn <- function(...) {
  a <- list(...)
  for (nm in names(a)) {
    if (is.function(a[[nm]])) stop(.rmbl_fn(), sprintf("`%s` must be data, not a function", nm), call. = FALSE)
    # an environment too: as.character() refuses it in its own words (CRAN stress test of 0.5.14)
    if (is.environment(a[[nm]])) stop(.rmbl_fn(), sprintf("`%s` must be data, not an environment", nm), call. = FALSE)
  }
  invisible(TRUE)
}

#' A file the function reads: one path that exists and is a file (not a directory)
#' @param path The path passed by the user.
#' @param what The argument's name, used in the error message.
#' @return The path.
#' @noRd
.rmbl_file1 <- function(path, what = "path") {
  path <- .rmbl_string1(path, what)
  if (!file.exists(path)) stop(.rmbl_fn(), sprintf("`%s`: no such file: %s", what, path), call. = FALSE)
  if (dir.exists(path)) stop(.rmbl_fn(), sprintf("`%s` is a directory, not a file: %s", what, path), call. = FALSE)
  path
}


#' Evaluates an expression under a fixed seed.
#'
#' Evaluate `expr` under a fixed RNG seed and hand the caller's stream back
#' untouched: a drift report must not move the user's downstream draws.
#' @param seed The seed, or NULL for the session's stream.
#' @param expr The expression to evaluate.
#' @return The value of `expr`.
#' @noRd
.rmbl_with_seed <- function(seed, expr) {
  # a NULL seed is no seed: the expression runs on the session's stream (set.seed(NULL) said
  # "supplied seed is not a valid integer" in seven functions; final audit of 1.0.0)
  if (is.null(seed)) return(expr)
  seed <- .rmbl_r_seed(seed)   # before the promise `expr` is forced
  had <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
  old <- if (had) get(".Random.seed", envir = globalenv(), inherits = FALSE)
  on.exit({
    if (had) assign(".Random.seed", old, envir = globalenv())
    else if (exists(".Random.seed", envir = globalenv(), inherits = FALSE))
      rm(".Random.seed", envir = globalenv())
  }, add = TRUE)
  .rmbl_set_seed(seed)
  expr
}

#' Finite, non-negative counts, or an error that names the argument.
#' @param v The counts to check.
#' @param what The argument's name, used in the error message.
#' @return `v`, invisibly.
#' @noRd
.rmbl_check_counts <- function(v, what) {
  if (any(!is.finite(v)) || any(v < 0)) {
    stop(.rmbl_fn(), sprintf("`%s` must be finite, non-negative counts", what), call. = FALSE)
  }
  invisible(v)
}

#' Checks that a plot method was given an object of its class.
#'
#' A plot method called on something its class's function did not make (plot.rmbl_crf(1)): said, not a
#' base R error from deep inside the drawing ("$ operator is invalid for atomic vectors"; 91 such
#' calls in the CRAN stress test of b617a3f)
#' @param x The object passed to the plot method.
#' @param cls The class the method expects.
#' @return `x`, invisibly.
#' @noRd
.rmbl_plot_check <- function(x, cls) {
  if (!inherits(x, cls) || !is.list(x)) {
    stop(.rmbl_fn(), sprintf("`x` must be a %s object, as returned by the function that makes one", cls), call. = FALSE)
  }
  invisible(x)
}

# The 0.5.x compatibility helpers that files sourced on their own (the otis-mrp bundle stages
# yoy.R and rate.R beside this file) call; the rest of the layer is R/compat_s3.R.

# Old allowed values renamed in 1.0.0: each element of `x` found in names(map) becomes its new
# value; a full old choice vector becomes the full new one, so the default still means "first".
.rmbl_alias_val <- function(x, map) {
  if (!is.character(x)) return(x)
  i <- match(x, names(map))
  x[!is.na(i)] <- unname(map[i[!is.na(i)]])
  x
}

# 0.5.x argument names reaching a function through `...` (yoy() kept its name, so it has no
# alias): when the call that is running used one, returns that call with the new names and the
# frame to evaluate it in, else NULL. A call naming both forms is refused.
.rmbl_old_names <- function(map) {
  env <- parent.frame(2L)
  fn <- sys.function(-1L)
  mc <- match.call(fn, sys.call(-1L), expand.dots = TRUE, envir = env)
  n <- names(mc)
  k <- n %in% names(map)
  if (!any(k)) return(NULL)
  both <- n[k][unname(map[n[k]]) %in% n]
  if (length(both)) {
    stop(.rmbl_fn(), sprintf("give `%s` or its 0.5.x name `%s`, not both", map[[both[1L]]], both[1L]),
         call. = FALSE)
  }
  names(mc)[k] <- unname(map[n[k]])
  # the function itself: an S3 method's call names the method, which the caller cannot see
  mc[[1L]] <- fn
  list(call = mc, env = env)
}

# 1.0.0 shortened the option names: a session that still sets a 0.5.x name (in .Rprofile, say)
# is read too, so an XMSS index record or a data cache it points to is not silently dropped
.rmbl_old_options <- c(allowhttp = "allow_http", dcache = "data_cache", llmcache = "llm_cache",
                       llmcachedays = "llm_cache_days", llmcachedir = "llm_cache_dir",
                       llmcachemax = "llm_cache_max", maxcsvbytes = "max_csv_bytes",
                       numcol = "num_colors", xmssidxfile = "xmss_index_file")

# getOption("rmoriebricklayer.<name>", default), falling back on the option's 0.5.x name.
.rmbl_getopt <- function(name, default = NULL) {
  v <- getOption(paste0("rmoriebricklayer.", name))
  if (is.null(v) && name %in% names(.rmbl_old_options)) {
    v <- getOption(paste0("rmoriebricklayer.", .rmbl_old_options[[name]]))
  }
  if (is.null(v)) default else v
}

# ---- 0.5.x result names --------------------------------------------------------------------
# Results keep their 1.0.0 names when a 1.0.0 function is called. Called through a 0.5.x alias
# (or yoy() with its 0.5.x argument names), the result comes back under its 0.5.x column and
# field names, from inst/compat/compat_results_map.tsv: the names of that page, then the
# unambiguous ones of every page (a 1.0.0 name no 0.5.13 result used). The object gets the class
# "rmbl_old" in front, so print(), plot(), format(), summary() and the aliases that take a
# result turn it back into the 1.0.0 form before the 1.0.0 method reads it.

.rmbl_compat_env <- new.env(parent = emptyenv())

#' The result-name maps, read once from the installed package.
#' @return A list: `topic`, named new -> old vectors by 0.5.x page; `global`, the unambiguous
#'   pairs. Empty when the map is not installed (a bundle that sources the R files).
#' @noRd
.rmbl_result_maps <- function() {
  m <- .rmbl_compat_env$maps
  if (!is.null(m)) return(m)
  p <- system.file("compat", "compat_results_map.tsv", package = "rmoriebricklayer")
  m <- list(topic = list(), global = character())
  if (nzchar(p)) {
    t <- utils::read.delim(p, stringsAsFactors = FALSE, na.strings = character())
    m$topic <- lapply(split(t, t$topic), function(d) stats::setNames(d$old, d$new))
    g <- t[t$safe == 1L, ]
    g <- g[!duplicated(g$new), ]
    m$global <- stats::setNames(g$old, g$new)
  }
  assign("maps", m, envir = .rmbl_compat_env)
  m
}

#' The new -> old map for a result of a 0.5.x page.
#' @param topic The 0.5.x page (the alias's name).
#' @param x The result: an rmbl_<page> class adds that page's names.
#' @return A named character vector, new name -> old name.
#' @noRd
.rmbl_out_map <- function(topic, x) {
  m <- .rmbl_result_maps()
  cls <- intersect(sub("^rmbl_", "", oldClass(x)), names(m$topic))
  r <- c(m$topic[[topic]], unlist(unname(m$topic[cls])), m$global)
  r[!duplicated(names(r))]
}

#' Renames, through a result, every name found in `map` (from -> to): names, column names,
#' dimnames and attribute names, in nested lists and attributes too.
#' @param x Any object.
#' @param map A named character vector, from -> to.
#' @param used An environment collecting the names renamed (`used$from`), or NULL.
#' @return `x` renamed.
#' @noRd
.rmbl_names_swap <- function(x, map, used = NULL) {
  if (!length(map) || is.function(x) || is.environment(x)) return(x)
  hit <- function(v) {
    k <- v %in% names(map)
    if (!is.null(used) && any(k)) used$from <- union(used$from, v[k])
    k
  }
  # a list is renamed bare, so a data frame's compact row names stay as they are
  cl <- if (is.list(x)) oldClass(x)
  if (is.list(x)) x <- unclass(x)
  n <- names(x)
  if (!is.null(n) && any(k <- hit(n))) names(x)[k] <- unname(map[n[k]])
  dn <- if (is.null(dim(x))) NULL else dimnames(x)
  if (is.list(dn)) {
    dimnames(x) <- lapply(dn, function(v) {
      if (!is.null(v) && any(k <- hit(v))) v[k] <- unname(map[v[k]])
      v
    })
  }
  if (is.list(x)) {
    for (i in seq_along(x)) {
      if (!is.null(x[[i]]) && (is.list(x[[i]]) || !is.null(attributes(x[[i]])))) {
        x[[i]] <- .rmbl_names_swap(x[[i]], map, used)
      }
    }
  }
  a <- attributes(x)
  for (nm in setdiff(names(a), c("names", "row.names", "class", "dim", "dimnames", "tsp", "levels",
                                 "comment", "srcref", "rmbl_names"))) {
    v <- .rmbl_names_swap(a[[nm]], map, used)
    to <- if (hit(nm)) map[[nm]] else nm
    attr(x, nm) <- NULL
    attr(x, to) <- v
  }
  if (!is.null(cl)) oldClass(x) <- cl
  x
}

#' A result under its 0.5.x names, as an alias returns it.
#' @param topic The 0.5.x page (the alias's name).
#' @param v The call's result, from withVisible().
#' @return The result renamed, visible as it was.
#' @noRd
.rmbl_alias_out <- function(topic, v) {
  x <- v$value
  map <- .rmbl_out_map(topic, x)
  if (length(map)) {
    used <- new.env(parent = emptyenv())
    x <- .rmbl_names_swap(x, map, used)
    # marked only when a name changed and the result has a class to dispatch on; the mark
    # keeps the renames made, so they are undone exactly
    if (length(used$from) && is.list(x) && !is.null(oldClass(x))) {
      class(x) <- unique(c("rmbl_old", oldClass(x)))
      attr(x, "rmbl_names") <- map[used$from]
    }
  }
  if (v$visible) x else invisible(x)
}

#' A result an alias returned, back in its 1.0.0 names; anything else as it is.
#' @param x Any object.
#' @return `x`, renamed back and unmarked when it carries the "rmbl_old" class.
#' @noRd
.rmbl_new_names <- function(x) {
  if (!inherits(x, "rmbl_old")) return(x)
  done <- attr(x, "rmbl_names")
  class(x) <- setdiff(oldClass(x), "rmbl_old")
  attr(x, "rmbl_names") <- NULL
  .rmbl_names_swap(x, stats::setNames(names(done), unname(done)))
}
