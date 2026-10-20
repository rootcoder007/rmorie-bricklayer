# The manual's figures of 1.0.0: titles drawn straight by the base call ran off the panel, dense
# rows lost every other label, and two labels cut to the same text were numbered.

test_that("labels cut to the same text keep the part that tells them apart", {
  f <- rmoriebricklayer:::.bl_short_label
  x <- c("Life satisfaction rating of 8, 9 or 10", "Life satisfaction rating between 0 and 5")
  expect_identical(f(x, 20L), c("...of 8, 9 or 10", "...between 0 and 5"))
  expect_identical(f(x, 60L), x)
  # ends that collide once cut: numbered, as before
  y <- c("Prefix shared aaaaaaaaaaaaaaaaaaaaaaaaX", "Prefix shared aaaaaaaaaaaaaaaaaaaaaaaaY")
  z <- f(y, 12L)
  expect_true(all(grepl("\\.\\.\\.#[12]$", z)))
  expect_false(anyDuplicated(z) > 0)
  expect_identical(rmoriebricklayer:::.bl_common_start(c("ab cd ef", "ab cd gh")), 6L)
  expect_identical(rmoriebricklayer:::.bl_common_start(c("abc", "xyz")), 0L)
})

test_that(".bl_row_labels() sizes the text to the row instead of leaving labels out", {
  grDevices::pdf(NULL, width = 6.5, height = 4.6)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::plot(1, 1, type = "n", ylim = c(0.5, 44.5), yaxt = "n")
  cex <- rmoriebricklayer:::.bl_row_labels(1:44, sprintf("row %d", 1:44))
  expect_lt(cex, 0.85)
  expect_gte(cex, 0.6)
  graphics::plot(1, 1, type = "n", ylim = c(0.5, 4.5), yaxt = "n")
  expect_identical(rmoriebricklayer:::.bl_row_labels(1:4, letters[1:4]), 0.85)
})

test_that("plot.rmbl_trc_gaps() draws with a key under the panel", {
  grDevices::pdf(NULL, width = 6.5, height = 4.6)
  on.exit(grDevices::dev.off(), add = TRUE)
  d <- plot(trchlthgap())
  expect_true(all(c("group", "disratio") %in% names(d)))
})

test_that("the methods that drew their title straight now fit it to the panel", {
  seen <- character()
  local_mocked_bindings(.bl_title = function(title) {
    seen <<- c(seen, as.character(title))
    invisible(title)
  }, .package = "rmoriebricklayer")
  grDevices::pdf(NULL, width = 3, height = 3)
  on.exit(grDevices::dev.off(), add = TRUE)
  plot(cnscwb(cnsprof(indiex("censuspop")), cnsprof(indiex("censushh"))))
  expect_true("Community Well-Being, by place and group" %in% seen)
  plot(cnscwb(cnsprof(indiex("censuspop")), cnsprof(indiex("censushh"))), main = "My title")
  expect_true("My title" %in% seen)
})

test_that("a column subset of a yoy() result prints its rows, not \"no periods\"", {
  y <- yoy(data.frame(year = 2018:2021, n = c(40, 44, 41, 55)), value = "n", prd = "year")
  out <- capture.output(print(y[1:3, c("year", "pctchg")]))
  expect_false(any(grepl("no periods", out)))
  expect_true(any(grepl("pctchg", out)))
  expect_identical(capture.output(print(y[0, ])), "<rmbl_yoy: no periods>")
})
