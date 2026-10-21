# cpschk() and the GitHub pieces: the PSI bands, the column table with Benford, manifests against a
# base copy, the source cache, file:// sources, Wayback snapshots and captures, explerr() notes, the
# footprint, ghann(), ghcmt() and ghout(). No network: fdl(), wbsnpurl() and wbsave() are mocked
# where a test needs an http source. Nothing here reads standard input.

# a capsule whose source is a CSV under the test's control, pinned; `url` is how the provenance names it
pinned_capsule <- function(df = data.frame(id = 1:300, v = rep(c("a", "b", "c"), 100)), url = "path",
                           env = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = env)
  d <- file.path(root, "one")
  dir.create(d)
  src <- file.path(d, "source.csv")  # a local source is read only inside its capsule
  utils::write.csv(df, src, row.names = FALSE)
  file.copy(src, file.path(d, "data.csv"))
  name <- switch(url, path = src, file = paste0("file://", src), http = "https://example.org/data.csv")
  prov <- list(name = "t", resource = list(filename = "data.csv", direct_url = name, sha256 = sha256file(src),
                                           size_bytes = file.size(src), row_count_data_rows = nrow(df)),
               table = list(rounding = 5, suppression_limit = 10))
  writeLines(tojs(prov, auto_unbox = TRUE, pretty = TRUE), file.path(d, "data_provenance.json"))
  list(root = root, dir = d, src = src)
}

# the package reports paths with forward slashes; Windows temp paths come with backslashes
fwd <- function(p) gsub("\\\\", "/", p)

serve_from <- function(src, env = parent.frame()) {
  testthat::local_mocked_bindings(fdl = function(url, tpath, attwb = NULL, allowfile = FALSE) {
    file.copy(src, tpath, overwrite = TRUE)
  }, .package = "rmoriebricklayer", .env = env)
}

test_that("cpschk() verifies, renders the action's report and refuses bad arguments", {
  cp <- pinned_capsule()
  x <- cpschk(cp$root)
  expect_s3_class(x, "rmbl_cpschk")
  expect_identical(x$status, "ok")
  expect_identical(names(x$rows), c("capsule", "part", "file", "check", "ok", "detail", "severity", "line"))
  expect_identical(x$capsules[[1]]$checks_passed, x$capsules[[1]]$checks_total)
  md <- format(x, failon = "warn")
  expect_match(md, "**\u2714 ok**: 1 capsule under", fixed = TRUE)
  expect_match(md, "| \u2714 pass | schema: data_provenance.json | valid against capsule.schema.json |", fixed = TRUE)
  expect_match(md, "\nFootprint of these checks (co2fp(), ", fixed = TRUE)
  expect_match(md, "fail-on `warn` \u00b7 rmoriebricklayer", fixed = TRUE)
  expect_output(print(x), "## rmbl capsule verify with", fixed = TRUE)
  j <- fromjs(format(x, fmt = "json"))
  expect_identical(j$capsules$result, "ok")
  expect_identical(j$capsules$source, cp$src)
  # no footprint asked: no footer
  x <- cpschk(cp$root, "report", fp = FALSE)
  expect_null(x$footprint)
  expect_false(grepl("Footprint", format(x), fixed = TRUE))
  expect_false(grepl("fail-on", format(x), fixed = TRUE))
  expect_identical(x$mode, "report")
  expect_error(cpschk(tempfile()), "cpschk: `path` is not an existing directory")
  expect_error(cpschk(cp$root, psiwarn = 1), "cpschk: `psiwarn` (1) must not exceed `psifail` (0.25)", fixed = TRUE)
  expect_error(cpschk(cp$root, mode = "nope"), "cpschk: `mode` must be one of")
  expect_error(cpschk(cp$root, key = NA_character_), "cpschk: `key` must be a single string")
  expect_error(cpschk(cp$root, base = tempfile()), "cpschk: `base` is not an existing manifest file or folder")
  expect_error(cpschk(cp$root, allowfile = NA), "cpschk: `allowfile` must be TRUE or FALSE")
  expect_error(format(x, fmt = "xml"), "`fmt` must be one of")
})

