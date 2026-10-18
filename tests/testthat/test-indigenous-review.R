# The 1.0.0 review of the Indigenous estimators: each fix, pinned

test_that("qltyrcd() maps another agency's flags onto ok, E and x", {
  expect_identical(qltyrcd(c("", "*", "**", "np", NA), suppr = c("**", "np"), caution = "*"),
                   c("ok", "E", "x", "x", "ok"))
  expect_identical(qltyrcd(c("E", "F", "..")), c("E", "x", "x"))
  expect_error(qltyrcd("a", suppr = "a", caution = "a"), "both suppressed and caution")
  expect_error(qltyrcd(list(1)), "vector of flags")
  expect_error(qltyrcd("a", suppr = 1), "must be flags")
})

test_that("unknown quality flags warn and count as ok", {
  expect_warning(q <- .rmbl_qflags(c("", "E", "zz", NA)), "\"zz\" not recognised")
  expect_identical(q, c("ok", "E", "ok", "ok"))
  expect_silent(.rmbl_qflags(c("x", "..", "...", "F")))
})

test_that("limfrom() builds limits from a standard error, a CV or a margin of error", {
  z <- stats::qnorm(0.975)
  r <- limfrom(c(40, 10), se = c(2, 1))
  expect_equal(r$lower, c(40, 10) - z * c(2, 1))
  expect_equal(r$upper, c(40, 10) + z * c(2, 1))
  expect_equal(limfrom(40, cv = 5)$se, 2)
  expect_equal(limfrom(40, moe = stats::qnorm(0.95) * 2)$se, 2)
  expect_equal(limfrom(40, moe = z * 2, moelev = 0.95)$se, 2)
  expect_error(limfrom(40), "give one of")
  expect_error(limfrom(40, se = 1, cv = 1), "give one of")
  expect_error(limfrom(c(1, 2, 3), se = c(1, 2)), "one per estimate")
  expect_error(limfrom(40, se = -1), "must not be negative")
})

test_that("indgap() refuses duplicate groups and warns on a total as the reference", {
  d <- data.frame(g = c("A", "A", "R"), est = c(10, 11, 12), lo = c(9, 10, 11), hi = c(11, 12, 13))
  expect_error(indgap(d, "g", "est", "lo", "hi", ref = "R"), "appears twice")
  d2 <- data.frame(g = c("A", "Total, all persons"), est = c(10, 12), lo = c(9, 11), hi = c(11, 13))
  expect_warning(indgap(d2, "g", "est", "lo", "hi", ref = "Total, all persons"), "total")
  d3 <- data.frame(g = c(" A", "B", "R"), est = c(10, 11, 12), lo = c(9, 10, 11), hi = c(11, 12, 13))
  r <- indgap(d3, "g", "est", "lo", "hi", ref = "R", pooled = "B")
  expect_identical(r$group, c("A", "B"))
  expect_identical(r$poogrp, c(FALSE, TRUE))
})

test_that("rategap() refuses a group against itself; exptrnd() refuses a constant outcome", {
  x <- agestd(c(5, 9, 2, 3), c(1000, 1200, 2000, 2500), c(1, 1), grp = c("a", "a", "b", "b"))
  expect_error(rategap(x, "a", "a"), "itself|same|differ")
  expect_error(exptrnd(c(0, 0, 0), c(10, 10, 10)), "no trend to test")
  expect_error(exptrnd(c(10, 10, 10), c(10, 10, 10)), "no trend to test")
})

test_that("holbal(): the interval holds the estimate, and proportions are refused", {
  d <- data.frame(g = rep(c("A", "B"), each = 4), dom = rep(c("physical", "emotional", "mental", "spiritual"), 2),
                  pct = c(50, 52, 48, 51, 80, 70, 20, 30), lo = c(45, 47, 43, 46, 75, 65, 15, 25),
                  hi = c(55, 57, 53, 56, 85, 75, 25, 35))
  r <- holbal(d, "g", "dom", "pct", "lo", "hi", reps = 1000, seed = 2)
  expect_true(all(r$ballo <= r$balance & r$balance <= r$balup))
  expect_true(all(r$ballo >= 0 & r$balup <= 1))
  p <- d
  p[c("pct", "lo", "hi")] <- p[c("pct", "lo", "hi")] / 100
  expect_error(holbal(p, "g", "dom", "pct", "lo", "hi"), "percent|proportion")
})

