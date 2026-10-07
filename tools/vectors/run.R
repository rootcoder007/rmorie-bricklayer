# Run the pinned C2SP Wycheproof and NIST ACVP vector sets against the installed
# rmoriebricklayer:  Rscript tools/vectors/run.R VEC_DIR [per_group]
# VEC_DIR as tools/vectors/fetch.sh lays it out. Every test is checked (pass/fail) or
# counted as not applicable with its reason; any failure exits 1. The runner itself is
# tests/testthat/helper-vectors.R, which the offline subset test shares.
args <- commandArgs(trailingOnly = TRUE)
vec <- if (length(args)) args[[1]] else "vectors"
per_group <- if (length(args) > 1) as.integer(args[[2]]) else NA_integer_
suppressPackageStartupMessages(library(rmoriebricklayer))
`%||%` <- function(a, b) if (is.null(a)) b else a
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
source(file.path(here, "..", "..", "tests", "testthat", "helper-vectors.R"))
TOTAL <- rmbl_run_vectors(vec, per_group, verbose = TRUE)
# ------------------------------------------------------------------- report
cat(sprintf("\n%-46s %7s %5s %6s  %s\n", "vector file", "pass", "fail", "n/a", "not applicable because"))
tp <- 0L; tf <- 0L; tn <- 0L
for (f in names(TOTAL)) {
  r <- TOTAL[[f]]; nn <- sum(unlist(r$na))
  why <- if (length(r$na)) paste(sprintf("%s (%d)", names(r$na), unlist(r$na)), collapse = "; ") else ""
  cat(sprintf("%-46s %7d %5d %6d  %s\n", f, r$pass, r$fail, nn, why))
  tp <- tp + r$pass; tf <- tf + r$fail; tn <- tn + nn
}
cat(sprintf("%-46s %7d %5d %6d\n", "TOTAL", tp, tf, tn))
quit(status = if (tf > 0L) 1L else 0L)
