# SPDX-License-Identifier: AGPL-3.0-or-later
# Print and format branches, report and capsule-check details no other test
# reached.

test_that("an analysis prints its missing columns and its suppression", {
  d <- data.frame(
    year = rep(2019:2022, 2),
    g = rep(c("a", "b"), each = 4),
    n = c(10, 12, 15, 9, 30, 28, 35, 40),
    note = c(NA, "x", "y", "z", "p", "q", "r", "s"),
    stringsAsFactors = FALSE
  )
  a <- anltab(d, "n", "year", by = "g", rnd = 5, suplim = 5)
  out <- capture.output(print(a))
  expect_true(any(grepl("Rows +8", out)))
  expect_true(any(grepl("Columns +4", out)))
  expect_true(any(grepl(
    "1 column(s) with missing values",
    out,
    fixed = TRUE
  )))
  expect_true(any(grepl(
    "rounding 5 (nearest), suppression below 5;",
    out,
    fixed = TRUE
  )))
})

test_that("a capture's manifest timestamp prints as verified or not", {
  x <- structure(
    data.frame(
      url = c("https://a.org/x", "https://a.org/y"),
      file = c("x", "y"),
      bytes = c(1, 2),
      status = c("captured", "failed: z"),
      archive = NA,
      stringsAsFactors = FALSE
    ),
    class = c("rmbl_archive_capture", "data.frame")
  )
  attr(x, "timestamp") <- list(
    time = as.POSIXct("2024-01-01", tz = "UTC"),
    ok = TRUE,
    checks = data.frame(
      check = c("message_imprint", "signature"),
      ok = TRUE,
      stringsAsFactors = FALSE
    )
  )
  expect_output(
    print(x),
    "(verified, with the authority's chain)",
    fixed = TRUE
  )
  attr(x, "timestamp")$ok <- FALSE
  attr(x, "timestamp")$checks$ok <- c(TRUE, FALSE)
  expect_output(
    print(x),
    "Manifest timestamp  2024-01-01 (NOT verified)",
    fixed = TRUE
  )
})

test_that("a captured URL with a query and no extension gets a hashed name", {
  u <- "https://a.org/path/page?q=1"
  expect_identical(
    .bl_capture_name(u),
    paste0("page_", substr(csha256(charToRaw(u)), 1L, 10L))
  )
})

test_that("a refused archive.org upload is marked failed with its answer", {
  out <- data.frame(
    file = "x",
    status = "captured",
    mirror = NA_character_,
    stringsAsFactors = FALSE
  )
  r <- .bl_cap_ia_mark(out, "x", list(status = 503L, error = "busy"), "item")
  expect_identical(r$status, "failed: upload answered 503 busy")
  expect_true(is.na(r$mirror))
})

test_that("a band sensitivity of a statistic at 0 has no relative span", {
  s <- bandsens(c("0-9", "10-19", "20+"), c(5, 5, 5), stat = function(v) 0)
  expect_true(is.na(attr(s, "relspan")))
  out <- capture.output(print(s))
  expect_true(any(grepl("span over the caps tried: 0.", out, fixed = TRUE)))
})

test_that("a capsule size of a megabyte or more is written in MB", {
  expect_identical(.bl_capsule_size(5 * 1024^2), "5.0 MB")
  expect_identical(.bl_capsule_size(512), "0.5 KB")
})

test_that("classical Mahalanobis outliers say so in the heading", {
  set.seed(1)
  m <- mahaoutl(data.frame(a = rnorm(30), b = rnorm(30)), robust = FALSE)
  expect_false(isTRUE(attr(m, "robust")))
  expect_output(print(m), "Mahalanobis outliers (classical)", fixed = TRUE)
})

test_that("falsification: a failed control and no seed in the format", {
  set.seed(3)
  d <- data.frame(t = rep(0:1, 10), y = rnorm(20))
  f <- cpsfals(
    d,
    function(d) mean(d$y[d$t == 1]) - mean(d$y[d$t == 0]),
    trt = "t",
    n = 19
  )
  expect_true(is.na(f$seed))
  f$controls$passed[1] <- FALSE
  txt <- format(f)
  expect_true(any(grepl("^  Permutations +19$", txt)))
  expect_true(any(grepl("^  FAIL +permutation ", txt)))
})

test_that("a Benford screen with no p-value says ?", {
  bt <- benfordtst(1:200)
  bt$p_value <- NA
  txt <- format(bt)
  expect_identical(txt[2L], "  ?")
})

