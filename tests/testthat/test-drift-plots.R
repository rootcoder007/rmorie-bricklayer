# The drift plots, the HTML report, the Shiny app and the CLI's --html and --app: each draws or
# writes from the binned summaries cpsdrft() keeps, and the numbers on the page are the object's.

with_dev <- function(expr) {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  force(expr)
}

# the page a browser would get, without starting a server
app_html <- function(app) {
  app$httpHandler(list(PATH_INFO = "/", REQUEST_METHOD = "GET", QUERY_STRING = "", HTTP_HOST = "localhost",
                       SCRIPT_NAME = "", rook.input = NULL))$content
}

drift_fixture <- function() {
  set.seed(5)
  ref <- data.frame(value = stats::rnorm(400), size = stats::runif(400, 1, 10),
                    grade = sample(c("a", "b", "c"), 400, TRUE),
                    day = format(as.Date("2020-01-01") + sample(0:300, 400, TRUE)),
                    id = sprintf("k%04d", 1:400), stringsAsFactors = FALSE)
  cur <- ref
  cur$value <- stats::rnorm(400, 0.5)
  cur$size <- cur$size * 3
  cur$grade[1:80] <- "z"
  cur$id <- sprintf("q%04d", 1:400)
  list(ref = ref, cur = cur, d = cpsdrft(ref, cur))
}

page_json <- function(f) {
  txt <- paste(readLines(f, warn = FALSE), collapse = "\n")
  j <- regmatches(txt, regexpr("(?s)<script type=\"application/json\" id=\"drift-data\">.*?</script>", txt,
                               perl = TRUE))
  fromjs(sub("</script>$", "", sub("^<script[^>]*>", "", j)), simplifyVector = FALSE)
}

test_that("cpsdrft() keeps binned summaries whose PSI terms add up to the index", {
  fx <- drift_fixture()
  d <- fx$d
  expect_named(d$summ, d$columns$column)
  expect_equal(d$bands, c(warn = 0.1, fail = 0.25))
  for (cl in c("value", "size", "grade")) {
    s <- d$summ[[cl]]
    expect_equal(sum(s$bins$contrib), d$columns$psi[d$columns$column == cl], tolerance = 1e-9)
    expect_equal(sum(s$bins$ref), 1, tolerance = 1e-12)
    expect_equal(sum(s$bins$cur), 1, tolerance = 1e-12)
  }
  s <- d$summ$size
  expect_equal(sum(s$hist$ref), 1, tolerance = 1e-12)
  expect_equal(nrow(s$hist), 30L)
  expect_equal(s$stats$stat, c("mean", "sd", "min", "q1", "median", "q3", "max"))
  expect_equal(s$stats$ref[1], mean(fx$ref$size), tolerance = 1e-12)
  expect_equal(sum(s$benford$cur), s$benford$n)
  expect_match(s$bins$bin[1], "^<= ")
  expect_match(s$bins$bin[10], "^> ")
  # a category the reference never had is its own bin, and the ten largest categories are kept
  expect_true("(not in the reference)" %in% d$summ$grade$bins$bin)
  expect_equal(nrow(d$summ$grade$top), 4L)
  # dates: labels as dates, no Benford; identifiers: sizes only
  expect_match(d$summ$day$bins$bin[2], "^\\(2020-")
  ds <- rmoriebricklayer:::.bl_drift_show_stats(d$summ$day)
  expect_match(ds$ref[ds$stat == "median"], "^2020-[0-9]{2}-[0-9]{2}$")
  expect_match(ds$ref[ds$stat == "sd"], " days$")
  expect_equal(nrow(with_dev(plot(d, what = "columns", cols = "day"))), nrow(d$summ$day$bins))
  expect_equal(rmoriebricklayer:::.bl_drift_show_stats(d$summ$grade), d$summ$grade$top)
  expect_null(d$summ$day$benford)
  expect_null(d$summ$id$bins)
  expect_equal(d$summ$id$nref, 400L)
  # a category set that did not change has no unseen bin
  same <- cpsdrft(fx$ref["grade"], fx$ref["grade"])
  expect_false("(not in the reference)" %in% same$summ$grade$bins$bin)
})

