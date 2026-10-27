# battery: runs in CI and locally; CRAN runs the correctness core
testthat::skip_on_cran()
# Mental health and wellbeing methods: each against an exact reference

test_that(
  paste0(
    "scests() puts each estimate beside its limits, cell by cell and ",
    "measure by measure"
  ),
  {
    d <- data.frame(
      REF_DATE = "2022",
      GEO = "Canada",
      `Indigenous identity` = rep(c("First Nations ", "Metis"), each = 5),
      Statistics = rep(
        c(
          "Percent",
          "Low 95% confidence interval",
          "High 95% confidence interval",
          "Number of persons",
          "Low 95% confidence interval, number of persons"
        ),
        2
      ),
      UOM = rep(c("Percent", "Percent", "Percent", "Persons", "Persons"), 2),
      VALUE = c(47.1, 45.2, 49.0, 1000, 900, 50.3, 48.1, 52.5, 800, 700),
      STATUS = c("", "", "", "", "", "F", "", "", "", ""),
      check.names = FALSE,
      stringsAsFactors = FALSE
    )
    e <- scests(d)
    p <- e[e$measure == "Percent", ]
    expect_identical(p[["Indigenous identity"]], c("First Nations", "Metis"))
    expect_identical(p$estimate, c(47.1, NA))
    expect_identical(p$lower, c(45.2, NA))
    expect_identical(p$upper, c(49.0, NA))
    expect_identical(p$cisou, c("published", NA))
    expect_identical(as.character(p$quality), c("ok", "F"))
    n <- e[e$measure == "Number of persons", ]
    expect_identical(n$estimate, c(1000, 800))
    # a lower limit published without its upper is kept, and the pair is not
    # called published
    expect_identical(n$lower, c(900, 700))
    expect_identical(n$upper, c(NA_real_, NA_real_))
    expect_identical(n$cisou, c(NA_character_, NA_character_))
    expect_identical(attr(e, "conflvl"), 0.95)
    d3 <- d[c(1:3, 1), ]
    expect_error(scests(d3), "two estimates for one cell")
    # one place name, two geographies: told apart by DGUID, not merged
    dg <- data.frame(
      GEO = "Division No.  1",
      DGUID = c("2021A00031001", "2021A00034601"),
      Statistics = "Count",
      VALUE = c(10, 20),
      STATUS = "",
      stringsAsFactors = FALSE
    )
    eg <- scests(dg)
    expect_identical(eg$DGUID, c("2021A00031001", "2021A00034601"))
    expect_identical(eg$estimate, c(10, 20))
  }
)

