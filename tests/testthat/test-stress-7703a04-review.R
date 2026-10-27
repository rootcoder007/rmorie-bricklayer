# battery: runs in CI and locally; CRAN runs the correctness core
testthat::skip_on_cran()
# SPDX-License-Identifier: AGPL-3.0-or-later The review of 7703a04 (report of
# 2026-10-12): every finding pinned, with the earlier round's weak tests
# sharpened.

cf_env3 <- function(env = parent.frame()) {
  withr::local_envvar(
    c(
      MORIE_LLM_BASE_URL = NA,
      MORIE_LLM_API_KEY = NA,
      MORIE_LLM_MODEL = NA,
      MORIE_LLM_ROUTE = NA,
      OLLAMA_HOST = NA,
      OLLAMA_BASE_URL = NA,
      OLLAMA_MODEL = NA,
      OLLAMA_API_KEY = NA,
      MORIE_DATA_URL = NA,
      MORIE_HOSTED_BASE_URL = NA,
      MORIE_HOSTED_KEY = NA,
      MORIE_HOSTED_MODEL = NA,
      XDG_CONFIG_HOME = withr::local_tempdir(.local_envir = env)
    ),
    .local_envir = env
  )
}

has_secret <- function(obj, key) {
  flat <- unlist(obj)
  any(grepl("skseed|skprf|sk_seed|sk_prf|key_state", names(flat))) ||
    any(grepl(key$skseed, flat, fixed = TRUE)) ||
    any(grepl(key[["skprf"]], flat, fixed = TRUE))
}

test_that(
  paste0(
    "Y1: no signature, attestation, bundle or serialisation of any scheme ",
    "carries private-key bytes"
  ),
  {
    k <- pqckg()
    s <- cpssign("hello", k, scheme = "xmss")
    expect_null(s$key_state)
    expect_false(has_secret(s, k))
    expect_false(has_secret(cpsatst(list(name = "m"), xmssadv(k, s)), k))
    renderings <- c(
      deparse(s),
      tojs(s),
      rawToChar(serialize(s, NULL, ascii = TRUE))
    )
    expect_false(any(grepl(k$skseed, renderings, fixed = TRUE)))
    expect_false(any(grepl(k[["skprf"]], tojs(unclass(s)), fixed = TRUE)))
    # the forgery of the report has nothing to work from
    expect_error(cpsatst(list(name = "forged"), s$key_state))
    f <- fipskg("ML-DSA-65")
    fs <- cpssign("hello", f)
    expect_false(any(grepl(
      f$secret %||% "no-secret-field",
      unlist(fs),
      fixed = TRUE
    )))
    expect_true(cpsvrf("hello", s, signpubkey(k)))
  }
)

test_that(
  paste0(
    "Y2: xmssadv() carries the key; one object twice is refused; the index ",
    "file survives sessions"
  ),
  {
    withr::local_options(
      rmoriebricklayer.xmssidxfile = withr::local_tempfile(fileext = ".json")
    )
    xmssfgt()
    k <- pqckg(height = 2)
    a1 <- cpsatst(list(n = 1), k)
    expect_null(a1$signature$key_state)
    expect_error(cpsatst(list(n = 2), k), "already used")
    k2 <- xmssadv(k, a1$signature)
    expect_identical(k2$next_index, 1L)
    a2 <- cpsatst(list(n = 2), k2)
    expect_identical(a2$signature$index, 1L)
    expect_error(
      xmssadv(pqckg(height = 2), a1$signature),
      "not made by this key"
    )
    # a "fresh session": the in-memory registry is cleared, the file is not, and
    # index 0 is refused
    rm(
      list = ls(.rmbl_xmss_used, all.names = TRUE),
      envir = .rmbl_xmss_used
    )
    expect_error(cpssign("again", k), "already used")
    xmssfgt()
    expect_false(file.exists(getOption("rmoriebricklayer.xmssidxfile")))
  }
)

