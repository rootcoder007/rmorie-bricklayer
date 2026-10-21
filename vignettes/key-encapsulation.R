## ----include = FALSE----------------------------------------------------------
# chunks run when the vignette is built (R CMD build, r-universe, pkgdown) and are skipped when
# R CMD check re-builds it (R sets _R_CHECK_PACKAGE_NAME_ there), unless NOT_CRAN is true
knitr::opts_chunk$set(eval = identical(Sys.getenv("NOT_CRAN"), "true") ||
                        !nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_")))
knitr::opts_chunk$set(collapse = TRUE, comment = "#>")
library(rmoriebricklayer)


## ----mlkem--------------------------------------------------------------------
key <- kemkg(768)
pub <- kempubkey(key)

# the sender holds only the public key
sent <- kemencap(pub)
# the recipient recovers the same secret from the ciphertext
got <- kemdecap(key, sent$ciphertext)
identical(sent$shared, got)


## ----sizes--------------------------------------------------------------------
kemsz(512)
kemsz(768)
kemsz(1024)


## ----reject-------------------------------------------------------------------
bad <- sent$ciphertext
substring(bad, 1L, 2L) <- "00"
other <- kemdecap(key, bad)
nchar(other) == 64L          # a 32-byte secret, as always
identical(other, got)        # but not the one the sender has


## ----masked-------------------------------------------------------------------
identical(kemdecap(key, sent$ciphertext, masked = FALSE), got)
identical(kemdecap(key, bad, masked = FALSE), other)


## ----hqc----------------------------------------------------------------------
hkey <- hqckg(1)
hpub <- hqcpubkey(hkey)

hsent <- hqcencap(hpub)
identical(hqcdecap(hkey, hsent$ciphertext), hsent$shared)
hqcsz(1)


## ----hqc-r4-------------------------------------------------------------------
old <- hqckg(1, ver = "round4")
cap <- hqcencap(hqcpubkey(old))
identical(hqcdecap(old, cap$ciphertext), cap$shared)


## ----seed---------------------------------------------------------------------
identical(hqckg(1, seed = as.raw(1:32))$public,
          hqckg(1, seed = as.raw(1:32))$public)


## ----use----------------------------------------------------------------------
tag <- chmac(sent$shared, "the capsule manifest")
cdgsteq(tag, chmac(got, "the capsule manifest"))


## ----indigenous-kem-----------------------------------------------------------
steward <- kemkg(768)
pub <- kempubkey(steward)
sent <- kemencap(pub)
msg <- tojs(indiex("wellbeing"))
# the shared secret keys an authentication tag the steward can recompute
tag <- chmac(msg, sent$shared)
identical(chmac(msg, kemdecap(steward, sent$ciphertext)), tag)


## ----kem-sizes-plot, fig.width = 7, fig.height = 4.5--------------------------
sz <- rbind(
  "ML-KEM-512" = kemsz(512L)[c("public", "ciphertext")],
  "ML-KEM-768" = kemsz(768L)[c("public", "ciphertext")],
  "ML-KEM-1024" = kemsz(1024L)[c("public", "ciphertext")],
  "HQC-1" = hqcsz(1L)[c("public", "ciphertext")],
  "HQC-3" = hqcsz(3L)[c("public", "ciphertext")],
  "HQC-5" = hqcsz(5L)[c("public", "ciphertext")]
)
op <- par(mar = c(7, 5, 3, 1))
barplot(t(sz), beside = TRUE, col = blpal()[1:2], ylab = "bytes", las = 2, cex.names = 0.8,
        legend.text = c("public key", "ciphertext"), args.legend = list(x = "topleft", bty = "n"),
        main = "Key and ciphertext sizes")
par(op)

