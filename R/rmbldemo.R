# SPDX-License-Identifier: AGPL-3.0-or-later
# Seeded, made-up datasets shaped like the data each family of the package reads: the dashboard
# opens every tab on one of them, and the examples can use them without a download.

#' Demonstration datasets
#'
#' Seeded synthetic datasets, made up but shaped like the data each family of the
#' package reads, so that every tab of [rmblapp()] (and any
#'   example) has something
#' realistic to run on without a download. Each call with the same `name` returns the
#' same data, and the caller's random number stream is left as it was.
#'
#' @details Every dataset is generated in R from a fixed seed, with
#'   [mksyncol()] for the
#'   categorical and count columns and base R's random number generators for the rest.
#'   None of it describes real people, courts or places.
#' \describe{
#'   \item{`court`}{576 rows: 16 courts by 36 months (2022 to 2024). Columns
#'   `court`,
#'     `region`, `month` (1 to 36), `date`, `received`, `disposed`,
#'     `pending` (the
#'     backlog carried forward), `clearance` (disposed per 100 received), `caseload`
#'     (cases received per judge), `delay` (median days to disposition), `reformed`
#'     (1 from the month a court adopted the reform) and `refmonth` (the month it did,
#'     `NA` for the eight that never did). Eight courts adopt a case-management reform
#'     in months 13, 19, 25 or 31; it lowers `delay` by 12 days, and the courts share
#'     a seasonal cycle and a common trend, so the parallel-trends assumption holds.}
#'   \item{`offences`}{1,440 rows: monthly offence counts for 10 areas, 2013 to 2024.
#'     Columns `area`, `year`, `month`, `date`, `n` (Poisson counts
#'     with a summer peak
#'     of about 15 percent) and `pop` (growing 1 percent a year). From April 2020 every
#'     area's level steps down by 28 percent and stays there.}
#'   \item{`offences_annual`}{120 rows: `offences` summed by area and year
#'   (`n`), with
#'     the mean population (`pop`).}
#'   \item{`survey`}{1,200 respondents of a stratified two-stage sample: 4 strata
#'     (`stratum`), 10 primary sampling units in each (`psu`), design weights
#'     (`w`),
#'     and 20 bootstrap replicate weights `rw01` to `rw20` (Rao-Wu: primary units
#'     drawn
#'     with replacement within each stratum). Variables `age`, `sex`, `smoker`
#'     (0/1),
#'     `drinks` per week, `victim` (0/1, victimised in the past year), `trust`
#'     (1 to 5)
#'     and `income` (with 8 percent missing and a few very large values).}
#'   \item{`fnmi`}{128 rows in the layout of [indiex()]:
#'   `period` (2015/2018,
#'     2019/2022), `group` (First Nations, Metis, Inuit, Non-Indigenous), `age`,
#'     `indicator` (four health indicators), `estimate`, `lower`, `upper`
#'     (95 percent)
#'     and `quality` (A to E by coefficient of variation; F, with the estimate and its
#'     interval suppressed, above 33.3 percent).}
#'   \item{`otis`}{144 rows: admissions to 12 institutions in 2013 to 2024, as a stock
#'     and flow table. Columns `inst`, `cd` (census division), `region`,
#'     `year`,
#'     `people` (admissions), `days` (days in custody of those admitted) and
#'     `releases`. Lengths of stay are log-normal and drift up after 2019.}
#'   \item{`air`}{2,016 rows: hourly NO2 at 6 monitors for 14 days around one stack
#'     (10 g/s, effective height 50 m). Columns `monitor`, `x`, `y`, `z`
#'     (metres from
#'     the stack), `hour`, `wind_from` (degrees), `wind_speed` (m/s),
#'     `stability`
#'     (Pasquill-Gifford class) and `no2` (micrograms per cubic metre): a diurnal
#'     background plus the stack's [gplume()] concentration at the
#'     monitor for that
#'     hour's wind.}
#'   \item{`hawkes`}{About 700 event times (`t`, in days, over 365 days) from a
#'     self-exciting process with a baseline of 0.9 events a day, branching ratio 0.55
#'     and an exponential kernel of rate 0.8 a day, simulated by thinning; `date` and
#'     `district` are added.}
#'   \item{`drift`}{3,000 rows: a reference and a current snapshot (`snapshot`)
#'   of 1,500
#'     rows each, with `age`, `income`, `region`, `visits` and
#'     `satisfied`. In the
#'     current snapshot age is 4 years older on average, income 16 percent higher, the
#'     North region larger and satisfaction lower; visits do not change.}
#'   \item{`waits`}{1,000 court cases: `case_id`, `court_type`, `days`
#'   to disposition
#'     (a gamma body with a heavy log-normal tail) and `appearances` (zero-inflated
#'     Poisson).}
#'   \item{`ledger`}{A proof ledger of 120 theorems (proved, sorry or axiom) covering
#'     the package's functions, written to a temporary JSON file and read back with
#'     [ldgrread()]; four theorems carry checks that
#'     [ldgrchk()] runs.}
#' }
#' @param name The dataset, one of the names `rmbldemo()` lists; `NULL` (the
#'   default)
#'   lists them.
#' @return A data frame; for `"ledger"` the ledger as
#'   [ldgrread()] returns it. With
#'   `name = NULL`, a data frame of `name`, `rows` and `description`.
#' @seealso [rmblapp()], whose tabs open on these datasets;
#'   [mksyncol()].
#' @examples
#' rmbldemo()
#' head(rmbldemo("court"))
#' identical(rmbldemo("survey"), rmbldemo("survey"))
#' @export
rmbldemo <- function(name = NULL) {
  tab <- .bl_demo_tab()
  if (is.null(name)) return(tab)
  name <- .rmbl_string1(name, "name")
  if (!name %in% tab$name) {
    stop("rmbldemo: `name` must be one of ", paste(tab$name, collapse = ", "), call. = FALSE)
  }
  .rmbl_local_seed(20261020L + match(name, tab$name))
  switch(name,
    court = .bl_demo_court(), offences = .bl_demo_offences(), offences_annual = .bl_demo_annual(),
    survey = .bl_demo_survey(), fnmi = .bl_demo_fnmi(), otis = .bl_demo_otis(), air = .bl_demo_air(),
    hawkes = .bl_demo_hawkes(), drift = .bl_demo_drift(), waits = .bl_demo_waits(), ledger = .bl_demo_ledger()
  )
}

