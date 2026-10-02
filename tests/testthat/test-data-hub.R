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
