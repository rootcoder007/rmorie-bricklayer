# archive.rmorie.com from R: arcfind(), arcget(), arccap(upload =),
# fetchvrf(arcs =), wbsave(fallback =), against an in-memory archive standing in
# for the transport seam .bl_arc_req()

fake_archive <- function() {
  s <- new.env()
  s$blobs <- list()
  s$caps <- list()
  s$calls <- list()
  s$fail <- list()
  reply <- function(status, json = NULL, body = NULL) {
    if (is.null(body)) {
      body <- if (is.null(json)) {
        raw(0)
      } else {
        charToRaw(as.character(tojs(json, auto_unbox = TRUE)))
      }
    }
    list(status = as.integer(status), json = json, body = body, error = "")
  }
  s$handle <- function(
    method,
    path,
    body = NULL,
    file = NULL,
    ctype = "",
    key = NULL,
    base = "",
    timeout = 60L
  ) {
    s$calls[[length(s$calls) + 1L]] <- list(
      method = method,
      path = path,
      key = key,
      body = body
    )
    f <- s$fail[[paste(method, sub("[?/].*$", "", sub("^/", "", path)))]]
    if (!is.null(f)) {
      return(f)
    }
    if (method == "GET" && grepl("^/cdx/search/cdx", path)) {
      u <- utils::URLdecode(sub("^.*[?&]url=([^&]*).*$", "\\1", path))
      matches <- function(c) {
        if (endsWith(u, "*")) {
          startsWith(c$url, sub("\\*$", "", u))
        } else {
          identical(c$url, u)
        }
      }
      row <- function(c) {
        list(
          "k",
          c$ts,
          c$url,
          c$mime,
          "200",
          paste0("sha256:", c$sha),
          as.character(c$len),
          c$id,
          c$sha,
          "client",
          c$visibility
        )
      }
      rows <- lapply(Filter(matches, s$caps), row)
      return(reply(
        200,
        c(
          list(list(
            "urlkey",
            "timestamp",
            "original",
            "mimetype",
            "statuscode",
            "digest",
            "length",
            "capture_id",
            "sha256",
            "mode",
            "visibility"
          )),
          rows
        )
      ))
    }
    if (method == "GET" && grepl("^/v1/captures/", path)) {
      c <- s$caps[[sub("^/v1/captures/", "", path)]]
      if (is.null(c)) {
        return(reply(404, list(error = "no such capture, or it is private")))
      }
      return(reply(
        200,
        list(id = c$id, url = c$url, ts = c$ts, sha256 = c$sha)
      ))
    }
    if (method == "GET" && grepl("^/v1/blob/", path)) {
      return(reply(
        if (is.null(s$blobs[[sub("^/v1/blob/", "", path)]])) 404 else 200
      ))
    }
    if (method == "PUT" && grepl("^/v1/blob/", path)) {
      sha <- sub("^/v1/blob/", "", path)
      b <- readBin(file, "raw", file.size(file))
      if (!identical(csha256(b), sha)) {
        return(reply(
          400,
          list(error = "the bytes do not hash to that SHA-256")
        ))
      }
      s$blobs[[sha]] <- b
      return(reply(201, list(ok = TRUE)))
    }
    if (method == "POST" && path == "/v1/captures") {
      id <- sprintf("%s-%08x", body$timestamp, length(s$caps) + 1L)
      s$caps[[id]] <- list(
        id = id,
        url = body$url,
        ts = body$timestamp,
        sha = body$sha256,
        len = body$length,
        mime = body$mime,
        visibility = body$visibility
      )
      return(reply(
        201,
        list(
          capture_id = id,
          capture = paste0("https://archive.rmorie.com/capture/", id)
        )
      ))
    }
    if (method == "GET" && grepl("^/b/", path)) {
      b <- s$blobs[[sub("^/b/", "", path)]]
      return(
        if (is.null(b)) {
          reply(404, list(error = "not found"))
        } else {
          reply(200, body = b)
        }
      )
    }
    reply(404, list(error = "no route"))
  }
  s$add <- function(url, bytes, ts = "20261020120000") {
    sha <- csha256(bytes)
    s$blobs[[sha]] <- bytes
    id <- sprintf("%s-%08x", ts, length(s$caps) + 1L)
    s$caps[[id]] <- list(
      id = id,
      url = url,
      ts = ts,
      sha = sha,
      len = length(bytes),
      mime = "text/csv",
      visibility = "public"
    )
    id
  }
  s
}

with_archive <- function(s, code, key = "sk-test-key") {
  local_mocked_bindings(
    .bl_arc_req = function(
      method,
      path,
      body = NULL,
      file = NULL,
      ctype = "application/octet-stream",
      key = NULL,
      base = "",
      timeout = 60L
    ) {
      s$handle(method, path, body, file, ctype, key, base, timeout)
    },
    .bl_hosted_key = function() key,
    .package = "rmoriebricklayer",
    .env = environment()
  )
  withr::local_envvar(MORIE_ARCHIVE_URL = NA, MORIE_ARCHIVE_KEY = NA)
  force(code)
}

cap_stub <- function(serve) {
  force(serve)
  function(url, dest, wb = "", tmout = 120L) {
    b <- serve[[url]]
    if (is.null(b)) {
      stop("blfetch: could not reach", call. = FALSE)
    }
    writeBin(b, dest)
    invisible("live")
  }
}