test_that("connassoc(): the Monte Carlo p-value is (b + 1) / (R + 1)", {
  big <- data.frame(p = 1:12, x = 1:12, y = 1:12)
  r <- connassoc(big, "p", "x", "y", reps = 999)
  expect_false(r$exact)
  expect_gt(r$p_value, 0)
  expect_equal(r$p_value * 1000, round(r$p_value * 1000), tolerance = 1e-9)
})

test_that("healchg(): with `distress` given, an indicator in neither list is other", {
  d <- data.frame(g = "A", ind = rep(c("well", "ill", "income"), each = 2), per = rep(c("t1", "t2"), 3),
                  est = c(50, 55, 20, 18, 30, 31), lo = c(46, 51, 18, 16, 28, 29), hi = c(54, 59, 22, 20, 32, 33))
  r <- healchg(d, "g", "ind", "per", "est", "lo", "hi", "t1", "t2", well = "well", distress = "ill")
  expect_identical(r$side[match(c("well", "ill", "income"), r$indicator)], c("wellness", "distress", "other"))
  r2 <- healchg(d, "g", "ind", "per", "est", "lo", "hi", "t1", "t2", well = "well")
  expect_identical(r2$side[r2$indicator == "income"], "distress")
  d$lo[1] <- 52
  expect_warning(healchg(d, "g", "ind", "per", "est", "lo", "hi", "t1", "t2"), "t1")
})

test_that("commidx() keeps its confidence level", {
  d <- data.frame(g = rep(c("A", "B"), each = 2), ind = rep(c("u", "v"), 2), est = c(40, 20, 50, 10),
                  lo = c(36, 17, 46, 8), hi = c(44, 23, 54, 12))
  ci <- commidx(d, "g", "ind", "est", "lo", "hi", w = c(u = 1, v = -1), conflvl = 0.9)
  expect_identical(attr(ci, "conflvl"), 0.9)
})

test_that("stdprev() caps the limit at `scale`, which may be Inf", {
  s <- stdprev(c(98, 99), c(95, 96), c(100, 100), c(0.5, 0.5))
  expect_lte(s$upper, 100)
  r <- stdprev(c(98, 99), c(95, 96), c(101, 102), c(0.5, 0.5), scale = Inf)
  expect_gt(r$upper, 100)
})

test_that("profshr(): rounding base and the on-reserve full canvass", {
  p <- cnsprof(indiex("censuspop"))
  a <- profshr(p, "Foster children", "Total - Children in census families")
  b <- profshr(p, "Foster children", "Total - Children in census families", roubase = 1)
  ok <- is.finite(a$lower) & is.finite(b$lower) & a$estimate > 0
  expect_true(all(b$upper[ok] - b$lower[ok] <= a$upper[ok] - a$lower[ok] + 1e-12))
  on <- a$residence == "On reserve" & ok
  if (any(on)) {
    c4 <- profshr(p, "Foster children", "Total - Children in census families", smpfrac = 0.5)
    expect_equal(c4$lower[on], a$lower[on])
  }
  expect_error(profshr(p, "Foster children", roubase = 0), "roubase")
})

test_that("cnscwb(): minpop and the DGUID column", {
  p <- cnsprof(indiex("censuspop"))
  h <- cnsprof(indiex("censushh"))
  cw <- cnscwb(p, h, minpop = 65)
  expect_true("dguid" %in% names(cw))
  expect_true(all(is.na(cw$cwb[is.finite(cw$population) & cw$population < 65])))
  expect_error(cnscwb(p, h, minpop = -1), "minpop")
})

test_that("trchlthgap(): a different reference, and duplicates warn", {
  hi <- indiex("health")
  g <- trchlthgap(hi, NULL, NULL, NULL)
  expect_true(all(c("disratio", "lower", "upper") %in% names(g)))
  expect_error(trchlthgap(hi, NULL, NULL, NULL, ref = "Nobody"), "\"Nobody\"")
  dup <- rbind(hi, hi[hi$indicator == "Diabetes", ])
  expect_warning(g2 <- trchlthgap(dup, NULL, NULL, NULL), "Diabetes .*more than one row per group")
  expect_false("Diabetes" %in% g2$measure)
})
