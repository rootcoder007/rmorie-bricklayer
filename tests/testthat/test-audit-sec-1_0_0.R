# The open findings of the pre-CRAN audit of 30bed8e: the capsule CLI's sources
# (#6-#10), the JSON u escape (#12), the grouped key, and the LOW list of #17.
# Each test reproduces the audit's case first. No network: fdl(), the archive's
# transport and the resolver are mocked where a test needs them. Nothing here
# reads standard input.

sec_cli <- function(args) {
  rec <- new.env()
  rec$txt <- character()
  st <- blcli(args, out = function(s) rec$txt <- c(rec$txt, s))
  list(status = st, out = paste(rec$txt, collapse = ""))
}

# a capsule under a root of its own, whose provenance names `src`; data.csv is
# pinned
sec_capsule <- function(src, filename = "data.csv", env = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = env)
  d <- file.path(root, "cap")
  dir.create(d)
  utils::write.csv(
    data.frame(
      id = 1:30,
      v = rep(c("a", "b", "c"), 10),
      stringsAsFactors = FALSE
    ),
    file.path(d, "data.csv"),
    row.names = FALSE
  )
  prov <- list(
    name = "t",
    resource = list(
      filename = filename,
      direct_url = src,
      sha256 = sha256file(file.path(d, "data.csv"))
    ),
    table = list(rounding = 5, suppression_limit = 10)
  )
  writeLines(
    tojs(prov, auto_unbox = TRUE),
    file.path(d, "data_provenance.json")
  )
  list(root = root, dir = d)
}

test_that(
  paste0(
    "#6: a source outside the capsule is never read, /proc/self/environ ",
    "included"
  ),
  {
    testthat::local_mocked_bindings(.bl_readline = function(...) {
      stop("a test read standard input")
    })
    # the audit's case: a creds.csv whose header is a secret, named by an
    # absolute path
    outside <- withr::local_tempdir()
    creds <- file.path(outside, "creds.csv")
    writeLines(c("MY_SECRET_TOKEN=v27-SECRET-0001", "1"), creds)
    cp <- sec_capsule(creds)
    r <- sec_cli(c("drift", cp$dir))
    expect_identical(r$status, 1L)
    expect_false(grepl("MY_SECRET_TOKEN", r$out, fixed = TRUE))
    expect_match(
      r$out,
      "a local source must be a file inside the capsule",
      fixed = TRUE
    )
    r <- sec_cli(c("drift", cp$dir, "--json"))
    expect_false(grepl("MY_SECRET_TOKEN", r$out, fixed = TRUE))
    # refresh copies nothing in
    expect_error(
      cpsrfrsh(cp$dir),
      "cpsrfrsh: a local source must be a file inside the capsule"
    )
    expect_identical(
      sort(list.files(cp$dir)),
      c("data.csv", "data_provenance.json")
    )
    # relative, through .., and the process's own environment
    for (s in c(
      file.path("..", "..", basename(outside), "creds.csv"),
      "/proc/self/environ",
      "/dev/stdin"
    )) {
      cp <- sec_capsule(s)
      x <- cpschk(cp$root, "drift", fp = FALSE)
      expect_identical(x$status, "error", info = s)
      expect_match(
        x$rows$detail[x$rows$check == "source_fetched"],
        "a local source must be a file inside",
        info = s
      )
    }
    # even inside an allowfile folder, never /proc
    cp <- sec_capsule("/proc/self/environ")
    if (dir.exists("/proc/self")) {
      expect_error(
        cpsrfrsh(cp$dir, allowfile = "/proc/self"),
        "a local source must be a file inside the capsule"
      )
    }
    expect_error(
      cpsrfrsh(cp$dir, allowfile = "/"),
      "cpsrfrsh: `allowfile` must not be the root of the file system"
    )
    expect_error(
      cpsrfrsh(cp$dir, allowfile = file.path(outside, "nope")),
      "cpsrfrsh: `allowfile` must be TRUE or FALSE, or an existing folder"
    )
    # an explicit allowfile folder admits its files, as a path or a file:// URL
    cp <- sec_capsule(creds)
    expect_identical(cpsrfrsh(cp$dir, allowfile = outside)$change, "changed")
    cp <- sec_capsule(paste0("file://", creds))
    expect_error(
      cpsrfrsh(cp$dir, allowfile = TRUE),
      "a local source must be a file inside the capsule or the"
    )
    expect_identical(cpsrfrsh(cp$dir, allowfile = outside)$change, "changed")
    # with TRUE, cpschk() admits files under the folder it checks
    cp <- sec_capsule(paste0(
      "file://",
      file.path(withr::local_tempdir(), "x.csv")
    ))
    writeLines(c("id", "1"), file.path(cp$root, "shared.csv"))
    p <- loadprov(file.path(cp$dir, "data_provenance.json"))
    p$resource$direct_url <- paste0("file://", file.path(cp$root, "shared.csv"))
    writeLines(
      tojs(p, auto_unbox = TRUE),
      file.path(cp$dir, "data_provenance.json")
    )
    expect_false(any(
      cpschk(cp$root, "drift", allowfile = TRUE, fp = FALSE)$rows$check ==
        "source_fetched"
    ))
    # a fetched source is https only
    cp <- sec_capsule("http://example.org/data.csv")
    expect_error(
      cpsrfrsh(cp$dir),
      "cpsrfrsh: a source to fetch must be an https:// URL: http://example.org"
    )
    cp <- sec_capsule("ftp://example.org/data.csv")
    expect_error(cpsrfrsh(cp$dir), "a source to fetch must be an https:// URL")
  }
)

