# Frameworks put to work: each against an exact reference

test_that(
  paste0(
    "cwbscr(): the four components and their mean, as the methodology sets ",
    "them"
  ),
  {
    r <- cwbscr(20000, 60, 9, 80, 70, 60, 90)
    expect_identical(
      r$income,
      100 * (log(20000) - log(2650)) / (log(75000) - log(2650))
    )
    expect_identical(r$education, 2 / 3 * 60 + 1 / 3 * 9)
    expect_identical(r$housing, 75)
    expect_identical(r$labour, 75)
    expect_identical(r$cwb, mean(c(r$income, r$education, r$housing, r$labour)))
    expect_identical(
      cwbscr(c(1000, 1e6), 50, 5, 50, 50, 50, 50)$income,
      c(0, 100)
    )
    expect_identical(
      cwbscr(20000, 60, 9, 80, 70, 60, 90, bounds = c(2000, 40000))$income,
      100 * (log(20000) - log(2000)) / (log(40000) - log(2000))
    )
    expect_identical(nrow(cwbscr(c(1e4, 2e4, 3e4), 50, 5, 50, 50, 50, 50)), 3L)
    expect_error(cwbscr(1e4, 150, 5, 50, 50, 50, 50), "from 0 to 100")
    expect_error(cwbscr(0, 50, 5, 50, 50, 50, 50), "must be positive")
    expect_error(
      cwbscr(1e4, c(1, 2), c(1, 2, 3), 50, 50, 50, 50),
      "one value per community"
    )
    expect_error(
      cwbscr(1e4, 50, 5, 50, 50, 50, 50, bounds = c(5, 1)),
      "two increasing"
    )
  }
)

test_that(
  paste0(
    "connassoc(): Spearman's rho, its exact p as cor.test gives it, and the ",
    "error interval"
  ),
  {
    d <- data.frame(
      p = letters[1:6],
      x = c(10, 14, 12, 19, 25, 22),
      y = c(31, 30, 36, 40, 39, 47),
      xl = c(8, 12, 10, 17, 23, 20),
      xh = c(12, 16, 14, 21, 27, 24),
      yl = c(29, 28, 34, 38, 37, 45),
      yh = c(33, 32, 38, 42, 41, 49)
    )
    r <- connassoc(d, "p", "x", "y", "xl", "xh", "yl", "yh", reps = 2000)
    ct <- suppressWarnings(stats::cor.test(
      d$x,
      d$y,
      method = "spearman",
      exact = TRUE
    ))
    expect_identical(r$rho, unname(ct$estimate))
    expect_equal(r$p_value, ct$p.value, tolerance = 1e-8)
    expect_true(r$exact)
    expect_lt(r$rholo, r$rho)
    expect_gt(r$rhoup, r$rho)
    expect_identical(nrow(.rmbl_permutations(5L)), 120L)
    expect_identical(
      anyDuplicated(apply(.rmbl_permutations(5L), 1L, paste, collapse = "")),
      0L
    )
    expect_output(print(r), "does not show that one causes the other")
    r2 <- connassoc(d, "p", "x", "y")
    expect_true(is.na(r2$rholo))
    expect_output(print(r2), "exact p")
    big <- data.frame(
      p = 1:12,
      x = 1:12,
      y = c(2, 1, 4, 3, 6, 5, 8, 7, 10, 9, 12, 11)
    )
    r3 <- connassoc(big, "p", "x", "y", reps = 2000)
    expect_false(r3$exact)
    expect_lt(r3$p_value, 0.01)
    expect_error(connassoc(d[1:2, ], "p", "x", "y"), "three places")
    expect_error(connassoc(d, "p", "x", "y", "xl"), "all four limit columns")
  }
)

.hc <- function() {
  data.frame(
    g = rep(c("A", "B"), each = 4),
    ind = rep(c("well", "well", "ill", "ill"), 2),
    per = rep(c("t1", "t2"), 4),
    est = c(50, 55, 20, 18, 40, 41, 30, 35),
    lo = c(46, 51, 18, 16, 36, 37, 27, 32),
    hi = c(54, 59, 22, 20, 44, 45, 33, 38),
    q = c("", "", "", "", "", "F", "", "E"),
    stringsAsFactors = FALSE
  )
}

