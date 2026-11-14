# Findings of the black-box audit of 716154bd (1.1.1 updates 62 to 68), N1 to
# N12, each with the input that showed it. No network: local files, and the
# stub transport of test-data_parts.R where a download is needed.

# a gzip-compressed CSV of these bytes
aud_gz <- function(bytes) {
  f <- tempfile(fileext = ".csv.gz")
  con <- gzfile(f, "wb")
  writeBin(bytes, con)
  close(con)
  f
}

# a cache folder holding one table, db/t, and a manifest with its digest
aud_cache <- function(bytes, env = parent.frame()) {
  d <- withr::local_tempdir(.local_envir = env)
  withr::local_options(
    list(rmoriebricklayer.dcache = d, morie.progress = FALSE),
    .local_envir = env
  )
  f <- file.path(d, "db__t.csv.gz")
  file.copy(aud_gz(bytes), f)
  m <- list(datasets = list(list(
    key = "db/t",
    rows = 1,
    sha256_gz = csha256(readBin(f, "raw", file.size(f)))
  )))
  writeLines(tojs(m, auto_unbox = TRUE), file.path(d, "manifest.json"))
  d
}

# a CSV of random shape: quoted commas and line breaks, doubled quotes, CRLF,
# a byte-order mark, empty fields, blank lines, short and long records, a
# quote inside an unquoted field, a last line with or without its line end
aud_csv <- function(seed) {
  set.seed(seed)
  nc <- sample(1:4, 1L)
  vals <- c(
    "1", "22", "-3", "007", "1.5", "2e3", "", "NA", "TRUE", "F", "true",
    "x", "a b", "\"q,1\"", "\"multi\nline\"", "\"he said \"\"hi\"\"\"",
    "\"\"", " 5", "\"cr\r\nlf\"", "1i", "0x1A"
  )
  head <- paste(
    sample(c("a", "b ", " c", "\"d e\"", "f", "a"), nc),
    collapse = ","
  )
  rec <- vapply(seq_len(sample(0:30, 1L)), function(i) {
    r <- stats::runif(1L)
    k <- if (r < 0.01) nc + sample(1:2, 1L) else if (r < 0.08) nc - 1L else nc
    f <- sample(vals, max(1L, k), replace = TRUE)
    if (stats::runif(1L) < 0.005) f[1L] <- "x\"y"
    paste(f, collapse = ",")
  }, "")
  lines <- c(head, rec)
  if (length(rec) && stats::runif(1L) < 0.2) {
    lines <- append(lines, "", after = sample(seq_along(lines), 1L))
  }
  eol <- if (stats::runif(1L) < 0.3) "\r\n" else "\n"
  txt <- paste(lines, collapse = eol)
  if (stats::runif(1L) < 0.6) txt <- paste0(txt, eol)
  b <- charToRaw(txt)
  if (stats::runif(1L) < 0.2) b <- c(as.raw(c(0xef, 0xbb, 0xbf)), b)
  b
}

test_that("N1: the part reader reads and refuses records as a whole read", {
  ns <- asNamespace("rmoriebricklayer")
  try_df <- function(expr) tryCatch(expr, error = conditionMessage)
  all_rows <- function(d) rep(TRUE, nrow(d))
  for (seed in 1:400) {
    f <- aud_gz(aud_csv(seed))
    whole <- try_df(ns$.bl_read_csv_gz(f))
    # piece sizes down to one byte put the cuts inside quoted fields
    for (piece in c(sample(c(1, 2, 3, 5, 8, 13, 31), 2L), 4096)) {
      expect_identical(
        try_df(ns$.bl_csv_part(f, NULL, Inf, NULL, piece = piece)),
        whole,
        info = paste(seed, piece)
      )
      expect_identical(
        try_df(ns$.bl_csv_part(f, NULL, Inf, all_rows, piece = piece)),
        whole,
        info = paste(seed, piece, "keep")
      )
    }
    if (is.data.frame(whole)) {
      top <- whole[seq_len(min(3L, nrow(whole))), , drop = FALSE]
      rownames(top) <- NULL
      expect_identical(ns$.bl_csv_part(f, NULL, 3, NULL, piece = 7), top)
    }
    unlink(f)
  }
})

