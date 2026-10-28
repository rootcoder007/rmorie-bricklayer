# Input contracts shared by the exported primitives. A numeric kernel that
# silently coerces "abc" to NA, a hash that digests the text "NA", or a
# stock-and-flow measure that accepts Inf all return a value that looks
# like an answer. The degenerate-input sweep of 2026-09-18 found 117
# exports doing one of those; these guards make every such call an error
# that names the argument.

#' The function a refusal comes from, as \dQuote{fn: }.
#'
#' A check several functions share still says which of them refused (srr G5.2a:
#' every message unique; \dQuote{`data` must be a data frame} came from 21). It
#' is the nearest frame on the stack running an exported function or an S3
#' method of the package, the method named by its generic; \code{""} when there
#' is none (an internal helper called on its own, or this file sourced
#' outside the package, as a bundle does).
#' @return A string, \dQuote{fn: } or \code{""}.
#' @noRd
.rmbl_fn <- function() {
  ns <- environment(.rmbl_fn)
  # sourced into a bundle (or any other environment) there is no namespace
  # to search: every refusal there crashed with "not a namespace" instead
  if (!isNamespace(ns)) {
    return("")
  }
  s3 <- getNamespaceInfo(ns, "S3methods")
  ex <- getNamespaceExports(ns)
  n <- sys.nframe() - 1L
  par <- sys.parents()
  for (i in rev(seq_len(n))) {
    f <- sys.function(i)
    if (!identical(environment(f), ns) || .rmbl_fnskip(f, i, n, par, ns)) {
      next
    }
    lab <- .rmbl_fnlab(.rmbl_fnname(sys.call(i)[[1L]], f, ns, ex), s3, ex)
    if (nzchar(lab)) {
      return(lab)
    }
  }
  ""
}

#' The label .rmbl_fn() gives a frame's function name: the generic of an
#' S3 method, else the export itself, else "".
#' @param nm The name, or NA.
#' @param s3 The namespace's S3 methods table.
#' @param ex Its exports.
#' @return \dQuote{fn: } or "".
#' @noRd
.rmbl_fnlab <- function(nm, s3, ex) {
  if (is.na(nm)) {
    return("")
  }
  g <- s3[which(s3[, 3L] == nm), 1L]
  if (length(g)) {
    return(paste0(g[[1L]], ": "))
  }
  if (nm %in% ex) paste0(nm, ": ") else ""
}

#' Whether .rmbl_fn() passes over a co2fp() frame.
#'
#' co2fp() evaluates the caller's expression: an error raised while that
#' expression runs (a frame further in whose parent lies outside co2fp)
#' belongs to the function that asked for the footprint, so the search goes
#' on past it; co2fp()'s own argument errors (every frame further in descends
#' from it) keep its name.
#' @param f The frame's function.
#' @param i The frame's number.
#' @param n The innermost frame searched.
#' @param par sys.parents().
#' @param ns The namespace.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_fnskip <- function(f, i, n, par, ns) {
  identical(f, get0("co2fp", ns)) && i < n && any(par[(i + 1L):n] < i)
}

#' The name a frame's function was called by, for .rmbl_fn().
#' @param h The head of the frame's call.
#' @param f The frame's function.
#' @param ns The namespace.
#' @param ex Its exports.
#' @return One string, or NA.
#' @noRd
.rmbl_fnname <- function(h, f, ns, ex) {
  if (is.call(h) && as.character(h[[1L]]) %in% c("::", ":::")) {
    h <- h[[3L]]
  }
  # do.call(fromjs, ...) calls the function itself, not its name
  if (is.name(h)) {
    return(as.character(h))
  }
  ex[vapply(ex, function(n) identical(get0(n, ns), f), NA)][1L]
}

#' Checks that an argument is numeric (or logical) and returns it as a double
#' vector.
#' @param x The argument's value, numeric or logical, or NULL.
#' @param what The argument's name, quoted when the value is not numeric.
#' @param allow_null Whether NULL is accepted (it becomes `numeric(0)`).
#' @return A double vector.
#' @noRd
.rmbl_num_input <- function(x, what, allow_null = TRUE) {
  if (is.null(x)) {
    if (allow_null) {
      return(numeric(0))
    }
    stop(
      .rmbl_fn(),
      sprintf("`%s` must be numeric, got NULL", what),
      call. = FALSE
    )
  }
  if (
    is.factor(x) ||
      is.character(x) ||
      is.list(x) ||
      is.data.frame(x) ||
      !(is.numeric(x) || is.logical(x))
  ) {
    stop(
      .rmbl_fn(),
      sprintf("`%s` must be numeric, got %s", what, class(x)[1]),
      call. = FALSE
    )
  }
  as.numeric(x)
}