test_that(
  paste0(
    "the archive address and its key: archive.rmorie.com gets the stored ",
    "key, any other archive its own"
  ),
  {
    withr::local_envvar(MORIE_ARCHIVE_URL = NA, MORIE_ARCHIVE_KEY = NA)
    expect_identical(.bl_arc_base(), "https://archive.rmorie.com")
    local_mocked_bindings(.bl_hosted_key = function() "sk-stored")
    expect_identical(.bl_arc_key("https://archive.rmorie.com"), "sk-stored")
    expect_null(.bl_arc_key("https://other.example.org"))
    withr::local_envvar(MORIE_ARCHIVE_KEY = "sk-other")
    expect_identical(.bl_arc_key("https://other.example.org"), "sk-other")
    withr::local_envvar(MORIE_ARCHIVE_URL = "http://127.0.0.1:8790/")
    expect_identical(.bl_arc_base(), "http://127.0.0.1:8790")
    withr::local_envvar(MORIE_ARCHIVE_URL = "ftp://x.org")
    expect_error(.bl_arc_base(), "http\\(s\\) address with no path")
    withr::local_envvar(MORIE_ARCHIVE_URL = "https://x.org/path")
    expect_error(.bl_arc_base(), "no path")
    withr::local_envvar(MORIE_ARCHIVE_URL = "http://plain.example.org")
    expect_error(.bl_arc_base())
  }
)

test_that(
  paste0(
    "one request: the key goes only in the Authorization header, the reply ",
    "is parsed"
  ),
  {
    seen <- new.env()
    local_mocked_bindings(.bl_net = function(url, expr) {
      seen$url <- url
      list(status = 200L, body = charToRaw('{"a":1}'), error = "")
    })
    r <- .bl_arc_req(
      "GET",
      "/x",
      key = "sk-k",
      base = "https://archive.rmorie.com"
    )
    expect_identical(seen$url, "https://archive.rmorie.com/x")
    expect_identical(r$status, 200L)
    expect_identical(r$json$a, 1L)
    r <- .bl_arc_req(
      "POST",
      "/v1/captures",
      body = list(b = 2),
      base = "https://archive.rmorie.com"
    )
    expect_identical(r$status, 200L)
    f <- withr::local_tempfile()
    writeLines("x", f)
    expect_identical(
      .bl_arc_req(
        "PUT",
        "/v1/blob/a",
        file = f,
        base = "https://archive.rmorie.com"
      )$status,
      200L
    )
    expect_error(
      .bl_arc_req("DELETE", "/x", base = "https://archive.rmorie.com"),
      "unknown method"
    )
    local_mocked_bindings(.bl_net = function(url, expr) {
      list(status = 502L, body = charToRaw("<html>"), error = "")
    })
    r <- .bl_arc_req("GET", "/x", base = "https://archive.rmorie.com")
    expect_null(r$json)
    local_mocked_bindings(.bl_net = function(url, expr) {
      list(status = NULL, body = raw(0), error = NULL)
    })
    r <- .bl_arc_req("GET", "/x", base = "https://archive.rmorie.com")
    expect_identical(r$status, -1L)
    expect_identical(r$error, "")
  }
)

test_that("a failed reply is said in the package's words", {
  why <- function(status, json = NULL, error = "") {
    .bl_arc_why(list(status = status, json = json, error = error), "x")
  }
  expect_match(why(-1L, error = "timeout"), "did not answer \\(timeout\\)")
  expect_match(why(0L), "no reply")
  expect_match(why(451L, list(error = "refused")), "HTTP 451 \\(refused\\)")
  expect_match(why(500L), "HTTP 500$")
})

test_that(
  paste0(
    "arcfind() lists captures oldest first, with their pages and ",
    "exact-bytes addresses"
  ),
  {
    s <- fake_archive()
    s$add("https://s.org/a.csv", charToRaw("a,b\n1,2\n"), "20250101000000")
    s$add("https://s.org/a.csv", charToRaw("a,b\n1,3\n"), "20261020120000")
    s$add("https://s.org/b.csv", charToRaw("x\n"), "20261021000000")
    with_archive(s, {
      f <- arcfind("https://s.org/a.csv")
      expect_s3_class(f, "rmbl_archive_find")
      expect_identical(nrow(f), 2L)
      expect_identical(format(f$captured[1], "%Y", tz = "UTC"), "2025")
      expect_match(
        f$replay[2],
        "^https://archive.rmorie.com/c/20261020120000id_/https://s.org/a.csv$"
      )
      expect_match(f$capture[1], "/capture/")
      expect_output(
        print(f),
        "2 captures in https://archive.rmorie.com, 2 distinct copies"
      )
      expect_identical(nrow(arcfind("https://s.org/*")), 3L)
      expect_match(s$calls[[1]]$path, "from=|limit=1000")
      arcfind("https://s.org/a.csv", from = 2025, to = "202612")
      expect_match(s$calls[[length(s$calls)]]$path, "&from=2025&to=202612$")
      none <- arcfind("https://s.org/none.csv")
      expect_identical(nrow(none), 0L)
      expect_output(print(none), "No capture in")
      expect_error(
        arcfind("https://s.org/a.csv", from = "20x"),
        "4 to 14 digits"
      )
      s$fail[["GET cdx"]] <- list(
        status = 503L,
        json = list(error = "busy"),
        body = raw(0),
        error = ""
      )
      expect_error(arcfind("https://s.org/a.csv"), "HTTP 503 \\(busy\\)")
    })
    many <- fake_archive()
    for (i in 1:22) {
      many$add(
        "https://s.org/m.csv",
        charToRaw(sprintf("%d\n", i)),
        sprintf("2026%02d01000000", (i %% 12) + 1L)
      )
    }
    with_archive(
      many,
      expect_output(print(arcfind("https://s.org/m.csv")), "and 2 more")
    )
    one <- fake_archive()
    one$add("https://s.org/o.csv", charToRaw("o\n"))
    with_archive(
      one,
      expect_output(
        print(arcfind("https://s.org/o.csv")),
        "1 capture in .*1 distinct copy of"
      )
    )
  }
)

