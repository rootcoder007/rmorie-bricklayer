# Input contracts shared by the exported primitives. A numeric kernel that
# silently coerces "abc" to NA, a hash that digests the text "NA", or a
# stock-and-flow measure that accepts Inf all return a value that looks
# like an answer. The degenerate-input sweep of 2026-09-18 found 117
# exports doing one of those; these guards make every such call an error
# that names the argument.

.rmbl_num_input <- function(x, what, allow_null = TRUE) {
  if (is.null(x)) {
    if (allow_null) return(numeric(0))
    stop(sprintf("`%s` must be numeric, got NULL", what), call. = FALSE)
  }
  if (is.factor(x) || is.character(x) || is.list(x) || is.data.frame(x) ||
        !(is.numeric(x) || is.logical(x))) {
    stop(sprintf("`%s` must be numeric, got %s", what, class(x)[1]),
      call. = FALSE
    )
  }
  as.numeric(x)
}

.rmbl_finite_input <- function(x, what, nonneg = FALSE, min_n = 0L) {
  x <- .rmbl_num_input(x, what)
  x <- x[!is.na(x)]
  if (any(!is.finite(x))) {
    stop(sprintf("`%s` must be finite (no Inf)", what), call. = FALSE)
  }
  if (nonneg && any(x < 0)) {
    stop(sprintf("`%s` must be non-negative", what), call. = FALSE)
  }
  if (length(x) < min_n) {
    stop(sprintf("`%s` needs at least %s non-missing value%s, got %d", what,
                 if (min_n == 1L) "one" else as.character(min_n),
                 if (min_n == 1L) "" else "s", length(x)), call. = FALSE)
  }
  x
}

.rmbl_text_input <- function(x, what, allow_raw = TRUE) {
  if (allow_raw && is.raw(x)) return(x)
  # a logical NA is left to the caller's own length/NA check
  if (is.logical(x) && all(is.na(x))) return(x)
  if (!is.character(x)) {
    stop(sprintf("`%s` must be character%s, got %s", what,
                 if (allow_raw) " or raw" else "", class(x)[1]),
      call. = FALSE
    )
  }
  x
}

# A column-name argument: text naming one column (or, with `several`, one or more), none missing or
# empty. NULL or character(0) went on to data[, cols] and failed there as "get1index" (statistics
# stress test of 5e1dce5).
.rmbl_colnames <- function(x, what, several = FALSE) {
  ok <- is.character(x) && length(x) >= 1L && !anyNA(x) && all(nzchar(x)) && (several || length(x) == 1L)
  if (!ok) {
    stop(sprintf("`%s` must name %s of `data`", what, if (several) "one or more columns" else "one column"),
         call. = FALSE)
  }
  x
}

# Text that is valid UTF-8 but carries no encoding mark is marked UTF-8, so that a group or level
# a user types ("Metis" with an accent) matches the same bytes read from a table with
# `encoding = "UTF-8"` in every locale: in a C locale R left the literal unmarked and
# `%in%` called the two different (the C-locale CI cell, 1.0.0).
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

.rmbl_string1 <- function(x, what) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(trimws(x))) {
    stop(sprintf("`%s` must be a single non-empty string", what),
      call. = FALSE
    )
  }
  .rmbl_utf8(x)
}

# A numeric argument: text that is not a number is refused in words (as.numeric() turned it into NA
# with "NAs introduced by coercion" and the function failed further on); every other type converts
# exactly as as.numeric() / as.integer() always did.
# .rmbl_arg() in the package's words: `what` must be one of the choices, and what was given is named
# (match.arg's "'arg' should be one of" names neither; review of 29a55d8, hostile battery). Without
# `choices` they are the argument's default in the calling function, as .rmbl_arg() finds them.
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
    stop(sprintf("`%s` must be %s %s, not %s", what, if (several) "one or more of" else "one of", shown, given),
         call. = FALSE)
  }
  i <- pmatch(arg, choices, nomatch = 0L, duplicates.ok = several)
  if (any(i == 0L)) {
    stop(sprintf("`%s` must be %s %s, not %s", what, if (several) "one or more of" else "one of", shown, given),
         call. = FALSE)
  }
  unique(choices[i])
}

