# arcmine(), arcvis(), arcwd() and their `rmbl archive` verbs: the captures a
# key saved, against a stand-in for the archive.

own_stub <- function(env) {
  function(method, path, body = NULL, key = NULL, ...) {
    env$calls[[length(env$calls) + 1L]] <-
      list(method = method, path = path, body = body, key = key)
    ok <- function(x) list(status = 200L, json = x, body = "", error = "")
    if (method == "GET") {
      return(ok(list(captures = env$rows)))
    }
    cid <- sub("^/v1/captures/([^/]+)/.*$", "\\1", path)
    if (grepl("/visibility$", path)) {
      return(ok(list(capture_id = cid, visibility = body$visibility)))
    }
    if (grepl("-00000000/withdraw$", path)) {
      return(list(
        status = 404L,
        json = list(error = "no such capture of yours"),
        body = "",
        error = ""
      ))
    }
    ok(list(
      capture_id = cid,
      url = "https://example.org/",
      withdrawn = TRUE,
      was = env$was,
      bytes_removed = identical(env$was, "private")
    ))
  }
}

own_env <- function(was = "private") {
  e <- new.env()
  e$calls <- list()
  e$was <- was
  e$rows <- list(
    list(
      capture_id = "20260102030405-0123abcd",
      url = "https://example.org/a",
      timestamp = "20260102030405",
      status = 200L,
      mime = "text/html",
      sha256 = strrep("a", 64),
      length = 577L,
      mode = "client",
      visibility = "private",
      created_at = "2026-01-02T03:04:06Z",
      withdrawn_at = NULL
    ),
    list(
      capture_id = "20260101000000-89abcdef",
      url = "https://example.org/b",
      timestamp = "20260101000000",
      status = 404L,
      mime = "text/plain",
      sha256 = strrep("b", 64),
      length = 12L,
      mode = "worker",
      visibility = "public",
      created_at = "2026-01-01T00:00:01Z",
      withdrawn_at = "2026-01-05T00:00:00Z"
    ),
    "not a record"
  )
  e
}

id1 <- "20260102030405-0123abcd"

test_that("arcmine() lists the captures of the key, withdrawn ones marked", {
  e <- own_env()
  local_mocked_bindings(
    .bl_arc_base = function() "https://archive.rmorie.com",
    .bl_arc_key = function(base) "sk-test",
    .bl_arc_req = own_stub(e)
  )
  m <- arcmine(limit = 7)
  expect_s3_class(m, "rmbl_archive_find")
  expect_identical(nrow(m), 2L)
  expect_identical(m$capture_id[1], id1)
  expect_identical(m$withdrawn, c(FALSE, TRUE))
  expect_identical(m$bytes, c(577, 12))
  expect_identical(m$status, c(200L, 404L))
  expect_identical(format(m$captured[1], "%Y%m%d%H%M%S"), "20260102030405")
  expect_identical(e$calls[[1]]$path, "/v1/captures?limit=7")
  expect_identical(e$calls[[1]]$key, "sk-test")
  expect_output(print(m), "withdrawn")
  expect_error(arcmine(0), "limit")
  expect_error(arcmine(1001), "limit")
})

test_that("arcmine() says so when the answer is no list of captures", {
  local_mocked_bindings(
    .bl_arc_base = function() "https://my.archive.example",
    .bl_arc_key = function(base) "sk-test",
    .bl_arc_req = function(...) {
      list(status = 200L, json = list(captures = "x"), body = "", error = "")
    }
  )
  expect_error(arcmine(), "my.archive.example answered HTTP 200")
  local_mocked_bindings(
    .bl_arc_req = function(...) {
      list(status = 401L, json = list(error = "sign in"), body = "", error = "")
    }
  )
  expect_error(arcmine(), "HTTP 401")
})

test_that("the three need a key and a well-formed id", {
  local_mocked_bindings(
    .bl_arc_base = function() "https://my.archive.example",
    .bl_arc_key = function(base) NULL,
    .bl_arc_req = function(...) stop("no request may be sent")
  )
  expect_error(arcmine(), "my.archive.example needs your key")
  expect_error(arcvis(id1, "private"), "needs your key")
  expect_error(arcwd(id1, confirm = TRUE), "needs your key")
  for (bad in list("x", "20260102030405-0123ABCD", NA, 1, c(id1, id1))) {
    expect_error(arcvis(bad, "private"), "id")
    expect_error(arcwd(bad, confirm = TRUE), "id")
  }
})

