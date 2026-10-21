## ----include = FALSE----------------------------------------------------------
# the one-time index record of this vignette stays out of the reader's configuration directory
options(rmoriebricklayer.xmssidxfile = tempfile())
# chunks run when the vignette is built (R CMD build, r-universe, pkgdown) and are skipped when
# R CMD check re-builds it (R sets _R_CHECK_PACKAGE_NAME_ there), unless NOT_CRAN is true
knitr::opts_chunk$set(eval = identical(Sys.getenv("NOT_CRAN"), "true") ||
                        !nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_")))
knitr::opts_chunk$set(collapse = TRUE, comment = "#>")
library(rmoriebricklayer)


## ----digests------------------------------------------------------------------
csha256("hello capsule")
csha512("hello capsule")
cblake2b("hello capsule")
ccrc32("hello capsule")


## ----files--------------------------------------------------------------------
f <- tempfile()
writeLines("hello capsule", f)
sha256file(f)
sha512file(f)
crc32file(f)

before <- sha256file(f)
writeLines("hello capsule (edited)", f)
sha256file(f) == before


## ----objects------------------------------------------------------------------
dgstobj(list(a = 1L, b = "x"))
identical(dgstobj(1:10), dgstobj(1:10))
dgstobj(1:10) == dgstobj(1:11)
dgstobj(matrix(1:6, nrow = 2)) == dgstobj(1:6)   # dimensions count
dgstobj(data.frame(x = 1:3))


## ----hmac---------------------------------------------------------------------
chmac("Jefe", "what do ya want for nothing?")   # RFC 4231 test case 2
chmac("key-a", "manifest")
chmac("key-b", "manifest")


## ----ct-----------------------------------------------------------------------
tag <- chmac("k", "m")
cdgsteq(tag, chmac("k", "m"))
cdgsteq(tag, chmac("k", "tampered"))
cdgsteq(tag, "too-short")


## ----pbkdf2-------------------------------------------------------------------
drvkey("password", "salt", iter = 1)     # the published test vector
identical(drvkey("pw", "s", 1000), drvkey("pw", "s", 1000))
drvkey("pw", "salt-a", 1000) == drvkey("pw", "salt-b", 1000)


## ----pbkdf2-sign--------------------------------------------------------------
salt <- paste(format(rndbytes(16)), collapse = "")
key <- drvkey("correct horse battery staple", salt)
sig <- cpssign("manifest-digest", key, scheme = "hmac")
cpsvrf("manifest-digest", sig, key)


## ----random-------------------------------------------------------------------
set.seed(1)
a <- stats::runif(1)
set.seed(1)
invisible(rndbytes(32))
identical(stats::runif(1), a)


## ----drbg---------------------------------------------------------------------
d <- drbgnew(as.raw(0:47))
drbggen(d, 16)
a <- drbgnew(as.raw(1:48), person = charToRaw("session 1"))
b <- drbgnew(as.raw(1:48), person = charToRaw("session 2"))
identical(drbggen(a, 16), drbggen(b, 16))


## ----merkle-------------------------------------------------------------------
chunks <- c("row1,row2", "row3,row4", "row5,row6", "row7,row8")
root <- mrkroot(chunks)
root

before <- mrklvs(chunks)
after <- mrklvs(c(chunks[1:2], "row5,row6-EDITED", chunks[4]))
which(before != after)

pr <- mrkprf(chunks, 3)
mrkvrf(chunks[3], pr, root)
mrkvrf("row5,row6-EDITED", pr, root)


## ----chunkfile----------------------------------------------------------------
p <- tempfile()
writeLines(rep("some capsule content", 50), p)
ch <- chnkfile(p, chnkbytes = 128)
length(ch)
mrkroot(ch)
identical(unlist(ch), readBin(p, "raw", file.size(p)))


## ----indigenous-hash----------------------------------------------------------
d <- indiex("suicide")
dgstobj(d)
rows <- apply(d, 1, paste, collapse = ",")
root <- mrkroot(rows)
proof <- mrkprf(rows, 3)
mrkvrf(rows[3], proof, root)


## ----hashed-table-plot, fig.width = 7, fig.height = 4.5-----------------------
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
t1 <- d[d$measure == d$measure[1], ]
ci_plot(t1, paste(t1$group, t1$age), t1$measure[1])

