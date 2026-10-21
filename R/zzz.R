# Registers the vignette engine of the prebuilt vignettes (R/vignette_engine.R).
.onLoad <- function(libname, pkgname) {
  .bl_register_vignette_engine()
}
