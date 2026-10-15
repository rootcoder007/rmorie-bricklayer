# bricklayer_progress() and the long-running functions wired to it. stderr is not a terminal under
# testthat, so a forced-on bar writes its milestone lines; the in-place frames are tested through
# the internal tty switch, as in test-progress-anim.R.

ns <- asNamespace("rmoriebricklayer")
msgs <- function(expr) paste(capture.output(type = "message", expr), collapse = "\n")
# progress on, with no lazy start, for the length of the calling test
progress_on <- function(env = parent.frame()) {
  withr::local_options(morie.progress = TRUE, morie.quiet = NULL, .local_envir = env)
  st <- ns$.bl_progress_state
  old <- st$delay
  st$delay <- 0
  withr::defer(st$delay <- old, envir = env)
}

test_that("the object API: update, tick, wait and done, each returning the object", {
  progress_on()
  p <- bricklayer_progress("Work", 4)
  expect_s3_class(p, "rmbl_progress")
  expect_named(p, c("update", "tick", "wait", "done"))
  out <- msgs({
    expect_identical(p$update(1, "one"), p)
    expect_identical(p$tick(info = "two"), p)
    expect_identical(p$tick(2, "four"), p)
    expect_identical(p$wait(0.05), p)
    expect_identical(p$done("Work: finished"), p)
  })
  expect_match(out, "Work: 1 of 4 (25%) one", fixed = TRUE)
  expect_match(out, "Work: 2 of 4 (50%) two", fixed = TRUE)
  expect_match(out, "Work: 4 of 4 (100%) four", fixed = TRUE)
  expect_match(out, "Work: finished", fixed = TRUE)
  expect_identical(environment(p$update)$a$done, 4)
  # done() acts once
  expect_identical(msgs(p$done("again")), "")
  expect_output(print(p), "<progress \"Work\": 4 of 4>", fixed = TRUE)
})

test_that("a milestone line at each tenth off a terminal, not one per step", {
  progress_on()
  out <- capture.output(type = "message", {
    p <- bricklayer_progress("Loop", 200)
    for (i in 1:200) p$tick(info = sprintf("step %d/200", i))
    p$done()
  })
  expect_length(out, 10L)
  expect_match(out[[1]], "Loop: 20 of 200 (10%) step 20/200", fixed = TRUE)
  expect_match(out[[10]], "Loop: 200 of 200 (100%)", fixed = TRUE)
})

test_that("quiet draws nothing, by argument, by option, and outside an interactive session", {
  progress_on()
  run <- function(...) {
    msgs({
      p <- bricklayer_progress("Q", 10, ...)
      for (i in 1:10) p$tick(info = "x")
      p$wait(0.01)
      p$done("summary")
    })
  }
  expect_identical(run(quiet = TRUE), "")
  withr::local_options(morie.quiet = TRUE)
  expect_identical(run(), "")
  withr::local_options(morie.quiet = NULL, morie.progress = NULL)
  if (!interactive()) expect_identical(run(), "")
  expect_match(run(quiet = FALSE), "Q: 10 of 10", fixed = TRUE)
})

test_that("nothing is drawn before the delay, so a fast call stays silent", {
  progress_on()
  out <- msgs({
    p <- bricklayer_progress("Fast", 5, delay = 60)
    for (i in 1:5) p$tick()
    p$done("Fast: done")
  })
  expect_identical(out, "")
  out <- msgs({
    p <- bricklayer_progress("Slow", 5, delay = 0.05)
    p$tick()
    Sys.sleep(0.1)
    for (i in 2:5) p$tick()
    p$done("Slow: done")
  })
  expect_match(out, "Slow: 5 of 5", fixed = TRUE)
  expect_match(out, "Slow: done", fixed = TRUE)
})

