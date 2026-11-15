# The values dload() gives for a CSV column (P9): numbers only when R gives
# them back as written, empty fields missing, numbers correctly rounded, and
# the names as the header writes them on request.

csv_gz <- function(txt) {
  f <- tempfile(fileext = ".csv.gz")
  con <- gzfile(f, "wb")
  writeBin(charToRaw(txt), con)
  close(con)
  f
}

test_that("a code with a leading zero stays text, as written", {
  f <- csv_gz(paste0(
    "lead,zero,half,negz,expo,pad,plus,hex,big,na,emp,onlyna,mix\n",
    "046,0,0.5,-0,1e5, 12,+1,0x1A,12345678901234567890,NA,,NA,6.0\n",
    "007,1,1.5,2,2,3,4,5,1,x,y,NA,7\n"
  ))
  w <- .bl_read_csv_gz(f)
  expect_identical(w$lead, c("046", "007"))
  expect_identical(w$zero, c(0L, 1L))
  expect_identical(w$half, c(0.5, 1.5))
  expect_identical(w$negz, c(0L, 2L))
  expect_identical(w$expo, c(1e5, 2))
  expect_identical(w$pad, c(12L, 3L))
  expect_identical(w$plus, c("+1", "4"))
  expect_identical(w$hex, c("0x1A", "5"))
  expect_identical(w$big, c("12345678901234567890", "1"))
  expect_identical(w$mix, c(6, 7))
  # only an empty field is missing in a text column
  expect_identical(w$na, c("NA", "x"))
  expect_identical(w$emp, c(NA, "y"))
  expect_identical(w$onlyna, c("NA", "NA"))
  # the part reader and the large-table path give the same frame
  for (p in c(3L, 7L, 64L)) {
    expect_identical(.bl_csv_part(f, NULL, Inf, NULL, piece = p), w)
  }
  expect_identical(.bl_read_csv_streamed(f), w)
})

test_that("NA is missing in a number column, and an empty column is NA", {
  f <- csv_gz("a,b,c\n1,TRUE,\nNA,NA,\n,F,\n")
  w <- .bl_read_csv_gz(f)
  expect_identical(w$a, c(1L, NA, NA))
  expect_identical(w$b, c(TRUE, NA, FALSE))
  expect_identical(w$c, c(NA, NA, NA))
  expect_identical(.bl_csv_part(f, NULL, Inf, NULL, piece = 3L), w)
})

test_that("numbers are read correctly rounded", {
  # the doubles nearest each text, from Python's float() (correctly
  # rounded), run once and written here as float.hex() gave them
  ref <- c(
    "1.239042694" = "0x1.3d31e6e913e67p+0",
    "-8833541.51630376" = "-0x1.0d940b0858f77p+23",
    "0.10000000000000001" = "0x1.999999999999ap-4",
    "123456789012345.67" = "0x1.c12218377de6bp+46",
    "9007199254740993" = "0x1.0000000000000p+53",
    "9007199254740995" = "0x1.0000000000002p+53",
    "1e23" = "0x1.52d02c7e14af6p+76",
    "8.98846567431158e307" = "0x1.0000000000000p+1023",
    "4.9406564584124654e-324" = "0x0.0000000000001p-1022",
    "2.4703282292062328e-324" = "0x0.0000000000001p-1022",
    "2.2250738585072011e-308" = "0x0.fffffffffffffp-1022",
    "2.2250738585072014e-308" = "0x1.0000000000000p-1022",
    "1.7976931348623157e308" = "0x1.fffffffffffffp+1023",
    "0.3" = "0x1.3333333333333p-2",
    "12345678901" = "0x1.6fee0e1a80000p+33",
    # halfway between 1 and the next double: to even, and just past it
    "1.00000000000000011102230246251565404236316680908203125" =
      "0x1.0000000000000p+0",
    "1.00000000000000011102230246251565404236316680908203126" =
      "0x1.0000000000001p+0",
    "3.14159265358979323846264338327950288419716939937510582097494459" =
      "0x1.921fb54442d18p+1"
  )
  want <- as.numeric(unname(ref))
  got <- .Call(C_rmbl_strtod, names(ref))
  expect_identical(sprintf("%a", got), sprintf("%a", want))
  # the readers take Inf, -Inf and NaN, and blanks around a number
  g <- .bl_read_csv_gz(csv_gz("x,y\n 2.5 ,a\nInf,b\n-Inf,c\nNaN,d\n,e\n"))
  expect_identical(g$x, c(2.5, Inf, -Inf, NaN, NA))
  # the readers: a column of the texts of 17 significant digits or fewer
  short <- names(ref)[nchar(gsub("[^0-9]", "", names(ref))) <= 17L |
                        grepl("e", names(ref))]
  short <- short[!grepl("^1\\.0000000000000001110|^3\\.14159", short)]
  f <- csv_gz(paste0("x\n", paste(short, collapse = "\n"), "\n"))
  w <- .bl_read_csv_gz(f)
  expect_identical(sprintf("%a", w$x), sprintf("%a", want[match(short,
                                                               names(ref))]))
  expect_identical(.bl_csv_part(f, NULL, Inf, NULL, piece = 7L), w)
})

test_that("names = \"asis\" keeps the header's own names", {
  f <- csv_gz(" Offence Description ,code,% share,x,x\nTheft,046,1.5,1,2\n")
  w <- .bl_read_csv_gz(f)
  expect_identical(names(w), c("Offence.Description", "code", "X..share",
                               "x", "x.1"))
  a <- .bl_read_csv_gz(f, names = "asis")
  raw <- c("Offence Description", "code", "% share", "x", "x")
  expect_identical(names(a), raw)
  expect_identical(unname(as.list(a)), unname(as.list(w)))
  p <- .bl_csv_part(f, "% share", Inf, NULL, names = "asis")
  expect_identical(names(p), "% share")
  seen <- NULL
  .bl_csv_part(f, NULL, Inf, function(d) {
    seen <<- names(d)
    rep(TRUE, nrow(d))
  }, names = "asis")
  expect_identical(seen, raw)
  expect_error(dload("a/b", names = "plain"), "names")
  got <- character()
  st <- blcli(c("data", "pull", "a/b", "--names", "plain"),
              out = function(...) got <<- c(got, paste0(...)))
  expect_identical(st, 2L)
  expect_match(got, "`--names` must be R or asis")
})