test_that("the summaries cover the small and degenerate columns", {
  t1 <- as.POSIXct("2024-01-01 00:00:00", tz = "UTC")
  d <- cpsdrft(data.frame(k = c(5, 5, 5), t = format(t1 + c(0, 60, 120)), e = c(NA, NA, NA), z = c(0, 0, 0),
                          s = c(NA, "a", "b"), stringsAsFactors = FALSE),
               data.frame(k = 5, t = format(t1 + 30), e = 1, z = 0, s = NA_character_, stringsAsFactors = FALSE))
  expect_true(is.na(d$summ$k$stats$cur[2]))           # one value: no sd
  expect_equal(diff(range(c(d$summ$k$hist$lo, d$summ$k$hist$hi))), 1)  # a constant: a unit range
  expect_match(d$summ$t$bins$bin[1], "2024-01-01T")   # date-times label as date-times, ISO 8601
  expect_equal(d$summ$t$kind, "datetime")
  st <- rmoriebricklayer:::.bl_drift_show_stats(d$summ$t)
  expect_equal(st$ref[st$stat == "min"], "2024-01-01T00:00:00Z")
  expect_equal(st$ref[st$stat == "sd"], "60 s")
  expect_equal(st$cur[st$stat == "sd"], "")
  expect_equal(rmoriebricklayer:::.bl_drift_show_stats(d$summ$k)$ref[1], "5")
  expect_null(rmoriebricklayer:::.bl_drift_show_stats(d$summ$e))
  expect_equal(nrow(with_dev(plot(d, what = "columns", cols = "t"))), nrow(d$summ$t$bins))
  expect_null(d$summ$e$bins)                          # nothing on one side
  expect_equal(d$summ$e$missref, 1)
  expect_null(d$summ$z$benford)                       # zeros carry no first digit
  expect_null(d$summ$s$bins)
  expect_equal(d$summ$s$misscur, 1)
  expect_equal(rmoriebricklayer:::.rmbl_drift_summ(numeric(), numeric(), "numeric", 10L)$missref, 0)
})

test_that("verdicts follow the bands, and fail is cpsdrft()'s drifted at the object's bands", {
  d <- drift_fixture()$d
  v <- rmoriebricklayer:::.bl_drift_verdict(d, 0.1, 0.25)
  expect_equal(v == "fail", d$columns$drifted %in% TRUE)
  expect_equal(v[d$columns$column == "id"], "untested")
  # a wide fail band and a tiny alpha leave a PSI above the warn band as warn
  v2 <- rmoriebricklayer:::.bl_drift_verdict(d, 0.1, 100, alpha = 1e-300)
  expect_equal(v2[d$columns$column == "value"], "warn")
  expect_equal(v2[d$columns$column == "day"], "ok")
  # an object without summaries (an older one) treats every sample as large
  old <- d
  old$summ <- NULL
  expect_equal(rmoriebricklayer:::.bl_drift_verdict(old, 0.1, 0.25), v)
  expect_equal(rmoriebricklayer:::.bl_drift_bands(old), list(warn = 0.1, fail = 0.25))
  expect_error(rmoriebricklayer:::.bl_drift_bands(d, 0.5, 0.2), "`warn` must not be above `fail`")
  expect_error(plot(d, warn = -1), "plot: `warn` must be one number of at least 0")
  t <- rmoriebricklayer:::.bl_drift_table(d, 0.1, 0.25)
  expect_equal(t$verdict[1:3], c("fail", "fail", "fail"))
  expect_equal(t$test[t$column == "grade"], "chi-square homogeneity")
  expect_equal(t$missing_change, rep(0, 5))
})

test_that("each verdict has its sentence", {
  d <- drift_fixture()$d
  b <- list(warn = 0.1, fail = 0.25)
  t <- rmoriebricklayer:::.bl_drift_table(d, 0.1, 0.25)
  note <- function(r, ...) rmoriebricklayer:::.bl_drift_note(r, b, 0.01, ...)
  expect_match(note(t[t$column == "size", ]), "size moved: the KS test gives p = .*look before pinning it")
  r <- t[t$column == "size", ]
  r$p_value <- 0.5
  expect_match(note(r), "its PSI of 4.3 is above the fail band 0.25")
  r$verdict <- "warn"
  expect_match(note(r), "worth a look")
  r$verdict <- "ok"
  expect_match(note(r), "looks the same in both")
  r$verdict <- "untested"
  r$p_value <- NA
  expect_match(note(r), "p = none|not tested: no test applies")
  expect_match(note(r, note = "400 distinct values"), "not tested: 400 distinct values")
})