test_that(
  paste0(
    "scests(): coefficients of variation, standard errors, and limits named ",
    "in every form"
  ),
  {
    z <- stats::qnorm(0.975)
    cv <- scests(data.frame(
      GEO = "Canada",
      Characteristics = c("Rate", "Coefficient of variation for rate"),
      VALUE = c(12.5, 8),
      STATUS = "",
      stringsAsFactors = FALSE
    ))
    expect_identical(cv$lower, 12.5 * exp(-z * sqrt(log(1 + 0.08^2))))
    expect_identical(cv$upper, 12.5 * exp(z * sqrt(log(1 + 0.08^2))))
    expect_identical(cv$cisou, "cv")
    se <- scests(data.frame(
      GEO = "A",
      Statistics = c("Average score", "Standard error"),
      VALUE = c(250, 2),
      STATUS = "",
      stringsAsFactors = FALSE
    ))
    expect_identical(se$upper, 250 + z * 2)
    expect_identical(se$cisou, "se")
    ct <- scests(data.frame(
      GEO = "A",
      Statistics = c(
        "Count",
        "Confidence interval lower bound of count",
        "Confidence interval upper bound of count"
      ),
      VALUE = c(100, 80, 120),
      STATUS = "",
      stringsAsFactors = FALSE
    ))
    expect_identical(c(ct$lower, ct$upper), c(80, 120))
    yr <- scests(data.frame(
      GEO = "A",
      Statistics = c(
        "2015",
        "2020",
        "95% confidence interval lower bound, 2015",
        "95% confidence interval upper bound, 2020"
      ),
      VALUE = c(10, 20, 8, 23),
      STATUS = "",
      stringsAsFactors = FALSE
    ))
    expect_identical(yr$lower, c(8, NA))
    expect_identical(yr$upper, c(NA, 23))
    lim <- scests(data.frame(
      GEO = "A",
      Statistics = c(
        "Percentage",
        "95% confidence interval (lower limit)",
        "95% confidence interval (upper limit)"
      ),
      VALUE = c(30, 25, 35),
      STATUS = "",
      stringsAsFactors = FALSE
    ))
    expect_identical(c(lim$lower, lim$upper), c(25, 35))
    # a name that fits three measures: the one whose estimates the limits
    # contain
    py <- data.frame(
      GEO = rep(c("A", "B"), each = 5),
      Characteristics = rep(
        c(
          "Number of potential years of life lost",
          "Crude rate of potential years of life lost",
          "Age-standardized rate of potential years of life lost",
          "Low 95% confidence interval, potential years of life lost",
          "High 95% confidence interval, potential years of life lost"
        ),
        2
      ),
      VALUE = c(5000, 900, 1100, 1000, 1200, 7000, 800, 950, 870, 1030),
      STATUS = "",
      stringsAsFactors = FALSE
    )
    pe <- scests(py)
    asr <- pe[
      pe$measure == "Age-standardized rate of potential years of life lost",
    ]
    expect_identical(asr$lower, c(1000, 870))
    expect_true(all(is.na(pe$lower[
      pe$measure != "Age-standardized rate of potential years of life lost"
    ])))
    expect_identical(attr(pe, "unmatched"), character())
    # one cell in 200 whose published limits miss its estimate: the match holds,
    # and the cell is marked
    many <- do.call(
      rbind,
      lapply(seq_len(200), function(i) {
        transform(py[1:5, ], GEO = paste0("R", i))
      })
    )
    many$VALUE[many$GEO == "R7"][3] <- 1300
    me <- scests(many)
    ma <- me[
      me$measure == "Age-standardized rate of potential years of life lost",
    ]
    expect_identical(attr(me, "unmatched"), character())
    expect_identical(ma$cisou[ma$GEO == "R7"], "inconsistent")
    expect_identical(sum(ma$cisou == "published"), 199L)
    # a limit no single measure fits is said, not guessed
    amb <- scests(data.frame(
      GEO = "A",
      Statistics = c("Men", "Women", "Low 95% confidence interval"),
      VALUE = c(10, 12, 5),
      STATUS = "",
      stringsAsFactors = FALSE
    ))
    expect_identical(attr(amb, "unmatched"), "Low 95% confidence interval")
    # no statistics column: every value its own estimate, with no limits
    nc <- scests(data.frame(
      GEO = c("A", "B"),
      Gender = "Total",
      UOM = "Number",
      VALUE = c(5, 6),
      STATUS = "",
      stringsAsFactors = FALSE
    ))
    expect_identical(nc$estimate, c(5, 6))
    expect_identical(nc$measure, c("Number", "Number"))
    expect_true(all(is.na(nc$lower)))
  }
)

# shares and Wald limits that imply an effective sample size of exactly n
.wald <- function(p, n) {
  z <- stats::qnorm(0.975)
  s <- sqrt(p * (1 - p) / n)
  list(lo = 100 * (p - z * s), hi = 100 * (p + z * s))
}

test_that(
  paste0(
    "ordcmp(): the probability of a higher rating, brute force over every ",
    "pair"
  ),
  {
    lv <- c("poor", "fair", "good", "excellent")
    p1 <- c(0.1, 0.2, 0.3, 0.4)
    p0 <- c(0.25, 0.25, 0.3, 0.2)
    w1 <- .wald(p1, 400)
    w0 <- .wald(p0, 900)
    d <- data.frame(
      g = rep(c("A", "R"), each = 4),
      cat = rep(lv, 2),
      pct = 100 * c(p1, p0),
      lo = c(w1$lo, w0$lo),
      hi = c(w1$hi, w0$hi),
      stringsAsFactors = FALSE
    )
    d <- rbind(
      d,
      data.frame(
        g = "A",
        cat = "not specified",
        pct = 3,
        lo = 2,
        hi = 4,
        stringsAsFactors = FALSE
      )
    )
    r <- ordcmp(d, "g", "cat", "pct", "lo", "hi", lvls = lv, ref = "R")
    x <- rep(1:4, 100 * p1)
    y <- rep(1:4, 100 * p0)
    cmp <- outer(x, y, function(a, b) (a > b) + 0.5 * (a == b))
    expect_equal(
      r$probbet,
      mean(cmp),
      tolerance = testthat::testthat_tolerance()
    )
    expect_equal(
      r$delta,
      2 * mean(cmp) - 1,
      tolerance = testthat::testthat_tolerance()
    )
    expect_equal(r$neff, 400, tolerance = testthat::testthat_tolerance())
    expect_equal(r$neffref, 900, tolerance = testthat::testthat_tolerance())
    # the U-statistic variance from the placements of each sample in the other
    v <- mean((rowMeans(cmp) - mean(cmp))^2) /
      400 +
      mean((colMeans(cmp) - mean(cmp))^2) / 900
    sl <- sqrt(v) / (mean(cmp) * (1 - mean(cmp)))
    expect_equal(
      r$upper,
      stats::plogis(stats::qlogis(mean(cmp)) + stats::qnorm(0.975) * sl),
      tolerance = testthat::testthat_tolerance()
    )
    expect_identical(dim(attr(r, "shares")), c(2L, 4L))
    # identical distributions: one half, interval about it
    d2 <- d[d$cat %in% lv, ]
    d2[d2$g == "A", c("pct", "lo", "hi")] <- d2[
      d2$g == "R",
      c("pct", "lo", "hi")
    ]
    r2 <- ordcmp(d2, "g", "cat", "pct", "lo", "hi", lvls = lv, ref = "R")
    expect_equal(r2$probbet, 0.5)
    expect_lt(r2$lower, 0.5)
    expect_gt(r2$upper, 0.5)
  }
)