#' Checks that an argument is numeric with no infinite value and returns its
#' non-missing values.
#' @param x The argument's value; NA values are dropped before the checks.
#' @param what The argument's name, quoted in the finite and count errors.
#' @param nonneg Whether negative values are refused.
#' @param min_n The least number of non-missing values accepted.
#' @return A double vector with the missing values dropped.
#' @noRd
.rmbl_finite_input <- function(x, what, nonneg = FALSE, min_n = 0L) {
  x <- .rmbl_num_input(x, what)
  x <- x[!is.na(x)]
  if (!all(is.finite(x))) {
    stop(
      .rmbl_fn(),
      sprintf("`%s` must be finite (no Inf)", what),
      call. = FALSE
    )
  }
  if (nonneg && any(x < 0)) {
    stop(.rmbl_fn(), sprintf("`%s` must be non-negative", what), call. = FALSE)
  }
  if (length(x) < min_n) {
    stop(
      .rmbl_fn(),
      sprintf(
        "`%s` needs at least %s non-missing value%s, got %d",
        what,
        if (min_n == 1L) "one" else as.character(min_n),
        if (min_n == 1L) "" else "s",
        length(x)
      ),
      call. = FALSE
    )
  }
  x
}

#' Checks that an argument is character (or raw, when allowed) and returns it
#' unchanged.
#' @param x The argument's value: character, raw, or an all-NA logical.
#' @param what The argument's name, quoted when the value is not character.
#' @param allow_raw Whether a raw vector is accepted.
#' @return `x`.
#' @noRd
.rmbl_text_input <- function(x, what, allow_raw = TRUE) {
  if (allow_raw && is.raw(x)) {
    return(x)
  }
  # a logical NA is left to the caller's own length/NA check
  if (is.logical(x) && all(is.na(x))) {
    return(x)
  }
  if (!is.character(x)) {
    stop(
      .rmbl_fn(),
      sprintf(
        "`%s` must be character%s, got %s",
        what,
        if (allow_raw) " or raw" else "",
        class(x)[1]
      ),
      call. = FALSE
    )
  }
  x
}

#' Checks a column-name argument.
#'
#' A column-name argument: text naming one column (or, with `several`, one or
#' more), none missing or empty. NULL or character(0) went on to data\[, cols\]
#' and failed there as \code{"get1index"} (statistics stress test of 5e1dce5).
#' @param x The column name or names passed by the user.
#' @param what The argument's name, quoted when it does not name a column.
#' @param several Whether more than one column may be named.
#' @return `x`.
#' @noRd
.rmbl_colnames <- function(x, what, several = FALSE) {
  ok <- is.character(x) &&
    length(x) >= 1L &&
    !anyNA(x) &&
    all(nzchar(x)) &&
    (several || length(x) == 1L)
  if (!ok) {
    stop(
      .rmbl_fn(),
      sprintf(
        "`%s` must name %s of `data`",
        what,
        if (several) "one or more columns" else "one column"
      ),
      call. = FALSE
    )
  }
  x
}

#' Marks unmarked valid UTF-8 text as UTF-8.
#'
#' Text that is valid UTF-8 but carries no encoding mark is marked UTF-8, so
#' that a group or level a user types (\code{"Metis"} with an accent) matches
#' the same bytes read from a table with `encoding = "UTF-8"` in every locale:
#' in a C locale R left the literal unmarked and `%in%` called the two different
#' (the C-locale CI cell, 1.0.0).
#' @param x A character vector; anything else is returned as it is.
#' @return `x`, with its unmarked valid UTF-8 elements marked UTF-8.
#' @noRd
.rmbl_utf8 <- function(x) {
  if (!is.character(x)) {
    return(x)
  }
  u <- !is.na(x) & Encoding(x) == "unknown" & validUTF8(x)
  if (any(u)) {
    v <- x[u]
    Encoding(v) <- "UTF-8"
    x[u] <- v
  }
  x
}

#' Checks that an argument is a single non-empty string and returns it marked
#' UTF-8.
#' @param x The argument's value, which must be one non-blank string.
#' @param what The argument's name, quoted when it is not one non-empty string.
#' @return `x`, through `.rmbl_utf8()`.
#' @noRd
.rmbl_string1 <- function(x, what) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(trimws(x))) {
    stop(
      .rmbl_fn(),
      sprintf("`%s` must be a single non-empty string", what),
      call. = FALSE
    )
  }
  .rmbl_utf8(x)
}