test_that("no capsule, a glob, and the plural of the summary", {
  root <- withr::local_tempdir()
  x <- cpschk(root, fp = FALSE)
  expect_identical(x$status, "ok")
  expect_match(format(x), "No manifests found under `", fixed = TRUE)
  expect_match(format(cpschk(root, glob = "data/*", fp = FALSE)), "` matching `data/*`.", fixed = TRUE)
  cp <- pinned_capsule()
  dir.create(file.path(cp$root, "two"))
  file.copy(list.files(cp$dir, full.names = TRUE), file.path(cp$root, "two"))
  x <- cpschk(cp$root, fp = FALSE)
  expect_length(x$capsules, 2L)
  expect_match(format(x), "2 capsules under", fixed = TRUE)
  x <- cpschk(cp$root, glob = "*two/*", fp = FALSE)
  # capsule paths come back with forward slashes on every OS
  expect_identical(vapply(x$capsules, `[[`, "", "capsule"), fwd(file.path(cp$root, "two")))
})

test_that("drift: the PSI bands decide warn and drift, and the column table carries Benford", {
  set.seed(3)
  df <- data.frame(id = 1:300, value = round(stats::rnorm(300), 6), grade = sample(c("a", "b"), 300, TRUE),
                   zero = 0)
  cp <- pinned_capsule(df)
  x <- cpschk(cp$root, "drift", fp = FALSE)
  expect_identical(x$status, "ok")
  expect_true(x$rows$ok[x$rows$check == "source_digest"])
  expect_false(x$capsules[[1]]$changed)
  # new bytes, the same columns: a note, and the columns decide (all within the bands)
  df2 <- df[c(2:300, 1), ]
  utils::write.csv(df2, cp$src, row.names = FALSE)
  x <- cpschk(cp$root, "drift", fp = FALSE)
  expect_identical(x$status, "ok")
  expect_identical(x$rows$severity[x$rows$check == "source_digest"], "note")
  expect_true(x$capsules[[1]]$changed)
  dr <- x$capsules[[1]]$drift
  expect_identical(dr$verdict, "ok")
  expect_identical(dr$columns$column, c("id", "value", "grade", "zero"))
  expect_true(all(c("band", "verdict", "benford_ref", "benford_cur") %in% names(dr$columns)))
  expect_true(is.na(dr$columns$benford_ref[3L]))  # not numeric
  expect_true(is.na(dr$columns$benford_ref[4L]))  # no non-zero leading digit
  expect_equal(dr$columns$benford_ref[1L], benfordtst(df$id)$p_value)
  md <- format(x)
  expect_match(md, "**Drift: \u2714 no column crossed a band.** 0 of 4 columns flagged by the package (none)",
               fixed = TRUE)
  expect_match(md, "| \u2714 ok | grade | categorical | \u03c7\u00b2 ", fixed = TRUE)
  expect_match(md, "| - note | drift: source_digest | changed +data.csv")
  expect_match(x$capsules[[1]]$drift_summary, "^0 of 4 columns past a band; rows 300 -> 300$")
  # a rescaled column: drift past psi-fail, a warning when the fail band is wide
  df3 <- df
  df3$value <- df3$value * 3 + 2
  utils::write.csv(df3, cp$src, row.names = FALSE)
  x <- cpschk(cp$root, "drift", fp = FALSE)
  expect_identical(x$status, "drift")
  expect_match(format(x), "| \u26a0 drift | value | numeric | KS D", fixed = TRUE)
  expect_match(x$capsules[[1]]$drift_summary, "1 of 4 columns past a band: value (stat", fixed = TRUE)
  expect_identical(cpschk(cp$root, "drift", psifail = 5, fp = FALSE)$status, "warn")
  # flagged below the fail band: a warning, in the JSON too
  x <- cpschk(cp$root, "drift", psiwarn = 0, psifail = 5, fp = FALSE)
  expect_identical(x$capsules[[1]]$drift$columns$verdict[2L], "warn")
  expect_match(format(x, fmt = "json"), '"verdict": "warn"', fixed = TRUE)
  # columns added and removed are drift
  utils::write.csv(data.frame(id = 1:300, w = 1), cp$src, row.names = FALSE)
  x <- cpschk(cp$root, "drift", fp = FALSE)
  expect_identical(x$status, "drift")
  expect_match(x$capsules[[1]]$drift_summary, "; added w; removed value, grade, zero", fixed = TRUE)
  expect_match(format(x), "; added w; removed value, grade, zero; PSI bands", fixed = TRUE)
  # no column in common: no table
  utils::write.csv(data.frame(q = 1:3), cp$src, row.names = FALSE)
  x <- cpschk(cp$root, "drift", fp = FALSE)
  expect_identical(nrow(x$capsules[[1]]$drift$columns), 0L)
  expect_false(grepl("| Verdict | Column |", format(x), fixed = TRUE))
})

