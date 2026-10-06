# Third review of the hardening work (rmoriebricklayer_0.5.7_stress_2026-10-06.md).
# Each finding below is fixed at every site of its kind, and where the
# siblings can be enumerated the test enumerates them itself, so a new one
# cannot appear without this file noticing.

C <- function(nm) get(nm, envir = asNamespace("rmoriebricklayer"))

test_that("N1: hostile text through EVERY one-string SIU entry point returns, in another process", {
  skip_on_cran()
  ns <- asNamespace("rmoriebricklayer")
  syms <- ls(ns, pattern = "^C_rmbl_siu_")
  entries <- Filter(function(s) {
    obj <- get(s, envir = ns)
    inherits(obj, "NativeSymbolInfo") && identical(obj$numParameters, 1L)
  }, syms)
  # the enumeration is the point: a fifth sibling lands in this list by itself
  expect_setequal(entries, c("C_rmbl_siu_html_to_text", "C_rmbl_siu_parse_html",
                             "C_rmbl_siu_resolve_so", "C_rmbl_siu_schema",
                             "C_rmbl_siu_to_iso_date"))
  inputs <- c(
    spaces = 'strrep(" ", 3e5)',
    letters = 'strrep("a", 3e5)',
    open_tag = 'paste0("<", strrep("a", 3e5))',
    entity = 'paste0("&#", strrep("9", 1e5), ";")',
    newlines = 'strrep("\\n", 3e5)',
    paragraphs = 'strrep("<p>x", 1e5)',
    ampersands = 'strrep("&amp;", 1e5)',
    script = 'paste0("<script>", strrep("x", 3e5))',
    nbsp = 'strrep("\\u00a0", 2e5)',
    date_words = 'strrep("January 5, 2023 ", 2e4)',
    # the fuzzer's find: std::stoi on a \\d+ capture past INT_MAX aborted the process
    tag_overflow = 'paste0("Subject Officials\\nSO\\n#", strrep("4", 30),
                           "\\nWitness Officials\\nWO #", strrep("9", 12))'
  )
  for (e in entries) {
    scr <- tempfile(fileext = ".R")
    writeLines(c(
      "suppressMessages(library(rmoriebricklayer))",
      sprintf('f <- get("%s", envir = asNamespace("rmoriebricklayer"))', e),
      sprintf("inputs <- list(%s)", paste(sprintf("%s = %s", names(inputs), inputs), collapse = ", ")),
      "for (nm in names(inputs)) {",
      '  r <- tryCatch({ .Call(f, inputs[[nm]]); "returned" }, error = function(z) "error")',
      '  cat("CASE", nm, r, "\\n")',
      "}",
      'cat("SESSION SURVIVED\\n")'
    ), scr)
    out <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"), shQuote(scr),
                                    stdout = TRUE, stderr = TRUE, timeout = 600))
    expect_true(any(grepl("SESSION SURVIVED", out, fixed = TRUE)),
                info = paste(e, paste(utils::tail(out[nzchar(out)], 3), collapse = " | ")))
    expect_identical(sum(grepl("^CASE ", out)), length(inputs), info = e)
  }
  # in-process, the exported wrappers on the reproducer's own input
  expect_identical(bricklayer_siu_text(strrep(" ", 25000)), " ")
  expect_type(bricklayer_parse_siu(strrep(" ", 25000)), "character")
  # an absurd tag number is noise, not a count, and the bare mention still counts one
  f <- bricklayer_parse_siu(paste0("Subject Officials\nSO\n#", strrep("4", 30), "\nCivilian Witnesses\nCW #2\n"))
  expect_identical(unname(f["number_of_subject_officials"]), "1")
  expect_identical(unname(f["number_of_civilian_witnesses"]), "2")
  # the loops give the same text as the regex passes they replaced: the
  # reference below is the 0.5.7 pipeline, written with R's PCRE
  ref_text <- function(h) {
    t <- gsub("\r\n?", "\n", h, perl = TRUE)
    t <- gsub("(?is)<(script|style)[^>]*>[\\s\\S]*?</\\1>", " ", t, perl = TRUE)
    t <- gsub("(?i)</(p|div|h[1-6]|tr|li|br)>|<br\\s*/?>", "\n", t, perl = TRUE)
    t <- gsub("<[^>]+>", " ", t, perl = TRUE)
    t <- gsub("&nbsp;", " ", t, fixed = TRUE)
    t <- gsub("&amp;", "&", t, fixed = TRUE)
    t <- gsub("(?i)&#8217;|&rsquo;|&#x2019;", "'", t, perl = TRUE)
    t <- gsub("(?i)&#8216;|&lsquo;|&#x2018;", "'", t, perl = TRUE)
    t <- gsub("(?i)&#8220;|&ldquo;|&#8221;|&rdquo;|&#x201c;|&#x201d;", "\"", t, perl = TRUE)
    t <- gsub("&quot;", "\"", t, fixed = TRUE)
    t <- gsub("&#0?39;|&apos;", "'", t, perl = TRUE)
    t <- gsub("(?i)&#8211;|&ndash;|&#x2013;", "-", t, perl = TRUE)
    t <- gsub("(?i)&#8212;|&mdash;|&#x2014;", "--", t, perl = TRUE)
    named <- c("&eacute;" = "\u00e9", "&egrave;" = "\u00e8", "&ecirc;" = "\u00ea", "&euml;" = "\u00eb",
               "&agrave;" = "\u00e0", "&acirc;" = "\u00e2", "&ccedil;" = "\u00e7", "&icirc;" = "\u00ee",
               "&iuml;" = "\u00ef", "&ocirc;" = "\u00f4", "&ouml;" = "\u00f6", "&ucirc;" = "\u00fb",
               "&ugrave;" = "\u00f9", "&uuml;" = "\u00fc", "&auml;" = "\u00e4", "&copy;" = "\u00a9",
               "&reg;" = "\u00ae", "&Eacute;" = "\u00c9", "&Agrave;" = "\u00c0", "&Egrave;" = "\u00c8",
               "&Ecirc;" = "\u00ca", "&Ccedil;" = "\u00c7", "&Ocirc;" = "\u00d4", "&Icirc;" = "\u00ce",
               "&Acirc;" = "\u00c2", "&laquo;" = "\u00ab", "&raquo;" = "\u00bb", "&oelig;" = "\u0153",
               "&OElig;" = "\u0152", "&thinsp;" = " ")
    for (nm in names(named)) t <- gsub(nm, named[[nm]], t, fixed = TRUE)
    t <- gsub("&hellip;|&#8230;", "...", t, perl = TRUE)
    m <- gregexpr("&#(x[0-9A-Fa-f]+|[0-9]+);", t, perl = TRUE)
    regmatches(t, m) <- list(vapply(regmatches(t, m)[[1]], function(e) {
      g <- sub("^&#(.*);$", "\\1", e)
      cp <- if (startsWith(g, "x")) strtoi(substring(g, 2), 16L) else as.numeric(g)
      if (is.na(cp) || cp == 0 || cp > 0x10FFFF) "" else intToUtf8(cp)
    }, ""))
    t <- gsub("&lt;", "<", t, fixed = TRUE)
    t <- gsub("&gt;", ">", t, fixed = TRUE)
    t <- gsub("[ \t]+", " ", t, perl = TRUE)
    t <- gsub(" ?\n ?", "\n", t, perl = TRUE)
    t <- gsub("\n{3,}", "\n\n", t, perl = TRUE)
    enc2utf8(t)
  }
  samples <- list(
    paste0("<html><head><style>p{}</style><script>var x = '<p>';</script></head>",
           "<body><h1>Title</h1>\r\n<p>One&nbsp;two &amp; three&#233;&#xE9;&rsquo;&#8217;</p>",
           "<div>Four<br/>five<BR>six</div>   seven\t\teight\n\n\n\nnine</body></html>"),
    "&lt;b&gt; &amp;amp; &#x1F600; &#0; &#1114112; &apos;&#039; &Eacute;t\u00e9 <br /> x<BR>y <>z <a\nhref=x>q",
    paste(readLines(system.file("extdata", "siu_synthetic_report.html", package = "rmoriebricklayer"),
                    warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  )
  for (h in samples) {
    got <- bricklayer_siu_text(h)
    expect_identical(enc2utf8(got), ref_text(h))
    expect_true(all(nchar(strsplit(got, "\n", fixed = TRUE)[[1]], type = "chars") <= 2000L))
  }
  # a line longer than the cap is broken at a space, so no extractor's regex
  # ever consumes more than kMaxLine characters at once
  long <- paste(rep("word", 1500), collapse = " ")
  out <- bricklayer_siu_text(paste0("<p>", long, "</p>"))
  expect_true(all(nchar(strsplit(out, "\n", fixed = TRUE)[[1]]) <= 2000L))
  expect_identical(trimws(gsub("\n", " ", out, fixed = TRUE)), long)
  expect_error(bricklayer_siu_text(strrep("a", 3e6)), "larger than 2 MiB")
})