#' Matches an argument against its accepted values.
#'
#' .rmbl_arg() in the package's words: `what` must be one of the choices, and
#' what was given is named (match.arg's \dQuote{'arg' should be one of} names
#' neither; review of 29a55d8, hostile battery). Without `choices` they are the
#' argument's default in the calling function, as .rmbl_arg() finds them.
#' @param arg The value passed by the user; NULL or the full default vector
#'   picks the first choice.
#' @param choices The accepted values; NULL (the default) reads them from the
#'   calling function's default.
#' @param several Whether more than one choice may be given.
#' @return The matched choice or choices.
#' @noRd
.rmbl_arg <- function(arg, choices = NULL, several = FALSE) {
  what <- deparse1(substitute(arg), collapse = "")
  if (is.null(choices)) {
    sysp <- sys.parent()
    fn <- sys.function(sysp)
    choices <- eval(formals(fn)[[what]], envir = sys.frame(sysp))
  }
  if (is.null(arg)) {
    return(choices[[1L]])
  }
  if (!several && identical(arg, choices)) {
    return(choices[[1L]])
  }
  shown <- toString(dQuote(choices, FALSE))
  given <- .rmbl_printable(paste(utils::head(deparse(arg), 1L), collapse = ""))
  if (
    !is.character(arg) ||
      !length(arg) ||
      anyNA(arg) ||
      (!several && length(arg) != 1L)
  ) {
    stop(
      .rmbl_fn(),
      sprintf(
        "`%s` must be %s %s, not %s",
        what,
        if (several) "one or more of" else "one of",
        shown,
        given
      ),
      call. = FALSE
    )
  }
  i <- pmatch(arg, choices, nomatch = 0L, duplicates.ok = several)
  if (any(i == 0L)) {
    stop(
      .rmbl_fn(),
      sprintf(
        "`%s` must be %s %s, not %s",
        what,
        if (several) "one or more of" else "one of",
        shown,
        given
      ),
      call. = FALSE
    )
  }
  unique(choices[i])
}

