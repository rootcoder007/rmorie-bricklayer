# The LinkingTo header, exercised the only way that proves it works:
# by building a package against it and CALLING every shim.
#
# The two halves fail independently. A signature mismatch is a compile
# error, which a consumer sees at build time. A wrong name in
# R_RegisterCCallable compiles perfectly and raises only when the shim
# is first called, because R_GetCCallable resolves lazily. A header that
# has only ever been compiled against is a header that has only been
# half checked -- and bricklayer exists to be reached this way, so the
# sibling packages are the ones that would find out.

test_that("every published kernel compiles and resolves from a consumer", {
  skip_on_cran()
  skip_if(Sys.getenv("R_TESTS_NO_COMPILE") != "", "compilation disabled")
  skip_if(!nzchar(Sys.which("R")), "no R on the path")
  inc <- system.file("include", package = "rmoriebricklayer")
  skip_if(!nzchar(inc) || !file.exists(file.path(inc,
                                                 "rmoriebricklayer.h")),
          "package not installed with its include directory")

  dir <- file.path(tempdir(), paste0("rmblconsume", Sys.getpid()))
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  dir.create(file.path(dir, "src"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(dir, "R"), recursive = TRUE, showWarnings = FALSE)

  writeLines(c(
    "Package: rmblconsume",
    "Title: Compile And Run Every LinkingTo Kernel",
    "Version: 0.0.1",
    "Authors@R: person('Test', 'Harness', role = c('aut', 'cre'),",
    "    email = 'noreply@example.com')",
    "Description: Throwaway consumer used by rmoriebricklayer's own tests.",
    "License: AGPL-3",
    "Encoding: UTF-8",
    # LinkingTo alone is NOT enough. It puts the header on the include
    # path at compile time, but the shims resolve lazily through
    # R_GetCCallable on first call, and that requires the providing
    # package's DLL to be LOADED. Without Imports the consumer builds
    # and then raises "function 'rmbl_gini' not provided by package
    # 'rmoriebricklayer'" the first time a kernel is touched. A real
    # consumer (rmorie) imports it, so the harness must too.
    "Imports: rmoriebricklayer",
    "LinkingTo: rmoriebricklayer"
  ), file.path(dir, "DESCRIPTION"))
  writeLines(c("useDynLib(rmblconsume, .registration = TRUE)",
               "import(rmoriebricklayer)",
               "export(consume_series)"),
             file.path(dir, "NAMESPACE"))
  writeLines("consume_series <- function() .Call(C_consume_series)",
             file.path(dir, "R", "consume.R"))

  # Deliberately a .c file, not .cpp: the header must be usable from
  # plain C, which is what most consumers compile.
  writeLines(c(
    "#include <R.h>",
    "#include <Rinternals.h>",
    "#include <R_ext/Rdynload.h>",
    "#include <rmoriebricklayer.h>",
    "",
    "SEXP C_consume_series(void) {",
    "    const double x[5] = {1.0, 2.0, 3.0, 4.0, 5.0};",
    "    double g = rmbl_gini(x, 5);",
    "    R_xlen_t units = 0;",
    "    double ts = rmbl_top_share(x, 5, 0.4, &units);",
    "    double pop[6], val[6];",
    "    R_xlen_t npts = rmbl_lorenz(x, 5, pop, val);",
    "    double S = 0.0, var = 0.0; R_xlen_t used = 0;",
    "    rmbl_mann_kendall(x, 5, &S, &var, &used);",
    "    double slope = 0.0, intercept = 0.0;",
    "    rmbl_theil_sen(x, x, 5, &slope, &intercept);",
    "    double z2 = rmbl_hurwitz_zeta(2.0, 1.0);",
    "    double m = rmbl_mean(x, 5);",
    "    double md = rmbl_median(x, 5);",
    "    char sha[65];",
    "    rmbl_sha256_hex((const unsigned char *) \"abc\", 3, sha);",
    "    SEXP out = PROTECT(Rf_allocVector(REALSXP, 12));",
    "    REAL(out)[0] = g;",
    "    REAL(out)[1] = ts;",
    "    REAL(out)[2] = (double) units;",
    "    REAL(out)[3] = (double) npts;",
    "    REAL(out)[4] = val[5];",
    "    REAL(out)[5] = S;",
    "    REAL(out)[6] = var;",
    "    REAL(out)[7] = slope;",
    "    REAL(out)[8] = intercept;",
    "    REAL(out)[9] = z2;",
    "    REAL(out)[10] = m;",
    "    REAL(out)[11] = md;",
    "    SEXP s = PROTECT(Rf_mkString(sha));",
    "    Rf_setAttrib(out, Rf_install(\"sha256_abc\"), s);",
    "    UNPROTECT(2);",
    "    return out;",
    "}",
    "",
    "static const R_CallMethodDef CallEntries[] = {",
    "    {\"C_consume_series\", (DL_FUNC) &C_consume_series, 0},",
    "    {NULL, NULL, 0}",
    "};",
    "",
    "void R_init_rmblconsume(DllInfo *dll) {",
    "    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);",
    "    R_useDynamicSymbols(dll, FALSE);",
    "}"
  ), file.path(dir, "src", "consume.c"))

  lib <- file.path(tempdir(), paste0("rmbllib", Sys.getpid()))
  dir.create(lib, showWarnings = FALSE)
  on.exit(unlink(lib, recursive = TRUE), add = TRUE)
  out <- suppressWarnings(system2(
    file.path(R.home("bin"), "R"),
    c("CMD", "INSTALL", paste0("--library=", shQuote(lib)),
      "--no-docs", shQuote(dir)),
    stdout = TRUE, stderr = TRUE))
  status <- attr(out, "status")
  # A compile failure here IS the finding, so show it rather than
  # skipping past it.
  if (!is.null(status) && status != 0L) {
    fail(paste("the consumer package did not build:",
               paste(utils::tail(out, 25L), collapse = "\n")))
  }
  expect_true(dir.exists(file.path(lib, "rmblconsume")))

  # Now CALL it. Everything above would pass with a misregistered name.
  # writeLines rather than cat with an escaped newline: the escape has
  # to survive R quoting it, the shell quoting it, and R parsing it
  # again, and one of those layers eats it.
  code <- paste(
    sprintf('.libPaths(c(%s, .libPaths()))', shQuote(lib)),
    'library(rmblconsume)',
    # loaded by the Imports above, but make the dependency explicit so a
    # failure here is unambiguous
    'stopifnot("rmoriebricklayer" %in% loadedNamespaces())',
    'r <- consume_series()',
    'writeLines(paste(sprintf("%.17g", r), collapse=","))',
    'writeLines(attr(r, "sha256_abc"))',
    sep = "; ")
  res <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"),
                                  c("-e", shQuote(code)),
                                  stdout = TRUE, stderr = TRUE))
  st <- attr(res, "status")
  if (!is.null(st) && st != 0L) {
    fail(paste("the consumer built but could not call the kernels:",
               paste(utils::tail(res, 25L), collapse = "\n")))
  }
  # %.17g round-trips a binary64 exactly, so the comparisons below can
  # be identities rather than tolerances
  nums <- as.numeric(strsplit(trimws(res[length(res) - 1L]), ",")[[1L]])
  sha <- trimws(res[length(res)])
  expect_length(nums, 12L)

  # and the kernels must agree with the R-level functions on the same
  # input, because they are supposed to be the same code
  x <- c(1, 2, 3, 4, 5)
  expect_equal(nums[1L], gini(x))
  expect_equal(nums[2L], top_share(x, 0.4)$share)
  expect_equal(nums[3L], as.numeric(top_share(x, 0.4)$units))
  expect_equal(nums[4L], nrow(lorenz(x)))
  expect_equal(nums[5L], 1)
  mk <- .Call(C_rmbl_mann_kendall, x)
  expect_equal(nums[6L], mk$S)
  expect_equal(nums[7L], mk$var)
  # a perfectly linear series has slope one through the origin
  expect_equal(nums[8L], 1)
  expect_equal(nums[9L], 0)
  expect_equal(nums[10L], pi^2 / 6, tolerance = 1e-13)
  expect_identical(nums[10L], hurwitz_zeta(2))
  expect_equal(nums[11L], core_mean(x))
  expect_equal(nums[12L], core_median(x))
  # and the digest kernel still matches its published vector, so a
  # regression in the older shims surfaces here too
  expect_identical(sha, core_sha256("abc"))
  expect_identical(
    sha, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
})