test_that("N2: manifest_canonical is one-to-one over objects and arrays, empty keys included", {
  A <- list(k = stats::setNames(list("X"), ""))
  B <- list(k = list("X"))
  expect_identical(as.character(manifest_canonical(A)), "{\"k\":{\"\":\"X\"}}")
  expect_identical(as.character(manifest_canonical(B)), "{\"k\":[\"X\"]}")
  expect_false(identical(manifest_digest(A), manifest_digest(B)))
  key <- fips_keygen("ML-DSA-44")
  att <- capsule_attest(A, key)
  expect_true(capsule_check_attestation(att, A)$ok)
  expect_false(capsule_check_attestation(att, B)$ok)
  # the 0.5.6 case (mixed empty and non-empty names) stays closed
  A2 <- bricklayer_json_from_json("{\"meta\":{\"\":\"X\",\"a\":1},\"results\":{}}", simplifyVector = FALSE)
  B2 <- bricklayer_json_from_json("{\"meta\":{\"1\":\"X\",\"a\":1},\"results\":{}}", simplifyVector = FALSE)
  expect_false(identical(manifest_digest(A2), manifest_digest(B2)))
  # the other door: a named atomic vector is an object, an unnamed one an array
  expect_identical(as.character(manifest_canonical(list(k = c(a = 1, b = 2)))), "{\"k\":{\"a\":1,\"b\":2}}")
  expect_identical(as.character(manifest_canonical(list(k = c(1, 2)))), "{\"k\":[1,2]}")
  expect_false(identical(manifest_digest(list(k = c(a = 1, b = 2))), manifest_digest(list(k = c(1, 2)))))
  # what the parser reads back canonicalises to what was written
  back <- bricklayer_json_from_json("{\"k\":{\"\":\"X\"}}", simplifyVector = FALSE)
  expect_identical(as.character(manifest_canonical(back)), "{\"k\":{\"\":\"X\"}}")
})

