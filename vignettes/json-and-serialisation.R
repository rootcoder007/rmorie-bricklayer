## ----include = FALSE----------------------------------------------------------
# chunks run when the vignette is built (R CMD build, r-universe, pkgdown) and are skipped when
# R CMD check re-builds it (R sets _R_CHECK_PACKAGE_NAME_ there), unless NOT_CRAN is true
knitr::opts_chunk$set(eval = identical(Sys.getenv("NOT_CRAN"), "true") ||
                        !nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_")))
knitr::opts_chunk$set(collapse = TRUE, comment = "#>")
library(rmoriebricklayer)


## ----encode-------------------------------------------------------------------
tojs(list(a = 1:3, b = "x"), auto_unbox = TRUE)
tojs(data.frame(id = 1:2, v = c(1.5, NA)), pretty = TRUE)


## ----parse--------------------------------------------------------------------
txt <- '{"id":[1,2,3],"name":["a","b","c"],"ok":true}'
str(fromjs(txt))
str(fromjs(txt, simplifyVector = FALSE))


## ----dup----------------------------------------------------------------------
try(fromjs('{"a":1,"a":2}'))
fromjs('{"a":1,"a":2}', duplicate_keys = "keep")


## ----bigint-------------------------------------------------------------------
fromjs('{"id": 9007199254740993}', bigint_as_char = TRUE)


## ----serialize----------------------------------------------------------------
f <- factor(c("b", "a", "b"), levels = c("a", "b", "c"))
back <- jsunser(jsser(f))
identical(back, f)

m <- matrix(1:6, nrow = 2)
identical(jsunser(jsser(m)), m)

x <- list(a = 1:3, b = list(c = "x", d = NULL), e = TRUE)
identical(jsunser(jsser(x)), x)


## ----serialize-vs-------------------------------------------------------------
tojs(f)


## ----digits-------------------------------------------------------------------
jsser(1 / 3)
exact <- jsser(1 / 3, digits = I(17))
identical(jsunser(exact), 1 / 3)


## ----pin----------------------------------------------------------------------
csha256(jsser(m))


## ----gzip---------------------------------------------------------------------
x <- list(rows = data.frame(id = 1:50, value = round(stats::runif(50), 3)))
enc <- jsgzenc(x)
substring(enc, 1, 40)
c(json = nchar(tojs(x)), gzipb64 = nchar(enc))
identical(jsgzdec(enc)$rows$id, 1:50)


## ----b64----------------------------------------------------------------------
jsb64enc(charToRaw("manifest"))
rawToChar(jsb64dec("bWFuaWZlc3Q="))


## ----indigenous-json----------------------------------------------------------
d <- indiex("infantmort")
js <- tojs(d[d$period == "2014/2016", ], auto_unbox = TRUE)
substring(js, 1, 200)
back <- fromjs(js)
all.equal(back$estimate, d$estimate[d$period == "2014/2016"])


## ----json-roundtrip-plot, fig.width = 7, fig.height = 4.5---------------------
o <- order(back$estimate)
t1 <- back[o, ]
yy <- seq_len(nrow(t1))
op <- par(mar = c(4, 16, 3, 1))
plot(t1$estimate, yy, xlim = range(t1$lower, t1$upper), yaxt = "n", pch = 19, col = blpal()[1],
     xlab = "estimate and 95% interval", ylab = "", main = t1$measure[1])
segments(t1$lower, yy, t1$upper, yy, col = blpal()[1])
axis(2, yy, t1$group, las = 1, cex.axis = 0.7)
par(op)

