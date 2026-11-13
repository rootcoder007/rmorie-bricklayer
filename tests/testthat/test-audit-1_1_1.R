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
  rec <- new.env()
  rec$buf <- character()
  blcli(
    c("verify", root, "--no-footprint"),
    out = function(s) rec$buf <- c(rec$buf, s)
  )
  lines <- strsplit(paste(rec$buf, collapse = ""), "\n", fixed = TRUE)[[1]]
  row <- lines[startsWith(lines, "| `")]
  expect_length(row, 1L)
  expect_match(row, "R&D survey`", fixed = TRUE)
})

# A server's error text as the package shows it: withheld whole when it
# repeats the key (the Save Page Now reader, .bl_wb_json())
errtext <- function(text, key) {
  body <- charToRaw(tojs(list(message = text), auto_unbox = TRUE))
  .bl_wb_json(list(body = body), key)$message
}

test_that("the key is withheld in every form a server may send it back", {
  key <- "s3cr+t/K=y_0123456789abcdefXYZ"
  b64 <- function(s) jsb64enc(charToRaw(s))
  half <- nchar(key) %/% 2L
  for (echo in c(
    paste("bad key Bearer", key),
    paste0("bad key ", substr(key, 1, half), "\n", substring(key, half + 1L)),
    paste0("bad key Bearer%20", utils::URLencode(key, reserved = TRUE)),
    paste("bad key", b64(paste("Bearer", key))),
    paste("bad key", b64(key)),
    paste("bad key", toupper(utils::URLencode(key, reserved = TRUE)))
  )) {
    got <- errtext(echo, key)
    flat <- gsub("[[:space:]]", "", got)
    expect_no_match(flat, key, fixed = TRUE)
    expect_no_match(flat, sub("=+$", "", b64(key)), fixed = TRUE)
    expect_no_match(
      tolower(flat),
      tolower(utils::URLencode(key, reserved = TRUE)),
      fixed = TRUE
    )
  }
  for (part in c(substr(key, 1, 15), substring(key, 12), substr(key, 5, 16))) {
    expect_identical(
      errtext(paste("bad key", part), key),
      "the error text is withheld: it repeated your key"
    )
  }
  expect_identical(errtext("bad key abc", "abc"),
                   "the error text is withheld: it repeated your key")
  expect_identical(
    errtext("quota exceeded for this account", key),
    "quota exceeded for this account"
  )
  expect_identical(errtext("plain", NULL), "plain")
})

# Findings of the pre-CRAN audit of 1.1.1 (BL-M2, BL-L1 to BL-L9).

test_that("the key is withheld at every base64 alignment (BL-M2)", {
  key <- "FAKEKEY_aud1t0nly_NOTREAL_zz9876543210ab"
  b64 <- function(s) jsb64enc(charToRaw(s))
  held <- "the error text is withheld: it repeated your key"
  pre <- paste0(
    "GET /v1/captures?limit=100 HTTP/1.1\r\n",
    "Host: x\r\nAuthorization: Bearer "
  )
  # the key starts at each of the three byte offsets of the encoded dump
  for (lead in c("", "a", "ab", "abc")) {
    dump <- b64(paste0(lead, pre, key, "\r\n"))
    expect_identical(
      errtext(paste("request dump:", dump), key),
      held,
      info = lead
    )
    url <- chartr("+/", "-_", dump)
    expect_identical(errtext(url, key), held, info = lead)
  }
  hex <- paste(as.character(charToRaw(key)), collapse = "")
  pct <- paste0("%", toupper(as.character(charToRaw(key))), collapse = "")
  sep8 <- paste(substring(key, seq(1, 40, 8), seq(8, 40, 8)), collapse = "-")
  for (echo in c(hex, toupper(hex), pct, sep8)) {
    expect_identical(errtext(paste("dump", echo), key), held)
  }
  # text that does not hold the key is shown
  expect_identical(
    errtext(paste("dump", b64("GET / HTTP/1.1\r\n")), key),
    paste("dump", b64("GET / HTTP/1.1\r\n"))
  )
  expect_false(.bl_key_echoed("anything", c(NA, "", NULL)))
  expect_false(.bl_key_echoed(NA_character_, key))
})