test_that(
  paste0(
    "arcget() fetches exact bytes by id or address, and refuses any other ",
    "bytes"
  ),
  {
    s <- fake_archive()
    old <- charToRaw("a,b\n1,2\n")
    new <- charToRaw("a,b\n1,3\n")
    id1 <- s$add("https://s.org/a.csv", old, "20250101000000")
    s$add("https://s.org/a.csv", new, "20261020120000")
    with_archive(s, {
      d <- withr::local_tempfile()
      f <- arcget(id1, d)
      expect_identical(readBin(d, "raw", 100), old)
      expect_identical(attr(f, "capture_id"), id1)
      expect_identical(attr(f, "sha256"), csha256(old))
      # an address: the latest, or the one closest to `at`, or the one with the
      # pinned SHA-256
      arcget("https://s.org/a.csv", d)
      expect_identical(readBin(d, "raw", 100), new)
      arcget("https://s.org/a.csv", d, at = "2025")
      expect_identical(readBin(d, "raw", 100), old)
      arcget("https://s.org/a.csv", d, sha256 = toupper(csha256(old)))
      expect_identical(readBin(d, "raw", 100), old)
      expect_error(
        arcget("https://s.org/a.csv", d, sha256 = strrep("0", 64)),
        "no capture of .* has SHA-256"
      )
      expect_error(
        arcget(id1, d, sha256 = strrep("0", 64)),
        "not the one asked for"
      )
      expect_error(arcget("https://s.org/none.csv", d), "has no capture of")
      expect_error(arcget("20990101000000-00000000", d), "HTTP 404")
      expect_error(arcget(id1, d, sha256 = "xyz"), "64 hexadecimal")
      # the archive answering other bytes than its record: nothing is written
      s$blobs[[csha256(old)]] <- charToRaw("tampered")
      unlink(d)
      expect_error(arcget(id1, d), "hash to .* not to the capture's")
      expect_false(file.exists(d))
      s$fail[["GET b"]] <- list(
        status = 500L,
        json = NULL,
        body = raw(0),
        error = ""
      )
      expect_error(arcget(id1, d), "the bytes of capture .*HTTP 500")
    })
    # a destination that cannot be written; a time that is not one
    s2 <- fake_archive()
    id <- s2$add("https://s.org/w.csv", charToRaw("w\n"))
    with_archive(s2, {
      expect_error(
        arcget("https://s.org/w.csv", withr::local_tempfile(), at = "20x"),
        "4 to 14 digits"
      )
      local_mocked_bindings(.bl_move = function(from, to) FALSE)
      expect_error(arcget(id, withr::local_tempfile()), "cannot write")
    })
  }
)

test_that(
  paste0(
    "arccap(upload = 'rmorie') writes WARC files and uploads each capture ",
    "once"
  ),
  {
    s <- fake_archive()
    save1 <- function() {
      arccap(
        "https://s.org/a.csv",
        tempfile("cap"),
        tsa = NULL,
        upload = "rmorie",
        reason = "Tables cited in a methods paper"
      )
    }
    dir <- withr::local_tempdir()
    local_mocked_bindings(
      blfetch = cap_stub(list(
        "https://s.org/a.csv" = charToRaw("a,b\n1,2\n"),
        "https://s.org/b.zip" = charToRaw("PK")
      ))
    )
    with_archive(s, {
      cap <- arccap(
        c("https://s.org/a.csv", "https://s.org/b.zip"),
        dir,
        tsa = NULL,
        upload = "rmorie",
        reason = "Tables cited in a methods paper, ch. 3",
        visibility = "private"
      )
      d <- as.data.frame(unclass(cap))
      expect_identical(d$status, c("archived", "archived"))
      expect_true(all(grepl("^https://archive.rmorie.com/capture/", d$archive)))
      expect_true(all(file.exists(d$warc)))
      expect_true(file.exists(file.path(dir, "indexes", "index.cdxj")))
      expect_length(s$blobs, 2L)
      posted <- Filter(function(c) c$method == "POST", s$calls)
      expect_identical(posted[[1]]$body$visibility, "private")
      expect_identical(posted[[1]]$body$mime, "text/csv")
      expect_identical(posted[[2]]$body$mime, "application/zip")
      expect_true(all(vapply(
        s$calls,
        function(c) identical(c$key, "sk-test-key"),
        TRUE
      )))
      expect_output(print(cap), "archive.rmorie.com +2 saved")
      # the same bytes again: checked, not sent again
      n <- length(Filter(function(c) c$method == "PUT", s$calls))
      save1()
      expect_length(Filter(function(c) c$method == "PUT", s$calls), n)
      # a failing archive keeps the local copy and says so
      s$fail[["POST v1"]] <- list(
        status = 451L,
        json = list(error = "refused"),
        body = raw(0),
        error = ""
      )
      cap <- save1()
      expect_match(
        cap$status,
        "failed: recording the capture.*451.*kept locally"
      )
      s$fail[["GET v1"]] <- list(
        status = 500L,
        json = NULL,
        body = raw(0),
        error = ""
      )
      cap <- save1()
      expect_match(cap$status, "checking the archive")
      s$fail[["GET v1"]] <- NULL
      s$blobs <- list()
      s$fail[["PUT v1"]] <- list(
        status = 413L,
        json = list(error = "too big"),
        body = raw(0),
        error = ""
      )
      cap <- save1()
      expect_match(cap$status, "uploading the bytes.*413")
    })
    with_archive(s, key = NULL, {
      expect_error(
        arccap(
          "https://s.org/a.csv",
          withr::local_tempdir(),
          tsa = NULL,
          upload = "rmorie",
          reason = "Tables cited in a methods paper"
        ),
        "needs your key"
      )
    })
  }
)

