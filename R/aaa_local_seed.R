# Seeding the RNG for one function call only. set.seed() replaces the
# session's random stream, so a user who seeded for reproducibility and
# then called a function that seeds internally would get identical
# downstream draws whatever seed they had chosen. This seeds for the rest
# of the calling function and restores the caller's stream (or its
# absence) when that function exits.
#' Puts back the caller's random stream, or removes the one a seeded call left when there was none.
#' @param old The saved `.Random.seed`, or NULL when the session had none.
#' @return NULL, invisibly.
#' @noRd
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

#' Checks a seed for R's own generator.
#'
#' A seed for R's own generator: one whole number from -2147483647 to 2^53 - 1. NA, Inf, text or two
#' numbers reached set.seed() itself, whose error ("supplied seed is not a valid integer") named
#' neither the function nor the argument (CRAN stress test of b617a3f). 2^53 is where doubles stop
#' holding every whole number, the native kernels' seed range too.
#' @param seed The value passed by the user.
#' @return The seed as an integer when it fits, otherwise as a double.
#' @noRd
.rmbl_r_seed <- function(seed) {
  if (!is.numeric(seed)) {
    stop("`seed` must be a single whole number from -2147483647 to 2^53 - 1 (a numeric value)", call. = FALSE)
  }
  if (length(seed) != 1L || !is.finite(seed) || seed != round(seed) ||
        seed < -.Machine$integer.max || seed >= 2^53) {
    stop("`seed` must be a single whole number from -2147483647 to 2^53 - 1", call. = FALSE)
  }
  if (abs(seed) <= .Machine$integer.max) as.integer(seed) else as.numeric(seed)
}

#' Sets R's generator from a seed in the range `.rmbl_r_seed()` accepts.
#'
#' set.seed() for every seed .rmbl_r_seed() takes. One in the integer range goes to set.seed(), so its
#' stream is the one R gives it. set.seed() takes no larger one, so past 2^31 - 1 the Mersenne-Twister
#' state is built from the seed's two halves: the state set.seed() makes from its low 31 bits, XORed
#' with the state it makes from minus its high bits (a seed set disjoint from the low halves), shifted
#' by one word so that equal halves cannot cancel. One stream for each seed up to 2^53, in R alone
#' (no native code: the files a bundle stages run without the package's library). Only R's default
#' generator has that state.
#' @param seed A seed checked by `.rmbl_r_seed()`.
#' @return NULL, invisibly.
#' @noRd
.rmbl_set_seed <- function(seed) {
  if (is.integer(seed)) return(set.seed(seed))
  if (!identical(RNGkind()[[1L]], "Mersenne-Twister")) {
    stop(sprintf(paste("a seed past 2147483647 needs R's default generator (Mersenne-Twister);",
                       "this session uses %s"), RNGkind()[[1L]]), call. = FALSE)
  }
  state <- function(s) {
    set.seed(s)
    get(".Random.seed", envir = globalenv())
  }
  lo <- state(as.integer(seed %% 2^31))
  hi <- state(-as.integer(seed %/% 2^31))   # 1 to 2^22 here: seeds -1 to -2^22
  words <- bitwXor(lo[3:626], hi[c(4:626, 3L)])
  words[is.na(words)] <- 1L   # a word that was NA_integer_ (-2^31) in either state
  assign(".Random.seed", c(lo[[1L]], 624L, words), envir = globalenv())
  invisible(NULL)
}

#' Seeds the RNG for the rest of the calling function and restores the caller's stream when that function exits.
#' @param seed The seed, or NULL to leave the stream alone.
#' @param envir The frame of the function whose exit restores the stream.
#' @return The checked seed, invisibly.
#' @noRd
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
