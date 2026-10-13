# wayback_save() against a fake Save Page Now 2 server: the transport seams (.bl_wb_post,
# .bl_wb_get, .bl_wb_lookup) are replaced and the clock is simulated, so nothing sleeps and
# nothing reaches archive.org.

fake_spn2 <- function(plan = list(), lookup = NULL) {
  s <- new.env()
  s$clock <- 0
  s$posts <- character()
  s$headers <- list()
  s$jobs <- list()
  s$n <- 0L
  s$tries <- list()
  s$post_at <- numeric()
  s$gets <- 0L
  reply <- function(status, x, retry_after = "") {
    list(status = as.integer(status), body = charToRaw(if (is.character(x)) x else
      bricklayer_json_to_json(x, auto_unbox = TRUE)), error = "", retry_after = retry_after)
  }
  new_job <- function(u, kind = "ok") {
    s$n <- s$n + 1L
    id <- sprintf("spn2-%d", s$n)
    s$jobs[[id]] <- list(url = u, kind = kind, polls = 0L)
    reply(200, list(url = u, job_id = id))
  }
  s$post <- function(body, headers) {
    s$posts <- c(s$posts, body)
    s$post_at <- c(s$post_at, s$clock)
    s$headers[[length(s$headers) + 1L]] <- headers
    u <- utils::URLdecode(sub("&.*$", "", sub("^url=", "", body)))
    p <- plan[[u]] %||% list(kind = "ok")
    s$tries[[u]] <- (s$tries[[u]] %||% 0L) + 1L
    k <- s$tries[[u]]
    switch(p$kind,
      ok = , slow = , joberr = , daily_job = {
        s$n <- s$n + 1L
        id <- sprintf("spn2-%d", s$n)
        s$jobs[[id]] <- list(url = u, kind = p$kind, polls = 0L)
        reply(200, list(url = u, job_id = id))
      },
      recent = reply(200, list(url = u, timestamp = "20261001000000", message = "The same snapshot had been made")),
      daily = reply(200, list(status = "error", status_ext = "error:too-many-daily-captures",
                              message = "This URL has been already captured 1 times today")),
      api404 = {
        if (k <= p$fail) {
          reply(404, list(status = "error", message = "not found"))
        } else {
          s$n <- s$n + 1L
          id <- sprintf("spn2-%d", s$n)
          s$jobs[[id]] <- list(url = u, kind = "ok", polls = 0L)
          reply(200, list(url = u, job_id = id))
        }
      },
      ratelimit = {
        if (k <= p$fail) {
          reply(429, "<html>Too Many Requests</html>")
        } else {
          s$n <- s$n + 1L
          id <- sprintf("spn2-%d", s$n)
          s$jobs[[id]] <- list(url = u, kind = "ok", polls = 0L)
          reply(200, list(url = u, job_id = id))
        }
      },
      down = list(status = -1L, body = raw(0), error = "could not connect"),
      # SPN2's throttle inside an HTTP 200, for the first `fail` tries (review of e57fed5, E7)
      session = if (k <= p$fail) {
        reply(200, list(status = "error", status_ext = "error:user-session-limit",
                        message = "You have already reached the limit of active sessions."))
      } else {
        new_job(u)
      },
      retry_after = if (k <= p$fail) reply(429, "<html>slow down</html>", retry_after = p$after) else new_job(u),
      acct = reply(200, list(status = "error", message = "You cannot make more than 4,000 captures per day.")),
      jobtrue = reply(200, list(url = u, job_id = TRUE)),
      job123 = reply(200, list(url = u, job_id = 123)),
      samejob = {
        s$jobs[["spn2-same"]] <- list(url = u, kind = "ok", polls = 0L)
        reply(200, list(url = u, job_id = "spn2-same"))
      },
      listts = {
        s$n <- s$n + 1L
        id <- sprintf("spn2-%d", s$n)
        s$jobs[[id]] <- list(url = u, kind = "listts", polls = 0L)
        reply(200, list(url = u, job_id = id))
      },
      poll429 = new_job(u, "poll429"),
      html = reply(502, "<html>Bad gateway</html>"),
      refused = reply(401, list(message = "invalid key")),
      odd = reply(200, list(message = "nothing useful"))
    )
  }
  s$get <- function(path, headers) {
    s$gets <- s$gets + 1L
    id <- utils::URLdecode(sub("^/save/status/", "", path))
    j <- s$jobs[[id]]
    if (is.null(j)) return(reply(404, "<html>no such job</html>"))
    j$polls <- j$polls + 1L
    s$jobs[[id]] <- j
    if (j$kind == "poll429" && j$polls <= 4L) return(reply(429, "<html>slow down</html>"))
    if (j$kind == "listts" && j$polls >= 2L) {
      return(reply(200, list(status = "success", timestamp = list("x", 1), original_url = j$url)))
    }
    if (j$kind == "slow") return(reply(200, list(status = "pending")))
    if (j$polls < 2L) return(reply(200, list(status = "pending")))
    if (j$kind == "joberr") return(reply(200, list(status = "error", status_ext = "error:not-found",
                                                   message = "Server returned 404")))
    if (j$kind == "daily_job") return(reply(200, list(status = "error", message = "already captured today")))
    reply(200, list(status = "success", timestamp = "20261013120000", original_url = j$url))
  }
  s$lookup <- function(url) if (is.null(lookup)) NULL else lookup(url)
  s
}