#' Checks that a data frame has unique, non-empty column names.
#'
#' A data frame's columns must be named, every name non-empty and no name twice:
#' a frame built by hand with NULL or \code{""} names is refused in words, not
#' with a subscript error later (review of 29a55d8, hostile battery).
#' @param data The data frame whose column names are checked.
#' @param what The data frame's argument name (default `data`), for errors.
#' @return `TRUE`, invisibly.
#' @noRd
.rmbl_df_names <- function(data, what = "data") {
  if (!is.data.frame(data)) {
    stop(
      .rmbl_fn(),
      sprintf(
        "`%s` must be a data frame, not %s",
        what,
        if (is.null(data)) "NULL" else class(data)[[1L]]
      ),
      call. = FALSE
    )
  }
  nm <- names(data)
  if (length(data) && (is.null(nm) || anyNA(nm) || !all(nzchar(nm)))) {
    stop(
      .rmbl_fn(),
      sprintf(
        "every column of `%s` must have a name (names(%s) has an empty one)",
        what,
        what
      ),
      call. = FALSE
    )
  }
  if (anyDuplicated(nm)) {
    stop(
      .rmbl_fn(),
      sprintf(
        "`%s` has two columns named %s: rename one",
        what,
        nm[duplicated(nm)][[1L]]
      ),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

#' Checks a seed for a native generator.
#'
#' A seed for a native generator: one whole number in [0, 2^53). The core casts
#' it to an unsigned 64-bit integer, and a NA, negative or fractional double
#' cast that way is undefined behaviour.
#' @param seed The seed to check: a whole number in [0, 2^53).
#' @param what The argument's name, quoted when the seed is out of range.
#' @return The seed as a double.
#' @noRd
.rmbl_seed <- function(seed, what = "seed") {
  seed <- .rmbl_num(seed, what)
  if (
    length(seed) != 1L ||
      is.na(seed) ||
      seed < 0 ||
      seed != floor(seed) ||
      seed >= 2^53
  ) {
    stop(
      .rmbl_fn(),
      sprintf("`%s` must be a whole number in [0, 2^53)", what),
      call. = FALSE
    )
  }
  seed
}

#' A confidence level: one number strictly inside (0, 1); outside it the
#' interval quantiles are NaN
#' @param x The confidence level to check, strictly between 0 and 1.
#' @param what The argument's name (default `conflvl`), quoted in the error.
#' @return The level as a double.
#' @noRd
.rmbl_conf_level <- function(x, what = "conflvl") {
  x <- .rmbl_num(x, what)
  if (length(x) != 1L || is.na(x) || x <= 0 || x >= 1) {
    stop(
      .rmbl_fn(),
      sprintf("`%s` must be a single number strictly between 0 and 1", what),
      call. = FALSE
    )
  }
  x
}

#' .rmbl_num()'s refusals before any conversion: a value that is no number,
#' and a date where a count is wanted.
#' @param x,what,integer As for .rmbl_num().
#' @noRd
.rmbl_num_kind <- function(x, what, integer) {
  # a list, a data frame, a factor, a complex number or a function is no number:
  # as.numeric() refused them in its own words ("'list' object cannot be coerced
  # to type 'double'") or read a factor's codes (re-test of the b617a3f CRAN
  # stress fixes, hostile battery)
  if (
    !is.null(x) && (!is.atomic(x) || is.factor(x) || is.complex(x) || is.raw(x))
  ) {
    stop(
      .rmbl_fn(),
      sprintf(
        "`%s` must be a%s number, not %s",
        what,
        if (integer) " whole" else "",
        if (is.data.frame(x)) {
          "a data frame"
        } else if (is.factor(x)) {
          "a factor"
        } else if (is.function(x)) {
          "a function"
        } else {
          class(x)[[1L]]
        }
      ),
      call. = FALSE
    )
  }
  # a date is a number of days, never a count: reps = Sys.Date() ran 20,000
  # replications (CRAN stress test of 0.5.14). A period (the x of a trend) may
  # be a date, so only counts refuse it.
  if (integer && inherits(x, c("Date", "POSIXt", "difftime"))) {
    stop(
      .rmbl_fn(),
      sprintf("`%s` must be a whole number, not a %s", what, class(x)[[1L]]),
      call. = FALSE
    )
  }
  invisible(NULL)
}

#' A number as a whole number: no fraction, no infinity, within the integer
#' range.
#' @param x The number.
#' @param what Its argument's name.
#' @return The integer.
#' @noRd
.rmbl_num_whole <- function(x, what) {
  # a whole number: as.integer() would read 2.5 as 2 and pick another setting
  # silently, and turn Inf or 1e10 into NA with a coercion warning
  x <- as.numeric(x)
  frac <- (is.finite(x) & x != floor(x)) | is.infinite(x)
  if (any(frac)) {
    stop(
      .rmbl_fn(),
      sprintf("`%s` must be a whole number, not %s", what, format(x[frac][1L])),
      call. = FALSE
    )
  }
  big <- !is.na(x) & abs(x) > .Machine$integer.max
  if (any(big)) {
    stop(
      .rmbl_fn(),
      sprintf(
        "`%s` is too large: %s (the limit is 2147483647)",
        what,
        format(x[big][1L])
      ),
      call. = FALSE
    )
  }
  as.integer(x)
}

#' Checks that an argument is a number (a whole one with `integer`) and converts
#' it.
#'
#' A numeric argument: text that is not a number is refused in words
#' (as.numeric() turned it into NA with \dQuote{NAs introduced by coercion} and
#' the function failed further on); every other type converts exactly as
#' as.numeric() / as.integer() always did.
#' @param x The value to convert: numeric, logical NA, or numeric text.
#' @param what The argument's name, quoted when the value is not a number.
#' @param integer Whether the value must be a whole number, returned as an
#'   integer.
#' @return A double vector, or an integer vector with `integer = TRUE`.
#' @noRd
.rmbl_num <- function(x, what, integer = FALSE) {
  .rmbl_num_kind(x, what, integer)
  if (is.character(x)) {
    v <- suppressWarnings(as.numeric(x))
    bad <- !is.na(x) & is.na(v) & nzchar(trimws(x)) & x != "NA"
    if (any(bad)) {
      stop(
        .rmbl_fn(),
        sprintf(
          "`%s` must be numeric, not text such as \"%s\"",
          what,
          x[bad][1L]
        ),
        call. = FALSE
      )
    }
    x <- v
  }
  # a number, not a flag: as.numeric(TRUE) is 1 (maxprs = TRUE was read as one
  # pair)
  if (is.logical(x) && !all(is.na(x))) {
    stop(
      .rmbl_fn(),
      sprintf(
        "`%s` must be a%s number, not %s",
        what,
        if (integer) " whole" else "",
        format(x[!is.na(x)][1L])
      ),
      call. = FALSE
    )
  }
  if (!integer) {
    return(as.numeric(x))
  }
  .rmbl_num_whole(x, what)
}

#' Checks where a function writes its output.
#'
#' Where a function writes: a connection, or one non-empty path to a file in a
#' folder that exists (a number or NA reached file() and writeLines() and
#' failed in their words: \dQuote{'con' is not a connection}, \dQuote{invalid
#' 'description' argument}; a folder, \dQuote{cannot open the connection})
#' @param file The connection or path passed by the user.
#' @param what The argument's name (default `file`), quoted in the path error.
#' @param connection Whether a connection or NULL is accepted.
#' @return `file`.
#' @noRd
.rmbl_out_file <- function(file, what = "file", connection = TRUE) {
  # NULL: the writer returns the text instead
  if (connection && (is.null(file) || inherits(file, "connection"))) {
    return(file)
  }
  file <- .rmbl_string1(file, what)
  # a folder, or a file in a folder that is not there, reached file() and
  # failed as "cannot open the connection"
  if (dir.exists(file)) {
    stop(.rmbl_fn(),
         sprintf("`%s` is a folder; give a file in it: %s", what, file),
         call. = FALSE)
  }
  if (!dir.exists(dirname(path.expand(file)))) {
    stop(.rmbl_fn(),
         sprintf("the folder for `%s` does not exist: %s", what,
                 dirname(file)),
         call. = FALSE)
  }
  file
}

#' TRUE or FALSE, said in words when it is neither (`if (quiet)` failed on NA, a
#' vector or a frame)
#' @param x The flag to check: one TRUE or FALSE.
#' @param what The argument's name, quoted when the flag is NA or not logical.
#' @return `x`.
#' @noRd
.rmbl_flag1 <- function(x, what) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    stop(.rmbl_fn(), sprintf("`%s` must be TRUE or FALSE", what), call. = FALSE)
  }
  x
}

#' One string, empty allowed (a title, an NA marker)
#' @param x The string to check; an empty string is accepted.
#' @param what The argument's name, quoted when it is not a single string.
#' @return `x`.
#' @noRd
.rmbl_text1 <- function(x, what) {
  if (!is.character(x) || length(x) != 1L || is.na(x)) {
    stop(
      .rmbl_fn(),
      sprintf("`%s` must be a single string", what),
      call. = FALSE
    )
  }
  x
}

#' Checks a scalar numeric argument against a range.
#'
#' One number (a whole one with `integer`), finite, in \[min, max\]: the checks
#' a scalar argument needs, said in words. A list, a data frame, text that is no
#' number, NA, a vector are each refused here, not by the base R call they
#' reached (`if (n < mintl)`: \dQuote{missing value where TRUE/FALSE needed};
#' CRAN stress test of 0.5.14)
#' @param x The scalar to check against `min` and `max`.
#' @param what The argument's name, quoted with the accepted range.
#' @param min The smallest value accepted (default `-Inf`, no lower bound).
#' @param max The largest value accepted.
#' @param integer Whether the value must be a whole number.
#' @return The value as a double, or an integer with `integer = TRUE`.
#' @noRd
.rmbl_scalar <- function(x, what, min = -Inf, max = Inf, integer = FALSE) {
  v <- .rmbl_num(x, what, integer = integer)
  if (length(v) != 1L || is.na(v) || !is.finite(v) || v < min || v > max) {
    rng <- if (is.finite(min) && is.finite(max)) {
      sprintf(" from %s to %s", format(min), format(max))
    } else if (is.finite(min)) {
      sprintf(" of at least %s", format(min))
    } else if (is.finite(max)) {
      sprintf(" of at most %s", format(max))
    } else {
      ""
    }
    stop(
      .rmbl_fn(),
      sprintf(
        "`%s` must be one %s%s",
        what,
        if (integer) "whole number" else "number",
        rng
      ),
      call. = FALSE
    )
  }
  v
}

#' Makes an error handler that returns a default but lets time limits through.
#'
#' An error handler for a user's function called in a loop (a statistic, an
#' injection): the error becomes `default`, except R's own time limits, which
#' must end the call. Caught, they were each an NA, and setTimeLimit() could
#' never stop cpspwr() or cpsfals() (CRAN stress test of 0.5.14).
#' @param default The value an ordinary error becomes.
#' @return A handler function for `tryCatch(error = )`.
#' @noRd
.rmbl_or <- function(default) {
  force(default)
  function(e) {
    m <- conditionMessage(e)
    lim <- c(
      "reached elapsed time limit",
      "reached CPU time limit",
      gettext("reached elapsed time limit", domain = "R"),
      gettext("reached CPU time limit", domain = "R")
    )
    if (any(startsWith(m, lim))) {
      stop(e)
    }
    default
  }
}

#' Refuses a function or an environment passed where data goes.
#'
#' A function where data goes: said in words, before as.character(), match() or
#' `[` refuse it in theirs (\dQuote{cannot coerce type 'closure' to vector of
#' type 'character'}; 64 such arguments in the re-test of the b617a3f CRAN
#' stress fixes). Called with the arguments named: .rmbl_no_fn(x = x)
#' @param ... The arguments to check, each named.
#' @return `TRUE`, invisibly.
#' @noRd
.rmbl_no_fn <- function(...) {
  a <- list(...)
  for (nm in names(a)) {
    if (is.function(a[[nm]])) {
      stop(
        .rmbl_fn(),
        sprintf("`%s` must be data, not a function", nm),
        call. = FALSE
      )
    }
    # an environment too: as.character() refuses it in its own words (CRAN
    # stress test of 0.5.14)
    if (is.environment(a[[nm]])) {
      stop(
        .rmbl_fn(),
        sprintf("`%s` must be data, not an environment", nm),
        call. = FALSE
      )
    }
  }
  invisible(TRUE)
}

#' A file the function reads: one path that exists and is a file (not a
#' directory)
#' @param path The path passed by the user.
#' @param what The argument's name (`path`), quoted if the file is missing.
#' @return The path.
#' @noRd
.rmbl_file1 <- function(path, what = "path") {
  path <- .rmbl_string1(path, what)
  if (!file.exists(path)) {
    stop(
      .rmbl_fn(),
      sprintf("`%s`: no such file: %s", what, path),
      call. = FALSE
    )
  }
  if (dir.exists(path)) {
    stop(
      .rmbl_fn(),
      sprintf("`%s` is a directory, not a file: %s", what, path),
      call. = FALSE
    )
  }
  path
}


#' Evaluates an expression under a fixed seed.
#'
#' Evaluate `expr` under a fixed RNG seed and hand the caller's stream back
#' untouched: a drift report must not move the user's downstream draws.
#' @param seed The seed set before `expr` is forced; NULL keeps the stream.
#' @param expr The expression forced under the seed; the old state is restored.
#' @return The value of `expr`.
#' @noRd
.rmbl_with_seed <- function(seed, expr) {
  # a NULL seed is no seed: the expression runs on the session's stream
  # (set.seed(NULL) said "supplied seed is not a valid integer" in seven
  # functions; final audit of 1.0.0)
  if (is.null(seed)) {
    return(expr)
  }
  seed <- .rmbl_r_seed(seed) # before the promise `expr` is forced
  had <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
  old <- if (had) get(".Random.seed", envir = globalenv(), inherits = FALSE)
  restore <- function() {
    if (had) {
      assign(".Random.seed", old, envir = globalenv())
    } else if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
      rm(".Random.seed", envir = globalenv())
    }
  }
  on.exit(restore(), add = TRUE)
  .rmbl_set_seed(seed)
  expr
}