test_that(
  paste0(
    "Y3: a mean without a prevalence (or the reverse) is an error report, ",
    "not zero cases"
  ),
  {
    r <- vrfpol("pm25", expomean = 25)
    expect_identical(r$status, "error")
    expect_identical(attr(r, "exitstat"), 2L)
    expect_match(r$error, "go together")
    expect_identical(vrfpol("no2", expoprev = 1)$status, "error")
    expect_identical(vrfpol("pm25")$status, "error")
    ok <- vrfpol("pm25", expomean = 25, expoprev = 1)
    expect_identical(ok$status, "ok")
    expect_gt(ok$pipeline$burden$attrcases, 0)
    expect_identical(vrfpol("pm25", expomean = 0, expoprev = 1)$status, "ok")
  }
)

test_that("Y4: a cue sentence ended by a newline keeps the line break", {
  H <- "UES\nAgents impliqu\u00e9s\n"
  fa <- paste0(
    H,
    "AI no 1 A particip\u00e9 à une entrevue. Le nom d'un agent ",
    "impliqu\u00e9 est ",
    "confidentiel\n",
    "AI no 2 N'a pas consenti à une entrevue\nAgents t\u00e9moins\n"
  )
  fb <- paste0(
    H,
    "AI no 1 A particip\u00e9 à une entrevue. Le nom d'un agent ",
    "impliqu\u00e9 est ",
    "confidentiel\n",
    "Agents t\u00e9moins\nAI no 7 (narrative)\n"
  )
  expect_identical(as.numeric(siuso(fa)$count), 2)
  expect_identical(as.numeric(siuso(fb)$count), 1)
  # the property, with the line-end position included
  bp <- "Le nom d'un agent impliqu\u00e9 est confidentiel"
  lines <- c(
    "AI no 1 A particip\u00e9 à une entrevue. AI no 3 \u00e9tait pr\u00e9sent",
    "AI no 2 N'a pas consenti à une entrevue.",
    paste0(
      "AI no 4 A particip\u00e9 à une entrevue; AI no 5 a refus\u00e9. AI ",
      "no 2 absent"
    )
  )
  for (ln in lines) {
    base <- as.numeric(
      siuso(paste0(H, ln, "\nAI no 1 absent\nAgents t\u00e9moins\n"))$count
    )
    variants <- c(
      paste0(bp, ". ", ln),
      paste0(ln, " ", bp, "."),
      paste0(ln, "\n", bp),
      paste0(bp, "\n", ln),
      paste0(sub(". ", paste0(". ", bp, ". "), ln, fixed = TRUE))
    )
    for (v in variants) {
      got <- as.numeric(
        siuso(paste0(H, v, "\nAI no 1 absent\nAgents t\u00e9moins\n"))$count
      )
      expect_identical(got, base, info = v)
    }
  }
})

test_that(
  paste0(
    "Y5 and Z5: one work cap for every run, the same for both spellings of ",
    "the same physics"
  ),
  {
    c0 <- matrix(0, 301, 301)
    c0[151, 151] <- 1
    r <- advdif2d(c0, u = 0.5, v = 0, kx = 0, ky = 0, 1, 1, 1, 2)
    expect_s3_class(r, "rmbl_field")
    expect_equal(r$mass, 1, tolerance = 1e-12)
    err <- tryCatch(
      advdif2d(
        matrix(1, 201, 201),
        u = 9999,
        v = 0,
        kx = 0,
        ky = 0,
        1,
        1,
        1,
        100
      ),
      error = function(e) conditionMessage(e)
    )
    expect_match(err, "above maxwork")
    # the hourly run written two ways: sub-stepped by the scheme, or stepped by
    # the caller
    c1 <- matrix(0, 5, 5)
    c1[3, 3] <- 1
    expect_warning(
      {
        a <- advdif2d(c1, u = 0, v = 0, kx = 50, ky = 50, 10, 10, 3600, 1)
      },
      "outside its stability bound"
    )
    b <- advdif2d(c1, u = 0, v = 0, kx = 50, ky = 50, 10, 10, 0.5, 7200)
    expect_equal(a$field, b$field, tolerance = 1e-12)
    msg <- function(e) conditionMessage(e)
    ea <- tryCatch(
      advdif2d(c1, 0, 0, 50, 50, 10, 10, 3600, 1, maxwork = 1e5),
      error = msg
    )
    eb <- tryCatch(
      advdif2d(c1, 0, 0, 50, 50, 10, 10, 0.5, 7200, maxwork = 1e5),
      error = msg
    )
    expect_match(ea, "above maxwork")
    expect_match(eb, "above maxwork")
    expect_warning(
      {
        f <- advdif2d(c1, 0, 0, 50, 50, 10, 10, 3600, 1, maxwork = Inf)
      },
      "outside its stability bound"
    )
    expect_s3_class(f, "rmbl_field")
    # a stable run is capped too: no run is unbounded
    expect_error(
      advdif2d(matrix(1, 3, 3), 0, 0, 0, 0, 1, 1, 0.1, 1e9),
      "above maxwork"
    )
    expect_error(
      advdif2d(matrix(1, 3, 3), 0, 0, 0, 0, 1, 1, 0.1, 1e300),
      "maxwork|not finite"
    )
    expect_false(grepl(", 0", err, fixed = TRUE))
    expect_match(err, "Pass maxwork = Inf")
    expect_error(
      lagrprt(
        n = 1e300,
        x0 = 0,
        y0 = 0,
        u = 1,
        v = 0,
        kx = 1,
        ky = 1,
        dt = 1,
        nsteps = 1
      ),
      "at most 100 million"
    )
    expect_warning(
      gspuff(mass = 1, u = 2, h = 10, rcpt = cbind(100, 0, -1), t = 10),
      "below ground"
    )
  }
)