test_that("drift that cannot compare columns is a warning; a fetch that fails is an error", {
  cp <- pinned_capsule()
  p <- loadprov(file.path(cp$dir, "data_provenance.json"))
  p$resource$row_count_data_rows <- NULL
  writeLines(tojs(p, auto_unbox = TRUE), file.path(cp$dir, "data_provenance.json"))
  writeLines("", cp$src)  # not a CSV any more
  x <- cpschk(cp$root, "drift", fp = FALSE)
  expect_identical(x$status, "warn")
  expect_identical(x$rows$severity[x$rows$check == "source_digest"], "warn")
  expect_true(any(grepl("could not be compared (no CSV copy)", unlist(x$capsules[[1]]$notes), fixed = TRUE)))
  expect_match(ghann(x), "^::warning file=.*,title=rmbl drift source_digest::changed +data.csv")
  # a file:// source needs allowfile
  cp <- pinned_capsule(url = "file")
  x <- cpschk(cp$root, "drift", fp = FALSE)
  expect_identical(x$status, "error")
  nt <- unlist(x$capsules[[1]]$notes)
  expect_match(nt[1L], "source_fetched: cpschk: the source is a file:// URL and `allowfile` is FALSE", fixed = TRUE)
  expect_true(any(grepl("^explained: raised by \\.bl_local_source\\(\\) \\(reached from ", nt)))
  expect_identical(cpschk(cp$root, "drift", allowfile = TRUE, fp = FALSE)$status, "ok")
  expect_error(cpsrfrsh(cp$dir), "cpsrfrsh: the source is a file:// URL and `allowfile` is FALSE")
  expect_identical(cpsrfrsh(cp$dir, allowfile = TRUE)$change, "unchanged")
  expect_error(cpsrfrsh(cp$dir, allowfile = "yes"), "cpsrfrsh: `allowfile` must be TRUE or FALSE")
  # a refused URL is rethrown with its own message, explained
  cp <- pinned_capsule()
  p <- loadprov(file.path(cp$dir, "data_provenance.json"))
  p$resource$direct_url <- "https://127.0.0.1/data.csv"
  writeLines(tojs(p, auto_unbox = TRUE), file.path(cp$dir, "data_provenance.json"))
  x <- cpschk(cp$root, "drift", fp = FALSE)
  nt <- unlist(x$capsules[[1]]$notes)
  expect_true(any(grepl("explained: raised by .rmbl_check_public_url()", nt, fixed = TRUE)))
})

test_that("the cache keeps each fetched source and stands in when a fetch fails", {
  cp <- pinned_capsule(url = "http")
  cache <- withr::local_tempdir()
  serve_from(cp$src)
  x <- cpschk(cp$root, "drift", cache = cache, fp = FALSE)
  expect_identical(x$status, "ok")
  kept <- list.files(cache, full.names = TRUE)
  expect_identical(basename(kept), paste0("source-", substr(csha256(charToRaw("https://example.org/data.csv")), 1, 16)))
  expect_identical(sha256file(kept), sha256file(cp$src))
  testthat::local_mocked_bindings(fdl = function(...) FALSE)
  x <- cpschk(cp$root, "drift", cache = cache, fp = FALSE)
  expect_identical(x$status, "ok")
  expect_true("source unreachable: used the copy cached by an earlier run" %in% unlist(x$capsules[[1]]$notes))
  expect_identical(cpschk(cp$root, "drift", cache = FALSE, fp = FALSE)$status, "error")
  # the default outside an interactive session: none
  expect_null(.bl_cache_arg(NULL))
  testthat::local_mocked_bindings(.bl_default_cache = function() cache)
  expect_identical(.bl_cache_arg(NULL), cache)
})

