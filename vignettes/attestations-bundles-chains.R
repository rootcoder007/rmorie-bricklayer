## ----include = FALSE----------------------------------------------------------
# the one-time index record of this vignette stays out of the reader's configuration directory
options(rmoriebricklayer.xmssidxfile = tempfile())
# chunks run when the vignette is built (R CMD build, r-universe, pkgdown) and are skipped when
# R CMD check re-builds it (R sets _R_CHECK_PACKAGE_NAME_ there), unless NOT_CRAN is true
knitr::opts_chunk$set(eval = identical(Sys.getenv("NOT_CRAN"), "true") ||
                        !nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_")))
knitr::opts_chunk$set(collapse = TRUE, comment = "#>")
library(rmoriebricklayer)


## ----attest-------------------------------------------------------------------
m <- mkmnf(list(dataset = "otis", rows = 1200L), env = FALSE)
key <- fipskg("ML-DSA-65")
att <- cpsatst(m, key, note = "counts as published")

res <- cpschkatst(att, m)
res$ok
res$checks


## ----attest-break-------------------------------------------------------------
m2 <- m
m2$meta$rows <- 1201L
cpschkatst(att, m2)$ok

cpschkatst(att, m, keyexp = fipskg("ML-DSA-65")$public)$ok


## ----bundle-------------------------------------------------------------------
dir <- tempfile()
dir.create(dir)
write.csv(data.frame(x = 1:3), file.path(dir, "data.csv"), row.names = FALSE)
m <- mkmnf(list(dataset = "demo"), env = FALSE)
key <- fipskg("ML-DSA-44")

b <- cpsbndl(dir, m, key, note = "as published")
cpsbndlvrf(attr(b, "path"), dir, man = m)$ok


## ----bundle-break-------------------------------------------------------------
write.csv(data.frame(x = 1:4), file.path(dir, "data.csv"), row.names = FALSE)
v <- cpsbndlvrf(attr(b, "path"), dir, man = m)
v$ok


## ----bundle-read--------------------------------------------------------------
cpsbndlrd(attr(b, "path"))$attestation$note
unlink(dir, recursive = TRUE)


## ----chain--------------------------------------------------------------------
ch <- chnnew()
ch <- chnapp(ch, "manifest for run 1", label = "run-1")
ch <- chnapp(ch, "manifest for run 2", label = "run-2")
ch <- chnapp(ch, "manifest for run 3", label = "run-3")
chnvrf(ch)$valid


## ----chain-edit---------------------------------------------------------------
edited <- ch
edited$entries[[2]]$digest <- csha256("something else")
chnvrf(edited)$valid
chnvrf(edited)$broken_at


## ----chain-drop---------------------------------------------------------------
dropped <- ch
dropped$entries[[2]] <- NULL
chnvrf(dropped)$valid


## ----seal---------------------------------------------------------------------
key <- fipskg("ML-DSA-44")
sig <- cpssign(chnseal(ch), key)
cpsvrf(chnseal(ch), sig, fipspubkey(key))

truncated <- ch
truncated$entries[[3]] <- NULL
cpsvrf(chnseal(truncated), sig, fipspubkey(key))


## ----seal-none----------------------------------------------------------------
chnseal(dropped)


## ----indigenous-chain---------------------------------------------------------
ch <- chnnew()
for (nm in c("health", "mentalhealth", "wellbeing")) {
  d <- indiex(nm)
  ch <- chnapp(ch, list(table = nm, rows = nrow(d), sha256 = dgstobj(d)),
                     label = nm)
}
chnvrf(ch)$valid


## ----chain-table-plot, fig.width = 7, fig.height = 4.5------------------------
ci_plot <- function(t, lab, main) {
  o <- order(t$estimate)
  t <- t[o, ]
  y <- seq_len(nrow(t))
  op <- par(mar = c(4, 10, 3, 1))
  on.exit(par(op))
  plot(t$estimate, y, xlim = range(t$lower, t$upper, na.rm = TRUE), yaxt = "n", pch = 19,
       col = blpal()[1], xlab = "estimate and 95% interval", ylab = "", main = main)
  segments(t$lower, y, t$upper, y, col = blpal()[1])
  axis(2, y, lab[o], las = 1, cex.axis = 0.7)
}
t1 <- d[d$indicator == d$indicator[1], ]
ci_plot(t1, t1$group, t1$indicator[1])

