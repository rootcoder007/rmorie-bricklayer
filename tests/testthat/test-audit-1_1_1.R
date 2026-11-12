# Findings of the black-box audit of 1.1.1 (every export, random and hostile
# input), each with the call that showed it.

test_that("quantiles with an infinite value agree with stats::quantile()", {
  for (x in list(c(-Inf, 1, 2), c(1, Inf), c(-Inf, 1), c(-Inf, 0, Inf))) {
    expect_identical(
      unname(cqnt(x)),
      stats::quantile(x, names = FALSE),
      info = toString(x)
    )
    expect_identical(cmed(x), stats::median(x), info = toString(x))
  }
  # two finite values whose difference overflows
  big <- c(-1.5e308, 1.5e308)
  expect_identical(cmed(big), stats::median(big))
  expect_identical(ciqr(c(-Inf, 1, 2, 3)), Inf)
})

test_that("the gamma CDF keeps its digits far below the shape", {
  for (a in c(10, 30, 200)) {
    for (x in c(1e-8, 1e-3, 1)) {
      expect_equal(
        cgamcdf(a, x),
        stats::pgamma(x, a),
        tolerance = 1e-11,
        info = paste(a, x)
      )
    }
  }
})

test_that("a bundle whose attestation has no signature is no bundle", {
  dir <- withr::local_tempdir()
  utils::write.csv(data.frame(x = 1:3), file.path(dir, "d.csv"))
  m <- mkmnf(list(dataset = "demo"), env = FALSE)
  p <- attr(cpsbndl(dir, m, "shared-secret"), "path")
  writeLines(
    sub("\"signature\":", "\"signaturX\":", readLines(p), fixed = TRUE),
    p
  )
  expect_error(cpsbndlrd(p), "not a capsule bundle")
  expect_error(
    cpsbndlvrf(p, dir, man = m, key = "shared-secret"),
    "not a capsule bundle"
  )
})

test_that("cpssign() names the keys it takes when given none of them", {
  expect_error(cpssign(charToRaw("a"), NULL), "fipskg\\(\\) or pqckg\\(\\)")
  expect_error(cpssign(charToRaw("a"), list(public = "00")), "shared secret")
})

test_that("a column name with a pipe, HTML or a line break stays in its cell", {
  d <- data.frame(
    yr = 2019:2021,
    n = c(5, 9, 7),
    g = "a|b",
    stringsAsFactors = FALSE
  )
  names(d)[2] <- "cases|<b>all</b>"
  md <- strsplit(
    yoymd(yoychg(d, names(d)[2], "yr", by = "g"), NULL),
    "\n",
    fixed = TRUE
  )[[1]]
  cells <- lengths(gregexpr("(?<!\\\\)\\|", md[1:5], perl = TRUE))
  expect_length(unique(cells), 1L)
  expect_false(any(grepl("<b>", md, fixed = TRUE)))

  e <- data.frame(yr = 2019:2021, n = c(5, 9, 7))
  names(e)[2] <- "cases\nper day"
  f <- withr::local_tempfile(fileext = ".csv")
  yoycsv(yoychg(e, names(e)[2], "yr"), f)
  expect_identical(nrow(utils::read.csv(f, comment.char = "#")), 3L)
  g <- withr::local_tempfile(fileext = ".tsv")
  yoytsv(yoychg(e, names(e)[2], "yr"), g)
  expect_identical(nrow(utils::read.delim(g, comment.char = "#")), 3L)
})

test_that("rptanl() escapes a pipe in a group label", {
  d <- data.frame(
    year = rep(2018:2020, 2),
    grp = rep(c("A|B", "C"), each = 3),
    n = c(5, 7, 9, 3, 4, 6),
    stringsAsFactors = FALSE
  )
  md <- strsplit(
    rptanl(anytab(d, value = "n", prd = "year", by = "grp")),
    "\n",
    fixed = TRUE
  )[[1]]
  tab <- grep("^\\|", md, value = TRUE)[1:4]
  cells <- lengths(gregexpr("(?<!\\\\)\\|", tab, perl = TRUE))
  expect_length(unique(cells), 1L)
})