test_that("plot() draws the PSI, the columns and the first digits", {
  d <- drift_fixture()$d
  p <- with_dev(plot(d))
  expect_setequal(p$column, d$columns$column)
  expect_equal(p$column[1], "size")                   # worst first
  expect_equal(p$verdict[1], "fail")
  expect_equal(p$drifted, d$columns$drifted[match(p$column, d$columns$column)])
  cl <- with_dev(plot(d, what = "columns"))
  expect_setequal(unique(cl$column), c("size", "grade", "value", "day"))
  expect_equal(sum(cl$contrib[cl$column == "grade"]), d$columns$psi[d$columns$column == "grade"],
               tolerance = 1e-9)
  bf <- with_dev(plot(d, what = "benford", cols = "value", main = "digits"))
  # a title too long for any size falls back to the fitted one; whole numbers get one bin per value
  expect_equal(nrow(with_dev(plot(d, what = "benford", cols = "value", main = strrep("long title ", 30)))), 9L)
  set.seed(9)
  w <- cpsdrft(data.frame(wait = stats::rpois(500, 21)), data.frame(wait = stats::rpois(500, 26)))
  hw <- w$summ$wait$hist
  expect_true(all(hw$hi - hw$lo == 1))
  expect_equal(hw$lo[1], min(w$summ$wait$stats$ref[3], w$summ$wait$stats$cur[3]) - 0.5)
  expect_equal(sum(hw$cur), 1)
  expect_equal(bf$expected, log10(1 + 1 / (1:9)))
  expect_equal(sum(bf$cur), 1)
  # colours, a palette, the bands, the default title's counts
  expect_equal(nrow(with_dev(plot(d, col = "red", warn = 0.05, fail = 0.5))), 5L)
  expect_equal(nrow(with_dev(plot(d, what = "columns", cols = "grade", palette = "grey"))),
               nrow(d$summ$grade$bins))
  expect_error(plot(d, what = "columns", cols = "nope"), "plot: `cols` must name columns")
  expect_error(plot(d, what = "pie"), "must be one of")
  # nothing to draw: a categorical-only result has no first digits
  cat_only <- cpsdrft(data.frame(g = c("a", "b")), data.frame(g = c("a", "a")))
  expect_equal(nrow(with_dev(plot(cat_only, what = "benford"))), 0L)
  expect_equal(nrow(with_dev(plot(cpsdrft(data.frame(i = 1:2), data.frame(j = 1:2)), what = "columns"))), 0L)
  # the reference has no non-zero value: its points are missing, the current's bars drawn
  z <- cpsdrft(data.frame(v = c(0, 0, 0)), data.frame(v = c(1, 2, 3)))
  expect_true(all(is.na(with_dev(plot(z, what = "benford"))$ref)))
})

test_that("print() names the plot and the report", {
  expect_true(any(grepl("drfthtml(x, file)", format(drift_fixture()$d), fixed = TRUE)))
})