test_that("Y6: a frequency table with a missing level plots", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  ft <- freqtbl(data.frame(g = c("a", "b", NA), stringsAsFactors = FALSE), "g")
  expect_silent({
    d <- plot(ft)
  })
  expect_s3_class(d, "data.frame")
})

test_that(
  paste0(
    "H1 and the attestation edges: edited HMAC signatures are FALSE; a ",
    "missing digest and a key object work"
  ),
  {
    s <- cpssign("m", "secret", scheme = "hmac")
    expect_true(cpsvrf("m", s, "secret"))
    edits <- list(
      c(s$signature, s$signature),
      5,
      "zz",
      substr(s$signature, 1, 10),
      NA_character_,
      list(s$signature)
    )
    for (bad in edits) {
      t <- s
      t$signature <- bad
      expect_false(cpsvrf("m", t, "secret"))
    }
    k <- pqckg(height = 2)
    at <- cpsatst(list(name = "m"), k)
    chk <- cpschkatst(at, list(name = "m"), keyexp = signpubkey(k))
    expect_true(all(chk$checks$ok))
    at2 <- at
    at2$digest <- NULL
    chk2 <- cpschkatst(at2, list(name = "m"))
    expect_false(all(chk2$checks$ok))
  }
)

test_that(
  paste0(
    "L1, L2, L3, L5 residuals: Ollama by model is announced; wrong types ",
    "are errors; keys follow addresses"
  ),
  {
    cf_env3()
    withr::local_envvar(c(
      OLLAMA_MODEL = "qwen3:8b",
      MORIE_LLM_MODEL = "m",
      OLLAMA_HOST = "http://127.0.0.1:18099",
      MORIE_HOSTED_BASE_URL = "https://llm.example.org"
    ))
    testthat::local_mocked_bindings(
      .bl_ollama_tags = function(base, timeout = 2) character(0),
      .package = "rmoriebricklayer"
    )
    expect_message(
      {
        hit <- .bl_llm_route()
      },
      "no address .*; using the local Ollama"
    )
    expect_identical(hit$model, "qwen3:8b")
    withr::local_envvar(c(MORIE_LLM_MODEL = NA))
    withr::local_envvar(c(OLLAMA_MODEL = NA))
    cfg <- .bl_config_path()
    dir.create(dirname(cfg), recursive = TRUE, showWarnings = FALSE)
    for (bad in c(
      '{"route": 5}',
      '{"route": ["ollama", "hosted"]}',
      '{"route": true}',
      '{"route": ""}'
    )) {
      writeLines(bad, cfg)
      expect_error(
        .bl_read_config(),
        "must be a non-empty string"
      )
    }
    unlink(cfg)
    # a credentials file without hosted_base_url (morie writes one) sends the
    # key only to the document's address
    withr::local_envvar(c(MORIE_HOSTED_KEY = NA))
    cred <- .bl_credentials_path()
    writeLines(
      paste0(
        '{"hosted_key": "sk-saved", "other": ["x"], "n": null, "big": ',
        "9007199254740993}"
      ),
      cred
    )
    withr::local_envvar(c(MORIE_HOSTED_BASE_URL = "https://other.example.org"))
    expect_message(
      expect_null(.bl_hosted_key()),
      "not sent to"
    )
    withr::local_envvar(c(MORIE_HOSTED_BASE_URL = NA))
    # login and logout keep the other package's entries as they were
    withr::local_envvar(c(MORIE_HOSTED_BASE_URL = "https://llm.example.org"))
    .bl_store_key("sk-new")
    flat <- function() {
      gsub(
        "[[:space:]]",
        "",
        paste(readLines(cred, warn = FALSE), collapse = "")
      )
    }
    expect_match(flat(), '"other":\\["x"\\]')
    expect_match(flat(), '"n":null')
    expect_match(flat(), "9007199254740993")
    dlogout()
    txt <- flat()
    expect_match(txt, '"other":\\["x"\\]')
    expect_false(grepl("hosted_key", txt, fixed = TRUE))
    # MORIE_DATA_URL does not receive the hosted key unless it is the document's
    # address
    withr::local_envvar(c(
      MORIE_HOSTED_KEY = "sk-h",
      MORIE_DATA_URL = "https://elsewhere.example.org"
    ))
    expect_message(
      expect_null(.bl_data_key()),
      "not sent to it"
    )
    withr::local_envvar(c(MORIE_DATA_URL = NA))
    expect_identical(.bl_data_key(), "sk-h")
    # a saved address is one address
    for (bad in c(
      "http://local host:1234/v1",
      "http://host#@evil",
      "http://user@host:1234/v1"
    )) {
      expect_error(llmcfg(own.url = bad), "plain address")
    }
    expect_error(llmcfg(ollama.url = "http://h ost:11434"), "plain address")
  }
)

