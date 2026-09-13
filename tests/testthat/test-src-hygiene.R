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

test_that("no Rd line exceeds 90 characters", {
  # Roxygen does not re-wrap what it emits, and its markdown expansion is
  # several times wider than the source: `[stats::ks.test()]` becomes a
  # 48-character \code{\link[...]{...}}, and \item{name}{ prepends the
  # parameter name to the first line of every @param. So a source line
  # that looks comfortable produces an Rd line that is not, and the only
  # way to keep this true is to check the generated file.
  #
  # Wrap the roxygen in R/ narrower to fix a failure here. Take care not
  # to break inside an inline span -- splitting `n = 8` across two source
  # lines makes roxygen rejoin it and emit ONE longer line, which is how
  # an earlier attempt at this made things worse.
  man <- NULL
  for (p in c("../../man", "../../../man", "man")) {
    if (dir.exists(p)) { man <- p; break }
  }
  skip_if(is.null(man), "man/ not available from here")
  files <- list.files(man, pattern = "[.]Rd$", full.names = TRUE)
  skip_if(!length(files), "no Rd files")
  long <- character(0)
  for (f in files) {
    lines <- readLines(f, warn = FALSE)
    w <- which(nchar(lines) > 90L)
    for (i in w) {
      long <- c(long, sprintf("%s:%d is %d chars", basename(f), i,
                              nchar(lines[i])))
    }
  }
  expect_equal(long, character(0))
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
    at <- grep(sprintf("extern SEXP %s\\(", nm), ini)
    if (!length(at)) next
    # a long declaration is legitimately wrapped, so join lines until the
    # closing parenthesis rather than reading only the first
    decl <- ini[at[1L]]
    k <- at[1L]
    while (!grepl(")", decl, fixed = TRUE) && k < length(ini)) {
      k <- k + 1L
      decl <- paste(decl, trimws(ini[k]))
    }
    args <- sub(".*\\(([^)]*)\\).*", "\\1", decl)
    n <- if (identical(trimws(args), "void") || !nzchar(trimws(args))) {
      0L
    } else {
      length(strsplit(args, ",", fixed = TRUE)[[1L]])
    }
    expect_equal(arity, n, info = nm)
  }
})

test_that("no S3 method for one class is defined in two files", {
  # This is not hypothetical. R/x509.R once returned
  # `bricklayer_chain_check`, which R/chain.R had owned since long
  # before for the hash-chain seal result, and defined its own format
  # and print for it. Whichever registered last rendered both, so
  # chain_verify()'s output printed through the certificate formatter
  # and failed on a field it never had. Nothing in the test suite
  # noticed; the vignette build did.
  #
  # Constructing one class in two files is fine and deliberate --
  # capsule_sign() and fips_sign_mu() both return a
  # `bricklayer_signature`. Defining its METHODS twice is the mistake.
  files <- list.files(file.path(test_path("..", ".."), "R"),
                      pattern = "[.]R$", full.names = TRUE)
  skip_if(length(files) == 0L, "not running from a source tree")
  seen <- list()
  for (f in files) {
    txt <- readLines(f, warn = FALSE)
    hits <- grep("^(format|print|as\\.character)\\.bricklayer_[A-Za-z0-9_]+ *<- *function",
                 txt, value = TRUE)
    for (h in hits) {
      m <- sub(" *<-.*", "", h)
      seen[[m]] <- unique(c(seen[[m]], basename(f)))
    }
  }
  twice <- seen[vapply(seen, length, integer(1)) > 1L]
  expect_identical(names(twice), character(0),
                   info = paste(names(twice), collapse = ", "))
  # every method is also registered exactly once
  ns <- readLines(test_path("..", "..", "NAMESPACE"), warn = FALSE)
  s3 <- grep("^S3method\\(", ns, value = TRUE)
  expect_identical(anyDuplicated(s3), 0L)
  expect_gt(length(s3), 20L)
})

test_that("the version is not stated twice with two different answers", {
  # CITATION.cff carries its own version field, and pkgdown renders it
  # on the citation page. It sat at 0.4.0 through six releases because
  # nothing compared it to DESCRIPTION -- the sort of staleness that
  # only a reader notices, and only after it has been wrong for a
  # while. This is the comparison.
  root <- test_path("..", "..")
  desc <- read.dcf(file.path(root, "DESCRIPTION"))[1, "Version"]
  cff <- file.path(root, "CITATION.cff")
  skip_if_not(file.exists(cff), "no CITATION.cff in this tree")
  txt <- readLines(cff, warn = FALSE)
  line <- grep("^version:", txt, value = TRUE)
  expect_length(line, 1L)
  stated <- gsub('^version: *"?|"?$', "", line)
  expect_identical(stated, unname(desc))
  # NEWS must lead with the version being released, too
  news <- readLines(file.path(root, "NEWS.md"), warn = FALSE)
  first <- grep("^# ", news, value = TRUE)[1]
  expect_match(first, unname(desc), fixed = TRUE)
})