test_that("drfthtml() writes one self-contained page whose data round-trip", {
  fx <- drift_fixture()
  d <- fx$d
  d$provenance <- list(name = "cap", source = list(url = "https://example.org/a.csv",
                                                   sha256 = strrep("ab", 32), retrieved = "2026-10-01"))
  d$manifest <- mnfdiff(data.frame(path = "a.csv", sha256 = "aa"), data.frame(path = "a.csv", sha256 = "bb"))
  d$columns$column[1] <- "</script><b>x</b>"
  names(d$summ)[1] <- d$columns$column[1]
  f <- tempfile(fileext = ".html")
  on.exit(unlink(f), add = TRUE)
  expect_invisible(drfthtml(d, f, title = "A & B <report>"))
  txt <- paste(readLines(f, warn = FALSE), collapse = "\n")
  expect_true(grepl("<title>A &amp; B &lt;report&gt;</title>", txt, fixed = TRUE))
  expect_true(grepl("<h1>A &amp; B &lt;report&gt;</h1>", txt, fixed = TRUE))
  expect_false(grepl("<b>x</b>", txt, fixed = TRUE))
  expect_equal(lengths(regmatches(txt, gregexpr("</script>", txt, fixed = TRUE))), 2L)
  # nothing fetched: no stylesheet, script source or font from elsewhere
  expect_false(grepl("<link", txt, fixed = TRUE))
  expect_false(grepl("src=", txt, fixed = TRUE))
  expect_false(grepl("https://[a-z]", gsub("https://example.org", "", txt, fixed = TRUE)))
  expect_false(grepl("@import|url\\(", txt))
  for (id in c("verdict", "counts", "prov", "coltable", "search", "filters", "warn", "fail", "alpha", "reset",
               "detail", "sumtable", "chart-cmp", "chart-flow", "chart-ecdf", "chart-qq", "chart-psi", "chart-benford",
               "tab-manifest", "manifest", "manifest-tree", "tab-history", "hist-file", "history-plots", "heatmap",
               "tab-overview", "fingerprint", "multiples", "tab-chain", "chain", "hero", "hero-col",
               "dl-md", "dl-json", "copy-gh", "theme", "drift-data")) {
    expect_true(grepl(sprintf("id=\"%s\"", id), txt, fixed = TRUE) || grepl(sprintf("'%s'", id), txt, fixed = TRUE),
                label = id)
  }
  expect_true(grepl("prefers-color-scheme", txt, fixed = TRUE))
  expect_true(grepl("aria-label", txt, fixed = TRUE))
  expect_true(grepl("navigator.clipboard.writeText", txt, fixed = TRUE))
  expect_false(grepl("execCommand", txt, fixed = TRUE))
  p <- page_json(f)
  expect_equal(p$title, "A & B <report>")
  expect_equal(p$columns[[1]]$column, "</script><b>x</b>")
  expect_equal(vapply(p$columns, function(e) e$verdict, ""),
               rmoriebricklayer:::.bl_drift_verdict(d, 0.1, 0.25))
  sz <- p$columns[[which(d$columns$column == "size")]]
  expect_equal(unlist(sz$bins$contrib), d$summ$size$bins$contrib, tolerance = 1e-5)
  expect_equal(unlist(sz$stats$stat), d$summ$size$stats$stat)
  expect_equal(p$columns[[which(d$columns$column == "day")]]$kind, "date")
  expect_equal(p$provenance$date, "2026-10-01")
  expect_equal(unlist(p$manifest$change), "changed")
  expect_equal(p$bands, list(warn = 0.1, fail = 0.25))
  expect_length(unlist(sz$dens$ref), 64L)
  expect_length(unlist(sz$benford$band$upper), 9L)
  expect_equal(unlist(p$chain$status), c("ok", "warn", "ok", "none"))
  expect_true(grepl("prefers-reduced-motion", txt, fixed = TRUE))
  expect_lt(file.size(f), 150000)                     # summaries, not rows
  # the bands the page opens with, and open = TRUE
  opened <- NULL
  local_mocked_bindings(.bl_open_file = function(f) opened <<- f, .package = "rmoriebricklayer")
  drfthtml(fx$d, f, warn = 0.02, fail = 0.05, open = TRUE)
  expect_equal(opened, f)
  expect_equal(page_json(f)$bands, list(warn = 0.02, fail = 0.05))
  expect_null(page_json(f)$provenance)
  expect_error(drfthtml(list(), f), "drfthtml: `x` must be a bricklayer_drift object")
  expect_error(drfthtml(d, f, title = NA), "drfthtml: `title` must be a single string")
  expect_error(drfthtml(d, f, open = NA), "drfthtml: `open` must be TRUE or FALSE")
  expect_error(drfthtml(d, f, warn = 0.3), "drfthtml: `warn` must not be above `fail`")
})

test_that("the Markdown, the PSI without its largest bins and the provenance record", {
  d <- drift_fixture()$d
  md <- rmoriebricklayer:::.bl_drift_md(d, list(warn = 0.1, fail = 0.25))
  expect_match(md, "## Drift: 3 fail, 0 warn, 1 ok, 1 untested")
  expect_match(md, "| \u2716 fail | size | numeric | KS |", fixed = TRUE)
  b <- d$summ$size$bins
  w <- rmoriebricklayer:::.bl_psi_without(b, 2L)
  expect_length(w$dropped, 2L)
  expect_lt(w$psi, sum(b$contrib))
  expect_true(is.na(rmoriebricklayer:::.bl_psi_without(b, nrow(b))$psi))
  expect_null(rmoriebricklayer:::.bl_drift_prov(NULL))
  expect_equal(rmoriebricklayer:::.bl_drift_prov(list(name = "n", date = "d", resource = list(sha256 = NA))),
               list(name = "n", url = NULL, sha256 = NULL, date = "d"))
  expect_true(grepl("\\u003c", rmoriebricklayer:::.bl_drift_json(list(a = "<")), fixed = TRUE))
})