test_that(
  paste0(
    "L11 and L12: no `--token [KEY]` anywhere in the help; C1 and bidi ",
    "characters never print"
  ),
  {
    out <- character()
    blcli("help", out = function(s) {
      assign("out", c(out, s), envir = parent.env(environment()))
    })
    blcli(c("login", "--help"), out = function(s) {
      assign("out", c(out, s), envir = parent.env(environment()))
    })
    expect_false(any(grepl("--token KEY|--token \\[KEY\\]", out)))
    expect_false(grepl(
      "--token KEY|\\[KEY\\]",
      .bl_access_hint()
    ))
    for (lc in c("C", "en_US.UTF-8")) {
      r <- try(
        withr::with_locale(c(LC_CTYPE = lc), {
          nm <- paste0(
            "Donn\u00e9es",
            "\u009b",
            "[31m",
            "\u202e",
            "Montr\u00e9al"
          )
          tab <- .bl_data_tables_df("db/t", nm, 3L, "x")
          txt <- .bl_format_data_tables(tab, width = 100)
          expect_false(grepl("\u009b", txt, fixed = TRUE))
          expect_false(grepl("\u202e", txt, fixed = TRUE))
          expect_false(grepl("Donnes", txt, fixed = TRUE))
        }),
        silent = TRUE
      )
      if (inherits(r, "try-error")) skip(paste("locale", lc, "not available"))
    }
  }
)

