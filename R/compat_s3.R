# Hand-written part of the 0.5.x compatibility layer: the helpers the generated aliases in
# R/compat_names.R call, and the four 0.5.13 S3 generics with their methods.

# Old allowed values renamed in 1.0.0: each element of `x` found in names(map) becomes its new
# value; a full old choice vector becomes the full new one, so the default still means "first".
.rmbl_alias_val <- function(x, map) {
  if (!is.character(x)) return(x)
  i <- match(x, names(map))
  x[!is.na(i)] <- unname(map[i[!is.na(i)]])
  x
}

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
  eval(substitute(rtcalc(x = x, count = count, pop = population, by = by, per = per,
                         conflvl = conf_level, mincnt = min_count, ...)), parent.frame())
}

#' @rdname rmbl-aliases
#' @usage NULL
#' @export
rate.default <- function(x, population, per = 1000, conf_level = 0.95, min_count = 0, ...) {
  eval(substitute(rtcalc(x = x, pop = population, per = per, conflvl = conf_level,
                         mincnt = min_count, ...)), parent.frame())
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
  eval(substitute(ratechg(x = x, count = count, pop = population, prd = period, by = by,
                          lag = lag, per = per, conflvl = conf_level, mincnt = min_count,
                          ...)), parent.frame())
}

#' @rdname rmbl-aliases
#' @usage NULL
#' @export
rate_change.default <- function(x, ...) {
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
  eval(substitute(shrs(x = x, count = count, by = by, total = total, conflvl = conf_level,
                       ...)), parent.frame())
}

#' @rdname rmbl-aliases
#' @usage NULL
#' @export
share.default <- function(x, total = NULL, conf_level = 0.95, ...) {
  eval(substitute(shrs(x = x, total = total, conflvl = conf_level, ...)), parent.frame())
}

#' @rdname rmbl-aliases
#' @usage NULL
#' @export
yoy_summary <- function(object, ...) UseMethod("yoy_summary")

#' @rdname rmbl-aliases
#' @usage NULL
#' @export
yoy_summary.default <- function(object, ...) yoysmry(object, ...)

#' @rdname rmbl-aliases
#' @usage NULL
#' @export
yoy_summary.rmbl_yoy <- function(object, ...) yoysmry(object, ...)

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
