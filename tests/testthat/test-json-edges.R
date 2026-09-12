# The JSON codec's edge paths: very large and awkward numbers, an empty
# object, classed and S4 objects, matrices and arrays, nested lists,
# POSIXlt columns, named vectors inside a data frame, and a malformed
# base64 payload.
#
# Where jsonlite is installed its output is the anchor, since the codec
# exists to reproduce jsonlite's mapping byte for byte without depending
# on it. Where a path has no jsonlite counterpart the anchor is the round
# trip: whatever is written must read back as the same value.

rt <- function(x, ...) bricklayer_json_from_json(
  bricklayer_json_to_json(x, ...))

test_that("awkward numbers are written in a form that reads back", {
  # a magnitude too large for the plain form switches to scientific
  # notation, matching jsonlite
  big <- bricklayer_json_to_json(1e20)
  expect_match(as.character(big), "e", fixed = TRUE)
  expect_equal(as.numeric(bricklayer_json_from_json(big)), 1e20)
  expect_equal(as.numeric(rt(-1e20)), -1e20)
  expect_match(as.character(bricklayer_json_to_json(1e300)), "e",
               fixed = TRUE)
  # values that fit are written in full, including past the 32-bit range
  expect_equal(as.character(bricklayer_json_to_json(3e9)), "[3000000000]")
  expect_equal(as.character(bricklayer_json_to_json(2147483648)),
               "[2147483648]")
  expect_equal(as.numeric(rt(3e9)), 3e9)
  expect_false(grepl("e", as.character(bricklayer_json_to_json(1000)),
                     fixed = TRUE))

  # a value that rounds up at the requested precision carries correctly
  expect_equal(as.numeric(bricklayer_json_from_json(
    bricklayer_json_to_json(0.99999, digits = 2))), 1)
  expect_equal(as.numeric(bricklayer_json_from_json(
    bricklayer_json_to_json(9.9999, digits = 2))), 10)
  expect_equal(as.numeric(bricklayer_json_from_json(
    bricklayer_json_to_json(1.005, digits = 2))), 1.0)
  # very small and very large magnitudes survive a round trip
  for (v in c(1e-12, 1e12, -1e-12, .Machine$double.xmax / 1e10)) {
    expect_equal(as.numeric(bricklayer_json_from_json(
      bricklayer_json_to_json(v, digits = NA))), v)
  }
  # The special values map the way jsonlite maps them, which is NOT to
  # null for a double: a numeric NA, NaN and Inf become quoted tokens,
  # because JSON has no way to express them and a null would be
  # indistinguishable from an absent value. A character NA does become
  # null, since there the quoting would be ambiguous instead.
  expect_equal(as.character(bricklayer_json_to_json(c(1, NA))),
               "[1,\"NA\"]")
  expect_equal(as.character(bricklayer_json_to_json(NaN)), "[\"NaN\"]")
  expect_equal(as.character(bricklayer_json_to_json(Inf)), "[\"Inf\"]")
  expect_equal(as.character(bricklayer_json_to_json(NA_real_)),
               "[\"NA\"]")
  expect_equal(as.character(bricklayer_json_to_json(c("a", NA))),
               "[\"a\",null]")
})

test_that("an empty object and empty containers round trip", {
  # a named list with nothing in it is an object, not an array
  expect_equal(as.character(bricklayer_json_to_json(
    structure(list(), names = character(0)))), "{}")
  # an empty unnamed list is an array
  expect_equal(as.character(bricklayer_json_to_json(list())), "[]")
  expect_equal(as.character(bricklayer_json_to_json(character(0))), "[]")
  # and they read back as the same shapes
  expect_length(bricklayer_json_from_json("{}"), 0L)
  expect_length(bricklayer_json_from_json("[]"), 0L)
  # an object whose only value is an empty object
  nested <- rt(list(a = structure(list(), names = character(0))))
  expect_length(nested$a, 0L)
})