test_that(
  paste0(
    "healchg(): the change between periods ",
    "and its interval, wellness first"
  ),
  {
    z <- stats::qnorm(0.975)
    r <- healchg(
      .hc(),
      "g",
      "ind",
      "per",
      "est",
      "lo",
      "hi",
      from = "t1",
      to = "t2",
      well = "well",
      qual = "q"
    )
    expect_identical(r$indicator, c("well", "well", "ill", "ill"))
    expect_identical(r$side, c("wellness", "wellness", "distress", "distress"))
    expect_identical(r$change[1], 5)
    expect_identical(r$upper[1], 5 + z * sqrt(2 * (8 / (2 * z))^2))
    expect_true(is.na(r$change[2]))
    expect_true(r$usewithcau[4])
    expect_true(all(is.na(
      healchg(.hc(), "g", "ind", "per", "est", "lo", "hi", "t1", "t2")$side
    )))
    expect_error(
      healchg(.hc(), "g", "ind", "per", "est", "lo", "hi", "t1", "t9"),
      "is not a period"
    )
    expect_error(
      healchg(
        rbind(.hc(), .hc()),
        "g",
        "ind",
        "per",
        "est",
        "lo",
        "hi",
        "t1",
        "t2"
      ),
      "appear twice"
    )
    d <- .hc()
    d$ind[d$per == "t2"] <- paste0("other", seq_len(sum(d$per == "t2")))
    expect_error(
      healchg(d, "g", "ind", "per", "est", "lo", "hi", "t1", "t2"),
      "in both periods"
    )
  }
)

test_that(
  paste0(
    "commidx(): the weighted sum over the sum of absolute weights, never ",
    "filled"
  ),
  {
    z <- stats::qnorm(0.975)
    d <- data.frame(
      g = rep(c("A", "B"), each = 3),
      ind = rep(c("belong", "stress", "drink"), 2),
      e = c(60, 20, 30, 70, 25, NA),
      lo = c(56, 18, 27, 66, 22, NA),
      hi = c(64, 22, 33, 74, 28, NA),
      q = c("", "", "", "", "", ".."),
      stringsAsFactors = FALSE
    )
    w <- c(belong = 2, stress = -1, drink = -1)
    r <- commidx(d, "g", "ind", "e", "lo", "hi", w = w, qual = "q")
    expect_identical(r$index[1], (2 * 60 - 20 - 30) / 4)
    se <- c(4, 2, 3) / z
    expect_identical(
      r$upper[1],
      (2 * 60 - 20 - 30) / 4 + z * sqrt(sum(w^2 * se^2)) / 4
    )
    expect_true(is.na(r$index[2]))
    expect_identical(attr(r, "weights"), w)
    expect_error(
      commidx(d, "g", "ind", "e", "lo", "hi"),
      "set by the community"
    )
    expect_error(
      commidx(d, "g", "ind", "e", "lo", "hi", w = c(zz = 1)),
      "not an indicator"
    )
    expect_error(
      commidx(rbind(d, d[1, ]), "g", "ind", "e", "lo", "hi", w = w),
      "indicator twice"
    )
  }
)

test_that("mhcont(): proxies per direction, shared and missing ones said", {
  z <- stats::qnorm(0.975)
  d <- data.frame(
    g = "A",
    ind = c("hopeful", "belong", "mp", "family"),
    e = c(50, 60, 40, 70),
    lo = c(46, 56, 36, 66),
    hi = c(54, 64, 44, 74),
    stringsAsFactors = FALSE
  )
  r <- mhcont(
    d,
    "g",
    "ind",
    "e",
    "lo",
    "hi",
    hope = "hopeful",
    belong = c("belong", "family"),
    meaning = "mp",
    purp = "mp"
  )
  expect_s3_class(r, "rmbl_wellness_profile")
  expect_identical(r$indicator, c("hope", "belonging", "meaning", "purpose"))
  expect_identical(r$estimate[2], 65)
  expect_identical(r$upper[2], 65 + z * sqrt(2 * (8 / (2 * z))^2) / 2)
  expect_identical(r$shared, c(FALSE, FALSE, TRUE, TRUE))
  r2 <- mhcont(d, "g", "ind", "e", "lo", "hi", hope = "hopeful")
  expect_identical(r2$domain[2:4], rep("no published proxy", 3))
  expect_true(all(is.na(r2$estimate[2:4])))
  expect_error(mhcont(d, "g", "ind", "e", "lo", "hi"), "one direction at least")
  expect_error(
    mhcont(d, "g", "ind", "e", "lo", "hi", hope = "zz"),
    "not an indicator"
  )
  expect_error(
    mhcont(d, "g", "ind", "e", "lo", "hi", hope = 1),
    "must name indicators"
  )
})

