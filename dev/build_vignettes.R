# Builds the vignettes: vignettes/NAME.html (with every figure) and vignettes/NAME.R (the R code)
# from each vignettes/NAME.Rmd, and stamps the HTML with the SHA-256 of the source it was built
# from (test-vignettes-built.R fails when a source has changed since). Run from the package
# directory with the package installed: Rscript dev/build_vignettes.R [NAME ...]
args <- commandArgs(trailingOnly = TRUE)
rmds <- list.files("vignettes", pattern = "[.]Rmd$", full.names = TRUE)
if (length(args)) rmds <- rmds[sub("[.]Rmd$", "", basename(rmds)) %in% args]
stopifnot(length(rmds) > 0L)
Sys.unsetenv("_R_CHECK_PACKAGE_NAME_")
for (rmd in rmds) {
  name <- sub("[.]Rmd$", "", basename(rmd))
  html <- file.path("vignettes", paste0(name, ".html"))
  rmarkdown::render(rmd, output_format = rmarkdown::html_vignette(), output_file = basename(html),
                    output_dir = "vignettes", envir = new.env(), quiet = TRUE)
  knitr::purl(rmd, output = file.path("vignettes", paste0(name, ".R")), quiet = TRUE, documentation = 1)
  sha <- rmoriebricklayer::sha256file(rmd)
  h <- readLines(html, warn = FALSE, encoding = "UTF-8")
  h <- h[!grepl("^<!-- rmoriebricklayer vignette source sha256: ", h)]
  writeLines(c(sprintf("<!-- rmoriebricklayer vignette source sha256: %s -->", sha), h), html, useBytes = TRUE)
  cat(sprintf("%-40s %d figures\n", name, sum(lengths(regmatches(h, gregexpr("data:image/png;base64", h))))))
}