test_that("the HTML report escapes a label once", {
  d <- data.frame(
    year = rep(2018:2020, 2),
    grp = rep(c("A|B & C <i>", "D"), each = 3),
    n = c(5, 7, 9, 3, 4, 6),
    stringsAsFactors = FALSE
  )
  h <- rptanl(
    anytab(d, value = "n", prd = "year", by = "grp"),
    withr::local_tempfile(fileext = ".html")
  )
  cell <- unique(regmatches(h, gregexpr("<td>A[^<]*</td>", h))[[1]])
  expect_identical(cell, "<td>A|B &amp; C &lt;i&gt;</td>")
})

test_that("a bundle whose file list holds no records is no bundle", {
  dir <- withr::local_tempdir()
  utils::write.csv(data.frame(x = 1:3), file.path(dir, "d.csv"))
  m <- mkmnf(list(dataset = "demo"), env = FALSE)
  p <- attr(cpsbndl(dir, m, "shared-secret"), "path")
  b <- fromjs(paste(readLines(p), collapse = "\n"), simplifyVector = FALSE)
  for (bad in list(list("d.csv"), 1, "x", list(list(path = 1)))) {
    b$files <- bad
    writeLines(tojs(b, auto_unbox = TRUE), p)
    expect_error(cpsbndlrd(p), "not a capsule bundle")
    expect_error(
      cpsbndlvrf(p, dir, man = m, key = "shared-secret"),
      "not a capsule bundle"
    )
  }
})

test_that("the archive client takes short rows and names the host it asked", {
  row <- list("org,example)/a", "20260101000000", "https://example.org/a",
              "text/plain", "200", "D", "20")
  out <- .bl_arc_rows(list(row), "http://x")
  expect_identical(out$url, "https://example.org/a")
  expect_identical(out$status, 200L)
  expect_true(is.na(out$capture_id))
  withr::local_envvar(MORIE_ARCHIVE_URL = "http://127.0.0.1:9")
  why <- .bl_arc_why(list(status = -1L, error = "refused", json = NULL), "x")
  expect_match(why, "127.0.0.1:9 did not answer", fixed = TRUE)
  local_mocked_bindings(
    .bl_arc_req = function(...) {
      list(status = 200L, json = NULL, body = "<html>", error = "")
    }
  )
  expect_error(
    arcget("20260101000000-0123abcd", withr::local_tempfile()),
    "no capture record"
  )
  expect_error(arcfind("https://example.org/a"), "no list of captures")
})

test_that("the sign-in wait holds to its limit whatever interval is sent", {
  for (iv in list(100000, "abc", -1, 0, NULL)) {
    local_mocked_bindings(
      .bl_hosted_auth = function() "https://auth.invalid",
      .bl_post_json = function(url, ...) {
        if (grepl("code$", url)) {
          list(
            status = 200L,
            json = list(
              verification_uri = "https://auth.invalid/go",
              user_code = "AB-12",
              device_code = "d",
              interval = iv
            )
          )
        } else {
          list(status = 428L, json = list())
        }
      }
    )
    t0 <- Sys.time()
    expect_error(
      suppressMessages(
        .bl_login_device(open_browser = FALSE, poll_max_seconds = 2)
      ),
      "timed out"
    )
    took <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    expect_lt(took, 8)
    expect_gt(took, 1)
  }
})

test_that("a key with a line break from the sign-in service is not stored", {
  stored <- FALSE
  local_mocked_bindings(
    .bl_hosted_auth = function() "https://auth.invalid",
    .bl_store_key = function(...) stored <<- TRUE,
    .bl_post_json = function(url, ...) {
      if (grepl("code$", url)) {
        list(status = 200L, json = list(
          verification_uri = "https://auth.invalid/go",
          user_code = "AB-12",
          device_code = "d",
          interval = 1
        ))
      } else {
        list(status = 200L, json = list(api_key = "sk-a\nb", user = "u"))
      }
    }
  )
  expect_error(
    suppressMessages(
      .bl_login_device(open_browser = FALSE, poll_max_seconds = 5)
    ),
    "nothing was stored"
  )
  expect_false(stored)
})

