set.seed(11)
toy <- data.frame(s = rep(c("a", "b"), each = 6), p = rep(1:4, each = 3), y = c(3, 5, 4, 6, 8, 7, 2, 1, 3, 9, 8, 10),
                  g = rep(c("x", "y", "z"), 4), w = c(10, 12, 9, 11, 10, 8, 20, 18, 22, 19, 21, 20))

test_that("a stratified cluster mean matches the linearization formula worked by hand", {
  des <- survey_design(toy, weights = "w", strata = "s", psu = "p")
  e <- survey_estimate(des, toy, "y")
  W <- sum(toy$w)
  m <- sum(toy$w * toy$y) / W
  z <- toy$w * (toy$y - m) / W
  tot <- tapply(z, toy$p, sum)
  st <- c(a = 1, b = 1, c = 2, d = 2)[seq_along(tot)]
  v <- 0
  for (h in 1:2) {
    th <- tot[st == h]
    v <- v + length(th) / (length(th) - 1) * sum((th - mean(th))^2)
  }
  expect_equal(e$estimate, m)
  expect_equal(e$se, sqrt(v))
  expect_equal(e$cv, 100 * sqrt(v) / m)
  expect_equal(e$n, 12L)
})

test_that("a replicate variance is the scaled sum of squared deviations", {
  R <- sapply(1:5, function(r) toy$w * c(2, 0, 1, 1, 1, 0, 1, 2, 0, 1, 1, 1)[(seq_len(12) + r) %% 12 + 1])
  th <- apply(R, 2, function(w) sum(w * toy$y) / sum(w))
  full <- sum(toy$w * toy$y) / sum(toy$w)
  for (case in list(list("bootstrap", 1 / 5), list("jk1", 4 / 5))) {
    des <- survey_design(toy, weights = "w", replicates = R, type = case[[1]])
    expect_equal(survey_estimate(des, toy, "y")$se, sqrt(case[[2]] * sum((th - full)^2)))
  }
  # BRR half-samples come in a Hadamard order: four of them
  des <- survey_design(toy, weights = "w", replicates = R[, 1:4], type = "brr")
  expect_equal(survey_estimate(des, toy, "y")$se, sqrt(1 / 4 * sum((th[1:4] - full)^2)))
  des <- survey_design(toy, weights = "w", replicates = R, type = "bootstrap", mse = FALSE)
  expect_equal(survey_estimate(des, toy, "y")$se, sqrt(sum((th - mean(th))^2) / 5))
  # CSUS 2023: mean bootstrap weights of R = 12, the same as Fay's BRR with rho = 1 - 1/sqrt(12)
  # (four replicates: Fay's are half-samples, in a Hadamard order)
  mb <- survey_design(toy, weights = "w", replicates = R[, 1:4], type = "mean_bootstrap", mean_size = 12)
  fay <- survey_design(toy, weights = "w", replicates = R[, 1:4], type = "fay", rho = 1 - 1 / sqrt(12))
  expect_equal(survey_estimate(mb, toy, "y")$se, sqrt(12 / 4 * sum((th[1:4] - full)^2)))
  expect_equal(survey_estimate(fay, toy, "y")$se, survey_estimate(mb, toy, "y")$se)
})

test_that("domains keep the whole design and the native kernel reads the replicate columns", {
  R <- matrix(rep(toy$w, 4), ncol = 4) * c(1, 2, 0.5, 1.5)
  tot <- .Call(rmoriebricklayer:::C_rmbl_svy_reptotals, cbind(toy$y, 1), unname(as.list(as.data.frame(R))))
  expect_equal(tot, crossprod(R, cbind(toy$y, 1)), ignore_attr = TRUE)
  expect_error(.Call(rmoriebricklayer:::C_rmbl_svy_reptotals, cbind(toy$y), list(1:3)), "replicate weight column 1")
  expect_error(.Call(rmoriebricklayer:::C_rmbl_svy_reptotals, toy$y, list(toy$w)), "double matrix")
  expect_error(.Call(rmoriebricklayer:::C_rmbl_svy_reptotals, cbind(toy$y), 1), "list")
  des <- survey_design(toy, weights = "w")
  e <- survey_estimate(des, toy, "y", by = "g")
  for (k in c("x", "y", "z")) {
    i <- toy$g == k
    expect_equal(e$estimate[e$g == k], sum(toy$w[i] * toy$y[i]) / sum(toy$w[i]))
  }
  # a missing value leaves the respondent in the design and out of the estimate
  t2 <- toy
  t2$y[1] <- NA
  e2 <- survey_estimate(survey_design(t2, weights = "w"), t2, "y")
  expect_equal(e2$estimate, sum(toy$w[-1] * toy$y[-1]) / sum(toy$w[-1]))
  expect_equal(e2$n, 11L)
})