test_that("ordcmp(): the interval covers at its level over simulated surveys", {
  lv <- c("1", "2", "3", "4")
  p1 <- c(0.15, 0.3, 0.35, 0.2)
  p0 <- c(0.2, 0.3, 0.3, 0.2)
  x <- rep(1:4, 1e3 * p1)
  y <- rep(1:4, 1e3 * p0)
  truth <- mean(outer(x, y, function(a, b) (a > b) + 0.5 * (a == b)))
  withr::local_seed(11)
  hit <- vapply(
    seq_len(600),
    function(i) {
      c1 <- tabulate(sample(4, 500, TRUE, p1), 4) / 500
      c0 <- tabulate(sample(4, 700, TRUE, p0), 4) / 700
      w1 <- .wald(c1, 500)
      w0 <- .wald(c0, 700)
      d <- data.frame(
        g = rep(c("A", "R"), each = 4),
        cat = rep(lv, 2),
        pct = 100 * c(c1, c0),
        lo = c(w1$lo, w0$lo),
        hi = c(w1$hi, w0$hi),
        stringsAsFactors = FALSE
      )
      r <- ordcmp(d, "g", "cat", "pct", "lo", "hi", lvls = lv, ref = "R")
      r$lower <= truth && truth <= r$upper
    },
    NA
  )
  expect_gt(mean(hit), 0.92)
  expect_lt(mean(hit), 0.98)
})

test_that("ordcmp(): suppressed categories, caution and bad arguments", {
  lv <- c("low", "high")
  d <- data.frame(
    g = rep(c("A", "B", "R"), each = 2),
    cat = rep(lv, 3),
    pct = c(40, 60, 30, 70, 50, 50),
    lo = c(35, 55, 25, 65, 45, 45),
    hi = c(45, 65, 35, 75, 55, 55),
    q = c("", "", "F", "", "", "E"),
    stringsAsFactors = FALSE
  )
  r <- ordcmp(
    d,
    "g",
    "cat",
    "pct",
    "lo",
    "hi",
    lvls = lv,
    ref = "R",
    qual = "q"
  )
  expect_true(is.na(r$probbet[r$group == "B"]))
  expect_true(all(r$usewithcau))
  expect_error(
    ordcmp(d, "g", "cat", "pct", "lo", "hi", lvls = "low", ref = "R"),
    "two or more"
  )
  expect_error(
    ordcmp(d, "g", "cat", "pct", "lo", "hi", lvls = lv, ref = "Z"),
    "is not a group"
  )
  expect_error(
    ordcmp(d, "g", "cat", "pct", "lo", "hi", lvls = c("x", "y"), ref = "R"),
    "no row of `data`"
  )
  d$q[5] <- "x"
  expect_error(
    ordcmp(d, "g", "cat", "pct", "lo", "hi", lvls = lv, ref = "R", qual = "q"),
    "reference group's distribution"
  )
  expect_error(
    ordcmp(
      rbind(d, d[1, ]),
      "g",
      "cat",
      "pct",
      "lo",
      "hi",
      lvls = lv,
      ref = "A"
    ),
    "has a category twice"
  )
})

test_that("stdprev(): weighted mean and the root of the weighted variances", {
  z <- stats::qnorm(0.975)
  r <- stdprev(c(6, 4, 2), c(5, 3, 1), c(7, 5, 3), std = c(2, 1, 1))
  expect_identical(r$estimate, sum(c(0.5, 0.25, 0.25) * c(6, 4, 2)))
  expect_identical(r$se, sqrt(sum(c(0.5, 0.25, 0.25)^2 * (1 / z)^2)))
  expect_identical(r$upper, r$estimate + z * r$se)
  r2 <- stdprev(
    c(6, 4, 2, 5, 5, 5),
    c(5, 3, 1, 4, 4, 4),
    c(7, 5, 3, 6, 6, 6),
    std = c(1, 1, 1),
    grp = rep(c("a", "b"), each = 3),
    qual = c("", "x", "", "E", "", "")
  )
  expect_true(is.na(r2$estimate[1]))
  expect_true(r2$usewithcau[2])
  expect_identical(r2$estimate[2], 5)
  expect_warning(
    {
      r3 <- stdprev(1, 2, 3, 1)
    },
    "do not contain their estimate"
  )
  expect_true(is.na(r3$estimate))
  expect_error(
    stdprev(c(1, 2), c(0, 1), c(2, 3), c(1, 1, 1)),
    "has 2 age groups"
  )
  expect_error(stdprev(c(1, 2), c(0, 1), 3, c(1, 1)), "same length")
  expect_error(stdprev(1, 0, 2, 1, qual = c("", "")), "one flag per row")
})