#' Finite, non-negative counts, or an error that names the argument.
#' @param v The counts to check.
#' @param what The argument's name, quoted if a count is negative or infinite.
#' @return `v`, invisibly.
#' @noRd
.rmbl_check_counts <- function(v, what) {
  if (!all(is.finite(v)) || any(v < 0)) {
    stop(
      .rmbl_fn(),
      sprintf("`%s` must be finite, non-negative counts", what),
      call. = FALSE
    )
  }
  invisible(v)
}

#' Checks that a plot method was given an object of its class.
#'
#' A plot method called on something its class's function did not make
#' (plot.rmbl_crf(1)): said, not a base R error from deep inside the drawing
#' (\dQuote{$ operator is invalid for atomic vectors}; 91 such calls in the CRAN
#' stress test of b617a3f)
#' @param x The object passed to the plot method.
#' @param cls The class the method expects.
#' @return `x`, invisibly.
#' @noRd
.rmbl_plot_check <- function(x, cls) {
  if (!inherits(x, cls) || !is.list(x)) {
    stop(
      .rmbl_fn(),
      sprintf(
        "`x` must be a %s object, as returned by the function that makes one",
        cls
      ),
      call. = FALSE
    )
  }
  invisible(x)
}

# The 0.5.x compatibility helpers that files sourced on their own (the otis-mrp
# bundle stages yoy.R and rate.R beside this file) call; the rest of the layer
# is R/compat_s3.R.