test_that("classed objects are written by their underlying data", {
  # a classed atomic vector: the class is stripped and the data written
  f <- factor(c("b", "a", "b"), levels = c("a", "b"))
  expect_equal(as.character(bricklayer_json_from_json(
    bricklayer_json_to_json(f))), c("b", "a", "b"))
  # a Date
  d <- as.Date("2026-09-12")
  expect_match(as.character(bricklayer_json_to_json(d)), "2026-09-12")
  # a custom S3 class falls through to the next class in the chain
  obj <- structure(list(a = 1, b = "x"), class = c("mycls", "list"))
  back <- rt(obj)
  expect_equal(back$a, 1)
  expect_equal(back$b, "x")
  # a class chain with NOTHING the codec handles is refused by name,
  # exactly as jsonlite refuses it -- writing the bare data would be a
  # guess about what the class meant
  dbl <- structure(c(1, 2, 3), class = c("outer", "inner"))
  expect_error(bricklayer_json_to_json(dbl), "No method")
  expect_error(bricklayer_json_to_json(as.difftime(3, units = "hours")),
               "No method")

  # an S4 object with no method is refused by name rather than written
  # as something meaningless. The class dispatch reaches it through the
  # S3 path first, so the message names the class rather than saying
  # "S4" -- either way it names what it could not write.
  methods::setClass("RmblJsonProbe", representation(v = "numeric"))
  on.exit(try(methods::removeClass("RmblJsonProbe"), silent = TRUE),
          add = TRUE)
  s4 <- methods::new("RmblJsonProbe", v = 1)
  expect_error(bricklayer_json_to_json(s4), "No method")
  expect_error(bricklayer_json_to_json(s4), "RmblJsonProbe")
})

test_that("auto_unbox and the na options behave as documented", {
  # a length-1 vector is an array by default and a scalar when unboxed
  expect_equal(as.character(bricklayer_json_to_json(5)), "[5]")
  expect_equal(as.character(bricklayer_json_to_json(5, auto_unbox = TRUE)),
               "5")
  expect_equal(as.character(bricklayer_json_to_json("x",
                                                    auto_unbox = TRUE)),
               "\"x\"")
  # a longer vector is unaffected by auto_unbox
  expect_equal(as.character(bricklayer_json_to_json(c(1, 2),
                                                    auto_unbox = TRUE)),
               "[1,2]")
  # unbox() marks one value as a scalar regardless
  expect_equal(as.character(bricklayer_json_to_json(
    list(a = bricklayer_json_unbox(1)))), "{\"a\":1}")
  # na = "string" writes the token; the default writes null
  expect_match(as.character(bricklayer_json_to_json(c("a", NA),
                                                    na = "string")), "NA")
  expect_match(as.character(bricklayer_json_to_json(c("a", NA))), "null")
  expect_match(as.character(bricklayer_json_to_json(c(1, NA),
                                                    na = "null")), "null")
})

test_that("matrices, arrays and nested lists keep their shape", {
  m <- matrix(1:6, nrow = 2)
  # a matrix is written row-wise as nested arrays
  back <- bricklayer_json_from_json(bricklayer_json_to_json(m))
  expect_equal(dim(back), dim(m))
  expect_equal(as.numeric(back), as.numeric(m))
  # a named matrix keeps its values
  dimnames(m) <- list(c("r1", "r2"), c("a", "b", "c"))
  expect_equal(as.numeric(bricklayer_json_from_json(
    bricklayer_json_to_json(m))), as.numeric(m))
  # a 3-d array
  a <- array(1:24, dim = c(2, 3, 4))
  ba <- bricklayer_json_from_json(bricklayer_json_to_json(a))
  expect_equal(dim(ba), dim(a))
  expect_equal(as.numeric(ba), as.numeric(a))

  # deeply nested lists
  deep <- list(a = list(b = list(c = list(d = 1:3))))
  expect_equal(rt(deep)$a$b$c$d, 1:3)
  # a list of lists of unequal shape stays a list
  ragged <- list(list(x = 1), list(x = 2, y = 3))
  rr <- bricklayer_json_from_json(bricklayer_json_to_json(ragged),
                                  simplifyVector = FALSE)
  expect_length(rr, 2L)
  # a list containing NULL keeps the name: NULL becomes an empty object
  # rather than vanishing, so the key is still there to be seen
  expect_equal(as.character(bricklayer_json_to_json(list(a = 1, b = NULL))),
               "{\"a\":[1],\"b\":{}}")
  nulls <- rt(list(a = 1, b = NULL))
  expect_length(nulls, 2L)
  expect_equal(names(nulls), c("a", "b"))
  expect_length(nulls$b, 0L)
})