test_that("N3: the redirect rule is pure and tested; the download entry refuses before touching the disk", {
  rc <- function(from, to, http = FALSE) .Call(C("C_rmbl_redirect_check"), from, to, http)
  r <- rc("https://a.example.org/x", "https://b.example.org/y")
  expect_true(r$ok)
  expect_true(r$drop_auth)
  r <- rc("https://a.example.org/x", "https://A.example.org/y?z=1")
  expect_true(r$ok)
  expect_false(r$drop_auth)
  r <- rc("https://a.example.org/x", "http://a.example.org/y", http = TRUE)
  expect_false(r$ok)
  expect_identical(r$why, "a redirect from https to plain http is refused")
  r <- rc("https://a.example.org/x", "https://169.254.169.254/latest/meta-data/")
  expect_false(r$ok)
  expect_match(r$why, "local or private")
  r <- rc("https://a.example.org/x", "https://metadata.internal/x")
  expect_false(r$ok)
  expect_match(r$why, "local or internal")
  r <- rc("https://a.example.org/x", "https://user@b.example.org/")
  expect_false(r$ok)
  # the destination is left alone when the URL is refused
  dest <- tempfile()
  writeLines("keep me", dest)
  res <- .Call(C("C_rmbl_http_download"), "https://127.0.0.1/x", dest, 5L, NULL, NULL)
  expect_identical(res$status, -1L)
  expect_match(res$error, "refused")
  expect_identical(readLines(dest), "keep me")
  expect_false(file.exists(paste0(dest, ".rmbl-part")))
  expect_error(.Call(C("C_rmbl_http_download"), "https://a.example.org/x", dest, 5L, NULL, 1),
               "`progress` must be a function or NULL")
  expect_error(.Call(C("C_rmbl_http_download"), "https://a.example.org/x", dest, 5L, 1L, NULL),
               "`headers` must be a character vector or NULL")
  # every R-level entry gates and then uses the C transport: a blocked host
  # is refused before any connection, by name
  expect_error(bricklayer_json_from_json("http://127.0.0.1:1/secret"), "must be an https:// URL")
  expect_error(bricklayer_json_from_json("https://127.0.0.1:1/secret"), "local or private")
  expect_error(download_data("https://10.0.0.1/x", tempfile()), "local or private")
  expect_error(download_data("https://example.org/x", tempfile(), mode = "a"), "`mode` must be")
  expect_error(bricklayer_download("https://example.org/x", tempfile(), headers = "Bearer x", quiet = TRUE),
               "named character vector")
  expect_error(bricklayer_download("https://example.org/x", tempfile(), timeout = 0, quiet = TRUE),
               "at least one second")
  # underscores in a deployed hostname are not a refusal
  expect_identical(.Call(C("C_rmbl_url_check"), "https://my_host.example.org/", FALSE, FALSE), "")
})