# Old allowed values renamed in 1.0.0: each element of `x` found in names(map)
# becomes its new value; a full old choice vector becomes the full new one, so
# the default still means "first".
.rmbl_alias_val <- function(x, map) {
  if (!is.character(x)) {
    return(x)
  }
  i <- match(x, names(map))
  x[!is.na(i)] <- unname(map[i[!is.na(i)]])
  x
}

# 0.5.x argument names reaching a function through `...` (yoy() kept its name,
# so it has no alias): when the call that is running used one, returns that call
# with the new names and the frame to evaluate it in, else NULL. A call naming
# both forms is refused.
.rmbl_old_names <- function(map) {
  env <- parent.frame(2L)
  fn <- sys.function(-1L)
  mc <- match.call(fn, sys.call(-1L), expand.dots = TRUE, envir = env)
  n <- names(mc)
  k <- n %in% names(map)
  if (!any(k)) {
    return(NULL)
  }
  both <- n[k][unname(map[n[k]]) %in% n]
  if (length(both)) {
    stop(
      .rmbl_fn(),
      sprintf(
        "give `%s` or its 0.5.x name `%s`, not both",
        map[[both[1L]]],
        both[1L]
      ),
      call. = FALSE
    )
  }
  names(mc)[k] <- unname(map[n[k]])
  # the function itself: an S3 method's call names the method, which the caller
  # cannot see
  mc[[1L]] <- fn
  list(call = mc, env = env)
}

