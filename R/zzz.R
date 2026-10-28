# Whether the help-page examples run (each one is wrapped in @examplesIf
# isTRUE(getOption("rmbl.examples"))): in an interactive session, in GitHub CI
# (NOT_CRAN), on r-universe (MY_UNIVERSE) and on the package website
# (IN_PKGDOWN), but not in CRAN's check, which runs them within a ten-minute
# limit. An option the user has set is left as it is.
.rmbl_examples_default <- function(libname, pkgname) {
  if (is.null(getOption("rmbl.examples"))) {
    options(
      rmbl.examples = interactive() ||
        any(nzchar(Sys.getenv(c("NOT_CRAN", "MY_UNIVERSE", "IN_PKGDOWN"))))
    )
  }
}

.onLoad <- function(libname, pkgname) {
  .rmbl_examples_default(libname, pkgname)
  # Date + perdays(): without this R warns of incompatible methods
  if (exists("chooseOpsMethod", envir = baseenv())) {
    registerS3method(
      "chooseOpsMethod", "rmbl_measure", .rmbl_measure_choose,
      envir = baseenv()
    )
  }
}
