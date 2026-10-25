# Hand-written part of the 0.5.x compatibility layer: the helpers the generated
# aliases in R/compat_names.R call, and the four 0.5.13 S3 generics with their
# methods.

# The four 0.5.13 S3 generics. They stay generics, so methods written for them
# still dispatch; each method takes the 0.5.13 arguments and calls the new
# generic with the new names. The call is rebuilt from the argument expressions,
# so a bare column name still reads as one.

#' @rdname rmbl-aliases
#' @usage NULL
#' @export
rate <- function(x, ...) UseMethod("rate")

#' @rdname rmbl-aliases
#' @usage NULL
#' @export
rate.data.frame <- function(
  x,
  count,
  population,
  by = NULL,
  per = 1000,
  conf_level = 0.95,
  min_count = 0,
  ...
) {
  r <- withVisible(eval(
    substitute(rtcalc(
      x = x,
      count = count,
      pop = population,
      by = by,
      per = per,
      conflvl = conf_level,
      mincnt = min_count,
      ...
    )),
    parent.frame()
  ))
  .rmbl_alias_out("rate", r)
}

#' @rdname rmbl-aliases
#' @usage NULL
#' @export
rate.default <- function(
  x,
  population,
  per = 1000,
  conf_level = 0.95,
  min_count = 0,
  ...
) {
  r <- withVisible(eval(
    substitute(rtcalc(
      x = x,
      pop = population,
      per = per,
      conflvl = conf_level,
      mincnt = min_count,
      ...
    )),
    parent.frame()
  ))
  .rmbl_alias_out("rate", r)
}

#' @rdname rmbl-aliases
#' @usage NULL
#' @export
rate_change <- function(x, ...) UseMethod("rate_change")

#' @rdname rmbl-aliases
#' @usage NULL
#' @export
rate_change.data.frame <- function(
  x,
  count,
  population,
  period,
  by = NULL,
  lag = 1L,
  per = 1000,
  conf_level = 0.95,
  min_count = 0,
  ...
) {
  r <- withVisible(eval(
    substitute(ratechg(
      x = x,
      count = count,
      pop = population,
      prd = period,
      by = by,
      lag = lag,
      per = per,
      conflvl = conf_level,
      mincnt = min_count,
      ...
    )),
    parent.frame()
  ))
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
share.data.frame <- function(
  x,
  count,
  by = NULL,
  total = NULL,
  conf_level = 0.95,
  ...
) {
  r <- withVisible(eval(
    substitute(shrs(
      x = x,
      count = count,
      by = by,
      total = total,
      conflvl = conf_level,
      ...
    )),
    parent.frame()
  ))
  .rmbl_alias_out("share", r)
}

#' @rdname rmbl-aliases
#' @usage NULL
#' @export
share.default <- function(x, total = NULL, conf_level = 0.95, ...) {
  r <- withVisible(eval(
    substitute(shrs(x = x, total = total, conflvl = conf_level, ...)),
    parent.frame()
  ))
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
  .rmbl_alias_out(
    "yoy_summary",
    withVisible(yoysmry(.rmbl_new_names(object), ...))
  )
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
