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
  hazardous <- c(
    "functional", "locale", "regex", "iomanip", "iostream",
    "sstream", "iosfwd", "istream", "ostream", "fstream"
  )
  offenders <- character(0)
  for (f in files) {
    lines <- readLines(f, warn = FALSE)
    inc <- grep("^\\s*#\\s*include\\s*<", lines)
    if (!length(inc)) next
    r_at <- inc[grepl(
      "^\\s*#\\s*include\\s*<R[./]|<Rinternals|<Rdefines",
      lines[inc]
    )]
    if (!length(r_at)) next
    first_r <- min(r_at)
    for (i in inc[inc > first_r]) {
      hdr <- sub(".*<([^>]+)>.*", "\\1", lines[i])
      if (hdr %in% hazardous) {
        offenders <- c(offenders, sprintf(
          "%s:%d includes <%s> after an R header",
          basename(f), i, hdr
        ))
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
      if (dir.exists(cand)) {
        p <- cand
        break
      }
    }
    if (is.null(p)) next
    files <- list.files(p,
      pattern = "[.](R|cpp|c|h|hpp)$",
      full.names = TRUE
    )
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
    if (dir.exists(p)) {
      man <- p
      break
    }
  }
  skip_if(is.null(man), "man/ not available from here")
  files <- list.files(man, pattern = "[.]Rd$", full.names = TRUE)
  skip_if(!length(files), "no Rd files")
  long <- character(0)
  for (f in files) {
    lines <- readLines(f, warn = FALSE)
    w <- which(nchar(lines) > 90L)
    for (i in w) {
      long <- c(long, sprintf(
        "%s:%d is %d chars", basename(f), i,
        nchar(lines[i])
      ))
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
    m <- regmatches(lines, regexpr(
      "SEXP\\s+C_rmbl_[A-Za-z0-9_]+\\s*\\(",
      lines
    ))
    m <- m[nzchar(m)]
    defined <- c(defined, gsub("^SEXP\\s+|\\s*\\($", "", m))
  }
  # every entry point is a wrapper in rmbl_barrier.cpp around <name>_impl:
  # the implementation names are the registered names
  defined <- unique(sub("_impl$", "", defined))

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
      sub(".*,\\s*([0-9]+)\\s*\\}.*", "\\1", row[1L])
    ))
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
    pattern = "[.]R$", full.names = TRUE
  )
  skip_if(length(files) == 0L, "not running from a source tree")
  seen <- list()
  for (f in files) {
    txt <- readLines(f, warn = FALSE)
    hits <- grep("^(format|print|as\\.character)\\.bricklayer_[A-Za-z0-9_]+ *<- *function",
      txt,
      value = TRUE
    )
    for (h in hits) {
      m <- sub(" *<-.*", "", h)
      seen[[m]] <- unique(c(seen[[m]], basename(f)))
    }
  }
  twice <- seen[vapply(seen, length, integer(1)) > 1L]
  expect_identical(names(twice), character(0),
    info = paste(names(twice), collapse = ", ")
  )
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
  # R CMD check runs the tests from the installed package, where this
  # source tree is not present -- reading DESCRIPTION from it errored on
  # every platform. The version is available without a source tree; the
  # files being compared against it are not, so they gate the test.
  root <- test_path("..", "..")
  cff <- file.path(root, "CITATION.cff")
  skip_if_not(
    file.exists(cff) && file.exists(file.path(root, "NEWS.md")),
    "not running from a source tree"
  )
  desc <- as.character(utils::packageVersion("rmoriebricklayer"))
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

test_that("every exported topic is in the pkgdown reference index", {
  skip_if_not_installed("pkgdown")
  d <- src_dir()
  skip_if(is.na(d), "package sources not available from here")
  root <- normalizePath(file.path(d, ".."))
  skip_if(!file.exists(file.path(root, "_pkgdown.yml")), "no _pkgdown.yml")
  # check_pkgdown() aborts on a topic missing from the index, which is the
  # failure the site build otherwise reports only after a push
  expect_no_error(pkgdown::check_pkgdown(root))
})

# ---- the sibling rules of the third review, as source properties ---------
# A fix that lands at one site and not its siblings is the failure mode of
# three review rounds. These enumerate the siblings mechanically.

r_dir <- function() {
  for (p in c("../../R", "../../../R", "R")) {
    if (dir.exists(p)) return(normalizePath(p))
  }
  NA_character_
}

test_that("the interrupt test is the throwing one everywhere but the barrier", {
  d <- src_dir()
  skip_if(is.na(d), "package sources not available from here")
  files <- list.files(d, pattern = "[.](cpp|c|h)$", full.names = TRUE)
  files <- files[basename(files) != "rmbl_barrier.cpp"]
  skip_if(!length(files), "no sources found")
  hits <- as.character(unlist(lapply(files, function(f) {
    l <- readLines(f, warn = FALSE)
    i <- grep("R_CheckUserInterrupt\\s*\\(", l)
    if (length(i)) paste0(basename(f), ":", i) else character(0)
  })))
  # R_CheckUserInterrupt() longjmps over every live C++ object; the kernels
  # call rmbl::check_interrupt() (throws) or rmbl_interrupt_pending() (flag)
  expect_identical(hits, character(0))
})