test_that("D1 gaps and M2, M4, M6, M8 leftovers", {
  dir <- withr::local_tempdir()
  f <- file.path(dir, "t.csv.gz")
  con <- gzfile(f, "wb")
  writeLines("a,b\n1,2", con)
  close(con)
  good <- csha256(readBin(f, "raw", file.size(f)))
  man <- function(sha) {
    function(refresh = FALSE) {
      list(datasets = list(list(key = "db/t", sha256 = sha)))
    }
  }
  testthat::local_mocked_bindings(
    dmnf = man(paste0("sha256:", good)),
    .package = "rmoriebricklayer"
  )
  expect_true(.bl_data_check_sha("db/t", f))
  testthat::local_mocked_bindings(
    dmnf = man("not-a-digest"),
    .package = "rmoriebricklayer"
  )
  expect_error(
    .bl_data_check_sha("db/t", f),
    "not a SHA-256"
  )
  expect_false(file.exists(f)) # the unverified file does not stay in the cache
  con <- gzfile(f, "wb")
  writeLines("a,b\n1,2", con)
  close(con)
  # a rebuilt table: the first manifest is stale, the refreshed one matches
  calls <- 0L
  testthat::local_mocked_bindings(
    dmnf = function(refresh = FALSE) {
      assign("calls", calls + 1L, envir = parent.env(environment()))
      list(
        datasets = list(list(
          key = "db/t",
          sha256 = if (refresh) good else strrep("0", 64)
        ))
      )
    },
    .package = "rmoriebricklayer"
  )
  expect_true(.bl_data_check_sha("db/t", f))
  expect_gte(calls, 2L)
  # an error since the review of 02a38be (M2): a typo that validates nothing
  # must not pass
  expect_error(
    schval(data.frame(a = 1), list(scheme = list(expected_columns = "a"))),
    "no `schema`"
  )
  expect_error(schval(data.frame(a = 1), new.env()), "provenance list")
  r <- vrfpol("pm25", expomean = 25, expoprev = 1, brate = 0.008)
  expect_identical(r$status, "assumption_failure")
  expect_true(any(grepl(
    "per person-year",
    vapply(r$assumptions, function(a) a$note, ""),
    fixed = TRUE
  )))
  expect_error(crfpm25(TRUE), "not logical")
  expect_error(crfno2(TRUE), "not logical")
  vp <- function(...) vrfpol("pm25", expoprev = 1, ...)$status
  expect_identical(vp(expomean = 1e308), "assumption_failure")
  expect_identical(vp(expomean = 90000), "assumption_failure")
  expect_identical(vp(expomean = as.Date("2020-01-01")), "error")
  bom <- withr::local_tempfile(fileext = ".csv")
  writeBin(c(as.raw(c(0xef, 0xbb, 0xbf)), charToRaw("exposure\n20\n30\n")), bom)
  expect_identical(vrfpol("pm25", expcsv = bom)$status, "ok")
  neg <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("exposure", "20", "-5"), neg)
  r <- vrfpol("pm25", expcsv = neg)
  expect_identical(r$status, "error")
  expect_match(r$error, "negative")
  expect_error(
    expconcidx(data.frame(e = c(1, Inf), i = c(1, 2)), "e", "i"),
    "finite"
  )
  expect_equal(hurwzeta(2, q = -0.5), 8.934802200544679, tolerance = 1e-9)
  expect_true(is.na(hurwzeta(2, q = -1)))
  expect_error(topshr(c(1, 2, 3), fracs = 1.5), "shares in")
  expect_identical(topshr(c(1, 2, 3), fracs = 0)$units, 0L)
  # NULL validates nothing: an error since the review of 02a38be (M2), not TRUE
  expect_error(schval(data.frame(a = 1), NULL), "no schema to validate against")
  expect_error(
    hilltlidx(c(1, 5, 9, 20, 50), xmin = c(1, 2)),
    "single threshold"
  )
  expect_error(raplok(NA), "single directory")
})

test_that("the earlier round's weak tests, sharpened", {
  # D4: the notes went on a page of their own, so the table page keeps every row
  d <- data.frame(
    year = 2015:2024,
    n = c(402, 377, 190, 268, 331, 300, 310, 290, 305, 320)
  )
  y <- yoy(d, value = "n", prd = "year")
  f <- withr::local_tempfile(fileext = ".pdf")
  yoypdf(y, f, notes = sprintf("note %d", 1:30), height = 5)
  bytes <- readBin(f, "raw", file.size(f))
  bytes[bytes == as.raw(0L)] <- as.raw(32L)
  expect_length(
    gregexpr("/Type /Page[^s]", rawToChar(bytes), useBytes = TRUE)[[1L]],
    2L
  )
  # plots: the frequency path with an NA level (above) and the margin helper,
  # which measures text on the open device: a null one, or it opened Rplots.pdf
  # in the tests directory (CRAN stress test of b617a3f)
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_true(is.finite(.bl_left_margin(
    labels = c(NA, "a")
  )))
})