with_fake <- function(s, code) {
  local_mocked_bindings(
    .bl_wb_post = function(body, headers) s$post(body, headers),
    .bl_wb_get = function(path, headers) s$get(path, headers),
    .bl_wb_lookup = function(url) s$lookup(url),
    .bl_wb_now = function() s$clock,
    .bl_wb_sleep = function(seconds) s$clock <- s$clock + seconds,
    .bl_anim_wait = function(a, seconds) {
      s$clock <- s$clock + seconds
      invisible(a)
    },
    .package = "rmoriebricklayer", .env = environment()
  )
  force(code)
}

keys <- c(IA_S3_ACCESS_KEY = "abcACCESS123", IA_S3_SECRET_KEY = "xyzSECRET456",
          IA_S3_ACCESS_KEY_FILE = NA, IA_S3_SECRET_KEY_FILE = NA)

test_that("wayback_save(): captures run in flight, finish, and are written as they land", {
  withr::local_envvar(keys)
  s <- fake_spn2()
  out <- withr::local_tempfile(fileext = ".jsonl")
  urls <- sprintf("https://example.org/page%d", 1:9)
  res <- with_fake(s, wayback_save(c(urls, urls[1], NA, ""), jobs = 3, output = out, quiet = TRUE))
  expect_s3_class(res, "rmbl_wayback_save")
  expect_identical(res$url, urls)
  expect_true(all(res$status == "saved"))
  expect_identical(res$snapshot[1], "https://web.archive.org/web/20261013120000/https://example.org/page1")
  expect_length(s$posts, 9L)
  # the key travels in the Authorization header in archive.org's LOW form, and the form asks to
  # keep a capture from the last 30 days
  expect_true(all(vapply(s$headers, function(h) "Authorization: LOW abcACCESS123:xyzSECRET456" %in% h, TRUE)))
  expect_true(all(grepl("if_not_archived_within=30d", s$posts, fixed = TRUE)))
  expect_true(all(grepl("skip_first_archive=1", s$posts, fixed = TRUE)))
  lines <- readLines(out)
  expect_length(lines, 9L)
  expect_identical(rmoriebricklayer:::.rmbl_json_parse(lines[1])$status, "saved")
  expect_output(print(res), "9 URLs: 9 saved, 0 existing, 0 failed")
})

test_that("wayback_save(): a run started again with the same output does not send finished URLs", {
  withr::local_envvar(keys)
  out <- withr::local_tempfile(fileext = ".jsonl")
  writeLines(c(bricklayer_json_to_json(list(url = "https://example.org/a", status = "saved",
                                            timestamp = "20261001000000",
                                            snapshot = paste0("https://web.archive.org/web/20261001000000/",
                                                              "https://example.org/a"),
                                            message = ""), auto_unbox = TRUE),
               bricklayer_json_to_json(list(url = "https://example.org/b", status = "failed", message = "x"),
                                       auto_unbox = TRUE),
               "not json"), out)
  s <- fake_spn2()
  res <- with_fake(s, wayback_save(c("https://example.org/a", "https://example.org/b"), output = out, quiet = TRUE))
  # the saved one is kept, the failed one is tried again
  expect_length(s$posts, 1L)
  expect_match(s$posts, "example.org%2Fb")
  expect_identical(res$status, c("saved", "saved"))
  expect_identical(res$timestamp[1], "20261001000000")
})

