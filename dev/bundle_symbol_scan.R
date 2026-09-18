#!/usr/bin/env Rscript
# Bundle staging gate: every package-internal name a staged R file calls
# must be defined by a staged R file (or be explicitly guarded with
# exists("name", ...)), because the bundle runs with no family package
# installed. Usage: Rscript bundle_symbol_scan.R <stage_dir>
dir <- commandArgs(trailingOnly = TRUE)[1]
files <- list.files(dir, pattern = "[.]R$", full.names = TRUE)
pat <- "^(\\.rmbl_|core_|bricklayer_)"
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
cat("bundle_symbol_scan: ", length(files), " files, ",
    length(unique(used)), " internal names, all defined\n", sep = "")