test_that("work with no count: a line at each stage, at most one every two seconds", {
  progress_on()
  out <- capture.output(type = "message", {
    p <- bricklayer_progress("Fit", 0)
    p$update(info = "reading")
    p$update(info = "fitting")
    p$done()
  })
  expect_length(out, 1L)
  expect_match(out, "^  Fit: reading \\([0-9.]+s\\)$")
  # on a terminal, a spinner, the label, the time so far and the stage, with no bar
  a <- ns$.bl_anim_new("Fit", 0, quiet = FALSE, tty = TRUE)
  a$indeterminate <- TRUE
  a$info <- "fitting"
  line <- ns$.bl_anim_line(a, 75)
  expect_match(line, "Fit 1m15s  fitting", fixed = TRUE)
  expect_false(grepl("%", line, fixed = TRUE))
  expect_identical(ns$.bl_fmt_elapsed(3.25), "3.2s")
})

test_that("a terminal gets one line redrawn in place, cleared at the end", {
  progress_on()
  withr::local_envvar(c(NO_COLOR = "1", COLUMNS = "100"))
  p <- bricklayer_progress("Draw", 3)
  a <- environment(p$update)$a
  a$tty <- TRUE
  out <- msgs({
    p$update(1, "one")
    p$done("Draw: done")
  })
  expect_match(out, "\rDraw|\r. Draw", perl = TRUE)
  expect_match(out, "Draw: done", fixed = TRUE)
  expect_false(grepl("\033", out, fixed = TRUE))
})

test_that("done() through on.exit() runs when the work errors, and releases the bar", {
  progress_on()
  f <- function() {
    p <- bricklayer_progress("Boom", 10)
    on.exit(p$done("Boom: ended"), add = TRUE)
    p$tick(5, "halfway")
    stop("the work failed")
  }
  out <- msgs(expect_error(f(), "the work failed"))
  expect_match(out, "Boom: 5 of 10 (50%) halfway", fixed = TRUE)
  expect_match(out, "Boom: ended", fixed = TRUE)
  expect_length(ns$.bl_progress_state$active, 0L)
})

test_that("nested work shows one bar, and a bar left open cannot silence later ones", {
  progress_on()
  inner <- function() {
    p <- bricklayer_progress("Inner", 2)
    on.exit(p$done(), add = TRUE)
    p$tick()
    p$tick()
  }
  outer <- function() {
    p <- bricklayer_progress("Outer", 2)
    on.exit(p$done(), add = TRUE)
    for (i in 1:2) {
      inner()
      p$tick()
    }
  }
  out <- msgs(outer())
  expect_match(out, "Outer: 2 of 2", fixed = TRUE)
  expect_false(grepl("Inner", out, fixed = TRUE))
  # a function that never calls done(): once it has returned, its bar holds nothing back
  leaky <- function() {
    bricklayer_progress("Leak", 1)
    invisible()
  }
  leaky()
  expect_match(msgs(inner()), "Inner: 2 of 2", fixed = TRUE)
})

test_that("the helper refuses bad arguments in words", {
  expect_error(bricklayer_progress(c("a", "b"), 1), "`label` must be a single string")
  expect_error(bricklayer_progress("a", -1), "`total` must be a single non-negative number")
  expect_error(bricklayer_progress("a", NA), "`total` must be a single non-negative number")
  expect_error(bricklayer_progress("a", 1, color = "pink"), "`color` must be one of")
  expect_error(bricklayer_progress("a", 1, quiet = NA), "`quiet` must be TRUE, FALSE or NULL")
  expect_error(bricklayer_progress("a", 1, delay = -1), "`delay` must be a single non-negative number")
  expect_identical(ns$.bl_count("x"), 0)
  expect_identical(ns$.bl_count(Inf), 0)
  expect_identical(ns$.bl_count(7L), 7)
})

# ---- every wired function: progress when forced on, silence when quiet -------------------------

wired <- function(label, expr, pattern = label) {
  expr <- substitute(expr)
  env <- parent.frame()
  test_that(sprintf("%s shows progress when forced on and nothing when quiet", label), {
    progress_on()
    out <- msgs(invisible(suppressWarnings(eval(expr, env))))
    expect_match(out, pattern, fixed = TRUE)
    withr::local_options(morie.quiet = TRUE)
    expect_identical(msgs(invisible(suppressWarnings(eval(expr, env)))), "")
  })
}