test_that("snapshot rows: looked up for http(s) sources, a note either way", {
  cp <- pinned_capsule(url = "http")
  testthat::local_mocked_bindings(wbsnpurl = function(url, ts = NULL) {
    "https://web.archive.org/web/20240102030405/https://example.org/data.csv"
  })
  x <- cpschk(cp$root, snapshot = TRUE, fp = FALSE)
  r <- x$rows[x$rows$check == "snapshot", ]
  expect_true(r$ok)
  expect_identical(x$capsules[[1]]$snapshot_utc, "2024-01-02T03:04:05Z")
  expect_match(r$detail, "/web/20240102030405/https://example.org/data.csv (2024-01-02T03:04:05Z)", fixed = TRUE)
  testthat::local_mocked_bindings(wbsnpurl = function(url, ts = NULL) "https://web.archive.org/web/x")
  expect_identical(cpschk(cp$root, snapshot = TRUE, fp = FALSE)$capsules[[1]]$snapshot_utc, "")
  testthat::local_mocked_bindings(wbsnpurl = function(url, ts = NULL) stop("offline"))
  x <- cpschk(cp$root, snapshot = TRUE, fp = FALSE)
  expect_identical(x$status, "ok")
  expect_true("snapshot: none found (or the archive could not be reached)" %in% unlist(x$capsules[[1]]$notes))
  expect_match(format(x), "| - note | source: snapshot | none found", fixed = TRUE)
  expect_length(ghann(x), 0L)
  cp <- pinned_capsule()
  x <- cpschk(cp$root, snapshot = TRUE, fp = FALSE)
  expect_true("snapshot: not looked up (not an http(s) source)" %in% unlist(x$capsules[[1]]$notes))
  expect_identical(x$capsules[[1]]$checks_total, x$capsules[[1]]$checks_passed)
})