test_that("a model reply with a member of the wrong type is named as such", {
  for (api in c("openai", "anthropic", "gemini")) {
    for (bad in list(
      list(choices = "busy"),
      list(content = "x"),
      list(candidates = "x"),
      list(choices = list("x"))
    )) {
      r <- tryCatch(
        .bl_llm_parse(list(api = api), bad),
        error = function(e) conditionMessage(e)
      )
      if (is.character(r)) {
        expect_match(r, "format", info = api)
      } else {
        expect_named(r, c("text", "tool_calls", "finish"), info = api)
      }
    }
  }
})

test_that("arcget() refuses a listed capture that has no id or digest", {
  local_mocked_bindings(
    arcfind = function(...) {
      .bl_arc_rows(
        list(list("k", "20260101000000", "https://example.org/a",
                  "text/plain", "200", "D", "20")),
        "http://x"
      )
    }
  )
  dest <- withr::local_tempfile()
  expect_error(
    arcget("https://example.org/a", dest),
    "without a capture id or a SHA-256"
  )
  expect_false(file.exists(dest))
})

test_that("a provenance member of the wrong type is a failed row or NULL", {
  d <- withr::local_tempdir()
  utils::write.csv(data.frame(id = 1:3), file.path(d, "d.csv"))
  for (js in c(
    "{\"resource\": \"d.csv\"}",
    "{\"dataset\": 1, \"resource\": {\"filename\": \"d.csv\"}}",
    "{\"schema\": \"x\", \"source\": [1], \"script\": \"y\"}"
  )) {
    writeLines(js, file.path(d, "data_provenance.json"))
    r <- tryCatch(vrfcps(d), error = function(e) conditionMessage(e))
    if (is.character(r)) {
      expect_no_match(r, "operator is invalid", info = js)
    }
  }
  bad <- list(dataset = "x", resource = "d.csv")
  expect_null(rslvckan(bad))
  expect_null(rslvckns(bad))
  expect_null(rslvsoc(bad))
  expect_null(rslvarc(bad))
  expect_identical(.rmbl_recs("x"), list())
  expect_identical(.rmbl_recs(list("a", list(b = 1))), list(list(b = 1)))
  expect_null(.rmbl_ckan_pick("x", "a"))
})

test_that("an identity card whose date is no string fails as a row", {
  f <- withr::local_tempfile(fileext = ".json")
  idcrd(fipskg("ML-DSA-44"), "Ada Lovelace", file = f)
  txt <- readLines(f)
  writeLines(sub("\"issued_utc\": \"[^\"]*\"", "\"issued_utc\": []", txt), f)
  r <- idcrdvrf(f)
  expect_s3_class(r, "rmbl_id_check")
  expect_false(r$ok)
  expect_false(r$checks$ok[r$checks$check == "in_date"])
})

test_that("the verify and drift Markdown cells escape HTML", {
  expect_identical(.bl_md_esc("a|<img src=x>"), "a\\|&lt;img src=x&gt;")
  expect_identical(.bl_arc_host("https://my.archive.example"),
                   "my.archive.example")
})

test_that("a provenance text member that is not one string is dropped", {
  ep <- "https://open.canada.ca/data/api/3/action/package_show?id=abc"
  one <- .rmbl_prov_shape(list(resource = list(filename = list("d.csv"))))
  expect_identical(one$resource$filename, "d.csv")
  for (bad in list(42, NA, TRUE, list(), list("a", "b"), c("a", "b"))) {
    p <- .rmbl_prov_shape(list(
      dataset = list(ckan_api_endpoint = bad, publisher = "kept"),
      resource = list(search_query = bad, size_bytes = 3)
    ))
    expect_null(p$dataset$ckan_api_endpoint)
    expect_null(p$resource$search_query)
    expect_identical(p$dataset$publisher, "kept")
    expect_identical(p$resource$size_bytes, 3)
    expect_null(rslvckns(list(
      dataset = list(ckan_api_endpoint = ep),
      resource = list(search_query = bad)
    )))
    expect_null(rslvckan(list(
      dataset = list(ckan_api_endpoint = bad),
      resource = list(name_match_pattern = "d")
    )))
    expect_null(rslvckns(list(
      dataset = list(ckan_api_endpoint = bad),
      resource = list(search_query = "d")
    )))
  }
  ok <- .rmbl_prov_shape(list(
    dataset = list(ckan_api_endpoint = ep),
    resource = list(search_query = "d", filename = "d.csv")
  ))
  expect_identical(ok$dataset$ckan_api_endpoint, ep)
  expect_identical(ok$resource$filename, "d.csv")
})