test_that(
  paste0(
    "arccap() checks upload, reason, visibility and warc before fetching ",
    "anything"
  ),
  {
    local_mocked_bindings(blfetch = function(...) stop("must not be called"))
    d <- withr::local_tempdir()
    expect_error(
      arccap("https://s.org/a", d, upload = "dropbox"),
      "`upload` must be"
    )
    expect_error(
      arccap("https://s.org/a", d, upload = character()),
      "`upload` must be"
    )
    expect_error(
      arccap("https://s.org/a", d, upload = "rmorie"),
      "`reason` is needed"
    )
    expect_error(
      arccap("https://s.org/a", d, upload = "rmorie", reason = "short"),
      "20 characters"
    )
    expect_error(
      arccap("https://s.org/a", d, visibility = "secret"),
      "should be one of"
    )
    expect_error(
      arccap("https://s.org/a", d, warc = NA),
      "`warc` must be TRUE or FALSE"
    )
  }
)

test_that(
  paste0(
    "arccap(upload = 'wayback') asks the Wayback Machine too, and says when ",
    "it cannot"
  ),
  {
    dir <- withr::local_tempdir()
    wb <- function(urls, status, timestamp) {
      d <- data.frame(url = urls, status = status, timestamp = timestamp)
      structure(d, class = c("rmbl_wayback_save", "data.frame"))
    }
    local_mocked_bindings(
      blfetch = cap_stub(list(
        "https://s.org/a.csv" = charToRaw("a"),
        "https://s.org/b.csv" = charToRaw("b")
      )),
      wbsave = function(urls, ...) wb(urls[1], "saved", "20261022000000")
    )
    cap <- arccap(
      c("https://s.org/a.csv", "https://s.org/b.csv"),
      dir,
      tsa = NULL,
      upload = "wayback",
      warc = FALSE
    )
    expect_identical(cap$wayback, c("saved 20261022000000", NA))
    expect_true(all(is.na(cap$warc)))
    local_mocked_bindings(wbsave = function(urls, ...) {
      stop("wbsave() needs your archive.org keys")
    })
    cap <- arccap(
      "https://s.org/a.csv",
      withr::local_tempdir(),
      tsa = NULL,
      upload = "wayback"
    )
    expect_match(
      cap$wayback,
      "^not asked: wbsave\\(\\) needs your archive.org keys"
    )
    local_mocked_bindings(wbsave = function(urls, ...) {
      wb(urls, "failed", NA_character_)
    })
    cap <- arccap(
      "https://s.org/a.csv",
      withr::local_tempdir(),
      tsa = NULL,
      upload = "wayback"
    )
    expect_identical(cap$wayback, "failed")
  }
)

test_that("media types from file names", {
  expect_identical(.bl_arc_mime("x.CSV"), "text/csv")
  expect_identical(
    .bl_arc_mime("a/b/c.parquet"),
    "application/vnd.apache.parquet"
  )
  expect_identical(.bl_arc_mime("noext"), "application/octet-stream")
  expect_identical(.bl_arc_mime("x.weird"), "application/octet-stream")
})

test_that(
  paste0(
    "fetchvrf() falls back to archive.rmorie.com, then to a capture ",
    "folder's WARC files"
  ),
  {
    s <- fake_archive()
    body <- charToRaw("a,b\n1,2\n")
    s$add("https://s.org/gone.csv", body)
    dest <- withr::local_tempfile()
    local_mocked_bindings(blfetch = function(...) {
      stop("blfetch: answered HTTP 404; the Wayback fallback failed too")
    })
    with_archive(s, {
      r <- fetchvrf("https://s.org/gone.csv", dest, sha256 = csha256(body))
      expect_identical(r$source, "rmorie")
      expect_identical(readBin(dest, "raw", 100), body)
      expect_identical(r$tried$outcome[2], "kept")
    })
    # no archive copy, but a folder arccap() wrote
    dir <- withr::local_tempdir()
    local_mocked_bindings(
      blfetch = cap_stub(list("https://s.org/local.csv" = body))
    )
    arccap("https://s.org/local.csv", dir, tsa = NULL)
    local_mocked_bindings(blfetch = function(...) {
      stop("blfetch: could not reach")
    })
    with_archive(fake_archive(), {
      r <- fetchvrf(
        "https://s.org/local.csv",
        dest,
        sha256 = csha256(body),
        arcs = c("rmorie", dir)
      )
      expect_identical(r$source, "local")
      expect_match(
        r$tried$outcome[2],
        "^failed: archive.rmorie.com has no capture"
      )
      expect_error(
        fetchvrf("https://s.org/local.csv", dest, arcs = character()),
        "no source served the file"
      )
      expect_error(
        fetchvrf("https://s.org/local.csv", dest, arcs = NA_character_),
        "`arcs` must be"
      )
    })
    # a destination that cannot be written arcget() places its download (the
    # first move); fetchvrf() then cannot place the file (the second)
    with_archive(s, {
      rec <- new.env()
      rec$moves <- 0L
      local_mocked_bindings(.bl_move = function(from, to) {
        rec$moves <- rec$moves + 1L
        if (rec$moves == 1L) file.rename(from, to) else FALSE
      })
      expect_error(
        fetchvrf(
          "https://s.org/gone.csv",
          withr::local_tempfile(),
          sha256 = csha256(body)
        ),
        "^cannot write"
      )
    })
  }
)

