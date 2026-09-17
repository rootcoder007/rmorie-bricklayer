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

.rmbl_local_seed <- function(seed, envir = parent.frame()) {
  if (is.null(seed)) {
    return(invisible(NULL))
  }
  old <- if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
    get(".Random.seed", envir = globalenv(), inherits = FALSE)
  } else {
    NULL
  }
  set.seed(seed)
  do.call(on.exit,
          list(bquote((.(.rmbl_restore_seed))(.(old))),
               add = TRUE, after = FALSE),
          envir = envir)
  invisible(seed)
}