test_that(
  paste0(
    "#6: a link inside the capsule that ",
    "points out of it is not followed"
  ),
  {
    skip_on_os("windows")
    outside <- withr::local_tempdir()
    writeLines(
      c("MY_SECRET_TOKEN=v27-SECRET-0001", "1"),
      file.path(outside, "creds.csv")
    )
    cp <- sec_capsule("source.csv")
    file.symlink(
      file.path(outside, "creds.csv"),
      file.path(cp$dir, "source.csv")
    )
    r <- sec_cli(c("drift", cp$dir))
    expect_false(grepl("MY_SECRET_TOKEN", r$out, fixed = TRUE))
    expect_error(
      cpsrfrsh(cp$dir),
      "a local source must be a file inside the capsule: source.csv"
    )
  }
)

test_that("#7: resource$filename out of the capsule is not read by drift", {
  outside <- withr::local_tempdir()
  dir.create(file.path(outside, "outside"))
  writeLines(
    c("OUTSIDE_HEADER_SECRET", "1"),
    file.path(outside, "outside", "outside.csv")
  )
  cp <- sec_capsule("source.csv", filename = "../../outside/outside.csv")
  utils::write.csv(
    data.frame(id = 1:3),
    file.path(cp$dir, "source.csv"),
    row.names = FALSE
  )
  file.rename(
    file.path(outside, "outside"),
    file.path(dirname(cp$root), "outside")
  )
  on.exit(
    unlink(file.path(dirname(cp$root), "outside"), recursive = TRUE),
    add = TRUE
  )
  x <- cpschk(cp$root, "drift", fp = FALSE)
  expect_false(grepl("OUTSIDE_HEADER_SECRET", format(x), fixed = TRUE))
  expect_false(grepl(
    "OUTSIDE_HEADER_SECRET",
    format(x, fmt = "json"),
    fixed = TRUE
  ))
  expect_null(x$capsules[[1]]$drift)
})

test_that(
  paste0(
    "#8: refresh never writes through a ",
    "provenance link out of the capsule"
  ),
  {
    skip_on_os("windows")
    outside <- withr::local_tempdir()
    cp <- sec_capsule("source.csv")
    utils::write.csv(
      data.frame(id = 1:5),
      file.path(cp$dir, "source.csv"),
      row.names = FALSE
    )
    target <- file.path(outside, "victim.json")
    file.copy(file.path(cp$dir, "data_provenance.json"), target)
    unlink(file.path(cp$dir, "data_provenance.json"))
    file.symlink(target, file.path(cp$dir, "data_provenance.json"))
    before <- sha256file(target)
    expect_error(
      cpsrfrsh(cp$dir),
      "cpsrfrsh: data_provenance.json is a link out of the capsule: not written"
    )
    expect_identical(sha256file(target), before)
    r <- sec_cli(c("refresh", cp$root))
    expect_identical(r$status, 1L)
    expect_identical(sha256file(target), before)
  }
)