test_that(
  paste0(
    "a capture folder's WARC files are read back exactly, and damage is ",
    "caught"
  ),
  {
    dir <- withr::local_tempdir()
    body <- charToRaw("x,y\n3,4\n")
    local_mocked_bindings(
      blfetch = cap_stub(list("https://s.org/w.csv" = body))
    )
    arccap("https://s.org/w.csv", dir, tsa = NULL)
    g <- withr::local_tempfile()
    .bl_warc_get(dir, "https://s.org/w.csv", g, csha256(body))
    expect_identical(readBin(g, "raw", 100), body)
    expect_error(
      .bl_warc_get(withr::local_tempdir(), "https://s.org/w.csv", g),
      "has no index"
    )
    expect_error(
      .bl_warc_get(dir, "https://s.org/other.csv", g),
      "no capture of"
    )
    w <- list.files(file.path(dir, "archive"), full.names = TRUE)
    raw <- readBin(w, "raw", file.size(w))
    i <- grepRaw("3,4", raw)
    raw[i] <- charToRaw("9")
    writeBin(raw, w)
    expect_error(
      .bl_warc_get(dir, "https://s.org/w.csv", g),
      "does not match its index"
    )
    writeBin(charToRaw("WARC/1.1\r\nno blank line"), w)
    idx <- file.path(dir, "indexes", "index.cdxj")
    l <- readLines(idx)
    writeLines(
      sub(
        '"offset":"[0-9]+"',
        '"offset":"0"',
        sub('"length":"[0-9]+"', '"length":"24"', l)
      ),
      idx
    )
    expect_error(
      .bl_warc_get(dir, "https://s.org/w.csv", g),
      "damaged WARC record"
    )
  }
)

test_that(
  paste0(
    "wbsave(fallback = 'rmorie') saves what the Wayback Machine refused to ",
    "archive.rmorie.com"
  ),
  {
    expect_error(
      wbsave("https://s.org/a", fallback = "dropbox"),
      "`fallback` must be"
    )
    out <- structure(
      data.frame(
        url = c(
          "https://s.org/ok",
          "https://s.org/refused",
          "https://s.org/other"
        ),
        status = c("saved", "failed", "failed"),
        message = c(
          NA,
          "The target server cannot find the page",
          "Server timed out"
        ),
        stringsAsFactors = FALSE
      ),
      class = c("rmbl_wayback_save", "data.frame")
    )
    got <- new.env()
    local_mocked_bindings(arccap = function(urls, dir, ..., upload, reason) {
      got$urls <- urls
      got$upload <- upload
      "captured"
    })
    res <- .bl_wb_fallback(out, "Tables cited in a methods paper")
    expect_identical(got$urls, "https://s.org/refused")
    expect_identical(got$upload, "rmorie")
    expect_identical(attr(res, "archive"), "captured")
    expect_null(attr(.bl_wb_fallback(out[1, ], "x"), "archive"))
    local_mocked_bindings(arccap = function(...) {
      stop("archive.rmorie.com needs your key")
    })
    expect_match(attr(.bl_wb_fallback(out, NULL), "archive"), "needs your key")
  }
)

test_that(
  paste0(
    "a finished download is moved into ",
    "place, and a failed move says so"
  ),
  {
    f1 <- withr::local_tempfile()
    f2 <- withr::local_tempfile()
    writeLines("x", f1)
    expect_true(.bl_move(f1, f2))
    expect_false(.bl_move(f1, f2))
  }
)

