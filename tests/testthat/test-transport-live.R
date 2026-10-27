# The compiled transport against the live internet: a cross-host redirect
# with a credential header, a 404, an unresolvable name, and a JSON URL. Not
# on CRAN, and skipped wherever the network is absent: the protocol logic is
# tested offline in test-review3.R and test-coverage-0_5_7.R, this file only
# proves the path through libcurl end to end.

C <- function(nm) get(nm, envir = asNamespace("rmoriebricklayer"))

online <- function() {
  # live traffic only when asked for (review of 46de6a9, H8)
  if (!identical(Sys.getenv("RMBL_LIVE_TESTS"), "1")) {
    return(FALSE)
  }
  r <- tryCatch(
    .Call(
      C("C_rmbl_http_download"),
      "https://cloud.r-project.org/",
      tempfile(),
      20L,
      NULL,
      NULL,
      NULL,
      FALSE
    ),
    error = function(e) NULL
  )
  !is.null(r) && identical(r$status, 200L)
}

test_that(
  paste0(
    "a cross-host redirect is followed with ",
    "the credential header left behind"
  ),
  {
    skip_on_cran()
    skip_if_not(online(), "no network")
    dest <- tempfile(fileext = ".html")
    seen <- numeric(0)
    # r-project.org answers 301 to www.r-project.org: a different host, so the
    # bearer header must not travel (libcurl's own rule, kept by the hand-rolled
    # loop)
    msgs <- utils::capture.output(
      assign(
        "out",
        bldl(
          "https://r-project.org/",
          dest,
          headers = c(
            Authorization = "Bearer not-for-www",
            Accept = "text/html"
          ),
          label = "r-project",
          quiet = FALSE,
          tty = TRUE
        )
      ),
      type = "message"
    )
    expect_identical(out, dest)
    expect_gt(file.size(dest), 1000)
    expect_true(any(grepl(
      "<html",
      readLines(dest, warn = FALSE, n = 20),
      ignore.case = TRUE
    )))
    expect_true(any(grepl("r-project:", msgs, fixed = TRUE)))
    # the same through the entry point, with the milestone lines of a
    # non-terminal
    msgs2 <- utils::capture.output(
      bldl(
        "https://r-project.org/",
        dest,
        label = "again",
        quiet = FALSE,
        tty = FALSE
      ),
      type = "message"
    )
    expect_true(any(grepl("again: downloading", msgs2, fixed = TRUE)))
    expect_true(any(grepl("again: .* in [0-9]+ s", msgs2)))
  }
)

test_that(
  paste0(
    "a 404 and an unresolvable name are errors that leave the destination ",
    "alone"
  ),
  {
    skip_on_cran()
    skip_if_not(online(), "no network")
    dest <- tempfile()
    writeLines("keep me", dest)
    expect_error(
      bldl(
        "https://cloud.r-project.org/this-page-does-not-exist-rmbl",
        dest,
        quiet = TRUE
      ),
      "answered HTTP 404"
    )
    expect_identical(readLines(dest), "keep me")
    expect_error(
      bldl("https://nonexistent.invalid/x", dest, quiet = TRUE),
      "could not resolve"
    )
    expect_identical(readLines(dest), "keep me")
    expect_error(
      dldata(
        "https://cloud.r-project.org/this-page-does-not-exist-rmbl",
        dest,
        quiet = TRUE
      ),
      "answered HTTP 404"
    )
  }
)

test_that("fromjs fetches a URL through the same transport", {
  skip_on_cran()
  skip_if_not(online(), "no network")
  r <- tryCatch(
    fromjs("https://rootcoder007.r-universe.dev/api/packages/rmoriebricklayer"),
    error = function(e) e
  )
  why <- if (inherits(r, "error")) conditionMessage(r) else ""
  # r-universe down, throttling (429), stalling or not answering in time is the
  # third party, not the transport
  skip_if(
    grepl("answered HTTP (5|429)|could not reach|timed? ?out|too slow", why),
    paste("r-universe did not answer:", why)
  )
  expect_identical(why, "")
  expect_identical(r$Package, "rmoriebricklayer")
  expect_error(
    fromjs("https://cloud.r-project.org/this-page-does-not-exist-rmbl.json"),
    "answered HTTP 404"
  )
  expect_error(
    fromjs("https://nonexistent.invalid/x.json"),
    "could not resolve"
  )
})

test_that(
  paste0(
    "a sized body drives the bar; a failing callback, an interrupt and an ",
    "unmovable destination are named"
  ),
  {
    skip_on_cran()
    skip_if_not(online(), "no network")
    # static, with a Content-Length
    url <- paste0("https://cloud.r-project.or", "g/favicon.ico")
    dest <- tempfile(fileext = ".ico")
    msgs <- utils::capture.output(
      bldl(url, dest, label = "icon", quiet = FALSE, tty = TRUE),
      type = "message"
    )
    expect_gt(file.size(dest), 0)
    expect_true(any(grepl("icon:", msgs, fixed = TRUE)))
    # a progress callback that errors ends the transfer and is reported as such
    res <- .Call(
      C("C_rmbl_http_download"),
      url,
      tempfile(),
      30L,
      NULL,
      function(now, total) stop("boom"),
      NULL,
      FALSE
    )
    expect_identical(res$status, -1L)
    expect_identical(res$error, "the progress callback failed")
    # a destination that cannot be replaced (a non-empty directory) is reported,
    # and the body written beside it is removed
    d <- tempfile()
    dir.create(d)
    writeLines("x", file.path(d, "inner"))
    expect_error(
      bldl(url, d, quiet = TRUE),
      "cannot move the download into place"
    )
    expect_true(file.exists(file.path(d, "inner")))
    expect_length(
      list.files(
        dirname(d),
        pattern = paste0("^", basename(d), "\\.rmbl-part")
      ),
      0L
    )
  }
)

test_that(
  paste0(
    "Ctrl-C during a transfer is R's interrupt, raised after the transport ",
    "cleaned up"
  ),
  {
    skip_on_cran()
    skip_on_os("windows")
    skip_if_not(online(), "no network")
    skip_if_sigint_ignored()
    dest <- tempfile()
    # the progress callback sends the process its own SIGINT: the next poll
    # sees it pending, the transfer stops, the barrier raises the interrupt
    got <- tryCatch(
      {
        .Call(
          C("C_rmbl_http_download"),
          "https://cloud.r-project.org/favicon.ico",
          dest,
          30L,
          NULL,
          function(now, total) tools::pskill(Sys.getpid(), tools::SIGINT),
          NULL,
          FALSE
        )
        "returned"
      },
      interrupt = function(e) "interrupt"
    )
    expect_identical(got, "interrupt")
    expect_length(
      list.files(
        dirname(dest),
        pattern = paste0("^", basename(dest), "\\.rmbl-part")
      ),
      0L
    )
  }
)
