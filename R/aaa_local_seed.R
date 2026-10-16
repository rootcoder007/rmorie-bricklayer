# Seeding the RNG for one function call only. set.seed() replaces the
# session's random stream, so a user who seeded for reproducibility and
# then called a function that seeds internally would get identical
# downstream draws whatever seed they had chosen. This seeds for the rest
# of the calling function and restores the caller's stream (or its
# absence) when that function exits.
.rmbl_restore_seed <- function(old) {
  if (is.null(old)) {
    if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
      rm(".Random.seed", envir = globalenv())
    }
  } else {
    assign(".Random.seed", old, envir = globalenv())
  }
  invisible(NULL)
}

# A seed for R's own generator: one whole number from -2147483647 to 2^53 - 1. NA, Inf, text or two
# numbers reached set.seed() itself, whose error ("supplied seed is not a valid integer") named
# neither the function nor the argument (CRAN stress test of b617a3f). 2^53 is where doubles stop
# holding every whole number, the native kernels' seed range too.
.rmbl_r_seed <- function(seed) {
  if (!is.numeric(seed) || length(seed) != 1L || !is.finite(seed) || seed != round(seed) ||
        seed < -.Machine$integer.max || seed >= 2^53) {
    stop("`seed` must be a single whole number from -2147483647 to 2^53 - 1", call. = FALSE)
  }
  if (abs(seed) <= .Machine$integer.max) as.integer(seed) else as.numeric(seed)
}

# set.seed() for every seed .rmbl_r_seed() takes. One in the integer range goes to set.seed(), so its
# stream is the one R gives it. set.seed() takes no larger one, so past 2^31 - 1 the Mersenne-Twister
# state is built from the seed instead: 624 words from the package's splitmix64 stream
# (core_uniforms()), one stream for each seed up to 2^53. Only R's default generator has that state.
.rmbl_set_seed <- function(seed) {
  if (is.integer(seed)) return(set.seed(seed))
  if (!identical(RNGkind()[[1L]], "Mersenne-Twister")) {
    stop(sprintf(paste("a seed past 2147483647 needs R's default generator (Mersenne-Twister);",
                       "this session uses %s"), RNGkind()[[1L]]), call. = FALSE)
  }
  set.seed(0L)   # the kind code R expects in the first word, for the session's normal and sample kinds
  code <- get(".Random.seed", envir = globalenv())[[1L]]
  words <- floor(core_uniforms(624, seed) * 2^32) - 2^31
  words[words == -2^31] <- -2^31 + 1   # -2^31 is NA_integer_ in R
  assign(".Random.seed", c(code, 624L, as.integer(words)), envir = globalenv())
  invisible(NULL)
}

.rmbl_local_seed <- function(seed, envir = parent.frame()) {
  if (is.null(seed)) {
    return(invisible(NULL))
  }
  seed <- .rmbl_r_seed(seed)
  old <- if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
    get(".Random.seed", envir = globalenv(), inherits = FALSE)
  } else {
    NULL
  }
  .rmbl_set_seed(seed)
  do.call(on.exit,
          list(bquote((.(.rmbl_restore_seed))(.(old))),
               add = TRUE, after = FALSE),
          envir = envir)
  invisible(seed)
}
