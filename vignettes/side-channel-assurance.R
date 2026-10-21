## ----include = FALSE----------------------------------------------------------
# chunks run when the vignette is built (R CMD build, r-universe, pkgdown) and are skipped when
# R CMD check re-builds it (R sets _R_CHECK_PACKAGE_NAME_ there), unless NOT_CRAN is true
knitr::opts_chunk$set(eval = identical(Sys.getenv("NOT_CRAN"), "true") ||
                        !nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_")))
knitr::opts_chunk$set(collapse = TRUE, comment = "#>")
library(rmoriebricklayer)


## ----harnesses----------------------------------------------------------------
list.files(system.file(package = "rmoriebricklayer"), pattern = "^(ctcheck|dudect|tvla|fuzz)$")


## ----agree--------------------------------------------------------------------
key <- kemkg(512)
sent <- kemencap(kempubkey(key))
identical(kemdecap(key, sent$ciphertext, masked = TRUE),
          kemdecap(key, sent$ciphertext, masked = FALSE))

skey <- fipskg("ML-DSA-44")
sig <- cpssign("manifest", skey, determ = TRUE)
cpsvrf("manifest", sig, fipspubkey(skey))


## ----tvla-readme--------------------------------------------------------------
readLines(system.file("tvla", "README.md", package = "rmoriebricklayer"), n = 12)


## ----indigenous-masked--------------------------------------------------------
getOption("rmoriebricklayer.masked", TRUE)


## ----decap-timing-plot, fig.width = 7, fig.height = 4.5-----------------------
bad <- sent$ciphertext
substr(bad, 1, 1) <- if (substr(bad, 1, 1) == "0") "1" else "0"  # one hex digit changed
tm <- function(ct) {
  s <- proc.time()[["elapsed"]]
  for (i in 1:200) kemdecap(key, ct)
  (proc.time()[["elapsed"]] - s) / 200 * 1e6
}
honest <- tampered <- numeric(60)
for (k in 1:60) {
  honest[k] <- tm(sent$ciphertext)
  tampered[k] <- tm(bad)
}
plotecdf(c(honest, tampered), rep(c("honest ciphertext", "one digit changed"), each = 60),
         main = "ML-KEM-512 decapsulation time (microseconds)")