# A data frame's columns must be named, every name non-empty and no name twice: a frame built by
# hand with NULL or "" names is refused in words, not with a subscript error later (review of
# 29a55d8, hostile battery).
.rmbl_df_names <- function(data, what = "data") {
  if (!is.data.frame(data)) {
    stop(sprintf("`%s` must be a data frame, not %s", what, if (is.null(data)) "NULL" else class(data)[[1L]]),
         call. = FALSE)
  }
  nm <- names(data)
  if (length(data) && (is.null(nm) || anyNA(nm) || any(!nzchar(nm)))) {
    stop(sprintf("every column of `%s` must have a name (names(%s) has an empty one)", what, what), call. = FALSE)
  }
  if (anyDuplicated(nm)) {
    stop(sprintf("`%s` has two columns named %s: rename one", what, nm[duplicated(nm)][[1L]]), call. = FALSE)
  }
  invisible(TRUE)
}

# a seed for a native generator: one whole number in [0, 2^53). The core casts it to an unsigned
# 64-bit integer, and a NA, negative or fractional double cast that way is undefined behaviour.
.rmbl_seed <- function(seed, what = "seed") {
  seed <- .rmbl_num(seed, what)
  if (length(seed) != 1L || is.na(seed) || seed < 0 || seed != floor(seed) || seed >= 2^53) {
    stop(sprintf("`%s` must be a whole number in [0, 2^53)", what), call. = FALSE)
  }
  seed
}

# a confidence level: one number strictly inside (0, 1); outside it the interval quantiles are NaN
.rmbl_conf_level <- function(x, what = "conflvl") {
  x <- .rmbl_num(x, what)
  if (length(x) != 1L || is.na(x) || x <= 0 || x >= 1) {
    stop(sprintf("`%s` must be a single number strictly between 0 and 1", what), call. = FALSE)
  }
  x
}

.rmbl_num <- function(x, what, integer = FALSE) {
  # a list, a data frame, a factor, a complex number or a function is no number: as.numeric() refused
  # them in its own words ("'list' object cannot be coerced to type 'double'") or read a factor's codes
  # (re-test of the b617a3f CRAN stress fixes, hostile battery)
  if (!is.null(x) && (!is.atomic(x) || is.factor(x) || is.complex(x) || is.raw(x))) {
    stop(sprintf("`%s` must be a%s number, not %s", what, if (integer) " whole" else "",
                 if (is.data.frame(x)) "a data frame" else if (is.factor(x)) "a factor" else
                   if (is.function(x)) "a function" else class(x)[[1L]]), call. = FALSE)
  }
  # a date is a number of days, never a count: reps = Sys.Date() ran 20,000 replications (CRAN stress
  # test of 0.5.14). A period (the x of a trend) may be a date, so only counts refuse it.
  if (integer && inherits(x, c("Date", "POSIXt", "difftime"))) {
    stop(sprintf("`%s` must be a whole number, not a %s", what, class(x)[[1L]]), call. = FALSE)
  }
  if (is.character(x)) {
    v <- suppressWarnings(as.numeric(x))
    bad <- !is.na(x) & is.na(v) & nzchar(trimws(x)) & x != "NA"
    if (any(bad)) {
      stop(sprintf("`%s` must be numeric, not text such as \"%s\"", what, x[bad][1L]), call. = FALSE)
    }
    x <- v
  }
  # a number, not a flag: as.numeric(TRUE) is 1 (maxprs = TRUE was read as one pair)
  if (is.logical(x) && any(!is.na(x))) {
    stop(sprintf("`%s` must be a%s number, not %s", what, if (integer) " whole" else "", format(x[!is.na(x)][1L])),
         call. = FALSE)
  }
  if (!integer) return(as.numeric(x))
  # a whole number: as.integer() would read 2.5 as 2 and pick another setting silently, and
  # turn Inf or 1e10 into NA with a coercion warning
  x <- as.numeric(x)
  frac <- (is.finite(x) & x != floor(x)) | is.infinite(x)
  if (any(frac)) stop(sprintf("`%s` must be a whole number, not %s", what, format(x[frac][1L])), call. = FALSE)
  big <- !is.na(x) & abs(x) > .Machine$integer.max
  if (any(big)) {
    stop(sprintf("`%s` is too large: %s (the limit is 2147483647)", what, format(x[big][1L])), call. = FALSE)
  }
  as.integer(x)
}