test_that("the barrier clears the interrupt flag on every path and raises for an unbarriered kernel", {
  d <- src_dir()
  skip_if(is.na(d), "package sources not available from here")
  b <- readLines(file.path(d, "rmbl_barrier.cpp"), warn = FALSE)
  expect_true(any(grepl("rmbl_kernel_interrupted = 0;   /* nothing from an earlier call may leak in */",
                        b, fixed = TRUE)))
  expect_true(any(grepl("if (rmbl_barrier_depth == 0) rmbl_raise_interrupt();", b, fixed = TRUE)))
  # the flag is cleared after the try block, before any longjmp
  i <- grep("every path leaves the flag clear", b, fixed = TRUE)
  expect_length(i, 1L)
  expect_true(any(grepl("rmbl_kernel_interrupted = 0;", b[i + (1:3)], fixed = TRUE)))
})

test_that("R code opens no network connection outside the compiled transport", {
  d <- r_dir()
  skip_if(is.na(d), "package sources not available from here")
  # under covr the installed package has an R/ directory with no sources in it
  files <- list.files(d, pattern = "[.]R$", full.names = TRUE)
  skip_if(!length(files), "no R sources found")
  pat <- paste0("(^|[^a-zA-Z_.])(base::)?url\\(|download\\.file\\(|curl::|",
                "file\\(\"https?://|readLines\\(\"https?://|gzcon\\(url")
  hits <- as.character(unlist(lapply(files, function(f) {
    l <- readLines(f, warn = FALSE)
    code <- sub("#.*$", "", l)          # not the comments
    code <- code[!grepl("^\\s*#'", l)]  # nor roxygen
    i <- grep(pat, code, perl = TRUE)
    if (length(i)) paste0(basename(f), ": ", trimws(code[i])) else character(0)
  })))
  # the two base-R fallbacks exist for a capsule bundle that copies one file
  # out of the package; inside the package `exists()` routes past them
  allowed <- c(
    "lib_data_loader.R: utils::download.file(url, dest, mode = \"wb\", quiet = FALSE)",
    "lib_helpers.R: utils::download.file(url, dest, mode = \"wb\", quiet = TRUE)"
  )
  expect_setequal(hits, allowed)
})

test_that("every SIU entry point reads its text through the same cap", {
  d <- src_dir()
  skip_if(is.na(d), "package sources not available from here")
  s <- readLines(file.path(d, "rmbl_siu.cpp"), warn = FALSE)
  entries <- grep("^SEXP C_rmbl_siu_[a-z_]+_impl\\(SEXP [a-z]+\\)", s)
  # the enumeration, not a floor (a fifth string entry lands here by itself)
  expect_setequal(sub("^SEXP (C_rmbl_siu_[a-z_]+)_impl.*$", "\\1", s[entries]),
                  c("C_rmbl_siu_html_to_text", "C_rmbl_siu_parse_html", "C_rmbl_siu_to_iso_date",
                    "C_rmbl_siu_resolve_so", "C_rmbl_siu_schema"))
  # each one-argument entry hands its argument to as_string() (the 2 MiB
  # cap) and nothing else reads CHAR() of it
  expect_identical(sum(grepl("CHAR(STRING_ELT", s, fixed = TRUE)), 1L)
  expect_true(any(grepl("(2 << 20)", s, fixed = TRUE)))
  # html_to_text() and the plain-text entry both run normalize_text()
  p <- readLines(file.path(d, "siu_parse.cpp"), warn = FALSE)
  expect_true(any(grepl("return normalize_text(t);", p, fixed = TRUE)))
  expect_true(any(grepl("siu::normalize_text(as_string(text", s, fixed = TRUE)))
  # and no whole-document pass is a regex any more
  h <- p[grep("^std::string html_to_text", p):grep("return normalize_text(t);", p, fixed = TRUE)]
  expect_false(any(grepl("std::regex", h, fixed = TRUE)))
  # No regex in EITHER SIU file may cross a line without a bound: a `[^...]` class that
  # does not exclude \\n or \\s, or `[\\s\\S]`, followed by `*`, `+` or `{n,}`, recurses once
  # per character of the whole document and the line cap cannot stop it (the SIU
  # review found two in siu_resolve.cpp after 0.5.8 hardened siu_parse.cpp only).
  rs <- readLines(file.path(d, "siu_resolve.cpp"), warn = FALSE)
  # code only: the comments quote the regexes they replaced
  src <- gsub("/\\*.*?\\*/", "", sub("//.*$", "", c(p, rs)))
  classes <- unlist(regmatches(src, gregexpr("\\[\\^[^]]*\\](\\*|\\+|\\{[0-9]*,\\})", src)))
  # a class that excludes \\n or \\s is bounded by the line
  bad <- classes[!(grepl("\\n", classes, fixed = TRUE) | grepl("\\s", classes, fixed = TRUE))]
  expect_identical(bad, character(0))
  for (q in c("[\\s\\S]*", "[\\s\\S]+", "[\\s\\S]{")) {
    expect_false(any(grepl(q, src, fixed = TRUE)), info = q)
  }
  # the boilerplate stripper is scans (its comments may name the regexes it replaced),
  # and every SIU core pass polls for an interrupt
  code_rs <- sub("//.*$", "", rs)
  strip_fn <- grep("^static std::string strip_boilerplate_impl", rs):grep("^static SoResolution resolve_fr", rs)
  expect_false(any(grepl("std::regex", code_rs[strip_fn], fixed = TRUE)))
  expect_true(any(grepl("siu::interrupt_hook()", s, fixed = TRUE)))
})