test_that("N1: a long record or a stray quote far down is refused by name", {
  ns <- asNamespace("rmoriebricklayer")
  body <- paste(1:3000, 1L, 2L, sep = ",")
  long <- body
  long[2600] <- "2600,1,2,7"
  txt <- paste0(paste(c("a,b,c", long), collapse = "\n"), "\n")
  f <- aud_gz(charToRaw(txt))
  expect_error(
    ns$.bl_csv_part(f, "a", Inf, NULL, piece = 1000),
    "^record 2601 has 4 fields where the header has 3"
  )
  expect_error(ns$.bl_read_csv_gz(f), "^record 2601 has 4 fields")
  stray <- body
  stray[1500] <- "1500,x\"y,2"
  f <- aud_gz(charToRaw(paste(c("a,b,c", stray), collapse = "\n")))
  msg <- "a quote inside an unquoted field \\(ab\"c\\) \\(record 1501\\)"
  expect_error(ns$.bl_csv_part(f, NULL, 10, NULL, piece = 500), msg)
  expect_error(ns$.bl_read_csv_gz(f), msg)
})

# columns whose look changes from piece to piece
aud_mixed <- function(n = 3000L) {
  v <- rep(c("50", "500"), length.out = n)
  v[n - 3L] <- "2.5"
  w <- as.character(seq_len(n))
  w[n - 1L] <- "n/a"
  d <- data.frame(
    id = seq_len(n),
    code = c(rep("007", n - 1L), "00A"),
    v = v,
    w = w,
    e = c(rep("", n / 2), rep("3", n / 2)),
    l = c(rep(c("TRUE", "F"), length.out = n - 1L), "1"),
    t = c(rep("T", n - 1L), "true"),
    z = c(rep("1", n - 1L), "1i"),
    stringsAsFactors = FALSE
  )
  lines <- c(
    paste(names(d), collapse = ","),
    do.call(paste, c(unname(as.list(d)), sep = ","))
  )
  charToRaw(paste0(paste(lines, collapse = "\n"), "\n"))
}

test_that("N2: keep sees the whole table's types, whatever the piece", {
  ns <- asNamespace("rmoriebricklayer")
  f <- aud_gz(aud_mixed())
  whole <- ns$.bl_read_csv_gz(f)
  expect_identical(
    vapply(whole, typeof, ""),
    c(
      id = "integer", code = "character", v = "double", w = "character",
      e = "integer", l = "character", t = "character", z = "complex"
    )
  )
  preds <- list(
    function(d) d$code == "007",
    function(d) !is.na(d$v) & d$v > 100,
    function(d) d$w == "5",
    function(d) is.na(d$e),
    function(d) d$l == "TRUE",
    function(d) d$t == "T",
    function(d) Re(d$z) == 1
  )
  for (i in seq_along(preds)) {
    ref <- whole[which(preds[[i]](whole)), , drop = FALSE]
    rownames(ref) <- NULL
    for (piece in c(512, 5000, 2^23)) {
      expect_identical(
        ns$.bl_csv_part(f, NULL, Inf, preds[[i]], piece = piece),
        ref,
        info = paste(i, piece)
      )
    }
  }
  # n and cols take the whole table's types too
  one <- ns$.bl_csv_part(f, NULL, 1, NULL, piece = 512)
  expect_identical(vapply(one, typeof, ""), vapply(whole, typeof, ""))
  expect_identical(one$code, "007")
  expect_identical(ns$.bl_csv_part(f, "v", 2, NULL, piece = 512)$v, c(50, 500))
})