#' The demonstration datasets: name, rows and a one-line description.
#' @return A data frame.
#' @noRd
.bl_demo_tab <- function() {
  data.frame(
    name = c("court", "offences", "offences_annual", "survey", "fnmi", "otis", "air", "hawkes", "drift",
             "waits", "ledger"),
    rows = c(576L, 1440L, 120L, 1200L, 128L, 144L, 2016L, NA, 3000L, 1000L, 120L),
    description = c(
      "Court caseload panel, 16 courts by 36 months, a staggered reform",
      "Monthly offence counts by area, seasonal, with a step down in April 2020",
      "The offence counts by area and year, with population",
      "Stratified two-stage survey with design and bootstrap replicate weights",
      "Published health table by distinction, suppressed cells and quality flags",
      "Custody admissions and days by institution and year (stock and flow)",
      "Hourly NO2 at six monitors around a stack, with the wind",
      "Self-exciting event stream over one year",
      "Two snapshots of one table, reference and current, with drift",
      "Days to disposition and appearances of 1,000 court cases",
      "Proof ledger of 120 theorems and the functions they cover"),
    stringsAsFactors = FALSE)
}

#' The court caseload panel.
#' @return A data frame.
#' @noRd
.bl_demo_court <- function() {
  courts <- sprintf("C%02d", 1:16)
  d <- data.frame(court = rep(courts, each = 36L), month = rep(1:36, 16L), stringsAsFactors = FALSE)
  ci <- match(d$court, courts)
  d$region <- c("Central", "East", "North", "West")[(ci - 1L) %% 4L + 1L]
  d$date <- seq(as.Date("2022-01-01"), by = "month", length.out = 36L)[d$month]
  d$refmonth <- c(13, 13, 19, 19, 25, 25, 31, 31, rep(NA, 8L))[ci]
  d$reformed <- as.integer(!is.na(d$refmonth) & d$month >= d$refmonth)
  size <- round(stats::runif(16L, 70, 180))[ci]
  season <- 1 + 0.12 * cos(2 * pi * (d$month - 2) / 12)
  d$received <- as.numeric(mksyncol(list(type = "poisson", lambda = size * season), nrow(d)))
  judges <- c(3, 4, 5, 6)[(ci - 1L) %% 4L + 1L]
  d$caseload <- round(d$received / judges, 1)
  d$disposed <- stats::rpois(nrow(d), d$received * (0.96 + 0.04 * d$reformed))
  d$pending <- stats::ave(d$received - d$disposed, d$court, FUN = function(z) pmax(0, 400 + cumsum(z)))
  d$clearance <- round(100 * d$disposed / d$received, 1)
  courtfe <- stats::rnorm(16L, 0, 6)[ci]
  d$delay <- round(90 + 0.3 * d$caseload + courtfe + 0.25 * d$month + 4 * (season - 1) / 0.12 -
                     12 * d$reformed + stats::rnorm(nrow(d), 0, 3), 1)
  d[, c("court", "region", "month", "date", "received", "disposed", "pending", "clearance", "caseload",
        "delay", "reformed", "refmonth")]
}

