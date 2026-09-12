# Source-level invariants that only break on a platform this machine is
# not.
#
# A macOS-only compile failure costs a full CI round trip to see and
# cannot be reproduced on a Linux host at all -- l14 has clang but no
# libc++ headers, so the standard library that causes it is absent. The
# answer is to state the hazard as a property of the SOURCE and check
# that property anywhere.

src_dir <- function() {
  # under R CMD check the tests run from a copy with no src/, so look for
  # the installed package's own sources first and skip when absent
  for (p in c("../../src", "../../../src", "src")) {
    if (dir.exists(p)) return(normalizePath(p))
  }
  NA_character_
}

test_that("no R header precedes a header that pulls in libc++ locale", {
  d <- src_dir()
  skip_if(is.na(d), "package sources not available from here")
  files <- list.files(d, pattern = "[.](cpp|c|h|hpp)$", full.names = TRUE)
  skip_if(!length(files), "no sources found")

  # R's Rinternals.h defines a MACRO named `length`. libc++ -- the
  # standard library on macOS -- has member functions of that name in
  # <locale>, so once the macro is in scope any header that reaches
  # <locale> is rewritten and the compile fails with "too many arguments
  # provided to function-like macro invocation". libstdc++ has no such
  # collision, which is why a Linux build is silent about it.
  #
  # These are the standard headers observed to reach <locale> on libc++.
  hazardous <- c("functional", "locale", "regex", "iomanip", "iostream",
                 "sstream", "iosfwd", "istream", "ostream", "fstream")
  offenders <- character(0)
  for (f in files) {
    lines <- readLines(f, warn = FALSE)
    inc <- grep("^\\s*#\\s*include\\s*<", lines)
    if (!length(inc)) next
    r_at <- inc[grepl("^\\s*#\\s*include\\s*<R[./]|<Rinternals|<Rdefines",
                      lines[inc])]
    if (!length(r_at)) next
    first_r <- min(r_at)
    for (i in inc[inc > first_r]) {
      hdr <- sub(".*<([^>]+)>.*", "\\1", lines[i])
      if (hdr %in% hazardous) {
        offenders <- c(offenders, sprintf("%s:%d includes <%s> after an R header",
                                          basename(f), i, hdr))
      }
    }
  }
  # Put the standard headers first in the offending file. That ordering
  # is always safe and costs nothing.
  expect_equal(offenders, character(0))
})

test_that("no source file carries a non-ASCII byte", {
  # R CMD check --as-cran rejects non-ASCII in R sources, and a stray
  # smart quote or box-drawing character in a comment is easy to
  # introduce and invisible on review
  for (d in list("R", "src")) {
    p <- NULL
    for (cand in c(file.path("../..", d), file.path("../../..", d), d)) {
      if (dir.exists(cand)) { p <- cand; break }
    }
    if (is.null(p)) next
    files <- list.files(p, pattern = "[.](R|cpp|c|h|hpp)$",
                        full.names = TRUE)
    bad <- character(0)
    for (f in files) {
      raw <- readBin(f, "raw", file.size(f))
      if (any(raw > as.raw(127))) bad <- c(bad, basename(f))
    }
    expect_equal(bad, character(0), info = d)
  }
})

test_that("every C entry point is registered and every registration resolves", {
  d <- src_dir()
  skip_if(is.na(d), "package sources not available from here")
  init <- file.path(d, "init.c")
  skip_if(!file.exists(init), "no init.c")
  ini <- readLines(init, warn = FALSE)

  # the names the .Call table offers
  reg <- regmatches(ini, regexpr("\"C_rmbl_[A-Za-z0-9_]+\"", ini))
  reg <- gsub("\"", "", reg[nzchar(reg)])
  reg <- unique(reg)
  expect_gt(length(reg), 30L)

  # the entry points the C++ actually defines
  defined <- character(0)
  for (f in list.files(d, pattern = "[.](cpp|c)$", full.names = TRUE)) {
    if (basename(f) == "init.c") next
    lines <- readLines(f, warn = FALSE)
    m <- regmatches(lines, regexpr("SEXP\\s+C_rmbl_[A-Za-z0-9_]+\\s*\\(",
                                   lines))
    m <- m[nzchar(m)]
    defined <- c(defined, gsub("^SEXP\\s+|\\s*\\($", "", m))
  }
  defined <- unique(defined)

  # A registration naming a function nobody defines fails to LINK; a
  # definition nobody registers is dead weight that R_useDynamicSymbols
  # FALSE makes unreachable from R. Neither is caught by a passing test
  # suite, because a test only exercises what it happens to call.
  expect_equal(sort(setdiff(reg, defined)), character(0))
  expect_equal(sort(setdiff(defined, reg)), character(0))

  # and each registration's declared arity matches its definition
  for (nm in reg) {
    row <- grep(sprintf("\"%s\"", nm), ini, value = TRUE)
    arity <- suppressWarnings(as.integer(
      sub(".*,\\s*([0-9]+)\\s*\\}.*", "\\1", row[1L])))
    if (is.na(arity)) next
    decl <- grep(sprintf("extern SEXP %s\\(", nm), ini, value = TRUE)
    if (!length(decl)) next
    args <- sub(".*\\(([^)]*)\\).*", "\\1", decl[1L])
    n <- if (identical(trimws(args), "void") || !nzchar(trimws(args))) {
      0L
    } else {
      length(strsplit(args, ",", fixed = TRUE)[[1L]])
    }
    expect_equal(arity, n, info = nm)
  }
})
