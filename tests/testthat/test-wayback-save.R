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
  reply <- function(status, x) {
    list(status = as.integer(status), body = charToRaw(if (is.character(x)) x else
      bricklayer_json_to_json(x, auto_unbox = TRUE)), error = "")
  }
  s$post <- function(body, headers) {
    s$posts <- c(s$posts, body)
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
      html = reply(502, "<html>Bad gateway</html>"),
      refused = reply(401, list(message = "invalid key")),
      odd = reply(200, list(message = "nothing useful"))
    )
  }
  s$get <- function(path, headers) {
    id <- utils::URLdecode(sub("^/save/status/", "", path))
    j <- s$jobs[[id]]
    j$polls <- j$polls + 1L
    s$jobs[[id]] <- j
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

test_that("the transport seams reach archive.org (live)", {
  skip_on_cran()
  expect_true(is.numeric(rmoriebricklayer:::.bl_wb_now()))
  # no key: archive.org answers with a refusal, through the package's own transport
  r <- rmoriebricklayer:::.bl_wb_get("/save/status/user", "Accept: application/json")
  skip_if(r$status < 0L, "archive.org is not reachable from here")
  expect_true(r$status %in% c(-1L, 200L, 401L, 403L, 429L, 502L, 503L, 520L, 523L))
  p <- rmoriebricklayer:::.bl_wb_post("url=https%3A%2F%2Fexample.org%2F", "Accept: application/json")
  expect_true(p$status %in% c(-1L, 200L, 401L, 403L, 429L, 502L, 503L, 520L, 523L))
  s <- rmoriebricklayer:::.bl_wb_lookup("https://www.r-project.org/")
  expect_true(is.null(s) || grepl("^https?://web.archive.org/web/", s))
  expect_null(rmoriebricklayer:::.bl_wb_json(list(body = raw(0))))
  expect_null(rmoriebricklayer:::.bl_wb_json(list(body = charToRaw("<html>no</html>"))))
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
  expect_equal(attr(r2, "retry"), data.frame(failed = 3L, found_by_lookup = 1L, captured_again = 1L, left_as_gone = 1L))
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
  expect_true(any(grepl("1 failures: 0 found already archived, 1 captured again, 0 left as gone; now 2 saved", outl)))
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