test_that("the history reads drift JSON and draws the PSI over runs", {
  d <- drift_fixture()$d
  dir <- tempfile("hist")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  expect_error(rmoriebricklayer:::.bl_drift_history(dir), "no drift JSON in")
  expect_error(rmoriebricklayer:::.bl_drift_history(file.path(dir, "nope")), "`hist` is not a directory")
  writeLines(rmoriebricklayer:::.bl_drift_json(rmoriebricklayer:::.bl_drift_payload(d)), file.path(dir, "1.json"))
  cols <- data.frame(column = c("size", "value"), psi = c(0.3, NA), p_value = 0.2)
  writeLines(tojs(list(capsules = list(list(capsule = "c", drift = list(columns = cols)), list(capsule = "d"))),
                  auto_unbox = TRUE), file.path(dir, "2.json"))
  writeLines("{not json", file.path(dir, "3.json"))
  h <- rmoriebricklayer:::.bl_drift_history(dir)
  expect_equal(unique(h$run), 1:2)
  expect_equal(h$psi[h$run == 2 & h$column == "size"], 0.3)
  expect_identical(with_dev(rmoriebricklayer:::.bl_drift_history_plot(h, list(warn = 0.1, fail = 0.25))), h)
})

test_that("drftapp() refuses without shiny, and builds its UI and server", {
  fx <- drift_fixture()
  d <- fx$d
  expect_error(drftapp(list()), "drftapp: `x` must be a bricklayer_drift object")
  local({
    local_mocked_bindings(requireNamespace = function(...) FALSE, .package = "base")
    expect_error(drftapp(d), "drftapp: the app needs the shiny package")
  })
  skip_if_not_installed("shiny")
  expect_error(drftapp(d, ref = fx$ref), "drftapp: `ref` and `cur` must both be data frames")
  expect_error(drftapp(d, ref = 1, cur = 2), "drftapp: `ref` and `cur` must both be data frames")
  dir <- tempfile("hist")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  writeLines(rmoriebricklayer:::.bl_drift_json(rmoriebricklayer:::.bl_drift_payload(d)), file.path(dir, "1.json"))
  d$manifest <- mnfdiff(data.frame(path = "a.csv", sha256 = "aa"), data.frame(path = "a.csv", sha256 = "bb"))
  app <- drftapp(d, ref = fx$ref, cur = fx$cur, hist = dir)
  expect_s3_class(app, "shiny.appobj")
  ui <- app_html(app)
  for (id in c("warn", "fail", "alpha", "reset", "col", "k", "sub", "bins", "rerun", "html", "md", "json"))
    expect_true(grepl(sprintf("id=\"%s\"", id), ui, fixed = TRUE), label = id)
  expect_true(grepl("Manifest", ui, fixed = TRUE) && grepl("History", ui, fixed = TRUE))
  shiny::testServer(app, {
    session$setInputs(warn = 0.1, fail = 0.25, alpha = 0.01, col = "size", k = 2, sub = character(), bins = 10)
    expect_match(output$note, "size moved")
    expect_match(output$clear, "Without .* the PSI would be")
    expect_match(output$tab, "chi-square homogeneity")
    expect_match(output$summ, "median")
    expect_type(output$psi, "list")
    expect_type(output$cmp, "list")
    expect_type(output$benford, "list")
    expect_type(output$history, "list")
    expect_type(output$heat, "list")
    expect_type(output$ecdf, "list")
    expect_type(output$qq, "list")
    expect_type(output$fingerprint, "list")
    expect_match(output$manifest, "changed")
    expect_true(file.exists(output$html))
    expect_match(paste(readLines(output$md), collapse = "\n"), "## Drift")
    expect_match(paste(readLines(output$json), collapse = "\n"), "\"columns\"")
    session$setInputs(reset = 1)
    session$setInputs(sub = c("size", "grade"), bins = 4, rerun = 1)
    expect_match(output$tab, "grade")
    session$setInputs(col = "grade")
    expect_type(output$benford, "list")
  })
})