test_that("a recomputation lists the results it did not recompute", {
  m <- mkmnf(list(dataset = "demo"), env = FALSE)
  m <- suppressMessages(recrd(m, "mean_x", obs = 5.5, expd = 5.5))
  m <- suppressMessages(recrd(m, "n", obs = 10, expd = 10))
  invisible(capture.output({
    r <- mnfrcmp(m, data.frame(x = 1:10), list(n = function(z) nrow(z)))
  }))
  expect_false(r$ok)
  txt <- format(r)
  expect_match(txt[1L], "Recomputation: see below", fixed = TRUE)
  expect_true(any(txt == "  1 recorded result(s) NOT recomputed: mean_x"))
})

test_that("a Wayback run prints its submitted and not-sent URLs", {
  ws <- structure(
    data.frame(
      url = c("https://a.org/", "https://b.org/"),
      status = c("saved", "submitted"),
      timestamp = c("20240101000000", NA),
      stringsAsFactors = FALSE
    ),
    class = c("rmbl_wayback_save", "data.frame")
  )
  attr(ws, "not_sent") <- "https://c.org/"
  out <- capture.output(print(ws))
  expect_true(any(grepl(
    "2 URLs: 1 saved, 0 existing, 0 failed, 1 submitted",
    out,
    fixed = TRUE
  )))
  expect_true(any(grepl("1 not sent this run", out, fixed = TRUE)))
})

test_that("the Wayback summary names why a run stopped", {
  w <- new.env()
  w$counts <- list(saved = 1L, existing = 0L, failed = 0L, submitted = 0L)
  w$stopped <- "the daily cap"
  expect_identical(
    .bl_wb_summary(w, 2L, 0L, "https://c.org/"),
    paste0(
      "Wayback: 1 saved, 0 existing, 0 failed (of 2); 1 not sent: ",
      "the daily cap, run again to continue"
    )
  )
})

test_that("a throttle by HTTP 429 is named so", {
  expect_identical(.bl_wb_throttle_why(list(status = 429L), list()), "HTTP 429")
})

test_that("a submit answer with no message nor job id fails with its status", {
  w <- new.env()
  w$counts <- list(saved = 0L, existing = 0L, failed = 0L, submitted = 0L)
  w$results <- list()
  w$output <- NULL
  .bl_wb_submit_answer(w, "https://d.org/", list(status = 503L), list())
  expect_identical(w$results[["https://d.org/"]]$status, "failed")
  expect_identical(w$results[["https://d.org/"]]$message, "HTTP 503")
  expect_identical(w$counts$failed, 1L)
})

test_that("the report takes a provenance list holding its schema", {
  d <- data.frame(
    a = c(1, 2, 3, 4),
    b = c("x", "y", "x", "y"),
    stringsAsFactors = FALSE
  )
  sch <- infsch(d)
  d2 <- d
  d2$a <- c("p", "q", "r", "s")
  f1 <- .rpt_structure(.rpt_empty(), d2, list(schema = sch), NULL)
  f2 <- .rpt_structure(.rpt_empty(), d2, sch, NULL)
  expect_identical(f1, f2)
  expect_identical(f1$detail, "Column 'a' is character, expected numeric")
})

test_that("a drift with no shared columns adds only its added note", {
  f <- .rpt_drift(
    .rpt_empty(),
    list(
      removed = character(),
      added = "z",
      columns = data.frame(
        column = character(),
        drifted = logical(),
        stringsAsFactors = FALSE
      )
    )
  )
  expect_identical(nrow(f), 1L)
  expect_identical(f$detail, "column(s) not in the reference")
})

test_that("the report writes a signature's verdict both ways", {
  expect_match(
    .rpt_sig_text(FALSE, .rmbl_glyphs()),
    "NOT verified$"
  )
  rp <- cpsrpt(data.frame(
    a = c(1, 2, 3, 4),
    b = c("x", "y", "x", "y"),
    stringsAsFactors = FALSE
  ))
  rp$digest$signature_valid <- TRUE
  expect_true("| signature | verified |" %in% .rpt_md_head(rp, "T"))
})

test_that("a column with no values has no inferred range", {
  expect_null(.infsch_range(c(NA_real_, NA_real_), 0.1))
  s <- infsch(data.frame(x = c(NA_real_, NA_real_)))
  expect_identical(s$numeric_ranges, list())
})

