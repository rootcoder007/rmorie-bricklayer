# The data service after the language-model tier was retired: a document may
# drop its llm block, and a table whose terms forbid redistribution is not
# offered. Canned replies only; nothing leaves the machine.

dk_ns <- function(nm) get(nm, envir = asNamespace("rmoriebricklayer"))

test_that(
  paste0(
    "a services document may leave out the llm block, and its data auth_url ",
    "is checked"
  ),
  {
    parse <- dk_ns(".rmbl_services_parse")
    doc <- function(data) {
      charToRaw(sprintf(
        '{"version":1,"issued":"2026-10-14T00:00:00Z","notice":"n","data":%s}',
        data
      ))
    }
    d <- parse(doc(
      paste0(
        '{"mode":"key","base_url":"https://data.rmorie.com","auth_url":"https',
        '://data.rmorie.com/auth"}'
      )
    ))
    expect_identical(d$llm$mode, "off")
    expect_identical(d$data$auth_url, "https://data.rmorie.com/auth")
    expect_null(parse(doc(
      paste0(
        '{"mode":"key","base_url":"https://data.rmorie.com","auth_url":"http:',
        '//10.0.0.1/auth"}'
      )
    )))
  }
)

test_that(
  paste0(
    "a table that is not served is never offered a terms page; ",
    "A2AJ case law is an open table"
  ),
  {
    expect_true(dk_ns(".bl_data_restricted")("icpsr_21600/ds0001"))
    expect_true(dk_ns(".bl_data_restricted")("db/ncvs_38604.db"))
    expect_false(dk_ns(".bl_data_restricted")("files/a2aj_onca/x.zip"))
    expect_false(dk_ns(".bl_data_restricted")("a2aj_onca/onca_decisions_meta"))
    expect_false(dk_ns(".bl_data_restricted")("chicago_crime/incidents"))
    withr::local_envvar(MORIE_DATA_URL = NA)
    local_mocked_bindings(
      .bl_data_url = function() "https://data.rmorie.com",
      dmnf = function(...) list(datasets = list()),
      bldl = function(...) stop("https://data.rmorie.com/x answered HTTP 403")
    )
    # a 403 is the service asking for a key, whatever the table: no table
    # is behind a terms page
    e <- expect_error(
      dk_ns(".bl_data_get")("/icpsr_21600/ds0001.csv.gz", tempfile()),
      "asked for a key"
    )
    expect_false(grepl("terms", conditionMessage(e), fixed = TRUE))
    expect_error(
      dk_ns(".bl_data_get")("/chicago_crime/incidents.csv.gz", tempfile()),
      "asked for a key"
    )
  }
)