#' The monthly offence counts.
#' @return A data frame.
#' @noRd
.bl_demo_offences <- function() {
  areas <- c("Downtown", "Eastview", "Harbour", "Hillcrest", "Lakeside", "Northgate", "Riverside", "Southpark",
             "Uptown", "Westfield")
  dates <- seq(as.Date("2013-01-01"), by = "month", length.out = 144L)
  d <- data.frame(area = rep(areas, each = 144L), date = rep(dates, 10L), stringsAsFactors = FALSE)
  d$year <- as.integer(format(d$date, "%Y"))
  d$month <- as.integer(format(d$date, "%m"))
  ai <- match(d$area, areas)
  pop0 <- c(61000, 38000, 24000, 45000, 27000, 52000, 33000, 29000, 47000, 41000)[ai]
  d$pop <- round(pop0 * 1.01^(d$year - 2013))
  lvl <- d$pop / 1000 * c(1.6, 0.9, 2.2, 0.7, 1.2, 1.1, 1.0, 1.3, 1.5, 0.8)[ai]
  season <- 1 + 0.15 * cos(2 * pi * (d$month - 7) / 12)
  step <- ifelse(d$date >= as.Date("2020-04-01"), 0.72, 1)
  d$n <- as.numeric(mksyncol(list(type = "poisson", lambda = lvl * season * step), nrow(d)))
  d[, c("area", "year", "month", "date", "n", "pop")]
}

#' The offence counts by area and year.
#' @return A data frame.
#' @noRd
.bl_demo_annual <- function() {
  d <- .bl_demo_offences()
  a <- stats::aggregate(n ~ area + year, d, sum)
  a$pop <- stats::aggregate(pop ~ area + year, d, mean)$pop
  a[order(a$area, a$year), c("area", "year", "n", "pop")]
}