test_that("rmbl archive: save, find and get from a terminal", {
  rec <- new.env()
  rec$outbuf <- character()
  run <- function(...) {
    rec$outbuf <- character()
    st <- blcli(c("archive", ...), out = function(s) {
      rec$outbuf <- c(rec$outbuf, s)
    })
    list(status = st, text = paste(rec$outbuf, collapse = ""))
  }
  expect_identical(run()$status, 2L)
  expect_match(run("help")$text, "archive get ID")
  expect_identical(run("help")$status, 0L)
  # the command list of `rmbl help` names it too
  expect_match(
    paste(capture.output(blcli("help")), collapse = "\n"),
    "archive find URL | get ID -o FILE",
    fixed = TRUE
  )
  expect_identical(run("save")$status, 2L)
  expect_match(run("save", "https://s.org/a")$text, "needs --reason")
  expect_match(
    run("save", "https://s.org/a", "--reason", "x", "--also", "dropbox")$text,
    "--also takes one value"
  )
  expect_match(run("get", "https://s.org/a")$text, "needs -o FILE")
  got <- new.env()
  local_mocked_bindings(
    arccap = function(urls, dir, tsa, upload, reason, visibility) {
      got$upload <- upload
      got$visibility <- visibility
      got$dir <- dir
      structure(
        data.frame(
          url = urls,
          status = c("archived", "failed: refused")[seq_along(urls)],
          archive = c("https://archive.rmorie.com/capture/1", NA)[seq_along(
            urls
          )]
        ),
        class = c("rmbl_archive_capture", "data.frame")
      )
    },
    arcfind = function(url, from = NULL, to = NULL) {
      got$from <- from
      structure(
        data.frame(
          capture_id = "20261020120000-00000001",
          captured = as.POSIXct("2026-10-20 12:00:00", tz = "UTC"),
          url = url,
          status = 200L,
          mime = "text/csv",
          bytes = 3,
          sha256 = strrep("a", 64),
          mode = "client",
          visibility = "public",
          capture = "c",
          replay = "r",
          stringsAsFactors = FALSE
        ),
        archive = "https://archive.rmorie.com",
        class = c("rmbl_archive_find", "data.frame")
      )
    },
    arcget = function(x, dest, sha256 = NULL, at = NULL) {
      structure(
        dest,
        capture_id = "20261020120000-00000001",
        sha256 = strrep("a", 64)
      )
    }
  )
  r <- run(
    "save",
    "https://s.org/a",
    "--reason",
    "Tables cited in a methods paper",
    "--private",
    "--also",
    "wayback",
    "--dir",
    "d1"
  )
  expect_identical(r$status, 0L)
  expect_identical(got$upload, c("rmorie", "wayback"))
  expect_identical(got$visibility, "private")
  expect_identical(got$dir, "d1")
  expect_match(
    r$text,
    "archived  https://s.org/a\n  https://archive.rmorie.com/capture/1"
  )
  r <- run(
    "save",
    "https://s.org/a",
    "https://s.org/b",
    "--reason",
    "Tables cited in a methods paper"
  )
  expect_identical(r$status, 1L)
  expect_identical(got$upload, "rmorie")
  expect_identical(got$visibility, "public")
  expect_match(r$text, "failed: refused  https://s.org/b")
  r <- run("find", "https://s.org/a", "--from", "2025")
  expect_identical(r$status, 0L)
  expect_identical(got$from, "2025")
  expect_match(r$text, "1 capture in https://archive.rmorie.com")
  r <- run("find", "https://s.org/a", "--json")
  expect_match(r$text, "\"captured\":\"2026-10-20T12:00:00Z\"", fixed = TRUE)
  local_mocked_bindings(arcfind = function(url, from = NULL, to = NULL) {
    empty <- data.frame(
      capture_id = character(),
      captured = as.POSIXct(character(), tz = "UTC"),
      sha256 = character(),
      stringsAsFactors = FALSE
    )
    structure(
      empty,
      archive = "a",
      class = c("rmbl_archive_find", "data.frame")
    )
  })
  expect_identical(run("find", "https://s.org/none")$status, 1L)
  r <- run("get", "20261020120000-00000001", "-o", "out.csv")
  expect_identical(r$status, 0L)
  expect_match(r$text, "out.csv  capture 20261020120000-00000001")
})

# cpschk(archive = TRUE): the archive copy with the pinned SHA-256 when the
# source and its Wayback snapshot cannot be fetched, and wbsave(fallback =
# "rmorie") in refresh
cps_capsule <- function(bytes = "a,b\n1,2\n") {
  d <- withr::local_tempdir(.local_envir = parent.frame())
  writeLines(bytes, file.path(d, "data.csv"), sep = "")
  prov <- list(
    resource = list(
      direct_url = "https://example.org/data.csv",
      filename = "data.csv",
      sha256 = sha256file(file.path(d, "data.csv"))
    )
  )
  writeLines(
    tojs(prov, auto_unbox = TRUE),
    file.path(d, "data_provenance.json")
  )
  d
}

test_that(
  paste0(
    ".bl_fetch_pin() takes the archive copy with the pinned SHA-256 when ",
    "the source fails"
  ),
  {
    d <- cps_capsule()
    pin <- sha256file(file.path(d, "data.csv"))
    rec <- new.env()
    rec$asked <- NULL
    local_mocked_bindings(
      fdl = function(url, dest, ...) stop("HTTP 503"),
      arcget = function(x, dest, sha256 = NULL, ...) {
        rec$asked <- list(x = x, sha256 = sha256)
        file.copy(file.path(d, "data.csv"), dest, overwrite = TRUE)
        invisible(dest)
      }
    )
    f <- .bl_fetch_pin(d, archive = TRUE)
    on.exit(.bl_fetch_cleanup(f), add = TRUE)
    expect_true(f$archived)
    expect_false(f$cached)
    expect_identical(
      rec$asked,
      list(x = "https://example.org/data.csv", sha256 = pin)
    )
    expect_identical(f$new$resource$sha256, pin)
  }
)