test_that("N2: dload() with keep gives the rows of dload() it keeps", {
  aud_cache(aud_mixed())
  withr::local_options(rmoriebricklayer.dpiece = 700)
  whole <- dload("db/t")
  ref <- subset(whole, code == "007" & !is.na(v) & v > 100)
  rownames(ref) <- NULL
  expect_identical(
    dload("db/t", keep = function(d) d$code == "007" & d$v > 100),
    ref
  )
  expect_identical(
    dload("db/t", cols = c("v", "id"), keep = function(d) d$w == "n/a"),
    data.frame(id = 2999L, v = 50)
  )
  withr::local_options(rmoriebricklayer.dpiece = 0)
  expect_error(dload("db/t", n = 1), "rmoriebricklayer.dpiece must be")
})

test_that("N3: a header with blanks around a name is named as a whole read", {
  ns <- asNamespace("rmoriebricklayer")
  for (h in c("a ,b", " a,\"b \",c", "\"x\" , y ")) {
    nf <- length(strsplit(h, ",", fixed = TRUE)[[1L]])
    row <- paste(seq_len(nf), collapse = ",")
    f <- aud_gz(charToRaw(paste0(h, "\n", row, "\n")))
    whole <- ns$.bl_read_csv_gz(f)
    part <- ns$.bl_csv_part(f, NULL, 10, NULL)
    expect_named(part, names(whole), info = h)
    expect_identical(ns$.bl_csv_part(f, names(whole), 10, NULL), part)
  }
  # the manifest's name, blanks and all, or without them
  f <- aud_gz(charToRaw("Type of assets ,n\nx,1\n"))
  for (k in c("Type of assets ", "Type of assets", "Type.of.assets")) {
    expect_named(ns$.bl_csv_part(f, k, Inf, NULL), "Type.of.assets", info = k)
  }
})

test_that("N4: parallel downloads of one table take turns and share it", {
  skip_on_os("windows")
  skip_on_cran()
  d <- withr::local_tempdir()
  set.seed(4)
  bytes <- as.raw(sample(0:255, 3 * 2^20 + 7, replace = TRUE))
  src <- file.path(d, "src")
  writeBin(bytes, src)
  log <- file.path(d, "log")
  dir.create(log)
  dir.create(file.path(d, "c"))
  dest <- file.path(d, "c", "db__t.csv.gz")
  withr::local_options(rmoriebricklayer.dpart = 2^20)
  local_mocked_bindings(
    .bl_data_url = function() "https://data.example.org",
    .bl_data_label = function(path) list(label = "db/t", size = length(bytes)),
    bldl = function(url, dest, headers = NULL, ...) {
      rng <- sub("^bytes=", "", headers[["Range"]])
      r <- as.numeric(strsplit(rng, "-", fixed = TRUE)[[1]])
      file.create(file.path(log, paste0(Sys.getpid(), "-", r[1L])))
      Sys.sleep(0.2)
      writeBin(bytes[(r[1L] + 1):(r[2L] + 1)], dest)
      invisible(dest)
    }
  )
  get <- function(i) {
    tryCatch(
      {
        suppressMessages(.bl_data_get("/db/t.csv.gz", dest))
        "ok"
      },
      error = conditionMessage
    )
  }
  skip_if_lowmem()
  res <- parallel::mclapply(1:2, get, mc.cores = 2L)
  expect_identical(unique(unlist(res)), "ok")
  expect_identical(readBin(dest, "raw", length(bytes) + 1), bytes)
  expect_setequal(
    list.files(dirname(dest), all.files = TRUE, no.. = TRUE),
    c("db__t.csv.gz", "db__t.csv.gz.lock")
  )
  # each part was fetched once: the process that waited kept the other's file
  expect_length(list.files(log), 4L)
})