test_that("refresh pins new bytes, captures in the Wayback Machine, and refuses data that fail the schema", {
  df <- data.frame(id = 1:300, v = rep(c("a", "b", "c"), 100))
  cp <- pinned_capsule(df, url = "http")
  serve_from(cp$src)
  utils::write.csv(data.frame(id = 1:301, v = "a"), cp$src, row.names = FALSE)
  file.copy(test_path("fixtures", "morie-hmac", "capsule_bundle.json"), cp$dir)
  testthat::local_mocked_bindings(wbsave = function(urls, ...) {
    data.frame(url = urls, status = "saved", snapshot = "https://web.archive.org/web/1/x", message = "")
  })
  x <- cpschk(cp$root, "refresh", wayback = TRUE, fp = FALSE)
  nt <- unlist(x$capsules[[1]]$notes)
  expect_true("refreshed: new data and provenance written to the workspace" %in% nt)
  expect_true("capsule_bundle.json no longer matches the data: sign it again with cpsbndl()" %in% nt)
  p <- loadprov(file.path(cp$dir, "data_provenance.json"))
  expect_identical(p$resource$sha256, sha256file(cp$src))
  expect_identical(p$wayback$csv_snapshot, "https://web.archive.org/web/1/x")
  expect_identical(p$wayback$captured_at_utc, p$resource$retrieved_utc)
  expect_match(p$resource$retrieved_utc, "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$")
  expect_identical(ghout(x)$changed, fwd(cp$dir))
  unlink(file.path(cp$dir, "capsule_bundle.json"))
  expect_true(all(x$rows$ok[x$rows$part == "after refresh"]))
  # a capture that fails, or errors, is a note; the bytes are still pinned
  utils::write.csv(data.frame(id = 1:302, v = "a"), cp$src, row.names = FALSE)
  testthat::local_mocked_bindings(wbsave = function(urls, ...) {
    data.frame(url = urls, status = "failed", snapshot = NA, message = "429")
  })
  x <- cpschk(cp$root, "refresh", wayback = TRUE, fp = FALSE)
  expect_true("wayback: capture failed 429" %in% unlist(x$capsules[[1]]$notes))
  utils::write.csv(data.frame(id = 1:303, v = "a"), cp$src, row.names = FALSE)
  testthat::local_mocked_bindings(wbsave = function(urls, ...) stop("no keys"))
  x <- cpschk(cp$root, "refresh", wayback = TRUE, fp = FALSE)
  expect_true("wayback: no keys" %in% unlist(x$capsules[[1]]$notes))
  # the pinned schema refuses the new data: nothing written, an error row
  p <- loadprov(file.path(cp$dir, "data_provenance.json"))
  p$schema <- list(expected_columns = list("id", "v"))
  writeLines(tojs(p, auto_unbox = TRUE), file.path(cp$dir, "data_provenance.json"))
  utils::write.csv(data.frame(id = 1:5), cp$src, row.names = FALSE)
  before <- readLines(file.path(cp$dir, "data_provenance.json"))
  x <- cpschk(cp$root, "refresh", fp = FALSE)
  expect_identical(x$status, "error")
  expect_match(x$rows$detail[x$rows$check == "refreshed"], "cpschk: the new data fail the pinned schema: ",
               fixed = TRUE)
  expect_identical(readLines(file.path(cp$dir, "data_provenance.json")), before)
  expect_error(cpsrfrsh(cp$dir), "cpsrfrsh: the new data fail the pinned schema")
  # a source that no longer reads as a CSV is pinned without the schema check
  p$resource$row_count_data_rows <- NULL
  writeLines(tojs(p, auto_unbox = TRUE), file.path(cp$dir, "data_provenance.json"))
  writeLines("", cp$src)
  expect_identical(cpsrfrsh(cp$dir)$change, "changed")
})

