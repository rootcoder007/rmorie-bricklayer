# Calls to Action 19 and 55: the catalogue and the gaps, against indgap() itself

test_that(
  paste0(
    "trcind() covers every Call 19 indicator, each with a direction or a ",
    "reason for none"
  ),
  {
    ti <- trcind()
    c19 <- c(
      "infant mortality",
      "maternal health",
      "suicide",
      "mental health",
      "addictions",
      "life expectancy",
      "birth rates",
      "infant and child health issues",
      "chronic diseases",
      "illness and injury incidence",
      "availability of appropriate health services"
    )
    expect_setequal(unique(ti$indicator[ti$call == "19"]), c19)
    expect_true(all(ti$better %in% c("higher", "lower", "")))
    expect_true(all(nzchar(ti$note[!nzchar(ti$better)])))
    expect_setequal(
      unique(ti$indicator[ti$call == "55"]),
      c("children in care", "educational attainment", "income attainment")
    )
  }
)

test_that(
  paste0(
    "trchlthgap(): each gap is indgap's ratio, turned so that above 1 is ",
    "worse"
  ),
  {
    g <- trchlthgap()
    expect_s3_class(g, "rmbl_trc_gaps")
    h <- indiex("health")
    d <- h[
      h$period == "2019/2022" &
        h$age == "Total, 18 years and over" &
        h$indicator == "Mood disorder",
    ]
    ig <- indgap(d, "group", "estimate", "lower", "upper", qual = "quality")
    r <- g[g$measure == "Mood disorder" & g$group == "First Nations", ]
    expect_identical(r$disratio, ig$ratio[ig$group == "First Nations"])
    expect_identical(r$lower, ig$ratiolo[ig$group == "First Nations"])
    # higher is better: the ratio is inverted, and so is its interval
    le <- indiex("lifeexp")
    le <- le[le$period == "2016/2021", ]
    il <- indgap(le, "group", "estimate", "lower", "upper", qual = "quality")
    r2 <- g[g$measure == "Life expectancy at birth" & g$group == "Inuit", ]
    expect_identical(r2$disratio, 1 / il$ratio[il$group == "Inuit"])
    expect_identical(r2$lower, 1 / il$ratioup[il$group == "Inuit"])
    expect_identical(r2$period, "2016/2021")
    expect_true(r2$worse)
    # the latest period with values: infant mortality 2014/2016, not the
    # unavailable 1994/1996
    expect_identical(
      unique(g$period[g$measure == "Infant mortality rate"]),
      "2014/2016"
    )
    expect_identical(g$worse, is.finite(g$lower) & g$lower > 1)
    # 41-10-0021 has no non-Indigenous rows, so suicidal thoughts are not among
    # the gaps
    expect_false(
      "Seriously contemplated suicide in the past 12 months" %in% g$measure
    )
    only <- trchlthgap(health = NULL, infmort = NULL, suiide = NULL)
    expect_identical(unique(only$measure), "Life expectancy at birth")
    expect_error(trchlthgap(NULL, NULL, NULL, NULL), "no table given measures")
    expect_error(trchlthgap(health = 1), "`health` must be a data frame")
    expect_error(trchlthgap(lifeexp = 1), "must be data frames or NULL")
    expect_error(trchlthgap(suiide = 1), "`suiide` must be a data frame")
    grDevices::pdf(NULL)
    on.exit(grDevices::dev.off(), add = TRUE)
    expect_identical(nrow(plot(g)), sum(is.finite(g$disratio)))
  }
)

# ---- printed boxes -----------------------------------------------------------