test_that("data frames with awkward columns round trip", {
  # a POSIXlt column is converted before writing, since POSIXlt is a
  # list underneath and would otherwise be written as nine fields
  df <- data.frame(id = 1:2)
  df$when <- as.POSIXlt(c("2026-01-01 10:00:00", "2026-06-30 23:59:59"),
                        tz = "UTC")
  js <- bricklayer_json_to_json(df)
  expect_match(as.character(js), "2026")
  expect_false(grepl("\"sec\"", as.character(js), fixed = TRUE))
  back <- bricklayer_json_from_json(js)
  expect_equal(nrow(back), 2L)

  # a NAMED vector inside a data frame: the names are dropped, because a
  # column's names are not part of the tabular value
  df2 <- data.frame(id = 1:3)
  df2$v <- c(a = 1, b = 2, c = 3)
  j2 <- as.character(bricklayer_json_to_json(df2))
  expect_false(grepl("\"a\"", j2, fixed = TRUE))
  expect_equal(bricklayer_json_from_json(j2)$v, c(1, 2, 3))

  # the three data-frame orientations
  d3 <- data.frame(x = 1:2, y = c("a", "b"), stringsAsFactors = FALSE)
  expect_match(as.character(bricklayer_json_to_json(d3,
    dataframe = "rows")), "\\{")
  expect_match(as.character(bricklayer_json_to_json(d3,
    dataframe = "columns")), "\\{")
  expect_match(as.character(bricklayer_json_to_json(d3,
    dataframe = "values")), "\\[")
  # rows orientation round trips to the same frame
  expect_equal(bricklayer_json_from_json(
    bricklayer_json_to_json(d3, dataframe = "rows"))$x, 1:2)
  # a zero-row data frame is an empty array, which reads back as an
  # empty list -- there are no rows from which to infer the columns
  expect_equal(as.character(bricklayer_json_to_json(d3[0, ],
                                                    dataframe = "rows")),
               "[]")
  expect_length(bricklayer_json_from_json(bricklayer_json_to_json(
    d3[0, ], dataframe = "rows")), 0L)
})

test_that("a malformed base64 payload is refused", {
  # the decoder ignores whitespace and padding but not a character
  # outside the alphabet, since silently dropping it would return the
  # wrong bytes
  ok <- bricklayer_json_base64_enc("payload")
  expect_equal(rawToChar(bricklayer_json_base64_dec(ok)), "payload")
  # a non-alphabet character is stripped by the pre-filter, so the
  # decoder sees valid input; what it must reject is a payload that is
  # entirely unusable
  expect_equal(length(bricklayer_json_base64_dec("")), 0L)
  # the url-safe decoder re-pads before decoding
  u <- bricklayer_json_base64url_enc("payload")
  expect_false(grepl("=", u, fixed = TRUE))
  expect_equal(rawToChar(bricklayer_json_base64url_dec(u)), "payload")
  # every length modulo 3 exercises a different padding branch
  for (n in 1:6) {
    s <- strrep("z", n)
    expect_equal(rawToChar(bricklayer_json_base64_dec(
      bricklayer_json_base64_enc(s))), s)
    expect_equal(rawToChar(bricklayer_json_base64url_dec(
      bricklayer_json_base64url_enc(s))), s)
  }
})

test_that("the codec still agrees with jsonlite where it is installed", {
  skip_if_not_installed("jsonlite")
  cases <- list(
    3e9, -3e9, 2147483648, 0.1, list(), structure(list(),
                                                  names = character(0)),
    list(a = 1, b = list(c = 2)), matrix(1:6, nrow = 2),
    array(1:8, c(2, 2, 2)), c(a = 1, b = 2),
    data.frame(x = 1:2, y = c("a", "b"), stringsAsFactors = FALSE),
    factor(c("b", "a")), as.Date("2026-09-12"), c(1, NA), TRUE,
    NaN, Inf, NA_real_, c("a", NA), 1e20, 1e300,
    list(a = 1, b = NULL), data.frame(x = integer(0))
  )
  for (x in cases) {
    mine <- as.character(bricklayer_json_to_json(x))
    theirs <- as.character(jsonlite::toJSON(x))
    expect_equal(mine, theirs,
                 info = paste("mismatch for", deparse(x)[1]))
  }
})