test_that("N5: a small ordinary factor gets a verdict; identifiers still do not", {
  set.seed(1)
  for (n in c(10L, 20L, 30L, 100L)) {
    a <- data.frame(g = as.character(sample(5, n, TRUE)))
    b <- data.frame(g = as.character(sample(5, n, TRUE)))
    cd <- capsule_drift(a, b)$columns
    expect_identical(cd$type, "categorical", info = n)
    expect_false(is.na(cd$drifted), info = n)
    expect_true(is.finite(cd$psi), info = n)
  }
  # more distinct values than identifier_levels: an identifier at any size
  ids <- data.frame(id = sprintf("id%04d", 1:500))
  ids2 <- data.frame(id = sprintf("id%04d", 251:750))
  cd <- capsule_drift(ids, ids2)$columns
  expect_identical(cd$type, "identifier")
  expect_true(is.na(cd$drifted))
  # the ratio test applies from a hundred rows a side: 90 values on 240 rows
  x <- data.frame(g = as.character(rep(1:60, 2)))
  y <- data.frame(g = as.character(rep(31:90, 2)))
  expect_identical(capsule_drift(x, y)$columns$type, "identifier")
  # ... and not below it: the same ratio on 40 rows is a categorical column
  x <- data.frame(g = as.character(rep(1:10, 2)))
  y <- data.frame(g = as.character(rep(6:15, 2)))
  expect_identical(capsule_drift(x, y)$columns$type, "categorical")
})