test_that("#9: a gzip source inflates no further than maxcsvbytes", {
  withr::local_options(rmoriebricklayer.maxcsvbytes = 1e5)
  gz <- function(path, n) {
    con <- gzfile(path, "wb")
    on.exit(close(con), add = TRUE)
    writeLines(c("id,v", rep("1,a", n)), con)
  }
  # the bomb, its ISIZE honest: refused before inflating
  cp <- sec_capsule("source.csv.gz")
  gz(file.path(cp$dir, "source.csv.gz"), 2e5)
  x <- cpschk(cp$root, "drift", fp = FALSE)
  expect_match(
    x$rows$detail[x$rows$check == "source_columns"],
    "source.csv.gz inflates to more than 100,000 bytes"
  )
  # ISIZE lying (zeroed): the count while inflating refuses it
  f <- file.path(cp$dir, "source.csv.gz")
  b <- readBin(f, "raw", file.size(f))
  b[(length(b) - 3L):length(b)] <- as.raw(0L)
  writeBin(b, f)
  x <- cpschk(cp$root, "drift", fp = FALSE)
  expect_match(
    x$rows$detail[x$rows$check == "source_columns"],
    "inflates to more than 100,000 bytes"
  )
  # a gzip under the limit is read, and its columns compared
  gz(f, 50)
  x <- cpschk(cp$root, "drift", fp = FALSE)
  expect_false(is.null(x$capsules[[1]]$drift))
  # the row count of a refresh goes through the same reader
  p <- loadprov(file.path(cp$dir, "data_provenance.json"))
  p$resource$row_count_data_rows <- 30
  writeLines(
    tojs(p, auto_unbox = TRUE),
    file.path(cp$dir, "data_provenance.json")
  )
  expect_identical(cpsrfrsh(cp$dir)$change, "changed")
  expect_identical(
    loadprov(file.path(
      cp$dir,
      "data_provenance.json"
    ))$resource$row_count_data_rows,
    50L
  )
  gz(f, 2e5)
  expect_error(
    cpsrfrsh(cp$dir),
    "cpsrfrsh: source.csv.gz inflates to more than 100,000 bytes"
  )
  writeLines("", file.path(cp$dir, "source.csv.gz"))
  expect_error(
    cpsrfrsh(cp$dir),
    "cpsrfrsh: the source does not read as a CSV, so its rows cannot be counted"
  )
})

test_that(
  paste0(
    "#10: an empty --public-key is a usage ",
    "error, an empty keyexp is refused"
  ),
  {
    testthat::local_mocked_bindings(.bl_readline = function(...) {
      stop("a test read standard input")
    })
    d <- withr::local_tempdir()
    r <- sec_cli(c("verify", d, "--public-key", ""))
    expect_identical(r$status, 2L)
    expect_match(r$out, "--public-key was given an empty value", fixed = TRUE)
    expect_identical(sec_cli(c("drift", d, "--cache", ""))$status, 2L)
    m <- list(resource = list(filename = "a.csv", sha256 = "01"))
    att <- cpsatst(m, "shared-secret")
    expect_error(
      cpschkatst(att, m, keyexp = ""),
      "cpschkatst: `keyexp` is empty"
    )
    expect_error(
      cpschkatst(att, m, keyexp = c("a", "b")),
      "cpschkatst: `keyexp` is empty"
    )
    expect_error(
      cpsbndlvrf(list(), d, keyexp = "  "),
      "cpsbndlvrf: `keyexp` is empty"
    )
  }
)

