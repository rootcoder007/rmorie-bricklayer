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
