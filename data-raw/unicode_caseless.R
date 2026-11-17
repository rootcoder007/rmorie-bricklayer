# Writes inst/unicode/caseless.txt, the tables of the bundle name rule's
# canonical caseless match (Unicode 15.1.0, chapter 3, D145):
# NFD(toCasefold(NFD(x))), with simple case folding (status C and S).
#
# Run from the package's root with the two files of the Unicode Character
# Database beside it:
#   https://www.unicode.org/Public/15.1.0/ucd/UnicodeData.txt
#   https://www.unicode.org/Public/15.1.0/ucd/CaseFolding.txt
#   Rscript data-raw/unicode_caseless.R UnicodeData.txt CaseFolding.txt
#
# Lines of the output, code points in hex:
#   D <cp> <cp> ...  the full canonical decomposition of a code point
#   F <cp> <cp>      its simple case folding
#   C <cp> <n>       its canonical combining class, when not 0
# Hangul syllables are not listed: their decomposition is arithmetic.
a <- commandArgs(TRUE)
ud <- utils::read.table(a[1], sep = ";", quote = "", colClasses = "character",
                        comment.char = "", na.strings = character())
cp <- strtoi(ud$V1, 16L)
dec <- ud$V6
canon <- nzchar(dec) & !startsWith(dec, "<")
one <- stats::setNames(strsplit(dec[canon], " ", fixed = TRUE),
                       ud$V1[canon])
full <- function(h) {
  d <- one[[h]]
  if (is.null(d)) {
    return(h)
  }
  unlist(lapply(d, full), use.names = FALSE)
}
dl <- vapply(names(one), function(h) paste(full(h), collapse = " "), "")
cf <- utils::read.table(a[2], sep = ";", quote = "", comment.char = "#",
                        colClasses = "character", strip.white = TRUE)
cf <- cf[cf$V2 %in% c("C", "S"), ]
ccc <- ud$V4 != "0"
out <- c(
  paste("D", names(dl), dl),
  paste("F", cf$V1, cf$V3),
  paste("C", ud$V1[ccc], ud$V4[ccc])
)
stopifnot(!anyNA(cp))
writeLines(out, "inst/unicode/caseless.txt")