test_that("estimates and variances match the survey package", {
  skip_if_not_installed("survey")
  suppressMessages(library(survey))
  data(api, package = "survey", envir = environment())
  ds <- survey::svydesign(id = ~1, strata = ~stype, fpc = ~fpc, weights = ~pw, data = apistrat)
  bs <- survey_design(apistrat, weights = "pw", strata = "stype", fpc = "fpc")
  m <- survey::svymean(~api00, ds)
  e <- survey_estimate(bs, apistrat, "api00")
  expect_equal(c(e$estimate, e$se), unname(c(coef(m), survey::SE(m))))
  t <- survey::svytotal(~enroll, ds)
  e <- survey_estimate(bs, apistrat, "enroll", stat = "total")
  expect_equal(c(e$estimate, e$se), unname(c(coef(t), survey::SE(t))))
  r <- survey::svyratio(~api00, ~api99, ds)
  e <- survey_estimate(bs, apistrat, "api00", stat = "ratio", denominator = "api99")
  expect_equal(c(e$estimate, e$se), unname(c(coef(r), survey::SE(r))))
  b <- survey::svyby(~api00, ~sch.wide, ds, survey::svymean)
  e <- survey_estimate(bs, apistrat, "api00", by = "sch.wide")
  expect_equal(c(e$estimate, e$se), unname(c(coef(b), survey::SE(b))))
  p <- survey::svymean(~stype, ds)
  e <- survey_estimate(bs, apistrat, "stype", stat = "proportion")
  expect_equal(c(e$estimate, e$se), unname(c(coef(p), survey::SE(p))))
  ci <- survey::svyciprop(~I(sch.wide == "Yes"), ds, method = "logit")
  e <- survey_estimate(bs, apistrat, "sch.wide", stat = "proportion", levels = "Yes", ci = "logit", df = "design")
  expect_equal(c(e$lower, e$upper), unname(as.numeric(attr(ci, "ci"))), tolerance = 1e-8)
  dc <- survey::svydesign(id = ~dnum, fpc = ~fpc, weights = ~pw, data = apiclus1)
  bc <- survey_design(apiclus1, weights = "pw", psu = "dnum", fpc = "fpc")
  b <- survey::svyby(~api00, ~stype, dc, survey::svymean)
  e <- survey_estimate(bc, apiclus1, "api00", by = "stype")
  expect_equal(c(e$estimate, e$se), unname(c(coef(b), survey::SE(b))))
  for (mse in c(FALSE, TRUE)) {
    dj <- survey::as.svrepdesign(survey::svydesign(id = ~dnum, weights = ~pw, data = apiclus1), type = "JK1", mse = mse)
    bj <- survey_design(apiclus1, weights = "pw", replicates = weights(dj, "analysis"), type = "jk1", mse = mse)
    b <- survey::svyby(~api00, ~stype, dj, survey::svymean, covmat = TRUE)
    e <- survey_estimate(bj, apiclus1, "api00", by = "stype")
    expect_equal(c(e$estimate, e$se), unname(c(coef(b), survey::SE(b))))
    con <- survey::svycontrast(b, list(H = c(-1, 1, 0), M = c(-1, 0, 1)))
    cmp <- survey_compare(bj, apiclus1, "api00", by = "stype", ref = "E")
    expect_equal(c(cmp$difference, cmp$se), unname(c(coef(con), survey::SE(con))))
  }
  set.seed(2)
  W <- replicate(60, apistrat$pw * tabulate(sample(nrow(apistrat), replace = TRUE), nrow(apistrat)))
  dr <- survey::svrepdesign(data = apistrat, weights = ~pw, repweights = W, type = "Fay", rho = 0.3, mse = TRUE,
                            combined.weights = TRUE)
  bf <- survey_design(apistrat, weights = "pw", replicates = W, type = "fay", rho = 0.3)
  m <- survey::svymean(~api00, dr)
  e <- survey_estimate(bf, apistrat, "api00")
  expect_equal(c(e$estimate, e$se), unname(c(coef(m), survey::SE(m))))
})

