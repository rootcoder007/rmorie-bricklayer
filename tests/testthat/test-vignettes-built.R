# Every vignette ships built (R/vignette_engine.R): its HTML and R code must exist and the HTML must
# have been built from the source as it is now (dev/build_vignettes.R stamps the source's SHA-256).
test_that("every vignette's HTML and R code are built from its current source", {
  skip_on_cran()
  vdir <- NA_character_
  for (p in c("../../vignettes", "../../../vignettes", "vignettes")) if (dir.exists(p)) vdir <- p
  skip_if(is.na(vdir), "package sources not available from here")
  rmds <- list.files(vdir, pattern = "[.]Rmd$", full.names = TRUE)
  expect_gt(length(rmds), 30L)
  for (rmd in rmds) {
    base <- sub("[.]Rmd$", "", rmd)
    expect_true(file.exists(paste0(base, ".R")), info = basename(rmd))
    html <- paste0(base, ".html")
    expect_true(file.exists(html), info = basename(rmd))
    if (!file.exists(html)) next
    stamp <- sub("^<!-- rmoriebricklayer vignette source sha256: ([0-9a-f]{64}) -->$", "\\1", readLines(html, n = 1L))
    expect_identical(stamp, sha256file(rmd), info = paste(basename(rmd), "changed since its HTML was built: run dev/build_vignettes.R"))
  }
})