.wb <- function() {
  data.frame(
    group = rep(c("First Nations", "Metis"), each = 4),
    indicator = rep(c("Hopeful", "Total", "Distress", "Satisfied"), 2),
    pct = c(60, 100, 20, 50, 65, 100, 15, 55),
    lo = c(55, 100, 17, 45, 60, 100, 12, 50),
    hi = c(65, 100, 23, 55, 70, 100, 18, 60),
    q = c("", "", "", "E", "", "", "", ""),
    stringsAsFactors = FALSE
  )
}

test_that(
  paste0(
    "welprof(): wellness first, totals left ",
    "out, suppressed values dropped"
  ),
  {
    w <- welprof(
      .wb(),
      "group",
      "indicator",
      "pct",
      "lo",
      "hi",
      well = c("Satisfied", "Hopeful"),
      distress = "Distress",
      domain = c(
        Hopeful = "spiritual",
        Satisfied = "mental",
        Distress = "mental"
      ),
      qual = "q"
    )
    expect_s3_class(w, "rmbl_wellness_profile")
    expect_identical(
      w$indicator,
      rep(c("Satisfied", "Hopeful", "Distress"), each = 2)
    )
    expect_identical(
      w$side,
      rep(c("wellness", "wellness", "distress"), each = 2)
    )
    expect_identical(w$domain[3], "spiritual")
    expect_true(w$usewithcau[1])
    expect_error(
      welprof(
        .wb(),
        "group",
        "indicator",
        "pct",
        "lo",
        "hi",
        well = "Nope",
        distress = "Distress"
      ),
      "not an indicator"
    )
    expect_error(
      welprof(
        .wb(),
        "group",
        "indicator",
        "pct",
        "lo",
        "hi",
        well = "Hopeful",
        distress = "Hopeful"
      ),
      "both one of wellness"
    )
    expect_error(
      welprof(
        .wb(),
        "group",
        "indicator",
        "pct",
        "lo",
        "hi",
        well = "Hopeful",
        distress = "Distress",
        domain = "x"
      ),
      "named character vector"
    )
  }
)

test_that("dualcont(): the strength ratio and its log-normal interval", {
  w <- welprof(
    .wb(),
    "group",
    "indicator",
    "pct",
    "lo",
    "hi",
    well = "Hopeful",
    distress = "Distress"
  )
  dc <- dualcont(w, "Hopeful", "Distress")
  z <- stats::qnorm(0.975)
  sl <- sqrt(
    ((log(65) - log(55)) / (2 * z))^2 + ((log(23) - log(17)) / (2 * z))^2
  )
  expect_identical(dc$strratio[1], 3)
  expect_identical(dc$ratiolo[1], exp(log(3) - z * sl))
  expect_error(dualcont(w, "Distress", "Distress"), "not a wellness indicator")
  expect_error(dualcont(w, "Hopeful", "Hopeful"), "not a distress indicator")
  expect_error(dualcont(data.frame(), "a", "b"), "must come from welprof")
})

test_that(
  paste0(
    "holbal(): one when every domain is ",
    "level; Atkinson's form otherwise"
  ),
  {
    d <- data.frame(
      g = rep(c("A", "B"), each = 4),
      dom = rep(c("physical", "emotional", "mental", "spiritual"), 2),
      pct = c(50, 50, 50, 50, 80, 80, 20, 20),
      lo = c(47, 47, 47, 47, 77, 77, 17, 17),
      hi = c(53, 53, 53, 53, 83, 83, 23, 23),
      stringsAsFactors = FALSE
    )
    r <- holbal(d, "g", "dom", "pct", "lo", "hi", reps = 2000)
    expect_identical(r$balance[1], 1)
    expect_equal(r$balance[2], sqrt(0.8 * 0.2) / 0.5, tolerance = 1e-12)
    expect_identical(r$level, c(50, 50))
    expect_lte(r$balup[1], 1)
    expect_lt(r$balup[2], 1)
    expect_identical(r$weadom[2], "mental")
    expect_identical(
      holbal(d, "g", "dom", "pct", "lo", "hi", reps = 500, seed = 4)$ballo,
      holbal(d, "g", "dom", "pct", "lo", "hi", reps = 500, seed = 4)$ballo
    )
    wt <- c(physical = 1, emotional = 1, mental = 1, spiritual = 3)
    r2 <- holbal(d, "g", "dom", "pct", "lo", "hi", w = wt, reps = 500)
    w <- wt / 6
    expect_identical(
      r2$balance[2],
      exp(sum(w * log(c(0.8, 0.8, 0.2, 0.2)))) / sum(w * c(0.8, 0.8, 0.2, 0.2))
    )
    expect_identical(r2$level[2], 100 * sum(w * c(0.8, 0.8, 0.2, 0.2)))
    d$q <- c("", "", "", "x", "", "", "", "")
    expect_true(is.na(holbal(
      d,
      "g",
      "dom",
      "pct",
      "lo",
      "hi",
      qual = "q",
      reps = 200
    )$balance[1]))
    expect_error(
      holbal(d, "g", "dom", "pct", "lo", "hi", w = c(a = 1)),
      "named by the domains"
    )
    expect_error(
      holbal(d[d$dom == "mental", ], "g", "dom", "pct", "lo", "hi"),
      "two domains"
    )
    d$pct[1] <- 100
    d$hi[1] <- 100
    expect_error(
      holbal(d, "g", "dom", "pct", "lo", "hi"),
      "strictly between 0 and 100"
    )
  }
)

