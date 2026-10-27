# Checks a result that prints as a box: format() gives character lines under
# the title with the given text in them, and print() on an ASCII console draws
# a +-- box no wider than 79 columns and returns the result invisibly.
expect_box2 <- function(x, title, has = character()) {
  withr::local_envvar(RMBL_ASCII_ONLY = "1")
  withr::local_options(rmoriebricklayer.width = 80, rmoriebricklayer.numcol = 1)
  txt <- format(x)
  testthat::expect_type(txt, "character")
  testthat::expect_true(grepl(title, txt[1L], fixed = TRUE), info = txt[1L])
  flat <- gsub("\\s+", " ", paste(txt, collapse = " "))
  for (h in has) {
    testthat::expect_true(grepl(h, flat, fixed = TRUE), info = h)
  }
  out <- utils::capture.output({
    res <- withVisible(print(x))
  })
  testthat::expect_false(res$visible)
  testthat::expect_identical(res$value, x)
  testthat::expect_match(out[1L], "^\\+-- ")
  testthat::expect_match(out[length(out)], "^\\+-+\\+$")
  testthat::expect_true(all(nchar(out) <= 79L))
  invisible(out)
}

# A result of class `cls` without the columns its box needs (a subset of it)
# prints as a plain table under its title, with a note saying why.
expect_df_fallback <- function(cls, title) {
  x <- structure(data.frame(zz = 1:2), class = c(cls, "data.frame"))
  flat <- gsub("\\s+", " ", paste(format(x), collapse = " "))
  testthat::expect_true(grepl(title, flat, fixed = TRUE), info = cls)
  testthat::expect_true(grepl("a subset of it", flat, fixed = TRUE),
    info = cls)
  invisible(flat)
}

# A table result without the columns its box needs prints as the plain
# data frame print() gives.
expect_plain_df <- function(cls) {
  d <- data.frame(zz = 1:2)
  x <- structure(d, class = c(cls, "data.frame"))
  testthat::expect_identical(format(x), utils::capture.output(print(d)),
    info = cls)
}

# A measure without its record of inputs formats as the plain number.
expect_plain_measure <- function(cls, v = c(a = 1.5)) {
  x <- structure(v, class = c(cls, "rmbl_measure", "numeric"))
  testthat::expect_identical(format(x), format(v), info = cls)
}

# A result's format() lines as one string, runs of space made one.
box_text <- function(x, ...) {
  gsub("\\s+", " ", paste(format(x, ...), collapse = " "))
}