test_that("#12: a u escape takes four hex digits and nothing else", {
  expect_error(fromjs('["\\u 041"]'), "invalid \\\\u escape")
  expect_error(fromjs('{"\\u-041":1}'), "invalid \\\\u escape")
  expect_error(fromjs('["\\u0x41"]'), "invalid \\\\u escape")
  expect_error(fromjs('["\\u+041"]'), "invalid \\\\u escape")
  expect_identical(fromjs('["\\u0041\\u00e9"]'), "Aé")
  # a high surrogate followed by a bad escape is lone
  expect_error(fromjs('["\\ud800\\u 041"]'), "lone surrogate")
  expect_identical(fromjs('{"\\u0041":1}'), list(A = 1L))
})

test_that("a grouped key joined by any separator with no space is a key", {
  ns <- asNamespace("rmoriebricklayer")
  for (s in c("!", "#", "$", "%", "&", "*", ",", ";", "@", "^", "|", "~")) {
    q <- sprintf("is abcd1234efgh%sijkl5678mnop%sqrst9012uvwx ok?", s, s)
    expect_true(ns$.bl_key_shaped(q), info = s)
    expect_false(ns$.bl_bare_question(q), info = s)
  }
  expect_true(ns$.bl_key_shaped("abcd1234efgh;ijkl5678mnop qrst9012uvwx"))
  # a question is still one
  expect_true(ns$.bl_bare_question(
    "what does the drift test compare, column by column?"
  ))
  expect_false(ns$.bl_key_shaped("compare 2019;2020;2021 rates?"))
})

test_that("#17: an all-letters AWS access key id is a key", {
  ns <- asNamespace("rmoriebricklayer")
  expect_true(ns$.bl_key_shaped("my key is AKIAABCDEFGHIJKLMNOP, is it set?"))
  expect_true(ns$.bl_key_shaped("ASIAQWERTYUIOPASDFGH"))
  expect_false(ns$.bl_bare_question("is AKIAABCDEFGHIJKLMNOP right?"))
  expect_false(ns$.bl_key_shaped("AKIA is a prefix"))
})

test_that(
  paste0(
    "#17: provider replies give the ",
    "package's messages, not R's warnings"
  ),
  {
    ns <- asNamespace("rmoriebricklayer")
    serve <- function(body) {
      testthat::local_mocked_bindings(
        .bl_http_post = function(...) {
          list(status = 200L, body = body, error = "")
        },
        .env = parent.frame()
      )
    }
    serve(charToRaw('{"id": 123456789012345678901, "choices": []}'))
    expect_no_warning(
      {
        r <- ns$.bl_post_json("https://api.example.org/v1", list(a = 1))
      }
    )
    expect_equal(r$json$id, 123456789012345678901, tolerance = 1e-8)
    serve(c(
      charToRaw('{"choices":[{"message":{"content":"caf'),
      as.raw(0xe9),
      charToRaw('"}}]}')
    ))
    expect_no_warning(
      {
        r <- ns$.bl_post_json("https://api.example.org/v1", list(a = 1))
      }
    )
    expect_identical(r$json$error$message, "the reply is not UTF-8 text")
    expect_error(
      ns$.bl_reply_error(r, "the route"),
      "the route answered 200: the reply is not UTF-8 text"
    )
    serve(c(charToRaw("{}"), as.raw(0L)))
    expect_identical(
      ns$.bl_post_json(
        "https://api.example.org/v1",
        list(a = 1)
      )$json$error$message,
      "the reply is not UTF-8 text"
    )
    expect_false(ns$.bl_utf8_body(rawToChar(as.raw(c(0x61, 0xff)))))
    expect_true(ns$.bl_utf8_body("{}"))
    bad <- rawToChar(as.raw(c(
      0x7b,
      0x22,
      0x61,
      0x22,
      0x3a,
      0x22,
      0xff,
      0x22,
      0x7d
    )))
    expect_no_warning(expect_error(ns$.rmbl_json_text(bad), "not UTF-8 text"))
    expect_no_warning(expect_null(ns$.bl_sse_error(bad)))
  }
)

