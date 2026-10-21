## ----setup, include = FALSE---------------------------------------------------
# the one-time index record of this vignette stays out of the reader's configuration directory
options(rmoriebricklayer.xmssidxfile = tempfile())
# chunks run when the vignette is built (R CMD build, r-universe, pkgdown) and are skipped when
# R CMD check re-builds it (R sets _R_CHECK_PACKAGE_NAME_ there), unless NOT_CRAN is true
knitr::opts_chunk$set(eval = identical(Sys.getenv("NOT_CRAN"), "true") ||
                        !nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_")))
knitr::opts_chunk$set(collapse = TRUE, comment = "#>")
library(rmoriebricklayer)
set.seed(1)


## -----------------------------------------------------------------------------
manifest <- paste0(
  "source=https://example.org/extract.csv\n",
  "sha256=", csha256("id,value\n1,2\n"), "\n",
  "fetched=2026-09-12"
)

sig <- cpssign(csha256(manifest), key = "team-secret",
                    scheme = "hmac")
cpsvrf(csha256(manifest), sig, "team-secret")


## -----------------------------------------------------------------------------
edited <- sub("fetched=2026-09-12", "fetched=2026-01-01", manifest)
cpsvrf(csha256(edited), sig, "team-secret")


## -----------------------------------------------------------------------------
# Fixed here so the vignette is reproducible. For a real key the salt
# comes from rndbytes(16), which reads the operating system's
# CSPRNG rather than R's generator.
salt <- "9f2c41a7d8e05b36"
key <- drvkey("correct horse battery staple", salt)
nchar(key)


## -----------------------------------------------------------------------------
# Small for the vignette; the default height 10 gives 1024 signatures.
signingkey <- pqckg(height = 3)
signingkey


## -----------------------------------------------------------------------------
pub <- signpubkey(signingkey)
pub


## -----------------------------------------------------------------------------
s1 <- cpssign(csha256(manifest), signingkey)
cpsvrf(csha256(manifest), s1, pub)

# A verifier holding only `pub` cannot forge one.
cpsvrf(csha256(edited), s1, pub)


## -----------------------------------------------------------------------------
signingkey <- xmssadv(signingkey, s1)
signingkey$next_index

s2 <- cpssign(csha256("a second manifest"), signingkey)
cpsvrf(csha256("a second manifest"), s2, pub)

# and forward again, for the next signature
signingkey <- xmssadv(signingkey, s2)


## ----error = TRUE-------------------------------------------------------------
try({
k <- pqckg(height = 1)          # signs exactly 2 messages
k <- xmssadv(k, cpssign("one", k))
k <- xmssadv(k, cpssign("two", k))
cpssign("three", k)
})


## -----------------------------------------------------------------------------
pqcbknd()


## -----------------------------------------------------------------------------
m <- mkmnf(list(dataset = "otis", rows = 1200L),
                   env = FALSE)
key <- fipskg("ML-DSA-65")
att <- cpsatst(m, key, note = "counts as published")
cpschkatst(att, m)


## -----------------------------------------------------------------------------
m2 <- m
m2$meta$rows <- 1201L
cpschkatst(att, m2)$ok


## -----------------------------------------------------------------------------
onethird <- mkmnf(list(x = 1 / 3), env = FALSE)
back <- fromjs(mnfcanon(onethird))
identical(back$meta$x, 1 / 3)


## -----------------------------------------------------------------------------
identical(
  mnfdgst(mkmnf(list(a = 1, b = 2), env = FALSE)),
  mnfdgst(mkmnf(list(b = 2, a = 1), env = FALSE)))


## -----------------------------------------------------------------------------
set.seed(1)
d <- data.frame(x = rnorm(200))
d$y <- 0.8 * d$x + rnorm(200)
cpsfals(d, function(z) cor(z$x, z$y), trt = "x",
                n = 199, seed = 42)


## -----------------------------------------------------------------------------
cpsfals(d, function(z) 0.5, trt = "x", n = 199,
                seed = 42)$controls[, c("control", "passed")]


## -----------------------------------------------------------------------------
d <- data.frame(x = 1:10)
man <- mkmnf(list(dataset = "demo"), env = FALSE)
man <- recrd(man, "mean_x", obs = mean(d$x), expd = 5.5)
man <- recrd(man, "n", obs = nrow(d), expd = 10)

mnfrcmp(man, d, list(mean_x = function(z) mean(z$x),
                                n = function(z) nrow(z)))


## -----------------------------------------------------------------------------
mnfrcmp(man, d, list(n = function(z) nrow(z)))


## -----------------------------------------------------------------------------
set.seed(1)
m2 <- mnfrecseed(mkmnf(list(a = 1),
                                         env = FALSE))
first <- runif(3)
invisible(runif(1000))          # any amount of other work
mnfrstseed(m2)
identical(runif(3), first)


## -----------------------------------------------------------------------------
plan <- prrgdecl(c(
  ate = "use of force is higher in the exposed division",
  n_rows = "the extract has the row count the source publishes"))

# a declared outcome that was not reported
prrgchk(plan, "n_rows")

# statistics reported that were never declared
prrgchk(plan, c("ate", "n_rows", "byyear", "byprecinct"))


## -----------------------------------------------------------------------------
falsfam(c(ate = 0.02, byyear = 0.3, byprecinct = 0.4,
                 byshift = 0.6, bymonth = 0.7), meth = "holm")


## -----------------------------------------------------------------------------
evlrr(2, lo = 1.4, hi = 2.9)


## -----------------------------------------------------------------------------
dir <- tempfile()
dir.create(dir)
write.csv(data.frame(x = 1:3), file.path(dir, "data.csv"),
          row.names = FALSE)
b <- cpsbndl(dir, man, key, note = "as published")
cpsbndlvrf(attr(b, "path"), dir, man = man)


## -----------------------------------------------------------------------------
unlink(dir, recursive = TRUE)


## ----eval=FALSE---------------------------------------------------------------
# res <- tsvrf("response.tsr", data = "manifest.json")
# res$time
# res$checks


## -----------------------------------------------------------------------------
chunks <- c("id,value", "1,2", "3,4", "5,6")
root <- mrkroot(chunks)
root


## -----------------------------------------------------------------------------
# Editing one chunk moves exactly one leaf.
editedchunks <- chunks
editedchunks[3] <- "3,5"
which(mrklvs(chunks) != mrklvs(editedchunks))


## -----------------------------------------------------------------------------
# Prove chunk 3 belongs, holding only it and log2(n) sibling digests.
proof <- mrkprf(chunks, 3)
proof
mrkvrf(chunks[3], proof, root)
mrkvrf("3,5", proof, root)


## -----------------------------------------------------------------------------
mrkroot(c("a", "b", "c")) == mrkroot(c("a", "b", "c", "c"))


## -----------------------------------------------------------------------------
chain <- chnnew()
chain <- chnapp(chain, "manifest for run 1", label = "run-1")
chain <- chnapp(chain, "manifest for run 2", label = "run-2")
chain <- chnapp(chain, "manifest for run 3", label = "run-3")
chain


## -----------------------------------------------------------------------------
# Deleting an entry from the middle breaks the links, and names where.
tampered <- chain
tampered$entries[[2]] <- NULL
chnvrf(tampered)


## -----------------------------------------------------------------------------
truncated <- chain
truncated$entries[[3]] <- NULL

c(headuncbymiddel =
    chnhead(tampered) == chnhead(chain),
  linksacctru = chnvrf(truncated)$valid)


## -----------------------------------------------------------------------------
sealsig <- cpssign(chnseal(chain), signingkey)
cpsvrf(chnseal(chain), sealsig, pub)

# The truncated chain seals to a different value.
cpsvrf(chnseal(truncated), sealsig, pub)

# A chain whose links disagree has no seal to offer at all.
chnseal(tampered)


## ----indigenous-provenance----------------------------------------------------
cr <- readLines(system.file("COPYRIGHTS", package = "rmoriebricklayer"))
cat(cr[grep("indigenouslifeexpectancy", cr) + 0:4], sep = "\n")


## ----indigenous-tables, eval = FALSE------------------------------------------
# head(indtabs()[, c("key", "rows")])


## ----provenance-plot, fig.width = 6, fig.height = 4---------------------------
barplot(d$x, names.arg = seq_len(nrow(d)), col = blpal()[1], xlab = "row", ylab = "x",
        main = "The values the manifest pins")

