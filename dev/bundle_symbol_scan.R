#!/usr/bin/env Rscript
# Bundle staging gate: every package-internal name a staged R file calls
# must be defined by a staged R file (or be explicitly guarded with
# exists("name", ...)), because the bundle runs with no family package
# installed. Usage: Rscript bundle_symbol_scan.R <stage_dir>
dir <- commandArgs(trailingOnly = TRUE)[1]
files <- list.files(dir, pattern = "[.]R$", full.names = TRUE)
# the shared helpers, and the box helpers every result prints with
pat <- "^(\\.rmbl_|\\.an_|\\.mf_|\\.rate_|\\.rd_|core_|bricklayer_)"
defined <- character(); used <- character(); guarded <- character()
for (f in files) {
  ex <- tryCatch(parse(f, keep.source = FALSE),
                 error = function(e) stop("cannot parse ", f, ": ",
                                          conditionMessage(e)))
  for (e in ex) {
    if (is.call(e) && as.character(e[[1]]) %in% c("<-", "=") &&
        is.name(e[[2]])) defined <- c(defined, as.character(e[[2]]))
  }
  used <- c(used, grep(pat, all.names(ex), value = TRUE))
  txt <- paste(readLines(f, warn = FALSE), collapse = "\n")
  g <- regmatches(txt, gregexpr('exists\\("([^"]+)"', txt))[[1]]
  guarded <- c(guarded, sub('exists\\("([^"]+)"', "\\1", g))
  # "# bundle-scan-guarded: a b c" marks names only reached behind an
  # exists() check on a sibling name
  a <- regmatches(txt, gregexpr("bundle-scan-guarded:[^\n]*", txt))[[1]]
  guarded <- c(guarded, unlist(strsplit(sub("bundle-scan-guarded:", "", a),
                                        "[[:space:]]+")))
}
missing <- setdiff(unique(used), c(defined, guarded))
if (length(missing)) {
  cat("bundle_symbol_scan: called but not staged:\n  ",
      paste(missing, collapse = "\n  "), "\n")
  quit(status = 1)
}
# setup_and_run.R runs before analysis.R sources anything more, so the
# files it sources itself must define every name they call: staging a
# file is not enough when setup_and_run.R never sources it (1.0.3 found
# loadprov() calling .rmbl_cls() from a staged but unsourced file)
sr <- file.path(dir, "setup_and_run.R")
if (file.exists(sr)) {
  libs <- character()
  for (e in parse(sr, keep.source = FALSE)) {
    if (is.call(e) && identical(e[[1]], as.name("for")) &&
        identical(e[[2]], as.name("lib"))) libs <- eval(e[[3]], baseenv())
  }
  s_def <- character(); s_used <- character()
  for (f in file.path(dir, libs)) {
    ex <- parse(f, keep.source = FALSE)
    for (e in ex) {
      if (is.call(e) && as.character(e[[1]]) %in% c("<-", "=") &&
          is.name(e[[2]])) s_def <- c(s_def, as.character(e[[2]]))
    }
    s_used <- c(s_used, grep(pat, all.names(ex), value = TRUE))
  }
  s_miss <- setdiff(unique(s_used), c(s_def, guarded))
  if (length(s_miss)) {
    cat("bundle_symbol_scan: setup_and_run.R calls but never sources:\n  ",
        paste(s_miss, collapse = "\n  "), "\n")
    quit(status = 1)
  }
}
cat("bundle_symbol_scan: ", length(files), " files, ",
    length(unique(used)), " internal names, all defined\n", sep = "")
