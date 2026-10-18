# The 2021 Census Indigenous Population Profile: against the published file itself

.raw_pop <- function() {
  utils::read.csv(system.file("extdata", "indigenous_census_population.csv", package = "rmoriebricklayer"),
                  check.names = FALSE, stringsAsFactors = FALSE, colClasses = "character", encoding = "UTF-8")
}

test_that("census_profile() reads every group, the hierarchy, the sample and the symbols", {
  raw <- .raw_pop()
  p <- census_profile(indigenous_example("census_population"))
  expect_s3_class(p, "rmbl_census_profile")
  expect_identical(nrow(p), nrow(raw) * 9L)
  expect_setequal(unique(p$group), c("Total", "Indigenous identity", "Single Indigenous responses", "First Nations",
                                     "M\u00e9tis", "Inuit", "Multiple Indigenous responses",
                                     "Indigenous responses not included elsewhere", "Non-Indigenous"))
  fc <- unique(p[p$characteristic == "Foster children", c("level", "parent_id", "root_id", "sample")])
  expect_identical(c(fc$level, fc$parent_id, fc$root_id), c(2L, 37L, 13L))
  expect_identical(fc$sample, "25%")
  expect_identical(unique(p$sample[p$characteristic_id == 923L]), "25%")
  # one value against the published cell
  r <- raw[raw$GEO_NAME == "Canada" & raw$CHARACTERISTIC_ID == "38" & raw$AGE_GROUP == "0 to 14 years" &
             raw$RESIDENCE == "On reserve", ]
  v <- p$value[p$geo == "Canada" & p$characteristic_id == 38L & p$age == "0 to 14 years" &
                 p$residence == "On reserve" & p$group == "First Nations"]
  expect_identical(v, as.numeric(r$FIRST_NATIONS))
  # a suppressed or unavailable cell has no value
  sx <- raw$SYMBOL_INUK %in% c("x", "F", "..", "...")
  if (any(sx)) {
    i <- which(sx)[1]
    pv <- p$value[p$geo == raw$GEO_NAME[i] & p$characteristic_id == as.integer(raw$CHARACTERISTIC_ID[i]) &
                    p$age == raw$AGE_GROUP[i] & p$residence == raw$RESIDENCE[i] & p$group == "Inuit"]
    expect_true(is.na(pv))
  }
  expect_error(census_profile(data.frame(a = 1)), "not an Indigenous Population Profile table")
  expect_error(census_profile(1), "must be a data frame or a data service key")
  bad <- raw[1:2, c("GEO_NAME", "CHARACTERISTIC_ID", "CHARACTERISTIC_NAME")]
  expect_error(census_profile(bad), "no group columns")
})

test_that("profile_share(): the published counts, and the interval of a 25% sample with random rounding", {
  raw <- .raw_pop()
  p <- census_profile(indigenous_example("census_population"))
  fc <- profile_share(p, "Foster children", "Total - Children in census families")
  r <- fc[fc$geo == "Canada" & fc$age == "0 to 14 years" & fc$residence == "Total - Residence on or off reserve" &
            fc$group == "First Nations", ]
  sel <- function(id) {
    raw[raw$GEO_NAME == "Canada" & raw$CHARACTERISTIC_ID == id & raw$AGE_GROUP == "0 to 14 years" &
          raw$RESIDENCE == "Total - Residence on or off reserve", "FIRST_NATIONS"]
  }
  n <- as.numeric(sel("38"))
  d <- as.numeric(sel("20"))
  expect_identical(c(r$numerator, r$denominator), c(n, d))
  q <- n / d
  expect_equal(r$estimate, 100 * q)
  v <- 0.75 * q * (1 - q) / (0.25 * d) + 4 * (1 + q^2) / d^2
  ne <- q * (1 - q) / v
  z <- stats::qnorm(0.975)
  wl <- (q + z^2 / (2 * ne) - z * sqrt(q * (1 - q) / ne + z^2 / (4 * ne^2))) / (1 + z^2 / ne)
  expect_equal(r$lower, 100 * wl)
  # the default denominator is the parent: persons not in census families
  dflt <- profile_share(p, 38)
  expect_identical(attr(dflt, "characteristics")[["denominator"]], "Total - Persons not in census families")
  # a design effect widens it
  w2 <- profile_share(p, "Foster children", "Total - Children in census families", deff = 2)
  expect_gt(w2$upper[1] - w2$lower[1], fc$upper[1] - fc$lower[1])
  expect_error(profile_share(p, "No such thing"), "names no characteristic")
  expect_error(profile_share(p, "Participation rate"), "has no parent")
  expect_error(profile_share(data.frame(), 1), "must come from census_profile")
  expect_error(profile_share(p, c(1, 2)), "one characteristic id or name")
})