test_that("frmaud(): the share of the report that is deficit-framed", {
  d <- data.frame(
    g = rep(c("A", "B"), each = 3),
    ind = rep(c("w", "d1", "d2"), 2),
    e = 1:6,
    lo = 0:5,
    hi = 2:7,
    stringsAsFactors = FALSE
  )
  w <- welprof(
    d[-1, ],
    "g",
    "ind",
    "e",
    "lo",
    "hi",
    well = "w",
    distress = c("d1", "d2")
  )
  f <- frmaud(w)
  expect_identical(f$shrdef, 4 / 5)
  expect_identical(f$defonly, "A")
  expect_output(print(f), "Reported on deficits alone: A")
  expect_output(print(f), "pair each with a strength-framed level")
  expect_error(frmaud(data.frame()), "must come from welprof")
})

test_that("the framework results draw themselves", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  d <- data.frame(
    p = letters[1:4],
    x = c(1, 3, 2, 4),
    y = c(2, 3, 1, 5),
    xl = 0:3,
    xh = 2:5,
    yl = c(1, 2, 0, 4),
    yh = c(3, 4, 2, 6)
  )
  expect_identical(
    nrow(plot(connassoc(d, "p", "x", "y", "xl", "xh", "yl", "yh", reps = 200))),
    4L
  )
  expect_identical(
    nrow(plot(connassoc(d, "p", "x", "y"), xlab = "Land", ylab = "Wellness")),
    4L
  )
  expect_error(
    plot(connassoc(d, "p", "x", "y"), xlab = 1),
    "`xlab` must be a single non-empty string"
  )
  expect_identical(
    nrow(plot(healchg(
      .hc(),
      "g",
      "ind",
      "per",
      "est",
      "lo",
      "hi",
      "t1",
      "t2",
      well = "well",
      qual = "q"
    ))),
    4L
  )
  ci <- commidx(
    .hc()[.hc()$per == "t1", ],
    "g",
    "ind",
    "est",
    "lo",
    "hi",
    w = c(well = 1, ill = -1)
  )
  expect_identical(nrow(plot(ci)), 2L)
  mw <- mhcont(
    data.frame(
      g = "A",
      ind = "h",
      e = 5,
      lo = 4,
      hi = 6,
      stringsAsFactors = FALSE
    ),
    "g",
    "ind",
    "e",
    "lo",
    "hi",
    hope = "h"
  )
  expect_identical(nrow(plot(mw)), 4L)
})

test_that("framework errors name the user's arguments", {
  d <- data.frame(
    g = rep(c("A", "B"), each = 2),
    ind = rep(c("hope1", "bel1"), 2),
    e = c(50, 60, 55, 65),
    lo = c(45, 55, 50, 60),
    hi = c(55, 65, 60, 70),
    stringsAsFactors = FALSE
  )
  expect_error(
    mhcont(d, "g", "ind", "e", "lo", "hi", hope = "hope1", belong = mean),
    "`belong` must be data"
  )
  expect_error(
    mhcont(d, "g", "ind", "e", "lo", "hi", hope = "hope1", purp = mean),
    "`purp` must be data"
  )
  expect_error(
    mhcont(d, "g", "ind", "e", "lo", "hi", hope = "hope1", belong = 1),
    "^mhcont: `belong` must name indicators"
  )
  expect_error(
    mhcont(d, "g", "ind", "e", "lo", "hi", hope = "hope1", purp = NA),
    "^mhcont: `purp` must name indicators"
  )
  expect_error(
    commidx(d, "g", "ind", "e", "lo", "hi", w = mean),
    "`w` must be data"
  )
  expect_error(
    healchg(.hc(), "g", "ind", "per", "est", "lo", "hi", "t1", "t2", mean),
    "`well` must be data"
  )
  # the column checks name the arguments, not long names
  expect_error(
    commidx(d, NULL, "ind", "e", "lo", "hi"),
    "`grp` must name a column"
  )
})

test_that("frmaud() refuses a profile with no indicator", {
  wb <- data.frame(
    group = c("A", "A"),
    indicator = c("Hopeful", "Distress"),
    pct = c(60, 20),
    lo = c(55, 17),
    hi = c(65, 23),
    stringsAsFactors = FALSE
  )
  w <- welprof(
    wb,
    "group",
    "indicator",
    "pct",
    "lo",
    "hi",
    well = "Hopeful",
    distress = "Distress"
  )
  expect_identical(frmaud(w)$shrdef, 0.5)
  empty <- w[0, ]
  class(empty) <- class(w)
  expect_error(frmaud(empty), "^frmaud: `x` has no wellness or distress")
})