#' The stratified two-stage survey with replicate weights.
#' @return A data frame.
#' @noRd
.bl_demo_survey <- function() {
  n <- 1200L
  strata <- c("Central", "East", "North", "West")
  d <- data.frame(stratum = rep(strata, each = n / 4L), stringsAsFactors = FALSE)
  d$psu <- sprintf("%s%02d", substr(d$stratum, 1L, 1L), rep(rep(1:10, each = 30L), 4L))
  si <- match(d$stratum, strata)
  psufe <- stats::rnorm(40L, 0, 0.35)[match(d$psu, unique(d$psu))]
  d$w <- round(c(410, 260, 150, 320)[si] * stats::runif(n, 0.8, 1.25), 1)
  d$age <- round(pmin(90, pmax(18, stats::rnorm(n, 46, 16))))
  d$sex <- mksyncol(list(type = "bernoulli", p = 0.51, labels = c("Female", "Male")), n)
  d$smoker <- stats::rbinom(n, 1L, stats::plogis(-0.6 - 0.02 * (d$age - 46) + 0.3 * (si == 3L) + psufe))
  d$drinks <- as.numeric(mksyncol(list(type = "poisson", lambda = exp(0.9 + 0.35 * (d$sex == "Male") + psufe / 2)),
                                  n))
  d$victim <- stats::rbinom(n, 1L, stats::plogis(-2 + 0.5 * (si == 1L) - 0.015 * (d$age - 46) + psufe))
  d$trust <- as.integer(pmin(5, pmax(1, round(3.4 - 0.6 * d$victim + stats::rnorm(n, 0, 0.9)))))
  d$income <- round(stats::rlnorm(n, log(52000) + 0.004 * (d$age - 46), 0.55), -2)
  d$income[sample.int(n, 8L)] <- d$income[sample.int(n, 8L)] * 12
  d$income[sample.int(n, round(0.08 * n))] <- NA
  for (r in 1:20) {
    m <- numeric(n)
    for (h in strata) {
      p <- unique(d$psu[d$stratum == h])
      k <- tabulate(match(sample(p, length(p) - 1L, replace = TRUE), p), length(p))
      m[d$stratum == h] <- (length(p) / (length(p) - 1L) * k)[match(d$psu[d$stratum == h], p)]
    }
    d[[sprintf("rw%02d", r)]] <- round(d$w * m, 2)
  }
  d
}

#' The published table by distinction, with suppression and quality flags.
#' @return A data frame.
#' @noRd
.bl_demo_fnmi <- function() {
  ind <- c("Perceived mental health, very good or excellent", "Perceived health, very good or excellent",
           "Has a regular health care provider", "Daily smoker")
  grp <- c("First Nations", "M\u00e9tis", "Inuit", "Non-Indigenous")
  age <- c("Total, 18 years and over", "18 to 34 years", "35 to 54 years", "55 years and over")
  d <- expand.grid(age = age, indicator = ind, group = grp, period = c("2015/2018", "2019/2022"),
                   stringsAsFactors = FALSE)[, c("period", "group", "age", "indicator")]
  base <- c(64, 55, 80, 17)[match(d$indicator, ind)]
  gap <- c(-12, -7, -10, 0)[match(d$group, grp)] * c(1, 1, 0.8, -1.2)[match(d$indicator, ind)]
  agef <- c(0, 3, -1, -3)[match(d$age, age)]
  prd <- ifelse(d$period == "2019/2022", -5, 0) * (d$indicator == ind[1])
  d$estimate <- round(pmin(97, pmax(3, base + gap + agef + prd + stats::rnorm(nrow(d), 0, 1.2))), 1)
  nn <- c(3200, 2900, 250, 52000)[match(d$group, grp)] * ifelse(d$age == age[1], 1, 0.25)
  se <- 100 * sqrt(d$estimate / 100 * (1 - d$estimate / 100) / nn) * 2.5
  d$lower <- round(d$estimate - 1.96 * se, 1)
  d$upper <- round(d$estimate + 1.96 * se, 1)
  cv <- 100 * se / d$estimate
  # the package vocabulary: acceptable ("ok"), use with caution ("E"), suppressed ("F")
  d$quality <- as.character(cut(cv, c(-Inf, 16.6, 33.3, Inf), labels = c("ok", "E", "F")))
  sup <- d$quality == "F"
  d$estimate[sup] <- NA
  d$lower[sup] <- NA
  d$upper[sup] <- NA
  d
}

