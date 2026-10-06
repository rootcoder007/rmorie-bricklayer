# The certificate fixtures: lines of  name|hex  (DER), shared by the x509,
# name-constraint and revocation tests.
x509_fx <- function() {
  fx <- readLines(test_path("x509-fixtures.txt"), warn = FALSE)
  fx <- fx[!startsWith(fx, "#") & nzchar(fx)]
  parts <- strsplit(fx, "|", fixed = TRUE)
  stats::setNames(
    lapply(parts, function(p) .rmbl_hex_to_raw(p[2L])),
    vapply(parts, `[[`, character(1), 1L)
  )
}