test_that("wayback_save(): recent captures, the daily limit, job errors, time-outs and odd replies", {
  withr::local_envvar(keys)
  plan <- list("https://e.org/recent" = list(kind = "recent"), "https://e.org/daily" = list(kind = "daily"),
               "https://e.org/dailynone" = list(kind = "daily"), "https://e.org/joberr" = list(kind = "joberr"),
               "https://e.org/dailyjob" = list(kind = "daily_job"), "https://e.org/slow" = list(kind = "slow"),
               "https://e.org/odd" = list(kind = "odd"))
  look <- function(u) {
    if (u == "https://e.org/dailynone") NULL else sprintf("https://web.archive.org/web/20261013000000/%s", u)
  }
  s <- fake_spn2(plan, lookup = look)
  res <- with_fake(s, wayback_save(names(plan), jobs = 4, poll = 5, max_wait = 60, quiet = TRUE))
  st <- stats::setNames(res$status, res$url)
  expect_identical(st[["https://e.org/recent"]], "existing")
  expect_identical(res$timestamp[res$url == "https://e.org/recent"], "20261001000000")
  expect_identical(st[["https://e.org/daily"]], "existing")
  expect_identical(res$timestamp[res$url == "https://e.org/daily"], "20261013000000")
  expect_identical(st[["https://e.org/dailynone"]], "failed")
  expect_match(res$message[res$url == "https://e.org/dailynone"], "already captured")
  expect_identical(st[["https://e.org/joberr"]], "failed")
  expect_match(res$message[res$url == "https://e.org/joberr"], "404")
  expect_identical(st[["https://e.org/dailyjob"]], "existing")
  expect_identical(st[["https://e.org/slow"]], "failed")
  expect_match(res$message[res$url == "https://e.org/slow"], "no answer from archive.org in 60 seconds")
  expect_identical(st[["https://e.org/odd"]], "failed")
  expect_match(res$message[res$url == "https://e.org/odd"], "nothing useful")
})

test_that("wayback_save(): rate limits and server errors back off and retry, then give up", {
  withr::local_envvar(keys)
  plan <- list("https://e.org/limited" = list(kind = "ratelimit", fail = 2), "https://e.org/down" = list(kind = "down"),
               "https://e.org/html" = list(kind = "html"))
  s <- fake_spn2(plan)
  res <- with_fake(s, wayback_save(names(plan), jobs = 2, quiet = TRUE))
  st <- stats::setNames(res$status, res$url)
  expect_identical(st[["https://e.org/limited"]], "saved")
  expect_identical(s$tries[["https://e.org/limited"]], 3L)
  expect_identical(st[["https://e.org/down"]], "failed")
  expect_match(res$message[res$url == "https://e.org/down"], "gave up after six tries: could not connect")
  expect_identical(s$tries[["https://e.org/down"]], 6L)
  expect_match(res$message[res$url == "https://e.org/html"], "HTTP 502")
  # the waits doubled from 15 s, capped at 300 s
  expect_gte(s$clock, 15 + 30 + 60 + 120 + 240)
})

test_that("wayback_save(): a refused key stops the run without printing the key", {
  withr::local_envvar(keys)
  s <- fake_spn2(list("https://e.org/x" = list(kind = "refused")))
  err <- tryCatch(with_fake(s, wayback_save("https://e.org/x", quiet = TRUE)), error = function(e) conditionMessage(e))
  expect_match(err, "refused the keys \\(HTTP 401\\)")
  expect_false(grepl("SECRET", err))
})

test_that("wayback_save(): within = '0', capture_all, and keys read from files", {
  ak <- withr::local_tempfile()
  sk <- withr::local_tempfile()
  writeLines("fileACCESS", ak)
  writeLines("fileSECRET", sk)
  Sys.chmod(c(ak, sk), "0600")   # key files are kept private (a readable one is warned about)
  withr::local_envvar(c(IA_S3_ACCESS_KEY = NA, IA_S3_SECRET_KEY = NA, IA_S3_ACCESS_KEY_FILE = ak,
                        IA_S3_SECRET_KEY_FILE = sk))
  s <- fake_spn2()
  with_fake(s, wayback_save("https://e.org/y", within = "0", capture_all = TRUE, quiet = TRUE))
  expect_false(grepl("if_not_archived_within", s$posts))
  expect_match(s$posts, "capture_all=1", fixed = TRUE)
  expect_true("Authorization: LOW fileACCESS:fileSECRET" %in% s$headers[[1]])
})