test_that("drftapp() with no result compares two uploaded CSV files", {
  skip_if_not_installed("shiny")
  fx <- drift_fixture()
  app <- drftapp()
  expect_true(grepl("Reference CSV", app_html(app), fixed = TRUE))
  r <- tempfile(fileext = ".csv")
  k <- tempfile(fileext = ".csv")
  on.exit(unlink(c(r, k)), add = TRUE)
  utils::write.csv(fx$ref, r, row.names = FALSE)
  utils::write.csv(fx$cur, k, row.names = FALSE)
  shiny::testServer(app, {
    session$setInputs(warn = 0.1, fail = 0.25, alpha = 0.01, k = 1, bins = 10, sub = character())
    session$setInputs(refcsv = list(datapath = r), curcsv = list(datapath = k))
    session$setInputs(col = "id")
    expect_match(output$tab, "size")
    expect_equal(output$clear, "")
    session$setInputs(rerun = 1)
    expect_match(output$tab, "value")
  })
})

test_that("rmbl drift --html, --json and --app on a capsule whose source moved", {
  home <- withr::local_tempdir()
  withr::local_envvar(HOME = home, XDG_CONFIG_HOME = file.path(home, "cfg"))
  root <- file.path(home, "caps")
  run <- function(...) {
    buf <- character()
    st <- blcli(c(...), out = function(s) buf <<- c(buf, s))
    list(status = st, text = paste(buf, collapse = ""))
  }
  mk <- function(name) {
    d <- file.path(root, name)
    dir.create(d, recursive = TRUE)
    src <- file.path(d, "source.csv")
    utils::write.csv(data.frame(id = 1:40, v = rep(c("a", "b"), 20)), src, row.names = FALSE)
    prov <- list(name = name, source = list(url = src, sha256 = "TODO: pinned later"),
                 resource = list(filename = "data.csv", row_count_data_rows = 0))
    writeLines(tojs(prov, auto_unbox = TRUE), file.path(d, "data_provenance.json"))
    expect_equal(run("refresh", d)$status, 0L)
    src
  }
  s1 <- mk("one")
  h <- file.path(home, "drift.html")
  r <- run("drift", root, "--html", h)
  expect_match(r$text, "no HTML report written")
  r <- run("drift", root, "--app")
  expect_match(r$text, "no app to open")
  utils::write.csv(data.frame(id = 1:40, v = rep(c("a", "c"), 20)), s1, row.names = FALSE)
  r <- run("drift", root, "--html", h)
  expect_equal(r$status, 0L)
  expect_match(r$text, "HTML report: ", fixed = TRUE)
  p <- page_json(h)
  expect_equal(p$provenance$name, "one")
  expect_equal(unlist(p$chain$link), c("provenance", "bytes", "manifest", "attestation"))
  expect_equal(unlist(p$chain$status)[2], "warn")
  expect_equal(unlist(p$manifest$change), "changed")
  j <- fromjs(run("drift", root, "--json", "--html", h)$text, simplifyVector = FALSE)
  expect_equal(j$capsules[[1]]$drift$columns[[2]]$column, "v")
  expect_null(j$capsules[[1]]$drift$object)
  expect_length(attr(cpschk(root, "drift", fp = FALSE), "drifts"), 1L)
  launched <- NULL
  local_mocked_bindings(.bl_run_app = function(app) launched <<- app, .package = "rmoriebricklayer")
  if (requireNamespace("shiny", quietly = TRUE)) {
    r <- run("drift", root, "--app")
    expect_equal(r$status, 0L)
    expect_s3_class(launched, "shiny.appobj")
  }
  # two capsules: one page each, named after the capsule
  s2 <- mk("two")
  utils::write.csv(data.frame(id = 41:80, v = rep(c("b", "c"), 20)), s2, row.names = FALSE)
  run("drift", root, "--html", h)
  expect_true(all(file.exists(file.path(home, c("drift-one.html", "drift-two.html")))))
})

test_that("the launchers hand on to the browser and to shiny, and the help names the options", {
  seen <- NULL
  withr::local_options(browser = function(url) seen <<- url)
  expect_null(rmoriebricklayer:::.bl_open_file("x.html"))
  expect_equal(seen, "x.html")
  skip_if_not_installed("shiny")
  local_mocked_bindings(runApp = function(app) "ran", .package = "shiny")
  expect_equal(rmoriebricklayer:::.bl_run_app(NULL), "ran")
  buf <- character()
  blcli("help", out = function(s) buf <<- c(buf, s))
  expect_match(paste(buf, collapse = ""), "[--html FILE] [--app]", fixed = TRUE)
})

