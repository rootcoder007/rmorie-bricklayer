# data.rmorie.com: key handling, manifest cache, download cache, data verbs.

test_that("data hub: key, manifest cache, table cache, CLI verbs", {
  withr::local_envvar(XDG_CONFIG_HOME = withr::local_tempdir(),
                      MORIE_HOSTED_KEY = NA,
                      MORIE_DATA_URL = "https://data.example.test")
  withr::local_options(rmoriebricklayer.data_cache = withr::local_tempdir())
  expect_error(bricklayer_data_manifest(), "bricklayer_llm_login")
  withr::local_envvar(MORIE_HOSTED_KEY = "sk-good")
  calls <- character()
  manifest <- paste0(
    '{"generated_utc":"2026-10-01T00:00:00Z",',
    '"datasets":[{"db":"chicago_crime",',
    '"table":"incidents","key":"chicago_crime/incidents","rows":3,',
    '"columns":["id","type"],"bytes_gz":10,"sha256":"x",',
    '"source":"bigquery-public-data.chicago_crime.crime",',
    '"meta":{"description":"Chicago Police incidents"}}]}'
  )
  fake_get <- function(path, dest, timeout = 600) {
    calls <<- c(calls, path)
    if (path == "/manifest.json") {
      writeLines(manifest, dest)
    } else if (path == "/chicago_crime/incidents.csv.gz") {
      con <- gzfile(dest, "w")
      writeLines(c("id,type", "1,THEFT", "2,BATTERY", "3,THEFT"), con)
      close(con)
    } else {
      stop("404")
    }
    invisible(dest)
  }
  testthat::local_mocked_bindings(.bl_data_get = fake_get)
  t <- bricklayer_data_tables()
  expect_equal(t$key, "chicago_crime/incidents")
  expect_equal(t$name, "Chicago Police incidents")
  expect_equal(t$rows, 3L)
  bricklayer_data_tables()
  expect_equal(sum(calls == "/manifest.json"), 1L)
  df <- bricklayer_data_load("chicago_crime/incidents")
  expect_equal(names(df), c("id", "type"))
  expect_equal(nrow(df), 3L)
  bricklayer_data_load("chicago_crime/incidents")
  expect_equal(sum(calls == "/chicago_crime/incidents.csv.gz"), 1L)
  expect_error(bricklayer_data_load("nokey"), "db/table")
  buf <- character()
  st <- bricklayer_cli(c("data", "list"), out = function(s) buf <<- c(buf, s))
  expect_equal(st, 0L)
  expect_match(paste(buf, collapse = ""), "chicago_crime/incidents")
  out <- withr::local_tempfile(fileext = ".csv")
  args <- c("data", "pull", "chicago_crime/incidents", "--out", out)
  st <- bricklayer_cli(args, out = function(s) buf <<- c(buf, s))
  expect_equal(st, 0L)
  expect_equal(nrow(utils::read.csv(out)), 3L)
  helptext <- character()
  bricklayer_cli("help", out = function(s) helptext <<- c(helptext, s))
  expect_match(paste(helptext, collapse = ""), "data pull")
})

test_that("the table list prints left-aligned, one line per table, in R and in the CLI", {
  t <- .bl_data_tables_df(
    c("bbc_news/articles", "a/b"),
    c("BBC News reference corpus with 2,225 articles across five categories, a common benchmark", "Short"),
    c(2225L, NA), c("", "")
  )
  expect_s3_class(t, "data.frame")
  txt <- .bl_format_data_tables(t, width = 60L)
  lines <- strsplit(txt, "\n", fixed = TRUE)[[1L]]
  expect_match(lines[[1L]], "^key +rows  name$")
  expect_match(lines[[2L]], "^bbc_news/articles  2,225  BBC News")
  expect_match(lines[[3L]], "^a/b +-  Short$")
  expect_true(all(nchar(lines[2:3]) <= 60L))
  expect_match(lines[[2L]], "[.][.][.]$")
  printed <- utils::capture.output(print(t))
  expect_match(printed[[1L]], "^key +rows  name$")
  expect_true(any(grepl("bricklayer_data_load", printed, fixed = TRUE)))
  expect_match(utils::capture.output(print(t[, c("key", "source")]))[[1L]], "key")
  expect_match(.bl_format_data_tables(t[0L, ]), "no curated tables")
})

test_that("a table with a blank description and source is named by its key", {
  otis <- list(key = "otis/otis_main", source = "", meta = list(description = ""))
  expect_identical(.bl_data_name(otis), "otis/otis_main")
  expect_identical(.bl_data_name(list(key = "a/b", source = "src", meta = list(description = " "))), "src")
  expect_identical(.bl_data_name(list(key = "a/b", source = "src", meta = list(description = "Desc"))), "Desc")
  expect_identical(.bl_data_name(list(key = "", source = NULL, meta = list(description = " "))), "")
  expect_identical(.bl_data_name(list()), "")
})
