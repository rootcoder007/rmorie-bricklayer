#!/usr/bin/env Rscript
# Seed corpora for the fuzz targets, from the test fixtures: DER certificates
# and a timestamp token, the synthetic SIU report, and a spread of decimal
# strings. Run from the package root: Rscript inst/fuzz/mkcorpus.R
hex2raw <- function(h) as.raw(strtoi(substring(h, seq(1, nchar(h), 2), seq(2, nchar(h), 2)), 16L))
der <- "inst/fuzz/corpus/der"; dir.create(der, recursive = TRUE, showWarnings = FALSE)
for (f in c("x509-fixtures.txt", "timestamp-token.txt")) {
  for (line in readLines(file.path("tests/testthat", f), warn = FALSE)) {
    if (startsWith(line, "#") || !grepl("|", line, fixed = TRUE)) next
    parts <- strsplit(line, "|", fixed = TRUE)[[1]]
    hx <- gsub("[^0-9a-fA-F]", "", paste(parts[-1], collapse = ""))
    if (nzchar(hx) && nchar(hx) %% 2 == 0) writeBin(c(as.raw(1), hex2raw(hx)), file.path(der, paste0(parts[1], ".bin")))
  }
}
writeBin(c(as.raw(0), as.raw(1:96)), file.path(der, "rsa-slices.bin"))
siu <- "inst/fuzz/corpus/siu"; dir.create(siu, recursive = TRUE, showWarnings = FALSE)
html <- readBin("inst/extdata/siu_synthetic_report.html", "raw", file.size("inst/extdata/siu_synthetic_report.html"))
writeBin(html, file.path(siu, "synthetic.html"))
cat(gsub("<[^>]+>", " ", rawToChar(html)), file = file.path(siu, "synthetic.txt"))
st <- "inst/fuzz/corpus/strtod"; dir.create(st, recursive = TRUE, showWarnings = FALSE)
vals <- c("0", "1", "-1", "0.1", "1e308", "1e-308", "4.9406564584124654e-324", "2.2250738585072014e-308",
          "9007199254740993", "0.30000000000000004", "123456789012345678901234567890", "1.7976931348623157e308",
          "1e-400", "1e400", "-0.0", "3.14159265358979323846264338327950288", "5e-324", "2.4703282292062327e-324")
for (i in seq_along(vals)) cat(vals[i], file = file.path(st, sprintf("s%d.txt", i - 1L)))
cat(sprintf("corpus: %d der, %d siu, %d strtod\n", length(list.files(der)), length(list.files(siu)), length(list.files(st))))