set.seed(1)
d <- data.frame(x1 = rnorm(200), x2 = rnorm(200))
d$exposure <- 20 + 2 * d$x1 + rnorm(200)
d$asthma <- 5 + 0.3 * d$exposure + d$x2 + rnorm(200)
dx <- data.frame(x = rnorm(60))
dx$y <- 0.8 * dx$x + rnorm(60)
inj <- function(z, size) {
  z$y <- z$y + size * z$x
  z
}
b <- read.csv(system.file("extdata", "tps_break_enter_d14_2024.csv", package = "rmoriebricklayer"))
b <- b[!is.na(b$lon), ]
m <- data.frame(x = rnorm(120), y = rnorm(120))
m$y[sample(120, 30)] <- NA

wired("cross-fitting", plr_crossfit(d, "asthma", "exposure", c("x1", "x2")), "cross-fitting: 1 of 5")
wired("exposure-response bootstrap",
      exposure_response_plr(d, "asthma", "exposure", c("x1", "x2"), n_bootstrap = 10),
      "bootstrap 10/10")
wired("Knox test", knox_test(b$lon, b$lat, as.Date(b$occ_date), c(100, 200), c(7, 14), nsim = 19, seed = 1),
      "permutation")
wired("step change", step_change(c(100, 104, 98, 60, 63, 58, 61, 99, 70, 64), n_perm = 50), "permutation")
wired("step change (exact)", step_change(c(5, 6, 1, 2), n_perm = 50), "ordering")
wired("falsification", capsule_falsify(dx, function(z) cor(z$x, z$y), treatment = "x", n = 19, seed = 1),
      "subset")
wired("power curve", capsule_power(dx, function(z) cor(z$x, z$y), inj, sizes = 0.5, treatment = "x",
                                   n = 19, reps = 2, seed = 1), "rep 2/2")
wired("drift calibration", drift_calibrate(data.frame(a = rnorm(80)), n = 5), "split 5/5")
wired("Hawkes fit (weibull) by EM", core_hawkes_fit(sort(runif(100, 0, 50)), 50, "weibull", method = "em"),
      "Hawkes fit (weibull): fitting 100 events")
wired("EM (normal, missing data)", mcar_test(m), "iteration 1")
wired("particles", lagrangian_particles(10, 0, 0, 1, 0, 1, 1, 1, 20), "particles: 2 of 20")
wired("advection-diffusion", advection_diffusion_2d(matrix(1, 6, 6), 1, 0, 1, 1, 10, 10, 1, 10),
      "advection-diffusion: 1 of 10")
wired("Gaussian plume", plume_field(100, 5, 50, x = seq(100, 1000, by = 100), y = c(-50, 0, 50)),
      "Gaussian plume: 3 of 30")
wired("Gaussian puff", gaussian_puff(1, 5, 10, cbind(1:20, 0, 0), t = 10), "Gaussian puff")
wired("synthetic data", make_synthetic_csv(list(n_rows = 5, seed = 1, columns = list(
  a = list(type = "bernoulli", p = 0.5), b = list(type = "poisson", lambda = 2))), tempfile(fileext = ".csv")),
  "synthetic data: 1 of 3")
wired("profiling columns", profile_columns(data.frame(a = 1:5, b = letters[1:5])), "profiling columns: 1 of 2")
wired("correlations (table)", correlation_table(data.frame(a = rnorm(9), b = rnorm(9), c = rnorm(9))),
      "correlations: 1 of 3")
wired("correlations (top)", top_correlations(data.frame(a = rnorm(9), b = rnorm(9), c = rnorm(9))),
      "correlations: 1 of 3")
wired("Mahalanobis distances", mahalanobis_outliers(data.frame(a = rnorm(30), b = rnorm(30))), "centring 30 rows")

reps <- replicate(10, d$x1^2 + 1 + runif(200))
d$w <- rowMeans(reps)
wired("checking replicate weights",
      survey_design(d, weights = "w", replicates = reps, type = "bootstrap"), "replicate 10/10")