test_that(
  paste0(
    "stress battery on 4b4af29: scheme edits on an HMAC secret, recorded ",
    "FIPS fields, a missing reference"
  ),
  {
    s <- cpssign("m", "secret", scheme = "hmac")
    for (bad in list(NULL, "xmss-sha256", "ML-DSA-44", 5, NA)) {
      t <- s
      t$scheme <- bad
      expect_false(cpsvrf("m", t, "secret"), info = deparse(bad))
    }
    f <- fipskg("ML-DSA-44")
    fs <- cpssign("m", f)
    expect_true(cpsvrf("m", fs, f))
    for (bad in list(5, c("a", "b"), list(1), NA_character_)) {
      t <- fs
      t$context <- bad
      expect_false(cpsvrf("m", t, f), info = deparse(bad))
      t <- fs
      t$prehash <- bad
      expect_false(cpsvrf("m", t, f), info = deparse(bad))
    }
    for (r in list(NA, NaN)) {
      v <- vrfpol("no2", expomean = 25, expoprev = 1, ref = r)
      expect_identical(v$status, "assumption_failure")
    }
  }
)

test_that(
  paste0(
    "Y2b: the XMSS index record persists by default, in the package config ",
    "directory"
  ),
  {
    withr::local_options(rmoriebricklayer.xmssidxfile = NULL)
    withr::local_envvar(RMBL_XMSS_INDEX_FILE = NA)
    expect_identical(
      .rmbl_xmss_index_file(),
      path.expand(file.path(
        tools::R_user_dir("rmoriebricklayer", "config"),
        "xmss_used_indices.txt"
      ))
    )
    if (.Platform$OS.type != "windows") {
      # Windows unsets an environment variable set to ""
      withr::local_envvar(RMBL_XMSS_INDEX_FILE = "")
      expect_null(.rmbl_xmss_index_file())
    }
    withr::local_options(rmoriebricklayer.xmssidxfile = FALSE)
    expect_null(.rmbl_xmss_index_file())
    # the file written by one "session" is read by the next: a reloaded stale
    # key is refused
    f <- withr::local_tempfile(fileext = ".json")
    withr::local_options(rmoriebricklayer.xmssidxfile = f)
    k <- pqckg(height = 2)
    saved <- k
    a <- cpsatst(list(n = 1), k)
    expect_true(file.exists(f))
    # removes the file too; recreate the record as another session would
    xmssfgt()
    writeLines(
      paste(paste0(k$root, ":", k$pubseed), a$signature$index, sep = "\t"),
      f
    )
    expect_error(cpsatst(list(n = 2), saved), "already used")
    expect_s3_class(
      cpsatst(list(n = 2), xmssadv(saved, a$signature)),
      "bricklayer_attestation"
    )
    # a record the package cannot read stops signing, it is not read around
    xmssfgt()
    writeLines("[1, 2]", f)
    expect_error(cpssign("m", pqckg(height = 2)), "malformed line")
    xmssfgt()
  }
)

test_that(
  paste0(
    "a stack at ambient temperature has no buoyancy and no rise, a cooler ",
    "one is refused"
  ),
  {
    r <- briggs(c(0, 100, 1000), 3, 2, 10, 290, 290)
    expect_identical(r$flux, 0)
    expect_identical(r$rise, c(0, 0, 0))
    expect_error(briggs(100, 3, 2, 10, 280, 290), "hotter")
  }
)

test_that(
  paste0(
    "a line typed at a terminal in a non-interactive session is read by a ",
    "shell child, so Ctrl-C lands"
  ),
  {
    skip_on_os("windows")
    calls <- character()
    testthat::local_mocked_bindings(
      .bl_interactive = function() FALSE,
      .bl_stdin_tty = function() TRUE
    )
    testthat::local_mocked_bindings(
      system2 = function(command, args = character(), ...) {
        assign("calls", c(calls, command), envir = parent.env(environment()))
        assign(
          "seen",
          c(seen, Sys.getenv("RMBL_PROMPT")),
          envir = parent.env(environment())
        )
        # the sh found on PATH, by its full path (network stress test of
        # 5e1dce5)
        if (identical(basename(command), "sh")) {
          "\002RMBL-LINE\002 sk-typed "
        } else {
          invisible(0L)
        }
      },
      .package = "base"
    )
    seen <- character()
    withr::local_envvar(RMBL_PROMPT = "before")
    got <- .bl_readline("key> ")
    expect_identical(got, "sk-typed")
    expect_true("sh" %in% basename(calls))
    # the shell prints the prompt once it is ready to read (review of e57fed5):
    # it is handed over in the environment, and the variable is put back
    # afterwards
    expect_true("key> " %in% seen)
    expect_identical(Sys.getenv("RMBL_PROMPT"), "before")
  }
)