test_that("a provider or Wayback echo of the key is withheld (BL-M2)", {
  key <- "sk-FAKE0nlyNOTREAL0123456789"
  dump <- jsb64enc(charToRaw(paste0("xAuthorization: Bearer ", key)))
  res <- list(status = 400L, json = list(error = paste("bad request", dump)))
  expect_error(
    .bl_reply_error(res, "the provider", secret = key),
    "the provider answered 400: the error text is withheld"
  )
  res$json$error <- "bad request: model not found"
  expect_error(
    .bl_reply_error(res, "the provider", secret = key),
    "answered 400: bad request: model not found",
    fixed = TRUE
  )
  ak <- "FAKEaccessKEY123"
  sk <- "FAKEsecretKEY4567"
  body <- charToRaw(sprintf(
    '{"message": "bad auth LOW %s:%s"}',
    ak,
    paste(substring(sk, 1:2 * 8 - 7, 1:2 * 8), collapse = " ")
  ))
  j <- .bl_wb_json(list(body = body), c(ak, sk))
  expect_identical(
    j$message,
    "the error text is withheld: it repeated your key"
  )
  slow <- charToRaw('{"message": "slow down"}')
  j <- .bl_wb_json(list(body = slow), c(ak, sk))
  expect_identical(j$message, "slow down")
})

test_that("cqnt() names its quantiles as stats::quantile() does (BL-L1)", {
  for (p in list(c(0.001, 0.5), c(0, 1 / 3, 0.25, 0.999, 1), 0.123456789)) {
    expect_named(
      cqnt(1:10, p),
      names(stats::quantile(1:10, p)),
      info = toString(p)
    )
  }
})

test_that("cgamcdf() at an infinite shape is the limit, as pgamma() (BL-L2)", {
  x <- c(-1, 0, 1, 1e308, Inf, NA)
  expect_identical(cgamcdf(Inf, x), stats::pgamma(x, Inf))
  expect_identical(cgamcdf(Inf, x), c(0, 0, 0, 0, 1, NA))
})

test_that("rptanl() keeps names on one line, labels as written (BL-L3)", {
  d <- data.frame(
    y = rep(2020:2022, 2),
    g = rep(c("x`y`**z**", "b"), each = 3),
    n = c(10, 12, 15, 20, 18, 25),
    stringsAsFactors = FALSE
  )
  names(d)[3] <- "count\nline2"
  a <- anytab(d, "count\nline2", "y", by = "g")
  md <- strsplit(rptanl(a), "\n", fixed = TRUE)[[1]]
  expect_identical(
    substr(md[3], 1L, 40L),
    "`count line2` by `y`, grouped by `g`; 6 "
  )
  # the label's backticks and asterisks are escaped once, as Markdown text
  expect_true(any(grepl("x\\`y\\`\\*\\*z\\*\\*", md, fixed = TRUE)))
  h <- rptanl(a, format = "html")
  expect_match(h, "<p><code>count line2</code> by <code>y</code>", fixed = TRUE)
  expect_match(h, "<td>x&#96;y&#96;&#42;&#42;z&#42;&#42;</td>", fixed = TRUE)
  expect_false(grepl("<code>y</code>&#42;", h, fixed = TRUE))
  # a name with a backtick is written as escaped text, not a broken span
  expect_identical(.md_code(c("a`b", "c")), c("a\\`b", "`c`"))
  expect_identical(.md_inline("a\\`b `c`"), "a&#96;b <code>c</code>")
})

test_that("a share of zero has a lower bound of exactly 0 (BL-L6)", {
  s <- unclass(shrs(c(a = 0, b = 10)))
  expect_identical(s$lower[1], 0)
  expect_identical(
    s$lower[1],
    100 * stats::prop.test(0, 10, correct = FALSE)$conf.int[1]
  )
  expect_identical(s$upper[2], 100)
  expect_equal(
    s$upper[1],
    100 * stats::prop.test(0, 10, correct = FALSE)$conf.int[2],
    tolerance = 1e-12
  )
})

test_that("densities of values near the largest double fail in words (BL-L7)", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  v <- c(1e308, 1.7e308, -1.7e308)
  expect_error(plotrdg(v), "no density can be drawn for values this large")
  expect_error(plotvln(v), "no density can be drawn for values this large")
  expect_no_warning(z <- hurwzeta(c(1e308, 1.7e308)))
  expect_identical(z, c(1, 1))
  # zeta(-2n) = 0: every double past 2^53 is even
  expect_no_warning(z <- hurwzeta(c(-1e308, -2^60)))
  expect_identical(z, c(0, 0))
  expect_no_warning(hurwzeta(c(1e308, -1e308), -0.5))
  expect_true(.rmbl_even(2^53))
  expect_false(.rmbl_even(3))
})