# 1.0.0 shortened the option names: a session that still sets a 0.5.x name (in
# .Rprofile, say) is read too, so an XMSS index record or a data cache it points
# to is not silently dropped
.rmbl_old_options <- c(
  allowhttp = "allow_http",
  dcache = "data_cache",
  llmcache = "llm_cache",
  llmcachedays = "llm_cache_days",
  llmcachedir = "llm_cache_dir",
  llmcachemax = "llm_cache_max",
  maxcsvbytes = "max_csv_bytes",
  numcol = "num_colors",
  xmssidxfile = "xmss_index_file"
)

# getOption("rmoriebricklayer.<name>", default), falling back on the option's
# 0.5.x name.
.rmbl_getopt <- function(name, default = NULL) {
  v <- getOption(paste0("rmoriebricklayer.", name))
  if (is.null(v) && name %in% names(.rmbl_old_options)) {
    v <- getOption(paste0("rmoriebricklayer.", .rmbl_old_options[[name]]))
  }
  if (is.null(v)) default else v
}

# .rmbl_getopt(), with the value checked: an option set by hand to something the
# package cannot use is refused where it is read, by name, instead of failing
# later with an error about something else.
.rmbl_getopt_ok <- function(name, default, ok, want) {
  v <- .rmbl_getopt(name, default)
  if (!is.null(v) && !isTRUE(ok(v))) {
    stop("option rmoriebricklayer.", name, " must be ", want, call. = FALSE)
  }
  v
}

.rmbl_is_num1 <- function(v, min = 0) {
  is.numeric(v) && length(v) == 1L && !is.na(v) && v >= min
}

.rmbl_is_str1 <- function(v) {
  is.character(v) && length(v) == 1L && !is.na(v) && nzchar(v)
}

# ---- 0.5.x result names ------------------------------------------------------
# Results keep their 1.0.0 names when a 1.0.0 function is called. Called through
# a 0.5.x alias (or yoy() with its 0.5.x argument names), the result comes back
# under its 0.5.x column and field names, from
# inst/compat/compat_results_map.tsv: the names of that page, then the
# unambiguous ones of every page (a 1.0.0 name no 0.5.13 result used). The
# object gets the class "rmbl_old" in front, so print(), plot(), format(),
# summary() and the aliases that take a result turn it back into the 1.0.0 form
# before the 1.0.0 method reads it.

.rmbl_compat_env <- new.env(parent = emptyenv())