#' The custody admissions table.
#' @return A data frame.
#' @noRd
.bl_demo_otis <- function() {
  inst <- c("Algoma Centre", "Brant Jail", "Central East Centre", "Elgin Middlesex Centre", "Hamilton Centre",
            "Maplehurst Complex", "Monteith Complex", "Niagara Centre", "Ottawa Carleton Centre",
            "South West Centre", "Thunder Bay Jail", "Toronto South Centre")
  cd <- c("3557", "3529", "3516", "3539", "3525", "3524", "3556", "3526", "3506", "3537", "3558", "3520")
  reg <- c("North", "West", "Central", "West", "Central", "Central", "North", "West", "East", "West", "North",
           "Toronto")
  d <- data.frame(inst = rep(inst, each = 12L), year = rep(2013:2024, 12L), stringsAsFactors = FALSE)
  ii <- match(d$inst, inst)
  d$cd <- cd[ii]
  d$region <- reg[ii]
  base <- round(stats::runif(12L, 900, 5200))[ii]
  d$people <- as.numeric(mksyncol(list(type = "poisson", lambda = base * (1 - 0.02 * (d$year - 2013))), nrow(d)))
  alos <- exp(stats::rnorm(nrow(d), log(28) + 0.06 * pmax(0, d$year - 2019), 0.12))
  d$days <- round(d$people * alos)
  d$releases <- stats::rpois(nrow(d), d$people * 0.98)
  d[, c("inst", "cd", "region", "year", "people", "days", "releases")]
}

#' The hourly monitor series around a stack.
#' @return A data frame.
#' @noRd
.bl_demo_air <- function() {
  mon <- data.frame(monitor = c("M1 Harbour", "M2 School", "M3 Market", "M4 Park", "M5 Clinic", "M6 Depot"),
                    x = c(800, 1500, -600, 2500, 300, -1800), y = c(200, -400, 900, 700, -1200, -300), z = 0,
                    stringsAsFactors = FALSE)
  hours <- 0:335
  wind <- (240 + 50 * sin(2 * pi * hours / 96) + stats::rnorm(336L, 0, 20)) %% 360
  speed <- round(pmax(1, 4 + 1.5 * sin(2 * pi * hours / 24) + stats::rnorm(336L, 0, 0.8)), 1)
  hod <- hours %% 24
  stab <- ifelse(hod >= 10 & hod <= 16, "B", ifelse(hod >= 20 | hod <= 5, "E", "D"))
  d <- data.frame(monitor = rep(mon$monitor, each = 336L), hour = rep(hours, 6L), stringsAsFactors = FALSE)
  mi <- match(d$monitor, mon$monitor)
  d$x <- mon$x[mi]
  d$y <- mon$y[mi]
  d$z <- 0
  d$wind_from <- round(wind[d$hour + 1L])
  d$wind_speed <- speed[d$hour + 1L]
  d$stability <- stab[d$hour + 1L]
  # the wind blows from wind_from: downwind is the opposite bearing
  th <- (d$wind_from + 180) * pi / 180
  dw <- d$x * sin(th) + d$y * cos(th)
  cw <- d$x * cos(th) - d$y * sin(th)
  plume <- numeric(nrow(d))
  for (k in unique(d$stability)) {
    i <- which(d$stability == k & dw > 0)
    for (j in i) plume[j] <- gplume(10, d$wind_speed[j], 50, cbind(dw[j], cw[j], 0), stab = k)
  }
  bg <- 14 + 6 * cos(2 * pi * (d$hour %% 24 - 8) / 24)
  d$no2 <- round(bg + 1e6 * plume + stats::rnorm(nrow(d), 0, 1.5), 1)
  d
}

#' The self-exciting event stream, by thinning.
#' @return A data frame.
#' @noRd
.bl_demo_hawkes <- function() {
  mu <- 0.9
  br <- 0.55
  beta <- 0.8
  hor <- 365
  t <- numeric()
  s <- 0
  excite <- 0
  repeat {
    lam <- mu + excite
    w <- stats::rexp(1L, lam)
    excite <- excite * exp(-beta * w)
    s <- s + w
    if (s > hor) break
    if (stats::runif(1L) <= (mu + excite) / lam) {
      t <- c(t, s)
      excite <- excite + br * beta
    }
  }
  data.frame(t = round(t, 4), date = as.Date("2024-01-01") + floor(t),
             district = mksyncol(list(values = c("D11", "D12", "D14", "D22"), weights = c(4, 3, 2, 1)),
                                 length(t)),
             stringsAsFactors = FALSE)
}