test_that("manifests against a base: a folder, one file, or a function, and their resources", {
  cp <- pinned_capsule()
  man <- function(path, ...) {
    invisible(utils::capture.output({
      m <- mkmnf(list(dataset = "fixture"), env = FALSE)
      for (r in list(...)) m <- recrd(m, r[[1]], obs = r[[2]], expd = r[[2]], tol = r[[3]])
      dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
      wrmnfjs(m, path)
    }))
  }
  base <- withr::local_tempdir()
  man(file.path(base, "one", "manifest.json"), list("mean_x", 5.5, 0.01), list("n", 10, 0), list("gone", 1, 0))
  man(file.path(cp$dir, "manifest.json"), list("mean_x", 5.505, 0.01), list("n", 11, 0), list("sd_x", 1.2, 0.01))
  x <- cpschk(cp$root, base = base, fp = FALSE)
  m <- x$capsules[[1]]$manifests
  expect_length(m, 1L)
  expect_identical(m[[1]]$state, "compared")
  expect_true(m[[1]]$changed)
  md <- format(x)
  expect_match(md, sprintf("### Manifests against `%s`: changed", base), fixed = TRUE)
  expect_match(md, "| \u2714 match | mean_x | 5.5 | 5.505 | 0.005 (within tol) | 0.01 |", fixed = TRUE)
  expect_match(md, "| \u2716 mismatch | n | 10 | 11 | 1 (outside tol) | 0 |", fixed = TRUE)
  expect_match(md, "| new | sd_x |", fixed = TRUE)
  expect_match(md, "3 results compared, removed: gone", fixed = TRUE)
  expect_identical(ghout(x)[["manifest-changed"]], "true")
  expect_match(format(x, fmt = "json"), '"state": "compared"', fixed = TRUE)
  # the same file as the base: unchanged, one result
  man(file.path(base, "same.json"), list("n", 11, 0))
  man(file.path(cp$dir, "manifest.json"), list("n", 11, 0))
  x <- cpschk(cp$root, base = file.path(base, "same.json"), fp = FALSE)
  expect_identical(ghout(x)[["manifest-changed"]], "false")
  expect_match(format(x), "Manifests against `.*`: unchanged")
  expect_match(format(x), "1 result compared\n", fixed = TRUE)
  # a function (a git ref the caller resolves), named by its label; only the base has one: removed
  f <- function(p) if (endsWith(p, "results/manifest.json")) file.path(base, "same.json")
  attr(f, "label") <- "origin/main"
  x <- cpschk(cp$root, base = f, fp = FALSE)
  st <- vapply(x$capsules[[1]]$manifests, `[[`, "", "state")
  expect_identical(st, c("added", "removed"))
  expect_match(format(x), "### Manifests against `origin/main`: changed", fixed = TRUE)
  expect_match(format(cpschk(cp$root, base = function(p) NULL, fp = FALSE)), "against `the base`", fixed = TRUE)
  # from the capsule folder itself (path "."), no results, resources, and a base without results
  withr::local_dir(cp$dir)
  writeLines('{"resource": {"filename": "data.csv", "sha256": "01"}}', file.path(base, "res.json"))
  writeLines('{"resource": {"filename": "data.csv", "sha256": "02"}}', "manifest.json")
  x <- cpschk(".", base = file.path(base, "res.json"), fp = FALSE)
  m <- x$capsules[[1]]$manifests[[1]]
  expect_identical(m$state, "no results")
  expect_true(m$changed)
  expect_match(format(x), "Manifest diff: 1 changed", fixed = TRUE)
  expect_match(format(x, fmt = "json"), '"change": "changed"', fixed = TRUE)
  dir.create(file.path(base, "dot"))
  file.copy(file.path(base, "res.json"), file.path(base, "dot", "manifest.json"))
  man("manifest.json", list("n", 11, 0))
  x <- cpschk(".", base = file.path(base, "dot"), fp = FALSE)
  expect_match(x$capsules[[1]]$manifests[[1]]$state, "^not compared: ")
  expect_match(format(x), "`./manifest.json`: not compared", fixed = TRUE)
})

test_that("failed rows carry their notes; a bundle row is labelled; a row with a line annotates it", {
  root <- withr::local_tempdir()
  d <- file.path(root, "x")
  dir.create(d)
  writeLines(c("{", '  "resource": {', '    "filename": "d.csv",', '    "sha256": "abc"', "  }", "}"),
             file.path(d, "data_provenance.json"))
  file.copy(test_path("fixtures", "morie-hmac", "capsule_bundle.json"), d)
  x <- cpschk(root, fp = FALSE)
  expect_identical(x$status, "error")
  r <- x$rows[x$rows$check == "schema: data_provenance.json", ]
  expect_identical(r$line, 4L)
  a <- ghann(x)
  expect_true(any(grepl("::error file=.*data_provenance.json,line=4,title=rmbl spec schema%3A data_provenance.json::",
                        a)))
  nt <- unlist(x$capsules[[1]]$notes)
  expect_true(any(startsWith(nt, "bundle attestation:signature: ")))
  expect_true(any(nt == paste("explained: the file does not follow its JSON Schema (schemapath()): see the detail")))
  expect_match(format(x), "| \u2716 fail | bundle: attestation:signature |", fixed = TRUE)
  # an empty detail and a check with no meaning add no explanation; explerr() failing adds none either
  expect_length(.bl_explain_note("odd", ""), 0L)
  testthat::local_mocked_bindings(explerr = function(...) stop("no table"))
  expect_identical(.bl_explain_note("data_present", "x"),
                   "explained: the data file the provenance names (resource$filename) is not in the capsule")
  # where a problem names no key, or a key no line holds, the row has no line
  f <- withr::local_tempfile(fileext = ".json")
  writeLines("{}", f)
  expect_true(is.na(.bl_json_line(f, "$: missing required r")))
  expect_true(is.na(.bl_json_line(f, "$.a[2].b: expected string")))
  # a capsule whose provenance does not parse: one row from vrfcps(), no source
  writeLines("{", file.path(d, "data_provenance.json"))
  unlink(file.path(d, "capsule_bundle.json"))
  x <- cpschk(root, "drift", snapshot = TRUE, fp = FALSE)
  expect_identical(x$capsules[[1]]$source, "")
  expect_false(any(x$rows$part == "drift"))
})

