# The demonstration datasets: each builds, has the columns its help page lists,
# has between 100 and 5,000 rows, is the same on every call, and leaves the
# caller's random number stream alone.

cols <- list(
  court = c(
    "court",
    "region",
    "month",
    "date",
    "received",
    "disposed",
    "pending",
    "clearance",
    "caseload",
    "delay",
    "reformed",
    "refmonth"
  ),
  offences = c("area", "year", "month", "date", "n", "pop"),
  offences_annual = c("area", "year", "n", "pop"),
  survey = c(
    "stratum",
    "psu",
    "w",
    "age",
    "sex",
    "smoker",
    "drinks",
    "victim",
    "trust",
    "income",
    sprintf("rw%02d", 1:20)
  ),
  fnmi = c(
    "period",
    "group",
    "age",
    "indicator",
    "estimate",
    "lower",
    "upper",
    "quality"
  ),
  otis = c("inst", "cd", "region", "year", "people", "days", "releases"),
  air = c(
    "monitor",
    "hour",
    "x",
    "y",
    "z",
    "wind_from",
    "wind_speed",
    "stability",
    "no2"
  ),
  hawkes = c("t", "date", "district"),
  drift = c("snapshot", "age", "income", "region", "visits", "satisfied"),
  waits = c("case_id", "court_type", "days", "appearances")
)

test_that("rmbldemo() lists its datasets with a one-line description each", {
  tab <- rmbldemo()
  expect_named(tab, c("name", "rows", "description"))
  expect_setequal(tab$name, c(names(cols), "ledger"))
  expect_true(all(nzchar(tab$description) & nchar(tab$description) < 90L))
})

test_that(
  paste0(
    "every demo dataset builds, with its documented columns and rows, the ",
    "same on every call"
  ),
  {
    tab <- rmbldemo()
    set.seed(99)
    before <- stats::runif(1L)
    set.seed(99)
    for (nm in names(cols)) {
      d <- rmbldemo(nm)
      expect_s3_class(d, "data.frame")
      expect_named(d, cols[[nm]], info = nm)
      expect_gte(nrow(d), 100L)
      expect_lte(nrow(d), 5000L)
      r <- tab$rows[tab$name == nm]
      if (!is.na(r)) {
        expect_identical(nrow(d), r, info = nm)
      }
      expect_identical(rmbldemo(nm), d, info = nm)
    }
    # the caller's stream is where it was
    expect_identical(stats::runif(1L), before)
    # no random number stream at all stays that way
    rm(".Random.seed", envir = globalenv())
    invisible(rmbldemo("court"))
    expect_false(exists(".Random.seed", envir = globalenv(), inherits = FALSE))
  }
)

test_that("the demo data carry what their tabs need", {
  ct <- rmbldemo("court")
  expect_identical(
    sum(!is.na(unique(ct[, c("court", "refmonth")])$refmonth)),
    8L
  )
  expect_true(all(
    ct$reformed == as.integer(!is.na(ct$refmonth) & ct$month >= ct$refmonth)
  ))
  of <- rmbldemo("offences")
  pre <- mean(of$n[of$date < as.Date("2020-04-01")])
  post <- mean(of$n[of$date >= as.Date("2020-04-01")])
  expect_lt(post / pre, 0.85)
  sv <- rmbldemo("survey")
  expect_length(unique(sv$psu), 40L)
  expect_true(anyNA(sv$income))
  fn <- rmbldemo("fnmi")
  expect_true(any(fn$quality == "F"))
  expect_true(all(is.na(fn$estimate[fn$quality == "F"])))
  expect_setequal(
    unique(fn$group),
    c("First Nations", "Métis", "Inuit", "Non-Indigenous")
  )
  air <- rmbldemo("air")
  expect_gt(max(air$no2), 3 * stats::median(air$no2))
  hk <- rmbldemo("hawkes")
  expect_true(all(diff(hk$t) > 0))
  expect_lte(max(hk$t), 365)
  dr <- rmbldemo("drift")
  expect_identical(
    as.vector(table(dr$snapshot)[c("reference", "current")]),
    c(1500L, 1500L)
  )
  led <- rmbldemo("ledger")
  expect_length(led$theorems, 120L)
  expect_true(file.exists(attr(led, "path")))
  expect_true(all(ldgrchk(led)$ok[grepl("thm-00[1-4]", ldgrchk(led)$check)]))
})

test_that("rmbldemo() refuses a name it does not have, in its own words", {
  expect_error(
    rmbldemo("nope"),
    "rmbldemo: `name` must be one of court, offences"
  )
  expect_error(rmbldemo(c("court", "air")), "name")
})