test_that(
  paste0(
    "#17: wbsave() refuses a public name ",
    "that resolves to a private address"
  ),
  {
    testthat::local_mocked_bindings(
      .bl_wb_resolved_why = function(u) {
        "intranet.example.com resolves to a local or private address (10.0.0.7)"
      }
    )
    expect_error(
      wbsave(
        "https://intranet.example.com/x",
        ak = "a",
        sk = "b",
        quiet = TRUE
      ),
      paste0(
        "wbsave: not a public address, so it is not sent to archive.org: ",
        "https://intranet.example.com/x"
      )
    )
    # a name this machine cannot resolve is the archive's to resolve: it goes on
    # to be sent
    testthat::local_mocked_bindings(
      .bl_wb_resolved_why = function(u) "could not resolve example.org",
      .bl_wb_post = function(body, headers) stop("sent to the archive")
    )
    expect_error(
      wbsave("https://example.org/x", ak = "a", sk = "b", quiet = TRUE),
      "sent to the archive"
    )
  }
)

test_that("#17: latin1 text is decoded by the JSON parser in a C locale", {
  x <- "[\"caf\xe9\"]"
  Encoding(x) <- "latin1"
  expect_identical(fromjs(x), "café")
  withr::with_locale(
    c(LC_CTYPE = "C"),
    expect_identical(enc2utf8(fromjs(x)), "café")
  )
  expect_identical(fromjs(c(x, "")), "café")
})

test_that("#17: sparse records simplify as before, with a column at a time", {
  recs <- lapply(1:60, function(i) {
    r <- list(id = i)
    if (i %% 3 == 0) {
      r$a <- "x"
    }
    if (i %% 5 == 0) {
      r$b <- i * 1.5
    }
    if (i %% 7 == 0) {
      r$c <- TRUE
    }
    if (i %% 11 == 0) {
      r$d <- list(1, 2)
    }
    r
  })
  df <- fromjs(tojs(recs, auto_unbox = TRUE))
  expect_named(df, c("id", "a", "b", "c", "d"))
  expect_identical(df$id, 1:60)
  expect_identical(df$a, ifelse(1:60 %% 3 == 0, "x", NA))
  expect_identical(df$b, ifelse(1:60 %% 5 == 0, 1:60 * 1.5, NA))
  expect_identical(df$c, ifelse(1:60 %% 7 == 0, TRUE, NA))
  expect_identical(df$d[[11]], c(1L, 2L))
  expect_null(df$d[[1]])
  # "NA" and "Inf" become numbers beside numbers, and a null is NA
  df <- fromjs('[{"x": 1}, {"x": "Inf"}, {"x": null}, {"y": 2}, {"x": "NA"}]')
  expect_identical(df$x, c(1, Inf, NA, NA, NA))
  expect_identical(fromjs('[{"x": "a"}, {"x": "NA"}]')$x, c("a", "NA"))
  # a repeated key keeps its first value, as before
  expect_identical(
    fromjs('[{"x": 1, "x": 2}, {"x": 3}]', duplicate_keys = "keep")$x,
    c(1L, 3L)
  )
  expect_identical(nrow(fromjs('[{"x": null}, {"x": null}]')), 2L)
  skip_if_not_installed("jsonlite")
  js <- tojs(recs, auto_unbox = TRUE)
  expect_equal(fromjs(js), jsonlite::fromJSON(js), tolerance = 1e-8)
})

test_that("#17: a symlink loop under the path lists each capsule once", {
  skip_on_os("windows")
  cp <- sec_capsule("source.csv")
  file.symlink(cp$root, file.path(cp$dir, "loop"))
  ns <- asNamespace("rmoriebricklayer")
  expect_length(ns$.bl_capsule_dirs(cp$root), 1L)
  x <- cpschk(cp$root, fp = FALSE)
  expect_length(x$capsules, 1L)
  expect_lt(nchar(format(x)), 20000L)
})

test_that(
  paste0(
    "#17: the drift report escapes a ",
    "capsule's directory name in its HTML"
  ),
  {
    skip_on_os("windows")
    root <- withr::local_tempdir()
    d <- file.path(root, "<img src=x onerror=alert(1)>")
    dir.create(d)
    writeLines(
      '{"resource": {"filename": "data.csv"}}',
      file.path(d, "data_provenance.json")
    )
    md <- format(cpschk(root, fp = FALSE))
    expect_false(grepl("<code>[^<]*<img", md))
    expect_match(md, "&lt;img src=x onerror=alert(1)&gt;</code>", fixed = TRUE)
  }
)