test_that("wayback_save(): bad input is refused in words", {
  withr::local_envvar(keys)
  expect_error(wayback_save(1), "character")
  expect_error(wayback_save(c(NA, "")), "has no URLs")
  expect_error(wayback_save("ftp://x.org/a"), "not an http\\(s\\) URL")
  expect_error(wayback_save("https://x.org/a b"), "not an http\\(s\\) URL")
  expect_error(wayback_save("https://x.org", within = "30 days"), "must look like")
  expect_error(wayback_save("https://x.org", jobs = 0), "1 to 12")
  expect_error(wayback_save("https://x.org", jobs = 13), "1 to 12")
  expect_error(wayback_save("https://x.org", poll = 0), "at least 1 second")
  expect_error(wayback_save("https://x.org", poll = 10, max_wait = 5), "at least `poll`")
  expect_error(wayback_save("https://x.org", capture_all = NA), "TRUE or FALSE")
  expect_error(wayback_save("https://x.org", access_key = "a\nb", secret_key = "c"), "letters and digits only")
  withr::local_envvar(c(IA_S3_ACCESS_KEY = NA, IA_S3_SECRET_KEY = NA))
  expect_error(wayback_save("https://x.org"), "needs your archive.org keys")
  withr::local_envvar(c(IA_S3_ACCESS_KEY_FILE = "/nonexistent/key"))
  expect_error(wayback_save("https://x.org"), "does not exist")
})

test_that("rmbl wayback: archives a file of URLs and reports, with usage for mistakes", {
  withr::local_envvar(keys)
  f <- withr::local_tempfile(fileext = ".txt")
  writeLines(c("# sources", "https://e.org/1", "", "https://e.org/2"), f)
  s <- fake_spn2(list("https://e.org/2" = list(kind = "joberr")))
  outl <- character()
  st <- with_fake(s, bricklayer_cli(c("wayback", f, "--jobs", "2"), out = function(x) outl <<- c(outl, x)))
  expect_identical(st, 1L)
  expect_true(any(grepl("1 saved, 0 existing, 1 failed", outl)))
  expect_true(file.exists(paste0(f, ".wayback.jsonl")))
  outl <- character()
  expect_identical(bricklayer_cli(c("wayback"), out = function(x) outl <<- c(outl, x)), 2L)
  expect_true(any(grepl("usage: .* wayback FILE", outl)))
  expect_identical(bricklayer_cli(c("wayback", "help"), out = function(x) NULL), 0L)
  expect_identical(bricklayer_cli(c("wayback", "/nonexistent/urls.txt"), out = function(x) NULL), 1L)
  expect_identical(bricklayer_cli(c("wayback", f, "--bogus"), out = function(x) NULL), 2L)
})

test_that("the transport seams reach archive.org (live, opt-in, never a capture)", {
  # real traffic only when asked for (RMBL_LIVE_TESTS=1), and never a POST to /save: a test run with
  # network used to start a real capture of example.org (review of e57fed5, E6)
  skip_on_cran()
  skip_if_not(nzchar(Sys.getenv("RMBL_LIVE_TESTS")), "set RMBL_LIVE_TESTS=1 for the live archive.org checks")
  expect_true(is.numeric(rmoriebricklayer:::.bl_wb_now()))
  # no key: archive.org answers with a refusal, through the package's own transport
  r <- rmoriebricklayer:::.bl_wb_get("/save/status/user", "Accept: application/json")
  skip_if(r$status < 0L, "archive.org is not reachable from here")
  expect_true(r$status %in% c(200L, 401L, 403L, 429L, 502L, 503L, 520L, 523L))
  s <- rmoriebricklayer:::.bl_wb_lookup("https://www.r-project.org/")
  expect_true(is.null(s) || grepl("^https?://web.archive.org/web/", s))
})

test_that("the reply reader takes JSON only: empty, HTML and oversized bodies are no reply", {
  expect_true(is.numeric(rmoriebricklayer:::.bl_wb_now()))
  expect_null(rmoriebricklayer:::.bl_wb_json(list(body = raw(0))))
  expect_null(rmoriebricklayer:::.bl_wb_json(list(body = charToRaw("<html>no</html>"))))
  big <- charToRaw(paste0("{\"message\": \"", strrep("x", 70000), "\"}"))
  expect_null(rmoriebricklayer:::.bl_wb_json(list(body = big)))
  expect_identical(rmoriebricklayer:::.bl_wb_json(list(body = charToRaw("{\"a\": \"b\"}")))$a, "b")
})