test_that("the curves, the Benford band, the chain and the history heatmap", {
  fx <- drift_fixture()
  d <- fx$d
  v <- d$summ$value
  expect_equal(nrow(v$dens), 64L)
  expect_true(all(diff(v$ecdf$ref) >= 0) && all(diff(v$ecdf$cur) >= 0))
  expect_equal(v$qq$ref, unname(stats::quantile(fx$ref$value, seq(0.02, 0.98, by = 0.04))))
  expect_gt(v$qq$cur[13], v$qq$ref[13])          # the median moved up by about 0.5
  # one value on each side: the bandwidth is still positive
  one <- cpsdrft(data.frame(v = 3), data.frame(v = 3))
  expect_equal(nrow(one$summ$v$dens), 64L)
  bb <- rmoriebricklayer:::.bl_benford_band(100)
  expect_equal(bb$expected, log10(1 + 1 / (1:9)))
  expect_true(all(bb$lower >= 0 & bb$lower < bb$expected & bb$upper > bb$expected))
  expect_equal(rmoriebricklayer:::.bl_benford_band(0)$upper[9] <= 1, TRUE)
  chain <- function(x) rmoriebricklayer:::.bl_drift_chain(x)$status
  expect_equal(chain(d), rep("none", 4))
  d$provenance <- list(name = "x")
  d$manifest <- data.frame(change = "unchanged")
  expect_equal(chain(d), c("ok", "ok", "ok", "none"))
  d$checks <- data.frame(part = c("provenance", "data", "data", "spec", "bundle", "data"),
                         file = c("p.json", "d.csv", "d.csv", "manifest.json", "b.json", "d.csv"),
                         check = c("provenance_readable", "data_sha256", "source_digest", "manifest_consistent",
                                   "attestation:signature", "source_columns"),
                         ok = c(TRUE, TRUE, FALSE, FALSE, TRUE, FALSE),
                         detail = c("", "", "moved", "differs", "", "drift"),
                         severity = c("error", "error", "note", "error", "error", "drift"), stringsAsFactors = FALSE)
  ch <- rmoriebricklayer:::.bl_drift_chain(d)
  expect_equal(ch$status, c("ok", "warn", "fail", "ok"))
  expect_match(ch$detail[2], "source_columns: drift")
  expect_equal(ch$detail[1], "1 check passed")
  d$checks <- d$checks[1, ]
  expect_equal(rmoriebricklayer:::.bl_drift_chain(d)$status, c("ok", "none", "none", "none"))
  h <- data.frame(run = rep(1:3, each = 2), column = rep(c("a", "b"), 3), psi = c(0.05, 0.2, 0.3, NA, 0.4, 0.1),
                  stringsAsFactors = FALSE)
  hb <- rmoriebricklayer:::.bl_drift_heat(h, list(warn = 0.1, fail = 0.25))
  expect_equal(hb$band, c("ok", "warn", "fail", "none", "fail", "ok"))
  expect_equal(with_dev(rmoriebricklayer:::.bl_drift_heat_plot(h, list(warn = 0.1, fail = 0.25)))$band, hb$band)
})

test_that("plot() draws the ECDFs, the quantiles and the fingerprint", {
  d <- drift_fixture()$d
  e <- with_dev(plot(d, what = "ecdf"))
  expect_setequal(unique(e$column), c("size", "grade", "value", "day"))
  expect_equal(max(e$ref[e$column == "grade"]), 1, tolerance = 1e-12)
  q <- with_dev(plot(d, what = "quantiles"))
  expect_setequal(unique(q$column), c("size", "value", "day"))
  expect_equal(q$ref[q$column == "value"], d$summ$value$qq$ref)
  f <- with_dev(plot(d, what = "fingerprint", warn = 0.05))
  expect_equal(nrow(f), 5L)
  expect_equal(f$radius[f$column == "size"], 1)      # the largest PSI sits on the outer ring
  expect_equal(f$verdict[f$column == "id"], "untested")
  # one or two columns: no polygon, the points alone
  expect_equal(nrow(with_dev(plot(cpsdrft(data.frame(a = 1:50), data.frame(a = 3:52)), what = "fingerprint"))), 1L)
  only_cat <- cpsdrft(data.frame(g = c("a", "b")), data.frame(g = c("a", "a")))
  expect_equal(nrow(with_dev(plot(only_cat, what = "quantiles"))), 0L)
  ids <- cpsdrft(data.frame(i = sprintf("x%03d", 1:200)), data.frame(i = sprintf("y%03d", 1:200)))
  expect_equal(nrow(with_dev(plot(ids, what = "ecdf"))), 0L)
})