#' The result-name maps, read once from the installed package.
#' @return A list: `topic`, named new -> old vectors by 0.5.x page; `global`,
#'   the unambiguous pairs. Empty when the map is not installed (a bundle that
#'   sources the R files).
#' @noRd
.rmbl_result_maps <- function() {
  m <- .rmbl_compat_env$maps
  if (!is.null(m)) {
    return(m)
  }
  p <- system.file(
    "compat",
    "compat_results_map.tsv",
    package = "rmoriebricklayer"
  )
  m <- list(topic = list(), global = character())
  if (nzchar(p)) {
    t <- utils::read.delim(
      p,
      stringsAsFactors = FALSE,
      na.strings = character()
    )
    m$topic <- lapply(split(t, t$topic), function(d) {
      stats::setNames(d$old, d$new)
    })
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

#' Which of some names the map renames, recorded in `used`.
#' @param v The names.
#' @param map,used As for .rmbl_names_swap().
#' @return A logical vector.
#' @noRd
.rmbl_names_hit <- function(v, map, used) {
  k <- v %in% names(map)
  if (!is.null(used) && any(k)) {
    used$from <- union(used$from, v[k])
  }
  k
}

#' An object's own attributes renamed, and their values swapped through.
#' @param x The object whose attributes (not names or class) are renamed.
#' @param map,used As for .rmbl_names_swap().
#' @return The object.
#' @noRd
.rmbl_names_swap_attrs <- function(x, map, used) {
  a <- attributes(x)
  for (nm in setdiff(
    names(a),
    c(
      "names",
      "row.names",
      "class",
      "dim",
      "dimnames",
      "tsp",
      "levels",
      "comment",
      "srcref",
      "rmbl_names"
    )
  )) {
    v <- .rmbl_names_swap(a[[nm]], map, used)
    to <- if (.rmbl_names_hit(nm, map, used)) map[[nm]] else nm
    attr(x, nm) <- NULL
    attr(x, to) <- v
  }
  x
}

#' An array's dimnames renamed through the map.
#' @param x The object whose dimnames, if it has any, are renamed.
#' @param map,used As for .rmbl_names_swap().
#' @return The object.
#' @noRd
.rmbl_names_swap_dimnames <- function(x, map, used) {
  dn <- if (is.null(dim(x))) NULL else dimnames(x)
  if (is.list(dn)) {
    dimnames(x) <- lapply(dn, function(v) {
      k <- if (!is.null(v)) .rmbl_names_hit(v, map, used)
      if (!is.null(v) && any(k)) {
        v[k] <- unname(map[v[k]])
      }
      v
    })
  }
  x
}

#' Renames, through a result, every name found in `map` (from -> to): names,
#' column names, dimnames and attribute names, in nested lists and attributes
#' too.
#' @param x Any object.
#' @param map A named character vector, from -> to.
#' @param used An environment collecting the names renamed (`used$from`), or
#'   NULL.
#' @return `x` renamed.
#' @noRd
.rmbl_names_swap <- function(x, map, used = NULL) {
  if (!length(map) || is.function(x) || is.environment(x)) {
    return(x)
  }
  hit <- function(v) .rmbl_names_hit(v, map, used)
  # a list is renamed bare, so a data frame's compact row names stay as they are
  cl <- if (is.list(x)) oldClass(x)
  if (is.list(x)) {
    x <- unclass(x)
  }
  n <- names(x)
  k <- if (!is.null(n)) hit(n)
  if (!is.null(n) && any(k)) {
    names(x)[k] <- unname(map[n[k]])
  }
  x <- .rmbl_names_swap_dimnames(x, map, used)
  if (is.list(x)) {
    for (i in seq_along(x)) {
      if (
        !is.null(x[[i]]) && (is.list(x[[i]]) || !is.null(attributes(x[[i]])))
      ) {
        x[[i]] <- .rmbl_names_swap(x[[i]], map, used)
      }
    }
  }
  x <- .rmbl_names_swap_attrs(x, map, used)
  if (!is.null(cl)) {
    oldClass(x) <- cl
  }
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
    # marked only when a name changed and the result has a class to dispatch on;
    # the mark keeps the renames made, so they are undone exactly
    if (length(used$from) && is.list(x) && !is.null(oldClass(x))) {
      class(x) <- unique(c("rmbl_old", oldClass(x)))
      attr(x, "rmbl_names") <- map[used$from]
    }
  }
  if (v$visible) x else invisible(x)
}

#' A result an alias returned, back in its 1.0.0 names; anything else as it is.
#' @param x Any object.
#' @return `x`, renamed back and unmarked when it carries the \code{"rmbl_old"}
#'   class.
#' @noRd
.rmbl_new_names <- function(x) {
  if (!inherits(x, "rmbl_old")) {
    return(x)
  }
  done <- attr(x, "rmbl_names")
  class(x) <- setdiff(oldClass(x), "rmbl_old")
  attr(x, "rmbl_names") <- NULL
  .rmbl_names_swap(x, stats::setNames(names(done), unname(done)))
}

# `%||%` (the right side when the left is NULL) is in base R from 4.4.0. It is
# defined here only for older R, in this file because it comes first both in the
# package and wherever lib_*.R files are sourced on their own (a capsule bundle,
# inst/scripts/setup_and_run.R).
if (!exists("%||%", envir = baseenv(), inherits = FALSE)) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

#' Refuses the arguments an S3 method's `...` would otherwise swallow.
#'
#' A misspelt or unsupported argument (`prdrd =`, or `prdord =` before it
#' was one) vanished into `...` and the call went on without it. The
#' arguments are not evaluated, so a bare column name is reported, not run.
#' @param fn The function's name, for the message.
#' @param ... The method's `...`.
#' @return NULL, invisibly; an error naming them otherwise.
#' @noRd
.rmbl_no_dots <- function(fn, ...) {
  n <- ...length()
  if (!n) {
    return(invisible(NULL))
  }
  nm <- ...names() %||% rep("", n)
  nm[is.na(nm)] <- ""
  stop(
    sprintf("%s: unused argument%s: %s", fn, if (n > 1L) "s" else "",
            toString(ifelse(nzchar(nm), nm, "(unnamed)"))),
    call. = FALSE
  )
}

#' Whether any of the conditions holds, each evaluated only when those before
#' it did not: `a || b || c` for long checks, where a later condition may
#' need an earlier one to be FALSE (a type, then a range). A condition that
#' is not TRUE (FALSE, NA, length 0) counts as not holding.
#' @param ... The conditions.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_anyof <- function(...) {
  for (i in seq_len(...length())) {
    if (isTRUE(...elt(i))) {
      return(TRUE)
    }
  }
  FALSE
}

#' Whether labels fail as names: NA, blank once spaces are trimmed, or two
#' that differ only in spaces ("A", "A ").
#' @param x The labels.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_badnames <- function(x) {
  t <- trimws(x)
  anyNA(x) || !all(nzchar(t)) || anyDuplicated(t) > 0L
}