test_that(
  paste0(
    ".bl_fetch_pin() leaves the archive alone unless asked, and when ",
    "nothing is pinned"
  ),
  {
    d <- cps_capsule()
    rec <- new.env()
    rec$called <- FALSE
    local_mocked_bindings(
      fdl = function(url, dest, ...) stop("HTTP 503"),
      arcget = function(...) {
        rec$called <- TRUE
        stop("no")
      }
    )
    expect_error(.bl_fetch_pin(d), "503")
    expect_false(rec$called)
    # asked, but the archive has no copy: the fetch error stands
    expect_error(.bl_fetch_pin(d, archive = TRUE), "503")
    expect_true(rec$called)
    p <- loadprov(file.path(d, "data_provenance.json"))
    p$resource$sha256 <- NULL
    writeLines(tojs(p, auto_unbox = TRUE), file.path(d, "data_provenance.json"))
    rec$called <- FALSE
    expect_error(.bl_fetch_pin(d, archive = TRUE), "503")
    expect_false(rec$called)
  }
)

test_that("cpschk(archive = TRUE) notes the archive copy in drift", {
  d <- cps_capsule()
  local_mocked_bindings(
    fdl = function(url, dest, ...) stop("HTTP 503"),
    arcget = function(x, dest, ...) {
      file.copy(file.path(d, "data.csv"), dest, overwrite = TRUE)
      invisible(dest)
    }
  )
  x <- cpschk(d, "drift", fp = FALSE, cache = FALSE, archive = TRUE)
  expect_match(
    paste(unlist(x$capsules[[1L]]$notes), collapse = " "),
    "archive.rmorie.com with the pinned SHA-256"
  )
  expect_error(cpschk(d, archive = NA), "archive")
})

test_that(
  paste0(
    "refresh with wayback hands wbsave() the archive fallback and notes ",
    "what it did"
  ),
  {
    d <- cps_capsule()
    rec <- new.env()
    rec$got <- NULL
    wb <- function(status, arch) {
      function(urls, ...) {
        rec$got <- list(...)
        out <- data.frame(
          url = urls,
          status = status,
          snapshot = NA_character_,
          message = "HTTP status=403",
          stringsAsFactors = FALSE
        )
        attr(out, "archive") <- arch
        out
      }
    }
    f <- list(
      src = "https://example.org/data.csv",
      new = list(resource = list())
    )
    o <- list(wayback = TRUE, archive = TRUE)
    local_mocked_bindings(.bl_write_pin = function(d, f) {
      stop("stop after the wayback step")
    })
    local_mocked_bindings(
      wbsave = wb(
        "failed",
        structure(
          data.frame(
            status = "archived",
            archive = "https://a/c/1",
            stringsAsFactors = FALSE
          ),
          class = "data.frame"
        )
      )
    )
    out <- .bl_refresh_capsule(d, f, o, list(notes = NULL))
    expect_identical(rec$got$fallback, "rmorie")
    expect_match(rec$got$reason, "^Source of the data capsule ")
    expect_gte(nchar(rec$got$reason), 20L)
    expect_true(any(grepl(
      "saved instead, https://a/c/1",
      out$notes,
      fixed = TRUE
    )))
    local_mocked_bindings(
      wbsave = wb("failed", structure("sign in first", class = "rmbl_fail"))
    )
    out <- .bl_refresh_capsule(d, f, o, list(notes = NULL))
    expect_true(any(grepl("archive.rmorie.com: sign in first", out$notes)))
    local_mocked_bindings(
      wbsave = wb(
        "failed",
        data.frame(
          status = "failed: upload answered 401",
          archive = NA,
          stringsAsFactors = FALSE
        )
      )
    )
    out <- .bl_refresh_capsule(d, f, o, list(notes = NULL))
    expect_true(any(grepl(
      "archive.rmorie.com: failed: upload answered 401",
      out$notes
    )))
    # without archive = TRUE, wbsave() is called as before
    local_mocked_bindings(wbsave = wb("failed", NULL))
    out <- .bl_refresh_capsule(
      d,
      f,
      list(wayback = TRUE, archive = FALSE),
      list(notes = NULL)
    )
    expect_null(rec$got$fallback)
    expect_null(rec$got$reason)
    expect_false(any(grepl("archive.rmorie.com", out$notes)))
  }
)

