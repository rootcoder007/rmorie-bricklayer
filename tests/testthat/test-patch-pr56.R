# Lines PR #56 added that no other test reached (Codecov patch on 84840ac): each is a behaviour,
# checked here directly.

ns <- function(x) get(x, envir = asNamespace("rmoriebricklayer"))

test_that(".rmbl_arg: NULL takes the first choice", {
  expect_identical(ns(".rmbl_arg")(NULL, c("auto", "own")), "auto")
})

test_that("the native CSV reader: no header, a header past 64 columns, text after a quoted field", {
  split <- function(txt) .Call(ns("C_rmbl_csv_split"), charToRaw(txt), FALSE)
  e <- split("")
  expect_identical(e$names, character())
  expect_identical(e$columns, list())
  expect_identical(split("\n\r\n")$names, character())
  wide <- paste0(paste(sprintf("c%d", 1:150), collapse = ","), "\n", paste(1:150, collapse = ","), "\n")
  w <- split(wide)
  expect_identical(w$names, sprintf("c%d", 1:150))
  expect_length(w$columns, 150L)
  expect_identical(w$columns[[150]], 150L)
  # a blank line before a wide header
  expect_identical(split(paste0("\n", wide))$names, sprintf("c%d", 1:150))
  expect_error(split("a,b\n\"x\"y,2\n"), "a quoted field is followed by text before the next comma")
})

test_that("hurwitz_zeta past the double range is the leading term's infinity, not NaN", {
  v <- suppressWarnings(hurwitz_zeta(-60, 1e10))
  expect_identical(v, -Inf)   # zeta(-60, q) is about -q^61 / 61
})

test_that("verify_pollution refuses a list, a complex, a flag, a date or text for a number, by type", {
  for (v in list(list(1e6), 1i, "many", TRUE, factor("a"), Sys.Date())) {
    r <- verify_pollution("pm25", population = v)
    expect_identical(r$status, "error")
    expect_match(r$error, sprintf("population must be a single number, not %s", class(v)[1L]), fixed = TRUE)
  }
  expect_match(verify_pollution("pm25", population = c(1, 2))$error, "not 2 values", fixed = TRUE)
})

test_that("the route on display: a saved `hosted` is shown as retired", {
  withr::local_envvar(MORIE_LLM_ROUTE = "hosted")
  expect_match(ns(".bl_config_effective")("route"), "retired and ignored", fixed = TRUE)
})

test_that("the answer and message caches create their folder, owner-only", {
  skip_on_os("windows")
  d <- file.path(withr::local_tempdir(), "not", "yet")
  withr::local_options(rmoriebricklayer.llm_cache_dir = d)
  local_mocked_bindings(.bl_answer_cache_on = function() TRUE, .package = "rmoriebricklayer")
  suppressMessages(ns(".bl_answer_put")(strrep("b", 64), "q", "m", "the answer"))
  expect_true(dir.exists(d))
  expect_identical(as.character(file.info(d)$mode), "700")
  d2 <- file.path(withr::local_tempdir(), "msgs")
  withr::local_options(rmoriebricklayer.llm_cache_dir = d2)
  rm(list = ls(ns(".bl_ee_memo")), envir = ns(".bl_ee_memo"))
  invisible(suppressMessages(bricklayer_explain_error("could not find function")))
  expect_true(length(list.files(d2, pattern = "^messages-.*[.]rds$")) == 1L)
})

test_that("survey: a reordered frame is caught by its digests; an empty frame has none; an id replicate is refused", {
  set.seed(5)
  n <- 40
  d <- data.frame(y = rnorm(n), w = runif(n, 1, 2))
  reps <- sapply(1:6, function(b) d$w * stats::rmultinom(1, n, rep(1, n))[, 1] * n / (n - 1))
  des <- survey_design(d, weights = d$w, replicates = reps, type = "bootstrap")
  d2 <- d[c(2:n, 1L), ]
  rownames(d2) <- NULL
  expect_error(survey_estimate(des, d2, "y"), "not the data frame the design was built on")
  dg <- ns(".svy_column_digests")(d[0])
  expect_identical(dim(dg), c(0L, 2L))
  d$id <- as.numeric(seq_len(n)) * 1.5
  r2 <- data.frame(id = d$id, reps, stray = d$id)
  expect_error(survey_design(d, weights = "w", id = "id", replicates = r2, type = "bootstrap"), "the id")
})
