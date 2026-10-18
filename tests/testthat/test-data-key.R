# The data key after the language-model tier was retired: the data service checks a key and
# issues it, a document may drop its llm block, and a restricted table says how to open it.
# Canned replies only; nothing leaves the machine.

dk_ns <- function(nm) get(nm, envir = asNamespace("rmoriebricklayer"))

test_that("a key is checked at the data service: /v1/whoami, or the manifest on an older service", {
  seen <- character()
  replies <- list("/v1/whoami" = list(status = 404L), "/manifest.json" = list(status = 200L))
  local_mocked_bindings(.bl_http_get = function(url, timeout, headers) {
    seen <<- c(seen, url)
    replies[[sub("^https://data.example.org", "", url)]]
  })
  expect_identical(dk_ns(".bl_key_reply")("https://data.example.org", "sk-x")$status, 200L)
  expect_identical(seen, c("https://data.example.org/v1/whoami", "https://data.example.org/manifest.json"))
  replies[["/v1/whoami"]] <- list(status = 401L)
  seen <- character()
  expect_identical(dk_ns(".bl_key_reply")("https://data.example.org", "sk-x")$status, 401L)
  expect_length(seen, 1L)
  local_mocked_bindings(.bl_http_get = function(...) stop("no network"))
  expect_null(dk_ns(".bl_key_reply")("https://data.example.org", "sk-x"))
  # login --token asks the data service named by the signed document, never MORIE_DATA_URL (G3)
  asked <- NULL
  withr::local_envvar(MORIE_DATA_URL = "https://data2.example.org")
  local_mocked_bindings(.rmbl_services_data = function() list(mode = "key", base_url = "https://data.example.org"),
                        .bl_key_reply = function(base, key, timeout = 10) {
                          asked <<- base
                          list(status = 403L)
                        })
  expect_error(dk_ns(".bl_check_token")("sk-x"), "the data service did not accept that key (HTTP 403)", fixed = TRUE)
  expect_identical(asked, "https://data.example.org")
})

test_that("the sign-in address: the data block's auth_url, else the llm block's, else the data address", {
  withr::local_envvar(MORIE_HOSTED_AUTH_URL = NA)
  local_mocked_bindings(
    .rmbl_services_data = function() list(base_url = "https://d.example.org", auth_url = "https://d.example.org/auth"),
    .rmbl_services_llm = function() list(auth_url = "https://llm.example.org/auth")
  )
  expect_identical(dk_ns(".bl_hosted_auth")(), "https://d.example.org/auth")
  local_mocked_bindings(.rmbl_services_data = function() list(base_url = "https://d.example.org"))
  expect_identical(dk_ns(".bl_hosted_auth")(), "https://llm.example.org/auth")
  local_mocked_bindings(.rmbl_services_llm = function() list(auth_url = ""))
  expect_identical(dk_ns(".bl_hosted_auth")(), "https://d.example.org/auth")
  withr::local_envvar(MORIE_HOSTED_AUTH_URL = "https://mine.example.org/auth/")
  expect_identical(dk_ns(".bl_hosted_auth")(), "https://mine.example.org/auth")
})

test_that("a services document may leave out the llm block, and its data auth_url is checked", {
  parse <- dk_ns(".rmbl_services_parse")
  doc <- function(data) charToRaw(sprintf('{"version":1,"issued":"2026-10-14T00:00:00Z","notice":"n","data":%s}', data))
  d <- parse(doc('{"mode":"key","base_url":"https://data.rmorie.com","auth_url":"https://data.rmorie.com/auth"}'))
  expect_identical(d$llm$mode, "off")
  expect_identical(d$data$auth_url, "https://data.rmorie.com/auth")
  expect_null(parse(doc('{"mode":"key","base_url":"https://data.rmorie.com","auth_url":"http://10.0.0.1/auth"}')))
})

test_that("a restricted table refused with 403 says where to accept the terms", {
  expect_true(dk_ns(".bl_data_restricted")("icpsr_21600/ds0001"))
  expect_true(dk_ns(".bl_data_restricted")("db/ncvs_38604.db"))
  expect_true(dk_ns(".bl_data_restricted")("files/a2aj_onca/x.zip"))
  expect_false(dk_ns(".bl_data_restricted")("chicago_crime/incidents"))
  withr::local_envvar(MORIE_DATA_URL = NA)
  local_mocked_bindings(.bl_data_key = function() "sk-x", .bl_data_url = function() "https://data.rmorie.com",
                        dmnf = function(...) list(datasets = list()),
                        bldl = function(...) stop("https://data.rmorie.com/x answered HTTP 403"))
  expect_error(dk_ns(".bl_data_get")("/icpsr_21600/ds0001.csv.gz", tempfile()),
               "icpsr_21600/ds0001 is a restricted table .* https://data.rmorie.com/terms")
  expect_error(dk_ns(".bl_data_get")("/chicago_crime/incidents.csv.gz", tempfile()), "rejected the stored key")
})
