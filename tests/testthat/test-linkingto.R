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

# The consumer the first test builds is reused by the second (the interrupt probe), which
# removes both directories when it is done.
consumer_dir <- file.path(tempdir(), paste0("rmblconsume", Sys.getpid()))
consumer_lib <- file.path(tempdir(), paste0("rmbllib", Sys.getpid()))

test_that("every published kernel compiles and resolves from a consumer", {
  skip_on_cran()
  # Windows is skipped deliberately, and the reason is not squeamishness
  # about the platform. This test builds a PACKAGE from inside a running
  # R CMD check, and that nesting is what is fragile: the sub-build has
  # to resolve LinkingTo against the check's own library, Rtools has to
  # be on the sub-process's path, and multiarch has to be suppressed.
  # None of that is what the test is about. The invariant it protects --
  # that the header compiles and that every registered name resolves --
  # is not platform-specific, and it is checked on Linux and macOS,
  # where it has already caught a real defect. Keeping it on Windows
  # bought three red CI runs and no information.
  skip_on_os("windows")
  skip_if(Sys.getenv("R_TESTS_NO_COMPILE") != "", "compilation disabled")
  skip_if(!nzchar(Sys.which("R")), "no R on the path")
  inc <- system.file("include", package = "rmoriebricklayer")
  skip_if(
    !nzchar(inc) || !file.exists(file.path(
      inc,
      "rmoriebricklayer.h"
    )),
    "package not installed with its include directory"
  )

  dir <- consumer_dir
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
  writeLines(
    c(
      "useDynLib(rmblconsume, .registration = TRUE)",
      "import(rmoriebricklayer)",
      "export(consume_series)",
      "export(consume_mk)"
    ),
    file.path(dir, "NAMESPACE")
  )
  writeLines(
    c("consume_series <- function() .Call(C_consume_series)",
      "consume_mk <- function(y) .Call(C_consume_mk, as.double(y))"),
    file.path(dir, "R", "consume.R")
  )

  # Deliberately a .c file, not .cpp: the header must be usable from
  # plain C, which is what most consumers compile. Every one of the 45
  # shims is called (the two libcurl ones need a network, so their
  # addresses are taken, which instantiates and resolves them).
  writeLines(c(
    "#include <R.h>",
    "#include <Rinternals.h>",
    "#include <R_ext/Rdynload.h>",
    "#include <string.h>",
    "#include <rmoriebricklayer.h>",
    "",
    "SEXP C_consume_series(void) {",
    "    const double x[6] = {1.0, 2.0, 3.0, 4.0, 5.0, 9.0};",
    "    const double y[6] = {2.0, 1.0, 4.0, 3.0, 6.0, 5.0};",
    "    const double w[6] = {1.0, 1.0, 2.0, 2.0, 1.0, 1.0};",
    "    const double treat[6] = {1, 0, 1, 0, 1, 0};",
    "    const double prop[6] = {0.6, 0.4, 0.7, 0.3, 0.5, 0.5};",
    "    const double probs[2] = {0.25, 0.75};",
    "    const double pp[3] = {0.2, 0.3, 0.5}, qq[3] = {0.3, 0.3, 0.4};",
    "    const double hpar[3] = {0.5, 0.3, 1.0};",
    "    double out[64], tmp[64], pop[8], val[8], ma[8], mb[8], mm[8];",
    "    double S = 0, var = 0, slope = 0, icpt = 0, d = 0;",
    "    R_xlen_t units = 0, used = 0, npts = 0;",
    "    unsigned char raw32[32], raw64[64];",
    "    char hex[129];",
    "    int k = 0;",
    "    out[k++] = rmbl_mean(x, 6);",
    "    out[k++] = rmbl_mean_running(x, 6);",
    "    out[k++] = rmbl_var(x, 6);",
    "    out[k++] = rmbl_cor_pearson(x, y, 6);",
    "    out[k++] = rmbl_normal_pdf(0.5, 0.0, 1.0);",
    "    rmbl_sha256_hex((const unsigned char *) \"abc\", 3, hex);",
    "    out[k++] = (double) strlen(hex);",
    "    out[k++] = rmbl_sd(x, 6, 1);",
    "    out[k++] = rmbl_euclid_dist(x, y, 6);",
    "    out[k++] = rmbl_normal_logpdf(0.5, 0.0, 1.0);",
    "    rmbl_ipw_weights(treat, prop, 6, 0.05, 0.95, tmp);",
    "    out[k++] = tmp[0] + tmp[5];",
    "    rmbl_bootstrap_mean(x, 6, 10, 42ULL, tmp);",
    "    out[k++] = tmp[0];",
    "    out[k++] = rmbl_gamma_cdf(2.0, 1.5);",
    "    out[k++] = rmbl_hawkes_nll(x, 6, 10.0, 0, hpar, 3);",
    "    rmbl_moments(x, 6, tmp);",
    "    out[k++] = tmp[0];",
    "    rmbl_quantile(x, 6, probs, 2, tmp);",
    "    out[k++] = tmp[0] + tmp[1];",
    "    out[k++] = rmbl_median(x, 6);",
    "    out[k++] = rmbl_gini(x, 6);",
    "    out[k++] = rmbl_top_share(x, 6, 0.4, &units) + (double) units;",
    "    npts = rmbl_lorenz(x, 6, pop, val);",
    "    out[k++] = (double) npts + val[npts - 1];",
    "    rmbl_mann_kendall(x, 6, &S, &var, &used);",
    "    out[k++] = S + var + (double) used;",
    "    rmbl_theil_sen(x, y, 6, &slope, &icpt);",
    "    out[k++] = slope + icpt;",
    "    out[k++] = rmbl_hurwitz_zeta(2.0, 1.0);",
    "    out[k++] = rmbl_mad(x, 6, 1.4826);",
    "    out[k++] = rmbl_trimmed_mean(x, 6, 0.2);",
    "    out[k++] = rmbl_winsorized_mean(x, 6, 0.2);",
    "    out[k++] = rmbl_weighted_mean(x, w, 6);",
    "    out[k++] = rmbl_weighted_var(x, w, 6);",
    "    out[k++] = rmbl_cor_spearman(x, y, 6);",
    "    rmbl_midranks(y, 6, tmp);",
    "    out[k++] = tmp[0] + tmp[5];",
    "    rmbl_cov_matrix(x, 3, 2, tmp);",
    "    out[k++] = tmp[0];",
    "    d = rmbl_ks_two_sample(x, 6, y, 6);",
    "    out[k++] = d;",
    "    out[k++] = rmbl_ks_pvalue(d, 3.0);",
    "    out[k++] = rmbl_psi(pp, qq, 3, 1e-6);",
    "    out[k++] = rmbl_js_divergence(pp, qq, 3);",
    "    rmbl_sha256_raw((const unsigned char *) \"abc\", 3, raw32);",
    "    out[k++] = (double) raw32[0];",
    "    rmbl_sha512_hex((const unsigned char *) \"abc\", 3, hex);",
    "    out[k++] = (double) strlen(hex);",
    "    rmbl_hmac_sha256_hex((const unsigned char *) \"Jefe\", 4,",
    "                         (const unsigned char *) \"what do ya want for nothing?\", 28, hex);",
    "    out[k++] = (double) strlen(hex);",
    "    out[k++] = (double) rmbl_digest_equal(\"abc\", \"abc\", 3) + 10.0 * rmbl_digest_equal(\"abc\", \"abd\", 3);",
    "    rmbl_moments_acc(x, 3, ma);",
    "    rmbl_moments_acc(x + 3, 3, mb);",
    "    rmbl_moments_merge(ma, mb, mm);",
    "    out[k++] = mm[0];",
    "    out[k++] = (double) rmbl_blake2b((const unsigned char *) \"abc\", 3, NULL, 0, 32, raw32) + raw32[0];",
    "    rmbl_pbkdf2_sha256((const unsigned char *) \"password\", 8,",
    "                       (const unsigned char *) \"salt\", 4, 1, 20, raw64);",
    "    out[k++] = (double) raw64[0];",
    "    out[k++] = (double) rmbl_os_random(raw32, 32);",
    "    {",
    "        /* called, not merely address-taken: an unresolvable host fails fast",
    "         * and offline, which is the path a misregistered name would break */",
    "        char snap[64];",
    "        int code = rmbl_fetch_with_fallback(\"https://invalid.invalid/x\", \"\", \"/nonexistent/dir/x\", 2);",
    "        int sn = rmbl_wayback_snapshot(\"https://invalid.invalid/x\", snap, (int) sizeof snap, 2);",
    "        out[k++] = (code < 0) + (sn == 0);",
    "    }",
    "    {",
    "        /* the Weibull, Lomax and gamma kernels take (a0, eta, p1, p2); an",
    "         * infeasible set answers the 1e12 sentinel and too few parameters NaN */",
    "        const double wpar[4] = {0.5, 0.3, 1.5, 2.0};",
    "        const double lpar[4] = {0.5, 0.3, 2.5, 1.0};",
    "        const double gpar[4] = {0.5, 0.3, 1.5, 0.8};",
    "        const double bad[4] = {0.5, 5.0, 1.5, 2.0};",
    "        const double xn[2] = {1.0, R_NaN};",
    "        const double xi[2] = {1.0, R_PosInf};",
    "        out[k++] = rmbl_hawkes_nll(x, 6, 10.0, 1, wpar, 4);",
    "        out[k++] = rmbl_hawkes_nll(x, 6, 10.0, 2, lpar, 4);",
    "        out[k++] = rmbl_hawkes_nll(x, 6, 10.0, 3, gpar, 4);",
    "        out[k++] = rmbl_hawkes_nll(x, 6, 10.0, 1, bad, 4) + rmbl_hawkes_nll(x, 6, 10.0, 3, bad, 4);",
    "        out[k++] = rmbl_hawkes_nll(x, 6, 10.0, 1, hpar, 3);",
    "        rmbl_quantile(xn, 2, probs, 2, tmp);",
    "        out[k++] = ISNAN(tmp[0]) && ISNAN(tmp[1]);",
    "        rmbl_cov_matrix(x, 1, 2, tmp);",
    "        out[k++] = ISNAN(tmp[0]) && ISNAN(tmp[3]);",
    "        out[k++] = ISNAN(rmbl_ks_two_sample(xn, 2, y, 6));",
    "        out[k++] = rmbl_mean(xi, 2) == R_PosInf;",
    "        /* PBKDF2's int channel: 0 with the key written, -1 for an invalid argument */",
    "        out[k++] = (double) rmbl_pbkdf2_sha256((const unsigned char *) \"password\", 8,",
    "                                               (const unsigned char *) \"salt\", 4, 1, 20, raw64)",
    "                 + 10.0 * (rmbl_pbkdf2_sha256((const unsigned char *) \"password\", 8,",
    "                                              (const unsigned char *) \"salt\", 4, 0, 20, raw64) == -1);",
    "    }",
    "    SEXP res = PROTECT(Rf_allocVector(REALSXP, k));",
    "    for (int i = 0; i < k; ++i) REAL(res)[i] = out[i];",
    "    rmbl_sha256_hex((const unsigned char *) \"abc\", 3, hex);",
    "    SEXP s = PROTECT(Rf_mkString(hex));",
    "    Rf_setAttrib(res, Rf_install(\"sha256_abc\"), s);",
    "    UNPROTECT(2);",
    "    return res;",
    "}",
    "",
    "/* the Mann-Kendall kernel on a caller-sized series, with no bricklayer barrier on",
    " * the stack: the path the interrupt probe below exercises */",
    "SEXP C_consume_mk(SEXP y) {",
    "    double S = 0, var = 0;",
    "    R_xlen_t used = 0;",
    "    rmbl_mann_kendall(REAL(y), XLENGTH(y), &S, &var, &used);",
    "    return Rf_ScalarReal(S);",
    "}",
    "",
    "static const R_CallMethodDef CallEntries[] = {",
    "    {\"C_consume_series\", (DL_FUNC) &C_consume_series, 0},",
    "    {\"C_consume_mk\", (DL_FUNC) &C_consume_mk, 1},",
    "    {NULL, NULL, 0}",
    "};",
    "",
    "void R_init_rmblconsume(DllInfo *dll) {",
    "    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);",
    "    R_useDynamicSymbols(dll, FALSE);",
    "}"
  ), file.path(dir, "src", "consume.c"))

  lib <- consumer_lib
  dir.create(lib, showWarnings = FALSE)
  out <- suppressWarnings(system2(
    file.path(R.home("bin"), "R"),
    c(
      "CMD", "INSTALL", paste0("--library=", shQuote(lib)),
      "--no-docs", shQuote(dir)
    ),
    stdout = TRUE, stderr = TRUE
  ))
  status <- attr(out, "status")
  # A compile failure here IS the finding, so show it rather than
  # skipping past it.
  if (!is.null(status) && status != 0L) {
    fail(paste(
      "the consumer package did not build:",
      paste(utils::tail(out, 25L), collapse = "\n")
    ))
  }
  expect_true(dir.exists(file.path(lib, "rmblconsume")))

  # Now CALL it. Everything above would pass with a misregistered name.
  # writeLines rather than cat with an escaped newline: the escape has
  # to survive R quoting it, the shell quoting it, and R parsing it
  # again, and one of those layers eats it.
  code <- paste(
    sprintf(".libPaths(c(%s, .libPaths()))", shQuote(lib)),
    "library(rmblconsume)",
    # loaded by the Imports above, but make the dependency explicit so a
    # failure here is unambiguous
    'stopifnot("rmoriebricklayer" %in% loadedNamespaces())',
    "r <- consume_series()",
    'writeLines(paste(sprintf("%.17g", r), collapse=","))',
    'writeLines(attr(r, "sha256_abc"))',
    sep = "; "
  )
  res <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"),
    c("-e", shQuote(code)),
    stdout = TRUE, stderr = TRUE
  ))
  st <- attr(res, "status")
  if (!is.null(st) && st != 0L) {
    fail(paste(
      "the consumer built but could not call the kernels:",
      paste(utils::tail(res, 25L), collapse = "\n")
    ))
    return(invisible(NULL))
  }
  # If the output is not the two lines expected, say what it WAS.
  # "Execution halted" reported as an unexpected digest tells the reader
  # nothing about the cause.
  if (length(res) < 2L) {
    fail(paste(
      "unexpected output from the consumer:",
      paste(res, collapse = " | ")
    ))
    return(invisible(NULL))
  }
  # %.17g round-trips a binary64 exactly, so the comparisons below can
  # be identities rather than tolerances
  nums <- suppressWarnings(
    as.numeric(strsplit(trimws(res[length(res) - 1L]), ",")[[1L]])
  )
  sha <- trimws(res[length(res)])
  if (length(nums) != 53L) {
    fail(paste(
      "the consumer did not print 53 numbers; it printed:",
      paste(utils::tail(res, 10L), collapse = " | ")
    ))
    return(invisible(NULL))
  }
  expect_length(nums, 53L)

  # the kernels must agree with the R-level functions on the same input,
  # because they are supposed to be the same code
  x <- c(1, 2, 3, 4, 5, 9)
  y <- c(2, 1, 4, 3, 6, 5)
  expect_equal(nums[1L], mean(x))
  expect_equal(nums[2L], mean(x))
  expect_equal(nums[3L], stats::var(x))
  expect_equal(nums[4L], stats::cor(x, y))
  expect_equal(nums[5L], stats::dnorm(0.5))
  expect_equal(nums[6L], 64)
  expect_equal(nums[7L], stats::sd(x))
  expect_equal(nums[8L], sqrt(sum((x - y)^2)))
  expect_equal(nums[9L], stats::dnorm(0.5, log = TRUE))
  expect_equal(nums[12L], stats::pgamma(1.5, 2))
  expect_equal(nums[14L], mean(x))
  expect_equal(nums[16L], stats::median(x))
  expect_equal(nums[17L], gini(x))
  expect_equal(nums[22L], pi^2 / 6, tolerance = 1e-13)
  expect_equal(nums[23L], stats::mad(x))
  expect_equal(nums[24L], mean(x, trim = 0.2))
  expect_equal(nums[26L], stats::weighted.mean(x, c(1, 1, 2, 2, 1, 1)))
  expect_equal(nums[28L], stats::cor(x, y, method = "spearman"))
  expect_equal(nums[35L], 0xba)
  expect_equal(nums[36L], 128)
  expect_equal(nums[37L], 64)
  expect_equal(nums[38L], 1)
  expect_equal(nums[39L], 6)
  expect_equal(nums[42L], 0)   # rmbl_os_random succeeded
  expect_equal(nums[43L], 2)   # both libcurl shims resolved
  # the Hawkes likelihood takes the kernel's own parameter layout; only
  # that it answered is asserted here, the value is pinned elsewhere
  expect_true(all(is.finite(nums[-c(13L, 48L)])))
  # the three O(n^2) kernels against the same formulas written out in R
  t6 <- x
  hk <- function(dens, comp, p) {
    nu <- exp(p[1])
    s <- vapply(seq_along(t6), function(i) {
      if (i == 1L) return(0)
      sum(dens(t6[i] - t6[seq_len(i - 1L)]))
    }, numeric(1))
    -(sum(log(nu + p[2] * s)) - nu * 10 - p[2] * sum(comp(10 - t6)))
  }
  wb <- c(0.5, 0.3, 1.5, 2.0)
  expect_equal(nums[44L], hk(
    function(u) (wb[3] / wb[4]) * (u / wb[4])^(wb[3] - 1) * exp(-(u / wb[4])^wb[3]),
    function(u) 1 - exp(-(u / wb[4])^wb[3]), wb))
  lx <- c(0.5, 0.3, 2.5, 1.0)
  expect_equal(nums[45L], hk(
    function(u) (lx[3] - 1) * lx[4]^(lx[3] - 1) / (u + lx[4])^lx[3],
    function(u) 1 - (lx[4] / (u + lx[4]))^(lx[3] - 1), lx))
  gm <- c(0.5, 0.3, 1.5, 0.8)
  expect_equal(nums[46L], hk(
    function(u) stats::dgamma(u, shape = gm[3], rate = gm[4]),
    function(u) stats::pgamma(u, shape = gm[3], rate = gm[4]), gm))
  expect_identical(nums[47L], 2e12)      # eta = 5 is infeasible for both kernels
  expect_true(is.nan(nums[48L]))         # three parameters where four are needed
  expect_identical(nums[49:52], c(1, 1, 1, 1))
  expect_identical(nums[53L], 10)         # pbkdf2: 0 on success, -1 on iterations = 0
  # and the digest kernel still matches its published vector, so a
  # regression in the older shims surfaces here too
  expect_identical(sha, core_sha256("abc"))
  expect_identical(
    sha, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  )
})