test_that("N6/N7: log_p_value at the fifth chi-square site, and the documented eps bound", {
  set.seed(1)
  X <- data.frame(a = rnorm(200), b = rnorm(200))
  X[1, ] <- c(4000, 4000)
  m <- mahalanobis_outliers(X)
  expect_true("log_p_value" %in% names(m))
  ok <- !is.na(m$p_value) & m$p_value > 0
  expect_equal(m$log_p_value[ok], log(m$p_value[ok]))
  # the planted row: the robust distance keeps its p-value above zero, and
  # the log column is its exact log
  expect_lt(m$p_value[m$row == 1], 1e-30)
  expect_equal(m$log_p_value[m$row == 1], log(m$p_value[m$row == 1]))
  expect_true(all(m$outlier[m$row == 1]))
  # eps is a parameter of the statistic, accepted anywhere in (0, 1) and documented as such
  set.seed(2)
  x <- rnorm(100)
  y <- rnorm(100) + 1
  expect_true(is.finite(drift_psi(x, y, eps = 0.05)[["psi"]]))
  expect_lt(drift_psi(x, y, eps = 0.05)[["psi"]], drift_psi(x, y, eps = 1e-6)[["psi"]])
  expect_error(drift_psi(x, y, eps = 1), "0 < eps < 1")
  expect_error(drift_psi(x, y, eps = 0), "0 < eps < 1")
  rd <- tools::Rd_db("rmoriebricklayer")
  txt <- function(f) {
    paste(utils::capture.output(tools::Rd2txt(rd[[f]], options = list(underline_titles = FALSE))),
          collapse = "\n")
  }
  expect_match(gsub("\\s+", " ", txt("drift_psi.Rd")), "any value in (0, 1)", fixed = TRUE)
  for (f in c("drift_chisq.Rd", "drift_homogeneity.Rd", "benford_test.Rd", "mahalanobis_outliers.Rd")) {
    expect_match(txt(f), "log_p_value", info = f)
  }
})

test_that("the Mann-Kendall exact-distribution memo is bounded", {
  for (i in 1:40) assign(as.character(1000L + i), 1, envir = .rmbl_mk_cache)
  # an entry other tests may already have cached would return before the
  # eviction; drop it so this call computes and stores
  if (exists("4", envir = .rmbl_mk_cache, inherits = FALSE)) rm("4", envir = .rmbl_mk_cache)
  .rmbl_mk_exact(4L)
  expect_lt(length(ls(.rmbl_mk_cache)), 40L)
  expect_true("4" %in% ls(.rmbl_mk_cache))
  # the tied-values memo shares the bound
  for (i in 1:40) assign(as.character(2000L + i), 1, envir = .rmbl_mk_cache)
  .rmbl_mk_exact_values(c(1, 1, 2, 3))
  expect_lt(length(ls(.rmbl_mk_cache)), 40L)
})

test_that("N4: a kernel interrupted inside the barrier raises R's interrupt and leaves no stale flag", {
  skip_on_cran()
  skip_on_os("windows")
  # PBKDF2 polls for an interrupt every 4096 iterations; a SIGINT sent to
  # this process from a child a moment from now lands inside the loop
  # the helper leaves a marker once the signal is away: without it (a loaded runner that
  # could not spawn bash in time) the run is inconclusive, which is not the same as a kernel
  # that swallowed the interrupt
  skip_if_sigint_ignored()
  signal_sent <- tempfile("sigint-")
  system2("bash", c("-c", shQuote(sprintf("sleep 1; kill -INT %d && touch %s", Sys.getpid(), signal_sent))),
          wait = FALSE)
  got <- tryCatch({
    .Call(C("C_rmbl_pbkdf2"), charToRaw("pw"), charToRaw("salt"), 20000000L, 32L)
    "returned"
  }, interrupt = function(e) "interrupt")
  for (i in 1:20) if (file.exists(signal_sent)) break else Sys.sleep(0.1)
  skip_if(!file.exists(signal_sent) && identical(got, "returned"),
          "the SIGINT helper did not run in time on this machine (inconclusive, not a failure)")
  expect_identical(got, "interrupt")
  # the next call starts clean: the flag the kernel set was cleared by the barrier
  expect_identical(.Call(C("C_rmbl_pbkdf2"), charToRaw("pw"), charToRaw("salt"), 1L, 4L),
                   .Call(C("C_rmbl_pbkdf2"), charToRaw("pw"), charToRaw("salt"), 1L, 4L))
  expect_identical(nchar(.Call(C("C_rmbl_pbkdf2"), charToRaw("pw"), charToRaw("salt"), 1L, 4L)), 8L)
})