test_that("a count written as text in a provenance file gives no warning", {
  d <- withr::local_tempdir()
  utils::write.csv(data.frame(id = 1:3), file.path(d, "d.csv"))
  writeLines(
    paste0(
      "{\"resource\": {\"filename\": \"d.csv\", ",
      "\"row_count_data_rows\": \"three\", \"size_bytes\": \"many\"}}"
    ),
    file.path(d, "data_provenance.json")
  )
  expect_no_warning(r <- vrfcps(d))
  expect_false(isTRUE(r$ok))
})

test_that("a code span in the verify table is not HTML-escaped", {
  expect_identical(.bl_md_code("R&D <b> a|b"), "`R&D <b> a\\|b`")
  expect_identical(.bl_md_code("a`b\nc"), "`` a`b c ``")
  root <- withr::local_tempdir()
  d <- file.path(root, "R&D survey")
  dir.create(d)
  utils::write.csv(data.frame(x = 1:3), file.path(d, "data.csv"))
  writeLines(
    "{\"resource\": {\"filename\": \"data.csv\"}}",
    file.path(d, "data_provenance.json")
  )
  buf <- character()
  blcli(
    c("verify", root, "--no-footprint"),
    out = function(s) buf <<- c(buf, s)
  )
  row <- grep("^\\| `", strsplit(paste(buf, collapse = ""), "\n")[[1]],
              value = TRUE)
  expect_length(row, 1L)
  expect_match(row, "R&D survey`", fixed = TRUE)
})

test_that("the missing-key advice fits the archive that was asked", {
  expect_match(.bl_arc_keyhow("https://archive.rmorie.com"), "dlogin()",
               fixed = TRUE)
  expect_match(.bl_arc_keyhow("https://my.archive.example"),
               "MORIE_ARCHIVE_KEY", fixed = TRUE)
  local_mocked_bindings(
    .bl_arc_base = function() "https://my.archive.example",
    .bl_arc_key = function(base) NULL
  )
  expect_error(arcmine(), "set MORIE_ARCHIVE_KEY")
})

test_that("a key the archive repeats in its error text is not shown", {
  local_mocked_bindings(
    .bl_arc_base = function() "http://127.0.0.1:9",
    .bl_arc_key = function(base) "SECRET-KEY-123",
    .bl_net = function(url, res) {
      list(
        status = 401L,
        body = charToRaw("{\"error\": \"bad key Bearer SECRET-KEY-123\"}"),
        error = ""
      )
    },
    .bl_loopback_url = function(base) FALSE
  )
  for (f in list(
    function() arcmine(),
    function() arcfind("https://example.org/"),
    function() arcvis("20260101120000-0123abcd", "private"),
    function() arcwd("20260101120000-0123abcd", confirm = TRUE)
  )) {
    msg <- tryCatch(f(), error = conditionMessage)
    expect_match(msg, "HTTP 401", fixed = TRUE)
    expect_no_match(msg, "SECRET-KEY-123", fixed = TRUE)
  }
})

test_that("arcvis() and arcwd() report only what the archive confirmed", {
  id <- "20260101120000-0123abcd"
  ans <- NULL
  local_mocked_bindings(
    .bl_arc_base = function() "https://archive.rmorie.com",
    .bl_arc_key = function(base) "sk-test",
    .bl_arc_req = function(...) {
      list(status = 200L, json = ans, body = "", error = "")
    }
  )
  for (bad in list(
    NULL,
    "sign in",
    list(),
    list(capture_id = 5, visibility = list("x")),
    list(visibility = "public"),
    list(withdrawn = "yes"),
    list(withdrawn = FALSE)
  )) {
    ans <- bad
    expect_error(arcvis(id, "private"), "without confirming the change")
    expect_error(arcwd(id, confirm = TRUE), "without confirming the change")
  }
  ans <- list(withdrawn = TRUE, was = list("odd"), bytes_removed = "x", url = 5)
  r <- suppressMessages(arcwd(id, confirm = TRUE))
  expect_identical(r$was, NA_character_)
  expect_false(r$bytes_removed)
  expect_identical(r$url, "5")
})