#' The two snapshots, reference and current.
#' @return A data frame.
#' @noRd
.bl_demo_drift <- function() {
  one <- function(snap, age, inc, wreg, psat) {
    data.frame(snapshot = snap, age = round(pmax(18, stats::rnorm(1500L, age, 13))),
               income = round(stats::rlnorm(1500L, log(inc), 0.5), -2),
               region = mksyncol(list(values = c("Central", "East", "North", "West"), weights = wreg), 1500L),
               visits = as.numeric(mksyncol(list(type = "poisson", lambda = 3), 1500L)),
               satisfied = mksyncol(list(type = "bernoulli", p = psat, labels = c("yes", "no")), 1500L),
               stringsAsFactors = FALSE)
  }
  rbind(one("reference", 41, 50000, c(4, 3, 2, 3), 0.72), one("current", 45, 58000, c(4, 3, 4.5, 3), 0.6))
}

#' The court case processing times.
#' @return A data frame.
#' @noRd
.bl_demo_waits <- function() {
  n <- 1000L
  type <- mksyncol(list(values = c("Provincial", "Superior", "Youth"), weights = c(0.7, 0.2, 0.1)), n)
  tail <- stats::runif(n) < 0.08
  days <- ifelse(tail, stats::rlnorm(n, log(420), 0.45),
                 stats::rgamma(n, 1.8, 1.8 / c(Provincial = 120, Superior = 260, Youth = 90)[type]))
  zero <- stats::runif(n) < 0.25
  data.frame(case_id = mksyncol(list(type = "id_pattern", pattern = "case-{seq:05d}"), n), court_type = type,
             days = round(days, 1), appearances = ifelse(zero, 0, stats::rpois(n, 4)), stringsAsFactors = FALSE)
}

#' The proof ledger, written to a temporary file and read back.
#' @return A ldgrread() result.
#' @noRd
.bl_demo_ledger <- function() {
  fns <- c("ginicoef", "yoy", "rtcalc", "trndtst", "stepchg", "plndid", "evstudy", "svyest", "dstfit", "chwkfit",
           "gplume", "caseflow")
  st <- sample(c("proved", "sorry", "axiom"), 120L, replace = TRUE, prob = c(0.75, 0.15, 0.1))
  th <- lapply(seq_len(120L), function(i) {
    f <- fns[(i - 1L) %% length(fns) + 1L]
    x <- list(id = sprintf("thm-%03d", i), name = sprintf("Rmorie.%s.lemma_%03d", f, i),
              statement = sprintf("theorem lemma_%03d : %s_spec %d", i, f, i),
              file = sprintf("Rmorie/%s.lean", f), line = 10L + 7L * i, status = st[[i]],
              sorry_count = as.integer(st[[i]] == "sorry"),
              covers = if (st[[i]] == "axiom") list() else
                list(list(package = "rmoriebricklayer", `function` = f, language = "R")))
    if (i <= 4L) {
      x$status <- "proved"
      x$sorry_count <- 0L
      x$covers <- list(list(package = "rmoriebricklayer", `function` = "ginicoef", language = "R"))
      x$check <- list(expr = sprintf("ginicoef(rep(%d, 5))", i), expect = 0, tol = 1e-12)
    }
    x
  })
  led <- list(name = "rmoriebricklayer demo ledger",
              toolchain = list(lean = "v4.12.0", mathlib = "v4.12.0", lake = "5.0.0"),
              source = list(repo = "https://github.com/rootcoder007/rmorie-proofs",
                            commit = "0123456789abcdef0123456789abcdef01234567", built_utc = "2026-10-20T12:00:00Z",
                            build_digest = "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08"),
              theorems = th)
  f <- tempfile("rmbl-demo-ledger-", fileext = ".json")
  writeLines(tojs(led, auto_unbox = TRUE), f)
  ldgrread(f)
}