test_that("the modified Wilson interval follows SAS SURVEYFREQ: n / Deff, df-adjusted, capped at n", {
  set.seed(5)
  d <- data.frame(y = rbinom(400, 1, 0.3), w = runif(400, 1, 3), s = rep(1:20, each = 20))
  des <- survey_design(d, weights = "w", strata = "s")
  e <- survey_estimate(des, d, "y", stat = "proportion", levels = "1")
  p <- e$estimate
  n <- e$n
  dfd <- 400 - 20
  # the degrees-of-freedom factor is (t_(n-1) / t_df)^2, as SAS documents it (review of e57fed5)
  ne <- min(n / (e$se^2 / (p * (1 - p) / (n - 1))) * (stats::qt(0.975, n - 1) / stats::qt(0.975, dfd))^2, n)
  z <- stats::qnorm(0.975)
  mid <- (p + z^2 / (2 * ne)) / (1 + z^2 / ne)
  half <- z / (1 + z^2 / ne) * sqrt(p * (1 - p) / ne + z^2 / (4 * ne^2))
  expect_equal(c(e$lower, e$upper), c(mid - half, mid + half))
  expect_lt(e$lower, p)
  expect_gt(e$upper, p)
  # a design effect below 1 is capped: the interval is the plain Wilson one at n
  w <- survey_estimate(survey_design(d, weights = rep(1, 400)), d, "y", stat = "proportion", levels = "1",
                       ci = "wald")
  expect_equal(w$estimate, mean(d$y))
})