test_that(
  paste0(
    "an XMSS object that still carries key_state (0.5.9 to 7703a04) is ",
    "verified with a warning"
  ),
  {
    k <- pqckg(height = 2)
    s <- cpssign("m", k)
    s$key_state <- list(
      sk_seed = k$skseed,
      sk_prf = k[["skprf"]],
      next_index = 1L
    )
    expect_warning(
      {
        ok <- cpsvrf("m", s, signpubkey(k))
      },
      "carries the signer"
    )
    expect_true(ok)
    a <- cpsatst(list(n = 1), xmssadv(k, s))
    a$signature$key_state <- s$key_state
    expect_warning(cpschkatst(a, list(n = 1)), "carries the signer")
  }
)

test_that(
  paste0(
    "the refusals of the third pass are exercised: work, keys, credentials, ",
    "stages"
  ),
  {
    # a step count that overflows the work estimate is refused before any loop
    # runs
    expect_error(
      advdif2d(matrix(1, 4, 4), 0, 0, 1, 1, 1, 1, 0.1, 1e308),
      "below 1e300"
    )
    # xmssadv() refuses what is not a key, not an XMSS signature, or has no
    # index
    k <- pqckg(height = 2)
    s <- cpssign("m", k)
    expect_error(xmssadv(list(), s), "signing key")
    expect_error(xmssadv(k, "x"), "XMSS signature")
    bad <- s
    bad$index <- NA_integer_
    expect_error(xmssadv(k, bad), "no valid index")
    # with the index file off, signing still works and nothing is saved
    withr::local_options(rmoriebricklayer.xmssidxfile = FALSE)
    expect_warning(
      {
        s2 <- cpssign("m2", xmssadv(k, s))
      },
      "record is off"
    )
    expect_s3_class(s2, "bricklayer_signature")
    # a FIPS public-key object is compared by its `public` field
    expect_warning(
      {
        a <- cpsatst(list(n = 1), pqckg(height = 2))
      },
      "record is off"
    )
    fk <- structure(list(public = "abcd"), class = "bricklayer_oqs_public_key")
    chk <- cpschkatst(a, list(n = 1), keyexp = fk)
    expect_false(chk$checks$ok[chk$checks$check == "key_as_expected"])
  }
)

test_that(
  paste0(
    "the data key follows the services document address; a credentials file ",
    "that is not an object is reported"
  ),
  {
    testthat::local_mocked_bindings(
      .bl_hosted_key = function(...) "sk-data",
      .rmbl_services_data = function(...) {
        list(base_url = "https://data.example.org/")
      }
    )
    withr::local_envvar(MORIE_DATA_URL = "https://data.example.org")
    expect_identical(.bl_data_key(), "sk-data")
    withr::local_envvar(MORIE_DATA_URL = "https://other.example.org")
    expect_message(expect_null(.bl_data_key()), "not sent")
    withr::local_envvar(XDG_CONFIG_HOME = withr::local_tempdir())
    cred <- .bl_credentials_path()
    dir.create(dirname(cred), recursive = TRUE, showWarnings = FALSE)
    writeLines("[1, 2]", cred)
    expect_error(.bl_read_credentials(), "not a JSON object")
  }
)

test_that(
  paste0(
    "vrfpol() turns a failure in the attributable fraction or the burden ",
    "stage into an error report"
  ),
  {
    testthat::local_mocked_bindings(attrfrac = function(...) {
      stop("paf exploded")
    })
    v <- vrfpol("pm25", expomean = 25, expoprev = 1)
    expect_identical(v$status, "error")
    expect_match(v$error, "paf exploded")
  }
)

test_that("vrfpol() turns a failure in the burden stage into an error report", {
  testthat::local_mocked_bindings(mortdisp = function(...) {
    stop("stage exploded")
  })
  v <- vrfpol("pm25", expomean = 25, expoprev = 1)
  expect_identical(v$status, "error")
  expect_match(v$error, "stage exploded")
})