# Where a function writes: a connection, or one non-empty path (a number or NA reached file() and
# writeLines() and failed in their words: "'con' is not a connection", "invalid 'description' argument")
.rmbl_out_file <- function(file, what = "file", connection = TRUE) {
  # NULL: the writer returns the text instead
  if (connection && (is.null(file) || inherits(file, "connection"))) return(file)
  .rmbl_string1(file, what)
}

# TRUE or FALSE, said in words when it is neither (`if (quiet)` failed on NA, a vector or a frame)
.rmbl_flag1 <- function(x, what) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    stop(sprintf("`%s` must be TRUE or FALSE", what), call. = FALSE)
  }
  x
}

# one string, empty allowed (a title, an NA marker)
.rmbl_text1 <- function(x, what) {
  if (!is.character(x) || length(x) != 1L || is.na(x)) {
    stop(sprintf("`%s` must be a single string", what), call. = FALSE)
  }
  x
}

# One number (a whole one with `integer`), finite, in [min, max]: the checks a scalar argument needs,
# said in words. A list, a data frame, text that is no number, NA, a vector are each refused here, not
# by the base R call they reached (`if (n < mintl)`: "missing value where TRUE/FALSE needed"; CRAN
# stress test of 0.5.14)
.rmbl_scalar <- function(x, what, min = -Inf, max = Inf, integer = FALSE) {
  v <- .rmbl_num(x, what, integer = integer)
  if (length(v) != 1L || is.na(v) || !is.finite(v) || v < min || v > max) {
    rng <- if (is.finite(min) && is.finite(max)) sprintf(" from %s to %s", format(min), format(max)) else
      if (is.finite(min)) sprintf(" of at least %s", format(min)) else
        if (is.finite(max)) sprintf(" of at most %s", format(max)) else ""
    stop(sprintf("`%s` must be one %s%s", what, if (integer) "whole number" else "number", rng), call. = FALSE)
  }
  v
}

# An error handler for a user's function called in a loop (a statistic, an injection): the error
# becomes `default`, except R's own time limits, which must end the call. Caught, they were each an NA,
# and setTimeLimit() could never stop cpspwr() or cpsfals() (CRAN stress test of 0.5.14).
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

# A function where data goes: said in words, before as.character(), match() or `[` refuse it in
# theirs ("cannot coerce type 'closure' to vector of type 'character'"; 64 such arguments in the
# re-test of the b617a3f CRAN stress fixes). Called with the arguments named: .rmbl_no_fn(x = x)
.rmbl_no_fn <- function(...) {
  a <- list(...)
  for (nm in names(a)) {
    if (is.function(a[[nm]])) stop(sprintf("`%s` must be data, not a function", nm), call. = FALSE)
    # an environment too: as.character() refuses it in its own words (CRAN stress test of 0.5.14)
    if (is.environment(a[[nm]])) stop(sprintf("`%s` must be data, not an environment", nm), call. = FALSE)
  }
  invisible(TRUE)
}

# A file the function reads: one path that exists and is a file (not a directory)
.rmbl_file1 <- function(path, what = "path") {
  path <- .rmbl_string1(path, what)
  if (!file.exists(path)) stop(sprintf("`%s`: no such file: %s", what, path), call. = FALSE)
  if (dir.exists(path)) stop(sprintf("`%s` is a directory, not a file: %s", what, path), call. = FALSE)
  path
}


# Evaluate `expr` under a fixed RNG seed and hand the caller's stream back
# untouched: a drift report must not move the user's downstream draws.
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

# Finite, non-negative counts, or an error that names the argument.
#' @noRd
.rmbl_check_counts <- function(v, what) {
  if (any(!is.finite(v)) || any(v < 0)) {
    stop(sprintf("`%s` must be finite, non-negative counts", what), call. = FALSE)
  }
  invisible(v)
}

# A plot method called on something its class's function did not make (plot.rmbl_crf(1)): said, not a
# base R error from deep inside the drawing ("$ operator is invalid for atomic vectors"; 91 such
# calls in the CRAN stress test of b617a3f)
.rmbl_plot_check <- function(x, cls) {
  if (!inherits(x, cls) || !is.list(x)) {
    stop(sprintf("`x` must be a %s object, as returned by the function that makes one", cls), call. = FALSE)
  }
  invisible(x)
}