test_that("dstntst(): Cochran's Q and I^2, pan-Indigenous rows left out", {
  z <- stats::qnorm(0.975)
  d <- data.frame(
    g = c("First Nations", "Metis", "Inuit", "Total, Indigenous identity"),
    y = c(34, 40, 37, 36),
    lo = c(32, 38, 34, 35),
    hi = c(36, 42, 40, 37),
    stringsAsFactors = FALSE
  )
  r <- dstntst(d, "g", "y", "lo", "hi")
  s <- c(4, 4, 6) / (2 * z)
  w <- 1 / s^2
  m <- sum(w * c(34, 40, 37)) / sum(w)
  q <- sum(w * (c(34, 40, 37) - m)^2)
  expect_identical(r$pooled, m)
  expect_identical(r$q, q)
  expect_identical(r$df, 2L)
  expect_identical(r$p_value, stats::pchisq(q, 2, lower.tail = FALSE))
  expect_identical(r$i2, (q - 2) / q)
  expect_identical(r$leftout, "Total, Indigenous identity")
  expect_output(print(r), "the groups differ")
  expect_output(print(r), "Distinctions test")
  r0 <- dstntst(
    data.frame(
      g = c("a", "b"),
      y = c(5, 5),
      lo = c(4, 4),
      hi = c(6, 6),
      stringsAsFactors = FALSE
    ),
    "g",
    "y",
    "lo",
    "hi"
  )
  expect_identical(r0$i2, 0)
  expect_output(print(r0), "not evidence that they are the same")
  expect_error(dstntst(d[1, ], "g", "y", "lo", "hi"), "two groups at least")
  expect_error(dstntst(rbind(d, d[1, ]), "g", "y", "lo", "hi"), "appears twice")
})

test_that("every Indigenous result draws itself and returns what it drew", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  g <- indgap(
    data.frame(
      g = c("First Nations", "Inuit", "Non-Indigenous"),
      e = c(45, 47, 61),
      lo = c(43, 43, 60),
      hi = c(47, 51, 62),
      q = c("", "F", ""),
      stringsAsFactors = FALSE
    ),
    "g",
    "e",
    "lo",
    "hi",
    qual = "q"
  )
  expect_s3_class(g, "rmbl_indigenous_gap")
  expect_identical(nrow(plot(g)), 2L)
  expect_named(
    plot(g, what = "ratio"),
    c("group", "ratio", "ratiolo", "ratioup")
  )
  expect_identical(
    nrow(plot(agestd(c(1, 2), c(100, 200), 1, grp = c("a", "b")))),
    2L
  )
  expect_identical(nrow(plot(stdprev(c(6, 4), c(5, 3), c(7, 5), c(1, 1)))), 1L)
  expect_identical(nrow(plot(exptrnd(c(60, 95, 70), c(500, 520, 300)))), 3L)
  expect_identical(nrow(plot(trcprog())), 5L)
  lv <- c("low", "high")
  oc <- ordcmp(
    data.frame(
      g = rep(c("A", "R"), each = 2),
      cat = rep(lv, 2),
      pct = c(40, 60, 50, 50),
      lo = c(35, 55, 45, 45),
      hi = c(45, 65, 55, 55),
      stringsAsFactors = FALSE
    ),
    "g",
    "cat",
    "pct",
    "lo",
    "hi",
    lvls = lv,
    ref = "R"
  )
  expect_identical(dim(plot(oc)), c(2L, 2L))
  w <- welprof(
    .wb(),
    "group",
    "indicator",
    "pct",
    "lo",
    "hi",
    well = "Hopeful",
    distress = "Distress"
  )
  expect_identical(nrow(plot(w)), 4L)
  expect_identical(nrow(plot(dualcont(w, "Hopeful", "Distress"))), 2L)
  hb <- holbal(
    .wb()[.wb()$indicator != "Total", ],
    "group",
    "indicator",
    "pct",
    "lo",
    "hi",
    reps = 200
  )
  expect_identical(dim(plot(hb)), c(2L, 3L))
  expect_identical(
    nrow(plot(dstntst(
      data.frame(
        g = c("a", "b"),
        y = c(5, 6),
        lo = c(4, 5),
        hi = c(6, 7),
        stringsAsFactors = FALSE
      ),
      "g",
      "y",
      "lo",
      "hi"
    ))),
    2L
  )
  expect_error(plot.rmbl_dsr(data.frame()), "rmbl_dsr object")
})