test_that("N5: a download that cannot be written says so, with the option", {
  ns <- asNamespace("rmoriebricklayer")
  # the transport's own check of `dest` runs, and nothing is sent
  local_mocked_bindings(
    .bl_data_url = function() "https://data.example.org",
    .bl_data_label = function(path) list(label = "db/t", size = NULL),
    bldl = function(url, dest, ...) {
      .rmbl_out_file(dest, "dest", connection = FALSE)
      stop("bldl: no network in this test", call. = FALSE)
    }
  )
  reg <- withr::local_tempfile()
  writeLines("x", reg)
  for (dc in c(file.path(reg, "sub"), "/proc/rmbl-none/cache")) {
    withr::local_options(rmoriebricklayer.dcache = dc)
    for (expr in list(
      quote(dmnf(refresh = TRUE)),
      quote(ns$.bl_data_get("/db/t.csv.gz", file.path(dc, "db__t.csv.gz")))
    )) {
      e <- tryCatch(eval(expr), error = conditionMessage)
      expect_match(e, "cannot write .* on this computer", info = dc)
      expect_match(e, "options(rmoriebricklayer.dcache = )", fixed = TRUE)
      expect_false(grepl("^data.rmorie.com", e), info = dc)
    }
  }
  # a full disk, as the transport reports it
  d <- withr::local_tempdir()
  local_mocked_bindings(
    bldl = function(...) {
      stop(
        "bldl: https://data.example.org/db/t.csv.gz: Failure writing output ",
        "to destination, passed 8192 returned 320",
        call. = FALSE
      )
    }
  )
  expect_error(
    ns$.bl_data_get("/db/t.csv.gz", file.path(d, "t.csv.gz")),
    "on this computer \\(https://.*Failure writing output.*dcache = \\)"
  )
  # a failure of the service still says so
  local_mocked_bindings(
    bldl = function(...) stop("bldl: answered HTTP 503", call. = FALSE)
  )
  expect_error(
    ns$.bl_data_get("/db/t.csv.gz", file.path(d, "t.csv.gz")),
    "^data.rmorie.com: bldl: answered HTTP 503$"
  )
  expect_length(list.files(d, pattern = "[.]dl$"), 0L)
})

test_that("N6: a key that is not valid text, or too long, is refused once", {
  ns <- asNamespace("rmoriebricklayer")
  said <- character()
  out <- function(x) said <<- c(said, x)
  flag <- function(x) NULL
  keys <- list(strrep("a", 5000), file.path(strrep("a", 300), "t"))
  if (isTRUE(l10n_info()[["UTF-8"]])) {
    keys <- c(keys, rawToChar(as.raw(c(0x61, 0xff, 0x2f, 0x62))))
  }
  for (k in c(keys, "a/b/c")) {
    if (!identical(k, "a/b/c")) {
      expect_no_warning(expect_error(dload(k), "^key must be db/table"))
    }
    said <- character()
    expect_no_warning(st <- ns$.bl_cli_data_pull(c("pull", k), flag, out))
    expect_identical(st, 2L)
    expect_length(said, 1L)
    expect_match(said, "is not a table key")
    expect_lt(nchar(said, type = "bytes"), 200)
    flag2 <- function(x) if (identical(x, "--out")) "x.csv" else NULL
    said <- character()
    expect_no_warning(st <- ns$.bl_cli_data_pull(c("pull", k), flag2, out))
    expect_identical(st, 2L)
  }
})

test_that("N7: jsunser() refuses a value that is not of its declared type", {
  bad <- c(
    '{"type":"logical","value":["x"]}',
    '{"type":"logical","value":[1]}',
    '{"type":"integer","value":[3.7]}',
    '{"type":"integer","value":["7"]}',
    '{"type":"integer","value":[true]}',
    '{"type":"integer","value":[3000000000]}',
    '{"type":"double","value":["7"]}',
    '{"type":"double","value":[true]}',
    '{"type":"double","value":[[1,2]]}',
    '{"type":"character","value":[1,true]}',
    '{"type":"complex","value":["zz"]}',
    '{"type":"complex","value":[1]}'
  )
  for (s in bad) {
    expect_no_warning(
      expect_error(jsunser(s), "not JSON written by jsser\\(\\)", info = s)
    )
  }
  ok <- list(
    '{"type":"logical","value":[true,null,"NA",false]}' =
      c(TRUE, NA, NA, FALSE),
    '{"type":"integer","value":[1,"NA",null,-2]}' = c(1L, NA, NA, -2L),
    '{"type":"double","value":[1.5,"NaN","Inf","-Inf","NA",2]}' =
      c(1.5, NaN, Inf, -Inf, NA, 2),
    '{"type":"character","value":["a",null,"NA"]}' = c("a", NA, "NA"),
    '{"type":"complex","value":["1+2i"]}' = 1 + 2i
  )
  for (s in names(ok)) {
    expect_identical(jsunser(s), ok[[s]], info = s)
  }
  for (x in list(
    data.frame(a = 1:2, b = c("x", "y")),
    factor(c("a", NA, "b")),
    structure(1:4, dim = c(2L, 2L)),
    Sys.Date()
  )) {
    expect_identical(jsunser(jsser(x)), x)
  }
})

