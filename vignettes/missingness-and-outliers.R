## ----include = FALSE----------------------------------------------------------
# chunks run when the vignette is built (R CMD build, r-universe, pkgdown) and are skipped when
# R CMD check re-builds it (R sets _R_CHECK_PACKAGE_NAME_ there), unless NOT_CRAN is true
knitr::opts_chunk$set(eval = identical(Sys.getenv("NOT_CRAN"), "true") ||
                        !nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_")))
knitr::opts_chunk$set(collapse = TRUE, comment = "#>")
library(rmoriebricklayer)


## ----missing------------------------------------------------------------------
df <- data.frame(a = c(1, NA, 3), b = c(NA, NA, 3), c = 1:3)
misssmry(df)
misssmry(data.frame(x = 1:3, y = 4:6))


## ----pattern------------------------------------------------------------------
set.seed(1)
big <- data.frame(id = 1:40, v = stats::rnorm(40), w = stats::rnorm(40))
big$v[c(10:14, 30)] <- NA
big$w[c(10:14)] <- NA
misspat(big)
missruns(big)


## ----dup----------------------------------------------------------------------
d <- data.frame(id = c(1, 2, 2, 3, 3, 3), x = c("a", "b", "b", "c", "c", "d"))
duprows(d)
duprows(d, cols = "id")


## ----maha---------------------------------------------------------------------
set.seed(1)
n <- 200
df <- data.frame(height = stats::rnorm(n, 170, 10))
df$weight <- df$height * 0.5 + stats::rnorm(n, 0, 5)
df[1, ] <- list(height = 155, weight = 100)      # ordinary on each, unlikely jointly

out <- mahaoutl(df)
head(out, 3)
out$row[1] == 1
range(df$height[-1])
range(df$weight[-1])


## ----maha-robust--------------------------------------------------------------
bad <- df
bad[2:21, ] <- list(height = 150, weight = 110)
dclassical <- mahaoutl(bad, robust = FALSE)
drobust <- mahaoutl(bad, robust = TRUE)
dclassical$distance[dclassical$row == 2] < drobust$distance[drobust$row == 2]


## ----hll----------------------------------------------------------------------
set.seed(1)
x <- sample(1:5000, 200000, replace = TRUE)
dstncnt(dstnskch(x))
length(unique(x))

s <- dstnskch(x[1:100000])
s <- dstnskch(x[100001:200000], regstr = s)
dstncnt(s)

a <- dstnskch(x[1:100000])
b <- dstnskch(x[100001:200000])
dstncnt(skchmrg(a, b))


## ----hll-small----------------------------------------------------------------
dstncnt(dstnskch(c("a", "b", "c", "a", "b")))
dstncnt(dstnskch(character(0)))


## ----benford------------------------------------------------------------------
set.seed(3)
benfordtst(10^stats::runif(2000, 0, 6))$p_value
benfordtst(as.numeric(paste0(sample(1:9, 2000, TRUE), "000")))$p_value


## ----indigenous-missing-------------------------------------------------------
im <- indiex("infantmort")
misssmry(im)
table(im$period, im$quality)


## ----outliers-plots, fig.width = 7, fig.height = 4.5--------------------------
plot(out)
planted <- dclassical$row %in% 2:21
plot(dclassical$distance, drobust$distance[match(dclassical$row, drobust$row)],
     pch = 19, col = ifelse(planted, blpal()[2], blpal()[1]),
     xlab = "classical distance", ylab = "robust distance",
     main = "Planted rows: classical against robust distance")
abline(0, 1, lty = 2)
legend("topleft", c("planted rows", "other rows"), pch = 19, col = blpal()[c(2, 1)], bty = "n")