test_that("mental-health errors name the user's arguments", {
  expect_error(
    welprof(
      .wb(),
      "group",
      "indicator",
      "pct",
      "lo",
      "hi",
      well = mean,
      distress = "Distress"
    ),
    "`well` must be data"
  )
  expect_error(stdprev(1, 0, 2, 1, grp = mean), "`grp` must be data")
  expect_error(stdprev(1, 0, 2, 1, qual = mean), "`qual` must be data")
  d <- data.frame(
    g = rep(c("A", "B"), each = 4),
    dom = rep(c("physical", "emotional", "mental", "spiritual"), 2),
    pct = c(50, 50, 50, 50, 80, 80, 20, 20),
    lo = c(47, 47, 47, 47, 77, 77, 17, 17),
    hi = c(53, 53, 53, 53, 83, 83, 23, 23),
    stringsAsFactors = FALSE
  )
  expect_error(
    holbal(d, "g", "dom", "pct", "lo", "hi", w = mean),
    "`w` must be data"
  )
  oc <- data.frame(
    g = rep(c("A", "R"), each = 2),
    cat = rep(c("low", "high"), 2),
    pct = c(40, 60, 50, 50),
    lo = c(35, 55, 45, 45),
    hi = c(45, 65, 55, 55),
    stringsAsFactors = FALSE
  )
  expect_error(
    ordcmp(oc, "g", "cat", "pct", "lo", "hi", lvls = mean, ref = "R"),
    "`lvls` must be data"
  )
  expect_error(
    ordcmp(
      oc,
      "g",
      "cat",
      "pct",
      "lo",
      "hi",
      lvls = c("low", "high"),
      ref = "R",
      pooled = "Totl"
    ),
    "^ordcmp: `pooled` names \"Totl\""
  )
})

test_that("dstntst() refuses a `pooled` label that matches no row", {
  d <- data.frame(
    g = c("First Nations", "Metis", "Inuit", "All Indigenous"),
    y = c(34, 40, 37, 36),
    lo = c(32, 38, 34, 35),
    hi = c(36, 42, 40, 37),
    stringsAsFactors = FALSE
  )
  # a typo kept the pooled row in Cochran's Q
  expect_error(
    dstntst(d, "g", "y", "lo", "hi", pooled = "All Indigenus"),
    "^dstntst: `pooled` names \"All Indigenus\", not a group of `data`"
  )
  r <- dstntst(d, "g", "y", "lo", "hi", pooled = "All Indigenous")
  expect_identical(nrow(r$groups), 3L)
})

test_that("a wellness profile plot leaves par(col) and par(fg) as they were", {
  w <- welprof(
    .wb(),
    "group",
    "indicator",
    "pct",
    "lo",
    "hi",
    well = "Hopeful",
    distress = "Distress"
  )
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  before <- graphics::par(c("col", "fg", "mar"))
  plot(w)
  expect_identical(graphics::par(c("col", "fg", "mar")), before)
  expect_identical(graphics::par("col"), "black")
})

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
    expect_true(grepl(.rmbl_txt(h), flat, fixed = TRUE), info = h)
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