test_that("ghann(), ghcmt() and ghout() give the action's annotation lines, comment body and outputs", {
  cp <- pinned_capsule()
  cat("1,a\n", file = file.path(cp$dir, "data.csv"), append = TRUE)
  x <- cpschk(cp$root, fp = FALSE)
  a <- ghann(x)
  # a property value escapes ":" and "," the way GitHub's workflow commands require (C: on Windows)
  prop <- gsub(":", "%3A", fwd(file.path(cp$dir, "data_provenance.json")), fixed = TRUE)
  expect_match(a[1L], sprintf("^::error file=%s,title=rmbl provenance data_sha256::expected ",
                              gsub(".", "\\.", prop, fixed = TRUE)))
  r <- x
  r$rows$detail[!r$rows$ok][1L] <- "50%\r\nof it, a: b"
  r$rows$file[!r$rows$ok][1L] <- "a,b:c"
  expect_identical(ghann(r)[1L], "::error file=a%2Cb%3Ac,title=rmbl provenance data_sha256::50%25%0D%0Aof it, a: b")
  b <- ghcmt(x, runurl = "https://github.com/o/r/actions/runs/1", failon = "error")
  expect_true(startsWith(b, "<!-- rmbl-action -->\n## rmbl capsule verify"))
  expect_true(endsWith(b, "[The run, with this report in its job summary](https://github.com/o/r/actions/runs/1)"))
  expect_match(b, "fail-on `error`", fixed = TRUE)
  expect_false(grepl("The run", ghcmt(x), fixed = TRUE))
  cut <- ghcmt(x, runurl = "https://u", limit = 200)
  expect_true(endsWith(cut, "(report cut to fit a comment; the full one is in the job summary: https://u)"))
  expect_true(endsWith(ghcmt(x, marker = "<!-- m -->", limit = 200), "job summary)"))
  expect_error(ghcmt(x, limit = 5), "ghcmt: `limit` must be")
  o <- ghout(x, report = "r.md", json = "r.json", comment = "dry-run")
  expect_identical(names(o), c("status", "report", "json", "changed", "verified", "failed", "manifest-changed",
                               "comment"))
  expect_identical(o[c("status", "changed", "verified", "failed", "manifest-changed", "comment")],
                   list(status = "error", changed = "", verified = 0L, failed = 1L, `manifest-changed` = "false",
                        comment = "dry-run"))
  expect_error(ghann(list()), "ghann: `x` must be a cpschk() result", fixed = TRUE)
  expect_error(ghout(x, report = 1), "ghout: `report` must be a single string")
})

test_that("the footprint footer names the method, the intensity and its year", {
  cp <- pinned_capsule()
  x <- cpschk(cp$root, fp = FALSE)
  x$footprint <- list(method = "rapl", durs = 1, cputms = 0.5, enekwh = list(total = 1e-6), co2eg = 1e-4,
                      co2int = list(g_per_kwh = 30, name = "Ontario", year = NA))
  expect_match(format(x), paste("(co2fp(), measured with RAPL): 1.0 s wall, 0.5 s CPU, 0.001 Wh, 0.0001 gCO2e",
                                "at 30 gCO2e/kWh (Ontario)."), fixed = TRUE)
})

plain_capsule <- function(env = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = env)
  d <- file.path(root, "one")
  dir.create(d)
  utils::write.csv(data.frame(x = 1:5), file.path(d, "data.csv"), row.names = FALSE)
  writeLines('{"resource": {"filename": "data.csv", "row_count_data_rows": 0}, "source": {"url": "x"}}',
             file.path(d, "data_provenance.json"))
  list(root = root, dir = d)
}

