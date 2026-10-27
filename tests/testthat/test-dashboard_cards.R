# SPDX-License-Identifier: AGPL-3.0-or-later

test_that(".bl_num() formats a number for a card", {
  expect_null(.bl_num(NULL))
  expect_null(.bl_num(NA))
  expect_identical(.bl_num(1234.5678), "1,235")
  expect_identical(.bl_num(1234.5678, big = FALSE), "1235")
  expect_identical(.bl_num(0.5, 3L), "0.5")
  expect_identical(.bl_num(0.00001234), "1.23e-05")
})

test_that(".bl_effect_lines() reads each kind of effect size", {
  expect_length(.bl_effect_lines(list()), 0L)
  expect_match(.bl_effect_lines(list(smd = c(0.02, 0.3))), "not balanced")
  expect_match(.bl_effect_lines(list(cramerv = 0.35)), "moderate association")
  expect_match(.bl_effect_lines(list(i2 = 0.8)), "high heterogeneity")
  expect_match(
    .bl_effect_lines(list(correlation = c(0.05, -0.6))),
    "Strongest correlation -0.6: large"
  )
  expect_match(.bl_effect_lines(list(rr = 1.25)), "25% higher")
  expect_match(.bl_effect_lines(list(braratio = 0.4)), "about 40%")
  expect_match(.bl_effect_lines(list(kspva = 0.5)), "is consistent with")
  expect_match(
    .bl_effect_lines(list(dispersion = 1, overdispersed = FALSE)),
    "no sign of overdispersion"
  )
  # the lines come in a fixed order, one per effect found
  two <- .bl_effect_lines(list(kspva = 0.01, smd = 0.01))
  expect_length(two, 2L)
  expect_match(two[[1L]], "^Largest standardised")
  expect_match(two[[2L]], "^Time-rescaling")
})

test_that(".bl_cell() and .bl_scalars() lay out a result's fields", {
  expect_identical(.bl_cell(NULL, 4L), "")
  expect_identical(.bl_cell(c(1, NA), 4L), "1, NA")
  expect_identical(.bl_cell(c("a", "b"), 4L), "a, b")
  sc <- .bl_scalars(list(a = 1, b = "x", c = 1:3, d = list(1)))
  expect_identical(sc$field, c("a", "b"))
  expect_identical(sc$value, c("1", "x"))
  expect_identical(nrow(.bl_scalars(data.frame(a = 1))), 0L)
})

test_that(".bl_col_summary() summarises numeric and text columns", {
  s <- .bl_col_summary(c(1, 2, 3, NA))
  expect_identical(s$statistic[1:3], c("rows", "missing", "mean"))
  expect_identical(s$value[1:3], c(4, 1, 2))
  t <- .bl_col_summary(c("a", "b", "b"))
  expect_identical(t$statistic, c("rows", "missing", "distinct", "b", "a"))
  expect_equal(
    t$value,
    c(3, 0, 2, 2, 1),
    tolerance = testthat::testthat_tolerance()
  )
})

test_that(".bl_snaps() and .bl_brush_share() split and count snapshots", {
  d <- data.frame(
    snapshot = rep(c("old", "new"), each = 4),
    x = c(1, 2, 3, 4, 2, 3, 4, 5),
    stringsAsFactors = FALSE
  )
  sn <- .bl_snaps(d)
  expect_named(sn, c("old", "new"))
  expect_named(sn$old, "x")
  sh <- .bl_brush_share(sn, "x", 2, 3)
  expect_identical(sh$rows, c(2, 2))
  expect_identical(sh$share, c(50, 50))
  expect_null(.bl_snaps(d[d$snapshot == "old", ]))
  expect_null(.bl_snaps(data.frame(x = 1)))
})

test_that(".bl_diag_ui() lists the checks and the flag counts", {
  skip_if_not_installed("shiny")
  html <- as.character(.bl_diag_ui(list(
    converged = TRUE,
    table = data.frame(a = 1),
    extra = data.frame(b = 2)
  )))
  expect_match(html, "Checks and statistics", fixed = TRUE)
  expect_match(html, "extra", fixed = TRUE)
  fl <- as.character(.bl_diag_ui(data.frame(
    flag = c("a", "a", "b"),
    stringsAsFactors = FALSE
  )))
  expect_match(fl, "Rows by flag", fixed = TRUE)
  none <- as.character(.bl_diag_ui(data.frame(z = 1)))
  expect_match(none, "no checks beyond its table", fixed = TRUE)
})

test_that("the dark colour mode is undone after each plot (B1)", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  p0 <- graphics::par(c("col", "fg", "col.axis", "col.lab", "mar", "mfrow"))
  .bl_col_plot(c(1, 4, 2, 8, 5), "x", mode = "dark")
  .bl_col_plot(c("a", "b", "a"), "k", mode = "dark")
  expect_identical(
    graphics::par(c("col", "fg", "col.axis", "col.lab", "mar", "mfrow")),
    p0
  )
  op <- .bl_par_mode("dark")
  expect_identical(tolower(graphics::par("fg")), "#e6e3de")
  graphics::par(op)
  expect_identical(graphics::par(c("col", "fg")), p0[c("col", "fg")])
  expect_identical(.bl_par_mode("light"), list())
})