test_that("the mental health results print as boxes, distinctions kept", {
  wb <- indiex("wellbeing")
  w <- welprof(
    wb,
    "group",
    "indicator",
    "estimate",
    "lower",
    "upper",
    well = "Always or often has a hopeful outlook",
    distress = "Life satisfaction rating between 0 and 5",
    qual = "quality"
  )
  expect_box(
    w,
    "Wellness profile",
    c("(wellness)", "(distress)", "First Nations", "M\u00e9tis", "Inuit")
  )
  dc <- dualcont(
    w,
    "Always or often has a hopeful outlook",
    "Life satisfaction rating between 0 and 5"
  )
  expect_box(
    dc,
    "Dual continuum",
    c("Always or often has a hopeful outlook", "above 1", "independent")
  )
  h <- indiex("health")
  dom <- c(
    "Perceived health, very good or excellent" = "physical",
    "Perceived mental health, very good or excellent" = "mental",
    "Life satisfaction, satisfied or very satisfied" = "emotional"
  )
  d <- h[
    h$period == "2019/2022" &
      h$age == "Total, 18 years and over" &
      h$indicator %in% names(dom),
  ]
  d$domain <- dom[d$indicator]
  hb <- holbal(d, "group", "domain", "estimate", "lower", "upper")
  expect_box(
    hb,
    "Holistic balance",
    c("equal, over 3 domains", "Domain levels", "weakest", "CARE")
  )
  expect_match(.an_hb_weights(c(a = 1, b = 2)), "a 1, b 2")
  expect_null(.an_hb_weights(NULL))
  mh <- indiex("mentalhealth")
  mh <- mh[mh$region == "Canada", ]
  oc <- ordcmp(
    mh,
    "group",
    "rating",
    "estimate",
    "lower",
    "upper",
    lvls = c("Fair or poor", "Good", "Very good", "Excellent"),
    ref = "M\u00e9tis",
    qual = "quality"
  )
  expect_box(oc, "Ordinal comparison", c("M\u00e9tis", "probbet", "neff"))
  sp <- stdprev(
    c(5, 6, 4),
    c(4, 5, 3),
    c(6, 7, 5),
    std = c(1, 1, 1),
    grp = c("a", "a", "a")
  )
  expect_box(sp, "Age-standardised prevalence", c("95% CI", "same population"))
  dt <- dstntst(
    data.frame(
      g = c("a", "b"),
      y = c(5, 5),
      lo = c(4, 4),
      hi = c(6, 6),
      stringsAsFactors = FALSE
    ),
    "g",
    "y",
    "lo",
    "hi"
  )
  expect_box(
    dt,
    "Distinctions test",
    c("Cochran's Q", "not evidence that they are the same", "pan-Indigenous")
  )
  expect_output(print(w[, c("group", "estimate")]), "estimate")
})

test_that("the help pages' own tables run through the estimators", {
  own <- data.frame(
    group = rep(c("Nation A", "Everyone else"), each = 4),
    rating = rep(c("Poor", "Fair", "Good", "Excellent"), 2),
    pct = c(10, 25, 40, 25, 6, 20, 44, 30),
    lo = c(7, 21, 35, 21, 5, 18, 42, 28),
    hi = c(13, 29, 45, 29, 7, 22, 46, 32),
    stringsAsFactors = FALSE
  )
  oc <- ordcmp(own, "group", "rating", "pct", "lo", "hi",
               lvls = c("Poor", "Fair", "Good", "Excellent"),
               ref = "Everyone else")
  expect_s3_class(oc, "rmbl_ordinal_compare")
  sp <- stdprev(
    est = c(12, 9, 6, 8, 6, 4),
    lower = c(9, 6, 3, 7, 5, 3),
    upper = c(15, 12, 9, 9, 7, 5),
    std = c(500, 300, 200),
    grp = rep(c("Nation A", "Everyone else"), each = 3)
  )
  expect_s3_class(sp, "rmbl_prevalence")
  expect_equal(sp$estimate[sp$group == "Nation A"], 9.9, tolerance = 1e-12)
  wp <- data.frame(
    community = rep(c("Lakeside", "Riverbend"), each = 4),
    item = rep(c("Hopeful", "Satisfied", "Rarely hopeful",
                 "Low satisfaction"), 2),
    pct = c(64, 71, 12, 18, 58, 66, 16, 22),
    lo = c(59, 66, 9, 14, 52, 60, 12, 17),
    hi = c(69, 76, 15, 22, 64, 72, 20, 27),
    stringsAsFactors = FALSE
  )
  w <- welprof(wp, "community", "item", "pct", "lo", "hi",
               well = c("Hopeful", "Satisfied"),
               distress = c("Rarely hopeful", "Low satisfaction"))
  expect_s3_class(w, "rmbl_wellness_profile")
  expect_s3_class(frmaud(w), "rmbl_framing")
  expect_s3_class(dualcont(w, "Hopeful", "Rarely hopeful"),
                  "rmbl_dual_continuum")
  hb <- data.frame(
    community = rep(c("Lakeside", "Riverbend"), each = 4),
    domain = rep(c("body", "mind", "spirit", "family"), 2),
    pct = c(62, 58, 70, 75, 55, 61, 66, 80),
    lo = c(57, 53, 65, 70, 49, 55, 60, 75),
    hi = c(67, 63, 75, 80, 61, 67, 72, 85),
    stringsAsFactors = FALSE
  )
  expect_s3_class(
    holbal(hb, "community", "domain", "pct", "lo", "hi", reps = 2000),
    "rmbl_holistic_balance"
  )
})

# ---- restored box items and result-driven readings ---------------------------

ls_flat <- function(x) gsub("\\s+", " ", paste(format(x), collapse = " "))