test_that("wayback_retry(): failures are looked up, captured again, and gone pages left alone", {
  withr::local_envvar(keys)
  out <- withr::local_tempfile(fileext = ".jsonl")
  urls <- sprintf("https://e.org/%d", 1:4)
  s1 <- fake_spn2(list("https://e.org/2" = list(kind = "joberr"), "https://e.org/3" = list(kind = "down"),
                       "https://e.org/4" = list(kind = "daily")))
  r1 <- with_fake(s1, wayback_save(urls, output = out, quiet = TRUE))
  expect_identical(r1$status, c("saved", "failed", "failed", "failed"))
  # the next day: the daily-limited page has a capture (another run made it), the server is back
  s2 <- fake_spn2(lookup = function(u) if (u == "https://e.org/4") .bl_wb_snapshot("20261013090000", u) else NULL)
  r2 <- with_fake(s2, wayback_retry(out, quiet = TRUE))
  st <- stats::setNames(r2$status, r2$url)
  expect_identical(unname(st[urls]), c("saved", "failed", "saved", "existing"))
  expect_equal(attr(r2, "retry"), data.frame(failed = 3L, found_by_lookup = 1L, captured_again = 1L, left_as_gone = 1L,
                                              left_for_tomorrow = 0L))
  expect_match(r2$message[r2$url == "https://e.org/4"], "found on retry")
  # only the server-error URL was sent again: the gone page and the finished ones were not
  expect_identical(s2$posts, paste0("url=", utils::URLencode("https://e.org/3", reserved = TRUE),
                                    sub("^url=[^&]*", "", s1$posts[1])))
  # include_gone sends the gone page too
  s3 <- fake_spn2()
  r3 <- with_fake(s3, wayback_retry(out, include_gone = TRUE, lookup = FALSE, quiet = TRUE))
  expect_identical(r3$status[r3$url == "https://e.org/2"], "saved")
  expect_equal(attr(r3, "retry")$captured_again, 1L)
  # nothing left to retry: nothing is sent
  s4 <- fake_spn2()
  r4 <- with_fake(s4, wayback_retry(out, quiet = TRUE))
  expect_length(s4$posts, 0L)
  expect_equal(attr(r4, "retry")$failed, 0L)
  expect_s3_class(r4, "rmbl_wayback_save")
})

test_that("wayback_retry(): what counts as gone, and bad input refused", {
  gone <- rmoriebricklayer:::.bl_wb_gone
  expect_true(all(gone(c("Server returned 404", "Server returned 410",
                         "The target server cannot find https://x", "error:not-found"))))
  # an "HTTP 404" from archive.org's own API is not the page: StatCan tables failed that way while live
  expect_false(any(gone(c("HTTP 404", "HTTP 410", "HTTP 502", "could not connect",
                          "This URL has been already captured 1 times today", "gave up after retries"))))
  out <- withr::local_tempfile(fileext = ".jsonl")
  expect_error(wayback_retry(out), "no results file")
  writeLines("{\"url\": \"https://e.org/1\", \"status\": \"failed\", \"message\": \"x\"}", out)
  expect_error(wayback_retry(out, include_gone = NA), "TRUE or FALSE")
  expect_error(wayback_retry(out, lookup = "yes"), "TRUE or FALSE")
})

test_that("rmbl wayback --retry: retries the failures of a results file", {
  withr::local_envvar(keys)
  f <- withr::local_tempfile(fileext = ".txt")
  writeLines(c("https://e.org/1", "https://e.org/2"), f)
  s1 <- fake_spn2(list("https://e.org/2" = list(kind = "down")))
  with_fake(s1, bricklayer_cli(c("wayback", f), out = function(x) NULL))
  res <- paste0(f, ".wayback.jsonl")
  s2 <- fake_spn2()
  outl <- character()
  st <- with_fake(s2, bricklayer_cli(c("wayback", "--retry", res, "--jobs", "2"),
                                     out = function(x) outl <<- c(outl, x)))
  expect_identical(st, 0L)
  expect_true(any(grepl(paste("1 failures: 0 found already archived, 1 captured again, 0 left as gone,",
                              "0 left for tomorrow \\(a daily limit\\); now 2 saved"), outl)))
  expect_identical(bricklayer_cli(c("wayback", "--retry", "/nonexistent.jsonl"), out = function(x) NULL), 1L)
  expect_identical(bricklayer_cli(c("wayback", "--retry"), out = function(x) NULL), 2L)
  # a gone page left by the retry exits 1, and --include-gone sends it
  s3 <- fake_spn2(list("https://e.org/1" = list(kind = "joberr")))
  f2 <- withr::local_tempfile(fileext = ".txt")
  writeLines("https://e.org/1", f2)
  with_fake(s3, bricklayer_cli(c("wayback", f2), out = function(x) NULL))
  r2 <- paste0(f2, ".wayback.jsonl")
  expect_identical(with_fake(fake_spn2(), bricklayer_cli(c("wayback", "--retry", r2), out = function(x) NULL)), 1L)
  expect_identical(with_fake(fake_spn2(), bricklayer_cli(c("wayback", "--retry", r2, "--include-gone"),
                                                           out = function(x) NULL)), 0L)
})