test_that(
  paste0(
    "in GitHub Actions with id-token: write, the job's OIDC token stands in ",
    "for a key"
  ),
  {
    rm(list = ls(.bl_oidc_cache), envir = .bl_oidc_cache)
    withr::local_envvar(
      ACTIONS_ID_TOKEN_REQUEST_URL = NA,
      ACTIONS_ID_TOKEN_REQUEST_TOKEN = NA
    )
    expect_null(.bl_gh_oidc("https://archive.rmorie.com"))
    withr::local_envvar(
      ACTIONS_ID_TOKEN_REQUEST_URL = paste0(
        "https://run.actions.example/tok",
        "en?api-version=2.0"
      ),
      ACTIONS_ID_TOKEN_REQUEST_TOKEN = "req-token"
    )
    rec <- new.env()
    rec$asked <- NULL
    rec$n <- 0L
    local_mocked_bindings(.bl_net = function(url, expr) {
      rec$asked <- url
      rec$n <- rec$n + 1L
      list(
        status = 200L,
        body = charToRaw('{"count":1,"value":"eyJ.github.jwt"}'),
        error = ""
      )
    })
    expect_identical(
      .bl_gh_oidc("https://archive.rmorie.com"),
      "eyJ.github.jwt"
    )
    expect_identical(
      rec$asked,
      paste0(
        "https://run.actions.example/token?api-version=2.0&audience=https%3A%",
        "2F%2Farchive.rmorie.com"
      )
    )
    # kept for a few minutes: no second request
    expect_identical(
      .bl_gh_oidc("https://archive.rmorie.com"),
      "eyJ.github.jwt"
    )
    expect_identical(rec$n, 1L)
    # the stored key wins; without one, archive.rmorie.com gets the token,
    # another archive never does
    local_mocked_bindings(.bl_hosted_key = function() "sk-stored")
    expect_identical(.bl_arc_key("https://archive.rmorie.com"), "sk-stored")
    local_mocked_bindings(.bl_hosted_key = function() NULL)
    expect_identical(
      .bl_arc_key("https://archive.rmorie.com"),
      "eyJ.github.jwt"
    )
    withr::local_envvar(MORIE_ARCHIVE_KEY = NA)
    expect_null(.bl_arc_key("https://other.example"))
    rm(list = ls(.bl_oidc_cache), envir = .bl_oidc_cache)
    # a refused request, a reply without a token, a plain-http address: no token
    local_mocked_bindings(.bl_net = function(url, expr) {
      list(status = 403L, body = raw(0), error = "")
    })
    expect_null(.bl_gh_oidc("https://archive.rmorie.com"))
    local_mocked_bindings(.bl_net = function(url, expr) {
      list(status = 200L, body = charToRaw("{}"), error = "")
    })
    expect_null(.bl_gh_oidc("https://archive.rmorie.com"))
    local_mocked_bindings(.bl_net = function(url, expr) stop("offline"))
    expect_null(.bl_gh_oidc("https://archive.rmorie.com"))
    withr::local_envvar(
      ACTIONS_ID_TOKEN_REQUEST_URL = "http://run.actions.example/token"
    )
    expect_null(.bl_gh_oidc("https://archive.rmorie.com"))
    # a URL without a query gets "?audience="
    withr::local_envvar(
      ACTIONS_ID_TOKEN_REQUEST_URL = "https://run.actions.example/token"
    )
    local_mocked_bindings(.bl_net = function(url, expr) {
      rec$asked <- url
      list(status = 200L, body = charToRaw('{"value":"t2"}'), error = "")
    })
    expect_identical(.bl_gh_oidc("https://archive.rmorie.com"), "t2")
    expect_match(rec$asked, "token\\?audience=")
    rm(list = ls(.bl_oidc_cache), envir = .bl_oidc_cache)
  }
)

# Prints `x` on an ASCII console: the lines and what print() returned.
o1_box <- function(x, ...) {
  withr::local_envvar(RMBL_ASCII_ONLY = "1")
  tmp <- withr::local_tempfile()
  v <- withr::with_output_sink(tmp, withVisible(print(x, ...)))
  list(out = readLines(tmp), v = v)
}

# The box's frame, its title and the facts expected in it.
o1_expect_box <- function(b, x, title, facts = character()) {
  expect_false(b$v$visible)
  expect_identical(b$v$value, x)
  expect_match(b$out[1L], "^\\+-- ")
  expect_true(grepl(title, b$out[1L], fixed = TRUE))
  expect_match(b$out[length(b$out)], "^\\+-+\\+$")
  for (f in facts) {
    expect_true(any(grepl(f, b$out, fixed = TRUE)), info = f)
  }
}

test_that("found copies print as a box", {
  x <- data.frame(
    capture_id = "c1",
    captured = as.POSIXct("2026-01-02 03:04:00", tz = "UTC"),
    url = "https://s.org/a",
    status = 200L,
    mime = "text/csv",
    bytes = 4,
    sha256 = strrep("a", 64),
    stringsAsFactors = FALSE
  )
  class(x) <- c("rmbl_archive_find", "data.frame")
  attr(x, "archive") <- "https://archive.rmorie.com"
  o1_expect_box(
    o1_box(x),
    x,
    "Saved copies",
    c("1 capture in", "1 distinct copy", "aaaaaaaaaaaa...")
  )
  none <- x[0, ]
  expect_true(any(grepl("No capture in", format(none), fixed = TRUE)))
})

test_that("the list of saved copies shows each address and replay link", {
  x <- structure(
    data.frame(
      capture_id = "20261022075911-8c43b620",
      captured = as.POSIXct("2026-10-22 07:59:11", tz = "UTC"),
      url = "https://example.org/t.zip",
      status = 200L,
      mime = "application/zip",
      bytes = 92815,
      sha256 = strrep("ab", 32L),
      mode = "client",
      visibility = "public",
      replay = "https://archive.rmorie.com/c/x/https://example.org/t.zip",
      stringsAsFactors = FALSE
    ),
    class = c("rmbl_archive_find", "data.frame"),
    archive = "https://archive.rmorie.com"
  )
  txt <- format(x)
  expect_true(any(grepl("address +https://example[.]org/t[.]zip", txt)))
  expect_true(any(grepl("replay", txt, fixed = TRUE)))
  expect_true(any(grepl("application/zip", txt, fixed = TRUE)))
  expect_true(any(grepl("public", txt, fixed = TRUE)))
})

test_that("a capture list without addresses has no link lines", {
  expect_null(.bl_arc_find_links(
    data.frame(id = "a", stringsAsFactors = FALSE)
  ))
})