test_that("welprof()'s box shows a domain and reads how far groups part", {
  wb <- indiex("wellbeing")
  w <- welprof(wb, "group", "indicator", "estimate", "lower", "upper",
    well = "Always or often has a hopeful outlook",
    distress = "Life satisfaction rating between 0 and 5", qual = "quality")
  txt <- ls_flat(w)
  expect_match(txt, "On none of the 2 indicators", fixed = TRUE)
  w$domain <- "emotional"
  expect_match(ls_flat(w), "domain", fixed = TRUE)
  expect_match(ls_flat(w), "emotional", fixed = TRUE)
  d <- data.frame(
    group = c("a", "b", "a", "b"),
    indicator = c("i1", "i1", "i2", "i2"),
    estimate = c(10, 50, 10, 11),
    lower = c(8, 48, 8, 9),
    upper = c(12, 52, 12, 13),
    stringsAsFactors = FALSE
  )
  expect_match(.an_wp_reading(d), "On 1 of 2 indicators", fixed = TRUE)
  expect_match(.an_wp_reading(d), "i1", fixed = TRUE)
})

test_that("holbal()'s reading names the most and least balanced group", {
  d <- data.frame(
    group = c("a", "b", "c"),
    balance = c(0.90, 0.99, 0.95),
    ballo = c(0.89, 0.985, 0.90),
    balup = c(0.91, 0.995, 0.99),
    weadom = c("physical", "mental", "physical"),
    usewithcau = FALSE,
    stringsAsFactors = FALSE
  )
  r <- .an_hb_reading(d)
  expect_match(r[1L], "Highest balance: b (0.99); lowest: a (0.9)",
    fixed = TRUE)
  expect_match(r[2L], "do not overlap", fixed = TRUE)
  expect_match(r[3L], "physical for 2 of 3 groups", fixed = TRUE)
  d$balance <- c(0.95, 0.96, 0.955)
  d$ballo <- d$balance - 0.05
  d$balup <- d$balance + 0.05
  d$weadom <- c("mental", "mental", "mental")
  r2 <- .an_hb_reading(d)
  expect_match(r2[2L], "overlap: the data cannot tell", fixed = TRUE)
  expect_match(r2[3L], "mental for 3 of 3", fixed = TRUE)
})

test_that("ordcmp()'s box marks a pooled row and reads each group", {
  mh <- indiex("mentalhealth")
  mh <- mh[mh$region == "Canada", ]
  lv <- c("Fair or poor", "Good", "Very good", "Excellent")
  oc <- ordcmp(mh, "group", "rating", "estimate", "lower", "upper",
    lvls = lv, ref = "Métis", qual = "quality", pooled = "Inuit")
  txt <- ls_flat(oc)
  expect_match(txt, "Inuit (pooled)", fixed = TRUE)
  expect_match(
    txt,
    .rmbl_txt("Rate lower than M\u00e9tis (interval below 0.5): First"),
    fixed = TRUE
  )
  expect_match(txt, "Not distinguishable from 0.5", fixed = TRUE)
  up <- .rd_null("g", 0.6, 0.7, 0.5, "Rate higher than R", "Rate lower")
  expect_match(up, "^Rate higher than R \\(interval above 0.5\\): g\\.$")
})

test_that("stdprev()'s reading compares the groups' prevalences", {
  sp <- stdprev(c(5, 6, 1, 2), c(4, 5, 0.5, 1.5), c(6, 7, 1.5, 2.5),
    std = c(1, 1), grp = c("x", "x", "y", "y"))
  txt <- ls_flat(sp)
  expect_match(txt, "Highest prevalence: x", fixed = TRUE)
  expect_match(txt, "lowest: y", fixed = TRUE)
  expect_match(txt, "do not overlap", fixed = TRUE)
  sp2 <- stdprev(c(5, 6, 5.5, 6.2), c(3, 4, 3.5, 4.2), c(7, 8, 7.5, 8.2),
    std = c(1, 1), grp = c("x", "x", "y", "y"))
  expect_match(ls_flat(sp2), "Highest prevalence: y", fixed = TRUE)
  expect_match(ls_flat(sp2), "Their intervals overlap", fixed = TRUE)
})

test_that("a mental-health table without its columns prints plainly", {
  for (cls in c("rmbl_holistic_balance", "rmbl_dual_continuum",
    "rmbl_ordinal_compare", "rmbl_prevalence")) {
    expect_plain_df(cls)
  }
})

test_that("a holistic balance without its domain levels has no domain table", {
  x <- structure(
    data.frame(group = "a", stringsAsFactors = FALSE),
    domains = NULL
  )
  expect_null(.an_hb_domains(x, "a"))
  y <- structure(
    data.frame(group = "a", stringsAsFactors = FALSE),
    domains = matrix(1, 2, 2)
  )
  expect_null(.an_hb_domains(y, "a"))
})
