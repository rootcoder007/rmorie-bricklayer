# Hand-written part of the 0.5.x compatibility layer: the helpers the generated
# aliases in R/compat_names.R call, and the 0.5.13 S3 generic yoy_summary() with
# its method.

# yoy_summary() stays a generic, so methods written for it still dispatch; its
# method calls yoysmry() and returns the result under the 0.5.13 names. (1.1.1
# dropped the other three 0.5.13 generics, rate(), rate_change() and share():
# their names clash with functions in other CRAN packages; rtcalc(), ratechg()
# and shrs() are the functions.)

#' @rdname rmbl-aliases
#' @usage NULL
#' @export
yoy_summary <- function(object, ...) UseMethod("yoy_summary")

#' @rdname rmbl-aliases
#' @usage NULL
#' @export
yoy_summary.default <- function(object, ...) {
  .rmbl_alias_out(
    "yoy_summary",
    withVisible(yoysmry(.rmbl_new_names(object), ...))
  )
}

#' @rdname rmbl-aliases
#' @usage NULL
#' @export
print.rmbl_old <- function(x, ...) {
  .rmbl_old_call("print", .rmbl_old_arg(x), ...)
  invisible(x)
}

#' @rdname rmbl-aliases
#' @usage NULL
#' @export
format.rmbl_old <- function(x, ...) {
  .rmbl_old_call("format", .rmbl_old_arg(x), ...)
}

#' @rdname rmbl-aliases
#' @usage NULL
#' @export
plot.rmbl_old <- function(x, ...) .rmbl_old_call("plot", .rmbl_old_arg(x), ...)

#' @rdname rmbl-aliases
#' @usage NULL
#' @export
summary.rmbl_old <- function(object, ...) {
  .rmbl_old_call("summary", .rmbl_old_arg(object), ...)
}

# The generics an "rmbl_old" result is drawn, printed or summarised with: the
# package's own method gets the result in its 1.0.0 names (and print() returns
# the object as given); with no method of the package's, R's own runs on the
# 0.5.x names.
.rmbl_old_call <- function(generic, x, ...) {
  ns <- asNamespace("rmoriebricklayer")
  cls <- setdiff(oldClass(x), "rmbl_old")
  own <- any(vapply(
    cls,
    function(k) {
      f <- utils::getS3method(generic, k, optional = TRUE)
      !is.null(f) && identical(environment(f), ns)
    },
    NA
  ))
  if (own) {
    r <- withVisible(match.fun(generic)(.rmbl_new_names(x), ...))
    if (identical(generic, "print")) {
      return(invisible(x))
    }
    # the method's own result (a summary, the points drawn) under the same 0.5.x
    # names
    done <- attr(x, "rmbl_names")
    return(
      if (r$visible) {
        .rmbl_names_swap(r$value, done)
      } else {
        invisible(.rmbl_names_swap(r$value, done))
      }
    )
  }
  class(x) <- cls
  attr(x, "rmbl_names") <- NULL
  r <- match.fun(generic)(x, ...)
  if (identical(generic, "print")) invisible(x) else r
}

#' The argument of an rmbl_old method must be a translated result: called by
#' name on anything else (the hostile-argument battery), the method would hand
#' it to the base generic.
#' @param x The argument as given.
#' @return `x`.
#' @noRd
.rmbl_old_arg <- function(x) {
  if (!inherits(x, "rmbl_old")) {
    stop(
      "`x` must be a result returned under its 0.5.x names (class rmbl_old)",
      call. = FALSE
    )
  }
  x
}