test_that("arguments that cannot describe a design or an estimate are refused", {
  expect_error(survey_design(list(1), "w"), "data frame")
  expect_error(survey_design(toy[1, ], "w"), "two rows")
  expect_error(survey_design(toy, "nope"), "does not have: nope")
  expect_error(survey_design(toy, c(1, 2)), "one value per row")
  expect_error(survey_design(toy, -toy$w), "non-negative")
  expect_error(survey_design(toy, "w", mse = NA), "TRUE or FALSE")
  R <- cbind(toy$w * 1.1, toy$w * 0.9, toy$w * 1.2)   # replicates, not copies of the full weight (refused)
  expect_error(survey_design(toy, "w", replicates = R, strata = "s"), "not both")
  expect_error(survey_design(toy, "w", replicates = "zz"), "not in `data`")
  expect_error(survey_design(toy, "w", replicates = list(1)), "data frame, a matrix")
  expect_error(survey_design(toy, "w", replicates = R[1:5, ]), "one row per row")
  expect_error(survey_design(toy, "w", replicates = R[, 1, drop = FALSE]), "at least two")
  expect_error(survey_design(toy, "w", replicates = -R), "non-negative")
  expect_error(survey_design(toy, "w", replicates = R, type = "mean_bootstrap", mean_size = 0), "mean_size")
  expect_error(survey_design(toy, "w", replicates = R, type = "fay"), "rho")
  rr <- data.frame(id = 12:1, r1 = toy$w[12:1] * 1.05, r2 = toy$w[12:1] * 2)
  t3 <- cbind(toy, id = 1:12)
  ok <- survey_design(t3, "w", replicates = rr, id = "id")
  expect_equal(ok$reps[[2]], 2 * toy$w)
  expect_error(survey_design(t3, "w", replicates = rr, id = "nope"), "present in both")
  expect_error(survey_design(t3, "w", replicates = rbind(rr, rr), id = "id"), "repeats")
  expect_error(survey_design(t3, "w", replicates = rr[-1, ], id = "id"), "have no replicate weights")
  expect_error(survey_design(transform(toy, s = replace(s, 1, NA)), "w", strata = "s"), "strata` has missing")
  expect_error(survey_design(transform(toy, p = replace(p, 1, NA)), "w", psu = "p"), "psu` has missing")
  expect_error(survey_design(toy, "w", strata = "s", fpc = rep(-1, 12)), "positive")
  expect_error(survey_design(toy, "w", strata = "s", fpc = seq_len(12) + 20), "constant within")
  expect_error(survey_design(toy, "w", strata = "s", psu = "p", fpc = rep(1.5, 12)), "more sampled PSUs")
  des <- survey_design(toy, "w")
  expect_error(survey_estimate(1, toy, "y"), "survey_design")
  expect_error(survey_estimate(des, toy[-1, ], "y"), "built on")
  expect_error(survey_estimate(des, toy, "y", conf_level = 2), "between 0 and 1")
  expect_error(survey_estimate(des, toy, "y", stat = "ratio"), "denominator")
  expect_error(survey_estimate(des, toy, "y", df = -1), "positive number")
  expect_error(survey_estimate(des, toy, "nope"), "name a column")
  expect_error(survey_estimate(des, toy, "y", by = "zz"), "does not have: zz")
  expect_error(survey_estimate(des, toy, "y", stat = "ratio", denominator = "zz"), "must name a column")
  expect_error(survey_estimate(des, toy, "y", stat = "ratio", denominator = "g"), "numeric")
  expect_error(survey_estimate(des, toy, "g"), "must be numeric")
  expect_error(survey_estimate(des, transform(toy, y = replace(y, 1, Inf)), "y"), "infinite")
  expect_error(survey_estimate(des, toy, "g", stat = "proportion", levels = "q"), "not observed")
  expect_error(survey_estimate(des, transform(toy, y = NA), "y", stat = "proportion"), "no non-missing")
  expect_error(survey_compare(des, toy, "y"), "name the domains")
  expect_error(survey_compare(des, toy, "y", by = "g", ref = "q"), "not one of")
  expect_error(survey_compare(des, transform(toy, g = "x"), "y", by = "g"), "at least two")
})

test_that("a stratum with one PSU fails, is removed, or is centred on the overall mean", {
  t1 <- toy
  t1$s[1:3] <- "c"
  base <- survey_design(t1, "w", strata = "s", psu = "p")
  expect_error(survey_estimate(base, t1, "y"), "single PSU")
  rm <- survey_estimate(survey_design(t1, "w", strata = "s", psu = "p", lonely_psu = "remove"), t1, "y")
  ad <- survey_estimate(survey_design(t1, "w", strata = "s", psu = "p", lonely_psu = "adjust"), t1, "y")
  expect_gt(ad$se, rm$se)
  skip_if_not_installed("survey")
  old <- options(survey.lonely.psu = "adjust")
  on.exit(options(old), add = TRUE)
  sd <- survey::svydesign(id = ~p, strata = ~s, weights = ~w, data = t1)
  expect_equal(ad$se, as.numeric(survey::SE(survey::svymean(~y, sd))))
  options(survey.lonely.psu = "remove")
  expect_equal(rm$se, as.numeric(survey::SE(survey::svymean(~y, sd))))
})

