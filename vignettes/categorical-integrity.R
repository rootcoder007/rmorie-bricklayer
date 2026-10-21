## ----include = FALSE----------------------------------------------------------
# the one-time index record of this vignette stays out of the reader's configuration directory
options(rmoriebricklayer.xmssidxfile = tempfile())
# chunks run when the vignette is built (R CMD build, r-universe, pkgdown) and are skipped when
# R CMD check re-builds it (R sets _R_CHECK_PACKAGE_NAME_ there), unless NOT_CRAN is true
knitr::opts_chunk$set(eval = identical(Sys.getenv("NOT_CRAN"), "true") ||
                        !nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_")))
knitr::opts_chunk$set(collapse = TRUE, comment = "#>")
library(rmoriebricklayer)


## -----------------------------------------------------------------------------
tab <- matrix(c(9000, 120, 2000, 220, 1500, 60, 4000, 1), ncol = 2, byrow = TRUE,
              dimnames = list(c("White", "Black", "Other", "Unknown"), c("no", "yes")))
tab
ref <- 120 / 9000
orchk(tab, "White", c(Black = 220 / 2000 / ref, Other = 60 / 1500 / ref,
                                 Unknown = 1 / 4000 / ref))$verdict


## -----------------------------------------------------------------------------
rotated <- tab[c("Unknown", "White", "Black", "Other"), ]
rownames(rotated) <- rownames(tab)
rref <- rotated["White", 2] / rotated["White", 1]
reported <- c(Black = rotated["Black", 2] / rotated["Black", 1] / rref,
              Other = rotated["Other", 2] / rotated["Other", 1] / rref,
              Unknown = rotated["Unknown", 2] / rotated["Unknown", 1] / rref)
round(reported, 1)
r <- orchk(tab, "White", reported)
r$consistent
r$matches
r$verdict


## -----------------------------------------------------------------------------
orchk(tab, "White", c(Black = 36, Other = 4, Unknown = 1))$verdict


## -----------------------------------------------------------------------------
raw <- data.frame(race = c(1, 2, 2, 3, 1), stringsAsFactors = FALSE)
audcats(data.frame(race = factor(raw$race)))
race <- deccodes(raw$race, c("1" = "White", "2" = "Black", "3" = "Indigenous"))
race


## -----------------------------------------------------------------------------
x <- c("W", "B", "W", "I", "B")
y <- grdrcd(x, c(W = "White", B = "Black", I = "Indigenous"))
vrfrcd(x, y, c(W = "White", B = "Black", I = "Indigenous"))
grdlvls(y, c("White", "Black", "Indigenous"), ref = "White")


## ----error = TRUE-------------------------------------------------------------
try({
vrfrcd(c("W", "B"), c("Black", "White"), c(W = "White", B = "Black"))
})


## ----error = TRUE-------------------------------------------------------------
try({
vrfmrg(y, c(White = 2, Black = 2, Indigenous = 1))
vrfmrg(y, c(White = 2, Black = 1, Indigenous = 2))
})


## -----------------------------------------------------------------------------
key <- pqckg(height = 2)
m <- rcdmnf(x, y, c(W = "White", B = "Black", I = "Indigenous"),
                     pub = c(White = 2, Black = 2, Indigenous = 1),
                     key = key, ctx = "vignette")
p <- wrrcdmnf(m, tempfile(fileext = ".json"))
vrfrcdmnf(p, x, y)[c("ok", "signature_ok")]


## -----------------------------------------------------------------------------
yswapped <- as.character(y)
yswapped[yswapped == "Black"] <- "Indigenous"
vrfrcdmnf(p, x, yswapped)[c("ok", "reasons")]


## ----error = TRUE-------------------------------------------------------------
try({
grdbin(c("treated", "control"), "treatment")
})


## -----------------------------------------------------------------------------
arrived <- structure(c(1, 1, 2, 4, 1, 3, 1, 2),
                     labels = c(White = 1, Black = 2, Other = 3, Unknown = 4))
code_book <- c("1" = "White", "2" = "Black", "3" = "Other", "4" = "Unknown")
spssfre <- c(White = 4, Black = 2, Other = 1, Unknown = 1)
chk <- xfrvrf(arrived, spssfre, codebook = code_book)
chk$ok
levels(chk$decoded)


## -----------------------------------------------------------------------------
f <- factor(c(1, 2, 3, 4, 1))
levels(f) <- sort(unname(code_book))
data.frame(code = c(1, 2, 3, 4, 1), became = as.character(f))


## ----error = TRUE-------------------------------------------------------------
try({
relbl(factor(c(1, 2, 3, 4, 1)), sort(unname(code_book)))
relbl(factor(c(1, 2, 3, 4, 1)), code_book)
})


## ----error = TRUE-------------------------------------------------------------
try({
xfrvrf(as.character(f), c(White = 2, Black = 1, Other = 1, Unknown = 1))
})


## -----------------------------------------------------------------------------
observed <- c(White = "Black", Black = "Other", Other = "Unknown", Unknown = "White")
rlblfrns(code_book, observed)


## ----rotation-plot, fig.width = 7, fig.height = 4.5---------------------------
odds_vs_white <- function(t) (t[, "yes"] / t[, "no"]) / (t["White", "yes"] / t["White", "no"])
r <- rbind(correct = odds_vs_white(tab), rotated = odds_vs_white(rotated))[, -1]
barplot(r, beside = TRUE, log = "y", col = blpal()[c(2, 1)], ylab = "odds ratio vs White (log scale)",
        legend.text = c("correct labels", "labels rotated one place"),
        args.legend = list(x = "topleft", bty = "n"), main = "Same counts, rotated labels")
abline(h = 1, lty = 2)