test_that("N7: jsunser() refuses a class its data do not fit", {
  cls <- function(x) {
    sprintf('"class":{"type":"character","value":["%s"]}', x)
  }
  bad <- c(
    sprintf(
      '{"type":"integer","value":[1],"attributes":{%s}}',
      cls("data.frame")
    ),
    sprintf(
      paste0(
        '{"type":"list","value":[{"type":"integer","value":[1,2]}],',
        '"attributes":{"names":{"type":"character","value":["a"]},%s,',
        '"row.names":{"type":"integer","value":[1,2,3]}}}'
      ),
      cls("data.frame")
    ),
    sprintf(
      paste0(
        '{"type":"integer","value":[5],"attributes":{%s,',
        '"levels":{"type":"character","value":["a"]}}}'
      ),
      cls("factor")
    ),
    sprintf(
      paste0(
        '{"type":"double","value":[1],"attributes":{%s,',
        '"levels":{"type":"character","value":["a"]}}}'
      ),
      cls("factor")
    )
  )
  for (s in bad) {
    expect_error(jsunser(s), "whose data do not have its shape", info = s)
  }
})

test_that("N8: file = TRUE with cols, n or keep is refused, not ignored", {
  aud_cache(charToRaw("a,b\n1,2\n"))
  for (a in list(
    list(cols = "a"),
    list(n = 1),
    list(keep = function(d) stop("never called"))
  )) {
    expect_error(
      do.call(dload, c(list("db/t", file = TRUE), a)),
      "`file = TRUE` returns the file's path"
    )
  }
  expect_true(file.exists(dload("db/t", file = TRUE)))
  # columns come in the order of the file, a name asked twice once
  expect_named(dload("db/t", cols = c("b", "a", "b")), c("a", "b"))
})

test_that("N9: a join cut short keeps what it joined, and the rerun goes on", {
  st <- new.env()
  set.seed(9)
  bytes <- as.raw(sample(0:255, 5000, replace = TRUE))
  st$seen <- character()
  st$writes <- 0
  st$fail <- 2
  local_mocked_bindings(
    .bl_data_url = function() "https://data.example.org",
    bldl = function(url, dest, headers = NULL, ...) {
      rng <- sub("^bytes=", "", headers[["Range"]])
      r <- as.numeric(strsplit(rng, "-", fixed = TRUE)[[1]])
      st$seen <- c(st$seen, headers[["Range"]])
      writeBin(bytes[(r[1L] + 1):(r[2L] + 1)], dest)
      invisible(dest)
    },
    .bl_write_raw = function(buf, out) {
      st$writes <- st$writes + 1
      if (st$writes == st$fail) {
        warning("problem writing to connection")
      }
      writeBin(buf, out)
    }
  )
  dest <- file.path(withr::local_tempdir(), "t.csv.gz")
  ns <- asNamespace("rmoriebricklayer")
  get <- function() {
    ns$.bl_data_get_parts(
      "/db/t.csv.gz", dest, character(), "db/t", 5000, 1024, 60
    )
  }
  expect_error(get(), "is full or cannot be written")
  expect_false(file.exists(dest))
  pd <- paste0(dest, ".parts")
  expect_identical(file.size(file.path(pd, "joined")), 2048)
  expect_setequal(list.files(pd), c("joined", "00003", "00004", "00005"))
  # the rerun downloads nothing again
  st$seen <- character()
  st$fail <- 0
  get()
  expect_identical(st$seen, character())
  expect_identical(readBin(dest, "raw", 6000), bytes)
  expect_false(dir.exists(pd))
  # a joined file holding half a part is written over from that part
  unlink(dest)
  dir.create(pd)
  writeBin(c(bytes[1:1500], as.raw(rep(0, 100))), file.path(pd, "joined"))
  for (i in 2:5) {
    a <- (i - 1) * 1024
    writeBin(
      bytes[(a + 1):min(a + 1024, 5000)],
      file.path(pd, sprintf("%05d", i))
    )
  }
  get()
  expect_identical(st$seen, character())
  expect_identical(readBin(dest, "raw", 6000), bytes)
})

