## ----include = FALSE----------------------------------------------------------
# the one-time index record of this vignette stays out of the reader's configuration directory
options(rmoriebricklayer.xmssidxfile = tempfile())
# chunks run when the vignette is built (R CMD build, r-universe, pkgdown) and are skipped when
# R CMD check re-builds it (R sets _R_CHECK_PACKAGE_NAME_ there), unless NOT_CRAN is true
knitr::opts_chunk$set(eval = identical(Sys.getenv("NOT_CRAN"), "true") ||
                        !nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_")))
knitr::opts_chunk$set(collapse = TRUE, comment = "#>")
library(rmoriebricklayer)


## ----mldsa--------------------------------------------------------------------
key <- fipskg("ML-DSA-65")
key$scheme

sig <- cpssign("a manifest digest", key)
cpsvrf("a manifest digest", sig, fipspubkey(key))


## ----mldsa-tamper-------------------------------------------------------------
cpsvrf("a manifest digest (edited)", sig, fipspubkey(key))


## ----context------------------------------------------------------------------
sig2 <- cpssign("a manifest digest", key, ctx = "release")
cpsvrf("a manifest digest", sig2, key, ctx = "release")
cpsvrf("a manifest digest", sig2, key, ctx = "staging")


## ----deterministic------------------------------------------------------------
s1 <- cpssign("same message", key, determ = TRUE)
s2 <- cpssign("same message", key, determ = TRUE)
identical(s1$signature, s2$signature)

h1 <- cpssign("same message", key)
h2 <- cpssign("same message", key)
identical(h1$signature, h2$signature)


## ----mu-----------------------------------------------------------------------
mu <- fipsmu(fipspubkey(key), "a manifest digest", ctx = "release")
sig3 <- fipssignmu(key, mu)
fipsvrfmu(key, mu, sig3)
# the same signature verifies the ordinary way
cpsvrf("a manifest digest", sig3, key, ctx = "release")


## ----slh----------------------------------------------------------------------
fipssz("ML-DSA-65")
fipssz("SLH-DSA-SHAKE-128f")


## ----slh-size-----------------------------------------------------------------
fipssz("SLH-DSA-SHAKE-128f")[["signature"]] > fipssz("ML-DSA-44")[["signature"]]


## ----slh-sign-----------------------------------------------------------------
hkey <- fipskg("SLH-DSA-SHAKE-128f")
hsig <- cpssign("a manifest digest", hkey)
cpsvrf("a manifest digest", hsig, fipspubkey(hkey))


## ----prehash------------------------------------------------------------------
p <- cpssign("a large artifact", key, prehash = "sha512")
cpsvrf("a large artifact", p, key, prehash = "sha512")
cpsvrf("a large artifact", p, key, prehash = "sha3_512")


## ----xmss---------------------------------------------------------------------
xkey <- pqckg(height = 3)
xkey$capacity
xkey$next_index

s1 <- cpssign("manifest-1", xkey)
cpsvrf("manifest-1", s1, signpubkey(xkey))

xkey <- xmssadv(xkey, s1)
xkey$next_index
s2 <- cpssign("manifest-2", xkey)
cpsvrf("manifest-2", s2, signpubkey(xkey))

# a signature does not transfer to another message
cpsvrf("manifest-1", s2, signpubkey(xkey))


## ----xmss-cli-----------------------------------------------------------------
root <- tempfile("capsules-")
for (nm in c("one", "two")) {
  d <- file.path(root, nm)
  dir.create(d, recursive = TRUE)
  utils::write.csv(data.frame(x = 1:3), file.path(d, "data.csv"), row.names = FALSE)
  writeLines('{"resource": {"filename": "data.csv"}}', file.path(d, "data_provenance.json"))
}
kf <- tempfile(fileext = ".json")
writeLines(tojs(unclass(pqckg(height = 4)), auto_unbox = TRUE), kf)
copy <- tempfile(fileext = ".json")
invisible(file.copy(kf, copy))   # an old copy of the key, kept by mistake

status <- blcli(c("sign", root, "--scheme", "xmss-sha256", "--key-file", kf, "--json"),
                out = function(s) NULL)
status
state <- fromjs(paste(readLines(kf), collapse = "\n"))
state$next_index                # two capsules signed, two indices used
state$used$generation

# the old copy is refused: the bundles show indices it does not know are used
blcli(c("sign", root, "--scheme", "xmss-sha256", "--key-file", copy, "--overwrite"),
      out = function(s) cat(s[grepl("stale", s)]))
xmssidxseen(root)[, c("index", "reused")]


## ----wrong--------------------------------------------------------------------
pub <- fipspubkey(key)
bad <- sig
bad$signature <- paste0("ff", substring(bad$signature, 3))
cpsvrf("a manifest digest", bad, pub)
trunc <- sig
trunc$signature <- substring(sig$signature, 1, 64)
cpsvrf("a manifest digest", trunc, pub)
cpsvrf("a manifest digest", sig, fipspubkey(fipskg("ML-DSA-65")))


## ----indigenous-sign----------------------------------------------------------
key <- fipskg("ML-DSA-65")
d <- indiex("mentalhealth")
msg <- dgstobj(d)
sig <- cpssign(msg, key)
cpsvrf(msg, sig, fipspubkey(key))


## ----signature-sizes-plot, fig.width = 7, fig.height = 4.5--------------------
sch <- c("ML-DSA-44", "ML-DSA-65", "ML-DSA-87", "SLH-DSA-SHA2-128f", "SLH-DSA-SHAKE-128s")
sz <- t(vapply(sch, function(s) fipssz(s)[c("public_key", "signature")], numeric(2)))
op <- par(mar = c(9, 5, 3, 1))
barplot(t(sz), beside = TRUE, log = "y", ylim = c(10, 2 * max(sz)), col = blpal()[1:2],
        ylab = "bytes (log scale)", las = 2, cex.names = 0.8, legend.text = c("public key", "signature"),
        args.legend = list(x = "topleft", bty = "n"), main = "Key and signature sizes")
par(op)