test_that("wayback_save(): a 404 from archive.org's capture endpoint is retried, not taken as the page", {
  withr::local_envvar(keys)
  s <- fake_spn2(list("https://e.org/1" = list(kind = "api404", fail = 2L)))
  r <- with_fake(s, wayback_save("https://e.org/1", quiet = TRUE))
  expect_identical(r$status, "saved")
  expect_equal(s$tries[["https://e.org/1"]], 3L)
  s2 <- fake_spn2(list("https://e.org/1" = list(kind = "api404", fail = 99L)))
  r2 <- with_fake(s2, wayback_save("https://e.org/1", quiet = TRUE))
  expect_identical(r2$status, "failed")
  expect_match(r2$message, "gave up after six tries: HTTP 404")
  # and the retry does not count that failure as a gone page
  expect_false(rmoriebricklayer:::.bl_wb_gone(r2$message))
})

# ---- review of e57fed5: keeping to archive.org's limits (E7) and the reply handling ----------

test_that("E7: captures start no faster than per_minute", {
  withr::local_envvar(keys)
  s <- fake_spn2()
  urls <- sprintf("https://e.org/p%d", 1:9)
  res <- with_fake(s, wayback_save(urls, jobs = 12, per_minute = 6, quiet = TRUE))
  expect_true(all(res$status == "saved"))
  expect_length(s$posts, 9L)
  # ten seconds apart at six a minute (the run cannot burst: 300 URLs had gone out in 32 s)
  expect_true(all(diff(s$post_at) >= 10 - 1e-9))
  expect_error(wayback_save("https://e.org/a", per_minute = 0), "above 0")
  expect_error(wayback_save("https://e.org/a", per_minute = 61), "at most 60")
  expect_error(wayback_save("https://e.org/a", max_captures = 0), "at least 1")
})

test_that("E7: a throttle inside an HTTP 200 holds every submission back, then the URL is sent again", {
  withr::local_envvar(keys)
  s <- fake_spn2(list("https://e.org/a" = list(kind = "session", fail = 3), "https://e.org/b" = list(kind = "ok")))
  res <- with_fake(s, wayback_save(c("https://e.org/a", "https://e.org/b"), jobs = 4, per_minute = 60, quiet = TRUE))
  expect_identical(res$status, c("saved", "saved"))
  # not a failure: the URL waited and went again, three times, 15 s doubling between
  expect_identical(s$tries[["https://e.org/a"]], 4L)
  gaps <- diff(s$post_at[grepl("e.org%2Fa", s$posts)])
  expect_true(all(gaps >= c(15, 30, 60) - 1e-9))
  # and nothing else was sent while held
  first_b <- s$post_at[grepl("e.org%2Fb", s$posts)][1]
  expect_gte(first_b, 15 + 30 + 60)
})

test_that("E7: Retry-After is waited out", {
  withr::local_envvar(keys)
  s <- fake_spn2(list("https://e.org/a" = list(kind = "retry_after", fail = 1, after = "240")))
  res <- with_fake(s, wayback_save("https://e.org/a", quiet = TRUE))
  expect_identical(res$status, "saved")
  expect_gte(diff(s$post_at), 240)
  # an HTTP date works too, and a bad one is ignored
  expect_true(is.na(rmoriebricklayer:::.bl_wb_retry_after(list(retry_after = "soon"))))
  future <- format(Sys.time() + 90, "%a, %d %b %Y %H:%M:%S GMT", tz = "GMT")
  ra <- rmoriebricklayer:::.bl_wb_retry_after(list(retry_after = future))
  expect_true(ra > 80 && ra <= 90)
  expect_identical(rmoriebricklayer:::.bl_wb_retry_after(list(retry_after = "99999")), 3600)
})