bdir <- tempfile()
dir.create(bdir)
for (i in 1:4) writeLines(as.character(i), file.path(bdir, sprintf("f%d.txt", i)))
bkey <- fips_keygen("ML-DSA-44")
bman <- make_manifest(list(dataset = "demo"), environment = FALSE)
wired("bundling", capsule_bundle(bdir, bman, bkey, path = tempfile(fileext = ".json")), "bundling: 1 of 4")
bpath <- tempfile(fileext = ".json")
invisible(capsule_bundle(bdir, bman, bkey, path = bpath))
wired("verifying bundle", capsule_bundle_verify(bpath, bdir, manifest = bman), "verifying bundle: 1 of 4")
wired("Benford digits", benford_test(rep(c(1.5, 23, 345), length.out = 1e6 + 5)), "1,000,005 of 1,000,005 values")
wired("distinct sketch", distinct_sketch(rep_len(1:5000, 1e6 + 5)), "1,000,005 of 1,000,005 values")
wired("drift screen", capsule_drift(data.frame(a = rnorm(50), b = runif(50)), data.frame(a = rnorm(50), b = runif(50))),
      "drift screen: 1 of 2 (50%) a")
wired("reading package descriptions", capture_dependencies(c("stats", "utils")), "1 of 2 (50%) stats")
otis <- read.csv(system.file("extdata", "otis_a01_individuals.csv", package = "rmoriebricklayer"))
wired("trends", analyse_table(otis, value = "individuals", period = "year", by = c("table", "group")), "trends: 1 of")
wired("exact p-values", yoy_pvalues(yoy(c(10, 20, 15, 30, 25, 40))), "exact p-values")

# ---- the long native calls: a spinner with the stage, through .bl_busy() ------------------------

test_that("the native routes name their stage for the spinner", {
  labels <- character()
  local_mocked_bindings(.bl_busy = function(label, expr) {
    labels <<- c(labels, label)
    expr
  })
  set.seed(3)
  invisible(core_hawkes_fit(sort(runif(100, 0, 50)), 50, "weibull"))
  expect_true(any(grepl("Hawkes fit (weibull, 100 events): first start", labels, fixed = TRUE)))
  expect_true(any(grepl("second start, from the exponential fit", labels, fixed = TRUE)))
  invisible(pqc_keygen(2))
  expect_true(any(grepl("XMSS key: building the tree of 4 one-time keys", labels, fixed = TRUE)))
  invisible(derive_key("pw", as.raw(1:16), iterations = 10L))
  expect_true(any(grepl("deriving a key (10 PBKDF2 iterations)", labels, fixed = TRUE)))
  invisible(ns$.bl_net("https://user@data.example.org:8443/x?y=1", 1))
  expect_true(any(labels == "waiting for data.example.org:8443"))
})

test_that("a busy spinner is set only when a person is watching a terminal, outside any bar", {
  seen <- list()
  local_mocked_bindings(.bl_stderr_tty = function() TRUE)
  withr::local_options(morie.progress = TRUE, morie.quiet = NULL)
  expect_identical(ns$.bl_busy("work", {
    seen$on <- ns$.bl_progress_state$busy
    # an inner one keeps the outer label
    ns$.bl_busy("inner", seen$inner <- ns$.bl_progress_state$busy)
    seen$after_inner <- ns$.bl_progress_state$busy
    2
  }), 2)
  expect_true(seen$on)
  expect_true(seen$inner)
  expect_true(seen$after_inner)
  expect_false(ns$.bl_progress_state$busy)
  # inside a running bar the bar is the one line
  f <- function() {
    p <- bricklayer_progress("Bar", 1)
    on.exit(p$done(), add = TRUE)
    ns$.bl_busy("x", ns$.bl_progress_state$busy)
  }
  expect_false(f())
  # an error inside clears the label
  expect_error(ns$.bl_busy("boom", stop("failed")), "failed")
  expect_false(ns$.bl_progress_state$busy)
})
