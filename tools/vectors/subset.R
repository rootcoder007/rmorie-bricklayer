# Cut the small offline subset tests/testthat/vectors/ from a full fetch:
#   Rscript tools/vectors/subset.R VEC_DIR
# Wycheproof: one test per (result, flags) class; ACVP: one test per group (SLH-DSA
# signatures only for the 128f sets). Keeps the CRAN tarball small; runs in seconds.
args <- commandArgs(trailingOnly = TRUE)
vec <- args[[1]]
out <- "tests/testthat/vectors"
suppressPackageStartupMessages(library(rmoriebricklayer))
rd <- function(p) bricklayer_json_from_json(paste(readLines(p, warn = FALSE), collapse = "\n"), simplifyVector = FALSE)
wr <- function(x, p) { dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE); writeLines(bricklayer_json_to_json(x, auto_unbox = TRUE, digits = NA), p) }
obj <- function(x) if (is.null(x$testGroups)) Filter(function(e) is.list(e) && !is.null(e$testGroups), x)[[1]] else x
unlink(out, recursive = TRUE)
for (f in list.files(file.path(vec, "wycheproof"), full.names = TRUE)) {
  d <- rd(f)
  # one test per distinct (result, flags) class across the file: every kind of malformed
  # input Wycheproof targets stays represented, at a fraction of the size
  seen <- character()
  d$testGroups <- lapply(d$testGroups, function(g) {
    g$tests <- Filter(function(t) {
      k <- paste(t$result, paste(sort(unlist(t$flags)), collapse = "+"), g$type)
      if (k %in% seen) return(FALSE)
      seen <<- c(seen, k)
      TRUE
    }, g$tests)
    g
  })
  d$testGroups <- Filter(function(g) length(g$tests) > 0L, d$testGroups)
  wr(d, file.path(out, "wycheproof", basename(f)))
}
for (set in list.dirs(file.path(vec, "acvp"), recursive = FALSE, full.names = FALSE)) {
  p <- obj(rd(file.path(vec, "acvp", set, "prompt.json")))
  e <- obj(rd(file.path(vec, "acvp", set, "expectedResults.json")))
  slh_sig <- grepl("^SLH-DSA-sig", set)
  keep <- character()
  p$testGroups <- Filter(Negate(is.null), lapply(p$testGroups, function(g) {
    if (slh_sig && !grepl("128f$", g$parameterSet)) return(NULL)
    if (identical(g$testType, "LDT")) return(NULL)
    g$tests <- utils::head(g$tests, 1L)
    keep <<- c(keep, vapply(g$tests, function(t) as.character(t$tcId), ""))
    g
  }))
  e$testGroups <- lapply(e$testGroups, function(g) {
    g$tests <- Filter(function(t) as.character(t$tcId) %in% keep, g$tests); g
  })
  e$testGroups <- Filter(function(g) length(g$tests) > 0L, e$testGroups)
  wr(p, file.path(out, "acvp", set, "prompt.json"))
  wr(e, file.path(out, "acvp", set, "expectedResults.json"))
}
cat("subset written to", out, "\n")