test_that("E7: eight slow-downs in a row stop the run; the account's daily cap stops it at once", {
  withr::local_envvar(keys)
  s <- fake_spn2(list("https://e.org/a" = list(kind = "session", fail = 99)))
  res <- with_fake(s, wayback_save(c("https://e.org/a", "https://e.org/b"), quiet = TRUE))
  expect_identical(nrow(res), 0L)
  expect_setequal(attr(res, "not_sent"), c("https://e.org/a", "https://e.org/b"))
  expect_match(attr(res, "stopped"), "eight times in a row")
  expect_length(s$posts, 9L)
  expect_output(print(res), "not sent this run")
  s2 <- fake_spn2(list("https://e.org/a" = list(kind = "acct")))
  res2 <- with_fake(s2, wayback_save(c("https://e.org/a", "https://e.org/b", "https://e.org/c"), quiet = TRUE))
  expect_length(s2$posts, 1L)
  expect_match(attr(res2, "stopped"), "daily capture limit")
  expect_length(attr(res2, "not_sent"), 3L)
})

test_that("E7: status checks that are refused back off instead of asking again at once", {
  withr::local_envvar(keys)
  s <- fake_spn2(list("https://e.org/a" = list(kind = "poll429")))
  res <- with_fake(s, wayback_save("https://e.org/a", poll = 1, max_wait = 600, quiet = TRUE))
  expect_identical(res$status, "saved")
  # four 429s then the answer: five checks, spread out by the back-off (1, 2, 4, 8 s)
  expect_identical(s$gets, 5L)
  expect_gte(s$clock, 1 + 2 + 4 + 8)
})

test_that("max_captures leaves the rest for the next run, which carries on", {
  withr::local_envvar(keys)
  out <- withr::local_tempfile(fileext = ".jsonl")
  urls <- sprintf("https://e.org/m%d", 1:5)
  s <- fake_spn2()
  r1 <- with_fake(s, wayback_save(urls, output = out, max_captures = 2, quiet = TRUE))
  expect_identical(r1$url, urls[1:2])
  expect_identical(attr(r1, "not_sent"), urls[3:5])
  s2 <- fake_spn2()
  r2 <- with_fake(s2, wayback_save(urls, output = out, max_captures = 2, quiet = TRUE))
  expect_length(s2$posts, 2L)
  expect_identical(r2$url, urls[1:4])
})

test_that("odd replies: a job id of TRUE or 123, two URLs given one id, a list timestamp", {
  withr::local_envvar(keys)
  plan <- list("https://e.org/t" = list(kind = "jobtrue"), "https://e.org/n" = list(kind = "job123"),
               "https://e.org/s1" = list(kind = "samejob"), "https://e.org/s2" = list(kind = "samejob"),
               "https://e.org/l" = list(kind = "listts"))
  out <- withr::local_tempfile(fileext = ".jsonl")
  s <- fake_spn2(plan)
  res <- with_fake(s, wayback_save(names(plan), output = out, per_minute = 60, quiet = TRUE))
  st <- stats::setNames(res$status, res$url)
  # TRUE looped for ever and 123 stopped the run; both are a reply with no job to poll
  expect_identical(st[["https://e.org/t"]], "failed")
  expect_match(res$message[res$url == "https://e.org/t"], "no usable job id")
  expect_identical(st[["https://e.org/n"]], "failed")
  # two URLs with one id each keep their own entry (one was dropped)
  expect_identical(unname(st[c("https://e.org/s1", "https://e.org/s2")]), c("saved", "saved"))
  # a list where a timestamp belongs is no timestamp: the capture is saved, the address undated
  expect_identical(st[["https://e.org/l"]], "saved")
  expect_true(is.na(res$timestamp[res$url == "https://e.org/l"]))
  expect_identical(res$snapshot[res$url == "https://e.org/l"], "https://web.archive.org/web/https://e.org/l")
  # and the file it wrote reads back (a list timestamp had broken every resume)
  cat('{"url": "https://e.org/x", "status": "saved", "timestamp": ["a", "b"]}\n', file = out, append = TRUE)
  back <- rmoriebricklayer:::.bl_wb_read(out)
  expect_true(is.na(back$timestamp[back$url == "https://e.org/x"]))
  expect_identical(rmoriebricklayer:::.bl_wb_job_id("spn2-ab12"), "spn2-ab12")
  expect_true(is.na(rmoriebricklayer:::.bl_wb_job_id("a b")))
})