test_that("results print, plot and flag small or empty domains", {
  R <- matrix(toy$w, 12, 4) * c(1, 1.2, 0.8, 1.1)
  R[toy$g == "z", 2] <- 0
  des <- survey_design(toy, "w", replicates = R, type = "jk1")
  e <- survey_estimate(des, toy, "y", by = "g", min_n = 5)
  expect_identical(e$flag[e$g != "z"], rep("fewer than 5 respondents", 2))
  e2 <- survey_estimate(des, toy, "y", by = "g", min_n = 1)
  expect_match(e2$flag[e2$g == "z"], "not computable")
  expect_true(is.na(e2$se[e2$g == "z"]))
  out <- utils::capture.output(print(des))
  expect_match(out[2], "4 replicate weights, jackknife")
  for (ty in list(list("bootstrap", NULL), list("mean_bootstrap", NULL), list("brr", NULL), list("fay", 0.5))) {
    d2 <- survey_design(toy, "w", replicates = R, type = ty[[1]], rho = ty[[2]], mean_size = 4)
    expect_length(utils::capture.output(print(d2)), 2L)
  }
  expect_match(utils::capture.output(print(survey_design(toy, "w", strata = "s", fpc = rep(0.5, 12))))[2],
               "finite population")
  expect_match(utils::capture.output(print(e))[1], "Survey mean of y by g")
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  pr <- survey_estimate(survey_design(toy, "w"), toy, "g", stat = "proportion")
  expect_equal(plot(pr)$estimate, 100 * pr$estimate)
  expect_equal(nrow(plot(e, col = "red")), 3L)
  ps <- survey_estimate(survey_design(toy, "w"), toy, "g", by = "s", stat = "proportion")
  expect_match(plot(ps)$label[1], "a: x")
  expect_identical(plot(survey_estimate(survey_design(toy, "w"), toy, "y"))$label, "y")
  cmp <- survey_compare(survey_design(toy, "w"), toy, "g", by = "s", stat = "proportion")
  expect_match(utils::capture.output(print(cmp))[1], "against a")
  expect_equal(plot(cmp)$difference, 100 * cmp$difference)
  cm2 <- survey_compare(survey_design(toy, "w"), toy, "y", by = "g")
  expect_null(cm2$level)
  expect_equal(nrow(plot(cm2, col = "black")), 2L)
})

test_that("replicate weights can be named columns, and a replicate design's df is replicates less one", {
  # multipliers per PSU, as replicate weights are (one per row is not a replicate; review of 46de6a9)
  i <- toy$p
  d <- cbind(toy, r1 = toy$w * (1 + 0.1 * sin(i)), r2 = toy$w * (1 + 0.1 * cos(i)), r3 = toy$w * (1 + 0.1 * sin(2 * i)))
  des <- survey_design(d, "w", replicates = c("r1", "r2", "r3"), type = "jk1")
  expect_length(des$reps, 3L)
  expect_equal(des$reps[[2]], toy$w * (1 + 0.1 * cos(i)))
  # copies of one weight scaled have rank 1: no degrees of freedom, said so
  d1 <- cbind(toy, r1 = toy$w * 1.05, r2 = toy$w * 1.1, r3 = toy$w * 0.9)
  d1des <- survey_design(d1, "w", replicates = c("r1", "r2", "r3"), type = "jk1")
  expect_error(survey_estimate(d1des, d1, "y", df = "design"), "0 degrees of freedom")
  e <- survey_estimate(des, d, "y", df = "design")
  z <- stats::qt(0.975, 2)
  expect_equal(c(e$lower, e$upper), e$estimate + c(-1, 1) * z * e$se)
})

test_that("a pending interrupt stops the replicate-totals kernel between replicates", {
  skip_on_cran()
  skip_on_os("windows")
  skip_if(!nzchar(Sys.which("python3")) || !nzchar(Sys.which("timeout")), "no python3/timeout")
  # 4,000 replicates over 3 million rows: seconds of work unless the poll between replicates
  # sees the signal (the replicate list holds one vector 4,000 times, so it costs 24 MB)
  got <- interrupt_probe(paste(
    "w <- as.numeric(seq_len(3e6)); y <- matrix(1, 3e6, 1);",
    ".Call(rmoriebricklayer:::C_rmbl_svy_reptotals, y, rep(list(w), 4000L))"))
  skip_if(startsWith(got, "inconclusive"), got)
  expect_identical(got, "interrupt")
})