test_that("census_standard(): the census age structure, as weights", {
  p <- census_profile(indigenous_example("census_population"))
  s <- census_standard(p)
  expect_equal(sum(s$weight), 1)
  expect_identical(nrow(s), 11L)
  raw <- .raw_pop()
  r <- raw[raw$GEO_NAME == "Canada" & raw$CHARACTERISTIC_ID == "1" & raw$AGE_GROUP == "25 to 34 years" &
             raw$RESIDENCE == "Total - Residence on or off reserve", "IND_IDENT (2)"]
  expect_identical(s$population[s$age == "25 to 34 years"], as.numeric(r))
  expect_error(census_standard(p, ages = "100 to 104 years"), "no population for")
  expect_error(census_standard(p, group = "Nobody"), "no population for group")
  # it feeds the standardisation directly
  expect_s3_class(age_standardise(rep(5, 11), rep(1000, 11), s$population), "rmbl_dsr")
})

test_that("census_cwb(): the four components worked from the published figures", {
  raw <- .raw_pop()
  p <- census_profile(indigenous_example("census_population"))
  h <- census_profile(indigenous_example("census_households"))
  cw <- census_cwb(p, h)
  fn <- cw[cw$geo == "Canada" & cw$group == "First Nations", ]
  tot <- "Total - Residence on or off reserve"
  g <- function(id, age) {
    as.numeric(raw[raw$GEO_NAME == "Canada" & raw$CHARACTERISTIC_ID == id & raw$AGE_GROUP == age &
                     raw$RESIDENCE == tot, "FIRST_NATIONS"])
  }
  inc <- g("807", "Total - Age groups") * g("809", "Total - Age groups") / g("1", "Total - Age groups")
  expect_equal(fn$income_per_capita, inc)
  expect_equal(fn$income, 100 * (log(inc) - log(2650)) / (log(75000) - log(2650)))
  expect_equal(fn$high_school_25plus, 100 * (1 - g("546", "25 years and over") / g("545", "25 years and over")))
  expect_equal(fn$labour, (g("629", "25 to 64 years") + 100 - g("631", "25 to 64 years")) / 2)
  hr <- utils::read.csv(system.file("extdata", "indigenous_census_households.csv", package = "rmoriebricklayer"),
                        check.names = FALSE, colClasses = "character")
  hv <- function(id) as.numeric(hr[hr$GEO_NAME == "Canada" & hr$CHARACTERISTIC_ID == id, "IND_HHLD (2)"])
  expect_equal(fn$housing, (100 * hv("38") / hv("37") + 100 * (1 - hv("54") / hv("52"))) / 2)
  expect_equal(fn$cwb, mean(c(fn$income, fn$education, fn$housing, fn$labour)))
  # fewer than 250 people: no score
  small <- cw[is.finite(cw$population) & cw$population < 250, ]
  expect_true(nrow(small) > 0 && all(is.na(small$cwb)))
  # without the household table, no housing component and no score
  nh <- census_cwb(p)
  expect_true(all(is.na(nh$housing)) && all(is.na(nh$cwb)))
  expect_false(all(is.na(nh$income)))
  expect_error(census_cwb(data.frame()), "must come from census_profile")
  expect_error(census_cwb(p, dwelling = data.frame()), "`dwelling` must come from census_profile")
})

test_that("a census share draws itself", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  p <- census_profile(indigenous_example("census_population"))
  fc <- profile_share(p, "Foster children", "Total - Children in census families")
  fc <- fc[fc$geo == "Canada" & fc$age == "0 to 14 years" & fc$residence == "Total - Residence on or off reserve", ]
  expect_identical(nrow(plot(fc)), nrow(fc))
})

test_that("plots of age-standardised prevalence and of Community Well-Being return what they draw", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  si <- indigenous_example("suicidal_ideation")
  si <- si[si$measure == "Seriously contemplated suicide in the past 12 months" &
              si$age != "Total, 15 years and over", ]
  si <- si[order(si$group, si$age), ]
  s <- standardise_prevalence(si$estimate, si$lower, si$upper, standard = c(20, 18, 17, 17, 28), group = si$group,
                              quality = si$quality)
  ps <- plot(s)
  expect_identical(ps$group, s$group)
  expect_equal(ps$estimate, s$estimate)
  p <- census_profile(indigenous_example("census_population"))
  cw <- census_cwb(p, census_profile(indigenous_example("census_households")))
  pc <- plot(cw)
  expect_true(all(is.finite(pc$cwb)))
  expect_setequal(unique(pc$geo), unique(cw$geo[is.finite(cw$cwb)]))
  expect_identical(names(plot(cw, component = "income")), c("geo", "group", "income"))
  expect_error(plot(cw, component = "zz"), "component")
})
