#' Registers the vignette engine of the prebuilt vignettes.
#'
#' Each vignette ships with its output: vignettes/NAME.Rmd (the source), NAME.html (built from it by
#' dev/build_vignettes.R, every figure included) and NAME.R (its R code, extracted with
#' knitr::purl). Weaving returns the HTML as it is, so R CMD check does not run the analyses again;
#' tangling returns the R code, so the source, the R code and the HTML are all listed. R CMD build
#' moves the outputs into inst/doc, where a later rebuild (the one R CMD check runs) finds them.
#' @return The engine, invisibly.
#' @noRd
.bl_register_vignette_engine <- function() {
  prebuilt <- function(name, what) {
    if (file.exists(name)) return(name)
    built <- file.path("..", "inst", "doc", name)
    if (!file.exists(built)) {
      stop("the ", what, " ", name, " is missing: run dev/build_vignettes.R", call. = FALSE)
    }
    file.copy(built, name, overwrite = TRUE)
    name
  }
  tools::vignetteEngine("prebuilt", package = "rmoriebricklayer", pattern = "[.]Rmd$",
                        weave = function(file, ...) {
                          prebuilt(sub("[.]Rmd$", ".html", basename(file)), "built vignette")
                        },
                        tangle = function(file, ...) {
                          prebuilt(sub("[.]Rmd$", ".R", basename(file)), "R code of the vignette")
                        })
}