test_that("cpsseal() pins a plain provenance once and signs each capsule, hmac or post-quantum", {
  cp <- plain_capsule()
  s <- cpsseal(cp$root, "secret")
  expect_identical(names(s), c("capsule", "pinned", "files", "public"))
  expect_true(s$pinned)
  expect_identical(s$files, 2L)
  p <- loadprov(file.path(cp$dir, "data_provenance.json"))
  expect_identical(p$resource$sha256, sha256file(file.path(cp$dir, "data.csv")))
  expect_identical(p$source$sha256, p$resource$sha256)
  expect_equal(p$resource$row_count_data_rows, 5)
  x <- cpschk(cp$root, key = "secret", pubkey = s$public, fp = FALSE)
  expect_identical(x$status, "ok")
  expect_error(cpsseal(cp$root, "secret"), "cpsseal: capsule_bundle.json already exists in")
  invisible(utils::capture.output(wrmnfjs(mkmnf(list(dataset = "t"), env = FALSE), file.path(cp$dir, "manifest.json"))))
  key <- fipskg("ML-DSA-44")
  s <- cpsseal(cp$root, key, overwrite = TRUE)
  expect_false(s$pinned)
  expect_identical(s$public, key$public)
  expect_identical(cpschk(cp$root, pubkey = key$public, fp = FALSE)$status, "ok")
  expect_identical(nrow(cpsseal(cp$root, "secret", overwrite = TRUE, glob = "*one/*")), 1L)
  expect_error(cpsseal(cp$root, "secret", glob = "nothing/*"), "cpsseal: no data_provenance.json under")
  expect_error(cpsseal(tempfile(), "secret"), "cpsseal: `path` is not an existing directory")
  expect_error(cpsseal(cp$root, "secret", overwrite = NA), "cpsseal: `overwrite` must be TRUE or FALSE")
  writeLines('{"resource": {"filename": "../x.csv"}}', file.path(cp$dir, "data_provenance.json"))
  expect_error(cpsseal(cp$root, "secret", overwrite = TRUE), "resource\\$filename must name the data file")
})

test_that("capsule folders are relative to the folder searched however its path is written", {
  root <- withr::local_tempdir()
  d <- file.path(root, "a", "b")
  dir.create(d, recursive = TRUE)
  expect_identical(.bl_rel_dir(d, root), "a/b")
  expect_identical(.bl_rel_dir(root, paste0(root, "/")), ".")
  expect_identical(.bl_rel_dir(d, file.path(root, ".")), "a/b")
})

test_that("a local source written with backslashes is read as a local file (Windows)", {
  skip_on_os(c("mac", "linux", "solaris"))
  cp <- pinned_capsule()
  p <- loadprov(file.path(cp$dir, "data_provenance.json"))
  p$resource$direct_url <- gsub("/", "\\\\", normalizePath(cp$src))
  writeLines(tojs(p, auto_unbox = TRUE), file.path(cp$dir, "data_provenance.json"))
  expect_identical(cpschk(gsub("/", "\\\\", cp$root), "drift", fp = FALSE)$status, "ok")
  expect_identical(cpsrfrsh(cp$dir)$change, "unchanged")
})

test_that("an error inside the footprint wrapper is named after cpschk(), not co2fp()", {
  d <- withr::local_tempdir()
  utils::write.csv(data.frame(a = 1:3), file.path(d, "data.csv"), row.names = FALSE)
  writeLines('{"name":"x","resource":{"filename":"data.csv","direct_url":""}}', file.path(d, "data_provenance.json"))
  r <- cpschk(d, "drift", fp = TRUE)
  msg <- grep("names no source to fetch", unlist(r), value = TRUE)
  expect_true(length(msg) >= 1L)
  expect_true(any(startsWith(msg, "cpschk: ")))
  expect_false(any(grepl("co2fp", msg, fixed = TRUE)))
  # co2fp()'s own argument errors keep its name
  expect_error(co2fp(1, meth = "nope"), "^co2fp: `meth` must be one of")
  expect_error(compute_footprint(1, method = "nope"), "^co2fp: `meth` must be one of")
})