test_that("N10: no two roxygen blocks run together in the sources", {
  r <- testthat::test_path("..", "..", "R")
  skip_if_not(dir.exists(r), "the package sources are not here")
  for (f in list.files(r, pattern = "[.]R$", full.names = TRUE)) {
    x <- readLines(f, warn = FALSE)
    rox <- startsWith(x, "#'")
    run <- cumsum(!rox)[rox]
    for (tag in c("@noRd", "@return", "@export")) {
      hit <- grepl(paste0("^#' ", tag, "\\b"), x[rox])
      expect_false(
        any(tabulate(run[hit] + 1L) > 1L),
        info = paste(basename(f), tag)
      )
    }
  }
})

test_that("N11: migrate reads assign(envir =) and with() scopes", {
  ns <- asNamespace("rmoriebricklayer")
  mig <- function(src) ns$.bl_migrate_text(src)$lines
  n4 <- c(
    "f <- function() {",
    "  assign(\"yoy\", function(d) d, envir = globalenv())",
    "}",
    "f()",
    "yoy(1)"
  )
  expect_identical(mig(n4), n4)
  n4b <- sub("envir = globalenv()", "pos = 1", n4, fixed = TRUE)
  expect_identical(mig(n4b), n4b)
  n4c <- sub(", envir = globalenv()", "", n4, fixed = TRUE)
  expect_identical(mig(n4c)[5L], "yoychg(1)")
  n4d <- sub("globalenv()", "environment()", n4, fixed = TRUE)
  expect_identical(mig(n4d)[5L], "yoychg(1)")
  n8 <- c("with(list(), { share <- sum; share(1) })", "share(2)")
  expect_identical(mig(n8), c(n8[1L], "shrs(2)"))
  n8b <- c("within(list(), share <- sum)", "share(2)")
  expect_identical(mig(n8b)[2L], "shrs(2)")
})

test_that("N12: a damaged cached manifest is fetched again, once", {
  good <- charToRaw("a,b\n1,2\n")
  d <- aud_cache(good)
  p <- file.path(d, "manifest.json")
  txt <- readLines(p)
  writeLines(substr(txt, 1L, nchar(txt) - 5L), p)
  st <- new.env()
  st$n <- 0
  local_mocked_bindings(.bl_data_get = function(path, dest, ...) {
    st$n <- st$n + 1
    writeLines(txt, dest)
    invisible(dest)
  })
  expect_identical(dmnf()$datasets[[1L]]$key, "db/t")
  expect_identical(st$n, 1)
  expect_identical(readLines(p), txt)
  # a fresh download is kept when the manifest has to be fetched again
  writeLines("{\"datasets\": [", p)
  tab <- file.path(d, "db__t.csv.gz")
  gz <- readBin(tab, "raw", file.size(tab))
  unlink(tab)
  local_mocked_bindings(.bl_data_get = function(path, dest, ...) {
    if (grepl("manifest", path, fixed = TRUE)) {
      writeLines(txt, dest)
    } else {
      writeBin(gz, dest)
    }
    invisible(dest)
  })
  expect_identical(dload("db/t"), data.frame(a = 1L, b = 2L))
  # offline, the damage is named
  writeLines("{\"datasets\": [", p)
  local_mocked_bindings(.bl_data_get = function(...) {
    stop("data.rmorie.com: offline", call. = FALSE)
  })
  expect_error(dmnf(), "the cached manifest .* is damaged, and a fresh one")
})
