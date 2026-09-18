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

.rmbl_string1 <- function(x, what) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(trimws(x))) {
    stop(sprintf("`%s` must be a single non-empty string", what),
      call. = FALSE
    )
  }
  x
}