test_that("a pending interrupt stops the Mann-Kendall kernel called with no barrier (D2)", {
  skip_on_cran()
  skip_on_os("windows")
  on.exit(unlink(c(consumer_dir, consumer_lib), recursive = TRUE), add = TRUE)
  skip_if(!dir.exists(file.path(consumer_lib, "rmblconsume")), "the consumer was not built")
  skip_if(!nzchar(Sys.which("python3")) || !nzchar(Sys.which("timeout")), "no python3/timeout")
  # Another package's .Call reaches rmbl_mann_kendall() with none of bricklayer's barriers
  # active, so there is nothing to raise after the kernel returns: mann_kendall_inner() has
  # to answer its sentinel on the poll, let its buffers go, and only then raise R's interrupt
  # (0.5.8 raised from inside the poll, over live std::vectors -- the 0.5.8 diff review).
  # 120k points keep the pair loop busy for many seconds unless the poll (every 512 rows)
  # sees the signal; the probe child has SIGINT reset to the default, so it is conclusive
  # where this process inherited SIGINT as ignored (a background chain, covr).
  got <- interrupt_probe(paste0(
    ".libPaths(c(", shQuote(consumer_lib), ", .libPaths())); library(rmblconsume);",
    " consume_mk(as.numeric(seq_len(120000L)) + rep(c(0.5, -0.5), 60000L))"))
  skip_if(startsWith(got, "inconclusive"), got)
  expect_identical(got, "interrupt")
})