test_that("arcvis() sends the visibility and refuses any other word", {
  e <- own_env()
  local_mocked_bindings(
    .bl_arc_base = function() "https://archive.rmorie.com",
    .bl_arc_key = function(base) "sk-test",
    .bl_arc_req = own_stub(e)
  )
  expect_message(r <- arcvis(id1, "private"), "now private")
  expect_identical(r, list(capture_id = id1, visibility = "private"))
  expect_identical(e$calls[[1]]$method, "POST")
  expect_identical(
    e$calls[[1]]$path,
    paste0("/v1/captures/", id1, "/visibility")
  )
  expect_identical(e$calls[[1]]$body, list(visibility = "private"))
  expect_message(arcvis(id1, "public"), "now public")
  expect_error(arcvis(id1, "secret"), "private")
  expect_error(arcvis(id1, c("private", "public")), "to")
  expect_length(e$calls, 2L)
})

test_that("arcwd() withdraws only when confirmed, and says what was removed", {
  e <- own_env("private")
  local_mocked_bindings(
    .bl_arc_base = function() "https://archive.rmorie.com",
    .bl_arc_key = function(base) "sk-test",
    .bl_arc_req = own_stub(e)
  )
  expect_error(arcwd(id1), "cannot be undone")
  expect_error(arcwd(id1, confirm = FALSE), "nothing was changed")
  expect_error(arcwd(id1, confirm = "yes"), "confirm")
  expect_length(e$calls, 0L)
  expect_message(r <- arcwd(id1, confirm = TRUE), "bytes were deleted")
  expect_true(r$bytes_removed)
  expect_identical(
    r,
    list(
      capture_id = id1,
      url = "https://example.org/",
      withdrawn = TRUE,
      was = "private",
      bytes_removed = TRUE
    )
  )
  expect_identical(
    e$calls[[1]]$path,
    paste0("/v1/captures/", id1, "/withdraw")
  )
  expect_identical(e$calls[[1]]$body, list(confirm = TRUE))
  e$was <- "public"
  expect_message(r <- arcwd(id1, confirm = TRUE), "bytes were kept")
  expect_false(r$bytes_removed)
  expect_error(
    arcwd("20260102030405-00000000", confirm = TRUE),
    "no such capture of yours"
  )
})

test_that("rmbl archive mine, private, public and withdraw", {
  e <- own_env("private")
  local_mocked_bindings(
    .bl_arc_base = function() "https://archive.rmorie.com",
    .bl_arc_key = function(base) "sk-test",
    .bl_arc_req = own_stub(e)
  )
  run <- function(...) {
    rec <- new.env()
    rec$buf <- character()
    st <- blcli(c(...), out = function(s) rec$buf <- c(rec$buf, s))
    list(status = st, text = paste(rec$buf, collapse = ""))
  }
  r <- run("archive", "mine")
  expect_identical(r$status, 0L)
  expect_match(r$text, id1, fixed = TRUE)
  r <- run("archive", "mine", "--json")
  j <- fromjs(r$text)
  expect_identical(j$capture_id[1], id1)
  expect_identical(j$withdrawn, c(FALSE, TRUE))
  r <- run("archive", "private", id1)
  expect_identical(r$status, 0L)
  expect_match(r$text, "now private", fixed = TRUE)
  expect_match(run("archive", "public", id1)$text, "now public", fixed = TRUE)
  n <- length(e$calls)
  r <- run("archive", "withdraw", id1)
  expect_identical(r$status, 2L)
  expect_match(r$text, "add --yes", fixed = TRUE)
  expect_length(e$calls, n)
  r <- run("archive", "withdraw", id1, "--yes")
  expect_identical(r$status, 0L)
  expect_match(r$text, "withdrawn; its stored bytes were deleted", fixed = TRUE)
  expect_identical(run("archive", "withdraw")$status, 2L)
  expect_identical(run("archive", "private")$status, 2L)
  e$rows <- list()
  expect_identical(run("archive", "mine")$status, 1L)
})
