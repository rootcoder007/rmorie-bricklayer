# battery: runs in CI and locally; CRAN runs the correctness core
testthat::skip_on_cran()
# The lines of this release's changes that no other test reached (codecov patch
# report on PR #56)

ns <- function(x) get(x, envir = asNamespace("rmoriebricklayer"))

test_that(
  paste0(
    "the Wayback seams call the transport: an address that refuses gives a ",
    "status, not an error"
  ),
  {
    expect_identical(ns(".bl_wb_base")(), "https://web.archive.org")
    local_mocked_bindings(.bl_wb_base = function() "https://127.0.0.1:9")
    p <- ns(".bl_wb_post")("url=https%3A%2F%2Fe.org", NULL)
    g <- ns(".bl_wb_get")("/wayback/available?url=e.org", NULL)
    expect_identical(p$status, -1L)
    expect_identical(g$status, -1L)
    expect_match(p$error, "local or private|refused")
    # an error in the lookup is "no snapshot"
    expect_null(ns(".bl_wb_lookup")("not a url at all"))
  }
)

test_that("a credentials file past 1 MB is refused as not one", {
  f <- withr::local_tempfile()
  writeBin(raw(1048577L), f)
  expect_error(ns(".bl_read_text")(f), "too large to be a credentials file")
  expect_error(
    ns(".bl_read_text")(file.path(withr::local_tempdir(), "none")),
    "cannot read"
  )
})

test_that("route_info takes a named route", {
  withr::local_envvar(
    GROQ_API_KEY = "gsk-x",
    MORIE_GROQ_MODEL = "llama-x",
    OLLAMA_HOST = "off",
    MORIE_LLM_BASE_URL = NA,
    XDG_CONFIG_HOME = withr::local_tempdir()
  )
  ri <- llmrte("groq")
  expect_identical(ri$route, "groq")
  expect_identical(ri$model, "llama-x")
  expect_error(llmrte("nowhere"), "must be one of")
})

test_that("vrfpol reports a scalar that is not a number", {
  expect_match(vrfpol("no2", ref = list(1))$error, "single number, not list")
  expect_match(vrfpol("no2", ref = 1i)$error, "single number, not complex")
  expect_match(vrfpol("no2", ref = "abc")$error, "must be a single number")
  expect_match(vrfpol("no2", ref = TRUE)$error, "must be a single number")
  expect_identical(attr(vrfpol("no2", ref = "abc"), "exitstat"), 2L)
})

test_that(
  paste0(
    "a design's degrees of freedom: PSUs less ",
    "strata, or replicates less one"
  ),
  {
    svy_df <- ns(".svy_df")
    expect_identical(
      svy_df(list(
        type = "linearization",
        psu = c(1, 1, 2, 3),
        strata = c(1, 1, 1, 2)
      )),
      1L
    )
    expect_identical(svy_df(list(type = "bootstrap", reps = list(1, 2, 3))), 2L)
    expect_identical(
      svy_df(list(type = "bootstrap", reps = list(1), degf = 9)),
      9
    )
  }
)

test_that("the cached manifest gives a listed table's digest", {
  d <- withr::local_tempdir()
  withr::local_options(rmoriebricklayer.dcache = d)
  sha <- strrep("ab", 32L)
  writeLines(
    sprintf('{"datasets":[{"key":"a/b","sha256_gz":"%s"},{"key":"c/d"}]}', sha),
    file.path(d, "manifest.json")
  )
  expect_identical(ns(".bl_data_cached_digest")("a/b"), sha)
  expect_null(ns(".bl_data_cached_digest")("c/d"))
  expect_identical(ns(".bl_data_cached_digest")("x/y"), NA)
})

test_that("a help page marked internal is left out of the knowledge index", {
  pages <- ns(".bl_kn_pages")("stats")
  nm <- vapply(pages, function(p) p$name, "")
  expect_false("stats-defunct" %in% nm)
  expect_true(length(pages) > 100L)
})

test_that("the lock hint names what to check", {
  hint <- ns(".rmbl_lock_hint")
  expect_identical(
    hint("Read-only file system", tempfile()),
    " (is the directory read-only?)"
  )
  expect_identical(hint("No space left on device", tempfile()), "")
  expect_identical(
    hint("Permission denied", tempfile()),
    " (is the directory read-only?)"
  )
  skip_on_os("windows")
  skip_if(
    identical(Sys.info()[["effective_user"]], "root"),
    "root can write any file"
  )
  f <- withr::local_tempfile()
  writeLines("", f)
  Sys.chmod(f, "0400")
  expect_identical(
    hint("Permission denied", f),
    " (is the lock file owned by another user?)"
  )
})

test_that(
  paste0(
    "an interrupt inside a guarded call stops the replicate kernel with an ",
    "error"
  ),
  {
    skip_on_cran()
    skip_on_os("windows")
    # the kernel runs from R code called back by a guarded download (its
    # progress closure), so no barrier of the kernel's own can raise R's
    # interrupt: it stops with "interrupted" instead
    port <- 18000L + sample.int(900L, 1L)
    srv <- withr::local_tempfile(fileext = ".R")
    writeLines(
      c(
        sprintf("s <- serverSocket(%dL)", port),
        "con <- socketAccept(s, blocking = TRUE, open = 'r+b')",
        "invisible(readLines(con, n = 1L))",
        "body <- strrep('x', 200000)",
        paste0(
          "hdr <- c('HTTP/1.1 200 OK', paste('Content-Length:', ",
          "nchar(body)), 'Connection: close', '')"
        ),
        "writeLines(hdr, con, sep = '\\r\\n')",
        "for (i in 1:20) {",
        paste0(
          "  cat(substr(body, (i - 1) * 10000 + 1, i * 10000), file = con); ",
          "flush(con); Sys.sleep(0.05)"
        ),
        "}",
        "close(con); close(s)"
      ),
      srv
    )
    withr::local_envvar(R_TESTS = NA)
    system2(
      file.path(R.home("bin"), "Rscript"),
      c("--vanilla", srv),
      wait = FALSE,
      stdout = FALSE,
      stderr = FALSE
    )
    Sys.sleep(1)
    got <- NULL
    prog <- function(now, total) {
      if (!is.null(got)) {
        return(invisible())
      }
      tools::pskill(Sys.getpid(), tools::SIGINT)
      got <<- tryCatch(
        .Call(
          ns("C_rmbl_svy_reptotals"),
          matrix(1, 10, 1),
          list(rep(1, 10)),
          NULL
        ),
        error = function(e) conditionMessage(e),
        interrupt = function(i) "interrupt"
      )
    }
    res <- tryCatch(
      .Call(
        ns("C_rmbl_http_download"),
        sprintf("http://127.0.0.1:%d/f", port),
        withr::local_tempfile(),
        10L,
        NULL,
        prog,
        NULL,
        TRUE
      ),
      interrupt = function(i) NULL,
      error = function(e) NULL
    )
    # a signal that arrived after the kernel had run is taken here, not by the
    # next test
    tryCatch(Sys.sleep(0.3), interrupt = function(i) NULL)
    skip_if(is.null(got), "the progress callback did not run")
    skip_if(
      is.numeric(got),
      "the signal reached R after the kernel had run (timing)"
    )
    # the kernel stopped: either with its own "interrupted" error, or R
    # delivered the pending interrupt as a condition to the handler around the
    # call before the kernel's check (what R 4.5+ does when a tryCatch(interrupt
    # = ) is on the stack); what matters is that no result came back
    expect_true(got %in% c("interrupted", "interrupt"))
  }
)