test_that("plot.rmbl_connection() leaves par(col) and par(fg) as they were", {
  d <- data.frame(
    p = letters[1:6],
    x = c(10, 14, 12, 19, 25, 22),
    y = c(31, 30, 36, 40, 39, 47)
  )
  r <- connassoc(d, "p", "x", "y", reps = 100)
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  before <- graphics::par(c("col", "fg", "mar"))
  plot(r)
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

test_that("the framework results print as boxes, distinctions kept", {
  wb <- indiex("wellbeing")
  mw <- mhcont(
    wb,
    "group",
    "indicator",
    "estimate",
    "lower",
    "upper",
    hope = "Always or often has a hopeful outlook",
    meaning = "Sense of meaning and purpose rating of 8, 9 or 10",
    purp = "Sense of meaning and purpose rating of 8, 9 or 10",
    qual = "quality"
  )
  expect_box(
    mw,
    "First Nations Mental Wellness Continuum",
    c(
      "First Nations",
      "M\u00e9tis",
      "Inuit",
      "No published proxy: belonging",
      "Proxy for hope",
      "95% CI"
    )
  )
  h <- indiex("health")
  belong <- paste0(
    "Sense of belonging to local community, ",
    "somewhat strong or very strong"
  )
  h1 <- h[
    h$age == "Total, 18 years and over" &
      h$indicator %in%
        c("Perceived mental health, very good or excellent", belong),
  ]
  hc <- healchg(
    h1,
    "group",
    "indicator",
    "period",
    "estimate",
    "lower",
    "upper",
    from = "2015/2018",
    to = "2019/2022",
    qual = "quality",
    well = "Perceived mental health, very good or excellent"
  )
  expect_box(
    hc,
    "Healing as change between two periods",
    c("2015/2018 to 2019/2022", "(wellness)", "clear of zero", "break")
  )
  h2 <- h[h$period == "2019/2022" & h$age == "Total, 18 years and over", ]
  w <- c(2, -1)
  names(w) <- c(belong, "Heavy drinking")
  ci <- commidx(h2, "group", "indicator", "estimate", "lower", "upper", w = w)
  expect_box(
    ci,
    "Community-weighted index",
    c("+2  Sense of belonging", "-1  Heavy drinking", "never a ranking")
  )
  # subsets that lost their columns print as plain tables
  expect_output(print(hc[, c("group", "change")]), "change")
  expect_output(print(ci[, c("group", "index")]), "index")
  expect_output(print(mw[, c("group", "estimate")]), "estimate")
})

test_that("a connection and a framing audit print as boxes", {
  d <- data.frame(
    p = letters[1:5],
    x = c(1, 2, 3, 4, 5),
    y = c(2, 1, 4, 3, 5)
  )
  r <- connassoc(d, "p", "x", "y")
  expect_box(
    r,
    "Connection across places",
    c("Places", "rho = ", "exact", "does not show that one causes the other")
  )
  expect_match(.an_conn_reading(0.8), "strongly together")
  expect_match(.an_conn_reading(-0.5), "moderately in opposite")
  expect_match(.an_conn_reading(NA_real_), "undefined")
  wb <- indiex("wellbeing")
  w <- welprof(
    wb,
    "group",
    "indicator",
    "estimate",
    "lower",
    "upper",
    well = "Always or often has a hopeful outlook",
    distress = c(
      "Life satisfaction rating between 0 and 5",
      "Rarely or never has a hopeful outlook"
    ),
    qual = "quality"
  )
  expect_box(
    frmaud(w),
    "Framing audit",
    c("Deficit-framed", "Walter (2016)", "strength-framed level")
  )
})

test_that("cwbscr() results print as a box", {
  s <- cwbscr(c(30000, 20000), c(70, 50), c(20, 10), c(90, 80), c(85, 70),
    c(65, 55), c(60, 50))
  expect_s3_class(s, c("rmbl_cwb_scores", "data.frame"))
  expect_box2(s, "Community Well-Being scores", c("Mean CWB", "labour"))
  expect_box2(s["cwb"], "Community Well-Being scores", "plain table")
})

test_that("the help pages' own tables run through the framework estimators", {
  own <- data.frame(
    community = rep(c("Lakeside", "Riverbend"), each = 2),
    item = rep(c("Hopeful", "Life has meaning"), 2),
    pct = c(64, 70, 58, 75),
    lo = c(59, 65, 52, 70),
    hi = c(69, 75, 64, 80),
    stringsAsFactors = FALSE
  )
  mc <- mhcont(own, "community", "item", "pct", "lo", "hi", hope = "Hopeful",
               meaning = "Life has meaning", purp = "Life has meaning")
  expect_s3_class(mc, "rmbl_wellness_continuum")
  pl <- data.frame(
    region = c("North", "South", "East", "West", "Coast", "Interior"),
    language = c(41, 18, 27, 33, 22, 38),
    wellbeing = c(68, 55, 60, 66, 57, 63),
    stringsAsFactors = FALSE
  )
  ca <- connassoc(pl, "region", "language", "wellbeing", reps = 2000)
  expect_s3_class(ca, "rmbl_connection")
  hc <- data.frame(
    community = "Lakeside",
    item = rep(c("Good mental health", "Anxiety"), 2),
    survey = rep(c("2018", "2023"), each = 2),
    pct = c(55, 14, 61, 11),
    lo = c(50, 11, 56, 8),
    hi = c(60, 17, 66, 14),
    stringsAsFactors = FALSE
  )
  h <- healchg(hc, "community", "item", "survey", "pct", "lo", "hi",
               from = "2018", to = "2023", well = "Good mental health",
               distress = "Anxiety")
  expect_s3_class(h, "rmbl_healing_change")
  ci <- data.frame(
    community = rep(c("Lakeside", "Riverbend"), each = 3),
    item = rep(c("Speaks the language", "Has a doctor", "Food insecure"), 2),
    pct = c(38, 72, 21, 25, 64, 30),
    lo = c(33, 67, 17, 20, 58, 25),
    hi = c(43, 77, 25, 30, 70, 35),
    stringsAsFactors = FALSE
  )
  x <- commidx(ci, "community", "item", "pct", "lo", "hi",
               w = c("Speaks the language" = 2, "Has a doctor" = 1,
                     "Food insecure" = -1))
  expect_s3_class(x, "rmbl_community_index")
})

# ---- restored box items and result-driven readings ---------------------------

ls_flat <- function(x) gsub("\\s+", " ", paste(format(x), collapse = " "))

test_that("mhcont()'s box marks the shared proxies and reads each group", {
  wb <- indiex("wellbeing")
  mw <- mhcont(wb, "group", "indicator", "estimate", "lower", "upper",
    hope = "Always or often has a hopeful outlook",
    meaning = "Sense of meaning and purpose rating of 8, 9 or 10",
    purp = "Sense of meaning and purpose rating of 8, 9 or 10",
    qual = "quality")
  txt <- ls_flat(mw)
  expect_match(txt, "yes (shared)", fixed = TRUE)
  expect_match(txt, "First Nations: highest hope", fixed = TRUE)
  d <- data.frame(
    group = "g",
    indicator = c("hope", "meaning"),
    estimate = c(10, 40),
    stringsAsFactors = FALSE
  )
  expect_identical(
    .an_wc_levels(d),
    "g: highest meaning (40), lowest hope (10)."
  )
})

test_that("healchg()'s reading says which way each side moved", {
  away <- data.frame(
    side = c("wellness", "distress"),
    lower = c(-5, 1),
    upper = c(-1, 4),
    stringsAsFactors = FALSE
  )
  r <- .an_hc_sides(away)
  expect_match(r[1L], "Wellness: 0 rose and 1 fell", fixed = TRUE)
  expect_match(r[2L], "away from healing", fixed = TRUE)
  toward <- away
  toward$lower <- c(1, -4)
  toward$upper <- c(5, -1)
  expect_match(.an_hc_sides(toward)[2L], "toward healing", fixed = TRUE)
  none <- away
  none$lower <- c(-1, -1)
  none$upper <- c(1, 1)
  expect_match(.an_hc_sides(none)[2L], "No change is larger", fixed = TRUE)
})

test_that("commidx()'s reading compares the groups' indices", {
  h <- indiex("health")
  h <- h[h$period == "2019/2022" & h$age == "Total, 18 years and over", ]
  w <- c(2, -1)
  names(w) <- c("Has a regular healthcare provider", "Heavy drinking")
  ci <- commidx(h, "group", "indicator", "estimate", "lower", "upper",
    qual = "quality", w = w)
  txt <- ls_flat(ci)
  expect_match(txt, "Highest index:", fixed = TRUE)
  expect_match(txt, "lowest:", fixed = TRUE)
  expect_match(txt, "A higher index: more of the protective", fixed = TRUE)
})

test_that("the framework readings for a weak link and full proxies", {
  expect_identical(.an_conn_reading(0.1),
    "Across these places the two rank weakly together.")
  d <- data.frame(
    indicator = c("a", "b"), estimate = c(1, 2), stringsAsFactors = FALSE
  )
  expect_identical(.an_wc_reading(d),
    "Every direction has a published proxy for every group.")
  expect_null(.an_wc_proxies(
    data.frame(indicator = "a", estimate = NA, stringsAsFactors = FALSE)
  ))
})