test_that("a stopped run records what it had started, and the next run polls it instead of sending it again", {
  withr::local_envvar(keys)
  out <- withr::local_tempfile(fileext = ".jsonl")
  s <- fake_spn2(list("https://e.org/a" = list(kind = "slow")))
  # the run is stopped while the capture is in flight (an error from the status check)
  s$get <- function(path, headers) stop("interrupted")
  expect_error(with_fake(s, wayback_save("https://e.org/a", output = out, quiet = TRUE)), "interrupted")
  rec <- rmoriebricklayer:::.bl_wb_records(out)[["https://e.org/a"]]
  expect_identical(rec$status, "submitted")
  expect_identical(rec$job_id, "spn2-1")
  s2 <- fake_spn2()
  s2$jobs[["spn2-1"]] <- list(url = "https://e.org/a", kind = "ok", polls = 0L)
  res <- with_fake(s2, wayback_save("https://e.org/a", output = out, quiet = TRUE))
  expect_length(s2$posts, 0L)
  expect_identical(res$status, "saved")
  # a job archive.org no longer knows is a failure the retry sends again
  s3 <- fake_spn2()
  writeLines('{"url": "https://e.org/z", "status": "submitted", "job_id": "spn2-gone"}', out)
  r3 <- with_fake(s3, wayback_save("https://e.org/z", output = out, quiet = TRUE))
  expect_match(r3$message, "no longer knows capture spn2-gone")
})

test_that("the results file is checked before anything is sent; a URL that hides characters is refused", {
  withr::local_envvar(keys)
  s <- fake_spn2()
  expect_error(with_fake(s, wayback_save("https://e.org/a", output = file.path(tempdir(), "no-such-dir", "o.jsonl"),
                                         quiet = TRUE)), "folder for `output` does not exist")
  expect_error(with_fake(s, wayback_save("https://e.org/a", output = tempdir(), quiet = TRUE)), "cannot write")
  expect_length(s$posts, 0L)
  err <- tryCatch(wayback_save("https://e.org/a\u202ebad"), error = conditionMessage)
  expect_match(err, "U+202E", fixed = TRUE)
  expect_false(grepl("\u202e", err, fixed = TRUE))
  expect_match(tryCatch(wayback_save("https://e.org/\x01"), error = conditionMessage), "U+0001", fixed = TRUE)
  # a results file that holds such a URL prints without it
  x <- rmoriebricklayer:::.bl_wb_frame(list(list(url = "https://e.org/\u202eevil", status = "saved")))
  expect_false(any(grepl("\u202e", capture.output(print(x)), fixed = TRUE)))
})

test_that("a key file other users can read is warned about; http pages are looked up", {
  skip_on_os("windows")
  ak <- withr::local_tempfile()
  writeLines("fileACCESS", ak)
  Sys.chmod(ak, "0644")
  withr::local_envvar(c(IA_S3_ACCESS_KEY = NA, IA_S3_ACCESS_KEY_FILE = ak))
  expect_warning(k <- rmoriebricklayer:::.bl_ia_key("IA_S3_ACCESS_KEY"), "other users can read")
  expect_identical(k, "fileACCESS")
  Sys.chmod(ak, "0600")
  expect_silent(rmoriebricklayer:::.bl_ia_key("IA_S3_ACCESS_KEY"))
  # the page is a parameter of the lookup, never fetched: plain http is looked up as it is
  expect_identical(rmoriebricklayer:::.rmbl_check_public_url("http://example.org/a", "url", allow_http = TRUE),
                   "http://example.org/a")
})

test_that("wayback_retry(): a daily limit hit today is left for tomorrow; lookups go one a second", {
  withr::local_envvar(keys)
  out <- withr::local_tempfile(fileext = ".jsonl")
  now <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  daily <- '{"url": "https://e.org/%s", "status": "failed", "message": "This URL has been captured 10 times today", '
  writeLines(c(paste0(sprintf(daily, "d"), sprintf('"at": "%s"}', now)),
               paste0(sprintf(daily, "old"), '"at": "2020-01-01T00:00:00Z"}'),
               '{"url": "https://e.org/x", "status": "failed", "message": "HTTP 502"}'), out)
  s <- fake_spn2()
  r <- with_fake(s, wayback_retry(out, quiet = TRUE))
  ra <- attr(r, "retry")
  expect_identical(ra$left_for_tomorrow, 1L)
  expect_identical(ra$captured_again, 2L)
  expect_false(any(grepl("e.org%2Fd", s$posts)))
  # three lookups, a second apart
  expect_gte(s$clock, 2)
})