test_that("capsule checks: a stale verdict, a missing script, synthetic data", {
  dir <- tempfile()
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE))
  writeLines(
    tojs(
      list(
        results = list(
          a = list(observed = 1, expected = 2, tol = 0.1, status = "PASS")
        )
      ),
      auto_unbox = TRUE
    ),
    file.path(dir, "m.json")
  )
  acc <- new.env()
  acc$checks <- list()
  acc$required <- character()
  .vc_manifest(acc, "m.json", dir)
  .vc_script(acc, "nope.R", list(), NULL, dir)
  .vc_synthetic(
    acc,
    file.path(dir, "d.csv"),
    FALSE,
    list(meta = list()),
    list(synthetic = TRUE)
  )
  ck <- do.call(rbind, acc$checks)
  expect_identical(
    ck$check,
    c("manifest_consistent", "script_sha256", "data_not_synthetic")
  )
  expect_false(any(ck$ok))
  expect_identical(
    ck$detail,
    c(
      "a",
      "script 'nope.R' is missing or outside the capsule",
      "the provenance records synthetic = true"
    )
  )
})

test_that("a BibTeX note with a retrieval date and no licence", {
  b <- citecps(list(
    captured_at_utc = "2026-06-23T04:41:40Z",
    dataset = list(publisher = "P", package_slug = "s")
  ))$bibtex
  expect_match(b, "  note = {Retrieved 2026-06-23},", fixed = TRUE)
  expect_false(grepl("licence", b, fixed = TRUE))
})

test_that("models: no list, an Ollama route and an own endpoint", {
  got <- new.env()
  got$out <- character()
  o <- function(s) got$out <- c(got$out, s)
  prog <- .bl_prog()
  local_mocked_bindings(
    .bl_llm_route = function(route = NULL) list(name = "local Ollama"),
    .bl_llm_list_models = function(rt) character()
  )
  expect_identical(.bl_cli_models(o), 0L)
  expect_identical(
    got$out,
    paste0(
      "local Ollama: no model list to show (the provider does not publish ",
      "one, or did not answer)\n"
    )
  )
  local_mocked_bindings(
    .bl_llm_route = function(route = NULL) {
      list(name = "local Ollama", model = "a")
    },
    .bl_llm_list_models = function(rt) c("a", "b")
  )
  got$out <- character()
  .bl_cli_models(o)
  expect_identical(got$out[2:3], c("  * a\n", "    b\n"))
  expect_match(
    got$out[4],
    sprintf("`%s config set ollama.model NAME`", prog),
    fixed = TRUE
  )
  local_mocked_bindings(
    .bl_llm_route = function(route = NULL) {
      list(name = "own endpoint", model = "a")
    }
  )
  got$out <- character()
  .bl_cli_models(o)
  expect_match(
    got$out[4],
    sprintf("`%s config set own.model NAME`", prog),
    fixed = TRUE
  )
})

test_that("a missing model lists at most eight of the models offered", {
  local_mocked_bindings(.bl_llm_list_models = function(rt) paste0("m", 1:10))
  msg <- .bl_no_model_message(list(name = "own endpoint"))
  expect_match(
    msg,
    sprintf(
      "m1, m2, m3, m4, m5, m6, m7, m8, ... 10 in all: `%s models`",
      .bl_prog()
    ),
    fixed = TRUE
  )
})

test_that("wayback --retry needs one results file that exists", {
  got <- new.env()
  got$out <- character()
  o <- function(s) got$out <- c(got$out, s)
  expect_identical(.bl_cli_wayback_retry(c("a", "b"), FALSE, 1, NULL, o), 2L)
  expect_identical(
    .bl_cli_wayback_retry("/nonexistent-gp/zz.jsonl", FALSE, 1, NULL, o),
    1L
  )
  expect_identical(
    got$out,
    c(
      "--retry takes the results file of an earlier run: give one FILE.jsonl\n",
      paste0(
        "--retry takes the results file of an earlier run: no such ",
        "file /nonexistent-gp/zz.jsonl\n"
      )
    )
  )
})

test_that("a null setting in the config file is an error that says null", {
  cfg <- tempfile(fileext = ".json")
  on.exit(unlink(cfg))
  writeLines("{\"route\": null}", cfg)
  local_mocked_bindings(.bl_config_path = function() cfg)
  expect_error(
    .bl_read_config(),
    "`route` must be a non-empty string, not null; fix or remove it",
    fixed = TRUE
  )
})

test_that("doctor reports no data key when the key state cannot be read", {
  got <- new.env()
  got$out <- character()
  local_mocked_bindings(.bl_hosted_key_state = function() stop("broken"))
  .bl_doctor_key(function(s) got$out <- c(got$out, s), "rmbl")
  expect_identical(
    got$out,
    "\n  data key: none (`rmbl login` opens the curated tables)\n"
  )
})