test_that(
  paste0(
    "#17: a 404 source is not looked up in the archive, and its download is ",
    "deleted"
  ),
  {
    seen <- new.env()
    testthat::local_mocked_bindings(fdl = function(
      url,
      tpath,
      attwb = NULL,
      allowfile = FALSE
    ) {
      seen$attwb <- attwb
      seen$tpath <- tpath
      writeLines("partial", tpath)
      FALSE
    })
    cp <- sec_capsule("https://example.org/gone.csv")
    x <- cpschk(cp$root, "drift", fp = FALSE)
    expect_identical(seen$attwb, "")
    expect_false(file.exists(seen$tpath))
    expect_match(
      x$rows$detail[x$rows$check == "source_fetched"],
      "could not be fetched"
    )
    # a fetched file is deleted after the check too
    testthat::local_mocked_bindings(fdl = function(
      url,
      tpath,
      attwb = NULL,
      allowfile = FALSE
    ) {
      seen$tpath <- tpath
      utils::write.csv(
        data.frame(id = 1:30, v = "z", stringsAsFactors = FALSE),
        tpath,
        row.names = FALSE
      )
      TRUE
    })
    x <- cpschk(cp$root, "drift", fp = FALSE)
    expect_false(is.null(attr(x, "drifts")[[1]]))
    expect_false(file.exists(seen$tpath))
    expect_s3_class(attr(attr(x, "drifts")[[1]], "data")$cur, "data.frame")
  }
)

test_that("#17: fdl() does not swallow a time limit", {
  testthat::local_mocked_bindings(.bl_fetch_file = function(
    url,
    dest,
    allow_file = FALSE
  ) {
    t0 <- Sys.time()
    while (Sys.time() - t0 < 3) {
      NULL
    }
    TRUE
  })
  t0 <- proc.time()[["elapsed"]]
  r <- tryCatch(
    {
      setTimeLimit(elapsed = 0.5, transient = TRUE)
      suppressMessages(fdl(
        "https://example.org/x.csv",
        tempfile(),
        attwb = "https://web.archive.org/web/x"
      ))
    },
    error = function(e) conditionMessage(e)
  )
  setTimeLimit()
  expect_match(r, "time limit")
  expect_lt(proc.time()[["elapsed"]] - t0, 6)
  ns <- asNamespace("rmoriebricklayer")
  expect_false(ns$.rmbl_time_limit("cannot open the connection"))
})

test_that("#17: RMBL_KEY leaves the process at once, its startup copy wiped", {
  testthat::local_mocked_bindings(.bl_readline = function(...) {
    stop("a test read standard input")
  })
  withr::local_envvar(RMBL_KEY = "a-secret-for-the-test")
  expect_identical(
    sec_cli(c("verify", file.path(tempdir(), "no-such-dir")))$status,
    2L
  )
  expect_identical(Sys.getenv("RMBL_KEY"), "")
  expect_error(
    .Call(asNamespace("rmoriebricklayer")$C_rmbl_env_wipe, NA_character_),
    "must be one string"
  )
  skip_on_cran()
  skip_if_not(file.exists("/proc/self/environ"), "no /proc/self/environ here")
  rs <- file.path(R.home("bin"), "Rscript")
  code <- paste0(
    "d <- tempfile(); dir.create(d); ",
    "invisible(rmoriebricklayer::blcli(c('verify', d), ",
    "out = function(s) NULL)); e <- readBin('/proc/self/environ', ",
    "'raw', 1e6); ",
    "e[e == as.raw(0)] <- as.raw(10); cat(grepl('k3y-v4lue-9x', ",
    "rawToChar(e), fixed = TRUE))"
  )
  out <- withr::with_envvar(
    c(
      RMBL_KEY = "k3y-v4lue-9x",
      R_TESTS = NA,
      R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep)
    ),
    system2(
      rs,
      c("--vanilla", "-e", shQuote(code)),
      stdout = TRUE,
      stderr = FALSE
    )
  )
  expect_identical(utils::tail(out, 1L), "FALSE")
})