# format() gives the plain lines of one titled block; print() draws them as a
# box that fits an 80-column console, ASCII where the console takes no Unicode,
# and returns the object invisibly.
expect_box <- function(x, title, has = character()) {
  withr::local_envvar(RMBL_ASCII_ONLY = "1")
  withr::local_options(rmoriebricklayer.width = 80, rmoriebricklayer.numcol = 1)
  txt <- format(x)
  expect_type(txt, "character")
  expect_true(grepl(title, txt[1L], fixed = TRUE), info = txt[1L])
  flat <- paste(txt, collapse = "\n")
  for (h in has) {
    expect_true(grepl(h, flat, fixed = TRUE), info = h)
  }
  out <- utils::capture.output(print(x))
  expect_output(expect_invisible(print(x)), "+-- ", fixed = TRUE)
  expect_identical(withr::with_output_sink(nullfile(), print(x)), x)
  expect_match(out[1L], "^\\+-- ")
  expect_match(out[length(out)], "^\\+-+\\+$")
  expect_true(all(nchar(out) == nchar(out[1L])))
  expect_true(all(nchar(out) <= 79L))
  invisible(out)
}

test_that("the Call 19 gaps print as a box, one table per measure", {
  g <- trchlthgap()
  out <- expect_box(
    g,
    "Truth and Reconciliation Call 19",
    c("First Nations", "M\u00e9tis", "Inuit", "disratio", "Call 55")
  )
  expect_true(any(grepl("Infant mortality", out, fixed = TRUE)))
  expect_output(
    print(g[g$group == "Inuit", c("measure", "disratio")]),
    "Inuit|disratio"
  )
})

test_that("trchlthgap() takes tables of your own and their all-ages label", {
  expect_identical(
    trchlthgap(agetot = c("Total, 18 years and over",
                          "Total, 15 years and over")),
    trchlthgap()
  )
  le <- data.frame(
    period = "2017/2019",
    group = c("First Nations", "Inuit", "Non-Indigenous"),
    estimate = c(74.2, 70.9, 81.8),
    lower = c(73.6, 69.1, 81.6),
    upper = c(74.8, 72.7, 82.0),
    quality = "ok",
    stringsAsFactors = FALSE
  )
  g <- trchlthgap(health = NULL, lifeexp = le, infmort = NULL, suiide = NULL)
  expect_s3_class(g, "rmbl_trc_gaps")
  expect_equal(g$disratio, 81.8 / c(74.2, 70.9), tolerance = 1e-12)
  # a health table with its own age label, or none
  h <- indiex("health")
  h <- h[h$age == "Total, 18 years and over", ]
  h2 <- h
  h2$age <- "All adults"
  a <- trchlthgap(health = h, lifeexp = NULL, infmort = NULL, suiide = NULL)
  b <- trchlthgap(
    health = h2, lifeexp = NULL, infmort = NULL, suiide = NULL,
    agetot = "All adults"
  )
  expect_equal(a, b, tolerance = 1e-12)
  h2$age <- NULL
  expect_equal(
    trchlthgap(health = h2, lifeexp = NULL, infmort = NULL, suiide = NULL),
    a,
    tolerance = 1e-12
  )
  expect_error(trchlthgap(agetot = 1), "trchlthgap: `agetot` must be")
  expect_error(trchlthgap(agetot = letters[1:3]), "trchlthgap: `agetot`")
})

test_that("the suicidal-thoughts gap uses the latest period only", {
  d <- data.frame(
    measure = "m",
    group = c("A", "B", "A", "B"),
    period = c("2015", "2015", "2019", "2019"),
    estimate = c(10, 5, 12, 6),
    lower = c(8, 4, 10, 5),
    upper = c(12, 6, 14, 7),
    quality = "A",
    stringsAsFactors = FALSE
  )
  ti <- data.frame(
    table = "41-10-0021", measure = "m", indicator = "Suicidal thoughts",
    better = "lower", stringsAsFactors = FALSE
  )
  r <- .trc_suicide_gap(d, ti, "B", "Total")
  expect_length(r, 1L)
  expect_true(all(r[[1L]]$period == "2019"))
  expect_identical(r[[1L]]$estimate[r[[1L]]$group == "A"], 12)
})
